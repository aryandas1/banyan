// AddPersonStatusStepView.swift
// Step 3 of the add-person flow: living or deceased, via two large option cards.
// Selecting deceased reveals the death-year field.

import SwiftUI

struct AddPersonStatusStepView: View {
    @Bindable var vm: AddPersonViewModel
    let onContinue: () -> Void

    // 0 = not selected; 1–12 = month; 1–31 = day. Local state synced to the VM via
    // .onChange, so the VM's interface (deathMonth: Int?, deathDayText: String) is
    // unchanged — mirrors the birth step.
    @State private var selectedDeathMonth: Int = 0
    @State private var selectedDeathDay: Int = 0
    @FocusState private var deathYearFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Are they still with us?")
                .font(.largeTitle)
                .fontWeight(.bold)

            optionCard(title: "Yes, they are living", isSelected: !vm.isDeceased) {
                vm.isDeceased = false
            }

            optionCard(title: "No, they have passed away", isSelected: vm.isDeceased) {
                vm.isDeceased = true
            }

            if vm.isDeceased {
                TextField("Year they passed, e.g. 1998", text: $vm.deathYearText)
                    .font(.title2)
                    .keyboardType(.numberPad)
                    .focused($deathYearFocused)
                    .banyanTextInput(focused: deathYearFocused)

                // Exact month/day, optional — but they matter for shraddha.
                MonthDayWheels(month: $selectedDeathMonth, day: $selectedDeathDay)
            }

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
        // Hold the layout steady when the numberPad appears; the year field stays
        // visible, and Done dismisses the pad to reveal the wheels + Continue.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { deathYearFocused = false }
            }
        }
        .onAppear {
            // Restore the pickers if the user navigated back to this step.
            selectedDeathMonth = vm.deathMonth ?? 0
            selectedDeathDay = Int(vm.deathDayText) ?? 0
        }
        .onChange(of: selectedDeathMonth) { _, newMonth in
            deathYearFocused = false
            vm.deathMonth = newMonth == 0 ? nil : newMonth
            // Clearing the month clears the day too — a day alone is meaningless.
            if newMonth == 0 {
                selectedDeathDay = 0
                vm.deathDayText = ""
            }
        }
        .onChange(of: selectedDeathDay) { _, newDay in
            vm.deathDayText = newDay == 0 ? "" : "\(newDay)"
        }
    }

    /// One full-width selectable card with a trailing checkmark when selected.
    private func optionCard(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.title3)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                }
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? BanyanTheme.Color.primaryTint : BanyanTheme.Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? BanyanTheme.Color.primary : BanyanTheme.Color.border, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
