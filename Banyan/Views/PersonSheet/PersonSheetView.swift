// PersonSheetView.swift
// The hub sheet for one person: header, actions, family, story, edit and delete.
// Presented from TreeTabView; owns its own NavigationStack so it can push the edit form.
// The body is a plain-style List — swipe-to-unlink on family rows only works in a List.

import SwiftUI
import SwiftData
import PhotosUI

struct PersonSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var syncService
    @Environment(\.photoSyncService) private var photoSyncService
    /// When true (a viewer's shared tree), every edit control is hidden.
    @Environment(\.isReadOnly) private var isReadOnly
    @State private var sheetVM: PersonSheetViewModel
    @State private var showDeleteConfirmation = false
    @State private var showLinkSheet = false
    @State private var deleteError: Error?
    @State private var showAddPhoto = false
    @State private var photoSelection: PhotoSelection?

    // Profile-photo flow: tapping the avatar picks a photo, frames it in the
    // Move & Scale step, then saves — or, when a photo already exists, offers a
    // choice between picking a new one and re-framing the current one.
    @State private var showProfilePhotoOptions = false
    @State private var showProfilePicker = false
    @State private var profilePickerItem: PhotosPickerItem?
    @State private var pickedProfileImage: PickedProfileImage?
    @State private var showAdjustFraming = false

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
                }
                .listRowSeparator(.hidden)

                // Lead with who this person was (dates + shraddha) before the
                // editing actions — content over controls.
                datesSection

                Section {
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
        .sheet(isPresented: $showAddPhoto, onDismiss: { sheetVM.refresh() }) {
            AddPhotoView(person: person)
        }
        .sheet(item: $photoSelection, onDismiss: { sheetVM.refresh() }) { selection in
            PhotoDetailView(photos: selection.photos, currentIndex: selection.startIndex)
        }
        // When a profile photo already exists, the avatar offers a choice; with none,
        // it goes straight to the picker.
        .confirmationDialog("Profile photo", isPresented: $showProfilePhotoOptions, titleVisibility: .hidden) {
            Button("Choose New Photo") { showProfilePicker = true }
            Button("Adjust Framing") { showAdjustFraming = true }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showProfilePicker, selection: $profilePickerItem, matching: .images)
        .onChange(of: profilePickerItem) { _, item in loadPickedProfileImage(item) }
        // Freshly picked photo → frame it, then save as the profile photo. No
        // onDismiss refresh here: saveNewProfilePhoto's async Task refreshes once the
        // save actually lands, so a synchronous dismiss-time refresh would just race
        // it and briefly read pre-save state.
        .sheet(item: $pickedProfileImage) { picked in
            AvatarFramingView(image: picked.image, confirmLabel: "Use Photo") { crop, _ in
                saveNewProfilePhoto(picked, crop: crop)
            }
        }
        // Re-frame the existing profile photo without replacing it.
        .sheet(isPresented: $showAdjustFraming, onDismiss: { sheetVM.refresh() }) {
            if let profile = person.profilePhoto {
                ProfilePhotoCropView(photo: profile)
            }
        }
    }

    /// Loads the picked item into memory and triggers the Move & Scale sheet. The
    /// data is kept for EXIF date extraction + the background upload.
    private func loadPickedProfileImage(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }
            pickedProfileImage = PickedProfileImage(image: image, data: data)
            profilePickerItem = nil
        }
    }

    /// Saves a freshly framed photo as this person's profile photo. Reuses
    /// AddPhotoViewModel so the disk write, profile-flag promotion, and background
    /// upload all match the gallery-add path; the chosen framing rides along.
    private func saveNewProfilePhoto(_ picked: PickedProfileImage, crop: AvatarCrop) {
        Task {
            let vm = AddPhotoViewModel(setAsProfilePhoto: true)
            vm.onImageSelected(image: picked.image, data: picked.data)
            try? await vm.save(for: person, in: modelContext, photoSync: photoSyncService, crop: crop)
            sheetVM.refresh()
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
        }
    }

    /// The 96pt avatar. Tapping picks + frames a new profile photo (or, when one
    /// exists, offers choose-new / re-frame) — disabled (and the camera badge
    /// hidden) for a read-only viewer.
    private var avatarButton: some View {
        Button {
            if person.profilePhoto != nil {
                showProfilePhotoOptions = true
            } else {
                showProfilePicker = true
            }
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
                relationshipRows(sheetVM.parents, kind: .parent)
                relationshipRows(sheetVM.partners, kind: .partner)
                relationshipRows(sheetVM.children, kind: .child)
                // Siblings can't be unlinked: the shared union is the parents'
                // union, so removing the sibling's link would detach them from
                // their own parents, not just from this person.
                relationshipRows(sheetVM.siblings, kind: .sibling, canUnlink: false)
            } header: {
                Text("Family")
                    .font(.headline)
                    .foregroundStyle(BanyanTheme.Color.textPrimary)
                    .textCase(nil)
            }
            .listRowSeparator(.hidden)
        }
    }

    /// The relationship categories shown in the Family section.
    private enum RelationKind { case parent, partner, child, sibling }

    @ViewBuilder
    private func relationshipRows(
        _ people: [Person],
        kind: RelationKind,
        canUnlink: Bool = true
    ) -> some View {
        ForEach(people) { relative in
            RelationshipRowView(
                person: relative,
                relationshipLabel: label(kind, for: relative),
                onTap: {
                    onSeeFamily(relative.id)
                    dismiss()
                },
                onDelete: (canUnlink && !isReadOnly) ? { unlink(relative) } : nil
            )
        }
    }

    /// A sexed label for a direct relative — "Wife" / "Daughter" / "Son" / … — so the
    /// Family section matches the People list's wording. This is relative to the FOCAL
    /// person (whose sheet this is), which is the right frame here; the People list is
    /// relative to the tree owner instead, so the two can legitimately differ on
    /// someone else's sheet.
    private func label(_ kind: RelationKind, for relative: Person) -> String {
        switch kind {
        case .parent:  return sexedWord(relative, male: "Father",  female: "Mother",   unknown: "Parent")
        case .partner: return sexedWord(relative, male: "Husband", female: "Wife",     unknown: "Partner")
        case .child:   return sexedWord(relative, male: "Son",     female: "Daughter", unknown: "Child")
        case .sibling: return sexedWord(relative, male: "Brother", female: "Sister",   unknown: "Sibling")
        }
    }

    private func sexedWord(_ person: Person, male: String, female: String, unknown: String) -> String {
        switch person.sex {
        case .male:    return male
        case .female:  return female
        case .unknown: return unknown
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

    // MARK: - Dates

    /// A soft card of the birth and (if deceased) death dates: each row has a small
    /// tinted glyph, the age inline, and an anniversary pill when the next occurrence
    /// is within the next few months — a birthday for the living, shraddha for the
    /// deceased. Hidden entirely when no date is recorded.
    @ViewBuilder
    private var datesSection: some View {
        if person.birthDate != nil || person.isDeceased {
            Section {
                VStack(alignment: .leading, spacing: 18) {
                    if let birth = person.birthDate {
                        dateRow(
                            icon: "leaf.fill",
                            tint: BanyanTheme.Color.positive,
                            title: "Born",
                            value: birth.displayString,
                            age: bornAgeText,
                            pill: birthdayPill
                        )
                    }
                    if person.isDeceased {
                        dateRow(
                            icon: "flame.fill",
                            tint: BanyanTheme.Color.warning,
                            title: "Passed away",
                            value: deathDateValue ?? "Not recorded",
                            age: diedAgeText,
                            pill: shraddhaPill
                        )
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BanyanTheme.Color.background)
                .clipShape(.rect(cornerRadius: BanyanTheme.Radius.card))
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
        }
    }

    /// One date row: a tinted glyph in a soft circle, the label, the date + age on a
    /// line, and an optional anniversary pill beneath.
    private func dateRow(icon: String, tint: Color, title: String, value: String, age: String?, pill: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(BanyanTheme.Color.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(value)
                        .font(.body).fontWeight(.semibold)
                        .foregroundStyle(BanyanTheme.Color.textPrimary)
                    if let age {
                        Text("· \(age)")
                            .font(.subheadline)
                            .foregroundStyle(BanyanTheme.Color.textSecondary)
                    }
                }
                if let pill {
                    Text(pill)
                        .font(.caption).fontWeight(.medium)
                        .foregroundStyle(tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(tint.opacity(0.14))
                        .clipShape(Capsule())
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// The death date's display, or nil when a deceased person has no date recorded
    /// (so the row reads "Not recorded" rather than "Unknown").
    private var deathDateValue: String? {
        guard let death = person.deathDate else { return nil }
        let text = death.displayString
        return text == "Unknown" ? nil : text
    }

    /// Years lived so far (living) or at death (deceased), shown beside the date.
    private var bornAgeText: String? {
        guard !person.isDeceased, let years = PersonAge.years(from: person.birthDate, to: nil) else { return nil }
        return "\(years) yrs"
    }
    private var diedAgeText: String? {
        guard person.isDeceased, let years = PersonAge.years(from: person.birthDate, to: person.deathDate) else { return nil }
        return "aged \(years)"
    }

    /// The birthday pill — only when the next birthday is within the window (~3 months).
    private var birthdayPill: String? {
        guard !person.isDeceased, let birth = person.birthDate,
              let phrase = upcomingPhrase(for: birth) else { return nil }
        return "🎂 Birthday \(phrase)"
    }

    /// The shraddha pill — only when the next death anniversary is within the window.
    private var shraddhaPill: String? {
        guard person.isDeceased, let death = person.deathDate,
              let phrase = upcomingPhrase(for: death) else { return nil }
        return "🪔 Shraddha \(phrase)"
    }

    /// The countdown phrase, but only when the anniversary falls within the next ~3
    /// months (92 days); otherwise nil so the date stands alone without a pill.
    private func upcomingPhrase(for date: PartialDate) -> String? {
        guard let days = AnniversaryCountdown.daysUntilNext(date), days <= 92 else { return nil }
        return AnniversaryCountdown.phrase(for: date)
    }

    // MARK: - Derived text

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

/// A profile photo picked but not yet saved, carried into the Move & Scale sheet.
/// A plain Identifiable value so `.sheet(item:)` presents on selection; `data` is
/// kept for EXIF date extraction and the background upload.
private struct PickedProfileImage: Identifiable {
    let id = UUID()
    let image: UIImage
    let data: Data?
}
