import AppKit
import SwiftUI

enum DisplayPreference: String, CaseIterable, Identifiable {
    case builtIn
    case main
    case pointer

    static let storageKey = "displayPreference"

    static var current: DisplayPreference {
        UserDefaults.standard.string(forKey: storageKey).flatMap(DisplayPreference.init(rawValue:)) ?? .builtIn
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .builtIn: String(localized: "Built-in display")
        case .main: String(localized: "Main display")
        case .pointer: String(localized: "Display with the pointer")
        }
    }

    func pick<Screen: DisplayCandidate>(from screens: [Screen], pointer: CGPoint) -> Screen? {
        switch self {
        case .builtIn:
            screens.first(where: \.hasNotch) ?? screens.first(where: \.isBuiltIn) ?? screens.first
        case .main:
            screens.first
        case .pointer:
            screens.first { $0.frame.contains(pointer) } ?? screens.first
        }
    }
}

protocol DisplayCandidate {
    var frame: CGRect { get }
    var hasNotch: Bool { get }
    var isBuiltIn: Bool { get }
}

extension NSScreen: DisplayCandidate {
    var hasNotch: Bool {
        safeAreaInsets.top > 0
    }

    var isBuiltIn: Bool {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
        return CGDisplayIsBuiltin(number.uint32Value) != 0
    }
}
