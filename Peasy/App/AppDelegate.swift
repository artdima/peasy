import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let notchModel = NotchViewModel()
    private var notchController: NotchPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !ProcessInfo.processInfo.isRunningTests else { return }
        notchController = NotchPanelController(model: notchModel)
    }
}
