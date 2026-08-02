// SignInView.swift
// Sign-in screen, designed for older users: large app name, one line of
// description, a single clear action, no fine print beyond a privacy reassurance.
//
// Dev scaffold uses a plain "Get started" button that drives the anonymous
// service directly — SignInWithAppleButton presents the real Apple sheet, which
// can't complete in the simulator. Swap in the Apple button (kept below in a
// comment) once AppleAuthService is wired to real credentials.

import SwiftUI

struct SignInView: View {

    @Environment(AuthStateManager.self) private var authState

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "tree.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)

                Text("Banyan")
                    .font(.largeTitle.bold())

                Text("Your family tree, together.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Dev (AnonymousAuthService): plain button, no Apple sheet.
            Button {
                Task { await authState.signIn() }
            } label: {
                Text("Get started")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)

            // Production (AppleAuthService): swap the button above for this once
            // Apple credentials are configured. The delegate handles the result;
            // AuthStateManager observes the session change.
            //
            // SignInWithAppleButton(.signIn) { request in
            //     request.requestedScopes = [.fullName, .email]
            // } onCompletion: { _ in
            //     Task { await authState.signIn() }
            // }
            // .signInWithAppleButtonStyle(.black)
            // .frame(height: 56)
            // .padding(.horizontal, 32)

            Text("Your tree is private and only shared with people you invite.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
                .frame(height: 40)
        }
    }
}

#Preview {
    SignInView()
        .environment(AuthStateManager(authService: PreviewAuthService()))
}

/// A no-op auth service so the preview renders without a Supabase client.
private final class PreviewAuthService: AuthServiceProtocol {
    var userId: UUID?
    func signIn() async throws -> UUID { UUID() }
    func signOut() async throws {}
}
