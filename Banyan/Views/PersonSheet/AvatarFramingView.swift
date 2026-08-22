// AvatarFramingView.swift
// The reusable "Move & Scale" avatar editor: pan/zoom a loaded image inside a
// circle and hand back the chosen AvatarCrop. Persistence is the caller's job — a
// new profile photo saves the crop alongside the photo; re-framing an existing one
// writes it via PhotoActionsViewModel.setCrop. Off the coverage gate; the framing
// math it drives lives in the unit-tested Utilities/AvatarCrop.

import SwiftUI

struct AvatarFramingView: View {
    @Environment(\.dismiss) private var dismiss

    let image: UIImage
    /// The confirm button's title — "Use Photo" when framing a freshly picked photo,
    /// "Save" when re-framing one that already exists.
    let confirmLabel: String
    /// Called with the chosen crop + the image's aspect ratio (width / height) when
    /// the user confirms. The caller persists it; this view only produces the value.
    let onUse: (AvatarCrop, Double) -> Void

    /// The saved-so-far framing; live gestures compose on top of it.
    @State private var committed: AvatarCrop
    /// In-progress pinch factor (1 when idle) and drag translation (points).
    @State private var magnify: CGFloat = 1
    @State private var drag: CGSize = .zero

    init(
        image: UIImage,
        initialCrop: AvatarCrop = .identity,
        confirmLabel: String = "Save",
        onUse: @escaping (AvatarCrop, Double) -> Void
    ) {
        self.image = image
        self.confirmLabel = confirmLabel
        self.onUse = onUse
        _committed = State(initialValue: initialCrop)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                GeometryReader { geo in
                    // Floor at 1 so a constrained size (e.g. an iPad split view)
                    // can't produce a negative frame width.
                    let diameter = max(1, min(geo.size.width, geo.size.height) - 64)
                    cropStage(diameter: diameter)
                        .frame(width: geo.size.width, height: geo.size.height)
                }

                VStack {
                    Spacer()
                    Text("Drag to move · Pinch to zoom")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.bottom, 24)
                }
            }
            .navigationTitle("Move & Scale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmLabel) {
                        onUse(committed.clamped(aspectRatio: aspectRatio), aspectRatio)
                        dismiss()
                    }
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    /// The dimmed full-frame preview with a bright circular window, both driven by
    /// the same live crop so what's inside the circle is exactly what will render.
    @ViewBuilder
    private func cropStage(diameter: CGFloat) -> some View {
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
    /// overflow (so a portrait can be panned vertically at 1×).
    private var aspectRatio: Double {
        guard image.size.height > 0 else { return 1 }
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
}
