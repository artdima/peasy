import AppKit
import SwiftUI

@MainActor
final class NotchPanelController {
    private let panel = NotchPanel()
    private let model: NotchViewModel
    private let hoverTracker = HoverTracker()
    private var screenObserver: NSObjectProtocol?

    init(model: NotchViewModel) {
        self.model = model
        let hostingView = NSHostingView(rootView: NotchRootView(model: model))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateGeometry()
            }
        }
        hoverTracker.zone = { [weak self] in self?.model.hoverZone }
        hoverTracker.onChange = { [weak self] inside in self?.setExpanded(inside) }
        updateGeometry()
        panel.orderFrontRegardless()
        hoverTracker.start()
    }

    private func updateGeometry() {
        guard let screen = NotchGeometry.preferredScreen() else { return }
        model.geometry = NotchGeometry(screen: screen)
        applyFrame()
    }

    private func setExpanded(_ expanded: Bool) {
        guard expanded != model.isExpanded else { return }
        model.state = expanded ? .expanded : .collapsed
        applyFrame()
    }

    private func applyFrame() {
        guard let geometry = model.geometry else { return }
        let frame = model.isExpanded ? (model.expandedFrame ?? geometry.notchRect) : geometry.notchRect
        panel.setFrame(frame, display: true)
        panel.ignoresMouseEvents = !model.isExpanded
    }
}
