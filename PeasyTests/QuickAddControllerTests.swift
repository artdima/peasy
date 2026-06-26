import AppKit
import SwiftData
import Testing
@testable import Peasy

@MainActor
@Suite(.serialized)
struct QuickAddControllerTests {
    @Test func toggleShowsAndHidesThePanel() async throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let model = NotchViewModel()
        let controller = QuickAddController(modelContainer: container, notchModel: model)

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

    @Test func cloudShowsBelowThePill() async throws {
        let cloud = CloudWindow()
        let pill = CGRect(x: 600, y: 900, width: 300, height: 32)
        cloud.show(title: "Подготовить релиз 2.4", colorHex: "#0A84FF", below: pill)
        try await Task.sleep(for: .milliseconds(300))
        #expect(cloud.isVisible)
        let panel = try #require(NSApp.windows.first { $0.ignoresMouseEvents && $0.level == .statusBar && $0.isVisible })
        #expect(panel.frame.width > 100 && panel.frame.height > 40)
        #expect(panel.frame.maxY <= pill.minY + 24)
        cloud.hide()
        try await Task.sleep(for: .milliseconds(300))
        #expect(!cloud.isVisible)
    }
}
