// TreeMutationServiceTests.swift
// Graph mutations: each add* method creates a person, wires them into the right
// union, and saves. Read-back assertions go through GraphService.

import Foundation
import SwiftData
import Testing
import UIKit
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

    @Test func addPartnerCoParentsExistingChildren() throws {
        // Given "me" whose only parent so far is Dad (added via addParent, so Dad
        // is the lone partner of the union where I am the child) — the user's exact flow
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let me = builder.makePerson(firstName: "Me", treeId: treeId)
        let dad = try service.addParent(
            to: me, firstName: "Dad", lastName: "",
            birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context
        )

        // When I add a partner to Dad and confirm they co-parent the existing children
        let mom = try service.addPartner(
            to: dad, firstName: "Mom", lastName: "",
            birthDate: nil, isDeceased: false, deathDate: nil,
            coParentExistingChildren: true, in: builder.context
        )

        // Then Mom is my second parent (she joined Dad's union — no new union)
        let myParents = graphService.parents(of: me)
        #expect(myParents.count == 2)
        #expect(myParents.contains { $0.id == mom.id })
        #expect(myParents.contains { $0.id == dad.id })
        #expect(me.links.filter { $0.role == .child }.count == 1)      // still one parent union
        #expect(graphService.children(of: mom).contains { $0.id == me.id })
    }

    @Test func addPartnerWithoutCoParentStaysSeparate() throws {
        // Given "me" whose only parent is Dad
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let me = builder.makePerson(firstName: "Me", treeId: treeId)
        let dad = try service.addParent(
            to: me, firstName: "Dad", lastName: "",
            birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context
        )

        // When I add a partner to Dad but say they are NOT a parent of my kids
        let stepmom = try service.addPartner(
            to: dad, firstName: "Stepmom", lastName: "",
            birthDate: nil, isDeceased: false, deathDate: nil,
            coParentExistingChildren: false, in: builder.context
        )

        // Then I still have only Dad as a parent; Stepmom is a partner in a separate union
        #expect(graphService.parents(of: me).count == 1)
        #expect(graphService.parents(of: me).first?.id == dad.id)
        #expect(!graphService.children(of: stepmom).contains { $0.id == me.id })
        #expect(graphService.allPartners(of: dad).contains { $0.id == stepmom.id })
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

    @Test func addSiblingJoinsExistingParentUnion() throws {
        // Given a person who is a child of a parent union
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let parent = builder.makePerson(firstName: "Parent", treeId: treeId)
        let focal = builder.makePerson(firstName: "Focal", treeId: treeId)
        let parentUnion = builder.makeUnion(treeId: treeId)
        builder.link(person: parent, to: parentUnion, role: .partner)
        builder.link(person: focal, to: parentUnion, role: .child)

        // When a sibling is added
        let sibling = try service.addSibling(
            to: focal,
            firstName: "Sib",
            lastName: "Kapoor",
            birthDate: PartialDate(year: 1990),
            isDeceased: false,
            deathDate: nil,
            in: builder.context
        )

        // Then the sibling joins the same parent union — no new union is made
        #expect(sibling.firstName == "Sib")
        #expect(sibling.lastName == "Kapoor")
        #expect(sibling.treeId == treeId)
        #expect(sibling.birthDate?.year == 1990)
        #expect(focal.links.filter { $0.role == .child }.count == 1)
        #expect(parentUnion.links.filter { $0.role == .child }.count == 2)
        // And the two are siblings who share the same parent
        #expect(graphService.siblings(of: focal).map(\.id) == [sibling.id])
        #expect(graphService.parents(of: sibling).map(\.id) == [parent.id])
    }

    @Test func addSiblingCreatesParentlessUnionWhenNoParents() throws {
        // Given a person with no recorded parents
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let focal = builder.makePerson(firstName: "Focal", treeId: treeId)

        // When a sibling is added
        let sibling = try service.addSibling(
            to: focal,
            firstName: "Sib",
            lastName: "",
            birthDate: nil,
            isDeceased: false,
            deathDate: nil,
            in: builder.context
        )

        // Then a new partnerless union groups the two as children of unknown parents
        #expect(graphService.siblings(of: focal).map(\.id) == [sibling.id])
        #expect(graphService.siblings(of: sibling).map(\.id) == [focal.id])
        let focalChildUnions = focal.links.filter { $0.role == .child }.compactMap(\.union)
        #expect(focalChildUnions.count == 1)
        let union = try #require(focalChildUnions.first)
        #expect(union.links.filter { $0.role == .partner }.isEmpty)
        #expect(union.links.filter { $0.role == .child }.count == 2)
        #expect(graphService.parents(of: focal).isEmpty)
    }

    @Test func addParentToSiblingGroupAttachesToEveryone() throws {
        // Given two siblings grouped by a parentless union (parents unknown)
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let a = builder.makePerson(firstName: "A", treeId: treeId)
        let b = try service.addSibling(
            to: a, firstName: "B", lastName: "",
            birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context
        )

        // When a parent is added to one of them
        let parent = try service.addParent(
            to: a, firstName: "Mum", lastName: "",
            birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context
        )

        // Then the parent joins the shared union and parents BOTH siblings,
        // and no separate union is created
        #expect(graphService.parents(of: a).map(\.id) == [parent.id])
        #expect(graphService.parents(of: b).map(\.id) == [parent.id])
        let unions = try builder.context.fetch(FetchDescriptor<Union>())
        #expect(unions.count == 1)
    }

    @Test func linkAsParentToSiblingGroupAttachesToEveryone() throws {
        // Given two siblings grouped by a parentless union, and an existing person
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let a = builder.makePerson(firstName: "A", treeId: treeId)
        let b = try service.addSibling(
            to: a, firstName: "B", lastName: "",
            birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context
        )
        let mum = builder.makePerson(firstName: "Mum", treeId: treeId)

        // When the existing person is linked as a parent of one sibling
        try service.linkAsParent(mum, of: a, in: builder.context)

        // Then they parent BOTH siblings via the shared union
        #expect(graphService.parents(of: a).map(\.id) == [mum.id])
        #expect(graphService.parents(of: b).map(\.id) == [mum.id])
        let unions = try builder.context.fetch(FetchDescriptor<Union>())
        #expect(unions.count == 1)
    }

    @Test func deleteSiblingKeepsParentlessSiblingGroupIntact() throws {
        // Given three siblings grouped by a parentless union (parents unknown),
        // built through the add-sibling flow
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let a = builder.makePerson(firstName: "A", treeId: treeId)
        let b = try service.addSibling(
            to: a, firstName: "B", lastName: "",
            birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context
        )
        let c = try service.addSibling(
            to: a, firstName: "C", lastName: "",
            birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context
        )
        #expect(Set(graphService.siblings(of: a).map(\.id)) == Set([b.id, c.id]))

        // When one sibling is deleted
        try service.deletePerson(b, in: builder.context)

        // Then the shared union survives and the remaining two are still siblings
        #expect(graphService.siblings(of: a).map(\.id) == [c.id])
        #expect(graphService.siblings(of: c).map(\.id) == [a.id])
        let remainingUnions = try builder.context.fetch(FetchDescriptor<Union>())
        #expect(remainingUnions.count == 1)
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

    @Test func deletePersonRemovesTheirPhotoFilesFromDisk() throws {
        // Given a person with a photo file actually written to disk
        let builder = try TestTreeBuilder()
        let person = builder.makePerson(firstName: "Ravi")
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { ctx in
            UIColor.gray.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        let filename = try #require(PhotoStorageService.save(image))
        let photo = PersonPhoto(treeId: person.treeId, personId: person.id, filename: filename)
        builder.context.insert(photo)
        photo.person = person
        #expect(PhotoStorageService.load(filename: filename) != nil)

        // When the person is deleted
        try service.deletePerson(person, in: builder.context)

        // Then the backing file is gone, not just the SwiftData row
        #expect(PhotoStorageService.load(filename: filename) == nil)
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
