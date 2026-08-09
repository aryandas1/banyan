// ViewerRootPicker.swift
// Chooses the focal/root person for a pulled shared tree. A viewer never
// onboarded, so they have no `ownerPersonId`, and the owner's root person id
// isn't stored anywhere the viewer can read (trees.owner_id is a *user* id).
// This picks a sensible top-of-tree person from the pulled graph instead.
//
// Long-term the correct fix is to denormalise `root_person_id` onto `trees` and
// have the owner's sync write their `ownerPersonId` (a schema change); this
// heuristic keeps step 12 self-contained with no backend change.
//
// Pure logic over DTOs — no SwiftData — so it's fully unit-testable.

import Foundation

enum ViewerRootPicker {
    /// Picks a root for the tree, preferring — in order:
    ///   1. a top ancestor (never a child in any union) who is a partner in a
    ///      union that has children, i.e. someone with descendants;
    ///   2. any top ancestor;
    ///   3. any person at all.
    /// Within each tier a real (non-placeholder) person is preferred, and ties
    /// break on the id's string form so re-imports of the same tree pick the same
    /// root. Returns nil only for an empty tree.
    static func pickRoot(persons: [PersonDTO], links: [PersonUnionLinkDTO]) -> UUID? {
        guard !persons.isEmpty else { return nil }

        let childPersonIds = Set(links.filter { $0.role == LinkRole.child.rawValue }.map(\.personId))
        let unionsWithChildren = Set(links.filter { $0.role == LinkRole.child.rawValue }.map(\.unionId))
        let partnerUnionsByPerson = Dictionary(
            grouping: links.filter { $0.role == LinkRole.partner.rawValue },
            by: \.personId
        ).mapValues { Set($0.map(\.unionId)) }

        let topAncestors = persons.filter { !childPersonIds.contains($0.id) }
        let ancestorsWithDescendants = topAncestors.filter { person in
            guard let unions = partnerUnionsByPerson[person.id] else { return false }
            return !unions.isDisjoint(with: unionsWithChildren)
        }

        return best(from: ancestorsWithDescendants)
            ?? best(from: topAncestors)
            ?? best(from: persons)
    }

    /// Local-model overload for the fallback over the tree already in SwiftData —
    /// used when no root was persisted at accept time (an empty-then-populated
    /// pull). Maps the models to DTOs and delegates to the DTO heuristic above so
    /// the ranking has a single source of truth. Returns nil for an empty tree.
    static func pickRoot(persons: [Person], links: [PersonUnionLink]) -> UUID? {
        pickRoot(
            persons: persons.map(PersonDTO.init(from:)),
            links: links.compactMap(PersonUnionLinkDTO.init(from:))
        )
    }

    /// Prefers a non-placeholder person, then breaks ties deterministically on the
    /// id's string form.
    private static func best(from candidates: [PersonDTO]) -> UUID? {
        let ordered = candidates.sorted { lhs, rhs in
            if lhs.isPlaceholder != rhs.isPlaceholder { return !lhs.isPlaceholder }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        return ordered.first?.id
    }
}
