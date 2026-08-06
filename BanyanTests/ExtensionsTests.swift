// ExtensionsTests.swift
// Covers the small shared conveniences in Utilities/Extensions.swift.

import Testing
import Foundation
@testable import Banyan

@Suite("Extensions")
struct ExtensionsTests {

    // MARK: - Collection[safe:]

    @Test func safeSubscriptReturnsElementInRange() {
        #expect([10, 20, 30][safe: 1] == 20)
    }

    @Test func safeSubscriptReturnsNilOutOfRange() {
        let a = [10, 20, 30]
        #expect(a[safe: 3] == nil)
        #expect(a[safe: -1] == nil)
    }

    @Test func safeSubscriptOnEmptyCollectionReturnsNil() {
        #expect([Int]()[safe: 0] == nil)
    }

    // MARK: - String.nonEmptyOrNil

    @Test func nonEmptyOrNilReturnsNilForEmpty() {
        #expect("".nonEmptyOrNil == nil)
    }

    @Test func nonEmptyOrNilReturnsSelfForNonEmpty() {
        #expect("hi".nonEmptyOrNil == "hi")
    }

    // MARK: - UUID.placeholder

    @Test func uuidPlaceholderIsAllZero() {
        #expect(UUID.placeholder == UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)))
    }
}
