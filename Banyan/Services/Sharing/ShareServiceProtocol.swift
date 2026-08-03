// ShareServiceProtocol.swift
// The seam the sharing ViewModel depends on, so it can be unit-tested with a
// mock instead of the live Supabase client. The concrete implementation is
// SupabaseShareService (in Networking/); a test double stands in under test.

import Foundation

/// Owner-side sharing operations against the backend. All async; the concrete
/// implementation does the I/O and RLS is enforced server-side.
protocol ShareServiceProtocol: AnyObject {
    /// All accepted viewers of a tree (its `tree_members` rows with role viewer).
    func fetchViewers(treeId: UUID) async throws -> [ViewerDTO]

    /// All still-pending invitations for a tree.
    func fetchPendingInvitations(treeId: UUID) async throws -> [InvitationDTO]

    /// Creates an invitation and returns its (client-generated) token, which the
    /// caller embeds in the invite deep link.
    func createInvitation(treeId: UUID, invitedBy: UUID, phoneNumber: String) async throws -> String

    /// Revokes a viewer's access by deleting their `tree_members` row.
    func revokeAccess(treeId: UUID, userId: UUID) async throws
}
