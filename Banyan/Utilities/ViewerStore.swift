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
    private static let ownerTreeIdKey = "ownerTreeId"
    private func rootKey(_ treeId: UUID) -> String { "viewerRoot:\(treeId.uuidString)" }
    private func acceptedTokenKey(_ token: String) -> String { "acceptedToken:\(token)" }

    /// The tree this device owns (created at onboarding), or nil if none recorded.
    /// Kept in a dedicated key that `addViewerTree` never touches, so accepting an
    /// invite can tell "my own tree" apart from a genuinely shared one.
    var ownerTreeId: UUID? {
        defaults.string(forKey: Self.ownerTreeIdKey).flatMap(UUID.init(uuidString:))
    }

    /// Records `treeId` as the tree this device owns. Set once — never overwrites,
    /// so a later reinstall or an existing install can't clobber the marker.
    func setOwnerTree(_ treeId: UUID) {
        guard ownerTreeId == nil else { return }
        defaults.set(treeId.uuidString, forKey: Self.ownerTreeIdKey)
    }

    /// Whether `treeId` is this device's own tree (created here, not one it joined
    /// as a viewer).
    func isOwnedTree(_ treeId: UUID) -> Bool { ownerTreeId == treeId }

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

    /// The tree id a previously-accepted `token` resolved to on this device, or
    /// nil if this token has not been accepted here. Lets the acceptance flow
    /// short-circuit a re-tap / `onOpenURL` redelivery straight to success instead
    /// of calling the accept RPC a second time — the RPC is NOT idempotent (it
    /// only matches a `pending` invitation, so a second call errors) and that
    /// error otherwise flashes a failure screen over a tree the viewer can already
    /// see.
    func treeId(forAcceptedToken token: String) -> UUID? {
        defaults.string(forKey: acceptedTokenKey(token)).flatMap(UUID.init(uuidString:))
    }

    /// Memoizes that `token` was successfully accepted for `treeId` on this device,
    /// so a later re-open of the same link can resolve without re-calling the RPC.
    func recordAcceptedToken(_ token: String, treeId: UUID) {
        defaults.set(treeId.uuidString, forKey: acceptedTokenKey(token))
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
