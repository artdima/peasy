import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import Peasy

@MainActor
struct RemindersTests {
    @Test func onlyOpenTasksWithAFutureTimeGetReminders() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let store = TaskStore(context: container.mainContext)
        let now = Date()
        let timed = try #require(store.addTask("Timed", to: .all))
        store.schedule(timed, on: now.addingTimeInterval(3600), hasTime: true)
        let dayOnly = try #require(store.addTask("Day only", to: .all))
        store.schedule(dayOnly, on: now.addingTimeInterval(86_400), hasTime: false)
        let past = try #require(store.addTask("Past", to: .all))
        store.schedule(past, on: now.addingTimeInterval(-60), hasTime: true)
        let done = try #require(store.addTask("Done", to: .all))
        store.schedule(done, on: now.addingTimeInterval(3600), hasTime: true)
        store.toggle(done)

        let requests = Reminders.requests(for: store.allTasks(), now: now)
        #expect(requests.map(\.content.title) == ["Timed"])
        #expect(requests.first?.identifier == "task.\(timed.id.uuidString)")
    }

    @Test func claudeNotificationsFollowTheirSwitches() throws {
        let suite = "ClaudeNotificationsTests"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let id = UUID()

        let help = try #require(ClaudeNotifications.request(for: .handedBack(taskID: id, title: "New keys", question: "Which key?"), defaults: defaults))
        #expect(help.content.body == "New keys: Which key?")
        #expect(help.content.userInfo[ClaudeNotifications.taskIDKey] as? String == id.uuidString)
        #expect(help.trigger == nil)

        let finished = AgentEvent.finished(taskID: id, title: "Ship", note: "Shipped")
        #expect(ClaudeNotifications.request(for: finished, defaults: defaults) == nil)
        defaults.set(true, forKey: ClaudeNotifications.finishedKey)
        #expect(ClaudeNotifications.request(for: finished, defaults: defaults)?.content.body == "Ship: Shipped")

        defaults.set(false, forKey: ClaudeNotifications.needsHelpKey)
        #expect(ClaudeNotifications.request(for: .handedBack(taskID: id, title: "New keys", question: "?"), defaults: defaults) == nil)
        #expect(ClaudeNotifications.request(for: .added(colorHex: "#0A84FF"), defaults: defaults) == nil)
        defaults.removePersistentDomain(forName: suite)
    }
}
