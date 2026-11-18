import AliveCore
import SwiftUI

struct QuickExpenseSheet: View {
    let model: AppModel
    let expense: Expense?

    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String
    @State private var note: String
    @State private var isSaving = false
    @State private var errorText: String?
    @State private var saveSucceeded = false
    @FocusState private var isAmountFocused: Bool

    init(model: AppModel, expense: Expense?) {
        self.model = model
        self.expense = expense
        _amountText = State(initialValue: expense.map { MoneyFormatter.editText(cents: $0.amountCents) } ?? "")
        _note = State(initialValue: expense?.note ?? "")
    }

    private var amountCents: Int? {
        MoneyParser.cents(from: amountText)
    }

    private var canSave: Bool {
        (amountCents ?? 0) > 0 && !isSaving
    }

    private var isEditing: Bool {
        expense != nil
    }

    private var validationMessage: String? {
        let trimmed = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let cents = MoneyParser.cents(from: trimmed) else {
            return "请输入有效金额，最多 9 位整数和 2 位小数。"
        }
        if cents == 0 {
            return "支出金额必须大于 0。"
        }
        return nil
    }

    private var noteLimitText: String {
        note.count >= 80 ? "已达 80 字符上限，超出部分不会保存。" : "\(note.count) / 80"
    }

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: AliveSpace.x5) {
                    SheetHeader(title: isEditing ? "编辑支出" : "记一笔") {
                        dismiss()
                    }

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: AliveSpace.x3) {
                            FieldLabel(text: "支出金额")
                            HStack(alignment: .firstTextBaseline, spacing: AliveSpace.x2) {
                                Text("¥")
                                    .font(AliveFont.display(32))
                                    .foregroundStyle(AliveColor.inkSecondary)
                                    .accessibilityHidden(true)
                                TextField("0.00", text: $amountText)
                                    .font(AliveFont.display(52))
                                    .monospacedDigit()
                                    .tracking(-1.5)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(AliveColor.ink)
                                    .focused($isAmountFocused)
                                    .lineLimit(1)
                                    .accessibilityLabel("支出金额")
                                    .accessibilityHint("最多 9 位整数和 2 位小数，必须大于 0。")
                                    .accessibilitySortPriority(2)
                            }
                            Rectangle().fill(AliveColor.separator).frame(height: 0.5)
                        }
                    }

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: AliveSpace.x3) {
                            FieldLabel(text: "备注（可选）")
                            TextField("午饭、咖啡、超市…", text: $note)
                                .font(AliveFont.sans(16, relativeTo: .body))
                                .foregroundStyle(AliveColor.ink)
                                .textFieldStyle(.plain)
                                .submitLabel(.done)
                                .accessibilityLabel("备注，可选")
                                .accessibilityHint("最多 80 个字符。")
                                .accessibilitySortPriority(1)
                                .onChange(of: note) { _, value in
                                    if value.count > 80 {
                                        note = String(value.prefix(80))
                                    }
                                }
                            Rectangle().fill(AliveColor.separator).frame(height: 0.5)
                            Text(noteLimitText)
                                .font(AliveFont.sans(12, relativeTo: .footnote))
                                .foregroundStyle(AliveColor.inkTertiary)
                                .monospacedDigit()
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }

                    HStack(spacing: AliveSpace.x2) {
                        Image(systemName: "clock")
                            .font(.system(size: 13))
                            .foregroundStyle(AliveColor.accent)
                            .accessibilityHidden(true)
                        Text(timestampText)
                            .font(AliveFont.sans(12, relativeTo: .caption))
                            .foregroundStyle(AliveColor.inkSecondary)
                        Spacer()
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
                    title: isEditing ? "保存修改" : "保存",
                    systemImage: "checkmark",
                    isProminent: true,
                    isBusy: isSaving,
                    accessibilityHint: isEditing ? "保存对这笔支出的修改。" : "保存这笔支出并更新今天还可花。"
                ) {
                    save()
                }
                .disabled(!canSave)
            }
        }

        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
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
        .onChange(of: amountText) { _, _ in
            errorText = nil
        }
        .sensoryFeedback(.success, trigger: saveSucceeded)
    }

    private var timestampText: String {
        guard let expense else {
            return "\(AliveDateText.monthDay(Date())) \(AliveDateText.time(Date())) · 保存时自动记录"
        }
        return "\(AliveDateText.monthDay(expense.occurredAt)) \(AliveDateText.time(expense.occurredAt)) · 自动记录"
    }

    private func save() {
        guard let amountCents, canSave else { return }
        isAmountFocused = false
        isSaving = true
        errorText = nil

        Task {
            do {
                if let expense {
                    try await model.updateExpense(
                        id: expense.id,
                        amountCents: amountCents,
                        note: note
                    )
                } else {
                    try await model.addExpense(amountCents: amountCents, note: note)
                }
                saveSucceeded.toggle()
                dismiss()
            } catch {
                errorText = error.localizedDescription
            }
            isSaving = false
        }
    }
}
