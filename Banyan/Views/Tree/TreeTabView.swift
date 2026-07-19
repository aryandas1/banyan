// TreeTabView.swift
// The Tree tab: resolves the current focal person and hosts the 3-generation view.
// Composition root for the tree — concrete GraphService instances are created here.

import SwiftUI
import SwiftData

struct TreeTabView: View {
    let ownerPersonId: UUID

    @AppStorage("treeId") private var treeIdString: String = ""
    @Query private var allPeople: [Person]

    @State private var treeViewModel = TreeViewModel(graphService: GraphService())
    @State private var threeGenViewModel: ThreeGenViewModel?

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
                        ownerPersonId: ownerPersonId
                    )
                } else {
                    ContentUnavailableView("No tree yet", systemImage: "tree")
                }
            }
            .onChange(of: treeViewModel.focusedPersonId) { _, newId in
                guard let person = person(with: newId ?? ownerPersonId) else { return }
                threeGenViewModel = ThreeGenViewModel(focalPerson: person, graphService: GraphService())
            }
            .onChange(of: ownerPersonId) { _, _ in
                guard treeViewModel.focusedPersonId == nil else { return }
                setUpIfPossible()
            }
            .onChange(of: allPeople.count) { _, _ in
                guard threeGenViewModel == nil else { return }
                setUpIfPossible()
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
        threeGenViewModel = ThreeGenViewModel(focalPerson: owner, graphService: GraphService())
    }

    private func person(with id: UUID) -> Person? {
        treePeople.first { $0.id == id }
    }
}
