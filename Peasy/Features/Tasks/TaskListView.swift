import SwiftUI

struct TaskListView: View {
    let list: TaskList
    let openTasks: [TaskItem]
    let completedTasks: [TaskItem]
    let store: TaskStore
    let model: NotchViewModel

    @State private var showsCompleted = false
    @State private var dropTargetID: UUID?
    @State private var isEndTargeted = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(openTasks) { task in
                        TaskRow(task: task, list: list, store: store, model: model)
                            .draggable(task.id.uuidString)
                            .dropDestination(for: String.self) { items, _ in
                                moveTask(withID: items.first, before: task)
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

                    if openTasks.isEmpty {
                        Text("All done")
                            .font(.system(size: 13))
                            .foregroundStyle(PanelStyle.tertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    } else {
                        Color.clear
                            .frame(height: 8)
                            .dropDestination(for: String.self) { items, _ in
                                moveTask(withID: items.first, before: nil)
                            } isTargeted: { targeted in
                                isEndTargeted = targeted
                            }
                            .overlay(alignment: .top) {
                                if isEndTargeted {
                                    DropIndicator(axis: .horizontal)
                                }
                            }
                    }

                    if !completedTasks.isEmpty {
                        CompletedDisclosure(count: completedTasks.count, isExpanded: $showsCompleted)
                        if showsCompleted {
                            ForEach(completedTasks) { task in
                                TaskRow(task: task, list: list, store: store, model: model)
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
            .onChange(of: list) {
                showsCompleted = false
            }
        }
    }

    private func moveTask(withID id: String?, before target: TaskItem?) -> Bool {
        guard let id, let source = openTasks.firstIndex(where: { $0.id.uuidString == id }) else { return false }
        let destination = target.flatMap { target in openTasks.firstIndex { $0.id == target.id } } ?? openTasks.count
        guard destination != source, destination != source + 1 else { return true }
        withAnimation(.snappy) {
            store.moveOpenTasks(in: list, from: IndexSet(integer: source), to: destination)
        }
        return true
    }
}

struct CompletedDisclosure: View {
    let count: Int
    @Binding var isExpanded: Bool

    @State private var isHovered = false

    var body: some View {
        Button {
            withAnimation(.snappy) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                Text("Completed · \(count)")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isHovered ? PanelStyle.primary : PanelStyle.tertiary)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .padding(.top, 6)
        .accessibilityAddTraits(isExpanded ? .isSelected : [])
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
