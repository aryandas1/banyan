// AuthServiceProtocol.swift
// The auth seam: AnonymousAuthService (dev) and AppleAuthService (prod) are
// interchangeable behind this. AuthStateManager and any ViewModels depend on
// this protocol, never the concrete types.

import Foundation

/// Abstracts the authentication backend so the anonymous and Apple
/// implementations are interchangeable.
protocol AuthServiceProtocol: AnyObject {
    /// The current user's UUID, or nil if not signed in.
    var userId: UUID? { get }

    /// Silently restores an existing session and returns the user id, WITHOUT any
    /// UI — throws when there is no session so the sign-in screen shows. Called at
    /// cold launch. (The anonymous dev service restores-or-creates a session here;
    /// Apple only restores, since presenting its sheet on every launch is wrong.)
    @discardableResult
    func restoreSession() async throws -> UUID

    /// Completes an interactive Sign in with Apple from a native credential: the
    /// identity token and the raw nonce whose SHA256 was set on the request. The
    /// default throws — services that don't support Apple (the anonymous dev
    /// service, test stubs) never call it.
    @discardableResult
    func completeSignIn(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> UUID

    /// Signs the user out and clears the local session.
    func signOut() async throws
}

extension AuthServiceProtocol {
    /// Default for non-Apple services: interactive Apple sign-in isn't supported.
    func completeSignIn(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> UUID {
        throw AuthError.notConfigured
    }
}
