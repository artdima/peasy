import SwiftUI

struct ProjectSwitcher: View {
    let projects: [Project]
    let selectedID: UUID?
    let store: TaskStore
    @Bindable var model: NotchViewModel
    let onSelect: (Project) -> Void
    let onDelete: (Project) -> Void

    @State private var dropTargetID: UUID?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(projects) { project in
                    if model.projectEditor == .renaming(project.id) {
                        ProjectNameField(initialName: project.name) { name in
                            store.rename(project, to: name)
                            model.projectEditor = nil
                        } onCancel: {
                            model.projectEditor = nil
                        }
                    } else {
                        ProjectChip(name: project.name, isSelected: project.id == selectedID) {
                            onSelect(project)
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
                            Button("Delete…", role: .destructive) {
                                requestDeletion(of: project)
                            }
                        }
                    }
                }
                if model.projectEditor == .adding {
                    ProjectNameField(initialName: "") { name in
                        if let project = store.createProject(named: name) {
                            onSelect(project)
                        }
                        model.projectEditor = nil
                    } onCancel: {
                        model.projectEditor = nil
                    }
                } else {
                    Button {
                        model.projectEditor = .adding
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .dropDestination(for: String.self) { items, _ in
                        moveProject(withID: items.first, before: nil)
                    }
                    .help("New project")
                    .accessibilityLabel("New project")
                }
            }
        }
        .scrollIndicators(.hidden)
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

struct ProjectChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.white.opacity(isSelected ? 0.16 : 0), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct ProjectNameField: View {
    let initialName: String
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var isFinished = false
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Project", text: $name)
            .textFieldStyle(.plain)
            .font(.subheadline.weight(.medium))
            .frame(width: 110)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.white.opacity(0.12), in: Capsule())
            .focused($isFocused)
            .onAppear {
                name = initialName
                isFocused = true
            }
            .onSubmit(finish)
            .onExitCommand {
                guard !isFinished else { return }
                isFinished = true
                onCancel()
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
        .font(.subheadline)
        .controlSize(.small)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.red.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
