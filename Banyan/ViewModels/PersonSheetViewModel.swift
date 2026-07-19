// PersonSheetViewModel.swift
// Derives the relationship collections shown in the person sheet. Read-only over
// the graph — no writes, no SwiftUI import.

import Foundation

@MainActor
@Observable
final class PersonSheetViewModel {
    private let graphService: GraphServiceProtocol
    private(set) var person: Person
    private(set) var parents: [Person] = []
    private(set) var partners: [Person] = []
    private(set) var children: [Person] = []
    private(set) var siblings: [Person] = []

    init(person: Person, graphService: GraphServiceProtocol) {
        self.graphService = graphService
        self.person = person
        refresh()
    }

    /// Reloads every relationship collection around this person.
    func refresh() {
        parents = graphService.parents(of: person)
        partners = graphService.allPartners(of: person)
        children = graphService.children(of: person)
        siblings = graphService.siblings(of: person)
    }
}
