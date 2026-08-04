// InviteAcceptanceServiceProtocol.swift
// The viewer-side seam: accept an invite token and pull the shared tree. Kept as
// a protocol (0 executable lines) so the ViewModel depends on it, not the SDK —
// the concrete SupabaseInviteAcceptanceService lives in Networking (off the
// coverage gate) while the orchestration around it stays unit-testable.

import Foundation

/// A read-only snapshot of a shared tree pulled from the backend. Pure DTOs — no
/// SwiftData — so the network layer never touches the (main-actor) ModelContext;
/// a @MainActor importer applies these to the store separately.
struct SharedTreeSnapshot: Equatable {
    let persons: [PersonDTO]
    let unions: [UnionDTO]
    let links: [PersonUnionLinkDTO]
}

protocol InviteAcceptanceServiceProtocol: AnyObject {
    /// Calls the `accept_invitation(p_token)` security-definer RPC, which adds the
    /// caller to `tree_members` as a viewer. Returns the joined tree's id.
    func acceptInvitation(token: String) async throws -> UUID

    /// Fetches every person, union, and link the caller can read for `treeId`
    /// (RLS scopes this to trees they're a member of). Returns DTOs only — the
    /// caller imports them into SwiftData on the main actor.
    func fetchSharedTree(treeId: UUID) async throws -> SharedTreeSnapshot
}
