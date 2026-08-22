// PersonSheetViewModel.swift
// Derives the relationship collections shown in the person sheet, plus the loaded
// profile image. Read-only over the graph — no writes, no SwiftUI import.

import Foundation
import UIKit

/// One of the focal person's partnerships, for the Dates card: the partner it's
/// with and the union that carries the anniversary. `startDate` is read live off the
/// union so an edit reflects on the next refresh without rebuilding the value.
struct Marriage: Identifiable {
    let partner: Person
    let union: Union
    /// The union's id — stable per relationship, so `.sheet(item:)`/ForEach are happy.
    var id: UUID { union.id }
    var startDate: PartialDate? { union.startDate }
}

@MainActor
@Observable
final class PersonSheetViewModel {
    private let graphService: GraphServiceProtocol
    private(set) var person: Person
    private(set) var parents: [Person] = []
    private(set) var partners: [Person] = []
    private(set) var children: [Person] = []
    private(set) var siblings: [Person] = []
    /// The focal person's partnerships, each pairing a partner with its union — the
    /// source of the "Married <partner>" rows and anniversary pills on the Dates card.
    private(set) var marriages: [Marriage] = []
    private(set) var profileImage: UIImage?

    init(person: Person, graphService: GraphServiceProtocol) {
        self.graphService = graphService
        self.person = person
        refresh()
    }

    /// Reloads every relationship collection around this person and the avatar image.
    func refresh() {
        parents = graphService.parents(of: person)
        partners = graphService.allPartners(of: person)
        children = graphService.children(of: person)
        siblings = graphService.siblings(of: person)
        marriages = graphService.partnerUnions(of: person).compactMap { union in
            // A union with no other partner yet (a lone-parent union) has no
            // marriage to show — skip it until a partner is actually named.
            guard let partner = graphService.partners(of: person, in: union).first else { return nil }
            return Marriage(partner: partner, union: union)
        }
        loadProfileImage()
    }

    /// The union type between the focal person and a partner of theirs — drives
    /// whether the Family row reads "Husband"/"Wife" or "Partner". Falls back to
    /// `.unknown` (sexed Husband/Wife) when no shared partner union is found.
    func partnerUnionType(with relative: Person) -> UnionType {
        marriages.first { $0.partner.id == relative.id }?.union.type ?? .unknown
    }

    /// Loads the current profile photo off the main thread, clearing it when the
    /// person has no photos.
    private func loadProfileImage() {
        guard let filename = person.profilePhoto?.filename else {
            profileImage = nil
            return
        }
        Task { [weak self] in
            // The disk read is off-main; the assignment hops back to the MainActor
            // (this Task inherits the VM's isolation).
            let image = await Task.detached(priority: .userInitiated) {
                PhotoStorageService.load(filename: filename)
            }.value
            // Ignore a stale load: a newer refresh() may have changed the profile
            // photo while this read was in flight — don't paint the old image over it.
            guard let self, self.person.profilePhoto?.filename == filename else { return }
            self.profileImage = image
        }
    }
}
