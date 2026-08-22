// BanyanTextInput.swift
// A ViewModifier that gives text fields a filled, rounded appearance with a
// colored border when focused — larger and easier to see/tap for older users,
// matching the button styling in the add-person flow. Apply via
// .banyanTextInput(focused:). Lives in Theme/ (off the coverage gate) like the
// rest of the appearance layer.

import SwiftUI

struct BanyanTextInput: ViewModifier {
    var isFocused: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(minHeight: 56)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isFocused ? Color.accentColor : Color.clear,
                        lineWidth: 2
                    )
            )
    }
}

extension View {
    /// Applies the Banyan filled text-field style. Pass `focused: true` when the
    /// field is active to show the accent-color border.
    func banyanTextInput(focused: Bool = false) -> some View {
        modifier(BanyanTextInput(isFocused: focused))
    }
}
