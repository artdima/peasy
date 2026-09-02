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
        let timed = try #require(store.addTask("Timed", to: .inbox))
        store.schedule(timed, on: now.addingTimeInterval(3600), hasTime: true)
        let dayOnly = try #require(store.addTask("Day only", to: .inbox))
        store.schedule(dayOnly, on: now.addingTimeInterval(86_400), hasTime: false)
        let past = try #require(store.addTask("Past", to: .inbox))
        store.schedule(past, on: now.addingTimeInterval(-60), hasTime: true)
        let done = try #require(store.addTask("Done", to: .inbox))
        store.schedule(done, on: now.addingTimeInterval(3600), hasTime: true)
        store.toggle(done)

        let requests = Reminders.requests(for: store.allTasks(), now: now)
        #expect(requests.map(\.content.title) == ["Timed"])
        #expect(requests.first?.identifier == "task.\(timed.id.uuidString)")
    }
}
