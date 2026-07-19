// AddPersonView.swift
// The add-person sheet: a NavigationStack pushing Name → Birth → Status → Review.
// Composition root for the flow — the concrete TreeMutationService is created here.

import SwiftUI
import SwiftData

/// The steps pushed after the root name step.
enum AddPersonStep: Hashable {
    case birth
    case status
    case review
}

struct AddPersonView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var vm: AddPersonViewModel
    @State private var path: [AddPersonStep] = []
    let onSave: () -> Void

    init(context: AddPersonContext, onSave: @escaping () -> Void) {
        _vm = State(initialValue: AddPersonViewModel(
            context: context,
            mutationService: TreeMutationService()
        ))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack(path: $path) {
            AddPersonNameStepView(vm: vm) {
                path.append(.birth)
            }
            .navigationDestination(for: AddPersonStep.self) { step in
                switch step {
                case .birth:
                    AddPersonBirthStepView(vm: vm) {
                        path.append(.status)
                    }
                case .status:
                    AddPersonStatusStepView(vm: vm) {
                        path.append(.review)
                    }
                case .review:
                    AddPersonReviewStepView(vm: vm) {
                        saveAndDismiss()
                    } onChangeSomething: {
                        path.removeAll()
                    }
                }
            }
            .alert("Couldn't save", isPresented: saveErrorPresented) {
                Button("OK") { vm.saveError = nil }
            } message: {
                Text(vm.saveError?.localizedDescription ?? "Something went wrong. Please try again.")
            }
        }
    }

    /// Runs the save, then notifies the parent and closes the sheet.
    /// A thrown error is routed into `vm.saveError`, which drives the alert.
    private func saveAndDismiss() {
        Task {
            do {
                try await vm.save(in: modelContext)
                onSave()
                dismiss()
            } catch {
                vm.saveError = error
            }
        }
    }

    /// Bridges the optional `saveError` into the Bool binding `.alert` needs.
    private var saveErrorPresented: Binding<Bool> {
        Binding(
            get: { vm.saveError != nil },
            set: { isPresented in
                if !isPresented { vm.saveError = nil }
            }
        )
    }
}
