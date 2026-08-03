// InviteView.swift
// Collects a phone number, creates an invitation, then opens the iOS share sheet
// pre-filled with the invite deep link. No SMS is sent by the app — the owner
// forwards the link however they like.

import SwiftUI

struct InviteView: View {

    var viewModel: ShareViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var phoneNumber = ""
    @State private var showShareSheet = false
    @State private var inviteToken: String?
    @State private var errorMessage: String?

    private var canSend: Bool {
        !phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Their phone number")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("e.g. +91 98765 43210", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .font(.title3)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(.rect(cornerRadius: 12))
                        .frame(minHeight: 56)
                }
                .padding(.horizontal)

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .padding(.horizontal)
                }

                Text("We'll create a private link. Send it to them however you like — WhatsApp, iMessage, or any app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                Spacer()

                Button {
                    Task { await sendInvite() }
                } label: {
                    Group {
                        if viewModel.isCreatingInvite {
                            ProgressView()
                        } else {
                            Text("Create invite link")
                                .font(.body.bold())
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSend || viewModel.isCreatingInvite)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Who would you like to invite?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet, onDismiss: { dismiss() }) {
                if let inviteToken {
                    ShareSheet(message: inviteMessage(token: inviteToken))
                }
            }
        }
    }

    private func sendInvite() async {
        errorMessage = nil
        // Trim so stored/displayed numbers don't carry stray whitespace and repeat
        // invites of the same number dedupe reliably.
        let trimmed = phoneNumber.trimmingCharacters(in: .whitespaces)
        do {
            let token = try await viewModel.createInvitation(phoneNumber: trimmed)
            inviteToken = token
            showShareSheet = true
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    private func inviteMessage(token: String) -> String {
        "I've shared my family tree with you on Banyan. Tap to view: banyan://invite?token=\(token)"
    }
}

// MARK: - ShareSheet wrapper

/// Bridges UIActivityViewController into SwiftUI for the system share sheet.
struct ShareSheet: UIViewControllerRepresentable {
    let message: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [message], applicationActivities: nil)
    }

    func updateUIViewController(_ viewController: UIActivityViewController, context: Context) {}
}
