// BanyanApp.swift
// App entry point. Installs the SwiftData container from the versioned schema.

import SwiftUI
import SwiftData

@main
struct BanyanApp: App {
    // The single app-wide sync service, injected into the view tree. Built here
    // (not in a previewable view) so the Supabase client is only constructed at
    // real app launch. One client is shared between the store and the auth
    // closure, which ensures an anonymous session so RLS sees a real user.
    @State private var syncService: SyncService = {
        let client = SupabaseClientProvider.makeClient()
        return SyncService(
            remote: SupabaseRemoteStore(client: client),
            currentUserId: { try await SupabaseAuth.currentUserId(client: client) }
        )
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(syncService)
        }
        .modelContainer(for: BanyanSchemaV1.models)
    }
}
