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
                Text(project.name)
                    .font(.headline)
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
                        selectedProjectID = project.id.uuidString
                    }
                }
            }
        }
        .padding(EdgeInsets(top: 6, leading: 16, bottom: 14, trailing: 16))
        .frame(width: NotchViewModel.contentWidth, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .onExitCommand(perform: actions.collapse)
        .onChange(of: model.draft) {
            model.selectedTaskID = nil
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            model.setContentHeight(height)
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
