// AddPersonBirthStepView.swift
// Add-person flow: birth date. Year is the primary field and enough on its own
// (genealogy often knows only a year); month and day are optional wheel pickers,
// and a day is only meaningful once a month is chosen. "I don't know" skips the
// whole thing; "Continue" carries whatever was entered forward.

import SwiftUI

struct AddPersonBirthStepView: View {
    @Bindable var vm: AddPersonViewModel
    let onContinue: () -> Void

    // 0 = not selected; 1–12 = month; 1–31 = day. Local state kept in sync with the
    // ViewModel via .onChange so the VM's interface (birthMonth: Int?, birthDayText:
    // String) is unchanged.
    @State private var selectedMonth: Int = 0
    @State private var selectedDay: Int = 0
    /// The numberPad year field has no return key to dismiss itself, so a keyboard
    /// toolbar "Done" drives this — otherwise the keyboard can sit over Continue.
    @FocusState private var yearFieldFocused: Bool

    /// Full month names, fixed (display must not shift with the runtime locale).
    private static let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("When were they born?")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Year — text field (a 4-digit number is faster to type than to scroll).
            TextField("Year, e.g. 1945", text: $vm.birthYearText)
                .font(.title2)
                .keyboardType(.numberPad)
                .focused($yearFieldFocused)
                .banyanTextInput(focused: yearFieldFocused)

            // Month + Day — wheel pickers (the standard iOS pattern for short lists).
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("Month")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Month", selection: $selectedMonth) {
                        Text("—").tag(0)
                        ForEach(1...12, id: \.self) { month in
                            Text(Self.monthNames[month - 1]).tag(month)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 140)
                    .clipped()
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 140)

                // A day is only meaningful once a month is chosen.
                VStack(spacing: 4) {
                    Text("Day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Day", selection: $selectedDay) {
                        Text("—").tag(0)
                        ForEach(1...31, id: \.self) { day in
                            Text("\(day)").tag(day)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 140)
                    .clipped()
                    .disabled(selectedMonth == 0)
                    .opacity(selectedMonth == 0 ? 0.35 : 1)
                }
                .frame(maxWidth: .infinity)
            }
            .background(BanyanTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(BanyanTheme.Color.border, lineWidth: 1)
            )

            Button {
                vm.birthYearText = ""
                vm.birthMonth = nil
                vm.birthDayText = ""
                selectedMonth = 0
                selectedDay = 0
                onContinue()
            } label: {
                Text("I don't know")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(BanyanTheme.Color.border, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                onContinue()
            } label: {
                Text("Continue")
            }
            .buttonStyle(PrimaryFilledButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(BanyanTheme.Color.background.ignoresSafeArea())
        .toolbar {
            // numberPad has no dismiss key; give one so the keyboard can't hide Continue.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { yearFieldFocused = false }
            }
        }
        .onAppear {
            // Restore the pickers if the user navigated back to this step.
            selectedMonth = vm.birthMonth ?? 0
            selectedDay = Int(vm.birthDayText) ?? 0
        }
        .onChange(of: selectedMonth) { _, newMonth in
            // Reaching for a picker means they're done typing the year — drop the keyboard.
            yearFieldFocused = false
            vm.birthMonth = newMonth == 0 ? nil : newMonth
            // Clearing the month clears the day too — a day alone is meaningless.
            if newMonth == 0 {
                selectedDay = 0
                vm.birthDayText = ""
            }
        }
        .onChange(of: selectedDay) { _, newDay in
            vm.birthDayText = newDay == 0 ? "" : "\(newDay)"
        }
    }
}
