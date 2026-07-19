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
