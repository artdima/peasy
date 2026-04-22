import AppKit
import NotchKit
import Observation
import SwiftData
import SwiftUI

@MainActor
final class NotchController {
    private let presenter: NotchPresenter
    private let model: NotchViewModel
    private var actions: NotchActions
    private let modelContainer: ModelContainer
    private let cloud = CloudWindow()
    private var observers: [NSObjectProtocol] = []
    private var monitors: [Any] = []
    private var displayPreference = DisplayPreference.current
    private var layout = PanelLayout.current
    private var focusReturnTask: Task<Void, Never>?
    private var hoverOpenTask: Task<Void, Never>?
    private var hoverCancelTask: Task<Void, Never>?
    private var collapseSoonTask: Task<Void, Never>?
    private var celebrationTask: Task<Void, Never>?

    init(model: NotchViewModel, actions: NotchActions, modelContainer: ModelContainer) {
        self.model = model
        self.modelContainer = modelContainer
        self.actions = actions
        presenter = NotchPresenter(
            configuration: Self.configuration(layout: PanelLayout.current, reserve: model.island.reserve, pinned: false)
        )
        self.actions.collapse = { [weak self] in self?.collapse() }
        model.onFocusStarted = { [weak self] in self?.collapseSoon() }
        model.onCelebration = { [weak self] in self?.celebrationStarted() }

        presenter.preferredScreenID = preferredScreenID()
        installPanel()

        observe(NSWindow.didBecomeKeyNotification) { controller, notification in
            guard notification.object is NotchPanel else { return }
            controller.panelDidBecomeKey()
        }
        observe(NSApplication.didChangeScreenParametersNotification) { controller, _ in
            controller.presenter.preferredScreenID = controller.preferredScreenID()
            controller.model.headerHeight = controller.presenter.geometry.collapsedHeight
        }
        observe(UserDefaults.didChangeNotification) { controller, _ in
            controller.settingsDidChange()
        }
        startMonitors()
        observePhase()
        observePin()
        observeIsland()
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
        cloud.hide()
        presenter.uninstall()
    }

    private static func configuration(layout: PanelLayout, reserve: CGFloat, pinned: Bool) -> NotchConfiguration {
        NotchConfiguration(
            expandedSize: layout.panelSize,
            collapsedWidth: .wrapCutout(reserve: reserve),
            expandedTopCornerRadius: 16,
            expandedBottomCornerRadius: layout.bottomCornerRadius,
            expandedContentInsetsOverride: EdgeInsets(),
            expandedTopReserve: .none,
            expandsOnHover: false,
            collapsesOnPointerExit: !pinned,
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
        let presenter = presenter
        presenter.install {
            IslandView(presenter: presenter, model: model)
                .modelContainer(modelContainer)
        } expanded: {
            NotchContentView(model: model, actions: actions)
                .modelContainer(modelContainer)
        }
        modelContainer.mainContext.undoManager = panel?.undoManager
        model.headerHeight = presenter.geometry.collapsedHeight
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

    private func observePin() {
        withObservationTracking {
            _ = model.isPinned
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                presenter.configuration.collapsesOnPointerExit = !model.isPinned
                observePin()
            }
        }
    }

    private func observeIsland() {
        withObservationTracking {
            _ = model.island
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.islandDidChange()
                self?.observeIsland()
            }
        }
    }

    private func islandDidChange() {
        if model.island.focusTitle == nil {
            cloud.hide()
        }
        let width = NotchCollapsedWidth.wrapCutout(reserve: model.island.reserve)
        guard presenter.configuration.collapsedWidth != width else { return }
        withAnimation(.smooth(duration: 0.46)) {
            presenter.configuration.collapsedWidth = width
        }
    }

    private func phaseDidChange() {
        cloud.hide()
        cancelHoverOpen(immediately: true)
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

    private func collapseSoon() {
        guard !model.isPinned else { return }
        collapseSoonTask?.cancel()
        collapseSoonTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled, let self, !model.isPinned else { return }
            collapse()
        }
    }

    private func celebrationStarted() {
        if presenter.phase == .expanded, !model.isPinned {
            collapse()
        }
        guard let id = model.celebration?.id else { return }
        celebrationTask?.cancel()
        celebrationTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3.4))
            guard !Task.isCancelled else { return }
            self?.model.endCelebration(id)
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
        let layout = PanelLayout.current
        if layout != self.layout {
            self.layout = layout
            collapse()
            presenter.uninstall()
            presenter.configuration = Self.configuration(layout: layout, reserve: model.island.reserve, pinned: false)
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
            MainActor.assumeIsolated { self?.pointerMoved() }
        }
        let localMoves = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            MainActor.assumeIsolated { self?.pointerMoved() }
            return event
        }
        monitors = [keys, outsideClicks, moves, localMoves].compactMap { $0 }
    }

    private func handleOutsideClick() {
        if presenter.phase == .expanded, !model.isPinned {
            collapse()
        }
    }

    private func pointerMoved() {
        followPointer()
        guard presenter.phase == .collapsed, let panel else {
            cloud.hide()
            cancelHoverOpen(immediately: true)
            return
        }
        let location = NSEvent.mouseLocation
        let pill = presenter.interactiveRect(in: panel.frame)
        if let title = model.island.focusTitle, let colorHex = model.island.focusColorHex {
            let buddyZone = CGRect(
                x: pill.minX,
                y: pill.minY,
                width: presenter.collapsedGutterWidth + presenter.configuration.collapsedHitPadding,
                height: pill.height
            )
            if NotchGeometry.contains(buddyZone, location) {
                cancelHoverOpen(immediately: true)
                cloud.show(title: title, colorHex: colorHex, below: pill)
                return
            }
        }
        cloud.hide()
        if NotchGeometry.contains(pill, location), PanelSettings.flag(PanelSettings.expandsOnHoverKey) {
            scheduleHoverOpen()
        } else {
            cancelHoverOpen(immediately: false)
        }
    }

    private func scheduleHoverOpen() {
        hoverCancelTask?.cancel()
        hoverCancelTask = nil
        guard hoverOpenTask == nil else { return }
        hoverOpenTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(OpenDelay.current.seconds))
            guard !Task.isCancelled, let self else { return }
            hoverOpenTask = nil
            if presenter.phase == .collapsed {
                presenter.expand(reason: .hover)
            }
        }
    }

    private func cancelHoverOpen(immediately: Bool) {
        if immediately {
            hoverOpenTask?.cancel()
            hoverOpenTask = nil
            hoverCancelTask?.cancel()
            hoverCancelTask = nil
            return
        }
        guard hoverOpenTask != nil, hoverCancelTask == nil else { return }
        hoverCancelTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled, let self else { return }
            hoverOpenTask?.cancel()
            hoverOpenTask = nil
            hoverCancelTask = nil
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
                model.send(.selectList(digit - 1))
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
