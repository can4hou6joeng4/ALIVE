import Foundation
import Testing
@testable import AliveCore

struct BudgetResolverTests {
    private let calendar = BudgetCalendar(timeZone: TimeZone(identifier: "Asia/Shanghai")!)
    private var resolver: BudgetResolver { BudgetResolver(calendar: calendar) }

    @Test("首次设置按剩余天数计算今日预算")
    func initialBudget() throws {
        let start = date(2026, 11, 17, hour: 9)
        let payday = date(2026, 11, 27)
        let resolution = try resolver.initialResolution(
            setup: CycleSetup(initialBalanceCents: 100_000, startDate: start, nextPayday: payday),
            now: start
        )

        let snapshot = try #require(resolution.snapshot)
        #expect(snapshot.phase == .active)
        #expect(snapshot.daysRemaining == 10)
        #expect(snapshot.todayBudgetCents == 10_000)
        #expect(snapshot.todayAvailableCents == 10_000)
        #expect(snapshot.currentBalanceCents == 100_000)
    }

    @Test("单笔支出只扣减今日可用和余额")
    func singleExpense() throws {
        let start = date(2026, 11, 17, hour: 9)
        let initial = try resolver.initialResolution(
            setup: CycleSetup(
                initialBalanceCents: 100_000,
                startDate: start,
                nextPayday: date(2026, 11, 27)
            ),
            now: start
        )

        let result = try resolver.addExpense(
            to: initial.state,
            amountCents: 4_000,
            note: "午饭",
            at: date(2026, 11, 17, hour: 12)
        )
        let snapshot = try #require(result.snapshot)

        #expect(snapshot.todayBudgetCents == 10_000)
        #expect(snapshot.todayAvailableCents == 6_000)
        #expect(snapshot.currentBalanceCents == 96_000)
        #expect(snapshot.todaySpentCents == 4_000)
    }

    @Test("次日按最新余额重新分配")
    func nextDayRollingBudget() throws {
        let start = date(2026, 11, 17, hour: 9)
        let initial = try resolver.initialResolution(
            setup: CycleSetup(
                initialBalanceCents: 100_000,
                startDate: start,
                nextPayday: date(2026, 11, 27)
            ),
            now: start
        )
        let spent = try resolver.addExpense(
            to: initial.state,
            amountCents: 4_000,
            note: nil,
            at: start
        )

        let nextDay = try resolver.resolve(spent.state, now: date(2026, 11, 18, hour: 8))
        let snapshot = try #require(nextDay.snapshot)

        #expect(snapshot.daysRemaining == 9)
        #expect(MoneyFormatter.currency(cents: snapshot.todayBudgetCents) == "¥106.67")
        #expect(snapshot.todayAvailableCents == snapshot.todayBudgetCents)
    }

    @Test("超过今日预算进入超支状态但不阻断记录")
    func overspend() throws {
        let start = date(2026, 11, 17, hour: 9)
        let initial = try resolver.initialResolution(
            setup: CycleSetup(
                initialBalanceCents: 100_000,
                startDate: start,
                nextPayday: date(2026, 11, 27)
            ),
            now: start
        )
        let result = try resolver.addExpense(
            to: initial.state,
            amountCents: 12_000,
            note: nil,
            at: date(2026, 11, 17, hour: 15)
        )
        let snapshot = try #require(result.snapshot)

        #expect(snapshot.phase == .overspent)
        #expect(snapshot.todayAvailableCents == -2_000)
        #expect(snapshot.currentBalanceCents == 88_000)
    }

    @Test("手动调整余额重设今日可用，且后续支出继续扣减")
    func manualBalanceOverride() throws {
        let start = date(2026, 11, 17, hour: 9)
        let initial = try resolver.initialResolution(
            setup: CycleSetup(
                initialBalanceCents: 100_000,
                startDate: start,
                nextPayday: date(2026, 11, 27)
            ),
            now: start
        )
        let spent = try resolver.addExpense(
            to: initial.state,
            amountCents: 4_000,
            note: nil,
            at: start
        )
        let overridden = try resolver.overrideCurrentBalance(
            in: spent.state,
            cents: 50_000,
            at: date(2026, 11, 17, hour: 13)
        )
        let firstSnapshot = try #require(overridden.snapshot)
        #expect(firstSnapshot.currentBalanceCents == 50_000)
        #expect(firstSnapshot.todayAvailableCents == 5_000)

        let added = try resolver.addExpense(
            to: overridden.state,
            amountCents: 1_000,
            note: nil,
            at: date(2026, 11, 17, hour: 14)
        )
        let finalSnapshot = try #require(added.snapshot)
        #expect(finalSnapshot.todayAvailableCents == 4_000)
        #expect(finalSnapshot.currentBalanceCents == 49_000)
    }

    @Test("手动调整余额清除结转待确认标记并重设当日锚点")
    func balanceOverrideClearsReviewFlag() throws {
        let start = date(2026, 11, 17, hour: 8)
        let initial = try resolver.initialResolution(
            setup: CycleSetup(
                initialBalanceCents: 100_000,
                startDate: start,
                nextPayday: date(2026, 11, 27)
            ),
            now: start
        )
        let spent = try resolver.addExpense(
            to: initial.state,
            amountCents: 4_000,
            note: nil,
            at: start
        )
        let rolled = try resolver.resolve(
            spent.state,
            now: date(2026, 11, 27, hour: 0, minute: 1)
        )
        let rolledSnapshot = try #require(rolled.snapshot)
        #expect(rolledSnapshot.needsBalanceReview)
        #expect(rolledSnapshot.currentBalanceCents == 96_000)

        let sameDay = try resolver.addExpense(
            to: rolled.state,
            amountCents: 1_000,
            note: nil,
            at: date(2026, 11, 27, hour: 9)
        )
        let beforeOverride = try #require(sameDay.snapshot)
        #expect(beforeOverride.needsBalanceReview)
        #expect(beforeOverride.todaySpentCents == 1_000)

        let overridden = try resolver.overrideCurrentBalance(
            in: sameDay.state,
            cents: 60_000,
            at: date(2026, 11, 27, hour: 10)
        )
        let snapshot = try #require(overridden.snapshot)

        #expect(!snapshot.needsBalanceReview)
        #expect(snapshot.currentBalanceCents == 60_000)
        #expect(snapshot.todaySpentCents == 1_000)
        #expect(snapshot.todayBudgetCents == 3_000)
        #expect(snapshot.todayAvailableCents == 2_000)
        #expect(snapshot.daysRemaining == 30)

        #expect(overridden.state.adjustments.count == 1)
        let adjustment = try #require(overridden.state.adjustments.first)
        #expect(adjustment.cycleID == rolledSnapshot.cycleID)
        #expect(adjustment.deltaCents == -35_000)
        #expect(adjustment.reason == "manualOverride")

        let todayAnchor = try #require(overridden.state.anchors.last {
            $0.cycleID == rolledSnapshot.cycleID
                && calendar.isSameDay($0.dayStart, date(2026, 11, 27, hour: 10))
        })
        #expect(todayAnchor.budgetCents == 3_000)
        #expect(todayAnchor.basisBalanceCents == 60_000)

        let currentCycle = try #require(overridden.state.cycles.last)
        #expect(currentCycle.id == rolledSnapshot.cycleID)
        #expect(!currentCycle.needsBalanceReview)

        let archivedCycle = try #require(overridden.state.cycles.first { $0.closedAt != nil })
        #expect(!archivedCycle.needsBalanceReview)
        #expect(archivedCycle.closedAt == calendar.startOfDay(date(2026, 11, 27)))
    }

    @Test("未来起始日进入待开始并拒绝支出")
    func pendingCycle() throws {
        let now = date(2026, 11, 17, hour: 9)
        let resolution = try resolver.initialResolution(
            setup: CycleSetup(
                initialBalanceCents: 120_000,
                startDate: date(2026, 11, 20),
                nextPayday: date(2026, 12, 20)
            ),
            now: now
        )
        let snapshot = try #require(resolution.snapshot)

        #expect(snapshot.phase == .pending)
        #expect(snapshot.daysRemaining == 30)
        #expect(snapshot.todayBudgetCents == 4_000)
        #expect(throws: BudgetError.cycleNotActive) {
            try resolver.addExpense(to: resolution.state, amountCents: 100, note: nil, at: now)
        }
    }

    @Test("待开始倒计时是距起始日的日历日数，不是周期天数")
    func pendingCountdown() throws {
        let resolution = try resolver.initialResolution(
            setup: CycleSetup(
                initialBalanceCents: 120_000,
                startDate: date(2026, 11, 20),
                nextPayday: date(2026, 12, 20)
            ),
            now: date(2026, 11, 17, hour: 9)
        )
        let threeDaysBefore = try #require(resolution.snapshot)
        #expect(threeDaysBefore.daysRemaining == 30)
        #expect(threeDaysBefore.daysUntilStart == 3)

        let nightBefore = try #require(
            resolver.resolve(resolution.state, now: date(2026, 11, 19, hour: 23, minute: 59)).snapshot
        )
        #expect(nightBefore.phase == .pending)
        #expect(nightBefore.daysUntilStart == 1)

        let started = try #require(
            resolver.resolve(resolution.state, now: date(2026, 11, 20)).snapshot
        )
        #expect(started.phase == .active)
        #expect(started.daysUntilStart == 0)
    }

    @Test("到达未来起始日后自动进入进行中")
    func pendingBecomesActive() throws {
        let resolution = try resolver.initialResolution(
            setup: CycleSetup(
                initialBalanceCents: 120_000,
                startDate: date(2026, 11, 20),
                nextPayday: date(2026, 12, 20)
            ),
            now: date(2026, 11, 17)
        )
        let activated = try resolver.resolve(resolution.state, now: date(2026, 11, 20, hour: 8))
        let snapshot = try #require(activated.snapshot)

        #expect(snapshot.phase == .active)
        #expect(snapshot.currentBalanceCents == 120_000)
    }

    @Test("发薪日当天先结转，再建立新周期")
    func paydayRollover() throws {
        let start = date(2026, 11, 17, hour: 8)
        let initial = try resolver.initialResolution(
            setup: CycleSetup(
                initialBalanceCents: 100_000,
                startDate: start,
                nextPayday: date(2026, 11, 27)
            ),
            now: start
        )
        let spent = try resolver.addExpense(
            to: initial.state,
            amountCents: 98_000,
            note: nil,
            at: start
        )
        let rolled = try resolver.resolve(spent.state, now: date(2026, 11, 27, hour: 0, minute: 1))
        let snapshot = try #require(rolled.snapshot)

        #expect(snapshot.phase == .active)
        #expect(snapshot.startDate == calendar.startOfDay(date(2026, 11, 27)))
        #expect(snapshot.payday == calendar.startOfDay(date(2026, 12, 27)))
        #expect(snapshot.currentBalanceCents == 2_000)
        #expect(snapshot.needsBalanceReview)
        #expect(rolled.state.cycles.filter { $0.closedAt != nil }.count == 1)
    }

    @Test("31 日发薪锚点在短月取月末且不改变锚点")
    func paydayClamping() throws {
        let initial = try resolver.initialResolution(
            setup: CycleSetup(
                initialBalanceCents: 100_000,
                startDate: date(2026, 1, 1),
                nextPayday: date(2026, 1, 31)
            ),
            now: date(2026, 1, 1)
        )
        let february = try resolver.resolve(initial.state, now: date(2026, 1, 31, hour: 0, minute: 1))
        let febSnapshot = try #require(february.snapshot)
        #expect(febSnapshot.payday == calendar.startOfDay(date(2026, 2, 28)))

        let march = try resolver.resolve(february.state, now: date(2026, 2, 28, hour: 0, minute: 1))
        let marchSnapshot = try #require(march.snapshot)
        #expect(marchSnapshot.payday == calendar.startOfDay(date(2026, 3, 31)))
        #expect(march.state.cycles.last?.paydayAnchorDay == 31)
    }

    @Test("多个月未打开按顺序补齐周期")
    func multiCycleCatchUp() throws {
        let initial = try resolver.initialResolution(
            setup: CycleSetup(
                initialBalanceCents: 100_000,
                startDate: date(2026, 1, 1),
                nextPayday: date(2026, 1, 31)
            ),
            now: date(2026, 1, 1)
        )
        let resolved = try resolver.resolve(initial.state, now: date(2026, 5, 1, hour: 9))
        let snapshot = try #require(resolved.snapshot)

        #expect(resolved.state.cycles.count == 5)
        #expect(snapshot.startDate == calendar.startOfDay(date(2026, 4, 30)))
        #expect(snapshot.payday == calendar.startOfDay(date(2026, 5, 31)))
    }

    @Test("编辑当前周期支出同步刷新余额和今日可用")
    func updateExpense() throws {
        let start = date(2026, 11, 17, hour: 8)
        let initial = try resolver.initialResolution(
            setup: CycleSetup(initialBalanceCents: 100_000, startDate: start, nextPayday: date(2026, 11, 27)),
            now: start
        )
        let added = try resolver.addExpense(to: initial.state, amountCents: 4_000, note: "咖啡", at: start)
        let expense = try #require(added.state.expenses.first)
        let updated = try resolver.updateExpense(
            in: added.state,
            id: expense.id,
            amountCents: 3_000,
            note: "咖啡与面包",
            now: start
        )
        let snapshot = try #require(updated.snapshot)

        #expect(snapshot.todayAvailableCents == 7_000)
        #expect(snapshot.currentBalanceCents == 97_000)
    }

    @Test("删除当前周期支出恢复金额")
    func deleteExpense() throws {
        let start = date(2026, 11, 17, hour: 8)
        let initial = try resolver.initialResolution(
            setup: CycleSetup(initialBalanceCents: 100_000, startDate: start, nextPayday: date(2026, 11, 27)),
            now: start
        )
        let added = try resolver.addExpense(to: initial.state, amountCents: 4_000, note: nil, at: start)
        let expense = try #require(added.state.expenses.first)
        let deleted = try resolver.deleteExpense(in: added.state, id: expense.id, now: start)
        let snapshot = try #require(deleted.snapshot)

        #expect(snapshot.todayAvailableCents == 10_000)
        #expect(snapshot.currentBalanceCents == 100_000)
        #expect(deleted.state.expenses.isEmpty)
    }

    @Test("编辑历史支出按新余额重算今日预算与可用")
    func updateHistoricalExpenseRollsBudget() throws {
        let start = date(2026, 11, 17, hour: 9)
        let initial = try resolver.initialResolution(
            setup: CycleSetup(initialBalanceCents: 100_000, startDate: start, nextPayday: date(2026, 11, 27)),
            now: start
        )
        let added = try resolver.addExpense(to: initial.state, amountCents: 4_000, note: nil, at: start)
        let expense = try #require(added.state.expenses.first)

        // 次日先固定 96,000 / 9 天的当日锚点。
        let nextDay = date(2026, 11, 18, hour: 9)
        let rolled = resolver.resolve(added.state, now: nextDay)
        let rolledSnapshot = try #require(rolled.snapshot)
        #expect(rolledSnapshot.todayBudgetCents == Decimal(96_000) / Decimal(9))

        let updated = try resolver.updateExpense(
            in: rolled.state,
            id: expense.id,
            amountCents: 6_000,
            note: nil,
            now: nextDay
        )
        let snapshot = try #require(updated.snapshot)

        #expect(snapshot.currentBalanceCents == 94_000)
        #expect(snapshot.todaySpentCents == 0)
        #expect(snapshot.todayBudgetCents == Decimal(94_000) / Decimal(9))
        #expect(snapshot.todayAvailableCents == snapshot.todayBudgetCents)
    }

    @Test("删除历史支出按新余额重算今日预算与可用")
    func deleteHistoricalExpenseRollsBudget() throws {
        let start = date(2026, 11, 17, hour: 9)
        let initial = try resolver.initialResolution(
            setup: CycleSetup(initialBalanceCents: 100_000, startDate: start, nextPayday: date(2026, 11, 27)),
            now: start
        )
        let added = try resolver.addExpense(to: initial.state, amountCents: 4_000, note: nil, at: start)
        let expense = try #require(added.state.expenses.first)

        let nextDay = date(2026, 11, 18, hour: 9)
        let rolled = resolver.resolve(added.state, now: nextDay)
        let deleted = try resolver.deleteExpense(in: rolled.state, id: expense.id, now: nextDay)
        let snapshot = try #require(deleted.snapshot)

        #expect(snapshot.currentBalanceCents == 100_000)
        #expect(snapshot.todaySpentCents == 0)
        #expect(snapshot.todayBudgetCents == Decimal(100_000) / Decimal(9))
        #expect(snapshot.todayAvailableCents == snapshot.todayBudgetCents)
    }

    @Test("归档周期支出不可修改")
    func archivedExpenseIsReadOnly() throws {
        let start = date(2026, 11, 17, hour: 8)
        let initial = try resolver.initialResolution(
            setup: CycleSetup(initialBalanceCents: 100_000, startDate: start, nextPayday: date(2026, 11, 27)),
            now: start
        )
        let added = try resolver.addExpense(to: initial.state, amountCents: 4_000, note: nil, at: start)
        let expense = try #require(added.state.expenses.first)
        let rolled = try resolver.resolve(added.state, now: date(2026, 11, 27, hour: 0, minute: 1))

        #expect(throws: BudgetError.archivedCycleReadOnly) {
            try resolver.updateExpense(
                in: rolled.state,
                id: expense.id,
                amountCents: 1_000,
                note: nil,
                now: date(2026, 11, 28)
            )
        }
    }

    @Test("投影在跨日后按余额重算且跨发薪日结转")
    func snapshotProjection() throws {
        let start = date(2026, 11, 17, hour: 8)
        let initial = try resolver.initialResolution(
            setup: CycleSetup(initialBalanceCents: 100_000, startDate: start, nextPayday: date(2026, 11, 27)),
            now: start
        )
        let spent = try resolver.addExpense(to: initial.state, amountCents: 4_000, note: nil, at: start)
        let snapshot = try #require(spent.snapshot)

        let tomorrow = snapshot.projected(at: date(2026, 11, 18, hour: 0, minute: 1), calendar: calendar)
        #expect(tomorrow.daysRemaining == 9)
        #expect(MoneyFormatter.currency(cents: tomorrow.todayBudgetCents) == "¥106.67")

        let nextCycle = snapshot.projected(at: date(2026, 11, 27, hour: 0, minute: 1), calendar: calendar)
        #expect(nextCycle.startDate == calendar.startOfDay(date(2026, 11, 27)))
        #expect(nextCycle.payday == calendar.startOfDay(date(2026, 12, 27)))
        #expect(nextCycle.needsBalanceReview)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        )!
    }
}
