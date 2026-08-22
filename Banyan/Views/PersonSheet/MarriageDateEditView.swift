// MarriageDateEditView.swift
// A small sheet to edit a couple's relationship after the fact — married vs
// (unmarried) partners, and the anniversary date for a marriage. Reached by tapping a
// partnership row on the person-sheet Dates card. Built as a Form with a short inline
// title + Cancel/Save, matching PersonEditView (the app's other edit sheet).

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
            Form {
                // The status toggle drives everything below: a marriage has an
                // anniversary; a partnership doesn't. The footer explains the latter.
                Section {
                    Picker("Status", selection: $vm.isMarried) {
                        Text("Married").tag(true)
                        Text("Partners").tag(false)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("With \(vm.partnerName)")
                } footer: {
                    if !vm.isMarried {
                        Text("Partners aren't married, so there's no wedding anniversary.")
                    }
                }

                if vm.isMarried {
                    Section("Anniversary") {
                        TextField("Year, e.g. 1972", text: $vm.marriageYearText)
                            .keyboardType(.numberPad)
                            .focused($yearFieldFocused)

                        // The month/day wheels carry their own bordered surface, so
                        // drop the Form row's inset/background and let them span.
                        MonthDayWheels(month: $selectedMonth, day: $selectedDay)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                    }

                    if vm.hasExistingDate {
                        Section {
                            Button("Remove anniversary", role: .destructive) {
                                removeDateAndDismiss()
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BanyanTheme.Color.background)
            .navigationTitle("Relationship")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
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
