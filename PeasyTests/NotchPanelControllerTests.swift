import AppKit
import SwiftData
import Testing
@testable import Peasy

@MainActor
@Suite(.serialized)
struct NotchPanelControllerTests {
    @Test func panelSurvivesExpandingAndGrowingContent() async throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let model = NotchViewModel()
        let actions = NotchActions(showAbout: {}, openSettings: {}, quit: {})
        let controller = NotchPanelController(model: model, actions: actions, modelContainer: container)

        controller.setExpanded(true)
        try await Task.sleep(for: .milliseconds(600))

        let store = TaskStore(context: container.mainContext)
        let project = try #require(store.createProject(named: "Home"))
        for index in 1...6 {
            store.addTask("Task \(index)", to: project)
            try await Task.sleep(for: .milliseconds(150))
        }
        try await Task.sleep(for: .milliseconds(600))
        #expect(model.isExpanded)
        #expect(model.contentSize.height > 120)

        controller.setExpanded(false)
        try await Task.sleep(for: .milliseconds(800))
        #expect(!model.isExpanded)
        withExtendedLifetime(controller) {}
    }
}
