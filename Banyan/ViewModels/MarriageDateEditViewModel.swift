// MarriageDateEditViewModel.swift
// Backs the small sheet that sets or clears a marriage's anniversary date on an
// existing union — the after-the-fact entry point (the add-partner flow captures it
// up front). Seeds its fields from the union's current date and writes back through
// the mutation service, then schedules a cloud sync so viewers see the anniversary.

import Foundation
import SwiftData

@MainActor
@Observable
final class MarriageDateEditViewModel {
    private let union: Union
    private let mutationService: TreeMutationServiceProtocol
    /// The partner this anniversary is with, for the sheet heading.
    let partnerName: String
    /// Whether a date is already recorded — drives showing the "Remove" affordance.
    let hasExistingDate: Bool

    var marriageYearText: String = ""
    var marriageMonth: Int? = nil
    var marriageDayText: String = ""
    var saveError: Error? = nil

    /// The date from whatever's entered — the same year-less-safe rule as birth/death.
    var marriageDate: PartialDate? {
        PartialDateBuilder.from(yearText: marriageYearText, month: marriageMonth, dayText: marriageDayText)
    }

    /// Prepares the editor for one union, seeding the fields from its current date.
    init(union: Union, partnerName: String, mutationService: TreeMutationServiceProtocol) {
        self.union = union
        self.partnerName = partnerName
        self.mutationService = mutationService
        self.hasExistingDate = union.startDate != nil
        if let start = union.startDate {
            marriageYearText = start.year.map(String.init) ?? ""
            marriageMonth = start.month
            marriageDayText = start.day.map(String.init) ?? ""
        }
    }

    /// Writes the entered date onto the union, then schedules a cloud sync.
    /// Throws on the ModelContext write — the caller routes it into `saveError`.
    func save(in context: ModelContext, sync: SyncScheduling) throws {
        try mutationService.setMarriageDate(marriageDate, on: union, in: context)
        sync.scheduleSync(treeId: union.treeId, context: context)
    }

    /// Clears the anniversary date on the union, then schedules a cloud sync.
    /// Throws on the ModelContext write — the caller routes it into `saveError`.
    func remove(in context: ModelContext, sync: SyncScheduling) throws {
        try mutationService.setMarriageDate(nil, on: union, in: context)
        sync.scheduleSync(treeId: union.treeId, context: context)
    }
}
