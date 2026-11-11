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

    @Test func claimLastsTwoHoursWithoutAnUpdate() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let task = TaskItem(title: "Tests", order: 0)
        container.mainContext.insert(task)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        task.assignee = TaskItem.claude
        task.agentState = TaskItem.AgentState.working.rawValue
        task.claimedAt = now.addingTimeInterval(-60 * 60)
        #expect(task.isClaimed(now: now))

        task.claimedAt = now.addingTimeInterval(-3 * 60 * 60)
        #expect(!task.isClaimed(now: now))
    }
}

struct CloudKitSchemaTests {
    @Test func modelsFitCloudKit() {
        for entity in Persistence.schema.entities {
            for attribute in entity.attributes {
                #expect(attribute.isOptional || attribute.defaultValue != nil, "\(entity.name).\(attribute.name) needs a default")
                #expect(!attribute.isUnique, "\(entity.name).\(attribute.name) must not be unique")
            }
            for relationship in entity.relationships {
                #expect(relationship.isOptional, "\(entity.name).\(relationship.name) must be optional")
            }
        }
    }

    @Test func unsignedBuildStaysLocal() {
        #expect(!CloudSync.shouldSync)
    }
}
