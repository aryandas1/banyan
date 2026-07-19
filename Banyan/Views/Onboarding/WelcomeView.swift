// WelcomeView.swift
// First screen on a fresh install. Wraps the onboarding flow in a NavigationStack
// so it can push the name-entry step.

import SwiftUI

struct WelcomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "tree.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)

                Text("Your family, all in one place")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Build your family tree and share it with the people who matter.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)

                Spacer()

                NavigationLink {
                    NameEntryView()
                } label: {
                    Text("Get started")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
        }
    }
}

#Preview("Welcome") {
    WelcomeView()
}
