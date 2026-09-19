import Foundation

nonisolated struct SyncManifest: Hashable, Codable, Sendable {
    var device: String
    var name: String
    var generation: Int
    /// A hash of the iCloud account this Mac syncs through, if any.
    var account: String?
    var updated: Date
}

nonisolated struct SyncBatch: Sendable {
    var operations: [SyncOperation]
    var cursor: SyncCursor
}

/// The shared folder. Every Mac writes only inside its own directory, so a sync
/// service never sees two Macs editing one file and never makes conflicted copies:
///
///     devices/<device>/manifest.json        name, generation, last seen
///     devices/<device>/snapshot-<n>.json    everything that Mac knew when it compacted
///     devices/<device>/journal-<n>.jsonl    operations since, one per line
actor SyncFolder {
    let root: URL
    let device: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(root: URL, device: String) {
        self.root = root
        self.device = device
    }

    func ownManifest() throws -> SyncManifest? {
        try manifest(of: device)
    }

    func write(_ manifest: SyncManifest) throws {
        try makeOwnDirectory()
        try replace(manifestURL(of: device), with: encoder.encode(manifest))
    }

    func manifests() throws -> [SyncManifest] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: devicesURL.path)) ?? []
        return names.filter { !$0.hasPrefix(".") }.compactMap { try? manifest(of: $0) }
    }

    func append(_ operations: [SyncOperation], generation: Int) throws {
        guard !operations.isEmpty else { return }
        var payload = Data()
        for operation in operations {
            payload.append(try encoder.encode(operation))
            payload.append(0x0A)
        }
        try makeOwnDirectory()
        let lines = payload
        try coordinate(writing: journalURL(of: device, generation: generation), options: .forMerging) { url in
            guard FileManager.default.fileExists(atPath: url.path) else {
                try lines.write(to: url)
                return
            }
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: lines)
        }
    }

    /// Starts generation `manifest.generation` from `operations` and drops older files.
    func compact(_ operations: [SyncOperation], manifest: SyncManifest) throws {
        let generation = manifest.generation
        try makeOwnDirectory()
        try replace(snapshotURL(of: device, generation: generation), with: encoder.encode(operations))
        try replace(journalURL(of: device, generation: generation), with: Data())
        try write(manifest)
        let own = directory(of: device)
        let keep: Set = ["manifest.json", "snapshot-\(generation).json", "journal-\(generation).jsonl"]
        let names = (try? FileManager.default.contentsOfDirectory(atPath: own.path)) ?? []
        for name in names where !keep.contains(name) && (name.hasPrefix("snapshot-") || name.hasPrefix("journal-")) {
            try? coordinate(writing: own.appending(path: name), options: .forDeleting) { url in
                try FileManager.default.removeItem(at: url)
            }
        }
    }

    /// Operations from another Mac after `cursor`, or nil when there is nothing new
    /// or its newest files have not arrived yet. Only complete lines are read.
    func read(from manifest: SyncManifest, after cursor: SyncCursor?) throws -> SyncBatch? {
        let generation = manifest.generation
        var operations: [SyncOperation] = []
        var offset = 0
        if let cursor, cursor.generation == generation {
            offset = cursor.offset
        } else if generation > 0 {
            guard let snapshot = try contents(of: snapshotURL(of: manifest.device, generation: generation)) else { return nil }
            operations = try decoder.decode([SyncOperation].self, from: snapshot)
        }

        let journal = journalURL(of: manifest.device, generation: generation)
        let size = (try? journal.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if size != offset, let data = try contents(of: journal) {
            if data.count < offset {
                offset = 0
            }
            if let newline = data.lastIndex(of: 0x0A), newline >= offset {
                for line in data[offset...newline].split(separator: 0x0A) {
                    if let operation = try? decoder.decode(SyncOperation.self, from: Data(line)) {
                        operations.append(operation)
                    }
                }
                offset = newline + 1
            }
        }

        let next = SyncCursor(generation: generation, offset: offset)
        if operations.isEmpty, next == cursor {
            return nil
        }
        return SyncBatch(operations: operations, cursor: next)
    }

    // MARK: - Files

    private var devicesURL: URL {
        root.appending(path: "devices", directoryHint: .isDirectory)
    }

    private func directory(of device: String) -> URL {
        devicesURL.appending(path: device, directoryHint: .isDirectory)
    }

    private func manifestURL(of device: String) -> URL {
        directory(of: device).appending(path: "manifest.json")
    }

    private func snapshotURL(of device: String, generation: Int) -> URL {
        directory(of: device).appending(path: "snapshot-\(generation).json")
    }

    private func journalURL(of device: String, generation: Int) -> URL {
        directory(of: device).appending(path: "journal-\(generation).jsonl")
    }

    private func makeOwnDirectory() throws {
        try FileManager.default.createDirectory(at: directory(of: device), withIntermediateDirectories: true)
    }

    private func manifest(of device: String) throws -> SyncManifest? {
        guard let data = try contents(of: manifestURL(of: device)) else { return nil }
        return try decoder.decode(SyncManifest.self, from: data)
    }

    /// Coordinated, so a sync service's placeholder is downloaded before it is read.
    private func contents(of url: URL) throws -> Data? {
        var result: Data?
        var failure: Error?
        var coordination: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordination) { url in
            do {
                result = try Data(contentsOf: url)
            } catch {
                failure = error
            }
        }
        if let error = coordination ?? failure {
            if isMissingFile(error) {
                return nil
            }
            throw error
        }
        return result
    }

    private func replace(_ url: URL, with data: Data) throws {
        try coordinate(writing: url, options: .forReplacing) { url in
            try data.write(to: url, options: .atomic)
        }
    }

    private func coordinate(writing url: URL, options: NSFileCoordinator.WritingOptions, _ body: (URL) throws -> Void) throws {
        var failure: Error?
        var coordination: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: options, error: &coordination) { url in
            do {
                try body(url)
            } catch {
                failure = error
            }
        }
        if let error = coordination ?? failure {
            throw error
        }
    }

    private func isMissingFile(_ error: Error) -> Bool {
        let error = error as NSError
        if error.domain == NSCocoaErrorDomain {
            return error.code == NSFileReadNoSuchFileError || error.code == NSFileNoSuchFileError
        }
        return error.domain == NSPOSIXErrorDomain && error.code == Int(ENOENT)
    }
}
