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

    var draft = ""
    var isPinned = false
    var headerHeight: CGFloat = 34
    var selectedTaskID: UUID?
    var editingTaskID: UUID?
    var projectEditor: ProjectEditor?
    var projectPendingDeletion: UUID?
    private(set) var lastCommand: CommandEvent?
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

    func resetInteraction() {
        isPinned = false
        selectedTaskID = nil
        editingTaskID = nil
        projectEditor = nil
        projectPendingDeletion = nil
    }
}
