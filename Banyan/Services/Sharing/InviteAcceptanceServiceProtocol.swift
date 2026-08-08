// InviteAcceptanceServiceProtocol.swift
// The viewer-side seam: accept an invite token and pull the shared tree. Kept as
// a protocol (0 executable lines) so the ViewModel depends on it, not the SDK —
// the concrete SupabaseInviteAcceptanceService lives in Networking (off the
// coverage gate) while the orchestration around it stays unit-testable.

import Foundation

/// One pulled photo: its metadata row plus the downloaded image bytes (nil when
/// the download failed — the metadata still applies and the file self-heals on a
/// later pull). Bytes travel in the snapshot so the importer stays network-free.
struct PhotoPayload: Equatable {
    let dto: PersonPhotoDTO
    let imageData: Data?
}

/// A read-only snapshot of a shared tree pulled from the backend. Pure DTOs (plus
/// photo bytes) — no SwiftData — so the network layer never touches the
/// (main-actor) ModelContext; a @MainActor importer applies these separately.
struct SharedTreeSnapshot: Equatable {
    let persons: [PersonDTO]
    let unions: [UnionDTO]
    let links: [PersonUnionLinkDTO]
    let photos: [PhotoPayload]

    /// `photos` defaults to empty so the many existing (photo-free) call sites and
    /// fixtures keep compiling; the pull fills it in.
    init(persons: [PersonDTO], unions: [UnionDTO], links: [PersonUnionLinkDTO], photos: [PhotoPayload] = []) {
        self.persons = persons
        self.unions = unions
        self.links = links
        self.photos = photos
    }
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
