import AppKit
import SwiftData

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let notchModel = NotchViewModel()
    private let settingsWindow = SettingsWindowController()
    private var notchController: NotchController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !ProcessInfo.processInfo.isRunningTests else { return }
        let container: ModelContainer
        do {
            container = try Persistence.makeContainer()
        } catch {
            fatalError("Failed to open the task store: \(error)")
        }
        let actions = NotchActions(
            showAbout: { Self.showAbout() },
            openSettings: { [weak self] in self?.settingsWindow.show() },
            quit: { NSApp.terminate(nil) }
        )
        notchController = NotchController(model: notchModel, actions: actions, modelContainer: container)
    }

    private static func showAbout() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let credits = NSAttributedString(
            string: String(localized: "Little tasks, big growth."),
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraph,
            ]
        )
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
}
