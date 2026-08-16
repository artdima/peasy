import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class NotchViewModel {
    enum ProjectEditor: Equatable {
        case adding
        case renaming(UUID)
    }

    enum Command: Equatable {
        case moveSelection(Int)
        case toggleSelected
        case editSelected
        case selectList(Int)
        case focusNewTask
    }

    struct CommandEvent: Equatable {
        let id: Int
        let command: Command
    }

    struct Celebration: Equatable {
        let id = UUID()
        let title: String
        let colorHex: String
    }

    static let focusKey = "focusedTaskID"

    var draft = ""
    var isPinned = false
    var headerHeight: CGFloat = 34
    var selectedTaskID: UUID?
    private(set) var editingTaskID: UUID?
    var editingDraft = ""
    @ObservationIgnored var onCommitEdit: (UUID, String) -> Void = { _, _ in }
    var projectEditor: ProjectEditor?
    var projectPendingDeletion: UUID?
    private(set) var lastCommand: CommandEvent?
    private(set) var focusedTaskID: UUID? = UserDefaults.standard.string(forKey: NotchViewModel.focusKey)
        .flatMap(UUID.init(uuidString:))
    private(set) var celebration: Celebration?
    var addedConfirmation: String?
    var island: IslandMode = .plain

    @ObservationIgnored var onFocusStarted: () -> Void = {}
    @ObservationIgnored var onCelebration: () -> Void = {}
    @ObservationIgnored var onResize: (CGSize, Bool) -> Void = { _, _ in }
    @ObservationIgnored var onResetSize: () -> Void = {}
    var panelSize = PanelLayout.current.panelSize
    var hasCustomSize = PanelLayout.current.customSize(in: .standard) != nil
    private(set) var newTaskFocusRequest = 0

    var acceptsNavigationKeys: Bool {
        editingTaskID == nil && projectEditor == nil && projectPendingDeletion == nil
    }

    func send(_ command: Command) {
        lastCommand = CommandEvent(id: (lastCommand?.id ?? 0) + 1, command: command)
    }

    func focusNewTask() {
        newTaskFocusRequest += 1
    }

    func startEditing(_ task: TaskItem) {
        selectedTaskID = task.id
        editingDraft = task.title
        editingTaskID = task.id
    }

    /// Saves the draft and ends editing: on Return, on focus loss, on a click
    /// anywhere else, and when the panel folds away.
    func commitEditing() {
        guard let id = editingTaskID else { return }
        editingTaskID = nil
        onCommitEdit(id, editingDraft)
    }

    func cancelEditing() {
        guard editingTaskID != nil else { return }
        editingTaskID = nil
    }

    func startFocus(on task: TaskItem) {
        celebration = nil
        setFocus(task.id)
        onFocusStarted()
    }

    func stopFocus() {
        setFocus(nil)
    }

    func taskCompleted(_ task: TaskItem) {
        guard task.isDone, task.id == focusedTaskID else { return }
        setFocus(nil)
        celebration = Celebration(title: task.title, colorHex: task.project?.colorHex ?? ProjectPalette.inbox)
        onCelebration()
    }

    func endCelebration(_ id: UUID) {
        if celebration?.id == id {
            celebration = nil
        }
    }

    private func setFocus(_ id: UUID?) {
        focusedTaskID = id
        UserDefaults.standard.set(id?.uuidString, forKey: Self.focusKey)
    }

    func resetInteraction() {
        commitEditing()
        isPinned = false
        selectedTaskID = nil
        projectEditor = nil
        projectPendingDeletion = nil
    }
}
