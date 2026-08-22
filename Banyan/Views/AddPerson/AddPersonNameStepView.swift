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
                .focused($isFirstNameFocused)
                .banyanTextInput(focused: isFirstNameFocused)

            TextField("Last name (optional)", text: $vm.lastName)
                .font(.title3)
                .textContentType(.familyName)
                .focused($isLastNameFocused)
                .banyanTextInput(focused: isLastNameFocused)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(BanyanTheme.Color.background.ignoresSafeArea())
        // Pin Continue above the keyboard — a bottom-of-frame button is otherwise
        // hidden behind it while the name field is being typed.
        .safeAreaInset(edge: .bottom) {
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
