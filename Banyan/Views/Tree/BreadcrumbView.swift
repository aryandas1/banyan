// BreadcrumbView.swift
// The navigation trail above the tree — the people walked through to reach the focus.

import SwiftUI

struct BreadcrumbView: View {
    let stack: [UUID]
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

                        if index < stack.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func name(for personId: UUID) -> String {
        allPeople.first { $0.id == personId }?.firstName ?? "Unknown"
    }
}

#Preview {
    BreadcrumbView(stack: [], allPeople: []) { _ in }
}
