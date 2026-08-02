// AddPersonViewModelTests.swift
// Form state for the add-person sheet: name validation and year parsing.

import Foundation
import Testing
@testable import Banyan

@MainActor
@Suite("AddPersonViewModel")
struct AddPersonViewModelTests {

    @Test func canContinueIsFalseWhenFirstNameEmpty() throws {
        // Given a fresh form with a whitespace-only first name
        let builder = try TestTreeBuilder()
        let anchor = builder.makePerson(firstName: "Aryan")
        let vm = AddPersonViewModel(
            context: .parent(of: anchor),
            mutationService: TreeMutationService()
        )
        vm.firstName = "   "

        // Then the name step cannot continue
        #expect(vm.canContinueFromName == false)
    }

    @Test func canContinueIsTrueWithName() throws {
        // Given a form with a real first name
        let builder = try TestTreeBuilder()
        let anchor = builder.makePerson(firstName: "Aryan")
        let vm = AddPersonViewModel(
            context: .parent(of: anchor),
            mutationService: TreeMutationService()
        )
        vm.firstName = "Ravi"

        // Then the name step can continue
        #expect(vm.canContinueFromName)
    }

    @Test func birthDateNilWhenYearTextEmpty() throws {
        // Given a form with no birth year entered
        let builder = try TestTreeBuilder()
        let anchor = builder.makePerson(firstName: "Aryan")
        let vm = AddPersonViewModel(
            context: .child(of: anchor),
            mutationService: TreeMutationService()
        )
        vm.birthYearText = ""

        // Then no birth date is derived
        #expect(vm.birthDate == nil)
    }

    @Test func birthDateParsedFromYearText() throws {
        // Given a form with a valid birth year
        let builder = try TestTreeBuilder()
        let anchor = builder.makePerson(firstName: "Aryan")
        let vm = AddPersonViewModel(
            context: .child(of: anchor),
            mutationService: TreeMutationService()
        )
        vm.birthYearText = "1945"

        // Then the birth date carries just that year
        #expect(vm.birthDate?.year == 1945)
        #expect(vm.birthDate?.month == nil)
    }

    @Test func deathDateNilWhenNotDeceased() throws {
        // Given a living person with a year typed into the death field
        let builder = try TestTreeBuilder()
        let anchor = builder.makePerson(firstName: "Aryan")
        let vm = AddPersonViewModel(
            context: .partner(of: anchor),
            mutationService: TreeMutationService()
        )
        vm.isDeceased = false
        vm.deathYearText = "1998"

        // Then no death date is derived
        #expect(vm.deathDate == nil)
    }

    @Test func saveSiblingContextCreatesSibling() async throws {
        // Given a sibling-context form anchored on a person with a parent
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let parent = builder.makePerson(firstName: "Parent", treeId: treeId)
        let focal = builder.makePerson(firstName: "Focal", treeId: treeId)
        let union = builder.makeUnion(treeId: treeId)
        builder.link(person: parent, to: union, role: .partner)
        builder.link(person: focal, to: union, role: .child)
        let vm = AddPersonViewModel(
            context: .sibling(of: focal),
            mutationService: TreeMutationService()
        )
        vm.firstName = "Sib"

        // When the form is saved
        try await vm.save(in: builder.context, sync: SpySyncScheduler())

        // Then the new person is a sibling of the anchor
        let graph = GraphService()
        #expect(graph.siblings(of: focal).contains { $0.firstName == "Sib" })
    }

    @Test func saveSchedulesSyncForAnchorTree() async throws {
        // Given an add-child form anchored on a person in a specific tree
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let anchor = builder.makePerson(firstName: "Anchor", treeId: treeId)
        let vm = AddPersonViewModel(
            context: .child(of: anchor),
            mutationService: TreeMutationService()
        )
        vm.firstName = "Kid"
        let spy = SpySyncScheduler()

        // When the form is saved
        try await vm.save(in: builder.context, sync: spy)

        // Then a sync is scheduled for the anchor's tree
        #expect(spy.scheduledTreeIds == [treeId])
    }

    @Test func deathDateParsedWhenDeceased() throws {
        // Given a deceased person with a valid death year
        let builder = try TestTreeBuilder()
        let anchor = builder.makePerson(firstName: "Aryan")
        let vm = AddPersonViewModel(
            context: .partner(of: anchor),
            mutationService: TreeMutationService()
        )
        vm.isDeceased = true
        vm.deathYearText = "1998"

        // Then the death date carries that year
        #expect(vm.deathDate?.year == 1998)
    }
}
