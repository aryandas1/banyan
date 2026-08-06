// TestTreeBuilder.swift
// Builds small family graphs in an in-memory container.
// A struct, not a suite fixture — every test makes its own, so no state is shared.

import Foundation
import SwiftData
@testable import Banyan

struct TestTreeBuilder {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Schema(BanyanSchemaV2.models), configurations: config)
        context = ModelContext(container)
        context.autosaveEnabled = false  // required — prevents background writes interfering with tests
    }

    @discardableResult
    func makePerson(firstName: String, lastName: String = "", treeId: UUID = UUID()) -> Person {
        let person = Person(treeId: treeId, firstName: firstName, lastName: lastName)
        context.insert(person)
        return person
    }

    @discardableResult
    func makeUnion(type: UnionType = .married, treeId: UUID = UUID()) -> Union {
        let union = Union(treeId: treeId, type: type)
        context.insert(union)
        return union
    }

    /// Joins a person to a union. Inserted into the context *before* the relationships are wired,
    /// and attached via the to-many sides so SwiftData populates the inverses.
    @discardableResult
    func link(
        person: Person,
        to union: Union,
        role: LinkRole,
        childType: ChildType? = nil
    ) -> PersonUnionLink {
        let link = PersonUnionLink(role: role, childType: childType)
        context.insert(link)
        person.links.append(link)
        union.links.append(link)
        return link
    }
}
