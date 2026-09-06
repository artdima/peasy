import Foundation

enum TaskList: Hashable {
    case today
    case all
    case project(UUID)

    static let storageKey = "selectedList"

    init(storageValue: String) {
        switch storageValue {
        case "today": self = .today
        case "all", "inbox": self = .all
        default: self = UUID(uuidString: storageValue).map(TaskList.project) ?? .today
        }
    }

    var storageValue: String {
        switch self {
        case .today: "today"
        case .all: "all"
        case .project(let id): id.uuidString
        }
    }
}

enum TaskQueries {
    /// Today keeps only what was finished today, so it starts every morning fresh.
    static func tasks(in list: TaskList, from tasks: [TaskItem], now: Date = .now) -> [TaskItem] {
        let calendar = Calendar.current
        let matching = tasks.filter { task in
            switch list {
            case .today:
                task.isDue(on: now, calendar: calendar)
                    && (!task.isDone || task.completedAt.map { calendar.isDate($0, inSameDayAs: now) } == true)
            case .all: true
            case .project(let id): task.project?.id == id
            }
        }
        return sorted(matching)
    }

    static func openTasks(in list: TaskList, from tasks: [TaskItem], now: Date = .now) -> [TaskItem] {
        self.tasks(in: list, from: tasks, now: now).filter { !$0.isDone }
    }

    static func completedTasks(in list: TaskList, from tasks: [TaskItem], now: Date = .now) -> [TaskItem] {
        self.tasks(in: list, from: tasks, now: now)
            .filter(\.isDone)
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    static func todayProgress(from tasks: [TaskItem], now: Date = .now) -> (done: Int, total: Int) {
        let today = self.tasks(in: .today, from: tasks, now: now)
        return (today.filter(\.isDone).count, today.count)
    }

    static func sorted(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.sorted { ($0.order, $0.createdAt) < ($1.order, $1.createdAt) }
    }
}
