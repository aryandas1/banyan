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

            if vm.coParentQuestionApplies {
                coParentQuestion
            }

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

    /// Asks whether the new partner is also a parent of the anchor's existing
    /// children — the difference between a co-parent (join their union) and a
    /// separate/step partner (a new union). Only shown when it applies.
    private var coParentQuestion: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Is \(vm.displayName) also a parent of \(vm.coParentChildrenNames)?")
                .font(.headline)

            coParentOption(
                title: "Yes — they're the parents together",
                isSelected: vm.coParentWithExistingChildren
            ) {
                vm.coParentWithExistingChildren = true
            }

            coParentOption(
                title: "No — a separate partner",
                isSelected: !vm.coParentWithExistingChildren
            ) {
                vm.coParentWithExistingChildren = false
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    /// One selectable answer in the co-parent question, filled when chosen.
    private func coParentOption(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                Text(title)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
