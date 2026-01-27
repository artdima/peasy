import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let notchModel = NotchViewModel()
    private let settingsWindow = SettingsWindowController()
    private var notchController: NotchPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !ProcessInfo.processInfo.isRunningTests else { return }
        let actions = NotchActions(
            openSettings: { [weak self] in self?.settingsWindow.show() },
            quit: { NSApp.terminate(nil) }
        )
        notchController = NotchPanelController(model: notchModel, actions: actions)
    }
}
