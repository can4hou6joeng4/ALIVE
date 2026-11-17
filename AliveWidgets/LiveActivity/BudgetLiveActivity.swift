import ActivityKit
import AliveCore
import AppIntents
import SwiftUI
import WidgetKit

struct BudgetLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BudgetActivityAttributes.self) { context in
            LockScreenActivityView(context: context)
                .activityBackgroundTint(WidgetColor.canvas)
                .activitySystemActionForegroundColor(WidgetColor.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ALIVE")
                            .font(WidgetFont.sans(8, weight: .semibold))
                            .tracking(1.8)
                            .foregroundStyle(WidgetColor.inkTertiary)
                        Text("今日 · \(context.state.daysRemaining) 天")
                            .font(WidgetFont.sans(9, weight: .medium))
                            .foregroundStyle(WidgetColor.inkSecondary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(MoneyFormatter.currency(cents: displayAmount(context.state)))
                        .font(WidgetFont.display(22))
                        .monospacedDigit()
                        .foregroundStyle(
                            context.state.phase == .overspent ? WidgetColor.overspend : WidgetColor.brassHighlight
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        HStack {
                            Text(context.state.phase == .overspent ? "今天已超出" : "今天还可花")
                                .font(WidgetFont.sans(10, weight: .semibold))
                                .foregroundStyle(WidgetColor.inkSecondary)
                            Spacer()
                            Text("余额 \(MoneyFormatter.currency(cents: context.state.currentBalanceCents))")
                                .font(WidgetFont.sans(10, weight: .medium))
                                .foregroundStyle(WidgetColor.inkTertiary)
                                .monospacedDigit()
                        }

                        HStack(spacing: 8) {
                            activityButton("记一笔", intent: OpenQuickEntryIntent())
                            activityButton("调余额", intent: OpenBalanceIntent())
                        }
                    }
                }
            } compactLeading: {
                ActivityRingMark(phase: context.state.phase)
            } compactTrailing: {
                Text(compactAmount(context.state))
                    .font(WidgetFont.sans(13, weight: .semibold, relativeTo: .body))
                    .monospacedDigit()
                    .foregroundStyle(context.state.phase == .overspent ? WidgetColor.overspend : WidgetColor.brassHighlight)
                    .minimumScaleFactor(0.7)
                    .accessibilityLabel(activityAccessibilityText(context.state))
            } minimal: {
                ZStack {
                    ActivityRingMark(phase: context.state.phase)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(activityAccessibilityText(context.state))
            }
            .keylineTint(WidgetColor.brass)
            .widgetURL(AppRoute.today.url)
        }
    }

    private func activityButton(_ title: String, intent: some AppIntent) -> some View {
        Button(intent: intent) {
            Text(title)
                .font(WidgetFont.sans(11, weight: .semibold, relativeTo: .body))
                .foregroundStyle(WidgetColor.ink)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 32)
                .overlay {
                    Rectangle()
                        .stroke(WidgetColor.brass.opacity(0.75), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func displayAmount(_ state: BudgetActivityAttributes.ContentState) -> Decimal {
        if state.phase == .overspent, state.todayAvailableCents < 0 {
            return -state.todayAvailableCents
        }
        return max(0, state.todayAvailableCents)
    }

    private func compactAmount(_ state: BudgetActivityAttributes.ContentState) -> String {
        if state.phase == .overspent {
            return "超 \(MoneyFormatter.currency(cents: displayAmount(state)))"
        }
        return MoneyFormatter.currency(cents: displayAmount(state))
    }

    private func activityAccessibilityText(_ state: BudgetActivityAttributes.ContentState) -> String {
        if state.phase == .overspent {
            return "ALIVE，今天已超出 \(MoneyFormatter.spoken(cents: displayAmount(state)))，余额 \(MoneyFormatter.spoken(cents: Decimal(state.currentBalanceCents)))"
        }
        return "ALIVE，今天还可花 \(MoneyFormatter.spoken(cents: displayAmount(state)))，余额 \(MoneyFormatter.spoken(cents: Decimal(state.currentBalanceCents)))，\(state.daysRemaining) 天"
    }
}

private struct LockScreenActivityView: View {
    let context: ActivityViewContext<BudgetActivityAttributes>

    private var amount: Decimal {
        if context.state.phase == .overspent, context.state.todayAvailableCents < 0 {
            return -context.state.todayAvailableCents
        }
        return max(0, context.state.todayAvailableCents)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ALIVE")
                    .font(WidgetFont.sans(9, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(WidgetColor.inkTertiary)
                Spacer()
                Text("今日 · \(context.state.daysRemaining) 天")
                    .font(WidgetFont.sans(10, weight: .medium))
                    .foregroundStyle(WidgetColor.inkSecondary)
                    .monospacedDigit()
            }

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.phase == .overspent ? "今天已超出" : "今天还可花")
                        .font(WidgetFont.sans(10, weight: .semibold))
                        .foregroundStyle(
                            context.state.phase == .overspent ? WidgetColor.overspend : WidgetColor.inkSecondary
                        )
                    Text(MoneyFormatter.currency(cents: amount))
                        .font(WidgetFont.display(34))
                        .monospacedDigit()
                        .foregroundStyle(
                            context.state.phase == .overspent ? WidgetColor.overspend : WidgetColor.ink
                        )
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("余额 \(MoneyFormatter.currency(cents: context.state.currentBalanceCents))")
                        .font(WidgetFont.sans(10, weight: .medium))
                        .foregroundStyle(WidgetColor.inkSecondary)
                        .monospacedDigit()
                    Button(intent: OpenQuickEntryIntent()) {
                        Text("记一笔")
                            .font(WidgetFont.sans(11, weight: .semibold))
                            .foregroundStyle(WidgetColor.ink)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 30)
                            .overlay {
                                Rectangle()
                                    .stroke(WidgetColor.brass, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
    }
}

private struct ActivityRingMark: View {
    let phase: BudgetPhase

    var body: some View {
        ZStack {
            Circle()
                .stroke(WidgetColor.brass.opacity(0.55), lineWidth: 1)
            Circle()
                .fill(phase == .overspent ? WidgetColor.overspend : WidgetColor.brass)
                .frame(width: 5, height: 5)
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }
}
