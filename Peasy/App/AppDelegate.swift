import AppKit
import CoreData
import SwiftData

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let notchModel = NotchViewModel()
    private let sync = SyncMonitor()
    private lazy var settingsWindow = SettingsWindowController(sync: sync)
    private var container: ModelContainer?
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
        prepare(container)
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
        startReminders()
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

    private func prepare(_ container: ModelContainer) {
        self.container = container
        let store = TaskStore(context: container.mainContext)
        store.assignDistinctColors()
        store.moveTodayFlagsToDates()
        Reminders.shared.refresh()
    }

    private func startReminders() {
        let reminders = Reminders.shared
        reminders.tasks = { [weak self] in
            guard let container = self?.container else { return [] }
            return TaskStore(context: container.mainContext).allTasks()
        }
        reminders.onOpen = { [weak self] in
            self?.notchController?.expand()
        }
        reminders.start()
        for name in [ModelContext.didSave, NSPersistentCloudKitContainer.eventChangedNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated {
                    Reminders.shared.refresh()
                }
            })
        }
    }

    private func reloadStore() {
        notchController?.unloadStore()
        quickAdd?.unloadStore()
        Task { [weak self] in
            await Task.yield()
            guard let self else { return }
            let container = openStore()
            prepare(container)
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
