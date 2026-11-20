import AppKit

extension AppTheme {
    /// `nil` lets windows follow macOS.
    var appearance: NSAppearance? {
        switch self {
        case .system: nil
        case .dark: NSAppearance(named: .darkAqua)
        case .light: NSAppearance(named: .aqua)
        }
    }

    var isLight: Bool {
        let appearance = self.appearance ?? NSApp.effectiveAppearance
        return appearance.bestMatch(from: [.darkAqua, .aqua]) == .aqua
    }
}
