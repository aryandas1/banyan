// MonthDayWheels.swift
// A pair of wheel pickers for an optional month + day, sharing one look between the
// add-person birth and death steps. `month`/`day` use 0 for "not set"; the day wheel
// is disabled until a month is chosen (a day alone is meaningless). Purely
// presentational — the parent owns the state and any VM syncing.

import SwiftUI

struct MonthDayWheels: View {
    @Binding var month: Int   // 0 = none, 1–12
    @Binding var day: Int     // 0 = none, 1–31

    /// Full month names, fixed (display must not shift with the runtime locale).
    private static let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    var body: some View {
        HStack(spacing: 0) {
            wheel(title: "Month", selection: $month) {
                Text("—").tag(0)
                ForEach(1...12, id: \.self) { m in
                    Text(Self.monthNames[m - 1]).tag(m)
                }
            }

            Divider().frame(height: 140)

            wheel(title: "Day", selection: $day, disabled: month == 0) {
                Text("—").tag(0)
                ForEach(1...31, id: \.self) { d in
                    Text("\(d)").tag(d)
                }
            }
        }
        .background(BanyanTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(BanyanTheme.Color.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func wheel<Content: View>(
        title: String,
        selection: Binding<Int>,
        disabled: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker(title, selection: selection, content: content)
                .pickerStyle(.wheel)
                .frame(height: 140)
                .clipped()
                .disabled(disabled)
                .opacity(disabled ? 0.35 : 1)
        }
        .frame(maxWidth: .infinity)
    }
}
