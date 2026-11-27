import AliveCore
import SwiftUI

struct SettingsView: View {
    let model: AppModel

    @State private var pendingBalanceText = ""
    @State private var pendingStartDate = Date()
    @State private var pendingPayday = Date()
    @State private var isSavingCycle = false
    @State private var cycleError: String?
    @State private var savedCycle = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var isPendingBalanceFocused: Bool

    private let calendar = BudgetCalendar()

    private var snapshot: BudgetSnapshot? {
        model.snapshot
    }

    private var pendingBalanceCents: Int? {
        MoneyParser.cents(from: pendingBalanceText)
    }

    private var pendingDatesValid: Bool {
        calendar.startOfDay(pendingStartDate) < calendar.startOfDay(pendingPayday)
    }

    private var pendingBalanceValidation: String? {
        let trimmed = pendingBalanceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let cents = MoneyParser.cents(from: trimmed), cents > 0 else {
            return "请输入大于 0 的初始余额。"
        }
        return nil
    }

    private var canSavePendingCycle: Bool {
        snapshot?.phase == .pending
            && (pendingBalanceCents ?? 0) > 0
            && pendingDatesValid
            && pendingBalanceValidation == nil
            && !isSavingCycle
    }

    private var pendingFieldsDifferFromSnapshot: Bool {
        guard let snapshot else { return false }
        let baselineBalance = MoneyFormatter.editText(cents: snapshot.currentBalanceCents)
        return pendingBalanceText != baselineBalance
            || calendar.startOfDay(pendingStartDate) != calendar.startOfDay(snapshot.startDate)
            || calendar.startOfDay(pendingPayday) != calendar.startOfDay(snapshot.payday)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AliveSpace.x6) {
                appearanceSection
                liveActivitySection
                cycleSection
                privacySection
            }
            .padding(.horizontal, AliveSpace.pageInset)
            .padding(.top, AliveSpace.x4)
            .padding(.bottom, AliveSpace.x4)
        }
        // The keyboard scrolls a focused field only just into view; this keeps the
        // balance row and its dismiss button clear of the keyboard's top edge.
        .safeAreaPadding(.bottom, AliveSpace.x4)
        .background(AliveColor.canvas)
        .onAppear {
            loadPendingFields(force: true)
        }
        .onChange(of: snapshot?.generatedAt) { _, _ in
            guard !isPendingBalanceFocused, !pendingFieldsDifferFromSnapshot else { return }
            loadPendingFields()
        }
        .sensoryFeedback(.success, trigger: savedCycle)
    }

    private var appearanceSection: some View {
        settingsSection("外观") {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    HStack(alignment: .top, spacing: AliveSpace.x3) {
                        settingsGlyph("circle.lefthalf.filled")
                        appearanceCopy
                    }
                } else {
                    HStack(spacing: AliveSpace.x3) {
                        settingsGlyph("circle.lefthalf.filled")
                        appearanceCopy
                        Spacer(minLength: AliveSpace.x2)
                        StatusPill(title: "自动")
                            .accessibilityHidden(true)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("跟随系统，浅色与深色自动切换")
        }
    }

    private var appearanceCopy: some View {
        VStack(alignment: .leading, spacing: AliveSpace.x1) {
            Text("跟随系统")
                .font(AliveFont.sans(15, weight: .semibold, relativeTo: .body))
                .foregroundStyle(AliveColor.ink)
            Text("浅色与深色自动切换")
                .font(AliveFont.sans(12, relativeTo: .caption))
                .foregroundStyle(AliveColor.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var liveActivitySection: some View {
        settingsSection("实时活动") {
            VStack(alignment: .leading, spacing: AliveSpace.x3) {
                HStack(spacing: AliveSpace.x2) {
                    Circle()
                        .fill(activityStatusColor)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                    Text(model.activity.statusText)
                        .font(AliveFont.sans(14, weight: .medium, relativeTo: .subheadline))
                        .foregroundStyle(AliveColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: AliveSpace.x2)
                }
                .accessibilityElement(children: .combine)

                GlassActionButton(
                    title: activityButtonTitle,
                    systemImage: activitySystemImage,
                    accessibilityHint: liveActivityDisabled
                        ? "当前周期尚未开始，或系统不允许实时活动。"
                        : "开启后可在锁屏与灵动岛查看今日预算摘要。"
                ) {
                    Task { await model.toggleLiveActivity() }
                }
                .disabled(liveActivityDisabled)

                Text("单次最长约 8 小时，不自动续期；跨午夜或到发薪日后过期。日常查看请使用 App 主屏。")
                    .font(AliveFont.sans(12, relativeTo: .caption))
                    .lineSpacing(5)
                    .foregroundStyle(AliveColor.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var cycleSection: some View {
        settingsSection("周期") {
            if let snapshot {
                if snapshot.phase == .pending {
                    pendingCycleEditor(snapshot)
                } else {
                    readOnlyCycle(snapshot)
                }
            } else {
                Text("尚未建立周期。")
                    .font(AliveFont.sans(14, relativeTo: .subheadline))
                    .foregroundStyle(AliveColor.inkTertiary)
            }
        }
    }

    private func readOnlyCycle(_ snapshot: BudgetSnapshot) -> some View {
        VStack(spacing: AliveSpace.x3) {
            cycleInfoRow("起始日", AliveDateText.fullDay(snapshot.startDate))
            Rectangle().fill(AliveColor.separator).frame(height: 0.5)
            cycleInfoRow("发薪日", AliveDateText.fullDay(snapshot.payday))
            Rectangle().fill(AliveColor.separator).frame(height: 0.5)
            cycleInfoRow("当前余额", MoneyFormatter.currency(cents: snapshot.currentBalanceCents))
            Text("日期在周期开始后锁定；余额可随时在今日主屏调整。")
                .font(AliveFont.sans(12, relativeTo: .caption))
                .lineSpacing(4)
                .foregroundStyle(AliveColor.inkTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func pendingCycleEditor(_ snapshot: BudgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AliveSpace.x3) {
            VStack(alignment: .leading, spacing: AliveSpace.x1) {
                FieldLabel(text: "初始余额")
                HStack(alignment: .center, spacing: AliveSpace.x2) {
                    HStack(alignment: .firstTextBaseline, spacing: AliveSpace.x2) {
                        Text("¥")
                            .font(AliveFont.display(24))
                            .foregroundStyle(AliveColor.inkTertiary)
                            .accessibilityHidden(true)
                        TextField("0.00", text: $pendingBalanceText)
                            .font(AliveFont.display(30))
                            .monospacedDigit()
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .foregroundStyle(AliveColor.ink)
                            .focused($isPendingBalanceFocused)
                            .lineLimit(1)
                            .minimumScaleFactor(AliveFont.amountFieldMinimumScale)
                            .accessibilityLabel("初始余额")
                            .accessibilityHint("大于 0，最多 9 位整数和 2 位小数。")
                    }
                    if isPendingBalanceFocused {
                        KeyboardDismissButton {
                            isPendingBalanceFocused = false
                        }
                    }
                }
                // Tall enough for the dismiss button, so the row does not jump on focus.
                .frame(minHeight: 44)
                Rectangle().fill(AliveColor.separator).frame(height: 0.5)
            }

            AdaptiveDatePickerRow(
                title: "起始日",
                selection: $pendingStartDate,
                horizontalPadding: 0,
                verticalPadding: AliveSpace.x1
            )

            Rectangle().fill(AliveColor.separator).frame(height: 0.5)

            AdaptiveDatePickerRow(
                title: "发薪日",
                selection: $pendingPayday,
                horizontalPadding: 0,
                verticalPadding: AliveSpace.x1
            )

            InlineError(
                message: cycleError ?? pendingBalanceValidation
                    ?? (pendingDatesValid ? nil : BudgetError.invalidDates.localizedDescription)
            )

            PrimaryAction(
                title: "保存周期设置",
                systemImage: "checkmark",
                isBusy: isSavingCycle
            ) {
                savePendingCycle()
            }
            .disabled(!canSavePendingCycle)
            .accessibilityHint("保存待开始周期的余额与日期。")

            Text("周期开始后，起始日与发薪日将变为只读。")
                .font(AliveFont.sans(12, relativeTo: .caption))
                .foregroundStyle(AliveColor.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: pendingBalanceText) { _, _ in
            cycleError = nil
        }
        .onChange(of: pendingStartDate) { _, _ in
            cycleError = nil
        }
        .onChange(of: pendingPayday) { _, _ in
            cycleError = nil
        }
    }

    private var privacySection: some View {
        settingsSection("隐私与关于") {
            VStack(alignment: .leading, spacing: AliveSpace.x2) {
                HStack(alignment: .top, spacing: AliveSpace.x3) {
                    settingsGlyph("lock.shield")
                    VStack(alignment: .leading, spacing: AliveSpace.x1) {
                        Text("数据仅保存在本机")
                            .font(AliveFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                            .foregroundStyle(AliveColor.ink)
                        Text("金额、日期与支出记录仅保存在本机 App 容器中，不联网，也不接入分析、广告或第三方 SDK。")
                            .font(AliveFont.sans(12, relativeTo: .caption))
                            .lineSpacing(5)
                            .foregroundStyle(AliveColor.inkTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Rectangle().fill(AliveColor.separator).frame(height: 0.5)
                    .padding(.vertical, AliveSpace.x1)
                HStack {
                    Text("ALIVE")
                        .tracking(2)
                    Spacer()
                    Text(appVersion)
                }
                .font(AliveFont.sans(11, weight: .medium, relativeTo: .caption2))
                .foregroundStyle(AliveColor.inkTertiary)
            }
        }
    }

    private func settingsGlyph(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AliveColor.accent)
            .frame(width: 32, height: 32)
            .background(
                AliveColor.accentTint,
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .accessibilityHidden(true)
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AliveSpace.x3) {
            Text(title)
                .font(AliveFont.sans(13, weight: .semibold, relativeTo: .footnote))
                .foregroundStyle(AliveColor.inkTertiary)
                .accessibilityAddTraits(.isHeader)
            SurfaceCard {
                content()
            }
        }
    }

    @ViewBuilder
    private func cycleInfoRow(_ label: String, _ value: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: AliveSpace.x1) {
                Text(label)
                    .foregroundStyle(AliveColor.inkSecondary)
                Text(value)
                    .foregroundStyle(AliveColor.ink)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(AliveFont.sans(14, weight: .medium, relativeTo: .subheadline))
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack {
                Text(label)
                    .foregroundStyle(AliveColor.inkSecondary)
                Spacer()
                Text(value)
                    .foregroundStyle(AliveColor.ink)
                    .monospacedDigit()
            }
            .font(AliveFont.sans(14, weight: .medium, relativeTo: .subheadline))
        }
    }

    private var liveActivityDisabled: Bool {
        snapshot?.phase == .pending || model.activity.status == .unavailable
    }

    private var activityButtonTitle: String {
        if model.activity.status == .active {
            return "结束实时活动"
        }
        if model.activity.status == .stale {
            return "重新开启实时活动"
        }
        return "开启实时活动"
    }

    private var activitySystemImage: String {
        model.activity.status == .active ? "stop.circle" : "record.circle"
    }

    private var activityStatusColor: Color {
        switch model.activity.status {
        case .active:
            AliveColor.progress
        case .stale:
            AliveColor.overspend
        case .inactive:
            AliveColor.inkTertiary
        case .unavailable:
            AliveColor.overspend
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return "v\(version)"
    }

    private func loadPendingFields(force: Bool = false) {
        guard let snapshot, snapshot.phase == .pending else { return }
        if !force, isPendingBalanceFocused || pendingFieldsDifferFromSnapshot {
            return
        }
        pendingBalanceText = MoneyFormatter.editText(cents: snapshot.currentBalanceCents)
        pendingStartDate = snapshot.startDate
        pendingPayday = snapshot.payday
    }

    private func savePendingCycle() {
        guard let pendingBalanceCents, canSavePendingCycle else { return }
        isPendingBalanceFocused = false
        isSavingCycle = true
        cycleError = nil

        Task {
            do {
                try await model.updatePendingCycle(
                    initialBalanceCents: pendingBalanceCents,
                    startDate: pendingStartDate,
                    payday: pendingPayday
                )
                savedCycle.toggle()
            } catch {
                cycleError = error.localizedDescription
            }
            isSavingCycle = false
        }
    }
}
