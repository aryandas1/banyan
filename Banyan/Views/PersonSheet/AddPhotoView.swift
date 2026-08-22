// AddPhotoView.swift
// The add-photo sheet: pick an image, optionally add caption / date / place, and
// save. Uses PhotosUI.PhotosPicker (no direct Photos import, so no full-library
// permission prompt). All writes go through AddPhotoViewModel.

import SwiftUI
import PhotosUI

struct AddPhotoView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.photoSyncService) private var photoSync

    let person: Person
    let preselectAsProfilePhoto: Bool

    @State private var vm: AddPhotoViewModel
    @State private var pickerItem: PhotosPickerItem?
    @ScaledMetric(relativeTo: .largeTitle) private var placeholderIconSize: CGFloat = 44

    init(person: Person, preselectAsProfilePhoto: Bool = false) {
        self.person = person
        self.preselectAsProfilePhoto = preselectAsProfilePhoto
        _vm = State(initialValue: AddPhotoViewModel(setAsProfilePhoto: preselectAsProfilePhoto))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Read the MainActor VM state here in `body` (which is isolated)
                    // and hand it down, so the picker's label closure doesn't reach
                    // across actors.
                    photoPreview(selectedImage: vm.selectedImage)
                    if vm.selectedImage != nil {
                        metadataForm
                    }
                }
                .padding(16)
            }
            .navigationTitle("Add photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(vm.selectedImage == nil || vm.isSaving)
                }
            }
            .alert("Couldn't save photo", isPresented: saveErrorPresented) {
                Button("OK") { vm.saveError = nil }
            } message: {
                Text(vm.saveError?.localizedDescription ?? "")
            }
        }
    }

    private func save() {
        Task {
            do {
                try await vm.save(for: person, in: context, photoSync: photoSync)
                dismiss()
            } catch {
                vm.saveError = error
            }
        }
    }

    private var saveErrorPresented: Binding<Bool> {
        Binding(
            get: { vm.saveError != nil },
            set: { if !$0 { vm.saveError = nil } }
        )
    }

    // MARK: - Photo picker / preview

    @ViewBuilder
    private func photoPreview(selectedImage: UIImage?) -> some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(BanyanTheme.Color.primaryTint)
                        .frame(height: 200)
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: placeholderIconSize))
                            .foregroundStyle(BanyanTheme.Color.primary)
                        Text("Tap to choose a photo")
                            .font(.body)
                            .foregroundStyle(BanyanTheme.Color.primary)
                    }
                }
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            Task {
                guard let newItem,
                      let data = try? await newItem.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                vm.onImageSelected(image: image, data: data)
            }
        }
    }

    // MARK: - Metadata form

    @ViewBuilder
    private var metadataForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            field(title: "Caption") {
                TextField("e.g. Wedding day, 1978", text: $vm.caption)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
            }

            HStack(spacing: 12) {
                field(title: "Year taken") {
                    TextField("e.g. 1967", text: $vm.takenYearText)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .font(.body)
                }
                field(title: "Month (1–12)") {
                    TextField("Optional", text: $vm.takenMonthText)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .font(.body)
                }
            }

            field(title: "Place") {
                TextField("e.g. Pune, India", text: $vm.takenPlace)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
            }

            // Hidden when the sheet was opened specifically to set a profile photo.
            if !preselectAsProfilePhoto {
                Toggle("Use as profile photo", isOn: $vm.setAsProfilePhoto)
                    .font(.body)
            }
        }
        .padding(16)
        .background(BanyanTheme.Color.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(BanyanTheme.Color.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func field<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            content()
        }
    }
}
