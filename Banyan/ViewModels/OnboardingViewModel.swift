// OnboardingViewModel.swift
// Form state and owner-creation for first-launch onboarding.

import Foundation
import SwiftUI
import SwiftData

@MainActor
@Observable
final class OnboardingViewModel {
    var firstName: String = ""
    var lastName: String = ""
    var isSaving: Bool = false
    var saveError: Error?

    /// Whether the entered first name is enough to proceed. Whitespace-only names do not count.
    var canContinue: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Creates the owner Person, persists it, and records its id and treeId in app storage.
    /// The two bindings are `@AppStorage`-backed strings owned by the view.
    /// Re-entrant calls are ignored so a double-tap cannot create two owners.
    func save(
        in context: ModelContext,
        ownerIdStorage: Binding<String>,
        treeIdStorage: Binding<String>
    ) async throws {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        let treeId = UUID()
        let owner = Person(
            treeId: treeId,
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            sex: .unknown
        )
        context.insert(owner)
        try context.save()

        ownerIdStorage.wrappedValue = owner.id.uuidString
        treeIdStorage.wrappedValue = treeId.uuidString
    }
}
