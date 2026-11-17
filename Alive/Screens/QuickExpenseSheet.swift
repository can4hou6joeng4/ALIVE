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

    var body: some View {
        ZStack {
            OrreryBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AliveSpace.x5) {
                    SheetHeader(title: isEditing ? "编辑支出" : "记一笔") {
                        dismiss()
                    }

                    VStack(alignment: .leading, spacing: AliveSpace.x2) {
                        FieldLabel(text: "支出金额")
                        HStack(alignment: .firstTextBaseline, spacing: AliveSpace.x2) {
                            Text("¥")
                                .font(AliveFont.display(32))
                                .foregroundStyle(AliveColor.brass)
                            TextField("0.00", text: $amountText)
                                .font(AliveFont.display(52))
                                .monospacedDigit()
                                .tracking(-2)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.plain)
                                .foregroundStyle(AliveColor.ink)
                                .focused($isAmountFocused)
                                .accessibilityLabel("支出金额")
                        }
                        BrassRule()
                    }

                    VStack(alignment: .leading, spacing: AliveSpace.x2) {
                        FieldLabel(text: "备注（可选）")
                        TextField("午饭、咖啡、超市…", text: $note)
                            .font(AliveFont.sans(16, relativeTo: .body))
                            .foregroundStyle(AliveColor.ink)
                            .textFieldStyle(.plain)
                            .submitLabel(.done)
                            .onChange(of: note) { _, value in
                                if value.count > 80 {
                                    note = String(value.prefix(80))
                                }
                            }
                        BrassRule()
                        Text("\(note.count) / 80")
                            .font(AliveFont.sans(11, relativeTo: .caption2))
                            .foregroundStyle(AliveColor.inkTertiary)
                            .monospacedDigit()
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    HStack(spacing: AliveSpace.x2) {
                        Image(systemName: "clock")
                            .font(.system(size: 13))
                            .foregroundStyle(AliveColor.brass)
                        Text(timestampText)
                            .font(AliveFont.sans(12, relativeTo: .caption))
                            .foregroundStyle(AliveColor.inkSecondary)
                        Spacer()
                    }

                    InlineError(message: errorText)

                    PrimaryAction(
                        title: isEditing ? "保存修改" : "保存",
                        systemImage: "checkmark",
                        isBusy: isSaving
                    ) {
                        save()
                    }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.44)
                }
                .padding(.horizontal, AliveSpace.pageInset)
                .padding(.top, AliveSpace.x3)
                .padding(.bottom, AliveSpace.x8)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .presentationBackground(AliveColor.canvas)
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
