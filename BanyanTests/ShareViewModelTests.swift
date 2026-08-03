// ShareViewModelTests.swift
// Load / create / revoke behaviour of the sharing ViewModel, using
// MockShareService to assert real service calls and list refreshes.
// The suite is @MainActor because ShareViewModel is.

import Foundation
import Testing
@testable import Banyan

@MainActor
@Suite("ShareViewModel")
struct ShareViewModelTests {

    // MARK: - Helpers

    private func makeViewModel(
        _ service: MockShareService,
        treeId: UUID = UUID(),
        userId: UUID = UUID()
    ) -> ShareViewModel {
        ShareViewModel(shareService: service, treeId: treeId, userId: userId)
    }

    private func aViewer(name: String? = nil) -> ViewerDTO {
        ViewerDTO(id: UUID(), displayName: name, invitationPhoneNumber: nil, joinedAt: .now)
    }

    private func anInvitation(phone: String) -> InvitationDTO {
        InvitationDTO(
            id: UUID(), treeId: UUID(), phoneNumber: phone,
            status: "pending", token: UUID().uuidString, createdAt: .now
        )
    }

    // MARK: - load

    @Test func loadPopulatesLoadedWithViewersAndPending() async {
        // Given a service primed with a viewer and a pending invitation
        let service = MockShareService()
        service.viewers = [aViewer(name: "Asha")]
        service.pending = [anInvitation(phone: "+1 555")]
        let viewModel = makeViewModel(service)

        // When loading
        await viewModel.load()

        // Then state is .loaded carrying both
        guard case let .loaded(viewers, pending) = viewModel.state else {
            Issue.record("expected .loaded, got \(viewModel.state)")
            return
        }
        #expect(viewers.count == 1)
        #expect(viewers.first?.label == "Asha")
        #expect(pending.count == 1)
        #expect(pending.first?.phoneNumber == "+1 555")
    }

    @Test func loadOnServiceErrorSetsErrorState() async {
        // Given a service that fails
        let service = MockShareService()
        service.errorToThrow = MockError()
        let viewModel = makeViewModel(service)

        // When loading
        await viewModel.load()

        // Then state is .error
        guard case .error = viewModel.state else {
            Issue.record("expected .error, got \(viewModel.state)")
            return
        }
    }

    // MARK: - createInvitation

    @Test func createInvitationCallsServiceWithArgsAndRefreshes() async throws {
        // Given a loaded view model
        let service = MockShareService()
        let treeId = UUID()
        let userId = UUID()
        let viewModel = makeViewModel(service, treeId: treeId, userId: userId)
        await viewModel.load()
        let viewersBefore = service.fetchViewersCount
        let pendingBefore = service.fetchPendingCount

        // When creating an invitation
        service.tokenToReturn = "abc-123"
        let token = try await viewModel.createInvitation(phoneNumber: "+91 98765 43210")

        // Then the service was called with the right args and the token surfaced
        #expect(token == "abc-123")
        #expect(viewModel.generatedToken == "abc-123")
        #expect(service.createdInvitations.count == 1)
        #expect(service.createdInvitations.first?.treeId == treeId)
        #expect(service.createdInvitations.first?.invitedBy == userId)
        #expect(service.createdInvitations.first?.phoneNumber == "+91 98765 43210")

        // And the lists were refreshed (a second fetch of each)
        #expect(service.fetchViewersCount == viewersBefore + 1)
        #expect(service.fetchPendingCount == pendingBefore + 1)
    }

    @Test func isCreatingInviteIsFalseAfterSuccessfulCreate() async throws {
        // Given a view model
        let service = MockShareService()
        let viewModel = makeViewModel(service)

        // When creating an invitation
        _ = try await viewModel.createInvitation(phoneNumber: "+1 555")

        // Then the in-flight flag is reset
        #expect(viewModel.isCreatingInvite == false)
    }

    @Test func isCreatingInviteIsResetWhenCreateThrows() async {
        // Given a service that fails the create
        let service = MockShareService()
        service.errorToThrow = MockError()
        let viewModel = makeViewModel(service)

        // When the create throws
        await #expect(throws: MockError.self) {
            _ = try await viewModel.createInvitation(phoneNumber: "+1 555")
        }

        // Then the defer still reset the in-flight flag
        #expect(viewModel.isCreatingInvite == false)
    }

    // MARK: - revokeAccess

    @Test func revokeAccessCallsServiceAndRefreshes() async {
        // Given a loaded view model and a viewer to remove
        let service = MockShareService()
        let treeId = UUID()
        let viewModel = makeViewModel(service, treeId: treeId)
        let viewer = aViewer(name: "Asha")
        await viewModel.load()
        let viewersBefore = service.fetchViewersCount

        // When revoking
        await viewModel.revokeAccess(viewer: viewer)

        // Then the service was asked to revoke that viewer and the list refreshed
        #expect(service.revokeCount == 1)
        #expect(service.revoked.first?.treeId == treeId)
        #expect(service.revoked.first?.userId == viewer.id)
        #expect(service.fetchViewersCount == viewersBefore + 1)
    }

    @Test func revokeAccessOnServiceErrorSetsErrorState() async {
        // Given a service that fails the revoke
        let service = MockShareService()
        service.errorToThrow = MockError()
        let viewModel = makeViewModel(service)

        // When revoking
        await viewModel.revokeAccess(viewer: aViewer())

        // Then state is .error
        guard case .error = viewModel.state else {
            Issue.record("expected .error, got \(viewModel.state)")
            return
        }
    }
}
