// ContentView.swift
// Root gate. First on auth: loading shows a spinner while the session restores,
// signed-out shows sign-in. Once signed in, either the owner's onboarding gate
// applies (empty ownerPersonId ⇒ WelcomeView) or — for a viewer who joined a
// shared tree — the main tab shell in read-only mode. Also handles the
// banyan://invite deep link that starts the acceptance flow.

import SwiftUI

struct ContentView: View {
    @Environment(AuthStateManager.self) private var authState
    @Environment(\.inviteAcceptanceService) private var inviteService
    @AppStorage("ownerPersonId") private var ownerPersonIdString: String = ""
    @AppStorage("treeId") private var treeIdString: String = ""

    /// Set from an incoming invite link; presented once the user is signed in.
    @State private var pendingToken: String?
    @State private var showAcceptance = false

    /// Whether the current tree is one this device only views (read-only).
    private var isViewer: Bool {
        guard let treeId = UUID(uuidString: treeIdString) else { return false }
        return ViewerStore().isViewer(treeId: treeId)
    }

    var body: some View {
        Group {
            switch authState.state {
            case .loading:
                ProgressView()
                    .task { await authState.initialize() }

            case .signedOut:
                SignInView()

            case .signedIn:
                signedInContent
            }
        }
        .onOpenURL { url in
            guard case .invite(let token) = DeepLinkHandler.parse(url) else { return }
            pendingToken = token
            // If already signed in, present now; otherwise wait for sign-in below.
            if authState.userId != nil { showAcceptance = true }
        }
        .onChange(of: authState.userId) { _, newId in
            if newId != nil, pendingToken != nil { showAcceptance = true }
        }
        .sheet(isPresented: $showAcceptance, onDismiss: { pendingToken = nil }) {
            if let token = pendingToken, let inviteService {
                InviteAcceptanceView(
                    token: token,
                    viewModel: InviteAcceptanceViewModel(
                        service: inviteService,
                        importer: SharedTreeImporter(),
                        store: ViewerStore()
                    )
                )
            }
        }
    }

    /// Signed-in routing: owners onboard, viewers go straight to the read-only tree.
    @ViewBuilder
    private var signedInContent: some View {
        if ownerPersonIdString.isEmpty && !isViewer {
            WelcomeView()
        } else {
            MainTabView()
                .environment(\.isReadOnly, isViewer)
        }
    }
}
