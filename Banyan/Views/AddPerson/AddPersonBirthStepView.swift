// AddPersonBirthStepView.swift
// Step 2 of the add-person flow: birth year. Optional — "I don't know" skips it.

import SwiftUI

struct AddPersonBirthStepView: View {
    @Bindable var vm: AddPersonViewModel
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("When were they born?")
                .font(.largeTitle)
                .fontWeight(.bold)

            TextField("e.g. 1945", text: $vm.birthYearText)
                .font(.title2)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)

            Button("I don't know") {
                vm.birthYearText = ""
                onContinue()
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(minWidth: 44, minHeight: 44)

            Spacer()

            Button {
                onContinue()
            } label: {
                Text("Continue")
                    .font(.title3)
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}
