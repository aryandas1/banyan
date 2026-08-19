// AppleNonceTests.swift
// The pure nonce helper behind native Sign in with Apple: a known-answer SHA256
// vector (so the value sent to Apple is provably correct) plus the raw-nonce
// generator's length / charset / uniqueness guarantees.

import Foundation
import Testing
@testable import Banyan

@Suite("AppleNonce")
struct AppleNonceTests {

    // MARK: - sha256 (known-answer vectors)

    @Test func sha256MatchesKnownVector() {
        // The canonical SHA-256("abc") test vector, lowercase hex.
        #expect(AppleNonce.sha256("abc")
            == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func sha256OfEmptyStringMatchesKnownVector() {
        #expect(AppleNonce.sha256("")
            == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    @Test func sha256IsDeterministicAnd64HexChars() {
        let hash = AppleNonce.sha256("some-raw-nonce")
        #expect(hash == AppleNonce.sha256("some-raw-nonce"))
        #expect(hash.count == 64)
        #expect(hash.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    // MARK: - randomRawNonce

    @Test func randomNonceHasRequestedLength() {
        #expect(AppleNonce.randomRawNonce(length: 32).count == 32)
        #expect(AppleNonce.randomRawNonce(length: 1).count == 1)
        #expect(AppleNonce.randomRawNonce(length: 200).count == 200)
    }

    @Test func randomNonceUsesOnlyURLSafeCharacters() {
        let allowed = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-.")
        let nonce = AppleNonce.randomRawNonce(length: 128)
        #expect(nonce.allSatisfy { allowed.contains($0) })
    }

    @Test func randomNonceIsNotConstant() {
        // Two draws colliding at 32 chars is astronomically unlikely — a constant
        // generator (the real bug this guards) would fail here.
        #expect(AppleNonce.randomRawNonce() != AppleNonce.randomRawNonce())
    }

    @Test func nonZeroLengthGuardReturnsEmpty() {
        #expect(AppleNonce.randomRawNonce(length: 0).isEmpty)
    }
}
