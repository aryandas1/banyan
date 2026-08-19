// AvatarCropTests.swift
// The pure avatar-framing math: identity, maxOffset slack, and clamping (scale
// floor + symmetric offset bounds), plus reading the framing off a PersonPhoto.

import Testing
import Foundation
@testable import Banyan

@Suite("AvatarCrop")
struct AvatarCropTests {

    @Test func identityIsNoCrop() {
        #expect(AvatarCrop.identity == AvatarCrop(scale: 1, offsetX: 0, offsetY: 0))
    }

    @Test func maxOffsetIsZeroForSquareAtFill() {
        // Square axis (fill 1) at scale 1 → no pan slack; below 1 clamps to 0.
        #expect(AvatarCrop.maxOffset(fill: 1, scale: 1) == 0)
        #expect(AvatarCrop.maxOffset(fill: 1, scale: 0.5) == 0)
    }

    @Test func maxOffsetGrowsHalfPerZoomUnit() {
        #expect(AvatarCrop.maxOffset(fill: 1, scale: 2) == 0.5)
        #expect(AvatarCrop.maxOffset(fill: 1, scale: 3) == 1.0)
    }

    @Test func maxOffsetHasSlackFromOverflowAtScaleOne() {
        // A 2× overflow axis (e.g. a portrait's height) can pan half a diameter
        // even without zooming — the pre-overflow formula wrongly returned 0 here.
        #expect(AvatarCrop.maxOffset(fill: 2, scale: 1) == 0.5)
    }

    @Test func clampFloorsScaleAtOne() {
        let c = AvatarCrop(scale: 0.3, offsetX: 0.4, offsetY: -0.4).clamped()
        #expect(c.scale == 1)
        // scale floored to 1 → no slack → offsets pinned to 0.
        #expect(c.offsetX == 0)
        #expect(c.offsetY == 0)
    }

    @Test func clampBoundsOffsetsSymmetrically() {
        // scale 2 → maxOffset 0.5. Over-pans in both directions clamp to ±0.5.
        let c = AvatarCrop(scale: 2, offsetX: 5, offsetY: -5).clamped()
        #expect(c.scale == 2)
        #expect(c.offsetX == 0.5)
        #expect(c.offsetY == -0.5)
    }

    @Test func clampLeavesInBoundsCropUntouched() {
        let inBounds = AvatarCrop(scale: 2, offsetX: 0.2, offsetY: -0.1)
        #expect(inBounds.clamped() == inBounds)
    }

    @Test func clampAllowsPortraitVerticalPanAtScaleOne() {
        // aspectRatio 0.5 = a tall portrait: it overflows vertically, so at scale 1
        // a vertical pan is allowed (bound 0.5) but a horizontal one isn't (bound 0).
        let c = AvatarCrop(scale: 1, offsetX: 0.3, offsetY: 0.3).clamped(aspectRatio: 0.5)
        #expect(c.offsetY == 0.3)   // within the vertical overflow slack
        #expect(c.offsetX == 0)     // no horizontal slack for a portrait
    }

    @Test func clampAllowsLandscapeHorizontalPanAtScaleOne() {
        // aspectRatio 2 = a wide landscape: horizontal pan allowed, vertical not.
        let c = AvatarCrop(scale: 1, offsetX: 0.3, offsetY: 0.3).clamped(aspectRatio: 2)
        #expect(c.offsetX == 0.3)
        #expect(c.offsetY == 0)
    }

    @Test func clampCapsScaleAtMax() {
        let c = AvatarCrop(scale: 100, offsetX: 0, offsetY: 0).clamped()
        #expect(c.scale == AvatarCrop.maxScale)
    }

    @Test func clampTreatsNonPositiveAspectAsSquare() {
        // A degenerate aspect (0) must not divide-by-zero into NaN offsets.
        let c = AvatarCrop(scale: 2, offsetX: 5, offsetY: 5).clamped(aspectRatio: 0)
        #expect(c.offsetX == 0.5)
        #expect(c.offsetY == 0.5)
    }

    @Test func initFromNilPhotoIsIdentity() {
        #expect(AvatarCrop(from: nil) == .identity)
    }

    @Test func initFromPhotoReadsStoredFields() {
        let photo = PersonPhoto(
            treeId: UUID(), personId: UUID(), filename: "x.jpg",
            cropScale: 2.5, cropOffsetX: 0.1, cropOffsetY: -0.2
        )
        #expect(AvatarCrop(from: photo) == AvatarCrop(scale: 2.5, offsetX: 0.1, offsetY: -0.2))
    }
}
