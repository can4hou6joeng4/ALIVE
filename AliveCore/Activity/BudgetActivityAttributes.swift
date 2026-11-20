import ActivityKit
import Foundation

public struct BudgetActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public let todayAvailableCents: Decimal
        public let currentBalanceCents: Int
        public let daysRemaining: Int
        public let phase: BudgetPhase
        public let updatedAt: Date
        public let liveEntry: LiveEntryState?

        public init(
            todayAvailableCents: Decimal,
            currentBalanceCents: Int,
            daysRemaining: Int,
            phase: BudgetPhase,
            updatedAt: Date,
            liveEntry: LiveEntryState? = nil
        ) {
            self.todayAvailableCents = todayAvailableCents
            self.currentBalanceCents = currentBalanceCents
            self.daysRemaining = daysRemaining
            self.phase = phase
            self.updatedAt = updatedAt
            self.liveEntry = liveEntry
        }

        public var displayState: BudgetDisplayState {
            BudgetDisplayState(
                phase: phase,
                todayBudgetCents: max(0, todayAvailableCents),
                todayAvailableCents: todayAvailableCents,
                currentBalanceCents: currentBalanceCents
            )
        }

        public func updating(liveEntry: LiveEntryState?) -> ContentState {
            ContentState(
                todayAvailableCents: todayAvailableCents,
                currentBalanceCents: currentBalanceCents,
                daysRemaining: daysRemaining,
                phase: phase,
                updatedAt: updatedAt,
                liveEntry: liveEntry
            )
        }

        public func updating(
            budget snapshot: BudgetSnapshot,
            liveEntry: LiveEntryState?
        ) -> ContentState {
            ContentState(
                todayAvailableCents: snapshot.todayAvailableCents,
                currentBalanceCents: snapshot.currentBalanceCents,
                daysRemaining: snapshot.daysRemaining,
                phase: snapshot.phase,
                updatedAt: snapshot.generatedAt,
                liveEntry: liveEntry
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
