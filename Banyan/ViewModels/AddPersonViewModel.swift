// AddPersonViewModel.swift
// Form state for the multi-step add-person sheet, and the save that hands
// the collected fields to TreeMutationService.

import Foundation
import SwiftData

@MainActor
@Observable
final class AddPersonViewModel {
    private let mutationService: TreeMutationServiceProtocol

    /// Which relationship is being created, and for whom. Drives headings and save routing.
    let context: AddPersonContext

    // MARK: - Form state

    var firstName: String = ""
    var lastName: String = ""
    var birthYearText: String = ""
    var isDeceased: Bool = false
    var deathYearText: String = ""
    private(set) var isSaving: Bool = false
    var saveError: Error? = nil

    // MARK: - Derived

    /// The name step requires a non-blank first name before continuing.
    var canContinueFromName: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The birth year parsed into a year-only PartialDate, or nil when blank/invalid.
    var birthDate: PartialDate? {
        guard let year = Int(birthYearText), year > 0 else { return nil }
        return PartialDate(year: year)
    }

    /// The death year parsed into a year-only PartialDate — only when deceased.
    var deathDate: PartialDate? {
        guard isDeceased, let year = Int(deathYearText), year > 0 else { return nil }
        return PartialDate(year: year)
    }

    /// The name as it will be saved, for the review card.
    var displayName: String {
        [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// The birth line on the review card.
    var birthDescription: String {
        guard let year = birthDate?.year else { return "Birth year unknown" }
        return "Born \(year)"
    }

    /// The living/deceased line on the review card.
    var statusDescription: String {
        guard isDeceased else { return "Living" }
        guard let year = deathDate?.year else { return "Passed away" }
        return "Passed away in \(year)"
    }

    /// Creates the form for one relationship context, with the service that will save it.
    init(context: AddPersonContext, mutationService: TreeMutationServiceProtocol) {
        self.context = context
        self.mutationService = mutationService
    }

    /// Saves the new person into the graph via the mutation service.
    /// Throws on failure — the caller routes the error into `saveError`.
    func save(in modelContext: ModelContext) async throws {
        isSaving = true
        defer { isSaving = false }

        let first = firstName.trimmingCharacters(in: .whitespaces)
        let last = lastName.trimmingCharacters(in: .whitespaces)
        let anchor = context.anchorPerson

        switch context {
        case .parent:
            try mutationService.addParent(
                to: anchor, firstName: first, lastName: last,
                birthDate: birthDate, isDeceased: isDeceased,
                deathDate: deathDate, in: modelContext
            )
        case .partner:
            try mutationService.addPartner(
                to: anchor, firstName: first, lastName: last,
                birthDate: birthDate, isDeceased: isDeceased,
                deathDate: deathDate, in: modelContext
            )
        case .child:
            try mutationService.addChild(
                to: anchor, firstName: first, lastName: last,
                birthDate: birthDate, isDeceased: isDeceased,
                deathDate: deathDate, in: modelContext
            )
        case .sibling:
            try mutationService.addSibling(
                to: anchor, firstName: first, lastName: last,
                birthDate: birthDate, isDeceased: isDeceased,
                deathDate: deathDate, in: modelContext
            )
        }
    }
}
