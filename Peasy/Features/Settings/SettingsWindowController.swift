import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let sync: SyncMonitor
    private let folderSync: FolderSync
    private let claudeAccess: MCPServer
    private var window: NSWindow?
    private var themeObserver: NSObjectProtocol?

    init(sync: SyncMonitor, folderSync: FolderSync, claudeAccess: MCPServer) {
        self.sync = sync
        self.folderSync = folderSync
        self.claudeAccess = claudeAccess
    }

    /// The panel floats above every window, so Settings moves out from under it.
    func show(beside panel: CGRect? = nil) {
        let window = self.window ?? makeWindow()
        self.window = window
        if let panel {
            moveAside(window, from: panel)
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func moveAside(_ window: NSWindow, from panel: CGRect) {
        guard window.frame.intersects(panel),
              let visible = NSScreen.screens.first(where: { $0.frame.intersects(panel) })?.visibleFrame
        else { return }
        let x = panel.minX - 16 - window.frame.width
        guard x >= visible.minX else { return }
        window.setFrameOrigin(CGPoint(x: x, y: window.frame.minY))
    }

    private func makeWindow() -> NSWindow {
        let window = SettingsWindow(
            contentRect: CGRect(x: 0, y: 0, width: 560, height: 320),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.appearance = AppTheme.current.appearance
        window.backgroundColor = SettingsStyle.windowNS
        window.isReleasedWhenClosed = false

        let view = NSHostingView(rootView: SettingsView(sync: sync, folderSync: folderSync, claudeAccess: claudeAccess) { [weak window] title in
            window?.title = title
        } onHeightChange: { [weak self] height in
            Task { @MainActor [weak self] in
                self?.fitWindow(toHeight: height)
            }
        })
        let size = view.fittingSize
        view.sizingOptions = []
        window.contentView = view
        window.setContentSize(CGSize(width: size.width, height: size.height.rounded(.up)))
        window.center()

        themeObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak window] _ in
            MainActor.assumeIsolated {
                let appearance = AppTheme.current.appearance
                if window?.appearance?.name != appearance?.name {
                    window?.appearance = appearance
                }
            }
        }
        return window
    }

    // The window keeps its top edge while it follows the pane's height,
    // like the system's own settings windows.
    private func fitWindow(toHeight height: CGFloat) {
        guard let window, let content = window.contentView else { return }
        let dh = height.rounded(.up) - content.frame.height
        guard abs(dh) > 0.5 else { return }
        var frame = window.frame
        frame.size.height += dh
        frame.origin.y -= dh
        window.setFrame(frame, display: true, animate: window.isVisible)
    }
}

/// Lets the panel tell Settings apart from other windows.
final class SettingsWindow: NSWindow {}
