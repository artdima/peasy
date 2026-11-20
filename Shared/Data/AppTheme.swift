import Foundation

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case dark
    case light

    static let storageKey = "appTheme"

    /// The former gray theme folded into dark, so its stored value falls back to the default.
    static var current: AppTheme {
        UserDefaults.standard.string(forKey: storageKey).flatMap(AppTheme.init(rawValue:)) ?? .dark
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: String(localized: "Match System")
        case .dark: String(localized: "Dark")
        case .light: String(localized: "Light")
        }
    }
}
