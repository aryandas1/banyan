// AvatarCrop.swift
// Pure value type describing how a person's profile photo is framed inside the
// round avatar. The gallery keeps the full photo untouched; only the circle is
// cropped (development-plan §0.9). No SwiftUI/SwiftData import so it stays on the
// coverage gate and is fully unit-testable (mirrors ViewerRootPicker/TreeSwitcher).
//
// The render model (see CroppedCircleImage): the photo is `scaledToFill`ed into
// the circle, then `scaleEffect(scale)` and `offset(offsetX*d, offsetY*d)` where
// `d` is the circle diameter. So `scale` is a zoom ≥ 1 and each offset is a pan
// expressed as a fraction of the diameter. `1 / 0 / 0` = no crop (image fills it).

import Foundation

/// The avatar framing for a photo: zoom + pan, both relative to the circle.
struct AvatarCrop: Equatable {
    /// Zoom applied on top of `scaledToFill`. Floored at 1 (never zoom out past
    /// filling the circle, which would expose the background).
    var scale: Double
    /// Horizontal pan as a fraction of the circle's diameter (+right).
    var offsetX: Double
    /// Vertical pan as a fraction of the circle's diameter (+down).
    var offsetY: Double

    init(scale: Double = 1, offsetX: Double = 0, offsetY: Double = 0) {
        self.scale = scale
        self.offsetX = offsetX
        self.offsetY = offsetY
    }

    /// No crop: the photo fills the circle, centered.
    static let identity = AvatarCrop(scale: 1, offsetX: 0, offsetY: 0)

    /// Hard ceiling on zoom, so a hard pinch can't upscale a tiny region of the
    /// photo into a blurry avatar.
    static let maxScale: Double = 5

    /// The furthest (in diameter-fractions) the image can pan along one axis while
    /// still fully covering the circle. `fill` is that axis's fill ratio (clamped
    /// to ≥ 1): 1 means the scaled photo exactly meets the circle on that axis, > 1
    /// means it overflows (scaledToFill on a non-square photo) so there's slack to
    /// pan even at `scale == 1`.
    static func maxOffset(fill: Double, scale: Double) -> Double {
        max(0, (max(1, fill) * scale - 1) / 2)
    }

    /// Clamps to a valid framing for a photo of `aspectRatio` (width / height):
    /// scale held in `1...maxScale`, and each offset bounded so the circle stays
    /// fully covered — accounting for the scaledToFill overflow on each axis, so a
    /// portrait can pan vertically (and a landscape horizontally) to reframe even
    /// at 1×. `aspectRatio` defaults to 1 (a square: the pre-overflow behavior).
    func clamped(aspectRatio: Double = 1) -> AvatarCrop {
        let s = min(AvatarCrop.maxScale, max(1, scale))
        let ar = aspectRatio > 0 ? aspectRatio : 1
        // Landscape (ar > 1) overflows horizontally; portrait (ar < 1) vertically.
        let boundX = AvatarCrop.maxOffset(fill: ar, scale: s)
        let boundY = AvatarCrop.maxOffset(fill: 1 / ar, scale: s)
        return AvatarCrop(
            scale: s,
            offsetX: min(boundX, max(-boundX, offsetX)),
            offsetY: min(boundY, max(-boundY, offsetY))
        )
    }

    /// Reads the framing stored on a photo, or `.identity` when there's no photo.
    init(from photo: PersonPhoto?) {
        guard let photo else { self = .identity; return }
        self.init(scale: photo.cropScale, offsetX: photo.cropOffsetX, offsetY: photo.cropOffsetY)
    }
}
