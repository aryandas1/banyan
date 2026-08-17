// AnonymousAuthService.swift
// Development auth: signs in anonymously via Supabase so requests carry a real
// `auth.uid()` and satisfy Row Level Security. The SDK persists the session
// across launches, so the anonymous user is created once and reused thereafter.
// Absorbs the logic formerly in SupabaseAuth. Swapped for AppleAuthService in
// production.
//
// NOTE: Anonymous sign-ins must be enabled in Supabase → Authentication →
// Sign In / Providers, or signInAnonymously() fails and sync stays inert.
//
// Lives in Networking (not Services) alongside SupabaseRemoteStore because it
// wraps the live Supabase client and can't be unit-tested — this keeps it off
// the `make coverage` gate.

import Foundation
import Supabase

final class AnonymousAuthService: AuthServiceProtocol {

    private let client: SupabaseClient
    private(set) var userId: UUID?

    /// Injects the shared Supabase client built at the composition root.
    init(client: SupabaseClient) {
        self.client = client
    }

    func restoreSession() async throws -> UUID {
        if let existing = try? await client.auth.session {
            let id = existing.user.id
            userId = id
            return id
        }
        let session = try await client.auth.signInAnonymously()
        let id = session.user.id
        userId = id
        return id
    }

    func signOut() async throws {
        try await client.auth.signOut()
        userId = nil
    }
}
