import AliveCore
import SwiftUI

struct TodayView: View {
    let model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            OrreryBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AliveSpace.x4) {
                    pageHeader

                    if let snapshot = model.snapshot {
                        contextLine(snapshot)

                        if snapshot.needsBalanceReview, snapshot.phase != .pending {
                            BalanceReviewBanner {
                                model.openBalance()
                            }
                        }

                        HeroBudgetCard(
                            snapshot: snapshot,
                            activityStatus: model.activity.status,
                            onPrimary: {
                                if snapshot.phase == .pending {
                                    model.openSettings()
                                } else {
                                    model.openQuickExpense()
                                }
                            },
                            onActivity: {
                                Task { await model.toggleLiveActivity() }
                            }
                        )
                        .animation(reduceMotion ? nil : AliveMotion.value, value: snapshot.generatedAt)

                        if snapshot.phase == .pending {
                            pendingFootnote
                        } else {
                            historyLink(snapshot)
                        }
                    } else {
                        ProgressView()
                            .tint(AliveColor.brass)
                            .frame(maxWidth: .infinity)
                            .padding(.top, AliveSpace.x8)
                    }
                }
                .padding(.horizontal, AliveSpace.pageInset)
                .padding(.top, AliveSpace.x2)
                .padding(.bottom, AliveSpace.x8)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var pageHeader: some View {
        HStack(spacing: AliveSpace.x2) {
            HStack(spacing: AliveSpace.x2) {
                OrnamentalRingMark()
                Text("ALIVE")
                    .font(AliveFont.sans(14, weight: .semibold, relativeTo: .headline))
                    .tracking(3)
                    .foregroundStyle(AliveColor.ink)
            }

            Spacer()

            IconAction(
                systemName: model.activity.isActive ? "record.circle.fill" : "record.circle",
                accessibilityLabel: model.activity.statusText
            ) {
                Task { await model.toggleLiveActivity() }
            }

            IconAction(systemName: "gearshape", accessibilityLabel: "设置") {
                model.openSettings()
            }
        }
        .padding(.top, AliveSpace.x1)
    }

    private func contextLine(_ snapshot: BudgetSnapshot) -> some View {
        HStack(spacing: AliveSpace.x2) {
            if snapshot.phase == .pending {
                Text("星盘将在 \(AliveDateText.monthDay(snapshot.startDate)) 启动")
            } else {
                Text(AliveDateText.monthDay(Date()))
                Text("·")
                    .foregroundStyle(AliveColor.brass)
                Text("距发薪 \(snapshot.daysRemaining) 天")
            }
            Spacer()
            CycleBadge(phase: snapshot.phase)
        }
        .font(AliveFont.sans(13, weight: .medium, relativeTo: .footnote))
        .foregroundStyle(AliveColor.inkSecondary)
        .accessibilityElement(children: .combine)
    }

    private func historyLink(_ snapshot: BudgetSnapshot) -> some View {
        Button {
            model.openHistory()
        } label: {
            HStack(spacing: AliveSpace.x3) {
                VStack(alignment: .leading, spacing: AliveSpace.x1) {
                    Text("本周期记录")
                        .font(AliveFont.sans(15, weight: .semibold, relativeTo: .body))
                        .foregroundStyle(AliveColor.ink)
                    Text("\(model.currentExpenses.count) 笔 · 合计 \(MoneyFormatter.currency(cents: model.currentExpenses.reduce(0) { $0 + $1.amountCents }))")
                        .font(AliveFont.sans(12, relativeTo: .caption))
                        .foregroundStyle(AliveColor.inkTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AliveColor.brass)
            }
            .padding(.vertical, AliveSpace.x3)
            .frame(minHeight: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            BrassRule()
        }
        .accessibilityLabel("本周期记录，\(model.currentExpenses.count) 笔支出")
    }

    private var pendingFootnote: some View {
        HStack(alignment: .top, spacing: AliveSpace.x2) {
            Image(systemName: "moon.stars")
                .foregroundStyle(AliveColor.brass)
                .padding(.top, 2)
            Text("起始日前不能记支出，也不能开启灵动岛。日期与初始余额仍可在设置中调整。")
                .font(AliveFont.sans(13, relativeTo: .footnote))
                .lineSpacing(5)
                .foregroundStyle(AliveColor.inkTertiary)
        }
        .padding(.horizontal, AliveSpace.x1)
    }
}

private struct HeroBudgetCard: View {
    let snapshot: BudgetSnapshot
    let activityStatus: BudgetActivityController.Status
    let onPrimary: () -> Void
    let onActivity: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isOverspent: Bool {
        snapshot.phase == .overspent
    }

    private var isPending: Bool {
        snapshot.phase == .pending
    }

    private var displayAmount: Decimal {
        if isPending {
            return snapshot.todayBudgetCents
        }
        if isOverspent, snapshot.todayAvailableCents < 0 {
            return -snapshot.todayAvailableCents
        }
        return max(0, snapshot.todayAvailableCents)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AliveSpace.x4) {
            HStack(alignment: .center) {
                Text(sectionLabel)
                    .font(AliveFont.sans(13, weight: .semibold, relativeTo: .footnote))
                    .tracking(1)
                    .foregroundStyle(isOverspent ? AliveColor.overspend : AliveColor.inkSecondary)
                Spacer()
                Text(isPending ? "预计每日额度" : "今日预算 \(MoneyFormatter.currency(cents: snapshot.todayBudgetCents))")
                    .font(AliveFont.sans(11, weight: .medium, relativeTo: .caption2))
                    .foregroundStyle(AliveColor.inkTertiary)
                    .monospacedDigit()
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AliveSpace.x3) {
                    amountBlock
                    ring
                }
            } else {
                HStack(alignment: .center, spacing: AliveSpace.x4) {
                    amountBlock
                        .layoutPriority(1)
                    Spacer(minLength: AliveSpace.x2)
                    ring
                }
            }

            BrassRule()

            VStack(alignment: .leading, spacing: AliveSpace.x1) {
                Text(detailLine)
                    .font(AliveFont.sans(14, weight: .medium, relativeTo: .subheadline))
                    .foregroundStyle(AliveColor.inkSecondary)
                    .monospacedDigit()

                if isOverspent {
                    Text("明天会按当前余额重新分配。")
                        .font(AliveFont.sans(13, relativeTo: .footnote))
                        .foregroundStyle(AliveColor.inkTertiary)
                } else if isPending {
                    Text("\(snapshot.daysRemaining) 天平均分配")
                        .font(AliveFont.sans(13, relativeTo: .footnote))
                        .foregroundStyle(AliveColor.inkTertiary)
                }
            }

            PrimaryAction(
                title: isPending ? "调整设置" : "记一笔",
                systemImage: isPending ? "slider.horizontal.3" : "plus"
            ) {
                onPrimary()
            }

            if !isPending {
                activityAction
            }
        }
        .padding(AliveSpace.x4)
        .background(AliveColor.card)
        .overlay {
            Rectangle()
                .stroke(AliveColor.line, lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            Rectangle()
                .fill(isOverspent ? AliveColor.overspend : AliveColor.brass)
                .frame(width: 34, height: 1)
                .padding(.trailing, AliveSpace.x4)
        }
        .accessibilityElement(children: .contain)
    }

    private var amountBlock: some View {
        AmountText(
            cents: displayAmount,
            size: 58,
            color: isOverspent ? AliveColor.overspend : AliveColor.ink
        )
        .accessibilityLabel(accessibilityAmount)
    }

    private var ring: some View {
        OrreryRing(
            progress: progressRatio,
            phase: snapshot.phase,
            diameter: 88
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日预算使用进度")
        .accessibilityValue("\(Int((progressRatio * 100).rounded()))%")
    }

    private var activityAction: some View {
        HStack {
            Spacer()
            Button(action: onActivity) {
                HStack(spacing: AliveSpace.x1) {
                    if activityStatus == .active {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                    }
                    Text(activityButtonTitle)
                        .font(AliveFont.sans(13, weight: .medium, relativeTo: .footnote))
                }
                .foregroundStyle(
                    activityStatus == .unavailable ? AliveColor.inkTertiary : AliveColor.inkSecondary
                )
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(activityStatus == .unavailable)
            .accessibilityHint("单次最长约 8 小时，跨午夜或到发薪日后需要重新开启。")
            Spacer()
        }
    }

    private var activityButtonTitle: String {
        switch activityStatus {
        case .active:
            "今日灵动岛已开启 · 结束"
        case .stale:
            "今日灵动岛已过期 · 重新开启"
        case .inactive:
            "开启今日灵动岛"
        case .unavailable:
            "系统未允许实时活动"
        }
    }

    private var sectionLabel: String {
        if isPending {
            return "预计每日额度"
        }
        return isOverspent ? "今天已超出" : "今天还可花"
    }

    private var detailLine: String {
        if isPending {
            return "起始余额 \(MoneyFormatter.currency(cents: snapshot.currentBalanceCents))"
        }
        return "余额 \(MoneyFormatter.currency(cents: snapshot.currentBalanceCents)) · \(snapshot.daysRemaining) 天"
    }

    private var progressRatio: Double {
        guard snapshot.todayBudgetCents > 0 else { return 0 }
        let spent = NSDecimalNumber(decimal: Decimal(snapshot.todaySpentCents)).doubleValue
        let budget = NSDecimalNumber(decimal: snapshot.todayBudgetCents).doubleValue
        guard budget > 0 else { return 0 }
        return min(max(spent / budget, 0), 1)
    }

    private var accessibilityAmount: String {
        if isOverspent {
            return "今天已超出 \(MoneyFormatter.spoken(cents: displayAmount))"
        }
        if isPending {
            return "预计每日额度 \(MoneyFormatter.spoken(cents: displayAmount))，起始 \(AliveDateText.monthDay(snapshot.startDate))"
        }
        return "今天还可花 \(MoneyFormatter.spoken(cents: displayAmount))，余额 \(MoneyFormatter.spoken(cents: Decimal(snapshot.currentBalanceCents)))，距发薪 \(snapshot.daysRemaining) 天"
    }
}

private struct BalanceReviewBanner: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: AliveSpace.x3) {
                Image(systemName: "sunrise")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AliveColor.brass)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: AliveSpace.x1) {
                    Text("新的周期已经开始")
                        .font(AliveFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(AliveColor.ink)
                    Text("已结转旧余额。收到工资后，请更新当前余额。")
                        .font(AliveFont.sans(12, relativeTo: .caption))
                        .lineSpacing(4)
                        .foregroundStyle(AliveColor.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AliveColor.brass)
                    .padding(.top, 3)
            }
            .padding(AliveSpace.x3)
            .background(AliveColor.surface)
            .overlay {
                Rectangle()
                    .stroke(AliveColor.line, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("打开调整余额")
    }
}
