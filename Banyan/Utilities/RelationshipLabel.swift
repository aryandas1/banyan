// RelationshipLabel.swift
// Derives a human-readable relationship label from the tree owner to any person.
// A pure value type — no SwiftUI, no SwiftData. It reads the graph only through
// GraphServiceProtocol and takes already-fetched Person values.

import Foundation

/// Derives a human-readable relationship label between two people in the graph.
/// Performs a BFS from `owner` to `target` across parent, child, partner, and
/// sibling edges, capped at depth 4. The sibling edge matters because sibling
/// groups can be recorded with unknown parents (a partnerless union): without it,
/// those siblings — and the aunts/uncles/cousins hanging off them — would have no
/// path up through a shared parent and would read as "Extended family".
/// Returns "Extended family" for anyone with no recognized path within that depth.
struct RelationshipLabel {

    /// One hop along a BFS path, tagged with the person reached so their sex can be read.
    private enum Step {
        case toParent(Person)
        case toChild(Person)
        case toPartner(Person)
        case toSibling(Person)
    }

    /// The label from `owner` to `target` — e.g. "Father", "Grandmother", "Parent's partner".
    /// Returns "You" when they are the same person and "Extended family" when there is no
    /// path within depth 4.
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
            if path.count >= 4 { continue }   // depth cap — don't expand further

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
            for sibling in graphService.siblings(of: person) {
                guard visited.insert(sibling.id).inserted else { continue }
                queue.append((sibling, path + [.toSibling(sibling)]))
            }
        }

        return "Extended family"
    }

    // MARK: - Labeling

    /// Turns a path of steps into a display label. An empty path means the owner themselves.
    private static func labelString(for path: [Step]) -> String {
        switch path.count {
        case 0:
            return "You"
        case 1:
            return capitalizedFirst(stepLabel(path[0]))
        case 2:
            return depthTwoLabel(path[0], path[1])
        case 3:
            return depthThreeLabel(path[0], path[1], path[2])
        case 4:
            return depthFourLabel(path[0], path[1], path[2], path[3])
        default:
            return "Extended family"
        }
    }

    /// Named labels for the common two-hop relationships; other combinations fall back
    /// to concatenating the two step fragments (e.g. "Child's partner").
    private static func depthTwoLabel(_ first: Step, _ second: Step) -> String {
        switch (first, second) {
        case (.toParent, .toParent(let p)):
            return sexed(male: "Grandfather", female: "Grandmother", unknown: "Grandparent", of: p)
        case (.toParent, .toChild(let p)):
            // A half-sibling reached through a shared parent (full siblings arrive
            // one hop away via the sibling edge).
            return sexed(male: "Brother", female: "Sister", unknown: "Sibling", of: p)
        case (.toParent, .toSibling(let p)):
            return sexed(male: "Uncle", female: "Aunt", unknown: "Aunt or uncle", of: p)
        case (.toSibling, .toChild(let p)):
            return sexed(male: "Nephew", female: "Niece", unknown: "Niece or nephew", of: p)
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

    /// Named labels for the common three-hop relationships. The first cousin — a
    /// parent's sibling's child — is named here (gender-neutral). Aunt/uncle and
    /// niece/nephew reappear at this depth for *half*-relations, where the linking
    /// sibling is only reachable through a shared parent rather than the sibling
    /// edge. Everything else concatenates (e.g. "Father's mother's parent").
    private static func depthThreeLabel(_ first: Step, _ second: Step, _ third: Step) -> String {
        switch (first, second, third) {
        case (.toParent, .toSibling, .toChild):
            return "Cousin"
        case (.toParent, .toParent, .toChild(let p)):
            return sexed(male: "Uncle", female: "Aunt", unknown: "Aunt or uncle", of: p)
        case (.toParent, .toChild, .toChild(let p)):
            return sexed(male: "Nephew", female: "Niece", unknown: "Niece or nephew", of: p)
        default:
            return capitalizedFirst([first, second, third].map(stepLabel).joined(separator: "'s "))
        }
    }

    /// The named four-hop relationship is a cousin reached through a *half*-sibling
    /// in the parent generation (the aunt/uncle shares only one grandparent, so the
    /// sibling edge doesn't apply and the path runs up through the grandparent).
    /// Cousin labels are gender-neutral. Every other four-hop path is too distant
    /// to name simply.
    private static func depthFourLabel(_ first: Step, _ second: Step, _ third: Step, _ fourth: Step) -> String {
        switch (first, second, third, fourth) {
        case (.toParent, .toParent, .toChild, .toChild):
            return "Cousin"
        default:
            return "Extended family"
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
        case .toSibling(let p):
            return sexed(male: "brother", female: "sister", unknown: "sibling", of: p)
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
