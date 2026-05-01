import SwiftUI

enum PanelLayout: String, CaseIterable, Identifiable {
    case vertical
    case horizontal

    static let storageKey = "panelLayout"

    static var current: PanelLayout {
        UserDefaults.standard.string(forKey: storageKey).flatMap(PanelLayout.init(rawValue:)) ?? .vertical
    }

    var id: String { rawValue }

    var panelSize: CGSize {
        switch self {
        case .vertical: CGSize(width: 680, height: 452)
        case .horizontal: CGSize(width: 560, height: 372)
        }
    }

    var bottomCornerRadius: CGFloat {
        switch self {
        case .vertical: 30
        case .horizontal: 28
        }
    }
}

enum PanelSettings {
    static let showsTodayIndicatorKey = "showsTodayIndicator"
    static let showsBuddyKey = "showsBuddy"
    static let expandsOnHoverKey = "expandsOnHover"
    static let hoverOpenDelay: Duration = .milliseconds(150)

    static func flag(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }
}
