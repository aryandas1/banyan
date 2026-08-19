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
    // Set when a genuine sign-in attempt fails (not a user cancel), so we can show
    // a calm retry message instead of the button silently doing nothing.
    @State private var signInFailed = false

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
                signInFailed = false
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

            if signInFailed {
                Text("Couldn't sign in — please try again.")
                    .font(.footnote)
                    .foregroundStyle(BanyanTheme.Color.warning)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

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
    /// them to AuthStateManager for the Supabase exchange. A user cancel stays
    /// silent; a genuine failure (Apple error, missing token, or a failed exchange)
    /// shows the retry message rather than leaving the button feeling dead.
    private func handleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            if !isCancellation(error) { signInFailed = true }

        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let rawNonce = currentNonce
            else {
                signInFailed = true
                return
            }
            let fullName = credential.fullName
            Task { @MainActor in
                let ok = await authState.completeAppleSignIn(idToken: idToken, rawNonce: rawNonce, fullName: fullName)
                if !ok { signInFailed = true }
            }
        }
    }

    /// True when the Apple sheet failure is just the user backing out — no error UI.
    private func isCancellation(_ error: Error) -> Bool {
        (error as? ASAuthorizationError)?.code == .canceled
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
