// MarriageDateEditView.swift
// A small sheet to set or change a marriage's anniversary date after the fact,
// reached by tapping a marriage row on the person-sheet Dates card. Same year +
// month/day capture as the add-partner step, wrapped in a Cancel/Save editing sheet.

import SwiftUI
import SwiftData

struct MarriageDateEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var syncService
    @State private var vm: MarriageDateEditViewModel

    // 0 = not selected; 1–12 = month; 1–31 = day. Local state synced to the VM via
    // .onChange, matching the add-person birth/death/marriage steps.
    @State private var selectedMonth: Int = 0
    @State private var selectedDay: Int = 0
    @FocusState private var yearFieldFocused: Bool

    init(union: Union, partnerName: String, mutationService: TreeMutationServiceProtocol) {
        _vm = State(initialValue: MarriageDateEditViewModel(
            union: union,
            partnerName: partnerName,
            mutationService: mutationService
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Relationship with \(vm.partnerName)")
                    .font(.title)
                    .fontWeight(.bold)

                // The status toggle drives everything below: a marriage has an
                // anniversary; a partnership doesn't.
                Picker("Status", selection: $vm.isMarried) {
                    Text("Married").tag(true)
                    Text("Partners").tag(false)
                }
                .pickerStyle(.segmented)

                if vm.isMarried {
                    Text("When did they marry?")
                        .font(.headline)
                        .foregroundStyle(BanyanTheme.Color.textSecondary)

                    TextField("Year, e.g. 1972", text: $vm.marriageYearText)
                        .font(.title2)
                        .keyboardType(.numberPad)
                        .focused($yearFieldFocused)
                        .banyanTextInput(focused: yearFieldFocused)

                    MonthDayWheels(month: $selectedMonth, day: $selectedDay)

                    if vm.hasExistingDate {
                        Button(role: .destructive) {
                            removeDateAndDismiss()
                        } label: {
                            Text("Remove anniversary")
                                .font(.body)
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(BanyanTheme.Color.marriage)
                    }
                } else {
                    Text("Partners aren't married, so there's no wedding anniversary.")
                        .font(.body)
                        .foregroundStyle(BanyanTheme.Color.textSecondary)
                }

                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(BanyanTheme.Color.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { yearFieldFocused = false }
                }
            }
            .alert("Couldn't save", isPresented: saveErrorPresented) {
                Button("OK") { vm.saveError = nil }
            } message: {
                Text(vm.saveError?.localizedDescription ?? "Something went wrong. Please try again.")
            }
        }
        // A focused three-field edit — present it as a right-sized sheet with a
        // grabber rather than full screen, so it reads as a quick change, not a page.
        // Expandable to large for big Dynamic Type / the keyboard.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            selectedMonth = vm.marriageMonth ?? 0
            selectedDay = Int(vm.marriageDayText) ?? 0
        }
        .onChange(of: selectedMonth) { _, newMonth in
            yearFieldFocused = false
            vm.marriageMonth = newMonth == 0 ? nil : newMonth
            if newMonth == 0 {
                selectedDay = 0
                vm.marriageDayText = ""
            }
        }
        .onChange(of: selectedDay) { _, newDay in
            vm.marriageDayText = newDay == 0 ? "" : "\(newDay)"
        }
    }

    private func saveAndDismiss() {
        do {
            try vm.save(in: modelContext, sync: syncService)
            dismiss()
        } catch {
            vm.saveError = error
        }
    }

    private func removeDateAndDismiss() {
        do {
            try vm.removeDate(in: modelContext, sync: syncService)
            dismiss()
        } catch {
            vm.saveError = error
        }
    }

    private var saveErrorPresented: Binding<Bool> {
        Binding(
            get: { vm.saveError != nil },
            set: { if !$0 { vm.saveError = nil } }
        )
    }
}
