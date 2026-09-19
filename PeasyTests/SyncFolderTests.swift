import Foundation
import Testing
@testable import Peasy

struct SyncFolderTests {
    let root = FileManager.default.temporaryDirectory.appending(path: "PeasyFolder-\(UUID().uuidString)", directoryHint: .isDirectory)

    private func operation(_ title: String, _ millis: Int64) -> SyncOperation {
        SyncOperation(
            key: RecordKey(entity: .task, id: UUID()),
            field: "title",
            value: .text(title),
            stamp: SyncStamp(millis: millis, counter: 0, device: "A")
        )
    }

    private func manifest(generation: Int) -> SyncManifest {
        SyncManifest(device: "A", name: "Mac A", generation: generation, account: nil, updated: .now)
    }

    @Test func journalIsReadOnceAndThenFromWhereItStopped() async throws {
        let writer = SyncFolder(root: root, device: "A")
        let reader = SyncFolder(root: root, device: "B")
        try await writer.write(manifest(generation: 0))
        try await writer.append([operation("One", 1), operation("Two", 2)], generation: 0)

        let first = try #require(try await reader.read(from: manifest(generation: 0), after: nil))
        #expect(first.operations.map(\.value) == [.text("One"), .text("Two")])
        #expect(try await reader.read(from: manifest(generation: 0), after: first.cursor) == nil)

        try await writer.append([operation("Three", 3)], generation: 0)
        let second = try #require(try await reader.read(from: manifest(generation: 0), after: first.cursor))
        #expect(second.operations.map(\.value) == [.text("Three")])
        #expect(try await reader.manifests().map(\.name) == ["Mac A"])
    }

    @Test func halfWrittenLineWaitsForTheRest() async throws {
        let reader = SyncFolder(root: root, device: "B")
        let directory = root.appending(path: "devices/A", directoryHint: .isDirectory)
        let journal = directory.appending(path: "journal-0.jsonl")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let full = try JSONEncoder().encode(operation("Full", 1))
        let later = try JSONEncoder().encode(operation("Later", 2))
        var data = full
        data.append(0x0A)
        data.append(later.prefix(10))
        try data.write(to: journal)

        let batch = try #require(try await reader.read(from: manifest(generation: 0), after: nil))
        #expect(batch.operations.map(\.value) == [.text("Full")])

        var rest = Data(later.dropFirst(10))
        rest.append(0x0A)
        let handle = try FileHandle(forWritingTo: journal)
        try handle.seekToEnd()
        try handle.write(contentsOf: rest)
        try handle.close()

        let next = try #require(try await reader.read(from: manifest(generation: 0), after: batch.cursor))
        #expect(next.operations.map(\.value) == [.text("Later")])
    }

    @Test func compactionStartsANewGeneration() async throws {
        let writer = SyncFolder(root: root, device: "A")
        let reader = SyncFolder(root: root, device: "B")
        try await writer.write(manifest(generation: 0))
        try await writer.append([operation("Old", 1)], generation: 0)
        let early = try #require(try await reader.read(from: manifest(generation: 0), after: nil))

        try await writer.compact([operation("Snapshot", 2)], manifest: manifest(generation: 1))
        try await writer.append([operation("New", 3)], generation: 1)

        #expect(try await reader.manifests().map(\.generation) == [1])
        let batch = try #require(try await reader.read(from: manifest(generation: 1), after: early.cursor))
        #expect(batch.operations.map(\.value) == [.text("Snapshot"), .text("New")])
        let files = try FileManager.default.contentsOfDirectory(atPath: root.appending(path: "devices/A").path).sorted()
        #expect(files == ["journal-1.jsonl", "manifest.json", "snapshot-1.json"])
    }

    @Test func newGenerationWaitsForItsSnapshot() async throws {
        let reader = SyncFolder(root: root, device: "B")
        #expect(try await reader.read(from: manifest(generation: 3), after: nil) == nil)
    }
}
