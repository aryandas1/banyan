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

    init() {
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
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authState)
                .environment(syncService)
                .environment(\.shareService, shareService)
        }
        .modelContainer(for: BanyanSchemaV1.models)
    }
}
