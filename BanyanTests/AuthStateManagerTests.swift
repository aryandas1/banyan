// AuthStateManagerTests.swift
// State transitions for the root auth manager. The suite is @MainActor because
// AuthStateManager is. A MockAuthService stands in for the Supabase-backed
// implementations, which can't be unit-tested.

import Foundation
import Testing
@testable import Banyan

@MainActor
@Suite("AuthStateManager")
struct AuthStateManagerTests {

    // MARK: - Test double

    /// Configurable stand-in for AuthServiceProtocol. `signIn` either returns a
    /// fixed id or throws, per the test's setup.
    final class MockAuthService: AuthServiceProtocol {
        var userId: UUID?
        var signInResult: Result<UUID, Error>
        private(set) var signOutCalled = false

        init(signInResult: Result<UUID, Error>) {
            self.signInResult = signInResult
        }

        func signIn() async throws -> UUID {
            let id = try signInResult.get()
            userId = id
            return id
        }

        func signOut() async throws {
            signOutCalled = true
            userId = nil
        }
    }

    struct MockError: Error {}

    // MARK: - Helpers

    /// True when the state is `.signedIn` carrying the expected id.
    private func isSignedIn(_ state: AuthStateManager.State, as id: UUID) -> Bool {
        if case .signedIn(let actual) = state { return actual == id }
        return false
    }

    private func isSignedOut(_ state: AuthStateManager.State) -> Bool {
        if case .signedOut = state { return true }
        return false
    }

    // MARK: - initialize()

    @Test func initializeSignsInWhenServiceSucceeds() async {
        // Given a service that returns a user id
        let id = UUID()
        let manager = AuthStateManager(authService: MockAuthService(signInResult: .success(id)))

        // When initializing
        await manager.initialize()

        // Then the state carries that id and userId matches
        #expect(isSignedIn(manager.state, as: id))
        #expect(manager.userId == id)
    }

    @Test func initializeSignsOutWhenServiceThrows() async {
        // Given a service that fails to sign in
        let manager = AuthStateManager(authService: MockAuthService(signInResult: .failure(MockError())))

        // When initializing
        await manager.initialize()

        // Then the state is signed out and userId is nil
        #expect(isSignedOut(manager.state))
        #expect(manager.userId == nil)
    }

    // MARK: - signIn()

    @Test func signInSetsSignedInStateOnSuccess() async {
        // Given a service that returns a user id
        let id = UUID()
        let manager = AuthStateManager(authService: MockAuthService(signInResult: .success(id)))

        // When signing in from the button
        await manager.signIn()

        // Then the state carries that id
        #expect(isSignedIn(manager.state, as: id))
    }

    @Test func signInFallsBackToSignedOutOnFailure() async {
        // Given a service that fails
        let manager = AuthStateManager(authService: MockAuthService(signInResult: .failure(MockError())))

        // When signing in
        await manager.signIn()

        // Then the state is signed out
        #expect(isSignedOut(manager.state))
    }

    // MARK: - signOut()

    @Test func signOutTransitionsToSignedOut() async {
        // Given a signed-in manager
        let id = UUID()
        let mock = MockAuthService(signInResult: .success(id))
        let manager = AuthStateManager(authService: mock)
        await manager.initialize()
        #expect(isSignedIn(manager.state, as: id))   // precondition

        // When signing out
        await manager.signOut()

        // Then the backend was told and the state is signed out
        #expect(mock.signOutCalled)
        #expect(isSignedOut(manager.state))
        #expect(manager.userId == nil)
    }

    // MARK: - userId

    @Test func userIdIsNilWhileLoading() {
        // Given a fresh manager (state == .loading)
        let manager = AuthStateManager(authService: MockAuthService(signInResult: .success(UUID())))

        // Then userId is nil before any sign-in
        #expect(manager.userId == nil)
    }
}
