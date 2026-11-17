import SwiftData

enum AliveSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [
            CycleRecord.self,
            ExpenseRecord.self,
            AdjustmentRecord.self,
            AnchorRecord.self
        ]
    }
}

enum AliveMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AliveSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
