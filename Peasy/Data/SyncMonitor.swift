import CloudKit
import CoreData
import Foundation
import Observation

enum SyncStatus: Equatable {
    case unavailable
    case off
    case noAccount
    case syncing
    case offline
    case failed
    case idle(lastSync: Date?)
}

enum SyncProblem: Equatable {
    case offline
    case noAccount
    case failed
}

enum SyncEventKind {
    case setup
    case `import`
    case export
}

@Observable
final class SyncMonitor {
    static let lastSyncKey = "lastSyncDate"

    let isAvailable: Bool
    private(set) var isEnabled: Bool
    private(set) var isAccountAvailable: Bool?
    private(set) var lastSync: Date?
    private(set) var problem: SyncProblem?
    private var runningEvents: Set<UUID> = []

    @ObservationIgnored var onStoreReloadNeeded: (() -> Void)?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init(isAvailable: Bool = CloudSync.isAvailable, defaults: UserDefaults = .standard) {
        self.isAvailable = isAvailable
        self.defaults = defaults
        isEnabled = CloudSync.isEnabled(in: defaults)
        lastSync = defaults.object(forKey: Self.lastSyncKey) as? Date
    }

    var isActive: Bool {
        isAvailable && isEnabled
    }

    var status: SyncStatus {
        guard isAvailable else { return .unavailable }
        guard isEnabled else { return .off }
        if isAccountAvailable == false || problem == .noAccount { return .noAccount }
        if !runningEvents.isEmpty { return .syncing }
        switch problem {
        case .offline: return .offline
        case .failed: return .failed
        default: return .idle(lastSync: lastSync)
        }
    }

    var canSyncNow: Bool {
        switch status {
        case .idle, .offline, .failed: true
        default: false
        }
    }

    func start() {
        guard isAvailable else { return }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handle(notification)
            }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshAccount()
            }
        })
        refreshAccount()
    }

    func setEnabled(_ enabled: Bool) {
        guard isAvailable, enabled != isEnabled else { return }
        isEnabled = enabled
        defaults.set(enabled, forKey: CloudSync.enabledKey)
        runningEvents.removeAll()
        problem = nil
        onStoreReloadNeeded?()
    }

    func syncNow() {
        guard canSyncNow else { return }
        problem = nil
        onStoreReloadNeeded?()
    }

    func storeFailed(_ error: Error) {
        problem = .failed
    }

    func record(_ id: UUID, kind: SyncEventKind, endDate: Date?, succeeded: Bool, error: Error?) {
        guard let endDate else {
            runningEvents.insert(id)
            return
        }
        runningEvents.remove(id)
        if succeeded {
            problem = nil
            if kind != .setup {
                lastSync = endDate
                defaults.set(endDate, forKey: Self.lastSyncKey)
            }
        } else if let error, let problem = Self.problem(for: error) {
            self.problem = problem
        }
    }

    func apply(accountStatus: CKAccountStatus?) {
        switch accountStatus {
        case .available:
            isAccountAvailable = true
            if problem == .noAccount { problem = nil }
        case .noAccount, .restricted, .temporarilyUnavailable:
            isAccountAvailable = false
        default:
            isAccountAvailable = nil
        }
    }

    static func problem(for error: Error) -> SyncProblem? {
        var current: NSError? = error as NSError
        while let error = current {
            if error.domain == CKError.errorDomain, let code = CKError.Code(rawValue: error.code) {
                switch code {
                case .networkUnavailable, .networkFailure:
                    return .offline
                case .notAuthenticated:
                    return .noAccount
                case .serviceUnavailable, .requestRateLimited, .zoneBusy:
                    return nil
                default:
                    return .failed
                }
            }
            current = error.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return .failed
    }

    private func handle(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
            as? NSPersistentCloudKitContainer.Event
        else { return }
        let kind: SyncEventKind = switch event.type {
        case .import: .import
        case .export: .export
        default: .setup
        }
        record(event.identifier, kind: kind, endDate: event.endDate, succeeded: event.succeeded, error: event.error)
    }

    private func refreshAccount() {
        Task {
            let status = try? await CKContainer(identifier: CloudSync.containerIdentifier).accountStatus()
            apply(accountStatus: status)
        }
    }
}
