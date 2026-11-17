import Foundation
import SwiftData

@Model
final class CycleRecord {
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var paydayDate: Date
    var paydayAnchorDay: Int
    var carryoverBalanceCents: Int
    var needsBalanceReview: Bool
    var createdAt: Date
    var closedAt: Date?

    init(cycle: BudgetCycle) {
        id = cycle.id
        startDate = cycle.startDate
        paydayDate = cycle.paydayDate
        paydayAnchorDay = cycle.paydayAnchorDay
        carryoverBalanceCents = cycle.carryoverBalanceCents
        needsBalanceReview = cycle.needsBalanceReview
        createdAt = cycle.createdAt
        closedAt = cycle.closedAt
    }

    func apply(_ cycle: BudgetCycle) {
        startDate = cycle.startDate
        paydayDate = cycle.paydayDate
        paydayAnchorDay = cycle.paydayAnchorDay
        carryoverBalanceCents = cycle.carryoverBalanceCents
        needsBalanceReview = cycle.needsBalanceReview
        closedAt = cycle.closedAt
    }

    var value: BudgetCycle {
        BudgetCycle(
            id: id,
            startDate: startDate,
            paydayDate: paydayDate,
            paydayAnchorDay: paydayAnchorDay,
            carryoverBalanceCents: carryoverBalanceCents,
            needsBalanceReview: needsBalanceReview,
            createdAt: createdAt,
            closedAt: closedAt
        )
    }
}

@Model
final class ExpenseRecord {
    @Attribute(.unique) var id: UUID
    var cycleID: UUID
    var amountCents: Int
    var occurredAt: Date
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    init(expense: Expense) {
        id = expense.id
        cycleID = expense.cycleID
        amountCents = expense.amountCents
        occurredAt = expense.occurredAt
        note = expense.note
        createdAt = expense.createdAt
        updatedAt = expense.updatedAt
    }

    func apply(_ expense: Expense) {
        cycleID = expense.cycleID
        amountCents = expense.amountCents
        occurredAt = expense.occurredAt
        note = expense.note
        updatedAt = expense.updatedAt
    }

    var value: Expense {
        Expense(
            id: id,
            cycleID: cycleID,
            amountCents: amountCents,
            occurredAt: occurredAt,
            note: note,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@Model
final class AdjustmentRecord {
    @Attribute(.unique) var id: UUID
    var cycleID: UUID
    var deltaCents: Int
    var reason: String
    var createdAt: Date

    init(adjustment: BalanceAdjustment) {
        id = adjustment.id
        cycleID = adjustment.cycleID
        deltaCents = adjustment.deltaCents
        reason = adjustment.reason
        createdAt = adjustment.createdAt
    }

    func apply(_ adjustment: BalanceAdjustment) {
        cycleID = adjustment.cycleID
        deltaCents = adjustment.deltaCents
        reason = adjustment.reason
    }

    var value: BalanceAdjustment {
        BalanceAdjustment(
            id: id,
            cycleID: cycleID,
            deltaCents: deltaCents,
            reason: reason,
            createdAt: createdAt
        )
    }
}

@Model
final class AnchorRecord {
    @Attribute(.unique) var id: UUID
    var cycleID: UUID
    var dayStart: Date
    var budgetCents: Decimal
    var basisBalanceCents: Int
    var createdAt: Date

    init(anchor: DailyBudgetAnchor) {
        id = anchor.id
        cycleID = anchor.cycleID
        dayStart = anchor.dayStart
        budgetCents = anchor.budgetCents
        basisBalanceCents = anchor.basisBalanceCents
        createdAt = anchor.createdAt
    }

    func apply(_ anchor: DailyBudgetAnchor) {
        cycleID = anchor.cycleID
        dayStart = anchor.dayStart
        budgetCents = anchor.budgetCents
        basisBalanceCents = anchor.basisBalanceCents
    }

    var value: DailyBudgetAnchor {
        DailyBudgetAnchor(
            id: id,
            cycleID: cycleID,
            dayStart: dayStart,
            budgetCents: budgetCents,
            basisBalanceCents: basisBalanceCents,
            createdAt: createdAt
        )
    }
}
