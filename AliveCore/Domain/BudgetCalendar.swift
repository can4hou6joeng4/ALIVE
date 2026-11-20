import Foundation

public struct BudgetCalendar: Sendable {
    /// ALIVE 固定使用北京时间（Asia/Shanghai）作为预算日界线。
    /// 这避免跨时区时发薪日与“今天”的本地午夜漂移；产品决策见 PRD 核心公式。
    public static let fixedTimeZone: TimeZone = TimeZone(identifier: "Asia/Shanghai")
        ?? TimeZone(secondsFromGMT: 8 * 60 * 60)!

    public var calendar: Calendar

    public init(timeZone: TimeZone = BudgetCalendar.fixedTimeZone, locale: Locale = Locale(identifier: "zh_CN")) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = locale
        calendar.firstWeekday = 2
        self.calendar = calendar
    }

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    public var timeZone: TimeZone {
        calendar.timeZone
    }

    public func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    public func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    public func calendarDays(from start: Date, to end: Date) -> Int {
        calendar.dateComponents(
            [.day],
            from: startOfDay(start),
            to: startOfDay(end)
        ).day ?? 0
    }

    public func nextMidnight(after date: Date) -> Date {
        let dayStart = startOfDay(date)
        return calendar.date(byAdding: .day, value: 1, to: dayStart) ?? .distantFuture
    }

    public func nextPayday(after date: Date, anchorDay: Int) -> Date {
        let safeAnchor = min(max(anchorDay, 1), 31)
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: date)
        ) ?? startOfDay(date)

        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart),
              let dayRange = calendar.range(of: .day, in: .month, for: nextMonth) else {
            return .distantFuture
        }

        var components = calendar.dateComponents([.year, .month], from: nextMonth)
        components.day = min(safeAnchor, dayRange.count)
        return startOfDay(calendar.date(from: components) ?? nextMonth)
    }

    public func anchorDay(for payday: Date) -> Int {
        calendar.component(.day, from: payday)
    }

    public func earliestDate(_ dates: [Date]) -> Date? {
        dates.min()
    }
}
