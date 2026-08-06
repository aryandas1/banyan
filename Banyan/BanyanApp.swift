// BanyanApp.swift
// App entry point and composition root. Builds one Supabase client and injects
// it into auth and the sync closure — no singletons. Installs the SwiftData
// container from the versioned schema.

import SwiftUI
import SwiftData

@main
struct BanyanApp: App {
    // Drives root navigation from auth state.
    @State private var authState: AuthStateManager
    // The single app-wide sync service, injected into the view tree.
    @State private var syncService: SyncService
    // The owner-side sharing service, injected via the environment (keypath).
    private let shareService: any ShareServiceProtocol
    // The viewer-side invite service, injected via the environment (keypath).
    private let inviteAcceptanceService: any InviteAcceptanceServiceProtocol
    // The SwiftData store. Normally the default persistent container; a UI-test
    // launch (DEBUG only) swaps in an in-memory seeded one.
    private let modelContainer: ModelContainer

    init() {
        #if DEBUG
        // Hermetic UI-test path: stubbed auth/invite + a seeded in-memory store,
        // so a viewer's read-only UI can be exercised with no network. Compiled
        // out of release builds (see UITestSupport).
        if UITestSupport.isViewerLaunch {
            let auth = AuthStateManager(authService: UITestAuthService())
            _authState = State(initialValue: auth)
            let client = SupabaseClientProvider.makeClient()
            _syncService = State(initialValue: SyncService(
                remote: SupabaseRemoteStore(client: client),
                currentUserId: { auth.userId ?? UUID() }
            ))
            shareService = SupabaseShareService(client: client)
            inviteAcceptanceService = UITestInviteService()
            modelContainer = UITestSupport.makeSeededViewerContainer()
            return
        }
        if UITestSupport.isAcceptFlowLaunch {
            // Clean signed-in state + a stub service that accepts successfully, so
            // the deep-link acceptance sheet runs end to end with no network.
            let auth = AuthStateManager(authService: UITestAuthService())
            _authState = State(initialValue: auth)
            let client = SupabaseClientProvider.makeClient()
            _syncService = State(initialValue: SyncService(
                remote: SupabaseRemoteStore(client: client),
                currentUserId: { auth.userId ?? UUID() }
            ))
            shareService = SupabaseShareService(client: client)
            inviteAcceptanceService = UITestAcceptInviteService()
            modelContainer = UITestSupport.makeEmptyContainer()
            return
        }
        #endif

        // One shared client at the composition root — injected into auth, the
        // remote store, the sync closure, and the share service (no singletons;
        // CLAUDE.md).
        let client = SupabaseClientProvider.makeClient()

        // Use AnonymousAuthService during development. Switch to AppleAuthService
        // when Apple Developer credentials are ready.
        let auth = AuthStateManager(authService: AnonymousAuthService(client: client))
        _authState = State(initialValue: auth)

        _syncService = State(initialValue: SyncService(
            remote: SupabaseRemoteStore(client: client),
            // Reuse the existing closure seam — sync reads the signed-in user from
            // AuthStateManager and throws when signed out (SyncService swallows it).
            currentUserId: {
                guard let id = auth.userId else { throw AuthError.notSignedIn }
                return id
            }
        ))

        shareService = SupabaseShareService(client: client)
        inviteAcceptanceService = SupabaseInviteAcceptanceService(client: client)
        modelContainer = BanyanApp.makeDefaultContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authState)
                .environment(syncService)
                .environment(\.shareService, shareService)
                .environment(\.inviteAcceptanceService, inviteAcceptanceService)
        }
        .modelContainer(modelContainer)
    }

    /// The default persistent container from the current (V2) schema — the
    /// explicit equivalent of `.modelContainer(for:)`, so a UI-test launch can
    /// substitute an in-memory one through the same `modelContainer` property.
    ///
    /// No explicit `SchemaMigrationPlan`: a frozen V1 stage would reuse the live
    /// `Person` type, which now declares `@Relationship var photos`, so SwiftData
    /// auto-discovers `PersonPhoto` and V1 resolves to the same models as V2 —
    /// a two-stage plan then collides on identical checksums. SwiftData's own
    /// inferred lightweight migration handles the additive change instead, and
    /// with no shipped users a bespoke stage isn't warranted (see BanyanSchemaV2).
    private static func makeDefaultContainer() -> ModelContainer {
        guard let container = try? ModelContainer(for: Schema(BanyanSchemaV2.models)) else {
            fatalError("Failed to create the SwiftData container.")
        }
        return container
    }
}
