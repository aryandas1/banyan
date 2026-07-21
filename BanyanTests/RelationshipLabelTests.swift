// RelationshipLabelTests.swift
// TDD for RelationshipLabel — the BFS that turns owner→target graph paths into labels.
// Builds small graphs with TestTreeBuilder, then asserts the returned string.

import Testing
import Foundation
@testable import Banyan

@Suite("RelationshipLabel")
struct RelationshipLabelTests {
    private let graphService = GraphService()

    // MARK: - Depth 0

    @Test func ownerLabelIsYou() throws {
        let builder = try TestTreeBuilder()
        let owner = builder.makePerson(firstName: "Owner")
        let label = RelationshipLabel.label(from: owner, to: owner, using: graphService)
        #expect(label == "You")
    }

    // MARK: - Depth 1

    @Test func fatherLabel() throws {
        let builder = try TestTreeBuilder()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let father = addParent(of: owner, sex: .male, in: builder)

        let label = RelationshipLabel.label(from: owner, to: father, using: graphService)
        #expect(label == "Father")
    }

    @Test func motherLabel() throws {
        let builder = try TestTreeBuilder()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let mother = addParent(of: owner, sex: .female, in: builder)

        let label = RelationshipLabel.label(from: owner, to: mother, using: graphService)
        #expect(label == "Mother")
    }

    @Test func sonLabel() throws {
        let builder = try TestTreeBuilder()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let son = addChild(of: owner, sex: .male, in: builder)

        let label = RelationshipLabel.label(from: owner, to: son, using: graphService)
        #expect(label == "Son")
    }

    @Test func daughterLabel() throws {
        let builder = try TestTreeBuilder()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let daughter = addChild(of: owner, sex: .female, in: builder)

        let label = RelationshipLabel.label(from: owner, to: daughter, using: graphService)
        #expect(label == "Daughter")
    }

    @Test func partnerLabel() throws {
        let builder = try TestTreeBuilder()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let partner = addPartner(of: owner, in: builder)

        let label = RelationshipLabel.label(from: owner, to: partner, using: graphService)
        #expect(label == "Partner")
    }

    // MARK: - Depth 2

    @Test func siblingLabel() throws {
        let builder = try TestTreeBuilder()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let parent = builder.makePerson(firstName: "Parent", treeId: tree)   // sex .unknown by default
        let sibling = builder.makePerson(firstName: "Sibling", treeId: tree) // sex .unknown → "Sibling"
        let union = builder.makeUnion(treeId: tree)
        builder.link(person: parent, to: union, role: .partner)
        builder.link(person: owner, to: union, role: .child, childType: .biological)
        builder.link(person: sibling, to: union, role: .child, childType: .biological)

        let label = RelationshipLabel.label(from: owner, to: sibling, using: graphService)
        #expect(label == "Sibling")
    }

    @Test func brotherLabel() throws {
        let builder = try TestTreeBuilder()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let parent = builder.makePerson(firstName: "Parent", treeId: tree)
        let brother = builder.makePerson(firstName: "Brother", treeId: tree)
        brother.sex = .male
        let union = builder.makeUnion(treeId: tree)
        builder.link(person: parent, to: union, role: .partner)
        builder.link(person: owner, to: union, role: .child, childType: .biological)
        builder.link(person: brother, to: union, role: .child, childType: .biological)

        let label = RelationshipLabel.label(from: owner, to: brother, using: graphService)
        #expect(label == "Brother")
    }

    @Test func grandfatherLabel() throws {
        let builder = try TestTreeBuilder()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let father = addParent(of: owner, sex: .male, in: builder)
        let grandfather = addParent(of: father, sex: .male, in: builder)

        let label = RelationshipLabel.label(from: owner, to: grandfather, using: graphService)
        #expect(label == "Grandfather")
    }

    @Test func grandmotherLabel() throws {
        let builder = try TestTreeBuilder()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let mother = addParent(of: owner, sex: .female, in: builder)
        let grandmother = addParent(of: mother, sex: .female, in: builder)

        let label = RelationshipLabel.label(from: owner, to: grandmother, using: graphService)
        #expect(label == "Grandmother")
    }

    @Test func grandsonLabel() throws {
        let builder = try TestTreeBuilder()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let child = addChild(of: owner, sex: .unknown, in: builder)
        let grandson = addChild(of: child, sex: .male, in: builder)

        let label = RelationshipLabel.label(from: owner, to: grandson, using: graphService)
        #expect(label == "Grandson")
    }

    @Test func granddaughterLabel() throws {
        let builder = try TestTreeBuilder()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let child = addChild(of: owner, sex: .unknown, in: builder)
        let granddaughter = addChild(of: child, sex: .female, in: builder)

        let label = RelationshipLabel.label(from: owner, to: granddaughter, using: graphService)
        #expect(label == "Granddaughter")
    }

    @Test func parentPartnerLabel() throws {
        let builder = try TestTreeBuilder()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let father = addParent(of: owner, sex: .male, in: builder)
        let stepParent = addPartner(of: father, in: builder)  // father's partner, not owner's parent

        let label = RelationshipLabel.label(from: owner, to: stepParent, using: graphService)
        #expect(label == "Parent's partner")
    }

    @Test func partnersChildLabel() throws {
        let builder = try TestTreeBuilder()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let partner = addPartner(of: owner, in: builder)
        let stepChild = addChild(of: partner, sex: .unknown, in: builder)  // partner's child, not owner's

        let label = RelationshipLabel.label(from: owner, to: stepChild, using: graphService)
        #expect(label == "Partner's child")
    }

    // MARK: - Depth 3 (always concatenated)

    @Test func depthThreeConcatenatesLabel() throws {
        let builder = try TestTreeBuilder()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let father = addParent(of: owner, sex: .male, in: builder)
        let grandmother = addParent(of: father, sex: .female, in: builder)
        let greatGrandparent = addParent(of: grandmother, sex: .unknown, in: builder)

        let label = RelationshipLabel.label(from: owner, to: greatGrandparent, using: graphService)
        #expect(label == "Father's mother's parent")
    }

    // MARK: - Depth 3 — aunt/uncle & niece/nephew

    @Test func uncleLabel() throws {
        let builder = try TestTreeBuilder()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let parent = addParent(of: owner, in: builder)
        let grandparent = addParent(of: parent, in: builder)
        let uncle = addChild(of: grandparent, sex: .male, in: builder)  // parent's brother

        let label = RelationshipLabel.label(from: owner, to: uncle, using: graphService)
        #expect(label == "Uncle")
    }

    @Test func auntLabel() throws {
        let builder = try TestTreeBuilder()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let parent = addParent(of: owner, in: builder)
        let grandparent = addParent(of: parent, in: builder)
        let aunt = addChild(of: grandparent, sex: .female, in: builder)  // parent's sister

        let label = RelationshipLabel.label(from: owner, to: aunt, using: graphService)
        #expect(label == "Aunt")
    }

    @Test func auntOrUncleLabelWhenSexUnknown() throws {
        let builder = try TestTreeBuilder()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let parent = addParent(of: owner, in: builder)
        let grandparent = addParent(of: parent, in: builder)
        let pibling = addChild(of: grandparent, sex: .unknown, in: builder)

        let label = RelationshipLabel.label(from: owner, to: pibling, using: graphService)
        #expect(label == "Aunt or uncle")
    }

    @Test func nephewLabel() throws {
        let builder = try TestTreeBuilder()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let parent = addParent(of: owner, in: builder)
        let sibling = addChild(of: parent, sex: .unknown, in: builder)  // owner's sibling
        let nephew = addChild(of: sibling, sex: .male, in: builder)

        let label = RelationshipLabel.label(from: owner, to: nephew, using: graphService)
        #expect(label == "Nephew")
    }

    @Test func nieceLabel() throws {
        let builder = try TestTreeBuilder()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let parent = addParent(of: owner, in: builder)
        let sibling = addChild(of: parent, sex: .unknown, in: builder)
        let niece = addChild(of: sibling, sex: .female, in: builder)

        let label = RelationshipLabel.label(from: owner, to: niece, using: graphService)
        #expect(label == "Niece")
    }

    @Test func nieceOrNephewLabelWhenSexUnknown() throws {
        let builder = try TestTreeBuilder()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let parent = addParent(of: owner, in: builder)
        let sibling = addChild(of: parent, sex: .unknown, in: builder)
        let nibling = addChild(of: sibling, sex: .unknown, in: builder)

        let label = RelationshipLabel.label(from: owner, to: nibling, using: graphService)
        #expect(label == "Niece or nephew")
    }

    // MARK: - Depth 4 — cousins

    @Test func cousinLabel() throws {
        let builder = try TestTreeBuilder()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let parent = addParent(of: owner, in: builder)
        let grandparent = addParent(of: parent, in: builder)
        let uncle = addChild(of: grandparent, sex: .male, in: builder)  // parent's sibling
        let cousin = addChild(of: uncle, sex: .female, in: builder)     // cousin — gender-neutral label

        let label = RelationshipLabel.label(from: owner, to: cousin, using: graphService)
        #expect(label == "Cousin")
    }

    @Test func cousinLabelIsGenderNeutral() throws {
        let builder = try TestTreeBuilder()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let parent = addParent(of: owner, in: builder)
        let grandparent = addParent(of: parent, in: builder)
        let aunt = addChild(of: grandparent, sex: .female, in: builder)
        let cousin = addChild(of: aunt, sex: .male, in: builder)

        let label = RelationshipLabel.label(from: owner, to: cousin, using: graphService)
        #expect(label == "Cousin")
    }

    // MARK: - End-to-end via TreeMutationService (matches how the app builds relations)

    @Test func uncleViaMutationServiceIsLabelled() throws {
        let builder = try TestTreeBuilder()
        let service = TreeMutationService()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let parent = try service.addParent(to: owner, firstName: "Parent", lastName: "", birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context)
        _ = try service.addParent(to: parent, firstName: "GP", lastName: "", birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context)
        let uncle = try service.addSibling(to: parent, firstName: "Uncle", lastName: "", birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context)
        uncle.sex = .male

        let label = RelationshipLabel.label(from: owner, to: uncle, using: graphService)
        #expect(label == "Uncle")
    }

    @Test func cousinViaMutationServiceIsLabelled() throws {
        let builder = try TestTreeBuilder()
        let service = TreeMutationService()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let parent = try service.addParent(to: owner, firstName: "Parent", lastName: "", birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context)
        _ = try service.addParent(to: parent, firstName: "GP", lastName: "", birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context)
        let uncle = try service.addSibling(to: parent, firstName: "Uncle", lastName: "", birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context)
        let cousin = try service.addChild(to: uncle, firstName: "Cousin", lastName: "", birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context)

        let label = RelationshipLabel.label(from: owner, to: cousin, using: graphService)
        #expect(label == "Cousin")
    }

    @Test func siblingInParentlessGroupIsLabelled() throws {
        // Given a sibling added to a person who has no recorded parents
        // (a partnerless sibling-group union — only creatable via addSibling)
        let builder = try TestTreeBuilder()
        let service = TreeMutationService()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        let sibling = try service.addSibling(to: owner, firstName: "Sib", lastName: "", birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context)
        sibling.sex = .male

        let label = RelationshipLabel.label(from: owner, to: sibling, using: graphService)
        #expect(label == "Brother")
    }

    // MARK: - Bounds & cycles

    @Test func extendedFamilyLabel() throws {
        let builder = try TestTreeBuilder()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)
        // A five-generation chain: the top person is four hops up, beyond the depth-3 cap.
        let p1 = addParent(of: owner, in: builder)
        let p2 = addParent(of: p1, in: builder)
        let p3 = addParent(of: p2, in: builder)
        let p4 = addParent(of: p3, in: builder)

        let label = RelationshipLabel.label(from: owner, to: p4, using: graphService)
        #expect(label == "Extended family")
    }

    @Test func noBfsLoopOnCrossBranch() throws {
        let builder = try TestTreeBuilder()
        let tree = UUID()
        let owner = builder.makePerson(firstName: "Owner", treeId: tree)

        // Path A (short): father is the owner's parent — one hop.
        let father = builder.makePerson(firstName: "Father", treeId: tree)
        father.sex = .male
        let parentUnion = builder.makeUnion(treeId: tree)
        builder.link(person: father, to: parentUnion, role: .partner)
        builder.link(person: owner, to: parentUnion, role: .child, childType: .biological)

        // Path B (long): the owner's partner shares parents with `father`, so father is also
        // reachable as owner → partner → grandparent → father (three hops).
        let partner = addPartner(of: owner, in: builder)
        let sharedGrandparent = builder.makePerson(firstName: "GP", treeId: tree)
        let siblingUnion = builder.makeUnion(treeId: tree)
        builder.link(person: sharedGrandparent, to: siblingUnion, role: .partner)
        builder.link(person: partner, to: siblingUnion, role: .child, childType: .biological)
        builder.link(person: father, to: siblingUnion, role: .child, childType: .biological)

        // BFS must terminate and return the shortest path's label, not loop between branches.
        let label = RelationshipLabel.label(from: owner, to: father, using: graphService)
        #expect(label == "Father")
    }
}

// MARK: - Graph-building helpers

/// Adds a parent of `child` through a fresh union and returns the new parent.
@discardableResult
private func addParent(of child: Person, sex: Sex = .unknown, in builder: TestTreeBuilder) -> Person {
    let parent = builder.makePerson(firstName: "Parent-\(UUID().uuidString.prefix(4))", treeId: child.treeId)
    parent.sex = sex
    let union = builder.makeUnion(treeId: child.treeId)
    builder.link(person: parent, to: union, role: .partner)
    builder.link(person: child, to: union, role: .child, childType: .biological)
    return parent
}

/// Adds a child of `parent` through a fresh union and returns the new child.
@discardableResult
private func addChild(of parent: Person, sex: Sex = .unknown, in builder: TestTreeBuilder) -> Person {
    let child = builder.makePerson(firstName: "Child-\(UUID().uuidString.prefix(4))", treeId: parent.treeId)
    child.sex = sex
    let union = builder.makeUnion(treeId: parent.treeId)
    builder.link(person: parent, to: union, role: .partner)
    builder.link(person: child, to: union, role: .child, childType: .biological)
    return child
}

/// Adds a partner of `person` through a fresh union and returns the new partner.
@discardableResult
private func addPartner(of person: Person, in builder: TestTreeBuilder) -> Person {
    let partner = builder.makePerson(firstName: "Partner-\(UUID().uuidString.prefix(4))", treeId: person.treeId)
    let union = builder.makeUnion(treeId: person.treeId)
    builder.link(person: person, to: union, role: .partner)
    builder.link(person: partner, to: union, role: .partner)
    return partner
}
