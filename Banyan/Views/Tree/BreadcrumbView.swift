// BreadcrumbView.swift
// The navigation trail above the tree — the people walked through to reach the focus.

import SwiftUI

struct BreadcrumbView: View {
    let stack: [UUID]
    /// The person currently centered in the tree — shown as the trail's final,
    /// non-tappable segment so the strip also answers "where am I now."
    let current: UUID
    let allPeople: [Person]
    let onSelect: (UUID) -> Void

    var body: some View {
        if !stack.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(stack.enumerated()), id: \.offset) { index, personId in
                        Button {
                            onSelect(personId)
                        } label: {
                            Text(name(for: personId))
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .frame(minWidth: 44, minHeight: 44)

                        chevron
                    }

                    Text(name(for: current))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .frame(minHeight: 44)
                }
                .padding(.horizontal)
            }
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }

    private func name(for personId: UUID) -> String {
        allPeople.first { $0.id == personId }?.firstName ?? "Unknown"
    }
}

#Preview {
    BreadcrumbView(stack: [], current: UUID(), allPeople: []) { _ in }
}
