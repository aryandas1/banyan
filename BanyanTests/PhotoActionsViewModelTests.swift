// PhotoActionsViewModelTests.swift
// The photo-detail mutation VM (step-13 finding #4 + step-14 re-sync): set-as-
// profile, delete, and metadata edits each do the local SwiftData write AND keep
// Supabase in step. Asserts the local mutation and the remote re-sync (via a mock)
// against an in-memory container. Re-sync fires only for already-uploaded photos.

import Foundation
import SwiftData
import Testing
@testable import Banyan

@MainActor
@Suite("PhotoActionsViewModel")
struct PhotoActionsViewModelTests {

    /// Inserts a photo for `person`. `uploaded` decides whether it has a
    /// supabaseStoragePath (so remote re-sync applies to it).
    @discardableResult
    private func addPhoto(
        to person: Person, in context: ModelContext,
        filename: String, uploaded: Bool, profile: Bool = false, sortOrder: Int = 0
    ) -> PersonPhoto {
        let photo = PersonPhoto(
            treeId: person.treeId, personId: person.id, filename: filename,
            supabaseStoragePath: uploaded ? "\(person.treeId.uuidString)/\(person.id.uuidString)/\(filename)" : nil,
            isProfilePhoto: profile, sortOrder: sortOrder
        )
        context.insert(photo)
        photo.person = person
        try? context.save()
        return photo
    }

    // MARK: - Set as profile

    @Test func setAsProfileFlipsFlagsAndReupsertsChangedUploadedRows() async throws {
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        let a = addPhoto(to: person, in: builder.context, filename: "a.jpg", uploaded: true, profile: true, sortOrder: 0)
        let b = addPhoto(to: person, in: builder.context, filename: "b.jpg", uploaded: true, sortOrder: 1)
        let mock = MockPhotoSyncService()
        let vm = PhotoActionsViewModel(photoSync: mock)

        vm.setAsProfile(b, among: [a, b], in: builder.context)
        await vm.awaitPendingSync()

        // local: profile moved to b
        #expect(b.isProfilePhoto)
        #expect(!a.isProfilePhoto)
        // remote: both the old and new profile rows re-upserted (both uploaded)
        let upsertedIds = Set(mock.upserts.map(\.id))
        #expect(upsertedIds == Set([a.id, b.id]))
        #expect(mock.deletes.isEmpty)
    }

    @Test func setAsProfileSkipsRemoteForPendingPhotos() async throws {
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        let a = addPhoto(to: person, in: builder.context, filename: "a.jpg", uploaded: true, profile: true)
        let b = addPhoto(to: person, in: builder.context, filename: "b.jpg", uploaded: false, sortOrder: 1)
        let mock = MockPhotoSyncService()
        let vm = PhotoActionsViewModel(photoSync: mock)

        vm.setAsProfile(b, among: [a, b], in: builder.context)
        await vm.awaitPendingSync()

        #expect(b.isProfilePhoto)
        // only the previously-profile (uploaded) row is re-upserted; pending b is skipped
        #expect(mock.upserts.map(\.id) == [a.id])
    }

    // MARK: - Delete

    @Test func deleteRemovesRowPromotesProfileAndSyncsRemote() async throws {
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        let a = addPhoto(to: person, in: builder.context, filename: "a.jpg", uploaded: true, profile: true)
        let b = addPhoto(to: person, in: builder.context, filename: "b.jpg", uploaded: true, sortOrder: 1)
        let deletedPath = try #require(a.supabaseStoragePath)
        let mock = MockPhotoSyncService()
        let vm = PhotoActionsViewModel(photoSync: mock)

        vm.delete(a, among: [a, b], in: builder.context)
        await vm.awaitPendingSync()

        // local: a gone, b promoted
        #expect(person.photos.count == 1)
        #expect(b.isProfilePhoto)
        // remote: a's object+row deleted, promoted b re-upserted
        #expect(mock.deletes.count == 1)
        let del = try #require(mock.deletes.first)
        #expect(del.id == a.id)
        #expect(del.storagePath == deletedPath)
        #expect(mock.upserts.map(\.id) == [b.id])
    }

    @Test func deletePendingPhotoMakesNoRemoteDelete() async throws {
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        let a = addPhoto(to: person, in: builder.context, filename: "a.jpg", uploaded: false, profile: true)
        let mock = MockPhotoSyncService()
        let vm = PhotoActionsViewModel(photoSync: mock)

        vm.delete(a, among: [a], in: builder.context)
        await vm.awaitPendingSync()

        #expect(person.photos.isEmpty)
        #expect(mock.deletes.isEmpty)   // never uploaded — nothing remote to remove
    }

    // MARK: - Update metadata

    @Test func updateMetadataAppliesLocallyAndReupsertsUploadedRow() async throws {
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        let a = addPhoto(to: person, in: builder.context, filename: "a.jpg", uploaded: true)
        let mock = MockPhotoSyncService()
        let vm = PhotoActionsViewModel(photoSync: mock)

        vm.updateMetadata(a, caption: "  Wedding  ", yearText: "1978", monthText: "6", place: " Pune ", in: builder.context)
        await vm.awaitPendingSync()

        // local: trimmed + parsed
        #expect(a.caption == "Wedding")
        #expect(a.takenYear == 1978)
        #expect(a.takenMonth == 6)
        #expect(a.takenPlace == "Pune")
        // remote: single re-upsert carrying the new caption
        #expect(mock.upserts.count == 1)
        #expect(mock.upserts.first?.id == a.id)
        #expect(mock.upserts.first?.caption == "Wedding")
    }

    @Test func updateMetadataOnPendingPhotoDoesNotReupsert() async throws {
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        let a = addPhoto(to: person, in: builder.context, filename: "a.jpg", uploaded: false)
        let mock = MockPhotoSyncService()
        let vm = PhotoActionsViewModel(photoSync: mock)

        vm.updateMetadata(a, caption: "New", yearText: "", monthText: "", place: "", in: builder.context)
        await vm.awaitPendingSync()

        #expect(a.caption == "New")
        #expect(mock.upserts.isEmpty)   // launch upload will carry current metadata
    }

    // MARK: - Set crop

    @Test func setCropWritesClampedFramingLocallyWithNoRemoteSync() async throws {
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        let a = addPhoto(to: person, in: builder.context, filename: "a.jpg", uploaded: true)
        let mock = MockPhotoSyncService()
        let vm = PhotoActionsViewModel(photoSync: mock)

        // square photo, scale 2 → maxOffset 0.5, so the over-pan clamps.
        vm.setCrop(AvatarCrop(scale: 2, offsetX: 5, offsetY: -0.1), aspectRatio: 1, on: a, in: builder.context)
        await vm.awaitPendingSync()

        // local: clamped framing persisted
        #expect(a.cropScale == 2)
        #expect(a.cropOffsetX == 0.5)
        #expect(a.cropOffsetY == -0.1)
        // crop is local-only for the pilot — never touches the remote, even uploaded
        #expect(mock.upserts.isEmpty)
        #expect(mock.deletes.isEmpty)
    }

    @Test func setCropAllowsPortraitVerticalReframeAtScaleOne() async throws {
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        let a = addPhoto(to: person, in: builder.context, filename: "a.jpg", uploaded: false)
        let vm = PhotoActionsViewModel(photoSync: nil)

        // A tall portrait (aspectRatio 0.5) can be panned vertically at 1× to move a
        // face into the circle — the square-only clamp used to pin this to 0.
        vm.setCrop(AvatarCrop(scale: 1, offsetX: 0, offsetY: 0.3), aspectRatio: 0.5, on: a, in: builder.context)
        await vm.awaitPendingSync()

        #expect(a.cropScale == 1)
        #expect(a.cropOffsetY == 0.3)
    }

    @Test func nilServiceMutatesLocallyWithoutCrashing() async throws {
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        let a = addPhoto(to: person, in: builder.context, filename: "a.jpg", uploaded: true)
        let vm = PhotoActionsViewModel(photoSync: nil)

        vm.updateMetadata(a, caption: "New", yearText: "", monthText: "", place: "", in: builder.context)
        await vm.awaitPendingSync()

        #expect(a.caption == "New")
    }
}
