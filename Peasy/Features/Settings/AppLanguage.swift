import AppKit

/// The interface language. It is stored where macOS keeps a per-app language and, as with
/// that setting in System Settings, takes effect when the app next launches.
enum AppLanguage: String, CaseIterable {
    case system
    case english = "en"
    case russian = "ru"

    static let relaunchArgument = "--relaunch-after"
    private static let languagesKey = "AppleLanguages"

    /// Only this app's own entry counts: the global list would always read as a choice.
    static func current(in defaults: UserDefaults = .standard) -> AppLanguage {
        let own = Bundle.main.bundleIdentifier.flatMap { defaults.persistentDomain(forName: $0)?[Self.languagesKey] as? [String] }
        guard let code = own?.first else { return .system }
        return allCases.first { $0 != .system && code.hasPrefix($0.rawValue) } ?? .system
    }

    func apply(in defaults: UserDefaults = .standard) {
        if self == .system {
            defaults.removeObject(forKey: Self.languagesKey)
        } else {
            defaults.set([rawValue], forKey: Self.languagesKey)
        }
    }

    /// Language names stay in their own language, as in macOS.
    var title: String {
        switch self {
        case .system: String(localized: "Match System")
        case .english: "English"
        case .russian: "Русский"
        }
    }

    /// The running app speaks another language than this choice would give it.
    var needsRelaunch: Bool {
        let preferences: [String]
        if self == .system {
            let global = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?[Self.languagesKey] as? [String]
            preferences = global ?? Locale.preferredLanguages
        } else {
            preferences = [rawValue]
        }
        let chosen = Bundle.preferredLocalizations(from: Bundle.main.localizations, forPreferences: preferences).first
        return chosen != Bundle.main.preferredLocalizations.first
    }

    /// Opens a new copy and quits; the copy waits for this one to exit before it opens the store.
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = [relaunchArgument, String(ProcessInfo.processInfo.processIdentifier)]
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            guard error == nil else { return }
            Task { @MainActor in
                NSApp.terminate(nil)
            }
        }
    }

    static func waitForPreviousInstance(arguments: [String] = CommandLine.arguments) {
        guard let index = arguments.firstIndex(of: relaunchArgument),
              arguments.indices.contains(index + 1),
              let pid = pid_t(arguments[index + 1])
        else { return }
        let deadline = Date().addingTimeInterval(5)
        while let previous = NSRunningApplication(processIdentifier: pid), !previous.isTerminated, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
    }
}
