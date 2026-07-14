// PartialDateTests.swift
// Rendering of incomplete dates.

import Testing
@testable import Banyan

@Suite("PartialDate")
struct PartialDateTests {
    @Test func yearOnly() { #expect(PartialDate(year: 1945).displayString == "1945") }
    @Test func yearAndMonth() { #expect(PartialDate(year: 1945, month: 3).displayString == "Mar 1945") }
    @Test func allNilIsUnknown() { #expect(PartialDate().displayString == "Unknown") }
    @Test func estimatedPrefixesTilde() { #expect(PartialDate(year: 1945, isEstimated: true).displayString == "~1945") }
    @Test func fullDate() { #expect(PartialDate(year: 1945, month: 3, day: 12).displayString == "12 Mar 1945") }
}
