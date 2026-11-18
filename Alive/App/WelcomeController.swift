import AliveCore
import Foundation

/// Welcome playback is a one-time UI preference, kept separate from budget state.
enum WelcomeController {
    private static let suiteName = BudgetSnapshotStore.appGroupID
    private static let hasSeenKey = "hasSeenWelcome"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    static var shouldShow: Bool {
        defaults?.bool(forKey: hasSeenKey) != true
    }

    static func markSeen() {
        defaults?.set(true, forKey: hasSeenKey)
    }
}
