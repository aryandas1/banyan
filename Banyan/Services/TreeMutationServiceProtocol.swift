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

    /// Creates a person and links them as a sibling of `anchorPerson` — i.e. as
    /// another child of the union `anchorPerson` is a child of.
    /// If `anchorPerson` already has a parent union, the sibling joins it and so
    /// shares the same parents. Otherwise a new partnerless union is created
    /// grouping the two as children of as-yet-unknown parents.
    @discardableResult
    func addSibling(
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

    /// Links an already-existing person as a parent of `anchorPerson`.
    /// Same union-reuse rule as `addParent`: joins the existing single-parent
    /// union when one exists, otherwise creates a new union. No Person is created.
    func linkAsParent(_ person: Person, of anchorPerson: Person, in context: ModelContext) throws

    /// Links two already-existing people as partners in a new union.
    /// No Person is created.
    func linkAsPartner(_ person: Person, with anchorPerson: Person, in context: ModelContext) throws

    /// Links an already-existing person as a child of `anchorPerson`.
    /// Same union-reuse rule as `addChild`: joins the first union where
    /// `anchorPerson` is a partner when one exists, otherwise creates a new
    /// union with `anchorPerson` as its sole partner. No Person is created.
    func linkAsChild(_ person: Person, of anchorPerson: Person, in context: ModelContext) throws

    /// Removes the connection between `person` and `anchorPerson` by deleting
    /// `person`'s links to every union the two share. A union that afterwards no
    /// longer relates at least two people — no partners left, or a single
    /// partner with no children — is deleted with it. Does nothing when the two
    /// share no union.
    func unlink(_ person: Person, from anchorPerson: Person, in context: ModelContext) throws
}
