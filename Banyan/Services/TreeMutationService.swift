// TreeMutationService.swift
// Creates people and wires them into unions. No UI, no observation — pure
// Foundation + SwiftData, saving through whichever ModelContext is passed in.
//
// Every object is inserted into the context BEFORE relationships are wired
// (Person → Union → PersonUnionLink), and links attach via the to-many sides
// (person.links / union.links) so SwiftData populates the inverses — the same
// proven pattern as TestTreeBuilder.

import Foundation
import SwiftData

final class TreeMutationService: TreeMutationServiceProtocol {

    /// Creates a person and links them as a parent of `anchorPerson`,
    /// joining the existing single-parent union when one exists.
    @discardableResult
    func addParent(
        to anchorPerson: Person,
        firstName: String,
        lastName: String,
        birthDate: PartialDate?,
        isDeceased: Bool,
        deathDate: PartialDate?,
        in context: ModelContext
    ) throws -> Person {
        let newParent = makePerson(
            treeId: anchorPerson.treeId,
            firstName: firstName,
            lastName: lastName,
            birthDate: birthDate,
            isDeceased: isDeceased,
            deathDate: deathDate
        )
        context.insert(newParent)

        let singleParentUnion = anchorPerson.links
            .filter { $0.role == .child }
            .compactMap(\.union)
            .first { union in
                union.links.filter { $0.role == .partner }.count == 1
            }

        if let singleParentUnion {
            makeLink(person: newParent, union: singleParentUnion, role: .partner, in: context)
        } else {
            let union = Union(treeId: anchorPerson.treeId, type: .unknown)
            context.insert(union)
            makeLink(person: anchorPerson, union: union, role: .child, in: context)
            makeLink(person: newParent, union: union, role: .partner, in: context)
        }

        try context.save()
        return newParent
    }

    /// Creates a person and links them as a partner of `anchorPerson` in a new union.
    @discardableResult
    func addPartner(
        to anchorPerson: Person,
        firstName: String,
        lastName: String,
        birthDate: PartialDate?,
        isDeceased: Bool,
        deathDate: PartialDate?,
        in context: ModelContext
    ) throws -> Person {
        let newPartner = makePerson(
            treeId: anchorPerson.treeId,
            firstName: firstName,
            lastName: lastName,
            birthDate: birthDate,
            isDeceased: isDeceased,
            deathDate: deathDate
        )
        context.insert(newPartner)

        let union = Union(treeId: anchorPerson.treeId, type: .unknown)
        context.insert(union)
        makeLink(person: anchorPerson, union: union, role: .partner, in: context)
        makeLink(person: newPartner, union: union, role: .partner, in: context)

        try context.save()
        return newPartner
    }

    /// Creates a person and links them as a child of `anchorPerson`, joining the
    /// first union where `anchorPerson` is already a partner when one exists.
    @discardableResult
    func addChild(
        to anchorPerson: Person,
        firstName: String,
        lastName: String,
        birthDate: PartialDate?,
        isDeceased: Bool,
        deathDate: PartialDate?,
        in context: ModelContext
    ) throws -> Person {
        let newChild = makePerson(
            treeId: anchorPerson.treeId,
            firstName: firstName,
            lastName: lastName,
            birthDate: birthDate,
            isDeceased: isDeceased,
            deathDate: deathDate
        )
        context.insert(newChild)

        let existingPartnerUnion = anchorPerson.links
            .filter { $0.role == .partner }
            .compactMap(\.union)
            .first

        if let existingPartnerUnion {
            makeLink(person: newChild, union: existingPartnerUnion, role: .child, in: context)
        } else {
            let union = Union(treeId: anchorPerson.treeId, type: .unknown)
            context.insert(union)
            makeLink(person: anchorPerson, union: union, role: .partner, in: context)
            makeLink(person: newChild, union: union, role: .child, in: context)
        }

        try context.save()
        return newChild
    }

    // MARK: - Helpers

    /// Builds the new Person with trimmed names. Not yet inserted into a context.
    /// A deceased person with an unknown death date still gets a non-nil (empty)
    /// PartialDate — `Person.isDeceased` is derived from `deathDate != nil`.
    private func makePerson(
        treeId: UUID,
        firstName: String,
        lastName: String,
        birthDate: PartialDate?,
        isDeceased: Bool,
        deathDate: PartialDate?
    ) -> Person {
        Person(
            treeId: treeId,
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            birthDate: birthDate,
            deathDate: isDeceased ? (deathDate ?? PartialDate()) : nil
        )
    }

    /// Joins a person to a union. The link is inserted into the context first,
    /// then attached via the to-many sides so SwiftData populates the inverses.
    @discardableResult
    private func makeLink(
        person: Person,
        union: Union,
        role: LinkRole,
        in context: ModelContext
    ) -> PersonUnionLink {
        let link = PersonUnionLink(role: role)
        context.insert(link)
        person.links.append(link)
        union.links.append(link)
        return link
    }
}
