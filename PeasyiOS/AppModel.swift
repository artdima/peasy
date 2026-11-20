import CoreData
import Foundation
import Observation
import SwiftData
import UserNotifications

@Observable
final class AppModel {
    let sync = SyncMonitor()
    private(set) var container: ModelContainer?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init() {
        sync.onStoreReloadNeeded = { [weak self] in self?.reloadStore() }
        sync.start()
        openStore()
        startReminders()
    }

    func becameActive() {
        DayClock.shared.refresh()
        Reminders.shared.refresh()
        updateBadge()
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
        Reminders.shared.refresh()
        updateBadge()
    }

    private func reloadStore() {
        // A second CloudKit container on the same store fails to register its export activity.
        container = nil
        Task { [weak self] in
            await Task.yield()
            self?.openStore()
        }
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
                }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateBadge()
            }
        })
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
