// ShareServiceEnvironment.swift
// The injection seam for the sharing service: built once at the composition root
// (BanyanApp) and read by TreeTabView. Mirrors how SyncService/AuthStateManager
// are composed at the root and injected — but as a plain protocol value (the
// concrete SupabaseShareService is a stateless SDK wrapper, not observable view
// state), so it goes in as a keypath environment value rather than an @Observable.

import SwiftUI

private struct ShareServiceKey: EnvironmentKey {
    static let defaultValue: (any ShareServiceProtocol)? = nil
}

extension EnvironmentValues {
    /// The owner-side sharing service, or nil before the root injects it (and in
    /// previews). Consumers guard for nil.
    var shareService: (any ShareServiceProtocol)? {
        get { self[ShareServiceKey.self] }
        set { self[ShareServiceKey.self] = newValue }
    }
}
