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

/// What Claude can do with the tasks: read them, add tasks for the user and report on the ones it was given.
struct PeasyTools {
    static let maximumTitleLength = 200
    static let maximumNoteLength = 2000
    static let maximumLinkLength = 2000
    static let agentTasksPerHour = 20
    static let linkSchemes: Set<String> = ["https", "http", "file"]

    let store: TaskStore
    let now: Date
    var time: Date = .now
    var session = MCPSession(id: "")

    func call(_ name: String, arguments: [String: Any]) throws -> [String: Any] {
        switch name {
        case "list_projects": listProjects()
        case "list_tasks": try listTasks(arguments)
        case "add_task": try addTask(arguments)
        case "update_task": try updateTask(arguments)
        case "set_task_status": try setTaskStatus(arguments)
        default: throw ToolError("Unknown tool: \(name)")
        }
    }

    private var sessionProject: Project? {
        store.project(forWorkspace: session.workspace)
    }

    private func listProjects() -> [String: Any] {
        let tasks = store.allTasks()
        let current = sessionProject
        let projects: [[String: Any]] = store.projects().map { project in
            var fields: [String: Any] = [
                "id": project.id.uuidString,
                "name": project.name,
                "open_tasks": openCount(in: .project(project.id), from: tasks),
                "claude_tasks": claudeCount(in: .project(project.id), from: tasks),
            ]
            if project.id == current?.id {
                fields["current"] = true
            }
            return fields
        }
        var result: [String: Any] = [
            "today_open_tasks": openCount(in: .today, from: tasks),
            "all_open_tasks": openCount(in: .all, from: tasks),
            "projects": projects,
        ]
        if let folder = session.workspace.flatMap(ProjectMatch.folderName) {
            result["workspace"] = folder
        }
        return result
    }

    private func listTasks(_ arguments: [String: Any]) throws -> [String: Any] {
        let list = try resolveList(arguments["list"] as? String)
        let assignee = try resolveAssignee(arguments["assignee"] as? String)
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
        if let assignee {
            tasks = tasks.filter { $0.isForClaude == assignee }
        }
        return ["list": name(of: list), "tasks": tasks.map(describe)]
    }

    private func addTask(_ arguments: [String: Any]) throws -> [String: Any] {
        guard let title = try text(arguments["title"], named: "title", limit: Self.maximumTitleLength), !title.isEmpty else {
            throw ToolError("title is required.")
        }
        let note = try text(arguments["note"], named: "note", limit: Self.maximumNoteLength) ?? ""
        let link = try validLink(arguments["link"]) ?? ""
        let project = try resolveProject(arguments["project"] as? String)
        let schedule = try schedule(from: arguments["date"])

        let open = store.openTasks(in: .all)
        if let existing = open.first(where: { $0.project?.id == project?.id && $0.title.compare(title, options: .caseInsensitive) == .orderedSame }) {
            return ["task": describe(existing), "duplicate": true]
        }
        let hourAgo = time.addingTimeInterval(-60 * 60)
        let recent = store.allTasks().filter { !$0.origin.isEmpty && $0.createdAt > hourAgo }
        guard recent.count < Self.agentTasksPerHour else {
            throw ToolError("Claude has added \(Self.agentTasksPerHour) tasks in the last hour, which is the limit. Tell the user the rest in chat instead.")
        }
        guard let task = store.addTask(
            title,
            project: project,
            date: schedule?.date,
            hasTime: schedule?.hasTime ?? false,
            note: note,
            link: link,
            origin: session.client ?? "Claude"
        ) else {
            throw ToolError("title is required.")
        }
        return ["task": describe(task), "duplicate": false]
    }

    private func updateTask(_ arguments: [String: Any]) throws -> [String: Any] {
        let task = try findTask(arguments["task_id"])
        let status = (arguments["status"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let note = try text(arguments["note"], named: "note", limit: Self.maximumNoteLength)
        let link = try validLink(arguments["link"])
        guard !status.isEmpty || note != nil || link != nil else {
            throw ToolError("Pass status, note or link.")
        }

        switch status {
        case "working":
            guard task.isForClaude, !task.isDone else {
                throw ToolError("Only open tasks assigned to Claude can be worked on. This one is the user's; they can hand it to Claude in Peasy.")
            }
            if task.isClaimed(now: time), task.claimedBy != session.id, let since = task.claimedAt {
                throw ToolError("Another Claude session has been working on this task since \(Self.clock(since)). Pick another task.")
            }
        case "blocked":
            guard task.isForClaude, !task.isDone else {
                throw ToolError("Only open tasks assigned to Claude can be handed back.")
            }
            guard let note, !note.isEmpty else {
                throw ToolError("blocked needs a note saying what you need from the user.")
            }
        case "", "done", "open":
            break
        default:
            throw ToolError("status must be working, done, blocked or open.")
        }

        if let link {
            store.setLink(link, for: task)
        }
        switch status {
        case "working":
            store.claim(task, by: session.id, at: time)
            if let note {
                store.setNote(note, for: task)
            }
        case "done":
            store.finish(task, note: note, at: time)
        case "blocked":
            store.handBack(task, note: note ?? "", at: time)
        case "open":
            if task.isDone {
                store.toggle(task)
            } else {
                store.release(task)
            }
            if let note {
                store.setNote(note, for: task)
            }
        default:
            if let note {
                store.setNote(note, for: task)
            }
        }
        return ["task": describe(task)]
    }

    private func setTaskStatus(_ arguments: [String: Any]) throws -> [String: Any] {
        let task = try findTask(arguments["task_id"])
        guard let done = arguments["done"] as? Bool else {
            throw ToolError("done must be true or false.")
        }
        if task.isDone != done {
            store.toggle(task)
        }
        return ["task": describe(task)]
    }

    private func findTask(_ value: Any?) throws -> TaskItem {
        guard let text = value as? String,
              let id = UUID(uuidString: text.trimmingCharacters(in: .whitespacesAndNewlines))
        else { throw ToolError("task_id must be a task id from list_tasks.") }
        guard let task = store.allTasks().first(where: { $0.id == id }) else {
            throw ToolError("No task with id \(text). Call list_tasks to get current ids.")
        }
        return task
    }

    private func resolveList(_ value: String?) throws -> TaskList {
        let value = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch value.lowercased() {
        case "": return sessionProject.map { TaskList.project($0.id) } ?? .today
        case "today": return .today
        case "all": return .all
        default: break
        }
        guard let project = try resolveProject(value) else { return .today }
        return .project(project.id)
    }

    private func resolveProject(_ value: String?) throws -> Project? {
        let value = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty else { return sessionProject }
        let projects = store.projects()
        if let id = UUID(uuidString: value), let project = projects.first(where: { $0.id == id }) {
            return project
        }
        if let project = projects.first(where: { $0.name.compare(value, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return project
        }
        let names = projects.map(\.name).joined(separator: ", ")
        throw ToolError("No project named \"\(value)\". Use one of: \(names).")
    }

    private func resolveAssignee(_ value: String?) throws -> Bool? {
        switch value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "" {
        case "", "any": nil
        case "me", "user": false
        case "claude": true
        default: throw ToolError("assignee must be me, claude or any.")
        }
    }

    private func text(_ value: Any?, named name: String, limit: Int) throws -> String? {
        guard let value else { return nil }
        guard let text = value as? String else {
            throw ToolError("\(name) must be text.")
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= limit else {
            throw ToolError("\(name) is longer than \(limit) characters.")
        }
        return trimmed
    }

    private func validLink(_ value: Any?) throws -> String? {
        guard let link = try text(value, named: "link", limit: Self.maximumLinkLength) else { return nil }
        guard !link.isEmpty else { return "" }
        guard let scheme = URL(string: link)?.scheme?.lowercased(), Self.linkSchemes.contains(scheme) else {
            throw ToolError("link must be an https, http or file URL.")
        }
        return link
    }

    private func schedule(from value: Any?) throws -> (date: Date, hasTime: Bool)? {
        guard let text = try text(value, named: "date", limit: 40), !text.isEmpty else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        switch text.lowercased() {
        case "today":
            return (today, false)
        case "tomorrow":
            return (calendar.date(byAdding: .day, value: 1, to: today) ?? today, false)
        default:
            break
        }
        let moment = ISO8601DateFormatter()
        moment.formatOptions = [.withInternetDateTime]
        if let date = moment.date(from: text) {
            return (date, true)
        }
        let local = DateFormatter()
        local.locale = Locale(identifier: "en_US_POSIX")
        local.timeZone = .current
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd HH:mm"] {
            local.dateFormat = format
            if let date = local.date(from: text) {
                return (date, true)
            }
        }
        local.dateFormat = "yyyy-MM-dd"
        if let date = local.date(from: text) {
            return (calendar.startOfDay(for: date), false)
        }
        throw ToolError("date must be today, tomorrow, a day like 2026-11-14 or a day and time like 2026-11-14T15:00.")
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

    private func claudeCount(in list: TaskList, from tasks: [TaskItem]) -> Int {
        TaskQueries.openTasks(in: list, from: tasks, now: now).filter(\.isForClaude).count
    }

    private func state(of task: TaskItem) -> String? {
        guard !task.isDone else { return nil }
        if task.isForClaude {
            return task.isClaimed(now: time) ? "working" : "waiting"
        }
        return task.agentStatus == .returned ? "returned" : nil
    }

    private func describe(_ task: TaskItem) -> [String: Any] {
        var fields: [String: Any] = [
            "id": task.id.uuidString,
            "title": task.title,
            "done": task.isDone,
            "overdue": task.isOverdue(now: now),
            "assignee": task.isForClaude ? "claude" : "me",
        ]
        if let state = state(of: task) {
            fields["state"] = state
        }
        if !task.note.isEmpty {
            fields["note"] = task.note
        }
        if !task.link.isEmpty {
            fields["link"] = task.link
        }
        if !task.origin.isEmpty {
            fields["origin"] = task.origin
        }
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

    private static func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
