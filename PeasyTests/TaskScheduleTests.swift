import CoreGraphics
import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import Peasy

@MainActor
struct TaskScheduleTests {
    let container: ModelContainer
    let store: TaskStore

    init() throws {
        container = try Persistence.makeContainer(inMemory: true)
        store = TaskStore(context: container.mainContext)
    }

    @Test func todayHoldsOverdueTasksButNotLaterOnes() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let late = try #require(store.addTask("Late", to: .inbox))
        let later = try #require(store.addTask("Later", to: .inbox))
        store.schedule(late, on: calendar.date(byAdding: .day, value: -2, to: today), hasTime: false)
        store.schedule(later, on: calendar.date(byAdding: .day, value: 1, to: today), hasTime: false)

        #expect(store.openTasks(in: .today).map(\.title) == ["Late"])
        #expect(late.isOverdue())
        #expect(!later.isOverdue())
    }

    @Test func todayForgetsTasksFinishedOnEarlierDays() throws {
        let old = try #require(store.addTask("Old", to: .today))
        store.toggle(old)
        old.completedAt = Calendar.current.date(byAdding: .day, value: -1, to: .now)
        store.addTask("Fresh", to: .today)

        #expect(store.completedTasks(in: .today).isEmpty)
        let progress = TaskQueries.todayProgress(from: store.allTasks())
        #expect(progress.done == 0)
        #expect(progress.total == 1)
    }

    @Test func movingToTodayKeepsTheTime() throws {
        let calendar = Calendar.current
        let task = try #require(store.addTask("Call", to: .inbox))
        let nextWeek = try #require(calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: .now)))
        store.schedule(task, on: calendar.date(bySettingHour: 14, minute: 30, second: 0, of: nextWeek), hasTime: true)
        store.moveToToday(task)

        let date = try #require(task.date)
        #expect(calendar.isDateInToday(date))
        #expect(calendar.component(.hour, from: date) == 14)
        #expect(calendar.component(.minute, from: date) == 30)
        #expect(task.hasTime)
    }

    @Test func removingTheDateDropsTheTime() throws {
        let task = try #require(store.addTask("Call", to: .inbox))
        store.schedule(task, on: .now, hasTime: true)
        store.setToday(task, false)

        #expect(task.date == nil)
        #expect(!task.hasTime)
    }

    @Test func todayFlagsBecomeDates() throws {
        let calendar = Calendar.current
        let open = try #require(store.addTask("Open", to: .inbox))
        open.isToday = true
        let done = try #require(store.addTask("Done", to: .inbox))
        let finished = try #require(calendar.date(byAdding: .day, value: -3, to: .now))
        done.isToday = true
        done.isDone = true
        done.completedAt = finished
        store.moveTodayFlagsToDates()

        #expect(!open.isToday)
        #expect(!done.isToday)
        #expect(open.date.map(calendar.isDateInToday) == true)
        #expect(done.date == calendar.startOfDay(for: finished))
    }

    @Test func quickChoicesLandOnTheWeekendAndNextMonday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let monday = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 26)))
        let saturday = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 31)))

        #expect(ScheduleDates.weekend(after: monday, calendar: calendar) == saturday)
        #expect(ScheduleDates.weekend(after: saturday, calendar: calendar) == calendar.date(byAdding: .day, value: 7, to: saturday))
        #expect(ScheduleDates.nextWeek(after: monday, calendar: calendar) == calendar.date(byAdding: .day, value: 7, to: monday))
        #expect(ScheduleDates.nextWeek(after: saturday, calendar: calendar) == calendar.date(from: DateComponents(year: 2026, month: 11, day: 2)))
    }

    @Test func monthGridStartsOnTheFirstWeekday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let october = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 15)))
        let grid = ScheduleDates.grid(for: october, calendar: calendar)

        #expect(grid.count == 42)
        #expect(grid.first == calendar.date(from: DateComponents(year: 2026, month: 9, day: 28)))
        #expect(calendar.component(.weekday, from: grid[0]) == 2)
    }

    @Test func pickerOpensToTheRightUnlessTheScreenEnds() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 944)
        let roomy = SchedulePickerWindow.placement(pointingAt: CGRect(x: 1000, y: 800, width: 24, height: 24), within: screen)
        #expect(roomy.arrowEdge == .leading)
        #expect(roomy.frame.minX == 1030)
        #expect(roomy.frame.maxY - roomy.arrowY == 812)

        let cramped = SchedulePickerWindow.placement(pointingAt: CGRect(x: 1400, y: 800, width: 24, height: 24), within: screen)
        #expect(cramped.arrowEdge == .trailing)
        #expect(cramped.frame.maxX == 1394)
    }
}
