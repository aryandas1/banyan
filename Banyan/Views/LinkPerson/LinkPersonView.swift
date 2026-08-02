// LinkPersonView.swift
// Sheet that connects two people who already exist in the tree.
// Three steps in its own NavigationStack: pick person → choose relationship → review.
// The mutation call happens here so the step views stay dumb.

import SwiftUI
import SwiftData

/// The relationship chosen for the person being linked, phrased from that
/// person's side: "person is anchor's parent / partner / child". A distinct
/// enum, not LinkRole — parent and partner both store as `.partner` links, so
/// LinkRole alone can't carry the choice from step 2 to the save.
enum LinkRelationship: Hashable {
    case parent
    case partner
    case child
}

/// Navigation path entries for the steps after the initial pick screen.
enum LinkPersonStep: Hashable {
    case role(Person)
    case review(Person, LinkRelationship)
}

struct LinkPersonView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var syncService
    @State private var path: [LinkPersonStep] = []
    @State private var saveError: Error?

    let anchor: Person
    let allPeople: [Person]   // passed down from TreeTabView — never @Query here
    let mutationService: TreeMutationServiceProtocol
    let onSave: () -> Void

    var body: some View {
        NavigationStack(path: $path) {
            LinkPersonPickView(anchor: anchor, allPeople: allPeople) { person in
                path.append(.role(person))
            }
            .navigationDestination(for: LinkPersonStep.self) { step in
                switch step {
                case let .role(person):
                    LinkPersonRoleView(anchor: anchor, person: person) { relationship in
                        path.append(.review(person, relationship))
                    }
                case let .review(person, relationship):
                    LinkPersonReviewView(
                        anchor: anchor,
                        person: person,
                        relationship: relationship,
                        onSave: { save(person, as: relationship) },
                        onChangeSomething: { path.removeAll() }
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .alert("Couldn't link", isPresented: saveErrorPresented) {
                Button("OK") { saveError = nil }
            } message: {
                Text(saveError?.localizedDescription ?? "Something went wrong. Please try again.")
            }
        }
    }

    /// Runs the mutation matching the chosen relationship, then notifies the
    /// presenter and closes the sheet. Failures surface in the alert instead.
    private func save(_ person: Person, as relationship: LinkRelationship) {
        do {
            switch relationship {
            case .parent:
                try mutationService.linkAsParent(person, of: anchor, in: modelContext)
            case .partner:
                try mutationService.linkAsPartner(person, with: anchor, in: modelContext)
            case .child:
                try mutationService.linkAsChild(person, of: anchor, in: modelContext)
            }
            syncService.scheduleSync(treeId: anchor.treeId, context: modelContext)
            onSave()
            dismiss()
        } catch {
            saveError = error
        }
    }

    private var saveErrorPresented: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )
    }
}
