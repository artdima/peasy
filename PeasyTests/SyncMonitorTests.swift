import CloudKit
import Foundation
import Testing
@testable import Peasy

@MainActor
struct SyncMonitorTests {
    private func makeDefaults() throws -> UserDefaults {
        let name = "SyncMonitorTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func unsignedBuildIsUnavailable() throws {
        let sync = SyncMonitor(isAvailable: false, defaults: try makeDefaults())
        #expect(sync.status == .unavailable)
        #expect(!sync.isActive)
        sync.setEnabled(false)
        #expect(sync.isEnabled)
    }

    @Test func turningSyncOffReloadsTheStoreAndPersists() throws {
        let defaults = try makeDefaults()
        let sync = SyncMonitor(isAvailable: true, defaults: defaults)
        var reloads = 0
        sync.onStoreReloadNeeded = { reloads += 1 }

        sync.setEnabled(false)

        #expect(sync.status == .off)
        #expect(reloads == 1)
        #expect(!SyncMonitor(isAvailable: true, defaults: defaults).isEnabled)
    }

    @Test func eventsDriveTheStatus() throws {
        let defaults = try makeDefaults()
        let sync = SyncMonitor(isAvailable: true, defaults: defaults)
        #expect(sync.status == .idle(lastSync: nil))

        let id = UUID()
        sync.record(id, kind: .import, endDate: nil, succeeded: false, error: nil)
        #expect(sync.status == .syncing)
        #expect(!sync.canSyncNow)

        let end = Date(timeIntervalSince1970: 1_800_000_000)
        sync.record(id, kind: .import, endDate: end, succeeded: true, error: nil)
        #expect(sync.status == .idle(lastSync: end))
        #expect(SyncMonitor(isAvailable: true, defaults: defaults).lastSync == end)
    }

    @Test func setupDoesNotCountAsSync() throws {
        let sync = SyncMonitor(isAvailable: true, defaults: try makeDefaults())
        sync.record(UUID(), kind: .setup, endDate: .now, succeeded: true, error: nil)
        #expect(sync.status == .idle(lastSync: nil))
    }

    @Test func networkErrorShowsOfflineUntilNextSuccess() throws {
        let sync = SyncMonitor(isAvailable: true, defaults: try makeDefaults())
        let error = NSError(domain: CKError.errorDomain, code: CKError.Code.networkUnavailable.rawValue)

        sync.record(UUID(), kind: .export, endDate: .now, succeeded: false, error: error)
        #expect(sync.status == .offline)
        #expect(sync.canSyncNow)

        let end = Date.now
        sync.record(UUID(), kind: .export, endDate: end, succeeded: true, error: nil)
        #expect(sync.status == .idle(lastSync: end))
    }

    @Test func signedOutAccountWins() throws {
        let sync = SyncMonitor(isAvailable: true, defaults: try makeDefaults())
        sync.apply(accountStatus: .noAccount)
        #expect(sync.status == .noAccount)
        #expect(!sync.canSyncNow)

        sync.apply(accountStatus: .available)
        #expect(sync.status == .idle(lastSync: nil))
    }

    @Test func cloudKitErrorsAreFoundInsideCoreDataErrors() {
        let inner = NSError(domain: CKError.errorDomain, code: CKError.Code.notAuthenticated.rawValue)
        let outer = NSError(domain: NSCocoaErrorDomain, code: 134_400, userInfo: [NSUnderlyingErrorKey: inner])
        #expect(SyncMonitor.problem(for: outer) == .noAccount)

        let busy = NSError(domain: CKError.errorDomain, code: CKError.Code.requestRateLimited.rawValue)
        #expect(SyncMonitor.problem(for: busy) == nil)
        #expect(SyncMonitor.problem(for: NSError(domain: NSCocoaErrorDomain, code: 1)) == .failed)
    }

    @Test func syncedDayNamesTodayAndYesterday() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 12)))
        #expect(SyncedDay(now.addingTimeInterval(-3_600), now: now, calendar: calendar) == .today)
        #expect(SyncedDay(now.addingTimeInterval(-86_400), now: now, calendar: calendar) == .yesterday)
        #expect(SyncedDay(now.addingTimeInterval(-5 * 86_400), now: now, calendar: calendar) == .earlier)
    }
}
