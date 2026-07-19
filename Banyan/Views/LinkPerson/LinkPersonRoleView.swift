// LinkPersonRoleView.swift
// Step 2 of the link flow: choose how the picked person relates to the anchor,
// via three large option cards (same card pattern as AddPersonStatusStepView).

import SwiftUI

struct LinkPersonRoleView: View {
    let anchor: Person
    let person: Person
    let onChoose: (LinkRelationship) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How is \(person.firstName) related to \(anchor.firstName)?")
                .font(.largeTitle)
                .fontWeight(.bold)

            relationshipCard("\(person.firstName) is \(anchor.firstName)'s parent", .parent)
            relationshipCard("\(person.firstName) is \(anchor.firstName)'s partner", .partner)
            relationshipCard("\(person.firstName) is \(anchor.firstName)'s child", .child)

            Spacer()
        }
        .padding(24)
    }

    /// One full-width card; tapping it advances to the review step.
    private func relationshipCard(
        _ title: String,
        _ relationship: LinkRelationship
    ) -> some View {
        Button {
            onChoose(relationship)
        } label: {
            HStack {
                Text(title)
                    .font(.title3)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
}
