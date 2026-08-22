// PersonAge.swift
// Whole-years age from a birth PartialDate to a reference — a death date for the
// deceased, or today for the living. Uses month/day when both sides have them for an
// exact figure, else falls back to the year difference. Pure + calendar-injectable
// so it stays on the coverage gate and is fully unit-testable.

import Foundation

enum PersonAge {

    /// Whole years from `birth` to `end` (pass `nil` for "now" — a living person).
    /// Returns nil when the birth year is unknown, when a supplied `end` has no year,
    /// or when the result would be negative. When month/day are known on both sides,
    /// a year is subtracted if the birthday hasn't occurred yet by the end date.
    static func years(
        from birth: PartialDate?,
        to end: PartialDate?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int? {
        guard let birthYear = birth?.year else { return nil }

        let endYear: Int
        let endMonth: Int?
        let endDay: Int?
        if let end {
            guard let year = end.year else { return nil }
            endYear = year; endMonth = end.month; endDay = end.day
        } else {
            let c = calendar.dateComponents([.year, .month, .day], from: now)
            guard let year = c.year else { return nil }
            endYear = year; endMonth = c.month; endDay = c.day
        }

        var age = endYear - birthYear
        // Only adjust when we can actually compare the day-in-year on both sides.
        if let birthMonth = birth?.month, let endMonth {
            if endMonth < birthMonth {
                age -= 1
            } else if endMonth == birthMonth, let birthDay = birth?.day, let endDay, endDay < birthDay {
                age -= 1
            }
        }
        return age >= 0 ? age : nil
    }
}
