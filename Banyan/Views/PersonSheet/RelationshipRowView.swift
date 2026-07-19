// RelationshipRowView.swift
// One tappable relative in the person sheet's Family section. Tapping it
// navigates the tree to that relative. When `onDelete` is set, the row offers
// a trailing swipe action to unlink — this only functions inside a List.

import SwiftUI

struct RelationshipRowView: View {
    let person: Person
    let relationshipLabel: String   // "Parent", "Partner", "Child", "Sibling"
    // `onDelete` sits after `onTap` so existing trailing-closure call sites
    // keep binding their closure to `onTap`.
    let onTap: () -> Void
    var onDelete: (() -> Void)? = nil

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(person.initials)
                            .font(.callout)
                            .fontWeight(.semibold)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(person.fullName)
                        .font(.body)
                        .fontWeight(.medium)
                    Text(relationshipLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .swipeActions(edge: .trailing) {
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Unlink", systemImage: "person.fill.xmark")
                }
            }
        }
    }
}
