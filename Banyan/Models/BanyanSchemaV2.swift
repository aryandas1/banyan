// BanyanSchemaV2.swift
// The current schema: adds PersonPhoto (multi-photo galleries) and drops the old
// Person.profilePhotoFilename scalar. This is the model list every container is
// built from.
//
// There is deliberately NO SchemaMigrationPlan / frozen V1 schema. `Person` is a
// single shared type, and it now declares `@Relationship var photos:
// [PersonPhoto]` — so any "V1" model list built from the live `Person` would
// auto-discover PersonPhoto through that relationship and resolve to the same
// schema as V2. A two-stage plan then trips CoreData's "duplicate version
// checksums" check. SwiftData's inferred lightweight migration covers the
// additive change, and with no shipped users a bespoke frozen-copy stage isn't
// worth the weight.

import SwiftData

enum BanyanSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Person.self, Union.self, PersonUnionLink.self, PersonPhoto.self]
    }
}
