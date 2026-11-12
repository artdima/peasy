import Foundation
import UserNotifications

nonisolated enum ClaudeNotifications {
    static let needsHelpKey = "claudeNotifyNeedsHelp"
    static let finishedKey = "claudeNotifyFinished"
    static let taskIDKey = "taskID"
    private static let prefix = "claude."

    static func isOn(_ key: String, in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: key) as? Bool ?? (key == needsHelpKey)
    }

    static func request(for event: AgentEvent, defaults: UserDefaults = .standard) -> UNNotificationRequest? {
        let content = UNMutableNotificationContent()
        let identifier: String
        switch event {
        case .added:
            return nil
        case .handedBack(let taskID, let title, let question):
            guard isOn(needsHelpKey, in: defaults) else { return nil }
            content.title = String(localized: "Claude needs help")
            content.body = "\(title): \(question)"
            content.userInfo = [taskIDKey: taskID.uuidString]
            identifier = prefix + "help." + taskID.uuidString
        case .finished(let taskID, let title, let note):
            guard isOn(finishedKey, in: defaults) else { return nil }
            content.title = String(localized: "Claude finished")
            content.body = note.isEmpty ? title : "\(title): \(note)"
            content.userInfo = [taskIDKey: taskID.uuidString]
            identifier = prefix + "done." + taskID.uuidString
        }
        content.sound = .default
        return UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
    }

    static func post(_ event: AgentEvent) {
        Task {
            guard let request = request(for: event) else { return }
            let center = UNUserNotificationCenter.current()
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            try? await center.add(request)
        }
    }
}
