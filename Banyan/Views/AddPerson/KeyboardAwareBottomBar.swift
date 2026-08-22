// KeyboardAwareBottomBar.swift
// Pins a bottom bar (the add-flow's primary Continue button) a small gap above the
// keyboard, driven by an OBSERVED keyboard height rather than SwiftUI's automatic
// keyboard avoidance — which proved intermittent on device (the button sometimes
// stayed hidden behind the keyboard). When the keyboard is down the bar rests at the
// bottom above the home indicator as usual.

import SwiftUI
import Combine
import UIKit

private struct KeyboardAwareBottomBar<Bar: View>: ViewModifier {
    let bar: Bar
    @State private var keyboardHeight: CGFloat = 0

    /// The keyboard's on-screen height as it shows (0 as it hides).
    private var keyboardHeightChanges: AnyPublisher<CGFloat, Never> {
        let willShow = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { ($0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height }
        let willHide = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in CGFloat.zero }
        return willShow.merge(with: willHide).eraseToAnyPublisher()
    }

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bar
                    // Offset (not padding) lifts the button above the keyboard WITHOUT
                    // reflowing the content — the inset only ever reserves the bar's own
                    // height, so the screen's title/fields stay put. When the keyboard
                    // is down the offset is 0 and the bar rests above the home indicator.
                    .offset(y: -keyboardHeight)
                    .animation(.easeOut(duration: 0.25), value: keyboardHeight)
            }
            // Disable the flaky automatic avoidance — the observed height does the work.
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onReceive(keyboardHeightChanges) { keyboardHeight = $0 }
    }
}

extension View {
    /// Pins `bar` a fixed gap above the keyboard (observed height, not the flaky
    /// automatic avoidance), and at the bottom when the keyboard is dismissed.
    func keyboardAwareBottomBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        modifier(KeyboardAwareBottomBar(bar: bar()))
    }
}
