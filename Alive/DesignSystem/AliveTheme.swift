import SwiftUI
import UIKit

enum AliveColor {
    static var canvas: Color {
        dynamic(light: 0xF4F1EA, dark: 0x0A0F2A)
    }

    static var surface: Color {
        dynamic(light: 0xFFFFFF, dark: 0x10163A)
    }

    static var card: Color {
        dynamic(light: 0xF4F1EA, dark: 0x10163A)
    }

    static var surfaceSunken: Color {
        dynamic(light: 0xE9E5DC, dark: 0x060918)
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

    static var line: Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 201 / 255, green: 162 / 255, blue: 78 / 255, alpha: 0.22)
            }
            return UIColor(red: 16 / 255, green: 22 / 255, blue: 58 / 255, alpha: 0.18)
        })
    }

    static var lineSubtle: Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 201 / 255, green: 162 / 255, blue: 78 / 255, alpha: 0.12)
            }
            return UIColor(red: 16 / 255, green: 22 / 255, blue: 58 / 255, alpha: 0.09)
        })
    }

    static var overspend: Color {
        dynamic(light: 0x8B2F22, dark: 0xF0806C)
    }

    static var focus: Color {
        dynamic(light: 0x10163A, dark: 0xF2DB94)
    }

    static var holo: AngularGradient {
        AngularGradient(
            stops: [
                .init(color: Color(red: 75 / 255, green: 91 / 255, blue: 1), location: 0),
                .init(color: Color(red: 125 / 255, green: 75 / 255, blue: 1), location: 0.18),
                .init(color: Color(red: 210 / 255, green: 75 / 255, blue: 1), location: 0.36),
                .init(color: Color(red: 255 / 255, green: 75 / 255, blue: 155 / 255), location: 0.54),
                .init(color: Color(red: 255 / 255, green: 184 / 255, blue: 75 / 255), location: 0.72),
                .init(color: Color(red: 75 / 255, green: 255 / 255, blue: 210 / 255), location: 0.88),
                .init(color: Color(red: 75 / 255, green: 91 / 255, blue: 1), location: 1)
            ],
            center: .center,
            angle: .degrees(210)
        )
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

enum AliveSpace {
    static let x1: CGFloat = 6
    static let x2: CGFloat = 12
    static let x3: CGFloat = 18
    static let x4: CGFloat = 24
    static let x5: CGFloat = 30
    static let x6: CGFloat = 36
    static let x8: CGFloat = 48
    static let pageInset: CGFloat = 24
}

enum AliveMotion {
    static let quick = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.18)
    static let value = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.42)
}

enum AliveFont {
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom("Gloock-Regular", size: size, relativeTo: style)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        let name: String
        if weight == .medium {
            name = "Commissioner-Medium"
        } else if weight == .semibold {
            name = "Commissioner-SemiBold"
        } else if weight == .bold || weight == .heavy || weight == .black {
            name = "Commissioner-Bold"
        } else {
            name = "Commissioner-Regular"
        }
        return .custom(name, size: size, relativeTo: style)
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
