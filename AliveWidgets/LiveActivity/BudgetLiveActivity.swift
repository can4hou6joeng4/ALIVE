import ActivityKit
import AppIntents
import AliveCore
import SwiftUI
import WidgetKit

struct BudgetLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BudgetActivityAttributes.self) { context in
            LockScreenActivityView(context: context)
        } dynamicIsland: { context in
            let state = context.state.displayState
            let cycleID = context.attributes.cycleID.uuidString
            return DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    if let liveEntry = context.state.liveEntry {
                        LiveEntryIslandCard(cycleID: cycleID, liveEntry: liveEntry)
                    } else {
                        HStack(spacing: IslandEntryMetrics.amountPanelSpacing) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 5) {
                                    AliveMonogram(tint: islandAccentColor(for: state))
                                    Text(state.label)
                                        .font(WidgetFont.sans(10, weight: .semibold))
                                        .foregroundStyle(WidgetColor.islandInkSecondary)
                                }
                                Text(MoneyFormatter.currency(cents: state.amountCents))
                                    .font(WidgetFont.display(22))
                                    .monospacedDigit()
                                    .foregroundStyle(islandAmountColor(for: state))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.55)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background {
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 16,
                                    bottomLeadingRadius: 16,
                                    bottomTrailingRadius: 10,
                                    topTrailingRadius: 10,
                                    style: .continuous
                                )
                                .fill(WidgetColor.islandInk.opacity(0.08))
                            }

                            Button(intent: BeginLiveEntryIntent(cycleID: cycleID)) {
                                Text("记一笔")
                                    .font(WidgetFont.sans(13, weight: .semibold))
                                    .foregroundStyle(WidgetColor.islandInk)
                                    .padding(.horizontal, 18)
                                    .frame(maxHeight: .infinity)
                                    .frame(minHeight: IslandEntryMetrics.noteTagHeight)
                                    .background {
                                        UnevenRoundedRectangle(
                                            topLeadingRadius: 10,
                                            bottomLeadingRadius: 10,
                                            bottomTrailingRadius: 16,
                                            topTrailingRadius: 16,
                                            style: .continuous
                                        )
                                        .fill(WidgetColor.islandInk.opacity(0.14))
                                    }
                            }
                            .buttonStyle(IslandControlButtonStyle())
                            .accessibilityIdentifier("live-entry-begin")
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, IslandEntryMetrics.horizontalInset)
                        .padding(.bottom, IslandEntryMetrics.bottomSafetyInset)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("live-entry-summary")
                    }
                }
            } compactLeading: {
                AliveMonogram(tint: islandAccentColor(for: state))
                    .padding(.leading, 1)
                    .widgetURL(AppRoute.today.url)
                    .accessibilityHint("打开 ALIVE 今日主屏")
            } compactTrailing: {
                Text(compactTrailingText(for: state))
                    .font(WidgetFont.display(13, relativeTo: .body))
                    .monospacedDigit()
                    .foregroundStyle(islandAmountColor(for: state))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .padding(.trailing, 1)
                    .contentTransition(.numericText())
                    .accessibilityLabel(activityAccessibilityText(context.state))
                    .widgetURL(AppRoute.today.url)
                    .accessibilityHint("打开 ALIVE 今日主屏")
            } minimal: {
                Text(minimalText(for: state))
                    .font(WidgetFont.display(12, relativeTo: .caption))
                    .monospacedDigit()
                    .foregroundStyle(minimalTextColor(for: state))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .accessibilityLabel(activityAccessibilityText(context.state))
                    .widgetURL(AppRoute.today.url)
                    .accessibilityHint("打开 ALIVE 今日主屏")
            }
            .contentMargins(.top, 0, for: .expanded)
            .contentMargins(.bottom, IslandEntryMetrics.expandedBottomMargin, for: .expanded)
            .keylineTint(WidgetColor.accentHighlight)
        }
    }

    private func islandAmountColor(for state: BudgetDisplayState) -> Color {
        state.isOverspent ? WidgetColor.islandOverspend : WidgetColor.islandInk
    }

    private func islandAccentColor(for state: BudgetDisplayState) -> Color {
        state.isOverspent ? WidgetColor.islandOverspend : WidgetColor.accentHighlight
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
            }

            HStack(spacing: 6) {
                Image(systemName: "hand.tap")
                    .accessibilityHidden(true)
                Text("轻点整张卡片，记一笔")
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .accessibilityHidden(true)
            }
            .font(WidgetFont.sans(11, weight: .semibold))
            .foregroundStyle(WidgetColor.accent)
            .frame(minHeight: 20)
        }
        .padding(16)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("轻点整张卡片打开快速记账")
        .widgetURL(AppRoute.liveEntry.url)
    }

    private var lockScreenAmountText: String {
        state.isZeroBalance ? "—" : WidgetAmount.standard(cents: state.amountCents)
    }
}

private struct AliveMonogram: View {
    let tint: Color

    var body: some View {
        AliveMonogramShape()
            .stroke(
                tint,
                style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
            )
            .frame(width: 16, height: 14)
            .accessibilityHidden(true)
    }
}

private struct AliveMonogramShape: Shape {
    func path(in rect: CGRect) -> Path {
        func pt(_ nx: CGFloat, _ ny: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + nx * rect.width,
                y: rect.minY + (1 - ny) * rect.height
            )
        }

        var path = Path()
        path.move(to: pt(0.06, 0.18))
        path.addCurve(to: pt(0.24, 0.84), control1: pt(0.12, 0.40), control2: pt(0.17, 0.84))
        path.addCurve(to: pt(0.41, 0.18), control1: pt(0.30, 0.84), control2: pt(0.35, 0.18))
        path.addCurve(to: pt(0.56, 0.72), control1: pt(0.46, 0.18), control2: pt(0.51, 0.72))
        path.addCurve(to: pt(0.72, 0.18), control1: pt(0.61, 0.72), control2: pt(0.66, 0.18))
        path.addCurve(to: pt(0.91, 0.74), control1: pt(0.78, 0.18), control2: pt(0.83, 0.74))
        path.addCurve(to: pt(0.96, 0.56), control1: pt(0.95, 0.74), control2: pt(0.96, 0.65))
        return path
    }
}
