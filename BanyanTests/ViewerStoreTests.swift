// ViewerStoreTests.swift
// The UserDefaults-backed viewer role/root persistence, exercised against an
// isolated suite so tests never touch the real defaults.

import Foundation
import Testing
@testable import Banyan

@Suite("ViewerStore")
struct ViewerStoreTests {

    /// A ViewerStore over a throwaway UserDefaults suite, unique per test.
    private func makeStore() -> (ViewerStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: "ViewerStoreTests-\(UUID().uuidString)")!
        return (ViewerStore(defaults: defaults), defaults)
    }

    @Test func newTreeIsNotViewerByDefault() {
        let (store, _) = makeStore()
        #expect(store.isViewer(treeId: UUID()) == false)
        #expect(store.viewerTreeIds.isEmpty)
    }

    @Test func addViewerTreeRecordsMembershipRootAndCurrentTree() {
        // Given an empty store
        let (store, defaults) = makeStore()
        let treeId = UUID()
        let root = UUID()

        // When adding a viewed tree
        store.addViewerTree(treeId, rootPersonId: root)

        // Then it's a viewer of that tree, with the stored root...
        #expect(store.isViewer(treeId: treeId))
        #expect(store.rootPersonId(forTree: treeId) == root)
        // ...and it switched the shared "treeId" key (same store as @AppStorage)
        #expect(defaults.string(forKey: "treeId") == treeId.uuidString)
    }

    @Test func addingASecondTreePreservesTheFirst() {
        let (store, _) = makeStore()
        let first = UUID()
        let second = UUID()

        store.addViewerTree(first, rootPersonId: UUID())
        store.addViewerTree(second, rootPersonId: UUID())

        #expect(store.isViewer(treeId: first))
        #expect(store.isViewer(treeId: second))
        #expect(store.viewerTreeIds.count == 2)
    }

    @Test func rootIsNilForUnknownTree() {
        let (store, _) = makeStore()
        #expect(store.rootPersonId(forTree: UUID()) == nil)
    }

    @Test func addViewerTreeWithNilRootStoresNoRoot() {
        let (store, _) = makeStore()
        let treeId = UUID()

        store.addViewerTree(treeId, rootPersonId: nil)

        #expect(store.isViewer(treeId: treeId))
        #expect(store.rootPersonId(forTree: treeId) == nil)
    }

    @Test func persistingRecomputedRootHealsAnEmptyAccept() {
        // Given a tree accepted before the owner synced: viewer with a nil root
        let (store, defaults) = makeStore()
        let treeId = UUID()
        store.addViewerTree(treeId, rootPersonId: nil)
        #expect(store.rootPersonId(forTree: treeId) == nil)

        // When a later refresh persists the recomputed root (the fix's write path)
        let recomputed = UUID()
        store.addViewerTree(treeId, rootPersonId: recomputed)

        // Then the root heals, membership is unchanged, and no duplicate tree entry
        #expect(store.rootPersonId(forTree: treeId) == recomputed)
        #expect(store.isViewer(treeId: treeId))
        #expect(store.viewerTreeIds.count == 1)
        #expect(defaults.string(forKey: "treeId") == treeId.uuidString)
    }
}
