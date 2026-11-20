import SwiftData
import SwiftUI

@main
struct PeasyiOSApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            if let container = model.container {
                RootView()
                    .modelContainer(container)
            }
        }
    }
}
