import SwiftUI
import UIKit

enum ProjectEdit: Equatable {
    case naming
    case renaming(Project)
    case deleting(Project)
}

/// Rename, color, order and delete, shared by the project pills and the iPad sidebar.
struct ProjectMenu: View {
    let project: Project
    let projects: [Project]
    let store: TaskStore
    var isVertical = false
    @Binding var edit: ProjectEdit?
    @Binding var selection: TaskList

    var body: some View {
        Button("Rename") {
            edit = .renaming(project)
        }
        Menu("Color") {
            ForEach(ProjectPalette.colors, id: \.self) { hex in
                Button {
                    store.setColor(project, to: hex)
                } label: {
                    Label {
                        Text(ProjectPalette.name(of: hex))
                    } icon: {
                        Image(uiImage: Self.swatch(hex: hex, isOn: project.colorHex == hex))
                    }
                }
            }
        }
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            if index > 0 {
                Button(isVertical ? LocalizedStringKey("Move Up") : "Move Left") {
                    move(from: index, to: index - 1)
                }
            }
            if index < projects.count - 1 {
                Button(isVertical ? LocalizedStringKey("Move Down") : "Move Right") {
                    move(from: index, to: index + 2)
                }
            }
        }
        Button("Delete…", role: .destructive) {
            if (project.tasks ?? []).isEmpty {
                ProjectEditing.delete(project, store: store, selection: $selection)
            } else {
                edit = .deleting(project)
            }
        }
    }

    private func move(from index: Int, to destination: Int) {
        withAnimation(.snappy) {
            store.moveProjects(from: IndexSet(integer: index), to: destination)
        }
    }

    private static func swatch(hex: String, isOn: Bool) -> UIImage {
        let symbol = UIImage(systemName: isOn ? "checkmark.circle.fill" : "circle.fill") ?? UIImage()
        return symbol.withTintColor(PlatformColor(hex: hex), renderingMode: .alwaysOriginal)
    }
}

struct ProjectEditing: ViewModifier {
    @Binding var edit: ProjectEdit?
    let store: TaskStore
    @Binding var selection: TaskList

    @State private var name = ""

    func body(content: Content) -> some View {
        content
            .alert("New project", isPresented: isPresented { $0 == .naming }) {
                TextField("Project name", text: $name)
                Button("Cancel", role: .cancel) {}
                Button("Create") {
                    if let project = store.createProject(named: name) {
                        selection = .project(project.id)
                    }
                }
            }
            .alert("Rename", isPresented: isPresented { $0.renaming != nil }, presenting: edit?.renaming) { project in
                TextField("Project name", text: $name)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    store.rename(project, to: name)
                }
            }
            .confirmationDialog(
                Text("Delete “\(edit?.deleting?.name ?? "")” and all its tasks?"),
                isPresented: isPresented { $0.deleting != nil },
                titleVisibility: .visible,
                presenting: edit?.deleting
            ) { project in
                Button("Delete", role: .destructive) {
                    Self.delete(project, store: store, selection: $selection)
                }
                Button("Cancel", role: .cancel) {}
            }
            .onChange(of: edit) { _, edit in
                if let edit {
                    name = edit.renaming?.name ?? ""
                }
            }
    }

    static func delete(_ project: Project, store: TaskStore, selection: Binding<TaskList>) {
        if selection.wrappedValue == .project(project.id) {
            selection.wrappedValue = .today
        }
        withAnimation(.snappy) {
            store.delete(project)
        }
    }

    private func isPresented(_ matches: @escaping (ProjectEdit) -> Bool) -> Binding<Bool> {
        Binding {
            edit.map(matches) ?? false
        } set: { isOn in
            if !isOn {
                edit = nil
            }
        }
    }
}

extension ProjectEdit {
    var renaming: Project? {
        if case .renaming(let project) = self {
            return project
        }
        return nil
    }

    var deleting: Project? {
        if case .deleting(let project) = self {
            return project
        }
        return nil
    }
}

extension View {
    func projectEditing(_ edit: Binding<ProjectEdit?>, store: TaskStore, selection: Binding<TaskList>) -> some View {
        modifier(ProjectEditing(edit: edit, store: store, selection: selection))
    }
}
