// PhotoSyncService.swift
// The Supabase-backed PhotoSyncServiceProtocol: uploads/downloads photo bytes to
// the `photos` Storage bucket and upserts/deletes the person_photos row. All
// access control is enforced server-side by RLS (members read, owner writes).
//
// Lives in Networking (not Services) alongside SupabaseRemoteStore/ShareService/
// InviteAcceptanceService because it wraps the live SDK client and can't be
// unit-tested — keeping it off the `make coverage` gate. Injected the shared
// client (no singletons; CLAUDE.md). Operates on Sendable values only — a @Model
// or ModelContext never reaches this layer (see PhotoSyncServiceProtocol).

import Foundation
import Supabase

final class PhotoSyncService: PhotoSyncServiceProtocol {

    private let client: SupabaseClient
    private let bucket = "photos"

    /// Injects the shared Supabase client built at the composition root.
    init(client: SupabaseClient) {
        self.client = client
    }

    func upload(_ photo: PersonPhotoDTO, imageData: Data) async throws {
        // Bytes first: on an FK failure (person row not yet pushed) the upload
        // throws before the row upsert, so the caller leaves supabaseStoragePath
        // nil and the launch retry re-runs this once the person exists.
        _ = try await client.storage
            .from(bucket)
            .upload(photo.storagePath, data: imageData,
                    options: FileOptions(contentType: "image/jpeg", upsert: true))
        try await upsertMetadata(photo)
    }

    func upsertMetadata(_ photo: PersonPhotoDTO) async throws {
        _ = try await client.from("person_photos")
            .upsert(photo, onConflict: "id", returning: .minimal)
            .execute()
    }

    func delete(id: UUID, storagePath: String) async throws {
        // Storage first, then the row. A stale object with no row is harmless
        // (unreferenced); a row pointing at a missing object would surface as a
        // failed download on a viewer's pull.
        _ = try await client.storage.from(bucket).remove(paths: [storagePath])
        _ = try await client.from("person_photos")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func download(path: String) async throws -> Data {
        try await client.storage.from(bucket).download(path: path)
    }
}
