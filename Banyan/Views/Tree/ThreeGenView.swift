// ThreeGenView.swift
// The 3-generation focused tree: parents on top, focal person with siblings and
// partner(s) in the middle, children below. Tapping any node opens the person sheet.

import SwiftUI

struct ThreeGenView: View {
    /// When true (a viewer's shared tree), the "Add …" placeholder slots are hidden.
    @Environment(\.isReadOnly) private var isReadOnly

    let threeGenVM: ThreeGenViewModel
    let treeVM: TreeViewModel
    let allPeople: [Person]
    /// The tree owner's id — NOT the focal person. "My tree" compares the current
    /// focus against this, so it must stay fixed while the focus moves around.
    let ownerPersonId: UUID
    /// Called when any person node is tapped — opens the person sheet.
    let onSelectPerson: (Person) -> Void
    /// Called when a placeholder node is tapped, with the relationship to create.
    let onAddPerson: (AddPersonContext) -> Void

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                BreadcrumbView(
                    stack: treeVM.navigationStack,
                    current: threeGenVM.focalPerson.id,
                    allPeople: allPeople
                ) { personId in
                    treeVM.jumpTo(personId: personId)
                }

                ScrollView {
                    VStack(spacing: 32) {
                        parentRow
                        middleRow(minWidth: geometry.size.width - 32)
                        childRow(minWidth: geometry.size.width - 32)
                    }
                    .padding(16)
                    .overlayPreferenceValue(NodeAnchorKey.self) { anchors in
                        TreeConnectorsView(
                            anchors: anchors,
                            parentIds: threeGenVM.parents.map(\.id),
                            focalId: threeGenVM.focalPerson.id,
                            partnerId: threeGenVM.focalPartners.first?.id,
                            childIds: threeGenVM.children.map(\.id)
                        )
                    }
                }
            }
        }
        // Deliberately titleless (finding #8): the breadcrumb below the bar names
        // the focal person, and Back / My tree fill the bar — a centre title would
        // just duplicate the breadcrumb and crowd an already-busy inline bar.
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                backButton
            }
            ToolbarItem(placement: .topBarTrailing) {
                backToMeButton
            }
        }
    }

    // MARK: - Rows

    private var parentRow: some View {
        HStack(spacing: 24) {
            if threeGenVM.parents.isEmpty {
                if !isReadOnly {
                    PlaceholderNodeView(label: "Add parent", pulseDelay: 0) {
                        onAddPerson(.parent(of: threeGenVM.focalPerson))
                    }
                }
            } else {
                ForEach(threeGenVM.parents) { parent in
                    node(for: parent)
                }
            }
        }
    }

    private func middleRow(minWidth: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                siblingNodes

                node(for: threeGenVM.focalPerson, isFocal: true)

                partnerSlot
            }
            .frame(minWidth: max(minWidth, 0))
        }
        .defaultScrollAnchor(.center)
    }

    private func childRow(minWidth: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                if threeGenVM.children.isEmpty {
                    if !isReadOnly {
                        PlaceholderNodeView(label: "Add child", pulseDelay: 1.4) {
                            onAddPerson(.child(of: threeGenVM.focalPerson))
                        }
                    }
                } else {
                    ForEach(threeGenVM.children) { child in
                        node(for: child)
                    }
                }
            }
            .frame(minWidth: max(minWidth, 0))
        }
    }

    // MARK: - Middle-row pieces

    @ViewBuilder
    private var siblingNodes: some View {
        // Every sibling renders — the middle row scrolls horizontally, so large
        // families are all reachable rather than hidden behind a "+N more" pill.
        ForEach(threeGenVM.siblings) { sibling in
            node(for: sibling)
        }
    }

    @ViewBuilder
    private var partnerSlot: some View {
        if threeGenVM.focalPartners.isEmpty {
            if !isReadOnly {
                PlaceholderNodeView(label: "Add partner", pulseDelay: 0.7) {
                    onAddPerson(.partner(of: threeGenVM.focalPerson))
                }
            }
        } else {
            // All partners render (scrollable) instead of one node + a "+N" badge,
            // so remarriages / multiple partners are each visible and tappable.
            ForEach(threeGenVM.focalPartners) { partner in
                node(for: partner)
            }
        }
    }

    /// A person node that publishes its centre anchor and opens the person sheet on tap.
    /// Every node — the focal one included — opens the sheet; "See their family"
    /// inside the sheet is what re-centres the tree.
    private func node(for person: Person, isFocal: Bool = false) -> some View {
        PersonNodeView(person: person, isFocal: isFocal) {
            onSelectPerson(person)
        }
        .anchorPreference(key: NodeAnchorKey.self, value: .center) { [person.id: $0] }
    }

    // MARK: - Toolbar

    private var backButton: some View {
        Button {
            treeVM.goBack()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .font(.body)
            .frame(minWidth: 44, minHeight: 44)
        }
        .disabled(treeVM.navigationStack.isEmpty)
    }

    private var backToMeButton: some View {
        Button("My tree") {
            treeVM.resetToRoot(ownerId: ownerPersonId)
        }
        .font(.body)
        .frame(minWidth: 44, minHeight: 44)
        .disabled(treeVM.focusedPersonId == ownerPersonId)
    }
}
