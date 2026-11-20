import AliveCore
import SwiftUI
import UIKit

struct RootView: View {
    @Bindable var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsWelcome = WelcomeController.shouldShow

    var body: some View {
        Group {
            switch model.loadState {
            case .loading:
                LoadingView()
                    .accessibilityHidden(showsWelcome)
            case .setup:
                SetupView(model: model)
                    .accessibilityHidden(showsWelcome)
            case .ready:
                readyContent
                    .accessibilityHidden(showsWelcome)
            case .failed(let message):
                RecoveryView(message: message) {
                    Task { await model.retryBootstrap() }
                }
                .accessibilityHidden(showsWelcome)
            }
        }
        .background(AliveColor.canvas)
        .task {
            await model.bootstrap()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task { await model.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
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
        .overlay {
            if showsWelcome {
                WelcomeView(onComplete: finishWelcome)
                    .transition(.opacity)
                    .accessibilityAddTraits(.isModal)
            }
        }
        .onChange(of: model.alertMessage) { _, message in
            if message != nil { finishWelcome() }
        }
        .onChange(of: model.loadState) { _, state in
            if case .failed = state { finishWelcome() }
        }
        .onOpenURL { url in
            finishWelcome()
            model.handle(url: url)
        }
        .onChange(of: model.isSettingsPresented) { _, presented in
            if presented { finishWelcome() }
        }
        .onChange(of: model.isQuickEntryPresented) { _, presented in
            if presented { finishWelcome() }
        }
    }

    private func finishWelcome() {
        guard showsWelcome else { return }
        WelcomeController.markSeen()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            showsWelcome = false
        }
    }

    private var readyContent: some View {
        ZStack(alignment: .leading) {
            NavigationStack(path: $model.path) {
                TodayView(model: model)
                    .navigationDestination(for: AppModel.Destination.self) { destination in
                        switch destination {
                        case .history:
                            HistoryView(model: model)
                        }
                    }
            }
            .tint(AliveColor.ink)
            .blur(radius: backgroundBlurRadius, opaque: true)
            .scaleEffect(backgroundScale, anchor: .trailing)
            .accessibilityHidden(model.isSettingsPresented || model.isQuickEntryPresented)
            .allowsHitTesting(!model.isSettingsPresented && !model.isQuickEntryPresented)
            // The quick card sits at the top; the keyboard must not lift the screen behind it.
            .ignoresSafeArea(.keyboard, edges: .bottom)

            if model.isQuickEntryPresented {
                if model.quickEntryPresentation == .liveActivity {
                    LiveEntryContinuityView(model: model)
                        .zIndex(2)
                        .transition(.opacity)
                } else {
                    Color.black.opacity(0.28)
                        .ignoresSafeArea()
                        .onTapGesture { model.closeQuickEntry() }
                        .accessibilityHidden(true)
                        .zIndex(1)
                        .transition(.opacity)

                    GeometryReader { proxy in
                        // The overlay follows the keyboard safe area, so this stays above
                        // the decimal pad; at accessibility sizes the card scrolls inside it.
                        let maxHeight = max(0, proxy.size.height - AliveSpace.x2)
                        VStack(spacing: 0) {
                            QuickEntryCard(model: model)
                                // maxHeight also reserves free space; the card itself
                                // must stay pinned to the top of that space.
                                .frame(maxHeight: maxHeight, alignment: .top)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, AliveSpace.pageInset)
                        .padding(.top, AliveSpace.x2)
                    }
                    .zIndex(2)
                    .transition(.asymmetric(insertion: .identity, removal: quickEntryRemoval))
                }
            }

            if model.isSettingsPresented {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { model.closeSettings() }
                    .accessibilityHidden(true)
                    .zIndex(3)
                    .transition(.opacity)

                SettingsDrawer(model: model)
                    .zIndex(4)
                    .transition(settingsDrawerTransition)
            }
        }
        .animation(reduceMotion ? nil : AliveMotion.enter, value: model.isSettingsPresented)
        .animation(reduceMotion ? nil : AliveMotion.card, value: model.isQuickEntryPresented)
        .sheet(item: $model.sheet) { sheet in
            switch sheet {
            case .editExpense(let id):
                if let expense = model.currentExpenses.first(where: { $0.id == id }) {
                    EditExpenseSheet(model: model, expense: expense)
                } else {
                    MissingSheetView()
                }
            case .balance:
                BalanceSheet(model: model)
            }
        }
    }

    private var backgroundBlurRadius: CGFloat {
        if model.isSettingsPresented { return 4 }
        if model.isQuickEntryPresented {
            return model.quickEntryPresentation == .liveActivity ? 0 : 1.5
        }
        return 0
    }

    private var backgroundScale: CGFloat {
        guard !reduceMotion, model.isSettingsPresented else { return 1 }
        return 0.985
    }

    private var settingsDrawerTransition: AnyTransition {
        if reduceMotion {
            return .identity
        }
        return .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    /// The card unfolds itself on insertion (see `QuickEntryCard`); on the way out
    /// it shrinks toward the island. Reduce Motion gets a plain fade instead.
    private var quickEntryRemoval: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .scale(scale: 0.94, anchor: .top).combined(with: .opacity)
    }
}

private struct SettingsDrawer: View {
    let model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var isHeaderFocused: Bool
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let width = dynamicTypeSize.isAccessibilitySize
                ? proxy.size.width
                : min(proxy.size.width * 0.86, 360)
            let isFullWidth = dynamicTypeSize.isAccessibilitySize
                || width >= proxy.size.width - 0.5
            let shape = UnevenRoundedRectangle(
                bottomTrailingRadius: isFullWidth ? 0 : 24,
                topTrailingRadius: 0,
                style: .continuous
            )

            ZStack(alignment: .leading) {
                shape
                    .fill(AliveColor.canvas)
                    .frame(width: width)
                    .frame(maxHeight: .infinity)
                    .ignoresSafeArea(edges: [.top, .bottom])
                    .overlay(alignment: .trailing) {
                        if !isFullWidth {
                            Rectangle()
                                .fill(AliveColor.separator)
                                .frame(width: 0.5)
                        }
                    }
                    .clipShape(shape)
                    .shadow(
                        color: .black.opacity(isFullWidth ? 0 : 0.12),
                        radius: 2,
                        x: 1
                    )
                    .shadow(
                        color: .black.opacity(isFullWidth ? 0 : 0.2),
                        radius: 28,
                        x: 10
                    )
                    .offset(x: dragOffset)

                VStack(spacing: 0) {
                    drawerHeader(width: width)
                    Rectangle()
                        .fill(AliveColor.separator)
                        .frame(height: 0.5)
                    SettingsView(model: model)
                }
                .frame(width: width)
                .frame(maxHeight: .infinity, alignment: .top)
                .offset(x: dragOffset)
                .accessibilityAddTraits(.isModal)
                .accessibilityAction(.escape) { close() }
            }
            .onAppear {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    isHeaderFocused = true
                }
            }
        }
    }

    private func drawerHeader(width: CGFloat) -> some View {
        HStack(alignment: .center, spacing: AliveSpace.x2) {
            Text("设置")
                .font(AliveFont.sans(22, weight: .bold, relativeTo: .title2))
                .foregroundStyle(AliveColor.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($isHeaderFocused)

            Spacer(minLength: AliveSpace.x2)

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(AliveColor.ink)
            .accessibilityLabel("关闭设置")
        }
        .padding(.leading, AliveSpace.pageInset)
        .padding(.trailing, AliveSpace.x3)
        .padding(.top, AliveSpace.x2)
        .padding(.bottom, AliveSpace.x1)
        .background(AliveColor.canvas)
        .simultaneousGesture(closeGesture(width: width))
    }

    private func closeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { value in
                guard value.translation.width < 0,
                      abs(value.translation.width) > abs(value.translation.height)
                else { return }
                dragOffset = max(value.translation.width, -width)
            }
            .onEnded { value in
                let shouldClose = dragOffset < -60
                    || value.predictedEndTranslation.width < -width * 0.4
                withAnimation(reduceMotion ? nil : AliveMotion.value) {
                    if shouldClose {
                        model.closeSettings()
                    } else {
                        dragOffset = 0
                    }
                }
            }
    }

    private func close() {
        withAnimation(reduceMotion ? nil : AliveMotion.enter) {
            model.closeSettings()
        }
    }
}

private struct LoadingView: View {
    var body: some View {
        ZStack {
            AliveColor.canvas.ignoresSafeArea()
            VStack(spacing: AliveSpace.x4) {
                ProgressView()
                Text("正在读取预算")
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
            AliveColor.canvas.ignoresSafeArea()
            VStack(alignment: .leading, spacing: AliveSpace.x4) {
                Text("存储不可用")
                    .font(AliveFont.sans(13, weight: .semibold, relativeTo: .footnote))
                    .foregroundStyle(AliveColor.inkTertiary)
                    .accessibilityAddTraits(.isHeader)
                Text("暂时无法读取预算")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(AliveColor.ink)
                Text("本地预算数据未能读取。ALIVE 不会自动清空已有数据。")
                    .font(AliveFont.sans(16, relativeTo: .body))
                    .foregroundStyle(AliveColor.inkSecondary)
                Text(message)
                    .font(AliveFont.sans(13, relativeTo: .footnote))
                    .foregroundStyle(AliveColor.inkTertiary)
                PrimaryAction(title: "重试", systemImage: "arrow.clockwise") {
                    retry()
                }
                .accessibilityHint("再次读取本地预算数据。")
            }
            .padding(AliveSpace.pageInset)
        }
    }
}

private struct MissingSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AliveColor.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: AliveSpace.x4) {
                SheetHeader(title: "编辑支出") {
                    dismiss()
                }

                Text(BudgetError.expenseNotFound.localizedDescription)
                    .font(AliveFont.sans(16, relativeTo: .body))
                    .foregroundStyle(AliveColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(AliveSpace.pageInset)
        }
        .presentationBackground(AliveColor.canvas)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }
}
