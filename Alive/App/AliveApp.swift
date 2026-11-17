import SwiftUI

@main
@MainActor
struct AliveApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .preferredColorScheme(model.preferredColorScheme)
        }
    }
}
