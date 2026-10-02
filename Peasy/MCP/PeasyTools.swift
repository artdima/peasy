import Foundation
import SwiftData

nonisolated struct ToolError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}

/// What Claude can do with the tasks: read them by list and mark them done.
struct PeasyTools {
    let store: TaskStore
    let now: Date

    func call(_ name: String, arguments: [String: Any]) throws -> [String: Any] {
        switch name {
        case "list_projects": listProjects()
        case "list_tasks": try listTasks(arguments)
        case "set_task_status": try setTaskStatus(arguments)
        default: throw ToolError("Unknown tool: \(name)")
        }
    }

    private func listProjects() -> [String: Any] {
        let tasks = store.allTasks()
        let projects: [[String: Any]] = store.projects().map { project in
            [
                "id": project.id.uuidString,
                "name": project.name,
                "open_tasks": openCount(in: .project(project.id), from: tasks),
            ]
        }
        return [
            "today_open_tasks": openCount(in: .today, from: tasks),
            "all_open_tasks": openCount(in: .all, from: tasks),
            "projects": projects,
        ]
    }

    private func listTasks(_ arguments: [String: Any]) throws -> [String: Any] {
        let list = try resolveList(arguments["list"] as? String)
        let includeCompleted = arguments["include_completed"] as? Bool ?? false
        let query = (arguments["query"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let all = store.allTasks()
        var tasks = TaskQueries.openTasks(in: list, from: all, now: now)
        if includeCompleted {
            tasks += TaskQueries.completedTasks(in: list, from: all, now: now)
        }
        if !query.isEmpty {
            tasks = tasks.filter { $0.title.localizedCaseInsensitiveContains(query) }
        }
        return ["list": name(of: list), "tasks": tasks.map(describe)]
    }

    private func setTaskStatus(_ arguments: [String: Any]) throws -> [String: Any] {
        guard let text = arguments["task_id"] as? String,
              let id = UUID(uuidString: text.trimmingCharacters(in: .whitespacesAndNewlines))
        else { throw ToolError("task_id must be a task id from list_tasks.") }
        guard let done = arguments["done"] as? Bool else {
            throw ToolError("done must be true or false.")
        }
        guard let task = store.allTasks().first(where: { $0.id == id }) else {
            throw ToolError("No task with id \(text). Call list_tasks to get current ids.")
        }
        if task.isDone != done {
            store.toggle(task)
        }
        return ["task": describe(task)]
    }

    private func resolveList(_ value: String?) throws -> TaskList {
        let value = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch value.lowercased() {
        case "", "today": return .today
        case "all": return .all
        default: break
        }
        let projects = store.projects()
        if let id = UUID(uuidString: value), projects.contains(where: { $0.id == id }) {
            return .project(id)
        }
        if let project = projects.first(where: { $0.name.compare(value, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return .project(project.id)
        }
        let names = projects.map(\.name).joined(separator: ", ")
        throw ToolError("No project named \"\(value)\". Use today, all or one of: \(names).")
    }

    private func name(of list: TaskList) -> String {
        switch list {
        case .today: "Today"
        case .all: "All"
        case .project(let id): store.project(id: id)?.name ?? ""
        }
    }

    private func openCount(in list: TaskList, from tasks: [TaskItem]) -> Int {
        TaskQueries.openTasks(in: list, from: tasks, now: now).count
    }

    private func describe(_ task: TaskItem) -> [String: Any] {
        var fields: [String: Any] = [
            "id": task.id.uuidString,
            "title": task.title,
            "done": task.isDone,
            "overdue": task.isOverdue(now: now),
        ]
        if let project = task.project {
            fields["project"] = ["id": project.id.uuidString, "name": project.name]
        }
        if let date = task.date {
            fields["date"] = task.hasTime ? Self.dateTime(date) : Self.day(date)
        }
        if let completed = task.completedAt {
            fields["completed_at"] = Self.dateTime(completed)
        }
        return fields
    }

    private static func day(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    private static func dateTime(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}
