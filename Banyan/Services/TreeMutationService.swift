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

    /// Creates a person and links them as a parent of `anchorPerson`, joining an
    /// existing parent union with room (a one-parent union, or a partnerless
    /// sibling group) so the new parent attaches to all of that union's children.
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

        let reusableParentUnion = anchorPerson.links
            .filter { $0.role == .child }
            .compactMap(\.union)
            .first { union in
                // A union with room for another partner: an existing one-parent
                // union, or a partnerless sibling group whose (unknown) parent is
                // now being named — either way the parent joins all its children.
                union.links.filter { $0.role == .partner }.count <= 1
            }

        if let reusableParentUnion {
            makeLink(person: newParent, union: reusableParentUnion, role: .partner, in: context)
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

    /// Creates a person and links them as a sibling of `anchorPerson`, joining
    /// the union `anchorPerson` is a child of so the two share parents. When
    /// `anchorPerson` has no parent union yet, a new partnerless union is created
    /// grouping both as children of as-yet-unknown parents.
    @discardableResult
    func addSibling(
        to anchorPerson: Person,
        firstName: String,
        lastName: String,
        birthDate: PartialDate?,
        isDeceased: Bool,
        deathDate: PartialDate?,
        in context: ModelContext
    ) throws -> Person {
        let newSibling = makePerson(
            treeId: anchorPerson.treeId,
            firstName: firstName,
            lastName: lastName,
            birthDate: birthDate,
            isDeceased: isDeceased,
            deathDate: deathDate
        )
        context.insert(newSibling)

        let parentUnion = anchorPerson.links
            .filter { $0.role == .child }
            .compactMap(\.union)
            .first

        if let parentUnion {
            makeLink(person: newSibling, union: parentUnion, role: .child, in: context)
        } else {
            let union = Union(treeId: anchorPerson.treeId, type: .unknown)
            context.insert(union)
            makeLink(person: anchorPerson, union: union, role: .child, in: context)
            makeLink(person: newSibling, union: union, role: .child, in: context)
        }

        try context.save()
        return newSibling
    }

    /// Deletes a person and prunes any union that no longer relates people once
    /// they are gone. The person's own links cascade; a union they belonged to is
    /// removed only when, after their removal, it has no other partner *and* fewer
    /// than two children — e.g. a child's sole parent union once the parent is
    /// gone. A parentless sibling group with two or more surviving children is
    /// kept, so deleting one sibling doesn't dissolve the others' relationship.
    func deletePerson(_ person: Person, in context: ModelContext) throws {
        // Decide each union's fate BEFORE deleting anything. SwiftData does not
        // eagerly remove the cascaded links from a union's in-memory `links` array,
        // so inspecting it after the delete would still see the links we removed —
        // instead, filter the person's own links out of each count up front.
        let orphanedUnions = person.links
            .compactMap(\.union)
            .filter { union in
                let remaining = union.links.filter { $0.person?.id != person.id }
                let hasOtherPartner = remaining.contains { $0.role == .partner }
                let remainingChildren = remaining.filter { $0.role == .child }.count
                // Nothing meaningful left: no surviving partner, and not enough
                // children to stand alone as a sibling group.
                return !hasOtherPartner && remainingChildren < 2
            }

        // The cascade removes the PersonPhoto rows but not their backing files —
        // the image bytes live in the documents directory, not SwiftData. Capture
        // the filenames before the delete detaches them, then remove the files.
        let photoFilenames = person.photos.map(\.filename)

        context.delete(person)   // cascades person.links and person.photos

        for filename in photoFilenames {
            PhotoStorageService.delete(filename: filename)
        }

        for union in orphanedUnions {
            context.delete(union)   // cascades the union's remaining (child) links
        }

        try context.save()
    }

    // MARK: - Link existing people (step 6)

    /// Links an existing person as a parent of `anchorPerson`, joining a parent
    /// union with room (a one-parent union, or a partnerless sibling group) so the
    /// parent attaches to all its children — the same union-reuse rule as
    /// `addParent`, minus the person creation.
    func linkAsParent(_ person: Person, of anchorPerson: Person, in context: ModelContext) throws {
        // Already this person's parent — making the link again would only
        // duplicate it (or spawn a redundant union). Treat as a no-op.
        guard !alreadyConnected(person, as: .partner, to: anchorPerson, as: .child) else { return }

        let reusableParentUnion = anchorPerson.links
            .filter { $0.role == .child }
            .compactMap(\.union)
            .first { union in
                // Room for another partner: an existing one-parent union, or a
                // partnerless sibling group now having a parent named — the parent
                // joins all its children.
                union.links.filter { $0.role == .partner }.count <= 1
            }

        if let reusableParentUnion {
            makeLink(person: person, union: reusableParentUnion, role: .partner, in: context)
        } else {
            let union = Union(treeId: anchorPerson.treeId, type: .unknown)
            context.insert(union)
            makeLink(person: anchorPerson, union: union, role: .child, in: context)
            makeLink(person: person, union: union, role: .partner, in: context)
        }

        try context.save()
    }

    /// Links two existing people as partners in a new union.
    func linkAsPartner(_ person: Person, with anchorPerson: Person, in context: ModelContext) throws {
        // Already partners — a second union pairing the same two people would
        // render as a duplicate. Treat as a no-op.
        guard !alreadyConnected(person, as: .partner, to: anchorPerson, as: .partner) else { return }

        let union = Union(treeId: anchorPerson.treeId, type: .unknown)
        context.insert(union)
        makeLink(person: anchorPerson, union: union, role: .partner, in: context)
        makeLink(person: person, union: union, role: .partner, in: context)

        try context.save()
    }

    /// Links an existing person as a child of `anchorPerson`, joining the first
    /// union where `anchorPerson` is already a partner when one exists — the
    /// same union-reuse rule as `addChild`, minus the person creation.
    func linkAsChild(_ person: Person, of anchorPerson: Person, in context: ModelContext) throws {
        // Already this person's child — making the link again would only
        // duplicate the child link. Treat as a no-op.
        guard !alreadyConnected(person, as: .child, to: anchorPerson, as: .partner) else { return }

        let existingPartnerUnion = anchorPerson.links
            .filter { $0.role == .partner }
            .compactMap(\.union)
            .first

        if let existingPartnerUnion {
            makeLink(person: person, union: existingPartnerUnion, role: .child, in: context)
        } else {
            let union = Union(treeId: anchorPerson.treeId, type: .unknown)
            context.insert(union)
            makeLink(person: anchorPerson, union: union, role: .partner, in: context)
            makeLink(person: person, union: union, role: .child, in: context)
        }

        try context.save()
    }

    /// Removes `person`'s links to every union shared with `anchorPerson`,
    /// deleting outright any union that afterwards no longer relates at least
    /// two people (no partners left, or a single partner with no children).
    func unlink(_ person: Person, from anchorPerson: Person, in context: ModelContext) throws {
        let personUnionIds = Set(person.links.compactMap(\.union?.id))
        var seen = Set<UUID>()
        let sharedUnions = anchorPerson.links
            .compactMap(\.union)
            .filter { personUnionIds.contains($0.id) && seen.insert($0.id).inserted }

        // Decide each union's fate BEFORE deleting anything: cascade-deleted
        // links linger in the in-memory `links` arrays until the context saves,
        // so counting afterwards would still see the links just removed — the
        // same staleness `deletePerson` works around.
        var linksToDelete: [PersonUnionLink] = []
        var unionsToDelete: [Union] = []

        for union in sharedUnions {
            let remainingLinks = union.links.filter { $0.person?.id != person.id }
            let remainingPartners = remainingLinks.filter { $0.role == .partner }.count
            let remainingChildren = remainingLinks.count - remainingPartners
            let survives = remainingPartners >= 2
                || (remainingPartners == 1 && remainingChildren >= 1)

            if survives {
                linksToDelete.append(contentsOf: union.links.filter { $0.person?.id == person.id })
            } else {
                unionsToDelete.append(union)   // cascades person's link with it
            }
        }

        for link in linksToDelete {
            context.delete(link)
        }
        for union in unionsToDelete {
            context.delete(union)   // cascades the union's remaining links
        }

        try context.save()
    }

    // MARK: - Helpers

    /// Whether `person` and `anchorPerson` already share a union in which each
    /// holds the given role — i.e. the connection about to be made already
    /// exists, so remaking it would only duplicate links (or a whole union).
    private func alreadyConnected(
        _ person: Person, as personRole: LinkRole,
        to anchorPerson: Person, as anchorRole: LinkRole
    ) -> Bool {
        let anchorUnionIds = Set(
            anchorPerson.links.filter { $0.role == anchorRole }.compactMap(\.union?.id)
        )
        return person.links.contains { link in
            link.role == personRole
                && (link.union.map { anchorUnionIds.contains($0.id) } ?? false)
        }
    }

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
