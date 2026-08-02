// SupabaseDTOs.swift
// Codable structs that map between the SwiftData models and Supabase JSON.
// Pure data mapping — no business logic. Column names are snake_case to match
// the Postgres schema; PartialDate encodes straight into the jsonb columns.

import Foundation

// MARK: - Tree

struct TreeDTO: Codable, Equatable {
    let id: UUID
    let name: String
    let ownerId: UUID

    enum CodingKeys: String, CodingKey {
        case id, name
        case ownerId = "owner_id"
    }
}

// MARK: - Person

struct PersonDTO: Codable, Equatable {
    let id: UUID
    let treeId: UUID
    let firstName: String
    let lastName: String
    let sex: String
    let birthDate: PartialDate?
    let deathDate: PartialDate?
    let birthPlace: String?
    let deathPlace: String?
    let isPlaceholder: Bool
    let bio: String?
    // profile_photo_url is deferred to the rich-content phase — it syncs as null.

    enum CodingKeys: String, CodingKey {
        case id
        case treeId        = "tree_id"
        case firstName     = "first_name"
        case lastName      = "last_name"
        case sex
        case birthDate     = "birth_date"
        case deathDate     = "death_date"
        case birthPlace    = "birth_place"
        case deathPlace    = "death_place"
        case isPlaceholder = "is_placeholder"
        case bio
    }

    init(from person: Person) {
        self.id            = person.id
        self.treeId        = person.treeId
        self.firstName     = person.firstName
        self.lastName      = person.lastName
        self.sex           = person.sex.rawValue
        self.birthDate     = person.birthDate
        self.deathDate     = person.deathDate
        self.birthPlace    = person.birthPlace
        self.deathPlace    = person.deathPlace
        self.isPlaceholder = person.isPlaceholder
        self.bio           = person.bio
    }
}

// MARK: - Union

struct UnionDTO: Codable, Equatable {
    let id: UUID
    let treeId: UUID
    let type: String
    let startDate: PartialDate?
    let endDate: PartialDate?
    let endReason: String?

    enum CodingKeys: String, CodingKey {
        case id
        case treeId    = "tree_id"
        case type
        case startDate = "start_date"
        case endDate   = "end_date"
        case endReason = "end_reason"
    }

    init(from union: Union) {
        self.id        = union.id
        self.treeId    = union.treeId
        self.type      = union.type.rawValue
        self.startDate = union.startDate
        self.endDate   = union.endDate
        self.endReason = union.endReason?.rawValue
    }
}

// MARK: - PersonUnionLink

struct PersonUnionLinkDTO: Codable, Equatable {
    let id: UUID
    let treeId: UUID
    let personId: UUID
    let unionId: UUID
    let role: String
    let childType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case treeId    = "tree_id"
        case personId  = "person_id"
        case unionId   = "union_id"
        case role
        case childType = "child_type"
    }

    /// Nil for a dangling link (person or union not set) — such a link isn't a
    /// valid row and is skipped by the sync. The model has no `treeId` of its
    /// own, so it's derived from the linked person.
    init?(from link: PersonUnionLink) {
        guard let person = link.person, let union = link.union else { return nil }
        self.id        = link.id
        self.treeId    = person.treeId
        self.personId  = person.id
        self.unionId   = union.id
        self.role      = link.role.rawValue
        self.childType = link.childType?.rawValue
    }
}

// MARK: - ID-only helper (orphan detection)

struct IDRow: Decodable {
    let id: UUID
}
