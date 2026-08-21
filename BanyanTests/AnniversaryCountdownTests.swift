// AnniversaryCountdownTests.swift
// Covers the pure birthday / shraddha countdown: day math, phrase buckets, the
// "no month/day → no countdown" guard, and roll-over to next year. Uses a fixed
// UTC Gregorian calendar and pinned `now` values so every assertion is deterministic.

import Testing
import Foundation
@testable import Banyan

@Suite("AnniversaryCountdown")
struct AnniversaryCountdownTests {

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

    @Test func yearOnlyHasNoCountdown() {
        let pd = PartialDate(year: 1945)
        #expect(AnniversaryCountdown.daysUntilNext(pd, now: date(2026, 3, 1), calendar: calendar) == nil)
        #expect(AnniversaryCountdown.phrase(for: pd, now: date(2026, 3, 1), calendar: calendar) == nil)
    }

    @Test func monthWithoutDayHasNoCountdown() {
        let pd = PartialDate(year: 1945, month: 3)
        #expect(AnniversaryCountdown.daysUntilNext(pd, now: date(2026, 3, 1), calendar: calendar) == nil)
    }

    @Test func sameDayIsToday() {
        let pd = PartialDate(year: 1945, month: 3, day: 12)
        #expect(AnniversaryCountdown.daysUntilNext(pd, now: date(2026, 3, 12), calendar: calendar) == 0)
        #expect(AnniversaryCountdown.phrase(for: pd, now: date(2026, 3, 12), calendar: calendar) == "today")
    }

    @Test func oneDayAheadIsTomorrow() {
        let pd = PartialDate(year: 1945, month: 3, day: 12)
        #expect(AnniversaryCountdown.phrase(for: pd, now: date(2026, 3, 11), calendar: calendar) == "tomorrow")
    }

    @Test func fewDaysAheadCountsDays() {
        let pd = PartialDate(year: 1945, month: 3, day: 12)
        #expect(AnniversaryCountdown.daysUntilNext(pd, now: date(2026, 3, 7), calendar: calendar) == 5)
        #expect(AnniversaryCountdown.phrase(for: pd, now: date(2026, 3, 7), calendar: calendar) == "in 5 days")
    }

    @Test func weeksBucketRounds() {
        let pd = PartialDate(year: 1945, month: 3, day: 22)
        #expect(AnniversaryCountdown.daysUntilNext(pd, now: date(2026, 3, 1), calendar: calendar) == 21)
        #expect(AnniversaryCountdown.phrase(for: pd, now: date(2026, 3, 1), calendar: calendar) == "in 3 weeks")
    }

    @Test func pastThisYearRollsToNextYear() {
        // now is after this year's occurrence, so it counts to next year's.
        let pd = PartialDate(year: 1945, month: 3, day: 12)
        #expect(AnniversaryCountdown.daysUntilNext(pd, now: date(2026, 6, 1), calendar: calendar) == 284)
        #expect(AnniversaryCountdown.phrase(for: pd, now: date(2026, 6, 1), calendar: calendar) == "in 9 months")
    }
}
