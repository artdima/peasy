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
        panel.ignoresMouseEvents = true
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

    private var animation: Animation {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? .easeInOut(duration: 0.15)
            : .spring(response: 0.38, dampingFraction: 0.8)
    }

    private func updateGeometry() {
        guard let screen = NotchGeometry.preferredScreen() else { return }
        model.geometry = NotchGeometry(screen: screen)
        panel.setFrame(currentFrame, display: true)
    }

    private var currentFrame: CGRect {
        let notch = model.geometry?.notchRect ?? .zero
        return model.isExpanded ? (model.expandedFrame ?? notch) : notch
    }

    private func setExpanded(_ expanded: Bool) {
        guard expanded != model.isExpanded, let frame = model.expandedFrame else { return }
        if expanded {
            panel.setFrame(frame, display: true)
            panel.ignoresMouseEvents = false
            withAnimation(animation) {
                model.state = .expanded
            }
        } else {
            panel.ignoresMouseEvents = true
            withAnimation(animation, completionCriteria: .logicallyComplete) {
                model.state = .collapsed
            } completion: { [weak self] in
                self?.finishCollapse()
            }
        }
    }

    private func finishCollapse() {
        guard !model.isExpanded else { return }
        panel.setFrame(currentFrame, display: true)
    }
}
