// SignInView.swift
// Sign-in screen, designed for older users: large app name, one line of
// description, a single clear action, no fine print beyond a privacy reassurance.
//
// The real Sign in with Apple button owns the Apple sheet and the nonce; its
// completion hands the identity token to AuthStateManager, which exchanges it
// with Supabase. Sign in with Apple works on the iOS Simulator (with an Apple ID
// signed into it), so this is exercised for real there.

import SwiftUI
import AuthenticationServices

struct SignInView: View {

    @Environment(AuthStateManager.self) private var authState
    // Scales the hero icon with Dynamic Type (accessibility goal for older users).
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 64
    // The raw nonce for the in-flight request; its SHA256 goes to Apple, the raw
    // value to Supabase. Held between the request and completion closures.
    @State private var currentNonce: String?

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "tree.fill")
                    .font(.system(size: iconSize))
                    .foregroundStyle(.green)

                Text("Banyan")
                    .font(.largeTitle.bold())

                Text("Your family tree, together.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            SignInWithAppleButton(.signIn) { request in
                let raw = AppleNonce.randomRawNonce()
                currentNonce = raw
                request.requestedScopes = [.fullName, .email]
                request.nonce = AppleNonce.sha256(raw)
            } onCompletion: { result in
                handleCompletion(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)

            Text("Your tree is private and only shared with people you invite.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
                .frame(height: 40)
        }
    }

    /// Extracts the identity token + raw nonce from the Apple credential and hands
    /// them to AuthStateManager for the Supabase exchange. A cancel / missing token
    /// is a no-op — the user simply stays on this screen.
    private func handleCompletion(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              let rawNonce = currentNonce
        else { return }

        let fullName = credential.fullName
        Task { await authState.completeAppleSignIn(idToken: idToken, rawNonce: rawNonce, fullName: fullName) }
    }
}

#Preview {
    SignInView()
        .environment(AuthStateManager(authService: PreviewAuthService()))
}

/// A no-op auth service so the preview renders without a Supabase client.
private final class PreviewAuthService: AuthServiceProtocol {
    var userId: UUID?
    func restoreSession() async throws -> UUID { UUID() }
    func signOut() async throws {}
}
