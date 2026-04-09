import SwiftUI

struct TaskListView: View {
    let project: Project
    let store: TaskStore
    let model: NotchViewModel

    @AppStorage(PanelSettings.showsCompletedKey) private var showsCompletedSection = true
    @State private var showsCompleted = false
    @State private var dropTargetID: UUID?
    @State private var isEndTargeted = false

    var body: some View {
        let openTasks = store.openTasks(in: project)
        let completedTasks = store.completedTasks(in: project)
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if openTasks.isEmpty {
                        Text(completedTasks.isEmpty ? LocalizedStringKey("No tasks yet") : "All done")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                    }
                    ForEach(openTasks) { task in
                        TaskRow(task: task, store: store, model: model)
                            .draggable(task.id.uuidString)
                            .dropDestination(for: String.self) { items, _ in
                                moveTask(withID: items.first, before: task, in: openTasks)
                            } isTargeted: { targeted in
                                if targeted {
                                    dropTargetID = task.id
                                } else if dropTargetID == task.id {
                                    dropTargetID = nil
                                }
                            }
                            .overlay(alignment: .top) {
                                if dropTargetID == task.id {
                                    DropIndicator(axis: .horizontal)
                                }
                            }
                    }
                    if !openTasks.isEmpty {
                        Color.clear
                            .frame(height: 8)
                            .dropDestination(for: String.self) { items, _ in
                                moveTask(withID: items.first, before: nil, in: openTasks)
                            } isTargeted: { targeted in
                                isEndTargeted = targeted
                            }
                            .overlay(alignment: .top) {
                                if isEndTargeted {
                                    DropIndicator(axis: .horizontal)
                                }
                            }
                    }
                    if showsCompletedSection, !completedTasks.isEmpty {
                        CompletedHeader(count: completedTasks.count, isExpanded: $showsCompleted)
                        if showsCompleted {
                            ForEach(completedTasks) { task in
                                TaskRow(task: task, store: store, model: model)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .onChange(of: model.selectedTaskID) { _, id in
                guard let id else { return }
                withAnimation(.snappy) {
                    proxy.scrollTo(id)
                }
            }
        }
    }

    private func moveTask(withID id: String?, before target: TaskItem?, in tasks: [TaskItem]) -> Bool {
        guard let id, let source = tasks.firstIndex(where: { $0.id.uuidString == id }) else { return false }
        let destination = target.flatMap { target in tasks.firstIndex { $0.id == target.id } } ?? tasks.count
        guard destination != source, destination != source + 1 else { return true }
        withAnimation(.snappy) {
            store.moveOpenTasks(in: project, from: IndexSet(integer: source), to: destination)
        }
        return true
    }
}

struct DropIndicator: View {
    let axis: Axis

    var body: some View {
        Capsule()
            .fill(.tint)
            .frame(width: axis == .vertical ? 2 : nil, height: axis == .horizontal ? 2 : nil)
            .padding(axis == .horizontal ? .horizontal : .vertical, 6)
            .offset(x: axis == .vertical ? -3 : 0, y: axis == .horizontal ? -1 : 0)
            .allowsHitTesting(false)
    }
}

struct CompletedHeader: View {
    let count: Int
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            withAnimation(.snappy) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                Text("Completed · \(count)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
