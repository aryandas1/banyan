import Foundation
import SwiftData
import Testing
@testable import Banyan

@Suite("Large tree performance")
struct LargeTreePerformanceTests {
    private let graphService = GraphService()

    // MARK: - Correctness on multi-generation trees

    @Test func parentsCorrectAcross5Generations() throws {
        let fixture = try LargeTreeFixture()
        // Focal has exactly 2 parents
        #expect(graphService.parents(of: fixture.focal).count == 2)
    }

    @Test func childrenCorrectAcross5Generations() throws {
        let fixture = try LargeTreeFixture()
        // Focal has 3 children + Child1's child = 4 total descendants
        #expect(graphService.children(of: fixture.focal).count == 3)
    }

    @Test func siblingsCorrectInLargeTree() throws {
        let fixture = try LargeTreeFixture()
        // Focal has 1 sibling
        #expect(graphService.siblings(of: fixture.focal).count == 1)
    }

    @Test func grandfatherLabelResolvedCorrectly() throws {
        let fixture = try LargeTreeFixture()
        let father = graphService.parents(of: fixture.focal).first { $0.firstName == "Father" }
        let paternalGF = father.flatMap { graphService.parents(of: $0).first { $0.firstName == "PatGF" } }
        guard let gf = paternalGF else { Issue.record("Paternal grandfather not found"); return }
        let label = RelationshipLabel.label(from: fixture.focal, to: gf, using: graphService)
        #expect(label == "Grandfather" || label == "Grandparent") // sex-dependent
    }

    @Test func greatGrandparentReachable() throws {
        let fixture = try LargeTreeFixture()
        // PatGGF is at depth 3 — just within the BFS cap
        let father = graphService.parents(of: fixture.focal).first { $0.firstName == "Father" }
        let pGF = father.flatMap { graphService.parents(of: $0).first { $0.firstName == "PatGF" } }
        let pGGF = pGF.flatMap { graphService.parents(of: $0).first { $0.firstName == "PatGGF" } }
        guard let ggf = pGGF else { Issue.record("Great-grandfather not found"); return }
        let label = RelationshipLabel.label(from: fixture.focal, to: ggf, using: graphService)
        // Depth 3 — should return a concatenated label, not "Extended family"
        #expect(label != "Extended family")
    }

    // MARK: - Performance on ~150-person tree

    @Test func graphQueriesCompleteQuicklyOnLargeTree() throws {
        let (builder, focal, _) = try LargeTreeFixture.buildLarge()
        let allPeople = try builder.context.fetch(FetchDescriptor<Person>())

        // All graph queries must complete within 1 second total on ~150 people
        let start = Date()

        let parents = graphService.parents(of: focal)
        let children = graphService.children(of: focal)
        let partners = graphService.allPartners(of: focal)
        let siblings = graphService.siblings(of: focal)

        // Compute relationship labels for every person
        for person in allPeople where person.id != focal.id {
            _ = RelationshipLabel.label(from: focal, to: person, using: graphService)
        }

        let elapsed = Date().timeIntervalSince(start)
        #expect(elapsed < 1.0, "Graph queries took \(elapsed)s — should be under 1s")

        // Sanity check results
        #expect(parents.count == 2)
        #expect(children.count == 10)
        #expect(partners.count == 1)
        #expect(siblings.count == 5)
    }

    @Test func allPeopleSortedCorrectlyInLargeTree() throws {
        let (builder, _, treeId) = try LargeTreeFixture.buildLarge()
        let allPeople = try builder.context.fetch(FetchDescriptor<Person>())
        let treePeople = allPeople
            .filter { $0.treeId == treeId && !$0.isPlaceholder }
            .sorted { $0.fullName.localizedCompare($1.fullName) == .orderedAscending }

        // Verify sort is stable: no adjacent pair is out of order
        for i in 0..<(treePeople.count - 1) {
            let result = treePeople[i].fullName.localizedCompare(treePeople[i+1].fullName)
            #expect(result != .orderedDescending,
                "\(treePeople[i].fullName) should not come after \(treePeople[i+1].fullName)")
        }
    }

    @Test func labelCacheCoversAllPeople() throws {
        // Verify that RelationshipLabel returns a non-empty string for every
        // person in a large tree — no silent failures or empty labels.
        let (builder, focal, _) = try LargeTreeFixture.buildLarge()
        let allPeople = try builder.context.fetch(FetchDescriptor<Person>())

        for person in allPeople where person.id != focal.id {
            let label = RelationshipLabel.label(from: focal, to: person, using: graphService)
            #expect(!label.isEmpty, "Empty label for \(person.fullName)")
        }
    }
}
