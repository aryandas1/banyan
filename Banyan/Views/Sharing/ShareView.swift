// ShareView.swift
// The owner's Share screen: lists current viewers and pending invitations,
// offers "Invite someone", and revokes a viewer via a confirmation dialog.
// Presented as a sheet from the Tree tab.

import SwiftUI

struct ShareView: View {

    @State var viewModel: ShareViewModel
    @State private var showInviteSheet = false
    @State private var viewerToRemove: ViewerDTO?

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView()
                case .error(let message):
                    Text(message)
                        .foregroundStyle(.red)
                        .padding()
                case .loaded(let viewers, let pending):
                    loadedBody(viewers: viewers, pending: pending)
                }
            }
            .navigationTitle("Share your tree")
            .navigationBarTitleDisplayMode(.large)
            .task { await viewModel.load() }
            .sheet(isPresented: $showInviteSheet) {
                InviteView(viewModel: viewModel)
            }
            .confirmationDialog(
                removeDialogTitle,
                isPresented: Binding(
                    get: { viewerToRemove != nil },
                    set: { if !$0 { viewerToRemove = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    guard let viewer = viewerToRemove else { return }
                    viewerToRemove = nil
                    Task { await viewModel.revokeAccess(viewer: viewer) }
                }
                Button("Keep them", role: .cancel) { viewerToRemove = nil }
            } message: {
                Text("They won't be able to see your tree anymore.")
            }
        }
    }

    @ViewBuilder
    private func loadedBody(viewers: [ViewerDTO], pending: [InvitationDTO]) -> some View {
        List {
            Section {
                Text("People you invite can view your tree but cannot make any changes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if viewers.isEmpty && pending.isEmpty {
                Section {
                    Text("No one has access yet. Invite a family member to let them see your tree.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            } else {
                if !viewers.isEmpty {
                    Section("Viewers") {
                        ForEach(viewers) { viewer in
                            viewerRow(viewer)
                        }
                    }
                }
                if !pending.isEmpty {
                    Section("Invited — waiting to accept") {
                        ForEach(pending) { invite in
                            Label(invite.phoneNumber, systemImage: "clock")
                                .font(.body)
                        }
                    }
                }
            }

            Section {
                Button {
                    showInviteSheet = true
                } label: {
                    Label("Invite someone", systemImage: "plus")
                        .font(.body.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
        }
    }

    private func viewerRow(_ viewer: ViewerDTO) -> some View {
        HStack {
            Text(viewer.label)
                .font(.body)
            Spacer()
            Button("Remove") {
                viewerToRemove = viewer
            }
            .foregroundStyle(.red)
            .font(.body)
            .frame(minWidth: 44, minHeight: 44)
        }
    }

    private var removeDialogTitle: String {
        guard let viewer = viewerToRemove else { return "Remove access?" }
        return "Remove \(viewer.label)?"
    }
}
