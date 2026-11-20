import Foundation

/// The draft state for the button-driven quick entry inside the expanded
/// Dynamic Island. It intentionally stores only digits and a fixed note tag:
/// Live Activities cannot host a `TextField` or a keyboard.
public struct LiveEntryState: Codable, Hashable, Sendable {
    public enum Step: String, Codable, Hashable, Sendable {
        case amount
        case note
        case saved
    }

    public static let noteTags = ["🥤", "🍚", "其他"]

    /// Optional so activities created by an older build remain decodable.
    /// New drafts reuse this identity when writing their expense.
    public var draftID: UUID?
    public var step: Step
    public var amountText: String
    public var note: String?
    public var savedAmountCents: Int?
    public var savedNote: String?
    public var errorMessage: String?

    public init(
        step: Step,
        amountText: String = "",
        note: String? = nil,
        savedAmountCents: Int? = nil,
        savedNote: String? = nil,
        errorMessage: String? = nil,
        draftID: UUID? = UUID()
    ) {
        self.draftID = draftID
        self.step = step
        self.amountText = amountText
        self.note = note
        self.savedAmountCents = savedAmountCents
        self.savedNote = savedNote
        self.errorMessage = errorMessage
    }

    public var amountCents: Int? {
        MoneyParser.cents(from: amountText)
    }

    public var canAdvance: Bool {
        (amountCents ?? 0) > 0
    }

    public var displayAmountText: String {
        amountText.isEmpty ? "0.00" : amountText
    }

    public var displaySavedAmount: String {
        MoneyFormatter.currency(cents: savedAmountCents ?? 0)
    }

    /// Applies one key from the island keypad. Invalid keys are ignored so
    /// the activity never enters a state that cannot be parsed by `MoneyParser`.
    public mutating func applyKey(_ key: String) {
        guard step == .amount else { return }
        errorMessage = nil

        switch key {
        case "backspace":
            guard !amountText.isEmpty else { return }
            amountText.removeLast()
        case ".":
            guard !amountText.contains(".") else { return }
            amountText = amountText.isEmpty ? "0." : amountText + "."
        case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
            appendDigit(key)
        default:
            return
        }
    }

    /// Selects one of the three fixed note tags. The caller saves immediately;
    /// the Dynamic Island intentionally has no separate confirmation action.
    @discardableResult
    public mutating func selectNote(_ tag: String) -> Bool {
        guard step == .note else { return false }
        guard Self.noteTags.contains(tag) else { return false }
        note = tag
        errorMessage = nil
        return true
    }

    @discardableResult
    public mutating func advanceToNote() -> Bool {
        guard step == .amount, canAdvance else { return false }
        draftID = draftID ?? UUID()
        step = .note
        errorMessage = nil
        return true
    }

    public mutating func backToAmount() {
        guard step == .note else { return }
        step = .amount
        errorMessage = nil
    }

    private mutating func appendDigit(_ digit: String) {
        if let decimalIndex = amountText.firstIndex(of: ".") {
            let decimalCount = amountText.distance(from: amountText.index(after: decimalIndex), to: amountText.endIndex)
            guard decimalCount < 2 else { return }
            amountText.append(digit)
            return
        }

        let integerCount = amountText.count
        guard integerCount < 9 else { return }

        if amountText == "0" {
            amountText = digit
        } else {
            amountText.append(digit)
        }
    }
}
