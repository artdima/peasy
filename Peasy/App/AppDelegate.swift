import AppKit
import SwiftData

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let notchModel = NotchViewModel()
    private let sync = SyncMonitor()
    private lazy var settingsWindow = SettingsWindowController(sync: sync)
    private var notchController: NotchController?
    private var quickAdd: QuickAddController?
    private let hotKey = GlobalHotKey()
    private var observers: [NSObjectProtocol] = []
    private var isRecordingShortcut = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !ProcessInfo.processInfo.isRunningTests else { return }
        sync.onStoreReloadNeeded = { [weak self] in self?.reloadStore() }
        sync.start()
        let container = openStore()
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
        observers.append(NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateHotKey()
            }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: .shortcutRecordingChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let isRecording = notification.object as? Bool ?? false
            MainActor.assumeIsolated {
                self?.isRecordingShortcut = isRecording
                self?.updateHotKey()
            }
        })
    }

    private func openStore() -> ModelContainer {
        Persistence.openStore(cloudKit: sync.isActive) { [sync] error in
            sync.storeFailed(error)
        }
    }

    private func reloadStore() {
        notchController?.unloadStore()
        quickAdd?.unloadStore()
        Task { [weak self] in
            await Task.yield()
            guard let self else { return }
            let container = openStore()
            notchController?.loadStore(container)
            quickAdd?.loadStore(container)
        }
    }

    private func updateHotKey() {
        if isRecordingShortcut {
            hotKey.unregister()
            return
        }
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
