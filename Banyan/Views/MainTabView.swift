// MainTabView.swift
// The three-tab shell shown once onboarding is complete.
// Every tab item carries a text label as well as an icon — this app's users rely on labels.

import SwiftUI

struct MainTabView: View {
    @AppStorage("ownerPersonId") private var ownerPersonIdString: String = ""

    /// The owner's id, resolved from storage. Falls back to the all-zero UUID if storage is
    /// somehow malformed — the tab still renders rather than crashing.
    private var ownerPersonId: UUID {
        UUID(uuidString: ownerPersonIdString) ?? .placeholder
    }

    var body: some View {
        TabView {
            TreeTabView(ownerPersonId: ownerPersonId)
                .tabItem { Label("Tree", systemImage: "person.3.fill") }

            PeopleListView(ownerPersonId: ownerPersonId)
                .tabItem { Label("People", systemImage: "list.bullet") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

#Preview {
    MainTabView()
}
