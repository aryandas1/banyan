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
    var isDeceased: Bool
    var deathYearText: String
    var bio: String

    private(set) var isSaving: Bool = false
    var saveError: Error? = nil

    /// A first name is the only required field.
    var canSave: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The birth year (and optional month) parsed into a PartialDate, or nil when blank/invalid.
    var birthDate: PartialDate? {
        guard let year = Int(birthYearText), year > 0 else { return nil }
        let month = Int(birthMonthText)   // nil when blank/invalid — that's fine
        return PartialDate(year: year, month: month)
    }

    /// A deceased person keeps a non-nil deathDate even with an unknown year, so
    /// `Person.isDeceased` (derived from `deathDate != nil`) survives the round-trip.
    /// This mirrors the decision made in step 4 for the add flow.
    var deathDate: PartialDate? {
        guard isDeceased else { return nil }
        guard let year = Int(deathYearText), year > 0 else { return PartialDate() }
        return PartialDate(year: year)
    }

    /// Seeds every editable field from the person being edited.
    init(person: Person) {
        firstName = person.firstName
        lastName = person.lastName
        sex = person.sex
        birthYearText = person.birthDate?.year.map(String.init) ?? ""
        birthMonthText = person.birthDate?.month.map(String.init) ?? ""
        isDeceased = person.isDeceased
        deathYearText = person.deathDate?.year.map(String.init) ?? ""
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
