// PersonUnionLink.swift
// Joins a Person to a Union in one of two roles: partner or child.
// Both back-references stay optional — non-optional back-refs crash on cascade delete.

import Foundation
import SwiftData

/// How a person participates in a union.
enum LinkRole: String, Codable, CaseIterable {
    case partner
    case child
}

/// How a child came into the union. Only meaningful when `role` is `.child`.
enum ChildType: String, Codable, CaseIterable {
    case biological
    case adopted
    case foster
    case step
    case unknown
}

@Model
final class PersonUnionLink {
    var id: UUID
    var role: LinkRole
    /// Nil when `role` is `.partner`.
    var childType: ChildType?

    // No @Relationship macro here — the inverse is declared on Person.links and Union.links.
    var person: Person?
    var union: Union?

    init(
        id: UUID = UUID(),
        role: LinkRole,
        childType: ChildType? = nil
    ) {
        self.id = id
        self.role = role
        self.childType = childType
    }
}
