// ContentView.swift
// Root gate. First on auth: loading shows a spinner while the session restores,
// signed-out shows sign-in. Once signed in, the existing onboarding gate applies:
// empty ownerPersonId ⇒ WelcomeView, otherwise the main tab shell.

import SwiftUI

struct ContentView: View {
    @Environment(AuthStateManager.self) private var authState
    @AppStorage("ownerPersonId") private var ownerPersonIdString: String = ""

    var body: some View {
        switch authState.state {
        case .loading:
            ProgressView()
                .task { await authState.initialize() }

        case .signedOut:
            SignInView()

        case .signedIn:
            if ownerPersonIdString.isEmpty {
                WelcomeView()
            } else {
                MainTabView()
            }
        }
    }
}
