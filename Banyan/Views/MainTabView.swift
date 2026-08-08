// MainTabView.swift
// The three-tab shell shown once onboarding is complete — or, for a viewer, once
// a shared tree has been accepted. Every tab item carries a text label as well as
// an icon — this app's users rely on labels.
//
// The tree centres on the "root" person. For an owner that's their own
// ownerPersonId; a viewer never onboarded, so in read-only mode the root is the
// focal ViewerRootPicker chose for the shared tree (see ViewerStore).

import SwiftUI

struct MainTabView: View {
    @AppStorage("ownerPersonId") private var ownerPersonIdString: String = ""
    @AppStorage("treeId") private var treeIdString: String = ""
    @Environment(\.isReadOnly) private var isReadOnly
    @Environment(\.modelContext) private var modelContext
    @Environment(\.inviteAcceptanceService) private var inviteService
    @Environment(\.photoSyncService) private var photoSyncService

    /// The person the tree centres on. Owner: their own id from storage. Viewer:
    /// the stored focal for the shared tree. Falls back to the all-zero UUID if
    /// neither resolves — the tab still renders rather than crashing.
    private var rootPersonId: UUID {
        if isReadOnly,
           let treeId = UUID(uuidString: treeIdString),
           let root = ViewerStore().rootPersonId(forTree: treeId) {
            return root
        }
        return UUID(uuidString: ownerPersonIdString) ?? .placeholder
    }

    var body: some View {
        TabView {
            TreeTabView(ownerPersonId: rootPersonId)
                .tabItem { Label("Tree", systemImage: "person.3.fill") }

            PeopleListView(ownerPersonId: rootPersonId)
                .tabItem { Label("People", systemImage: "list.bullet") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .task { await syncPhotosOnLaunch() }
    }

    /// Launch photo reconciliation. A viewer re-pulls the shared tree (which now
    /// carries photos); an owner retries any local photos that never finished
    /// uploading. Both best-effort.
    private func syncPhotosOnLaunch() async {
        guard let treeId = UUID(uuidString: treeIdString) else { return }
        if isReadOnly {
            await refreshSharedTree(treeId: treeId)
        } else if let photoSyncService {
            await PhotoSyncCoordinator().uploadPending(treeId: treeId, in: modelContext, using: photoSyncService)
        }
    }

    /// For a viewer, re-pull the shared tree on launch so they see the owner's
    /// latest. Best-effort: a revoked viewer's pull is blocked by RLS and simply
    /// leaves the last-synced local copy in place.
    private func refreshSharedTree(treeId: UUID) async {
        guard let inviteService,
              let snapshot = try? await inviteService.fetchSharedTree(treeId: treeId)
        else { return }
        _ = try? SharedTreeImporter().importTree(snapshot, treeId: treeId, into: modelContext)
    }
}

#Preview {
    MainTabView()
}
