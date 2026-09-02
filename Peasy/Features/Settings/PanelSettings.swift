import SwiftUI

enum PanelLayout: String, CaseIterable, Identifiable {
    case vertical
    case horizontal

    static let storageKey = "panelLayout"

    static var current: PanelLayout {
        UserDefaults.standard.string(forKey: storageKey).flatMap(PanelLayout.init(rawValue:)) ?? .vertical
    }

    var id: String { rawValue }

    var defaultSize: CGSize {
        switch self {
        case .vertical: CGSize(width: 680, height: 452)
        case .horizontal: CGSize(width: 560, height: 372)
        }
    }

    var minimumSize: CGSize {
        switch self {
        case .vertical: CGSize(width: 520, height: 300)
        case .horizontal: CGSize(width: 440, height: 260)
        }
    }

    /// The size the user dragged the panel to, or the default.
    var panelSize: CGSize {
        customSize(in: .standard) ?? defaultSize
    }

    var sizeStorageKey: String { "panelSize.\(rawValue)" }

    func customSize(in defaults: UserDefaults) -> CGSize? {
        guard let stored = defaults.array(forKey: sizeStorageKey) as? [Double], stored.count == 2 else { return nil }
        return CGSize(width: stored[0], height: stored[1])
    }

    func saveSize(_ size: CGSize, in defaults: UserDefaults = .standard) {
        if size == defaultSize {
            defaults.removeObject(forKey: sizeStorageKey)
        } else {
            defaults.set([size.width, size.height], forKey: sizeStorageKey)
        }
    }

    func resetSize(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: sizeStorageKey)
    }

    func clamp(_ size: CGSize, to limit: CGSize) -> CGSize {
        CGSize(
            width: min(max(size.width.rounded(), minimumSize.width), max(limit.width, minimumSize.width)),
            height: min(max(size.height.rounded(), minimumSize.height), max(limit.height, minimumSize.height))
        )
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
    static let expandsOnHoverKey = "expandsOnHover"
    static let multilineTasksKey = "multilineTasks"
    static let hoverOpenDelay: Duration = .milliseconds(150)

    static func flag(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }
}
