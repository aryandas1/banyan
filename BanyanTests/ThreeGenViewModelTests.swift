// ThreeGenViewModelTests.swift
// The 3-generation snapshot around a focal person: parents, partners, siblings, children.

import Foundation
import Testing
@testable import Banyan

@MainActor
@Suite("ThreeGenViewModel")
struct ThreeGenViewModelTests {

    @Test func parentsPopulatedOnInit() throws {
        // Given a focal person who is a child of a two-partner union
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let focal = builder.makePerson(firstName: "Focal", treeId: treeId)
        let mother = builder.makePerson(firstName: "Mother", treeId: treeId)
        let father = builder.makePerson(firstName: "Father", treeId: treeId)
        let parentUnion = builder.makeUnion(treeId: treeId)
        builder.link(person: mother, to: parentUnion, role: .partner)
        builder.link(person: father, to: parentUnion, role: .partner)
        builder.link(person: focal, to: parentUnion, role: .child)

        // When the view model is created
        let vm = ThreeGenViewModel(focalPerson: focal, graphService: GraphService())

        // Then both parents are loaded
        #expect(vm.parents.count == 2)
        #expect(Set(vm.parents.map(\.id)) == [mother.id, father.id])
    }

    @Test func siblingsPopulatedOnInit() throws {
        // Given a focal person and a sibling sharing the same parent union
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let focal = builder.makePerson(firstName: "Focal", treeId: treeId)
        let sibling = builder.makePerson(firstName: "Sibling", treeId: treeId)
        let parentUnion = builder.makeUnion(treeId: treeId)
        builder.link(person: focal, to: parentUnion, role: .child)
        builder.link(person: sibling, to: parentUnion, role: .child)

        // When the view model is created
        let vm = ThreeGenViewModel(focalPerson: focal, graphService: GraphService())

        // Then the sibling is loaded and the focal person is not their own sibling
        #expect(vm.siblings.count == 1)
        #expect(vm.siblings.first?.id == sibling.id)
    }

    @Test func partnersPopulatedOnInit() throws {
        // Given a focal person with one partner in a union
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let focal = builder.makePerson(firstName: "Focal", treeId: treeId)
        let partner = builder.makePerson(firstName: "Partner", treeId: treeId)
        let union = builder.makeUnion(treeId: treeId)
        builder.link(person: focal, to: union, role: .partner)
        builder.link(person: partner, to: union, role: .partner)

        // When the view model is created
        let vm = ThreeGenViewModel(focalPerson: focal, graphService: GraphService())

        // Then the partner is loaded
        #expect(vm.focalPartners.count == 1)
        #expect(vm.focalPartners.first?.id == partner.id)
    }

    @Test func childrenPopulatedOnInit() throws {
        // Given a focal person with one child in their union
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let focal = builder.makePerson(firstName: "Focal", treeId: treeId)
        let child = builder.makePerson(firstName: "Child", treeId: treeId)
        let union = builder.makeUnion(treeId: treeId)
        builder.link(person: focal, to: union, role: .partner)
        builder.link(person: child, to: union, role: .child)

        // When the view model is created
        let vm = ThreeGenViewModel(focalPerson: focal, graphService: GraphService())

        // Then the child is loaded
        #expect(vm.children.count == 1)
        #expect(vm.children.first?.id == child.id)
    }

    @Test func updateRefreshesData() throws {
        // Given two people, each with one child in their own union
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let personA = builder.makePerson(firstName: "A", treeId: treeId)
        let personB = builder.makePerson(firstName: "B", treeId: treeId)
        let childOfA = builder.makePerson(firstName: "ChildA", treeId: treeId)
        let childOfB = builder.makePerson(firstName: "ChildB", treeId: treeId)
        let unionA = builder.makeUnion(treeId: treeId)
        let unionB = builder.makeUnion(treeId: treeId)
        builder.link(person: personA, to: unionA, role: .partner)
        builder.link(person: childOfA, to: unionA, role: .child)
        builder.link(person: personB, to: unionB, role: .partner)
        builder.link(person: childOfB, to: unionB, role: .child)

        let vm = ThreeGenViewModel(focalPerson: personA, graphService: GraphService())
        #expect(vm.children.map(\.id) == [childOfA.id])

        // When the focal person changes to B
        vm.update(focalPerson: personB)

        // Then the snapshot reflects B's family
        #expect(vm.focalPerson.id == personB.id)
        #expect(vm.children.map(\.id) == [childOfB.id])
    }

    @Test func emptyTreeReturnsEmptyCollections() throws {
        // Given a focal person with no relationships at all
        let builder = try TestTreeBuilder()
        let focal = builder.makePerson(firstName: "Loner", treeId: UUID())

        // When the view model is created
        let vm = ThreeGenViewModel(focalPerson: focal, graphService: GraphService())

        // Then every collection is empty
        #expect(vm.parents.isEmpty)
        #expect(vm.siblings.isEmpty)
        #expect(vm.focalPartners.isEmpty)
        #expect(vm.children.isEmpty)
    }
}
