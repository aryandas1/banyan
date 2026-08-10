// TreeSwitcher.swift
// Pure logic for the tree switcher: turns the device's owned/viewed tree ids into
// an ordered, labeled option list. No SwiftData — focal names are resolved by an
// injected closure — so it's fully unit-testable (mirrors ViewerRootPicker).
//
// There is no local Tree-name model yet (trees are unnamed; see development-plan
// §3), so a tree is labeled by its focal person's name — the owner's person for
// the owned tree, the stored viewer root for a viewed one.

import Foundation

/// One selectable tree in the switcher.
struct TreeSwitcherOption: Identifiable, Equatable {
    let treeId: UUID
    /// Display label, e.g. "Ravi's family" — falls back to a generic name when the
    /// focal person can't be resolved locally.
    let label: String
    /// True for the device's own editable tree; false for a tree it only views.
    let isOwned: Bool
    var id: UUID { treeId }
}

enum TreeSwitcher {
    /// Shown when a tree's focal person can't be resolved to a name.
    static let fallbackLabel = "Family tree"

    /// Builds the ordered switch options: the owned tree first, then viewed trees
    /// sorted by label (case-insensitive) for a stable menu. `focalName(treeId)`
    /// returns the tree's focal person's first name, or nil if unknown. The owned
    /// tree is never listed twice even if it also appears in `viewerTreeIds`.
    static func options(
        ownerTreeId: UUID?,
        viewerTreeIds: Set<UUID>,
        focalName: (UUID) -> String?
    ) -> [TreeSwitcherOption] {
        func label(for treeId: UUID) -> String {
            let name = focalName(treeId)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty ? fallbackLabel : "\(name)'s family"
        }

        var options: [TreeSwitcherOption] = []
        if let ownerTreeId {
            options.append(TreeSwitcherOption(treeId: ownerTreeId, label: label(for: ownerTreeId), isOwned: true))
        }
        let viewed = viewerTreeIds
            .subtracting(ownerTreeId.map { [$0] } ?? [])
            .map { TreeSwitcherOption(treeId: $0, label: label(for: $0), isOwned: false) }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
        options.append(contentsOf: viewed)
        return options
    }
}
