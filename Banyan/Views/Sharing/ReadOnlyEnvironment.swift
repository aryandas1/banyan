// ReadOnlyEnvironment.swift
// The environment flag that gates every edit control for a viewer's shared tree.
// Set by ContentView around MainTabView when the current tree is one this device
// only views; read by the tree/person views to hide their mutation entry points.
//
// Lives in Views/Sharing (like ShareServiceEnvironment) — env plumbing isn't
// meaningfully unit-testable, so it stays off the coverage gate.

import SwiftUI

private struct IsReadOnlyKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True when the visible tree is shared read-only. Edit controls hide on it;
    /// the security boundary itself is RLS server-side, this is UX.
    var isReadOnly: Bool {
        get { self[IsReadOnlyKey.self] }
        set { self[IsReadOnlyKey.self] = newValue }
    }
}
