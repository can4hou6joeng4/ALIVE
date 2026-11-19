import AliveCore
import SwiftUI

struct BalanceSheet: View {
    let model: AppModel

    @Environment(\.dismiss) private var dismiss
    @State private var balanceText: String
    @State private var isSaving = false
    @State private var errorText: String?
    @State private var saveSucceeded = false
    @FocusState private var isFocused: Bool

    init(model: AppModel) {
        self.model = model
        _balanceText = State(
            initialValue: model.snapshot.map { MoneyFormatter.editText(cents: $0.currentBalanceCents) } ?? ""
        )
    }

    private var balanceCents: Int? {
        MoneyParser.cents(from: balanceText, allowNegative: true)
    }

    private var canSave: Bool {
        balanceCents != nil && !isSaving
    }

    private var isNegativeInput: Bool {
        balanceText.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("-")
    }

    private var validationMessage: String? {
        let trimmed = balanceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard MoneyParser.cents(from: trimmed, allowNegative: true) != nil else {
            return "请输入有效余额，支持负值，最多 9 位整数和 2 位小数。"
        }
        return nil
    }

    private var balanceNote: String? {
        guard let balanceCents else { return nil }
        if balanceCents < 0 {
            return "负余额会保留在修正记录中，今日额度按 0 计算。"
        }
        if balanceCents == 0 {
            return "余额为 0 时，今天还可花会变为 ¥0.00，且今日额度不可用。"
        }
        return nil
    }

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: AliveSpace.x5) {
                    SheetHeader(title: "调整当前余额") {
                        dismiss()
                    }

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: AliveSpace.x3) {
                            FieldLabel(text: "当前周期剩余总金额")
                            HStack(alignment: .center, spacing: AliveSpace.x2) {
                                HStack(alignment: .firstTextBaseline, spacing: AliveSpace.x2) {
                                    Text("¥")
                                        .font(AliveFont.display(32))
                                        .foregroundStyle(AliveColor.inkSecondary)
                                        .accessibilityHidden(true)
                                    TextField("0.00", text: $balanceText)
                                        .font(AliveFont.display(50))
                                        .monospacedDigit()
                                        .tracking(-1.5)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.plain)
                                        .foregroundStyle(AliveColor.ink)
                                        .focused($isFocused)
                                        .lineLimit(1)
                                        .minimumScaleFactor(AliveFont.amountFieldMinimumScale)
                                        .accessibilityLabel("当前周期剩余总金额")
                                        .accessibilityHint("支持负值；输入负余额时今日额度按 0 计算。")
                                        .accessibilitySortPriority(2)
                                }
                                GlassIconButton(
                                    systemName: "plus.forwardslash.minus",
                                    accessibilityLabel: "切换余额正负",
                                    accessibilityValue: isNegativeInput ? "当前为负值" : "当前为正值"
                                ) {
                                    toggleSign()
                                }
                            }
                            Rectangle().fill(AliveColor.separator).frame(height: 0.5)
                        }
                    }

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: AliveSpace.x3) {
                            if let balanceNote {
                                Text(balanceNote)
                                    .font(AliveFont.sans(13, relativeTo: .footnote))
                                    .foregroundStyle(AliveColor.inkTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Text("保存后会立即重算今天还可花，并保留一条余额修正记录。今天已记录的支出不会再次扣减。")
                                .font(AliveFont.sans(14, relativeTo: .subheadline))
                                .foregroundStyle(AliveColor.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            if let snapshot = model.snapshot {
                                HStack {
                                    Text("剩余天数")
                                    Spacer()
                                    Text("\(snapshot.daysRemaining) 天").monospacedDigit()
                                }
                                .font(AliveFont.sans(14, weight: .medium, relativeTo: .subheadline))
                                .foregroundStyle(AliveColor.inkSecondary)
                            }
                        }
                    }

                    InlineError(message: errorText ?? validationMessage)
                }
                .padding(.horizontal, AliveSpace.pageInset)
                .padding(.top, AliveSpace.x3)
                .padding(.bottom, AliveSpace.x4)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AliveColor.canvas)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GlassActionBar {
                GlassActionButton(
                    title: "保存",
                    systemImage: "checkmark",
                    isProminent: true,
                    isBusy: isSaving,
                    accessibilityHint: "保存余额并重算今天还可花。"
                ) {
                    save()
                }
                .disabled(!canSave)

                if isFocused {
                    KeyboardDismissButton {
                        isFocused = false
                    }
                }
            }
        }

        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                isFocused = true
            }
        }
        .onChange(of: balanceText) { _, _ in
            errorText = nil
        }
        .sensoryFeedback(.success, trigger: saveSucceeded)
    }

    private func toggleSign() {
        if balanceText.hasPrefix("-") {
            balanceText.removeFirst()
        } else {
            balanceText = "-\(balanceText)"
        }
    }

    private func save() {
        guard let balanceCents, canSave else { return }
        isFocused = false
        isSaving = true
        errorText = nil

        Task {
            do {
                try await model.overrideBalance(cents: balanceCents)
                saveSucceeded.toggle()
                dismiss()
            } catch {
                errorText = error.localizedDescription
            }
            isSaving = false
        }
    }
}
