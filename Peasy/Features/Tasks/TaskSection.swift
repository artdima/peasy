import SwiftUI

struct TaskSection: View {
    let list: TaskList
    let title: Text
    let openTasks: [TaskItem]
    let completedTasks: [TaskItem]
    let projects: [Project]
    let store: TaskStore
    @Bindable var model: NotchViewModel
    let onDeleteProject: (Project) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let pendingID = model.projectPendingDeletion,
               let pending = projects.first(where: { $0.id == pendingID }) {
                DeleteProjectConfirmation(project: pending) {
                    model.projectPendingDeletion = nil
                } onConfirm: {
                    model.projectPendingDeletion = nil
                    onDeleteProject(pending)
                }
                .padding(.bottom, 8)
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                title
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.17)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if !openTasks.isEmpty {
                    Text("\(openTasks.count) tasks")
                        .font(.system(size: 12))
                        .foregroundStyle(PanelStyle.tertiary)
                }
            }
            .frame(height: 24)
            .padding(EdgeInsets(top: 4.5, leading: 10, bottom: 9.5, trailing: 10))

            TaskListView(
                list: list,
                openTasks: openTasks,
                completedTasks: completedTasks,
                store: store,
                model: model
            )

            NewTaskField(model: model, placeholder: list == .today ? "New task for today" : "New task") { title in
                withAnimation(.snappy) {
                    _ = store.addTask(title, to: list)
                }
            }
            .padding(.top, 6)
        }
    }
}
