// ViewerStore.swift
// Persists the viewer's role: which trees this device joined as a viewer, and the
// focal/root person chosen for each. Backed by UserDefaults so it shares the same
// store as @AppStorage("treeId") — writing "treeId" here keeps the tree views in
// sync. UserDefaults is injected so tests use an isolated suite.
//
// There is no `AppState` type in this app (treeId / ownerPersonId are plain
// @AppStorage String keys written in onboarding); this is the small persistence
// helper the sharing flow needs on top of them.

import Foundation

struct ViewerStore {
    private let defaults: UserDefaults

    /// Injects the backing store. Defaults to `.standard` in the app so it shares
    /// state with @AppStorage; tests pass an isolated suite.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private static let viewerTreeIdsKey = "viewerTreeIds"
    private func rootKey(_ treeId: UUID) -> String { "viewerRoot:\(treeId.uuidString)" }

    /// The set of tree ids this device joined as a viewer.
    var viewerTreeIds: Set<UUID> {
        let strings = defaults.stringArray(forKey: Self.viewerTreeIdsKey) ?? []
        return Set(strings.compactMap { UUID(uuidString: $0) })
    }

    /// Whether the given tree is one this device only views (read-only).
    func isViewer(treeId: UUID) -> Bool {
        viewerTreeIds.contains(treeId)
    }

    /// The focal/root person chosen for a viewed tree, or nil if none was stored.
    func rootPersonId(forTree treeId: UUID) -> UUID? {
        guard let string = defaults.string(forKey: rootKey(treeId)) else { return nil }
        return UUID(uuidString: string)
    }

    /// Records that this device joined `treeId` as a viewer with `rootPersonId` as
    /// its focal, and switches the app to that tree by writing the shared "treeId"
    /// key (the same backing store as @AppStorage("treeId")).
    func addViewerTree(_ treeId: UUID, rootPersonId: UUID?) {
        var ids = viewerTreeIds
        ids.insert(treeId)
        defaults.set(ids.map(\.uuidString), forKey: Self.viewerTreeIdsKey)
        defaults.set(treeId.uuidString, forKey: "treeId")
        if let rootPersonId {
            defaults.set(rootPersonId.uuidString, forKey: rootKey(treeId))
        }
    }
}
