// PersonEditViewModelTests.swift
// The edit form's derived state and its write-back to a Person.

import Foundation
import Testing
@testable import Banyan

@MainActor
@Suite("PersonEditViewModel")
struct PersonEditViewModelTests {

    @Test func seedsFieldsFromPerson() throws {
        // Given a person with a name, sex, birth date and bio
        let person = Person(
            treeId: UUID(),
            firstName: "Ravi",
            lastName: "Das",
            sex: .male,
            birthDate: PartialDate(year: 1960, month: 3),
            bio: "A gardener."
        )

        // When the edit view model is seeded from them
        let vm = PersonEditViewModel(person: person)

        // Then every editable field mirrors the person
        #expect(vm.firstName == "Ravi")
        #expect(vm.lastName == "Das")
        #expect(vm.sex == .male)
        #expect(vm.birthYearText == "1960")
        #expect(vm.birthMonthText == "3")
        #expect(vm.isDeceased == false)
        #expect(vm.bio == "A gardener.")
    }

    @Test func deathDateKeepsMonthDayWithoutYear() throws {
        // Given a deceased person edited with a shraddha date but an unknown year
        let person = Person(treeId: UUID(), firstName: "Bapa")
        let vm = PersonEditViewModel(person: person)
        vm.isDeceased = true
        vm.deathYearText = ""
        vm.deathMonthText = "4"
        vm.deathDayText = "16"

        // Then the month + day are preserved (not dropped for the missing year)
        let death = try #require(vm.deathDate)
        #expect(death.year == nil)
        #expect(death.month == 4)
        #expect(death.day == 16)
    }

    @Test func birthDateKeepsMonthDayWithoutYear() throws {
        let person = Person(treeId: UUID(), firstName: "Bapa")
        let vm = PersonEditViewModel(person: person)
        vm.birthYearText = ""
        vm.birthMonthText = "11"
        vm.birthDayText = "29"

        let birth = try #require(vm.birthDate)
        #expect(birth.year == nil)
        #expect(birth.month == 11)
        #expect(birth.day == 29)
    }

    @Test func deceasedWithNothingStillMarksDeceased() throws {
        // A deceased person with no date at all keeps a non-nil (empty) deathDate so
        // Person.isDeceased (deathDate != nil) survives the round-trip.
        let person = Person(treeId: UUID(), firstName: "Bapa")
        let vm = PersonEditViewModel(person: person)
        vm.isDeceased = true

        let death = try #require(vm.deathDate)
        #expect(death.year == nil && death.month == nil && death.day == nil)
    }

    @Test func canSaveIsFalseWhenFirstNameBlank() throws {
        // Given an edit form
        let person = Person(treeId: UUID(), firstName: "Ravi")
        let vm = PersonEditViewModel(person: person)

        // When the first name is empty or only whitespace
        vm.firstName = ""
        #expect(vm.canSave == false)
        vm.firstName = "   "

        // Then saving is disallowed
        #expect(vm.canSave == false)
    }

    @Test func canSaveIsTrueWithFirstName() throws {
        // Given an edit form
        let person = Person(treeId: UUID(), firstName: "")
        let vm = PersonEditViewModel(person: person)

        // When the first name is present
        vm.firstName = "Ravi"

        // Then saving is allowed
        #expect(vm.canSave == true)
    }

    @Test func birthDateNilWhenYearTextEmpty() throws {
        // Given an edit form with no birth year
        let person = Person(treeId: UUID(), firstName: "Ravi")
        let vm = PersonEditViewModel(person: person)
        vm.birthYearText = ""

        // Then no birth date is derived
        #expect(vm.birthDate == nil)
    }

    @Test func birthDateIncludesMonthWhenProvided() throws {
        // Given an edit form with a year and month
        let person = Person(treeId: UUID(), firstName: "Ravi")
        let vm = PersonEditViewModel(person: person)
        vm.birthYearText = "1960"
        vm.birthMonthText = "3"

        // Then both components appear in the derived date
        #expect(vm.birthDate?.year == 1960)
        #expect(vm.birthDate?.month == 3)
    }

    @Test func deathDateNilWhenNotDeceased() throws {
        // Given a living person's edit form with a stray death year
        let person = Person(treeId: UUID(), firstName: "Ravi")
        let vm = PersonEditViewModel(person: person)
        vm.isDeceased = false
        vm.deathYearText = "2005"

        // Then no death date is derived
        #expect(vm.deathDate == nil)
    }

    @Test func deathDateParsedWhenDeceased() throws {
        // Given a deceased person's edit form with a death year
        let person = Person(treeId: UUID(), firstName: "Ravi")
        let vm = PersonEditViewModel(person: person)
        vm.isDeceased = true
        vm.deathYearText = "2005"

        // Then the death year is parsed
        #expect(vm.deathDate?.year == 2005)
    }

    @Test func deathDateNonNilWhenDeceasedWithNoYear() throws {
        // Given a deceased person with an unknown death year
        let person = Person(treeId: UUID(), firstName: "Ravi")
        let vm = PersonEditViewModel(person: person)
        vm.isDeceased = true
        vm.deathYearText = ""

        // Then the death date is non-nil (so isDeceased survives) but year-less
        #expect(vm.deathDate != nil)
        #expect(vm.deathDate?.year == nil)
    }

    @Test func saveWritesChangesToPerson() async throws {
        // Given a person in a context and an edit form with changes
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Old", lastName: "Name")
        let vm = PersonEditViewModel(person: person)
        vm.firstName = "  Ravi  "
        vm.lastName = "  Das  "
        vm.sex = .female
        vm.birthYearText = "1960"
        vm.birthMonthText = "3"
        vm.isDeceased = true
        vm.deathYearText = "2005"
        vm.bio = "   "

        // When the form is saved
        try await vm.save(person: person, in: builder.context, sync: SpySyncScheduler())

        // Then trimmed values are written and a blank bio becomes nil
        #expect(person.firstName == "Ravi")
        #expect(person.lastName == "Das")
        #expect(person.sex == .female)
        #expect(person.birthDate?.year == 1960)
        #expect(person.birthDate?.month == 3)
        #expect(person.isDeceased)
        #expect(person.deathDate?.year == 2005)
        #expect(person.bio == nil)
    }

    @Test func saveSchedulesSyncForPersonTree() async throws {
        // Given a person in a specific tree and an edit form
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let person = builder.makePerson(firstName: "Old", treeId: treeId)
        let vm = PersonEditViewModel(person: person)
        vm.firstName = "New"
        let spy = SpySyncScheduler()

        // When the form is saved
        try await vm.save(person: person, in: builder.context, sync: spy)

        // Then a sync is scheduled for the person's tree
        #expect(spy.scheduledTreeIds == [treeId])
    }
}
