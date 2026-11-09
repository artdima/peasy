import Foundation
import UserNotifications

/// Pending notifications are rebuilt from the tasks after every change, so a
/// task that is moved, finished or deleted never fires a stale reminder.
@MainActor
final class Reminders: NSObject {
    static let shared = Reminders()

    var tasks: () -> [TaskItem] = { [] }
    var onOpen: () -> Void = {}
    var onOpenUpdate: () -> Void = {}

    private static let prefix = "task."
    private var refreshTask: Task<Void, Never>?

    func start() {
        UNUserNotificationCenter.current().delegate = self
        refresh()
    }

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        refresh()
        return granted
    }

    func refresh() {
        let requests = Self.requests(for: tasks(), now: .now)
        refreshTask?.cancel()
        refreshTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let center = UNUserNotificationCenter.current()
            let stale = await center.pendingNotificationRequests()
                .map(\.identifier)
                .filter { $0.hasPrefix(Self.prefix) }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            for request in requests {
                try? await center.add(request)
            }
        }
    }

    static func requests(for tasks: [TaskItem], now: Date) -> [UNNotificationRequest] {
        tasks.compactMap { task in
            guard task.hasTime, !task.isDone, let date = task.date, date > now else { return nil }
            let content = UNMutableNotificationContent()
            content.title = task.title
            if let project = task.project {
                content.subtitle = project.name
            }
            content.sound = .default
            let moment = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            return UNNotificationRequest(
                identifier: prefix + task.id.uuidString,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: moment, repeats: false)
            )
        }
    }
}

extension Reminders: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let isUpdate = response.notification.request.identifier == Updater.notificationID
        await MainActor.run {
            if isUpdate {
                self.onOpenUpdate()
            } else {
                self.onOpen()
            }
        }
    }
}
