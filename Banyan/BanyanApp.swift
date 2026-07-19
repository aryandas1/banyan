// BanyanApp.swift
// App entry point. Installs the SwiftData container from the versioned schema.

import SwiftUI
import SwiftData

@main
struct BanyanApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: BanyanSchemaV1.models)
    }
}
