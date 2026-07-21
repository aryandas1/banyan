// AddPersonContext.swift
// Which relationship the add-person sheet is creating, and for whom.

import Foundation

/// The relationship being created and which existing person it attaches to.
enum AddPersonContext: Identifiable {
    case parent(of: Person)
    case partner(of: Person)
    case child(of: Person)
    case sibling(of: Person)

    var id: String {
        switch self {
        case .parent(let p): "parent-\(p.id)"
        case .partner(let p): "partner-\(p.id)"
        case .child(let p): "child-\(p.id)"
        case .sibling(let p): "sibling-\(p.id)"
        }
    }

    /// The anchor person this relationship is relative to.
    var anchorPerson: Person {
        switch self {
        case .parent(let p), .partner(let p), .child(let p), .sibling(let p): p
        }
    }

    /// Sheet heading shown at the top of the add-person form.
    var heading: String {
        switch self {
        case .parent(let p): "Add \(p.firstName)'s parent"
        case .partner(let p): "Add \(p.firstName)'s partner"
        case .child(let p): "Add \(p.firstName)'s child"
        case .sibling(let p): "Add \(p.firstName)'s sibling"
        }
    }

    /// The relationship line on the review card, e.g. "Parent of Aryan".
    var relationshipDescription: String {
        switch self {
        case .parent(let p): "Parent of \(p.firstName)"
        case .partner(let p): "Partner of \(p.firstName)"
        case .child(let p): "Child of \(p.firstName)"
        case .sibling(let p): "Sibling of \(p.firstName)"
        }
    }
}
