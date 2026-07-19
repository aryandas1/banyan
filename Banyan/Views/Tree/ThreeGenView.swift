// ThreeGenView.swift
// The 3-generation focused tree: parents on top, focal person with siblings and
// partner(s) in the middle, children below. Tapping any node re-centres the tree.

import SwiftUI

struct ThreeGenView: View {
    let threeGenVM: ThreeGenViewModel
    let treeVM: TreeViewModel
    let allPeople: [Person]
    /// The tree owner's id — NOT the focal person. "My tree" compares the current
    /// focus against this, so it must stay fixed while the focus moves around.
    let ownerPersonId: UUID

    /// At most this many sibling nodes render; beyond it, two nodes plus a "+N more" pill.
    private let maxVisibleSiblings = 3

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
                PlaceholderNodeView(label: "Add parent") {
                    print("Placeholder tapped: Add parent")
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
                    PlaceholderNodeView(label: "Add child") {
                        print("Placeholder tapped: Add child")
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
        let siblings = threeGenVM.siblings
        let visible = siblings.count > maxVisibleSiblings ? Array(siblings.prefix(2)) : siblings

        ForEach(visible) { sibling in
            node(for: sibling)
        }

        if siblings.count > maxVisibleSiblings {
            Text("+\(siblings.count - 2) more")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(.systemGray6)))
        }
    }

    @ViewBuilder
    private var partnerSlot: some View {
        if let partner = threeGenVM.focalPartners.first {
            node(for: partner)
                .overlay(alignment: .topTrailing) {
                    if threeGenVM.focalPartners.count > 1 {
                        Text("+\(threeGenVM.focalPartners.count - 1)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(5)
                            .background(Circle().fill(Color(.systemGray5)))
                            .offset(x: 8, y: -8)
                    }
                }
        } else {
            PlaceholderNodeView(label: "Add partner") {
                print("Placeholder tapped: Add partner")
            }
        }
    }

    /// A person node that publishes its centre anchor and re-centres the tree on tap.
    /// The focal node's tap is a no-op — it is already the centre.
    private func node(for person: Person, isFocal: Bool = false) -> some View {
        PersonNodeView(person: person, isFocal: isFocal) {
            guard !isFocal else { return }
            treeVM.focus(on: person.id)
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
