import AppKit
import SwiftData
import Testing
@testable import Peasy

@MainActor
@Suite(.serialized)
struct QuickAddControllerTests {
    @Test func toggleShowsAndHidesThePanel() async throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let model = PanelViewModel()
        let controller = QuickAddController(modelContainer: container, panelModel: model)

        controller.toggle()
        try await Task.sleep(for: .milliseconds(400))
        let panel = try #require(NSApp.windows.first { $0 is QuickAddPanel })
        #expect(panel.isVisible)
        #expect(panel.alphaValue == 1)
        #expect(panel.frame.width > 500 && panel.frame.height > 100)
        let screen = try #require(NSScreen.main)
        #expect(screen.frame.intersects(panel.frame))
        print("quick add frame:", panel.frame, "screen:", screen.frame, "key:", panel.isKeyWindow)

        controller.toggle()
        try await Task.sleep(for: .milliseconds(400))
        #expect(!panel.isVisible)
    }
}
