// BanyanButtonStyle.swift
// Shared filled-button styles so every primary/secondary action dims on press —
// older users rely on that "it noticed my tap" feedback. Lives in Theme/ (off gate).

import SwiftUI

/// Deep-blue filled button (primary actions: Continue, See their family).
/// Reads `isEnabled` so a `.disabled()` button shows the muted tertiary fill —
/// callers just add `.disabled(…)` instead of hand-rolling the disabled color.
struct PrimaryFilledButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: BanyanTheme.TapTarget.button)
            .background(isEnabled ? BanyanTheme.Color.primary : BanyanTheme.Color.textTertiary)
            .clipShape(.rect(cornerRadius: BanyanTheme.Radius.button))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Inverted primary: white fill with a blue label. The full-bleed brand-blue
/// Welcome screen's "Get started" sits on this.
struct InvertedFilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(BanyanTheme.Color.primary)
            .frame(maxWidth: .infinity, minHeight: BanyanTheme.TapTarget.button)
            .background(.white)
            .clipShape(.rect(cornerRadius: BanyanTheme.Radius.button))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Tinted secondary button (the "Add …" rows on the person sheet).
struct TintFilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline).fontWeight(.semibold)
            .foregroundStyle(BanyanTheme.Color.primary)
            .frame(maxWidth: .infinity, minHeight: BanyanTheme.TapTarget.button)
            .background(BanyanTheme.Color.primaryTint)
            .clipShape(.rect(cornerRadius: BanyanTheme.Radius.button))
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Minimal press feedback for buttons that own their custom label chrome (the
/// dashed placeholder node) — just dims and springs, adds no fill of its own.
struct DimOnPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
