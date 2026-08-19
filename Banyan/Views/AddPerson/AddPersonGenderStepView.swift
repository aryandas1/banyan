// AddPersonGenderStepView.swift
// Add-person flow: gender (Male / Female / Skip). Sets `sex`, which drives the
// relationship labels (mother/father, son/daughter, aunt/uncle). Tapping an option
// advances immediately; Skip leaves it unknown — gender is never forced.

import SwiftUI

struct AddPersonGenderStepView: View {
    @Bindable var vm: AddPersonViewModel
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What is their gender?")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("This sets how they appear in the tree — like mother, son, or aunt.")
                .font(.title3)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                genderButton(.male, "Male")
                genderButton(.female, "Female")
            }
            .padding(.top, 8)

            Button("Skip") {
                vm.sex = .unknown
                onContinue()
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(minWidth: 44, minHeight: 44)

            Spacer()
        }
        .padding(24)
    }

    /// A large tappable gender option. Highlighted when it's the current choice
    /// (visible if the user navigates back), and advances the flow when tapped.
    private func genderButton(_ sex: Sex, _ label: String) -> some View {
        Button {
            vm.sex = sex
            onContinue()
        } label: {
            HStack(spacing: 6) {
                if vm.sex == sex {
                    Image(systemName: "checkmark")
                }
                Text(label)
            }
            .font(.title3)
            .frame(maxWidth: .infinity, minHeight: 72)
        }
        .buttonStyle(.borderedProminent)
    }
}
