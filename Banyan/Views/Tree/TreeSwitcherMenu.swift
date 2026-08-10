// TreeSwitcherMenu.swift
// The Tree tab's tree-name menu: shows the active tree's name and lets the user
// switch among the trees they own or view. The caller places this in the toolbar
// and only when there's more than one tree, so a single-tree user sees no chrome.

import SwiftUI

struct TreeSwitcherMenu: View {
    let options: [TreeSwitcherOption]
    let activeTreeId: UUID?
    let onSelect: (UUID) -> Void

    private var activeLabel: String {
        options.first { $0.treeId == activeTreeId }?.label ?? TreeSwitcher.fallbackLabel
    }

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    onSelect(option.treeId)
                } label: {
                    // A checkmark marks the tree currently on screen; the owned tree
                    // is always listed first (TreeSwitcher.options guarantees it).
                    if option.treeId == activeTreeId {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(activeLabel)
                    .font(.headline)
                    .foregroundStyle(BanyanTheme.Color.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BanyanTheme.Color.textSecondary)
            }
            .frame(minHeight: 44)
        }
        .accessibilityIdentifier("treeSwitcher")
        .accessibilityLabel("Switch family tree, showing \(activeLabel)")
    }
}
