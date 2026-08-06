// PhotoStorageService.swift
// Saves and loads profile photos in the app's documents directory, addressed by
// filename (not full path) so a Person stores only the generated filename.
// Pure file I/O — UIKit only, no SwiftUI, and no shared mutable state (the static
// helpers are stateless, so this is not a singleton).

import Foundation
import UIKit
import ImageIO

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

    // MARK: - EXIF

    /// Reads the capture year/month from image bytes via EXIF (falling back to
    /// the TIFF DateTime), or nil when no usable date is present. The ImageIO
    /// read is here; the string parsing is factored into `parseExifDateString`
    /// so it can be unit-tested without a real image.
    static func extractTakenDate(from data: Data) -> (year: Int, month: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return nil }

        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]

        let raw = (exif?[kCGImagePropertyExifDateTimeOriginal] as? String)
            ?? (tiff?[kCGImagePropertyTIFFDateTime] as? String)

        guard let raw else { return nil }
        return parseExifDateString(raw)
    }

    /// Parses an EXIF datetime string ("YYYY:MM:DD HH:MM:SS") into a year/month
    /// pair, or nil if it isn't a plausible date (year after 1800, month 1–12).
    static func parseExifDateString(_ raw: String) -> (year: Int, month: Int)? {
        let parts = raw.split(separator: ":")
        guard parts.count >= 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              year > 1800, (1...12).contains(month)
        else { return nil }
        return (year: year, month: month)
    }
}
