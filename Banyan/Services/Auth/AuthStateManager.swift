// AuthStateManager.swift
// Drives root navigation from auth state. Injected into the environment at
// startup. Depends only on AuthServiceProtocol, so the same manager works with
// the anonymous dev service or the real Apple service.

import Foundation
import Observation

@MainActor
@Observable
final class AuthStateManager {

    enum State {
        case loading
        case signedOut
        case signedIn(userId: UUID)
    }

    private(set) var state: State = .loading
    private let authService: any AuthServiceProtocol

    init(authService: any AuthServiceProtocol) {
        self.authService = authService
    }

    /// Called once at startup: restores an existing session, or lands on
    /// `.signedOut` so the sign-in screen shows. Never presents UI.
    func initialize() async {
        do {
            let id = try await authService.restoreSession()
            state = .signedIn(userId: id)
        } catch {
            state = .signedOut
        }
    }

    /// Called from the Sign in with Apple button's completion with the native
    /// credential. Exchanges it for a session and transitions to `.signedIn` on
    /// success, else falls back to `.signedOut`. Returns whether it succeeded, so
    /// the sign-in screen can show a message on a genuine failure.
    @discardableResult
    func completeAppleSignIn(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async -> Bool {
        do {
            let id = try await authService.completeSignIn(idToken: idToken, rawNonce: rawNonce, fullName: fullName)
            state = .signedIn(userId: id)
            return true
        } catch {
            print("[AuthStateManager] Apple sign-in failed: \(error)")
            state = .signedOut
            return false
        }
    }

    /// Signs out and returns to `.signedOut` regardless of backend errors.
    func signOut() async {
        do {
            try await authService.signOut()
        } catch {
            print("[AuthStateManager] Sign-out failed: \(error)")
        }
        state = .signedOut
    }

    /// The signed-in user id, or nil when loading or signed out.
    var userId: UUID? {
        if case .signedIn(let id) = state { return id }
        return nil
    }
}
