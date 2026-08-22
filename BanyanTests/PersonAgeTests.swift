// PersonAgeTests.swift
// Covers whole-years age math: living (to now), deceased (to a death date), the
// birthday-not-yet-passed adjustment, year-only fallback, and the guards for
// unknown/negative values. Fixed UTC Gregorian calendar + pinned `now`.

import Testing
import Foundation
@testable import Banyan

@Suite("PersonAge")
struct PersonAgeTests {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = 12
        return calendar.date(from: c)!
    }

    @Test func livingAgeAfterBirthdayThisYear() {
        // Born 29 Nov 1996; today 21 Aug 2026 — birthday not yet passed this year → 29.
        let birth = PartialDate(year: 1996, month: 11, day: 29)
        let age = PersonAge.years(from: birth, to: nil, now: date(2026, 8, 21), calendar: calendar)
        #expect(age == 29)
    }

    @Test func livingAgeOnceBirthdayHasPassed() {
        // Same birth; today 1 Dec 2026 — birthday already passed → 30.
        let birth = PartialDate(year: 1996, month: 11, day: 29)
        let age = PersonAge.years(from: birth, to: nil, now: date(2026, 12, 1), calendar: calendar)
        #expect(age == 30)
    }

    @Test func ageAtDeathUsesMonthDay() {
        // Born 3 Nov 1940, died 16 Apr 2026 — birthday not reached in 2026 → 85.
        let birth = PartialDate(year: 1940, month: 11, day: 3)
        let death = PartialDate(year: 2026, month: 4, day: 16)
        #expect(PersonAge.years(from: birth, to: death, calendar: calendar) == 85)
    }

    @Test func yearOnlyFallsBackToYearDifference() {
        let birth = PartialDate(year: 1940)
        let death = PartialDate(year: 2026)
        #expect(PersonAge.years(from: birth, to: death, calendar: calendar) == 86)
    }

    @Test func unknownBirthYearIsNil() {
        #expect(PersonAge.years(from: PartialDate(month: 4, day: 3), to: nil, now: date(2026, 8, 21), calendar: calendar) == nil)
    }

    @Test func deceasedWithoutDeathYearIsNil() {
        let birth = PartialDate(year: 1940)
        #expect(PersonAge.years(from: birth, to: PartialDate(), calendar: calendar) == nil)
    }
}
