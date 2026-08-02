// SupabaseClientProvider.swift
// Builds the app's Supabase client from the bundled config (Supabase.plist via
// SupabaseConfig). Create one client at the composition root and inject it where
// needed — no global singletons, per CLAUDE.md.

import Foundation
import Supabase

enum SupabaseClientProvider {
    /// A Supabase client for this project, keyed with the anon (public) key.
    /// Access control is enforced by Row Level Security; the auth session layered
    /// on top identifies the actual signed-in user.
    static func makeClient() -> SupabaseClient {
        SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.anonKey)
    }
}
