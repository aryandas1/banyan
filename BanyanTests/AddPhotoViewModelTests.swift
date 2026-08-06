// AddPhotoViewModelTests.swift
// Covers the add-photo save path against an in-memory V2 container (profile-photo
// promotion, sort order, blank-field trimming) plus the year/month parsing and
// EXIF auto-fill guard. `save` writes a real file into the sim's documents dir,
// which works under test; each test cleans up the files it created.

import Testing
import SwiftData
import UIKit
@testable import Banyan

@MainActor
@Suite("AddPhotoViewModel")
struct AddPhotoViewModelTests {

    // MARK: - Helpers

    private func makeImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        return renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }

    /// Deletes any files the saves wrote so tests don't litter the documents dir.
    private func cleanUp(_ person: Person) {
        for photo in person.photos { PhotoStorageService.delete(filename: photo.filename) }
    }

    // MARK: - save

    @Test func firstPhotoBecomesProfilePhoto() async throws {
        // given
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        let vm = AddPhotoViewModel()
        vm.onImageSelected(image: makeImage(), data: nil)

        // when
        try await vm.save(for: person, in: builder.context)

        // then
        #expect(person.photos.count == 1)
        let photo = try #require(person.photos.first)
        #expect(photo.isProfilePhoto)
        #expect(photo.sortOrder == 0)
        cleanUp(person)
    }

    @Test func secondNonProfilePhotoStaysSecondaryAndIncrementsSort() async throws {
        // given a person who already has a (profile) photo
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        let first = AddPhotoViewModel()
        first.onImageSelected(image: makeImage(), data: nil)
        try await first.save(for: person, in: builder.context)

        // when a second is added without the profile flag
        let second = AddPhotoViewModel(setAsProfilePhoto: false)
        second.onImageSelected(image: makeImage(), data: nil)
        try await second.save(for: person, in: builder.context)

        // then it is not a profile photo, sorts after the first, and there is still one profile photo
        #expect(person.photos.count == 2)
        let sorted = person.photos.sorted { $0.sortOrder < $1.sortOrder }
        #expect(sorted[0].isProfilePhoto)
        #expect(!sorted[1].isProfilePhoto)
        #expect(sorted[1].sortOrder == 1)
        #expect(person.photos.filter(\.isProfilePhoto).count == 1)
        cleanUp(person)
    }

    @Test func settingNewProfilePhotoUnsetsThePrevious() async throws {
        // given a person with an existing profile photo
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        let first = AddPhotoViewModel()
        first.onImageSelected(image: makeImage(), data: nil)
        try await first.save(for: person, in: builder.context)
        let firstPhoto = try #require(person.photos.first)

        // when a second photo is saved as the profile photo
        let second = AddPhotoViewModel(setAsProfilePhoto: true)
        second.onImageSelected(image: makeImage(), data: nil)
        try await second.save(for: person, in: builder.context)

        // then the flag moves to the new one and only one photo is profile
        let sorted = person.photos.sorted { $0.sortOrder < $1.sortOrder }
        #expect(!firstPhoto.isProfilePhoto)
        #expect(sorted[1].isProfilePhoto)
        #expect(person.photos.filter(\.isProfilePhoto).count == 1)
        cleanUp(person)
    }

    @Test func blankCaptionAndPlaceSaveAsNil() async throws {
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        let vm = AddPhotoViewModel()
        vm.onImageSelected(image: makeImage(), data: nil)
        vm.caption = "   "
        vm.takenPlace = ""

        try await vm.save(for: person, in: builder.context)

        let photo = try #require(person.photos.first)
        #expect(photo.caption == nil)
        #expect(photo.takenPlace == nil)
        cleanUp(person)
    }

    @Test func metadataIsTrimmedAndStored() async throws {
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        let vm = AddPhotoViewModel()
        vm.onImageSelected(image: makeImage(), data: nil)
        vm.caption = "  Wedding day  "
        vm.takenPlace = " Pune "
        vm.takenYearText = "1978"
        vm.takenMonthText = "6"

        try await vm.save(for: person, in: builder.context)

        let photo = try #require(person.photos.first)
        #expect(photo.caption == "Wedding day")
        #expect(photo.takenPlace == "Pune")
        #expect(photo.takenYear == 1978)
        #expect(photo.takenMonth == 6)
        cleanUp(person)
    }

    @Test func saveWithoutImageThrows() async throws {
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        let vm = AddPhotoViewModel()

        var thrown: Error?
        do { try await vm.save(for: person, in: builder.context) }
        catch { thrown = error }

        #expect(thrown is PhotoSaveError)
        #expect(person.photos.isEmpty)
    }

    // MARK: - Parsing / EXIF

    @Test func yearParsedFromText() {
        let vm = AddPhotoViewModel()
        vm.takenYearText = "1967"
        #expect(vm.takenYear == 1967)
    }

    @Test func invalidYearReturnsNil() {
        let vm = AddPhotoViewModel()
        vm.takenYearText = "abc"
        #expect(vm.takenYear == nil)
    }

    @Test func yearBelow1800ReturnsNil() {
        let vm = AddPhotoViewModel()
        vm.takenYearText = "1799"
        #expect(vm.takenYear == nil)
    }

    @Test func monthInRangeReturnsValue() {
        let vm = AddPhotoViewModel()
        vm.takenMonthText = "6"
        #expect(vm.takenMonth == 6)
    }

    @Test func monthOutOfRangeReturnsNil() {
        let vm = AddPhotoViewModel()
        vm.takenMonthText = "13"
        #expect(vm.takenMonth == nil)
    }

    @Test func onImageSelectedWithNilDataLeavesDateEmpty() {
        let vm = AddPhotoViewModel()
        vm.onImageSelected(image: makeImage(), data: nil)
        #expect(vm.takenYearText.isEmpty)
        #expect(vm.selectedImage != nil)
    }

    @Test func exifDoesNotOverwriteExistingYear() {
        let vm = AddPhotoViewModel()
        vm.takenYearText = "1950"
        vm.onImageSelected(image: makeImage(), data: nil)
        #expect(vm.takenYearText == "1950")
    }
}
