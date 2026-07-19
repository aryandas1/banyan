// NameEntryView.swift
// Second onboarding step: capture the owner's name and create their Person record.
// On success, writing ownerPersonId to app storage flips ContentView over to the main app.

import SwiftUI
import SwiftData

struct NameEntryView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage("ownerPersonId") private var ownerPersonIdString: String = ""
    @AppStorage("treeId") private var treeIdString: String = ""

    @State private var vm = OnboardingViewModel()
    @FocusState private var firstNameFocused: Bool

    var body: some View {
        @Bindable var vm = vm

        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Let's start with you")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("You'll be the centre of your tree.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("First name")
                    .font(.headline)
                TextField("First name", text: $vm.firstName)
                    .font(.title3)
                    .textContentType(.givenName)
                    .textFieldStyle(.roundedBorder)
                    .focused($firstNameFocused)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Last name")
                    .font(.headline)
                TextField("Last name (optional)", text: $vm.lastName)
                    .font(.title3)
                    .textContentType(.familyName)
                    .textFieldStyle(.roundedBorder)
            }

            Spacer()

            Button {
                continueTapped()
            } label: {
                Text("Continue")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!vm.canContinue || vm.isSaving)
        }
        .padding()
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
                    treeIdStorage: $treeIdString
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
