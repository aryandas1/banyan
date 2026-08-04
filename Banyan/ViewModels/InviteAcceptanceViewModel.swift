// InviteAcceptanceViewModel.swift
// Drives the invite-acceptance screen: accept the token, pull the shared tree,
// import it locally, and record this device as a viewer of that tree. Depends on
// the network service via a protocol (mockable) and on the local importer/store
// (plain value types) — all injected, so the flow is unit-testable end to end.

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class InviteAcceptanceViewModel {

    enum State: Equatable {
        case idle
        case accepting
        case downloading
        case success(treeId: UUID)
        case failure(String)
    }

    private(set) var state: State = .idle

    private let service: any InviteAcceptanceServiceProtocol
    private let importer: SharedTreeImporter
    private let store: ViewerStore

    init(
        service: any InviteAcceptanceServiceProtocol,
        importer: SharedTreeImporter,
        store: ViewerStore
    ) {
        self.service = service
        self.importer = importer
        self.store = store
    }

    /// Runs the whole flow: accept → download → import → record viewer role.
    /// Any failure lands on `.failure` with a user-facing message (the token is
    /// most often invalid or already used).
    func accept(token: String, context: ModelContext) async {
        state = .accepting
        do {
            let treeId = try await service.acceptInvitation(token: token)
            state = .downloading
            let snapshot = try await service.fetchSharedTree(treeId: treeId)
            let rootPersonId = try importer.importTree(snapshot, treeId: treeId, into: context)
            store.addViewerTree(treeId, rootPersonId: rootPersonId)
            state = .success(treeId: treeId)
        } catch {
            state = .failure("This invite link is invalid or has already been used.")
        }
    }
}
