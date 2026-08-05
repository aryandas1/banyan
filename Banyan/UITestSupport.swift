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

    // Fixed ids so the test and the seed agree on the tree/root.
    static let treeId = UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID()
    static let rootId = UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID()

    /// An empty in-memory container with owner/viewer state cleared, so the
    /// acceptance flow starts from a clean signed-in state and imports into it.
    static func makeEmptyContainer() -> ModelContainer {
        for key in ["ownerPersonId", "treeId", "viewerTreeIds"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: Schema(BanyanSchemaV1.models), configurations: config) else {
            fatalError("UITestSupport: failed to build the empty in-memory container.")
        }
        return container
    }

    /// Builds an in-memory container seeded with a tiny tree (root + partner + one
    /// child) and writes the viewer UserDefaults so ContentView routes to a
    /// read-only MainTabView centred on the root.
    static func makeSeededViewerContainer() -> ModelContainer {
        // Become a pure viewer: drop any owner identity, mark this tree as viewed.
        UserDefaults.standard.removeObject(forKey: "ownerPersonId")
        ViewerStore().addViewerTree(treeId, rootPersonId: rootId)

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: Schema(BanyanSchemaV1.models), configurations: config) else {
            fatalError("UITestSupport: failed to build the seeded in-memory container.")
        }
        let context = ModelContext(container)

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
        return container
    }
}

/// Signs in instantly with a fixed id — no network — so UI tests reach the
/// signed-in state deterministically.
final class UITestAuthService: AuthServiceProtocol {
    let userId: UUID? = UUID(uuidString: "33333333-3333-3333-3333-333333333333")
    func signIn() async throws -> UUID { userId ?? UUID() }
    func signOut() async throws {}
}

/// A no-op invite service: the viewer launch-refresh calls `fetchSharedTree`, so
/// throwing here makes that best-effort `try?` bail — no network, seed preserved.
final class UITestInviteService: InviteAcceptanceServiceProtocol {
    private struct Unused: Error {}
    func acceptInvitation(token: String) async throws -> UUID { UITestSupport.treeId }
    func fetchSharedTree(treeId: UUID) async throws -> SharedTreeSnapshot { throw Unused() }
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
