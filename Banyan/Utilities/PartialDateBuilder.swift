// PartialDateBuilder.swift
// Builds a PartialDate from raw form fields (a year string, an optional month, and a
// day string), applying the one rule shared across every date-capture form: the year
// is NOT required, and a day is only kept alongside a valid month. Pure and
// SwiftData-free so it stays fully unit-testable and reusable — birth, death, and
// marriage capture all funnel through it.

import Foundation

enum PartialDateBuilder {

    /// A PartialDate from a year field, an optional month, and a day field.
    /// A day is only kept alongside a valid month (matching PartialDate's own rule).
    /// Returns nil only when neither a year nor a valid month is known — so a
    /// year-less anniversary ("12 May", year unknown) is preserved, not dropped.
    static func from(yearText: String, month: Int?, dayText: String) -> PartialDate? {
        let year = Int(yearText).flatMap { $0 > 0 ? $0 : nil }
        let validMonth = month.flatMap { (1...12).contains($0) ? $0 : nil }
        let day = validMonth == nil ? nil : Int(dayText).flatMap { (1...31).contains($0) ? $0 : nil }
        guard year != nil || validMonth != nil else { return nil }
        return PartialDate(year: year, month: validMonth, day: day)
    }
}
