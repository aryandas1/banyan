// AddPersonGenderStepView.swift
// Add-person flow: gender (Male / Female / Not sure). Sets `sex`, which drives the
// relationship labels (mother/father, son/daughter, aunt/uncle). Tapping an option
// advances immediately; "Not sure" leaves sex as .unknown — gender is never forced.

import SwiftUI

struct AddPersonGenderStepView: View {
    @Bindable var vm: AddPersonViewModel
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What is their gender?")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("This sets how they appear in the tree — like mother, son, or aunt.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                genderButton(.male, "Male")
                genderButton(.female, "Female")
            }
            .padding(.top, 8)

            Button {
                vm.sex = .unknown
                onContinue()
            } label: {
                Text("Not sure")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(.systemGray3), lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(24)
    }

    /// Filled when selected, outlined when not. Tapping always advances the flow.
    private func genderButton(_ sex: Sex, _ label: String) -> some View {
        let isSelected = vm.sex == sex
        return Button {
            vm.sex = sex
            onContinue()
        } label: {
            Text(label)
                .font(.title3.weight(.semibold))
                .foregroundStyle(isSelected ? .white : Color.accentColor)
                .frame(maxWidth: .infinity, minHeight: 72)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.accentColor : Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.accentColor, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }
}
