// ShareViewModel.swift
// Drives the Share screen: loads the current viewers and pending invitations,
// creates new invitations (returning a token for the share sheet), and revokes
// access. Depends on ShareServiceProtocol, not the SDK, so it's unit-testable.

import Foundation
import Observation

@MainActor
@Observable
final class ShareViewModel {

    enum State {
        case idle
        case loading
        case loaded(viewers: [ViewerDTO], pending: [InvitationDTO])
        case error(String)
    }

    private(set) var state: State = .idle
    /// True while an invitation create is in flight, so the button can show a spinner.
    private(set) var isCreatingInvite = false
    /// The token from the most recent successful create (for the share message).
    private(set) var generatedToken: String?

    private let shareService: any ShareServiceProtocol
    private let treeId: UUID
    private let userId: UUID

    init(shareService: any ShareServiceProtocol, treeId: UUID, userId: UUID) {
        self.shareService = shareService
        self.treeId = treeId
        self.userId = userId
    }

    /// Loads viewers and pending invitations concurrently into `.loaded`, or
    /// `.error` if either fetch fails.
    func load() async {
        state = .loading
        do {
            async let viewers = shareService.fetchViewers(treeId: treeId)
            async let pending = shareService.fetchPendingInvitations(treeId: treeId)
            state = try await .loaded(viewers: viewers, pending: pending)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Creates an invitation and returns the invite token to embed in the share
    /// sheet. Refreshes the lists on success. Rethrows so the caller can show an
    /// inline error; `isCreatingInvite` is reset either way.
    func createInvitation(phoneNumber: String) async throws -> String {
        isCreatingInvite = true
        defer { isCreatingInvite = false }
        let token = try await shareService.createInvitation(
            treeId: treeId,
            invitedBy: userId,
            phoneNumber: phoneNumber
        )
        generatedToken = token
        await load()
        return token
    }

    /// Revokes a viewer's access, then refreshes the lists. Surfaces failures as
    /// `.error`.
    func revokeAccess(viewer: ViewerDTO) async {
        do {
            try await shareService.revokeAccess(treeId: treeId, userId: viewer.id)
            await load()
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
