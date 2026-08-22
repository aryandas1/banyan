// PartialDateBuilderTests.swift
// The shared year/month/day → PartialDate rule used by every date-capture form.

import Foundation
import Testing
@testable import Banyan

@Suite("PartialDateBuilder")
struct PartialDateBuilderTests {

    @Test func nilWhenNothingEntered() {
        #expect(PartialDateBuilder.from(yearText: "", month: nil, dayText: "") == nil)
    }

    @Test func yearOnly() {
        let date = PartialDateBuilder.from(yearText: "1972", month: nil, dayText: "")
        #expect(date?.year == 1972)
        #expect(date?.month == nil)
        #expect(date?.day == nil)
    }

    @Test func yearlessMonthDayIsPreserved() {
        // A known anniversary day with an unknown year must survive.
        let date = PartialDateBuilder.from(yearText: "", month: 5, dayText: "12")
        #expect(date?.year == nil)
        #expect(date?.month == 5)
        #expect(date?.day == 12)
    }

    @Test func dayDroppedWithoutMonth() {
        let date = PartialDateBuilder.from(yearText: "1972", month: nil, dayText: "12")
        #expect(date?.year == 1972)
        #expect(date?.month == nil)
        #expect(date?.day == nil)
    }

    @Test func invalidMonthRejected() {
        // Month 0 (the "not set" sentinel from the wheels) yields no month/day.
        let date = PartialDateBuilder.from(yearText: "1972", month: 0, dayText: "12")
        #expect(date?.month == nil)
        #expect(date?.day == nil)
    }

    @Test func zeroYearTreatedAsUnknown() {
        #expect(PartialDateBuilder.from(yearText: "0", month: nil, dayText: "") == nil)
    }
}
