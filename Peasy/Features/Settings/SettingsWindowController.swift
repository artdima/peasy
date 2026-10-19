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

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        window.level = MenuBarPanel.level
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        // macOS may decline activation while the panel holds the keyboard; the window must show anyway.
        window.orderFrontRegardless()
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
        window.collectionBehavior = [.moveToActiveSpace]

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

/// Rises to the panel's level while it has the keyboard, so it opens on top of the panel,
/// and drops back to a normal window after, so it never floats over other apps.
final class SettingsWindow: NSWindow {
    override func becomeKey() {
        level = MenuBarPanel.level
        super.becomeKey()
        orderFrontRegardless()
    }

    override func resignKey() {
        super.resignKey()
        level = .normal
    }
}
