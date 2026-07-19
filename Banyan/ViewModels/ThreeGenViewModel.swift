// ThreeGenViewModel.swift
// The data snapshot for the 3-generation tree view: the focal person's parents,
// partners, siblings, and children, refreshed whenever the focus moves.

import Foundation

@MainActor
@Observable
final class ThreeGenViewModel {
    private let graphService: GraphServiceProtocol

    /// The person currently centred in the tree.
    private(set) var focalPerson: Person

    /// The focal person's parents (partners in the union where focal is a child).
    private(set) var parents: [Person] = []

    /// The focal person's own partner(s).
    private(set) var focalPartners: [Person] = []

    /// The focal person's children across all their unions.
    private(set) var children: [Person] = []

    /// Siblings: people who share at least one parent union with focal.
    /// The view caps display at 3; excess is shown as a "+N more" label.
    private(set) var siblings: [Person] = []

    /// Creates the view model centred on a person and loads their 3-generation snapshot.
    init(focalPerson: Person, graphService: GraphServiceProtocol) {
        self.graphService = graphService
        self.focalPerson = focalPerson
        refresh()
    }

    /// Call whenever the focal person changes.
    func update(focalPerson: Person) {
        self.focalPerson = focalPerson
        refresh()
    }

    /// Reloads every relationship collection around the current focal person.
    private func refresh() {
        parents = graphService.parents(of: focalPerson)
        focalPartners = graphService.allPartners(of: focalPerson)
        children = graphService.children(of: focalPerson)
        siblings = graphService.siblings(of: focalPerson)
    }
}
