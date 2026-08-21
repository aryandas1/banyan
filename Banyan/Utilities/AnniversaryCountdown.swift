// AnniversaryCountdown.swift
// Turns a PartialDate's month + day into "how long until the next anniversary" —
// used on the person sheet for birthdays (living) and shraddha / death anniversaries
// (deceased). Pure and calendar-injectable so it stays on the coverage gate and is
// fully unit-testable; the year is ignored (an anniversary recurs every year).

import Foundation

enum AnniversaryCountdown {

    /// Whole days from `now` until the next occurrence of `date`'s month/day
    /// (0 when that day is today). Nil when the month or day is unknown — a
    /// year-only date has no recurring anniversary to count toward.
    static func daysUntilNext(_ date: PartialDate, now: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard let month = date.month, let day = date.day,
              (1...12).contains(month), (1...31).contains(day) else { return nil }

        let today = calendar.startOfDay(for: now)
        let todayMD = calendar.dateComponents([.month, .day], from: today)
        if todayMD.month == month && todayMD.day == day { return 0 }

        var target = DateComponents()
        target.month = month
        target.day = day
        guard let next = calendar.nextDate(after: today, matching: target, matchingPolicy: .nextTime) else {
            return nil
        }
        return calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: next)).day
    }

    /// A friendly lower-cased phrase for the countdown, e.g. "today", "tomorrow",
    /// "in 5 days", "in 3 weeks", "in 2 months". Nil when there's no month/day.
    /// Callers compose it, e.g. "Birthday \(phrase)" → "Birthday in 5 days".
    static func phrase(for date: PartialDate, now: Date = Date(), calendar: Calendar = .current) -> String? {
        guard let days = daysUntilNext(date, now: now, calendar: calendar) else { return nil }
        switch days {
        case 0:
            return "today"
        case 1:
            return "tomorrow"
        case 2...13:
            return "in \(days) days"
        case 14...59:
            let weeks = Int((Double(days) / 7).rounded())
            return "in \(weeks) weeks"
        default:
            let months = Int((Double(days) / 30).rounded())
            return "in \(months) month\(months == 1 ? "" : "s")"
        }
    }
}
