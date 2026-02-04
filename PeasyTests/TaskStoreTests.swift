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

    @Test func projectsKeepCreationOrder() throws {
        store.createProject(named: "Home")
        store.createProject(named: "  Work  ")
        #expect(store.projects().map(\.name) == ["Home", "Work"])
    }

    @Test func emptyNamesAreIgnored() throws {
        #expect(store.createProject(named: "   ") == nil)
        let project = try #require(store.createProject(named: "Home"))
        #expect(store.addTask("\n", to: project) == nil)
        #expect(store.openTasks(in: project).isEmpty)
    }

    @Test func newTasksGoToTheEnd() throws {
        let project = try #require(store.createProject(named: "Home"))
        store.addTask("One", to: project)
        store.addTask("Two", to: project)
        store.addTask("Three", to: project)
        #expect(store.openTasks(in: project).map(\.title) == ["One", "Two", "Three"])
    }

    @Test func toggleMovesTaskToCompleted() throws {
        let project = try #require(store.createProject(named: "Home"))
        let task = try #require(store.addTask("One", to: project))
        store.toggle(task)
        #expect(task.isDone)
        #expect(task.completedAt != nil)
        #expect(store.openTasks(in: project).isEmpty)
        #expect(store.completedTasks(in: project).map(\.title) == ["One"])

        store.toggle(task)
        #expect(task.completedAt == nil)
    }

    @Test func movingTaskChangesOnlyItsOrder() throws {
        let project = try #require(store.createProject(named: "Home"))
        for title in ["A", "B", "C"] {
            store.addTask(title, to: project)
        }
        store.moveOpenTasks(in: project, from: IndexSet(integer: 2), to: 0)
        #expect(store.openTasks(in: project).map(\.title) == ["C", "A", "B"])

        store.moveOpenTasks(in: project, from: IndexSet(integer: 0), to: 2)
        #expect(store.openTasks(in: project).map(\.title) == ["A", "C", "B"])
    }

    @Test func repeatedMovesStayOrdered() throws {
        let project = try #require(store.createProject(named: "Home"))
        for title in ["A", "B", "C"] {
            store.addTask(title, to: project)
        }
        for _ in 0..<80 {
            store.moveOpenTasks(in: project, from: IndexSet(integer: 2), to: 1)
        }
        #expect(store.openTasks(in: project).count == 3)
        let orders = store.openTasks(in: project).map(\.order)
        #expect(orders == orders.sorted())
        #expect(Set(orders).count == 3)
    }

    @Test func clearCompletedKeepsOpenTasks() throws {
        let project = try #require(store.createProject(named: "Home"))
        let done = try #require(store.addTask("Done", to: project))
        store.addTask("Open", to: project)
        store.toggle(done)
        store.clearCompleted(in: project)
        #expect(store.openTasks(in: project).map(\.title) == ["Open"])
        #expect(store.completedTasks(in: project).isEmpty)
    }

    @Test func deletingProjectRemovesTasks() throws {
        let project = try #require(store.createProject(named: "Home"))
        store.addTask("One", to: project)
        store.delete(project)
        #expect(store.projects().isEmpty)
        #expect(try store.context.fetchCount(FetchDescriptor<TaskItem>()) == 0)
    }

    @Test func orderingFillsGaps() {
        #expect(Ordering.orders(count: 1, between: 1, and: 2) == [1.5])
        #expect(Ordering.orders(count: 2, between: nil, and: 0) == [-2, -1])
        #expect(Ordering.orders(count: 2, between: 3, and: nil) == [4, 5])
        #expect(Ordering.orders(count: 3, between: nil, and: nil) == [0, 1, 2])
    }
}
