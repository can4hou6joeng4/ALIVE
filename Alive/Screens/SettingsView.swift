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

    private var canSavePendingCycle: Bool {
        snapshot?.phase == .pending
            && (pendingBalanceCents ?? 0) > 0
            && pendingDatesValid
            && !isSavingCycle
    }

    var body: some View {
        ZStack {
            OrreryBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AliveSpace.x6) {
                    appearanceSection
                    liveActivitySection
                    cycleSection
                    privacySection
                }
                .padding(.horizontal, AliveSpace.pageInset)
                .padding(.top, AliveSpace.x4)
                .padding(.bottom, AliveSpace.x8)
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AliveColor.canvas, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear(perform: loadPendingFields)
        .onChange(of: snapshot?.generatedAt) { _, _ in
            loadPendingFields()
        }
        .sensoryFeedback(.success, trigger: savedCycle)
    }

    private var appearanceSection: some View {
        settingsSection("外观") {
            VStack(alignment: .leading, spacing: AliveSpace.x3) {
                HStack(spacing: 0) {
                    ForEach(ThemePreference.allCases) { option in
                        Button {
                            withAnimation(AliveMotion.quick) {
                                model.theme = option
                            }
                        } label: {
                            Text(option.title)
                                .font(AliveFont.sans(13, weight: .semibold, relativeTo: .footnote))
                                .foregroundStyle(model.theme == option ? AliveColor.canvas : AliveColor.inkSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                                .background(model.theme == option ? AliveColor.ink : Color.clear)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(model.theme == option ? .isSelected : [])
                    }
                }
                .overlay {
                    Rectangle()
                        .stroke(AliveColor.line, lineWidth: 1)
                }

                Text("默认使用羊皮纸浅色主题；深色主题沿用同一套黄铜与星银令牌。")
                    .font(AliveFont.sans(12, relativeTo: .caption))
                    .lineSpacing(4)
                    .foregroundStyle(AliveColor.inkTertiary)
            }
        }
    }

    private var liveActivitySection: some View {
        settingsSection("今日灵动岛") {
            VStack(alignment: .leading, spacing: AliveSpace.x3) {
                HStack(spacing: AliveSpace.x2) {
                    Circle()
                        .fill(activityStatusColor)
                        .frame(width: 6, height: 6)
                    Text(model.activity.statusText)
                        .font(AliveFont.sans(14, weight: .medium, relativeTo: .subheadline))
                        .foregroundStyle(AliveColor.inkSecondary)
                    Spacer()
                }

                Button {
                    Task { await model.toggleLiveActivity() }
                } label: {
                    Text(activityButtonTitle)
                        .font(AliveFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(AliveColor.ink)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .overlay {
                            Rectangle()
                                .stroke(AliveColor.brass, lineWidth: 1)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(snapshot?.phase == .pending || model.activity.status == .unavailable)
                .opacity(snapshot?.phase == .pending || model.activity.status == .unavailable ? 0.44 : 1)

                Text("单次最长约 8 小时，不自动续期。跨午夜后会标记过期；可以再次手动开启。Widget 用于持续查看。")
                    .font(AliveFont.sans(12, relativeTo: .caption))
                    .lineSpacing(5)
                    .foregroundStyle(AliveColor.inkTertiary)
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
            BrassRule(subtle: true)
            cycleInfoRow("发薪日", AliveDateText.fullDay(snapshot.payday))
            BrassRule(subtle: true)
            cycleInfoRow("当前余额", MoneyFormatter.currency(cents: snapshot.currentBalanceCents))
            Text("周期开始后日期不可修改。余额可随时在今日主屏调整。")
                .font(AliveFont.sans(12, relativeTo: .caption))
                .lineSpacing(4)
                .foregroundStyle(AliveColor.inkTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func pendingCycleEditor(_ snapshot: BudgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AliveSpace.x3) {
            VStack(alignment: .leading, spacing: AliveSpace.x1) {
                FieldLabel(text: "初始余额")
                HStack(alignment: .firstTextBaseline, spacing: AliveSpace.x2) {
                    Text("¥")
                        .font(AliveFont.display(24))
                        .foregroundStyle(AliveColor.brass)
                    TextField("0.00", text: $pendingBalanceText)
                        .font(AliveFont.display(30))
                        .monospacedDigit()
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .foregroundStyle(AliveColor.ink)
                }
                BrassRule()
            }

            HStack {
                Text("起始日")
                    .font(AliveFont.sans(14, weight: .medium, relativeTo: .subheadline))
                    .foregroundStyle(AliveColor.inkSecondary)
                Spacer()
                DatePicker("起始日", selection: $pendingStartDate, displayedComponents: .date)
                    .labelsHidden()
                    .tint(AliveColor.ink)
            }
            .frame(minHeight: 44)

            BrassRule(subtle: true)

            HStack {
                Text("发薪日")
                    .font(AliveFont.sans(14, weight: .medium, relativeTo: .subheadline))
                    .foregroundStyle(AliveColor.inkSecondary)
                Spacer()
                DatePicker("发薪日", selection: $pendingPayday, displayedComponents: .date)
                    .labelsHidden()
                    .tint(AliveColor.ink)
            }
            .frame(minHeight: 44)

            InlineError(message: cycleError ?? (pendingDatesValid ? nil : BudgetError.invalidDates.localizedDescription))

            PrimaryAction(
                title: "保存周期设置",
                systemImage: "checkmark",
                isBusy: isSavingCycle
            ) {
                savePendingCycle()
            }
            .disabled(!canSavePendingCycle)
            .opacity(canSavePendingCycle ? 1 : 0.44)

            Text("周期开始后，起始日与发薪日将变为只读。")
                .font(AliveFont.sans(12, relativeTo: .caption))
                .foregroundStyle(AliveColor.inkTertiary)
        }
    }

    private var privacySection: some View {
        settingsSection("隐私与关于") {
            VStack(alignment: .leading, spacing: AliveSpace.x2) {
                Text("数据仅保存在本机。")
                    .font(AliveFont.sans(14, weight: .medium, relativeTo: .subheadline))
                    .foregroundStyle(AliveColor.ink)
                Text("金额、日期与支出记录保存在 App Group 本地容器中，不接入网络、分析、广告或第三方 SDK。")
                    .font(AliveFont.sans(12, relativeTo: .caption))
                    .lineSpacing(5)
                    .foregroundStyle(AliveColor.inkTertiary)
                BrassRule(subtle: true)
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

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AliveSpace.x3) {
            Text(title)
                .font(AliveFont.sans(12, weight: .semibold, relativeTo: .caption))
                .tracking(1.8)
                .foregroundStyle(AliveColor.brass)
            content()
        }
        .padding(.top, AliveSpace.x2)
        .overlay(alignment: .top) {
            BrassRule()
        }
    }

    private func cycleInfoRow(_ label: String, _ value: String) -> some View {
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

    private var activityButtonTitle: String {
        if model.activity.status == .active {
            return "结束活动"
        }
        if model.activity.status == .stale {
            return "重新开启今日灵动岛"
        }
        return "开启今日灵动岛"
    }

    private var activityStatusColor: Color {
        switch model.activity.status {
        case .active:
            AliveColor.brass
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

    private func loadPendingFields() {
        guard let snapshot, snapshot.phase == .pending else { return }
        pendingBalanceText = MoneyFormatter.editText(cents: snapshot.currentBalanceCents)
        pendingStartDate = snapshot.startDate
        pendingPayday = snapshot.payday
    }

    private func savePendingCycle() {
        guard let pendingBalanceCents, canSavePendingCycle else { return }
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
