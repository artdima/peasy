import SwiftData
import SwiftUI

@main
struct PeasyiOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = model.container {
                    RootView()
                        .modelContainer(container)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    model.becameActive()
                }
            }
        }
    }
}
