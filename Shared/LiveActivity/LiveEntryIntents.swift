import ActivityKit
import AliveCore
import AppIntents
import Foundation

private enum LiveEntryActivityResolver {
    static func activity(cycleID: String) -> Activity<BudgetActivityAttributes>? {
        let matches = Activity<BudgetActivityAttributes>.activities.filter {
            $0.attributes.cycleID.uuidString.caseInsensitiveCompare(cycleID) == .orderedSame
        }
        let now = Date()
        return matches.first {
            $0.activityState == .active
                && now >= $0.attributes.startDate
                && now < $0.attributes.payday
                && ($0.content.staleDate.map { now < $0 } ?? false)
        }
    }
}

private func publishLiveEntry(_ activity: Activity<BudgetActivityAttributes>) async {
    let activityID = activity.id
    await LiveEntryUpdateCoordinator.shared.publish(activityID: activityID) { update in
        guard let currentActivity = Activity<BudgetActivityAttributes>.activities.first(where: {
            $0.id == activityID && $0.activityState == .active
        }) else { return }
        let state: BudgetActivityAttributes.ContentState
        if let snapshot = update.budget {
            state = currentActivity.content.state.updating(budget: snapshot, liveEntry: update.liveEntry)
        } else {
            state = currentActivity.content.state.updating(liveEntry: update.liveEntry)
        }
        await currentActivity.update(ActivityContent(state: state, staleDate: currentActivity.content.staleDate))
    }
}

private func applyLiveEntry(
    _ action: LiveEntryUpdateCoordinator.Action,
    to activity: Activity<BudgetActivityAttributes>
) async {
    guard await LiveEntryUpdateCoordinator.shared.apply(
        action,
        activityID: activity.id,
        fallback: activity.content.state.liveEntry
    ) else { return }
    await publishLiveEntry(activity)
}

/// Serializes save taps inside the app process. Two rapid taps therefore cannot
/// insert the same draft twice before the first activity update lands.
private actor LiveEntrySaveGate {
    static let shared = LiveEntrySaveGate()
    private var inFlight: Set<String> = []

    func begin(_ key: String) -> Bool {
        guard !inFlight.contains(key) else { return false }
        inFlight.insert(key)
        return true
    }

    func end(_ key: String) {
        inFlight.remove(key)
    }
}

private func saveLiveEntry(
    _ activity: Activity<BudgetActivityAttributes>,
    note: String,
    expectedDraftID: UUID?
) async {
    let gateKey = activity.id
    guard await LiveEntrySaveGate.shared.begin(gateKey) else {
        return
    }

    guard activity.activityState == .active,
          activity.content.staleDate.map({ Date() < $0 }) == true,
          let liveEntry = await LiveEntryUpdateCoordinator.shared.selectNote(
        note,
        expectedDraftID: expectedDraftID,
        activityID: activity.id,
        fallback: activity.content.state.liveEntry
    ),
          let amountCents = liveEntry.amountCents,
          amountCents > 0,
          let expenseID = liveEntry.draftID
    else {
        await LiveEntrySaveGate.shared.end(gateKey)
        return
    }

    var savedEntry = liveEntry
    var savedSnapshot: BudgetSnapshot?
    do {
        let repository = try SwiftDataBudgetRepository.makeDefault()
        let snapshot = try await repository.addExpense(
            id: expenseID,
            amountCents: amountCents,
            note: liveEntry.note,
            expectedCycleID: activity.attributes.cycleID,
            at: Date()
        )

        savedEntry.step = .saved
        savedEntry.savedAmountCents = amountCents
        savedEntry.savedNote = liveEntry.note
        savedEntry.errorMessage = nil
        savedSnapshot = snapshot
    } catch BudgetError.expenseAlreadyRecorded {
        savedEntry.errorMessage = "这笔已记录，请返回 App 查看"
    } catch BudgetError.expenseOutsideCurrentCycle {
        savedEntry.errorMessage = "周期已变化，请返回 App"
    } catch {
        savedEntry.errorMessage = "保存失败，请进 App 重试"
    }
    await LiveEntryUpdateCoordinator.shared.store(
        savedEntry,
        activityID: activity.id,
        budget: savedSnapshot
    )
    await publishLiveEntry(activity)

    await LiveEntrySaveGate.shared.end(gateKey)
}

public struct BeginLiveEntryIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "记一笔"
    public static let openAppWhenRun = false
    public static let supportedModes: IntentModes = .background

    @Parameter(title: "Cycle")
    public var cycleID: String

    public init() {
        cycleID = ""
    }

    public init(cycleID: String) {
        self.cycleID = cycleID
    }

    public func perform() async throws -> some IntentResult {
        guard let activity = LiveEntryActivityResolver.activity(cycleID: cycleID),
              activity.activityState == .active,
              activity.content.state.phase != .pending
        else {
            return .result()
        }

        await applyLiveEntry(.begin, to: activity)
        return .result()
    }
}

public struct LiveEntryKeyIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "输入金额"
    public static let openAppWhenRun = false
    public static let supportedModes: IntentModes = .background

    @Parameter(title: "Cycle")
    public var cycleID: String

    @Parameter(title: "Key")
    public var key: String

    public init() {
        cycleID = ""
        key = ""
    }

    public init(cycleID: String, key: String) {
        self.cycleID = cycleID
        self.key = key
    }

    public func perform() async throws -> some IntentResult {
        guard let activity = LiveEntryActivityResolver.activity(cycleID: cycleID),
              activity.activityState == .active
        else {
            return .result()
        }

        await applyLiveEntry(.key(key), to: activity)
        return .result()
    }
}

public struct LiveEntryAdvanceIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "下一步"
    public static let openAppWhenRun = false
    public static let supportedModes: IntentModes = .background

    @Parameter(title: "Cycle")
    public var cycleID: String

    public init() {
        cycleID = ""
    }

    public init(cycleID: String) {
        self.cycleID = cycleID
    }

    public func perform() async throws -> some IntentResult {
        guard let activity = LiveEntryActivityResolver.activity(cycleID: cycleID),
              activity.activityState == .active
        else {
            return .result()
        }

        await applyLiveEntry(.advance, to: activity)
        return .result()
    }
}

public struct LiveEntryNoteIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "选择备注并记账"
    public static let openAppWhenRun = false
    public static let supportedModes: IntentModes = .background

    @Parameter(title: "Cycle")
    public var cycleID: String

    @Parameter(title: "Note")
    public var note: String

    @Parameter(title: "Draft")
    public var draftID: String

    public init() {
        cycleID = ""
        note = ""
        draftID = ""
    }

    public init(cycleID: String, note: String, draftID: String = "") {
        self.cycleID = cycleID
        self.note = note
        self.draftID = draftID
    }

    public func perform() async throws -> some IntentResult {
        guard let activity = LiveEntryActivityResolver.activity(cycleID: cycleID),
              draftID.isEmpty || UUID(uuidString: draftID) != nil
        else {
            return .result()
        }

        await saveLiveEntry(activity, note: note, expectedDraftID: UUID(uuidString: draftID))
        return .result()
    }
}

public struct LiveEntryBackIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "返回金额"
    public static let openAppWhenRun = false
    public static let supportedModes: IntentModes = .background

    @Parameter(title: "Cycle")
    public var cycleID: String

    public init() {
        cycleID = ""
    }

    public init(cycleID: String) {
        self.cycleID = cycleID
    }

    public func perform() async throws -> some IntentResult {
        guard let activity = LiveEntryActivityResolver.activity(cycleID: cycleID),
              activity.activityState == .active
        else {
            return .result()
        }

        await applyLiveEntry(.back, to: activity)
        return .result()
    }
}

public struct LiveEntryCancelIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "完成"
    public static let openAppWhenRun = false
    public static let supportedModes: IntentModes = .background

    @Parameter(title: "Cycle")
    public var cycleID: String

    public init() {
        cycleID = ""
    }

    public init(cycleID: String) {
        self.cycleID = cycleID
    }

    public func perform() async throws -> some IntentResult {
        guard let activity = LiveEntryActivityResolver.activity(cycleID: cycleID),
              activity.activityState == .active
        else {
            return .result()
        }

        await applyLiveEntry(.finish, to: activity)
        return .result()
    }
}
