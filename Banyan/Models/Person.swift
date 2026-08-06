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
    var bio: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \PersonUnionLink.person)
    var links: [PersonUnionLink]

    @Relationship(deleteRule: .cascade, inverse: \PersonPhoto.person)
    var photos: [PersonPhoto]

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
        self.bio = bio
        self.createdAt = createdAt
        self.links = []
        self.photos = []
    }

    /// The photo to show as this person's avatar: the one flagged as profile, or
    /// else the first by sort order. Nil when the person has no photos.
    var profilePhoto: PersonPhoto? {
        photos.first(where: { $0.isProfilePhoto })
            ?? photos.sorted(by: { $0.sortOrder < $1.sortOrder }).first
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
