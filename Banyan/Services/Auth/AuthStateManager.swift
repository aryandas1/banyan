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
    /// `.signedOut` so the sign-in screen shows.
    func initialize() async {
        do {
            let id = try await authService.signIn()
            state = .signedIn(userId: id)
        } catch {
            state = .signedOut
        }
    }

    /// Called from the sign-in button. Transitions to `.signedIn` on success.
    func signIn() async {
        do {
            let id = try await authService.signIn()
            state = .signedIn(userId: id)
        } catch {
            print("[AuthStateManager] Sign-in failed: \(error)")
            state = .signedOut
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
