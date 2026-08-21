// PersonEditViewModel.swift
// Editable copies of a person's fields, seeded on init and written back on save.
// No SwiftUI import; SwiftData only for the ModelContext that save writes through.

import Foundation
import SwiftData

@MainActor
@Observable
final class PersonEditViewModel {
    var firstName: String
    var lastName: String
    var sex: Sex
    var birthYearText: String
    var birthMonthText: String   // "1"–"12"; empty = unknown
    var birthDayText: String     // "1"–"31"; empty = unknown (kept only with a month)
    var isDeceased: Bool
    var deathYearText: String
    var deathMonthText: String   // "1"–"12"; empty = unknown
    var deathDayText: String     // "1"–"31"; empty = unknown (kept only with a month)
    var bio: String

    private(set) var isSaving: Bool = false
    var saveError: Error? = nil

    /// A first name is the only required field.
    var canSave: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The birth year plus optional month and day parsed into a PartialDate, or nil
    /// when the year is blank/invalid. A day is only kept alongside a valid month.
    var birthDate: PartialDate? {
        guard let year = Int(birthYearText), year > 0 else { return nil }
        return PartialDate(year: year, month: Self.month(birthMonthText), day: Self.day(birthDayText, month: birthMonthText))
    }

    /// A deceased person keeps a non-nil deathDate even with an unknown year, so
    /// `Person.isDeceased` (derived from `deathDate != nil`) survives the round-trip.
    /// This mirrors the decision made in step 4 for the add flow. Month/day (for
    /// shraddha) are kept when present, a day only alongside a valid month.
    var deathDate: PartialDate? {
        guard isDeceased else { return nil }
        guard let year = Int(deathYearText), year > 0 else { return PartialDate() }
        return PartialDate(year: year, month: Self.month(deathMonthText), day: Self.day(deathDayText, month: deathMonthText))
    }

    /// A validated 1–12 month from text, or nil.
    private static func month(_ text: String) -> Int? {
        Int(text).flatMap { (1...12).contains($0) ? $0 : nil }
    }

    /// A validated 1–31 day from text, but only when `monthText` is a valid month
    /// (a day without a month is meaningless — matches PartialDate's rule).
    private static func day(_ text: String, month monthText: String) -> Int? {
        guard month(monthText) != nil else { return nil }
        return Int(text).flatMap { (1...31).contains($0) ? $0 : nil }
    }

    /// Seeds every editable field from the person being edited.
    init(person: Person) {
        firstName = person.firstName
        lastName = person.lastName
        sex = person.sex
        birthYearText = person.birthDate?.year.map(String.init) ?? ""
        birthMonthText = person.birthDate?.month.map(String.init) ?? ""
        birthDayText = person.birthDate?.day.map(String.init) ?? ""
        isDeceased = person.isDeceased
        deathYearText = person.deathDate?.year.map(String.init) ?? ""
        deathMonthText = person.deathDate?.month.map(String.init) ?? ""
        deathDayText = person.deathDate?.day.map(String.init) ?? ""
        bio = person.bio ?? ""
    }

    /// Writes the edited values back to the person, saves, then schedules a
    /// cloud sync of the person's tree.
    func save(person: Person, in context: ModelContext, sync: SyncScheduling) async throws {
        isSaving = true
        defer { isSaving = false }
        person.firstName = firstName.trimmingCharacters(in: .whitespaces)
        person.lastName = lastName.trimmingCharacters(in: .whitespaces)
        person.sex = sex
        person.birthDate = birthDate
        person.deathDate = deathDate
        person.bio = bio.trimmingCharacters(in: .whitespaces).isEmpty ? nil : bio
        try context.save()
        sync.scheduleSync(treeId: person.treeId, context: context)
    }
}
