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

    // MARK: - Co-parent question (adding a second parent via "add partner")

    @Test func coParentQuestionAppliesWhenAddingPartnerToLoneParent() throws {
        // Given "me" whose only parent so far is Dad
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let me = builder.makePerson(firstName: "Me", treeId: treeId)
        let dad = try TreeMutationService().addParent(
            to: me, firstName: "Dad", lastName: "",
            birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context
        )

        // When building the add-partner form for Dad
        let vm = AddPersonViewModel(context: .partner(of: dad), mutationService: TreeMutationService())

        // Then the co-parent question applies and names the existing child
        #expect(vm.coParentQuestionApplies)
        #expect(vm.coParentChildrenNames == "Me")
    }

    @Test func coParentQuestionDoesNotApplyWithoutExistingChildren() throws {
        // Given a person with no children
        let builder = try TestTreeBuilder()
        let solo = builder.makePerson(firstName: "Solo")

        // When building the add-partner form for them
        let vm = AddPersonViewModel(context: .partner(of: solo), mutationService: TreeMutationService())

        // Then there's nothing to co-parent, so no question
        #expect(vm.coParentQuestionApplies == false)
    }

    @Test func savePartnerCoParentsWhenConfirmed() async throws {
        // Given the add-partner form for Dad (who has child Me), answer = yes
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let me = builder.makePerson(firstName: "Me", treeId: treeId)
        let dad = try TreeMutationService().addParent(
            to: me, firstName: "Dad", lastName: "",
            birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context
        )
        let vm = AddPersonViewModel(context: .partner(of: dad), mutationService: TreeMutationService())
        vm.firstName = "Mom"
        vm.coParentWithExistingChildren = true

        // When saved
        try await vm.save(in: builder.context, sync: SpySyncScheduler())

        // Then Mom becomes Me's second parent
        let parents = GraphService().parents(of: me)
        #expect(parents.count == 2)
        #expect(parents.contains { $0.firstName == "Mom" })
    }

    @Test func savePartnerStaysSeparateWhenDeclined() async throws {
        // Given the add-partner form for Dad (who has child Me), answer = no
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let me = builder.makePerson(firstName: "Me", treeId: treeId)
        let dad = try TreeMutationService().addParent(
            to: me, firstName: "Dad", lastName: "",
            birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context
        )
        let vm = AddPersonViewModel(context: .partner(of: dad), mutationService: TreeMutationService())
        vm.firstName = "Stepmom"
        vm.coParentWithExistingChildren = false

        // When saved
        try await vm.save(in: builder.context, sync: SpySyncScheduler())

        // Then Me still has only Dad as a parent
        #expect(GraphService().parents(of: me).count == 1)
        #expect(GraphService().parents(of: me).first?.firstName == "Dad")
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
