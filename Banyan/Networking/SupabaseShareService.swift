// SupabaseShareService.swift
// The Supabase-backed ShareServiceProtocol: PostgREST calls for the owner's
// sharing flow. Access control is enforced server-side by RLS.
//
// Lives in Networking (not Services) alongside SupabaseRemoteStore because it
// wraps the live Supabase client and can't be unit-tested — this keeps it off
// the `make coverage` gate. Injected the shared client (no singletons; CLAUDE.md).
//
// Backend behaviour below was verified against the live DB (see the step-11
// prompt's "Backend risks"):
//   • createInvitation inserts a client-generated token with return=minimal, so
//     there's no representation read-back round-trip.
//   • fetchViewers does NOT embed profiles(display_name): there is no FK from
//     tree_members to profiles (the embed 400s), and the owner can't read other
//     users' profiles under the current RLS anyway — so display names are
//     unavailable and labels fall back to "Family member".
//   • revokeAccess only deletes the tree_members row (that's what gates the read
//     path); invitations carry no accepted_by link, so their status can't be
//     scoped to one viewer and is left untouched.

import Foundation
import Supabase

final class SupabaseShareService: ShareServiceProtocol {

    private let client: SupabaseClient

    /// Injects the shared Supabase client built at the composition root.
    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchViewers(treeId: UUID) async throws -> [ViewerDTO] {
        // A tree_members row for a viewer. No profile embed (no FK; owner can't
        // read others' profiles) — displayName is therefore always nil today.
        struct MemberRow: Decodable {
            let userId: UUID
            let joinedAt: Date
            enum CodingKeys: String, CodingKey {
                case userId   = "user_id"
                case joinedAt = "joined_at"
            }
        }

        let members: [MemberRow] = try await client
            .from("tree_members")
            .select("user_id, joined_at")
            .eq("tree_id", value: treeId.uuidString)
            .eq("role", value: "viewer")
            .execute()
            .value

        return members.map { member in
            ViewerDTO(
                id: member.userId,
                displayName: nil,
                invitationPhoneNumber: nil,
                joinedAt: member.joinedAt
            )
        }
    }

    func fetchPendingInvitations(treeId: UUID) async throws -> [InvitationDTO] {
        try await client
            .from("invitations")
            .select()
            .eq("tree_id", value: treeId.uuidString)
            .eq("status", value: "pending")
            .execute()
            .value
    }

    func createInvitation(treeId: UUID, invitedBy: UUID, phoneNumber: String) async throws -> String {
        // Generate the token client-side and insert with return=minimal — no
        // .select() read-back (avoids an extra round-trip and the step-9 RLS
        // representation-read pitfall).
        let token = UUID().uuidString
        _ = try await client
            .from("invitations")
            .insert(
                InvitationInsertDTO(
                    treeId: treeId, invitedBy: invitedBy, phoneNumber: phoneNumber, token: token
                ),
                returning: .minimal
            )
            .execute()
        return token
    }

    func revokeAccess(treeId: UUID, userId: UUID) async throws {
        // Deleting the tree_members row is what removes access: the read policies
        // gate on membership (is_tree_member), and invitation.status is cosmetic.
        _ = try await client
            .from("tree_members")
            .delete()
            .eq("tree_id", value: treeId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }
}
