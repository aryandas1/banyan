// RemoteStore.swift
// The seam between SyncService and Supabase. SyncService depends on this
// protocol, not the SDK, so its orchestration can be unit-tested with a mock.

import Foundation

/// The remote tables sync touches, keyed to their Postgres names.
enum RemoteTable: String {
    case persons = "persons"
    case unions  = "unions"
    case links   = "person_union_links"
}

/// The remote operations sync needs: idempotent upserts, id enumeration for
/// orphan detection, and row deletion. All async; implementations do the I/O.
protocol RemoteStore {
    func upsertTree(_ tree: TreeDTO) async throws
    func upsert(_ persons: [PersonDTO]) async throws
    func upsert(_ unions: [UnionDTO]) async throws
    func upsert(_ links: [PersonUnionLinkDTO]) async throws

    /// All row ids in `table` for the given tree — the remote side of orphan detection.
    func remoteIds(in table: RemoteTable, treeId: UUID) async throws -> Set<UUID>

    /// Deletes a single row by id from `table`.
    func delete(from table: RemoteTable, id: UUID) async throws
}
