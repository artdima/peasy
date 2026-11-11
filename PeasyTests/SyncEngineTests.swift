import Foundation
import Testing
@testable import Peasy

struct SyncEngineTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let taskKey = RecordKey(entity: .task, id: UUID())
    let projectKey = RecordKey(entity: .project, id: UUID())

    private func engine(_ device: String) -> SyncEngine {
        var state = SyncState()
        state.device = device
        return SyncEngine(state: state)
    }

    private func applying(_ changes: LocalChanges, to store: StoreSnapshot) -> StoreSnapshot {
        var store = store
        for key in changes.deletions {
            store[key] = nil
        }
        for (key, fields) in changes.upserts {
            store[key] = fields
        }
        return store
    }

    @Test func captureSendsNewRecordsAndThenOnlyWhatChanged() {
        var a = engine("A")
        var store: StoreSnapshot = [taskKey: ["title": .text("Milk"), "done": .bool(false)]]
        #expect(a.capture(store, deletedLocally: false, now: start).operations.count == 2)

        store[taskKey]?["done"] = .bool(true)
        let second = a.capture(store, deletedLocally: false, now: start)
        #expect(second.operations.map(\.field) == ["done"])
        #expect(a.capture(store, deletedLocally: false, now: start).operations.isEmpty)
    }

    @Test func editsToDifferentFieldsBothSurvive() {
        var a = engine("A")
        var b = engine("B")
        var storeA: StoreSnapshot = [taskKey: ["title": .text("Call"), "done": .bool(false)]]
        var storeB = applying(b.merge(a.capture(storeA, deletedLocally: false, now: start).operations), to: [:])

        storeA[taskKey]?["title"] = .text("Call mom")
        storeB[taskKey]?["done"] = .bool(true)
        let fromA = a.capture(storeA, deletedLocally: false, now: start.addingTimeInterval(1)).operations
        let fromB = b.capture(storeB, deletedLocally: false, now: start.addingTimeInterval(2)).operations
        storeA = applying(a.merge(fromB), to: storeA)
        storeB = applying(b.merge(fromA), to: storeB)

        let expected: [String: FieldValue] = ["title": .text("Call mom"), "done": .bool(true)]
        #expect(storeA[taskKey] == expected)
        #expect(storeB[taskKey] == expected)
    }

    @Test func laterEditWinsInAnyOrder() {
        var a = engine("A")
        var b = engine("B")
        var c = engine("C")
        var d = engine("D")
        let base: StoreSnapshot = [taskKey: ["title": .text("Draft")]]
        let created = a.capture(base, deletedLocally: false, now: start).operations

        var storeB = applying(b.merge(created), to: [:])
        storeB[taskKey]?["title"] = .text("Older")
        let older = b.capture(storeB, deletedLocally: false, now: start.addingTimeInterval(5)).operations
        var storeA = base
        storeA[taskKey]?["title"] = .text("Newer")
        let newer = a.capture(storeA, deletedLocally: false, now: start.addingTimeInterval(10)).operations

        let forward = applying(c.merge(created + older + newer), to: [:])
        let backward = applying(d.merge(newer + older + created), to: [:])
        #expect(forward[taskKey]?["title"] == .text("Newer"))
        #expect(backward[taskKey]?["title"] == .text("Newer"))
    }

    @Test func deletionWinsOverAConcurrentEdit() {
        var a = engine("A")
        var b = engine("B")
        let created = a.capture([taskKey: ["title": .text("Old")]], deletedLocally: false, now: start).operations
        var storeB = applying(b.merge(created), to: [:])

        let deleted = a.capture([:], deletedLocally: true, now: start.addingTimeInterval(1)).operations
        storeB[taskKey]?["title"] = .text("Edited later")
        let edited = b.capture(storeB, deletedLocally: false, now: start.addingTimeInterval(9)).operations

        storeB = applying(b.merge(deleted), to: storeB)
        #expect(storeB[taskKey] == nil)
        #expect(a.merge(edited).isEmpty)
    }

    @Test func mergingTwiceChangesNothingAndSendsNothingBack() {
        var a = engine("A")
        var b = engine("B")
        let operations = a.capture([taskKey: ["title": .text("Once")]], deletedLocally: false, now: start).operations
        let store = applying(b.merge(operations), to: [:])

        #expect(b.merge(operations).isEmpty)
        #expect(b.capture(store, deletedLocally: false, now: start).operations.isEmpty)
    }

    @Test func clockStaysAheadOfAMacThatRunsFast() {
        var a = engine("A")
        var b = engine("B")
        let remote = b.capture([taskKey: ["title": .text("From the future")]], deletedLocally: false, now: start.addingTimeInterval(3600)).operations
        _ = a.merge(remote)
        let local = a.capture([taskKey: ["title": .text("Now")]], deletedLocally: false, now: start).operations

        #expect(!local.isEmpty)
        #expect(local.allSatisfy { mine in remote.allSatisfy { mine.stamp > $0.stamp } })
    }

    @Test func emptiedStoreIsRefilledInsteadOfDeletedEverywhere() {
        var a = engine("A")
        let store: StoreSnapshot = [projectKey: ["name": .text("Home")], taskKey: ["title": .text("Milk")]]
        _ = a.capture(store, deletedLocally: false, now: start)

        let wiped = a.capture([:], deletedLocally: false, now: start)
        #expect(wiped.operations.isEmpty)
        #expect(applying(wiped.restore, to: [:]) == store)
    }

    @Test func recordDeletedElsewhereIsRemovedWhenItComesBack() {
        var a = engine("A")
        let store: StoreSnapshot = [taskKey: ["title": .text("Gone")]]
        _ = a.capture(store, deletedLocally: false, now: start)
        _ = a.merge([.deletion(of: taskKey, stamp: SyncStamp(millis: 1_900_000_000_000, counter: 0, device: "B"))])

        let again = a.capture(store, deletedLocally: false, now: start)
        #expect(again.operations.isEmpty)
        #expect(again.restore.deletions == [taskKey])
    }

    @Test func deletingAProjectTakesItsTasks() {
        var a = engine("A")
        var b = engine("B")
        let store: StoreSnapshot = [
            projectKey: ["name": .text("Home")],
            taskKey: ["title": .text("Milk"), SyncField.project: .uuid(projectKey.id)],
        ]
        _ = b.merge(a.capture(store, deletedLocally: false, now: start).operations)

        let changes = b.merge([.deletion(of: projectKey, stamp: SyncStamp(millis: 1_900_000_000_000, counter: 0, device: "A"))])
        #expect(changes.deletions == [projectKey, taskKey])
        #expect(changes.upserts.isEmpty)
    }

    @Test func taskArrivingBeforeItsProjectIsLinkedLater() {
        var a = engine("A")
        var b = engine("B")
        let store: StoreSnapshot = [
            projectKey: ["name": .text("Home")],
            taskKey: ["title": .text("Milk"), SyncField.project: .uuid(projectKey.id)],
        ]
        let operations = a.capture(store, deletedLocally: false, now: start).operations

        var storeB = applying(b.merge(operations.filter { $0.key == taskKey }), to: [:])
        storeB[taskKey]?[SyncField.project] = .null
        #expect(b.capture(storeB, deletedLocally: false, now: start).operations.isEmpty)

        let linked = b.merge(operations.filter { $0.key == projectKey })
        #expect(linked.upserts[taskKey]?[SyncField.project] == .uuid(projectKey.id))
    }

    @Test func snapshotRebuildsTheSameState() {
        var a = engine("A")
        var b = engine("B")
        let project: StoreSnapshot = [projectKey: ["name": .text("Home")]]
        _ = a.capture(project.merging([taskKey: ["title": .text("Milk")]]) { first, _ in first }, deletedLocally: false, now: start)
        _ = a.capture(project, deletedLocally: true, now: start)

        let rebuilt = b.merge(a.snapshotOperations())
        #expect(applying(rebuilt, to: [:]) == project)
        #expect(b.state.tombstones[taskKey] != nil)
    }

    @Test func operationsRoundTripThroughTheJournal() throws {
        let stamp = SyncStamp(millis: 1_800_000_000_123, counter: 7, device: "9F1C-AB")
        #expect(SyncStamp(text: stamp.text) == stamp)
        #expect(SyncStamp(millis: 1, counter: 0, device: "Z") < SyncStamp(millis: 1, counter: 1, device: "A"))

        for value in [FieldValue.null, .bool(true), .number(0), .number(783_456_789.125), .text("1")] {
            let operation = SyncOperation(key: taskKey, field: "date", value: value, stamp: stamp)
            let decoded = try JSONDecoder().decode(SyncOperation.self, from: JSONEncoder().encode(operation))
            #expect(decoded == operation)
        }
    }

    @Test func fieldANewVersionAddsKeepsAValueSetOnAnotherMac() {
        var a = engine("A")
        var b = engine("B")
        let created = a.capture([taskKey: ["title": .text("Ship")]], deletedLocally: false, now: start).operations
        var storeB = applying(b.merge(created), to: [:])

        let assigned = a.capture(
            [taskKey: ["title": .text("Ship"), "assignee": .text("claude")]],
            deletedLocally: false,
            now: start.addingTimeInterval(1)
        ).operations
        storeB[taskKey]?["assignee"] = .text("")
        #expect(b.capture(storeB, deletedLocally: false, now: start.addingTimeInterval(2)).operations.isEmpty)

        storeB = applying(b.merge(assigned), to: storeB)
        #expect(storeB[taskKey]?["assignee"] == .text("claude"))
    }
}
