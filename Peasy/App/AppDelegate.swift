import AppKit
import SwiftData

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let notchModel = NotchViewModel()
    private let settingsWindow = SettingsWindowController()
    private var notchController: NotchPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !ProcessInfo.processInfo.isRunningTests else { return }
        let container: ModelContainer
        do {
            container = try Persistence.makeContainer()
        } catch {
            fatalError("Failed to open the task store: \(error)")
        }
        let actions = NotchActions(
            openSettings: { [weak self] in self?.settingsWindow.show() },
            quit: { NSApp.terminate(nil) }
        )
        notchController = NotchPanelController(model: notchModel, actions: actions, modelContainer: container)
    }
}
