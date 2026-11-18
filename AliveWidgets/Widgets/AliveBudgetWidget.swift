import AliveCore
import AppIntents
import Foundation
import SwiftUI
import WidgetKit

struct AliveBudgetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AliveBudgetWidget", provider: BudgetTimelineProvider()) { entry in
            BudgetWidgetView(entry: entry)
        }
        .configurationDisplayName("ALIVE 今日额度")
        .description("让余额活到发薪日。")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
        .contentMarginsDisabled()
    }
}

private struct BudgetWidgetView: View {
    let entry: BudgetWidgetEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    private var palette: WidgetPalette {
        WidgetPalette.resolved(for: colorScheme)
    }

    private var projected: ProjectedBudget? {
        entry.document?.snapshot.projected(at: entry.date, calendar: BudgetCalendar())
    }

    var body: some View {
        Group {
            if let projected {
                let state = projected.displayState
                switch family {
                case .systemSmall:
                    smallView(projected, state: state)
                case .systemMedium:
                    mediumView(projected, state: state)
                case .accessoryCircular:
                    circularView(projected, state: state)
                case .accessoryRectangular:
                    rectangularView(projected, state: state)
                case .accessoryInline:
                    inlineView(projected, state: state)
                default:
                    smallView(projected, state: state)
                }
            } else {
                noDataView
            }
        }
        .containerBackground(for: .widget) {
            if family == .systemSmall || family == .systemMedium {
                palette.card
            } else {
                Color.clear
            }
        }
        .widgetURL(destinationURL)
    }

    private func smallView(_ budget: ProjectedBudget, state: BudgetDisplayState) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("ALIVE")
                    .font(WidgetFont.sans(9, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(palette.accent)
                Spacer(minLength: 4)
                Text(daysText(for: budget, state: state))
                    .font(WidgetFont.sans(9, weight: .medium))
                    .foregroundStyle(palette.inkTertiary)
                    .monospacedDigit()
            }

            Spacer(minLength: 8)

            Text(state.label)
                .font(WidgetFont.sans(11, weight: .semibold))
                .foregroundStyle(labelColor(for: state))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(WidgetAmount.text(for: state))
                .font(WidgetFont.display(34))
                .monospacedDigit()
                .tracking(-1.3)
                .foregroundStyle(amountColor(for: state))
                .lineLimit(1)
                .minimumScaleFactor(0.45)

            Spacer(minLength: 8)

            WidgetProgressBar(
                progress: progress(for: budget, state: state),
                isOverspent: state.isOverspent,
                palette: palette
            )

            HStack(spacing: 4) {
                Text("余额")
                    .font(WidgetFont.sans(9, weight: .medium))
                    .foregroundStyle(palette.inkTertiary)
                Spacer(minLength: 4)
                Text(MoneyFormatter.currency(cents: budget.currentBalanceCents))
                    .font(WidgetFont.sans(9, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.top, 7)
        }
        .padding(14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(for: state, budget: budget))
    }

    private func mediumView(_ budget: ProjectedBudget, state: BudgetDisplayState) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Text("ALIVE")
                        .font(WidgetFont.sans(9, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(palette.accent)
                    Text("·")
                        .font(WidgetFont.sans(9, weight: .medium))
                        .foregroundStyle(palette.inkTertiary)
                    Text(state.label)
                        .font(WidgetFont.sans(10, weight: .semibold))
                        .foregroundStyle(labelColor(for: state))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 6)

                Text(WidgetAmount.text(for: state))
                    .font(WidgetFont.display(38))
                    .monospacedDigit()
                    .tracking(-1.6)
                    .foregroundStyle(amountColor(for: state))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)

                Spacer(minLength: 8)

                WidgetProgressBar(
                    progress: progress(for: budget, state: state),
                    isOverspent: state.isOverspent,
                    palette: palette
                )

                HStack(spacing: 6) {
                    Text("余额 \(MoneyFormatter.currency(cents: budget.currentBalanceCents))")
                        .font(WidgetFont.sans(10, weight: .medium))
                        .foregroundStyle(palette.inkSecondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 4)
                    if case .pending = state {
                        Text("待开始")
                            .font(WidgetFont.sans(10, weight: .medium))
                            .foregroundStyle(palette.inkTertiary)
                    } else {
                        Text("已花 \(spentText(for: budget))")
                            .font(WidgetFont.sans(10, weight: .medium))
                            .foregroundStyle(palette.inkTertiary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(palette.line)
                .frame(width: 0.5)
                .padding(.vertical, 2)

            VStack(alignment: .trailing, spacing: 0) {
                Text(daysCaption(for: budget, state: state))
                    .font(WidgetFont.sans(9, weight: .medium))
                    .foregroundStyle(palette.inkTertiary)
                    .lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(budget.daysRemaining)")
                        .font(WidgetFont.display(36))
                        .monospacedDigit()
                        .foregroundStyle(palette.ink)
                    Text("天")
                        .font(WidgetFont.sans(10, weight: .medium))
                        .foregroundStyle(palette.inkTertiary)
                }

                Spacer(minLength: 8)

                mediumAction(for: state)
            }
            .frame(width: 86)
            .frame(maxHeight: .infinity, alignment: .topTrailing)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func mediumAction(for state: BudgetDisplayState) -> some View {
        if case .pending = state {
            Link(destination: AppRoute.today.url) {
                actionLabel("查看")
            }
            .buttonStyle(.plain)
        } else {
            Button(intent: OpenQuickEntryIntent()) {
                actionLabel("记一笔")
            }
            .buttonStyle(.plain)
        }
    }

    private func actionLabel(_ title: String) -> some View {
        Text(title)
            .font(WidgetFont.sans(11, weight: .semibold))
            .foregroundStyle(palette.ink)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .background(
                Capsule().fill(palette.accent.opacity(palette.scheme == .dark ? 0.24 : 0.12))
            )
            .contentShape(Capsule())
    }

    private func circularView(_ budget: ProjectedBudget, state: BudgetDisplayState) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            Circle()
                .stroke(palette.line, lineWidth: 5)
            Circle()
                .trim(from: 0, to: min(max(progress(for: budget, state: state), 0), 1))
                .stroke(
                    state.isOverspent ? palette.overspend : palette.accent,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(circularAmountText(for: state))
                    .font(WidgetFont.display(15, relativeTo: .title3))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(amountColor(for: state))
                Text(circularStatus(for: state, daysRemaining: budget.daysRemaining))
                    .font(WidgetFont.sans(7, weight: .semibold, relativeTo: .caption2))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(palette.inkSecondary)
            }
            .padding(6)
        }
        .accessibilityLabel(accessibilityText(for: state, budget: budget))
    }

    private func rectangularView(_ budget: ProjectedBudget, state: BudgetDisplayState) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text("ALIVE")
                    .font(WidgetFont.sans(9, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(palette.accent)
                Text(state.label)
                    .font(WidgetFont.sans(9, weight: .semibold))
                    .foregroundStyle(labelColor(for: state))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Text(daysText(for: budget, state: state))
                    .font(WidgetFont.sans(9, weight: .medium))
                    .foregroundStyle(palette.inkTertiary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(WidgetAmount.text(for: state))
                    .font(WidgetFont.display(24))
                    .monospacedDigit()
                    .foregroundStyle(amountColor(for: state))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                Spacer(minLength: 4)
                Text("余额 \(MoneyFormatter.currency(cents: budget.currentBalanceCents))")
                    .font(WidgetFont.sans(9, weight: .medium))
                    .foregroundStyle(palette.inkSecondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            WidgetProgressBar(
                progress: progress(for: budget, state: state),
                isOverspent: state.isOverspent,
                palette: palette,
                height: 3
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(for: state, budget: budget))
    }

    private func inlineView(_ budget: ProjectedBudget, state: BudgetDisplayState) -> some View {
        Text(inlineText(for: state, daysRemaining: budget.daysRemaining))
            .accessibilityLabel(accessibilityText(for: state, budget: budget))
    }

    @ViewBuilder
    private var noDataView: some View {
        switch family {
        case .accessoryInline:
            Text("ALIVE · 未开始")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Text("ALIVE")
                        .font(WidgetFont.sans(7, weight: .semibold, relativeTo: .caption2))
                        .tracking(0.5)
                        .foregroundStyle(palette.accent)
                    Text("未开始")
                        .font(WidgetFont.sans(8, weight: .semibold, relativeTo: .caption2))
                        .foregroundStyle(palette.ink)
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("ALIVE")
                    .font(WidgetFont.sans(9, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(palette.accent)
                Text("未开始 · 打开 ALIVE")
                    .font(WidgetFont.sans(11, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        default:
            VStack(alignment: .leading, spacing: 0) {
                Text("ALIVE")
                    .font(WidgetFont.sans(9, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(palette.accent)
                Spacer(minLength: 8)
                Text("打开 ALIVE 开始")
                    .font(WidgetFont.sans(17, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(palette.ink)
                Text("把余额分给此后的每一天。")
                    .font(WidgetFont.sans(10, relativeTo: .caption2))
                    .foregroundStyle(palette.inkTertiary)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(16)
        }
    }

    private var destinationURL: URL {
        guard let projected, projected.phase != .pending else {
            return AppRoute.today.url
        }
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            return AppRoute.today.url
        default:
            return AppRoute.quickEntry.url
        }
    }

    private func daysText(for budget: ProjectedBudget, state: BudgetDisplayState) -> String {
        if case .pending = state {
            return "\(budget.daysRemaining) 天后"
        }
        return "\(budget.daysRemaining) 天"
    }

    private func daysCaption(for budget: ProjectedBudget, state: BudgetDisplayState) -> String {
        if case .pending = state {
            return "距开始"
        }
        return "距发薪"
    }

    private func spentText(for budget: ProjectedBudget) -> String {
        let spent = max(0, budget.todayBudgetCents - budget.todayAvailableCents)
        return MoneyFormatter.currency(cents: spent)
    }

    private func labelColor(for state: BudgetDisplayState) -> Color {
        if state.isOverspent {
            return palette.overspend
        }
        if case .pending = state {
            return palette.accent
        }
        return palette.inkSecondary
    }

    private func amountColor(for state: BudgetDisplayState) -> Color {
        state.isOverspent ? palette.overspend : palette.ink
    }

    private func circularAmountText(for state: BudgetDisplayState) -> String {
        state.isZeroBalance ? "—" : WidgetAmount.compact(cents: state.amountCents)
    }

    private func circularStatus(for state: BudgetDisplayState, daysRemaining: Int) -> String {
        switch state {
        case .pending:
            "待开始"
        case .available:
            "\(daysRemaining)天"
        case .overspent:
            "超支"
        case .negativeBalance:
            "余额负"
        case .zeroBalance:
            "不可用"
        }
    }

    private func inlineText(for state: BudgetDisplayState, daysRemaining: Int) -> String {
        switch state {
        case .pending(let cents):
            "ALIVE 待开始 \(WidgetAmount.compact(cents: cents))"
        case .available(let cents):
            "ALIVE 还可花 \(WidgetAmount.compact(cents: cents)) · \(daysRemaining)天"
        case .overspent(let overage):
            "ALIVE 超 \(WidgetAmount.compact(cents: overage)) · \(daysRemaining)天"
        case .negativeBalance(let balance, let overage):
            if let overage {
                "ALIVE 超 \(WidgetAmount.compact(cents: overage)) · 余额负"
            } else {
                "ALIVE 余额负 \(WidgetAmount.compact(cents: balance))"
            }
        case .zeroBalance:
            "ALIVE 今日不可用 · \(daysRemaining)天"
        }
    }

    private func progress(for budget: ProjectedBudget, state: BudgetDisplayState) -> Double {
        guard budget.todayBudgetCents > 0 else {
            return state.isOverspent ? 1 : 0
        }
        if state.isOverspent {
            return 1
        }
        let available = NSDecimalNumber(decimal: budget.todayAvailableCents).doubleValue
        let total = NSDecimalNumber(decimal: budget.todayBudgetCents).doubleValue
        guard total > 0 else { return 0 }
        return min(max(1 - available / total, 0), 1)
    }

    private func accessibilityText(for state: BudgetDisplayState, budget: ProjectedBudget) -> String {
        switch state {
        case .pending(let cents):
            "ALIVE，预计每日额度 \(MoneyFormatter.spoken(cents: cents))，\(budget.daysRemaining) 天后启动"
        case .available(let cents):
            "ALIVE，今天还可花 \(MoneyFormatter.spoken(cents: cents))，余额 \(MoneyFormatter.spoken(cents: Decimal(budget.currentBalanceCents)))，\(budget.daysRemaining) 天"
        case .overspent(let overage):
            "ALIVE，今天已超出 \(MoneyFormatter.spoken(cents: overage))，余额 \(MoneyFormatter.spoken(cents: Decimal(budget.currentBalanceCents)))"
        case .negativeBalance(let balance, let overage):
            if let overage {
                "ALIVE，余额已为负 \(MoneyFormatter.spoken(cents: balance))，今天已超出 \(MoneyFormatter.spoken(cents: overage))"
            } else {
                "ALIVE，余额已为负 \(MoneyFormatter.spoken(cents: balance))，今日额度不可用"
            }
        case .zeroBalance:
            "ALIVE，今日额度不可用，余额 \(MoneyFormatter.spoken(cents: Decimal(0)))，\(budget.daysRemaining) 天"
        }
    }
}

private struct WidgetProgressBar: View {
    let progress: Double
    let isOverspent: Bool
    let palette: WidgetPalette
    var height: CGFloat = 4

    private var clamped: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.line)
                Capsule()
                    .fill(isOverspent ? palette.overspend : palette.accent)
                    .frame(width: proxy.size.width * clamped)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
