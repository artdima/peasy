import Foundation
import SwiftData
import Testing
@testable import Peasy

@MainActor
struct TaskLabelsTests {
    let container: ModelContainer
    let store: TaskStore

    init() throws {
        container = try Persistence.makeContainer(inMemory: true)
        store = TaskStore(context: container.mainContext)
    }

    @Test func ringShowsWhoHasTheTask() throws {
        let task = try #require(store.addTask("Ship", to: .all))
        #expect(task.ringMark == .own)
        store.assignToClaude(task)
        #expect(task.ringMark == .waiting)
        store.claim(task, by: "session", at: .now)
        #expect(task.ringMark == .working)
        store.toggle(task)
        #expect(task.ringMark == .own)
    }

    @Test func staleClaimWaitsForClaudeAgain() throws {
        let task = try #require(store.addTask("Ship", to: .all))
        store.assignToClaude(task)
        store.claim(task, by: "session", at: Date.now.addingTimeInterval(-TaskItem.claimLifetime - 60))
        #expect(task.ringMark == .waiting)
    }

    @Test func noteMarkShowsOnlyForClaude() throws {
        let plain = try #require(store.addTask("Plain", to: .all))
        #expect(plain.noteLabel == nil)
        store.setNote("Buy oat milk", for: plain)
        #expect(plain.noteLabel != nil)
        #expect(!plain.showsNoteMark)

        let asked = try #require(store.addTask("Pick a token", to: .all))
        store.assignToClaude(asked)
        store.handBack(asked, note: "Old token or new?", at: .now)
        #expect(asked.noteLabel != nil)
        #expect(asked.showsNoteMark)
    }

    @Test func agentLabelOnlyForOpenClaudeTasks() throws {
        let task = try #require(store.addTask("Ship", to: .all))
        #expect(task.agentLabel(now: .now) == nil)
        store.assignToClaude(task)
        #expect(task.agentLabel(now: .now) != nil)
        store.toggle(task)
        #expect(task.agentLabel(now: .now) == nil)
    }

    @Test func movingTaskChangesItsProject() throws {
        let home = try #require(store.createProject(named: "Home"))
        let task = try #require(store.addTask("Ship", to: .all))
        store.move(task, to: home)
        #expect(task.project?.id == home.id)
        #expect(store.tasks(in: .project(home.id)).map(\.id) == [task.id])
        store.move(task, to: nil)
        #expect(task.project == nil)
        #expect(store.tasks(in: .project(home.id)).isEmpty)
    }

    @Test func loneWebAddressBecomesTheLink() {
        let link = NoteOrLink.split("  https://github.com/artdima/peasy \n")
        #expect(link.note.isEmpty)
        #expect(link.link == "https://github.com/artdima/peasy")

        let note = NoteOrLink.split("see https://github.com/artdima/peasy")
        #expect(note.note == "see https://github.com/artdima/peasy")
        #expect(note.link.isEmpty)

        let file = NoteOrLink.split("file:///Users/dima/notes.md")
        #expect(file.note == "file:///Users/dima/notes.md")
        #expect(file.link.isEmpty)
    }

    @Test func hexColorsAreSRGB() throws {
        let color = try #require(PlatformColor(hex: "#3D5CCC").usingColorSpace(.sRGB))
        #expect(abs(color.redComponent - 0x3D / 255) < 0.001)
        #expect(abs(color.greenComponent - 0x5C / 255) < 0.001)
        #expect(abs(color.blueComponent - 0xCC / 255) < 0.001)
        #expect(PlatformColor(hex: "3D5CCC").usingColorSpace(.sRGB)?.blueComponent == color.blueComponent)
    }
}
