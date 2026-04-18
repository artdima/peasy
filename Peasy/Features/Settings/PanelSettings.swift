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

enum PanelSettings {
    static let showsCompletedKey = "showsCompletedTasks"
    static let showsTodayIndicatorKey = "showsTodayIndicator"
    static let showsBuddyKey = "showsBuddy"
    static let expandsOnHoverKey = "expandsOnHover"

    static func flag(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }
}
