import Foundation
import Testing
@testable import AliveCore

struct DomainSupportTests {
    private let calendar = BudgetCalendar(timeZone: TimeZone(identifier: "Asia/Shanghai")!)

    @Test("金额解析拒绝超过两位小数")
    func moneyParsing() {
        #expect(MoneyParser.cents(from: "1,234.56") == 123_456)
        #expect(MoneyParser.cents(from: "0.01") == 1)
        #expect(MoneyParser.cents(from: "-12.30", allowNegative: true) == -1_230)
        #expect(MoneyParser.cents(from: "12.345") == nil)
        #expect(MoneyParser.cents(from: "abc") == nil)
        #expect(MoneyParser.cents(from: "-1.00") == nil)
    }

    @Test("金额展示固定两位小数")
    func moneyFormatting() {
        #expect(MoneyFormatter.currency(cents: 4_250) == "¥42.50")
        #expect(MoneyFormatter.currency(cents: 0) == "¥0.00")
        #expect(MoneyFormatter.currency(cents: -850) == "-¥8.50")
    }

    @Test("紧凑金额按千元切换小数位且保持 Decimal 精度")
    func compactMoneyFormatting() {
        #expect(MoneyFormatter.compactYuan(cents: 0) == "0")
        #expect(MoneyFormatter.compactYuan(cents: 12_345) == "123.5")
        #expect(MoneyFormatter.compactYuan(cents: 99_000) == "990")
        #expect(MoneyFormatter.compactYuan(cents: 100_000) == "1,000")
        #expect(MoneyFormatter.compactYuan(cents: 123_456) == "1,235")

        // This integer cannot be represented exactly by Double; the Decimal
        // path must preserve every digit.
        let exactCents = Decimal(string: "900719925474099300")!
        #expect(MoneyFormatter.compactYuan(cents: exactCents) == "9,007,199,254,740,993")
    }

    @Test("展示状态区分可用、待开始、超支、零余额与负余额")
    func budgetDisplayState() {
        let available = BudgetDisplayState(
            phase: .active,
            todayBudgetCents: 10_000,
            todayAvailableCents: 6_000,
            currentBalanceCents: 96_000
        )
        #expect(available == .available(amountCents: 6_000))
        #expect(available.amountCents == 6_000)
        #expect(available.label == "今天还可花")
        #expect(!available.isOverspent)
        #expect(!available.isZeroBalance)
        #expect(!available.isNegativeBalance)

        let pending = BudgetDisplayState(
            phase: .pending,
            todayBudgetCents: 4_000,
            todayAvailableCents: 4_000,
            currentBalanceCents: 120_000
        )
        #expect(pending == .pending(budgetCents: 4_000))
        #expect(pending.amountCents == 4_000)
        #expect(pending.label == "预计每日额度")

        let overspentToday = BudgetDisplayState(
            phase: .overspent,
            todayBudgetCents: 10_000,
            todayAvailableCents: -2_000,
            currentBalanceCents: 88_000
        )
        #expect(overspentToday == .overspent(overageCents: 2_000))
        #expect(overspentToday.amountCents == 2_000)
        #expect(overspentToday.label == "今天已超出")
        #expect(overspentToday.isOverspent)

        let zeroBalance = BudgetDisplayState(
            phase: .active,
            todayBudgetCents: 0,
            todayAvailableCents: 0,
            currentBalanceCents: 0
        )
        #expect(zeroBalance == .zeroBalance)
        #expect(zeroBalance.amountCents == 0)
        #expect(zeroBalance.isZeroBalance)
        #expect(!zeroBalance.isOverspent)

        let negativeWithoutOverage = BudgetDisplayState(
            phase: .overspent,
            todayBudgetCents: 0,
            todayAvailableCents: 0,
            currentBalanceCents: -500
        )
        #expect(negativeWithoutOverage == .negativeBalance(balanceCents: 500, overageCents: nil))
        #expect(negativeWithoutOverage.amountCents == 500)
        #expect(negativeWithoutOverage.label == "余额已为负")
        #expect(negativeWithoutOverage.isNegativeBalance)
        #expect(negativeWithoutOverage.isOverspent)

        let negativeWithOverage = BudgetDisplayState(
            phase: .overspent,
            todayBudgetCents: 10_000,
            todayAvailableCents: -300,
            currentBalanceCents: -500
        )
        #expect(negativeWithOverage == .negativeBalance(balanceCents: 500, overageCents: 300))
        #expect(negativeWithOverage.amountCents == 500)
    }

    @Test("预算日历固定使用北京时间")
    func fixedBudgetTimeZone() {
        #expect(BudgetCalendar.fixedTimeZone.identifier == "Asia/Shanghai")
        #expect(BudgetCalendar().timeZone.identifier == "Asia/Shanghai")
    }

    @Test("共享偏好键保持稳定")
    func sharedPreferenceKeys() {
        #expect(SharedPreferenceKeys.appGroupID == "group.cn.bobochang.alive")
    }

    @Test("Live Activity 过期时间取 8 小时、午夜和发薪日中最早值")
    func liveActivityStaleDate() {
        let openedAt = calendar.calendar.date(
            from: DateComponents(year: 2026, month: 11, day: 17, hour: 20)
        )!
        let snapshot = BudgetSnapshot(
            cycleID: UUID(),
            phase: .active,
            todayBudgetCents: 10_000,
            todayAvailableCents: 10_000,
            todaySpentCents: 0,
            currentBalanceCents: 100_000,
            daysRemaining: 10,
            startDate: calendar.startOfDay(openedAt),
            payday: calendar.calendar.date(
                from: DateComponents(year: 2026, month: 11, day: 27)
            )!,
            paydayAnchorDay: 27,
            needsBalanceReview: false,
            generatedAt: openedAt
        )

        let window = LiveActivityWindow.calculate(snapshot: snapshot, openedAt: openedAt, calendar: calendar)
        #expect(window.staleDate == calendar.nextMidnight(after: openedAt))
    }

    @Test("共享快照 JSON 可往返")
    func snapshotDocumentRoundTrip() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = BudgetSnapshot(
            cycleID: UUID(),
            phase: .active,
            todayBudgetCents: Decimal(string: "10666.666666")!,
            todayAvailableCents: Decimal(string: "6000.5")!,
            todaySpentCents: 3_999,
            currentBalanceCents: 96_001,
            daysRemaining: 9,
            startDate: now,
            payday: now.addingTimeInterval(9 * 24 * 60 * 60),
            paydayAnchorDay: 31,
            needsBalanceReview: false,
            generatedAt: now
        )
        let document = BudgetSnapshotDocument(
            snapshot: snapshot,
            nextRefresh: calendar.nextMidnight(after: now)
        )
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let store = BudgetSnapshotStore(directoryURL: directory)
        try store.write(document)
        let decoded = try #require(store.read())
        #expect(decoded == document)
    }

    @Test("深链解析只接受 known route")
    func deepLinks() {
        #expect(AppRoute(url: URL(string: "alive://quick-entry")!) == .quickEntry)
        #expect(AppRoute(url: URL(string: "alive://balance")!) == .balance)
        #expect(AppRoute(url: URL(string: "https://quick-entry")!) == nil)
    }
}
