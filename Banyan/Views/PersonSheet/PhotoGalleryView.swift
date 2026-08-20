// PhotoGalleryView.swift
// A horizontally scrolling strip of photo thumbnails for the person sheet. The
// trailing "Add photo" tile appears only for editors (canAdd). Each thumbnail is
// a Button so it reads as a single control (CLAUDE.md — no bare tap gestures).

import SwiftUI
import UIKit

struct PhotoGalleryView: View {

    let photos: [PersonPhoto]          // pre-sorted by sortOrder
    let canAdd: Bool
    let onAddPhoto: () -> Void
    let onSelectPhoto: (PersonPhoto) -> Void

    private let thumbSize: CGFloat = 88

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 10) {
                ForEach(photos, id: \.id) { photo in
                    Button {
                        onSelectPhoto(photo)
                    } label: {
                        PhotoThumbView(photo: photo, size: thumbSize)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(photo.caption ?? "Photo")
                }

                if canAdd {
                    Button(action: onAddPhoto) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(BanyanTheme.Color.primaryTint)
                                .frame(width: thumbSize, height: thumbSize)
                            VStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.title2)
                                    .foregroundStyle(BanyanTheme.Color.primary)
                                Text("Add photo")
                                    .font(.caption2)
                                    .foregroundStyle(BanyanTheme.Color.primary)
                            }
                        }
                    }
                    .frame(width: thumbSize, height: thumbSize)
                    .accessibilityLabel("Add photo")
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: thumbSize + 4)
    }
}

/// One gallery thumbnail. Loads its image off the main thread and overlays a
/// marker when it's the profile photo.
struct PhotoThumbView: View {
    let photo: PersonPhoto
    let size: CGFloat

    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    BanyanTheme.Color.border
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if photo.isProfilePhoto {
                Image(systemName: "person.crop.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .shadow(radius: 1)
                    .padding(4)
                    .accessibilityHidden(true)
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
