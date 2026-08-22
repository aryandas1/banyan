// AddPersonMarriageStepView.swift
// Add-partner flow only: the (optional) marriage / anniversary date. Same shape as
// the birth step — a year text field plus optional month/day wheels — because an
// anniversary is often remembered as a day and month with a hazy year. "We're not
// married" skips it entirely (the partnership still stands, just without a date).

import SwiftUI

struct AddPersonMarriageStepView: View {
    @Bindable var vm: AddPersonViewModel
    let onContinue: () -> Void

    // 0 = not selected; 1–12 = month; 1–31 = day. Local state kept in sync with the
    // ViewModel via .onChange, matching the birth/death steps.
    @State private var selectedMonth: Int = 0
    @State private var selectedDay: Int = 0
    /// The numberPad year field has no return key; a keyboard-toolbar "Done" drives this.
    @FocusState private var yearFieldFocused: Bool

    /// The partner being added, for the heading — the anniversary is theirs and the anchor's.
    private var partnerName: String {
        let name = vm.firstName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "they" : name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("When did they marry?")
                .font(.largeTitle)
                .fontWeight(.bold)

            TextField("Year, e.g. 1972", text: $vm.marriageYearText)
                .font(.title2)
                .keyboardType(.numberPad)
                .focused($yearFieldFocused)
                .banyanTextInput(focused: yearFieldFocused)

            MonthDayWheels(month: $selectedMonth, day: $selectedDay)

            Button {
                // Explicitly not married: record a partnership (no anniversary),
                // clearing any date the user had started entering.
                vm.marriageYearText = ""
                vm.marriageMonth = nil
                vm.marriageDayText = ""
                selectedMonth = 0
                selectedDay = 0
                vm.isUnmarriedPartner = true
                onContinue()
            } label: {
                Text("They're partners, not married")
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
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(BanyanTheme.Color.background.ignoresSafeArea())
        // Keep the big Continue always visible above the keyboard — older users
        // shouldn't have to discover "Done" to find the way forward. Done stays in the
        // accessory bar to dismiss the pad and reach the (optional) month/day wheels.
        .keyboardAwareBottomBar {
            Button {
                // Proceeding as a married couple (a date makes it an anniversary; no
                // date leaves it an assumed spouse). Clear any earlier "partners" pick.
                vm.isUnmarriedPartner = false
                onContinue()
            } label: {
                Text("Continue")
            }
            .buttonStyle(PrimaryFilledButtonStyle())
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(BanyanTheme.Color.background)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { yearFieldFocused = false }
            }
        }
        .onAppear {
            // Restore the pickers if the user navigated back to this step.
            selectedMonth = vm.marriageMonth ?? 0
            selectedDay = Int(vm.marriageDayText) ?? 0
        }
        .onChange(of: selectedMonth) { _, newMonth in
            // Reaching for a picker means they're done typing the year — drop the keyboard.
            yearFieldFocused = false
            vm.marriageMonth = newMonth == 0 ? nil : newMonth
            // Clearing the month clears the day too — a day alone is meaningless.
            if newMonth == 0 {
                selectedDay = 0
                vm.marriageDayText = ""
            }
        }
        .onChange(of: selectedDay) { _, newDay in
            vm.marriageDayText = newDay == 0 ? "" : "\(newDay)"
        }
    }
}
