// PlaceholderNodeView.swift
// A faint tappable slot marking a missing person — "Add parent", "Add partner", "Add child".

import SwiftUI

struct PlaceholderNodeView: View {
    let label: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                Text(label)
                    .multilineTextAlignment(.center)
            }
            .font(.caption)
            .foregroundStyle(Color(.systemGray2))
            .frame(width: NodeMetrics.width, height: NodeMetrics.height)
            .background(
                RoundedRectangle(cornerRadius: NodeMetrics.cornerRadius)
                    .fill(Color(.systemGray6).opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: NodeMetrics.cornerRadius)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                    .foregroundStyle(Color(.systemGray4))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview {
    PlaceholderNodeView(label: "Add parent") {}
}
