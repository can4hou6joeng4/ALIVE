import AliveCore
import SwiftUI

enum IslandEntryMetrics {
    static let actionHeight: CGFloat = 26
    static let headerActionHeight: CGFloat = 22
    static let sectionSpacing: CGFloat = 4
    static let rowSpacing: CGFloat = 4
    static let keySpacing: CGFloat = 6
    static let amountPanelWidth: CGFloat = 120
    static let amountPanelSpacing: CGFloat = 10
    static let utilityActionSize: CGFloat = 26
    static let keyHeight: CGFloat = 32
    static let amountPanelHeight = keyHeight * 2 + rowSpacing
    static let amountCardHeight = amountPanelHeight + rowSpacing + utilityActionSize
    static let noteTagHeight: CGFloat = 40
    static let horizontalInset: CGFloat = 6
    static let bottomSafetyInset: CGFloat = 8
    // Reserve space in the system container as well as inside the card. The
    // renderer can clip button backgrounds even when their AX frames are intact.
    static let expandedBottomMargin: CGFloat = 12
}

struct LiveEntryIslandCard: View {
    let cycleID: String
    let liveEntry: LiveEntryState

    var body: some View {
        Group {
            switch liveEntry.step {
            case .amount:
                LiveEntryIslandAmountStep(cycleID: cycleID, liveEntry: liveEntry)
            case .note, .saved:
                VStack(spacing: IslandEntryMetrics.sectionSpacing) {
                    HStack(alignment: .center, spacing: 10) {
                        LiveEntryIslandHeader(liveEntry: liveEntry)
                        Spacer(minLength: 8)
                        LiveEntryIslandTrailing(cycleID: cycleID, liveEntry: liveEntry)
                    }
                    .frame(height: IslandEntryMetrics.headerActionHeight)
                    .padding(.horizontal, IslandEntryMetrics.horizontalInset)

                    LiveEntryIslandBottom(cycleID: cycleID, liveEntry: liveEntry)
                }
            }
        }
        .padding(.bottom, IslandEntryMetrics.bottomSafetyInset)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("live-entry-island")
    }
}

private struct LiveEntryIslandAmountStep: View {
    let cycleID: String
    let liveEntry: LiveEntryState

    var body: some View {
        HStack(alignment: .top, spacing: IslandEntryMetrics.amountPanelSpacing) {
            VStack(alignment: .leading, spacing: 0) {
                Text("支出金额")
                    .font(WidgetFont.sans(10, weight: .semibold))
                    .foregroundStyle(liveEntry.errorMessage == nil ? WidgetColor.islandInkMuted : WidgetColor.islandOverspend)
                    .lineLimit(1)
                    .frame(height: 12)
                    .accessibilityHidden(true)

                Text("¥\(liveEntry.displayAmountText)")
                    .font(WidgetFont.display(22))
                    .monospacedDigit()
                    .foregroundStyle(WidgetColor.islandInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .accessibilityLabel("支出金额 \(liveEntry.displayAmountText) 元")
                    .frame(height: 28)
                    .contentTransition(.numericText())

                Spacer(minLength: 0)
            }
            .frame(width: IslandEntryMetrics.amountPanelWidth, alignment: .leading)
            .frame(height: IslandEntryMetrics.amountPanelHeight)

            VStack(spacing: IslandEntryMetrics.rowSpacing) {
                keyRow(["1", "2", "3", "4", "5"], isTopRow: true)
                keyRow(["6", "7", "8", "9", "0"], isTopRow: false)
                actionRow
            }
        }
        .padding(.horizontal, IslandEntryMetrics.horizontalInset)
        .frame(height: IslandEntryMetrics.amountCardHeight)
    }

    private func keyRow(_ keys: [String], isTopRow: Bool) -> some View {
        HStack(spacing: IslandEntryMetrics.keySpacing) {
            ForEach(keys, id: \.self) { key in
                LiveEntryKeyButton(
                    cycleID: cycleID,
                    key: key,
                    isOuterTopCorner: isTopRow && key == keys.last,
                    isOuterBottomCorner: !isTopRow && key == keys.last
                )
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: IslandEntryMetrics.keySpacing) {
            LiveEntryBackspaceButton(cycleID: cycleID)

            Button(intent: LiveEntryAdvanceIntent(cycleID: cycleID)) {
                IslandActionLabel(
                    title: "下一步",
                    style: liveEntry.canAdvance ? .primary : .inactive,
                    height: IslandEntryMetrics.utilityActionSize,
                    fontSize: 12
                )
            }
            .buttonStyle(IslandControlButtonStyle())
            .disabled(!liveEntry.canAdvance)
            .accessibilityIdentifier("live-entry-next")
            .accessibilityHint("进入备注标签选择。")
        }
        .frame(height: IslandEntryMetrics.utilityActionSize)
    }
}

struct LiveEntryIslandHeader: View {
    let liveEntry: LiveEntryState

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(WidgetFont.sans(10, weight: .semibold))
                .foregroundStyle(liveEntry.errorMessage == nil ? WidgetColor.islandInkMuted : WidgetColor.islandOverspend)
                .lineLimit(1)

            Text(amount)
                .font(WidgetFont.display(16))
                .monospacedDigit()
                .foregroundStyle(WidgetColor.islandInk)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var title: String {
        switch liveEntry.step {
        case .amount:
            "支出金额"
        case .note:
            liveEntry.errorMessage ?? "选择备注即记账"
        case .saved:
            "已记一笔"
        }
    }

    private var amount: String {
        switch liveEntry.step {
        case .amount: "¥\(liveEntry.displayAmountText)"
        case .note: MoneyFormatter.currency(cents: liveEntry.amountCents ?? 0)
        case .saved: liveEntry.displaySavedAmount
        }
    }

    private var accessibilitySummary: String {
        switch liveEntry.step {
        case .amount:
            "支出金额 \(liveEntry.displayAmountText) 元"
        case .note:
            "支出金额 \(liveEntry.displayAmountText) 元，\(liveEntry.errorMessage ?? "备注可选")"
        case .saved:
            "已记一笔 \(MoneyFormatter.spoken(cents: Decimal(liveEntry.savedAmountCents ?? 0)))"
        }
    }
}

struct LiveEntryIslandTrailing: View {
    let cycleID: String
    let liveEntry: LiveEntryState

    var body: some View {
        switch liveEntry.step {
        case .amount, .note:
            EmptyView()
        case .saved:
            if let note = liveEntry.savedNote {
                Text(note)
                    .font(WidgetFont.sans(12, weight: .medium))
                    .foregroundStyle(WidgetColor.islandInkSecondary)
                    .lineLimit(1)
                    .frame(height: IslandEntryMetrics.actionHeight)
                    .accessibilityLabel("备注 \(note)")
            }
        }
    }
}

struct LiveEntryIslandBottom: View {
    let cycleID: String
    let liveEntry: LiveEntryState

    var body: some View {
        Group {
            switch liveEntry.step {
            case .amount:
                EmptyView()
            case .note:
                HStack(spacing: IslandEntryMetrics.keySpacing) {
                    ForEach(LiveEntryState.noteTags, id: \.self) { tag in
                        LiveEntryNoteButton(
                            cycleID: cycleID,
                            draftID: liveEntry.draftID?.uuidString ?? "",
                            tag: tag
                        )
                    }
                }
            case .saved:
                HStack(spacing: IslandEntryMetrics.keySpacing) {
                    Button(intent: BeginLiveEntryIntent(cycleID: cycleID)) {
                        IslandActionLabel(title: "再记一笔", style: .secondary)
                    }
                    .buttonStyle(IslandControlButtonStyle())
                    .accessibilityIdentifier("live-entry-again")

                    Button(intent: LiveEntryCancelIntent(cycleID: cycleID)) {
                        IslandActionLabel(title: "完成", style: .primary)
                    }
                    .buttonStyle(IslandControlButtonStyle())
                    .accessibilityIdentifier("live-entry-done")
                }
            }
        }
        .padding(.horizontal, IslandEntryMetrics.horizontalInset)
    }
}

private struct LiveEntryBackspaceButton: View {
    let cycleID: String

    var body: some View {
        Button(intent: LiveEntryKeyIntent(cycleID: cycleID, key: "backspace")) {
            Image(systemName: "delete.left")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(WidgetColor.islandInk)
            .frame(
                width: IslandEntryMetrics.utilityActionSize,
                height: IslandEntryMetrics.utilityActionSize
            )
            .background {
                Capsule()
                    .fill(WidgetColor.islandInk.opacity(0.12))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(IslandControlButtonStyle())
        .accessibilityLabel("退格")
        .accessibilityIdentifier("live-entry-backspace")
    }
}

private struct IslandActionLabel: View {
    enum Style {
        case primary, secondary, inactive
    }

    let title: String
    let style: Style
    var height: CGFloat = IslandEntryMetrics.actionHeight
    var fontSize: CGFloat = 13

    private var ink: Color {
        switch style {
        case .primary: .black
        case .secondary: WidgetColor.islandInk
        case .inactive: WidgetColor.islandInkMuted
        }
    }

    var body: some View {
        Text(title)
            .font(WidgetFont.sans(fontSize, weight: .semibold))
            .foregroundStyle(ink)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background {
                Capsule()
                    .fill(style == .primary ? WidgetColor.islandActionFill : WidgetColor.islandInk.opacity(0.12))
            }
            .contentShape(Rectangle())
    }
}

private struct LiveEntryKeyButton: View {
    let cycleID: String
    let key: String
    var isOuterTopCorner = false
    var isOuterBottomCorner = false

    private var keyShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 8,
            bottomLeadingRadius: 8,
            bottomTrailingRadius: isOuterBottomCorner ? 20 : 8,
            topTrailingRadius: isOuterTopCorner ? 20 : 8,
            style: .continuous
        )
    }

    var body: some View {
        Button(intent: LiveEntryKeyIntent(cycleID: cycleID, key: key)) {
            Text(key)
            .font(WidgetFont.display(18))
            .monospacedDigit()
            .foregroundStyle(WidgetColor.islandInk)
            .frame(maxWidth: .infinity)
            .frame(height: IslandEntryMetrics.keyHeight)
            .background {
                keyShape
                    .fill(WidgetColor.islandInk.opacity(0.14))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(IslandControlButtonStyle())
        .accessibilityLabel(key)
        .accessibilityIdentifier("live-entry-key-\(key)")
    }
}

private struct LiveEntryNoteButton: View {
    let cycleID: String
    let draftID: String
    let tag: String

    private var semanticNote: String {
        switch tag {
        case "🥤": "饮品"
        case "🍚": "餐饭"
        default: "其他"
        }
    }

    var body: some View {
        Button(intent: LiveEntryNoteIntent(cycleID: cycleID, note: tag, draftID: draftID)) {
            Text(tag)
                .font(WidgetFont.sans(tag == "其他" ? 15 : 23, weight: .semibold))
                .foregroundStyle(WidgetColor.islandInk)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .frame(height: IslandEntryMetrics.noteTagHeight)
                .background {
                    Capsule()
                        .fill(WidgetColor.islandInk.opacity(0.14))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(IslandControlButtonStyle())
        .accessibilityLabel(semanticNote)
        .accessibilityIdentifier("live-entry-tag-\(tag)")
        .accessibilityHint("立即保存这笔支出，并记录该备注。")
    }
}

struct IslandControlButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
