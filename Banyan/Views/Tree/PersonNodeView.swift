// PersonNodeView.swift
// A tappable card for one person in the tree canvas: avatar circle (photo or
// deterministic-color initials), first name, birth year.

import SwiftUI

/// Fixed node dimensions shared by every tree node — the connector layer
/// computes edge positions from these, so they must never vary per node.
enum NodeMetrics {
    static let width: CGFloat = 88
    // Headroom for a name wrapping to two lines (finding #9) — long names and
    // larger Dynamic Type sizes wrap instead of truncating mid-name. The connector
    // layer reads this same constant, so taller nodes still meet their edges.
    static let height: CGFloat = 128
    static let cornerRadius: CGFloat = BanyanTheme.Radius.node
    /// Diameter of the avatar circle inside every node.
    static let avatarSize: CGFloat = 62
}

struct PersonNodeView: View {
    let person: Person
    let isFocal: Bool
    let onTap: () -> Void

    @State private var photo: UIImage?

    private var avatarColor: Color {
        BanyanTheme.avatarColor(for: person.id)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                avatarCircle

                Text(person.firstName)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
                    .truncationMode(.tail)
                    .foregroundStyle(isFocal ? BanyanTheme.Color.primary : BanyanTheme.Color.textPrimary)

                if let year = person.birthDate?.year {
                    Text(String(year))
                        .font(.caption2)
                        // On the focal node's tinted fill, tertiary is too faint —
                        // step up to secondary so the year stays legible.
                        .foregroundStyle(isFocal ? BanyanTheme.Color.textSecondary : BanyanTheme.Color.textTertiary)
                }
            }
            .padding(.horizontal, 4)
            .frame(width: NodeMetrics.width, height: NodeMetrics.height)
            .background(
                RoundedRectangle(cornerRadius: NodeMetrics.cornerRadius)
                    .fill(isFocal ? BanyanTheme.Color.primaryTint : BanyanTheme.Color.surface)
                    .shadow(
                        color: isFocal ? .clear : BanyanTheme.Color.textPrimary.opacity(0.06),
                        radius: 4,
                        y: 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: NodeMetrics.cornerRadius)
                    .stroke(
                        isFocal ? BanyanTheme.Color.primary : BanyanTheme.Color.border,
                        lineWidth: isFocal ? 2 : 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(person.fullName)
        .accessibilityAddTraits(.isButton)
        .task(id: person.profilePhoto?.filename) { await loadPhoto() }
    }

    private var avatarCircle: some View {
        Circle()
            .fill(avatarColor)
            .frame(width: NodeMetrics.avatarSize, height: NodeMetrics.avatarSize)
            .overlay {
                if let photo {
                    CroppedCircleImage(
                        uiImage: photo,
                        crop: AvatarCrop(from: person.profilePhoto),
                        diameter: NodeMetrics.avatarSize
                    )
                } else {
                    Text(person.initials)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
            }
    }

    /// Loads the stored profile photo off the main thread; keeps the initials
    /// avatar when there's none. Keyed by filename so a node reused as the tree
    /// re-centers cancels its in-flight load instead of painting a stale face.
    private func loadPhoto() async {
        let loaded = await ProfilePhotoLoader.load(for: person)
        guard !Task.isCancelled else { return }
        photo = loaded
    }
}
