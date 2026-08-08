// AddPhotoViewModel.swift
// Backs the add-photo sheet: holds the picked image + metadata fields, auto-fills
// the date from EXIF, and writes a PersonPhoto (plus its file on disk) into
// SwiftData. @MainActor because it drives a view.

import Foundation
import Observation
import SwiftData
import UIKit

enum PhotoSaveError: LocalizedError {
    case noImageSelected
    case failedToWriteToDisk

    var errorDescription: String? {
        switch self {
        case .noImageSelected: return "No photo selected."
        case .failedToWriteToDisk: return "Could not save the photo. Please try again."
        }
    }
}

@MainActor
@Observable
final class AddPhotoViewModel {

    // Inputs
    var selectedImage: UIImage?
    var caption: String
    var takenYearText: String
    var takenMonthText: String
    var takenPlace: String
    var setAsProfilePhoto: Bool

    // State
    var isSaving: Bool
    var saveError: Error?

    /// The in-flight background upload of the just-saved photo, if any. Exposed so
    /// tests can await it deterministically (mirrors SyncService.awaitPendingSync).
    @ObservationIgnored private(set) var pendingUpload: Task<Void, Never>?

    /// The typed year as an Int, ignoring implausible values.
    var takenYear: Int? { Int(takenYearText).flatMap { $0 > 1800 ? $0 : nil } }

    /// The typed month as an Int, only when in 1...12.
    var takenMonth: Int? {
        guard let m = Int(takenMonthText), (1...12).contains(m) else { return nil }
        return m
    }

    init(setAsProfilePhoto: Bool = false) {
        self.selectedImage = nil
        self.caption = ""
        self.takenYearText = ""
        self.takenMonthText = ""
        self.takenPlace = ""
        self.setAsProfilePhoto = setAsProfilePhoto
        self.isSaving = false
        self.saveError = nil
    }

    /// Records a freshly picked image and, if the date fields are still empty,
    /// auto-fills year/month from the image's EXIF metadata.
    func onImageSelected(image: UIImage, data: Data?) {
        selectedImage = image
        if takenYearText.isEmpty,
           let data,
           let date = PhotoStorageService.extractTakenDate(from: data) {
            takenYearText = String(date.year)
            takenMonthText = String(date.month)
        }
    }

    /// Writes the image to disk and inserts a PersonPhoto for `person`. The first
    /// photo (or one the user marked) becomes the profile photo, unsetting any
    /// prior profile photo. Throws if nothing is selected or the write fails. Then
    /// kicks a background upload via `photoSync` (nil in previews / when signed
    /// out); the local save has already succeeded, so an upload failure is
    /// non-fatal and the launch retry re-runs it.
    func save(for person: Person, in context: ModelContext, photoSync: (any PhotoSyncServiceProtocol)?) async throws {
        guard let image = selectedImage else { throw PhotoSaveError.noImageSelected }
        isSaving = true
        defer { isSaving = false }

        guard let filename = PhotoStorageService.save(image) else {
            throw PhotoSaveError.failedToWriteToDisk
        }

        let isProfile = setAsProfilePhoto || person.photos.isEmpty
        // Photos that will lose their profile flag AND already exist remotely need
        // their rows re-upserted too, else the backend keeps two is_profile_photo
        // rows and a viewer's pull shows the wrong avatar. Captured before the flip.
        let demotedProfiles = isProfile
            ? person.photos.filter { $0.isProfilePhoto && $0.supabaseStoragePath != nil }
            : []
        if isProfile {
            person.photos.forEach { $0.isProfilePhoto = false }
        }

        let photo = PersonPhoto(
            treeId: person.treeId,
            personId: person.id,
            filename: filename,
            caption: caption.trimmingCharacters(in: .whitespaces).nonEmptyOrNil,
            takenYear: takenYear,
            takenMonth: takenMonth,
            takenPlace: takenPlace.trimmingCharacters(in: .whitespaces).nonEmptyOrNil,
            isProfilePhoto: isProfile,
            // One past the current max, so ordering survives deletions (count would
            // collide with an existing sortOrder once any earlier photo is removed).
            sortOrder: (person.photos.map(\.sortOrder).max() ?? -1) + 1
        )

        // Insert before wiring the relationship (SwiftData insert-before-link rule).
        context.insert(photo)
        photo.person = person
        try context.save()

        scheduleUpload(of: photo, image: image, demoted: demotedProfiles, photoSync: photoSync, in: context)
    }

    /// Uploads the saved photo's bytes+row in the background and, only on success,
    /// records `supabaseStoragePath` on the model. Also re-upserts any `demoted`
    /// previous profile photos so the backend keeps a single profile row. The Task
    /// inherits this VM's @MainActor isolation, so the model reads/writes stay on
    /// the main actor and only Sendable values (DTOs + Data) cross into the service.
    private func scheduleUpload(
        of photo: PersonPhoto,
        image: UIImage,
        demoted: [PersonPhoto],
        photoSync: (any PhotoSyncServiceProtocol)?,
        in context: ModelContext
    ) {
        guard let photoSync else { return }
        let dto = PersonPhotoDTO(from: photo)
        let imageData = image.jpegData(compressionQuality: 0.8)
        // Build the demoted rows now (after the flag flip) so only Sendable DTOs,
        // not @Models, cross into the Task.
        let demotedDTOs = demoted.map(PersonPhotoDTO.init(from:))
        pendingUpload = Task {
            if let imageData {
                do {
                    try await photoSync.upload(dto, imageData: imageData)
                    photo.supabaseStoragePath = dto.storagePath
                    try? context.save()
                } catch {
                    // Non-fatal: the photo is saved locally; syncPending retries later.
                }
            }
            // Independent of the new upload's success — the old profile must be
            // demoted remotely regardless.
            for demotedDTO in demotedDTOs {
                try? await photoSync.upsertMetadata(demotedDTO)
            }
        }
    }

    /// Awaits the in-flight background upload, if any. Used by tests to assert the
    /// upload deterministically; harmless in production.
    func awaitPendingUpload() async {
        await pendingUpload?.value
    }
}
