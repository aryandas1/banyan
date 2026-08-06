// SharedTreeImporterTests.swift
// The @MainActor importer that applies a pulled snapshot to SwiftData, against an
// in-memory container built inline per test. Covers insert, idempotent re-import
// (upsert-by-id), relationship wiring, and dangling-link skipping.

import Foundation
import SwiftData
import Testing
@testable import Banyan

@MainActor
@Suite("SharedTreeImporter")
struct SharedTreeImporterTests {

    // MARK: - Fixtures

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Schema(BanyanSchemaV2.models), configurations: config)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private func personDTO(_ id: UUID, treeId: UUID, first: String = "A", placeholder: Bool = false) -> PersonDTO {
        SharedTreeDTOFactory.person(id: id, treeId: treeId, first: first, placeholder: placeholder)
    }

    private func unionDTO(_ id: UUID, treeId: UUID) -> UnionDTO {
        SharedTreeDTOFactory.union(id: id, treeId: treeId)
    }

    private func linkDTO(_ id: UUID, treeId: UUID, person: UUID, union: UUID, role: LinkRole) -> PersonUnionLinkDTO {
        SharedTreeDTOFactory.link(id: id, treeId: treeId, personId: person, unionId: union, role: role)
    }

    /// A couple + one child snapshot.
    private func familySnapshot(treeId: UUID) -> (SharedTreeSnapshot, parent: UUID, child: UUID) {
        let parent = UUID(), partner = UUID(), child = UUID(), union = UUID()
        let snapshot = SharedTreeSnapshot(
            persons: [personDTO(parent, treeId: treeId, first: "Parent"),
                      personDTO(partner, treeId: treeId, first: "Partner"),
                      personDTO(child, treeId: treeId, first: "Child")],
            unions: [unionDTO(union, treeId: treeId)],
            links: [linkDTO(UUID(), treeId: treeId, person: parent, union: union, role: .partner),
                    linkDTO(UUID(), treeId: treeId, person: partner, union: union, role: .partner),
                    linkDTO(UUID(), treeId: treeId, person: child, union: union, role: .child)]
        )
        return (snapshot, parent, child)
    }

    // MARK: - Tests

    @Test func importsPersonsUnionsAndLinks() throws {
        // Given an empty store and a family snapshot
        let context = try makeContext()
        let treeId = UUID()
        let (snapshot, _, _) = familySnapshot(treeId: treeId)

        // When importing
        _ = try SharedTreeImporter().importTree(snapshot, treeId: treeId, into: context)

        // Then all rows landed with their ids preserved
        #expect(try context.fetch(FetchDescriptor<Person>()).count == 3)
        #expect(try context.fetch(FetchDescriptor<Union>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<PersonUnionLink>()).count == 3)
    }

    @Test func wiresLinkRelationships() throws {
        let context = try makeContext()
        let treeId = UUID()
        let (snapshot, _, child) = familySnapshot(treeId: treeId)

        _ = try SharedTreeImporter().importTree(snapshot, treeId: treeId, into: context)

        // The child's link points at both a person and a union
        let childId = child
        let childPerson = try #require(
            try context.fetch(FetchDescriptor<Person>(predicate: #Predicate { $0.id == childId })).first
        )
        let childLink = try #require(childPerson.links.first)
        #expect(childLink.role == .child)
        #expect(childLink.union != nil)
    }

    @Test func reimportIsIdempotentAndUpdatesFields() throws {
        // Given a tree already imported once
        let context = try makeContext()
        let treeId = UUID()
        let (snapshot, parent, _) = familySnapshot(treeId: treeId)
        _ = try SharedTreeImporter().importTree(snapshot, treeId: treeId, into: context)

        // When the parent's name changes remotely and we re-import
        let renamed = SharedTreeSnapshot(
            persons: snapshot.persons.map { dto in
                dto.id == parent ? personDTO(parent, treeId: treeId, first: "Renamed") : dto
            },
            unions: snapshot.unions,
            links: snapshot.links
        )
        _ = try SharedTreeImporter().importTree(renamed, treeId: treeId, into: context)

        // Then no rows duplicated and the field updated in place
        #expect(try context.fetch(FetchDescriptor<Person>()).count == 3)
        #expect(try context.fetch(FetchDescriptor<PersonUnionLink>()).count == 3)
        let parentId = parent
        let parentPerson = try #require(
            try context.fetch(FetchDescriptor<Person>(predicate: #Predicate { $0.id == parentId })).first
        )
        #expect(parentPerson.firstName == "Renamed")
    }

    @Test func skipsLinkWithMissingEndpoints() throws {
        // Given a link that references a person not present in the snapshot
        let context = try makeContext()
        let treeId = UUID()
        let realPerson = UUID(), union = UUID(), ghost = UUID()
        let snapshot = SharedTreeSnapshot(
            persons: [personDTO(realPerson, treeId: treeId)],
            unions: [unionDTO(union, treeId: treeId)],
            links: [linkDTO(UUID(), treeId: treeId, person: ghost, union: union, role: .partner)]
        )

        // When importing
        _ = try SharedTreeImporter().importTree(snapshot, treeId: treeId, into: context)

        // Then the dangling link is skipped
        #expect(try context.fetch(FetchDescriptor<PersonUnionLink>()).isEmpty)
    }

    @Test func returnsChosenRoot() throws {
        let context = try makeContext()
        let treeId = UUID()
        let (snapshot, parent, child) = familySnapshot(treeId: treeId)

        let root = try SharedTreeImporter().importTree(snapshot, treeId: treeId, into: context)

        // Root is a top ancestor with descendants — never the child
        #expect(root != child)
        #expect(root == parent || root == snapshot.persons[1].id) // parent or partner
    }

    // MARK: - Orphan pruning (re-pull reflects the owner's deletions)

    @Test func removesPersonDeletedFromSnapshot() throws {
        // Given a family already imported once
        let context = try makeContext()
        let treeId = UUID()
        let (snapshot, _, child) = familySnapshot(treeId: treeId)
        _ = try SharedTreeImporter().importTree(snapshot, treeId: treeId, into: context)

        // When the owner deletes the child and the viewer re-pulls (child + its link gone)
        let withoutChild = SharedTreeSnapshot(
            persons: snapshot.persons.filter { $0.id != child },
            unions: snapshot.unions,
            links: snapshot.links.filter { $0.personId != child }
        )
        _ = try SharedTreeImporter().importTree(withoutChild, treeId: treeId, into: context)

        // Then the child (and its cascaded link) are gone — no ghost rows
        let childId = child
        #expect(try context.fetch(
            FetchDescriptor<Person>(predicate: #Predicate { $0.id == childId })
        ).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Person>()).count == 2)
        #expect(try context.fetch(FetchDescriptor<PersonUnionLink>()).count == 2)
    }

    @Test func removesUnlinkedLinkWhenEndpointsSurvive() throws {
        // Given a family already imported once
        let context = try makeContext()
        let treeId = UUID()
        let (snapshot, _, child) = familySnapshot(treeId: treeId)
        _ = try SharedTreeImporter().importTree(snapshot, treeId: treeId, into: context)

        // When the owner unlinks the child but the child stays in the tree
        let unlinked = SharedTreeSnapshot(
            persons: snapshot.persons,
            unions: snapshot.unions,
            links: snapshot.links.filter { $0.personId != child }
        )
        _ = try SharedTreeImporter().importTree(unlinked, treeId: treeId, into: context)

        // Then only the removed link is pruned; all three people remain
        #expect(try context.fetch(FetchDescriptor<Person>()).count == 3)
        #expect(try context.fetch(FetchDescriptor<PersonUnionLink>()).count == 2)
    }

    @Test func pruneIsScopedToTheImportedTree() throws {
        // Given tree A already imported
        let context = try makeContext()
        let treeA = UUID(), treeB = UUID()
        let (snapA, _, _) = familySnapshot(treeId: treeA)
        _ = try SharedTreeImporter().importTree(snapA, treeId: treeA, into: context)

        // When importing an unrelated tree B
        let (snapB, _, _) = familySnapshot(treeId: treeB)
        _ = try SharedTreeImporter().importTree(snapB, treeId: treeB, into: context)

        // Then tree A's rows are untouched by tree B's prune pass
        let a = treeA
        #expect(try context.fetch(
            FetchDescriptor<Person>(predicate: #Predicate { $0.treeId == a })
        ).count == 3)
        #expect(try context.fetch(FetchDescriptor<Person>()).count == 6)
    }
}
