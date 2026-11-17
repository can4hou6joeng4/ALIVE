import AliveCore
import AppIntents
import Foundation
import SwiftUI
import WidgetKit

struct AliveBudgetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AliveBudgetWidget", provider: BudgetTimelineProvider()) { entry in
            BudgetWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetColor.canvas
                }
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

    private var projected: ProjectedBudget? {
        entry.document?.snapshot.projected(at: entry.date, calendar: BudgetCalendar())
    }

    var body: some View {
        Group {
            if let projected {
                switch family {
                case .systemSmall:
                    smallView(projected)
                case .systemMedium:
                    mediumView(projected)
                case .accessoryCircular:
                    circularView(projected)
                case .accessoryRectangular:
                    rectangularView(projected)
                case .accessoryInline:
                    inlineView(projected)
                default:
                    smallView(projected)
                }
            } else {
                noDataView
            }
        }
        .widgetURL(destinationURL)
    }

    private func smallView(_ budget: ProjectedBudget) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ALIVE")
                    .font(WidgetFont.sans(9, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(WidgetColor.inkTertiary)
                Spacer()
                Circle()
                    .fill(budget.phase == .overspent ? WidgetColor.overspend : WidgetColor.brass)
                    .frame(width: 5, height: 5)
            }

            Spacer(minLength: 0)

            Text(label(for: budget))
                .font(WidgetFont.sans(10, weight: .medium))
                .foregroundStyle(budget.phase == .overspent ? WidgetColor.overspend : WidgetColor.inkSecondary)

            Text(amountText(for: budget))
                .font(WidgetFont.display(28))
                .monospacedDigit()
                .tracking(-1.2)
                .foregroundStyle(budget.phase == .overspent ? WidgetColor.overspend : WidgetColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            Text(budget.phase == .pending ? "\(budget.daysRemaining) 天后启动" : "\(budget.daysRemaining) 天")
                .font(WidgetFont.sans(10, weight: .medium))
                .foregroundStyle(WidgetColor.inkTertiary)
                .monospacedDigit()
        }
        .padding(14)
        .overlay {
            Rectangle()
                .stroke(WidgetColor.line, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(for: budget))
    }

    private func mediumView(_ budget: ProjectedBudget) -> some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ALIVE · \(label(for: budget))")
                    .font(WidgetFont.sans(9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(WidgetColor.inkTertiary)

                Text(amountText(for: budget))
                    .font(WidgetFont.display(34))
                    .monospacedDigit()
                    .tracking(-1.6)
                    .foregroundStyle(budget.phase == .overspent ? WidgetColor.overspend : WidgetColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                Text("余额 \(MoneyFormatter.currency(cents: budget.currentBalanceCents)) · \(budget.daysRemaining) 天")
                    .font(WidgetFont.sans(11, weight: .medium))
                    .foregroundStyle(WidgetColor.inkSecondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 10) {
                WidgetBrassRing(progress: progress(for: budget), phase: budget.phase)
                    .frame(width: 52, height: 52)

                if budget.phase == .pending {
                    Link("调整设置", destination: AppRoute.today.url)
                        .font(WidgetFont.sans(11, weight: .semibold))
                        .foregroundStyle(WidgetColor.inkSecondary)
                } else {
                    Button(intent: OpenQuickEntryIntent()) {
                        Text("记一笔")
                            .font(WidgetFont.sans(11, weight: .semibold))
                            .foregroundStyle(WidgetColor.inkSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .overlay {
            Rectangle()
                .stroke(WidgetColor.line, lineWidth: 1)
        }
    }

    private func circularView(_ budget: ProjectedBudget) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            WidgetBrassRing(progress: progress(for: budget), phase: budget.phase)
                .padding(5)
            VStack(spacing: 0) {
                Text(shortAmount(for: budget))
                    .font(WidgetFont.display(16))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(budget.phase == .overspent ? WidgetColor.overspend : WidgetColor.ink)
                if budget.phase == .pending {
                    Text("\(budget.daysRemaining)天")
                        .font(WidgetFont.sans(7, weight: .semibold))
                        .foregroundStyle(WidgetColor.inkSecondary)
                }
            }
        }
        .accessibilityLabel(accessibilityText(for: budget))
    }

    private func rectangularView(_ budget: ProjectedBudget) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("ALIVE · \(label(for: budget))")
                .font(WidgetFont.sans(9, weight: .semibold))
                .tracking(1)
                .foregroundStyle(WidgetColor.inkSecondary)
            Text(amountText(for: budget))
                .font(WidgetFont.display(24))
                .monospacedDigit()
                .foregroundStyle(budget.phase == .overspent ? WidgetColor.overspend : WidgetColor.ink)
                .lineLimit(1)
            Text("余额 \(MoneyFormatter.currency(cents: budget.currentBalanceCents)) · \(budget.daysRemaining) 天")
                .font(WidgetFont.sans(10, weight: .medium))
                .foregroundStyle(WidgetColor.inkSecondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(for: budget))
    }

    private func inlineView(_ budget: ProjectedBudget) -> some View {
        Text("ALIVE \(amountText(for: budget)) · \(budget.daysRemaining)天")
            .accessibilityLabel(accessibilityText(for: budget))
    }

    private var noDataView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ALIVE")
                .font(WidgetFont.sans(9, weight: .semibold))
                .tracking(2)
                .foregroundStyle(WidgetColor.inkTertiary)
            Spacer()
            Text("打开 ALIVE 开始")
                .font(WidgetFont.sans(16, weight: .semibold, relativeTo: .body))
                .foregroundStyle(WidgetColor.ink)
            Text("把余额分给此后的每一天。")
                .font(WidgetFont.sans(10, relativeTo: .caption2))
                .foregroundStyle(WidgetColor.inkTertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .overlay {
            Rectangle()
                .stroke(WidgetColor.line, lineWidth: 1)
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

    private func label(for budget: ProjectedBudget) -> String {
        switch budget.phase {
        case .pending:
            "预计每日额度"
        case .active:
            "今天还可花"
        case .overspent:
            "今天已超出"
        }
    }

    private func amountText(for budget: ProjectedBudget) -> String {
        if budget.phase == .overspent, budget.todayAvailableCents < 0 {
            return MoneyFormatter.currency(cents: -budget.todayAvailableCents)
        }
        if budget.phase == .pending {
            return MoneyFormatter.currency(cents: budget.todayBudgetCents)
        }
        return MoneyFormatter.currency(cents: max(0, budget.todayAvailableCents))
    }

    private func shortAmount(for budget: ProjectedBudget) -> String {
        let cents: Decimal
        if budget.phase == .overspent, budget.todayAvailableCents < 0 {
            cents = -budget.todayAvailableCents
        } else if budget.phase == .pending {
            cents = budget.todayBudgetCents
        } else {
            cents = max(0, budget.todayAvailableCents)
        }
        let yuan = NSDecimalNumber(decimal: cents / Decimal(100)).doubleValue
        if yuan >= 1_000 {
            return String(format: "%.0f", yuan)
        }
        return String(format: "%.1f", yuan)
    }

    private func progress(for budget: ProjectedBudget) -> Double {
        guard budget.todayBudgetCents > 0 else {
            return budget.phase == .overspent ? 1 : 0
        }
        if budget.phase == .overspent {
            return 1
        }
        let available = NSDecimalNumber(decimal: budget.todayAvailableCents).doubleValue
        let total = NSDecimalNumber(decimal: budget.todayBudgetCents).doubleValue
        guard total > 0 else { return 0 }
        return min(max(1 - available / total, 0), 1)
    }

    private func accessibilityText(for budget: ProjectedBudget) -> String {
        if budget.phase == .overspent {
            return "ALIVE，今天已超出 \(MoneyFormatter.spoken(cents: -budget.todayAvailableCents))，余额 \(MoneyFormatter.spoken(cents: Decimal(budget.currentBalanceCents)))"
        }
        if budget.phase == .pending {
            return "ALIVE，预计每日额度 \(MoneyFormatter.spoken(cents: budget.todayBudgetCents))，\(budget.daysRemaining) 天后启动"
        }
        return "ALIVE，今天还可花 \(MoneyFormatter.spoken(cents: budget.todayAvailableCents))，余额 \(MoneyFormatter.spoken(cents: Decimal(budget.currentBalanceCents)))，\(budget.daysRemaining) 天"
    }
}

private struct WidgetBrassRing: View {
    let progress: Double
    let phase: BudgetPhase

    var body: some View {
        ZStack {
            Circle()
                .stroke(WidgetColor.line, style: StrokeStyle(lineWidth: 1, dash: [1, 3]))
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    phase == .overspent ? WidgetColor.overspend : WidgetColor.brass,
                    style: StrokeStyle(lineWidth: 2, lineCap: .butt)
                )
                .rotationEffect(.degrees(-90))
            Circle()
                .stroke(WidgetColor.brassHighlight.opacity(0.55), lineWidth: 0.5)
                .padding(5)
        }
        .accessibilityHidden(true)
    }
}
