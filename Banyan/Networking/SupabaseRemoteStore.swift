// SupabaseRemoteStore.swift
// The Supabase-backed RemoteStore: turns the protocol calls into PostgREST
// upserts/selects/deletes. All access control is enforced server-side by RLS.

import Foundation
import Supabase

struct SupabaseRemoteStore: RemoteStore {
    let client: SupabaseClient

    func upsertTree(_ tree: TreeDTO) async throws {
        _ = try await client.from("trees").upsert(tree, onConflict: "id").execute()
    }

    func upsert(_ persons: [PersonDTO]) async throws {
        _ = try await client.from(RemoteTable.persons.rawValue).upsert(persons, onConflict: "id").execute()
    }

    func upsert(_ unions: [UnionDTO]) async throws {
        _ = try await client.from(RemoteTable.unions.rawValue).upsert(unions, onConflict: "id").execute()
    }

    func upsert(_ links: [PersonUnionLinkDTO]) async throws {
        _ = try await client.from(RemoteTable.links.rawValue).upsert(links, onConflict: "id").execute()
    }

    func remoteIds(in table: RemoteTable, treeId: UUID) async throws -> Set<UUID> {
        let rows: [IDRow] = try await client.from(table.rawValue)
            .select("id")
            .eq("tree_id", value: treeId.uuidString)
            .execute()
            .value
        return Set(rows.map(\.id))
    }

    func delete(from table: RemoteTable, id: UUID) async throws {
        _ = try await client.from(table.rawValue)
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
