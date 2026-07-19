// TreeMutationServiceTests.swift
// Graph mutations: each add* method creates a person, wires them into the right
// union, and saves. Read-back assertions go through GraphService.

import Foundation
import SwiftData
import Testing
@testable import Banyan

@Suite("TreeMutationService")
struct TreeMutationServiceTests {
    private let service = TreeMutationService()
    private let graphService = GraphService()

    @Test func addParentCreatesPersonAndLink() throws {
        // Given a person with no parents
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let focal = builder.makePerson(firstName: "Focal", treeId: treeId)

        // When a parent is added
        let parent = try service.addParent(
            to: focal,
            firstName: "Mum",
            lastName: "Kapoor",
            birthDate: PartialDate(year: 1950),
            isDeceased: false,
            deathDate: nil,
            in: builder.context
        )

        // Then the new person comes back filled in and linked as a parent
        #expect(parent.firstName == "Mum")
        #expect(parent.lastName == "Kapoor")
        #expect(parent.treeId == treeId)
        #expect(parent.birthDate?.year == 1950)
        let parents = graphService.parents(of: focal)
        #expect(parents.count == 1)
        #expect(parents.first?.id == parent.id)
    }

    @Test func addParentUsesExistingUnionWhenOnlyOneParentExists() throws {
        // Given a person who already has exactly one parent
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let focal = builder.makePerson(firstName: "Focal", treeId: treeId)
        let mother = builder.makePerson(firstName: "Mother", treeId: treeId)
        let parentUnion = builder.makeUnion(treeId: treeId)
        builder.link(person: mother, to: parentUnion, role: .partner)
        builder.link(person: focal, to: parentUnion, role: .child)

        // When a second parent is added
        try service.addParent(
            to: focal,
            firstName: "Father",
            lastName: "",
            birthDate: nil,
            isDeceased: false,
            deathDate: nil,
            in: builder.context
        )

        // Then both parents share the one existing parent union
        #expect(graphService.parents(of: focal).count == 2)
        #expect(focal.links.filter { $0.role == .child }.count == 1)
        #expect(parentUnion.links.filter { $0.role == .partner }.count == 2)
    }

    @Test func addPartnerCreatesNewUnion() throws {
        // Given a person with no unions
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let focal = builder.makePerson(firstName: "Focal", treeId: treeId)

        // When a partner is added
        let partner = try service.addPartner(
            to: focal,
            firstName: "Partner",
            lastName: "",
            birthDate: nil,
            isDeceased: false,
            deathDate: nil,
            in: builder.context
        )

        // Then they share a single new union as its two partners
        let partners = graphService.allPartners(of: focal)
        #expect(partners.count == 1)
        #expect(partners.first?.id == partner.id)
        let partnerUnions = focal.links.filter { $0.role == .partner }.compactMap(\.union)
        #expect(partnerUnions.count == 1)
        #expect(partnerUnions.first?.treeId == treeId)
    }

    @Test func addChildLinksToExistingPartnerUnion() throws {
        // Given a person with one partner in a union
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let focal = builder.makePerson(firstName: "Focal", treeId: treeId)
        let spouse = builder.makePerson(firstName: "Spouse", treeId: treeId)
        let union = builder.makeUnion(treeId: treeId)
        builder.link(person: focal, to: union, role: .partner)
        builder.link(person: spouse, to: union, role: .partner)

        // When a child is added
        let child = try service.addChild(
            to: focal,
            firstName: "Kid",
            lastName: "",
            birthDate: nil,
            isDeceased: false,
            deathDate: nil,
            in: builder.context
        )

        // Then the child joins the existing union — both partners gain the child
        #expect(graphService.children(of: focal).count == 1)
        #expect(focal.links.filter { $0.role == .partner }.count == 1)
        #expect(graphService.children(of: spouse).first?.id == child.id)
    }

    @Test func addChildCreatesNewUnionWhenNoPartnerUnion() throws {
        // Given a person with no unions
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let focal = builder.makePerson(firstName: "Focal", treeId: treeId)

        // When a child is added
        let child = try service.addChild(
            to: focal,
            firstName: "Kid",
            lastName: "",
            birthDate: nil,
            isDeceased: false,
            deathDate: nil,
            in: builder.context
        )

        // Then a new union exists with the person as its sole partner
        let children = graphService.children(of: focal)
        #expect(children.count == 1)
        #expect(children.first?.id == child.id)
        let partnerLinks = focal.links.filter { $0.role == .partner }
        #expect(partnerLinks.count == 1)
        #expect(partnerLinks.first?.union?.links.filter { $0.role == .partner }.count == 1)
    }

    @Test func addedPersonNameIsTrimmed() throws {
        // Given a person to attach a parent to
        let builder = try TestTreeBuilder()
        let focal = builder.makePerson(firstName: "Focal")

        // When a parent is added with padded names
        let parent = try service.addParent(
            to: focal,
            firstName: "  Ravi  ",
            lastName: "  Das  ",
            birthDate: nil,
            isDeceased: false,
            deathDate: nil,
            in: builder.context
        )

        // Then both name parts are stored trimmed
        #expect(parent.firstName == "Ravi")
        #expect(parent.lastName == "Das")
    }

    @Test func deceasedWithUnknownDeathDateIsStillMarkedDeceased() throws {
        // Given a person to attach a parent to
        let builder = try TestTreeBuilder()
        let focal = builder.makePerson(firstName: "Focal")

        // When a deceased parent is added without a death year
        let parent = try service.addParent(
            to: focal,
            firstName: "Grandma",
            lastName: "",
            birthDate: nil,
            isDeceased: true,
            deathDate: nil,
            in: builder.context
        )

        // Then the person still reads as deceased, with an unknown death date
        #expect(parent.isDeceased)
        #expect(parent.deathDate?.year == nil)
    }

    // MARK: - Delete

    @Test func deletePersonRemovesThem() throws {
        // Given an owner with a child
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: treeId)
        let child = try service.addChild(
            to: owner,
            firstName: "Kid",
            lastName: "",
            birthDate: nil,
            isDeceased: false,
            deathDate: nil,
            in: builder.context
        )

        // When the child is deleted
        try service.deletePerson(child, in: builder.context)

        // Then the owner has no children left
        #expect(graphService.children(of: owner).isEmpty)
    }

    @Test func deletePersonPrunesOrphanedParentUnion() throws {
        // Given a child whose sole parent sits in a one-partner union
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let focal = builder.makePerson(firstName: "Focal", treeId: treeId)
        let parent = builder.makePerson(firstName: "Parent", treeId: treeId)
        let union = builder.makeUnion(treeId: treeId)
        builder.link(person: parent, to: union, role: .partner)
        builder.link(person: focal, to: union, role: .child)

        // When the sole parent is deleted
        try service.deletePerson(parent, in: builder.context)

        // Then the now-partnerless union is pruned and the child has no parents
        #expect(graphService.parents(of: focal).isEmpty)
        let remainingUnions = try builder.context.fetch(FetchDescriptor<Union>())
        #expect(remainingUnions.isEmpty)
    }

    @Test func deletePersonKeepsUnionWithRemainingPartner() throws {
        // Given a two-partner union with a shared child
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let mother = builder.makePerson(firstName: "Mother", treeId: treeId)
        let father = builder.makePerson(firstName: "Father", treeId: treeId)
        let child = builder.makePerson(firstName: "Child", treeId: treeId)
        let union = builder.makeUnion(treeId: treeId)
        builder.link(person: mother, to: union, role: .partner)
        builder.link(person: father, to: union, role: .partner)
        builder.link(person: child, to: union, role: .child)

        // When one partner is deleted
        try service.deletePerson(father, in: builder.context)

        // Then the union survives and the child still has the other parent
        let parents = graphService.parents(of: child)
        #expect(parents.count == 1)
        #expect(parents.first?.id == mother.id)
    }
}
