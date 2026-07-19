// PersonSheetView.swift
// The hub sheet for one person: header, actions, family, story, edit and delete.
// Presented from TreeTabView; owns its own NavigationStack so it can push the edit form.

import SwiftUI
import SwiftData
import PhotosUI

struct PersonSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var sheetVM: PersonSheetViewModel
    @State private var showDeleteConfirmation = false
    @State private var deleteError: Error?
    @State private var pickerItem: PhotosPickerItem?
    @State private var photoImage: UIImage?

    private let isFocal: Bool      // hide "See their family" when already focal
    private let canDelete: Bool    // false for the tree owner — see TreeTabView
    private let mutationService: TreeMutationServiceProtocol
    let onSeeFamily: (UUID) -> Void
    let onAddPerson: (AddPersonContext) -> Void

    init(
        person: Person,
        graphService: GraphServiceProtocol,
        mutationService: TreeMutationServiceProtocol,
        isFocal: Bool,
        canDelete: Bool,
        onSeeFamily: @escaping (UUID) -> Void,
        onAddPerson: @escaping (AddPersonContext) -> Void
    ) {
        _sheetVM = State(initialValue: PersonSheetViewModel(person: person, graphService: graphService))
        self.isFocal = isFocal
        self.canDelete = canDelete
        self.mutationService = mutationService
        self.onSeeFamily = onSeeFamily
        self.onAddPerson = onAddPerson
    }

    private var person: Person { sheetVM.person }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    actionButtons
                    familySection
                    storySection
                    if canDelete { deleteButton }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Close")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("Edit") {
                        PersonEditView(person: person, focusBio: false)
                    }
                }
            }
            .alert("Couldn't delete", isPresented: deleteErrorPresented) {
                Button("OK") { deleteError = nil }
            } message: {
                Text(deleteError?.localizedDescription ?? "Something went wrong. Please try again.")
            }
        }
        .task(id: person.profilePhotoFilename) { await loadPhoto() }
        .onChange(of: pickerItem) { _, newItem in
            Task { await adoptPickedPhoto(newItem) }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                photoCircle
            }
            .buttonStyle(.plain)

            Text(person.fullName)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(lifespanLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var photoCircle: some View {
        Group {
            if let photoImage {
                Image(uiImage: photoImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(.systemGray5)
                    .overlay(
                        Text(person.initials)
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(Circle())
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if !isFocal {
                Button {
                    onSeeFamily(person.id)
                    dismiss()
                } label: {
                    Text("See their family")
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.bordered)
            }

            addButton("Add \(person.firstName)'s parent") { onAddPerson(.parent(of: person)) }
            addButton("Add \(person.firstName)'s partner") { onAddPerson(.partner(of: person)) }
            addButton("Add \(person.firstName)'s child") { onAddPerson(.child(of: person)) }
        }
    }

    private func addButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, minHeight: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Family

    @ViewBuilder
    private var familySection: some View {
        let hasFamily = !sheetVM.parents.isEmpty || !sheetVM.partners.isEmpty
            || !sheetVM.children.isEmpty || !sheetVM.siblings.isEmpty
        if hasFamily {
            VStack(alignment: .leading, spacing: 8) {
                Text("Family")
                    .font(.headline)
                relationshipRows(sheetVM.parents, label: "Parent")
                relationshipRows(sheetVM.partners, label: "Partner")
                relationshipRows(sheetVM.children, label: "Child")
                relationshipRows(sheetVM.siblings, label: "Sibling")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func relationshipRows(_ people: [Person], label: String) -> some View {
        ForEach(people) { relative in
            RelationshipRowView(person: relative, relationshipLabel: label) {
                onSeeFamily(relative.id)
                dismiss()
            }
        }
    }

    // MARK: - Story

    private var storySection: some View {
        NavigationLink {
            PersonEditView(person: person, focusBio: true)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Story")
                    .font(.headline)
                if let bio = person.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Add a story about \(person.firstName)")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Text("Delete \(person.firstName)")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .confirmationDialog(
            "Delete \(person.firstName)?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deletePerson() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove them from the tree. This cannot be undone.")
        }
    }

    private func deletePerson() {
        do {
            try mutationService.deletePerson(person, in: modelContext)
            dismiss()   // TreeTabView's onChange(of: allPeople.count) refreshes the tree
        } catch {
            deleteError = error
        }
    }

    // MARK: - Photo I/O

    /// Loads the stored profile photo off the synchronous main path.
    private func loadPhoto() async {
        guard let filename = person.profilePhotoFilename else {
            photoImage = nil
            return
        }
        let image = await Task.detached { PhotoStorageService.load(filename: filename) }.value
        photoImage = image
    }

    /// Persists a freshly picked photo and points the person at the new file.
    private func adoptPickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        guard let filename = await Task.detached(operation: { PhotoStorageService.save(image) }).value
        else { return }

        if let old = person.profilePhotoFilename {
            PhotoStorageService.delete(filename: old)
        }
        person.profilePhotoFilename = filename
        try? modelContext.save()
        photoImage = image
    }

    // MARK: - Derived text

    /// The birth/death summary line under the name.
    private var lifespanLine: String {
        let birth = person.birthDate?.year
        let death = person.deathDate?.year
        if person.isDeceased {
            switch (birth, death) {
            case let (b?, d?): return "\(b)–\(d)"
            case let (b?, nil): return "Born \(b) · Deceased"
            case let (nil, d?): return "Died \(d)"
            case (nil, nil): return "Deceased"
            }
        } else {
            if let birth { return "Born \(birth) · Living" }
            return "Living"
        }
    }

    private var deleteErrorPresented: Binding<Bool> {
        Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )
    }
}
