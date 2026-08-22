// PhotoDetailView.swift
// Full-screen viewer for a person's photos: swipe between them, and — for editors
// only — edit metadata, set as profile photo, or delete. Every edit control is
// gated on \.isReadOnly, so a viewer of a shared tree sees a read-only carousel.

import SwiftUI

struct PhotoDetailView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isReadOnly) private var isReadOnly
    @Environment(\.photoSyncService) private var photoSync

    let photos: [PersonPhoto]
    @State var currentIndex: Int

    @State private var showDeleteConfirmation = false
    @State private var showEditMetadata = false
    @State private var showCrop = false

    private var current: PersonPhoto { photos[currentIndex] }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                TabView(selection: $currentIndex) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                        PhotoFullView(photo: photo)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Close")
                }
                if !isReadOnly {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Edit details") { showEditMetadata = true }
                            if current.isProfilePhoto {
                                Button("Adjust framing") { showCrop = true }
                            } else {
                                Button("Set as profile photo") { setAsProfile() }
                            }
                            Divider()
                            Button("Delete photo", role: .destructive) {
                                showDeleteConfirmation = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(.white)
                        }
                        .accessibilityLabel("Photo options")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                photoMetadataBar
            }
        }
        .confirmationDialog(
            "Delete this photo?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deletePhoto() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .sheet(isPresented: $showEditMetadata) {
            EditPhotoMetadataView(photo: current)
        }
        .sheet(isPresented: $showCrop) {
            ProfilePhotoCropView(photo: current)
        }
    }

    @ViewBuilder
    private var photoMetadataBar: some View {
        let photo = current
        if photo.caption != nil || photo.takenDateDisplay != nil || photo.takenPlace != nil {
            VStack(alignment: .leading, spacing: 4) {
                if let caption = photo.caption {
                    Text(caption)
                        .font(.body)
                        .foregroundStyle(.white)
                }
                HStack(spacing: 8) {
                    if let date = photo.takenDateDisplay {
                        Label(date, systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    if let place = photo.takenPlace {
                        Label(place, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(0.6))
        }
    }

    private func setAsProfile() {
        PhotoActionsViewModel(photoSync: photoSync).setAsProfile(current, among: photos, in: context)
    }

    private func deletePhoto() {
        PhotoActionsViewModel(photoSync: photoSync).delete(current, among: photos, in: context)
        dismiss()
    }
}

// MARK: - Full image loader

/// Loads and shows one photo at full size, with a spinner while it loads.
struct PhotoFullView: View {
    let photo: PersonPhoto
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .task(id: photo.filename) {
            let filename = photo.filename
            image = await Task.detached(priority: .userInitiated) {
                PhotoStorageService.load(filename: filename)
            }.value
        }
    }
}

// MARK: - Edit metadata sheet

/// Edits a single photo's caption / date / place. Owner-only — reached from the
/// PhotoDetailView menu, which is itself gated on \.isReadOnly.
struct EditPhotoMetadataView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.photoSyncService) private var photoSync

    let photo: PersonPhoto

    @State private var caption: String
    @State private var takenYearText: String
    @State private var takenMonthText: String
    @State private var takenPlace: String

    init(photo: PersonPhoto) {
        self.photo = photo
        _caption = State(initialValue: photo.caption ?? "")
        _takenYearText = State(initialValue: photo.takenYear.map(String.init) ?? "")
        _takenMonthText = State(initialValue: photo.takenMonth.map(String.init) ?? "")
        _takenPlace = State(initialValue: photo.takenPlace ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Caption") {
                    TextField("e.g. Wedding day, 1978", text: $caption)
                }
                Section("Date taken") {
                    HStack {
                        TextField("Year", text: $takenYearText)
                            .keyboardType(.numberPad)
                        Divider()
                        TextField("Month (1–12)", text: $takenMonthText)
                            .keyboardType(.numberPad)
                    }
                }
                Section("Place") {
                    TextField("e.g. Pune, India", text: $takenPlace)
                }
            }
            .navigationTitle("Edit photo details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private func save() {
        PhotoActionsViewModel(photoSync: photoSync).updateMetadata(
            photo,
            caption: caption,
            yearText: takenYearText,
            monthText: takenMonthText,
            place: takenPlace,
            in: context
        )
        dismiss()
    }
}
