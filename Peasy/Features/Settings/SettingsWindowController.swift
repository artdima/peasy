import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let sync: SyncMonitor
    private var window: NSWindow?
    private var hosting: NSHostingController<SettingsView>?
    private var sizeObservation: NSKeyValueObservation?
    private var themeObserver: NSObjectProtocol?

    init(sync: SyncMonitor) {
        self.sync = sync
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 560, height: 320),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.appearance = AppTheme.current.appearance
        window.backgroundColor = SettingsStyle.windowNS
        window.isReleasedWhenClosed = false

        let hosting = NSHostingController(rootView: SettingsView(sync: sync) { [weak window] title in
            window?.title = title
        })
        hosting.sizingOptions = .preferredContentSize
        window.contentViewController = hosting
        self.hosting = hosting
        hosting.view.layoutSubtreeIfNeeded()
        window.setContentSize(hosting.preferredContentSize)
        window.center()

        // The window keeps its top edge while it follows the pane's height,
        // like the system's own settings windows.
        themeObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak window] _ in
            MainActor.assumeIsolated {
                window?.appearance = AppTheme.current.appearance
            }
        }
        sizeObservation = hosting.observe(\.preferredContentSize, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.fitWindow()
            }
        }
        return window
    }

    private func fitWindow() {
        guard let window, let hosting, let content = window.contentView else { return }
        let target = hosting.preferredContentSize
        guard target.width > 0, target.height > 0 else { return }
        let dw = target.width - content.frame.width
        let dh = target.height - content.frame.height
        guard abs(dw) > 0.5 || abs(dh) > 0.5 else { return }
        var frame = window.frame
        frame.size.width += dw
        frame.size.height += dh
        frame.origin.y -= dh
        window.setFrame(frame, display: true, animate: window.isVisible)
    }
}
