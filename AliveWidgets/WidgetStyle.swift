import SwiftUI
import UIKit

enum WidgetColor {
    static var canvas: Color {
        dynamic(light: 0xF4F1EA, dark: 0x0A0F2A)
    }

    static var card: Color {
        dynamic(light: 0xF4F1EA, dark: 0x10163A)
    }

    static var ink: Color {
        dynamic(light: 0x10163A, dark: 0xF4F1FF)
    }

    static var inkSecondary: Color {
        dynamic(light: 0x42485C, dark: 0xD6DAE3)
    }

    static var inkTertiary: Color {
        dynamic(light: 0x4A5065, dark: 0xA4B0CC)
    }

    static var brass: Color {
        Color(red: 201 / 255, green: 162 / 255, blue: 78 / 255)
    }

    static var brassHighlight: Color {
        Color(red: 242 / 255, green: 219 / 255, blue: 148 / 255)
    }

    static var overspend: Color {
        dynamic(light: 0x8B2F22, dark: 0xF0806C)
    }

    static var line: Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 201 / 255, green: 162 / 255, blue: 78 / 255, alpha: 0.24)
            }
            return UIColor(red: 16 / 255, green: 22 / 255, blue: 58 / 255, alpha: 0.18)
        })
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
    static func display(_ size: CGFloat) -> Font {
        .custom("Gloock-Regular", size: size, relativeTo: .title)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .caption) -> Font {
        let name: String
        if weight == .semibold {
            name = "Commissioner-SemiBold"
        } else if weight == .bold {
            name = "Commissioner-Bold"
        } else if weight == .medium {
            name = "Commissioner-Medium"
        } else {
            name = "Commissioner-Regular"
        }
        return .custom(name, size: size, relativeTo: style)
    }
}

struct WidgetBrassRule: View {
    var body: some View {
        Rectangle()
            .fill(WidgetColor.line)
            .frame(height: 0.5)
            .accessibilityHidden(true)
    }
}
