// SharedTreeImporter.swift
// Applies a pulled SharedTreeSnapshot to the local SwiftData store, upserting by
// id so re-pulls (on accept and on each launch) are idempotent. Runs on the main
// actor because ModelContext is not thread-safe — the network layer hands over
// plain DTOs and this is the only place that touches the context.
//
// A struct (like SupabaseRemoteStore) — stateless, injected into the ViewModel.
// Unit-testable against an in-memory ModelContainer.

import Foundation
import SwiftData

@MainActor
struct SharedTreeImporter {
    /// Upserts persons, unions, then links (links reference the first two, so they
    /// come last), then prunes local rows the snapshot no longer contains so a
    /// viewer's re-pull reflects the owner's deletions/unlinks — not just additions.
    /// Returns a chosen focal/root for the viewer, or nil for an empty tree. Throws
    /// if a context write fails.
    @discardableResult
    func importTree(_ snapshot: SharedTreeSnapshot, treeId: UUID, into context: ModelContext) throws -> UUID? {
        try upsertPersons(snapshot.persons, into: context)
        try upsertUnions(snapshot.unions, into: context)
        try context.save()
        try upsertLinks(snapshot.links, into: context)
        try context.save()
        try pruneOrphans(snapshot, treeId: treeId, into: context)
        return ViewerRootPicker.pickRoot(persons: snapshot.persons, links: snapshot.links)
    }

    /// Deletes local rows for this tree that are absent from the snapshot: persons
    /// and unions the owner removed (their links cascade away), then any link the
    /// owner unlinked while both endpoints survived. Mirrors the owner-side
    /// SyncService orphan cleanup, in the opposite direction.
    private func pruneOrphans(_ snapshot: SharedTreeSnapshot, treeId: UUID, into context: ModelContext) throws {
        let personIds = Set(snapshot.persons.map(\.id))
        let unionIds = Set(snapshot.unions.map(\.id))
        let linkIds = Set(snapshot.links.map(\.id))

        let localPersons = try context.fetch(
            FetchDescriptor<Person>(predicate: #Predicate { $0.treeId == treeId })
        )
        for person in localPersons where !personIds.contains(person.id) {
            context.delete(person)   // cascades this person's links
        }
        let localUnions = try context.fetch(
            FetchDescriptor<Union>(predicate: #Predicate { $0.treeId == treeId })
        )
        for union in localUnions where !unionIds.contains(union.id) {
            context.delete(union)    // cascades this union's links
        }
        try context.save()

        // Re-fetch AFTER the save so cascade-deleted links (which linger in memory
        // until save/refetch) don't reappear here; scope by the linked person's
        // tree since PersonUnionLink has no treeId of its own. What remains and is
        // still absent from the snapshot is an unlink whose endpoints survived.
        let localLinks = try context.fetch(FetchDescriptor<PersonUnionLink>())
        for link in localLinks where link.person?.treeId == treeId && !linkIds.contains(link.id) {
            context.delete(link)
        }
        try context.save()
    }

    private func upsertPersons(_ dtos: [PersonDTO], into context: ModelContext) throws {
        for dto in dtos {
            let id = dto.id
            let existing = try context.fetch(
                FetchDescriptor<Person>(predicate: #Predicate { $0.id == id })
            ).first
            if let person = existing {
                person.firstName     = dto.firstName
                person.lastName      = dto.lastName
                person.sex           = Sex(rawValue: dto.sex) ?? .unknown
                person.birthDate     = dto.birthDate
                person.deathDate     = dto.deathDate
                person.birthPlace    = dto.birthPlace
                person.deathPlace    = dto.deathPlace
                person.isPlaceholder = dto.isPlaceholder
                person.bio           = dto.bio
            } else {
                let person = Person(
                    id:            dto.id,
                    treeId:        dto.treeId,
                    firstName:     dto.firstName,
                    lastName:      dto.lastName,
                    sex:           Sex(rawValue: dto.sex) ?? .unknown,
                    birthDate:     dto.birthDate,
                    deathDate:     dto.deathDate,
                    birthPlace:    dto.birthPlace,
                    deathPlace:    dto.deathPlace,
                    isPlaceholder: dto.isPlaceholder,
                    bio:           dto.bio
                )
                context.insert(person)
            }
        }
    }

    private func upsertUnions(_ dtos: [UnionDTO], into context: ModelContext) throws {
        for dto in dtos {
            let id = dto.id
            let existing = try context.fetch(
                FetchDescriptor<Union>(predicate: #Predicate { $0.id == id })
            ).first
            if let union = existing {
                union.type      = UnionType(rawValue: dto.type) ?? .unknown
                union.startDate = dto.startDate
                union.endDate   = dto.endDate
                union.endReason = dto.endReason.flatMap { EndReason(rawValue: $0) }
            } else {
                let union = Union(
                    id:        dto.id,
                    treeId:    dto.treeId,
                    type:      UnionType(rawValue: dto.type) ?? .unknown,
                    startDate: dto.startDate,
                    endDate:   dto.endDate,
                    endReason: dto.endReason.flatMap { EndReason(rawValue: $0) }
                )
                context.insert(union)
            }
        }
    }

    private func upsertLinks(_ dtos: [PersonUnionLinkDTO], into context: ModelContext) throws {
        for dto in dtos {
            let id = dto.id
            let exists = try context.fetch(
                FetchDescriptor<PersonUnionLink>(predicate: #Predicate { $0.id == id })
            ).first != nil
            guard !exists else { continue }

            // Skip a link whose endpoints didn't come through — it isn't a valid row.
            let personId = dto.personId
            let unionId = dto.unionId
            guard let person = try context.fetch(
                      FetchDescriptor<Person>(predicate: #Predicate { $0.id == personId })
                  ).first,
                  let union = try context.fetch(
                      FetchDescriptor<Union>(predicate: #Predicate { $0.id == unionId })
                  ).first
            else { continue }

            // Insert before wiring relationships (CLAUDE.md); the model has no
            // treeId of its own — it's derived from the linked person.
            let link = PersonUnionLink(
                id:        dto.id,
                role:      LinkRole(rawValue: dto.role) ?? .child,
                childType: dto.childType.flatMap { ChildType(rawValue: $0) }
            )
            context.insert(link)
            link.person = person
            link.union  = union
        }
    }
}
