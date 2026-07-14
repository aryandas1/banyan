// PartialDate.swift
// A date where any component may be unknown — genealogical records are rarely complete.

import Foundation

/// A calendar date with optionally missing components, plus a flag for estimated dates.
/// Stored inside SwiftData models as a `Codable` value, so it must not depend on SwiftData.
struct PartialDate: Codable, Hashable {
    var year: Int?
    var month: Int?
    var day: Int?
    var isEstimated: Bool

    init(year: Int? = nil, month: Int? = nil, day: Int? = nil, isEstimated: Bool = false) {
        self.year = year
        self.month = month
        self.day = day
        self.isEstimated = isEstimated
    }

    /// Human-readable rendering of whichever components are known,
    /// e.g. "1945", "Mar 1945", "12 Mar 1945", "~1945", or "Unknown" when nothing is known.
    var displayString: String {
        var components: [String] = []

        // A day is only meaningful alongside a month.
        if let day, month != nil {
            components.append(String(day))
        }
        if let monthName = Self.monthName(for: month) {
            components.append(monthName)
        }
        if let year {
            components.append(String(year))
        }

        guard !components.isEmpty else { return "Unknown" }

        let text = components.joined(separator: " ")
        return isEstimated ? "~\(text)" : text
    }

    /// Fixed English abbreviations — display must not shift with the runtime locale.
    private static let monthNames = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ]

    private static func monthName(for month: Int?) -> String? {
        guard let month, (1...12).contains(month) else { return nil }
        return monthNames[month - 1]
    }
}
