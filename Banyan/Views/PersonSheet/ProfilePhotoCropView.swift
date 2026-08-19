// ProfilePhotoCropView.swift
// Pan/zoom editor for a person's avatar framing. The full photo in the gallery is
// never changed — this only writes cropScale/cropOffsetX/cropOffsetY on the photo,
// which every avatar site reads via AvatarCrop. Reached from PhotoDetailView's
// "Adjust" (profile photo only). Off the coverage gate; the framing math it drives
// lives in the unit-tested Utilities/AvatarCrop.

import SwiftUI

struct ProfilePhotoCropView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.photoSyncService) private var photoSync

    let photo: PersonPhoto

    @State private var image: UIImage?
    /// The saved-so-far framing; live gestures compose on top of it.
    @State private var committed: AvatarCrop
    /// In-progress pinch factor (1 when idle) and drag translation (points).
    @State private var magnify: CGFloat = 1
    @State private var drag: CGSize = .zero

    init(photo: PersonPhoto) {
        self.photo = photo
        _committed = State(initialValue: AvatarCrop(from: photo))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let image {
                    GeometryReader { geo in
                        // Floor at 1 so a constrained size (e.g. an iPad split view)
                        // can't produce a negative frame width.
                        let diameter = max(1, min(geo.size.width, geo.size.height) - 64)
                        cropStage(image: image, diameter: diameter)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                } else {
                    ProgressView().tint(.white)
                }

                VStack {
                    Spacer()
                    Text("Drag to move · Pinch to zoom")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.bottom, 24)
                }
            }
            .navigationTitle("Adjust photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .foregroundStyle(.white)
                        .disabled(image == nil)
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

    /// The dimmed full-frame preview with a bright circular window, both driven by
    /// the same live crop so what's inside the circle is exactly what will render.
    @ViewBuilder
    private func cropStage(image: UIImage, diameter: CGFloat) -> some View {
        let crop = liveCrop(diameter: diameter)
        ZStack {
            // Same transform as the bright circle (and the rendered avatar), just
            // unclipped and dimmed, so what's outside the circle stays visible.
            CroppedCircleImage(uiImage: image, crop: crop, diameter: diameter, clipped: false)
                .opacity(0.35)
            CroppedCircleImage(uiImage: image, crop: crop, diameter: diameter)
            Circle()
                .stroke(.white, lineWidth: 2)
                .frame(width: diameter, height: diameter)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            dragGesture(diameter: diameter)
                .simultaneously(with: magnifyGesture(diameter: diameter))
        )
    }

    // MARK: - Gestures

    /// The loaded photo's width / height, used to bound the pan to the scaledToFill
    /// overflow (so a portrait can be panned vertically at 1×). 1 until it loads.
    private var aspectRatio: Double {
        guard let image, image.size.height > 0 else { return 1 }
        return Double(image.size.width / image.size.height)
    }

    /// Committed framing plus the in-flight pinch + drag, clamped so the circle is
    /// always fully covered (offsets are diameter-fractions, matching AvatarCrop).
    private func liveCrop(diameter: CGFloat) -> AvatarCrop {
        AvatarCrop(
            scale: committed.scale * Double(magnify),
            offsetX: committed.offsetX + Double(drag.width / diameter),
            offsetY: committed.offsetY + Double(drag.height / diameter)
        ).clamped(aspectRatio: aspectRatio)
    }

    private func dragGesture(diameter: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { drag = $0.translation }
            .onEnded { value in
                // Fold only the drag's contribution, so an in-flight pinch (if any)
                // isn't double-applied when the two gestures end at different times.
                committed = AvatarCrop(
                    scale: committed.scale,
                    offsetX: committed.offsetX + Double(value.translation.width / diameter),
                    offsetY: committed.offsetY + Double(value.translation.height / diameter)
                ).clamped(aspectRatio: aspectRatio)
                drag = .zero
            }
    }

    private func magnifyGesture(diameter: CGFloat) -> some Gesture {
        MagnifyGesture()
            .onChanged { magnify = $0.magnification }
            .onEnded { value in
                committed = AvatarCrop(
                    scale: committed.scale * Double(value.magnification),
                    offsetX: committed.offsetX,
                    offsetY: committed.offsetY
                ).clamped(aspectRatio: aspectRatio)
                magnify = 1
            }
    }

    private func save() {
        PhotoActionsViewModel(photoSync: photoSync)
            .setCrop(committed, aspectRatio: aspectRatio, on: photo, in: context)
        dismiss()
    }
}
