// LargeTreeFixture.swift
// Builds multi-generation family trees through the real TreeMutationService, so correctness
// and performance tests exercise the same union-reuse rules the app uses. Lives beside
// TestTreeBuilder — every test constructs its own, so no state is shared.

import Foundation
import SwiftData
@testable import Banyan

/// Builds a multi-generation family tree for performance and correctness testing.
/// The resulting tree has a predictable shape so tests can make specific assertions.
struct LargeTreeFixture {

    let builder: TestTreeBuilder
    let treeId: UUID
    let service: TreeMutationService

    /// The focal person at the centre of the tree (generation 3 of 5).
    let focal: Person

    /// All people in the fixture tree.
    var allPeople: [Person] {
        (try? builder.context.fetch(FetchDescriptor<Person>())) ?? []
    }

    /// Builds a 5-generation tree with this shape:
    /// The tree is deliberately asymmetric — just enough on each branch to reach every
    /// depth the labelling BFS cares about:
    ///
    /// Gen 1 (great-grandparents): 2 people — paternal only (PatGGF, PatGGM, via PatGF)
    /// Gen 2 (grandparents):       4 people — paternal (PatGF, PatGM) + maternal (MatGF, MatGM)
    /// Gen 3 (parents + focal):    4 people — focal, one sibling, and focal's parents (Father, Mother)
    /// Gen 4 (focal's children):   4 people — focal's partner + 3 children (Child1–3)
    /// Gen 5 (grandchild):         1 person  — GrandChild1, child of Child1
    ///
    /// Total: 15 people, no placeholders — enough to exercise multi-generation traversal.
    /// For a larger fixture (~150 people) use `buildLarge()`.
    init() throws {
        builder = try TestTreeBuilder()
        treeId = UUID()
        service = TreeMutationService()
        focal = builder.makePerson(firstName: "Focal", lastName: "Sharma", treeId: treeId)
        buildTree()
    }

    private func buildTree() {
        // Gen 3: focal's parents
        let father = try! service.addParent(to: focal, firstName: "Father", lastName: "Sharma",
            birthDate: PartialDate(year: 1958), isDeceased: false, deathDate: nil, in: builder.context)
        let mother = try! service.addParent(to: focal, firstName: "Mother", lastName: "Sharma",
            birthDate: PartialDate(year: 1960), isDeceased: false, deathDate: nil, in: builder.context)

        // Gen 3: focal's sibling
        _ = try! service.addChild(to: father, firstName: "Sibling", lastName: "Sharma",
            birthDate: PartialDate(year: 1985), isDeceased: false, deathDate: nil, in: builder.context)

        // Gen 2: father's parents (paternal grandparents)
        let paternalGF = try! service.addParent(to: father, firstName: "PatGF", lastName: "Sharma",
            birthDate: PartialDate(year: 1930), isDeceased: true, deathDate: PartialDate(year: 2010), in: builder.context)
        _ = try! service.addParent(to: father, firstName: "PatGM", lastName: "Sharma",
            birthDate: PartialDate(year: 1932), isDeceased: false, deathDate: nil, in: builder.context)

        // Gen 2: mother's parents (maternal grandparents)
        _ = try! service.addParent(to: mother, firstName: "MatGF", lastName: "Patel",
            birthDate: PartialDate(year: 1935), isDeceased: true, deathDate: PartialDate(year: 2015), in: builder.context)
        _ = try! service.addParent(to: mother, firstName: "MatGM", lastName: "Patel",
            birthDate: PartialDate(year: 1938), isDeceased: false, deathDate: nil, in: builder.context)

        // Gen 1: paternal great-grandparents
        _ = try! service.addParent(to: paternalGF, firstName: "PatGGF", lastName: "Sharma",
            birthDate: PartialDate(year: 1900), isDeceased: true, deathDate: PartialDate(year: 1975), in: builder.context)
        _ = try! service.addParent(to: paternalGF, firstName: "PatGGM", lastName: "Sharma",
            birthDate: PartialDate(year: 1902), isDeceased: true, deathDate: PartialDate(year: 1980), in: builder.context)

        // Gen 4: focal's partner and children
        _ = try! service.addPartner(to: focal, firstName: "Partner", lastName: "Mehta",
            birthDate: PartialDate(year: 1990), isDeceased: false, deathDate: nil, in: builder.context)
        let child1 = try! service.addChild(to: focal, firstName: "Child1", lastName: "Sharma",
            birthDate: PartialDate(year: 2015), isDeceased: false, deathDate: nil, in: builder.context)
        _ = try! service.addChild(to: focal, firstName: "Child2", lastName: "Sharma",
            birthDate: PartialDate(year: 2018), isDeceased: false, deathDate: nil, in: builder.context)
        _ = try! service.addChild(to: focal, firstName: "Child3", lastName: "Sharma",
            birthDate: PartialDate(year: 2020), isDeceased: false, deathDate: nil, in: builder.context)

        // Gen 5: grandchild
        _ = try! service.addChild(to: child1, firstName: "GrandChild1", lastName: "Sharma",
            birthDate: PartialDate(year: 2040), isDeceased: false, deathDate: nil, in: builder.context)
    }

    /// Builds a larger tree with ~150 people by creating multiple branches.
    static func buildLarge() throws -> (builder: TestTreeBuilder, focal: Person, treeId: UUID) {
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let service = TreeMutationService()
        let focal = builder.makePerson(firstName: "Root", treeId: treeId)

        // Add 4 generations of ancestors: 2 parents, 4 grandparents, 8 great-grandparents
        var parents: [Person] = []
        for i in 0..<2 {
            let parent = try service.addParent(to: focal, firstName: "P\(i)", lastName: "",
                birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context)
            parents.append(parent)
        }
        var grandparents: [Person] = []
        for parent in parents {
            for i in 0..<2 {
                let gp = try service.addParent(to: parent, firstName: "GP\(i)", lastName: "",
                    birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context)
                grandparents.append(gp)
            }
        }
        for gp in grandparents {
            for i in 0..<2 {
                _ = try service.addParent(to: gp, firstName: "GGP\(i)", lastName: "",
                    birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context)
            }
        }

        // Add 5 siblings to focal
        for i in 0..<5 {
            _ = try service.addChild(to: parents[0], firstName: "Sib\(i)", lastName: "",
                birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context)
        }

        // Give the focal a partner so the 10 children below hang off one couple's union
        // (matching the small fixture's shape) and allPartners(of: focal) == 1.
        _ = try service.addPartner(to: focal, firstName: "Partner", lastName: "",
            birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context)

        // Add 10 children to focal
        for i in 0..<10 {
            let child = try service.addChild(to: focal, firstName: "C\(i)", lastName: "",
                birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context)
            // Add 3 children to each of focal's children (grandchildren)
            for j in 0..<3 {
                _ = try service.addChild(to: child, firstName: "GC\(i)\(j)", lastName: "",
                    birthDate: nil, isDeceased: false, deathDate: nil, in: builder.context)
            }
        }

        return (builder, focal, treeId)
    }
}
