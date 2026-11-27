import AliveCore
import Foundation

enum AliveDateText {
    private static let monthDayFormatter = makeFormatter("M月d日")
    private static let fullDayFormatter = makeFormatter("yyyy年M月d日")
    private static let timeFormatter = makeFormatter("HH:mm")

    static func monthDay(_ date: Date) -> String {
        monthDayFormatter.string(from: date)
    }

    static func fullDay(_ date: Date) -> String {
        fullDayFormatter.string(from: date)
    }

    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func range(_ start: Date, _ end: Date) -> String {
        "\(monthDay(start)) — \(monthDay(end))"
    }

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = BudgetCalendar.fixedTimeZone
        formatter.dateFormat = format
        return formatter
    }
}
