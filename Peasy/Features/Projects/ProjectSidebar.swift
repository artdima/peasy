import SwiftUI

struct ProjectSidebar: View {
    let projects: [Project]
    let tasks: [TaskItem]
    let selection: TaskList
    let store: TaskStore
    @Bindable var model: NotchViewModel
    let onSelect: (TaskList) -> Void
    let onDelete: (Project) -> Void

    @State private var dropTargetID: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                SidebarRow(title: Text("Today"), count: count(in: .today), isSelected: selection == .today) {
                    SproutIcon()
                        .frame(width: 16, height: 16)
                } action: {
                    onSelect(.today)
                }

                Rectangle()
                    .fill(PanelStyle.separator)
                    .frame(height: 1)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 8)

                SidebarRow(title: Text("All"), count: count(in: .all), isSelected: selection == .all) {
                    ColorDot(hex: ProjectPalette.noProject)
                } action: {
                    onSelect(.all)
                }

                ForEach(projects) { project in
                    projectRow(project)
                }

                if model.projectEditor == .adding {
                    ProjectNameField(
                        colorHex: ProjectPalette.nextColor(excluding: projects.map(\.colorHex)),
                        initialName: ""
                    ) { name in
                        if let project = store.createProject(named: name) {
                            onSelect(.project(project.id))
                        }
                        model.projectEditor = nil
                    } onCancel: {
                        model.projectEditor = nil
                    }
                } else {
                    NewProjectRow {
                        model.projectEditor = .adding
                    }
                    .dropDestination(for: String.self) { items, _ in
                        moveProject(withID: items.first, before: nil)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func projectRow(_ project: Project) -> some View {
        if model.projectEditor == .renaming(project.id) {
            ProjectNameField(colorHex: project.colorHex, initialName: project.name) { name in
                store.rename(project, to: name)
                model.projectEditor = nil
            } onCancel: {
                model.projectEditor = nil
            }
        } else {
            SidebarRow(
                title: Text(verbatim: project.name),
                count: count(in: .project(project.id)),
                isSelected: selection == .project(project.id)
            ) {
                ColorDot(hex: project.colorHex)
            } action: {
                onSelect(.project(project.id))
            }
            .draggable(project.id.uuidString)
            .dropDestination(for: String.self) { items, _ in
                moveProject(withID: items.first, before: project)
            } isTargeted: { targeted in
                if targeted {
                    dropTargetID = project.id
                } else if dropTargetID == project.id {
                    dropTargetID = nil
                }
            }
            .overlay(alignment: .top) {
                if dropTargetID == project.id {
                    DropIndicator(axis: .horizontal)
                }
            }
            .contextMenu {
                Button("Rename") {
                    model.projectEditor = .renaming(project.id)
                }
                ProjectColorMenu(project: project, store: store)
                Button("Delete…", role: .destructive) {
                    requestDeletion(of: project)
                }
            }
        }
    }

    private func count(in list: TaskList) -> Int {
        TaskQueries.openTasks(in: list, from: tasks, now: DayClock.shared.today).count
    }

    private func moveProject(withID id: String?, before target: Project?) -> Bool {
        guard let id, let source = projects.firstIndex(where: { $0.id.uuidString == id }) else { return false }
        let destination = target.flatMap { target in projects.firstIndex { $0.id == target.id } } ?? projects.count
        guard destination != source, destination != source + 1 else { return true }
        withAnimation(.snappy) {
            store.moveProjects(from: IndexSet(integer: source), to: destination)
        }
        return true
    }

    private func requestDeletion(of project: Project) {
        if (project.tasks ?? []).isEmpty {
            onDelete(project)
        } else {
            model.projectPendingDeletion = project.id
        }
    }
}

struct SidebarRow<Icon: View>: View {
    let title: Text
    let count: Int
    let isSelected: Bool
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon()
                    .frame(width: 16, height: 16)
                title
                    .font(.system(size: 15))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if count > 0 {
                    Text(count, format: .number)
                        .font(.system(size: 14))
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? PanelStyle.selectedTertiary : PanelStyle.tertiary)
                }
            }
            .foregroundStyle(isSelected ? PanelStyle.selectedPrimary : PanelStyle.primary)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                isSelected ? PanelStyle.selection : isHovered ? PanelStyle.hover : .clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct NewProjectRow: View {
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Glyph(kind: .plus, size: 11)
                    .frame(width: 16, height: 16)
                Text("New project")
                    .font(.system(size: 15))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isHovered ? PanelStyle.primary : PanelStyle.tertiary)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(isHovered ? PanelStyle.hover : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct ProjectNameField: View {
    let colorHex: String
    let initialName: String
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var isFinished = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            ColorDot(hex: colorHex)
                .frame(width: 16, height: 16)
            TextField("Project name", text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($isFocused)
                .onSubmit(finish)
                .onExitCommand {
                    guard !isFinished else { return }
                    isFinished = true
                    onCancel()
                }
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(PanelStyle.nameField, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear {
            name = initialName
            isFocused = true
        }
        .onChange(of: isFocused) { _, focused in
            if !focused {
                finish()
            }
        }
    }

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            onCancel()
        } else {
            onCommit(name)
        }
    }
}

struct DeleteProjectConfirmation: View {
    let project: Project
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("Delete “\(project.name)” and all its tasks?")
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Cancel", action: onCancel)
                .buttonStyle(.borderless)
            Button("Delete", role: .destructive, action: onConfirm)
                .buttonStyle(.borderedProminent)
                .tint(.red)
        }
        .font(.system(size: 12))
        .controlSize(.small)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.red.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
