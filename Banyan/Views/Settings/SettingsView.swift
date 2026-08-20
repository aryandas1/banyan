// SettingsView.swift
// The Settings tab: who's signed in, the app version, and a sign-out control.
// Deliberately minimal for older, non-technical users — one screen, no nesting.

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AuthStateManager.self) private var authState
    @Environment(\.modelContext) private var modelContext
    @AppStorage("ownerPersonId") private var ownerPersonIdString: String = ""

    @State private var ownerName: String?
    @State private var showSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                if let ownerName {
                    Section("You") {
                        Text(ownerName)
                            .font(.body)
                            .foregroundStyle(BanyanTheme.Color.textPrimary)
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(BanyanTheme.Color.textSecondary)
                    }
                    .font(.body)
                }

                Section {
                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        Text("Sign out")
                            .frame(maxWidth: .infinity, minHeight: BanyanTheme.TapTarget.minimum)
                    }
                }
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(BanyanTheme.Color.background)
            .task { loadOwnerName() }
            .confirmationDialog(
                "Sign out?",
                isPresented: $showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign out", role: .destructive) {
                    Task { await authState.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You can sign back in anytime. Your family tree stays safe.")
            }
        }
    }

    /// Loads the signed-in owner's display name for the "You" section. A viewer who
    /// never onboarded has no ownerPersonId, so the section simply doesn't appear.
    private func loadOwnerName() {
        guard let id = UUID(uuidString: ownerPersonIdString) else { return }
        let match = try? modelContext.fetch(
            FetchDescriptor<Person>(predicate: #Predicate { $0.id == id })
        ).first
        ownerName = match?.fullName
    }

    /// Marketing version + build, e.g. "1.0 (12)", read from the app bundle.
    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        guard let build = info?["CFBundleVersion"] as? String else { return short }
        return "\(short) (\(build))"
    }
}

#Preview {
    SettingsView()
        .environment(AuthStateManager(authService: PreviewAuthService()))
}

/// A no-op auth service so the preview renders without a Supabase client.
private final class PreviewAuthService: AuthServiceProtocol {
    var userId: UUID?
    func restoreSession() async throws -> UUID { UUID() }
    func signOut() async throws {}
}
