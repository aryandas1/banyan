// TreeMutationServiceProtocol.swift
// The write surface over the family graph — the mutation counterpart to GraphService.

import Foundation
import SwiftData

/// Writes new people and relationships into the SwiftData store.
/// All methods insert the returned Person into the context and save.
protocol TreeMutationServiceProtocol {
    /// Creates a person and links them as a parent of `anchorPerson`.
    /// If `anchorPerson` already has exactly one parent union with one partner,
    /// the new parent is added as the second partner in that union.
    /// Otherwise a new union is created.
    @discardableResult
    func addParent(
        to anchorPerson: Person,
        firstName: String,
        lastName: String,
        birthDate: PartialDate?,
        isDeceased: Bool,
        deathDate: PartialDate?,
        in context: ModelContext
    ) throws -> Person

    /// Creates a person and links them as a partner of `anchorPerson`
    /// in a new union.
    @discardableResult
    func addPartner(
        to anchorPerson: Person,
        firstName: String,
        lastName: String,
        birthDate: PartialDate?,
        isDeceased: Bool,
        deathDate: PartialDate?,
        in context: ModelContext
    ) throws -> Person

    /// Creates a person and links them as a child of `anchorPerson`.
    /// If `anchorPerson` has exactly one union where they are a partner,
    /// the child is added to that union.
    /// Otherwise a new union is created with `anchorPerson` as the sole partner.
    @discardableResult
    func addChild(
        to anchorPerson: Person,
        firstName: String,
        lastName: String,
        birthDate: PartialDate?,
        isDeceased: Bool,
        deathDate: PartialDate?,
        in context: ModelContext
    ) throws -> Person

    /// Deletes a person and prunes any union left with no partners.
    /// Removing the person cascades their PersonUnionLinks; unions the person
    /// belonged to are then inspected and deleted if no partner link remains
    /// (e.g. a child's sole parent union once that parent is gone).
    func deletePerson(_ person: Person, in context: ModelContext) throws
}
