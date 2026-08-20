// PlaceholderNodeView.swift
// A tappable slot marking a missing person — "Add parent", "Add partner",
// "Add child". A dashed avatar circle with a soft pulse (stilled when the
// user has Reduce Motion on — this app is for older users).

import SwiftUI

struct PlaceholderNodeView: View {
    let label: String
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(BanyanTheme.Color.primaryTint)
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .foregroundStyle(BanyanTheme.Color.primary)
                        .shadow(
                            color: BanyanTheme.Color.primary.opacity(pulsing ? 0 : 0.25),
                            radius: pulsing ? 8 : 0
                        )
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundStyle(BanyanTheme.Color.primary)
                }
                .frame(width: NodeMetrics.avatarSize, height: NodeMetrics.avatarSize)

                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(BanyanTheme.Color.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal, 4)
            .frame(width: NodeMetrics.width, height: NodeMetrics.height)
        }
        .buttonStyle(DimOnPressButtonStyle())
        .accessibilityLabel(label)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }
}

#Preview {
    PlaceholderNodeView(label: "Add parent") {}
}
