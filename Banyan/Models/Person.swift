// Person.swift
// A person in a family tree. Nodes of the person-union graph.

import Foundation
import SwiftData

/// Biological sex, used only for tree layout and iconography.
enum Sex: String, Codable, CaseIterable {
    case male
    case female
    case unknown
}

@Model
final class Person {
    var id: UUID
    var treeId: UUID
    var firstName: String
    var lastName: String
    var sex: Sex
    var birthDate: PartialDate?
    var deathDate: PartialDate?
    var birthPlace: String?
    var deathPlace: String?
    /// A stand-in for an unrecorded person, e.g. an unnamed parent needed to attach a union.
    var isPlaceholder: Bool
    /// Filename within the app's documents directory — not a UUID, not a full path.
    var profilePhotoFilename: String?
    var bio: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \PersonUnionLink.person)
    var links: [PersonUnionLink]

    init(
        id: UUID = UUID(),
        treeId: UUID,
        firstName: String,
        lastName: String = "",
        sex: Sex = .unknown,
        birthDate: PartialDate? = nil,
        deathDate: PartialDate? = nil,
        birthPlace: String? = nil,
        deathPlace: String? = nil,
        isPlaceholder: Bool = false,
        profilePhotoFilename: String? = nil,
        bio: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.treeId = treeId
        self.firstName = firstName
        self.lastName = lastName
        self.sex = sex
        self.birthDate = birthDate
        self.deathDate = deathDate
        self.birthPlace = birthPlace
        self.deathPlace = deathPlace
        self.isPlaceholder = isPlaceholder
        self.profilePhotoFilename = profilePhotoFilename
        self.bio = bio
        self.createdAt = createdAt
        self.links = []
    }

    /// First and last name joined, collapsing to whichever part is present.
    var fullName: String {
        [firstName, lastName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Up to two uppercase initials, for avatar placeholders.
    var initials: String {
        [firstName, lastName]
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()
    }

    var isDeceased: Bool {
        deathDate != nil
    }
}
