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

    var body: some View {
        ZStack {
            OrreryBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AliveSpace.x5) {
                    SheetHeader(title: "调整当前余额") {
                        dismiss()
                    }

                    VStack(alignment: .leading, spacing: AliveSpace.x2) {
                        FieldLabel(text: "当前周期剩余总金额")
                        HStack(alignment: .firstTextBaseline, spacing: AliveSpace.x2) {
                            Text("¥")
                                .font(AliveFont.display(32))
                                .foregroundStyle(AliveColor.brass)
                            TextField("0.00", text: $balanceText)
                                .font(AliveFont.display(50))
                                .monospacedDigit()
                                .tracking(-2)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.plain)
                                .foregroundStyle(AliveColor.ink)
                                .focused($isFocused)
                                .accessibilityLabel("当前余额")
                        }
                        BrassRule()
                    }

                    Text("保存后会立即重算今天还可花，并保留一条余额修正记录。今天已记录的支出不会再次扣减。")
                        .font(AliveFont.sans(14, relativeTo: .subheadline))
                        .lineSpacing(6)
                        .foregroundStyle(AliveColor.inkSecondary)

                    if let snapshot = model.snapshot {
                        HStack {
                            Text("剩余天数")
                            Spacer()
                            Text("\(snapshot.daysRemaining) 天")
                                .monospacedDigit()
                        }
                        .font(AliveFont.sans(14, weight: .medium, relativeTo: .subheadline))
                        .foregroundStyle(AliveColor.inkSecondary)
                        .padding(.vertical, AliveSpace.x3)
                        .overlay(alignment: .top) { BrassRule(subtle: true) }
                        .overlay(alignment: .bottom) { BrassRule(subtle: true) }
                    }

                    InlineError(message: errorText)

                    PrimaryAction(
                        title: "保存",
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
                    isFocused = false
                }
            }
        }
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                isFocused = true
            }
        }
        .sensoryFeedback(.success, trigger: saveSucceeded)
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
