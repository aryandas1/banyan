// TreeSwitcherTests.swift
// The pure option-builder for the tree switcher: owned-first ordering, focal-name
// labels with a fallback, de-duplication of the owned tree, and the single/empty
// cases the toolbar uses to decide whether to show the menu at all.

import Foundation
import Testing
@testable import Banyan

@Suite("TreeSwitcher")
struct TreeSwitcherTests {

    @Test func emptyWhenNoTrees() {
        let options = TreeSwitcher.options(
            ownerTreeId: nil, viewerTreeIds: [], focalName: { _ in nil }
        )
        #expect(options.isEmpty)
    }

    @Test func onlyOwnedReturnsASingleOwnedOption() {
        // Given only an owned tree with a resolvable focal
        let owned = UUID()
        let options = TreeSwitcher.options(
            ownerTreeId: owned, viewerTreeIds: [], focalName: { _ in "Ravi" }
        )

        // Then there's one option, marked owned, labeled by the focal person
        #expect(options.count == 1)
        #expect(options[0].treeId == owned)
        #expect(options[0].isOwned)
        #expect(options[0].label == "Ravi's family")
    }

    @Test func ownedTreeIsListedFirstThenViewedTrees() {
        // Given an owned tree and two viewed trees
        let owned = UUID(); let viewedA = UUID(); let viewedB = UUID()
        let names = [owned: "Ravi", viewedA: "Zara", viewedB: "Meera"]

        let options = TreeSwitcher.options(
            ownerTreeId: owned,
            viewerTreeIds: [viewedA, viewedB],
            focalName: { names[$0] }
        )

        // Then the owned tree is first, and the viewed trees follow sorted by label
        #expect(options.map(\.treeId) == [owned, viewedB, viewedA])   // Ravi, Meera, Zara
        #expect(options.map(\.isOwned) == [true, false, false])
        #expect(options.map(\.label) == ["Ravi's family", "Meera's family", "Zara's family"])
    }

    @Test func fallsBackToGenericLabelWhenFocalNameMissingOrBlank() {
        // Given trees whose focal can't be resolved (nil) or is blank/whitespace
        let owned = UUID(); let viewed = UUID()
        let options = TreeSwitcher.options(
            ownerTreeId: owned,
            viewerTreeIds: [viewed],
            focalName: { $0 == owned ? "   " : nil }
        )

        // Then both fall back to the generic label
        #expect(options.allSatisfy { $0.label == TreeSwitcher.fallbackLabel })
    }

    @Test func ownedTreeIsNotDuplicatedWhenAlsoInViewerSet() {
        // Given the owned tree id also appears in the viewer set (e.g. a stale entry)
        let owned = UUID()
        let options = TreeSwitcher.options(
            ownerTreeId: owned,
            viewerTreeIds: [owned],
            focalName: { _ in "Ravi" }
        )

        // Then it appears once, as the owned tree — never as a viewed duplicate
        #expect(options.count == 1)
        #expect(options[0].isOwned)
    }

    @Test func viewedTreesWithEqualLabelsAreOrderedDeterministicallyById() {
        // Given two viewed trees that resolve to the SAME label
        let a = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
        let b = UUID(uuidString: "00000000-0000-0000-0000-0000000000BB")!
        func build() -> [UUID] {
            TreeSwitcher.options(ownerTreeId: nil, viewerTreeIds: [a, b], focalName: { _ in "Sam" })
                .map(\.treeId)
        }

        // Then ties break on the id's string form (…AA < …BB), stable across calls
        #expect(build() == [a, b])
        #expect(build() == build())
    }

    @Test func viewerOnlyDeviceListsViewedTreesWithNoOwned() {
        // Given no owned tree, two viewed trees
        let a = UUID(); let b = UUID()
        let options = TreeSwitcher.options(
            ownerTreeId: nil,
            viewerTreeIds: [a, b],
            focalName: { $0 == a ? "Anaya" : "Bram" }
        )

        #expect(options.count == 2)
        #expect(options.allSatisfy { !$0.isOwned })
        #expect(options.map(\.label) == ["Anaya's family", "Bram's family"])
    }
}
