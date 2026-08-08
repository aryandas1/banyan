// PhotoSyncServiceProtocol.swift
// The photo-sync seam: upload/upsert/delete a photo's bytes+row, and download a
// photo's bytes for a viewer's pull. Kept a protocol (0 executable lines) so the
// ViewModels/coordinator depend on it, not the SDK — the concrete PhotoSyncService
// lives in Networking (off the coverage gate) while the orchestration around it
// stays unit-testable.
//
// Every method takes/returns only Sendable values (DTOs, Data, ids) — never a
// SwiftData @Model or ModelContext. The @MainActor callers read the model's
// fields, load the bytes, call these, and write results back to the model
// themselves; the network layer never touches the (main-actor) store.

import Foundation

protocol PhotoSyncServiceProtocol: AnyObject {
    /// Uploads the image bytes to the `photos` Storage bucket, then upserts the
    /// photo's metadata row. Used on add and on the launch retry.
    func upload(_ photo: PersonPhotoDTO, imageData: Data) async throws

    /// Upserts only the photo's metadata row — caption/date/place/profile flag/
    /// order — for an edit where the image bytes are unchanged.
    func upsertMetadata(_ photo: PersonPhotoDTO) async throws

    /// Removes the image from Storage and deletes the photo's metadata row.
    func delete(id: UUID, storagePath: String) async throws

    /// Downloads the image bytes for a stored photo, for a viewer's pull.
    func download(path: String) async throws -> Data
}
