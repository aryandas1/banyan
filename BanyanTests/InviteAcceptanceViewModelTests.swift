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
        let container = try ModelContainer(for: Schema(BanyanSchemaV2.models), configurations: config)
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

    @Test func ownerOpeningTheirOwnInviteSucceedsWithoutBecomingAViewer() async throws {
        // Given a store that already owns the tree the invite points at
        let treeId = UUID()
        let service = MockInviteAcceptanceService()
        service.treeIdToReturn = treeId
        service.snapshotToReturn = SharedTreeSnapshot(
            persons: [personDTO(UUID(), treeId: treeId)], unions: [], links: []
        )
        let store = makeStore()
        store.setOwnerTree(treeId)
        let viewModel = makeViewModel(service: service, store: store)
        let context = try makeContext()

        // When the owner opens their own invite link
        await viewModel.accept(token: "own-link", context: context)

        // Then it lands on .success without downloading, importing, or registering
        // this device as a viewer / overwriting the active tree.
        #expect(viewModel.state == .success(treeId: treeId))
        #expect(service.acceptedTokens == ["own-link"])
        #expect(service.fetchedTreeIds.isEmpty)
        #expect(store.viewerTreeIds.isEmpty)
        #expect(store.isViewer(treeId: treeId) == false)
        #expect(try context.fetch(FetchDescriptor<Person>()).isEmpty)
    }

    @Test func reacceptingARecordedTokenSucceedsWithoutCallingTheService() async throws {
        // Given a token already accepted once on this device (RPC + pull happened)
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
        await viewModel.accept(token: "link", context: context)
        #expect(service.acceptedTokens == ["link"])
        #expect(service.fetchedTreeIds == [treeId])

        // When the same link is re-tapped (or iOS redelivers onOpenURL)
        await viewModel.accept(token: "link", context: context)

        // Then it lands on success against the memoized tree id WITHOUT calling the
        // non-idempotent accept RPC (or the pull) a second time.
        #expect(viewModel.state == .success(treeId: treeId))
        #expect(service.acceptedTokens == ["link"])
        #expect(service.fetchedTreeIds == [treeId])
    }

    @Test func ownerReopeningTheirOwnRecordedInviteShortCircuitsWithoutTheRPC() async throws {
        // Given the owner already opened their own invite once (guard recorded the
        // token so a re-tap needn't re-consume it via the RPC)
        let treeId = UUID()
        let service = MockInviteAcceptanceService()
        service.treeIdToReturn = treeId
        let store = makeStore()
        store.setOwnerTree(treeId)
        let viewModel = makeViewModel(service: service, store: store)
        let context = try makeContext()
        await viewModel.accept(token: "own-link", context: context)
        #expect(service.acceptedTokens == ["own-link"])

        // When the owner re-taps their own link
        await viewModel.accept(token: "own-link", context: context)

        // Then it resolves to success from the memo — no second RPC call — and the
        // owner is still NOT registered as a viewer (the re-activation only applies
        // to viewed trees; re-registering the owned tree would lock read-only).
        #expect(viewModel.state == .success(treeId: treeId))
        #expect(service.acceptedTokens == ["own-link"])
        #expect(store.viewerTreeIds.isEmpty)
    }

    @Test func reacceptingAViewedTreeReactivatesItAsTheCurrentTree() async throws {
        // Given a viewer who accepted tree A, then tree B — so B is the active tree
        let treeA = UUID(); let rootA = UUID()
        let treeB = UUID(); let rootB = UUID()
        let defaults = UserDefaults(suiteName: "InviteVMReactivate-\(UUID().uuidString)")!
        let store = ViewerStore(defaults: defaults)
        let service = MockInviteAcceptanceService()
        let viewModel = makeViewModel(service: service, store: store)
        let context = try makeContext()

        service.treeIdToReturn = treeA
        service.snapshotToReturn = SharedTreeSnapshot(
            persons: [personDTO(rootA, treeId: treeA)], unions: [], links: []
        )
        await viewModel.accept(token: "link-A", context: context)

        service.treeIdToReturn = treeB
        service.snapshotToReturn = SharedTreeSnapshot(
            persons: [personDTO(rootB, treeId: treeB)], unions: [], links: []
        )
        await viewModel.accept(token: "link-B", context: context)
        #expect(defaults.string(forKey: "treeId") == treeB.uuidString)

        // When the viewer re-opens tree A's link
        await viewModel.accept(token: "link-A", context: context)

        // Then it succeeds from the memo (no third RPC call) AND switches the active
        // tree back to A, restoring A's stored root — not leaving them stuck on B.
        #expect(viewModel.state == .success(treeId: treeA))
        #expect(service.acceptedTokens == ["link-A", "link-B"])
        #expect(defaults.string(forKey: "treeId") == treeA.uuidString)
        #expect(store.rootPersonId(forTree: treeA) == rootA)
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
