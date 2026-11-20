import BackgroundTasks
import CloudKit
import CoreData
import Foundation
import Observation
import SwiftData
import UIKit
import UserNotifications
import WidgetKit

@Observable
final class AppModel {
    static let folderRefreshID = "com.artdima.Peasy.folderSync"

    let sync = SyncMonitor()
    let folderSync = FolderSync()
    @ObservationIgnored private let claudeWatch = ClaudeWatch()
    private(set) var container: ModelContainer?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var pendingLink: AppLink?

    init() {
        sync.onStoreReloadNeeded = { [weak self] in self?.reloadStore() }
        sync.start()
        openStore()
        folderSync.refreshCloudAccount(isActive: sync.isActive)
        folderSync.start()
        startReminders()
    }

    func becameActive() {
        if SharedStore.takeOutsideChange() {
            reloadStore()
        }
        DayClock.shared.refresh()
        Reminders.shared.refresh()
        updateBadge()
        folderSync.scheduleSync(after: .zero)
    }

    func enteredBackground() {
        scheduleFolderRefresh()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func open(_ url: URL) {
        guard let link = AppLink(url: url) else { return }
        if container == nil {
            pendingLink = link
        } else {
            show(link)
        }
    }

    func refreshFolder() async {
        await folderSync.syncNow()
        scheduleFolderRefresh()
    }

    func updateBadge() {
        var count = 0
        if UserDefaults.standard.object(forKey: PhoneSettings.showsBadgeKey) as? Bool ?? true, let container {
            let tasks = TaskStore(context: container.mainContext).allTasks()
            count = TaskQueries.ownOpenTasks(in: .today, from: tasks).count
        }
        UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
    }

    private func openStore() {
        let container = Persistence.openStore(cloudKit: sync.isActive) { [sync] error in
            sync.storeFailed(error)
        }
        let store = TaskStore(context: container.mainContext)
        store.assignDistinctColors()
        store.moveTodayFlagsToDates()
        self.container = container
        SharedStore.appContainer = container
        _ = SharedStore.takeOutsideChange()
        folderSync.attach(container)
        Reminders.shared.refresh()
        updateBadge()
        watchClaude()
        if let pendingLink {
            self.pendingLink = nil
            show(pendingLink)
        }
    }

    private func reloadStore() {
        folderSync.detach()
        // A second CloudKit container on the same store fails to register its export activity.
        container = nil
        SharedStore.appContainer = nil
        Task { [weak self] in
            await Task.yield()
            guard let self else { return }
            openStore()
            folderSync.refreshCloudAccount(isActive: sync.isActive)
        }
    }

    private func scheduleFolderRefresh() {
        guard folderSync.isOn else { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.folderRefreshID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func startReminders() {
        let reminders = Reminders.shared
        reminders.permissionOptions = [.alert, .sound, .badge]
        reminders.tasks = { [weak self] in
            guard let container = self?.container else { return [] }
            return TaskStore(context: container.mainContext).allTasks()
        }
        reminders.onOpenTask = { [weak self] id in
            self?.reveal(id)
        }
        reminders.start()
        for name in [ModelContext.didSave, NSPersistentCloudKitContainer.eventChangedNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    Reminders.shared.refresh()
                    self?.updateBadge()
                    self?.folderSync.scheduleSync()
                    self?.watchClaude()
                    WidgetCenter.shared.reloadAllTimelines()
                }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                folderSync.refreshCloudAccount(isActive: sync.isActive)
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateBadge()
            }
        })
    }

    /// Reads the store itself: the main context may not have merged an import yet.
    private func watchClaude() {
        guard let container else { return }
        let look = claudeWatch.look(at: TaskStore(context: ModelContext(container)).allTasks())
        for event in look.events {
            ClaudeNotifications.post(event, asksPermission: false)
        }
        if look.handedToClaude, UIApplication.shared.applicationState == .active {
            askForClaudeNotifications()
        }
    }

    private func askForClaudeNotifications() {
        guard ClaudeNotifications.isOn(ClaudeNotifications.needsHelpKey) || ClaudeNotifications.isOn(ClaudeNotifications.finishedKey) else { return }
        Task {
            guard await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .notDetermined else { return }
            _ = await Reminders.shared.requestPermission()
        }
    }

    private func show(_ link: AppLink) {
        switch link {
        case .today:
            UserDefaults.standard.set(TaskList.today.storageValue, forKey: TaskList.storageKey)
        case .task(let id):
            reveal(id)
        }
    }

    private func reveal(_ id: UUID) {
        guard let container else { return }
        let store = TaskStore(context: container.mainContext)
        guard let task = store.allTasks().first(where: { $0.id == id }) else { return }
        let list: TaskList
        if !task.isDone, task.isDue(on: .now) {
            list = .today
        } else {
            list = task.project.map { TaskList.project($0.id) } ?? .all
        }
        UserDefaults.standard.set(list.storageValue, forKey: TaskList.storageKey)
    }
}
