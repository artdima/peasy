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
    private var modelContainer: ModelContainer?
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
            configuration: Self.configuration(layout: PanelLayout.current, size: model.panelSize, reserve: model.island.reserve, pinned: false, notchHeight: 0)
        )
        self.actions.collapse = { [weak self] in self?.collapse() }
        let openSettings = actions.openSettings
        let showAbout = actions.showAbout
        self.actions.openSettings = { [weak self] in
            self?.collapse()
            openSettings()
        }
        self.actions.showAbout = { [weak self] in
            self?.collapse()
            showAbout()
        }
        model.onFocusStarted = { [weak self] in self?.collapseSoon() }
        model.onCelebration = { [weak self] in self?.celebrationStarted() }
        model.onResize = { [weak self] size, finished in self?.resize(to: size, finished: finished) }
        model.onCommitEdit = { [weak self] id, title in self?.commitEdit(of: id, title: title) }
        model.onResetSize = { [weak self] in self?.resetSize() }

        presenter.preferredScreenID = preferredScreenID()
        presenter.configuration = makeConfiguration(pinned: false)
        installPanel()

        observe(NSWindow.didBecomeKeyNotification) { controller, notification in
            guard notification.object is NotchPanel else { return }
            controller.panelDidBecomeKey()
        }
        observe(NSApplication.didChangeScreenParametersNotification) { controller, _ in
            controller.presenter.preferredScreenID = controller.preferredScreenID()
            controller.model.headerHeight = controller.presenter.geometry.collapsedHeight
            controller.presenter.configuration = controller.makeConfiguration(pinned: controller.model.isPinned)
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

    /// Size of the opaque panel body below the ears, including the notch row.
    var expandedPanelSize: CGSize {
        let size = presenter.configuration.expandedSize
        return CGSize(
            width: size.width - presenter.configuration.expandedTopCornerRadius * 2,
            height: size.height + presenter.geometry.collapsedHeight
        )
    }

    func expand() {
        presenter.expand(reason: .click)
    }

    func collapse() {
        presenter.collapse()
    }

    func unloadStore() {
        collapse()
        panel?.undoManager?.removeAllActions()
        presenter.uninstall()
        modelContainer = nil
    }

    func loadStore(_ container: ModelContainer) {
        modelContainer = container
        installPanel()
    }

    func shutdown() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        cloud.hide()
        presenter.uninstall()
    }

    private static let earRadius: CGFloat = 16

    private func makeConfiguration(pinned: Bool) -> NotchConfiguration {
        Self.configuration(
            layout: layout,
            size: model.panelSize,
            reserve: model.island.reserve,
            pinned: pinned,
            notchHeight: presenter.geometry.collapsedHeight
        )
    }

    // NotchKit's expandedSize spans the concave ears and excludes the notch row;
    // the mockups measure the panel body below the ears, including that row.
    private static func configuration(layout: PanelLayout, size: CGSize, reserve: CGFloat, pinned: Bool, notchHeight: CGFloat) -> NotchConfiguration {
        NotchConfiguration(
            expandedSize: CGSize(
                width: size.width + earRadius * 2,
                height: max(size.height - notchHeight, 0)
            ),
            collapsedWidth: .wrapCutout(reserve: reserve),
            expandedTopCornerRadius: earRadius,
            expandedBottomCornerRadius: layout.bottomCornerRadius,
            expandedContentInsetsOverride: EdgeInsets(top: 0, leading: earRadius, bottom: 0, trailing: earRadius),
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
        guard let modelContainer else { return }
        let model = model
        let actions = actions
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
            model.panelSize = layout.panelSize
            model.hasCustomSize = layout.customSize(in: .standard) != nil
            collapse()
            presenter.uninstall()
            presenter.configuration = makeConfiguration(pinned: false)
            installPanel()
        }
    }

    private var sizeLimit: CGSize {
        let screen = displayPreference.pick(from: NSScreen.screens, pointer: NSEvent.mouseLocation)
        let frame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        return CGSize(width: frame.width - 40, height: frame.height - 40)
    }

    private func resize(to size: CGSize, finished: Bool) {
        let clamped = layout.clamp(size, to: sizeLimit)
        if clamped != model.panelSize {
            model.panelSize = clamped
            presenter.configuration = makeConfiguration(pinned: model.isPinned)
        }
        if finished {
            layout.saveSize(clamped)
            model.hasCustomSize = layout.customSize(in: .standard) != nil
        }
    }

    private func resetSize() {
        layout.resetSize()
        model.hasCustomSize = false
        resize(to: layout.defaultSize, finished: true)
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
        let localClicks = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            MainActor.assumeIsolated { self?.handleLocalClick(event) }
            return event
        }
        monitors = [keys, outsideClicks, moves, localMoves, localClicks].compactMap { $0 }
    }

    /// A click anywhere but inside the field being edited ends the edit.
    private func handleLocalClick(_ event: NSEvent) {
        guard model.editingTaskID != nil, let window = event.window, window is NotchPanel else { return }
        let hit = window.contentView?.hitTest(event.locationInWindow)
        if let editor = window.firstResponder as? NSView, let hit, hit.isDescendant(of: editor) {
            return
        }
        model.commitEditing()
    }

    private func commitEdit(of id: UUID, title: String) {
        guard let modelContainer else { return }
        let store = TaskStore(context: modelContainer.mainContext)
        guard let task = store.allTasks().first(where: { $0.id == id }) else { return }
        store.rename(task, to: title)
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
            try? await Task.sleep(for: PanelSettings.hoverOpenDelay)
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

        if let action = EditCommands.action(modifiers: modifiers, characters: characters) {
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

        if event.keyCode == KeyCode.escape {
            collapse()
            return true
        }
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
}
