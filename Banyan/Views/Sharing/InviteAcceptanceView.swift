// InviteAcceptanceView.swift
// The sheet shown when the app opens an invite deep link: kicks off the accept →
// download → import flow and reflects its state. On success the viewer dismisses
// into the (now read-only) tree; on failure they get a plain explanation.

import SwiftUI

struct InviteAcceptanceView: View {
    let token: String
    @State var viewModel: InviteAcceptanceViewModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            content
            Spacer()
        }
        .padding(32)
        .task { await viewModel.accept(token: token, context: context) }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .accepting:
            ProgressView()
            Text("Verifying invite…")
                .font(.body)
                .foregroundStyle(.secondary)

        case .downloading:
            ProgressView()
            Text("Loading family tree…")
                .font(.body)
                .foregroundStyle(.secondary)

        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("You're in!")
                .font(.title2)
                .fontWeight(.bold)
            Text("The family tree is ready to view.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                dismiss()
            } label: {
                Text("View tree")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)

        case .failure(let message):
            Image(systemName: "exclamationmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text("Invite not valid")
                .font(.title2)
                .fontWeight(.bold)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                dismiss()
            } label: {
                Text("Close")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
        }
    }
}
