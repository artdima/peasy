import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class NotchViewModel {
    enum State {
        case collapsed
        case expanded
    }

    enum ProjectEditor: Equatable {
        case adding
        case renaming(UUID)
    }

    enum Command: Equatable {
        case moveSelection(Int)
        case toggleSelected
        case editSelected
        case selectProject(Int)
        case focusNewTask
    }

    struct CommandEvent: Equatable {
        let id: Int
        let command: Command
    }

    static let contentWidth: CGFloat = 380
    static let earRadius: CGFloat = 12
    static let collapsedCornerRadius: CGFloat = 10
    static let expandedCornerRadius: CGFloat = 22

    var geometry: NotchGeometry?
    var state: State = .collapsed
    var draft = ""
    var selectedTaskID: UUID?
    var editingTaskID: UUID?
    var projectEditor: ProjectEditor?
    var projectPendingDeletion: UUID?
    private(set) var lastCommand: CommandEvent?
    private(set) var newTaskFocusRequest = 0
    private(set) var contentSize = CGSize(width: NotchViewModel.contentWidth, height: 120)

    @ObservationIgnored var onLayoutChange: () -> Void = {}

    var isExpanded: Bool { state == .expanded }

    var holdsOpen: Bool {
        editingTaskID != nil || projectEditor != nil || projectPendingDeletion != nil
            || !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var collapsedSize: CGSize {
        geometry?.notchRect.size ?? .zero
    }

    var expandedSize: CGSize {
        let notch = collapsedSize
        return CGSize(
            width: max(contentSize.width, notch.width) + 2 * Self.earRadius,
            height: notch.height + contentSize.height
        )
    }

    var expandedFrame: CGRect? {
        guard let geometry else { return nil }
        let size = expandedSize
        return CGRect(
            x: geometry.notchRect.midX - size.width / 2,
            y: geometry.screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    var hoverZone: CGRect? {
        if isExpanded {
            return expandedFrame
        }
        guard let notch = geometry?.notchRect else { return nil }
        return CGRect(x: notch.minX - 6, y: notch.minY, width: notch.width + 12, height: notch.height + 2)
    }

    var acceptsNavigationKeys: Bool {
        editingTaskID == nil && projectEditor == nil && projectPendingDeletion == nil
    }

    func send(_ command: Command) {
        lastCommand = CommandEvent(id: (lastCommand?.id ?? 0) + 1, command: command)
    }

    func focusNewTask() {
        newTaskFocusRequest += 1
    }

    func setContentHeight(_ height: CGFloat) {
        let height = height.rounded(.up)
        guard height > 0, height != contentSize.height else { return }
        contentSize.height = height
        onLayoutChange()
    }
}
