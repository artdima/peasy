import SwiftData
import SwiftUI

struct NotchContentView: View {
    let model: NotchViewModel
    let actions: NotchActions

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Project.order), SortDescriptor(\Project.createdAt)])
    private var projects: [Project]
    @AppStorage("selectedProjectID") private var selectedProjectID = ""

    var body: some View {
        let store = TaskStore(context: modelContext)
        VStack(alignment: .leading, spacing: 10) {
            if let project = selectedProject {
                ProjectSwitcher(
                    projects: projects,
                    selectedID: project.id,
                    store: store,
                    model: model,
                    onSelect: select,
                    onDelete: { delete($0, store: store) }
                )
                if let pendingID = model.projectPendingDeletion,
                   let pending = projects.first(where: { $0.id == pendingID }) {
                    DeleteProjectConfirmation(project: pending) {
                        model.projectPendingDeletion = nil
                    } onConfirm: {
                        model.projectPendingDeletion = nil
                        delete(pending, store: store)
                    }
                }
                NewTaskField(model: model) { title in
                    withAnimation(.snappy) {
                        _ = store.addTask(title, to: project)
                    }
                }
                TaskListView(project: project, store: store, model: model)
                    .background {
                        Button("Delete Task") {
                            deleteSelectedTask(in: project, store: store)
                        }
                        .keyboardShortcut(.delete, modifiers: .command)
                        .disabled(model.selectedTaskID == nil || model.editingTaskID != nil)
                        .opacity(0)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }
            } else {
                FirstProjectView { name in
                    if let project = store.createProject(named: name) {
                        select(project)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .contextMenu {
            Button("About Peasy", action: actions.showAbout)
            Button("Settings…", action: actions.openSettings)
            Divider()
            Button("Quit Peasy", action: actions.quit)
        }
        .onExitCommand(perform: actions.collapse)
        .onChange(of: model.draft) {
            model.selectedTaskID = nil
        }
        .onChange(of: model.lastCommand) { _, event in
            if let event {
                perform(event.command, store: store)
            }
        }
    }

    private func perform(_ command: NotchViewModel.Command, store: TaskStore) {
        switch command {
        case .selectProject(let index):
            if projects.indices.contains(index) {
                select(projects[index])
            }
        case .focusNewTask:
            model.selectedTaskID = nil
            model.focusNewTask()
        case .moveSelection(let delta):
            guard let project = selectedProject else { return }
            let tasks = store.openTasks(in: project)
            guard !tasks.isEmpty else { return }
            if let current = tasks.firstIndex(where: { $0.id == model.selectedTaskID }) {
                let next = min(max(current + delta, 0), tasks.count - 1)
                model.selectedTaskID = tasks[next].id
            } else {
                model.selectedTaskID = delta > 0 ? tasks.first?.id : tasks.last?.id
            }
        case .toggleSelected:
            guard let project = selectedProject else { return }
            let tasks = store.openTasks(in: project)
            guard let index = tasks.firstIndex(where: { $0.id == model.selectedTaskID }) else { return }
            withAnimation(.snappy) {
                store.toggle(tasks[index])
            }
            let remaining = store.openTasks(in: project)
            model.selectedTaskID = remaining.isEmpty ? nil : remaining[min(index, remaining.count - 1)].id
        case .editSelected:
            model.editingTaskID = model.selectedTaskID
        }
    }

    private func select(_ project: Project) {
        selectedProjectID = project.id.uuidString
        model.selectedTaskID = nil
        model.editingTaskID = nil
    }

    private func delete(_ project: Project, store: TaskStore) {
        if project.id.uuidString == selectedProjectID {
            selectedProjectID = ""
        }
        withAnimation(.snappy) {
            store.delete(project)
        }
    }

    private func deleteSelectedTask(in project: Project, store: TaskStore) {
        guard let id = model.selectedTaskID, let task = project.tasks?.first(where: { $0.id == id }) else { return }
        model.selectedTaskID = nil
        withAnimation(.snappy) {
            store.delete(task)
        }
    }

    private var selectedProject: Project? {
        projects.first { $0.id.uuidString == selectedProjectID } ?? projects.first
    }
}
