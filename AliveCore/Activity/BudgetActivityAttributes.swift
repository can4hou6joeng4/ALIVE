import ActivityKit
import Foundation

public struct BudgetActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public let todayAvailableCents: Decimal
        public let currentBalanceCents: Int
        public let daysRemaining: Int
        public let phase: BudgetPhase
        public let updatedAt: Date

        public init(
            todayAvailableCents: Decimal,
            currentBalanceCents: Int,
            daysRemaining: Int,
            phase: BudgetPhase,
            updatedAt: Date
        ) {
            self.todayAvailableCents = todayAvailableCents
            self.currentBalanceCents = currentBalanceCents
            self.daysRemaining = daysRemaining
            self.phase = phase
            self.updatedAt = updatedAt
        }

        public var displayState: BudgetDisplayState {
            BudgetDisplayState(
                phase: phase,
                todayBudgetCents: max(0, todayAvailableCents),
                todayAvailableCents: todayAvailableCents,
                currentBalanceCents: currentBalanceCents
            )
        }
    }

    public let cycleID: UUID
    public let startDate: Date
    public let payday: Date

    public init(cycleID: UUID, startDate: Date, payday: Date) {
        self.cycleID = cycleID
        self.startDate = startDate
        self.payday = payday
    }
}
