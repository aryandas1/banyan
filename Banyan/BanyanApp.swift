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
    // The photo-sync service (upload/download bytes + rows), injected via keypath.
    private let photoSyncService: any PhotoSyncServiceProtocol
    // The SwiftData store. Normally the default persistent container; a UI-test
    // launch (DEBUG only) swaps in an in-memory seeded one.
    private let modelContainer: ModelContainer

    init() {
        // Appearance first — every path below (UITest branches included) returns
        // early, so the global chrome styling has to run before any of them.
        BanyanApp.configureAppearance()

        #if DEBUG
        // Hermetic UI-test paths: stubbed auth + a seeded in-memory store, so the
        // UI can be exercised with no network. Each shares the same composition
        // (see makeUITestServices) and differs only in the invite service + store.
        // Compiled out of release builds (see UITestSupport).
        if UITestSupport.isViewerLaunch {
            let s = BanyanApp.makeUITestServices()
            _authState = State(initialValue: s.auth)
            _syncService = State(initialValue: s.sync)
            shareService = s.share
            photoSyncService = s.photo
            inviteAcceptanceService = UITestInviteService()
            modelContainer = UITestSupport.makeSeededViewerContainer()
            return
        }
        if UITestSupport.isAcceptFlowLaunch {
            // Clean signed-in state + a stub service that accepts successfully, so
            // the deep-link acceptance sheet runs end to end with no network.
            let s = BanyanApp.makeUITestServices()
            _authState = State(initialValue: s.auth)
            _syncService = State(initialValue: s.sync)
            shareService = s.share
            photoSyncService = s.photo
            inviteAcceptanceService = UITestAcceptInviteService()
            modelContainer = UITestSupport.makeEmptyContainer()
            return
        }
        if UITestSupport.isReacceptFlowLaunch {
            // Viewer who already accepted this invite + a FAILING accept service, so
            // re-presenting the sheet must short-circuit via the token memo (success),
            // never the failure screen the real non-idempotent RPC would produce.
            let s = BanyanApp.makeUITestServices()
            _authState = State(initialValue: s.auth)
            _syncService = State(initialValue: s.sync)
            shareService = s.share
            photoSyncService = s.photo
            inviteAcceptanceService = UITestReacceptInviteService()
            modelContainer = UITestSupport.makeReacceptedViewerContainer()
            return
        }
        if UITestSupport.isOwnerOwnInviteLaunch {
            // Signed-in owner of the invited tree + a stub accept service that
            // returns that same tree id, so the owner-opens-own-invite guard runs.
            let s = BanyanApp.makeUITestServices()
            _authState = State(initialValue: s.auth)
            _syncService = State(initialValue: s.sync)
            shareService = s.share
            photoSyncService = s.photo
            inviteAcceptanceService = UITestAcceptInviteService()
            modelContainer = UITestSupport.makeSeededOwnerContainer()
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
        photoSyncService = PhotoSyncService(client: client)
        modelContainer = BanyanApp.makeDefaultContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authState)
                .environment(syncService)
                .environment(\.shareService, shareService)
                .environment(\.inviteAcceptanceService, inviteAcceptanceService)
                .environment(\.photoSyncService, photoSyncService)
                // BanyanTheme's palette is light-only (fixed warm off-white +
                // near-black text); rendering it over dark system surfaces would
                // break contrast, so the app locks to light appearance.
                .preferredColorScheme(.light)
                .tint(BanyanTheme.Color.primary)
        }
        .modelContainer(modelContainer)
    }

    /// Global UIKit chrome that SwiftUI can't reach per-view: the tab bar.
    /// Screen backgrounds are set per-view with BanyanTheme tokens instead of a
    /// blanket `UIView.appearance` hack, which bleeds into alerts and sheets.
    private static func configureAppearance() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(BanyanTheme.Color.surface)
        tabAppearance.shadowColor = UIColor(BanyanTheme.Color.chrome)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = UIColor(BanyanTheme.Color.primary)
        UITabBar.appearance().unselectedItemTintColor = UIColor(BanyanTheme.Color.textTertiary)
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

    #if DEBUG
    /// The composition shared by every hermetic UI-test launch branch: a stub auth
    /// (instant sign-in) and the real sync/share/photo services over one client.
    /// Branches differ only in the invite service and seeded store.
    private static func makeUITestServices() -> (
        auth: AuthStateManager,
        sync: SyncService,
        share: any ShareServiceProtocol,
        photo: any PhotoSyncServiceProtocol
    ) {
        let auth = AuthStateManager(authService: UITestAuthService())
        let client = SupabaseClientProvider.makeClient()
        let sync = SyncService(
            remote: SupabaseRemoteStore(client: client),
            currentUserId: { auth.userId ?? UUID() }
        )
        return (auth, sync, SupabaseShareService(client: client), PhotoSyncService(client: client))
    }
    #endif
}
