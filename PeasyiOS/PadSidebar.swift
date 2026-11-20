import SwiftUI

struct PadSidebar: View {
    let projects: [Project]
    let tasks: [TaskItem]
    let store: TaskStore
    @Binding var selection: TaskList

    @State private var edit: ProjectEdit?

    var body: some View {
        List(selection: listSelection) {
            Section {
                row(.today, title: Text("Today")) {
                    SproutIcon()
                        .frame(width: 18, height: 18)
                }
                row(.all, title: Text("All")) {
                    ColorDot(hex: ProjectPalette.noProject, size: 10)
                }
            }

            Section {
                ForEach(projects) { project in
                    row(.project(project.id), title: Text(project.name)) {
                        ColorDot(hex: project.colorHex, size: 10)
                    }
                    .contextMenu {
                        ProjectMenu(project: project, projects: projects, store: store, isVertical: true, edit: $edit, selection: $selection)
                    }
                }
                .onMove { source, destination in
                    withAnimation(.snappy) {
                        store.moveProjects(from: source, to: destination)
                    }
                }

                Button {
                    edit = .naming
                } label: {
                    Label {
                        Text("New project")
                    } icon: {
                        Glyph(kind: .plus, size: 14)
                    }
                }
                .foregroundStyle(PanelStyle.secondary)
            } header: {
                Text("Projects")
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(PhoneStyle.background)
        .projectEditing($edit, store: store, selection: $selection)
    }

    private func row<Icon: View>(_ list: TaskList, title: Text, @ViewBuilder icon: () -> Icon) -> some View {
        Label {
            title
                .lineLimit(1)
        } icon: {
            icon()
                .frame(width: 22, height: 22)
        }
        .badge(TaskQueries.ownOpenTasks(in: list, from: tasks, now: DayClock.shared.today).count)
        .tag(list)
    }

    private var listSelection: Binding<TaskList?> {
        Binding {
            selection
        } set: { list in
            if let list {
                selection = list
            }
        }
    }
}
