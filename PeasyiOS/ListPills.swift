import SwiftUI

struct ListPills: View {
    let projects: [Project]
    let tasks: [TaskItem]
    let store: TaskStore
    @Binding var selection: TaskList

    @State private var edit: ProjectEdit?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    PhonePill(title: Text("Today"), count: count(in: .today), isSelected: selection == .today, action: { selection = .today }) {
                        SproutIcon()
                            .frame(width: 16, height: 16)
                    }
                    .id(TaskList.today)

                    PhonePill(title: Text("All"), count: count(in: .all), isSelected: selection == .all, action: { selection = .all }) {
                        ColorDot(hex: ProjectPalette.noProject)
                    }
                    .id(TaskList.all)

                    ForEach(projects) { project in
                        let list = TaskList.project(project.id)
                        PhonePill(title: Text(project.name), count: count(in: list), isSelected: selection == list, action: { selection = list }) {
                            ColorDot(hex: project.colorHex)
                        }
                        .contextMenu {
                            ProjectMenu(project: project, projects: projects, store: store, edit: $edit, selection: $selection)
                        }
                        .id(list)
                    }

                    newProjectButton
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                proxy.scrollTo(selection, anchor: .center)
            }
            .onChange(of: selection) { _, list in
                withAnimation(.snappy) {
                    proxy.scrollTo(list, anchor: .center)
                }
            }
        }
        .projectEditing($edit, store: store, selection: $selection)
    }

    private var newProjectButton: some View {
        Button {
            edit = .naming
        } label: {
            HStack(spacing: 7) {
                Glyph(kind: .plus, size: 12)
                Text("Project")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(PanelStyle.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .frame(minHeight: 34)
            .overlay {
                Capsule()
                    .strokeBorder(PanelStyle.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("New project"))
    }

    private func count(in list: TaskList) -> Int {
        TaskQueries.ownOpenTasks(in: list, from: tasks, now: DayClock.shared.today).count
    }
}
