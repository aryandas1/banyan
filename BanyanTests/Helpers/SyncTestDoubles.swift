// SyncTestDoubles.swift
// Test doubles for the sync layer: an in-memory RemoteStore that records what it
// was asked to do, and a SyncScheduling spy for asserting mutations schedule a sync.

import Foundation
import SwiftData
@testable import Banyan

struct MockError: Error {}

/// Records every call so tests can assert what a sync pushed / deleted, and can
/// be primed with remote IDs (for orphan detection) or an error (to prove the
/// service swallows failures).
@MainActor
final class MockRemoteStore: RemoteStore {
    /// An ordered record of every mutating call, so tests can assert FK-safe
    /// ordering (upsert parents before links; delete links before parents).
    enum Op: Equatable {
        case upsertTree, upsertPersons, upsertUnions, upsertLinks
        case delete(RemoteTable)
    }

    private(set) var upsertedTrees: [TreeDTO] = []
    private(set) var upsertedPersonIds: Set<UUID> = []
    private(set) var upsertedUnionIds: Set<UUID> = []
    private(set) var upsertedLinkIds: Set<UUID> = []
    private(set) var personUpsertCallCount = 0
    private(set) var syncCount = 0
    private(set) var deleted: [(table: RemoteTable, id: UUID)] = []
    private(set) var callLog: [Op] = []
    var remoteIdsByTable: [RemoteTable: Set<UUID>] = [:]
    var errorToThrow: Error?

    func upsertTree(_ tree: TreeDTO) async throws {
        if let errorToThrow { throw errorToThrow }
        syncCount += 1
        upsertedTrees.append(tree)
        callLog.append(.upsertTree)
    }

    func upsert(_ persons: [PersonDTO]) async throws {
        if let errorToThrow { throw errorToThrow }
        personUpsertCallCount += 1
        upsertedPersonIds.formUnion(persons.map(\.id))
        callLog.append(.upsertPersons)
    }

    func upsert(_ unions: [UnionDTO]) async throws {
        if let errorToThrow { throw errorToThrow }
        upsertedUnionIds.formUnion(unions.map(\.id))
        callLog.append(.upsertUnions)
    }

    func upsert(_ links: [PersonUnionLinkDTO]) async throws {
        if let errorToThrow { throw errorToThrow }
        upsertedLinkIds.formUnion(links.map(\.id))
        callLog.append(.upsertLinks)
    }

    func remoteIds(in table: RemoteTable, treeId: UUID) async throws -> Set<UUID> {
        if let errorToThrow { throw errorToThrow }
        return remoteIdsByTable[table] ?? []
    }

    func delete(from table: RemoteTable, id: UUID) async throws {
        if let errorToThrow { throw errorToThrow }
        deleted.append((table: table, id: id))
        callLog.append(.delete(table))
    }
}

/// Records the treeIds it was asked to sync, so ViewModel tests can assert a
/// mutation scheduled a sync without any real networking.
@MainActor
final class SpySyncScheduler: SyncScheduling {
    private(set) var scheduledTreeIds: [UUID] = []

    func scheduleSync(treeId: UUID, context: ModelContext) {
        scheduledTreeIds.append(treeId)
    }
}
