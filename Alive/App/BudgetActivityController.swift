@preconcurrency import ActivityKit
import AliveCore
import Foundation
import Observation

enum ActivityControlError: Error, LocalizedError {
    case unsupported
    case pendingCycle

    var errorDescription: String? {
        switch self {
        case .unsupported:
            "系统未允许实时活动，或当前设备不支持。"
        case .pendingCycle:
            "周期开始后才能开启今日灵动岛。"
        }
    }
}

@MainActor
@Observable
final class BudgetActivityController {
    enum Status: Equatable {
        case unavailable
        case inactive
        case active
        case stale
    }

    private(set) var status: Status = .inactive
    private var activity: Activity<BudgetActivityAttributes>?

    var isActive: Bool {
        status == .active
    }

    var canStart: Bool {
        status == .inactive || status == .stale
    }

    var statusText: String {
        switch status {
        case .unavailable:
            "系统未允许实时活动"
        case .inactive:
            "今日灵动岛未开启"
        case .active:
            "今日灵动岛已开启"
        case .stale:
            "今日灵动岛已过期"
        }
    }

    func refreshStatus() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            status = .unavailable
            return
        }

        guard let activity = Activity<BudgetActivityAttributes>.activities.first else {
            self.activity = nil
            status = .inactive
            return
        }
        self.activity = activity
        updateStatus(for: activity)
    }

    func attach(to snapshot: BudgetSnapshot?) async {
        refreshStatus()
        guard let snapshot, let activity else { return }
        if activity.attributes.cycleID != snapshot.cycleID {
            await endActivity(activity)
            self.activity = nil
            status = .inactive
            return
        }
        if activity.activityState == .active, snapshot.phase != .pending {
            let staleDate = activity.content.staleDate ?? Date().addingTimeInterval(LiveActivityWindow.maximumDuration)
            await activity.update(content(for: snapshot, staleDate: staleDate))
        }
        updateStatus(for: activity)
    }

    func startOrUpdate(with snapshot: BudgetSnapshot, now: Date = Date()) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            status = .unavailable
            throw ActivityControlError.unsupported
        }
        guard snapshot.phase != .pending else {
            throw ActivityControlError.pendingCycle
        }

        refreshStatus()

        if let activity, activity.activityState == .active {
            let staleDate = activity.content.staleDate
                ?? LiveActivityWindow.calculate(snapshot: snapshot, openedAt: now).staleDate
            await activity.update(content(for: snapshot, staleDate: staleDate))
            self.activity = activity
            status = .active
            return
        }

        for existing in Activity<BudgetActivityAttributes>.activities {
            await endActivity(existing)
        }

        let window = LiveActivityWindow.calculate(snapshot: snapshot, openedAt: now)
        let attributes = BudgetActivityAttributes(
            cycleID: snapshot.cycleID,
            startDate: snapshot.startDate,
            payday: snapshot.payday
        )
        let newActivity = try Activity.request(
            attributes: attributes,
            content: content(for: snapshot, staleDate: window.staleDate),
            pushType: nil
        )
        activity = newActivity
        status = .active
    }

    func updateIfActive(with snapshot: BudgetSnapshot) async {
        refreshStatus()
        guard let activity, activity.activityState == .active else { return }
        guard activity.attributes.cycleID == snapshot.cycleID, snapshot.phase != .pending else {
            await endActivity(activity)
            self.activity = nil
            status = .inactive
            return
        }
        let staleDate = activity.content.staleDate
            ?? Date().addingTimeInterval(LiveActivityWindow.maximumDuration)
        await activity.update(content(for: snapshot, staleDate: staleDate))
        updateStatus(for: activity)
    }

    func end() async {
        for activity in Activity<BudgetActivityAttributes>.activities {
            await endActivity(activity)
        }
        activity = nil
        refreshStatus()
    }

    private func content(
        for snapshot: BudgetSnapshot,
        staleDate: Date
    ) -> ActivityContent<BudgetActivityAttributes.ContentState> {
        ActivityContent(
            state: BudgetActivityAttributes.ContentState(
                todayAvailableCents: snapshot.todayAvailableCents,
                currentBalanceCents: snapshot.currentBalanceCents,
                daysRemaining: snapshot.daysRemaining,
                phase: snapshot.phase,
                updatedAt: snapshot.generatedAt
            ),
            staleDate: staleDate
        )
    }

    private func endActivity(_ activity: Activity<BudgetActivityAttributes>) async {
        await activity.end(nil, dismissalPolicy: .immediate)
    }

    private func updateStatus(for activity: Activity<BudgetActivityAttributes>) {
        switch activity.activityState {
        case .active:
            if let staleDate = activity.content.staleDate, Date() >= staleDate {
                status = .stale
            } else {
                status = .active
            }
        case .stale:
            status = .stale
        case .dismissed, .ended:
            status = .inactive
        case .pending:
            status = .inactive
        @unknown default:
            status = .inactive
        }
    }
}
