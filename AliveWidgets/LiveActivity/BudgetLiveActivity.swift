import ActivityKit
import AliveCore
import AppIntents
import SwiftUI
import WidgetKit

struct BudgetLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BudgetActivityAttributes.self) { context in
            LockScreenActivityView(context: context)
        } dynamicIsland: { context in
            let state = context.state.displayState
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ALIVE")
                            .font(WidgetFont.sans(9, weight: .semibold, relativeTo: .caption2))
                            .tracking(1.6)
                            .foregroundStyle(WidgetColor.accentHighlight)
                        Text("今天")
                            .font(WidgetFont.sans(10, weight: .medium, relativeTo: .caption2))
                            .foregroundStyle(WidgetColor.islandInkMuted)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(context.state.daysRemaining) 天")
                            .font(WidgetFont.display(18, relativeTo: .title3))
                            .monospacedDigit()
                            .foregroundStyle(WidgetColor.islandInk)
                        Text("距发薪")
                            .font(WidgetFont.sans(9, weight: .medium, relativeTo: .caption2))
                            .foregroundStyle(WidgetColor.islandInkMuted)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(state.label)
                                    .font(WidgetFont.sans(9, weight: .semibold, relativeTo: .caption2))
                                    .foregroundStyle(islandLabelColor(for: state))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Text(islandAmountText(for: state))
                                    .font(WidgetFont.display(28, relativeTo: .title2))
                                    .monospacedDigit()
                                    .foregroundStyle(islandAmountColor(for: state))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.55)
                            }
                            Spacer(minLength: 8)
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("余额")
                                    .font(WidgetFont.sans(9, weight: .medium, relativeTo: .caption2))
                                    .foregroundStyle(WidgetColor.islandInkMuted)
                                Text(MoneyFormatter.currency(cents: context.state.currentBalanceCents))
                                    .font(WidgetFont.sans(11, weight: .semibold, relativeTo: .caption))
                                    .monospacedDigit()
                                    .foregroundStyle(WidgetColor.islandInk)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                        }

                        HStack(spacing: 8) {
                            activityButton("记一笔", intent: OpenQuickEntryIntent(), isProminent: true)
                            activityButton("调余额", intent: OpenBalanceIntent(), isProminent: false)
                        }
                    }
                }
            } compactLeading: {
                MiniBarsMark(tint: islandAccentColor(for: state))
            } compactTrailing: {
                Text(compactTrailingText(for: state))
                    .font(WidgetFont.display(14, relativeTo: .body))
                    .monospacedDigit()
                    .foregroundStyle(islandAmountColor(for: state))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .accessibilityLabel(activityAccessibilityText(context.state))
            } minimal: {
                Text(minimalText(for: state))
                    .font(WidgetFont.display(12, relativeTo: .caption))
                    .monospacedDigit()
                    .foregroundStyle(minimalTextColor(for: state))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .accessibilityLabel(activityAccessibilityText(context.state))
            }
            .keylineTint(WidgetColor.accentHighlight)
            .widgetURL(AppRoute.today.url)
        }
    }

    private func activityButton(
        _ title: String,
        intent: some AppIntent,
        isProminent: Bool
    ) -> some View {
        Button(intent: intent) {
            Text(title)
                .font(WidgetFont.sans(11, weight: .semibold, relativeTo: .body))
                .foregroundStyle(isProminent ? Color.black : WidgetColor.islandInk)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(
                    Capsule().fill(
                        isProminent ? WidgetColor.islandInk : WidgetColor.islandInk.opacity(0.14)
                    )
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func islandLabelColor(for state: BudgetDisplayState) -> Color {
        state.isOverspent ? WidgetColor.islandOverspend : WidgetColor.islandInkMuted
    }

    private func islandAmountColor(for state: BudgetDisplayState) -> Color {
        state.isOverspent ? WidgetColor.islandOverspend : WidgetColor.islandInk
    }

    private func islandAccentColor(for state: BudgetDisplayState) -> Color {
        state.isOverspent ? WidgetColor.islandOverspend : WidgetColor.accentHighlight
    }

    private func islandAmountText(for state: BudgetDisplayState) -> String {
        state.isZeroBalance ? "—" : WidgetAmount.standard(cents: state.amountCents)
    }

    private func compactTrailingText(for state: BudgetDisplayState) -> String {
        switch state {
        case .pending:
            "待"
        case .available(let cents):
            WidgetAmount.compact(cents: cents)
        case .overspent(let overage):
            "超 \(WidgetAmount.compact(cents: overage))"
        case .negativeBalance(let balance, let overage):
            if let overage {
                "超 \(WidgetAmount.compact(cents: overage))"
            } else {
                "负 \(WidgetAmount.compact(cents: balance))"
            }
        case .zeroBalance:
            "—"
        }
    }

    private func minimalText(for state: BudgetDisplayState) -> String {
        switch state {
        case .pending:
            "待"
        case .available(let cents):
            WidgetAmount.compact(cents: cents)
        case .overspent(let overage):
            "超\(WidgetAmount.compact(cents: overage))"
        case .negativeBalance:
            "负"
        case .zeroBalance:
            "—"
        }
    }

    private func minimalTextColor(for state: BudgetDisplayState) -> Color {
        state.isOverspent ? WidgetColor.islandOverspend : WidgetColor.islandInk
    }

    private func activityAccessibilityText(_ state: BudgetActivityAttributes.ContentState) -> String {
        switch state.displayState {
        case .pending(let cents):
            "ALIVE，预计每日额度 \(MoneyFormatter.spoken(cents: cents))，\(state.daysRemaining) 天后启动"
        case .available(let cents):
            "ALIVE，今天还可花 \(MoneyFormatter.spoken(cents: cents))，余额 \(MoneyFormatter.spoken(cents: Decimal(state.currentBalanceCents)))，\(state.daysRemaining) 天"
        case .overspent(let overage):
            "ALIVE，今天已超出 \(MoneyFormatter.spoken(cents: overage))，余额 \(MoneyFormatter.spoken(cents: Decimal(state.currentBalanceCents)))"
        case .negativeBalance(let balance, let overage):
            if let overage {
                "ALIVE，余额已为负 \(MoneyFormatter.spoken(cents: balance))，今天已超出 \(MoneyFormatter.spoken(cents: overage))"
            } else {
                "ALIVE，余额已为负 \(MoneyFormatter.spoken(cents: balance))，今日额度不可用"
            }
        case .zeroBalance:
            "ALIVE，今日额度不可用，余额 \(MoneyFormatter.spoken(cents: Decimal(0)))，\(state.daysRemaining) 天"
        }
    }
}

private struct LockScreenActivityView: View {
    let context: ActivityViewContext<BudgetActivityAttributes>

    private var state: BudgetDisplayState {
        context.state.displayState
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("ALIVE")
                    .font(WidgetFont.sans(9, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(WidgetColor.accent)
                Text("今天")
                    .font(WidgetFont.sans(10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text("\(context.state.daysRemaining) 天")
                    .font(WidgetFont.sans(10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.label)
                        .font(WidgetFont.sans(10, weight: .semibold))
                        .foregroundStyle(state.isOverspent ? WidgetColor.overspend : Color.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(lockScreenAmountText)
                        .font(WidgetFont.display(34))
                        .monospacedDigit()
                        .foregroundStyle(state.isOverspent ? WidgetColor.overspend : Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("余额")
                            .font(WidgetFont.sans(9, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(MoneyFormatter.currency(cents: context.state.currentBalanceCents))
                            .font(WidgetFont.sans(10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    Button(intent: OpenQuickEntryIntent()) {
                        Text("记一笔")
                            .font(WidgetFont.sans(11, weight: .semibold))
                            .foregroundStyle(Color.primary)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(Capsule().fill(WidgetColor.accent.opacity(0.16)))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
    }

    private var lockScreenAmountText: String {
        state.isZeroBalance ? "—" : WidgetAmount.standard(cents: state.amountCents)
    }
}

private struct MiniBarsMark: View {
    let tint: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            Capsule().fill(tint).frame(width: 3, height: 7)
            Capsule().fill(tint).frame(width: 3, height: 13)
            Capsule().fill(tint).frame(width: 3, height: 10)
        }
        .frame(width: 13, height: 14)
        .accessibilityHidden(true)
    }
}
