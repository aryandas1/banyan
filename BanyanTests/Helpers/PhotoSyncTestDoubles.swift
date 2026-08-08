// PhotoSyncTestDoubles.swift
// In-memory PhotoSyncServiceProtocol that records every call and can be primed
// with an error or download bytes — so the photo ViewModels / importer flow can be
// asserted without any real Supabase Storage or PostgREST traffic.

import Foundation
@testable import Banyan

@MainActor
final class MockPhotoSyncService: PhotoSyncServiceProtocol {
    private(set) var uploads: [(dto: PersonPhotoDTO, imageData: Data)] = []
    private(set) var upserts: [PersonPhotoDTO] = []
    private(set) var deletes: [(id: UUID, storagePath: String)] = []
    private(set) var downloads: [String] = []

    /// Bytes returned by `download`; default is empty Data.
    var downloadData = Data()
    /// Thrown from every method when set (simulates offline / RLS rejection).
    var errorToThrow: Error?

    func upload(_ photo: PersonPhotoDTO, imageData: Data) async throws {
        if let errorToThrow { throw errorToThrow }
        uploads.append((photo, imageData))
    }

    func upsertMetadata(_ photo: PersonPhotoDTO) async throws {
        if let errorToThrow { throw errorToThrow }
        upserts.append(photo)
    }

    func delete(id: UUID, storagePath: String) async throws {
        if let errorToThrow { throw errorToThrow }
        deletes.append((id, storagePath))
    }

    func download(path: String) async throws -> Data {
        if let errorToThrow { throw errorToThrow }
        downloads.append(path)
        return downloadData
    }
}
