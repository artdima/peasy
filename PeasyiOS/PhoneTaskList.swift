import SwiftUI

struct PhoneTaskList: View {
    let list: TaskList
    let openTasks: [TaskItem]
    let completedTasks: [TaskItem]
    let projects: [Project]
    let store: TaskStore

    @State private var showsCompleted = false

    var body: some View {
        List {
            ForEach(openTasks) { task in
                PhoneTaskRow(task: task, list: list, projects: projects, store: store)
                    .taskRow()
            }
            .onMove { source, destination in
                withAnimation(.snappy) {
                    store.moveOpenTasks(in: list, from: source, to: destination)
                }
            }

            if openTasks.isEmpty {
                Text("All done")
                    .font(.body)
                    .foregroundStyle(PanelStyle.tertiary)
                    .padding(.vertical, 11)
                    .taskRow()
                    .listRowSeparator(.hidden)
            }

            if !completedTasks.isEmpty {
                Button {
                    withAnimation(.snappy) {
                        showsCompleted.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Glyph(kind: .chevron, size: 11)
                            .rotationEffect(.degrees(showsCompleted ? 90 : 0))
                        Text("Completed · \(completedTasks.count)")
                    }
                    .font(.subheadline)
                    .foregroundStyle(PanelStyle.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(showsCompleted ? .isSelected : [])
                .taskRow()
                .listRowSeparator(.hidden)

                if showsCompleted {
                    ForEach(completedTasks) { task in
                        PhoneTaskRow(task: task, list: list, projects: projects, store: store)
                            .taskRow()
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: list) {
            showsCompleted = false
        }
    }
}

private extension View {
    func taskRow() -> some View {
        listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparatorTint(PanelStyle.separator)
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
    }
}
