import Foundation

public enum AppRoute: String, CaseIterable, Sendable {
    case today
    case quickEntry = "quick-entry"
    case balance
    case history

    public init?(url: URL) {
        guard url.scheme?.lowercased() == "alive" else { return nil }
        let value = url.host?.lowercased() ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        self.init(rawValue: value)
    }

    public var url: URL {
        URL(string: "alive://\(rawValue)")!
    }
}
