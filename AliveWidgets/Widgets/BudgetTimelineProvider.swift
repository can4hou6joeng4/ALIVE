import AliveCore
import Foundation
import WidgetKit

struct BudgetWidgetEntry: TimelineEntry {
    let date: Date
    let document: BudgetSnapshotDocument?
}

struct BudgetTimelineProvider: TimelineProvider {
    private let calendar = BudgetCalendar()

    func placeholder(in context: Context) -> BudgetWidgetEntry {
        BudgetWidgetEntry(date: Date(), document: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetWidgetEntry) -> Void) {
        let document = try? BudgetSnapshotStore.appGroup().read()
        completion(BudgetWidgetEntry(date: Date(), document: document))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetWidgetEntry>) -> Void) {
        let now = Date()
        let document = try? BudgetSnapshotStore.appGroup().read()
        let nextMidnight = calendar.nextMidnight(after: now)
        let refreshDate = document.map { max(nextMidnight, $0.nextRefresh) } ?? nextMidnight
        let entries = [
            BudgetWidgetEntry(date: now, document: document),
            BudgetWidgetEntry(
                date: min(refreshDate, nextMidnight),
                document: document
            )
        ]
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }
}
