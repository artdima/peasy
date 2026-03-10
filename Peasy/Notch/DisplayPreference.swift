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

    var title: LocalizedStringKey {
        switch self {
        case .builtIn: "Built-in display"
        case .main: "Main display"
        case .pointer: "Display with the pointer"
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
