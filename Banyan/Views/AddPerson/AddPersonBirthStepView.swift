// AddPersonBirthStepView.swift
// Add-person flow: birth date. The year is the primary field and enough on its
// own (genealogy often knows only a year); month and day are optional, and a day
// is only entered once a month is chosen. "I don't know" skips the whole thing.

import SwiftUI

struct AddPersonBirthStepView: View {
    @Bindable var vm: AddPersonViewModel
    let onContinue: () -> Void

    /// Full month names, fixed (display must not shift with the runtime locale).
    private static let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("When were they born?")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("The year is enough — add a month and day only if you know them.")
                .font(.title3)
                .foregroundStyle(.secondary)

            TextField("Year, e.g. 1945", text: $vm.birthYearText)
                .font(.title2)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                Picker("Month", selection: $vm.birthMonth) {
                    Text("Month").tag(Int?.none)
                    ForEach(1...12, id: \.self) { month in
                        Text(Self.monthNames[month - 1]).tag(Int?.some(month))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)

                // A day is only meaningful alongside a month.
                TextField("Day", text: $vm.birthDayText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .disabled(vm.birthMonth == nil)
                    .opacity(vm.birthMonth == nil ? 0.4 : 1)
            }
            .font(.title3)

            Button("I don't know") {
                vm.birthYearText = ""
                vm.birthMonth = nil
                vm.birthDayText = ""
                onContinue()
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(minWidth: 44, minHeight: 44)

            Spacer()

            Button {
                onContinue()
            } label: {
                Text("Continue")
                    .font(.title3)
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}
