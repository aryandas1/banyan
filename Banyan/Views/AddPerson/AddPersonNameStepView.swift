// AddPersonNameStepView.swift
// Step 1 of the add-person flow: first and last name. First name is required.

import SwiftUI

struct AddPersonNameStepView: View {
    @Bindable var vm: AddPersonViewModel
    let onContinue: () -> Void

    @FocusState private var isFirstNameFocused: Bool
    @FocusState private var isLastNameFocused: Bool

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
                .submitLabel(.next)
                .focused($isFirstNameFocused)
                .banyanTextInput(focused: isFirstNameFocused)
                .onSubmit { isLastNameFocused = true }

            TextField("Last name (optional)", text: $vm.lastName)
                .font(.title3)
                .textContentType(.familyName)
                .submitLabel(.done)
                .focused($isLastNameFocused)
                .banyanTextInput(focused: isLastNameFocused)
                .onSubmit { if vm.canContinueFromName { onContinue() } }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(BanyanTheme.Color.background.ignoresSafeArea())
        // The big Continue button, kept just above the keyboard while typing.
        .keyboardAwareBottomBar {
            Button {
                onContinue()
            } label: {
                Text("Continue")
            }
            .buttonStyle(PrimaryFilledButtonStyle())
            .disabled(!vm.canContinueFromName)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(BanyanTheme.Color.background)
        }
        .onAppear {
            isFirstNameFocused = true
        }
    }
}
