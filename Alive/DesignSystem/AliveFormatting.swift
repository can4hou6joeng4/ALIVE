import Foundation

enum AliveDateText {
    static func monthDay(_ date: Date) -> String {
        formatter("M月d日").string(from: date)
    }

    static func fullDay(_ date: Date) -> String {
        formatter("yyyy年M月d日").string(from: date)
    }

    static func time(_ date: Date) -> String {
        formatter("HH:mm").string(from: date)
    }

    static func range(_ start: Date, _ end: Date) -> String {
        "\(monthDay(start)) — \(monthDay(end))"
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = format
        return formatter
    }
}
