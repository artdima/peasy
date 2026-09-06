import Foundation
import SwiftData
import Testing
@testable import Peasy

@MainActor
struct TaskStoreTests {
    let container: ModelContainer
    let store: TaskStore

    init() throws {
        container = try Persistence.makeContainer(inMemory: true)
        store = TaskStore(context: container.mainContext)
    }

    @Test func projectsKeepCreationOrderAndGetDistinctColors() throws {
        store.createProject(named: "Home")
        store.createProject(named: "  Work  ")
        let projects = store.projects()
        #expect(projects.map(\.name) == ["Home", "Work"])
        #expect(projects.map(\.colorHex) == Array(ProjectPalette.colors.prefix(2)))
    }

    @Test func emptyNamesAreIgnored() throws {
        #expect(store.createProject(named: "   ") == nil)
        #expect(store.addTask("\n", to: .all) == nil)
        #expect(store.allTasks().isEmpty)
    }

    @Test func newTasksGoToTheEnd() throws {
        let project = try #require(store.createProject(named: "Home"))
        for title in ["One", "Two", "Three"] {
            store.addTask(title, to: .project(project.id))
        }
        #expect(store.openTasks(in: .project(project.id)).map(\.title) == ["One", "Two", "Three"])
    }

    @Test func todayCollectsFlaggedTasksFromEveryList() throws {
        let work = try #require(store.createProject(named: "Work"))
        let release = try #require(store.addTask("Release", to: .project(work.id)))
        store.addTask("Backlog", to: .project(work.id))
        store.addTask("Mail", to: .today)
        store.setToday(release, true)

        #expect(store.openTasks(in: .today).map(\.title) == ["Release", "Mail"])
        #expect(store.openTasks(in: .all).map(\.title) == ["Release", "Backlog", "Mail"])
        #expect(store.openTasks(in: .project(work.id)).map(\.title) == ["Release", "Backlog"])
    }

    @Test func todayProgressCountsOnlyTodayTasks() throws {
        let done = try #require(store.addTask("Done", to: .today))
        store.addTask("Open", to: .today)
        store.addTask("Someday", to: .all)
        store.toggle(done)

        let progress = TaskQueries.todayProgress(from: store.allTasks())
        #expect(progress.done == 1)
        #expect(progress.total == 2)
    }

    @Test func toggleMovesTaskToCompleted() throws {
        let task = try #require(store.addTask("One", to: .all))
        store.toggle(task)
        #expect(task.completedAt != nil)
        #expect(store.openTasks(in: .all).isEmpty)
        #expect(store.completedTasks(in: .all).map(\.title) == ["One"])

        store.toggle(task)
        #expect(task.completedAt == nil)
    }

    @Test func movingTaskChangesOnlyItsOrder() throws {
        for title in ["A", "B", "C"] {
            store.addTask(title, to: .all)
        }
        store.moveOpenTasks(in: .all, from: IndexSet(integer: 2), to: 0)
        #expect(store.openTasks(in: .all).map(\.title) == ["C", "A", "B"])

        store.moveOpenTasks(in: .all, from: IndexSet(integer: 0), to: 2)
        #expect(store.openTasks(in: .all).map(\.title) == ["A", "C", "B"])
    }

    @Test func repeatedMovesRenumberWithoutBreakingOtherLists() throws {
        let work = try #require(store.createProject(named: "Work"))
        for title in ["A", "B", "C"] {
            store.addTask(title, to: .all)
        }
        store.addTask("W", to: .project(work.id))
        for _ in 0..<80 {
            store.moveOpenTasks(in: .all, from: IndexSet(integer: 2), to: 1)
        }
        let orders = store.openTasks(in: .all).map(\.order)
        #expect(orders == orders.sorted())
        #expect(Set(store.allTasks().map(\.order)).count == 4)
        #expect(store.openTasks(in: .project(work.id)).map(\.title) == ["W"])
    }

    @Test func clearCompletedKeepsOpenTasks() throws {
        let done = try #require(store.addTask("Done", to: .all))
        store.addTask("Open", to: .all)
        store.toggle(done)
        store.clearCompleted(in: .all)
        #expect(store.openTasks(in: .all).map(\.title) == ["Open"])
        #expect(store.completedTasks(in: .all).isEmpty)
    }

    @Test func deletingProjectRemovesTasks() throws {
        let project = try #require(store.createProject(named: "Home"))
        store.addTask("One", to: .project(project.id))
        store.delete(project)
        #expect(store.projects().isEmpty)
        #expect(try store.context.fetchCount(FetchDescriptor<TaskItem>()) == 0)
    }

    @Test func listsSurviveStorage() {
        let id = UUID()
        for list in [TaskList.today, .all, .project(id)] {
            #expect(TaskList(storageValue: list.storageValue) == list)
        }
        #expect(TaskList(storageValue: "inbox") == .all)
        #expect(TaskList(storageValue: "garbage") == .today)
    }

    @Test func orderingFillsGaps() {
        #expect(Ordering.orders(count: 1, between: 1, and: 2) == [1.5])
        #expect(Ordering.orders(count: 2, between: nil, and: 0) == [-2, -1])
        #expect(Ordering.orders(count: 2, between: 3, and: nil) == [4, 5])
        #expect(Ordering.orders(count: 3, between: nil, and: nil) == [0, 1, 2])
    }
}

@MainActor
struct ProjectColorTests {
    @Test func duplicateColorsGetFreeOnes() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        for (index, name) in ["A", "B", "C"].enumerated() {
            context.insert(Project(name: name, order: Double(index), colorHex: "#0A84FF"))
        }
        try context.save()
        let store = TaskStore(context: context)

        store.assignDistinctColors()

        let colors = store.projects().map(\.colorHex)
        #expect(colors == ["#0A84FF", "#FF9F0A", "#30D158"])
        #expect(Set(colors).count == 3)
    }

    @Test func distinctColorsStayUntouched() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let store = TaskStore(context: container.mainContext)
        let home = try #require(store.createProject(named: "Home"))
        let work = try #require(store.createProject(named: "Work"))
        store.setColor(work, to: "#FFD60A")

        store.assignDistinctColors()

        #expect(home.colorHex == "#0A84FF")
        #expect(work.colorHex == "#FFD60A")
    }
}
