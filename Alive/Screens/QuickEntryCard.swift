import AliveCore
import SwiftUI

/// The quick-entry card that unfolds from the top of the Today screen.
///
/// It is a light overlay rather than a sheet: tapping 记一笔 on the Today screen
/// drops a card from the Dynamic Island area over the dimmed Today screen. A
/// Live Activity link uses the same card inside `LiveEntryContinuityView`, which
/// hides Today and keeps the activity summary at the top. The amount is focused
/// at once; notes can be typed freely or filled from the common tags.
struct QuickEntryCard: View {
    let model: AppModel
    var fillsAvailableHeight = false

    @State private var amountText = ""
    @State private var noteText = ""
    @State private var isSaving = false
    @State private var errorText: String?
    @State private var saveSucceeded = false
    @State private var isUnfolded = false
    @FocusState private var isAmountFocused: Bool
    @FocusState private var isNoteFocused: Bool
    @AccessibilityFocusState private var isTitleFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var amountCents: Int? {
        MoneyParser.cents(from: amountText)
    }

    private var canSave: Bool {
        (amountCents ?? 0) > 0 && !isSaving
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if fillsAvailableHeight {
                ScrollView {
                    sections
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
                .frame(maxHeight: .infinity)

                Rectangle()
                    .fill(AliveColor.separator)
                    .frame(height: 0.5)
                    .padding(.horizontal, AliveSpace.x5)
            } else if dynamicTypeSize.isAccessibilitySize {
                // A greedy ScrollView would stretch the card over the keyboard.
                // Only the largest text sizes need scrolling; the card otherwise
                // stays as tall as its content.
                ScrollView {
                    sections
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollEdgeEffectStyle(.soft, for: .bottom)

                Rectangle()
                    .fill(AliveColor.separator)
                    .frame(height: 0.5)
                    .padding(.horizontal, AliveSpace.x5)
            } else {
                sections
            }

            saveButton
        }
        .background(cardBackground)
        // The unfold is a render transform, not a view transition: a field focused
        // during a transition stays first responder but never raises the keyboard.
        .scaleEffect(isUnfolded || reduceMotion ? 1 : 0.58, anchor: .top)
        .opacity(isUnfolded || reduceMotion ? 1 : 0)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { close() }
        .sensoryFeedback(.success, trigger: saveSucceeded)
        .onAppear {
            withAnimation(reduceMotion ? nil : AliveMotion.card) {
                isUnfolded = true
            }
            isTitleFocused = true
        }
        .task {
            // Wait a beat so the keyboard rises alongside the card.
            try? await Task.sleep(for: .milliseconds(380))
            guard !Task.isCancelled else { return }
            isAmountFocused = true
        }
        .onChange(of: amountText) { _, _ in
            errorText = nil
        }
        .onChange(of: noteText) { _, newValue in
            if newValue.count > 80 {
                noteText = String(newValue.prefix(80))
            }
        }
    }

    private var sections: some View {
        VStack(alignment: .leading, spacing: AliveSpace.x4) {
            amountSection
            noteSection
            timestamp
            InlineError(message: errorText ?? validationMessage)
        }
        .padding(.horizontal, AliveSpace.x5)
        .padding(.top, AliveSpace.x4)
        .padding(.bottom, AliveSpace.x2)
    }

    private var header: some View {
        VStack(spacing: AliveSpace.x2) {
            Capsule()
                .fill(AliveColor.separator)
                .frame(width: 34, height: 4)
                .padding(.top, AliveSpace.x2)
                .accessibilityHidden(true)

            HStack(alignment: .center, spacing: AliveSpace.x2) {
                Text("记一笔")
                    .font(AliveFont.sans(20, weight: .bold, relativeTo: .title3))
                    .foregroundStyle(AliveColor.ink)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($isTitleFocused)

                Spacer(minLength: AliveSpace.x2)

                ModalCloseButton(action: close)
            }
            .padding(.leading, AliveSpace.x5)
            .padding(.trailing, AliveSpace.x3)
        }
    }

    private var saveButton: some View {
        PrimaryAction(title: "保存", systemImage: "checkmark", isBusy: isSaving) {
            save()
        }
        .disabled(!canSave)
        .accessibilityHint("保存这笔支出并更新今天还可花。")
        .padding(.horizontal, AliveSpace.x5)
        .padding(.top, AliveSpace.x2)
        .padding(.bottom, AliveSpace.x4)
    }

    private var amountSection: some View {
        AmountInputRow(
            label: "支出金额",
            text: $amountText,
            fontSize: 44,
            prefixSize: 26,
            accessibilityHint: "最多 9 位整数和 2 位小数，必须大于 0。",
            focusedField: $isAmountFocused,
            focusEquals: true
        ) {
            if isAmountFocused || isNoteFocused {
                KeyboardDismissButton {
                    isAmountFocused = false
                    isNoteFocused = false
                }
            }
        }
    }

    private var noteLimitText: String {
        noteText.count >= 80 ? "已达 80 字符上限，超出部分不会保存。" : "\(noteText.count) / 80"
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: AliveSpace.x2) {
            FieldLabel(text: "备注（可选）")

            TextField("例如：午饭", text: $noteText)
                .font(AliveFont.sans(15, weight: .medium, relativeTo: .body))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($isNoteFocused)
                .padding(.horizontal, AliveSpace.x3)
                .frame(minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: AliveRadius.control, style: .continuous)
                        .fill(AliveColor.surfaceSunken)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AliveRadius.control, style: .continuous)
                        .stroke(AliveColor.separator, lineWidth: 0.5)
                }
                .accessibilityLabel("备注")
                .accessibilityHint("可选，最多 80 个字符。")

            if !noteText.isEmpty {
                HStack {
                    Spacer()
                    Text(noteLimitText)
                        .font(AliveFont.sans(12, relativeTo: .footnote))
                        .foregroundStyle(noteText.count >= 80 ? AliveColor.overspend : AliveColor.inkTertiary)
                        .monospacedDigit()
                }
            }
        }
    }

    private var timestamp: some View {
        HStack(spacing: AliveSpace.x2) {
            Image(systemName: "clock")
                .font(.system(size: 12))
                .foregroundStyle(AliveColor.accent)
                .accessibilityHidden(true)
            Text("\(AliveDateText.monthDay(Date())) \(AliveDateText.time(Date())) · 保存时自动记录")
                .font(AliveFont.sans(12, relativeTo: .caption))
                .foregroundStyle(AliveColor.inkSecondary)
            Spacer(minLength: 0)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: AliveRadius.card, style: .continuous)
            .fill(AliveColor.card)
            .overlay {
                RoundedRectangle(cornerRadius: AliveRadius.card, style: .continuous)
                    .stroke(AliveColor.separator, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.22), radius: 28, y: 14)
    }

    private func save() {
        guard let amountCents, canSave else { return }
        isAmountFocused = false
        isNoteFocused = false
        isSaving = true
        errorText = nil

        Task {
            do {
                let trimmedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                let note = trimmedNote.isEmpty ? nil : String(trimmedNote.prefix(80))
                try await model.addExpense(amountCents: amountCents, note: note)
                saveSucceeded.toggle()
                close()
            } catch {
                errorText = error.localizedDescription
            }
            isSaving = false
        }
    }

    private func close() {
        isAmountFocused = false
        isNoteFocused = false
        model.closeQuickEntry()
    }
}
