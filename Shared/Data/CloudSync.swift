import Foundation
import Security

enum CloudSync {
    static let containerIdentifier = "iCloud.com.artdima.Peasy"
    static let enabledKey = "iCloudSyncEnabled"

    static let isEntitled: Bool = {
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(
                  task,
                  "com.apple.developer.icloud-container-identifiers" as CFString,
                  nil
              ) as? [String]
        else { return false }
        return value.contains(containerIdentifier)
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
