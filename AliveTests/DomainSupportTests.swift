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
