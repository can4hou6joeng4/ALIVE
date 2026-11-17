import Foundation
import ActivityKit

public struct LiveActivityWindow: Sendable {
    public static let maximumDuration: TimeInterval = 8 * 60 * 60

    public let openedAt: Date
    public let staleDate: Date

    public init(openedAt: Date, staleDate: Date) {
        self.openedAt = openedAt
        self.staleDate = staleDate
    }

    public static func calculate(
        snapshot: BudgetSnapshot,
        openedAt: Date,
        calendar: BudgetCalendar = BudgetCalendar()
    ) -> LiveActivityWindow {
        let eightHoursLater = openedAt.addingTimeInterval(maximumDuration)
        let midnight = calendar.nextMidnight(after: openedAt)
        let payday = calendar.startOfDay(snapshot.payday)
        let stale = [eightHoursLater, midnight, payday].min() ?? eightHoursLater
        return LiveActivityWindow(openedAt: openedAt, staleDate: stale)
    }
}
