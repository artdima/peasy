import AppKit
import CoreGraphics
import Foundation
import SwiftData
import Testing
@testable import Peasy

@MainActor
@Suite(.serialized)
struct MenuBarControllerTests {
    @Test func panelSurvivesOpeningAndAddingTasks() async throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let model = PanelViewModel()
        let actions = PanelActions(showAbout: {}, openSettings: {}, quit: {})
        let controller = MenuBarController(model: model, actions: actions, modelContainer: container)
        defer { controller.shutdown() }

        controller.expand()
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
        let model = PanelViewModel()
        let actions = PanelActions(showAbout: {}, openSettings: {}, quit: {})
        let controller = MenuBarController(model: model, actions: actions, modelContainer: container)
        defer { controller.shutdown() }

        #expect(controller.expandedPanelSize == PanelLayout.current.panelSize)
        #expect(model.headerHeight > 0)
    }

    @Test func draggingResizesAndClampsThePanel() throws {
        let layout = PanelLayout.current
        let savedSize = layout.customSize(in: .standard)
        layout.resetSize()
        defer {
            if let savedSize { layout.saveSize(savedSize) } else { layout.resetSize() }
        }
        let container = try Persistence.makeContainer(inMemory: true)
        let model = PanelViewModel()
        let actions = PanelActions(showAbout: {}, openSettings: {}, quit: {})
        let controller = MenuBarController(model: model, actions: actions, modelContainer: container)
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

    @Test func foldingThePanelSavesTheEdit() async throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let model = PanelViewModel()
        let actions = PanelActions(showAbout: {}, openSettings: {}, quit: {})
        let controller = MenuBarController(model: model, actions: actions, modelContainer: container)
        defer { controller.shutdown() }
        let store = TaskStore(context: container.mainContext)
        let task = try #require(store.addTask("Draft", to: .all))

        model.startEditing(task)
        model.editingDraft = "Draft, edited"
        model.resetInteraction()

        #expect(task.title == "Draft, edited")
        #expect(model.editingTaskID == nil)

        model.startEditing(task)
        model.editingDraft = "Thrown away"
        model.cancelEditing()
        #expect(task.title == "Draft, edited")
    }

    @Test func panelSurvivesReloadingTheStore() async throws {
        let first = try Persistence.makeContainer(inMemory: true)
        let model = PanelViewModel()
        let actions = PanelActions(showAbout: {}, openSettings: {}, quit: {})
        let controller = MenuBarController(model: model, actions: actions, modelContainer: first)
        defer { controller.shutdown() }

        controller.unloadStore()
        await Task.yield()
        let second = try Persistence.makeContainer(inMemory: true)
        controller.loadStore(second)

        controller.expand()
        try await Task.sleep(for: .milliseconds(600))
        #expect(controller.isExpanded)

        let store = TaskStore(context: second.mainContext)
        #expect(store.addTask("After reload", to: .all) != nil)
        try await Task.sleep(for: .milliseconds(300))
        #expect(controller.isExpanded)
    }

    @Test func switchingToAnotherAppFoldsThePanel() async throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let model = PanelViewModel()
        let actions = PanelActions(showAbout: {}, openSettings: {}, quit: {})
        let controller = MenuBarController(model: model, actions: actions, modelContainer: container)
        defer { controller.shutdown() }
        let ownPID = NSRunningApplication.current.processIdentifier
        let other = try #require(NSWorkspace.shared.runningApplications.first { $0.processIdentifier != ownPID })
        func activate(_ app: NSRunningApplication) async throws {
            NSWorkspace.shared.notificationCenter.post(
                name: NSWorkspace.didActivateApplicationNotification,
                object: NSWorkspace.shared,
                userInfo: [NSWorkspace.applicationUserInfoKey: app]
            )
            try await Task.sleep(for: .milliseconds(150))
        }

        controller.expand()
        try await Task.sleep(for: .milliseconds(300))
        try await activate(.current)
        #expect(controller.isExpanded)

        try await activate(other)
        #expect(!controller.isExpanded)
    }
}
