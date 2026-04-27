import AppKit
import SwiftData

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let notchModel = NotchViewModel()
    private let settingsWindow = SettingsWindowController()
    private var notchController: NotchController?
    private var quickAdd: QuickAddController?
    private let hotKey = GlobalHotKey()
    private var defaultsObserver: NSObjectProtocol?

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
        let quickAdd = QuickAddController(modelContainer: container, notchModel: notchModel)
        self.quickAdd = quickAdd
        hotKey.action = { quickAdd.toggle() }
        hotKey.register(Shortcut.current)
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateHotKey()
            }
        }
    }

    private func updateHotKey() {
        let shortcut = Shortcut.current
        if hotKey.shortcut != shortcut {
            hotKey.register(shortcut)
        }
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
