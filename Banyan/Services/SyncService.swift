// SyncService.swift
// Debounced push of a tree's local SwiftData graph to Supabase: upsert all
// persons/unions/links, then delete remote rows that no longer exist locally.
// Depends on RemoteStore (a protocol) rather than the SDK, so its orchestration
// is unit-testable. Injected, not a singleton — one instance is created at the
// app root and shared via the SwiftUI environment.

import Foundation
import SwiftData

/// The write-trigger seam ViewModels depend on: "something changed in this tree,
/// schedule a sync." Kept minimal so a spy can stand in for tests.
@MainActor
protocol SyncScheduling {
    /// Requests a (debounced) sync of `treeId`, reading local state from `context`.
    func scheduleSync(treeId: UUID, context: ModelContext)
    /// Cancels any pending debounced sync and performs one immediately, awaiting it.
    /// Best-effort like `scheduleSync` — never throws; records `lastSyncError` on failure.
    func syncNow(treeId: UUID, context: ModelContext) async
}

@MainActor
@Observable
final class SyncService: SyncScheduling {
    @ObservationIgnored private let remote: RemoteStore
    @ObservationIgnored private let currentUserId: () async throws -> UUID
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private var pendingTask: Task<Void, Never>?

    /// The error from the most recent sync attempt, or nil if it succeeded.
    /// Sync is best-effort and never throws to callers, so this observable is the
    /// only signal that a push failed (e.g. a misconfigured backend). Starts nil.
    private(set) var lastSyncError: Error?
    /// When the most recent sync last completed successfully. nil until then.
    private(set) var lastSyncDate: Date?

    /// - Parameters:
    ///   - remote: the backing store (Supabase in the app, a mock in tests).
    ///   - currentUserId: resolves the signed-in user id — in the app this
    ///     ensures an anonymous Supabase session (so RLS sees a real `auth.uid()`)
    ///     and returns its id. Real auth later swaps the closure, not this class.
    ///   - debounce: how long to wait after the last change before syncing.
    init(remote: RemoteStore, currentUserId: @escaping () async throws -> UUID, debounce: Duration = .seconds(2)) {
        self.remote = remote
        self.currentUserId = currentUserId
        self.debounce = debounce
    }

    // MARK: - SyncScheduling

    /// Coalesces rapid mutations: each call cancels the previous pending sync and
    /// restarts the debounce window, so a burst of edits results in one sync.
    func scheduleSync(treeId: UUID, context: ModelContext) {
        pendingTask?.cancel()
        pendingTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.debounce)
            guard !Task.isCancelled else { return }
            await self.performSync(treeId: treeId, context: context)
        }
    }

    /// Cancels any pending debounced sync and performs one immediately, awaiting
    /// it. Used to force the tree to the backend before an action that depends on
    /// it being there (e.g. generating an invite link). Best-effort like
    /// `performSync` — never throws; records `lastSyncError` on failure.
    func syncNow(treeId: UUID, context: ModelContext) async {
        pendingTask?.cancel()
        pendingTask = nil
        await performSync(treeId: treeId, context: context)
    }

    /// Awaits the in-flight debounced sync, if any. Used by tests to sync
    /// deterministically; harmless in production.
    func awaitPendingSync() async {
        await pendingTask?.value
    }

    // MARK: - Sync

    private func performSync(treeId: UUID, context: ModelContext) async {
        do {
            // Resolve the signed-in user (ensures an anonymous session in the app),
            // then create the tree row before its rows can reference it.
            let ownerId = try await currentUserId()
            try await remote.upsertTree(
                TreeDTO(id: treeId, name: "Family Tree", ownerId: ownerId)
            )

            let persons = try context.fetch(
                FetchDescriptor<Person>(predicate: #Predicate { $0.treeId == treeId })
            )
            let unions = try context.fetch(
                FetchDescriptor<Union>(predicate: #Predicate { $0.treeId == treeId })
            )
            // PersonUnionLink has no treeId of its own, so scope links via their
            // (derived) tree id; dangling links drop out in the DTO mapping.
            let linkDTOs = try context.fetch(FetchDescriptor<PersonUnionLink>())
                .compactMap(PersonUnionLinkDTO.init(from:))
                .filter { $0.treeId == treeId }

            // Upsert order matters: links reference persons and unions.
            if !persons.isEmpty { try await remote.upsert(persons.map(PersonDTO.init(from:))) }
            if !unions.isEmpty  { try await remote.upsert(unions.map(UnionDTO.init(from:))) }
            if !linkDTOs.isEmpty { try await remote.upsert(linkDTOs) }

            // Delete remote orphans. Links first (they reference the others).
            try await deleteOrphans(in: .links,   treeId: treeId, localIds: Set(linkDTOs.map(\.id)))
            try await deleteOrphans(in: .persons, treeId: treeId, localIds: Set(persons.map(\.id)))
            try await deleteOrphans(in: .unions,  treeId: treeId, localIds: Set(unions.map(\.id)))

            lastSyncError = nil
            lastSyncDate = .now
            print("[SyncService] Synced \(persons.count) persons, \(unions.count) unions, \(linkDTOs.count) links")
        } catch {
            // Sync is best-effort: record and log, never surface to the user.
            lastSyncError = error
            print("[SyncService] Sync failed: \(error)")
        }
    }

    /// Deletes rows present remotely but not locally for this tree.
    private func deleteOrphans(in table: RemoteTable, treeId: UUID, localIds: Set<UUID>) async throws {
        let orphans = try await remote.remoteIds(in: table, treeId: treeId).subtracting(localIds)
        for id in orphans {
            try await remote.delete(from: table, id: id)
        }
    }
}
