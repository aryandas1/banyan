// SharedTreeImporterTests.swift
// The @MainActor importer that applies a pulled snapshot to SwiftData, against an
// in-memory container built inline per test. Covers insert, idempotent re-import
// (upsert-by-id), relationship wiring, and dangling-link skipping.

import Foundation
import SwiftData
import Testing
import UIKit
@testable import Banyan

@MainActor
@Suite("SharedTreeImporter")
struct SharedTreeImporterTests {

    // MARK: - Fixtures

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Schema(BanyanSchemaV2.models), configurations: config)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private func personDTO(_ id: UUID, treeId: UUID, first: String = "A", placeholder: Bool = false) -> PersonDTO {
        SharedTreeDTOFactory.person(id: id, treeId: treeId, first: first, placeholder: placeholder)
    }

    private func unionDTO(_ id: UUID, treeId: UUID) -> UnionDTO {
        SharedTreeDTOFactory.union(id: id, treeId: treeId)
    }

    private func linkDTO(_ id: UUID, treeId: UUID, person: UUID, union: UUID, role: LinkRole) -> PersonUnionLinkDTO {
        SharedTreeDTOFactory.link(id: id, treeId: treeId, personId: person, unionId: union, role: role)
    }

    /// A couple + one child snapshot.
    private func familySnapshot(treeId: UUID) -> (SharedTreeSnapshot, parent: UUID, child: UUID) {
        let parent = UUID(), partner = UUID(), child = UUID(), union = UUID()
        let snapshot = SharedTreeSnapshot(
            persons: [personDTO(parent, treeId: treeId, first: "Parent"),
                      personDTO(partner, treeId: treeId, first: "Partner"),
                      personDTO(child, treeId: treeId, first: "Child")],
            unions: [unionDTO(union, treeId: treeId)],
            links: [linkDTO(UUID(), treeId: treeId, person: parent, union: union, role: .partner),
                    linkDTO(UUID(), treeId: treeId, person: partner, union: union, role: .partner),
                    linkDTO(UUID(), treeId: treeId, person: child, union: union, role: .child)]
        )
        return (snapshot, parent, child)
    }

    /// A few bytes of a real JPEG so PhotoStorageService.save/UIImage(data:) work.
    private func makeImageData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        let image = renderer.image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }

    /// A PhotoPayload for `personId`, deriving its DTO the production way.
    private func photoPayload(treeId: UUID, personId: UUID, caption: String? = nil, data: Data?) -> PhotoPayload {
        let model = PersonPhoto(treeId: treeId, personId: personId, filename: "", caption: caption)
        return PhotoPayload(dto: PersonPhotoDTO(from: model), imageData: data)
    }

    // MARK: - Tests

    @Test func importsPersonsUnionsAndLinks() throws {
        // Given an empty store and a family snapshot
        let context = try makeContext()
        let treeId = UUID()
        let (snapshot, _, _) = familySnapshot(treeId: treeId)

        // When importing
        _ = try SharedTreeImporter().importTree(snapshot, treeId: treeId, into: context)

        // Then all rows landed with their ids preserved
        #expect(try context.fetch(FetchDescriptor<Person>()).count == 3)
        #expect(try context.fetch(FetchDescriptor<Union>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<PersonUnionLink>()).count == 3)
    }

    @Test func wiresLinkRelationships() throws {
        let context = try makeContext()
        let treeId = UUID()
        let (snapshot, _, child) = familySnapshot(treeId: treeId)

        _ = try SharedTreeImporter().importTree(snapshot, treeId: treeId, into: context)

        // The child's link points at both a person and a union
        let childId = child
        let childPerson = try #require(
            try context.fetch(FetchDescriptor<Person>(predicate: #Predicate { $0.id == childId })).first
        )
        let childLink = try #require(childPerson.links.first)
        #expect(childLink.role == .child)
        #expect(childLink.union != nil)
    }

    @Test func reimportIsIdempotentAndUpdatesFields() throws {
        // Given a tree already imported once
        let context = try makeContext()
        let treeId = UUID()
        let (snapshot, parent, _) = familySnapshot(treeId: treeId)
        _ = try SharedTreeImporter().importTree(snapshot, treeId: treeId, into: context)

        // When the parent's name changes remotely and we re-import
        let renamed = SharedTreeSnapshot(
            persons: snapshot.persons.map { dto in
                dto.id == parent ? personDTO(parent, treeId: treeId, first: "Renamed") : dto
            },
            unions: snapshot.unions,
            links: snapshot.links
        )
        _ = try SharedTreeImporter().importTree(renamed, treeId: treeId, into: context)

        // Then no rows duplicated and the field updated in place
        #expect(try context.fetch(FetchDescriptor<Person>()).count == 3)
        #expect(try context.fetch(FetchDescriptor<PersonUnionLink>()).count == 3)
        let parentId = parent
        let parentPerson = try #require(
            try context.fetch(FetchDescriptor<Person>(predicate: #Predicate { $0.id == parentId })).first
        )
        #expect(parentPerson.firstName == "Renamed")
    }

    @Test func skipsLinkWithMissingEndpoints() throws {
        // Given a link that references a person not present in the snapshot
        let context = try makeContext()
        let treeId = UUID()
        let realPerson = UUID(), union = UUID(), ghost = UUID()
        let snapshot = SharedTreeSnapshot(
            persons: [personDTO(realPerson, treeId: treeId)],
            unions: [unionDTO(union, treeId: treeId)],
            links: [linkDTO(UUID(), treeId: treeId, person: ghost, union: union, role: .partner)]
        )

        // When importing
        _ = try SharedTreeImporter().importTree(snapshot, treeId: treeId, into: context)

        // Then the dangling link is skipped
        #expect(try context.fetch(FetchDescriptor<PersonUnionLink>()).isEmpty)
    }

    @Test func returnsChosenRoot() throws {
        let context = try makeContext()
        let treeId = UUID()
        let (snapshot, parent, child) = familySnapshot(treeId: treeId)

        let root = try SharedTreeImporter().importTree(snapshot, treeId: treeId, into: context)

        // Root is a top ancestor with descendants — never the child
        #expect(root != child)
        #expect(root == parent || root == snapshot.persons[1].id) // parent or partner
    }

    @Test func returnsNilRootForEmptySnapshot() throws {
        // Given an empty pull (owner hadn't synced yet when the viewer accepted)
        let context = try makeContext()
        let treeId = UUID()

        // When importing nothing
        let root = try SharedTreeImporter().importTree(
            SharedTreeSnapshot(persons: [], unions: [], links: []),
            treeId: treeId, into: context)

        // Then there's no focal to store — the viewer sees "No tree yet"
        #expect(root == nil)
    }

    /// The accept-before-sync self-heal: a viewer accepts before the owner has
    /// synced (empty pull ⇒ nil root stored), then the owner syncs and the viewer
    /// re-pulls. Mirrors the calls MainTabView.refreshSharedTree makes — importer
    /// returns the recomputed root, which is persisted because none was stored.
    @Test func refreshPersistsRootWhenAcceptStoredNone() throws {
        // Given a viewer that accepted an empty tree (nil root persisted)
        let context = try makeContext()
        let defaults = UserDefaults(suiteName: "ImporterRefreshTests-\(UUID().uuidString)")!
        let store = ViewerStore(defaults: defaults)
        let treeId = UUID()

        let emptyRoot = try SharedTreeImporter().importTree(
            SharedTreeSnapshot(persons: [], unions: [], links: []),
            treeId: treeId, into: context)
        store.addViewerTree(treeId, rootPersonId: emptyRoot)   // nil ⇒ no root stored
        #expect(store.rootPersonId(forTree: treeId) == nil)

        // When the owner later syncs and the viewer re-pulls a populated tree
        let (snapshot, _, child) = familySnapshot(treeId: treeId)
        let importedRoot = try SharedTreeImporter().importTree(snapshot, treeId: treeId, into: context)
        if let importedRoot, store.rootPersonId(forTree: treeId) == nil {
            store.addViewerTree(treeId, rootPersonId: importedRoot)
        }

        // Then the recomputed root is persisted (state self-heals across relaunch)
        let healed = try #require(store.rootPersonId(forTree: treeId))
        #expect(healed == importedRoot)
        #expect(healed != child)   // never the child
    }

    // MARK: - Orphan pruning (re-pull reflects the owner's deletions)

    @Test func removesPersonDeletedFromSnapshot() throws {
        // Given a family already imported once
        let context = try makeContext()
        let treeId = UUID()
        let (snapshot, _, child) = familySnapshot(treeId: treeId)
        _ = try SharedTreeImporter().importTree(snapshot, treeId: treeId, into: context)

        // When the owner deletes the child and the viewer re-pulls (child + its link gone)
        let withoutChild = SharedTreeSnapshot(
            persons: snapshot.persons.filter { $0.id != child },
            unions: snapshot.unions,
            links: snapshot.links.filter { $0.personId != child }
        )
        _ = try SharedTreeImporter().importTree(withoutChild, treeId: treeId, into: context)

        // Then the child (and its cascaded link) are gone — no ghost rows
        let childId = child
        #expect(try context.fetch(
            FetchDescriptor<Person>(predicate: #Predicate { $0.id == childId })
        ).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Person>()).count == 2)
        #expect(try context.fetch(FetchDescriptor<PersonUnionLink>()).count == 2)
    }

    @Test func removesUnlinkedLinkWhenEndpointsSurvive() throws {
        // Given a family already imported once
        let context = try makeContext()
        let treeId = UUID()
        let (snapshot, _, child) = familySnapshot(treeId: treeId)
        _ = try SharedTreeImporter().importTree(snapshot, treeId: treeId, into: context)

        // When the owner unlinks the child but the child stays in the tree
        let unlinked = SharedTreeSnapshot(
            persons: snapshot.persons,
            unions: snapshot.unions,
            links: snapshot.links.filter { $0.personId != child }
        )
        _ = try SharedTreeImporter().importTree(unlinked, treeId: treeId, into: context)

        // Then only the removed link is pruned; all three people remain
        #expect(try context.fetch(FetchDescriptor<Person>()).count == 3)
        #expect(try context.fetch(FetchDescriptor<PersonUnionLink>()).count == 2)
    }

    // MARK: - Photos

    @Test func importsPhotoSavingBytesAndWiringToPerson() throws {
        // Given a person and one pulled photo carrying bytes
        let context = try makeContext()
        let treeId = UUID(), personId = UUID()
        let payload = photoPayload(treeId: treeId, personId: personId, caption: "Wedding", data: makeImageData())
        let snapshot = SharedTreeSnapshot(
            persons: [personDTO(personId, treeId: treeId, first: "Ravi")],
            unions: [], links: [], photos: [payload]
        )

        // When importing
        _ = try SharedTreeImporter().importTree(snapshot, treeId: treeId, into: context)

        // Then the photo lands with a local file, its storage path, and its person
        let photos = try context.fetch(FetchDescriptor<PersonPhoto>())
        #expect(photos.count == 1)
        let photo = try #require(photos.first)
        #expect(photo.id == payload.dto.id)
        #expect(photo.caption == "Wedding")
        #expect(!photo.filename.isEmpty)                                  // bytes written to disk
        #expect(PhotoStorageService.load(filename: photo.filename) != nil)
        #expect(photo.supabaseStoragePath == payload.dto.storagePath)
        #expect(photo.person?.id == personId)                            // inverse wired
        let personId2 = personId
        let person = try #require(try context.fetch(
            FetchDescriptor<Person>(predicate: #Predicate { $0.id == personId2 })).first)
        #expect(person.photos.count == 1)
        PhotoStorageService.delete(filename: photo.filename)
    }

    @Test func reimportUpdatesPhotoMetadataWithoutDuplicating() throws {
        // Given a photo imported once
        let context = try makeContext()
        let treeId = UUID(), personId = UUID()
        let data = makeImageData()
        let first = photoPayload(treeId: treeId, personId: personId, caption: "Old", data: data)
        let persons = [personDTO(personId, treeId: treeId, first: "Ravi")]
        _ = try SharedTreeImporter().importTree(
            SharedTreeSnapshot(persons: persons, unions: [], links: [], photos: [first]),
            treeId: treeId, into: context)

        // When the caption changes remotely (same id) and no bytes are re-sent
        let updatedDTO = PersonPhotoDTO(from: PersonPhoto(
            id: first.dto.id, treeId: treeId, personId: personId, filename: "", caption: "New"))
        _ = try SharedTreeImporter().importTree(
            SharedTreeSnapshot(persons: persons, unions: [], links: [],
                               photos: [PhotoPayload(dto: updatedDTO, imageData: nil)]),
            treeId: treeId, into: context)

        // Then the row updated in place — no duplicate, file preserved
        let photos = try context.fetch(FetchDescriptor<PersonPhoto>())
        #expect(photos.count == 1)
        let photo = try #require(photos.first)
        #expect(photo.caption == "New")
        #expect(!photo.filename.isEmpty)
        #expect(PhotoStorageService.load(filename: photo.filename) != nil)
        PhotoStorageService.delete(filename: photo.filename)
    }

    @Test func prunesPhotoRemovedFromSnapshotAndDeletesFile() throws {
        // Given a person with a photo imported once
        let context = try makeContext()
        let treeId = UUID(), personId = UUID()
        let payload = photoPayload(treeId: treeId, personId: personId, data: makeImageData())
        let persons = [personDTO(personId, treeId: treeId, first: "Ravi")]
        _ = try SharedTreeImporter().importTree(
            SharedTreeSnapshot(persons: persons, unions: [], links: [], photos: [payload]),
            treeId: treeId, into: context)
        let saved = try #require(try context.fetch(FetchDescriptor<PersonPhoto>()).first)
        let filename = saved.filename
        #expect(PhotoStorageService.load(filename: filename) != nil)

        // When the owner deletes the photo (person survives) and the viewer re-pulls
        _ = try SharedTreeImporter().importTree(
            SharedTreeSnapshot(persons: persons, unions: [], links: [], photos: []),
            treeId: treeId, into: context)

        // Then the row is gone and its local file was removed
        #expect(try context.fetch(FetchDescriptor<PersonPhoto>()).isEmpty)
        #expect(PhotoStorageService.load(filename: filename) == nil)
    }

    @Test func prunesPhotoFileWhenOwnerDeletesThePerson() throws {
        // Given a person with a downloaded photo imported once
        let context = try makeContext()
        let treeId = UUID(), personId = UUID()
        let payload = photoPayload(treeId: treeId, personId: personId, data: makeImageData())
        _ = try SharedTreeImporter().importTree(
            SharedTreeSnapshot(persons: [personDTO(personId, treeId: treeId, first: "Ravi")],
                               unions: [], links: [], photos: [payload]),
            treeId: treeId, into: context)
        let saved = try #require(try context.fetch(FetchDescriptor<PersonPhoto>()).first)
        let filename = saved.filename
        #expect(PhotoStorageService.load(filename: filename) != nil)

        // When the owner deletes the whole person and the viewer re-pulls empty
        _ = try SharedTreeImporter().importTree(
            SharedTreeSnapshot(persons: [], unions: [], links: [], photos: []),
            treeId: treeId, into: context)

        // Then the person + photo row cascade away AND the local file is not leaked
        #expect(try context.fetch(FetchDescriptor<Person>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PersonPhoto>()).isEmpty)
        #expect(PhotoStorageService.load(filename: filename) == nil)
    }

    @Test func pruneIsScopedToTheImportedTree() throws {
        // Given tree A already imported
        let context = try makeContext()
        let treeA = UUID(), treeB = UUID()
        let (snapA, _, _) = familySnapshot(treeId: treeA)
        _ = try SharedTreeImporter().importTree(snapA, treeId: treeA, into: context)

        // When importing an unrelated tree B
        let (snapB, _, _) = familySnapshot(treeId: treeB)
        _ = try SharedTreeImporter().importTree(snapB, treeId: treeB, into: context)

        // Then tree A's rows are untouched by tree B's prune pass
        let a = treeA
        #expect(try context.fetch(
            FetchDescriptor<Person>(predicate: #Predicate { $0.treeId == a })
        ).count == 3)
        #expect(try context.fetch(FetchDescriptor<Person>()).count == 6)
    }
}
