import SwiftData
import SwiftUI

@main
struct PeasyiOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = AppModel()
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.dark

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = model.container {
                    RootView()
                        .modelContainer(container)
                }
            }
            .environment(model.sync)
            .environment(model.folderSync)
            .preferredColorScheme(theme.colorScheme)
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active: model.becameActive()
                case .background: model.enteredBackground()
                default: break
                }
            }
        }
        .backgroundTask(.appRefresh(AppModel.folderRefreshID)) {
            await model.refreshFolder()
        }
    }
}
