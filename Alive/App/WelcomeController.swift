import Foundation

/// Welcome playback is a one-time UI preference, kept separate from budget state.
enum WelcomeController {
    private static let hasSeenKey = "hasSeenWelcome"

    static var shouldShow: Bool {
        !UserDefaults.standard.bool(forKey: hasSeenKey)
    }

    static func markSeen() {
        UserDefaults.standard.set(true, forKey: hasSeenKey)
    }
}
