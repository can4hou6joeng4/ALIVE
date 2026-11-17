import AliveCore
import SwiftUI
import UIKit

struct RootView: View {
    @Bindable var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch model.loadState {
            case .loading:
                LoadingView()
            case .setup:
                SetupView(model: model)
            case .ready:
                readyContent
            case .failed(let message):
                RecoveryView(message: message) {
                    Task { await model.retryBootstrap() }
                }
            }
        }
        .background(AliveColor.canvas)
        .task {
            await model.bootstrap()
        }
        .onOpenURL { url in
            model.handle(url: url)
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task { await model.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            Task { await model.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            Task { await model.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            Task { await model.refresh() }
        }
        .alert(
            "提示",
            isPresented: Binding(
                get: { model.alertMessage != nil },
                set: { if !$0 { model.alertMessage = nil } }
            )
        ) {
            Button("好") {
                model.alertMessage = nil
            }
        } message: {
            Text(model.alertMessage ?? "")
        }
    }

    private var readyContent: some View {
        NavigationStack(path: $model.path) {
            TodayView(model: model)
                .navigationDestination(for: AppModel.Destination.self) { destination in
                    switch destination {
                    case .history:
                        HistoryView(model: model)
                    case .settings:
                        SettingsView(model: model)
                    }
                }
        }
        .tint(AliveColor.ink)
        .sheet(item: $model.sheet) { sheet in
            switch sheet {
            case .quickExpense:
                QuickExpenseSheet(model: model, expense: nil)
            case .editExpense(let id):
                if let expense = model.currentExpenses.first(where: { $0.id == id }) {
                    QuickExpenseSheet(model: model, expense: expense)
                } else {
                    MissingSheetView()
                }
            case .balance:
                BalanceSheet(model: model)
            }
        }
    }
}

private struct LoadingView: View {
    var body: some View {
        ZStack {
            OrreryBackground()
            VStack(spacing: AliveSpace.x4) {
                OrnamentalRingMark()
                    .scaleEffect(1.5)
                ProgressView()
                    .tint(AliveColor.brass)
                Text("正在校准星盘")
                    .font(AliveFont.sans(14, relativeTo: .subheadline))
                    .foregroundStyle(AliveColor.inkSecondary)
            }
        }
    }
}

private struct RecoveryView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ZStack {
            OrreryBackground()
            VStack(alignment: .leading, spacing: AliveSpace.x4) {
                CycleBadge(phase: .overspent)
                Text("星盘暂时失准")
                    .font(AliveFont.display(42))
                    .foregroundStyle(AliveColor.ink)
                Text("本地预算数据未能读取。ALIVE 不会自动清空已有数据。")
                    .font(AliveFont.sans(16, relativeTo: .body))
                    .lineSpacing(6)
                    .foregroundStyle(AliveColor.inkSecondary)
                Text(message)
                    .font(AliveFont.sans(13, relativeTo: .footnote))
                    .foregroundStyle(AliveColor.inkTertiary)
                PrimaryAction(title: "重试", systemImage: "arrow.clockwise") {
                    retry()
                }
            }
            .padding(AliveSpace.pageInset)
        }
    }
}

private struct MissingSheetView: View {
    var body: some View {
        ZStack {
            AliveColor.canvas.ignoresSafeArea()
            Text(BudgetError.expenseNotFound.localizedDescription)
                .font(AliveFont.sans(16))
                .foregroundStyle(AliveColor.inkSecondary)
        }
    }
}
