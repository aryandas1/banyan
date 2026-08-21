// SyncStatus.swift
// Pure derivation of what the owner-only sync indicator should say, from the three
// observables SyncService exposes (isSyncing / lastSyncError / lastSyncDate). All
// the "which state wins, what words, what relative time" logic lives here so it's
// fully unit-tested; the SwiftUI view is a thin switch over it (mirrors TreeSwitcher
// and ViewerRootPicker — no SwiftUI import, so it stays on the coverage gate).
//
// Tone is calm by design: this app targets older, non-technical users, so a
// transient failed push reads as a reassuring "will retry", never an alarming code.

import Foundation

/// The display state of the last / current cloud sync. Derived, never stored.
enum SyncStatus: Equatable {
    /// A sync is in flight right now.
    case syncing
    /// The most recent attempt failed (retryable, best-effort — never surfaced raw).
    case failed
    /// The last successful sync completed at this date.
    case synced(Date)
    /// Nothing to report yet: never synced, no error, not syncing.
    case idle

    /// A color intent for the view — kept abstract (no SwiftUI Color) so this type
    /// stays pure and testable; the view maps each case to a theme token.
    enum Tone: Equatable {
        case neutral
        case working
        case positive
        case warning
    }

    /// Precedence: an in-flight sync wins, then a failure, then a last-success date,
    /// else nothing. `lastSyncError` is inspected only for presence — the raw error
    /// is never shown.
    static func from(isSyncing: Bool, lastSyncError: Error?, lastSyncDate: Date?) -> SyncStatus {
        if isSyncing { return .syncing }
        if lastSyncError != nil { return .failed }
        if let lastSyncDate { return .synced(lastSyncDate) }
        return .idle
    }

    /// The color intent for this status.
    var tone: Tone {
        switch self {
        case .syncing:  return .working
        case .failed:   return .warning
        case .synced:   return .positive
        case .idle:     return .neutral
        }
    }

    /// The SF Symbol for this status, or nil when nothing should be shown.
    var systemImage: String? {
        switch self {
        case .syncing:  return "arrow.triangle.2.circlepath"
        case .failed:   return "exclamationmark.circle"
        case .synced:   return "checkmark.circle.fill"
        case .idle:     return nil
        }
    }

    /// The line to show, or nil when the indicator should be hidden (`.idle`).
    /// `now` is injectable so the relative-time formatting is deterministic in tests.
    func displayText(now: Date = .now) -> String? {
        switch self {
        case .syncing:          return "Saving…"
        case .failed:           return "Couldn't save — will retry"
        case .synced(let date): return "Saved · \(Self.relativeText(from: date, now: now))"
        case .idle:             return nil
        }
    }

    /// A short, non-technical "how long ago" string with coarse buckets (just now /
    /// Nm ago / Nh ago / Nd ago). Deliberately hand-rolled — there's no
    /// RelativeDateTimeFormatter in the app and these buckets read plainly for older
    /// users. Future dates (clock skew) clamp to "just now".
    static func relativeText(from date: Date, now: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = Int(seconds / 3600)
        if hours < 24 { return "\(hours)h ago" }
        let days = Int(seconds / 86_400)
        return "\(days)d ago"
    }
}
