import AliveCore
import AppIntents

struct OpenQuickEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "记一笔"

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(AppRoute.quickEntry.url))
    }
}

struct OpenBalanceIntent: AppIntent {
    static let title: LocalizedStringResource = "调余额"

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(AppRoute.balance.url))
    }
}
