// SyncServiceTests.swift
// The debounced sync orchestration, exercised against an in-memory ModelContext
// and a MockRemoteStore — no real networking. Covers: upserting all local data,
// ensuring the tree row, orphan deletion, empty-tree short-circuits, debounce
// coalescing, and error swallowing.

import Foundation
import SwiftData
import Testing
@testable import Banyan

@MainActor
@Suite("SyncService")
struct SyncServiceTests {

    /// A tree with two partners and their union, saved into an in-memory context.
    private func makeTree() throws -> (builder: TestTreeBuilder, treeId: UUID, a: Person, b: Person, union: Union) {
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let a = builder.makePerson(firstName: "A", treeId: treeId)
        let b = builder.makePerson(firstName: "B", treeId: treeId)
        let union = builder.makeUnion(treeId: treeId)
        builder.link(person: a, to: union, role: .partner)
        builder.link(person: b, to: union, role: .partner)
        try builder.context.save()
        return (builder, treeId, a, b, union)
    }

    @Test func syncEnsuresTreeAndUpsertsAllLocalData() async throws {
        let (builder, treeId, a, b, union) = try makeTree()
        let store = MockRemoteStore()
        let userId = UUID()
        let sync = SyncService(remote: store, currentUserId: { userId }, debounce: .milliseconds(5))

        sync.scheduleSync(treeId: treeId, context: builder.context)
        await sync.awaitPendingSync()

        #expect(store.upsertedTrees.count == 1)
        #expect(store.upsertedTrees.first?.id == treeId)
        #expect(store.upsertedTrees.first?.ownerId == userId)
        #expect(store.upsertedPersonIds == Set([a.id, b.id]))
        #expect(store.upsertedUnionIds == Set([union.id]))
        #expect(store.upsertedLinkIds.count == 2)
        #expect(sync.lastSyncError == nil)
        #expect(sync.lastSyncDate != nil)
    }

    @Test func syncUpsertsParentsBeforeLinksAndDeletesLinksFirst() async throws {
        let (builder, treeId, _, _, _) = try makeTree()
        let store = MockRemoteStore()
        // An orphan in every table, so all three deletes fire and we can order them.
        store.remoteIdsByTable[.persons] = [UUID()]
        store.remoteIdsByTable[.unions]  = [UUID()]
        store.remoteIdsByTable[.links]   = [UUID()]
        let sync = SyncService(remote: store, currentUserId: { UUID() }, debounce: .milliseconds(5))

        sync.scheduleSync(treeId: treeId, context: builder.context)
        await sync.awaitPendingSync()

        // Links reference persons + unions, so they must be upserted last...
        let iLinks   = try #require(store.callLog.firstIndex(of: .upsertLinks))
        let iPersons = try #require(store.callLog.firstIndex(of: .upsertPersons))
        let iUnions  = try #require(store.callLog.firstIndex(of: .upsertUnions))
        #expect(iLinks > iPersons)
        #expect(iLinks > iUnions)

        // ...and deleted first (FK-safe: children before their parents).
        let dLinks   = try #require(store.callLog.firstIndex(of: .delete(.links)))
        let dPersons = try #require(store.callLog.firstIndex(of: .delete(.persons)))
        let dUnions  = try #require(store.callLog.firstIndex(of: .delete(.unions)))
        #expect(dLinks < dPersons)
        #expect(dLinks < dUnions)
    }

    @Test func syncDeletesRemoteOrphansOnly() async throws {
        let (builder, treeId, a, b, _) = try makeTree()
        let store = MockRemoteStore()
        let orphan = UUID()
        // Remote knows about a local person plus one that no longer exists locally.
        store.remoteIdsByTable[.persons] = [a.id, b.id, orphan]
        let sync = SyncService(remote: store, currentUserId: { UUID() }, debounce: .milliseconds(5))

        sync.scheduleSync(treeId: treeId, context: builder.context)
        await sync.awaitPendingSync()

        #expect(store.deleted.contains { $0.table == .persons && $0.id == orphan })
        #expect(!store.deleted.contains { $0.id == a.id })
        #expect(!store.deleted.contains { $0.id == b.id })
    }

    @Test func syncSkipsUpsertWhenTreeHasNoData() async throws {
        let builder = try TestTreeBuilder()
        let store = MockRemoteStore()
        let sync = SyncService(remote: store, currentUserId: { UUID() }, debounce: .milliseconds(5))

        sync.scheduleSync(treeId: UUID(), context: builder.context)   // empty tree
        await sync.awaitPendingSync()

        #expect(store.personUpsertCallCount == 0)   // guarded — no empty upsert
        #expect(store.upsertedTrees.count == 1)      // but the tree row is still ensured
    }

    @Test func debounceCoalescesRapidCalls() async throws {
        let (builder, treeId, _, _, _) = try makeTree()
        let store = MockRemoteStore()
        let sync = SyncService(remote: store, currentUserId: { UUID() }, debounce: .milliseconds(30))

        sync.scheduleSync(treeId: treeId, context: builder.context)
        sync.scheduleSync(treeId: treeId, context: builder.context)
        sync.scheduleSync(treeId: treeId, context: builder.context)
        await sync.awaitPendingSync()

        #expect(store.syncCount == 1)   // only the last of the three actually ran
    }

    @Test func syncSwallowsRemoteErrors() async throws {
        let (builder, treeId, _, _, _) = try makeTree()
        let store = MockRemoteStore()
        store.errorToThrow = MockError()
        let sync = SyncService(remote: store, currentUserId: { UUID() }, debounce: .milliseconds(5))

        sync.scheduleSync(treeId: treeId, context: builder.context)
        await sync.awaitPendingSync()   // must return normally, not crash or throw

        #expect(store.deleted.isEmpty)
        #expect(sync.lastSyncError != nil)   // failure is recorded, not surfaced
        #expect(sync.lastSyncDate == nil)    // never marked as a successful sync
    }
}
