// MarriageDateEditViewModelTests.swift
// The after-the-fact relationship editor: seeding status + date from a union, saving
// married/partners, and clearing the date — each scheduling a sync of the union's tree.

import Foundation
import SwiftData
import Testing
@testable import Banyan

@MainActor
@Suite("MarriageDateEditViewModel")
struct MarriageDateEditViewModelTests {

    /// A two-partner union, optionally pre-dated, for the editor to work over.
    private func makeUnion(startDate: PartialDate?, in builder: TestTreeBuilder, treeId: UUID) -> Union {
        let a = builder.makePerson(firstName: "A", treeId: treeId)
        let b = builder.makePerson(firstName: "B", treeId: treeId)
        let union = builder.makeUnion(type: startDate == nil ? .unknown : .married, treeId: treeId)
        union.startDate = startDate
        builder.link(person: a, to: union, role: .partner)
        builder.link(person: b, to: union, role: .partner)
        return union
    }

    @Test func seedsFieldsFromExistingDate() throws {
        // Given a union that already has an anniversary
        let builder = try TestTreeBuilder()
        let union = makeUnion(startDate: PartialDate(year: 1972, month: 2, day: 3), in: builder, treeId: UUID())

        // When the editor is built for it
        let vm = MarriageDateEditViewModel(union: union, partnerName: "Priya", mutationService: TreeMutationService())

        // Then the fields reflect the stored date, it knows a date exists, and (a
        // .married seed) it starts on the married status
        #expect(vm.marriageYearText == "1972")
        #expect(vm.marriageMonth == 2)
        #expect(vm.marriageDayText == "3")
        #expect(vm.hasExistingDate)
        #expect(vm.isMarried)
    }

    @Test func seedsPartneredStatusFromPartneredUnion() throws {
        // Given an unmarried-partner union
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let a = builder.makePerson(firstName: "A", treeId: treeId)
        let b = builder.makePerson(firstName: "B", treeId: treeId)
        let union = builder.makeUnion(type: .partnered, treeId: treeId)
        builder.link(person: a, to: union, role: .partner)
        builder.link(person: b, to: union, role: .partner)

        // When the editor is built, it starts on the partners status
        let vm = MarriageDateEditViewModel(union: union, partnerName: "Sam", mutationService: TreeMutationService())
        #expect(vm.isMarried == false)
    }

    @Test func hasExistingDateFalseWhenNoneStored() throws {
        // Given a date-less union
        let builder = try TestTreeBuilder()
        let union = makeUnion(startDate: nil, in: builder, treeId: UUID())

        // When the editor is built
        let vm = MarriageDateEditViewModel(union: union, partnerName: "Sam", mutationService: TreeMutationService())

        // Then no existing date, and empty fields
        #expect(vm.hasExistingDate == false)
        #expect(vm.marriageYearText.isEmpty)
        #expect(vm.marriageMonth == nil)
    }

    @Test func saveMarriedWritesDateAndSchedulesSync() throws {
        // Given a date-less union and a spy scheduler
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let union = makeUnion(startDate: nil, in: builder, treeId: treeId)
        let vm = MarriageDateEditViewModel(union: union, partnerName: "Sam", mutationService: TreeMutationService())
        vm.isMarried = true
        vm.marriageYearText = "2001"
        vm.marriageMonth = 8
        vm.marriageDayText = "15"
        let spy = SpySyncScheduler()

        // When saved
        try vm.save(in: builder.context, sync: spy)

        // Then the union carries the date and a sync is scheduled for its tree
        #expect(union.startDate?.year == 2001)
        #expect(union.startDate?.month == 8)
        #expect(union.type == .married)
        #expect(spy.scheduledTreeIds == [treeId])
    }

    @Test func saveAsPartnersMarksPartneredAndDropsDate() throws {
        // Given a married union with a date, then switched to partners in the editor
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let union = makeUnion(startDate: PartialDate(year: 1995), in: builder, treeId: treeId)
        let vm = MarriageDateEditViewModel(union: union, partnerName: "Sam", mutationService: TreeMutationService())
        vm.isMarried = false
        let spy = SpySyncScheduler()

        // When saved
        try vm.save(in: builder.context, sync: spy)

        // Then it's an unmarried partnership with no wedding date
        #expect(union.type == .partnered)
        #expect(union.startDate == nil)
        #expect(spy.scheduledTreeIds == [treeId])
    }

    @Test func removeDateKeepsMarriedAndSchedulesSync() throws {
        // Given a married union with an anniversary already set
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let union = makeUnion(startDate: PartialDate(year: 1990), in: builder, treeId: treeId)
        let vm = MarriageDateEditViewModel(union: union, partnerName: "Sam", mutationService: TreeMutationService())
        let spy = SpySyncScheduler()

        // When the date is removed
        try vm.removeDate(in: builder.context, sync: spy)

        // Then the date is cleared, the couple stays married, and a sync is scheduled
        #expect(union.startDate == nil)
        #expect(union.type == .married)
        #expect(spy.scheduledTreeIds == [treeId])
    }
}
