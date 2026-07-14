// BanyanSchemaV1.swift
// Versioned schema wrapper — required for SwiftData migrations.

import SwiftData

enum BanyanSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Person.self, Union.self, PersonUnionLink.self]
    }
}
