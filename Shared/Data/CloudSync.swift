import Foundation
import Security

enum CloudSync {
    static let containerIdentifier = "iCloud.com.artdima.Peasy"
    static let enabledKey = "iCloudSyncEnabled"

    static let isEntitled: Bool = {
        #if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(
                  task,
                  "com.apple.developer.icloud-container-identifiers" as CFString,
                  nil
              ) as? [String]
        else { return false }
        return value.contains(containerIdentifier)
        #else
        // iOS has no API to read the app's own entitlements; the iOS target is always signed with the container.
        return true
        #endif
    }()

    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: enabledKey) as? Bool ?? true
    }

    static var isAvailable: Bool {
        isEntitled && !ProcessInfo.processInfo.isRunningTests
    }

    static var shouldSync: Bool {
        isAvailable && isEnabled()
    }
}
