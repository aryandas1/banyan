// Union.swift
// A relationship between partners, and the anchor that children attach to.
// Edges of the person-union graph — parents and children never link directly.

import Foundation
import SwiftData

/// The nature of a partnership.
enum UnionType: String, Codable, CaseIterable {
    case married
    case partnered
    case unknown
}

/// Why a union ended.
enum EndReason: String, Codable, CaseIterable {
    case divorce
    case death
    case unknown
}

@Model
final class Union {
    var id: UUID
    var treeId: UUID
    var type: UnionType
    var startDate: PartialDate?
    var endDate: PartialDate?
    var endReason: EndReason?

    @Relationship(deleteRule: .cascade, inverse: \PersonUnionLink.union)
    var links: [PersonUnionLink]

    init(
        id: UUID = UUID(),
        treeId: UUID,
        type: UnionType = .unknown,
        startDate: PartialDate? = nil,
        endDate: PartialDate? = nil,
        endReason: EndReason? = nil
    ) {
        self.id = id
        self.treeId = treeId
        self.type = type
        self.startDate = startDate
        self.endDate = endDate
        self.endReason = endReason
        self.links = []
    }
}
