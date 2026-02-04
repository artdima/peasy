import Foundation
import SwiftData

@MainActor
struct TaskStore {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func projects() -> [Project] {
        let descriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\.order), SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func project(id: UUID) -> Project? {
        projects().first { $0.id == id }
    }

    @discardableResult
    func createProject(named name: String) -> Project? {
        guard let name = Self.clean(name) else { return nil }
        let project = Project(name: name, order: (projects().last?.order ?? -1) + 1)
        context.insert(project)
        save()
        return project
    }

    func rename(_ project: Project, to name: String) {
        guard let name = Self.clean(name), name != project.name else { return }
        project.name = name
        save()
    }

    func delete(_ project: Project) {
        context.delete(project)
        save()
    }

    func moveProjects(from source: IndexSet, to destination: Int) {
        Ordering.move(projects(), from: source, to: destination)
        save()
    }

    func openTasks(in project: Project) -> [TaskItem] {
        sortedTasks(in: project).filter { !$0.isDone }
    }

    func completedTasks(in project: Project) -> [TaskItem] {
        sortedTasks(in: project)
            .filter(\.isDone)
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    @discardableResult
    func addTask(_ title: String, to project: Project) -> TaskItem? {
        guard let title = Self.clean(title) else { return nil }
        let lastOrder = sortedTasks(in: project).last?.order ?? -1
        let task = TaskItem(title: title, order: lastOrder + 1)
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

    func rename(_ task: TaskItem, to title: String) {
        guard let title = Self.clean(title), title != task.title else { return }
        task.title = title
        save()
    }

    func delete(_ task: TaskItem) {
        context.delete(task)
        save()
    }

    func clearCompleted(in project: Project) {
        for task in completedTasks(in: project) {
            context.delete(task)
        }
        save()
    }

    func moveOpenTasks(in project: Project, from source: IndexSet, to destination: Int) {
        Ordering.move(openTasks(in: project), from: source, to: destination)
        save()
    }

    private func sortedTasks(in project: Project) -> [TaskItem] {
        (project.tasks ?? []).sorted { ($0.order, $0.createdAt) < ($1.order, $1.createdAt) }
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
