import Foundation
import SwiftData

@MainActor
struct TaskStore {
    let context: ModelContext

    func projects() -> [Project] {
        let descriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\.order), SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func project(id: UUID) -> Project? {
        projects().first { $0.id == id }
    }

    func allTasks() -> [TaskItem] {
        (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
    }

    func tasks(in list: TaskList) -> [TaskItem] {
        TaskQueries.tasks(in: list, from: allTasks())
    }

    func openTasks(in list: TaskList) -> [TaskItem] {
        TaskQueries.openTasks(in: list, from: allTasks())
    }

    func completedTasks(in list: TaskList) -> [TaskItem] {
        TaskQueries.completedTasks(in: list, from: allTasks())
    }

    @discardableResult
    func createProject(named name: String) -> Project? {
        guard let name = Self.clean(name) else { return nil }
        let existing = projects()
        let project = Project(
            name: name,
            order: (existing.last?.order ?? -1) + 1,
            colorHex: ProjectPalette.nextColor(excluding: existing.map(\.colorHex))
        )
        context.insert(project)
        save()
        return project
    }

    func rename(_ project: Project, to name: String) {
        guard let name = Self.clean(name), name != project.name else { return }
        project.name = name
        save()
    }

    func setColor(_ project: Project, to colorHex: String) {
        guard project.colorHex != colorHex else { return }
        project.colorHex = colorHex
        save()
    }

    /// Projects created before colors were assigned all carry the default
    /// color; give every duplicate the next free one.
    func assignDistinctColors() {
        var used: [String] = []
        var changed = false
        for project in projects() {
            if used.contains(project.colorHex) {
                project.colorHex = ProjectPalette.nextColor(excluding: used)
                changed = true
            }
            used.append(project.colorHex)
        }
        if changed {
            save()
        }
    }

    func delete(_ project: Project) {
        SyncLedger.hasLocalDeletions = true
        context.delete(project)
        save()
    }

    func moveProjects(from source: IndexSet, to destination: Int) {
        let projects = projects()
        if Ordering.move(projects, from: source, to: destination) {
            Ordering.renumber(projects)
        }
        save()
    }

    @discardableResult
    func addTask(_ title: String, to list: TaskList) -> TaskItem? {
        switch list {
        case .today: addTask(title, project: nil, isToday: true)
        case .all: addTask(title, project: nil, isToday: false)
        case .project(let id): addTask(title, project: project(id: id), isToday: false)
        }
    }

    @discardableResult
    func addTask(_ title: String, project: Project?, isToday: Bool) -> TaskItem? {
        guard let title = Self.clean(title) else { return nil }
        let lastOrder = allTasks().map(\.order).max() ?? -1
        let task = TaskItem(title: title, order: lastOrder + 1, date: isToday ? Calendar.current.startOfDay(for: .now) : nil)
        context.insert(task)
        task.project = project
        save()
        return task
    }

    func toggle(_ task: TaskItem) {
        task.isDone.toggle()
        task.completedAt = task.isDone ? Date() : nil
        save()
    }

    func setToday(_ task: TaskItem, _ isToday: Bool, now: Date = .now) {
        if isToday {
            moveToToday(task, now: now)
        } else {
            schedule(task, on: nil, hasTime: false)
        }
    }

    func moveToToday(_ task: TaskItem, now: Date = .now) {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: now)
        if task.hasTime, let date = task.date {
            let time = calendar.dateComponents([.hour, .minute], from: date)
            day = calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: 0, of: day) ?? day
        }
        schedule(task, on: day, hasTime: task.hasTime)
    }

    func schedule(_ task: TaskItem, on date: Date?, hasTime: Bool) {
        let hasTime = date != nil && hasTime
        guard task.date != date || task.hasTime != hasTime else { return }
        task.date = date
        task.hasTime = hasTime
        save()
    }

    /// Today used to be a flag. Flagged tasks get today's date, or the day they were finished.
    func moveTodayFlagsToDates(now: Date = .now) {
        let calendar = Calendar.current
        let flagged = allTasks().filter(\.isToday)
        guard !flagged.isEmpty else { return }
        for task in flagged {
            if task.date == nil {
                task.date = calendar.startOfDay(for: task.isDone ? task.completedAt ?? now : now)
            }
            task.isToday = false
        }
        save()
    }

    func rename(_ task: TaskItem, to title: String) {
        guard let title = Self.clean(title), title != task.title else { return }
        task.title = title
        save()
    }

    func delete(_ task: TaskItem) {
        SyncLedger.hasLocalDeletions = true
        context.delete(task)
        save()
    }

    func clearCompleted(in list: TaskList) {
        SyncLedger.hasLocalDeletions = true
        for task in completedTasks(in: list) {
            context.delete(task)
        }
        save()
    }

    func moveOpenTasks(in list: TaskList, from source: IndexSet, to destination: Int) {
        if Ordering.move(openTasks(in: list), from: source, to: destination) {
            Ordering.renumber(allTasks())
        }
        save()
    }

    private func save() {
        do {
            try context.save()
        } catch {
            assertionFailure("Failed to save tasks: \(error)")
        }
    }

    private static func clean(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
