import Foundation
import SwiftData

/// Reads the store as plain field values and writes merged changes back.
enum StoreBridge {
    static func snapshot(of context: ModelContext) -> StoreSnapshot {
        var snapshot: StoreSnapshot = [:]
        for project in (try? context.fetch(FetchDescriptor<Project>())) ?? [] {
            snapshot[RecordKey(entity: .project, id: project.id)] = fields(of: project)
        }
        for task in (try? context.fetch(FetchDescriptor<TaskItem>())) ?? [] {
            snapshot[RecordKey(entity: .task, id: task.id)] = fields(of: task)
        }
        return snapshot
    }

    static func fields(of project: Project) -> [String: FieldValue] {
        [
            "name": .text(project.name),
            "color": .text(project.colorHex),
            "order": .number(project.order),
            "created": .date(project.createdAt),
            "folder": .text(project.folder),
        ]
    }

    static func fields(of task: TaskItem) -> [String: FieldValue] {
        [
            "title": .text(task.title),
            "done": .bool(task.isDone),
            "today": .bool(task.isToday),
            "date": .date(task.date),
            "time": .bool(task.hasTime),
            "completed": .date(task.completedAt),
            "created": .date(task.createdAt),
            "order": .number(task.order),
            SyncField.project: .uuid(task.project?.id),
            "assignee": .text(task.assignee),
            "agent": .text(task.agentState),
            "claimed": .date(task.claimedAt),
            "claimedBy": .text(task.claimedBy),
            "note": .text(task.note),
            "link": .text(task.link),
            "origin": .text(task.origin),
        ]
    }

    /// Changes from other Macs are not the user's to undo.
    static func apply(_ changes: LocalChanges, to context: ModelContext) {
        guard !changes.isEmpty else { return }
        let undoManager = context.undoManager
        undoManager?.disableUndoRegistration()
        defer { undoManager?.enableUndoRegistration() }

        let projects = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        var projectsByID = Dictionary(projects.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var tasksByID = Dictionary(tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        for key in changes.deletions {
            switch key.entity {
            case .project:
                if let project = projectsByID.removeValue(forKey: key.id) {
                    context.delete(project)
                }
            case .task:
                if let task = tasksByID.removeValue(forKey: key.id) {
                    context.delete(task)
                }
            }
        }

        for (key, fields) in changes.upserts where key.entity == .project {
            let project: Project
            if let existing = projectsByID[key.id] {
                project = existing
            } else {
                project = Project(name: "", order: 0, colorHex: ProjectPalette.colors[0])
                project.id = key.id
                context.insert(project)
                projectsByID[key.id] = project
            }
            update(project, with: fields)
        }

        for (key, fields) in changes.upserts where key.entity == .task {
            let task: TaskItem
            if let existing = tasksByID[key.id] {
                task = existing
            } else {
                task = TaskItem(title: "", order: 0)
                task.id = key.id
                context.insert(task)
                tasksByID[key.id] = task
            }
            update(task, with: fields, projects: projectsByID)
        }

        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("Failed to save synced changes: \(error)")
        }
    }

    /// Only differing values are assigned, so nothing unchanged goes out to iCloud.
    private static func update(_ project: Project, with fields: [String: FieldValue]) {
        if let name = fields["name"]?.textValue, project.name != name {
            project.name = name
        }
        if let color = fields["color"]?.textValue, project.colorHex != color {
            project.colorHex = color
        }
        if let order = fields["order"]?.numberValue, project.order != order {
            project.order = order
        }
        if let created = fields["created"]?.dateValue, project.createdAt != created {
            project.createdAt = created
        }
        if let folder = fields["folder"]?.textValue, project.folder != folder {
            project.folder = folder
        }
    }

    private static func update(_ task: TaskItem, with fields: [String: FieldValue], projects: [UUID: Project]) {
        if let title = fields["title"]?.textValue, task.title != title {
            task.title = title
        }
        if let done = fields["done"]?.boolValue, task.isDone != done {
            task.isDone = done
        }
        if let today = fields["today"]?.boolValue, task.isToday != today {
            task.isToday = today
        }
        if let date = fields["date"], task.date != date.dateValue {
            task.date = date.dateValue
        }
        if let time = fields["time"]?.boolValue, task.hasTime != time {
            task.hasTime = time
        }
        if let completed = fields["completed"], task.completedAt != completed.dateValue {
            task.completedAt = completed.dateValue
        }
        if let created = fields["created"]?.dateValue, task.createdAt != created {
            task.createdAt = created
        }
        if let order = fields["order"]?.numberValue, task.order != order {
            task.order = order
        }
        if let link = fields[SyncField.project] {
            let project = link.uuidValue.flatMap { projects[$0] }
            if task.project?.id != project?.id {
                task.project = project
            }
        }
        if let assignee = fields["assignee"]?.textValue, task.assignee != assignee {
            task.assignee = assignee
        }
        if let agent = fields["agent"]?.textValue, task.agentState != agent {
            task.agentState = agent
        }
        if let claimed = fields["claimed"], task.claimedAt != claimed.dateValue {
            task.claimedAt = claimed.dateValue
        }
        if let claimedBy = fields["claimedBy"]?.textValue, task.claimedBy != claimedBy {
            task.claimedBy = claimedBy
        }
        if let note = fields["note"]?.textValue, task.note != note {
            task.note = note
        }
        if let url = fields["link"]?.textValue, task.link != url {
            task.link = url
        }
        if let origin = fields["origin"]?.textValue, task.origin != origin {
            task.origin = origin
        }
    }
}
