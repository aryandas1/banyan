// BanyanThemeTests.swift
// Covers the two bits of real logic in Theme/BanyanTheme.swift: the
// deterministic avatar color (must not vary across launches — so it must be
// derived from UUID bytes, never the per-process-seeded hashValue) and the
// Color(hex:) parser the token file is built on.

import Testing
import Foundation
import SwiftUI
@testable import Banyan

@Suite("BanyanTheme")
struct BanyanThemeTests {

    // MARK: - avatarColor(for:) determinism

    @Test func avatarColorIsStableForTheSameUUID() {
        let id = UUID(uuidString: "01234567-89AB-CDEF-0123-456789ABCDEF")!
        #expect(BanyanTheme.avatarColor(for: id) == BanyanTheme.avatarColor(for: id))
    }

    @Test func avatarColorMatchesTheByteSumIndex() {
        // Bytes sum to 136 — pins the algorithm to the UUID's raw bytes, which
        // are launch-stable, unlike hashValue.
        let id = UUID(uuid: (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16))
        let expected = BanyanTheme.avatarPalette[136 % BanyanTheme.avatarPalette.count]
        #expect(BanyanTheme.avatarColor(for: id) == expected)
    }

    @Test func avatarColorAlwaysComesFromThePalette() {
        for _ in 0..<100 {
            #expect(BanyanTheme.avatarPalette.contains(BanyanTheme.avatarColor(for: UUID())))
        }
    }

    @Test func avatarColorOfAllZeroUUIDIsTheFirstPaletteEntry() {
        #expect(BanyanTheme.avatarColor(for: .placeholder) == BanyanTheme.avatarPalette[0])
    }

    // MARK: - Color(hex:)

    @Test func hexParsesPureChannels() {
        #expect(Color(hex: "#FF0000") == Color(red: 1, green: 0, blue: 0))
        #expect(Color(hex: "#00FF00") == Color(red: 0, green: 1, blue: 0))
        #expect(Color(hex: "#0000FF") == Color(red: 0, green: 0, blue: 1))
    }

    @Test func hexParsesBlackAndWhite() {
        #expect(Color(hex: "#000000") == Color(red: 0, green: 0, blue: 0))
        #expect(Color(hex: "#FFFFFF") == Color(red: 1, green: 1, blue: 1))
    }

    @Test func hexIgnoresTheLeadingHash() {
        #expect(Color(hex: "1C3FB0") == Color(hex: "#1C3FB0"))
    }

    @Test func hexParsesMixedChannels() {
        // #1C3FB0 → r 0x1C, g 0x3F, b 0xB0
        let expected = Color(red: Double(0x1C) / 255, green: Double(0x3F) / 255, blue: Double(0xB0) / 255)
        #expect(Color(hex: "#1C3FB0") == expected)
    }
}
