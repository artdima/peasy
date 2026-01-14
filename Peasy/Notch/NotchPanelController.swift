import AppKit
import SwiftUI

@MainActor
final class NotchPanelController {
    private let panel = NotchPanel()
    private let model: NotchViewModel
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
        updateGeometry()
        panel.orderFrontRegardless()
    }

    private func updateGeometry() {
        guard let screen = NotchGeometry.preferredScreen() else { return }
        let geometry = NotchGeometry(screen: screen)
        model.geometry = geometry
        panel.setFrame(geometry.notchRect, display: true)
    }
}
