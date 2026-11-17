import Foundation

public struct BudgetResolver: Sendable {
    public let calendar: BudgetCalendar

    public init(calendar: BudgetCalendar = BudgetCalendar()) {
        self.calendar = calendar
    }

    public func initialResolution(setup: CycleSetup, now: Date) throws -> BudgetResolution {
        try validate(setup: setup)

        let start = calendar.startOfDay(setup.startDate)
        let payday = calendar.startOfDay(setup.nextPayday)
        let cycle = BudgetCycle(
            startDate: start,
            paydayDate: payday,
            paydayAnchorDay: calendar.anchorDay(for: payday),
            carryoverBalanceCents: setup.initialBalanceCents,
            needsBalanceReview: false,
            createdAt: now
        )
        let state = BudgetState(cycles: [cycle])
        return resolve(state, now: now)
    }

    public func resolve(_ input: BudgetState, now: Date) -> BudgetResolution {
        var state = input
        state.cycles.sort { $0.startDate < $1.startDate }

        guard !state.cycles.isEmpty else {
            return BudgetResolution(state: state, snapshot: nil)
        }

        var current = state.cycles[state.cycles.count - 1]
        var currentIndex = state.cycles.count - 1

        while now >= current.paydayDate {
            let endingBalance = state.currentBalanceCents(cycleID: current.id)
            let closedDate = current.paydayDate
            state.cycles[currentIndex].closedAt = closedDate

            let nextPayday = calendar.nextPayday(
                after: current.paydayDate,
                anchorDay: current.paydayAnchorDay
            )
            let nextCycle = BudgetCycle(
                startDate: current.paydayDate,
                paydayDate: nextPayday,
                paydayAnchorDay: current.paydayAnchorDay,
                carryoverBalanceCents: endingBalance,
                needsBalanceReview: true,
                createdAt: now
            )
            state.cycles.append(nextCycle)
            currentIndex = state.cycles.count - 1
            current = state.cycles[currentIndex]
        }

        let currentBalance = state.currentBalanceCents(cycleID: current.id)

        if now < current.startDate {
            let projectedDays = max(1, calendar.calendarDays(from: current.startDate, to: current.paydayDate))
            let projectedBudget = Decimal(max(0, currentBalance)) / Decimal(projectedDays)
            let snapshot = BudgetSnapshot(
                cycleID: current.id,
                phase: .pending,
                todayBudgetCents: projectedBudget,
                todayAvailableCents: projectedBudget,
                todaySpentCents: 0,
                currentBalanceCents: currentBalance,
                daysRemaining: projectedDays,
                startDate: current.startDate,
                payday: current.paydayDate,
                paydayAnchorDay: current.paydayAnchorDay,
                needsBalanceReview: current.needsBalanceReview,
                generatedAt: now
            )
            return BudgetResolution(state: state, snapshot: snapshot)
        }

        let today = calendar.startOfDay(now)
        let remainingDays = max(1, calendar.calendarDays(from: today, to: current.paydayDate))
        let todayExpenses = state.expenses.filter {
            $0.cycleID == current.id && calendar.isSameDay($0.occurredAt, now)
        }
        let todaySpent = todayExpenses.reduce(0) { $0 + $1.amountCents }

        let existingAnchorIndex = state.anchors.lastIndex {
            $0.cycleID == current.id && calendar.isSameDay($0.dayStart, today)
        }

        let budget: Decimal
        if let existingAnchorIndex {
            budget = state.anchors[existingAnchorIndex].budgetCents
        } else {
            budget = Decimal(max(0, currentBalance)) / Decimal(remainingDays)
            state.anchors.append(
                DailyBudgetAnchor(
                    cycleID: current.id,
                    dayStart: today,
                    budgetCents: budget,
                    basisBalanceCents: currentBalance,
                    createdAt: now
                )
            )
        }

        let todayAvailable = budget - Decimal(todaySpent)
        let phase: BudgetPhase = (todayAvailable < 0 || currentBalance < 0) ? .overspent : .active
        let snapshot = BudgetSnapshot(
            cycleID: current.id,
            phase: phase,
            todayBudgetCents: budget,
            todayAvailableCents: todayAvailable,
            todaySpentCents: todaySpent,
            currentBalanceCents: currentBalance,
            daysRemaining: remainingDays,
            startDate: current.startDate,
            payday: current.paydayDate,
            paydayAnchorDay: current.paydayAnchorDay,
            needsBalanceReview: current.needsBalanceReview,
            generatedAt: now
        )
        return BudgetResolution(state: state, snapshot: snapshot)
    }

    public func addExpense(
        to state: BudgetState,
        amountCents: Int,
        note: String?,
        at date: Date
    ) throws -> BudgetResolution {
        guard amountCents > 0 else { throw BudgetError.invalidAmount }
        let cleanedNote = try validatedNote(note)

        let initial = resolve(state, now: date)
        guard let snapshot = initial.snapshot else { throw BudgetError.noCycle }
        guard snapshot.phase != .pending else { throw BudgetError.cycleNotActive }
        guard date >= snapshot.startDate, date < snapshot.payday else {
            throw BudgetError.cycleNotActive
        }

        var updated = initial.state
        updated.expenses.append(
            Expense(
                cycleID: snapshot.cycleID,
                amountCents: amountCents,
                occurredAt: date,
                note: cleanedNote,
                createdAt: date,
                updatedAt: date
            )
        )
        return resolve(updated, now: date)
    }

    public func updateExpense(
        in state: BudgetState,
        id: UUID,
        amountCents: Int,
        note: String?,
        now: Date
    ) throws -> BudgetResolution {
        guard amountCents > 0 else { throw BudgetError.invalidAmount }
        let cleanedNote = try validatedNote(note)
        let initial = resolve(state, now: now)
        guard let snapshot = initial.snapshot else { throw BudgetError.noCycle }
        guard let index = initial.state.expenses.firstIndex(where: { $0.id == id }) else {
            throw BudgetError.expenseNotFound
        }
        guard initial.state.expenses[index].cycleID == snapshot.cycleID else {
            throw BudgetError.archivedCycleReadOnly
        }

        var updated = initial.state
        updated.expenses[index].amountCents = amountCents
        updated.expenses[index].note = cleanedNote
        updated.expenses[index].updatedAt = now
        return resolve(updated, now: now)
    }

    public func deleteExpense(
        in state: BudgetState,
        id: UUID,
        now: Date
    ) throws -> BudgetResolution {
        let initial = resolve(state, now: now)
        guard let snapshot = initial.snapshot else { throw BudgetError.noCycle }
        guard let expense = initial.state.expenses.first(where: { $0.id == id }) else {
            throw BudgetError.expenseNotFound
        }
        guard expense.cycleID == snapshot.cycleID else {
            throw BudgetError.archivedCycleReadOnly
        }

        var updated = initial.state
        updated.expenses.removeAll { $0.id == id }
        return resolve(updated, now: now)
    }

    public func overrideCurrentBalance(
        in state: BudgetState,
        cents: Int,
        at date: Date
    ) throws -> BudgetResolution {
        let initial = resolve(state, now: date)
        guard let snapshot = initial.snapshot else { throw BudgetError.noCycle }
        guard snapshot.phase != .pending else { throw BudgetError.cycleNotActive }

        let computedBalance = initial.state.currentBalanceCents(cycleID: snapshot.cycleID)
        let delta = cents - computedBalance

        var updated = initial.state
        updated.adjustments.append(
            BalanceAdjustment(
                cycleID: snapshot.cycleID,
                deltaCents: delta,
                reason: "manualOverride",
                createdAt: date
            )
        )

        let today = calendar.startOfDay(date)
        if let anchorIndex = updated.anchors.lastIndex(where: {
            $0.cycleID == snapshot.cycleID && calendar.isSameDay($0.dayStart, today)
        }) {
            let resetAvailable = Decimal(max(0, cents)) / Decimal(snapshot.daysRemaining)
            updated.anchors[anchorIndex].budgetCents = resetAvailable + Decimal(snapshot.todaySpentCents)
            updated.anchors[anchorIndex].basisBalanceCents = cents
        }

        return resolve(updated, now: date)
    }

    public func updatePendingCycle(
        in state: BudgetState,
        setup: CycleSetup,
        now: Date
    ) throws -> BudgetResolution {
        try validate(setup: setup)

        let initial = resolve(state, now: now)
        guard let snapshot = initial.snapshot, snapshot.phase == .pending else {
            throw BudgetError.cycleAlreadyStarted
        }

        var updated = initial.state
        guard let index = updated.cycles.firstIndex(where: { $0.id == snapshot.cycleID }) else {
            throw BudgetError.noCycle
        }

        let start = calendar.startOfDay(setup.startDate)
        let payday = calendar.startOfDay(setup.nextPayday)
        guard start < payday else { throw BudgetError.invalidDates }

        updated.cycles[index].startDate = start
        updated.cycles[index].paydayDate = payday
        updated.cycles[index].paydayAnchorDay = calendar.anchorDay(for: payday)
        updated.cycles[index].carryoverBalanceCents = setup.initialBalanceCents
        updated.cycles[index].needsBalanceReview = false
        return resolve(updated, now: now)
    }

    public func archivedSummaries(in state: BudgetState, now: Date) -> [ArchivedCycleSummary] {
        let resolved = resolve(state, now: now).state
        return resolved.cycles
            .filter { $0.closedAt != nil }
            .sorted { $0.startDate > $1.startDate }
            .map { cycle in
                ArchivedCycleSummary(
                    id: cycle.id,
                    startDate: cycle.startDate,
                    paydayDate: cycle.paydayDate,
                    startingBalanceCents: cycle.carryoverBalanceCents,
                    endingBalanceCents: resolved.currentBalanceCents(cycleID: cycle.id),
                    needsBalanceReview: cycle.needsBalanceReview,
                    expenses: resolved.expenses
                        .filter { $0.cycleID == cycle.id }
                        .sorted { $0.occurredAt > $1.occurredAt }
                )
            }
    }

    private func validate(setup: CycleSetup) throws {
        guard setup.initialBalanceCents > 0 else { throw BudgetError.invalidAmount }
        guard calendar.startOfDay(setup.startDate) < calendar.startOfDay(setup.nextPayday) else {
            throw BudgetError.invalidDates
        }
    }

    private func validatedNote(_ note: String?) throws -> String? {
        guard let note else { return nil }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count <= 80 else { throw BudgetError.noteTooLong }
        return trimmed
    }
}
