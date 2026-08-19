// CroppedCircleImage.swift
// The one place the avatar framing (AvatarCrop) is turned into pixels: a photo
// scaled to fill a circle of `diameter`, then zoomed + panned per the crop, then
// clipped. Used at every avatar site (tree node, People row, person-sheet header)
// and inside the crop editor so the live preview matches the final render exactly.

import SwiftUI

/// Renders `uiImage` framed by `crop` inside a circle of `diameter` points.
/// `clipped: false` skips the circle clip so the crop editor can reuse the exact
/// same transform for its dimmed full-frame preview layer.
struct CroppedCircleImage: View {
    let uiImage: UIImage
    let crop: AvatarCrop
    let diameter: CGFloat
    var clipped: Bool = true

    var body: some View {
        let framed = Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .scaleEffect(crop.scale)
            // Offsets are fractions of the diameter (see AvatarCrop), so a stored
            // crop frames identically at any avatar size.
            .offset(x: crop.offsetX * diameter, y: crop.offsetY * diameter)
            .frame(width: diameter, height: diameter)
        if clipped {
            framed.clipShape(Circle())
        } else {
            framed
        }
    }
}
