// LinkPersonPickView.swift
// Step 1 of the link flow: pick the already-existing person to connect,
// from a searchable list of everyone in the tree except the anchor.

import SwiftUI

struct LinkPersonPickView: View {
    let anchor: Person
    let allPeople: [Person]
    let onPick: (Person) -> Void

    @State private var query = ""

    private var candidates: [Person] {
        allPeople.filter { candidate in
            candidate.id != anchor.id
                && (query.isEmpty || candidate.fullName.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        Group {
            if candidates.isEmpty {
                ContentUnavailableView("No one found", systemImage: "person.slash")
            } else {
                List {
                    Section {
                        ForEach(candidates) { person in
                            personRow(person)
                        }
                    } header: {
                        Text("Who is \(anchor.firstName) related to?")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .textCase(nil)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(BanyanTheme.Color.background)
        .searchable(text: $query, prompt: "Search by name")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func personRow(_ person: Person) -> some View {
        Button {
            onPick(person)
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(BanyanTheme.avatarColor(for: person.id))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(person.initials)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    )
                Text(person.fullName)
                    .font(.body)
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }
}
