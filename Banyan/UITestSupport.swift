// UITestSupport.swift
// DEBUG-only launch-argument harness that makes UI tests hermetic: activated by
// `-uiTestViewer`, it stands the app up as a viewer of a small seeded tree with no
// network — a stub auth service (instant sign-in), a stub invite service (so the
// launch-refresh can't reach the network or wipe the seed), and an in-memory store
// seeded with a couple of people. Compiled out of release builds entirely.

#if DEBUG
import Foundation
import SwiftData

enum UITestSupport {
    /// True when the app was launched by a UI test that wants read-only viewer mode.
    static var isViewerLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestViewer")
    }

    /// True when the app should present the deep-link acceptance sheet on launch
    /// (against a stub service) — guards the onOpenURL → .sheet → InviteAcceptanceView
    /// path that the viewer-seed harness bypasses.
    static var isAcceptFlowLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestAcceptFlow")
    }

    /// True when the app should stand up as the OWNER of the invited tree and then
    /// present the acceptance sheet — exercises the owner-opens-own-invite guard,
    /// which must land on success WITHOUT locking the owner into read-only mode.
    static var isOwnerOwnInviteLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestOwnerOwnInvite")
    }

    /// True when the app should stand up as a viewer who has ALREADY accepted the
    /// invite and then re-present the acceptance sheet — exercises the re-accept
    /// memo, which must short-circuit to success WITHOUT calling the (failing,
    /// non-idempotent) accept service again, so no failure screen flashes.
    static var isReacceptFlowLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestReaccept")
    }

    /// True when the app should stand up as an owner who ALSO views a second tree,
    /// active on the owned tree — exercises the tree switcher (owned ⇄ viewed).
    static var isTreeSwitcherLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestTreeSwitcher")
    }

    /// True when the app should stand up as an OWNER whose SyncService is backed by
    /// a remote that always throws, then force a sync so `lastSyncError` is set —
    /// exercises the owner-only sync-status indicator's "couldn't save" state.
    static var isSyncFailedLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestSyncFailed")
    }

    /// Whether a launch flag asks ContentView to present the acceptance sheet on
    /// launch (the accept-flow, owner-own-invite, and re-accept harnesses all do).
    static var presentsAcceptSheetOnLaunch: Bool {
        isAcceptFlowLaunch || isOwnerOwnInviteLaunch || isReacceptFlowLaunch
    }

    /// The token ContentView presents on a hermetic accept-sheet launch (matches
    /// the DEBUG launch hook), so the re-accept harness can pre-record it.
    static let launchAcceptToken = "uitest"

    // Fixed ids so the test and the seed agree on the tree/root.
    static let treeId = UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID()
    static let rootId = UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID()
    // A second tree this device only views (used by the tree-switcher harness).
    static let tree2Id = UUID(uuidString: "44444444-4444-4444-4444-444444444444") ?? UUID()
    static let root2Id = UUID(uuidString: "55555555-5555-5555-5555-555555555555") ?? UUID()

    /// An empty in-memory container with owner/viewer state cleared, so the
    /// acceptance flow starts from a clean signed-in state and imports into it.
    static func makeEmptyContainer() -> ModelContainer {
        for key in ["ownerPersonId", "treeId", "viewerTreeIds", "ownerTreeId"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        ViewerStore().clearAcceptedToken(launchAcceptToken)
        return makeInMemoryContainer(label: "empty")
    }

    /// Builds an in-memory container seeded with a tiny tree (root + partner + one
    /// child) and writes the viewer UserDefaults so ContentView routes to a
    /// read-only MainTabView centred on the root.
    static func makeSeededViewerContainer() -> ModelContainer {
        // Become a pure viewer: drop any owner identity, mark this tree as viewed.
        UserDefaults.standard.removeObject(forKey: "ownerPersonId")
        UserDefaults.standard.removeObject(forKey: "ownerTreeId")
        ViewerStore().clearAcceptedToken(launchAcceptToken)
        ViewerStore().addViewerTree(treeId, rootPersonId: rootId)

        let container = makeInMemoryContainer(label: "seeded viewer")
        seedTinyTree(into: ModelContext(container))
        return container
    }

    /// Builds an in-memory container seeded with a tiny tree the device OWNS: sets
    /// `ownerPersonId`/`treeId` app storage + the `ownerTreeId` marker (via
    /// `ViewerStore.setOwnerTree`), and clears any viewer state. Used to prove that
    /// opening one's own invite doesn't flip the app into read-only viewer mode.
    static func makeSeededOwnerContainer() -> ModelContainer {
        UserDefaults.standard.removeObject(forKey: "viewerTreeIds")
        ViewerStore().clearAcceptedToken(launchAcceptToken)
        UserDefaults.standard.set(rootId.uuidString, forKey: "ownerPersonId")
        UserDefaults.standard.set(treeId.uuidString, forKey: "treeId")
        ViewerStore().setOwnerTree(treeId)

        let container = makeInMemoryContainer(label: "seeded owner")
        seedTinyTree(into: ModelContext(container))
        return container
    }

    /// Builds a viewer container that has ALREADY accepted the invite token: it's a
    /// viewer of the seeded tree AND the launch token is memoized. Re-presenting the
    /// acceptance sheet must therefore short-circuit to success via the token memo,
    /// not call the (failing) accept service — proving the re-accept-flash fix.
    static func makeReacceptedViewerContainer() -> ModelContainer {
        UserDefaults.standard.removeObject(forKey: "ownerPersonId")
        UserDefaults.standard.removeObject(forKey: "ownerTreeId")
        let store = ViewerStore()
        store.addViewerTree(treeId, rootPersonId: rootId)
        store.recordAcceptedToken(launchAcceptToken, treeId: treeId)

        let container = makeInMemoryContainer(label: "reaccepted viewer")
        seedTinyTree(into: ModelContext(container))
        return container
    }

    /// Builds a container for the tree-switcher test: the device OWNS the "Ravi"
    /// tree (active + editable) and also VIEWS a second "Priya" tree. Both trees'
    /// persons live in the one store, so the switcher can label each by its focal.
    static func makeTreeSwitcherContainer() -> ModelContainer {
        for key in ["viewerTreeIds", "ownerTreeId"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        let store = ViewerStore()
        // Register the viewed tree first (addViewerTree makes it the active tree)…
        store.addViewerTree(tree2Id, rootPersonId: root2Id)
        // …then make the OWNED tree the active + owned one.
        UserDefaults.standard.set(rootId.uuidString, forKey: "ownerPersonId")
        UserDefaults.standard.set(treeId.uuidString, forKey: "treeId")
        store.setOwnerTree(treeId)

        let container = makeInMemoryContainer(label: "tree switcher")
        let context = ModelContext(container)
        seedTinyTree(into: context)
        seedSecondTree(into: context)
        return container
    }

    /// Inserts the viewed second tree's focal person ("Priya"), enough for the
    /// switcher to label it and for the read-only tree to render after a switch.
    private static func seedSecondTree(into context: ModelContext) {
        let root = Person(id: root2Id, treeId: tree2Id, firstName: "Priya", lastName: "Rao")
        context.insert(root)
        try? context.save()
    }

    /// An empty in-memory container for the current schema; traps with `label` if
    /// SwiftData can't build it (a programmer error in a DEBUG-only test harness).
    private static func makeInMemoryContainer(label: String) -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: Schema(BanyanSchemaV2.models), configurations: config) else {
            fatalError("UITestSupport: failed to build the \(label) in-memory container.")
        }
        return container
    }

    /// Inserts the shared 3-person fixture (root + partner + child in one married
    /// union) used by both the viewer and owner seed containers.
    private static func seedTinyTree(into context: ModelContext) {
        let root = Person(id: rootId, treeId: treeId, firstName: "Ravi", lastName: "Sharma")
        let partner = Person(treeId: treeId, firstName: "Meera", lastName: "Sharma")
        let child = Person(treeId: treeId, firstName: "Anaya", lastName: "Sharma")
        let union = Union(treeId: treeId, type: .married)
        for person in [root, partner, child] { context.insert(person) }
        context.insert(union)
        for (person, role) in [(root, LinkRole.partner), (partner, .partner), (child, .child)] {
            let link = PersonUnionLink(role: role)
            context.insert(link)
            link.person = person
            link.union = union
        }
        try? context.save()
    }
}

/// Signs in instantly with a fixed id — no network — so UI tests reach the
/// signed-in state deterministically.
final class UITestAuthService: AuthServiceProtocol {
    let userId: UUID? = UUID(uuidString: "33333333-3333-3333-3333-333333333333")
    func restoreSession() async throws -> UUID { userId ?? UUID() }
    func signOut() async throws {}
}

/// A no-op invite service: the viewer launch-refresh calls `fetchSharedTree`, so
/// throwing here makes that best-effort `try?` bail — no network, seed preserved.
final class UITestInviteService: InviteAcceptanceServiceProtocol {
    private struct Unused: Error {}
    func acceptInvitation(token: String) async throws -> UUID { UITestSupport.treeId }
    func fetchSharedTree(treeId: UUID) async throws -> SharedTreeSnapshot { throw Unused() }
}

/// An invite service that FAILS on every call — simulates the real non-idempotent
/// RPC rejecting a second accept. The re-accept token memo must short-circuit to
/// success BEFORE this is ever reached; if it didn't, the sheet would flash the
/// failure screen (the bug under test).
final class UITestReacceptInviteService: InviteAcceptanceServiceProtocol {
    private struct AlreadyUsed: Error {}
    func acceptInvitation(token: String) async throws -> UUID { throw AlreadyUsed() }
    func fetchSharedTree(treeId: UUID) async throws -> SharedTreeSnapshot { throw AlreadyUsed() }
}

/// A RemoteStore that fails every operation — simulates a misconfigured / offline
/// backend so the owner-only sync-status indicator lands in its "couldn't save"
/// state after a forced sync (the -uiTestSyncFailed harness).
final class UITestFailingRemoteStore: RemoteStore {
    private struct Offline: Error {}
    func upsertTree(_ tree: TreeDTO) async throws { throw Offline() }
    func upsert(_ persons: [PersonDTO]) async throws { throw Offline() }
    func upsert(_ unions: [UnionDTO]) async throws { throw Offline() }
    func upsert(_ links: [PersonUnionLinkDTO]) async throws { throw Offline() }
    func remoteIds(in table: RemoteTable, treeId: UUID) async throws -> Set<UUID> { throw Offline() }
    func delete(from table: RemoteTable, id: UUID) async throws { throw Offline() }
}

/// A stub invite service that SUCCEEDS with a one-person canned tree, so the
/// acceptance-sheet UI test can run the full accept → import → success path
/// hermetically (no network).
final class UITestAcceptInviteService: InviteAcceptanceServiceProtocol {
    func acceptInvitation(token: String) async throws -> UUID { UITestSupport.treeId }
    func fetchSharedTree(treeId: UUID) async throws -> SharedTreeSnapshot {
        let person = PersonDTO(from: Person(
            id: UITestSupport.rootId, treeId: UITestSupport.treeId, firstName: "Ravi", lastName: "Sharma"
        ))
        return SharedTreeSnapshot(persons: [person], unions: [], links: [])
    }
}
#endif
