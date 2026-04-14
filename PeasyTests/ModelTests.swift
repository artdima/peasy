import Foundation
import SwiftData
import Testing
@testable import Peasy

@MainActor
struct ModelTests {
    @Test func projectKeepsItsTasks() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let project = Project(name: "Home", order: 0, colorHex: ProjectPalette.colors[0])
        context.insert(project)
        for (index, title) in ["Buy milk", "Call mom"].enumerated() {
            let task = TaskItem(title: title, order: Double(index))
            context.insert(task)
            task.project = project
        }
        try context.save()

        #expect(project.tasks?.count == 2)
        #expect(try context.fetchCount(FetchDescriptor<TaskItem>()) == 2)
    }

    @Test func deletingProjectDeletesItsTasks() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let project = Project(name: "Home", order: 0, colorHex: ProjectPalette.colors[0])
        context.insert(project)
        let task = TaskItem(title: "Buy milk", order: 0)
        context.insert(task)
        task.project = project
        try context.save()

        context.delete(project)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Project>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<TaskItem>()) == 0)
    }
}
