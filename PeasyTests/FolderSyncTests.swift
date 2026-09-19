import Foundation
import SwiftData
import Testing
@testable import Peasy

@MainActor
@Suite(.serialized)
struct FolderSyncTests {
    struct Mac {
        let sync: FolderSync
        let store: TaskStore
        let container: ModelContainer
    }

    let folder = FileManager.default.temporaryDirectory.appending(path: "PeasySync-\(UUID().uuidString)", directoryHint: .isDirectory)

    private func makeMac(_ device: String) throws -> Mac {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let container = try Persistence.makeContainer(inMemory: true)
        let state = FileManager.default.temporaryDirectory.appending(path: "PeasySyncState-\(device)-\(UUID().uuidString).json")
        let defaults = try #require(UserDefaults(suiteName: "PeasySyncTests-\(device)"))
        let sync = FolderSync(defaults: defaults, stateURL: state, device: device)
        sync.attach(container)
        sync.activate(folder)
        return Mac(sync: sync, store: TaskStore(context: container.mainContext), container: container)
    }

    @Test func tasksTravelBetweenMacs() async throws {
        let a = try makeMac("A")
        let b = try makeMac("B")
        let home = try #require(a.store.createProject(named: "Home"))
        let milk = try #require(a.store.addTask("Milk", project: home, isToday: true))
        await a.sync.syncNow()
        await b.sync.syncNow()

        let copy = try #require(b.store.allTasks().first { $0.id == milk.id })
        #expect(copy.title == "Milk")
        #expect(copy.project?.name == "Home")
        #expect(copy.date == milk.date)
        #expect(b.sync.peers.map(\.id) == ["A"])

        b.store.rename(copy, to: "Oat milk")
        await b.sync.syncNow()
        await a.sync.syncNow()
        #expect(milk.title == "Oat milk")

        a.store.delete(milk)
        await a.sync.syncNow()
        await b.sync.syncNow()
        #expect(b.store.allTasks().isEmpty)
        #expect(b.store.projects().map(\.name) == ["Home"])
    }

    @Test func editsOnBothMacsMerge() async throws {
        let a = try makeMac("A")
        let b = try makeMac("B")
        let task = try #require(a.store.addTask("Call mom", to: .all))
        await a.sync.syncNow()
        await b.sync.syncNow()
        let copy = try #require(b.store.allTasks().first)

        a.store.rename(task, to: "Call mom tonight")
        b.store.toggle(copy)
        await a.sync.syncNow()
        await b.sync.syncNow()
        await a.sync.syncNow()

        #expect(task.title == "Call mom tonight")
        #expect(task.isDone)
        #expect(copy.title == "Call mom tonight")
        #expect(copy.isDone)
    }

    @Test func wipedStoreIsRefilledFromWhatWasSynced() async throws {
        let a = try makeMac("A")
        let task = try #require(a.store.addTask("Keep me", to: .all))
        await a.sync.syncNow()

        let wiped = try Persistence.makeContainer(inMemory: true)
        a.sync.detach()
        a.sync.attach(wiped)
        SyncLedger.hasLocalDeletions = false
        await a.sync.syncNow()

        #expect(TaskStore(context: wiped.mainContext).allTasks().map(\.title) == [task.title])
    }

    @Test func secondMacOnTheSameICloudAccountPauses() async throws {
        let a = try makeMac("A")
        let b = try makeMac("B")
        a.sync.cloudAccount = .known("account")
        b.sync.cloudAccount = .known("account")
        await a.sync.syncNow()
        await b.sync.syncNow()

        guard case .paused = b.sync.status else {
            Issue.record("Expected B to pause, got \(b.sync.status)")
            return
        }
        guard case .idle = a.sync.status else {
            Issue.record("Expected A to keep syncing, got \(a.sync.status)")
            return
        }
    }
}
