// PersonEditView.swift
// The edit form pushed within the person sheet's NavigationStack. Writes back
// through PersonEditViewModel; the Sex picker is what makes `sex` editable.

import SwiftUI
import SwiftData

struct PersonEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var editVM: PersonEditViewModel
    @FocusState private var bioFocused: Bool
    let person: Person
    let focusBio: Bool

    init(person: Person, focusBio: Bool) {
        self.person = person
        self.focusBio = focusBio
        _editVM = State(initialValue: PersonEditViewModel(person: person))
    }

    var body: some View {
        Form {
            nameSection
            detailsSection
            birthSection
            statusSection
            storySection
        }
        .navigationTitle("Edit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { saveAndDismiss() }
                    .disabled(!editVM.canSave)
            }
        }
        .alert("Couldn't save", isPresented: saveErrorPresented) {
            Button("OK") { editVM.saveError = nil }
        } message: {
            Text(editVM.saveError?.localizedDescription ?? "Something went wrong. Please try again.")
        }
        .task {
            if focusBio { bioFocused = true }
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section("Name") {
            TextField("First name", text: $editVM.firstName)
                .textContentType(.givenName)
            TextField("Last name (optional)", text: $editVM.lastName)
                .textContentType(.familyName)
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            Picker("Sex", selection: $editVM.sex) {
                ForEach(Sex.allCases, id: \.self) { sex in
                    Text(label(for: sex)).tag(sex)
                }
            }
        }
    }

    private var birthSection: some View {
        Section("Birth") {
            TextField("Birth year (e.g. 1945)", text: $editVM.birthYearText)
                .keyboardType(.numberPad)
            TextField("Birth month (1–12, optional)", text: $editVM.birthMonthText)
                .keyboardType(.numberPad)
        }
    }

    private var statusSection: some View {
        Section("Status") {
            Toggle("Passed away", isOn: $editVM.isDeceased)
            if editVM.isDeceased {
                TextField("Death year (optional)", text: $editVM.deathYearText)
                    .keyboardType(.numberPad)
            }
        }
    }

    private var storySection: some View {
        Section("Story") {
            TextEditor(text: $editVM.bio)
                .font(.body)
                .frame(minHeight: 120)
                .focused($bioFocused)
        }
    }

    // MARK: - Save

    /// Writes the edits back and closes the form; a thrown error drives the alert.
    private func saveAndDismiss() {
        Task {
            do {
                try await editVM.save(person: person, in: modelContext)
                dismiss()
            } catch {
                editVM.saveError = error
            }
        }
    }

    /// A user-facing label for each sex case.
    private func label(for sex: Sex) -> String {
        switch sex {
        case .male: "Male"
        case .female: "Female"
        case .unknown: "Unknown"
        }
    }

    /// Bridges the optional `saveError` into the Bool binding `.alert` needs.
    private var saveErrorPresented: Binding<Bool> {
        Binding(
            get: { editVM.saveError != nil },
            set: { isPresented in
                if !isPresented { editVM.saveError = nil }
            }
        )
    }
}
