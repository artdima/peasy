import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let sync: SyncMonitor
    private var window: NSWindow?

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
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(sync: sync)))
        window.title = String(localized: "Settings")
        window.styleMask = [.titled, .closable]
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(srgbRed: 0x1E / 255, green: 0x1E / 255, blue: 0x20 / 255, alpha: 1)
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
