import AliveCore
import SwiftUI
import UIKit

enum WidgetColor {
    static var canvas: Color {
        dynamic(light: 0xF2F2F7, dark: 0x000000)
    }

    static var card: Color {
        dynamic(light: 0xF4F1EA, dark: 0x10163A)
    }

    static var ink: Color {
        dynamic(light: 0x000000, dark: 0xFFFFFF)
    }

    static var inkSecondary: Color {
        dynamic(light: 0x3C3C43, dark: 0xEBEBF5)
    }

    static var inkTertiary: Color {
        dynamic(light: 0x5B5B61, dark: 0xA1A1AA)
    }

    static var accent: Color {
        dynamic(light: 0x007AFF, dark: 0x0A84FF)
    }

    static var accentHighlight: Color {
        Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255)
    }

    static var overspend: Color {
        dynamic(light: 0xB3261E, dark: 0xFF9A8A)
    }

    static var line: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.14)
                : UIColor.black.withAlphaComponent(0.10)
        })
    }

    // The Dynamic Island container stays black in both themes, so these colors are fixed
    // instead of resolving against the system/app color scheme.
    static var islandInk: Color {
        Color.white
    }

    static var islandInkMuted: Color {
        Color.white.opacity(0.66)
    }

    static var islandInkSecondary: Color {
        Color.white.opacity(0.82)
    }

    static var islandActionFill: Color {
        Color(red: 138 / 255, green: 197 / 255, blue: 255 / 255)
    }

    static var islandOverspend: Color {
        Color(red: 1, green: 154 / 255, blue: 138 / 255)
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

enum WidgetFont {
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .caption) -> Font {
        .system(size: size, weight: weight)
    }
}

enum WidgetAmount {
    /// Above ¥1,000,000 the fixed two-decimal currency string is too long for a
    /// single Live Activity line, so the compact representation is used as a fallback.
    static let compactThresholdCents: Decimal = 100_000_000

    static func standard(cents: Decimal) -> String {
        if cents >= compactThresholdCents {
            return compact(cents: cents)
        }
        return MoneyFormatter.currency(cents: cents)
    }

    static func compact(cents: Decimal) -> String {
        "¥\(MoneyFormatter.compactYuan(cents: cents))"
    }

}
