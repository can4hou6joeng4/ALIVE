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

    @Test("深链解析只接受 known route")
    func deepLinks() {
        #expect(AppRoute(url: URL(string: "alive://quick-entry")!) == .quickEntry)
        #expect(AppRoute(url: URL(string: "alive://live-entry")!) == .liveEntry)
        #expect(AppRoute.liveEntry.url.absoluteString == "alive://live-entry")
        #expect(AppRoute(url: URL(string: "alive://balance")!) == .balance)
        #expect(AppRoute(url: URL(string: "https://quick-entry")!) == nil)
    }

    @Test("灵动岛金额键盘遵守 9 位整数和 2 位小数")
    func liveEntryKeypad() {
        var state = LiveEntryState(step: .amount)
        for key in ["1", "8", ".", "6", "0"] {
            state.applyKey(key)
        }
        #expect(state.amountText == "18.60")
        #expect(state.amountCents == 1_860)
        #expect(state.canAdvance)

        state.applyKey("1")
        #expect(state.amountText == "18.60")

        state.applyKey("backspace")
        #expect(state.amountText == "18.6")

        var longInteger = LiveEntryState(step: .amount)
        for _ in 0..<12 {
            longInteger.applyKey("9")
        }
        #expect(longInteger.amountText == "999999999")

        var longDecimal = LiveEntryState(step: .amount, amountText: "1.23")
        longDecimal.applyKey("4")
        #expect(longDecimal.amountText == "1.23")

        var decimalFromEmpty = LiveEntryState(step: .amount)
        decimalFromEmpty.applyKey(".")
        #expect(decimalFromEmpty.amountText == "0.")
        decimalFromEmpty.applyKey(".")
        #expect(decimalFromEmpty.amountText == "0.")
    }

    @Test("灵动岛金额必须大于 0 才能进入备注")
    func liveEntryAdvanceValidation() {
        var state = LiveEntryState(step: .amount)
        let emptyAdvance = state.advanceToNote()
        #expect(!emptyAdvance)
        #expect(state.step == .amount)

        state.applyKey("0")
        let zeroAdvance = state.advanceToNote()
        #expect(!zeroAdvance)

        state.applyKey(".")
        state.applyKey("1")
        #expect(state.amountText == "0.1")
        let validAdvance = state.advanceToNote()
        #expect(validAdvance)
        #expect(state.step == .note)
    }

    @Test("灵动岛备注只接受三个固定标签")
    func liveEntryNotes() {
        var state = LiveEntryState(step: .note, amountText: "18.60")
        let acceptedDrink = state.selectNote("🥤")
        #expect(acceptedDrink)
        #expect(state.note == "🥤")

        let acceptedMeal = state.selectNote("🍚")
        #expect(acceptedMeal)
        #expect(state.note == "🍚")

        let acceptedOther = state.selectNote("其他")
        #expect(acceptedOther)
        #expect(state.note == "其他")

        let rejectedLunch = state.selectNote("午饭")
        #expect(!rejectedLunch)
        #expect(state.note == "其他")

        let rejectedCustom = state.selectNote("自定义")
        #expect(!rejectedCustom)
        #expect(state.note == "其他")
    }

    @Test("Live Activity 旧内容缺少草稿字段时按摘要态解码")
    func liveEntryLegacyContentState() throws {
        let oldJSON = """
        {
          "todayAvailableCents": 10000,
          "currentBalanceCents": 100000,
          "daysRemaining": 10,
          "phase": "active",
          "updatedAt": 0
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(
            BudgetActivityAttributes.ContentState.self,
            from: oldJSON
        )
        #expect(state.liveEntry == nil)
        #expect(state.todayAvailableCents == 10_000)
        #expect(state.currentBalanceCents == 100_000)
    }

    @Test("同金额独立草稿有不同标识，编码后标识保持")
    func liveEntryDraftIdentity() throws {
        let first = LiveEntryState(step: .amount, amountText: "18.60")
        let second = LiveEntryState(step: .amount, amountText: "18.60")
        #expect(first.draftID != nil)
        #expect(first.draftID != second.draftID)

        let decoded = try JSONDecoder().decode(
            LiveEntryState.self,
            from: JSONEncoder().encode(first)
        )
        #expect(decoded.draftID == first.draftID)
        #expect(decoded.amountCents == 1_860)
    }

    @Test("旧版草稿无需标识即可解码，进入备注时补齐")
    func liveEntryLegacyDraftIdentity() throws {
        let json = """
        {"step":"amount","amountText":"18.60"}
        """.data(using: .utf8)!
        var decoded = try JSONDecoder().decode(LiveEntryState.self, from: json)
        #expect(decoded.draftID == nil)
        let advanced = decoded.advanceToNote()
        #expect(advanced)
        #expect(decoded.draftID != nil)
        #expect(decoded.amountCents == 1_860)
    }

    @Test("Live Activity 草稿更新保留预算摘要")
    func liveEntryContentStatePreservesBudget() {
        let state = BudgetActivityAttributes.ContentState(
            todayAvailableCents: 8_140,
            currentBalanceCents: 298_140,
            daysRemaining: 30,
            phase: .active,
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let draft = state.updating(liveEntry: LiveEntryState(step: .amount, amountText: "18.60"))
        #expect(draft.todayAvailableCents == 8_140)
        #expect(draft.currentBalanceCents == 298_140)
        #expect(draft.daysRemaining == 30)
        #expect(draft.liveEntry?.amountText == "18.60")
    }

    @Test("远程刷新前的并发按键不丢失，下一步使用最新草稿")
    func liveEntryConcurrentKeys() async {
        let coordinator = LiveEntryUpdateCoordinator()
        let draft = LiveEntryState(step: .amount)
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    await coordinator.apply(.key("1"), activityID: "activity", fallback: draft)
                }
            }
        }
        await coordinator.apply(.advance, activityID: "activity", fallback: draft)
        let state = await coordinator.state(activityID: "activity", fallback: draft)
        #expect(state?.amountText == "11111111")
        #expect(state?.step == .note)
        #expect(state?.draftID == draft.draftID)
    }

    @Test("完成后拒绝旧按键和旧快照，再记一笔创建独立草稿")
    func liveEntryCompletionRejectsStaleState() async {
        let coordinator = LiveEntryUpdateCoordinator()
        let draft = LiveEntryState(step: .amount, amountText: "42")
        await coordinator.apply(.finish, activityID: "activity", fallback: draft)
        let acceptedKey = await coordinator.apply(.key("3"), activityID: "activity", fallback: draft)
        #expect(!acceptedKey)
        let cleared = await coordinator.state(activityID: "activity", fallback: draft)
        #expect(cleared == nil)
        await coordinator.apply(.begin, activityID: "activity", fallback: draft)
        let next = await coordinator.state(activityID: "activity", fallback: draft)
        #expect(next?.step == .amount)
        #expect(next?.amountText == "")
        #expect(next?.draftID != draft.draftID)
    }

    @Test("远程更新阻塞时合并后续刷新，最终发布完成状态")
    func liveEntryCoalescesInFlightUpdates() async {
        let coordinator = LiveEntryUpdateCoordinator()
        let recorder = LiveEntryPublicationRecorder()
        let started = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        let draft = LiveEntryState(step: .amount, amountText: "4")
        await coordinator.store(draft, activityID: "activity")

        let publication = Task {
            await coordinator.publish(activityID: "activity") { update in
                let count = await recorder.record(update)
                if count == 1 {
                    started.continuation.yield(())
                    for await _ in release.stream { break }
                }
            }
        }
        for await _ in started.stream { break }

        await coordinator.apply(.key("2"), activityID: "activity", fallback: draft)
        await coordinator.apply(.advance, activityID: "activity", fallback: draft)
        await coordinator.apply(.finish, activityID: "activity", fallback: draft)
        await coordinator.publish(activityID: "activity") { update in
            await recorder.record(update)
        }
        release.continuation.yield(())
        await publication.value
        started.continuation.finish()
        release.continuation.finish()

        let updates = await recorder.updates
        #expect(updates.count == 2)
        #expect(updates.first?.liveEntry?.amountText == "4")
        #expect(updates.last?.liveEntry == nil)
        #expect(updates.first?.revision != updates.last?.revision)
    }
}

private actor LiveEntryPublicationRecorder {
    private(set) var updates: [LiveEntryUpdateCoordinator.Update] = []

    @discardableResult
    func record(_ update: LiveEntryUpdateCoordinator.Update) -> Int {
        updates.append(update)
        return updates.count
    }
}
