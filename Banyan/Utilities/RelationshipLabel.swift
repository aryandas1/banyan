// RelationshipLabel.swift
// Derives a human-readable relationship label from the tree owner to any person,
// in a relational / Indian-family style (e.g. a parent's cousin — and their spouse —
// reads as "Uncle"/"Aunty", not "first cousin once removed"). A pure value type —
// no SwiftUI, no SwiftData. It reads the graph only through GraphServiceProtocol.
//
// How it works: the blood relationship is derived from the CLOSEST COMMON ANCESTOR
// of the two people — the generations up from each side (a, b) fully determine the
// kinship (parent/grandparent, aunt/uncle, cousin, niece/nephew, …). Collateral
// relations then collapse by *generation gap* rather than cousin-degree: anyone an
// older generation across is Uncle/Aunty, the same generation is a cousin, a younger
// generation is Niece/Nephew. Spouses are handled by a final in-law pass.

import Foundation

struct RelationshipLabel {

    /// The label from `owner` to `target` — "You", a blood/relational term, an
    /// in-law term, or "Extended family" when no relation is found.
    static func label(
        from owner: Person,
        to target: Person,
        using graph: GraphServiceProtocol
    ) -> String {
        if owner.id == target.id { return "You" }

        // A direct spouse is named first (they may also be a distant blood relative).
        if graph.allPartners(of: owner).contains(where: { $0.id == target.id }) {
            return sexed(male: "Husband", female: "Wife", unknown: "Partner", target.sex)
        }

        // 1) Blood / relational path via the closest common ancestor.
        if let kin = bloodKinship(from: owner, to: target, using: graph) {
            return render(kin, sex: target.sex)
        }

        // 2) In-law: the target is the spouse of a blood relative of the owner
        //    (e.g. a parent's cousin's husband → "Uncle").
        for spouseOf in graph.allPartners(of: target) {
            if let kin = bloodKinship(from: owner, to: spouseOf, using: graph),
               let label = inLawSpouseOf(kin, spouseSex: target.sex) {
                return label
            }
        }

        // 3) In-law: the target is a blood relative of the owner's spouse
        //    (e.g. a spouse's brother → "Brother-in-law").
        for spouse in graph.allPartners(of: owner) {
            if let kin = bloodKinship(from: spouse, to: target, using: graph),
               let label = inLawViaSpouse(kin, sex: target.sex) {
                return label
            }
        }

        return "Extended family"
    }

    // MARK: - Blood kinship

    /// A blood relationship, reduced to what drives its label.
    private enum Kinship {
        case samePerson
        case ancestor(Int)          // generations up (1 = parent)
        case descendant(Int)        // generations down (1 = child)
        case sibling
        case olderCollateral(Int)   // generation gap ≥ 1 (1 = aunt/uncle)
        case youngerCollateral(Int) // generation gap ≥ 1 (1 = niece/nephew)
        case cousin                 // same generation, degree ignored (relational style)
    }

    /// How far up to walk when collecting ancestors. Bounds cost and stops absurdly
    /// distant links from being claimed as close kin.
    private static let maxGenerations = 6

    /// A node in the ancestor search. Sibling groups recorded WITHOUT known parents
    /// still share a union, so they're bridged by a synthetic group node — kept in
    /// its own case so it can never collide with a real person id.
    private enum AncestorKey: Hashable {
        case person(UUID)
        case siblingGroup(UUID)   // representative = the group's minimum member id
    }

    /// Generations from `person` up to each reachable ancestor (person itself = 0).
    private static func ancestorDistances(
        of person: Person,
        using graph: GraphServiceProtocol
    ) -> [AncestorKey: Int] {
        var distance: [AncestorKey: Int] = [.person(person.id): 0]
        var frontier: [Person] = [person]
        var generation = 0

        while !frontier.isEmpty && generation < maxGenerations {
            generation += 1
            var next: [Person] = []
            for p in frontier {
                let parents = graph.parents(of: p)
                if parents.isEmpty {
                    // No recorded parents — bridge any parentless sibling group so
                    // siblings still meet at a shared ancestor one generation up.
                    let siblings = graph.siblings(of: p)
                    // UUID isn't Comparable — order by uuidString for a stable
                    // representative that every group member computes identically.
                    if !siblings.isEmpty,
                       let groupId = ([p.id] + siblings.map(\.id)).min(by: { $0.uuidString < $1.uuidString }) {
                        let key = AncestorKey.siblingGroup(groupId)
                        if distance[key] == nil { distance[key] = generation }
                    }
                } else {
                    for parent in parents where distance[.person(parent.id)] == nil {
                        distance[.person(parent.id)] = generation
                        next.append(parent)
                    }
                }
            }
            frontier = next
        }
        return distance
    }

    /// The blood kinship between two people, or nil when they share no ancestor
    /// within `maxGenerations`.
    private static func bloodKinship(
        from owner: Person,
        to target: Person,
        using graph: GraphServiceProtocol
    ) -> Kinship? {
        let distOwner = ancestorDistances(of: owner, using: graph)
        let distTarget = ancestorDistances(of: target, using: graph)

        // The closest common ancestor minimises (a + b); that pair fixes the kinship.
        var best: (a: Int, b: Int)?
        for (key, a) in distOwner {
            guard let b = distTarget[key] else { continue }
            if best == nil || (a + b) < (best!.a + best!.b) { best = (a, b) }
        }
        guard let (a, b) = best else { return nil }
        return classify(a: a, b: b)
    }

    /// Maps generations-up-from-each-side to a kinship. `a` is the owner's distance
    /// to the common ancestor, `b` the target's.
    private static func classify(a: Int, b: Int) -> Kinship {
        if a == 0 && b == 0 { return .samePerson }
        if a == 0 { return .descendant(b) }   // owner is the ancestor
        if b == 0 { return .ancestor(a) }     // target is the ancestor
        if a == 1 && b == 1 { return .sibling }
        let gap = a - b                        // > 0 ⇒ target an older generation
        if gap == 0 { return .cousin }
        return gap > 0 ? .olderCollateral(gap) : .youngerCollateral(-gap)
    }

    // MARK: - Rendering

    private static func render(_ kin: Kinship, sex: Sex) -> String {
        switch kin {
        case .samePerson:            return "You"
        case .ancestor(let n):       return ancestorLabel(n, sex: sex)
        case .descendant(let n):     return descendantLabel(n, sex: sex)
        case .sibling:               return sexed(male: "Brother", female: "Sister", unknown: "Sibling", sex)
        case .olderCollateral(let g):   return olderCollateralLabel(g, sex: sex)
        case .youngerCollateral(let g): return youngerCollateralLabel(g, sex: sex)
        case .cousin:                return sexed(male: "Cousin-brother", female: "Cousin-sister", unknown: "Cousin", sex)
        }
    }

    private static func ancestorLabel(_ n: Int, sex: Sex) -> String {
        switch n {
        case 1: return sexed(male: "Father", female: "Mother", unknown: "Parent", sex)
        case 2: return sexed(male: "Grandfather", female: "Grandmother", unknown: "Grandparent", sex)
        default:
            return greatPrefix(n - 2) + sexed(male: "grandfather", female: "grandmother", unknown: "grandparent", sex)
        }
    }

    private static func descendantLabel(_ n: Int, sex: Sex) -> String {
        switch n {
        case 1: return sexed(male: "Son", female: "Daughter", unknown: "Child", sex)
        case 2: return sexed(male: "Grandson", female: "Granddaughter", unknown: "Grandchild", sex)
        default:
            return greatPrefix(n - 2) + sexed(male: "grandson", female: "granddaughter", unknown: "grandchild", sex)
        }
    }

    private static func olderCollateralLabel(_ g: Int, sex: Sex) -> String {
        switch g {
        case 1: return sexed(male: "Uncle", female: "Aunty", unknown: "Uncle or aunty", sex)
        case 2: return sexed(male: "Grand-uncle", female: "Grand-aunty", unknown: "Grand-uncle or aunty", sex)
        default:
            return greatPrefix(g - 2) + sexed(male: "grand-uncle", female: "grand-aunty", unknown: "grand-uncle or aunty", sex)
        }
    }

    private static func youngerCollateralLabel(_ g: Int, sex: Sex) -> String {
        switch g {
        case 1: return sexed(male: "Nephew", female: "Niece", unknown: "Niece or nephew", sex)
        case 2: return sexed(male: "Grand-nephew", female: "Grand-niece", unknown: "Grand-niece or nephew", sex)
        default:
            return greatPrefix(g - 2) + sexed(male: "grand-nephew", female: "grand-niece", unknown: "grand-niece or nephew", sex)
        }
    }

    // MARK: - In-laws

    /// The target is the spouse of a blood relative whose kinship to the owner is
    /// `kin`. Relational style: an aunt's husband is an Uncle, a sibling's spouse is
    /// a brother/sister-in-law, and so on. Nil for relations too distant to name.
    private static func inLawSpouseOf(_ kin: Kinship, spouseSex: Sex) -> String? {
        switch kin {
        case .sibling, .cousin:
            return sexed(male: "Brother-in-law", female: "Sister-in-law", unknown: "Sibling-in-law", spouseSex)
        case .olderCollateral(let g):
            return olderCollateralLabel(g, sex: spouseSex)      // aunt's husband → Uncle
        case .youngerCollateral(let g):
            return youngerCollateralLabel(g, sex: spouseSex)    // niece's husband → Nephew
        case .descendant(1):
            return sexed(male: "Son-in-law", female: "Daughter-in-law", unknown: "Child-in-law", spouseSex)
        case .ancestor(1):
            return sexed(male: "Step-father", female: "Step-mother", unknown: "Step-parent", spouseSex)
        default:
            return nil
        }
    }

    /// The target is a blood relative of the owner's spouse, with kinship `kin` from
    /// the spouse. A spouse's parent is a parent-in-law, their sibling a sibling-in-law,
    /// their uncle still an Uncle. Nil for relations too distant to name.
    private static func inLawViaSpouse(_ kin: Kinship, sex: Sex) -> String? {
        switch kin {
        case .ancestor(1):
            return sexed(male: "Father-in-law", female: "Mother-in-law", unknown: "Parent-in-law", sex)
        case .ancestor(let n):
            return ancestorLabel(n, sex: sex) + "-in-law"
        case .sibling, .cousin:
            return sexed(male: "Brother-in-law", female: "Sister-in-law", unknown: "Sibling-in-law", sex)
        case .olderCollateral(let g):
            return olderCollateralLabel(g, sex: sex)            // spouse's uncle → Uncle
        case .youngerCollateral(let g):
            return youngerCollateralLabel(g, sex: sex)
        case .descendant(1):
            return sexed(male: "Step-son", female: "Step-daughter", unknown: "Step-child", sex)
        default:
            return nil
        }
    }

    // MARK: - Helpers

    private static func sexed(male: String, female: String, unknown: String, _ sex: Sex) -> String {
        switch sex {
        case .male:    return male
        case .female:  return female
        case .unknown: return unknown
        }
    }

    /// `count` repetitions of "great-", capitalised — e.g. 1 → "Great-", 2 → "Great-great-".
    private static func greatPrefix(_ count: Int) -> String {
        let greats = String(repeating: "great-", count: max(1, count))
        return greats.prefix(1).uppercased() + greats.dropFirst()
    }
}
