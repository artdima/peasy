import AppKit
import NotchKit
import Observation
import SwiftData
import SwiftUI

@MainActor
final class NotchController {
    static let panelSize = CGSize(width: 420, height: 320)

    private let presenter: NotchPresenter
    private let model: NotchViewModel
    private var actions: NotchActions
    private let modelContainer: ModelContainer
    private var observers: [NSObjectProtocol] = []
    private var monitors: [Any] = []
    private var displayPreference = DisplayPreference.current
    private var openDelay = OpenDelay.current
    private var focusReturnTask: Task<Void, Never>?

    init(model: NotchViewModel, actions: NotchActions, modelContainer: ModelContainer) {
        self.model = model
        self.modelContainer = modelContainer
        self.actions = actions
        presenter = NotchPresenter(configuration: Self.configuration(openDelay: OpenDelay.current))
        self.actions.collapse = { [weak self] in self?.collapse() }

        presenter.preferredScreenID = preferredScreenID()
        installPanel()

        observe(NSWindow.didBecomeKeyNotification) { controller, notification in
            guard notification.object is NotchPanel else { return }
            controller.panelDidBecomeKey()
        }
        observe(NSApplication.didChangeScreenParametersNotification) { controller, _ in
            controller.presenter.preferredScreenID = controller.preferredScreenID()
        }
        observe(UserDefaults.didChangeNotification) { controller, _ in
            controller.settingsDidChange()
        }
        startMonitors()
        observePhase()
    }

    var isExpanded: Bool {
        presenter.phase == .expanded
    }

    func expand() {
        presenter.expand(reason: .click)
    }

    func collapse() {
        presenter.collapse()
    }

    func shutdown() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        presenter.uninstall()
    }

    private static func configuration(openDelay: OpenDelay) -> NotchConfiguration {
        NotchConfiguration(
            expandedSize: panelSize,
            collapsedWidth: .wrapCutout(reserve: 0),
            expandedTopCornerRadius: 14,
            expandedBottomCornerRadius: 22,
            hoverOpenDelay: openDelay.seconds,
            collapsesOnOutsideClick: false
        )
    }

    private var panel: NSWindow? {
        NSApp.windows.first { $0 is NotchPanel }
    }

    private func installPanel() {
        let model = model
        let actions = actions
        let modelContainer = modelContainer
        presenter.install {
            EmptyView()
        } expanded: {
            NotchContentView(model: model, actions: actions)
                .modelContainer(modelContainer)
        }
        modelContainer.mainContext.undoManager = panel?.undoManager
    }

    private func observe(_ name: Notification.Name, perform action: @escaping (NotchController, Notification) -> Void) {
        let token = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
            MainActor.assumeIsolated {
                if let self {
                    action(self, notification)
                }
            }
        }
        observers.append(token)
    }

    private func observePhase() {
        withObservationTracking {
            _ = presenter.phase
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.phaseDidChange()
                self?.observePhase()
            }
        }
    }

    private func phaseDidChange() {
        guard presenter.phase == .collapsed else { return }
        model.resetInteraction()
        returnKeyboardFocus()
    }

    private func panelDidBecomeKey() {
        if presenter.phase == .expanded, presenter.expandReason != .click {
            presenter.expand(reason: .click)
        }
        if model.acceptsNavigationKeys {
            model.focusNewTask()
        }
    }

    private func returnKeyboardFocus() {
        focusReturnTask?.cancel()
        focusReturnTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, let self, presenter.phase != .expanded,
                  let panel, panel.isKeyWindow
            else { return }
            panel.orderOut(nil)
            panel.orderFrontRegardless()
        }
    }

    private func settingsDidChange() {
        let preference = DisplayPreference.current
        if preference != displayPreference {
            displayPreference = preference
            presenter.preferredScreenID = preferredScreenID()
        }
        let delay = OpenDelay.current
        if delay != openDelay {
            openDelay = delay
            presenter.uninstall()
            presenter.configuration = Self.configuration(openDelay: delay)
            installPanel()
        }
    }

    private func preferredScreenID() -> String? {
        displayPreference.pick(from: NSScreen.screens, pointer: NSEvent.mouseLocation)?.notch_stableID
    }

    private func startMonitors() {
        let keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let handled = MainActor.assumeIsolated { self?.handleKey(event) ?? false }
            return handled ? nil : event
        }
        let outsideClicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleOutsideClick() }
        }
        let moves = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            MainActor.assumeIsolated { self?.followPointer() }
        }
        monitors = [keys, outsideClicks, moves].compactMap { $0 }
    }

    private func handleOutsideClick() {
        if presenter.phase == .expanded {
            collapse()
        }
    }

    private func followPointer() {
        guard displayPreference == .pointer, presenter.phase != .expanded else { return }
        let id = preferredScreenID()
        if id != presenter.preferredScreenID {
            presenter.preferredScreenID = id
        }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        guard presenter.phase == .expanded, let panel, panel.isKeyWindow else { return false }
        let modifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.numericPad, .function, .capsLock])
        let characters = event.charactersIgnoringModifiers?.lowercased() ?? ""

        if let action = Self.editAction(modifiers: modifiers, characters: characters) {
            return NSApp.sendAction(action, to: nil, from: nil)
        }
        guard model.acceptsNavigationKeys else { return false }

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

    private static func editAction(modifiers: NSEvent.ModifierFlags, characters: String) -> Selector? {
        switch (modifiers, characters) {
        case (.command, "x"): #selector(NSText.cut(_:))
        case (.command, "c"): #selector(NSText.copy(_:))
        case (.command, "v"): #selector(NSText.paste(_:))
        case (.command, "a"): #selector(NSText.selectAll(_:))
        case (.command, "z"): Selector(("undo:"))
        case ([.command, .shift], "z"): Selector(("redo:"))
        default: nil
        }
    }
}
