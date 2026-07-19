// AddPersonReviewStepView.swift
// Step 4 of the add-person flow: a preview card of the person about to be
// created, with Save and a way back to the start.

import SwiftUI

struct AddPersonReviewStepView: View {
    let vm: AddPersonViewModel
    let onSave: () -> Void
    let onChangeSomething: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Does this look right?")
                .font(.largeTitle)
                .fontWeight(.bold)

            previewCard

            Spacer()

            Button {
                onSave()
            } label: {
                Text("Save")
                    .font(.title3)
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isSaving)

            Button("Change something") {
                onChangeSomething()
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(24)
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(vm.displayName)
                .font(.title2)
                .fontWeight(.semibold)

            Text(vm.birthDescription)
                .font(.body)
                .foregroundStyle(.secondary)

            Text(vm.statusDescription)
                .font(.body)
                .foregroundStyle(.secondary)

            Text(vm.context.relationshipDescription)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}
