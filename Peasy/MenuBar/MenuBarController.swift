import AppKit
import Observation
import SwiftData
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let statusView = StatusItemHostingView(rootView: AnyView(EmptyView()))
    private let panel = MenuBarPanel()
    private let hostingView: NSHostingView<PanelWindowView>
    private let model: PanelViewModel
    private var actions: PanelActions
    private var modelContainer: ModelContainer?
    private var content: AnyView?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var monitors: [Any] = []
    private let schedulePicker = SchedulePickerWindow()
    private var pickerTaskID: UUID?
    private var layout = PanelLayout.current
    private var theme = AppTheme.current
    private var surface: PanelSurface
    private var appearanceObservation: NSKeyValueObservation?
    private(set) var isExpanded = false
    private(set) var placement: PanelPlacement?

    init(model: PanelViewModel, actions: PanelActions, modelContainer: ModelContainer) {
        self.model = model
        self.modelContainer = modelContainer
        self.actions = actions
        let surface = PanelSurface(theme: AppTheme.current)
        self.surface = surface
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        hostingView = NSHostingView(rootView: PanelWindowView(surface: surface, content: AnyView(EmptyView())))
        super.init()

        model.headerHeight = PanelGeometry.headerHeight
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        statusView.sizingOptions = []
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            _ = button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel("Peasy")
            statusView.frame = button.bounds
            statusView.autoresizingMask = [.width, .height]
            button.addSubview(statusView)
        }

        self.actions.collapse = { [weak self] in self?.collapse() }
        let showAbout = actions.showAbout
        self.actions.showAbout = { [weak self] in
            self?.collapse()
            showAbout()
        }
        model.onResize = { [weak self] size, finished in self?.resize(to: size, finished: finished) }
        model.onCommitEdit = { [weak self] id, title in self?.commitEdit(of: id, title: title) }
        model.onResetSize = { [weak self] in self?.resetSize() }
        schedulePicker.onResignKey = { [weak self] in self?.model.schedulingTaskID = nil }

        installPanel()

        observe(NSApplication.didChangeScreenParametersNotification) { controller, _ in
            if controller.isExpanded {
                controller.place()
            }
        }
        observe(UserDefaults.didChangeNotification) { controller, _ in
            controller.settingsDidChange()
        }
        observe(NSWorkspace.didActivateApplicationNotification, in: NSWorkspace.shared.notificationCenter) { controller, notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.processIdentifier != NSRunningApplication.current.processIdentifier else { return }
            controller.collapseFromOutside()
        }
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.applyTheme()
            }
        }
        startMonitors()
        observeHold()
    }

    /// The panel body, header included.
    var expandedPanelSize: CGSize {
        model.panelSize
    }

    func expand() {
        guard modelContainer != nil else { return }
        if !isExpanded {
            isExpanded = true
            place()
            panel.alphaValue = 0
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                panel.animator().alphaValue = 1
            }
        }
        panel.makeKeyAndOrderFront(nil)
        setHighlighted(true)
    }

    func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        model.resetInteraction()
        setHighlighted(false)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.isExpanded else { return }
                self.panel.orderOut(nil)
            }
        }
    }

    func unloadStore() {
        closeSchedulePicker()
        collapse()
        panel.undoManager?.removeAllActions()
        content = nil
        statusView.rootView = AnyView(StatusItemLabel(mode: .plain))
        modelContainer = nil
    }

    func loadStore(_ container: ModelContainer) {
        modelContainer = container
        installPanel()
    }

    func shutdown() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        observers.forEach { center, token in center.removeObserver(token) }
        observers.removeAll()
        appearanceObservation = nil
        closeSchedulePicker()
        panel.orderOut(nil)
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    // MARK: - Status item

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
            return
        }
        if isExpanded {
            collapse()
        } else {
            expand()
        }
    }

    /// The button drops its highlight when the click that opened the panel ends, so it is set on the next turn.
    private func setHighlighted(_ isOn: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isExpanded == isOn else { return }
            self.statusItem.button?.highlight(isOn)
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: String(localized: "About Peasy"), action: #selector(menuAbout), keyEquivalent: "").target = self
        menu.addItem(withTitle: String(localized: "Settings…"), action: #selector(menuSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Quit Peasy"), action: #selector(menuQuit), keyEquivalent: "q").target = self
        collapse()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func menuAbout() { actions.showAbout() }
    @objc private func menuSettings() { actions.openSettings() }
    @objc private func menuQuit() { actions.quit() }

    // MARK: - Layout

    /// The button's horizontal extent, from the menu bar's bottom edge up to the button's top.
    private func statusItemFrame() -> CGRect {
        guard let button = statusItem.button, let window = button.window else {
            let screen = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
            return CGRect(x: screen.maxX - 80, y: screen.maxY - 24, width: 50, height: 24)
        }
        let onScreen = window.convertToScreen(button.convert(button.bounds, to: nil))
        let bottom = min(window.frame.minY, onScreen.minY)
        return CGRect(x: onScreen.minX, y: bottom, width: onScreen.width, height: onScreen.maxY - bottom)
    }

    private var screen: NSScreen? {
        statusItem.button?.window?.screen ?? NSScreen.main
    }

    private func place() {
        let frame = screen?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let placement = PanelPlacement(item: statusItemFrame(), screen: frame, panelSize: model.panelSize)
        self.placement = placement
        panel.setFrame(placement.frame, display: true)
        render()
    }

    private func render() {
        hostingView.rootView = PanelWindowView(surface: surface, content: content ?? AnyView(EmptyView()))
        DispatchQueue.main.async { [weak self] in
            self?.panel.invalidateShadow()
        }
    }

    private func installPanel() {
        guard let modelContainer else { return }
        content = AnyView(
            PanelContentView(model: model, actions: actions)
                .modelContainer(modelContainer)
        )
        statusView.rootView = AnyView(
            StatusItemView(model: model) { [weak self] width in
                self?.statusItem.length = width
            }
            .modelContainer(modelContainer)
        )
        panel.appearance = theme.appearance
        modelContainer.mainContext.undoManager = panel.undoManager
        render()
    }

    private func observe(
        _ name: Notification.Name,
        in center: NotificationCenter = .default,
        perform action: @escaping (MenuBarController, Notification) -> Void
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
            MainActor.assumeIsolated {
                if let self {
                    action(self, notification)
                }
            }
        }
        observers.append((center, token))
    }

    // MARK: - Holding open

    private func observeHold() {
        withObservationTracking {
            _ = model.schedulingTaskID
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.holdDidChange()
                self?.observeHold()
            }
        }
    }

    private func holdDidChange() {
        if let id = model.schedulingTaskID {
            if id != pickerTaskID {
                showSchedulePicker(for: id)
            }
        } else {
            closeSchedulePicker()
        }
    }

    private func showSchedulePicker(for id: UUID) {
        closeSchedulePicker()
        guard isExpanded else { return }
        let anchor = model.scheduleAnchor
        let target = CGRect(
            x: panel.frame.minX + anchor.minX,
            y: panel.frame.maxY - anchor.maxY,
            width: anchor.width,
            height: anchor.height
        )
        let visible = (panel.screen ?? NSScreen.main)?.visibleFrame ?? panel.frame
        let placement = SchedulePickerWindow.placement(pointingAt: target, within: visible)
        pickerTaskID = id
        let picker = TaskSchedulePicker(model: model, arrowEdge: placement.arrowEdge, arrowY: placement.arrowY) { [weak self] in
            self?.model.schedulingTaskID = nil
        }
        schedulePicker.show(picker, frame: placement.frame, appearance: theme.appearance)
    }

    /// The choice is saved only now, so a task does not leave the list while it is being planned.
    private func closeSchedulePicker() {
        guard let id = pickerTaskID else { return }
        pickerTaskID = nil
        let returnsKeyboard = schedulePicker.isKey && isExpanded
        schedulePicker.hide()
        if returnsKeyboard {
            panel.makeKey()
        }
        guard let modelContainer else { return }
        let store = TaskStore(context: modelContainer.mainContext)
        guard let task = store.allTasks().first(where: { $0.id == id }) else { return }
        store.schedule(task, on: model.scheduleDraft.date, hasTime: model.scheduleDraft.hasTime)
    }

    // MARK: - Settings

    private func settingsDidChange() {
        applyTheme()
        let layout = PanelLayout.current
        if layout != self.layout {
            self.layout = layout
            model.panelSize = layout.panelSize
            model.hasCustomSize = layout.customSize(in: .standard) != nil
            collapse()
        }
    }

    private func applyTheme() {
        let theme = AppTheme.current
        let surface = PanelSurface(theme: theme)
        guard theme != self.theme || surface != self.surface else { return }
        self.theme = theme
        self.surface = surface
        installPanel()
    }

    private var sizeLimit: CGSize {
        let frame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let item = statusItemFrame()
        let margin = PanelGeometry.screenMargin
        let rightEdge = min(item.maxX + PanelGeometry.overhang, frame.maxX - margin)
        return CGSize(width: rightEdge - frame.minX - margin, height: frame.height - PanelGeometry.gap - 40)
    }

    private func resize(to size: CGSize, finished: Bool) {
        let clamped = layout.clamp(size, to: sizeLimit)
        if clamped != model.panelSize {
            model.panelSize = clamped
            if isExpanded {
                place()
            }
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

    // MARK: - Mouse and keyboard

    private func startMonitors() {
        let keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let handled = MainActor.assumeIsolated { self?.handleKey(event) ?? false }
            return handled ? nil : event
        }
        let outsideClicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.collapseFromOutside() }
        }
        let localClicks = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.handleLocalClick(event)
            }
            return event
        }
        monitors = [keys, outsideClicks, localClicks].compactMap { $0 }
    }

    /// Clicks in our own windows: in the panel they end an edit and give the clicked
    /// field the keyboard; in the status item the button toggles; Settings keeps the
    /// panel open to show its changes; elsewhere they close.
    private func handleLocalClick(_ event: NSEvent) {
        guard let window = event.window else { return }
        if window === statusItem.button?.window || window is SchedulePickerPanel || window is SettingsWindow {
            return
        }
        guard window === panel else {
            collapseFromOutside()
            return
        }
        endEditIfClickedElsewhere(event)
        focusClickedField(event)
    }

    private func endEditIfClickedElsewhere(_ event: NSEvent) {
        guard model.editingTaskID != nil else { return }
        let hit = panel.contentView?.hitTest(event.locationInWindow)
        if let editor = panel.firstResponder as? NSView, let hit, hit.isDescendant(of: editor) {
            return
        }
        model.commitEditing()
    }

    private func focusClickedField(_ event: NSEvent) {
        guard !panel.isKeyWindow else { return }
        var view = panel.contentView?.hitTest(event.locationInWindow)
        while let current = view, !(current is NSTextField) {
            view = current.superview
        }
        guard let field = view as? NSTextField, field.currentEditor() == nil else { return }
        panel.makeFirstResponder(field)
    }

    private func commitEdit(of id: UUID, title: String) {
        guard let modelContainer else { return }
        let store = TaskStore(context: modelContainer.mainContext)
        guard let task = store.allTasks().first(where: { $0.id == id }) else { return }
        store.rename(task, to: title)
    }

    private func collapseFromOutside() {
        model.schedulingTaskID = nil
        collapse()
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        guard isExpanded, panel.isKeyWindow else { return false }
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
