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
        if !amountText.isEmpty, (amountCents ?? 0) <= 0 {
            return "请输入大于 0 的金额。"
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
        ZStack {
            OrreryBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AliveSpace.x6) {
                    brandHeader

                    VStack(alignment: .leading, spacing: AliveSpace.x2) {
                        Text("让余额活到发薪日")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(AliveColor.ink)
                        Text("把剩余金额分给此后的每一天。")
                            .font(AliveFont.sans(16, relativeTo: .body))
                            .lineSpacing(7)
                            .foregroundStyle(AliveColor.inkSecondary)
                    }

                    amountSection
                    dateSection

                    VStack(alignment: .leading, spacing: AliveSpace.x3) {
                        InlineError(message: errorText ?? validationMessage)
                        PrimaryAction(
                            title: "开始",
                            systemImage: "sparkle",
                            isBusy: isSubmitting
                        ) {
                            submit()
                        }
                        .disabled(!canSubmit)
                        .opacity(canSubmit ? 1 : 0.44)

                        Text("起始日默认是今天；未来的起始日会先进入待开始状态。")
                            .font(AliveFont.sans(12, relativeTo: .caption))
                            .foregroundStyle(AliveColor.inkTertiary)
                            .lineSpacing(4)
                    }
                }
                .padding(.horizontal, AliveSpace.pageInset)
                .padding(.top, AliveSpace.x5)
                .padding(.bottom, AliveSpace.x8)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    isAmountFocused = false
                }
            }
        }
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                isAmountFocused = true
            }
        }
    }

    private var brandHeader: some View {
        HStack(spacing: AliveSpace.x2) {
            OrnamentalRingMark()
            Text("ALIVE")
                .font(AliveFont.sans(15, weight: .semibold, relativeTo: .headline))
                .tracking(3.2)
                .foregroundStyle(AliveColor.ink)
            Spacer()
        }
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: AliveSpace.x2) {
            FieldLabel(text: "当前剩余金额")
            HStack(alignment: .firstTextBaseline, spacing: AliveSpace.x2) {
                Text("¥")
                    .font(AliveFont.display(34))
                    .foregroundStyle(AliveColor.brass)
                TextField("0.00", text: $amountText)
                    .font(AliveFont.display(54))
                    .monospacedDigit()
                    .tracking(-2)
                    .foregroundStyle(AliveColor.ink)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .focused($isAmountFocused)
                    .accessibilityLabel("当前剩余金额")
            }
            BrassRule()
            Text("人民币 CNY")
                .font(AliveFont.sans(11, weight: .medium, relativeTo: .caption2))
                .tracking(1.2)
                .foregroundStyle(AliveColor.inkTertiary)
        }
    }

    private var dateSection: some View {
        VStack(spacing: 0) {
            dateRow(title: "下一次发薪日", selection: $payday)
            BrassRule(subtle: true)
            dateRow(title: "起始日", selection: $startDate)
            BrassRule(subtle: true)
        }
    }

    private func dateRow(title: String, selection: Binding<Date>) -> some View {
        HStack {
            Text(title)
                .font(AliveFont.sans(15, weight: .medium, relativeTo: .body))
                .foregroundStyle(AliveColor.inkSecondary)
            Spacer()
            DatePicker(
                title,
                selection: selection,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(AliveColor.ink)
        }
        .frame(minHeight: 54)
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
