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

    private func makeFixture() throws -> RepositoryFixture {
        try RepositoryFixture(calendar: calendar)
    }

    @Test("同一草稿并发点击与冷启动重试只扣款一次")
    func repeatedDraftIsIdempotent() async throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }

        let now = date(2026, 11, 20, hour: 9)
        let repository = try fixture.makeRepository()
        let created = try await repository.createCycle(
            CycleSetup(initialBalanceCents: 100_000, startDate: now, nextPayday: date(2026, 11, 30)),
            now: now
        )
        let id = UUID()
        async let first = repository.addExpense(
            id: id, amountCents: 1_860, note: "🍚", expectedCycleID: created.cycleID, at: now
        )
        async let repeated = repository.addExpense(
            id: id, amountCents: 1_860, note: "🍚", expectedCycleID: created.cycleID, at: now
        )
        _ = try await (first, repeated)

        let reloaded = try fixture.makeRepository()
        let retried = try await reloaded.addExpense(
            id: id, amountCents: 1_860, note: "🍚", expectedCycleID: created.cycleID, at: now
        )
        let expenses = try await reloaded.currentExpenses(at: now)
        #expect(expenses.count == 1)
        #expect(expenses.first?.id == id)
        #expect(expenses.first?.note == "🍚")
        #expect(retried.currentBalanceCents == 98_140)
        #expect(retried.todaySpentCents == 1_860)
        #expect(retried.todayAvailableCents == 8_140)
    }

    @Test("金额相同的独立草稿仍可分别记账")
    func sameAmountDistinctDrafts() async throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }

        let now = date(2026, 11, 20, hour: 9)
        let repository = try fixture.makeRepository()
        let created = try await repository.createCycle(
            CycleSetup(initialBalanceCents: 100_000, startDate: now, nextPayday: date(2026, 11, 30)),
            now: now
        )
        _ = try await repository.addExpense(
            id: UUID(), amountCents: 250, note: "🥤", expectedCycleID: created.cycleID, at: now
        )
        let second = try await repository.addExpense(
            id: UUID(), amountCents: 250, note: "其他", expectedCycleID: created.cycleID, at: now
        )
        let expenses = try await repository.currentExpenses(at: now)
        #expect(expenses.count == 2)
        #expect(Set(expenses.map(\.id)).count == 2)
        #expect(Set(expenses.compactMap(\.note)) == Set(["🥤", "其他"]))
        #expect(second.currentBalanceCents == 99_500)
        #expect(second.todayAvailableCents == 9_500)
    }

    @Test("已保存草稿的冲突重试不覆盖原记录")
    func conflictingDraftDoesNotOverwriteExpense() async throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }

        let now = date(2026, 11, 20, hour: 9)
        let repository = try fixture.makeRepository()
        let created = try await repository.createCycle(
            CycleSetup(initialBalanceCents: 100_000, startDate: now, nextPayday: date(2026, 11, 30)),
            now: now
        )
        let id = UUID()
        _ = try await repository.addExpense(
            id: id, amountCents: 250, note: "🥤", expectedCycleID: created.cycleID, at: now
        )
        await #expect(throws: BudgetError.expenseAlreadyRecorded) {
            try await repository.addExpense(
                id: id, amountCents: 500, note: "其他", expectedCycleID: created.cycleID, at: now
            )
        }
        let expenses = try await repository.currentExpenses(at: now)
        let snapshot = try await repository.snapshot(at: now)
        #expect(expenses.count == 1)
        #expect(expenses.first?.amountCents == 250)
        #expect(expenses.first?.note == "🥤")
        #expect(snapshot.currentBalanceCents == 99_750)
    }

    @Test("发薪日后旧草稿不能误记入新周期")
    func oldDraftCannotWriteIntoRolledCycle() async throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }

        let now = date(2026, 11, 20, hour: 9)
        let repository = try fixture.makeRepository()
        let created = try await repository.createCycle(
            CycleSetup(initialBalanceCents: 100_000, startDate: now, nextPayday: date(2026, 11, 21)),
            now: now
        )
        let payday = date(2026, 11, 21)
        await #expect(throws: BudgetError.expenseOutsideCurrentCycle) {
            try await repository.addExpense(
                id: UUID(), amountCents: 250, note: "其他", expectedCycleID: created.cycleID, at: payday
            )
        }
        let snapshot = try await repository.snapshot(at: payday)
        let expenses = try await repository.currentExpenses(at: payday)
        #expect(snapshot.cycleID != created.cycleID)
        #expect(snapshot.currentBalanceCents == 100_000)
        #expect(snapshot.todaySpentCents == 0)
        #expect(expenses.isEmpty)
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
    }

    func makeRepository() throws -> SwiftDataBudgetRepository {
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
            storeDirectoryURL: directory,
            calendar: calendar
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}
