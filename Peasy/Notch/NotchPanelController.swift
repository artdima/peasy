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
    private var shrinkTask: Task<Void, Never>?
    private var keyMonitor: Any?
    private var displayPreference = DisplayPreference.current

    init(model: NotchViewModel, actions: NotchActions, modelContainer: ModelContainer) {
        self.model = model
        var actions = actions
        actions.collapse = { [weak self] in self?.setExpanded(false) }
        modelContainer.mainContext.undoManager = panel.undoManager
        let rootView = NotchRootView(model: model, actions: actions)
            .modelContainer(modelContainer)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        panel.ignoresMouseEvents = true
        observe(NSApplication.didChangeScreenParametersNotification) { $0.updateGeometry() }
        observe(UserDefaults.didChangeNotification) { controller in
            let preference = DisplayPreference.current
            guard preference != controller.displayPreference else { return }
            controller.displayPreference = preference
            controller.updateGeometry()
        }
        observe(NSMenu.didBeginTrackingNotification) { $0.isMenuOpen = true }
        observe(NSMenu.didEndTrackingNotification) {
            $0.isMenuOpen = false
            $0.hoverTracker.update(force: true)
        }
        hoverTracker.zone = { [weak self] in self?.model.hoverZone }
        hoverTracker.onChange = { [weak self] inside in self?.setExpanded(inside) }
        observe(NSWindow.didResignKeyNotification) {
            guard $0.model.isExpanded else { return }
            $0.hoverTracker.update(force: true)
        }
        hoverTracker.holdOpen = { [weak self] in self?.shouldHoldOpen ?? false }
        hoverTracker.onMove = { [weak self] location in self?.followPointer(to: location) }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let handled = MainActor.assumeIsolated { self?.handleKey(event) ?? false }
            return handled ? nil : event
        }
        model.onLayoutChange = { [weak self] in self?.layoutDidChange() }
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

    private func handleKey(_ event: NSEvent) -> Bool {
        guard panel.isKeyWindow, model.isExpanded, model.acceptsNavigationKeys else { return false }
        let modifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.numericPad, .function, .capsLock])
        let characters = event.charactersIgnoringModifiers ?? ""

        if modifiers == .command {
            if characters == "n" {
                model.send(.focusNewTask)
                return true
            }
            if let digit = Int(characters), (1...9).contains(digit) {
                model.send(.selectProject(digit - 1))
                return true
            }
            return false
        }
        guard modifiers.isEmpty else { return false }

        let canActOnSelection = model.draft.isEmpty && model.selectedTaskID != nil
        switch event.keyCode {
        case KeyCode.down:
            model.send(.moveSelection(1))
        case KeyCode.up:
            model.send(.moveSelection(-1))
        case KeyCode.space where canActOnSelection:
            model.send(.toggleSelected)
        case KeyCode.returnKey where canActOnSelection, KeyCode.enter where canActOnSelection:
            model.send(.editSelected)
        default:
            return false
        }
        return true
    }

    private var shouldHoldOpen: Bool {
        isMenuOpen || (model.holdsOpen && panel.isKeyWindow)
    }

    private var animation: Animation {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? .easeInOut(duration: 0.15)
            : .spring(response: 0.38, dampingFraction: 0.8)
    }

    private func updateGeometry() {
        guard let screen = displayPreference.pick(from: NSScreen.screens, pointer: NSEvent.mouseLocation) else { return }
        let geometry = NotchGeometry(screen: screen)
        guard geometry != model.geometry else { return }
        model.geometry = geometry
        panel.setFrame(currentFrame, display: true)
    }

    private func followPointer(to location: CGPoint) {
        guard displayPreference == .pointer, !model.isExpanded,
              let screenFrame = model.geometry?.screenFrame, !screenFrame.contains(location)
        else { return }
        updateGeometry()
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
            panel.makeKey()
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

    private func layoutDidChange() {
        guard model.isExpanded, let frame = model.expandedFrame else { return }
        shrinkTask?.cancel()
        if frame.height >= panel.frame.height {
            panel.setFrame(frame, display: true)
            return
        }
        shrinkTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let self, model.isExpanded, let frame = model.expandedFrame else { return }
            panel.setFrame(frame, display: true)
        }
    }

    private func finishCollapse() {
        guard !model.isExpanded else { return }
        model.selectedTaskID = nil
        model.editingTaskID = nil
        model.projectEditor = nil
        model.projectPendingDeletion = nil
        if panel.isKeyWindow {
            panel.orderOut(nil)
            panel.orderFrontRegardless()
        }
        panel.setFrame(currentFrame, display: true)
    }
}
