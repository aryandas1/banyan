// AddPersonViewModel.swift
// Form state for the multi-step add-person sheet, and the save that hands
// the collected fields to TreeMutationService.

import Foundation
import SwiftData

@MainActor
@Observable
final class AddPersonViewModel {
    private let mutationService: TreeMutationServiceProtocol
    private let graph: GraphServiceProtocol

    /// Which relationship is being created, and for whom. Drives headings and save routing.
    let context: AddPersonContext

    // MARK: - Form state

    var firstName: String = ""
    var lastName: String = ""
    var sex: Sex = .unknown
    var birthYearText: String = ""
    /// Optional birth month (1–12); nil when unknown. A day is only kept if a month is set.
    var birthMonth: Int? = nil
    var birthDayText: String = ""
    var isDeceased: Bool = false
    var deathYearText: String = ""
    /// Optional death month (1–12); nil when unknown. A day is only kept if a month
    /// is set. Exact death dates matter for Hindu shraddha observances.
    var deathMonth: Int? = nil
    var deathDayText: String = ""
    /// Marriage / anniversary date — only captured in the `.partner` context. The
    /// year is optional (a known anniversary day with an unknown year is still worth
    /// keeping); a day is only kept alongside a month, like birth and death.
    var marriageYearText: String = ""
    var marriageMonth: Int? = nil
    var marriageDayText: String = ""
    private(set) var isSaving: Bool = false
    var saveError: Error? = nil

    /// The answer to "is this partner also a parent of the anchor's existing
    /// children?" Only consulted when `coParentQuestionApplies`. Defaults to true —
    /// the common case is that two partners are the parents of their shared kids.
    var coParentWithExistingChildren: Bool = true

    // MARK: - Derived

    /// The name step requires a non-blank first name before continuing.
    var canContinueFromName: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The birth date from whatever the user entered. The year is NOT required — a
    /// month/day with an unknown year (e.g. a known birthday) is preserved, since
    /// PartialDate supports it. Nil only when nothing at all is known.
    var birthDate: PartialDate? {
        PartialDateBuilder.from(yearText: birthYearText, month: birthMonth, dayText: birthDayText)
    }

    /// The death date from whatever the user entered — only when deceased. Like
    /// birth, the year is NOT required, so a year-less shraddha date (month + day) is
    /// kept rather than dropped. Nil when deceased with nothing entered (the separate
    /// `isDeceased` flag still records the status).
    var deathDate: PartialDate? {
        guard isDeceased else { return nil }
        return PartialDateBuilder.from(yearText: deathYearText, month: deathMonth, dayText: deathDayText)
    }

    /// The marriage / anniversary date from whatever the user entered — the same
    /// year-less-safe rule as birth and death, so a known anniversary day with an
    /// unknown year survives. Nil when nothing at all is entered. Only meaningful in
    /// the `.partner` context (the only place it's captured or applied).
    var marriageDate: PartialDate? {
        PartialDateBuilder.from(yearText: marriageYearText, month: marriageMonth, dayText: marriageDayText)
    }

    /// The name as it will be saved, for the review card.
    var displayName: String {
        [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// The birth line on the review card — shows whatever of year/month/day is known.
    var birthDescription: String {
        guard let birthDate else { return "Birth date unknown" }
        return "Born \(birthDate.displayString)"
    }

    /// The gender line on the review card.
    var genderDescription: String {
        switch sex {
        case .male:    return "Male"
        case .female:  return "Female"
        case .unknown: return "Gender not set"
        }
    }

    /// The living/deceased line on the review card — shows the full death date
    /// (day/month/year as known), so an exact shraddha date is confirmed before save.
    var statusDescription: String {
        guard isDeceased else { return "Living" }
        guard let deathDate else { return "Passed away" }
        return "Passed away \(deathDate.displayString)"
    }

    /// The union whose children a new partner would co-parent if the user says so —
    /// nil unless we're adding a partner to someone with a single one-parent,
    /// childed union. Drives the co-parent question on the review step.
    private var coParentableUnion: Union? {
        guard case .partner(let anchor) = context else { return nil }
        return graph.coParentableUnion(for: anchor)
    }

    /// Whether the review step should ask "is this partner also a parent of the
    /// anchor's existing children?" (i.e. there are existing children to co-parent).
    var coParentQuestionApplies: Bool { coParentableUnion != nil }

    /// The existing children's names for the co-parent question, e.g. "Aryan" or
    /// "Aryan and Meera". Empty when the question doesn't apply.
    var coParentChildrenNames: String {
        guard let union = coParentableUnion else { return "" }
        let names = union.links
            .filter { $0.role == .child }
            .compactMap { $0.person?.firstName }
            .filter { !$0.isEmpty }
        return ListFormatter.localizedString(byJoining: names)
    }

    /// Creates the form for one relationship context, with the services that save it
    /// and read the graph (for the co-parent question).
    init(
        context: AddPersonContext,
        mutationService: TreeMutationServiceProtocol,
        graph: GraphServiceProtocol = GraphService()
    ) {
        self.context = context
        self.mutationService = mutationService
        self.graph = graph
    }

    /// Saves the new person into the graph via the mutation service, then
    /// schedules a cloud sync of the affected tree.
    /// Throws on failure — the caller routes the error into `saveError`.
    func save(in modelContext: ModelContext, sync: SyncScheduling) async throws {
        isSaving = true
        defer { isSaving = false }

        let first = firstName.trimmingCharacters(in: .whitespaces)
        let last = lastName.trimmingCharacters(in: .whitespaces)
        let anchor = context.anchorPerson

        switch context {
        case .parent:
            try mutationService.addParent(
                to: anchor, firstName: first, lastName: last, sex: sex,
                birthDate: birthDate, isDeceased: isDeceased,
                deathDate: deathDate, in: modelContext
            )
        case .partner:
            try mutationService.addPartner(
                to: anchor, firstName: first, lastName: last, sex: sex,
                birthDate: birthDate, isDeceased: isDeceased,
                deathDate: deathDate,
                // Only co-parent when the question actually applied AND the user said yes.
                coParentExistingChildren: coParentQuestionApplies && coParentWithExistingChildren,
                marriageDate: marriageDate,
                in: modelContext
            )
        case .child:
            try mutationService.addChild(
                to: anchor, firstName: first, lastName: last, sex: sex,
                birthDate: birthDate, isDeceased: isDeceased,
                deathDate: deathDate, in: modelContext
            )
        case .sibling:
            try mutationService.addSibling(
                to: anchor, firstName: first, lastName: last, sex: sex,
                birthDate: birthDate, isDeceased: isDeceased,
                deathDate: deathDate, in: modelContext
            )
        }

        sync.scheduleSync(treeId: anchor.treeId, context: modelContext)
    }
}
