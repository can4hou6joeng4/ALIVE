import Foundation

public enum PendingAppRouteStore {
    private static let suiteName = BudgetSnapshotStore.appGroupID
    private static let key = "pendingAppRoute"

    public static func store(_ route: AppRoute) {
        UserDefaults(suiteName: suiteName)?.set(route.rawValue, forKey: key)
    }

    public static func consume() -> AppRoute? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let rawValue = defaults.string(forKey: key) else {
            return nil
        }
        defaults.removeObject(forKey: key)
        return AppRoute(rawValue: rawValue)
    }
}
