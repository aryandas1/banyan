// PersonSheetViewModel.swift
// Derives the relationship collections shown in the person sheet, plus the loaded
// profile image. Read-only over the graph — no writes, no SwiftUI import.

import Foundation
import UIKit

@MainActor
@Observable
final class PersonSheetViewModel {
    private let graphService: GraphServiceProtocol
    private(set) var person: Person
    private(set) var parents: [Person] = []
    private(set) var partners: [Person] = []
    private(set) var children: [Person] = []
    private(set) var siblings: [Person] = []
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
        loadProfileImage()
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
