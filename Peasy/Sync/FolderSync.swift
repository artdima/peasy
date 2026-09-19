import AppKit
import CloudKit
import CryptoKit
import Observation
import SwiftData

enum FolderSyncStatus: Equatable {
    case off
    case waiting
    case idle(Date)
    /// Another Mac already carries this iCloud account to the folder.
    case paused(String)
    case failed(String)
    case noAccess
}

enum CloudAccount: Equatable {
    case none
    case pending
    case known(String)
    case unknown

    var id: String? {
        switch self {
        case .known(let id): id
        default: nil
        }
    }
}

struct SyncPeer: Equatable, Identifiable {
    let id: String
    let name: String
    let lastSeen: Date
}

/// Syncs tasks through a folder that Dropbox, Yandex Disk, Google Drive, Syncthing or a
/// network share keeps in sync, for Macs that can't share an iCloud account.
@Observable
final class FolderSync {
    static let bookmarkKey = "folderSyncBookmark"
    static let pollInterval: TimeInterval = 15
    static let compactionThreshold = 500
    static let heartbeat: TimeInterval = 6 * 3600
    static let peerLifetime: TimeInterval = 14 * 24 * 3600
    static let tombstoneLifetime: TimeInterval = 90 * 24 * 3600

    private(set) var status: FolderSyncStatus = .off
    private(set) var folderName: String?
    private(set) var peers: [SyncPeer] = []
    var cloudAccount: CloudAccount = .none

    var isOn: Bool {
        status != .off
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let stateURL: URL
    @ObservationIgnored private var state: SyncState
    @ObservationIgnored private var folder: SyncFolder?
    @ObservationIgnored private var container: ModelContainer?
    @ObservationIgnored private var scopedURL: URL?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var pendingSync: Task<Void, Never>?
    @ObservationIgnored private var isRunning = false
    @ObservationIgnored private var needsRerun = false
    @ObservationIgnored private var waiters: [CheckedContinuation<Void, Never>] = []

    init(defaults: UserDefaults = .standard, stateURL: URL = FolderSync.defaultStateURL, device: String? = nil) {
        self.defaults = defaults
        self.stateURL = stateURL
        var state = Self.loadState(from: stateURL)
        if let device {
            state.device = device
        }
        self.state = state
    }

    static var defaultStateURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "Peasy", directoryHint: .isDirectory)
            .appending(path: "FolderSync.json")
    }

    // MARK: - Lifecycle

    /// Reopens the saved folder and starts checking it for other Macs' changes.
    func start() {
        if let url = resolveBookmark() {
            activate(url)
        }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scheduleSync(after: .zero)
            }
        }
    }

    func attach(_ container: ModelContainer) {
        self.container = container
        scheduleSync(after: .zero)
    }

    func detach() {
        pendingSync?.cancel()
        pendingSync = nil
        container = nil
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "Sync Here")
        panel.message = String(localized: "Choose a folder that Dropbox, Yandex Disk, Google Drive or another service keeps in sync. On your other Macs, choose the same folder.")
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            defaults.set(bookmark, forKey: Self.bookmarkKey)
        } catch {
            status = .failed(error.localizedDescription)
            return
        }
        activate(url)
    }

    /// Starts syncing through `url`, or through its `Peasy` subfolder when it isn't one already.
    func activate(_ url: URL) {
        stopAccessing()
        if url.startAccessingSecurityScopedResource() {
            scopedURL = url
        }
        let root = Self.root(for: url)
        if state.folderPath != root.path {
            state.folderPath = root.path
            state.cursors = [:]
            state.generation = 0
            state.journalLines = 0
            state.outbox = []
            state.needsSnapshot = true
            saveState()
        }
        folder = SyncFolder(root: root, device: state.device)
        folderName = Self.displayName(of: url)
        status = .waiting
        scheduleSync(after: .zero)
    }

    func turnOff() {
        pendingSync?.cancel()
        pendingSync = nil
        folder = nil
        stopAccessing()
        defaults.removeObject(forKey: Self.bookmarkKey)
        state.folderPath = nil
        state.cursors = [:]
        state.outbox = []
        saveState()
        folderName = nil
        peers = []
        status = .off
    }

    // MARK: - Syncing

    func scheduleSync(after delay: Duration = .seconds(1)) {
        guard folder != nil, container != nil else { return }
        pendingSync?.cancel()
        pendingSync = Task { [weak self] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled, let self else { return }
            self.pendingSync = nil
            await self.syncNow()
        }
    }

    /// Returns once a full pass has run after the call, even if one was already running.
    func syncNow() async {
        guard folder != nil, container != nil else { return }
        if isRunning {
            needsRerun = true
            await withCheckedContinuation { continuation in
                self.waiters.append(continuation)
            }
            return
        }
        isRunning = true
        repeat {
            needsRerun = false
            await runPass()
        } while needsRerun
        isRunning = false
        let finished = waiters
        waiters.removeAll()
        finished.forEach { $0.resume() }
    }

    /// Reads first, then captures, merges and applies in one turn of the main actor so
    /// no edit slips in between, then writes.
    private func runPass() async {
        guard let folder, let container, cloudAccount != .pending else { return }
        let context = container.mainContext
        do {
            try await publishManifest(to: folder)
            let manifests = try await folder.manifests()
            guard isCurrent(folder, container) else { return }
            let others = manifests.filter { $0.device != state.device }
            peers = others
                .map { SyncPeer(id: $0.device, name: $0.name, lastSeen: $0.updated) }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            if let bridge = bridgingPeer(in: others) {
                status = .paused(bridge.name)
                return
            }

            var batches: [(device: String, batch: SyncBatch)] = []
            for manifest in others {
                if let batch = try await folder.read(from: manifest, after: state.cursors[manifest.device]) {
                    batches.append((manifest.device, batch))
                }
            }
            guard isCurrent(folder, container) else { return }

            var engine = SyncEngine(state: state)
            let captured = engine.capture(StoreBridge.snapshot(of: context), deletedLocally: SyncLedger.hasLocalDeletions)
            SyncLedger.hasLocalDeletions = false
            let merged = engine.merge(batches.flatMap { $0.batch.operations })
            StoreBridge.apply(captured.restore.merging(merged), to: context)
            engine.state.outbox.append(contentsOf: captured.operations)
            for (device, batch) in batches {
                engine.state.cursors[device] = batch.cursor
            }
            state = engine.state
            if !captured.operations.isEmpty || !captured.restore.isEmpty || !batches.isEmpty {
                saveState()
            }

            if !state.outbox.isEmpty {
                let outbox = state.outbox
                try await folder.append(outbox, generation: state.generation)
                guard isCurrent(folder, container) else { return }
                state.outbox.removeFirst(min(outbox.count, state.outbox.count))
                state.journalLines += outbox.count
                saveState()
            }

            if state.needsSnapshot || state.journalLines >= Self.compactionThreshold {
                var compacted = SyncEngine(state: state)
                compacted.forgetTombstones(before: .now.addingTimeInterval(-Self.tombstoneLifetime))
                let generation = state.generation + 1
                try await folder.compact(compacted.snapshotOperations(), manifest: manifest(generation: generation))
                guard isCurrent(folder, container) else { return }
                state.tombstones = compacted.state.tombstones
                state.generation = generation
                state.journalLines = 0
                state.needsSnapshot = false
                saveState()
            }
            status = .idle(.now)
        } catch {
            guard isCurrent(folder, container) else { return }
            status = .failed(error.localizedDescription)
        }
    }

    /// Keeps this Mac's manifest in step with its generation, name and iCloud account,
    /// and starts over with a full snapshot when its directory went missing.
    private func publishManifest(to folder: SyncFolder) async throws {
        let own = try await folder.ownManifest()
        if let own, own.generation != state.generation {
            state.generation = max(own.generation, state.generation)
            state.journalLines = 0
            state.needsSnapshot = true
        } else if own == nil, state.generation > 0 || state.journalLines > 0 {
            state.generation = 0
            state.journalLines = 0
            state.needsSnapshot = true
        }
        let current = manifest(generation: state.generation)
        let isStale = own.map {
            $0.name != current.name || $0.generation != current.generation || $0.account != current.account
                || $0.updated < .now.addingTimeInterval(-Self.heartbeat)
        } ?? true
        if isStale {
            try await folder.write(current)
        }
    }

    private func manifest(generation: Int) -> SyncManifest {
        SyncManifest(device: state.device, name: Self.deviceName, generation: generation, account: cloudAccount.id, updated: .now)
    }

    /// Two Macs on one iCloud account would both import every task from the folder and
    /// each push its own copy to iCloud, so only the first of them syncs the folder.
    private func bridgingPeer(in others: [SyncManifest]) -> SyncManifest? {
        guard let account = cloudAccount.id else { return nil }
        let recent = Date.now.addingTimeInterval(-Self.peerLifetime)
        return others
            .filter { $0.account == account && $0.updated > recent && $0.device < state.device }
            .min { $0.device < $1.device }
    }

    private func isCurrent(_ folder: SyncFolder, _ container: ModelContainer) -> Bool {
        self.folder === folder && self.container === container
    }

    // MARK: - Storage

    private static func loadState(from url: URL) -> SyncState {
        guard let data = try? Data(contentsOf: url), let state = try? JSONDecoder().decode(SyncState.self, from: data) else {
            return SyncState()
        }
        return state
    }

    private func saveState() {
        do {
            try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(state).write(to: stateURL, options: .atomic)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func resolveBookmark() -> URL? {
        guard let bookmark = defaults.data(forKey: Self.bookmarkKey) else { return nil }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            status = .noAccess
            return nil
        }
        if isStale, url.startAccessingSecurityScopedResource() {
            if let fresh = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                defaults.set(fresh, forKey: Self.bookmarkKey)
            }
            url.stopAccessingSecurityScopedResource()
        }
        return url
    }

    private func stopAccessing() {
        scopedURL?.stopAccessingSecurityScopedResource()
        scopedURL = nil
    }

    private static func root(for url: URL) -> URL {
        let devices = url.appending(path: "devices", directoryHint: .isDirectory)
        if url.lastPathComponent == "Peasy" || FileManager.default.fileExists(atPath: devices.path) {
            return url
        }
        return url.appending(path: "Peasy", directoryHint: .isDirectory)
    }

    private static func displayName(of url: URL) -> String {
        let name = FileManager.default.displayName(atPath: url.path)
        let parent = url.deletingLastPathComponent()
        guard parent.path != "/" else { return name }
        return "\(FileManager.default.displayName(atPath: parent.path)) › \(name)"
    }

    private static let deviceName = Host.current().localizedName ?? "Mac"
}

extension FolderSync {
    /// Learns which iCloud account this Mac syncs through, so two Macs on one account
    /// don't both carry it to the folder.
    func refreshCloudAccount(isActive: Bool) {
        guard isActive else {
            cloudAccount = .none
            return
        }
        cloudAccount = .pending
        Task { [weak self] in
            let record = try? await CKContainer(identifier: CloudSync.containerIdentifier).userRecordID()
            guard let self else { return }
            self.cloudAccount = record.map { CloudAccount.known(Self.accountHash($0.recordName)) } ?? .unknown
            self.scheduleSync(after: .zero)
        }
    }

    static func accountHash(_ name: String) -> String {
        SHA256.hash(data: Data(name.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}
