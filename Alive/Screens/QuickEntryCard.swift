import AliveCore
import SwiftUI

/// The quick-entry card that unfolds from the top of the Today screen.
///
/// It is a light overlay rather than a sheet: tapping 记一笔 in the Live
/// Activity (or on the Today screen) drops a card from the Dynamic Island area,
/// the amount is focused at once, and the Today screen stays visible behind it.
/// Quick notes come from fixed tags; free-text notes remain in the edit form.
struct QuickEntryCard: View {
    let model: AppModel

    static let noteTags = ["午饭", "咖啡", "超市", "交通"]

    @State private var amountText = ""
    @State private var selectedTag: String?
    @State private var isSaving = false
    @State private var errorText: String?
    @State private var saveSucceeded = false
    @State private var isUnfolded = false
    @FocusState private var isAmountFocused: Bool
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

            if dynamicTypeSize.isAccessibilitySize {
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

            PrimaryAction(title: "保存", systemImage: "checkmark", isBusy: isSaving) {
                save()
            }
            .disabled(!canSave)
            .accessibilityHint("保存这笔支出并更新今天还可花。")
            .padding(.horizontal, AliveSpace.x5)
            .padding(.top, AliveSpace.x2)
            .padding(.bottom, AliveSpace.x4)
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
            Task { @MainActor in
                // Wait a beat so the keyboard rises alongside the card.
                try? await Task.sleep(for: .milliseconds(380))
                isAmountFocused = true
            }
        }
        .onChange(of: amountText) { _, _ in
            errorText = nil
        }
    }

    private var sections: some View {
        VStack(alignment: .leading, spacing: AliveSpace.x4) {
            amountSection
            tagSection
            timestamp
            InlineError(message: errorText ?? validationMessage)
        }
        .padding(.horizontal, AliveSpace.x5)
        .padding(.top, AliveSpace.x4)
        .padding(.bottom, AliveSpace.x2)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: AliveSpace.x2) {
            Text("记一笔")
                .font(AliveFont.sans(20, weight: .bold, relativeTo: .title3))
                .foregroundStyle(AliveColor.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($isTitleFocused)

            Spacer(minLength: AliveSpace.x2)

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(AliveColor.ink)
            .accessibilityLabel("关闭")
        }
        .padding(.leading, AliveSpace.x5)
        .padding(.trailing, AliveSpace.x3)
        .padding(.top, AliveSpace.x3)
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: AliveSpace.x2) {
            FieldLabel(text: "支出金额")
            HStack(alignment: .firstTextBaseline, spacing: AliveSpace.x2) {
                Text("¥")
                    .font(AliveFont.display(26))
                    .foregroundStyle(AliveColor.inkSecondary)
                    .accessibilityHidden(true)
                TextField("0.00", text: $amountText)
                    .font(AliveFont.display(44))
                    .monospacedDigit()
                    .tracking(-1.2)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AliveColor.ink)
                    .focused($isAmountFocused)
                    .lineLimit(1)
                    .minimumScaleFactor(AliveFont.amountFieldMinimumScale)
                    .accessibilityLabel("支出金额")
                    .accessibilityHint("最多 9 位整数和 2 位小数，必须大于 0。")
                    .accessibilitySortPriority(2)
            }
            Rectangle().fill(AliveColor.separator).frame(height: 0.5)
        }
    }

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: AliveSpace.x2) {
            Text("备注")
                .font(AliveFont.sans(13, weight: .semibold, relativeTo: .footnote))
                .foregroundStyle(AliveColor.inkSecondary)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: AliveSpace.x2),
                    count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
                ),
                alignment: .leading,
                spacing: AliveSpace.x2
            ) {
                ForEach(Self.noteTags, id: \.self) { tag in
                    tagChip(tag)
                }
            }
        }
    }

    private func tagChip(_ tag: String) -> some View {
        let isSelected = selectedTag == tag
        return Button {
            selectedTag = isSelected ? nil : tag
        } label: {
            HStack(spacing: AliveSpace.x1) {
                if isSelected {
                    // Selection must not rely on color alone.
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .accessibilityHidden(true)
                }
                Text(tag)
                    .font(AliveFont.sans(15, weight: .medium, relativeTo: .subheadline))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Color.white : AliveColor.ink)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AliveSpace.x3)
            .frame(minHeight: 44)
            .background(
                Capsule().fill(isSelected ? AliveColor.accentFill : AliveColor.surfaceSunken)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tag)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "再点一次取消备注。" : "把备注设为\(tag)。")
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
        isSaving = true
        errorText = nil

        Task {
            do {
                try await model.addExpense(amountCents: amountCents, note: selectedTag)
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
        model.closeQuickEntry()
    }
}
