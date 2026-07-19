// PhotoStorageService.swift
// Saves and loads profile photos in the app's documents directory, addressed by
// filename (not full path) so a Person stores only the generated filename.
// Pure file I/O — UIKit only, no SwiftUI, and no shared mutable state (the static
// helpers are stateless, so this is not a singleton).

import Foundation
import UIKit

struct PhotoStorageService {
    private static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Saves image data and returns the generated filename, or nil on failure.
    static func save(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let filename = UUID().uuidString + ".jpg"
        do {
            try data.write(to: documentsURL.appendingPathComponent(filename))
            return filename
        } catch {
            return nil
        }
    }

    /// Loads the image for a filename, or nil if not found.
    static func load(filename: String) -> UIImage? {
        UIImage(contentsOfFile: documentsURL.appendingPathComponent(filename).path)
    }

    /// Deletes the file for a filename. Silent if absent.
    static func delete(filename: String) {
        try? FileManager.default.removeItem(at: documentsURL.appendingPathComponent(filename))
    }
}
