// MarriageDateEditViewModel.swift
// Backs the sheet that edits a couple's relationship after the fact: whether they're
// married or (unmarried) partners, and — for a marriage — the anniversary date. Seeds
// its fields from the union, then writes the chosen type + date back through the
// mutation service and schedules a cloud sync so viewers see the change.

import Foundation
import SwiftData

@MainActor
@Observable
final class MarriageDateEditViewModel {
    private let union: Union
    private let mutationService: TreeMutationServiceProtocol
    /// The partner this relationship is with, for the sheet heading.
    let partnerName: String
    /// Whether an anniversary date is already recorded — drives the "Remove" affordance.
    let hasExistingDate: Bool

    /// The chosen status. True = married (an anniversary applies); false = unmarried
    /// partners (no wedding date). Seeded from the union — a legacy `.unknown` union
    /// (an assumed spouse) starts as married.
    var isMarried: Bool
    var marriageYearText: String = ""
    var marriageMonth: Int? = nil
    var marriageDayText: String = ""
    var saveError: Error? = nil

    /// The date from whatever's entered — the same year-less-safe rule as birth/death.
    var marriageDate: PartialDate? {
        PartialDateBuilder.from(yearText: marriageYearText, month: marriageMonth, dayText: marriageDayText)
    }

    /// Prepares the editor for one union, seeding status and date from it.
    init(union: Union, partnerName: String, mutationService: TreeMutationServiceProtocol) {
        self.union = union
        self.partnerName = partnerName
        self.mutationService = mutationService
        self.hasExistingDate = union.startDate != nil
        self.isMarried = union.type != .partnered
        if let start = union.startDate {
            marriageYearText = start.year.map(String.init) ?? ""
            marriageMonth = start.month
            marriageDayText = start.day.map(String.init) ?? ""
        }
    }

    /// Writes the chosen status (and, when married, the entered date) onto the union,
    /// then schedules a cloud sync. Switching to partners drops any wedding date.
    /// Throws on the ModelContext write — the caller routes it into `saveError`.
    func save(in context: ModelContext, sync: SyncScheduling) throws {
        let type: UnionType = isMarried ? .married : .partnered
        let date = isMarried ? marriageDate : nil
        try mutationService.setUnionRelationship(type, startDate: date, on: union, in: context)
        sync.scheduleSync(treeId: union.treeId, context: context)
    }

    /// Clears the anniversary date while keeping the couple married, then schedules a
    /// cloud sync. Throws on the ModelContext write — routed into `saveError`.
    func removeDate(in context: ModelContext, sync: SyncScheduling) throws {
        try mutationService.setUnionRelationship(.married, startDate: nil, on: union, in: context)
        sync.scheduleSync(treeId: union.treeId, context: context)
    }
}
