// ProfilePhotoLoader.swift
// Shared off-main-thread load of a person's profile photo, used by the tree
// node and the People-list row (and anywhere else a small avatar needs the
// stored image). Callers still guard on `Task.isCancelled` after awaiting —
// nodes and rows are recycled, so an in-flight load can outlive its view.

import UIKit

enum ProfilePhotoLoader {
    /// The person's profile photo decoded off the main thread, or nil when they
    /// have none. Does no work (no detached task) when there's no filename.
    static func load(for person: Person) async -> UIImage? {
        guard let filename = person.profilePhoto?.filename else { return nil }
        return await Task.detached { PhotoStorageService.load(filename: filename) }.value
    }
}
