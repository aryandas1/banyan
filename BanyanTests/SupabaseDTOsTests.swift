// SupabaseDTOsTests.swift
// The Codable DTOs that map SwiftData models to Supabase JSON: field mapping,
// snake_case column keys, round-trips, and the failable link init.

import Foundation
import Testing
@testable import Banyan

@Suite("SupabaseDTOs")
struct SupabaseDTOsTests {

    // MARK: - Person

    @Test func personDTOMapsEveryField() throws {
        let treeId = UUID()
        let person = Person(
            treeId: treeId,
            firstName: "Ravi",
            lastName: "Das",
            sex: .female,
            birthDate: PartialDate(year: 1950, month: 3),
            deathDate: PartialDate(year: 2010),
            birthPlace: "Kolkata",
            deathPlace: "Delhi",
            isPlaceholder: false,
            bio: "A gardener."
        )

        let dto = PersonDTO(from: person)

        #expect(dto.id == person.id)
        #expect(dto.treeId == treeId)
        #expect(dto.firstName == "Ravi")
        #expect(dto.lastName == "Das")
        #expect(dto.sex == "female")
        #expect(dto.birthDate?.year == 1950)
        #expect(dto.birthDate?.month == 3)
        #expect(dto.deathDate?.year == 2010)
        #expect(dto.birthPlace == "Kolkata")
        #expect(dto.deathPlace == "Delhi")
        #expect(dto.isPlaceholder == false)
        #expect(dto.bio == "A gardener.")
    }

    @Test func personDTOEncodesSnakeCaseColumns() throws {
        let dto = PersonDTO(from: Person(treeId: UUID(), firstName: "A"))
        let json = String(decoding: try JSONEncoder().encode(dto), as: UTF8.self)

        #expect(json.contains("\"tree_id\""))
        #expect(json.contains("\"first_name\""))
        #expect(json.contains("\"last_name\""))
        #expect(json.contains("\"is_placeholder\""))
        #expect(!json.contains("\"treeId\""))
        #expect(!json.contains("\"firstName\""))
    }

    @Test func personDTORoundTrips() throws {
        let dto = PersonDTO(from: Person(
            treeId: UUID(), firstName: "A", lastName: "B",
            sex: .male, birthDate: PartialDate(year: 1990)
        ))
        let decoded = try JSONDecoder().decode(PersonDTO.self, from: JSONEncoder().encode(dto))
        #expect(decoded == dto)
    }

    // MARK: - Union

    @Test func unionDTOMapsFieldsAndSnakeCase() throws {
        let treeId = UUID()
        let union = Union(treeId: treeId, type: .married, endReason: .divorce)
        let dto = UnionDTO(from: union)

        #expect(dto.id == union.id)
        #expect(dto.treeId == treeId)
        #expect(dto.type == "married")
        #expect(dto.endReason == "divorce")

        let json = String(decoding: try JSONEncoder().encode(dto), as: UTF8.self)
        #expect(json.contains("\"tree_id\""))
        #expect(json.contains("\"end_reason\""))
    }

    // MARK: - PersonUnionLink

    @Test func linkDTODerivesTreeIdFromPersonAndMapsIds() throws {
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let person = builder.makePerson(firstName: "A", treeId: treeId)
        let union = builder.makeUnion(treeId: treeId)
        let link = builder.link(person: person, to: union, role: .child, childType: .biological)

        let dto = try #require(PersonUnionLinkDTO(from: link))

        #expect(dto.id == link.id)
        #expect(dto.treeId == treeId)          // derived from person, since the model has no treeId
        #expect(dto.personId == person.id)
        #expect(dto.unionId == union.id)
        #expect(dto.role == "child")
        #expect(dto.childType == "biological")

        let json = String(decoding: try JSONEncoder().encode(dto), as: UTF8.self)
        #expect(json.contains("\"person_id\""))
        #expect(json.contains("\"union_id\""))
        #expect(json.contains("\"child_type\""))
    }

    @Test func linkDTOIsNilWhenPersonOrUnionMissing() throws {
        // A dangling link (no person / union set) can't produce a valid row.
        let dangling = PersonUnionLink(role: .partner)
        #expect(PersonUnionLinkDTO(from: dangling) == nil)
    }

    // MARK: - Tree

    @Test func treeDTOEncodesOwnerIdSnakeCase() throws {
        let dto = TreeDTO(id: UUID(), name: "Family Tree", ownerId: UUID())
        let json = String(decoding: try JSONEncoder().encode(dto), as: UTF8.self)
        #expect(json.contains("\"owner_id\""))
        #expect(!json.contains("\"ownerId\""))
    }

    // MARK: - Invitation (insert)

    @Test func invitationInsertDTOEncodesSnakeCaseColumns() throws {
        let dto = InvitationInsertDTO(
            treeId: UUID(), invitedBy: UUID(), phoneNumber: "+91 98765 43210", token: "tok-123"
        )
        let json = String(decoding: try JSONEncoder().encode(dto), as: UTF8.self)

        #expect(json.contains("\"tree_id\""))
        #expect(json.contains("\"invited_by\""))
        #expect(json.contains("\"phone_number\""))
        #expect(json.contains("\"token\""))
        #expect(!json.contains("\"treeId\""))
        #expect(!json.contains("\"phoneNumber\""))
    }

    // MARK: - Invitation (read)

    @Test func invitationDTODecodesFromSupabaseRow() throws {
        // Mirrors a real PostgREST row (snake_case keys, ISO8601 timestamptz).
        let json = """
        {
          "id": "d3147425-e628-42d6-ae60-dcb11b5aa0db",
          "tree_id": "a872107d-b72e-4ba4-b3ba-884ecd1b40e8",
          "phone_number": "+1 555",
          "status": "pending",
          "token": "c88e65ce-ac81-4d9b-87bf-fe30bc522b4b",
          "created_at": "2026-08-03T00:08:25Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(InvitationDTO.self, from: Data(json.utf8))

        #expect(dto.id == UUID(uuidString: "d3147425-e628-42d6-ae60-dcb11b5aa0db"))
        #expect(dto.treeId == UUID(uuidString: "a872107d-b72e-4ba4-b3ba-884ecd1b40e8"))
        #expect(dto.phoneNumber == "+1 555")
        #expect(dto.status == "pending")
        #expect(dto.token == "c88e65ce-ac81-4d9b-87bf-fe30bc522b4b")
    }

    // MARK: - PersonPhoto

    @Test func personPhotoDTOMapsFieldsAndDerivesStoragePath() throws {
        let treeId = UUID(), personId = UUID()
        let photo = PersonPhoto(
            treeId: treeId, personId: personId, filename: "local.jpg",
            caption: "Wedding", takenYear: 1978, takenMonth: 6, takenPlace: "Pune",
            isProfilePhoto: true, sortOrder: 2
        )
        let dto = PersonPhotoDTO(from: photo)

        #expect(dto.id == photo.id)
        #expect(dto.treeId == treeId)
        #expect(dto.personId == personId)
        #expect(dto.caption == "Wedding")
        #expect(dto.takenYear == 1978)
        #expect(dto.takenMonth == 6)
        #expect(dto.takenPlace == "Pune")
        #expect(dto.isProfilePhoto)
        #expect(dto.sortOrder == 2)
        // Path is derived from the ids, not the local filename.
        #expect(dto.storagePath == "\(treeId.uuidString)/\(personId.uuidString)/\(photo.id.uuidString).jpg")
        #expect(dto.storagePath == PersonPhotoDTO.storagePath(treeId: treeId, personId: personId, photoId: photo.id))
    }

    @Test func personPhotoDTOEncodesSnakeCaseColumns() throws {
        // Populate the optionals so encodeIfPresent emits their keys.
        let dto = PersonPhotoDTO(from: PersonPhoto(
            treeId: UUID(), personId: UUID(), filename: "x.jpg",
            caption: "c", takenYear: 1990, takenMonth: 6, takenPlace: "p"
        ))
        let json = String(decoding: try JSONEncoder().encode(dto), as: UTF8.self)

        #expect(json.contains("\"tree_id\""))
        #expect(json.contains("\"person_id\""))
        #expect(json.contains("\"storage_path\""))
        #expect(json.contains("\"taken_year\""))
        #expect(json.contains("\"is_profile_photo\""))
        #expect(json.contains("\"sort_order\""))
        #expect(!json.contains("\"treeId\""))
        #expect(!json.contains("\"storagePath\""))
    }

    @Test func personPhotoDTORoundTrips() throws {
        let dto = PersonPhotoDTO(from: PersonPhoto(
            treeId: UUID(), personId: UUID(), filename: "x.jpg",
            caption: "c", takenYear: 1990, takenMonth: 12, takenPlace: "p",
            isProfilePhoto: false, sortOrder: 3
        ))
        let decoded = try JSONDecoder().decode(PersonPhotoDTO.self, from: JSONEncoder().encode(dto))
        #expect(decoded == dto)
    }

    // MARK: - Viewer label

    @Test func viewerDTOLabelPrefersDisplayName() {
        let viewer = ViewerDTO(
            id: UUID(), displayName: "Asha", invitationPhoneNumber: "+1 555", joinedAt: .now
        )
        #expect(viewer.label == "Asha")
    }

    @Test func viewerDTOLabelFallsBackToPhoneThenGeneric() {
        let phoneOnly = ViewerDTO(
            id: UUID(), displayName: nil, invitationPhoneNumber: "+1 555", joinedAt: .now
        )
        #expect(phoneOnly.label == "+1 555")

        let emptyName = ViewerDTO(
            id: UUID(), displayName: "", invitationPhoneNumber: nil, joinedAt: .now
        )
        #expect(emptyName.label == "Family member")

        let nothing = ViewerDTO(
            id: UUID(), displayName: nil, invitationPhoneNumber: nil, joinedAt: .now
        )
        #expect(nothing.label == "Family member")
    }
}
