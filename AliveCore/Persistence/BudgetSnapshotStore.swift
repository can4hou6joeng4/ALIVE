import Foundation

public struct BudgetSnapshotDocument: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let snapshot: BudgetSnapshot
    public let nextRefresh: Date

    public init(schemaVersion: Int = BudgetSnapshotDocument.currentSchemaVersion, snapshot: BudgetSnapshot, nextRefresh: Date) {
        self.schemaVersion = schemaVersion
        self.snapshot = snapshot
        self.nextRefresh = nextRefresh
    }
}

public struct BudgetSnapshotStore: Sendable {
    public static let appGroupID = "group.cn.bobochang.alive"

    public let directoryURL: URL

    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    public static func appGroup() throws -> BudgetSnapshotStore {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            throw BudgetError.storageUnavailable
        }
        return BudgetSnapshotStore(
            directoryURL: container.appending(path: "Snapshots", directoryHint: .isDirectory)
        )
    }

    public var fileURL: URL {
        directoryURL.appending(path: "budget-snapshot.json")
    }

    public func read() -> BudgetSnapshotDocument? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let document = try? decoder.decode(BudgetSnapshotDocument.self, from: data),
              document.schemaVersion == BudgetSnapshotDocument.currentSchemaVersion else {
            return nil
        }
        return document
    }

    public func write(_ document: BudgetSnapshotDocument) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(document)
        try data.write(
            to: fileURL,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }

    public func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
