import SwiftUI

struct TaskListView: View {
    static let maxHeight: CGFloat = 320

    let project: Project
    let store: TaskStore
    let model: NotchViewModel

    @State private var showsCompleted = false
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        let openTasks = store.openTasks(in: project)
        let completedTasks = store.completedTasks(in: project)
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                if openTasks.isEmpty {
                    Text(completedTasks.isEmpty ? "No tasks yet" : "All done")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }
                ForEach(openTasks) { task in
                    TaskRow(task: task, store: store, model: model)
                }
                if !completedTasks.isEmpty {
                    CompletedHeader(count: completedTasks.count, isExpanded: $showsCompleted)
                    if showsCompleted {
                        ForEach(completedTasks) { task in
                            TaskRow(task: task, store: store, model: model)
                        }
                    }
                }
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                contentHeight = height
            }
        }
        .frame(height: min(contentHeight, Self.maxHeight))
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
