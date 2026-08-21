// ProfilePhotoCropView.swift
// Re-framing editor for a person's EXISTING profile photo: loads the saved image
// off disk, then hands it to the reusable AvatarFramingView and writes the chosen
// crop back via PhotoActionsViewModel.setCrop. The full photo in the gallery is
// never changed — only cropScale/cropOffsetX/cropOffsetY, which every avatar site
// reads via AvatarCrop. Reached from PhotoDetailView's "Adjust framing" and the
// person-sheet avatar's "Adjust Framing". Off the coverage gate.

import SwiftUI

struct ProfilePhotoCropView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.photoSyncService) private var photoSync

    let photo: PersonPhoto

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                AvatarFramingView(image: image, initialCrop: AvatarCrop(from: photo)) { crop, aspectRatio in
                    PhotoActionsViewModel(photoSync: photoSync)
                        .setCrop(crop, aspectRatio: aspectRatio, on: photo, in: context)
                }
            } else {
                // Brief disk load — keep a black backdrop and a way out while it runs.
                NavigationStack {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        ProgressView().tint(.white)
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { dismiss() }
                                .foregroundStyle(.white)
                        }
                    }
                }
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
