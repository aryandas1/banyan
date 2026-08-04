// InviteAcceptanceServiceEnvironment.swift
// Injection seam for the viewer-side invite service: built once at the composition
// root (BanyanApp) and read by ContentView (to build the acceptance ViewModel) and
// MainTabView (to refresh a viewed tree on launch). A plain protocol value, like
// ShareServiceEnvironment — the concrete service is a stateless SDK wrapper.

import SwiftUI

private struct InviteAcceptanceServiceKey: EnvironmentKey {
    static let defaultValue: (any InviteAcceptanceServiceProtocol)? = nil
}

extension EnvironmentValues {
    /// The viewer-side invite service, or nil before the root injects it (and in
    /// previews). Consumers guard for nil.
    var inviteAcceptanceService: (any InviteAcceptanceServiceProtocol)? {
        get { self[InviteAcceptanceServiceKey.self] }
        set { self[InviteAcceptanceServiceKey.self] = newValue }
    }
}
