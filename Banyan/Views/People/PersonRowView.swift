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
                        .foregroundStyle(BanyanTheme.Color.textPrimary)
                    Text(relationshipLabel)
                        .font(.caption)
                        .foregroundStyle(BanyanTheme.Color.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(BanyanTheme.Color.textTertiary)
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .task(id: person.profilePhoto?.filename) { await loadPhoto() }
    }

    private var avatar: some View {
        Group {
            if let photo {
                CroppedCircleImage(
                    uiImage: photo,
                    crop: AvatarCrop(from: person.profilePhoto),
                    diameter: 44
                )
            } else {
                BanyanTheme.avatarColor(for: person.id)
                    .overlay(
                        Text(person.initials)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    )
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            }
        }
    }

    /// Loads the stored profile photo off the main thread; keeps the initials placeholder
    /// when the person has no photo. The row may have been recycled or its filename changed
    /// while loading, so don't paint a stale image over whatever the current .task now loads.
    private func loadPhoto() async {
        let loaded = await ProfilePhotoLoader.load(for: person)
        guard !Task.isCancelled else { return }
        photo = loaded
    }
}
