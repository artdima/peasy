import AppKit
import Observation
import Sparkle
import UserNotifications

@MainActor
@Observable
final class Updater: NSObject {
    nonisolated static let notificationID = "update"

    private(set) var checksAutomatically = false
    @ObservationIgnored var willCheckForUpdates: () -> Void = {}

    @ObservationIgnored private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: nil,
        userDriverDelegate: self
    )

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    func start() {
        controller.startUpdater()
        checksAutomatically = controller.updater.automaticallyChecksForUpdates
    }

    func checkForUpdates() {
        willCheckForUpdates()
        NSApp.activate()
        controller.checkForUpdates(nil)
    }

    func setChecksAutomatically(_ isOn: Bool) {
        controller.updater.automaticallyChecksForUpdates = isOn
        checksAutomatically = controller.updater.automaticallyChecksForUpdates
    }

    private func remind(version: String) {
        Task {
            let center = UNUserNotificationCenter.current()
            let status = await center.notificationSettings().authorizationStatus
            guard status == .authorized || status == .provisional else {
                // Without notifications a menu bar app has no other way to tell about the update.
                checkForUpdates()
                return
            }
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Peasy \(version) is available")
            content.body = String(localized: "Click to see what’s new and install it.")
            try? await center.add(UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: nil))
        }
    }
}

extension Updater: SPUStandardUserDriverDelegate {
    nonisolated var supportsGentleScheduledUpdateReminders: Bool {
        true
    }

    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        immediateFocus
    }

    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard !handleShowingUpdate else { return }
        let version = update.displayVersionString
        MainActor.assumeIsolated {
            remind(version: version)
        }
    }

    nonisolated func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Self.notificationID])
    }
}
