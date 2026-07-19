// OnboardingViewModelTests.swift
// Form-state rules for the name-entry step. The suite is @MainActor because the view model is.

import Testing
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
}
