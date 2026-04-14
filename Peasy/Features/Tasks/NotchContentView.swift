import SwiftData
import SwiftUI

struct NotchContentView: View {
    let model: NotchViewModel
    let actions: NotchActions

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Project.order), SortDescriptor(\Project.createdAt)])
    private var projects: [Project]
    @Query private var tasks: [TaskItem]
    @AppStorage(TaskList.storageKey) private var selectedListValue = TaskList.today.storageValue

    var body: some View {
        let store = TaskStore(context: modelContext)
        let list = selectedList
        let openTasks = TaskQueries.openTasks(in: list, from: tasks)
        VStack(spacing: 0) {
            PanelHeader(model: model)
                .frame(height: model.headerHeight)

            HStack(alignment: .top, spacing: 12) {
                ProjectSidebar(
                    projects: projects,
                    tasks: tasks,
                    selection: list,
                    store: store,
                    model: model,
                    onSelect: select,
                    onDelete: { delete($0, store: store) }
                )
                .frame(width: 172)

                Rectangle()
                    .fill(PanelStyle.separator)
                    .frame(width: 1)

                TaskSection(
                    list: list,
                    title: title(for: list),
                    openTasks: openTasks,
                    completedTasks: TaskQueries.completedTasks(in: list, from: tasks),
                    projects: projects,
                    store: store,
                    model: model,
                    onDeleteProject: { delete($0, store: store) }
                )
                .background {
                    Button("Delete Task") {
                        deleteSelectedTask(store: store)
                    }
                    .keyboardShortcut(.delete, modifiers: .command)
                    .disabled(model.selectedTaskID == nil || model.editingTaskID != nil)
                    .opacity(0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .padding(EdgeInsets(top: 10, leading: 14, bottom: 14, trailing: 14))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(PanelStyle.primary)
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

    private var selectedList: TaskList {
        let list = TaskList(storageValue: selectedListValue)
        if case .project(let id) = list, !projects.contains(where: { $0.id == id }) {
            return .today
        }
        return list
    }

    private var lists: [TaskList] {
        [.today, .inbox] + projects.map { .project($0.id) }
    }

    private func title(for list: TaskList) -> Text {
        switch list {
        case .today:
            Text("Today")
        case .inbox:
            Text("Inbox")
        case .project(let id):
            Text(verbatim: projects.first { $0.id == id }?.name ?? "")
        }
    }

    private func perform(_ command: NotchViewModel.Command, store: TaskStore) {
        switch command {
        case .selectList(let index):
            if lists.indices.contains(index) {
                select(lists[index])
            }
        case .focusNewTask:
            model.selectedTaskID = nil
            model.focusNewTask()
        case .moveSelection(let delta):
            let open = TaskQueries.openTasks(in: selectedList, from: tasks)
            guard !open.isEmpty else { return }
            if let current = open.firstIndex(where: { $0.id == model.selectedTaskID }) {
                let next = min(max(current + delta, 0), open.count - 1)
                model.selectedTaskID = open[next].id
            } else {
                model.selectedTaskID = delta > 0 ? open.first?.id : open.last?.id
            }
        case .toggleSelected:
            let open = TaskQueries.openTasks(in: selectedList, from: tasks)
            guard let index = open.firstIndex(where: { $0.id == model.selectedTaskID }) else { return }
            withAnimation(.snappy) {
                store.toggle(open[index])
            }
            let remaining = store.openTasks(in: selectedList)
            model.selectedTaskID = remaining.isEmpty ? nil : remaining[min(index, remaining.count - 1)].id
        case .editSelected:
            model.editingTaskID = model.selectedTaskID
        }
    }

    private func select(_ list: TaskList) {
        selectedListValue = list.storageValue
        model.selectedTaskID = nil
        model.editingTaskID = nil
    }

    private func delete(_ project: Project, store: TaskStore) {
        if selectedList == .project(project.id) {
            selectedListValue = TaskList.today.storageValue
        }
        withAnimation(.snappy) {
            store.delete(project)
        }
    }

    private func deleteSelectedTask(store: TaskStore) {
        guard let id = model.selectedTaskID, let task = tasks.first(where: { $0.id == id }) else { return }
        model.selectedTaskID = nil
        withAnimation(.snappy) {
            store.delete(task)
        }
    }
}
