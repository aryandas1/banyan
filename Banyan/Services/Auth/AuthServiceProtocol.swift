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

    /// Signs the user in (restoring an existing session if one exists) and
    /// returns the authenticated user id.
    @discardableResult
    func signIn() async throws -> UUID

    /// Signs the user out and clears the local session.
    func signOut() async throws
}
