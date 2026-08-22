// LinkPersonReviewView.swift
// Step 3 of the link flow: a summary of the connection about to be made,
// with Save and a way back to the start (same shape as AddPersonReviewStepView).

import SwiftUI

struct LinkPersonReviewView: View {
    let anchor: Person
    let person: Person
    let relationship: LinkRelationship
    let onSave: () -> Void
    let onChangeSomething: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Does this look right?")
                .font(.largeTitle)
                .fontWeight(.bold)

            summaryCard

            Spacer()

            Button {
                onSave()
            } label: {
                Text("Save")
            }
            .buttonStyle(PrimaryFilledButtonStyle())

            Button("Change something") {
                onChangeSomething()
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(BanyanTheme.Color.background.ignoresSafeArea())
    }

    private var summaryCard: some View {
        Text("\(person.fullName) will be linked as \(anchor.firstName)'s \(relationshipWord).")
            .font(.title3)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(BanyanTheme.Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(BanyanTheme.Color.border, lineWidth: 1)
            )
    }

    private var relationshipWord: String {
        switch relationship {
        case .parent: "parent"
        case .partner: "partner"
        case .child: "child"
        }
    }
}
