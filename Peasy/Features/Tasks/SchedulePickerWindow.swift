import AppKit
import SwiftUI

/// A window of its own instead of a popover: the picker draws its own body and
/// arrow, which a popover's chrome would not allow.
@MainActor
final class SchedulePickerWindow: NSObject, NSWindowDelegate {
    var onResignKey: () -> Void = {}

    private let panel = SchedulePickerPanel(
        contentRect: CGRect(origin: .zero, size: TaskSchedulePicker.windowSize),
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: true
    )

    var isKey: Bool {
        panel.isKeyWindow
    }

    override init() {
        super.init()
        panel.delegate = self
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
    }

    func show(_ content: some View, frame: CGRect, appearance: NSAppearance?) {
        let hosting = NSHostingView(rootView: content)
        hosting.sizingOptions = []
        hosting.frame = CGRect(origin: .zero, size: frame.size)
        panel.appearance = appearance
        panel.contentView = hosting
        panel.setFrame(frame, display: true)
        panel.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [panel] in
            panel.invalidateShadow()
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        panel.contentView = nil
    }

    func windowDidResignKey(_ notification: Notification) {
        onResignKey()
    }

    static func placement(pointingAt anchor: CGRect, within visible: CGRect) -> (frame: CGRect, arrowEdge: HorizontalEdge, arrowY: CGFloat) {
        let size = TaskSchedulePicker.windowSize
        let gap: CGFloat = 6
        var edge = HorizontalEdge.leading
        var x = anchor.maxX + gap
        if x + size.width > visible.maxX, anchor.minX - gap - size.width >= visible.minX {
            edge = .trailing
            x = anchor.minX - gap - size.width
        }
        let top = max(min(anchor.midY + 40, visible.maxY), visible.minY + size.height)
        let frame = CGRect(x: x, y: top - size.height, width: size.width, height: size.height)
        return (frame, edge, top - anchor.midY)
    }
}

final class SchedulePickerPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}
