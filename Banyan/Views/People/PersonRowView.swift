// PersonRowView.swift
// One row in the People list: circular avatar, name, relationship label, and a chevron.
// The whole row is a plain Button so it reads and taps as a single control.

import SwiftUI
import UIKit

struct PersonRowView: View {
    let person: Person
    let relationshipLabel: String
    let onTap: () -> Void

    @State private var photo: UIImage?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                avatar

                VStack(alignment: .leading, spacing: 2) {
                    Text(person.fullName)
                        .font(.body)
                        .fontWeight(.medium)
                    Text(relationshipLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .task(id: person.profilePhotoFilename) { await loadPhoto() }
    }

    private var avatar: some View {
        Group {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(.systemGray5)
                    .overlay(
                        Text(person.initials)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }

    /// Loads the stored profile photo off the main thread; keeps the initials placeholder
    /// when the person has no photo.
    private func loadPhoto() async {
        guard let filename = person.profilePhotoFilename else {
            photo = nil
            return
        }
        let loaded = await Task.detached { PhotoStorageService.load(filename: filename) }.value
        // The row may have been recycled or its filename changed while loading; don't paint a
        // stale image over whatever the current .task is now loading.
        guard !Task.isCancelled else { return }
        photo = loaded
    }
}
