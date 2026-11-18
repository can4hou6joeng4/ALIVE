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
        sampleEntry(at: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetWidgetEntry) -> Void) {
        if context.isPreview {
            completion(sampleEntry(at: Date()))
            return
        }
        let document = try? BudgetSnapshotStore.appGroup().read()
        completion(BudgetWidgetEntry(date: Date(), document: document))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetWidgetEntry>) -> Void) {
        let now = Date()
        let document = try? BudgetSnapshotStore.appGroup().read()
        let nextMidnight = calendar.nextMidnight(after: now)
        let refreshDate = max(nextMidnight, document?.nextRefresh ?? nextMidnight)

        // The widget view projects the snapshot at the timeline entry date rather than
        // at render time, so every entry stays internally consistent. Limitation:
        // WidgetKit may still render an older entry after midnight if it delays the
        // next timeline request; `.after(refreshDate)` is a hint, not a guarantee.
        let entries = [
            BudgetWidgetEntry(date: now, document: document),
            BudgetWidgetEntry(date: nextMidnight, document: document)
        ]
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }

    /// Gallery / placeholder sample so adding the widget never starts on an empty card.
    private func sampleEntry(at date: Date) -> BudgetWidgetEntry {
        let start = calendar.startOfDay(date)
        let payday = calendar.calendar.date(byAdding: .day, value: 14, to: start) ?? start
        let snapshot = BudgetSnapshot(
            cycleID: UUID(),
            phase: .active,
            todayBudgetCents: 4_280,
            todayAvailableCents: 3_125,
            todaySpentCents: 1_155,
            currentBalanceCents: 105_000,
            daysRemaining: 14,
            startDate: start,
            payday: payday,
            paydayAnchorDay: calendar.anchorDay(for: payday),
            needsBalanceReview: false,
            generatedAt: date
        )
        return BudgetWidgetEntry(
            date: date,
            document: BudgetSnapshotDocument(
                snapshot: snapshot,
                nextRefresh: calendar.nextMidnight(after: date)
            )
        )
    }
}
