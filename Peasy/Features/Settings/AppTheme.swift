import AppKit

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case dark
    case gray
    case light

    static let storageKey = "appTheme"

    static var current: AppTheme {
        UserDefaults.standard.string(forKey: storageKey).flatMap(AppTheme.init(rawValue:)) ?? .dark
    }

    nonisolated static var isGray: Bool {
        UserDefaults.standard.string(forKey: "appTheme") == "gray"
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: String(localized: "Match System")
        case .dark: String(localized: "Dark")
        case .gray: String(localized: "Gray")
        case .light: String(localized: "Light")
        }
    }

    /// `nil` lets windows follow macOS.
    var appearance: NSAppearance? {
        switch self {
        case .system: nil
        case .dark, .gray: NSAppearance(named: .darkAqua)
        case .light: NSAppearance(named: .aqua)
        }
    }

    var isLight: Bool {
        let appearance = self.appearance ?? NSApp.effectiveAppearance
        return appearance.bestMatch(from: [.darkAqua, .aqua]) == .aqua
    }
}
