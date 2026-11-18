import Foundation

public struct ProjectedBudget: Hashable, Sendable {
    public let cycleID: UUID
    public let phase: BudgetPhase
    public let todayBudgetCents: Decimal
    public let todayAvailableCents: Decimal
    public let currentBalanceCents: Int
    public let daysRemaining: Int
    public let startDate: Date
    public let payday: Date
    public let needsBalanceReview: Bool

    public init(
        cycleID: UUID,
        phase: BudgetPhase,
        todayBudgetCents: Decimal,
        todayAvailableCents: Decimal,
        currentBalanceCents: Int,
        daysRemaining: Int,
        startDate: Date,
        payday: Date,
        needsBalanceReview: Bool
    ) {
        self.cycleID = cycleID
        self.phase = phase
        self.todayBudgetCents = todayBudgetCents
        self.todayAvailableCents = todayAvailableCents
        self.currentBalanceCents = currentBalanceCents
        self.daysRemaining = daysRemaining
        self.startDate = startDate
        self.payday = payday
        self.needsBalanceReview = needsBalanceReview
    }

    public var displayState: BudgetDisplayState {
        BudgetDisplayState(
            phase: phase,
            todayBudgetCents: todayBudgetCents,
            todayAvailableCents: todayAvailableCents,
            currentBalanceCents: currentBalanceCents
        )
    }
}

public extension BudgetSnapshot {
    func projected(at date: Date, calendar: BudgetCalendar) -> ProjectedBudget {
        if calendar.isSameDay(date, generatedAt) {
            return ProjectedBudget(
                cycleID: cycleID,
                phase: phase,
                todayBudgetCents: todayBudgetCents,
                todayAvailableCents: todayAvailableCents,
                currentBalanceCents: currentBalanceCents,
                daysRemaining: daysRemaining,
                startDate: startDate,
                payday: payday,
                needsBalanceReview: needsBalanceReview
            )
        }

        var cycleStart = startDate
        var cyclePayday = payday
        var reviewNeeded = needsBalanceReview

        while date >= cyclePayday {
            cycleStart = cyclePayday
            cyclePayday = calendar.nextPayday(after: cyclePayday, anchorDay: paydayAnchorDay)
            reviewNeeded = true
        }

        if date < cycleStart {
            let days = max(1, calendar.calendarDays(from: cycleStart, to: cyclePayday))
            let budget = Decimal(max(0, currentBalanceCents)) / Decimal(days)
            return ProjectedBudget(
                cycleID: cycleID,
                phase: .pending,
                todayBudgetCents: budget,
                todayAvailableCents: budget,
                currentBalanceCents: currentBalanceCents,
                daysRemaining: days,
                startDate: cycleStart,
                payday: cyclePayday,
                needsBalanceReview: reviewNeeded
            )
        }

        let today = calendar.startOfDay(date)
        let days = max(1, calendar.calendarDays(from: today, to: cyclePayday))
        let budget = Decimal(max(0, currentBalanceCents)) / Decimal(days)
        let phase: BudgetPhase = currentBalanceCents < 0 ? .overspent : .active
        return ProjectedBudget(
            cycleID: cycleID,
            phase: phase,
            todayBudgetCents: budget,
            todayAvailableCents: budget,
            currentBalanceCents: currentBalanceCents,
            daysRemaining: days,
            startDate: cycleStart,
            payday: cyclePayday,
            needsBalanceReview: reviewNeeded
        )
    }
}
