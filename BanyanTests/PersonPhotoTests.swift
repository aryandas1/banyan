// PersonPhotoTests.swift
// Covers PersonPhoto.takenDateDisplay, including the out-of-range month path that
// exercises the Collection[safe:] fallback.

import Testing
import Foundation
import SwiftData
@testable import Banyan

@Suite("PersonPhoto")
struct PersonPhotoTests {

    private func makePhoto(year: Int? = nil, month: Int? = nil) -> PersonPhoto {
        PersonPhoto(treeId: UUID(), personId: UUID(), filename: "x.jpg",
                    takenYear: year, takenMonth: month)
    }

    @Test func yearOnlyDisplaysYear() {
        #expect(makePhoto(year: 1967).takenDateDisplay == "1967")
    }

    @Test func yearAndMonthDisplaysMonthName() {
        // Locale-safe: compare against the same symbol table the property uses.
        let expectedMonth = DateFormatter().monthSymbols[5]   // index 5 == June
        #expect(makePhoto(year: 1967, month: 6).takenDateDisplay == "\(expectedMonth) 1967")
    }

    @Test func noYearDisplaysNil() {
        #expect(makePhoto(month: 6).takenDateDisplay == nil)
    }

    @Test func outOfRangeMonthFallsBackToYear() {
        // month 13 → monthSymbols[safe: 12] is nil → falls back to the year string.
        #expect(makePhoto(year: 1967, month: 13).takenDateDisplay == "1967")
    }

    @Test func cropDefaultsToNoCrop() {
        // A photo added without a crop fills the circle: scale 1, no offset.
        let photo = PersonPhoto(treeId: UUID(), personId: UUID(), filename: "x.jpg")
        #expect(photo.cropScale == 1)
        #expect(photo.cropOffsetX == 0)
        #expect(photo.cropOffsetY == 0)
    }
}

@MainActor
@Suite("Person.profilePhoto")
struct PersonProfilePhotoTests {

    /// Inserts photos into `person` through a real in-memory context so the
    /// relationship inverse is populated.
    private func attach(_ specs: [(order: Int, profile: Bool, name: String)],
                        to person: Person, in context: ModelContext) {
        for spec in specs {
            let photo = PersonPhoto(treeId: person.treeId, personId: person.id,
                                    filename: spec.name, isProfilePhoto: spec.profile,
                                    sortOrder: spec.order)
            context.insert(photo)
            photo.person = person
        }
    }

    @Test func nilWhenNoPhotos() throws {
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        #expect(person.profilePhoto == nil)
    }

    @Test func prefersFlaggedPhotoOverSortOrder() throws {
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        attach([(0, false, "a.jpg"), (1, true, "b.jpg")], to: person, in: builder.context)
        #expect(person.profilePhoto?.filename == "b.jpg")
    }

    @Test func fallsBackToLowestSortOrderWhenNoneFlagged() throws {
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        attach([(2, false, "c.jpg"), (1, false, "b.jpg")], to: person, in: builder.context)
        #expect(person.profilePhoto?.filename == "b.jpg")
    }
}
