import Foundation

enum TaskList: Hashable {
    case today
    case inbox
    case project(UUID)

    static let storageKey = "selectedList"

    init(storageValue: String) {
        switch storageValue {
        case "today": self = .today
        case "inbox": self = .inbox
        default: self = UUID(uuidString: storageValue).map(TaskList.project) ?? .today
        }
    }

    var storageValue: String {
        switch self {
        case .today: "today"
        case .inbox: "inbox"
        case .project(let id): id.uuidString
        }
    }
}

enum TaskQueries {
    static func tasks(in list: TaskList, from tasks: [TaskItem]) -> [TaskItem] {
        let matching = tasks.filter { task in
            switch list {
            case .today: task.isToday
            case .inbox: task.project == nil
            case .project(let id): task.project?.id == id
            }
        }
        return sorted(matching)
    }

    static func openTasks(in list: TaskList, from tasks: [TaskItem]) -> [TaskItem] {
        self.tasks(in: list, from: tasks).filter { !$0.isDone }
    }

    static func completedTasks(in list: TaskList, from tasks: [TaskItem]) -> [TaskItem] {
        self.tasks(in: list, from: tasks)
            .filter(\.isDone)
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    static func todayProgress(from tasks: [TaskItem]) -> (done: Int, total: Int) {
        let today = tasks.filter(\.isToday)
        return (today.filter(\.isDone).count, today.count)
    }

    static func sorted(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.sorted { ($0.order, $0.createdAt) < ($1.order, $1.createdAt) }
    }
}
