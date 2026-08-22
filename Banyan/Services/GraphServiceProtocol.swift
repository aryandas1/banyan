// GraphServiceProtocol.swift
// The read-only query surface over the family graph.

import Foundation

/// Provides read-only graph queries over the person-union family graph.
/// All methods are pure — they take entities and return derived data.
/// No SwiftUI or SwiftData imports. No side effects.
protocol GraphServiceProtocol {
    /// All unions this person participates in (as partner or child).
    func unions(for person: Person) -> [Union]

    /// The other partner(s) in a given union.
    func partners(of person: Person, in union: Union) -> [Person]

    /// All partners across all of this person's unions.
    func allPartners(of person: Person) -> [Person]

    /// The unions where this person is a partner — each a distinct relationship
    /// that can carry its own anniversary (`Union.startDate`).
    func partnerUnions(of person: Person) -> [Union]

    /// The parents of a person — the partner(s) of the union where this person is a child.
    func parents(of person: Person) -> [Person]

    /// All children across all unions where this person is a partner.
    func children(of person: Person) -> [Person]

    /// The single union a new partner of `person` could reasonably co-parent: one
    /// where `person` is the lone partner and there is at least one child. Returns
    /// nil when no such union exists, or when there is more than one (ambiguous —
    /// never assume co-parenting in that case).
    func coParentableUnion(for person: Person) -> Union?

    /// People who share at least one parent union with this person.
    func siblings(of person: Person) -> [Person]

    /// All people in a tree, sorted alphabetically by fullName.
    func allPeople(treeId: UUID, from people: [Person]) -> [Person]
}
