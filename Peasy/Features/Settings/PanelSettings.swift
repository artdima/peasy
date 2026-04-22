import SwiftUI

enum OpenDelay: Int, CaseIterable, Identifiable {
    case short = 50
    case normal = 150
    case long = 400

    static let storageKey = "openDelayMilliseconds"

    static var current: OpenDelay {
        OpenDelay(rawValue: UserDefaults.standard.integer(forKey: storageKey)) ?? .normal
    }

    var id: Int { rawValue }

    var seconds: TimeInterval {
        TimeInterval(rawValue) / 1000
    }

    var title: LocalizedStringKey {
        switch self {
        case .short: "Short"
        case .normal: "Normal"
        case .long: "Long"
        }
    }
}

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
    static let showsCompletedKey = "showsCompletedTasks"
    static let showsTodayIndicatorKey = "showsTodayIndicator"
    static let showsBuddyKey = "showsBuddy"
    static let expandsOnHoverKey = "expandsOnHover"

    static func flag(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }
}
