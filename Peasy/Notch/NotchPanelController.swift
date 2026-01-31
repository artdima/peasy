import AppKit
import SwiftData
import SwiftUI

@MainActor
final class NotchPanelController {
    private let panel = NotchPanel()
    private let model: NotchViewModel
    private let hoverTracker = HoverTracker()
    private var observers: [NSObjectProtocol] = []
    private var isMenuOpen = false

    init(model: NotchViewModel, actions: NotchActions, modelContainer: ModelContainer) {
        self.model = model
        let rootView = NotchRootView(model: model, actions: actions)
            .modelContainer(modelContainer)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        panel.ignoresMouseEvents = true
        observe(NSApplication.didChangeScreenParametersNotification) { $0.updateGeometry() }
        observe(NSMenu.didBeginTrackingNotification) { $0.isMenuOpen = true }
        observe(NSMenu.didEndTrackingNotification) {
            $0.isMenuOpen = false
            $0.hoverTracker.update(force: true)
        }
        hoverTracker.zone = { [weak self] in self?.model.hoverZone }
        hoverTracker.onChange = { [weak self] inside in self?.setExpanded(inside) }
        hoverTracker.holdOpen = { [weak self] in self?.isMenuOpen ?? false }
        updateGeometry()
        panel.orderFrontRegardless()
        hoverTracker.start()
    }

    private func observe(_ name: Notification.Name, perform action: @escaping (NotchPanelController) -> Void) {
        let token = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                if let self { action(self) }
            }
        }
        observers.append(token)
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
