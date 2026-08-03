// ShareTestDoubles.swift
// Test double for the sharing layer: an in-memory ShareServiceProtocol that
// records calls (args + counts) and can be primed with responses or an error,
// so ShareViewModel tests can assert real refresh behaviour rather than imply it.

import Foundation
@testable import Banyan

@MainActor
final class MockShareService: ShareServiceProtocol {
    // Primed responses.
    var viewers: [ViewerDTO] = []
    var pending: [InvitationDTO] = []
    var tokenToReturn = "mock-token"
    var errorToThrow: Error?

    // Call tracking.
    private(set) var fetchViewersCount = 0
    private(set) var fetchPendingCount = 0
    private(set) var revokeCount = 0
    private(set) var createdInvitations: [(treeId: UUID, invitedBy: UUID, phoneNumber: String)] = []
    private(set) var revoked: [(treeId: UUID, userId: UUID)] = []

    func fetchViewers(treeId: UUID) async throws -> [ViewerDTO] {
        fetchViewersCount += 1
        if let errorToThrow { throw errorToThrow }
        return viewers
    }

    func fetchPendingInvitations(treeId: UUID) async throws -> [InvitationDTO] {
        fetchPendingCount += 1
        if let errorToThrow { throw errorToThrow }
        return pending
    }

    func createInvitation(treeId: UUID, invitedBy: UUID, phoneNumber: String) async throws -> String {
        createdInvitations.append((treeId, invitedBy, phoneNumber))
        if let errorToThrow { throw errorToThrow }
        return tokenToReturn
    }

    func revokeAccess(treeId: UUID, userId: UUID) async throws {
        revokeCount += 1
        revoked.append((treeId, userId))
        if let errorToThrow { throw errorToThrow }
    }
}
