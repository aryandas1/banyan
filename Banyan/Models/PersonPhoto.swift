// PersonPhoto.swift
// A photo attached to a Person, stored locally by filename in the documents
// directory (the bytes never live in SwiftData). `supabaseStoragePath` is a
// placeholder for step 14, when photos start syncing.

import Foundation
import SwiftData

@Model
final class PersonPhoto {
    var id: UUID
    var treeId: UUID
    /// Denormalised owner id — kept for the step-14 Supabase queries, so a photo
    /// row can be matched to its person without a join.
    var personId: UUID
    /// Local file in the app's documents directory — filename only, not a path.
    var filename: String
    /// Set in step 14 once the photo is uploaded; nil while local-only.
    var supabaseStoragePath: String?
    var caption: String?
    var takenYear: Int?
    var takenMonth: Int?
    var takenPlace: String?
    var isProfilePhoto: Bool
    var sortOrder: Int
    var createdAt: Date

    /// How the round avatar frames this photo (the full photo in the gallery is
    /// never altered). `1 / 0 / 0` = no crop — the image fills the circle. Offsets
    /// are fractions of the circle's diameter; see `AvatarCrop`. Local-only for the
    /// pilot: not carried on `PersonPhotoDTO`, so viewers see the uncropped avatar
    /// and an owner reinstall loses the framing (development-plan §0.9 follow-up).
    var cropScale: Double
    var cropOffsetX: Double
    var cropOffsetY: Double

    /// Back-reference to the owning person. Optional so a cascade delete of the
    /// person doesn't crash while SwiftData tears the relationship down.
    var person: Person?

    init(
        id: UUID = UUID(),
        treeId: UUID,
        personId: UUID,
        filename: String,
        supabaseStoragePath: String? = nil,
        caption: String? = nil,
        takenYear: Int? = nil,
        takenMonth: Int? = nil,
        takenPlace: String? = nil,
        isProfilePhoto: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        cropScale: Double = 1,
        cropOffsetX: Double = 0,
        cropOffsetY: Double = 0
    ) {
        self.id = id
        self.treeId = treeId
        self.personId = personId
        self.filename = filename
        self.supabaseStoragePath = supabaseStoragePath
        self.caption = caption
        self.takenYear = takenYear
        self.takenMonth = takenMonth
        self.takenPlace = takenPlace
        self.isProfilePhoto = isProfilePhoto
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.cropScale = cropScale
        self.cropOffsetX = cropOffsetX
        self.cropOffsetY = cropOffsetY
        self.person = nil
    }

    /// Localized month names, computed once rather than per `takenDateDisplay` call.
    private static let monthSymbols = DateFormatter().monthSymbols ?? []

    /// A human-readable "when taken" line: "June 1967", "1967", or nil when no
    /// year is recorded. Month is only shown when the year is present.
    var takenDateDisplay: String? {
        guard let year = takenYear else { return nil }
        if let month = takenMonth,
           let monthName = Self.monthSymbols[safe: month - 1] {
            return "\(monthName) \(year)"
        }
        return String(year)
    }
}
