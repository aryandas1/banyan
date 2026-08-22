// TreeViewModelTests.swift
// Focus and back-stack behavior. The suite is @MainActor because TreeViewModel is.

import Foundation
import Testing
@testable import Banyan

@MainActor
@Suite("TreeViewModel")
struct TreeViewModelTests {

    @Test func focusSetsId() {
        // Given a fresh view model
        let viewModel = TreeViewModel(graphService: GraphService())
        let personId = UUID()

        // When focusing on a person
        viewModel.focus(on: personId)

        // Then that person is focused
        #expect(viewModel.focusedPersonId == personId)
    }

    @Test func focusPushesPreviousOntoStack() {
        // Given a view model already focused on someone
        let viewModel = TreeViewModel(graphService: GraphService())
        let first = UUID()
        let second = UUID()
        viewModel.focus(on: first)

        // When focusing on someone else
        viewModel.focus(on: second)

        // Then the previous focus is on the back stack
        #expect(viewModel.focusedPersonId == second)
        #expect(viewModel.navigationStack == [first])
    }

    @Test func goBackRestoresPreviousFocus() {
        // Given two focuses deep
        let viewModel = TreeViewModel(graphService: GraphService())
        let first = UUID()
        let second = UUID()
        viewModel.focus(on: first)
        viewModel.focus(on: second)

        // When going back
        viewModel.goBack()

        // Then the previous person is focused and the stack is drained
        #expect(viewModel.focusedPersonId == first)
        #expect(viewModel.navigationStack.isEmpty)
    }

    @Test func goBackDoesNothingOnEmptyStack() {
        // Given a view model with no history
        let viewModel = TreeViewModel(graphService: GraphService())
        let personId = UUID()
        viewModel.focus(on: personId)

        // When going back with an empty stack
        viewModel.goBack()  // must not crash

        // Then focus is unchanged
        #expect(viewModel.focusedPersonId == personId)
        #expect(viewModel.navigationStack.isEmpty)
    }

    @Test func resetToRootClearsStack() {
        // Given a view model several people deep
        let viewModel = TreeViewModel(graphService: GraphService())
        viewModel.focus(on: UUID())
        viewModel.focus(on: UUID())
        viewModel.focus(on: UUID())

        // When resetting to root
        viewModel.resetToRoot(ownerId: UUID())

        // Then the history is gone
        #expect(viewModel.navigationStack.isEmpty)
    }

    @Test func resetToRootSetsFocusToOwner() {
        // Given a view model focused elsewhere
        let viewModel = TreeViewModel(graphService: GraphService())
        let ownerId = UUID()
        viewModel.focus(on: UUID())

        // When resetting to root
        viewModel.resetToRoot(ownerId: ownerId)

        // Then the owner is focused
        #expect(viewModel.focusedPersonId == ownerId)
    }

    @Test func jumpToTruncatesStackToThatPerson() {
        // Given a trail three people deep: A -> B -> C, focused on C
        let viewModel = TreeViewModel(graphService: GraphService())
        let personA = UUID()
        let personB = UUID()
        let personC = UUID()
        viewModel.focus(on: personA)
        viewModel.focus(on: personB)
        viewModel.focus(on: personC)

        // When jumping back to B via a breadcrumb tap
        viewModel.jumpTo(personId: personB)

        // Then B is focused and everything visited after B is discarded, not appended
        #expect(viewModel.focusedPersonId == personB)
        #expect(viewModel.navigationStack == [personA])
    }

    @Test func jumpToDoesNothingWhenAlreadyFocused() {
        // Given a view model already focused on a person
        let viewModel = TreeViewModel(graphService: GraphService())
        let personId = UUID()
        viewModel.focus(on: personId)

        // When jumping to the same person
        viewModel.jumpTo(personId: personId)

        // Then nothing changes
        #expect(viewModel.focusedPersonId == personId)
        #expect(viewModel.navigationStack.isEmpty)
    }

    @Test func jumpToFallsBackToFocusWhenPersonNotInStack() {
        // Given a view model focused on A with no history
        let viewModel = TreeViewModel(graphService: GraphService())
        let personA = UUID()
        let personB = UUID()
        viewModel.focus(on: personA)

        // When jumping to a person who was never visited
        viewModel.jumpTo(personId: personB)

        // Then it behaves like a normal focus: A is pushed, B becomes focus
        #expect(viewModel.focusedPersonId == personB)
        #expect(viewModel.navigationStack == [personA])
    }
}
