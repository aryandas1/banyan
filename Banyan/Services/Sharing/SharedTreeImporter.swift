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
    /// come last). Returns a chosen focal/root for the viewer, or nil for an empty
    /// tree. Throws if a context write fails.
    @discardableResult
    func importTree(_ snapshot: SharedTreeSnapshot, treeId: UUID, into context: ModelContext) throws -> UUID? {
        try upsertPersons(snapshot.persons, into: context)
        try upsertUnions(snapshot.unions, into: context)
        try context.save()
        try upsertLinks(snapshot.links, into: context)
        try context.save()
        return ViewerRootPicker.pickRoot(persons: snapshot.persons, links: snapshot.links)
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
