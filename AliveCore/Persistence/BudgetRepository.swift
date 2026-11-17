import Foundation

public protocol BudgetRepository: Sendable {
    func hasCycle() async throws -> Bool
    func createCycle(_ setup: CycleSetup, now: Date) async throws -> BudgetSnapshot
    func snapshot(at date: Date) async throws -> BudgetSnapshot
    func addExpense(amountCents: Int, note: String?, at date: Date) async throws -> BudgetSnapshot
    func updateExpense(id: UUID, amountCents: Int, note: String?, now: Date) async throws -> BudgetSnapshot
    func deleteExpense(id: UUID, now: Date) async throws -> BudgetSnapshot
    func overrideCurrentBalance(cents: Int, at date: Date) async throws -> BudgetSnapshot
    func updatePendingCycle(_ setup: CycleSetup, now: Date) async throws -> BudgetSnapshot
    func currentExpenses(at date: Date) async throws -> [Expense]
    func archivedCycles(at date: Date) async throws -> [ArchivedCycleSummary]
}
