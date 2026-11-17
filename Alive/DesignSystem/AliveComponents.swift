import AliveCore
import SwiftUI

struct BrassRule: View {
    var subtle = false
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(subtle ? AliveColor.lineSubtle : AliveColor.line)
            .frame(height: max(0.5, 1 / displayScale))
            .accessibilityHidden(true)
    }
}

struct AmountText: View {
    let cents: Decimal
    var size: CGFloat = 58
    var color: Color = AliveColor.ink
    var alignment: TextAlignment = .leading

    var body: some View {
        Text(MoneyFormatter.currency(cents: cents))
            .font(AliveFont.display(size))
            .monospacedDigit()
            .tracking(-0.055 * size)
            .foregroundStyle(color)
            .multilineTextAlignment(alignment)
            .lineLimit(1)
            .minimumScaleFactor(0.46)
            .accessibilityLabel(MoneyFormatter.spoken(cents: cents))
    }
}

struct CycleBadge: View {
    let phase: BudgetPhase

    var body: some View {
        Text(label)
            .font(AliveFont.sans(12, weight: .semibold, relativeTo: .caption))
            .tracking(1.2)
            .foregroundStyle(phase == .overspent ? AliveColor.overspend : AliveColor.inkSecondary)
            .padding(.horizontal, AliveSpace.x2)
            .padding(.vertical, AliveSpace.x1)
            .overlay {
                Rectangle()
                    .stroke(phase == .overspent ? AliveColor.overspend : AliveColor.brass, lineWidth: 1)
            }
            .accessibilityLabel(label)
    }

    private var label: String {
        switch phase {
        case .pending:
            "待开始"
        case .active:
            "进行中"
        case .overspent:
            "已超支"
        }
    }
}

struct OrreryRing: View {
    let progress: Double
    let phase: BudgetPhase
    var diameter: CGFloat = 92

    var body: some View {
        ZStack {
            Circle()
                .stroke(AliveColor.line, style: StrokeStyle(lineWidth: 1, dash: [1, 4]))

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    phase == .overspent
                        ? AnyShapeStyle(AliveColor.overspend)
                        : AnyShapeStyle(AliveColor.brass),
                    style: StrokeStyle(lineWidth: 2, lineCap: .butt)
                )
                .rotationEffect(.degrees(-90))

            Circle()
                .stroke(AliveColor.brassHighlight.opacity(0.55), lineWidth: 1)
                .padding(8)

            Circle()
                .fill(phase == .overspent ? AliveColor.overspend : AliveColor.brass)
                .frame(width: 5, height: 5)

            AstrolabeTicks()
                .stroke(AliveColor.brass.opacity(0.7), lineWidth: 0.8)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}

private struct AstrolabeTicks: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        for index in 0..<24 {
            let angle = Double(index) / 24 * Double.pi * 2
            let length: CGFloat = index.isMultiple(of: 6) ? 7 : 3
            let start = CGPoint(
                x: center.x + cos(angle) * (outer - length - 3),
                y: center.y + sin(angle) * (outer - length - 3)
            )
            let end = CGPoint(
                x: center.x + cos(angle) * (outer - 3),
                y: center.y + sin(angle) * (outer - 3)
            )
            path.move(to: start)
            path.addLine(to: end)
        }
        return path
    }
}

struct OrreryBackground: View {
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Canvas { context, size in
            let hairline = max(0.5, 1 / displayScale)
            let gridStep: CGFloat = 36
            var grid = Path()

            var x: CGFloat = 0
            while x <= size.width {
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: size.height))
                x += gridStep
            }

            var y: CGFloat = 0
            while y <= size.height {
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
                y += gridStep
            }
            context.stroke(grid, with: .color(AliveColor.lineSubtle.opacity(0.38)), lineWidth: hairline)

            let center = CGPoint(x: size.width * 0.82, y: size.height * 0.16)
            for radius in [68.0, 118.0, 172.0] {
                let rect = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(AliveColor.brass.opacity(0.13)),
                    lineWidth: hairline
                )
            }

            var ray = Path()
            let rayEnd = CGPoint(x: center.x + 210, y: center.y + 110)
            ray.move(to: center)
            ray.addLine(to: rayEnd)
            context.stroke(ray, with: .color(AliveColor.brass.opacity(0.14)), lineWidth: hairline)
        }
        .background(AliveColor.canvas)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct PrimaryAction: View {
    let title: String
    var systemImage: String?
    var isBusy = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AliveSpace.x2) {
                if isBusy {
                    ProgressView()
                        .tint(AliveColor.canvas)
                        .controlSize(.small)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(AliveFont.sans(16, weight: .semibold, relativeTo: .headline))
                    .tracking(0.5)
            }
            .foregroundStyle(AliveColor.canvas)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.horizontal, AliveSpace.x3)
            .background(AliveColor.ink)
            .overlay {
                Rectangle()
                    .stroke(AliveColor.brassHighlight.opacity(0.28), lineWidth: 1)
            }
        }
        .buttonStyle(AlivePrimaryButtonStyle())
        .disabled(isBusy)
    }
}

private struct AlivePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                if configuration.isPressed {
                    Rectangle()
                        .stroke(AliveColor.holo, lineWidth: 1)
                }
            }
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(AliveMotion.quick, value: configuration.isPressed)
    }
}

struct GhostButton: View {
    let title: String
    var isEnabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AliveFont.sans(14, weight: .medium, relativeTo: .subheadline))
                .tracking(0.4)
                .foregroundStyle(isEnabled ? AliveColor.inkSecondary : AliveColor.inkTertiary)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct IconAction: View {
    let systemName: String
    let accessibilityLabel: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AliveColor.inkSecondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct SheetHeader: View {
    let title: String
    var close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text(title)
                    .font(AliveFont.sans(22, weight: .semibold, relativeTo: .title3))
                    .foregroundStyle(AliveColor.ink)

                Spacer()

                Button("关闭", action: close)
                    .font(AliveFont.sans(14, weight: .medium, relativeTo: .subheadline))
                    .foregroundStyle(AliveColor.inkSecondary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            BrassRule()
        }
    }
}

struct FieldLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AliveFont.sans(12, weight: .semibold, relativeTo: .caption))
            .tracking(1.4)
            .foregroundStyle(AliveColor.inkTertiary)
    }
}

struct InlineError: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(AliveFont.sans(13, weight: .medium, relativeTo: .footnote))
                .foregroundStyle(AliveColor.overspend)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("错误：\(message)")
        }
    }
}

struct OrnamentalRingMark: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(AliveColor.brass, lineWidth: 1)
            Circle()
                .stroke(AliveColor.brassHighlight.opacity(0.6), lineWidth: 1)
                .padding(4)
            Circle()
                .fill(AliveColor.brass)
                .frame(width: 3, height: 3)
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }
}
