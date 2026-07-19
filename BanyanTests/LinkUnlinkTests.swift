// LinkUnlinkTests.swift
// Step 6: connecting two already-existing people and removing connections.
// Read-back assertions go through GraphService. Union pruning is asserted
// against a persisted fetch, not the in-memory to-many arrays — cascade-deleted
// links linger there until the context saves (same as TreeMutationServiceTests).

import Foundation
import SwiftData
import Testing
@testable import Banyan

@Suite("Link and unlink")
struct LinkUnlinkTests {
    private let service = TreeMutationService()
    private let graphService = GraphService()

    // MARK: - Link

    @Test func linkAsParentConnectsTwoPeople() throws {
        // Given a focal person with no parents and an existing unconnected person
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let focal = builder.makePerson(firstName: "Focal", treeId: treeId)
        let existing = builder.makePerson(firstName: "Existing", treeId: treeId)

        // When the existing person is linked as focal's parent
        try service.linkAsParent(existing, of: focal, in: builder.context)

        // Then they read back as focal's only parent
        let parents = graphService.parents(of: focal)
        #expect(parents.count == 1)
        #expect(parents.first?.id == existing.id)
    }

    @Test func linkAsParentUsesExistingUnion() throws {
        // Given a focal person who already has exactly one parent
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let focal = builder.makePerson(firstName: "Focal", treeId: treeId)
        let mother = builder.makePerson(firstName: "Mother", treeId: treeId)
        let parentUnion = builder.makeUnion(treeId: treeId)
        builder.link(person: mother, to: parentUnion, role: .partner)
        builder.link(person: focal, to: parentUnion, role: .child)
        let father = builder.makePerson(firstName: "Father", treeId: treeId)

        // When a second existing person is linked as focal's parent
        try service.linkAsParent(father, of: focal, in: builder.context)

        // Then both parents share the one existing parent union
        #expect(graphService.parents(of: focal).count == 2)
        #expect(focal.links.filter { $0.role == .child }.count == 1)
        #expect(parentUnion.links.filter { $0.role == .partner }.count == 2)
    }

    @Test func linkAsPartnerCreatesUnion() throws {
        // Given two people with no unions
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let focal = builder.makePerson(firstName: "Focal", treeId: treeId)
        let existing = builder.makePerson(firstName: "Existing", treeId: treeId)

        // When they are linked as partners
        try service.linkAsPartner(existing, with: focal, in: builder.context)

        // Then they share a single new union as its two partners
        let partners = graphService.allPartners(of: focal)
        #expect(partners.count == 1)
        #expect(partners.first?.id == existing.id)
        let partnerUnions = focal.links.filter { $0.role == .partner }.compactMap(\.union)
        #expect(partnerUnions.count == 1)
        #expect(partnerUnions.first?.treeId == treeId)
    }

    @Test func linkAsChildAddsToExistingUnion() throws {
        // Given a focal person with a partner in a union, and a separate person
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let focal = builder.makePerson(firstName: "Focal", treeId: treeId)
        let spouse = builder.makePerson(firstName: "Spouse", treeId: treeId)
        let union = builder.makeUnion(treeId: treeId)
        builder.link(person: focal, to: union, role: .partner)
        builder.link(person: spouse, to: union, role: .partner)
        let kid = builder.makePerson(firstName: "Kid", treeId: treeId)

        // When the person is linked as focal's child
        try service.linkAsChild(kid, of: focal, in: builder.context)

        // Then the child joins the existing union — both partners gain the child
        #expect(graphService.children(of: focal).count == 1)
        #expect(focal.links.filter { $0.role == .partner }.count == 1)
        #expect(graphService.children(of: spouse).first?.id == kid.id)
    }

    @Test func linkAsChildCreatesUnionWhenNone() throws {
        // Given a focal person with no unions and a separate person
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let focal = builder.makePerson(firstName: "Focal", treeId: treeId)
        let kid = builder.makePerson(firstName: "Kid", treeId: treeId)

        // When the person is linked as focal's child
        try service.linkAsChild(kid, of: focal, in: builder.context)

        // Then a new union exists with focal as its sole partner and kid as child
        let children = graphService.children(of: focal)
        #expect(children.count == 1)
        #expect(children.first?.id == kid.id)
        let partnerLinks = focal.links.filter { $0.role == .partner }
        #expect(partnerLinks.count == 1)
        #expect(partnerLinks.first?.union?.links.filter { $0.role == .partner }.count == 1)
    }

    // MARK: - Unlink

    @Test func unlinkRemovesConnection() throws {
        // Given a focal person with one partner
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let focal = builder.makePerson(firstName: "Focal", treeId: treeId)
        let partner = builder.makePerson(firstName: "Partner", treeId: treeId)
        let union = builder.makeUnion(treeId: treeId)
        builder.link(person: focal, to: union, role: .partner)
        builder.link(person: partner, to: union, role: .partner)

        // When the partner is unlinked from focal
        try service.unlink(partner, from: focal, in: builder.context)

        // Then focal has no partners left
        #expect(graphService.allPartners(of: focal).isEmpty)
    }

    @Test func unlinkCleansUpOrphanedUnion() throws {
        // Given a focal person with one partner — a union with only two partners,
        // no children
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let focal = builder.makePerson(firstName: "Focal", treeId: treeId)
        let partner = builder.makePerson(firstName: "Partner", treeId: treeId)
        let union = builder.makeUnion(treeId: treeId)
        builder.link(person: focal, to: union, role: .partner)
        builder.link(person: partner, to: union, role: .partner)

        // When the partner is unlinked from focal
        try service.unlink(partner, from: focal, in: builder.context)

        // Then the union is deleted — it no longer relates two people. Asserted
        // via a persisted fetch: the in-memory `focal.links` array is stale after
        // a cascade delete, so inspecting it directly would give a false failure.
        let remainingUnions = try builder.context.fetch(FetchDescriptor<Union>())
        #expect(remainingUnions.isEmpty)
        let remainingLinks = try builder.context.fetch(FetchDescriptor<PersonUnionLink>())
        #expect(remainingLinks.isEmpty)
    }

    @Test func unlinkDoesNothingWhenNotConnected() throws {
        // Given two people with no shared union
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let focal = builder.makePerson(firstName: "Focal", treeId: treeId)
        let stranger = builder.makePerson(firstName: "Stranger", treeId: treeId)
        let union = builder.makeUnion(treeId: treeId)
        builder.link(person: focal, to: union, role: .partner)

        // When unlink is called on the unconnected pair, it does not throw
        try service.unlink(stranger, from: focal, in: builder.context)

        // Then nothing was removed — both people and focal's union survive
        let people = try builder.context.fetch(FetchDescriptor<Person>())
        #expect(people.count == 2)
        let unions = try builder.context.fetch(FetchDescriptor<Union>())
        #expect(unions.count == 1)
        #expect(focal.links.filter { $0.role == .partner }.count == 1)
    }
}
