// BanyanTheme.swift
// Single source of truth for the app's visual design: colors, avatar palette,
// corner radii, and tap-target sizes (Phase 04 prototype, Direction D hybrid).
// Lives in Theme/ (off the coverage gate) — it is almost entirely declarative
// tokens; the two bits of real logic (avatarColor, Color(hex:)) are unit tested
// in BanyanThemeTests. Font sizes are deliberately absent: text always uses
// semantic styles (.title2, .subheadline, …) so Dynamic Type keeps working.

import SwiftUI

enum BanyanTheme {

    // MARK: - Colors

    enum Color {
        /// Deep brand blue — buttons, active states, focus rings
        static let primary        = SwiftUI.Color(hex: "#1C3FB0")
        /// Light blue tint — selected backgrounds, placeholder fills
        static let primaryTint    = SwiftUI.Color(hex: "#EEF2FF")
        /// Main app background — warm off-white
        static let background     = SwiftUI.Color(hex: "#F7F4F0")
        /// Cards, sheets, white surfaces
        static let surface        = SwiftUI.Color.white
        /// Input field borders (idle)
        static let border         = SwiftUI.Color(hex: "#E0DBD3")
        /// Thin separators
        static let separator      = SwiftUI.Color(hex: "#F0ECE7")
        /// Connector lines between nodes
        static let connector      = SwiftUI.Color(hex: "#C8C2B8")
        /// Primary text — near-black, warm
        static let textPrimary    = SwiftUI.Color(hex: "#1A1814")
        /// Secondary text — warm gray
        static let textSecondary  = SwiftUI.Color(hex: "#6B6058")
        /// Tertiary / captions / muted labels
        static let textTertiary   = SwiftUI.Color(hex: "#A09890")
        /// Tab bar, sheet drag handle
        static let chrome         = SwiftUI.Color(hex: "#E5E0D8")
    }

    // MARK: - Avatar palette

    static let avatarPalette: [SwiftUI.Color] = [
        SwiftUI.Color(hex: "#1C3FB0"),
        SwiftUI.Color(hex: "#7C3AED"),
        SwiftUI.Color(hex: "#9D174D"),
        SwiftUI.Color(hex: "#0D7A5F"),
        SwiftUI.Color(hex: "#1E40AF"),
        SwiftUI.Color(hex: "#065F46"),
        SwiftUI.Color(hex: "#92400E"),
        SwiftUI.Color(hex: "#7C2D12"),
        SwiftUI.Color(hex: "#BE185D"),
        SwiftUI.Color(hex: "#0369A1"),
        SwiftUI.Color(hex: "#6D28D9"),
        SwiftUI.Color(hex: "#C2410C"),
    ]

    /// Returns a deterministic avatar color for a given UUID — the same person
    /// gets the same color across launches. Derived from the UUID's raw bytes,
    /// NOT `hashValue`, which is randomly seeded per process.
    static func avatarColor(for id: UUID) -> SwiftUI.Color {
        let sum = withUnsafeBytes(of: id.uuid) { $0.reduce(0) { $0 &+ Int($1) } }
        return avatarPalette[sum % avatarPalette.count]
    }

    // MARK: - Corner radii

    enum Radius {
        static let node:   CGFloat = 13
        static let button: CGFloat = 13
        static let input:  CGFloat = 12
        static let sheet:  CGFloat = 24
        static let card:   CGFloat = 12
    }

    // MARK: - Tap targets

    enum TapTarget {
        static let minimum: CGFloat = 44
        static let button:  CGFloat = 52
    }
}

// MARK: - Hex color convenience

extension Color {
    /// Builds an sRGB color from a "#RRGGBB" (or "RRGGBB") hex string.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
