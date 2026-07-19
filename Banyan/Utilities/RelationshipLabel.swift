// RelationshipLabel.swift
// Derives a human-readable relationship label from the tree owner to any person.
// A pure value type — no SwiftUI, no SwiftData. It reads the graph only through
// GraphServiceProtocol and takes already-fetched Person values.

import Foundation

/// Derives a human-readable relationship label between two people in the graph.
/// Performs a BFS from `owner` to `target` across parent, child, and partner edges,
/// capped at depth 3. Returns "Extended family" when no path is found within that depth.
struct RelationshipLabel {

    /// One hop along a BFS path, tagged with the person reached so their sex can be read.
    private enum Step {
        case toParent(Person)
        case toChild(Person)
        case toPartner(Person)
    }

    /// The label from `owner` to `target` — e.g. "Father", "Grandmother", "Parent's partner".
    /// Returns "You" when they are the same person and "Extended family" when there is no
    /// path within depth 3.
    static func label(
        from owner: Person,
        to target: Person,
        using graphService: GraphServiceProtocol
    ) -> String {
        // Seed `visited` with the owner so the BFS never re-labels them as the target, and so
        // cross-branch cycles terminate. Marking each node visited as it is enqueued means the
        // first path found to any node is the shortest, so labels reflect the closest relation.
        var visited: Set<UUID> = [owner.id]
        var queue: [(person: Person, path: [Step])] = [(owner, [])]
        var head = 0

        while head < queue.count {
            let (person, path) = queue[head]
            head += 1

            if person.id == target.id { return labelString(for: path) }
            if path.count >= 3 { continue }   // depth cap — don't expand further

            for parent in graphService.parents(of: person) {
                guard visited.insert(parent.id).inserted else { continue }
                queue.append((parent, path + [.toParent(parent)]))
            }
            for child in graphService.children(of: person) {
                guard visited.insert(child.id).inserted else { continue }
                queue.append((child, path + [.toChild(child)]))
            }
            for partner in graphService.allPartners(of: person) {
                guard visited.insert(partner.id).inserted else { continue }
                queue.append((partner, path + [.toPartner(partner)]))
            }
        }

        return "Extended family"
    }

    // MARK: - Labelling

    /// Turns a path of steps into a display label. An empty path means the owner themselves.
    private static func labelString(for path: [Step]) -> String {
        switch path.count {
        case 0:
            return "You"
        case 1:
            return capitalizedFirst(stepLabel(path[0]))
        case 2:
            return depthTwoLabel(path[0], path[1])
        default:
            return capitalizedFirst(path.map(stepLabel).joined(separator: "'s "))
        }
    }

    /// Named labels for the common two-hop relationships; other combinations fall back
    /// to concatenating the two step fragments (e.g. "Child's partner").
    private static func depthTwoLabel(_ first: Step, _ second: Step) -> String {
        switch (first, second) {
        case (.toParent, .toParent(let p)):
            return sexed(male: "Grandfather", female: "Grandmother", unknown: "Grandparent", of: p)
        case (.toParent, .toChild(let p)):
            return sexed(male: "Brother", female: "Sister", unknown: "Sibling", of: p)
        case (.toChild, .toChild(let p)):
            return sexed(male: "Grandson", female: "Granddaughter", unknown: "Grandchild", of: p)
        case (.toParent, .toPartner):
            return "Parent's partner"
        case (.toPartner, .toChild):
            return "Partner's child"
        case (.toPartner, .toParent):
            return "Partner's parent"
        default:
            return capitalizedFirst(stepLabel(first) + "'s " + stepLabel(second))
        }
    }

    /// A single hop as a lowercase fragment, for concatenation. Only the final label is
    /// capitalised, so these stay lowercase.
    private static func stepLabel(_ step: Step) -> String {
        switch step {
        case .toParent(let p):
            return sexed(male: "father", female: "mother", unknown: "parent", of: p)
        case .toChild(let p):
            return sexed(male: "son", female: "daughter", unknown: "child", of: p)
        case .toPartner:
            return "partner"
        }
    }

    private static func sexed(male: String, female: String, unknown: String, of person: Person) -> String {
        switch person.sex {
        case .male: return male
        case .female: return female
        case .unknown: return unknown
        }
    }

    private static func capitalizedFirst(_ string: String) -> String {
        guard let first = string.first else { return string }
        return first.uppercased() + string.dropFirst()
    }
}
