// NameEntryView.swift
// Second onboarding step: capture the owner's name and create their Person record.
// On success, writing ownerPersonId to app storage flips ContentView over to the main app.

import SwiftUI
import SwiftData

struct NameEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService

    @AppStorage("ownerPersonId") private var ownerPersonIdString: String = ""
    @AppStorage("treeId") private var treeIdString: String = ""

    @State private var vm = OnboardingViewModel()
    @FocusState private var firstNameFocused: Bool
    @FocusState private var lastNameFocused: Bool

    var body: some View {
        @Bindable var vm = vm

        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Let's start with you")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(BanyanTheme.Color.textPrimary)

                Text("You'll be the centre of your tree.")
                    .font(.subheadline)
                    .foregroundStyle(BanyanTheme.Color.textSecondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("First name")
                    .font(.headline)
                    .foregroundStyle(BanyanTheme.Color.textPrimary)
                TextField("First name", text: $vm.firstName)
                    .font(.body)
                    .textContentType(.givenName)
                    .focused($firstNameFocused)
                    .banyanTextInput(focused: firstNameFocused)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Last name")
                    .font(.headline)
                    .foregroundStyle(BanyanTheme.Color.textPrimary)
                TextField("Last name (optional)", text: $vm.lastName)
                    .font(.body)
                    .textContentType(.familyName)
                    .focused($lastNameFocused)
                    .banyanTextInput(focused: lastNameFocused)
            }

            Spacer()

            Button {
                continueTapped()
            } label: {
                Text("Continue")
            }
            .buttonStyle(PrimaryFilledButtonStyle())
            .disabled(!vm.canContinue || vm.isSaving)
        }
        .padding()
        .background(BanyanTheme.Color.surface.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { firstNameFocused = true }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { vm.saveError != nil },
                set: { presented in if !presented { vm.saveError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again.")
        }
    }

    private func continueTapped() {
        Task {
            do {
                try await vm.save(
                    in: modelContext,
                    ownerIdStorage: $ownerPersonIdString,
                    treeIdStorage: $treeIdString,
                    sync: syncService
                )
            } catch {
                vm.saveError = error
            }
        }
    }
}

#Preview("Empty") {
    NavigationStack {
        NameEntryView()
    }
}

#Preview("Name entered") {
    NavigationStack {
        NameEntryView(previewFirstName: "Ravi", previewLastName: "Das")
    }
}

extension NameEntryView {
    /// Preview-only initializer that seeds the form. Not used by the app.
    fileprivate init(previewFirstName: String, previewLastName: String) {
        let seeded = OnboardingViewModel()
        seeded.firstName = previewFirstName
        seeded.lastName = previewLastName
        _vm = State(initialValue: seeded)
    }
}
