// AddPersonNameStepView.swift
// Step 1 of the add-person flow: first and last name. First name is required.

import SwiftUI

struct AddPersonNameStepView: View {
    @Bindable var vm: AddPersonViewModel
    let onContinue: () -> Void

    @FocusState private var isFirstNameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(vm.context.heading)
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("What is their name?")
                .font(.title3)
                .foregroundStyle(.secondary)

            TextField("First name", text: $vm.firstName)
                .font(.title3)
                .textContentType(.givenName)
                .textFieldStyle(.roundedBorder)
                .focused($isFirstNameFocused)

            TextField("Last name (optional)", text: $vm.lastName)
                .font(.title3)
                .textContentType(.familyName)
                .textFieldStyle(.roundedBorder)

            Spacer()

            Button {
                onContinue()
            } label: {
                Text("Continue")
                    .font(.title3)
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!vm.canContinueFromName)
        }
        .padding(24)
        .onAppear {
            isFirstNameFocused = true
        }
    }
}
