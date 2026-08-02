// AppleAuthService.swift
// Production auth: Sign in with Apple, verified by Supabase. The full UI and
// delegate flow are built; the Supabase exchange is stubbed until an Apple
// Developer account is available.
//
// TODO (requires Apple Developer account):
//   1. Register a Service ID in the Apple Developer portal.
//   2. Add "Sign in with Apple" capability in Xcode → Signing & Capabilities.
//   3. Configure the Apple provider in Supabase → Authentication → Providers →
//      Apple (paste Service ID + private key).
//   4. Uncomment the `signInWithIdToken` block below and remove the
//      `AuthError.notConfigured` resume. No other changes needed.
//
// Account migration (record for when creds land): prefer LINKING the anonymous
// identity to Apple (Supabase can upgrade an anon user, preserving the uid and
// already-synced data) over a fresh signInWithIdToken, which mints a new uid
// and orphans the tree under RLS (the 42501 trap). No migration code here —
// Apple is stubbed — but the seam is ready.
//
// Lives in Networking (not Services) alongside SupabaseRemoteStore: it wraps the
// live Supabase client and Apple's UI, so it can't be unit-tested and stays off
// the `make coverage` gate.

import Foundation
import AuthenticationServices
import Supabase
import UIKit

final class AppleAuthService: NSObject, AuthServiceProtocol {

    private let client: SupabaseClient
    private(set) var userId: UUID?
    private var continuation: CheckedContinuation<UUID, Error>?

    /// Injects the shared Supabase client built at the composition root.
    init(client: SupabaseClient) {
        self.client = client
    }

    func signIn() async throws -> UUID {
        try await withCheckedThrowingContinuation { continuation in
            // A newer sign-in supersedes any pending one (don't leak the continuation).
            self.continuation?.resume(throwing: AuthError.cancelled)
            self.continuation = continuation

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func signOut() async throws {
        try await client.auth.signOut()
        userId = nil
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleAuthService: ASAuthorizationControllerDelegate {

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let _ = String(data: tokenData, encoding: .utf8)
        else {
            continuation?.resume(throwing: AuthError.invalidCredential)
            continuation = nil
            return
        }

        Task {
            // TODO: uncomment when the Apple provider is configured in Supabase.
            // let session = try await client.auth.signInWithIdToken(
            //     credentials: .init(provider: .apple, idToken: token)
            // )
            // let id = session.user.id
            // self.userId = id
            //
            // // Apple provides the name only on first sign-in — capture it then.
            // let name = [
            //     credential.fullName?.givenName,
            //     credential.fullName?.familyName
            // ].compactMap { $0 }.joined(separator: " ")
            // if !name.isEmpty {
            //     try await updateDisplayName(name, for: id)
            // }
            //
            // self.continuation?.resume(returning: id)
            // self.continuation = nil

            // Until the Apple provider is configured, fail gracefully instead of
            // crashing — keeps the app testable and doesn't leak the continuation.
            self.continuation?.resume(throwing: AuthError.notConfigured)
            self.continuation = nil
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleAuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first ?? ASPresentationAnchor()
    }
}

// MARK: - Helpers

extension AppleAuthService {
    // The `profiles` row is auto-created by the `on_auth_user_created` trigger,
    // so this only UPDATEs — never insert a duplicate. Uses the injected client.
    // Referenced by the stubbed sign-in block above; wired in when Apple is live.
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
    case notConfigured   // Apple provider not yet set up in Supabase
    case cancelled       // a newer sign-in superseded a pending one
    case notSignedIn     // used by the sync closure to skip when signed out
}
