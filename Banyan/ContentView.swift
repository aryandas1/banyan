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

    /// The invite currently being presented. Using `.sheet(item:)` (not a bool +
    /// separate token) guarantees the token is non-nil in the sheet builder — a
    /// bool + `@State` token race presents an EMPTY sheet.
    @State private var pendingInvite: PendingInvite?
    /// A token that arrived before sign-in completed; promoted once signed in.
    @State private var deferredToken: String?

    /// An invite awaiting acceptance. Identifiable so it can drive `.sheet(item:)`.
    private struct PendingInvite: Identifiable {
        let id = UUID()
        let token: String
    }

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
            // Present now if signed in; otherwise hold the token until sign-in.
            if authState.userId != nil {
                pendingInvite = PendingInvite(token: token)
            } else {
                deferredToken = token
            }
        }
        .onChange(of: authState.userId) { _, newId in
            if newId != nil, let token = deferredToken {
                deferredToken = nil
                pendingInvite = PendingInvite(token: token)
            }
        }
        .sheet(item: $pendingInvite) { invite in
            if let inviteService {
                InviteAcceptanceView(
                    token: invite.token,
                    viewModel: InviteAcceptanceViewModel(
                        service: inviteService,
                        importer: SharedTreeImporter(),
                        store: ViewerStore()
                    )
                )
            }
        }
        #if DEBUG
        // UI-test hook: present the acceptance sheet on launch (same path an
        // onOpenURL would take) so a test can assert it renders + completes.
        .task {
            if UITestSupport.presentsAcceptSheetOnLaunch, pendingInvite == nil {
                pendingInvite = PendingInvite(token: UITestSupport.launchAcceptToken)
            }
        }
        #endif
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
