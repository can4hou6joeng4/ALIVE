import Foundation

public enum MoneyFormatter {
    public static func currency(cents: Int) -> String {
        currency(cents: Decimal(cents))
    }

    public static func currency(cents: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .halfUp
        formatter.usesGroupingSeparator = true
        let yuan = cents / Decimal(100)
        return formatter.string(from: NSDecimalNumber(decimal: yuan)) ?? "¥0.00"
    }

    public static func yuan(cents: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .halfUp
        formatter.usesGroupingSeparator = true
        let yuan = cents / Decimal(100)
        return formatter.string(from: NSDecimalNumber(decimal: yuan)) ?? "0.00"
    }

    /// Compact amount for narrow Live Activity surfaces. Keeps Decimal end-to-end.
    public static func compactYuan(cents: Decimal) -> String {
        let yuan = cents / Decimal(100)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.numberStyle = .decimal
        formatter.roundingMode = .halfUp
        formatter.usesGroupingSeparator = true
        if yuan >= 1_000 {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
        } else {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 1
        }
        return formatter.string(from: NSDecimalNumber(decimal: yuan)) ?? "0"
    }

    public static func spoken(cents: Decimal) -> String {
        "\(yuan(cents: cents)) 元"
    }

    public static func editText(cents: Int) -> String {
        yuan(cents: Decimal(cents))
    }
}

public enum MoneyParser {
    public static func cents(from text: String, allowNegative: Bool = false) -> Int? {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "，", with: "")
        guard !cleaned.isEmpty else { return nil }

        let pattern = allowNegative ? #"^-?\d{1,9}(\.\d{1,2})?$"# : #"^\d{1,9}(\.\d{1,2})?$"#
        guard cleaned.range(of: pattern, options: .regularExpression) != nil else {
            return nil
        }
        guard let decimal = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }

        let centsValue = decimal * Decimal(100)
        var rounded = Decimal()
        var raw = centsValue
        NSDecimalRound(&rounded, &raw, 0, .plain)
        guard rounded <= Decimal(Int.max), rounded >= Decimal(Int.min) else { return nil }
        return NSDecimalNumber(decimal: rounded).intValue
    }
}
