// WelcomeView.swift
// First screen on a fresh install: full-bleed brand blue with a white
// call-to-action. Wraps the onboarding flow in a NavigationStack so it can
// push the name-entry step.

import SwiftUI

struct WelcomeView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                BanyanTheme.Color.primary.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    RoundedRectangle(cornerRadius: 20)
                        .fill(.white.opacity(0.16))
                        .frame(width: 76, height: 76)
                        .overlay(
                            Image(systemName: "tree.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.white)
                        )
                        .accessibilityHidden(true)
                        .padding(.bottom, 24)

                    Text("Your family,\nall in one place")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.bottom, 12)

                    Text("Build your family tree and share it with the people who matter.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.76))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 36)

                    NavigationLink {
                        NameEntryView()
                    } label: {
                        Text("Get started")
                    }
                    .buttonStyle(InvertedFilledButtonStyle())

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

#Preview("Welcome") {
    WelcomeView()
}
