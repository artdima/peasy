import AppKit
import SwiftData
import SwiftUI

final class QuickAddPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let action = EditCommands.action(for: event), NSApp.sendAction(action, to: nil, from: self) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

@MainActor
final class QuickAddController {
    private let panel: QuickAddPanel
    private let hostingView: NSHostingView<AnyView>
    private let state = QuickAddState()
    private var modelContainer: ModelContainer?
    private let notchModel: NotchViewModel
    private var observers: [NSObjectProtocol] = []
    private var confirmationTask: Task<Void, Never>?
    private var isShown = false

    init(modelContainer: ModelContainer, notchModel: NotchViewModel) {
        self.notchModel = notchModel
        panel = QuickAddPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .modalPanel
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.appearance = NSAppearance(named: .darkAqua)
        hostingView = NSHostingView(rootView: AnyView(EmptyView()))
        hostingView.sizingOptions = .intrinsicContentSize
        let container = NSView()
        container.addSubview(hostingView)
        panel.contentView = container

        loadStore(modelContainer)

        let token = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.hide()
            }
        }
        observers.append(token)
    }

    func loadStore(_ container: ModelContainer) {
        modelContainer = container
        hostingView.rootView = AnyView(
            QuickAddView(
                state: state,
                onSubmit: { [weak self] in self?.submit() },
                onCancel: { [weak self] in self?.hide() }
            )
            .modelContainer(container)
        )
    }

    func unloadStore() {
        hide()
        hostingView.rootView = AnyView(EmptyView())
        modelContainer = nil
    }

    func toggle() {
        isShown ? hide() : show()
    }

    func show() {
        guard modelContainer != nil else { return }
        let selected = UserDefaults.standard.string(forKey: TaskList.storageKey).map(TaskList.init(storageValue:))
        if case .project(let id) = selected {
            state.reset(projectID: id)
        } else {
            state.reset(projectID: nil)
        }
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let screen else { return }
        let size = hostingView.intrinsicContentSize
        guard size.width > 0, size.height > 0 else { return }
        hostingView.frame = CGRect(origin: .zero, size: size)
        let top = screen.frame.maxY - screen.frame.height * 0.41 + QuickAddView.shadowRoom.top
        panel.setFrame(
            CGRect(x: screen.frame.midX - size.width / 2, y: top - size.height, width: size.width, height: size.height),
            display: true
        )
        isShown = true
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard isShown else { return }
        isShown = false
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.isShown else { return }
                self.panel.orderOut(nil)
            }
        }
    }

    private func submit() {
        guard let modelContainer else { return }
        let store = TaskStore(context: modelContainer.mainContext)
        let project = state.projectID.flatMap { store.project(id: $0) }
        guard let task = store.addTask(state.title, project: project, isToday: state.isToday) else { return }
        let colorHex = task.project?.colorHex ?? ProjectPalette.inbox
        hide()
        notchModel.addedConfirmation = colorHex
        confirmationTask?.cancel()
        confirmationTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled, let self else { return }
            notchModel.addedConfirmation = nil
        }
    }
}
