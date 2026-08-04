// SharedTreeDTOFactory.swift
// Builds the pulled DTOs the sharing flow imports, using the production `init(from:)`
// mappings on standalone models — the same path the app uses to map models to DTOs,
// so tests don't reach for a memberwise init the production DTOs deliberately omit.

import Foundation
@testable import Banyan

enum SharedTreeDTOFactory {
    static func person(
        id: UUID = UUID(),
        treeId: UUID,
        first: String = "A",
        placeholder: Bool = false
    ) -> PersonDTO {
        PersonDTO(from: Person(id: id, treeId: treeId, firstName: first, isPlaceholder: placeholder))
    }

    static func union(id: UUID = UUID(), treeId: UUID) -> UnionDTO {
        UnionDTO(from: Union(id: id, treeId: treeId, type: .married))
    }

    static func link(
        id: UUID = UUID(),
        treeId: UUID,
        personId: UUID,
        unionId: UUID,
        role: LinkRole
    ) -> PersonUnionLinkDTO {
        let person = Person(id: personId, treeId: treeId, firstName: "")
        let union = Union(id: unionId, treeId: treeId)
        let link = PersonUnionLink(id: id, role: role, childType: role == .child ? .biological : nil)
        link.person = person
        link.union = union
        // Non-nil by construction (both endpoints set) — force unwrap allowed in tests.
        return PersonUnionLinkDTO(from: link)!
    }
}
