// PhotoActionsViewModel.swift
// The mutation logic behind the photo-detail menu and the edit-metadata sheet:
// set-as-profile, delete, and metadata edits. Extracted out of the views (step-13
// review finding #4) so each mutation does the local SwiftData write AND keeps
// Supabase in step — an edit re-upserts the changed row(s), a delete removes the
// object + row. @MainActor: it reads/writes @Models directly, and hands the
// network service only Sendable values (DTOs, ids, paths).

import Foundation
import Observation
import SwiftData
import UIKit

@MainActor
@Observable
final class PhotoActionsViewModel {

    private let photoSync: (any PhotoSyncServiceProtocol)?

    /// The in-flight background re-sync of the mutated row(s), if any. Exposed so
    /// tests can await it deterministically (mirrors AddPhotoViewModel).
    @ObservationIgnored private(set) var pendingSync: Task<Void, Never>?

    /// - Parameter photoSync: the sync service, or nil (previews / signed out) to
    ///   mutate locally only.
    init(photoSync: (any PhotoSyncServiceProtocol)?) {
        self.photoSync = photoSync
    }

    /// A queued remote change — computed on the main actor from the (now-updated)
    /// models, then run off it, so no @Model crosses the actor boundary.
    private enum RemoteOp {
        case upsert(PersonPhotoDTO)
        case delete(id: UUID, storagePath: String)
    }

    /// Makes `photo` the profile photo among `photos`, unsetting the previous one,
    /// saves, then re-upserts every row whose flag changed (uploaded photos only —
    /// a pending photo's launch upload carries its current flag anyway).
    func setAsProfile(_ photo: PersonPhoto, among photos: [PersonPhoto], in context: ModelContext) {
        let previousProfiles = photos.filter { $0.isProfilePhoto && $0.id != photo.id }
        photos.forEach { $0.isProfilePhoto = false }
        photo.isProfilePhoto = true
        try? context.save()

        let changed = previousProfiles + [photo]
        schedule(changed.filter { $0.supabaseStoragePath != nil }.map { .upsert(PersonPhotoDTO(from: $0)) })
    }

    /// Deletes `photo` from `photos`: promotes another to profile if it was the
    /// profile, drops the local file + row, then removes the remote object + row
    /// (and re-upserts the promoted photo). The caller dismisses the view.
    func delete(_ photo: PersonPhoto, among photos: [PersonPhoto], in context: ModelContext) {
        let removedId = photo.id
        let removedPath = photo.supabaseStoragePath

        var promoted: PersonPhoto?
        if photo.isProfilePhoto {
            promoted = photos.first(where: { $0.id != removedId })
            promoted?.isProfilePhoto = true
        }
        PhotoStorageService.delete(filename: photo.filename)
        context.delete(photo)
        try? context.save()

        var ops: [RemoteOp] = []
        if let promoted, promoted.supabaseStoragePath != nil {
            ops.append(.upsert(PersonPhotoDTO(from: promoted)))
        }
        if let removedPath {
            ops.append(.delete(id: removedId, storagePath: removedPath))
        }
        schedule(ops)
    }

    /// Applies edited caption / date / place to `photo`, saves, and re-upserts the
    /// row (uploaded photos only). Mirrors the parsing AddPhotoViewModel uses.
    func updateMetadata(
        _ photo: PersonPhoto,
        caption: String,
        yearText: String,
        monthText: String,
        place: String,
        in context: ModelContext
    ) {
        photo.caption    = caption.trimmingCharacters(in: .whitespaces).nonEmptyOrNil
        photo.takenYear  = Int(yearText).flatMap { $0 > 1800 ? $0 : nil }
        photo.takenMonth = Int(monthText).flatMap { (1...12).contains($0) ? $0 : nil }
        photo.takenPlace = place.trimmingCharacters(in: .whitespaces).nonEmptyOrNil
        try? context.save()

        guard photo.supabaseStoragePath != nil else { return }
        schedule([.upsert(PersonPhotoDTO(from: photo))])
    }

    /// Runs the queued remote ops in order on a background task (best-effort — a
    /// failure leaves the local edit in place; the next pull/retry reconciles).
    private func schedule(_ ops: [RemoteOp]) {
        guard let photoSync, !ops.isEmpty else { return }
        pendingSync = Task {
            for op in ops {
                do {
                    switch op {
                    case .upsert(let dto):
                        try await photoSync.upsertMetadata(dto)
                    case .delete(let id, let storagePath):
                        try await photoSync.delete(id: id, storagePath: storagePath)
                    }
                } catch {
                    // Best-effort; local state is already updated.
                }
            }
        }
    }

    /// Awaits the in-flight remote re-sync, if any. Used by tests; harmless in prod.
    func awaitPendingSync() async {
        await pendingSync?.value
    }
}
