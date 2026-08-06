// Extensions.swift
// Small shared conveniences.

import Foundation

extension UUID {
    /// The all-zero UUID, used as a stand-in identifier before a real one exists.
    /// Built from bytes rather than `UUID(uuidString:)!` — production code takes no force unwraps.
    static var placeholder: UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    }
}

extension Collection {
    /// Bounds-checked element access — returns nil instead of trapping when the
    /// index is out of range. Handy for indexing into system arrays like
    /// `DateFormatter().monthSymbols`.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension String {
    /// The trimmed-optional idiom: nil when empty, otherwise self. Lets callers
    /// collapse blank text fields to a nil model value in one step.
    var nonEmptyOrNil: String? {
        isEmpty ? nil : self
    }
}
