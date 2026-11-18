import AliveCore
import SwiftUI

struct SetupView: View {
    let model: AppModel

    @State private var amountText = ""
    @State private var startDate: Date
    @State private var payday: Date
    @State private var isSubmitting = false
    @State private var errorText: String?
    @FocusState private var isAmountFocused: Bool

    init(model: AppModel) {
        self.model = model
        let calendar = BudgetCalendar()
        let today = calendar.startOfDay(Date())
        let defaultPayday = calendar.calendar.date(byAdding: .month, value: 1, to: today)
            ?? calendar.calendar.date(byAdding: .day, value: 30, to: today)
            ?? today
        _startDate = State(initialValue: today)
        _payday = State(initialValue: calendar.startOfDay(defaultPayday))
    }

    private var amountCents: Int? {
        MoneyParser.cents(from: amountText)
    }

    private var datesAreValid: Bool {
        BudgetCalendar().startOfDay(startDate) < BudgetCalendar().startOfDay(payday)
    }

    private var validationMessage: String? {
        let trimmedAmount = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAmount.isEmpty {
            guard let cents = amountCents else {
                return "请输入有效金额，最多 9 位整数和 2 位小数。"
            }
            if cents <= 0 {
                return "请输入大于 0 的金额。"
            }
        }
        if !datesAreValid {
            return "发薪日必须晚于起始日。"
        }
        return nil
    }

    private var canSubmit: Bool {
        (amountCents ?? 0) > 0 && datesAreValid && !isSubmitting
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AliveSpace.x6) {
                VStack(alignment: .leading, spacing: AliveSpace.x2) {
                    Text("ALIVE")
                        .font(AliveFont.sans(12, weight: .bold, relativeTo: .footnote))
                        .tracking(2)
                        .foregroundStyle(AliveColor.accent)
                    Text("让余额活到发薪日")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(AliveColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("把剩余金额分给此后的每一天。")
                        .font(AliveFont.sans(16, relativeTo: .body))
                        .foregroundStyle(AliveColor.inkSecondary)
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: AliveSpace.x3) {
                        FieldLabel(text: "当前剩余金额")
                        HStack(alignment: .firstTextBaseline, spacing: AliveSpace.x2) {
                            Text("¥")
                                .font(AliveFont.display(32))
                                .foregroundStyle(AliveColor.inkSecondary)
                                .accessibilityHidden(true)
                            TextField("0.00", text: $amountText)
                                .font(AliveFont.display(52))
                                .monospacedDigit()
                                .tracking(-1.5)
                                .foregroundStyle(AliveColor.ink)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.plain)
                                .focused($isAmountFocused)
                                .lineLimit(1)
                                .accessibilityLabel("当前剩余金额")
                                .accessibilityHint("最多 9 位整数和 2 位小数，必须大于 0。")
                        }
                        Rectangle()
                            .fill(AliveColor.separator)
                            .frame(height: 0.5)
                        Text("人民币 CNY")
                            .font(AliveFont.sans(12, relativeTo: .footnote))
                            .foregroundStyle(AliveColor.inkTertiary)
                    }
                }

                SurfaceCard(padding: 0) {
                    VStack(spacing: 0) {
                        dateRow(title: "下一次发薪日", selection: $payday)
                        Divider().padding(.leading, AliveSpace.x5)
                        dateRow(title: "起始日", selection: $startDate)
                    }
                }

                VStack(alignment: .leading, spacing: AliveSpace.x3) {
                    InlineError(message: errorText ?? validationMessage)
                    PrimaryAction(title: "开始", systemImage: "arrow.right", isBusy: isSubmitting) {
                        submit()
                    }
                    .disabled(!canSubmit)
                    .accessibilityHint("创建预算周期并进入今日主屏。")

                    Text("起始日默认是今天；未来的起始日会先进入待开始状态。")
                        .font(AliveFont.sans(12, relativeTo: .footnote))
                        .foregroundStyle(AliveColor.inkTertiary)
                }
            }
            .padding(.horizontal, AliveSpace.pageInset)
            .padding(.top, AliveSpace.x8)
            .padding(.bottom, AliveSpace.x10)
        }
        .background(AliveColor.canvas)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { isAmountFocused = false }
            }
        }
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                isAmountFocused = true
            }
        }
    }

    private func dateRow(title: String, selection: Binding<Date>) -> some View {
        HStack {
            Text(title)
                .font(AliveFont.sans(15, weight: .medium, relativeTo: .body))
                .foregroundStyle(AliveColor.inkSecondary)
            Spacer()
            DatePicker(title, selection: selection, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(AliveColor.accent)
        }
        .frame(minHeight: 56)
        .padding(.horizontal, AliveSpace.x5)
        .accessibilityElement(children: .contain)
    }

    private func submit() {
        guard let amountCents, canSubmit else { return }
        isAmountFocused = false
        isSubmitting = true
        errorText = nil

        Task {
            do {
                try await model.createCycle(
                    initialBalanceCents: amountCents,
                    startDate: startDate,
                    payday: payday
                )
            } catch {
                errorText = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
