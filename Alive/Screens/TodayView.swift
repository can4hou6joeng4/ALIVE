import AliveCore
import SwiftUI

struct TodayView: View {
    let model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var isSettingsButtonFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AliveSpace.x3) {
                if let snapshot = model.snapshot {
                    bentoHeroTile(snapshot)

                    if snapshot.needsBalanceReview, snapshot.phase != .pending {
                        BalanceReviewBanner { model.openBalance() }
                    }

                    bentoMetricsGrid(snapshot)

                    if snapshot.phase != .pending && !model.currentExpenses.isEmpty {
                        recentExpensesTile
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
            .padding(.top, AliveSpace.x2)
            .padding(.bottom, AliveSpace.x6)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background(AliveColor.canvas)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let snapshot = model.snapshot,
               !model.isSettingsPresented,
               !model.isQuickEntryPresented {
                bottomActionBar(snapshot)
            }
        }
        .toolbar {
            if !model.isSettingsPresented {
                ToolbarItem(placement: .topBarLeading) {
                    TopChromeIconButton(
                        systemName: "line.3.horizontal",
                        accessibilityLabel: "设置",
                        accessibilityHint: "打开设置，也可以从屏幕左边缘向右轻扫。"
                    ) {
                        model.openSettings()
                    }
                    .accessibilityFocused($isSettingsButtonFocused)
                }
                .sharedBackgroundVisibility(.hidden)

                ToolbarItem(placement: .principal) {
                    Text(AliveDateText.monthDay(Date()))
                        .font(AliveFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                        .monospacedDigit()
                        .foregroundStyle(AliveColor.inkSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    ActivityControlButton(
                        status: activityVisualStatus(for: model.snapshot),
                        isEnabled: isActivityControlEnabled(for: model.snapshot),
                        accessibilityLabel: activityActionLabel(for: model.snapshot),
                        accessibilityValue: model.activity.statusText,
                        accessibilityHint: "单次最长约 8 小时，跨午夜或到发薪日后需要重新开启。"
                    ) {
                        Task { await model.toggleLiveActivity() }
                    }
                }
                .sharedBackgroundVisibility(.hidden)
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

    // MARK: - Top Bento Hero Tile

    private func bentoHeroTile(_ snapshot: BudgetSnapshot) -> some View {
        let state = snapshot.displayState
        let progress = progressRatio(snapshot)
        let percentage = "\(Int((progress * 100).rounded()))%"
        let badgeTitle = snapshot.phase == .pending
            ? "待开始"
            : (state.isOverspent ? "已超出" : "已用 \(percentage)")

        return SurfaceCard(
            padding: AliveSpace.x5,
            borderColor: state.isOverspent ? AliveColor.overspend.opacity(0.32) : AliveColor.separator,
            borderWidth: state.isOverspent ? 1 : 0.5
        ) {
            VStack(alignment: .leading, spacing: AliveSpace.x3) {
                HStack(alignment: .center, spacing: AliveSpace.x2) {
                    Text(state.label)
                        .font(AliveFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(state.isOverspent ? AliveColor.overspend : AliveColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)

                    Spacer(minLength: AliveSpace.x2)

                    Text(badgeTitle)
                        .font(AliveFont.sans(12, weight: .semibold, relativeTo: .footnote))
                        .monospacedDigit()
                        .foregroundStyle(state.isOverspent ? AliveColor.overspend : AliveColor.accent)
                        .padding(.horizontal, AliveSpace.x2 + 2)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(state.isOverspent ? AliveColor.overspend.opacity(0.12) : AliveColor.accentTint)
                        )
                        .accessibilityHidden(true)
                }

                AmountText(
                    cents: state.amountCents,
                    size: 56,
                    color: state.isOverspent ? AliveColor.overspend : AliveColor.ink
                )
                .accessibilityLabel(heroAccessibilityLabel(state))
                .accessibilityAddTraits(.isHeader)

                if snapshot.phase != .pending {
                    VStack(alignment: .leading, spacing: AliveSpace.x2) {
                        BudgetProgress(progress: progress, isOverspent: state.isOverspent)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("今日预算使用进度")
                            .accessibilityValue(percentage)

                        HStack {
                            Text("今日已花 \(MoneyFormatter.currency(cents: snapshot.todaySpentCents))")
                            Spacer(minLength: AliveSpace.x2)
                            Text("预算 \(MoneyFormatter.currency(cents: snapshot.todayBudgetCents))")
                        }
                        .font(AliveFont.sans(12, weight: .medium, relativeTo: .footnote))
                        .monospacedDigit()
                        .foregroundStyle(AliveColor.inkTertiary)
                    }
                }

                if let footnote = footnoteText(state) {
                    Text(footnote)
                        .font(AliveFont.sans(12, relativeTo: .footnote))
                        .foregroundStyle(state.isOverspent ? AliveColor.overspend : AliveColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .animation(reduceMotion ? nil : AliveMotion.value, value: snapshot.generatedAt)
    }

    // MARK: - 2-Column Bento Metrics Grid

    @ViewBuilder
    private func bentoMetricsGrid(_ snapshot: BudgetSnapshot) -> some View {
        let countdownTile = SurfaceCard(padding: AliveSpace.x4) {
            VStack(alignment: .leading, spacing: AliveSpace.x3) {
                Text(snapshot.phase == .pending ? "距开始" : "距发薪日")
                    .font(AliveFont.sans(12, weight: .semibold, relativeTo: .footnote))
                    .foregroundStyle(AliveColor.inkTertiary)

                Spacer(minLength: 0)

                HStack(alignment: .firstTextBaseline, spacing: AliveSpace.x1) {
                    Text("\(snapshot.phase == .pending ? snapshot.daysUntilStart : snapshot.daysRemaining)")
                        .font(AliveFont.display(34, relativeTo: .title))
                        .monospacedDigit()
                        .foregroundStyle(AliveColor.ink)
                    Text("天")
                        .font(AliveFont.sans(13, weight: .semibold, relativeTo: .footnote))
                        .foregroundStyle(AliveColor.inkSecondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        }
        .accessibilityElement(children: .combine)

        let balanceTile = Button {
            if snapshot.phase == .pending {
                model.openSettings()
            } else {
                model.openBalance()
            }
        } label: {
            SurfaceCard(padding: AliveSpace.x4) {
                VStack(alignment: .leading, spacing: AliveSpace.x3) {
                    HStack(spacing: AliveSpace.x1) {
                        Text(snapshot.phase == .pending ? "起始余额" : "当前余额")
                            .font(AliveFont.sans(12, weight: .semibold, relativeTo: .footnote))
                            .foregroundStyle(AliveColor.inkTertiary)
                        Spacer(minLength: 0)
                        Text("调整")
                            .font(AliveFont.sans(12, weight: .semibold, relativeTo: .footnote))
                            .foregroundStyle(AliveColor.accent)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AliveColor.accent)
                            .accessibilityHidden(true)
                    }

                    Spacer(minLength: 0)

                    Text(MoneyFormatter.currency(cents: snapshot.currentBalanceCents))
                        .font(AliveFont.display(22, relativeTo: .title3))
                        .monospacedDigit()
                        .foregroundStyle(AliveColor.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
                .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(snapshot.phase == .pending ? "打开设置调整起始余额。" : "修改当前剩余余额并重算今天还可花。")

        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: AliveSpace.x3) {
                countdownTile
                balanceTile
            }
        } else {
            HStack(spacing: AliveSpace.x3) {
                countdownTile
                balanceTile
            }
        }
    }

    // MARK: - Bottom Bento Recent Tile

    private var recentExpensesTile: some View {
        let sorted = Array(model.currentExpenses.sorted { $0.occurredAt > $1.occurredAt }.prefix(3))

        return SurfaceCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Button { model.openHistory() } label: {
                    HStack(spacing: AliveSpace.x2) {
                        Text("最近记录")
                            .font(AliveFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                            .foregroundStyle(AliveColor.inkSecondary)
                        Spacer()
                        Text("共 \(model.currentExpenses.count) 笔")
                            .font(AliveFont.sans(12, weight: .medium, relativeTo: .footnote))
                            .monospacedDigit()
                            .foregroundStyle(AliveColor.inkTertiary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AliveColor.inkTertiary)
                    }
                    .frame(minHeight: 46)
                    .padding(.horizontal, AliveSpace.x5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("打开本周期全部记录")

                ForEach(sorted) { expense in
                    Rectangle()
                        .fill(AliveColor.separator)
                        .frame(height: 0.5)
                        .padding(.leading, AliveSpace.x5)

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
                            .padding(.vertical, AliveSpace.x2)
                            .contentShape(Rectangle())
                        } else {
                            HStack(spacing: AliveSpace.x3) {
                                Text(expense.note ?? "支出")
                                    .font(AliveFont.sans(15, weight: .medium, relativeTo: .body))
                                    .foregroundStyle(AliveColor.ink)
                                    .lineLimit(1)

                                Text(recentTimeLabel(expense.occurredAt))
                                    .font(AliveFont.sans(12, weight: .medium, relativeTo: .footnote))
                                    .monospacedDigit()
                                    .foregroundStyle(AliveColor.inkTertiary)
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

    private func activityVisualStatus(for snapshot: BudgetSnapshot?) -> BudgetActivityController.Status {
        guard let snapshot, snapshot.phase != .pending else { return .unavailable }
        return model.activity.status
    }
}

private struct ActivityControlButton: View {
    let status: BudgetActivityController.Status
    let isEnabled: Bool
    let accessibilityLabel: String
    let accessibilityValue: String
    let accessibilityHint: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                Text(title)
                    .font(AliveFont.sans(12, weight: .semibold, relativeTo: .footnote))
                    .foregroundStyle(isEnabled ? AliveColor.ink : AliveColor.inkTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .dynamicTypeSize(...DynamicTypeSize.aliveControlLimit)
            .padding(.horizontal, AliveSpace.x3)
            .frame(minHeight: 44)
            .contentShape(Capsule())
            .background(Capsule().fill(AliveColor.surfaceElevated))
            .overlay {
                Capsule().stroke(AliveColor.separator, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.44)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
    }

    private var title: String {
        switch status {
        case .active: "实时中"
        case .inactive: "未开启"
        case .stale: "已过期"
        case .unavailable: "不可用"
        }
    }

    private var symbolName: String {
        switch status {
        case .active: "dot.radiowaves.left.and.right"
        case .inactive: "plus.circle"
        case .stale: "arrow.clockwise.circle"
        case .unavailable: "slash.circle"
        }
    }

    private var tint: Color {
        switch status {
        case .active: .green
        case .inactive: AliveColor.accent
        case .stale: .orange
        case .unavailable: AliveColor.inkTertiary
        }
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
            .overlay {
                RoundedRectangle(cornerRadius: AliveRadius.card, style: .continuous)
                    .stroke(AliveColor.accent.opacity(0.22), lineWidth: 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("新的周期已经开始")
        .accessibilityHint("打开调整余额")
    }
}
