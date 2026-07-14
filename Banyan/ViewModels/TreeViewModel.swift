// TreeViewModel.swift
// Owns which person the tree is centred on, and the trail of people walked through to get there.

import Foundation

@MainActor
@Observable
final class TreeViewModel {
    private let graphService: GraphServiceProtocol

    private(set) var focusedPersonId: UUID?
    private(set) var navigationStack: [UUID] = []

    init(graphService: GraphServiceProtocol) {
        self.graphService = graphService
    }

    /// Centres the tree on a person, pushing the previous focus onto the back stack.
    /// Re-focusing the person already in focus does nothing, so the stack cannot fill with repeats.
    func focus(on personId: UUID) {
        guard personId != focusedPersonId else { return }

        if let focusedPersonId {
            navigationStack.append(focusedPersonId)
        }
        focusedPersonId = personId
    }

    /// Returns to the previously focused person. No-op when there is no history.
    func goBack() {
        guard let previous = navigationStack.popLast() else { return }

        focusedPersonId = previous
    }

    /// Clears the history and centres the tree on the tree's owner.
    func resetToRoot(ownerId: UUID) {
        navigationStack.removeAll()
        focusedPersonId = ownerId
    }
}
