#if os(iOS)
import AppIntents
import Foundation

nonisolated struct AddTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Task"
    static let description = IntentDescription("Adds a task to Today. Mention @claude to hand it to Claude.")

    @Parameter(title: "Task", requestValueDialog: "What do you need to do?")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard ClaudeMention.parse(text).title.contains(where: { !$0.isWhitespace }) else {
            throw TaskIntentError.emptyTitle
        }
        guard let title = SharedStore.write({ $0.addTypedTask(text, to: .today)?.title }) ?? nil else {
            throw TaskIntentError.storeUnavailable
        }
        return .result(dialog: "Added to Today: \(title)")
    }
}

nonisolated struct ToggleTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Task"
    static let isDiscoverable = false

    @Parameter(title: "Task")
    var taskID: String

    init() {}

    init(taskID: UUID) {
        self.taskID = taskID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let id = UUID(uuidString: taskID)
        SharedStore.write { store in
            if let task = store.allTasks().first(where: { $0.id == id }) {
                store.toggle(task)
            }
        }
        return .result()
    }
}

/// Runs in the app, which shows the new task sheet as it comes forward.
nonisolated struct NewTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "New task"
    static let description = IntentDescription("Opens Peasy with a new task.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NewTaskPrompt.shared.isPresented = true
        return .result()
    }
}

nonisolated enum TaskIntentError: Error, CustomLocalizedStringResourceConvertible {
    case emptyTitle
    case storeUnavailable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .emptyTitle: "Type what needs to be done."
        case .storeUnavailable: "Peasy couldn’t open its tasks."
        }
    }
}
#endif
