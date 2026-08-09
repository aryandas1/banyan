// OnboardingViewModelTests.swift
// Form-state rules for the name-entry step. The suite is @MainActor because the view model is.

import Testing
import SwiftUI
import SwiftData
@testable import Banyan

@MainActor
@Suite("OnboardingViewModel")
struct OnboardingViewModelTests {

    @Test func canContinueIsFalseWhenFirstNameIsEmpty() {
        // Given a fresh view model with no name entered
        let viewModel = OnboardingViewModel()

        // Then continuing is not allowed
        #expect(viewModel.canContinue == false)
    }

    @Test func canContinueIsTrueWithFirstName() {
        // Given a first name
        let viewModel = OnboardingViewModel()
        viewModel.firstName = "Ravi"

        // Then continuing is allowed
        #expect(viewModel.canContinue == true)
    }

    @Test func canContinueIsFalseForWhitespaceOnly() {
        // Given a first name of only spaces
        let viewModel = OnboardingViewModel()
        viewModel.firstName = "   "

        // Then continuing is not allowed
        #expect(viewModel.canContinue == false)
    }

    @Test func saveSchedulesSyncForNewTree() async throws {
        // Given a fresh onboarding form with a name and an in-memory container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Schema(BanyanSchemaV2.models), configurations: config)
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let viewModel = OnboardingViewModel()
        viewModel.firstName = "Ravi"

        // @AppStorage bindings are backed by local vars for the test.
        var ownerId = ""
        var treeId = ""
        let ownerBinding = Binding(get: { ownerId }, set: { ownerId = $0 })
        let treeBinding = Binding(get: { treeId }, set: { treeId = $0 })
        let spy = SpySyncScheduler()

        // When the owner is saved
        try await viewModel.save(
            in: context,
            ownerIdStorage: ownerBinding,
            treeIdStorage: treeBinding,
            sync: spy
        )

        // Then exactly one sync is scheduled for the newly created tree
        let expectedTreeId = try #require(UUID(uuidString: treeId))
        #expect(spy.scheduledTreeIds == [expectedTreeId])
    }
}
