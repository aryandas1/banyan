// AppleAuthService.swift
// Production auth: Sign in with Apple, verified by Supabase. The native
// SignInWithAppleButton (in SignInView) owns the Apple sheet and the nonce; this
// service just (a) restores an existing Supabase session at launch and (b)
// exchanges the button's identity token for a session. It deliberately does NOT
// present ASAuthorization itself — driving the flow from the button removes the
// old CheckedContinuation (and its main-thread-delegate-vs-Task data race) and
// avoids double-presenting a second Apple sheet.
//
// External setup (one-time): App ID `com.aryandas.Banyan` with the Sign in with
// Apple capability; Supabase → Auth → Providers → Apple enabled with
// `com.aryandas.Banyan` in "Client IDs" (native needs no Service ID / OAuth
// secret). Until that's saved, signInWithIdToken returns an invalid-client error.
//
// Account migration (deferred — see dev-plan §1, decision D1): sign-in happens
// BEFORE onboarding and there are no real anonymous users, so a fresh user has no
// data to strand under RLS, and Apple returns the same uid on reinstall
// (reinstall-safety for free). If "try before sign-in" is ever added, LINK the
// anonymous identity to Apple rather than a plain signInWithIdToken (which mints a
// new uid and orphans the tree — the 42501 trap).
//
// Lives in Networking (not Services) alongside SupabaseRemoteStore: it wraps the
// live Supabase client, so it can't be unit-tested and stays off the coverage gate.

import Foundation
import Supabase

final class AppleAuthService: AuthServiceProtocol {

    private let client: SupabaseClient
    private(set) var userId: UUID?

    /// Injects the shared Supabase client built at the composition root.
    init(client: SupabaseClient) {
        self.client = client
    }

    /// Restores an existing Supabase session with no UI; throws when signed out so
    /// the sign-in screen shows. Apple's sheet is only presented interactively.
    @discardableResult
    func restoreSession() async throws -> UUID {
        let session = try await client.auth.session
        let id = session.user.id
        userId = id
        return id
    }

    /// Exchanges a native Apple identity token for a Supabase session. `rawNonce`
    /// must be the un-hashed nonce whose SHA256 was set on the ASAuthorization
    /// request, so Supabase can verify the token's embedded nonce.
    @discardableResult
    func completeSignIn(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> UUID {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: rawNonce)
        )
        let id = session.user.id
        userId = id

        // Apple provides the name only on the FIRST sign-in — capture it then.
        if let fullName {
            let name = [fullName.givenName, fullName.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            if !name.isEmpty {
                try await updateDisplayName(name, for: id)
            }
        }
        return id
    }

    func signOut() async throws {
        try await client.auth.signOut()
        userId = nil
    }

    /// The `profiles` row is auto-created by the `on_auth_user_created` trigger,
    /// so this only UPDATEs — never inserts a duplicate.
    private func updateDisplayName(_ name: String, for userId: UUID) async throws {
        try await client
            .from("profiles")
            .update(["display_name": name])
            .eq("id", value: userId)
            .execute()
    }
}

/// Errors surfaced by the auth layer.
enum AuthError: Error {
    case invalidCredential
    case notConfigured   // Apple provider not yet set up in Supabase / unsupported
    case notSignedIn     // used by the sync closure to skip when signed out
}
