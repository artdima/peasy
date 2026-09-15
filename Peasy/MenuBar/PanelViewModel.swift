import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class PanelViewModel {
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

    var draft = ""
    var isPinned = false
    var headerHeight = PanelGeometry.headerHeight
    var selectedTaskID: UUID?
    private(set) var editingTaskID: UUID?
    var editingDraft = ""
    @ObservationIgnored var onCommitEdit: (UUID, String) -> Void = { _, _ in }
    var projectEditor: ProjectEditor?
    var projectPendingDeletion: UUID?
    private(set) var lastCommand: CommandEvent?
    var schedulingTaskID: UUID?
    var scheduleDraft = ScheduleDraft()
    var scheduleAnchor: CGRect = .zero
    var addedConfirmation: String?

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

    /// The anchor is the calendar button's frame in the panel's SwiftUI space.
    func openSchedule(for task: TaskItem, anchor: CGRect) {
        scheduleAnchor = anchor
        scheduleDraft = ScheduleDraft(date: task.date, hasTime: task.hasTime)
        schedulingTaskID = task.id
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

    func resetInteraction() {
        commitEditing()
        isPinned = false
        schedulingTaskID = nil
        selectedTaskID = nil
        projectEditor = nil
        projectPendingDeletion = nil
    }
}

struct ScheduleDraft: Equatable {
    var date: Date?
    var hasTime = false
}
