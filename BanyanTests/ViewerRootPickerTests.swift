// ViewerRootPickerTests.swift
// The heuristic that chooses a viewer's focal/root from pulled DTOs. Pure logic —
// build small DTO graphs and assert the pick.

import Foundation
import Testing
@testable import Banyan

@Suite("ViewerRootPicker")
struct ViewerRootPickerTests {

    // MARK: - DTO builders

    private func person(_ id: UUID, placeholder: Bool = false, treeId: UUID) -> PersonDTO {
        SharedTreeDTOFactory.person(id: id, treeId: treeId, first: "P", placeholder: placeholder)
    }

    private func link(person pid: UUID, union uid: UUID, role: LinkRole, treeId: UUID) -> PersonUnionLinkDTO {
        SharedTreeDTOFactory.link(treeId: treeId, personId: pid, unionId: uid, role: role)
    }

    // MARK: - Tests

    @Test func returnsNilForEmptyTree() {
        #expect(ViewerRootPicker.pickRoot(persons: [], links: []) == nil)
    }

    @Test func prefersTopAncestorWithDescendants() {
        // Given a grandparent (partner in a union with a child) and that child
        let treeId = UUID()
        let grandparent = UUID()
        let child = UUID()
        let union = UUID()
        let persons = [person(grandparent, treeId: treeId), person(child, treeId: treeId)]
        let links = [
            link(person: grandparent, union: union, role: .partner, treeId: treeId),
            link(person: child, union: union, role: .child, treeId: treeId),
        ]

        // When picking a root
        let root = ViewerRootPicker.pickRoot(persons: persons, links: links)

        // Then the ancestor with descendants wins over the child
        #expect(root == grandparent)
    }

    @Test func neverPicksAChild() {
        // Given two generations, the pick must be the one who is never a child
        let treeId = UUID()
        let parent = UUID()
        let child = UUID()
        let union = UUID()
        let persons = [person(child, treeId: treeId), person(parent, treeId: treeId)]
        let links = [
            link(person: parent, union: union, role: .partner, treeId: treeId),
            link(person: child, union: union, role: .child, treeId: treeId),
        ]

        let root = ViewerRootPicker.pickRoot(persons: persons, links: links)

        #expect(root != child)
        #expect(root == parent)
    }

    @Test func prefersRealPersonOverPlaceholderAncestor() {
        // Given a real top ancestor and a placeholder top ancestor, both childless-partnered
        let treeId = UUID()
        let real = UUID()
        let placeholder = UUID()
        let union = UUID()
        let child = UUID()
        let persons = [
            person(placeholder, placeholder: true, treeId: treeId),
            person(real, treeId: treeId),
            person(child, treeId: treeId),
        ]
        // Both real and placeholder are partners in a union that has the child.
        let links = [
            link(person: real, union: union, role: .partner, treeId: treeId),
            link(person: placeholder, union: union, role: .partner, treeId: treeId),
            link(person: child, union: union, role: .child, treeId: treeId),
        ]

        let root = ViewerRootPicker.pickRoot(persons: persons, links: links)

        #expect(root == real)
    }

    @Test func fallsBackToAnyPersonWhenNoLinks() {
        // Given people but no links, everyone is a "top ancestor"; pick is deterministic
        let treeId = UUID()
        let a = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let b = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let persons = [person(b, treeId: treeId), person(a, treeId: treeId)]

        let root = ViewerRootPicker.pickRoot(persons: persons, links: [])

        // Deterministic tiebreak on the id's string form → the lower id
        #expect(root == a)
    }

    @Test func isDeterministicAcrossReimports() {
        let treeId = UUID()
        let p1 = UUID(), p2 = UUID(), union = UUID()
        let persons = [person(p1, treeId: treeId), person(p2, treeId: treeId)]
        let links = [
            link(person: p1, union: union, role: .partner, treeId: treeId),
            link(person: p2, union: union, role: .child, treeId: treeId),
        ]

        let first = ViewerRootPicker.pickRoot(persons: persons, links: links)
        let second = ViewerRootPicker.pickRoot(persons: persons.reversed(), links: links.reversed())

        #expect(first == second)
    }
}
