// PhotoSyncServiceEnvironment.swift
// Injection seam for the photo-sync service: built once at the composition root
// (BanyanApp) and read by the photo views to pass into their ViewModels. A plain
// protocol value, like ShareServiceEnvironment — the concrete service is a
// stateless SDK wrapper, not observable view state.

import SwiftUI

private struct PhotoSyncServiceKey: EnvironmentKey {
    static let defaultValue: (any PhotoSyncServiceProtocol)? = nil
}

extension EnvironmentValues {
    /// The photo-sync service, or nil before the root injects it (and in
    /// previews). Consumers guard for nil — a nil service just skips the upload.
    var photoSyncService: (any PhotoSyncServiceProtocol)? {
        get { self[PhotoSyncServiceKey.self] }
        set { self[PhotoSyncServiceKey.self] = newValue }
    }
}
