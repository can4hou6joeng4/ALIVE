import AliveCore
import SwiftUI

struct TodayView: View {
    let model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var isSettingsButtonFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AliveSpace.x5) {
                if let snapshot = model.snapshot {
                    dateHeader(snapshot)

                    if snapshot.needsBalanceReview, snapshot.phase != .pending {
                        BalanceReviewBanner { model.openBalance() }
                    }

                    heroCard(snapshot)

                    if snapshot.phase != .pending && !model.currentExpenses.isEmpty {
                        recentExpensesCard
                    }

                    if snapshot.phase == .pending {
                        pendingNote
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, AliveSpace.x10)
                }
            }
            .padding(.horizontal, AliveSpace.pageInset)
            .padding(.top, AliveSpace.x3)
            .padding(.bottom, AliveSpace.x6)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background(AliveColor.canvas)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let snapshot = model.snapshot {
                bottomActionBar(snapshot)
                    .opacity(model.isSettingsPresented ? 0 : 1)
            }
        }
        .toolbar {
            if !model.isSettingsPresented {
                ToolbarItem(placement: .topBarLeading) {
                    GlassIconButton(
                        systemName: "line.3.horizontal",
                        accessibilityLabel: "设置",
                        accessibilityHint: "打开设置，也可以从屏幕左边缘向右轻扫。"
                    ) {
                        model.openSettings()
                    }
                    .accessibilityFocused($isSettingsButtonFocused)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    GlassIconButton(
                        systemName: "waveform",
                        accessibilityLabel: activityActionLabel(for: model.snapshot),
                        accessibilityValue: model.activity.statusText,
                        accessibilityHint: "单次最长约 8 小时，跨午夜或到发薪日后需要重新开启。",
                        isEnabled: isActivityControlEnabled(for: model.snapshot)
                    ) {
                        Task { await model.toggleLiveActivity() }
                    }
                }
            }
        }
        .onChange(of: model.isSettingsPresented) { _, presented in
            if !presented {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(250))
                    isSettingsButtonFocused = true
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .global)
                .onEnded { value in
                    guard value.startLocation.x <= 24,
                          value.translation.width >= 72,
                          abs(value.translation.height) <= value.translation.width * 0.6
                    else { return }
                    model.openSettings()
                }
        )
    }

    private func dateHeader(_ snapshot: BudgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AliveSpace.x1) {
            Text(snapshot.phase == .pending ? "周期尚未开始" : "今天")
                .font(AliveFont.sans(13, weight: .semibold, relativeTo: .footnote))
                .foregroundStyle(AliveColor.inkTertiary)
            HStack(alignment: .firstTextBaseline, spacing: AliveSpace.x3) {
                Text(AliveDateText.monthDay(Date()))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AliveColor.ink)
                if snapshot.phase != .pending {
                    StatusPill(title: snapshot.displayState.isOverspent ? "已超支" : "距发薪 \(snapshot.daysRemaining) 天",
                               isEmphasized: snapshot.displayState.isOverspent)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func heroCard(_ snapshot: BudgetSnapshot) -> some View {
        let state = snapshot.displayState
        return SurfaceCard {
            VStack(alignment: .leading, spacing: AliveSpace.x5) {
                VStack(alignment: .leading, spacing: AliveSpace.x2) {
                    Text(state.label)
                        .font(AliveFont.sans(15, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(state.isOverspent ? AliveColor.overspend : AliveColor.inkSecondary)
                        .accessibilityHidden(true)

                    AmountText(
                        cents: state.amountCents,
                        size: 62,
                        color: state.isOverspent ? AliveColor.overspend : AliveColor.ink
                    )
                    .accessibilityLabel(heroAccessibilityLabel(state))
                    .accessibilityAddTraits(.isHeader)
                }

                Divider().overlay(AliveColor.separator)

                VStack(alignment: .leading, spacing: AliveSpace.x3) {
                    if snapshot.phase == .pending {
                        infoRow("预计每日额度", MoneyFormatter.currency(cents: snapshot.todayBudgetCents))
                        infoRow("起始余额", MoneyFormatter.currency(cents: snapshot.currentBalanceCents))
                        infoRow("距开始", "\(snapshot.daysUntilStart) 天")
                    } else {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: AliveSpace.x1) {
                                Text("今日预算")
                                    .font(AliveFont.sans(14, weight: .medium, relativeTo: .subheadline))
                                    .foregroundStyle(AliveColor.inkSecondary)
                                HStack(alignment: .firstTextBaseline, spacing: AliveSpace.x2) {
                                    Text(MoneyFormatter.currency(cents: snapshot.todayBudgetCents))
                                        .font(AliveFont.sans(15, weight: .semibold, relativeTo: .subheadline))
                                        .monospacedDigit()
                                        .foregroundStyle(AliveColor.ink)
                                        .minimumScaleFactor(0.75)
                                    Spacer(minLength: AliveSpace.x2)
                                    Text("\(Int((progressRatio(snapshot) * 100).rounded()))%")
                                        .font(AliveFont.sans(12, weight: .medium, relativeTo: .footnote))
                                        .monospacedDigit()
                                        .foregroundStyle(AliveColor.inkTertiary)
                                }
                            }
                        } else {
                            HStack(alignment: .firstTextBaseline) {
                                Text("今日预算")
                                    .font(AliveFont.sans(14, weight: .medium, relativeTo: .subheadline))
                                    .foregroundStyle(AliveColor.inkSecondary)
                                Spacer()
                                HStack(spacing: AliveSpace.x2) {
                                    Text(MoneyFormatter.currency(cents: snapshot.todayBudgetCents))
                                        .font(AliveFont.sans(15, weight: .semibold, relativeTo: .subheadline))
                                        .monospacedDigit()
                                        .foregroundStyle(AliveColor.ink)
                                    Text("\(Int((progressRatio(snapshot) * 100).rounded()))%")
                                        .font(AliveFont.sans(12, weight: .medium, relativeTo: .footnote))
                                        .monospacedDigit()
                                        .foregroundStyle(AliveColor.inkTertiary)
                                }
                            }
                        }
                        BudgetProgress(progress: progressRatio(snapshot), isOverspent: state.isOverspent)
                            .accessibilityLabel("今日预算使用进度")
                            .accessibilityValue("\(Int((progressRatio(snapshot) * 100).rounded()))%")
                        infoRow("今日已花", MoneyFormatter.currency(cents: snapshot.todaySpentCents))
                        infoRow("当前余额", MoneyFormatter.currency(cents: snapshot.currentBalanceCents))
                    }
                }

                if let footnote = footnoteText(state) {
                    Text(footnote)
                        .font(AliveFont.sans(13, relativeTo: .footnote))
                        .foregroundStyle(AliveColor.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .animation(reduceMotion ? nil : AliveMotion.value, value: snapshot.generatedAt)
    }

    @ViewBuilder
    private func infoRow(_ title: String, _ value: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: AliveSpace.x1) {
                Text(title)
                    .font(AliveFont.sans(14, weight: .medium, relativeTo: .subheadline))
                    .foregroundStyle(AliveColor.inkSecondary)
                Text(value)
                    .font(AliveFont.sans(15, weight: .semibold, relativeTo: .subheadline))
                    .monospacedDigit()
                    .foregroundStyle(AliveColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 28)
        } else {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(AliveFont.sans(14, weight: .medium, relativeTo: .subheadline))
                    .foregroundStyle(AliveColor.inkSecondary)
                Spacer(minLength: AliveSpace.x3)
                Text(value)
                    .font(AliveFont.sans(15, weight: .semibold, relativeTo: .subheadline))
                    .monospacedDigit()
                    .foregroundStyle(AliveColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(minHeight: 28)
        }
    }

    private var recentExpensesCard: some View {
        SurfaceCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Button { model.openHistory() } label: {
                    HStack {
                        Text("最近记录")
                            .font(AliveFont.sans(16, weight: .semibold, relativeTo: .headline))
                            .foregroundStyle(AliveColor.ink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AliveColor.inkTertiary)
                    }
                    .frame(minHeight: 50)
                    .padding(.horizontal, AliveSpace.x5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("打开本周期全部记录")

                ForEach(Array(model.currentExpenses.sorted { $0.occurredAt > $1.occurredAt }.prefix(3))) { expense in
                    Button { model.openHistory() } label: {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: AliveSpace.x1) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(recentTimeLabel(expense.occurredAt))
                                        .font(AliveFont.sans(12, weight: .medium, relativeTo: .footnote))
                                        .monospacedDigit()
                                        .foregroundStyle(AliveColor.inkTertiary)
                                    Spacer(minLength: AliveSpace.x2)
                                    recentAmountLabel(expense)
                                }
                                Text(expense.note ?? "支出")
                                    .font(AliveFont.sans(15, weight: .medium, relativeTo: .body))
                                    .foregroundStyle(AliveColor.ink)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(minHeight: 44)
                            .padding(.horizontal, AliveSpace.x5)
                            .contentShape(Rectangle())
                        } else {
                            HStack(spacing: AliveSpace.x3) {
                                Text(recentTimeLabel(expense.occurredAt))
                                    .font(AliveFont.sans(12, weight: .medium, relativeTo: .footnote))
                                    .monospacedDigit()
                                    .foregroundStyle(AliveColor.inkTertiary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    .frame(width: 64, alignment: .leading)
                                Text(expense.note ?? "支出")
                                    .font(AliveFont.sans(15, weight: .medium, relativeTo: .body))
                                    .foregroundStyle(AliveColor.ink)
                                    .lineLimit(1)
                                Spacer(minLength: AliveSpace.x2)
                                recentAmountLabel(expense)
                            }
                            .frame(minHeight: 44)
                            .padding(.horizontal, AliveSpace.x5)
                            .contentShape(Rectangle())
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("打开本周期全部记录")
                }
            }
        }
    }

    private var pendingNote: some View {
        HStack(alignment: .top, spacing: AliveSpace.x3) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(AliveColor.accent)
                .accessibilityHidden(true)
            Text("起始日前不能记支出，也不能开启实时活动。日期与初始余额仍可在设置中调整。")
                .font(AliveFont.sans(13, relativeTo: .footnote))
                .foregroundStyle(AliveColor.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AliveSpace.x4)
        .background(AliveColor.accentTint, in: RoundedRectangle(cornerRadius: AliveRadius.control, style: .continuous))
    }

    private func bottomActionBar(_ snapshot: BudgetSnapshot) -> some View {
        GlassActionBar(axis: dynamicTypeSize.isAccessibilitySize ? .vertical : .horizontal) {
            if snapshot.phase == .pending {
                GlassActionButton(
                    title: "调整设置",
                    systemImage: "slider.horizontal.3",
                    isProminent: true,
                    accessibilityHint: "修改起始日、发薪日和初始余额。"
                ) { model.openSettings() }
            } else {
                GlassActionButton(
                    title: "调余额",
                    systemImage: "plus.forwardslash.minus",
                    accessibilityHint: "修改当前剩余余额并重算今天还可花。"
                ) { model.openBalance() }
                GlassActionButton(
                    title: "记一笔",
                    systemImage: "plus",
                    isProminent: true,
                    accessibilityHint: "记录一笔支出。"
                ) { model.openQuickExpense() }
            }
        }
    }

    private func recentTimeLabel(_ date: Date) -> String {
        let calendar = BudgetCalendar()
        let today = Date()
        if calendar.isSameDay(date, today) {
            return AliveDateText.time(date)
        }
        if let yesterday = calendar.calendar.date(byAdding: .day, value: -1, to: today),
           calendar.isSameDay(date, yesterday) {
            return "昨天 \(AliveDateText.time(date))"
        }
        return "\(AliveDateText.monthDay(date)) \(AliveDateText.time(date))"
    }

    private func recentAmountLabel(_ expense: Expense) -> some View {
        Text("-\(MoneyFormatter.currency(cents: Decimal(expense.amountCents)))")
            .font(AliveFont.sans(15, weight: .semibold, relativeTo: .body))
            .monospacedDigit()
            .foregroundStyle(AliveColor.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private func progressRatio(_ snapshot: BudgetSnapshot) -> Double {
        guard snapshot.todayBudgetCents > 0 else {
            return snapshot.displayState.isOverspent ? 1 : 0
        }
        let spent = NSDecimalNumber(decimal: Decimal(snapshot.todaySpentCents)).doubleValue
        let budget = NSDecimalNumber(decimal: snapshot.todayBudgetCents).doubleValue
        return min(max(spent / budget, 0), 1)
    }

    private func heroAccessibilityLabel(_ state: BudgetDisplayState) -> String {
        switch state {
        case .pending(let cents):
            "预计每日额度，\(MoneyFormatter.spoken(cents: cents))"
        case .available(let cents):
            "今天还可花，\(MoneyFormatter.spoken(cents: cents))"
        case .overspent(let overage):
            "今天已超出，\(MoneyFormatter.spoken(cents: overage))"
        case .negativeBalance(let balance, _):
            "余额已为负，差额 \(MoneyFormatter.spoken(cents: balance))"
        case .zeroBalance:
            "今日额度不可用，余额为零"
        }
    }

    private func footnoteText(_ state: BudgetDisplayState) -> String? {
        switch state {
        case .pending, .available:
            return nil
        case .overspent:
            return "明天会按当前余额重新分配。"
        case .negativeBalance(_, let overage):
            if let overage { return "今天已超出 \(MoneyFormatter.currency(cents: overage))，明天会按当前余额重新分配。" }
            return "今日额度按 0 计算，调整余额后会重新分配。"
        case .zeroBalance:
            return "当前余额为 ¥0.00，今日额度按 0 计算。"
        }
    }

    private func activityActionLabel(for snapshot: BudgetSnapshot?) -> String {
        guard let snapshot else { return "今日实时活动不可用" }
        if snapshot.phase == .pending || model.activity.status == .unavailable {
            return "今日实时活动不可用"
        }
        switch model.activity.status {
        case .active: return "结束今日实时活动"
        case .stale: return "重新开启今日实时活动"
        case .inactive: return "开启今日实时活动"
        case .unavailable: return "今日实时活动不可用"
        }
    }

    private func isActivityControlEnabled(for snapshot: BudgetSnapshot?) -> Bool {
        guard let snapshot else { return false }
        return snapshot.phase != .pending && model.activity.status != .unavailable
    }
}

private struct BalanceReviewBanner: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: AliveSpace.x3) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AliveColor.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AliveSpace.x1) {
                    Text("新的周期已经开始")
                        .font(AliveFont.sans(15, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(AliveColor.ink)
                    Text("已结转旧余额。收到工资后，请更新当前余额。")
                        .font(AliveFont.sans(13, relativeTo: .footnote))
                        .foregroundStyle(AliveColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: AliveSpace.x2)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AliveColor.inkTertiary)
                    .accessibilityHidden(true)
            }
            .padding(AliveSpace.x4)
            .background(AliveColor.accentTint, in: RoundedRectangle(cornerRadius: AliveRadius.card, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("新的周期已经开始")
        .accessibilityHint("打开调整余额")
    }
}
