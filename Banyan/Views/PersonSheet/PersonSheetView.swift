// PersonSheetView.swift
// The hub sheet for one person: header, actions, family, story, edit and delete.
// Presented from TreeTabView; owns its own NavigationStack so it can push the edit form.
// The body is a plain-style List — swipe-to-unlink on family rows only works in a List.

import SwiftUI
import SwiftData

struct PersonSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var syncService
    /// When true (a viewer's shared tree), every edit control is hidden.
    @Environment(\.isReadOnly) private var isReadOnly
    @State private var sheetVM: PersonSheetViewModel
    @State private var showDeleteConfirmation = false
    @State private var showLinkSheet = false
    @State private var deleteError: Error?
    @State private var showAddProfilePhoto = false
    @State private var showAddPhoto = false
    @State private var photoSelection: PhotoSelection?

    private let isFocal: Bool      // hide "See their family" when already focal
    private let canDelete: Bool    // false for the tree owner — see TreeTabView
    private let allPeople: [Person]   // candidates for the link sheet — from TreeTabView
    private let mutationService: TreeMutationServiceProtocol
    let onSeeFamily: (UUID) -> Void
    let onAddPerson: (AddPersonContext) -> Void

    init(
        person: Person,
        allPeople: [Person],
        graphService: GraphServiceProtocol,
        mutationService: TreeMutationServiceProtocol,
        isFocal: Bool,
        canDelete: Bool,
        onSeeFamily: @escaping (UUID) -> Void,
        onAddPerson: @escaping (AddPersonContext) -> Void
    ) {
        _sheetVM = State(initialValue: PersonSheetViewModel(person: person, graphService: graphService))
        self.allPeople = allPeople
        self.isFocal = isFocal
        self.canDelete = canDelete
        self.mutationService = mutationService
        self.onSeeFamily = onSeeFamily
        self.onAddPerson = onAddPerson
    }

    private var person: Person { sheetVM.person }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                        .frame(maxWidth: .infinity)
                    actionButtons
                }
                .listRowSeparator(.hidden)

                familySection

                photosSection

                if showsStory {
                    Section {
                        storySection
                    }
                    .listRowSeparator(.hidden)
                }

                if canDelete && !isReadOnly {
                    Section {
                        deleteButton
                    }
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(BanyanTheme.Color.surface)
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
                if !isReadOnly {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink("Edit") {
                            PersonEditView(person: person, focusBio: false)
                        }
                    }
                }
            }
            .alert("Couldn't delete", isPresented: deleteErrorPresented) {
                Button("OK") { deleteError = nil }
            } message: {
                Text(deleteError?.localizedDescription ?? "Something went wrong. Please try again.")
            }
            .sheet(isPresented: $showLinkSheet) {
                LinkPersonView(
                    anchor: person,
                    allPeople: allPeople,
                    mutationService: mutationService,
                    onSave: { sheetVM.refresh() }
                )
            }
        }
        // System drag handle instead of a hand-rolled capsule — the body is a
        // List, which no custom top element slots into cleanly.
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showAddProfilePhoto, onDismiss: { sheetVM.refresh() }) {
            AddPhotoView(person: person, preselectAsProfilePhoto: true)
        }
        .sheet(isPresented: $showAddPhoto, onDismiss: { sheetVM.refresh() }) {
            AddPhotoView(person: person)
        }
        .sheet(item: $photoSelection, onDismiss: { sheetVM.refresh() }) { selection in
            PhotoDetailView(photos: selection.photos, currentIndex: selection.startIndex)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            avatarButton

            Text(person.fullName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(BanyanTheme.Color.textPrimary)
                .multilineTextAlignment(.center)

            Text(lifespanLine)
                .font(.subheadline)
                .foregroundStyle(BanyanTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    /// The 96pt avatar. Tapping opens the add-photo sheet to set a new profile
    /// photo — disabled (and the camera badge hidden) for a read-only viewer.
    private var avatarButton: some View {
        Button {
            showAddProfilePhoto = true
        } label: {
            Circle()
                .fill(BanyanTheme.avatarColor(for: person.id))
                .frame(width: 96, height: 96)
                .overlay {
                    if let image = sheetVM.profileImage {
                        CroppedCircleImage(
                            uiImage: image,
                            crop: AvatarCrop(from: person.profilePhoto),
                            diameter: 96
                        )
                    } else {
                        Text(person.initials)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if !isReadOnly {
                        Image(systemName: "camera.fill")
                            .font(.caption)
                            .foregroundStyle(BanyanTheme.Color.textSecondary)
                            .padding(6)
                            .background(BanyanTheme.Color.surface)
                            .clipShape(Circle())
                            .shadow(radius: 2)
                            .offset(x: 4, y: 4)
                    }
                }
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .disabled(isReadOnly)
        .accessibilityLabel(isReadOnly ? "Profile photo" : "Change profile photo")
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
                }
                .buttonStyle(PrimaryFilledButtonStyle())
            }

            // All add/link entry points are hidden for a viewer.
            if !isReadOnly {
                addButton("Add \(person.firstName)'s parent") { onAddPerson(.parent(of: person)) }
                addButton("Add \(person.firstName)'s partner") { onAddPerson(.partner(of: person)) }
                addButton("Add \(person.firstName)'s child") { onAddPerson(.child(of: person)) }
                addButton("Add \(person.firstName)'s sibling") { onAddPerson(.sibling(of: person)) }
                addButton("Link to someone already in the tree") { showLinkSheet = true }
            }
        }
    }

    private func addButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(TintFilledButtonStyle())
    }

    // MARK: - Family

    @ViewBuilder
    private var familySection: some View {
        let hasFamily = !sheetVM.parents.isEmpty || !sheetVM.partners.isEmpty
            || !sheetVM.children.isEmpty || !sheetVM.siblings.isEmpty
        if hasFamily {
            Section {
                relationshipRows(sheetVM.parents, label: "Parent")
                relationshipRows(sheetVM.partners, label: "Partner")
                relationshipRows(sheetVM.children, label: "Child")
                // Siblings can't be unlinked: the shared union is the parents'
                // union, so removing the sibling's link would detach them from
                // their own parents, not just from this person.
                relationshipRows(sheetVM.siblings, label: "Sibling", canUnlink: false)
            } header: {
                Text("Family")
                    .font(.headline)
                    .foregroundStyle(BanyanTheme.Color.textPrimary)
                    .textCase(nil)
            }
            .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder
    private func relationshipRows(
        _ people: [Person],
        label: String,
        canUnlink: Bool = true
    ) -> some View {
        ForEach(people) { relative in
            RelationshipRowView(
                person: relative,
                relationshipLabel: label,
                onTap: {
                    onSeeFamily(relative.id)
                    dismiss()
                },
                onDelete: (canUnlink && !isReadOnly) ? { unlink(relative) } : nil
            )
        }
    }

    /// Removes the connection between this person and `relative`, then refreshes
    /// the family rows. No confirmation — re-linking restores the connection.
    private func unlink(_ relative: Person) {
        try? mutationService.unlink(relative, from: person, in: modelContext)
        sheetVM.refresh()
        syncService.scheduleSync(treeId: person.treeId, context: modelContext)
    }

    // MARK: - Photos

    @ViewBuilder
    private var photosSection: some View {
        let sorted = person.photos.sorted(by: { $0.sortOrder < $1.sortOrder })
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("Photos")
                    .font(.headline)
                    .foregroundStyle(BanyanTheme.Color.textPrimary)
                    .padding(.horizontal, 16)

                if sorted.isEmpty && isReadOnly {
                    Text("No photos added yet.")
                        .font(.body)
                        .foregroundStyle(BanyanTheme.Color.textSecondary)
                        .padding(.horizontal, 16)
                } else {
                    PhotoGalleryView(
                        photos: sorted,
                        canAdd: !isReadOnly,
                        onAddPhoto: { showAddPhoto = true },
                        onSelectPhoto: { photo in
                            let index = sorted.firstIndex(where: { $0.id == photo.id }) ?? 0
                            photoSelection = PhotoSelection(id: photo.id, photos: sorted, startIndex: index)
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowSeparator(.hidden)
    }

    // MARK: - Story

    /// The owner always sees the Story block (to add/edit); a viewer only when
    /// there's actually a story, so read-only never renders an empty Section.
    private var showsStory: Bool {
        !isReadOnly || !(person.bio ?? "").isEmpty
    }

    @ViewBuilder
    private var storySection: some View {
        // A viewer sees the story read-only (no tap-through to the editor), and
        // only when there's a story to show.
        if isReadOnly {
            if let bio = person.bio, !bio.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Story")
                        .font(.headline)
                        .foregroundStyle(BanyanTheme.Color.textPrimary)
                    Text(bio)
                        .font(.body)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .background(BanyanTheme.Color.background)
                .clipShape(.rect(cornerRadius: BanyanTheme.Radius.card))
            }
        } else {
            NavigationLink {
                PersonEditView(person: person, focusBio: true)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Story")
                        .font(.headline)
                        .foregroundStyle(BanyanTheme.Color.textPrimary)
                    if let bio = person.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.body)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("Add a story about \(person.firstName)")
                            .font(.body)
                            .foregroundStyle(BanyanTheme.Color.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
                .background(BanyanTheme.Color.background)
                .clipShape(.rect(cornerRadius: BanyanTheme.Radius.card))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Text("Delete \(person.firstName)")
                .font(.body)
                .frame(maxWidth: .infinity, minHeight: BanyanTheme.TapTarget.minimum)
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
            let treeId = person.treeId   // capture before the delete detaches it
            try mutationService.deletePerson(person, in: modelContext)
            syncService.scheduleSync(treeId: treeId, context: modelContext)
            dismiss()   // TreeTabView's onChange(of: allPeople.count) refreshes the tree
        } catch {
            deleteError = error
        }
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

/// Identifies which photo gallery to open full-screen and where to start.
/// A plain value type so `.sheet(item:)` has an unambiguous `Identifiable` id
/// (a SwiftData `@Model`'s `id` is ambiguous for that overload).
private struct PhotoSelection: Identifiable {
    let id: UUID
    let photos: [PersonPhoto]
    let startIndex: Int
}
