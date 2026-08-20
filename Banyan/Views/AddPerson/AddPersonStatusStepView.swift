// AddPersonStatusStepView.swift
// Step 3 of the add-person flow: living or deceased, via two large option cards.
// Selecting deceased reveals the death-year field.

import SwiftUI

struct AddPersonStatusStepView: View {
    @Bindable var vm: AddPersonViewModel
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Are they still with us?")
                .font(.largeTitle)
                .fontWeight(.bold)

            optionCard(title: "Yes, they are living", isSelected: !vm.isDeceased) {
                vm.isDeceased = false
            }

            optionCard(title: "No, they have passed away", isSelected: vm.isDeceased) {
                vm.isDeceased = true
            }

            if vm.isDeceased {
                TextField("Year they passed, e.g. 1998", text: $vm.deathYearText)
                    .font(.title2)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            }

            Spacer()

            Button {
                onContinue()
            } label: {
                Text("Continue")
            }
            .buttonStyle(PrimaryFilledButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(BanyanTheme.Color.background.ignoresSafeArea())
    }

    /// One full-width selectable card with a trailing checkmark when selected.
    private func optionCard(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.title3)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                }
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? BanyanTheme.Color.primaryTint : BanyanTheme.Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? BanyanTheme.Color.primary : BanyanTheme.Color.border, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
