import Foundation
import SwiftData
import Testing
@testable import AliveCore

struct SwiftDataBudgetRepositoryTests {
    private let calendar = BudgetCalendar(timeZone: TimeZone(identifier: "Asia/Shanghai")!)

    @Test("支出在仓库冷启动后仍可读取")
    func expenseSurvivesColdStart() async throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }

        let now = date(2026, 11, 17, hour: 9)
        let first = try fixture.makeRepository()
        let created = try await first.createCycle(
            CycleSetup(
                initialBalanceCents: 100_000,
                startDate: now,
                nextPayday: date(2026, 11, 27)
            ),
            now: now
        )
        _ = try await first.addExpense(amountCents: 4_000, note: "午饭", at: now)

        let reloaded = try fixture.makeRepository()
        let snapshot = try await reloaded.snapshot(at: now)
        let expenses = try await reloaded.currentExpenses(at: now)

        #expect(snapshot.cycleID == created.cycleID)
        #expect(snapshot.currentBalanceCents == 96_000)
        #expect(snapshot.todaySpentCents == 4_000)
        #expect(expenses.count == 1)
        #expect(expenses[0].cycleID == created.cycleID)
        #expect(expenses[0].amountCents == 4_000)
        #expect(expenses[0].note == "午饭")

        let document = try #require(fixture.snapshotStore.read())
        #expect(document.snapshot == snapshot)
    }

    @Test("编辑和删除支出在冷启动后保持")
    func expenseMutationSurvivesColdStart() async throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }

        let now = date(2026, 11, 17, hour: 9)
        let first = try fixture.makeRepository()
        _ = try await first.createCycle(
            CycleSetup(
                initialBalanceCents: 100_000,
                startDate: now,
                nextPayday: date(2026, 11, 27)
            ),
            now: now
        )
        _ = try await first.addExpense(amountCents: 4_000, note: "咖啡", at: now)
        let originalExpense = try #require(try await first.currentExpenses(at: now).first)
        _ = try await first.updateExpense(
            id: originalExpense.id,
            amountCents: 3_000,
            note: "咖啡与面包",
            now: now
        )

        let afterEdit = try fixture.makeRepository()
        let editedExpenses = try await afterEdit.currentExpenses(at: now)
        #expect(editedExpenses.count == 1)
        #expect(editedExpenses[0].amountCents == 3_000)
        #expect(editedExpenses[0].note == "咖啡与面包")

        _ = try await afterEdit.deleteExpense(id: originalExpense.id, now: now)

        let afterDelete = try fixture.makeRepository()
        let deletedSnapshot = try await afterDelete.snapshot(at: now)
        let deletedExpenses = try await afterDelete.currentExpenses(at: now)
        #expect(deletedSnapshot.currentBalanceCents == 100_000)
        #expect(deletedSnapshot.todaySpentCents == 0)
        #expect(deletedExpenses.isEmpty)
    }

    @Test("余额修正和今日锚点在冷启动后保持")
    func balanceOverrideSurvivesColdStart() async throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }

        let now = date(2026, 11, 17, hour: 9)
        let first = try fixture.makeRepository()
        _ = try await first.createCycle(
            CycleSetup(
                initialBalanceCents: 100_000,
                startDate: now,
                nextPayday: date(2026, 11, 27)
            ),
            now: now
        )
        _ = try await first.addExpense(amountCents: 4_000, note: nil, at: now)
        _ = try await first.overrideCurrentBalance(cents: 50_000, at: now)

        let reloaded = try fixture.makeRepository()
        let snapshot = try await reloaded.snapshot(at: now)

        #expect(snapshot.currentBalanceCents == 50_000)
        #expect(snapshot.todayBudgetCents == 9_000)
        #expect(snapshot.todayAvailableCents == 5_000)

        let nextDay = try await reloaded.snapshot(at: date(2026, 11, 18, hour: 8))
        #expect(nextDay.currentBalanceCents == 50_000)
        #expect(MoneyFormatter.currency(cents: nextDay.todayBudgetCents) == "¥55.56")
    }

    @Test("快照不可写时创建周期仍然成功并持久化")
    func createCycleSurvivesSnapshotWriteFailure() async throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }

        let snapshotStore = try fixture.makeUnwritableSnapshotStore()
        let repository = try fixture.makeRepository(snapshotStore: snapshotStore)
        let now = date(2026, 11, 17, hour: 9)

        let created = try await repository.createCycle(
            CycleSetup(
                initialBalanceCents: 100_000,
                startDate: now,
                nextPayday: date(2026, 11, 27)
            ),
            now: now
        )

        #expect(created.currentBalanceCents == 100_000)
        #expect(created.todayBudgetCents == 10_000)
        #expect(try await repository.hasCycle())

        let reloaded = try fixture.makeRepository()
        let persisted = try await reloaded.snapshot(at: now)
        #expect(persisted.cycleID == created.cycleID)
        #expect(persisted.currentBalanceCents == 100_000)
        #expect(persisted.todayBudgetCents == 10_000)
    }

    @Test("快照不可写时支出仍保存且重读只有一笔")
    func addExpenseSurvivesSnapshotWriteFailure() async throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }

        let snapshotStore = try fixture.makeUnwritableSnapshotStore()
        let repository = try fixture.makeRepository(snapshotStore: snapshotStore)
        let now = date(2026, 11, 17, hour: 9)
        let created = try await repository.createCycle(
            CycleSetup(
                initialBalanceCents: 100_000,
                startDate: now,
                nextPayday: date(2026, 11, 27)
            ),
            now: now
        )

        let added = try await repository.addExpense(
            amountCents: 4_000,
            note: "午饭",
            at: now
        )

        #expect(added.cycleID == created.cycleID)
        #expect(added.currentBalanceCents == 96_000)
        #expect(added.todaySpentCents == 4_000)
        #expect(added.todayAvailableCents == 6_000)
        #expect(snapshotStore.read() == nil)

        let reloaded = try fixture.makeRepository()
        let expenses = try await reloaded.currentExpenses(at: now)
        #expect(expenses.count == 1)
        #expect(expenses[0].cycleID == created.cycleID)
        #expect(expenses[0].amountCents == 4_000)

        let persisted = try await reloaded.snapshot(at: now)
        #expect(persisted.currentBalanceCents == 96_000)
        #expect(persisted.todaySpentCents == 4_000)
    }

    @Test("快照路径恢复后重新生成共享快照")
    func snapshotRegeneratesAfterStoreRecovers() async throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }

        let snapshotStore = try fixture.makeUnwritableSnapshotStore()
        let repository = try fixture.makeRepository(snapshotStore: snapshotStore)
        let now = date(2026, 11, 17, hour: 9)
        _ = try await repository.createCycle(
            CycleSetup(
                initialBalanceCents: 100_000,
                startDate: now,
                nextPayday: date(2026, 11, 27)
            ),
            now: now
        )
        _ = try await repository.addExpense(amountCents: 4_000, note: nil, at: now)
        #expect(snapshotStore.read() == nil)

        try FileManager.default.removeItem(at: snapshotStore.directoryURL)

        let recovered = try await repository.snapshot(at: now)
        #expect(recovered.currentBalanceCents == 96_000)
        #expect(recovered.todaySpentCents == 4_000)

        let document = try #require(snapshotStore.read())
        #expect(document.snapshot == recovered)
    }

    private func makeFixture() throws -> RepositoryFixture {
        try RepositoryFixture(calendar: calendar)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour)
        )!
    }
}

private struct RepositoryFixture {
    let directory: URL
    let storeURL: URL
    let calendar: BudgetCalendar
    let snapshotStore: BudgetSnapshotStore

    init(calendar: BudgetCalendar) throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "AliveRepositoryTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        self.directory = directory
        storeURL = directory.appending(path: "Alive.store")
        self.calendar = calendar
        snapshotStore = BudgetSnapshotStore(
            directoryURL: directory.appending(path: "Snapshots", directoryHint: .isDirectory)
        )
    }

    func makeRepository(snapshotStore: BudgetSnapshotStore? = nil) throws -> SwiftDataBudgetRepository {
        let schema = Schema(versionedSchema: AliveSchemaV1.self)
        let configuration = ModelConfiguration(
            "AliveTests",
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
        return SwiftDataBudgetRepository(
            modelContainer: container,
            snapshotStore: snapshotStore ?? self.snapshotStore,
            calendar: calendar
        )
    }

    /// Places a regular file where the snapshot directory should be so every
    /// snapshot write fails while SwiftData remains usable.
    func makeUnwritableSnapshotStore() throws -> BudgetSnapshotStore {
        let blockedDirectory = directory.appending(
            path: "BlockedSnapshots",
            directoryHint: .isDirectory
        )
        try Data("blocked".utf8).write(to: blockedDirectory)
        return BudgetSnapshotStore(directoryURL: blockedDirectory)
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}
