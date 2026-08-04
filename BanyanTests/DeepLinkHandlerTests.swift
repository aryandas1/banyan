// DeepLinkHandlerTests.swift
// Pure parsing of banyan://invite links — no mocks, just URL in, DeepLink out.

import Foundation
import Testing
@testable import Banyan

@Suite("DeepLinkHandler")
struct DeepLinkHandlerTests {

    @Test func parsesValidInviteLink() {
        // Given a well-formed invite URL
        let url = URL(string: "banyan://invite?token=abc123")!

        // When parsed
        let link = DeepLinkHandler.parse(url)

        // Then it yields the token
        #expect(link == .invite(token: "abc123"))
    }

    @Test func returnsNilWhenTokenMissing() {
        let url = URL(string: "banyan://invite")!
        #expect(DeepLinkHandler.parse(url) == nil)
    }

    @Test func returnsNilForEmptyToken() {
        let url = URL(string: "banyan://invite?token=")!
        #expect(DeepLinkHandler.parse(url) == nil)
    }

    @Test func returnsNilForWrongScheme() {
        let url = URL(string: "https://invite?token=abc")!
        #expect(DeepLinkHandler.parse(url) == nil)
    }

    @Test func returnsNilForWrongHost() {
        let url = URL(string: "banyan://profile?token=abc")!
        #expect(DeepLinkHandler.parse(url) == nil)
    }

    @Test func picksTokenAmongMultipleQueryItems() {
        // Given extra query items alongside the token
        let url = URL(string: "banyan://invite?ref=sms&token=xyz789")!

        // Then the token is still extracted
        #expect(DeepLinkHandler.parse(url) == .invite(token: "xyz789"))
    }
}
