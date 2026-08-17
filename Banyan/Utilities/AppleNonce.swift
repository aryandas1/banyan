// AppleNonce.swift
// Nonce generation for native Sign in with Apple. Apple + Supabase want a nonce
// to bind the identity token to this specific sign-in request (replay safety):
// the SHA256 hash is set on the ASAuthorization request, and the RAW value is
// handed to Supabase to verify against the token's embedded nonce. Pure and
// unit-tested (Utilities is on the coverage gate); the SwiftUI button and the
// AppleAuthService exchange are thin callers.

import Foundation
import CryptoKit

enum AppleNonce {
    /// The unreserved characters a raw nonce is drawn from (URL/JWT-safe, 64 of
    /// them so a single random byte < 64 maps to one with no modulo bias).
    private static let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-.")

    /// A cryptographically-random raw nonce of `length` characters. Kept by the
    /// caller and passed to Supabase; only its `sha256` goes to Apple.
    static func randomRawNonce(length: Int = 32) -> String {
        guard length > 0 else { return "" }
        var result = ""
        result.reserveCapacity(length)
        while result.count < length {
            for byte in randomBytes(16) where result.count < length {
                // Reject bytes ≥ charset.count so every character is equally likely.
                if Int(byte) < charset.count {
                    result.append(charset[Int(byte)])
                }
            }
        }
        return result
    }

    /// Lowercase-hex SHA256 of `input` — the value set on the request's `nonce`.
    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    /// A batch of random bytes. `SystemRandomNumberGenerator` is a CSPRNG.
    private static func randomBytes(_ count: Int) -> [UInt8] {
        var generator = SystemRandomNumberGenerator()
        return (0..<count).map { _ in UInt8.random(in: 0...255, using: &generator) }
    }
}
