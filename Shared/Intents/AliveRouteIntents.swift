import AliveCore
import AppIntents

struct OpenQuickEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "记一笔"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        PendingAppRouteStore.store(.quickEntry)
        return .result()
    }
}

struct OpenBalanceIntent: AppIntent {
    static let title: LocalizedStringResource = "调余额"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        PendingAppRouteStore.store(.balance)
        return .result()
    }
}
