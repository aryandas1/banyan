// SupabaseInviteAcceptanceService.swift
// The Supabase-backed InviteAcceptanceServiceProtocol: the RPC that joins a tree
// and the reads that pull it. Access control is enforced server-side by RLS — the
// invitee can only read a tree once accept_invitation has made them a member, and
// their writes are rejected 42501 regardless of the UI.
//
// Lives in Networking (not Services) alongside SupabaseRemoteStore/ShareService
// because it wraps the live SDK client and can't be unit-tested — keeping it off
// the `make coverage` gate. Injected the shared client (no singletons; CLAUDE.md).
//
// Backend behaviour verified live (two anonymous sessions, curl): accept_invitation
// returns the tree_id as a bare uuid scalar and flips the invitee to viewer; the
// member read policies then allow SELECT on persons/unions/person_union_links.

import Foundation
import Supabase

final class SupabaseInviteAcceptanceService: InviteAcceptanceServiceProtocol {

    private let client: SupabaseClient

    /// Injects the shared Supabase client built at the composition root.
    init(client: SupabaseClient) {
        self.client = client
    }

    func acceptInvitation(token: String) async throws -> UUID {
        // rpc(_:params:) is synchronous+throwing (returns a builder); execute() is
        // async. The function returns a bare `uuid` scalar, decoded straight to UUID.
        try await client
            .rpc("accept_invitation", params: ["p_token": token])
            .execute()
            .value
    }

    func fetchSharedTree(treeId: UUID) async throws -> SharedTreeSnapshot {
        // Fetch the metadata tables concurrently; all are RLS-scoped to members.
        async let persons: [PersonDTO] = client
            .from("persons").select().eq("tree_id", value: treeId.uuidString).execute().value
        async let unions: [UnionDTO] = client
            .from("unions").select().eq("tree_id", value: treeId.uuidString).execute().value
        async let links: [PersonUnionLinkDTO] = client
            .from("person_union_links").select().eq("tree_id", value: treeId.uuidString).execute().value
        async let photoDTOs: [PersonPhotoDTO] = client
            .from("person_photos").select().eq("tree_id", value: treeId.uuidString).execute().value

        // Download each photo's bytes best-effort (nil on failure — the metadata
        // still imports and the file self-heals on a later pull), so the importer
        // can apply everything without any networking of its own.
        var photos: [PhotoPayload] = []
        for dto in try await photoDTOs {
            let data = try? await client.storage.from("photos").download(path: dto.storagePath)
            photos.append(PhotoPayload(dto: dto, imageData: data))
        }

        return try await SharedTreeSnapshot(persons: persons, unions: unions, links: links, photos: photos)
    }
}
