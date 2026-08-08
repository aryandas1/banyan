// PhotoSyncCoordinatorTests.swift
// The owner-side launch retry: uploads only the photos still missing a
// supabaseStoragePath, reads their bytes from disk, and records the path on
// success. Against an in-memory container + a mock; writes real files (as the app
// does) and cleans them up.

import Foundation
import SwiftData
import Testing
import UIKit
@testable import Banyan

@MainActor
@Suite("PhotoSyncCoordinator")
struct PhotoSyncCoordinatorTests {

    private func makeImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        return renderer.image { ctx in
            UIColor.systemPink.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }

    /// Inserts a photo whose bytes are really on disk, returning it.
    @discardableResult
    private func addPhotoWithFile(to person: Person, in context: ModelContext, uploaded: Bool) throws -> PersonPhoto {
        let filename = try #require(PhotoStorageService.save(makeImage()))
        let photo = PersonPhoto(
            treeId: person.treeId, personId: person.id, filename: filename,
            supabaseStoragePath: uploaded ? "already/\(filename)" : nil
        )
        context.insert(photo)
        photo.person = person
        try context.save()
        return photo
    }

    @Test func uploadsPendingPhotosAndRecordsPath() async throws {
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let person = builder.makePerson(firstName: "Ravi", treeId: treeId)
        let pending = try addPhotoWithFile(to: person, in: builder.context, uploaded: false)
        let mock = MockPhotoSyncService()

        await PhotoSyncCoordinator().uploadPending(treeId: treeId, in: builder.context, using: mock)

        // the pending photo was uploaded with its bytes and its path recorded
        #expect(mock.uploads.count == 1)
        let uploaded = try #require(mock.uploads.first)
        #expect(uploaded.dto.id == pending.id)
        #expect(!uploaded.imageData.isEmpty)
        #expect(pending.supabaseStoragePath == uploaded.dto.storagePath)

        PhotoStorageService.delete(filename: pending.filename)
    }

    @Test func skipsAlreadyUploadedPhotos() async throws {
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let person = builder.makePerson(firstName: "Ravi", treeId: treeId)
        let done = try addPhotoWithFile(to: person, in: builder.context, uploaded: true)
        let pending = try addPhotoWithFile(to: person, in: builder.context, uploaded: false)
        let mock = MockPhotoSyncService()

        await PhotoSyncCoordinator().uploadPending(treeId: treeId, in: builder.context, using: mock)

        // only the pending one is uploaded; the finished one is left alone
        #expect(mock.uploads.map(\.dto.id) == [pending.id])

        PhotoStorageService.delete(filename: done.filename)
        PhotoStorageService.delete(filename: pending.filename)
    }

    @Test func uploadFailureLeavesPathNilForNextLaunch() async throws {
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let person = builder.makePerson(firstName: "Ravi", treeId: treeId)
        let pending = try addPhotoWithFile(to: person, in: builder.context, uploaded: false)
        let mock = MockPhotoSyncService()
        mock.errorToThrow = URLError(.notConnectedToInternet)

        await PhotoSyncCoordinator().uploadPending(treeId: treeId, in: builder.context, using: mock)

        #expect(pending.supabaseStoragePath == nil)

        PhotoStorageService.delete(filename: pending.filename)
    }

    @Test func scopesToTheGivenTree() async throws {
        let builder = try TestTreeBuilder()
        let treeA = UUID(), treeB = UUID()
        let personA = builder.makePerson(firstName: "A", treeId: treeA)
        let personB = builder.makePerson(firstName: "B", treeId: treeB)
        let a = try addPhotoWithFile(to: personA, in: builder.context, uploaded: false)
        let b = try addPhotoWithFile(to: personB, in: builder.context, uploaded: false)
        let mock = MockPhotoSyncService()

        await PhotoSyncCoordinator().uploadPending(treeId: treeA, in: builder.context, using: mock)

        #expect(mock.uploads.map(\.dto.id) == [a.id])

        PhotoStorageService.delete(filename: a.filename)
        PhotoStorageService.delete(filename: b.filename)
    }
}
