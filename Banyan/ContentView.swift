// ContentView.swift
// Root gate: first launch shows onboarding; afterwards, the main tab shell.

import SwiftUI

struct ContentView: View {
    @AppStorage("ownerPersonId") private var ownerPersonIdString: String = ""

    var body: some View {
        if ownerPersonIdString.isEmpty {
            WelcomeView()
        } else {
            MainTabView()
        }
    }
}

#Preview("Onboarding") {
    ContentView()
}
