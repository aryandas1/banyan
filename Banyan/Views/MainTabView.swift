// MainTabView.swift
// The three-tab shell shown once onboarding is complete — or, for a viewer, once
// a shared tree has been accepted. Every tab item carries a text label as well as
// an icon — this app's users rely on labels.
//
// The tree centres on the "root" person. For an owner that's their own
// ownerPersonId; a viewer never onboarded, so in read-only mode the root is the
// focal ViewerRootPicker chose for the shared tree (see ViewerStore).

import SwiftUI
import SwiftData

struct MainTabView: View {
    @AppStorage("ownerPersonId") private var ownerPersonIdString: String = ""
    @AppStorage("treeId") private var treeIdString: String = ""
    @Environment(\.isReadOnly) private var isReadOnly
    @Environment(\.modelContext) private var modelContext
    @Environment(\.inviteAcceptanceService) private var inviteService
    @Environment(\.photoSyncService) private var photoSyncService

    /// The viewer's resolved focal for the shared tree. Held in @State (not read
    /// straight from UserDefaults) so the tree re-renders when it self-heals after
    /// a refresh — the accept may have stored a nil root from an empty pull.
    @State private var viewerRoot: UUID?

    /// The person the tree centres on. Owner: their own id from storage. Viewer:
    /// the reactive focal resolved for the shared tree. Falls back to the all-zero
    /// UUID if neither resolves — the tab still renders rather than crashing.
    private var rootPersonId: UUID {
        if isReadOnly {
            // Prefer the root stored for THIS tree, so a switch (including viewed →
            // viewed) centres on the right person immediately rather than the
            // previous tree's stale focal. Fall back to the reactive viewerRoot,
            // which the .task recomputes to self-heal an empty accept (no stored root).
            if let root = storedViewerRoot ?? viewerRoot { return root }
            return .placeholder
        }
        return UUID(uuidString: ownerPersonIdString) ?? .placeholder
    }

    /// The focal stored for the active viewed tree, read synchronously so a tree
    /// switch has an immediate centre without waiting for the async resolve.
    private var storedViewerRoot: UUID? {
        guard let treeId = UUID(uuidString: treeIdString) else { return nil }
        return ViewerStore().rootPersonId(forTree: treeId)
    }

    var body: some View {
        TabView {
            // Keyed on the active tree so switching rebuilds the tab with the new
            // tree's focal (fresh browse state) rather than reusing the old one.
            TreeTabView(ownerPersonId: rootPersonId)
                .id(treeIdString)
                .tabItem { Label("Tree", systemImage: "person.3.fill") }

            PeopleListView(ownerPersonId: rootPersonId)
                .id(treeIdString)
                .tabItem { Label("People", systemImage: "list.bullet") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        // Re-runs on launch AND whenever the active tree changes (a switch), so the
        // viewer focal + photo reconciliation follow the current tree.
        .task(id: treeIdString) {
            // Resolve the focal before the network refresh so the tree renders
            // immediately from local state, then let the refresh update it.
            if isReadOnly, let treeId = UUID(uuidString: treeIdString) {
                viewerRoot = resolveViewerRoot(treeId: treeId)
            } else {
                viewerRoot = nil
                if let treeId = UUID(uuidString: treeIdString) {
                    // Backfill the owned-tree marker for owners who onboarded before it
                    // existed (set-once, so a no-op once recorded). Guarded on !isReadOnly
                    // so a currently-viewed tree is never mis-recorded as owned.
                    ViewerStore().setOwnerTree(treeId)
                }
            }
            await syncPhotosOnLaunch()
        }
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
    ///
    /// If the accept happened before the owner had synced, ViewerStore holds a nil
    /// root; once this pull brings the tree in, persist the recomputed root (so it
    /// survives relaunch) and refresh the reactive focal (so the tree renders now).
    private func refreshSharedTree(treeId: UUID) async {
        guard let inviteService,
              let snapshot = try? await inviteService.fetchSharedTree(treeId: treeId)
        else { return }
        // try? on a UUID?-returning call yields UUID??; flatten to UUID?.
        let importedRoot = (try? SharedTreeImporter().importTree(snapshot, treeId: treeId, into: modelContext)) ?? nil

        // Persist the recomputed root only when the accept stored none. addViewerTree
        // writes the root key only when non-nil and re-writes "treeId" harmlessly.
        if let importedRoot, ViewerStore().rootPersonId(forTree: treeId) == nil {
            ViewerStore().addViewerTree(treeId, rootPersonId: importedRoot)
        }

        viewerRoot = resolveViewerRoot(treeId: treeId)
    }

    /// The viewer's focal for a tree: the stored root if the accept captured one,
    /// otherwise a root recomputed from the tree now in SwiftData (the fallback
    /// that lets an empty-then-populated accept self-heal).
    private func resolveViewerRoot(treeId: UUID) -> UUID? {
        if let stored = ViewerStore().rootPersonId(forTree: treeId) { return stored }
        return localRoot(treeId: treeId)
    }

    /// Runs the root heuristic over the tree already in SwiftData. Links carry no
    /// treeId of their own, so scope them via their linked person's tree.
    private func localRoot(treeId: UUID) -> UUID? {
        let persons = (try? modelContext.fetch(
            FetchDescriptor<Person>(predicate: #Predicate { $0.treeId == treeId })
        )) ?? []
        let links = ((try? modelContext.fetch(FetchDescriptor<PersonUnionLink>())) ?? [])
            .filter { $0.person?.treeId == treeId }
        return ViewerRootPicker.pickRoot(persons: persons, links: links)
    }
}

#Preview {
    MainTabView()
}
