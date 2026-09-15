import AppKit
import SwiftUI

/// A floating, non-activating window: typing in it never takes the front app away.
final class MenuBarPanel: NSPanel {
    static let level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)

    init() {
        super.init(
            contentRect: CGRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        level = Self.level
        isFloatingPanel = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

enum PanelSurface: Equatable {
    case dark
    case glass

    init(theme: AppTheme) {
        self = theme.isLight ? .glass : .dark
    }
}

/// The panel's rounded body with its content. The window's own shadow follows the corners.
struct PanelWindowView: View {
    let surface: PanelSurface
    let content: AnyView

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                background
            }
            .clipShape(RoundedRectangle(cornerRadius: PanelGeometry.cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var background: some View {
        switch surface {
        case .dark:
            PanelStyle.ink
        case .glass:
            PanelGlass(cornerRadius: PanelGeometry.cornerRadius)
        }
    }
}
