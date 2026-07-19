// PersonNodeView.swift
// A tappable card for one person in the tree canvas.

import SwiftUI

/// Fixed node dimensions shared by every tree node — the connector layer
/// computes edge positions from these, so they must never vary per node.
enum NodeMetrics {
    static let width: CGFloat = 80
    static let height: CGFloat = 88
    static let cornerRadius: CGFloat = 12
}

struct PersonNodeView: View {
    let person: Person
    let isFocal: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                initialsCircle

                Text(person.firstName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(isFocal ? Color(.systemBackground) : Color.primary)

                if let year = person.birthDate?.year {
                    Text(String(year))
                        .font(.caption2)
                        .foregroundStyle(isFocal ? Color(.systemBackground).opacity(0.7) : Color(.secondaryLabel))
                }
            }
            .padding(.horizontal, 4)
            .frame(width: NodeMetrics.width, height: NodeMetrics.height)
            .background(
                RoundedRectangle(cornerRadius: NodeMetrics.cornerRadius)
                    .fill(isFocal ? Color.primary : Color(.systemBackground))
                    .shadow(
                        color: isFocal ? .clear : .black.opacity(0.06),
                        radius: 4,
                        y: 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: NodeMetrics.cornerRadius)
                    .stroke(isFocal ? Color.clear : Color(.systemGray4), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(person.fullName)
        .accessibilityAddTraits(.isButton)
    }

    private var initialsCircle: some View {
        Circle()
            .fill(isFocal ? Color(.systemBackground).opacity(0.2) : Color(.systemGray6))
            .frame(width: 36, height: 36)
            .overlay(
                Text(person.initials)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(isFocal ? Color(.systemBackground) : Color.primary)
            )
    }
}
