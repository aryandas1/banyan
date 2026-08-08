// PhotoSyncCoordinator.swift
// The owner-side launch retry: re-uploads any local photos that never made it to
// Supabase (a prior session failed mid-upload, or the add happened offline). The
// model reads/writes live here on the main actor; the network service sees only
// Sendable values (a DTO + Data). Kept a small @MainActor struct — stateless and
// injected — so it's unit-testable against an in-memory container + a mock.

import Foundation
import SwiftData
import UIKit

@MainActor
struct PhotoSyncCoordinator {
    /// Re-uploads every local photo for `treeId` still missing a
    /// `supabaseStoragePath`, recording the path on success. Idempotent — a photo
    /// already uploaded is skipped by the predicate, so this is safe to run on
    /// every launch. Best-effort: a still-failing upload is left for the next run.
    /// Owner-only (a viewer has no upload rights; RLS would reject it anyway).
    func uploadPending(treeId: UUID, in context: ModelContext, using photoSync: any PhotoSyncServiceProtocol) async {
        let pending = (try? context.fetch(
            FetchDescriptor<PersonPhoto>(
                predicate: #Predicate { $0.treeId == treeId && $0.supabaseStoragePath == nil }
            )
        )) ?? []

        for photo in pending {
            guard let image = PhotoStorageService.load(filename: photo.filename),
                  let data = image.jpegData(compressionQuality: 0.8) else { continue }
            let dto = PersonPhotoDTO(from: photo)
            do {
                try await photoSync.upload(dto, imageData: data)
                photo.supabaseStoragePath = dto.storagePath
                try? context.save()
            } catch {
                // Best-effort; retried on the next launch.
            }
        }
    }
}
