import SwiftUI

struct ProjectTabs: View {
    let projects: [Project]
    let tasks: [TaskItem]
    let selection: TaskList
    let store: TaskStore
    @Bindable var model: NotchViewModel
    let onSelect: (TaskList) -> Void
    let onDelete: (Project) -> Void

    @State private var dropTargetID: UUID?

    var body: some View {
        FlowLayout(spacing: 4, rowSpacing: 4) {
            TabPill(title: String(localized: "Today"), count: count(in: .today), isSelected: selection == .today) {
                SproutIcon()
                    .frame(width: 12, height: 12)
            } action: {
                onSelect(.today)
            }

            TabPill(title: String(localized: "Inbox"), count: count(in: .inbox), isSelected: selection == .inbox) {
                ColorDot(hex: ProjectPalette.inbox, size: 6)
            } action: {
                onSelect(.inbox)
            }

            ForEach(projects) { project in
                projectTab(project)
            }

            if model.projectEditor == .adding {
                TabNameField(
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
                AddTabButton {
                    model.projectEditor = .adding
                }
                .overflowAllowance(8)
                .dropDestination(for: String.self) { items, _ in
                    moveProject(withID: items.first, before: nil)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func projectTab(_ project: Project) -> some View {
        if model.projectEditor == .renaming(project.id) {
            TabNameField(colorHex: project.colorHex, initialName: project.name) { name in
                store.rename(project, to: name)
                model.projectEditor = nil
            } onCancel: {
                model.projectEditor = nil
            }
        } else {
            TabPill(
                title: project.name,
                count: count(in: .project(project.id)),
                isSelected: selection == .project(project.id)
            ) {
                ColorDot(hex: project.colorHex, size: 6)
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
            .overlay(alignment: .leading) {
                if dropTargetID == project.id {
                    DropIndicator(axis: .vertical)
                }
            }
            .contextMenu {
                Button("Rename") {
                    model.projectEditor = .renaming(project.id)
                }
                ProjectColorMenu(project: project, store: store)
                Button("Delete…", role: .destructive) {
                    if (project.tasks ?? []).isEmpty {
                        onDelete(project)
                    } else {
                        model.projectPendingDeletion = project.id
                    }
                }
            }
        }
    }

    private func count(in list: TaskList) -> Int {
        TaskQueries.openTasks(in: list, from: tasks).count
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
}

struct TabPill<Icon: View>: View {
    let title: String
    let count: Int
    let isSelected: Bool
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                icon()
                FittedText(string: title)
                if count > 0 {
                    FittedText(string: count.formatted(), size: 12, tabular: true)
                        .foregroundStyle(PanelStyle.tertiary)
                }
            }
            .foregroundStyle(isSelected || isHovered ? PanelStyle.primary : PanelStyle.secondary)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(isSelected ? PanelStyle.pillSelection : .clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct AddTabButton: View {
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Glyph(kind: .plus, size: 12)
                .foregroundStyle(isHovered ? PanelStyle.primary : PanelStyle.tertiary)
                .frame(width: 30, height: 30)
                .background(isHovered ? PanelStyle.strongHover : .clear, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("New project")
        .accessibilityLabel("New project")
    }
}

struct TabNameField: View {
    let colorHex: String
    let initialName: String
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var isFinished = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 7) {
            ColorDot(hex: colorHex, size: 6)
            TextField("Project name", text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .frame(width: 120)
                .focused($isFocused)
                .onSubmit(finish)
                .onExitCommand {
                    guard !isFinished else { return }
                    isFinished = true
                    onCancel()
                }
        }
        .padding(.horizontal, 11)
        .frame(height: 30)
        .background(PanelStyle.pillSelection, in: Capsule())
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
