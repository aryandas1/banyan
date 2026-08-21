// SyncStatusView.swift
// A small, calm cloud-sync indicator for the Tree tab, OWNER-ONLY (a viewer never
// pushes, so this is only placed on the non-read-only path). It's a thin switch
// over the pure `SyncStatus` derivation — all the wording/precedence/relative-time
// logic is unit-tested there; this view only maps the status to icon + color and
// self-hides when there's nothing to report (`.idle`).

import SwiftUI

struct SyncStatusView: View {
    @Environment(SyncService.self) private var syncService

    private var status: SyncStatus {
        SyncStatus.from(
            isSyncing: syncService.isSyncing,
            lastSyncError: syncService.lastSyncError,
            lastSyncDate: syncService.lastSyncDate
        )
    }

    var body: some View {
        if let text = status.displayText() {
            HStack(spacing: 6) {
                if let systemImage = status.systemImage {
                    Image(systemName: systemImage)
                        .font(.footnote)
                }
                Text(text)
                    .font(.footnote)
            }
            .foregroundStyle(color(for: status.tone))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("syncStatus")
        }
    }

    /// Maps the abstract tone to a theme token. Kept in the view so `SyncStatus`
    /// stays free of SwiftUI (and on the coverage gate).
    private func color(for tone: SyncStatus.Tone) -> Color {
        switch tone {
        case .neutral, .working: return BanyanTheme.Color.textSecondary
        case .positive:          return BanyanTheme.Color.positive
        case .warning:           return BanyanTheme.Color.warning
        }
    }
}
