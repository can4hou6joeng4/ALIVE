import Foundation

public struct CycleSetup: Codable, Hashable, Sendable {
    public var initialBalanceCents: Int
    public var startDate: Date
    public var nextPayday: Date

    public init(initialBalanceCents: Int, startDate: Date, nextPayday: Date) {
        self.initialBalanceCents = initialBalanceCents
        self.startDate = startDate
        self.nextPayday = nextPayday
    }
}

public struct BudgetCycle: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var startDate: Date
    public var paydayDate: Date
    public var paydayAnchorDay: Int
    public var carryoverBalanceCents: Int
    public var needsBalanceReview: Bool
    public let createdAt: Date
    public var closedAt: Date?

    public init(
        id: UUID = UUID(),
        startDate: Date,
        paydayDate: Date,
        paydayAnchorDay: Int,
        carryoverBalanceCents: Int,
        needsBalanceReview: Bool,
        createdAt: Date,
        closedAt: Date? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.paydayDate = paydayDate
        self.paydayAnchorDay = paydayAnchorDay
        self.carryoverBalanceCents = carryoverBalanceCents
        self.needsBalanceReview = needsBalanceReview
        self.createdAt = createdAt
        self.closedAt = closedAt
    }
}

public struct Expense: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let cycleID: UUID
    public var amountCents: Int
    public let occurredAt: Date
    public var note: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        cycleID: UUID,
        amountCents: Int,
        occurredAt: Date,
        note: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.cycleID = cycleID
        self.amountCents = amountCents
        self.occurredAt = occurredAt
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct BalanceAdjustment: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let cycleID: UUID
    public let deltaCents: Int
    public let reason: String
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        cycleID: UUID,
        deltaCents: Int,
        reason: String,
        createdAt: Date
    ) {
        self.id = id
        self.cycleID = cycleID
        self.deltaCents = deltaCents
        self.reason = reason
        self.createdAt = createdAt
    }
}

public struct DailyBudgetAnchor: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let cycleID: UUID
    public let dayStart: Date
    public var budgetCents: Decimal
    public var basisBalanceCents: Int
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        cycleID: UUID,
        dayStart: Date,
        budgetCents: Decimal,
        basisBalanceCents: Int,
        createdAt: Date
    ) {
        self.id = id
        self.cycleID = cycleID
        self.dayStart = dayStart
        self.budgetCents = budgetCents
        self.basisBalanceCents = basisBalanceCents
        self.createdAt = createdAt
    }
}

public enum BudgetPhase: String, Codable, CaseIterable, Hashable, Sendable {
    case pending
    case active
    case overspent
}

public struct BudgetSnapshot: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID { cycleID }

    public let cycleID: UUID
    public let phase: BudgetPhase
    public let todayBudgetCents: Decimal
    public let todayAvailableCents: Decimal
    public let todaySpentCents: Int
    public let currentBalanceCents: Int
    public let daysRemaining: Int
    public let startDate: Date
    public let payday: Date
    public let paydayAnchorDay: Int
    public let needsBalanceReview: Bool
    public let generatedAt: Date

    public init(
        cycleID: UUID,
        phase: BudgetPhase,
        todayBudgetCents: Decimal,
        todayAvailableCents: Decimal,
        todaySpentCents: Int,
        currentBalanceCents: Int,
        daysRemaining: Int,
        startDate: Date,
        payday: Date,
        paydayAnchorDay: Int,
        needsBalanceReview: Bool,
        generatedAt: Date
    ) {
        self.cycleID = cycleID
        self.phase = phase
        self.todayBudgetCents = todayBudgetCents
        self.todayAvailableCents = todayAvailableCents
        self.todaySpentCents = todaySpentCents
        self.currentBalanceCents = currentBalanceCents
        self.daysRemaining = daysRemaining
        self.startDate = startDate
        self.payday = payday
        self.paydayAnchorDay = paydayAnchorDay
        self.needsBalanceReview = needsBalanceReview
        self.generatedAt = generatedAt
    }

    public var displayState: BudgetDisplayState {
        BudgetDisplayState(snapshot: self)
    }

    /// Calendar days from the day this snapshot was generated until the cycle
    /// starts; 0 once it has started.
    ///
    /// This is the pending countdown. `daysRemaining` is not: in the pending
    /// phase it holds the projected length of the cycle, the divisor of the
    /// projected daily budget.
    public var daysUntilStart: Int {
        max(0, BudgetCalendar().calendarDays(from: generatedAt, to: startDate))
    }
}

/// Presentation-only state shared by the App and Live Activity.
///
/// The domain keeps `BudgetPhase` limited to pending/active/overspent so the
/// persisted calculations stay stable. This type adds the missing zero and
/// negative-balance distinctions required by PRD F3 without changing the
/// formula or the persisted snapshot.
public enum BudgetDisplayState: Equatable, Sendable {
    case pending(budgetCents: Decimal)
    case available(amountCents: Decimal)
    case overspent(overageCents: Decimal)
    case negativeBalance(balanceCents: Decimal, overageCents: Decimal?)
    case zeroBalance

    public init(snapshot: BudgetSnapshot) {
        self.init(
            phase: snapshot.phase,
            todayBudgetCents: snapshot.todayBudgetCents,
            todayAvailableCents: snapshot.todayAvailableCents,
            currentBalanceCents: snapshot.currentBalanceCents
        )
    }

    public init(
        phase: BudgetPhase,
        todayBudgetCents: Decimal,
        todayAvailableCents: Decimal,
        currentBalanceCents: Int
    ) {
        if phase == .pending {
            self = .pending(budgetCents: todayBudgetCents)
            return
        }
        if currentBalanceCents < 0 {
            self = .negativeBalance(
                balanceCents: Decimal(-currentBalanceCents),
                overageCents: todayAvailableCents < 0 ? -todayAvailableCents : nil
            )
            return
        }
        if todayAvailableCents < 0 {
            self = .overspent(overageCents: -todayAvailableCents)
            return
        }
        if currentBalanceCents == 0 {
            self = .zeroBalance
            return
        }
        self = .available(amountCents: max(0, todayAvailableCents))
    }

    /// The amount shown as the large number. It is always a magnitude.
    public var amountCents: Decimal {
        switch self {
        case .pending(let budget):
            budget
        case .available(let amount):
            amount
        case .overspent(let overage):
            overage
        case .negativeBalance(let balance, _):
            balance
        case .zeroBalance:
            0
        }
    }

    public var label: String {
        switch self {
        case .pending:
            "预计每日额度"
        case .available:
            "今天还可花"
        case .overspent:
            "今天已超出"
        case .negativeBalance:
            "余额已为负"
        case .zeroBalance:
            "今日额度不可用"
        }
    }

    public var isNegativeBalance: Bool {
        if case .negativeBalance = self { return true }
        return false
    }

    public var isZeroBalance: Bool {
        if case .zeroBalance = self { return true }
        return false
    }

    public var isOverspent: Bool {
        switch self {
        case .overspent, .negativeBalance:
            true
        case .pending, .available, .zeroBalance:
            false
        }
    }
}

public struct BudgetState: Codable, Equatable, Sendable {
    public var cycles: [BudgetCycle]
    public var expenses: [Expense]
    public var adjustments: [BalanceAdjustment]
    public var anchors: [DailyBudgetAnchor]

    public init(
        cycles: [BudgetCycle] = [],
        expenses: [Expense] = [],
        adjustments: [BalanceAdjustment] = [],
        anchors: [DailyBudgetAnchor] = []
    ) {
        self.cycles = cycles
        self.expenses = expenses
        self.adjustments = adjustments
        self.anchors = anchors
    }

    public func currentBalanceCents(cycleID: UUID) -> Int {
        let carryover = cycles.first(where: { $0.id == cycleID })?.carryoverBalanceCents ?? 0
        let expenseTotal = expenses
            .filter { $0.cycleID == cycleID }
            .reduce(0) { $0 + $1.amountCents }
        let adjustmentTotal = adjustments
            .filter { $0.cycleID == cycleID }
            .reduce(0) { $0 + $1.deltaCents }
        return carryover + adjustmentTotal - expenseTotal
    }
}

public struct BudgetResolution: Sendable {
    public let state: BudgetState
    public let snapshot: BudgetSnapshot?

    public init(state: BudgetState, snapshot: BudgetSnapshot?) {
        self.state = state
        self.snapshot = snapshot
    }
}

public struct ArchivedCycleSummary: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let startDate: Date
    public let paydayDate: Date
    public let startingBalanceCents: Int
    public let endingBalanceCents: Int
    public let needsBalanceReview: Bool
    public let expenses: [Expense]

    public init(
        id: UUID,
        startDate: Date,
        paydayDate: Date,
        startingBalanceCents: Int,
        endingBalanceCents: Int,
        needsBalanceReview: Bool,
        expenses: [Expense]
    ) {
        self.id = id
        self.startDate = startDate
        self.paydayDate = paydayDate
        self.startingBalanceCents = startingBalanceCents
        self.endingBalanceCents = endingBalanceCents
        self.needsBalanceReview = needsBalanceReview
        self.expenses = expenses
    }
}

public enum BudgetError: Error, Equatable, LocalizedError, Sendable {
    case noCycle
    case invalidAmount
    case invalidBalance
    case noteTooLong
    case invalidDates
    case cycleNotActive
    case cycleAlreadyStarted
    case archivedCycleReadOnly
    case expenseNotFound
    case expenseOutsideCurrentCycle
    case expenseAlreadyRecorded
    case storageUnavailable
    case snapshotUnavailable

    public var errorDescription: String? {
        switch self {
        case .noCycle:
            "还没有预算周期。"
        case .invalidAmount:
            "请输入大于 0 的金额。"
        case .invalidBalance:
            "请输入有效的当前余额。"
        case .noteTooLong:
            "备注最多 80 个字符。"
        case .invalidDates:
            "发薪日必须晚于起始日。"
        case .cycleNotActive:
            "周期尚未开始，暂时不能记录支出。"
        case .cycleAlreadyStarted:
            "周期已经开始，日期不可修改。"
        case .archivedCycleReadOnly:
            "归档周期只能查看，不能再修改。"
        case .expenseNotFound:
            "这笔支出已不存在。"
        case .expenseOutsideCurrentCycle:
            "只能修改当前周期的支出。"
        case .expenseAlreadyRecorded:
            "这笔支出已经记录，请返回 App 查看。"
        case .storageUnavailable:
            "本地数据暂时不可用，请稍后重试。"
        case .snapshotUnavailable:
            "无法更新共享预算状态。"
        }
    }
}
