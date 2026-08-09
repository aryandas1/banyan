// GraphService.swift
// Pure graph traversal over Person / Union / PersonUnionLink. No persistence, no UI.
//
// The graph has no direct parent-child edges: people attach to unions, and a union
// is what makes two partners into parents of its children. Every query below is a
// walk of person → links → union → links → person.

import Foundation

final class GraphService: GraphServiceProtocol {

    /// All unions this person participates in (as partner or child).
    func unions(for person: Person) -> [Union] {
        deduplicated(person.links.compactMap(\.union))
    }

    /// The other partner(s) in a given union.
    func partners(of person: Person, in union: Union) -> [Person] {
        deduplicated(people(in: union, role: .partner).filter { $0.id != person.id })
    }

    /// All partners across all of this person's unions.
    func allPartners(of person: Person) -> [Person] {
        let result = unions(for: person, role: .partner)
            .flatMap { self.partners(of: person, in: $0) }
        return deduplicated(result)
    }

    /// The parents of a person — the partner(s) of the union where this person is a child.
    func parents(of person: Person) -> [Person] {
        let result = unions(for: person, role: .child)
            .flatMap { people(in: $0, role: .partner) }
        return deduplicated(result)
    }

    /// All children across all unions where this person is a partner.
    func children(of person: Person) -> [Person] {
        let result = unions(for: person, role: .partner)
            .flatMap { people(in: $0, role: .child) }
        return deduplicated(result)
    }

    /// The single union a new partner of `person` could reasonably co-parent: one
    /// where `person` is the lone partner and there is at least one child. Returns
    /// nil when no such union exists, or when there is more than one (ambiguous —
    /// never assume co-parenting in that case).
    func coParentableUnion(for person: Person) -> Union? {
        let candidates = unions(for: person, role: .partner).filter { union in
            let partnerCount = union.links.filter { $0.role == .partner }.count
            let hasChildren = union.links.contains { $0.role == .child }
            return partnerCount <= 1 && hasChildren
        }
        return candidates.count == 1 ? candidates.first : nil
    }

    /// People who share at least one parent union with this person.
    /// Half-siblings — who share a parent but not a parent *union* — are not included.
    func siblings(of person: Person) -> [Person] {
        let result = unions(for: person, role: .child)
            .flatMap { people(in: $0, role: .child) }
            .filter { $0.id != person.id }
        return deduplicated(result)
    }

    /// All people in a tree, sorted alphabetically by fullName.
    func allPeople(treeId: UUID, from people: [Person]) -> [Person] {
        people
            .filter { $0.treeId == treeId }
            .sorted { $0.fullName.localizedStandardCompare($1.fullName) == .orderedAscending }
    }

    // MARK: - Helpers

    /// The unions this person participates in under a specific role.
    private func unions(for person: Person, role: LinkRole) -> [Union] {
        deduplicated(
            person.links
                .filter { $0.role == role }
                .compactMap(\.union)
        )
    }

    /// The people attached to a union under a specific role.
    private func people(in union: Union, role: LinkRole) -> [Person] {
        union.links
            .filter { $0.role == role }
            .compactMap(\.person)
    }

    private func deduplicated(_ people: [Person]) -> [Person] {
        var seen = Set<UUID>()
        return people.filter { seen.insert($0.id).inserted }
    }

    private func deduplicated(_ unions: [Union]) -> [Union] {
        var seen = Set<UUID>()
        return unions.filter { seen.insert($0.id).inserted }
    }
}
