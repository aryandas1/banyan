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
        try await vm.save(for: person, in: builder.context, photoSync: nil)

        // then
        #expect(person.photos.count == 1)
        let photo = try #require(person.photos.first)
        #expect(photo.isProfilePhoto)
        #expect(photo.sortOrder == 0)
        cleanUp(person)
    }

    @Test func savedProfilePhotoPersistsChosenCrop() async throws {
        // given — a square test image (aspectRatio 1) and a framing well within bounds
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        let vm = AddPhotoViewModel(setAsProfilePhoto: true)
        vm.onImageSelected(image: makeImage(), data: nil)
        let crop = AvatarCrop(scale: 2, offsetX: 0.1, offsetY: -0.1)

        // when
        try await vm.save(for: person, in: builder.context, photoSync: nil, crop: crop)

        // then — the framing rides along onto the stored photo
        let photo = try #require(person.photos.first)
        #expect(photo.cropScale == 2)
        #expect(photo.cropOffsetX == 0.1)
        #expect(photo.cropOffsetY == -0.1)
        cleanUp(person)
    }

    @Test func galleryAddDefaultsToIdentityCrop() async throws {
        // given — no crop argument (the gallery-add path)
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        let vm = AddPhotoViewModel()
        vm.onImageSelected(image: makeImage(), data: nil)

        // when
        try await vm.save(for: person, in: builder.context, photoSync: nil)

        // then — the photo fills the circle (identity framing)
        let photo = try #require(person.photos.first)
        #expect(photo.cropScale == 1)
        #expect(photo.cropOffsetX == 0)
        #expect(photo.cropOffsetY == 0)
        cleanUp(person)
    }

    @Test func secondNonProfilePhotoStaysSecondaryAndIncrementsSort() async throws {
        // given a person who already has a (profile) photo
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        let first = AddPhotoViewModel()
        first.onImageSelected(image: makeImage(), data: nil)
        try await first.save(for: person, in: builder.context, photoSync: nil)

        // when a second is added without the profile flag
        let second = AddPhotoViewModel(setAsProfilePhoto: false)
        second.onImageSelected(image: makeImage(), data: nil)
        try await second.save(for: person, in: builder.context, photoSync: nil)

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
        try await first.save(for: person, in: builder.context, photoSync: nil)
        let firstPhoto = try #require(person.photos.first)

        // when a second photo is saved as the profile photo
        let second = AddPhotoViewModel(setAsProfilePhoto: true)
        second.onImageSelected(image: makeImage(), data: nil)
        try await second.save(for: person, in: builder.context, photoSync: nil)

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

        try await vm.save(for: person, in: builder.context, photoSync: nil)

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

        try await vm.save(for: person, in: builder.context, photoSync: nil)

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
        do { try await vm.save(for: person, in: builder.context, photoSync: nil) }
        catch { thrown = error }

        #expect(thrown is PhotoSaveError)
        #expect(person.photos.isEmpty)
    }

    // MARK: - Upload trigger

    @Test func saveUploadsPhotoAndRecordsStoragePath() async throws {
        // given
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        let mock = MockPhotoSyncService()
        let vm = AddPhotoViewModel()
        vm.onImageSelected(image: makeImage(), data: nil)

        // when the local save succeeds and the background upload completes
        try await vm.save(for: person, in: builder.context, photoSync: mock)
        await vm.awaitPendingUpload()

        // then the mock was asked to upload the saved photo, with its bytes,
        let photo = try #require(person.photos.first)
        #expect(mock.uploads.count == 1)
        let uploaded = try #require(mock.uploads.first)
        #expect(uploaded.dto.id == photo.id)
        #expect(uploaded.dto.storagePath == PersonPhotoDTO.storagePath(
            treeId: person.treeId, personId: person.id, photoId: photo.id))
        #expect(!uploaded.imageData.isEmpty)
        // and the successful upload's path was written back to the model.
        #expect(photo.supabaseStoragePath == uploaded.dto.storagePath)
        cleanUp(person)
    }

    @Test func saveWithoutSyncServiceStillSavesLocally() async throws {
        // given no injected sync service (previews / signed out)
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        let vm = AddPhotoViewModel()
        vm.onImageSelected(image: makeImage(), data: nil)

        // when
        try await vm.save(for: person, in: builder.context, photoSync: nil)
        await vm.awaitPendingUpload()

        // then the photo is saved but nothing was uploaded and no path recorded
        let photo = try #require(person.photos.first)
        #expect(photo.supabaseStoragePath == nil)
        cleanUp(person)
    }

    @Test func uploadFailureLeavesStoragePathNilForRetry() async throws {
        // given a sync service that fails every upload
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        let mock = MockPhotoSyncService()
        mock.errorToThrow = URLError(.notConnectedToInternet)
        let vm = AddPhotoViewModel()
        vm.onImageSelected(image: makeImage(), data: nil)

        // when the (non-fatal) upload fails
        try await vm.save(for: person, in: builder.context, photoSync: mock)
        await vm.awaitPendingUpload()

        // then the local save stands and the path stays nil so syncPending retries
        let photo = try #require(person.photos.first)
        #expect(photo.supabaseStoragePath == nil)
        cleanUp(person)
    }

    @Test func addingNewProfilePhotoReupsertsTheDemotedPreviousProfile() async throws {
        // given a person whose first (uploaded) photo is the profile
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        let mock = MockPhotoSyncService()
        let first = AddPhotoViewModel()
        first.onImageSelected(image: makeImage(), data: nil)
        try await first.save(for: person, in: builder.context, photoSync: mock)
        await first.awaitPendingUpload()
        let firstPhoto = try #require(person.photos.first)
        #expect(firstPhoto.supabaseStoragePath != nil)   // uploaded

        // when a second photo is added AS the profile photo
        let second = AddPhotoViewModel(setAsProfilePhoto: true)
        second.onImageSelected(image: makeImage(), data: nil)
        try await second.save(for: person, in: builder.context, photoSync: mock)
        await second.awaitPendingUpload()

        // then the demoted first photo's row is re-upserted with is_profile=false,
        // so the backend doesn't keep two profile rows
        #expect(!firstPhoto.isProfilePhoto)
        let demotedUpsert = try #require(mock.upserts.first(where: { $0.id == firstPhoto.id }))
        #expect(demotedUpsert.isProfilePhoto == false)
        // and the new photo was uploaded as profile
        #expect(mock.uploads.contains { $0.dto.isProfilePhoto && $0.dto.id != firstPhoto.id })
        cleanUp(person)
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
