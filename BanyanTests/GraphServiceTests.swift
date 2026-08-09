// GraphServiceTests.swift
// Traversal rules of the person-union graph.

import Foundation
import Testing
@testable import Banyan

@Suite("GraphService")
struct GraphServiceTests {
    // Each test creates its own in-memory container via TestTreeBuilder.
    // Tests are independent — no shared state.

    @Test func parentsReturnsBothParents() async throws {
        // Given a child in a union with two partners
        let builder = try TestTreeBuilder()
        let service = GraphService()
        let father = builder.makePerson(firstName: "Ravi")
        let mother = builder.makePerson(firstName: "Meera")
        let child = builder.makePerson(firstName: "Anil")
        let union = builder.makeUnion()
        builder.link(person: father, to: union, role: .partner)
        builder.link(person: mother, to: union, role: .partner)
        builder.link(person: child, to: union, role: .child, childType: .biological)

        // When asking for the child's parents
        let parents = service.parents(of: child)

        // Then both partners come back
        #expect(parents.count == 2)
        #expect(Set(parents.map(\.id)) == Set([father.id, mother.id]))
    }

    @Test func parentsReturnsEmptyWhenNone() async throws {
        // Given a person who is a child of no union
        let builder = try TestTreeBuilder()
        let service = GraphService()
        let orphan = builder.makePerson(firstName: "Solo")

        // When asking for parents
        let parents = service.parents(of: orphan)

        // Then there are none
        #expect(parents.isEmpty)
    }

    @Test func childrenAcrossTwoUnions() async throws {
        // Given a parent with one child in each of two unions
        let builder = try TestTreeBuilder()
        let service = GraphService()
        let parent = builder.makePerson(firstName: "Ravi")
        let firstSpouse = builder.makePerson(firstName: "Meera")
        let secondSpouse = builder.makePerson(firstName: "Lata")
        let firstChild = builder.makePerson(firstName: "Anil")
        let secondChild = builder.makePerson(firstName: "Bina")

        let firstUnion = builder.makeUnion()
        builder.link(person: parent, to: firstUnion, role: .partner)
        builder.link(person: firstSpouse, to: firstUnion, role: .partner)
        builder.link(person: firstChild, to: firstUnion, role: .child)

        let secondUnion = builder.makeUnion()
        builder.link(person: parent, to: secondUnion, role: .partner)
        builder.link(person: secondSpouse, to: secondUnion, role: .partner)
        builder.link(person: secondChild, to: secondUnion, role: .child)

        // When asking for the parent's children
        let children = service.children(of: parent)

        // Then children from both unions come back
        #expect(children.count == 2)
        #expect(Set(children.map(\.id)) == Set([firstChild.id, secondChild.id]))
    }

    @Test func childrenEmptyWhenNone() async throws {
        // Given a childless couple
        let builder = try TestTreeBuilder()
        let service = GraphService()
        let person = builder.makePerson(firstName: "Ravi")
        let spouse = builder.makePerson(firstName: "Meera")
        let union = builder.makeUnion()
        builder.link(person: person, to: union, role: .partner)
        builder.link(person: spouse, to: union, role: .partner)

        // When asking for children
        let children = service.children(of: person)

        // Then there are none
        #expect(children.isEmpty)
    }

    @Test func allPartnersWithRemarriage() async throws {
        // Given a person married twice
        let builder = try TestTreeBuilder()
        let service = GraphService()
        let person = builder.makePerson(firstName: "Ravi")
        let firstSpouse = builder.makePerson(firstName: "Meera")
        let secondSpouse = builder.makePerson(firstName: "Lata")

        let firstUnion = builder.makeUnion()
        builder.link(person: person, to: firstUnion, role: .partner)
        builder.link(person: firstSpouse, to: firstUnion, role: .partner)

        let secondUnion = builder.makeUnion()
        builder.link(person: person, to: secondUnion, role: .partner)
        builder.link(person: secondSpouse, to: secondUnion, role: .partner)

        // When asking for all partners
        let partners = service.allPartners(of: person)

        // Then both spouses come back, and never the person themselves
        #expect(partners.count == 2)
        #expect(Set(partners.map(\.id)) == Set([firstSpouse.id, secondSpouse.id]))
        #expect(!partners.contains { $0.id == person.id })
    }

    @Test func siblingsFromSameUnion() async throws {
        // Given three children of one union
        let builder = try TestTreeBuilder()
        let service = GraphService()
        let union = builder.makeUnion()
        let first = builder.makePerson(firstName: "Anil")
        let second = builder.makePerson(firstName: "Bina")
        let third = builder.makePerson(firstName: "Chandra")
        builder.link(person: first, to: union, role: .child)
        builder.link(person: second, to: union, role: .child)
        builder.link(person: third, to: union, role: .child)

        // When asking for one child's siblings
        let siblings = service.siblings(of: first)

        // Then the other two come back, excluding the person themselves
        #expect(siblings.count == 2)
        #expect(Set(siblings.map(\.id)) == Set([second.id, third.id]))
        #expect(!siblings.contains { $0.id == first.id })
    }

    @Test func halfSiblingsFromDifferentUnions() async throws {
        // Given a father with a child by each of two unions.
        // `siblings(of:)` is defined as "people who share at least one parent union",
        // so a half-sibling attached to a *different* union is not a sibling.
        let builder = try TestTreeBuilder()
        let service = GraphService()
        let father = builder.makePerson(firstName: "Ravi")
        let firstMother = builder.makePerson(firstName: "Meera")
        let secondMother = builder.makePerson(firstName: "Lata")
        let child = builder.makePerson(firstName: "Anil")
        let halfSibling = builder.makePerson(firstName: "Bina")

        let firstUnion = builder.makeUnion()
        builder.link(person: father, to: firstUnion, role: .partner)
        builder.link(person: firstMother, to: firstUnion, role: .partner)
        builder.link(person: child, to: firstUnion, role: .child)

        let secondUnion = builder.makeUnion()
        builder.link(person: father, to: secondUnion, role: .partner)
        builder.link(person: secondMother, to: secondUnion, role: .partner)
        builder.link(person: halfSibling, to: secondUnion, role: .child)

        // When asking for siblings
        let siblings = service.siblings(of: child)

        // Then the half-sibling is not among them — they share a parent, not a parent union
        #expect(siblings.isEmpty)
        #expect(!siblings.contains { $0.id == halfSibling.id })

        // But the shared parent is visible from both sides
        #expect(service.children(of: father).count == 2)
    }

    @Test func onlyChildHasNoSiblings() async throws {
        // Given a single child of a union
        let builder = try TestTreeBuilder()
        let service = GraphService()
        let union = builder.makeUnion()
        let onlyChild = builder.makePerson(firstName: "Anil")
        builder.link(person: onlyChild, to: union, role: .child)

        // When asking for siblings
        let siblings = service.siblings(of: onlyChild)

        // Then there are none — and the child is not their own sibling
        #expect(siblings.isEmpty)
    }

    @Test func allPeopleFiltersTreeId() async throws {
        // Given people in two different trees
        let builder = try TestTreeBuilder()
        let service = GraphService()
        let treeId = UUID()
        let otherTreeId = UUID()
        let mine = builder.makePerson(firstName: "Anil", lastName: "Das", treeId: treeId)
        let alsoMine = builder.makePerson(firstName: "Bina", lastName: "Das", treeId: treeId)
        let theirs = builder.makePerson(firstName: "Zara", lastName: "Khan", treeId: otherTreeId)

        // When asking for one tree's people
        let people = service.allPeople(treeId: treeId, from: [mine, alsoMine, theirs])

        // Then only that tree's people come back
        #expect(people.count == 2)
        #expect(Set(people.map(\.id)) == Set([mine.id, alsoMine.id]))
    }

    @Test func allPeopleSortsAlphabetically() async throws {
        // Given people added out of order
        let builder = try TestTreeBuilder()
        let service = GraphService()
        let treeId = UUID()
        let charlie = builder.makePerson(firstName: "Chandra", lastName: "Das", treeId: treeId)
        let alice = builder.makePerson(firstName: "Anil", lastName: "Das", treeId: treeId)
        let bob = builder.makePerson(firstName: "Bina", lastName: "Das", treeId: treeId)

        // When asking for the tree's people
        let people = service.allPeople(treeId: treeId, from: [charlie, alice, bob])

        // Then they come back sorted by fullName
        #expect(people.map(\.fullName) == ["Anil Das", "Bina Das", "Chandra Das"])
    }

    // MARK: - coParentableUnion

    @Test func coParentableUnionFindsSingleOneParentChildedUnion() throws {
        // Given a lone parent (one partner) with a child
        let builder = try TestTreeBuilder()
        let service = GraphService()
        let dad = builder.makePerson(firstName: "Dad")
        let kid = builder.makePerson(firstName: "Kid")
        let union = builder.makeUnion()
        builder.link(person: dad, to: union, role: .partner)
        builder.link(person: kid, to: union, role: .child)

        // Then that union is the one a new partner could co-parent
        #expect(service.coParentableUnion(for: dad)?.id == union.id)
    }

    @Test func coParentableUnionNilWhenUnionAlreadyHasTwoPartners() throws {
        // Given a child whose union already has both parents
        let builder = try TestTreeBuilder()
        let service = GraphService()
        let dad = builder.makePerson(firstName: "Dad")
        let mom = builder.makePerson(firstName: "Mom")
        let kid = builder.makePerson(firstName: "Kid")
        let union = builder.makeUnion()
        builder.link(person: dad, to: union, role: .partner)
        builder.link(person: mom, to: union, role: .partner)
        builder.link(person: kid, to: union, role: .child)

        // Then there is no lone-parent union to co-parent
        #expect(service.coParentableUnion(for: dad) == nil)
    }

    @Test func coParentableUnionNilWhenNoChildren() throws {
        // Given a childless partnership
        let builder = try TestTreeBuilder()
        let service = GraphService()
        let dad = builder.makePerson(firstName: "Dad")
        let union = builder.makeUnion()
        builder.link(person: dad, to: union, role: .partner)

        // Then nothing to co-parent
        #expect(service.coParentableUnion(for: dad) == nil)
    }

    @Test func coParentableUnionNilWhenAmbiguous() throws {
        // Given a lone parent across TWO separate childed unions
        let builder = try TestTreeBuilder()
        let service = GraphService()
        let dad = builder.makePerson(firstName: "Dad")
        let kidA = builder.makePerson(firstName: "KidA")
        let kidB = builder.makePerson(firstName: "KidB")
        let unionA = builder.makeUnion()
        let unionB = builder.makeUnion()
        builder.link(person: dad, to: unionA, role: .partner)
        builder.link(person: kidA, to: unionA, role: .child)
        builder.link(person: dad, to: unionB, role: .partner)
        builder.link(person: kidB, to: unionB, role: .child)

        // Then it's ambiguous — never assume which union to co-parent
        #expect(service.coParentableUnion(for: dad) == nil)
    }
}
