// TreeTabView.swift
// The Tree tab: resolves the current focal person and hosts the 3-generation view.
// Composition root for the tree — concrete GraphService instances are created here.

import SwiftUI
import SwiftData

struct TreeTabView: View {
    let ownerPersonId: UUID

    @AppStorage("treeId") private var treeIdString: String = ""
    @Query private var allPeople: [Person]

    /// Shared across the tab's lifetime — stateless, so one instance is enough for every
    /// ViewModel this composition root creates.
    private let graphService: GraphServiceProtocol
    @State private var treeViewModel: TreeViewModel
    @State private var threeGenViewModel: ThreeGenViewModel?
    @State private var addPersonContext: AddPersonContext? = nil

    init(ownerPersonId: UUID) {
        self.ownerPersonId = ownerPersonId
        let graphService = GraphService()
        self.graphService = graphService
        _treeViewModel = State(initialValue: TreeViewModel(graphService: graphService))
    }

    private var treePeople: [Person] {
        guard let treeId = UUID(uuidString: treeIdString) else { return [] }
        return allPeople.filter { $0.treeId == treeId }
    }

    private var focalPersonId: UUID {
        treeViewModel.focusedPersonId ?? ownerPersonId
    }

    var body: some View {
        NavigationStack {
            Group {
                if let vm = threeGenViewModel,
                   treePeople.contains(where: { $0.id == focalPersonId }) {
                    ThreeGenView(
                        threeGenVM: vm,
                        treeVM: treeViewModel,
                        allPeople: treePeople,
                        ownerPersonId: ownerPersonId,
                        onAddPerson: { context in addPersonContext = context }
                    )
                } else {
                    ContentUnavailableView("No tree yet", systemImage: "tree")
                }
            }
            .onChange(of: treeViewModel.focusedPersonId) { _, newId in
                guard let person = person(with: newId ?? ownerPersonId) else { return }
                threeGenViewModel = ThreeGenViewModel(focalPerson: person, graphService: graphService)
            }
            .onChange(of: ownerPersonId) { _, _ in
                guard treeViewModel.focusedPersonId == nil else { return }
                setUpIfPossible()
            }
            .onChange(of: allPeople.count) { _, _ in
                if threeGenViewModel == nil {
                    setUpIfPossible()
                } else {
                    refreshSnapshot()
                }
            }
            .sheet(item: $addPersonContext) { context in
                AddPersonView(context: context) {
                    refreshSnapshot()
                }
            }
            .onAppear {
                guard threeGenViewModel == nil else { return }
                setUpIfPossible()
            }
        }
    }

    /// Centres the tree on the owner once the owner's Person exists in the store.
    private func setUpIfPossible() {
        guard let owner = person(with: ownerPersonId) else { return }
        treeViewModel.resetToRoot(ownerId: ownerPersonId)
        threeGenViewModel = ThreeGenViewModel(focalPerson: owner, graphService: graphService)
    }

    /// Reloads the 3-generation snapshot around the current focal person,
    /// e.g. after the add-person sheet saves a new relative.
    private func refreshSnapshot() {
        guard let focalPerson = person(with: focalPersonId) else { return }
        threeGenViewModel?.update(focalPerson: focalPerson)
    }

    private func person(with id: UUID) -> Person? {
        treePeople.first { $0.id == id }
    }
}
