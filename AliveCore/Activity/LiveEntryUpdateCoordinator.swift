import Foundation

public actor LiveEntryUpdateCoordinator {
    public enum Action: Sendable {
        case begin
        case key(String)
        case advance
        case back
        case finish
    }

    public struct Update: Sendable {
        public let revision: UUID
        public let liveEntry: LiveEntryState?
        public let budget: BudgetSnapshot?
    }

    public static let shared = LiveEntryUpdateCoordinator()

    private var updates: [String: Update] = [:]
    private var publishing: Set<String> = []

    public init() {}

    public func state(activityID: String, fallback: LiveEntryState?) -> LiveEntryState? {
        if let update = updates[activityID] {
            return update.liveEntry
        }
        return fallback
    }

    @discardableResult
    public func apply(
        _ action: Action,
        activityID: String,
        fallback: LiveEntryState?
    ) -> Bool {
        let current = state(activityID: activityID, fallback: fallback)
        let next: LiveEntryState?
        switch action {
        case .begin:
            next = LiveEntryState(step: .amount)
        case .key(let key):
            guard var draft = current, draft.step == .amount else { return false }
            draft.applyKey(key)
            guard draft != current else { return false }
            next = draft
        case .advance:
            guard var draft = current, draft.advanceToNote() else { return false }
            next = draft
        case .back:
            guard var draft = current, draft.step == .note else { return false }
            draft.backToAmount()
            next = draft
        case .finish:
            next = nil
        }
        store(next, activityID: activityID)
        return true
    }

    public func selectNote(
        _ note: String,
        expectedDraftID: UUID?,
        activityID: String,
        fallback: LiveEntryState?
    ) -> LiveEntryState? {
        guard var draft = state(activityID: activityID, fallback: fallback),
              draft.draftID == expectedDraftID,
              draft.selectNote(note)
        else {
            return nil
        }
        draft.draftID = draft.draftID ?? UUID()
        store(draft, activityID: activityID)
        return draft
    }

    public func store(
        _ liveEntry: LiveEntryState?,
        activityID: String,
        budget: BudgetSnapshot? = nil
    ) {
        updates[activityID] = Update(
            revision: UUID(),
            liveEntry: liveEntry,
            budget: budget ?? updates[activityID]?.budget
        )
    }

    public func publish(
        activityID: String,
        using publisher: @Sendable (Update) async -> Void
    ) async {
        guard updates[activityID] != nil, publishing.insert(activityID).inserted else { return }
        defer { publishing.remove(activityID) }

        while let update = updates[activityID] {
            await publisher(update)
            if updates[activityID]?.revision == update.revision {
                updates[activityID] = Update(
                    revision: update.revision,
                    liveEntry: update.liveEntry,
                    budget: nil
                )
                return
            }
        }
    }
}
