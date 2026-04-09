import SwiftData
import Testing
@testable import Peasy

@MainActor
@Suite(.serialized)
struct NotchControllerTests {
    @Test func panelSurvivesOpeningAndAddingTasks() async throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let model = NotchViewModel()
        let actions = NotchActions(showAbout: {}, openSettings: {}, quit: {})
        let controller = NotchController(model: model, actions: actions, modelContainer: container)
        defer { controller.shutdown() }

        controller.expand()
        try await Task.sleep(for: .milliseconds(600))
        #expect(controller.isExpanded)

        let store = TaskStore(context: container.mainContext)
        let project = try #require(store.createProject(named: "Home"))
        for index in 1...12 {
            store.addTask("Task \(index)", to: project)
            try await Task.sleep(for: .milliseconds(80))
        }
        try await Task.sleep(for: .milliseconds(400))
        #expect(controller.isExpanded)

        model.selectedTaskID = project.tasks?.first?.id
        controller.collapse()
        try await Task.sleep(for: .milliseconds(800))
        #expect(!controller.isExpanded)
        #expect(model.selectedTaskID == nil)
    }
}
