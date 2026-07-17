import CoreGraphics
import Foundation
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
        model.isPinned = true
        try await Task.sleep(for: .milliseconds(600))
        #expect(controller.isExpanded)

        let store = TaskStore(context: container.mainContext)
        let project = try #require(store.createProject(named: "Home"))
        for index in 1...12 {
            store.addTask("Task \(index)", to: .project(project.id))
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

    @Test func panelBodyMatchesTheLayoutSize() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let model = NotchViewModel()
        let actions = NotchActions(showAbout: {}, openSettings: {}, quit: {})
        let controller = NotchController(model: model, actions: actions, modelContainer: container)
        defer { controller.shutdown() }

        #expect(controller.expandedPanelSize == PanelLayout.current.panelSize)
        #expect(model.headerHeight > 0)
    }

    @Test func draggingResizesAndClampsThePanel() throws {
        let layout = PanelLayout.current
        defer { layout.resetSize() }
        let container = try Persistence.makeContainer(inMemory: true)
        let model = NotchViewModel()
        let actions = NotchActions(showAbout: {}, openSettings: {}, quit: {})
        let controller = NotchController(model: model, actions: actions, modelContainer: container)
        defer { controller.shutdown() }

        model.onResize(CGSize(width: 760, height: 500), false)
        #expect(controller.expandedPanelSize == CGSize(width: 760, height: 500))
        #expect(!model.hasCustomSize)

        model.onResize(CGSize(width: 100, height: 100), true)
        #expect(controller.expandedPanelSize == layout.minimumSize)
        #expect(model.hasCustomSize)
        #expect(layout.panelSize == layout.minimumSize)

        model.onResetSize()
        #expect(controller.expandedPanelSize == layout.defaultSize)
        #expect(!model.hasCustomSize)
        #expect(layout.customSize(in: .standard) == nil)
    }

    @Test func panelSurvivesReloadingTheStore() async throws {
        let first = try Persistence.makeContainer(inMemory: true)
        let model = NotchViewModel()
        let actions = NotchActions(showAbout: {}, openSettings: {}, quit: {})
        let controller = NotchController(model: model, actions: actions, modelContainer: first)
        defer { controller.shutdown() }

        controller.unloadStore()
        await Task.yield()
        let second = try Persistence.makeContainer(inMemory: true)
        controller.loadStore(second)

        controller.expand()
        model.isPinned = true
        try await Task.sleep(for: .milliseconds(600))
        #expect(controller.isExpanded)

        let store = TaskStore(context: second.mainContext)
        #expect(store.addTask("After reload", to: .inbox) != nil)
        try await Task.sleep(for: .milliseconds(300))
        #expect(controller.isExpanded)
    }
}
