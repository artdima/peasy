import SwiftUI

struct TaskRow: View {
    let task: TaskItem
    let store: TaskStore
    @Bindable var model: NotchViewModel

    @State private var isHovered = false
    @State private var editedTitle = ""
    @FocusState private var isEditorFocused: Bool

    private var isEditing: Bool { model.editingTaskID == task.id }
    private var isSelected: Bool { model.selectedTaskID == task.id }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Button(action: toggle) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(task.isDone ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isDone ? LocalizedStringKey("Mark as not done") : "Mark as done")

            if isEditing {
                TextField("Task", text: $editedTitle)
                    .textFieldStyle(.plain)
                    .focused($isEditorFocused)
                    .onSubmit(commitEdit)
                    .onExitCommand(perform: cancelEdit)
                    .onAppear {
                        editedTitle = task.title
                        isEditorFocused = true
                    }
                    .onChange(of: isEditorFocused) { _, focused in
                        if !focused {
                            commitEdit()
                        }
                    }
            } else {
                Text(task.title)
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture(count: 2, perform: startEditing)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(isSelected ? 0.12 : isHovered ? 0.07 : 0))
        )
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { model.selectedTaskID = task.id })
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .contextMenu {
            Button(task.isDone ? LocalizedStringKey("Mark as Not Done") : "Mark as Done", action: toggle)
            Button("Edit", action: startEditing)
            Divider()
            Button("Delete", role: .destructive, action: delete)
        }
    }

    private func toggle() {
        withAnimation(.snappy) {
            store.toggle(task)
        }
    }

    private func startEditing() {
        model.selectedTaskID = task.id
        model.editingTaskID = task.id
    }

    private func commitEdit() {
        guard isEditing else { return }
        store.rename(task, to: editedTitle)
        model.editingTaskID = nil
        model.focusNewTask()
    }

    private func cancelEdit() {
        model.editingTaskID = nil
        model.focusNewTask()
    }

    private func delete() {
        if isSelected {
            model.selectedTaskID = nil
        }
        withAnimation(.snappy) {
            store.delete(task)
        }
    }
}
