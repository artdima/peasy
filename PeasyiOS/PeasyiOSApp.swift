import SwiftData
import SwiftUI

@main
struct PeasyiOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = AppModel()
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.dark

    var body: some Scene {
        WindowGroup {
            ZStack {
                PhoneStyle.background
                    .ignoresSafeArea()
                if let container = model.container {
                    RootView()
                        .modelContainer(container)
                }
            }
            // Outside the store's views, so Sync now and the iCloud switch don't close it.
            .sheet(isPresented: $model.showsSettings) {
                SettingsSheet()
            }
            .environment(model)
            .environment(model.sync)
            .environment(model.folderSync)
            .preferredColorScheme(theme.colorScheme)
            .onOpenURL { model.open($0) }
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
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New task") {
                    NewTaskPrompt.shared.isPresented = true
                }
                .keyboardShortcut("n")
            }
        }
    }
}
