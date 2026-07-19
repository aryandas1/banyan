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
