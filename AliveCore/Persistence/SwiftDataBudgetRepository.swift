import Foundation
import os
import SwiftData

public actor SwiftDataBudgetRepository: BudgetRepository {
    private static let logger = Logger(
        subsystem: "cn.bobochang.alive",
        category: "BudgetSnapshot"
    )

    private let modelContainer: ModelContainer
    private let snapshotStore: BudgetSnapshotStore
    private let resolver: BudgetResolver
    private var modelContext: ModelContext {
        ModelContext(modelContainer)
    }

    public init(
        modelContainer: ModelContainer,
        snapshotStore: BudgetSnapshotStore,
        calendar: BudgetCalendar = BudgetCalendar()
    ) {
        self.modelContainer = modelContainer
        self.snapshotStore = snapshotStore
        self.resolver = BudgetResolver(calendar: calendar)
    }

    public static func makeDefault(calendar: BudgetCalendar = BudgetCalendar()) throws -> SwiftDataBudgetRepository {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: BudgetSnapshotStore.appGroupID
        ) else {
            throw BudgetError.storageUnavailable
        }

        let storeDirectory = groupURL.appending(path: "Database", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: storeDirectory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        let storeURL = storeDirectory.appending(path: "Alive.store")
        let schema = Schema(versionedSchema: AliveSchemaV1.self)
        let configuration = ModelConfiguration(
            "Alive",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: schema,
            migrationPlan: AliveMigrationPlan.self,
            configurations: [configuration]
        )
        let snapshotStore = try BudgetSnapshotStore.appGroup()
        let repository = SwiftDataBudgetRepository(
            modelContainer: container,
            snapshotStore: snapshotStore,
            calendar: calendar
        )
        Task {
            await repository.protectStoreFiles()
        }
        return repository
    }

    public func hasCycle() async throws -> Bool {
        try !loadState().cycles.isEmpty
    }

    public func createCycle(_ setup: CycleSetup, now: Date) async throws -> BudgetSnapshot {
        let existing = try loadState()
        guard existing.cycles.isEmpty else { throw BudgetError.cycleAlreadyStarted }
        let resolution = try resolver.initialResolution(setup: setup, now: now)
        guard let snapshot = resolution.snapshot else { throw BudgetError.noCycle }
        try persist(resolution.state)
        return writeSnapshotBestEffort(snapshot)
    }

    public func snapshot(at date: Date) async throws -> BudgetSnapshot {
        let resolution = try resolveAndPersist(at: date)
        guard let snapshot = resolution.snapshot else {
            snapshotStore.clear()
            throw BudgetError.noCycle
        }
        return writeSnapshotBestEffort(snapshot)
    }

    public func addExpense(amountCents: Int, note: String?, at date: Date) async throws -> BudgetSnapshot {
        let state = try resolveAndPersist(at: date).state
        let resolution = try resolver.addExpense(
            to: state,
            amountCents: amountCents,
            note: note,
            at: date
        )
        try persist(resolution.state)
        guard let snapshot = resolution.snapshot else { throw BudgetError.noCycle }
        return writeSnapshotBestEffort(snapshot)
    }

    public func updateExpense(
        id: UUID,
        amountCents: Int,
        note: String?,
        now: Date
    ) async throws -> BudgetSnapshot {
        let state = try resolveAndPersist(at: now).state
        let resolution = try resolver.updateExpense(
            in: state,
            id: id,
            amountCents: amountCents,
            note: note,
            now: now
        )
        try persist(resolution.state)
        guard let snapshot = resolution.snapshot else { throw BudgetError.noCycle }
        return writeSnapshotBestEffort(snapshot)
    }

    public func deleteExpense(id: UUID, now: Date) async throws -> BudgetSnapshot {
        let state = try resolveAndPersist(at: now).state
        let resolution = try resolver.deleteExpense(in: state, id: id, now: now)
        try persist(resolution.state)
        guard let snapshot = resolution.snapshot else { throw BudgetError.noCycle }
        return writeSnapshotBestEffort(snapshot)
    }

    public func overrideCurrentBalance(cents: Int, at date: Date) async throws -> BudgetSnapshot {
        let state = try resolveAndPersist(at: date).state
        let resolution = try resolver.overrideCurrentBalance(in: state, cents: cents, at: date)
        try persist(resolution.state)
        guard let snapshot = resolution.snapshot else { throw BudgetError.noCycle }
        return writeSnapshotBestEffort(snapshot)
    }

    public func updatePendingCycle(_ setup: CycleSetup, now: Date) async throws -> BudgetSnapshot {
        let state = try resolveAndPersist(at: now).state
        let resolution = try resolver.updatePendingCycle(in: state, setup: setup, now: now)
        try persist(resolution.state)
        guard let snapshot = resolution.snapshot else { throw BudgetError.noCycle }
        return writeSnapshotBestEffort(snapshot)
    }

    public func currentExpenses(at date: Date) async throws -> [Expense] {
        let resolution = try resolveAndPersist(at: date)
        guard let snapshot = resolution.snapshot else { throw BudgetError.noCycle }
        return resolution.state.expenses
            .filter { $0.cycleID == snapshot.cycleID }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    public func archivedCycles(at date: Date) async throws -> [ArchivedCycleSummary] {
        let state = try resolveAndPersist(at: date).state
        return resolver.archivedSummaries(in: state, now: date)
    }

    private func resolveAndPersist(at date: Date) throws -> BudgetResolution {
        let state = try loadState()
        let resolution = resolver.resolve(state, now: date)
        if resolution.state != state {
            try persist(resolution.state)
        }
        return resolution
    }

    private func loadState() throws -> BudgetState {
        let context = modelContext
        let cycles = try context.fetch(FetchDescriptor<CycleRecord>())
            .map(\.value)
            .sorted { $0.startDate < $1.startDate }
        let expenses = try context.fetch(FetchDescriptor<ExpenseRecord>())
            .map(\.value)
            .sorted { $0.occurredAt < $1.occurredAt }
        let adjustments = try context.fetch(FetchDescriptor<AdjustmentRecord>())
            .map(\.value)
            .sorted { $0.createdAt < $1.createdAt }
        let anchors = try context.fetch(FetchDescriptor<AnchorRecord>())
            .map(\.value)
            .sorted { $0.dayStart < $1.dayStart }
        return BudgetState(
            cycles: cycles,
            expenses: expenses,
            adjustments: adjustments,
            anchors: anchors
        )
    }

    private func persist(_ state: BudgetState) throws {
        let context = modelContext

        let cycleRecords = try context.fetch(FetchDescriptor<CycleRecord>())
        let cycleIDs = Set(state.cycles.map(\.id))
        for record in cycleRecords where !cycleIDs.contains(record.id) {
            context.delete(record)
        }
        var cycleByID = Dictionary(uniqueKeysWithValues: cycleRecords.map { ($0.id, $0) })
        for cycle in state.cycles {
            if let record = cycleByID[cycle.id] {
                record.apply(cycle)
            } else {
                let record = CycleRecord(cycle: cycle)
                context.insert(record)
                cycleByID[cycle.id] = record
            }
        }

        let expenseRecords = try context.fetch(FetchDescriptor<ExpenseRecord>())
        let expenseIDs = Set(state.expenses.map(\.id))
        for record in expenseRecords where !expenseIDs.contains(record.id) {
            context.delete(record)
        }
        var expenseByID = Dictionary(uniqueKeysWithValues: expenseRecords.map { ($0.id, $0) })
        for expense in state.expenses {
            if let record = expenseByID[expense.id] {
                record.apply(expense)
            } else {
                let record = ExpenseRecord(expense: expense)
                context.insert(record)
                expenseByID[expense.id] = record
            }
        }

        let adjustmentRecords = try context.fetch(FetchDescriptor<AdjustmentRecord>())
        let adjustmentIDs = Set(state.adjustments.map(\.id))
        for record in adjustmentRecords where !adjustmentIDs.contains(record.id) {
            context.delete(record)
        }
        var adjustmentByID = Dictionary(uniqueKeysWithValues: adjustmentRecords.map { ($0.id, $0) })
        for adjustment in state.adjustments {
            if let record = adjustmentByID[adjustment.id] {
                record.apply(adjustment)
            } else {
                let record = AdjustmentRecord(adjustment: adjustment)
                context.insert(record)
                adjustmentByID[adjustment.id] = record
            }
        }

        let anchorRecords = try context.fetch(FetchDescriptor<AnchorRecord>())
        let anchorIDs = Set(state.anchors.map(\.id))
        for record in anchorRecords where !anchorIDs.contains(record.id) {
            context.delete(record)
        }
        var anchorByID = Dictionary(uniqueKeysWithValues: anchorRecords.map { ($0.id, $0) })
        for anchor in state.anchors {
            if let record = anchorByID[anchor.id] {
                record.apply(anchor)
            } else {
                let record = AnchorRecord(anchor: anchor)
                context.insert(record)
                anchorByID[anchor.id] = record
            }
        }

        try context.save()
        protectStoreFiles()
    }

    /// SwiftData is the source of truth. A failed shared-snapshot write must not
    /// roll back or fail an already-persisted user action; the next successful
    /// read or write regenerates the snapshot.
    private func writeSnapshotBestEffort(_ snapshot: BudgetSnapshot) -> BudgetSnapshot {
        let document = BudgetSnapshotDocument(
            snapshot: snapshot,
            nextRefresh: resolver.calendar.nextMidnight(after: snapshot.generatedAt)
        )
        do {
            try snapshotStore.write(document)
        } catch {
            let code = (error as NSError).code
            Self.logger.error(
                "Shared snapshot write failed with code \(code, privacy: .public); SwiftData state remains authoritative."
            )
        }
        return snapshot
    }

    private func protectStoreFiles() {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: BudgetSnapshotStore.appGroupID
        ) else {
            return
        }
        let storeURL = groupURL
            .appending(path: "Database", directoryHint: .isDirectory)
            .appending(path: "Alive.store")
        for suffix in ["", "-wal", "-shm"] {
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
        }
    }
}
