import SwiftUI
import UIKit

enum AliveColor {
    static var canvas: Color {
        dynamic(light: 0xF2F2F7, dark: 0x000000)
    }

    static var surface: Color {
        dynamic(light: 0xFFFFFF, dark: 0x1C1C1E)
    }

    static var card: Color {
        dynamic(light: 0xFFFFFF, dark: 0x1C1C1E)
    }

    static var surfaceElevated: Color {
        dynamic(light: 0xFFFFFF, dark: 0x2C2C2E)
    }

    static var surfaceSunken: Color {
        dynamic(light: 0xE9E9EE, dark: 0x111114)
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

    static var separator: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.14)
                : UIColor.black.withAlphaComponent(0.10)
        })
    }

    static var accent: Color {
        dynamic(light: 0x007AFF, dark: 0x0A84FF)
    }

    static var accentFill: Color {
        dynamic(light: 0x0062CC, dark: 0x0066CC)
    }

    static var accentTint: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 10 / 255, green: 132 / 255, blue: 255 / 255, alpha: 0.22)
                : UIColor(red: 0, green: 122 / 255, blue: 1, alpha: 0.12)
        })
    }

    static var overspend: Color {
        dynamic(light: 0xB3261E, dark: 0xFF9A8A)
    }

    static var progress: Color {
        accent
    }

    static var focus: Color {
        accent
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

enum AliveSpace {
    static let x1: CGFloat = 4
    static let x2: CGFloat = 8
    static let x3: CGFloat = 12
    static let x4: CGFloat = 16
    static let x5: CGFloat = 20
    static let x6: CGFloat = 24
    static let x8: CGFloat = 32
    static let x10: CGFloat = 40
    static let pageInset: CGFloat = 20
}

enum AliveRadius {
    static let card: CGFloat = 20
    static let control: CGFloat = 14
    static let pill: CGFloat = 999
}

enum AliveMotion {
    static let quick = Animation.easeOut(duration: 0.18)
    static let value = Animation.easeOut(duration: 0.32)
    static let enter = Animation.easeOut(duration: 0.22)
}

enum AliveFont {
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .system(
            size: scaled(size, relativeTo: style, maximumScale: 1.75),
            weight: .semibold,
            design: .rounded
        )
    }

    static func sans(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo style: Font.TextStyle = .body
    ) -> Font {
        .system(size: scaled(size, relativeTo: style), weight: weight)
    }

    private static func scaled(
        _ size: CGFloat,
        relativeTo style: Font.TextStyle,
        maximumScale: CGFloat? = nil
    ) -> CGFloat {
        let metrics = UIFontMetrics(forTextStyle: uiTextStyle(for: style))
        let scaled = metrics.scaledValue(for: size)
        guard let maximumScale else { return scaled }
        return min(scaled, size * maximumScale)
    }

    private static func uiTextStyle(for style: Font.TextStyle) -> UIFont.TextStyle {
        switch style {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        @unknown default: .body
        }
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
