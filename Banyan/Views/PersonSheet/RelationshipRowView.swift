// RelationshipRowView.swift
// One tappable relative in the person sheet's Family section. Tapping it
// navigates the tree to that relative.

import SwiftUI

struct RelationshipRowView: View {
    let person: Person
    let relationshipLabel: String   // "Parent", "Partner", "Child", "Sibling"
    let onTap: () -> Void

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
    }
}
