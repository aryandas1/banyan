// InviteAcceptanceViewModelTests.swift
// The accept → download → import → record flow, using MockInviteAcceptanceService
// for the network seam and a real importer + in-memory context + isolated
// ViewerStore for the local side. The suite is @MainActor because the VM is.

import Foundation
import SwiftData
import Testing
@testable import Banyan

@MainActor
@Suite("InviteAcceptanceViewModel")
struct InviteAcceptanceViewModelTests {

    // MARK: - Fixtures

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Schema(BanyanSchemaV1.models), configurations: config)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private func makeStore() -> ViewerStore {
        ViewerStore(defaults: UserDefaults(suiteName: "InviteVMTests-\(UUID().uuidString)")!)
    }

    private func makeViewModel(
        service: MockInviteAcceptanceService,
        store: ViewerStore
    ) -> InviteAcceptanceViewModel {
        InviteAcceptanceViewModel(service: service, importer: SharedTreeImporter(), store: store)
    }

    private func personDTO(_ id: UUID, treeId: UUID) -> PersonDTO {
        SharedTreeDTOFactory.person(id: id, treeId: treeId)
    }

    // MARK: - Tests

    @Test func successfulAcceptEndsInSuccessWithTreeId() async throws {
        // Given a service primed with a tree and a one-person snapshot
        let treeId = UUID()
        let service = MockInviteAcceptanceService()
        service.treeIdToReturn = treeId
        service.snapshotToReturn = SharedTreeSnapshot(
            persons: [personDTO(UUID(), treeId: treeId)], unions: [], links: []
        )
        let store = makeStore()
        let viewModel = makeViewModel(service: service, store: store)
        let context = try makeContext()

        // When accepting
        await viewModel.accept(token: "good-token", context: context)

        // Then state is .success carrying the tree id, and the token/tree were used
        #expect(viewModel.state == .success(treeId: treeId))
        #expect(service.acceptedTokens == ["good-token"])
        #expect(service.fetchedTreeIds == [treeId])
    }

    @Test func successRecordsViewerRoleAndImportsData() async throws {
        // Given a valid single-person tree
        let treeId = UUID()
        let personId = UUID()
        let service = MockInviteAcceptanceService()
        service.treeIdToReturn = treeId
        service.snapshotToReturn = SharedTreeSnapshot(
            persons: [personDTO(personId, treeId: treeId)], unions: [], links: []
        )
        let store = makeStore()
        let viewModel = makeViewModel(service: service, store: store)
        let context = try makeContext()

        // When accepting
        await viewModel.accept(token: "t", context: context)

        // Then the device is now a viewer of that tree, with a stored root,
        // and the data was imported locally
        #expect(store.isViewer(treeId: treeId))
        #expect(store.rootPersonId(forTree: treeId) == personId)
        #expect(try context.fetch(FetchDescriptor<Person>()).count == 1)
    }

    @Test func acceptFailureEndsInFailureAndRecordsNothing() async throws {
        // Given a service whose RPC rejects the token
        let service = MockInviteAcceptanceService()
        service.acceptError = MockError()
        let store = makeStore()
        let viewModel = makeViewModel(service: service, store: store)
        let context = try makeContext()

        // When accepting
        await viewModel.accept(token: "bad", context: context)

        // Then state is .failure, no download happened, and no viewer role recorded
        guard case .failure = viewModel.state else {
            Issue.record("expected .failure, got \(viewModel.state)")
            return
        }
        #expect(service.fetchedTreeIds.isEmpty)
        #expect(store.viewerTreeIds.isEmpty)
    }

    @Test func downloadFailureEndsInFailure() async throws {
        // Given accept succeeds but the pull fails
        let service = MockInviteAcceptanceService()
        service.fetchError = MockError()
        let store = makeStore()
        let viewModel = makeViewModel(service: service, store: store)
        let context = try makeContext()

        // When accepting
        await viewModel.accept(token: "t", context: context)

        // Then state is .failure and no viewer role was recorded
        guard case .failure = viewModel.state else {
            Issue.record("expected .failure, got \(viewModel.state)")
            return
        }
        #expect(store.viewerTreeIds.isEmpty)
    }
}
