// PhotoStorageServiceTests.swift
// Covers EXIF date handling: the pure string parser directly, and the ImageIO
// extraction against a small in-memory JPEG carrying an EXIF DateTimeOriginal.

import Testing
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import Banyan

@Suite("PhotoStorageService")
struct PhotoStorageServiceTests {

    // MARK: - parseExifDateString

    @Test func parsesValidExifDate() {
        let result = PhotoStorageService.parseExifDateString("1967:06:15 10:30:00")
        #expect(result?.year == 1967)
        #expect(result?.month == 6)
    }

    @Test func rejectsMonthOutOfRange() {
        #expect(PhotoStorageService.parseExifDateString("2020:13:01 00:00:00") == nil)
    }

    @Test func rejectsYearBefore1800() {
        #expect(PhotoStorageService.parseExifDateString("1799:06:01 00:00:00") == nil)
    }

    @Test func rejectsMalformedString() {
        #expect(PhotoStorageService.parseExifDateString("not-a-date") == nil)
        #expect(PhotoStorageService.parseExifDateString("") == nil)
    }

    // MARK: - extractTakenDate

    @Test func extractsDateFromExifTaggedJPEG() throws {
        let data = try makeJPEG(withExifDate: "1975:09:20 08:00:00")
        let result = PhotoStorageService.extractTakenDate(from: data)
        #expect(result?.year == 1975)
        #expect(result?.month == 9)
    }

    @Test func extractReturnsNilForNonImageData() {
        #expect(PhotoStorageService.extractTakenDate(from: Data([0x00, 0x01, 0x02])) == nil)
    }

    @Test func extractReturnsNilForImageWithoutExifDate() throws {
        let data = try makeJPEG(withExifDate: nil)
        #expect(PhotoStorageService.extractTakenDate(from: data) == nil)
    }

    // MARK: - Helpers

    /// Builds a tiny in-memory JPEG, optionally carrying an EXIF DateTimeOriginal.
    private func makeJPEG(withExifDate raw: String?) throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        let image = renderer.image { ctx in
            UIColor.gray.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        let cg = try #require(image.cgImage)
        let out = NSMutableData()
        let dest = try #require(
            CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil)
        )
        var props: [CFString: Any] = [:]
        if let raw {
            props[kCGImagePropertyExifDictionary] = [kCGImagePropertyExifDateTimeOriginal: raw]
        }
        CGImageDestinationAddImage(dest, cg, props as CFDictionary)
        #expect(CGImageDestinationFinalize(dest))
        return out as Data
    }
}
