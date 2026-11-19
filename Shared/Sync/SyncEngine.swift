import Foundation

typealias StoreSnapshot = [RecordKey: [String: FieldValue]]

nonisolated struct SyncEntry: Hashable, Codable, Sendable {
    var value: FieldValue
    var stamp: SyncStamp
}

nonisolated struct SyncCursor: Hashable, Codable, Sendable {
    var generation: Int
    var offset: Int
}

/// What this Mac last agreed on with the folder: every field with the stamp of its
/// winning write, the deleted records, how far other Macs' journals were read and
/// what is still waiting to be written.
nonisolated struct SyncState: Codable, Sendable {
    var device = UUID().uuidString
    var fields: [RecordKey: [String: SyncEntry]] = [:]
    var tombstones: [RecordKey: SyncStamp] = [:]
    var lastStamp: SyncStamp?
    var folderPath: String?
    var cursors: [String: SyncCursor] = [:]
    var generation = 0
    var journalLines = 0
    var needsSnapshot = true
    var outbox: [SyncOperation] = []
}

nonisolated struct LocalChanges: Equatable, Sendable {
    /// Every field of each record to create or update.
    var upserts: StoreSnapshot = [:]
    var deletions: Set<RecordKey> = []

    var isEmpty: Bool {
        upserts.isEmpty && deletions.isEmpty
    }

    func merging(_ other: LocalChanges) -> LocalChanges {
        var result = self
        result.upserts.merge(other.upserts) { _, newer in newer }
        result.deletions.formUnion(other.deletions)
        for key in result.deletions {
            result.upserts[key] = nil
        }
        return result
    }
}

nonisolated struct CaptureResult: Sendable {
    var operations: [SyncOperation] = []
    /// Records to put back or remove again so the store matches what was agreed.
    var restore = LocalChanges()
}

/// Last writer wins per field, deletion wins over edits.
nonisolated struct SyncEngine {
    var state: SyncState
    private var clock: SyncClock

    init(state: SyncState) {
        self.state = state
        clock = SyncClock(device: state.device, last: state.lastStamp)
    }

    /// Compares the store with what was agreed and stamps every difference now.
    mutating func capture(_ snapshot: StoreSnapshot, deletedLocally: Bool, now: Date = .now) -> CaptureResult {
        var result = CaptureResult()
        let tombstones = state.tombstones
        let present = snapshot.filter { tombstones[$0.key] == nil }
        result.restore.deletions = Set(snapshot.keys.filter { tombstones[$0] != nil })

        let missing = state.fields.keys.filter { present[$0] == nil }.sorted()
        // An empty store nobody emptied by hand was wiped, by an iCloud account switch for one.
        if present.isEmpty, !missing.isEmpty, !deletedLocally {
            for key in missing {
                result.restore.upserts[key] = state.fields[key]?.mapValues(\.value)
            }
        } else {
            for key in missing {
                let stamp = clock.tick(now: now)
                result.operations.append(.deletion(of: key, stamp: stamp))
                state.tombstones[key] = stamp
                state.fields[key] = nil
            }
        }

        for key in present.keys.sorted() {
            guard let fields = present[key] else { continue }
            let isKnownRecord = state.fields[key] != nil
            var known = state.fields[key] ?? [:]
            for name in fields.keys.sorted() {
                guard let value = fields[name], known[name]?.value != value else { continue }
                if isKnownRecord, known[name] == nil, value.isEmpty {
                    continue
                }
                if isUnresolvedLink(key: key, field: name, value: value, known: known[name]?.value, snapshot: snapshot) {
                    continue
                }
                let stamp = clock.tick(now: now)
                result.operations.append(SyncOperation(key: key, field: name, value: value, stamp: stamp))
                known[name] = SyncEntry(value: value, stamp: stamp)
            }
            state.fields[key] = known
        }
        state.lastStamp = clock.last
        return result
    }

    /// Applies other Macs' operations and returns what the store has to change.
    mutating func merge(_ operations: [SyncOperation]) -> LocalChanges {
        var changes = LocalChanges()
        var touched: Set<RecordKey> = []
        for operation in operations {
            clock.observe(operation.stamp)
            let key = operation.key
            guard state.tombstones[key] == nil else { continue }

            if operation.field == SyncField.deleted {
                var doomed = [key]
                if key.entity == .project {
                    doomed += tasks(linkedTo: key.id)
                }
                for record in doomed {
                    state.tombstones[record] = operation.stamp
                    state.fields[record] = nil
                    changes.deletions.insert(record)
                    touched.remove(record)
                }
                continue
            }

            let isNew = state.fields[key] == nil
            var known = state.fields[key] ?? [:]
            if let entry = known[operation.field], entry.stamp >= operation.stamp {
                continue
            }
            known[operation.field] = SyncEntry(value: operation.value, stamp: operation.stamp)
            state.fields[key] = known
            touched.insert(key)
            if isNew, key.entity == .project {
                touched.formUnion(tasks(linkedTo: key.id))
            }
        }
        for key in touched {
            changes.upserts[key] = state.fields[key]?.mapValues(\.value)
        }
        state.lastStamp = clock.last
        return changes
    }

    /// The whole agreed state, for a Mac that reads this one from scratch.
    func snapshotOperations() -> [SyncOperation] {
        var operations: [SyncOperation] = []
        for key in state.fields.keys.sorted() {
            guard let fields = state.fields[key] else { continue }
            for name in fields.keys.sorted() {
                guard let entry = fields[name] else { continue }
                operations.append(SyncOperation(key: key, field: name, value: entry.value, stamp: entry.stamp))
            }
        }
        for key in state.tombstones.keys.sorted() {
            guard let stamp = state.tombstones[key] else { continue }
            operations.append(.deletion(of: key, stamp: stamp))
        }
        return operations
    }

    /// A Mac away for longer than this could bring a deleted record back.
    mutating func forgetTombstones(before date: Date) {
        let limit = Int64(date.timeIntervalSince1970 * 1000)
        state.tombstones = state.tombstones.filter { $0.value.millis >= limit }
    }

    private func tasks(linkedTo project: UUID) -> [RecordKey] {
        let link = FieldValue.uuid(project)
        return state.fields.compactMap { key, fields in
            key.entity == .task && fields[SyncField.project]?.value == link ? key : nil
        }
    }

    /// A task can arrive before its project; until the project exists the store shows no link.
    private func isUnresolvedLink(key: RecordKey, field: String, value: FieldValue, known: FieldValue?, snapshot: StoreSnapshot) -> Bool {
        guard key.entity == .task, field == SyncField.project, value == .null,
              let project = known?.uuidValue
        else { return false }
        return snapshot[RecordKey(entity: .project, id: project)] == nil
    }
}
