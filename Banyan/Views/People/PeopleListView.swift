// PeopleListView.swift
// The People tab: a searchable, alphabetical list of everyone in the tree, each row carrying
// a relationship label derived from the owner. Tapping a row opens that person's sheet.

import SwiftUI
import SwiftData

struct PeopleListView: View {
    let ownerPersonId: UUID

    @AppStorage("treeId") private var treeIdString: String = ""
    @Query private var allPeople: [Person]
    @State private var query: String = ""
    @State private var selectedPerson: Person?
    @State private var labelCache: [UUID: String] = [:]

    private let graphService: GraphServiceProtocol = GraphService()

    /// The tree owner, resolved from the queried people.
    private var owner: Person? {
        allPeople.first { $0.id == ownerPersonId }
    }

    /// Real people in this tree, alphabetised. Placeholder nodes are graph scaffolding, not
    /// people, so they're excluded; `localizedCompare` orders non-ASCII names correctly.
    private var treePeople: [Person] {
        guard let treeId = UUID(uuidString: treeIdString) else { return [] }
        return allPeople
            .filter { $0.treeId == treeId && !$0.isPlaceholder }
            .sorted { $0.fullName.localizedCompare($1.fullName) == .orderedAscending }
    }

    private var filteredPeople: [Person] {
        guard !query.isEmpty else { return treePeople }
        return treePeople.filter { $0.fullName.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredPeople.isEmpty {
                    ContentUnavailableView(
                        query.isEmpty ? "No family members yet" : "No results",
                        systemImage: query.isEmpty ? "person.3" : "magnifyingglass"
                    )
                } else {
                    List {
                        ForEach(filteredPeople) { person in
                            PersonRowView(
                                person: person,
                                relationshipLabel: labelFor(person)
                            ) {
                                selectedPerson = person
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("People")
            .searchable(text: $query, prompt: "Search by name")
            .onAppear { rebuildLabelCache() }
            .onChange(of: treePeople.map(\.id)) { _, _ in rebuildLabelCache() }
            .sheet(item: $selectedPerson) { person in
                // onSeeFamily / onAddPerson only dismiss here — tree navigation lives in the
                // Tree tab, so the People tab can't re-centre it. See docs/known-gaps.md #4.
                PersonSheetView(
                    person: person,
                    allPeople: treePeople,
                    graphService: graphService,
                    mutationService: TreeMutationService(),
                    isFocal: person.id == ownerPersonId,
                    canDelete: person.id != ownerPersonId,
                    onSeeFamily: { _ in selectedPerson = nil },
                    onAddPerson: { _ in selectedPerson = nil }
                )
            }
        }
    }

    /// The relationship label for a row, read from the cache. Empty until the cache is built
    /// (on appear / when the tree's id-set changes) — never a per-render BFS traversal.
    private func labelFor(_ person: Person) -> String {
        labelCache[person.id] ?? ""
    }

    /// Recomputes every tree member's owner-relative label in one pass. Called on appear and
    /// whenever `treePeople`'s id-set changes (add/delete), so search keystrokes — which only
    /// re-render — never trigger BFS. The owner is labelled "That's you"; everyone else via BFS.
    private func rebuildLabelCache() {
        guard let owner else { return }
        var cache: [UUID: String] = [:]
        for person in treePeople {
            if person.id == owner.id {
                cache[person.id] = "That's you"
            } else {
                cache[person.id] = RelationshipLabel.label(from: owner, to: person, using: graphService)
            }
        }
        labelCache = cache
    }
}

#Preview {
    PeopleListView(ownerPersonId: .placeholder)
}
