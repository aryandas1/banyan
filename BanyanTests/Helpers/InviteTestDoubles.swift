// InviteTestDoubles.swift
// Test double for the viewer-side invite flow: an in-memory
// InviteAcceptanceServiceProtocol that records calls and can be primed with a
// tree id, a snapshot, or an error — so InviteAcceptanceViewModel tests assert
// real behaviour without networking.

import Foundation
@testable import Banyan

@MainActor
final class MockInviteAcceptanceService: InviteAcceptanceServiceProtocol {
    // Primed responses.
    var treeIdToReturn = UUID()
    var snapshotToReturn = SharedTreeSnapshot(persons: [], unions: [], links: [])
    /// Thrown from `acceptInvitation` when set (simulates an invalid/used token).
    var acceptError: Error?
    /// Thrown from `fetchSharedTree` when set.
    var fetchError: Error?

    // Call tracking.
    private(set) var acceptedTokens: [String] = []
    private(set) var fetchedTreeIds: [UUID] = []

    func acceptInvitation(token: String) async throws -> UUID {
        acceptedTokens.append(token)
        if let acceptError { throw acceptError }
        return treeIdToReturn
    }

    func fetchSharedTree(treeId: UUID) async throws -> SharedTreeSnapshot {
        fetchedTreeIds.append(treeId)
        if let fetchError { throw fetchError }
        return snapshotToReturn
    }
}
