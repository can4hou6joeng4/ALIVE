import AliveCore
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppModel {
    enum LoadState: Equatable {
        case loading
        case setup
        case ready
        case failed(String)
    }

    enum Sheet: Identifiable, Hashable {
        case editExpense(UUID)
        case balance

        var id: String {
            switch self {
            case .editExpense(let id):
                "edit-\(id)"
            case .balance:
                "balance"
            }
        }
    }

    enum Destination: Hashable {
        case history
    }

    private let calendar = BudgetCalendar()
    private var repository: (any BudgetRepository)?
    private var didBootstrap = false
    private var queuedRoute: AppRoute?

    var loadState: LoadState = .loading
    var snapshot: BudgetSnapshot?
    var currentExpenses: [Expense] = []
    var archivedCycles: [ArchivedCycleSummary] = []
    var sheet: Sheet?
    var path: [Destination] = []
    var alertMessage: String?
    var isSettingsPresented = false
    var isQuickEntryPresented = false
    let activity = BudgetActivityController()

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        loadState = .loading

        do {
            let repository = try SwiftDataBudgetRepository.makeDefault(calendar: calendar)
            self.repository = repository

            guard try await repository.hasCycle() else {
                await enterSetupWithoutCycle()
                return
            }

            let snapshot = try await repository.snapshot(at: Date())
            await commit(snapshot, openQueuedRoute: true, attachActivity: true)
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func retryBootstrap() async {
        didBootstrap = false
        repository = nil
        await bootstrap()
    }

    func createCycle(initialBalanceCents: Int, startDate: Date, payday: Date) async throws {
        let repository = try requireRepository()
        let setup = CycleSetup(
            initialBalanceCents: initialBalanceCents,
            startDate: startDate,
            nextPayday: payday
        )
        let snapshot = try await repository.createCycle(setup, now: Date())
        await commit(snapshot, openQueuedRoute: true, attachActivity: true)
    }

    func updatePendingCycle(initialBalanceCents: Int, startDate: Date, payday: Date) async throws {
        let repository = try requireRepository()
        let setup = CycleSetup(
            initialBalanceCents: initialBalanceCents,
            startDate: startDate,
            nextPayday: payday
        )
        let snapshot = try await repository.updatePendingCycle(setup, now: Date())
        await commit(snapshot)
    }

    func refresh() async {
        guard let repository, loadState == .ready else { return }
        do {
            let snapshot = try await repository.snapshot(at: Date())
            await commit(snapshot)
            await activity.attach(to: snapshot)
        } catch BudgetError.noCycle {
            await enterSetupWithoutCycle()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func addExpense(amountCents: Int, note: String?) async throws {
        let repository = try requireRepository()
        let snapshot = try await repository.addExpense(amountCents: amountCents, note: note, at: Date())
        await commit(snapshot)
    }

    func updateExpense(id: UUID, amountCents: Int, note: String?) async throws {
        let repository = try requireRepository()
        let snapshot = try await repository.updateExpense(
            id: id,
            amountCents: amountCents,
            note: note,
            now: Date()
        )
        await commit(snapshot)
    }

    func deleteExpense(id: UUID) async {
        guard let repository else { return }
        do {
            let snapshot = try await repository.deleteExpense(id: id, now: Date())
            await commit(snapshot)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func overrideBalance(cents: Int) async throws {
        let repository = try requireRepository()
        let snapshot = try await repository.overrideCurrentBalance(cents: cents, at: Date())
        await commit(snapshot)
    }

    func toggleLiveActivity() async {
        guard let snapshot else {
            alertMessage = BudgetError.noCycle.localizedDescription
            return
        }
        do {
            if activity.status == .active {
                await activity.end()
            } else {
                try await activity.startOrUpdate(with: snapshot)
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func openQuickExpense() {
        guard let snapshot else { return }
        guard snapshot.phase != .pending else {
            alertMessage = BudgetError.cycleNotActive.localizedDescription
            return
        }
        path = []
        isSettingsPresented = false
        sheet = nil
        isQuickEntryPresented = true
    }

    func closeQuickEntry() {
        isQuickEntryPresented = false
    }

    func openBalance() {
        guard let snapshot else { return }
        guard snapshot.phase != .pending else {
            openSettings()
            return
        }
        path = []
        isSettingsPresented = false
        isQuickEntryPresented = false
        sheet = .balance
    }

    func editExpense(id: UUID) {
        isQuickEntryPresented = false
        sheet = .editExpense(id)
    }

    func openHistory() {
        sheet = nil
        isSettingsPresented = false
        isQuickEntryPresented = false
        path.append(.history)
    }

    func openSettings() {
        sheet = nil
        isQuickEntryPresented = false
        path = []
        isSettingsPresented = true
    }

    func closeSettings() {
        isSettingsPresented = false
    }

    func handle(url: URL) {
        guard let route = AppRoute(url: url) else { return }
        switch loadState {
        case .loading, .setup, .failed:
            queuedRoute = route
        case .ready:
            apply(route)
        }
    }

    private func apply(_ route: AppRoute) {
        switch route {
        case .today:
            sheet = nil
            isSettingsPresented = false
            isQuickEntryPresented = false
            path = []
        case .quickEntry:
            openQuickExpense()
        case .balance:
            openBalance()
        case .history:
            openHistory()
        }
    }

    private func applyQueuedRouteIfNeeded() {
        guard let route = queuedRoute else { return }
        queuedRoute = nil
        apply(route)
    }

    private func commit(
        _ snapshot: BudgetSnapshot,
        openQueuedRoute: Bool = true,
        attachActivity: Bool = false
    ) async {
        var derivedDataError: String?

        if let repository {
            do {
                currentExpenses = try await repository.currentExpenses(at: Date())
                archivedCycles = try await repository.archivedCycles(at: Date())
            } catch {
                derivedDataError = "当前周期记录暂时无法读取，请稍后重试。"
            }
        }

        self.snapshot = snapshot
        if openQueuedRoute {
            applyQueuedRouteIfNeeded()
        }
        loadState = .ready

        if attachActivity {
            await activity.attach(to: snapshot)
        } else {
            await activity.updateIfActive(with: snapshot)
        }

        if let derivedDataError {
            alertMessage = derivedDataError
        }
    }

    private func enterSetupWithoutCycle() async {
        snapshot = nil
        currentExpenses = []
        archivedCycles = []
        sheet = nil
        isQuickEntryPresented = false
        path = []

        await activity.end()

        loadState = .setup
    }

    private func requireRepository() throws -> any BudgetRepository {
        guard let repository else { throw BudgetError.storageUnavailable }
        return repository
    }
}
