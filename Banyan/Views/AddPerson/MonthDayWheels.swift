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

            // The day range follows the chosen month, so an impossible date (31 Feb,
            // 31 Apr) can't be picked. The year is unknown here, so February allows 29.
            wheel(title: "Day", selection: $day, disabled: month == 0) {
                Text("—").tag(0)
                ForEach(1...maxDay, id: \.self) { d in
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
        // Switching to a shorter month drops a now-invalid day (e.g. 31 → clears when
        // the month becomes April), so the picker never holds a value outside its range.
        .onChange(of: month) { _, _ in
            if day > maxDay { day = 0 }
        }
    }

    /// The highest valid day for the chosen month (31 when no month is set, since the
    /// day wheel is disabled then). February allows 29 — the year, and so leapness, is
    /// unknown at this step.
    private var maxDay: Int {
        switch month {
        case 2: return 29
        case 4, 6, 9, 11: return 30
        default: return 31
        }
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
