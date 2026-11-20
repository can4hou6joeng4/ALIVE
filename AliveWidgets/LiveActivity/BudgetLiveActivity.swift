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
                            VStack(alignment: .leading, spacing: IslandEntryMetrics.sectionSpacing) {
                                Text(state.label)
                                    .font(WidgetFont.sans(10, weight: .semibold))
                                    .foregroundStyle(WidgetColor.islandInkSecondary)
                                Text(MoneyFormatter.currency(cents: state.amountCents))
                                    .font(WidgetFont.display(22))
                                    .monospacedDigit()
                                    .foregroundStyle(islandAmountColor(for: state))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.55)
                            }
                            Spacer(minLength: 0)
                            Button(intent: BeginLiveEntryIntent(cycleID: cycleID)) {
                                Text("记一笔")
                                    .font(WidgetFont.sans(13, weight: .semibold))
                                    .foregroundStyle(WidgetColor.islandInk)
                                    .padding(.horizontal, 16)
                                    .frame(height: IslandEntryMetrics.noteTagHeight)
                                    .background(WidgetColor.islandInk.opacity(0.14), in: Capsule())
                            }
                            .buttonStyle(IslandControlButtonStyle())
                            .accessibilityIdentifier("live-entry-begin")
                        }
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
            .frame(width: 14, height: 14)
            .accessibilityHidden(true)
    }
}

private struct AliveMonogramShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let left = rect.minX + rect.width * 0.10
        let right = rect.maxX - rect.width * 0.10
        let bottom = rect.maxY - rect.height * 0.08
        let apexY = rect.minY + rect.height * 0.10

        path.move(to: CGPoint(x: left, y: bottom))
        path.addLine(to: CGPoint(x: rect.midX, y: apexY))
        path.addLine(to: CGPoint(x: right, y: bottom))

        path.move(
            to: CGPoint(
                x: rect.minX + rect.width * 0.27,
                y: rect.minY + rect.height * 0.62
            )
        )
        path.addLine(
            to: CGPoint(
                x: rect.maxX - rect.width * 0.27,
                y: rect.minY + rect.height * 0.62
            )
        )
        return path
    }
}
