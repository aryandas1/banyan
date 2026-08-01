#!/usr/bin/env python3
"""Summarise Xcode test coverage for Banyan's meaningful (unit-testable) source.

Reads an .xcresult bundle via `xccov`, filters to the MVVM logic layers
(Models, Services, ViewModels, Utilities) — the code unit tests can meaningfully
cover — and reports per-file and aggregate line coverage. SwiftUI Views and the
app entry point are listed but NOT gated: exercising them needs UI tests, which
this repo can't run (no Accessibility permission for scripted taps).

Exit status is non-zero when meaningful coverage is below --min, so `make
coverage` can act as a gate.

Usage: coverage.py <path/to/result.xcresult> [--min 80]
"""
import argparse
import json
import subprocess
import sys

# Path fragments that mark a file as meaningful — the layers unit tests reach.
# Add a layer here if the app grows one that ought to be gated.
MEANINGFUL = (
    "/Banyan/Models/",
    "/Banyan/Services/",
    "/Banyan/ViewModels/",
    "/Banyan/Utilities/",
)

_TTY = sys.stdout.isatty()
GREEN = "\033[32m" if _TTY else ""
RED = "\033[31m" if _TTY else ""
DIM = "\033[2m" if _TTY else ""
BOLD = "\033[1m" if _TTY else ""
RESET = "\033[0m" if _TTY else ""


def app_files(xcresult):
    """Every source file in the app target (the test bundle is skipped)."""
    out = subprocess.run(
        ["xcrun", "xccov", "view", "--report", "--json", xcresult],
        capture_output=True, text=True, check=True,
    ).stdout
    report = json.loads(out)
    files = []
    for target in report.get("targets", []):
        if target.get("name", "").endswith(".xctest"):
            continue
        files.extend(target.get("files", []))
    return files


def repo_path(path):
    """Trim an absolute path down to its repo-relative form (from 'Banyan/')."""
    marker = "/Banyan/"
    i = path.rfind(marker)
    return path[i + 1:] if i >= 0 else path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("xcresult", help="path to the .xcresult bundle")
    ap.add_argument("--min", type=float, default=80.0,
                    help="minimum aggregate %% for meaningful files (default 80)")
    args = ap.parse_args()

    files = app_files(args.xcresult)
    meaningful, other = [], []
    for f in files:
        bucket = meaningful if any(m in f["path"] for m in MEANINGFUL) else other
        bucket.append(f)

    if not meaningful:
        print(f"{RED}No meaningful source files found in coverage report.{RESET}",
              file=sys.stderr)
        return 2

    meaningful.sort(key=lambda f: (f["lineCoverage"], repo_path(f["path"])))

    print(f"\n{BOLD}Meaningful files (Models · Services · ViewModels · Utilities){RESET}\n")
    covered = executable = 0
    for f in meaningful:
        c, e = f["coveredLines"], f["executableLines"]
        covered += c
        executable += e
        pct = f["lineCoverage"] * 100
        color = GREEN if pct >= args.min else RED
        print(f"  {color}{pct:6.1f}%{RESET}  {c:>4}/{e:<5} {repo_path(f['path'])}")

    total = (covered / executable * 100) if executable else 100.0
    passed = total >= args.min
    verdict = f"{GREEN}PASS{RESET}" if passed else f"{RED}FAIL{RESET}"
    print(f"\n  {'-' * 62}")
    print(f"  {BOLD}TOTAL  {total:.1f}%{RESET}  ({covered}/{executable} lines)  "
          f"min {args.min:.0f}%  {verdict}\n")

    if other:
        other.sort(key=lambda f: (f["lineCoverage"], repo_path(f["path"])))
        print(f"{DIM}Not gated — UI / app entry (need UI tests):{RESET}")
        for f in other:
            print(f"{DIM}  {f['lineCoverage'] * 100:6.1f}%  {repo_path(f['path'])}{RESET}")
        print()

    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
