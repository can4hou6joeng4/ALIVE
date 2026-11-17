import AliveCore
import SwiftUI

struct HistoryView: View {
    let model: AppModel
    @State private var expenseToDelete: Expense?
    @State private var expandedArchived: Set<UUID> = []

    private let calendar = BudgetCalendar()

    private var currentGroups: [(day: Date, expenses: [Expense])] {
        let grouped = Dictionary(grouping: model.currentExpenses) {
            calendar.startOfDay($0.occurredAt)
        }
        return grouped
            .map { (day: $0.key, expenses: $0.value.sorted { $0.occurredAt > $1.occurredAt }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        ZStack {
            OrreryBackground()

            List {
                currentCycleSummary

                if model.currentExpenses.isEmpty {
                    emptyState
                } else {
                    ForEach(currentGroups, id: \.day) { group in
                        Section {
                            ForEach(group.expenses) { expense in
                                expenseRow(expense, editable: true)
                            }
                        } header: {
                            dayHeader(group.day)
                        }
                    }
                }

                if !model.archivedCycles.isEmpty {
                    Section {
                        ForEach(model.archivedCycles) { cycle in
                            archivedCycle(cycle)
                        }
                    } header: {
                        sectionHeader("已归档周期")
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 44)
        }
        .navigationTitle("本周期记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AliveColor.canvas, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert(
            "删除这笔支出？",
            isPresented: Binding(
                get: { expenseToDelete != nil },
                set: { if !$0 { expenseToDelete = nil } }
            ),
            presenting: expenseToDelete
        ) { expense in
            Button("删除", role: .destructive) {
                expenseToDelete = nil
                Task { await model.deleteExpense(id: expense.id) }
            }
            Button("取消", role: .cancel) {
                expenseToDelete = nil
            }
        } message: { expense in
            Text("\(MoneyFormatter.currency(cents: expense.amountCents)) 删除后会恢复到可用额度。")
        }
    }

    @ViewBuilder
    private var currentCycleSummary: some View {
        if let snapshot = model.snapshot {
            VStack(alignment: .leading, spacing: AliveSpace.x2) {
                Text(AliveDateText.range(snapshot.startDate, snapshot.payday))
                    .font(AliveFont.sans(12, weight: .semibold, relativeTo: .caption))
                    .tracking(1.2)
                    .foregroundStyle(AliveColor.inkTertiary)
                Text("已记录 \(model.currentExpenses.count) 笔 · 合计 \(MoneyFormatter.currency(cents: model.currentExpenses.reduce(0) { $0 + $1.amountCents }))")
                    .font(AliveFont.sans(16, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(AliveColor.ink)
            }
            .padding(.vertical, AliveSpace.x2)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AliveSpace.x2) {
            Text("还没有记录。")
                .font(AliveFont.sans(17, weight: .semibold, relativeTo: .body))
                .foregroundStyle(AliveColor.ink)
            Text("今天的第一笔，会让预算更准确。")
                .font(AliveFont.sans(14, relativeTo: .subheadline))
                .foregroundStyle(AliveColor.inkTertiary)
        }
        .padding(.vertical, AliveSpace.x4)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func dayHeader(_ date: Date) -> some View {
        Text(dayLabel(date))
            .font(AliveFont.sans(12, weight: .semibold, relativeTo: .caption))
            .tracking(1.4)
            .foregroundStyle(AliveColor.inkTertiary)
            .textCase(nil)
            .listRowInsets(
                EdgeInsets(
                    top: AliveSpace.x2,
                    leading: 0,
                    bottom: AliveSpace.x1,
                    trailing: 0
                )
            )
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(AliveFont.sans(12, weight: .semibold, relativeTo: .caption))
            .tracking(1.4)
            .foregroundStyle(AliveColor.inkTertiary)
            .textCase(nil)
            .padding(.top, AliveSpace.x4)
    }

    private func expenseRow(_ expense: Expense, editable: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AliveSpace.x3) {
            Text(AliveDateText.time(expense.occurredAt))
                .font(AliveFont.sans(12, weight: .medium, relativeTo: .caption))
                .foregroundStyle(AliveColor.inkTertiary)
                .monospacedDigit()
                .frame(width: 44, alignment: .leading)

            Text(expense.note ?? "支出")
                .font(AliveFont.sans(15, weight: .medium, relativeTo: .body))
                .foregroundStyle(AliveColor.ink)
                .lineLimit(1)

            Spacer(minLength: AliveSpace.x2)

            Text("-\(MoneyFormatter.currency(cents: expense.amountCents))")
                .font(AliveFont.sans(15, weight: .semibold, relativeTo: .body))
                .foregroundStyle(AliveColor.ink)
                .monospacedDigit()
        }
        .padding(.vertical, AliveSpace.x1)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .overlay(alignment: .bottom) { BrassRule(subtle: true) }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if editable {
                Button(role: .destructive) {
                    expenseToDelete = expense
                } label: {
                    Label("删除", systemImage: "trash")
                }

                Button {
                    model.editExpense(id: expense.id)
                } label: {
                    Label("编辑", systemImage: "pencil")
                }
                .tint(AliveColor.brass)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(AliveDateText.time(expense.occurredAt))，\(expense.note ?? "支出")，\(MoneyFormatter.spoken(cents: Decimal(expense.amountCents)))")
    }

    private func archivedCycle(_ cycle: ArchivedCycleSummary) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedArchived.contains(cycle.id) },
                set: { isExpanded in
                    if isExpanded {
                        expandedArchived.insert(cycle.id)
                    } else {
                        expandedArchived.remove(cycle.id)
                    }
                }
            )
        ) {
            if cycle.expenses.isEmpty {
                Text("这个周期没有支出记录。")
                    .font(AliveFont.sans(13, relativeTo: .footnote))
                    .foregroundStyle(AliveColor.inkTertiary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(cycle.expenses) { expense in
                    expenseRow(expense, editable: false)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: AliveSpace.x1) {
                Text(AliveDateText.range(cycle.startDate, cycle.paydayDate))
                    .font(AliveFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                    .foregroundStyle(AliveColor.ink)
                Text("\(cycle.expenses.count) 笔 · 期末余额 \(MoneyFormatter.currency(cents: cycle.endingBalanceCents))")
                    .font(AliveFont.sans(12, relativeTo: .caption))
                    .foregroundStyle(AliveColor.inkTertiary)
            }
            .padding(.vertical, AliveSpace.x1)
        }
        .tint(AliveColor.brass)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func dayLabel(_ date: Date) -> String {
        let today = Date()
        if calendar.isSameDay(date, today) {
            return "今天"
        }
        if let yesterday = calendar.calendar.date(byAdding: .day, value: -1, to: today),
           calendar.isSameDay(date, yesterday) {
            return "昨天"
        }
        return AliveDateText.monthDay(date)
    }
}
