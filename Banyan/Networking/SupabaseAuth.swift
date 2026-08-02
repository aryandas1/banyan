// SupabaseAuth.swift
// Development auth: ensures an anonymous Supabase session so requests carry a
// real `auth.uid()` and satisfy Row Level Security. The SDK persists the session
// across launches, so an anonymous user is created once and reused thereafter.
// Real Sign in with Apple replaces this in the next step.
//
// NOTE: Anonymous sign-ins must be enabled in Supabase → Authentication →
// Sign In / Providers, or signInAnonymously() fails and sync stays inert.

import Foundation
import Supabase

enum SupabaseAuth {
    /// The current session's user id, signing in anonymously if there's no session yet.
    static func currentUserId(client: SupabaseClient) async throws -> UUID {
        if let existing = try? await client.auth.session {
            return existing.user.id
        }
        let session = try await client.auth.signInAnonymously()
        return session.user.id
    }
}
