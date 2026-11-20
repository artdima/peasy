import SwiftUI
import UIKit

struct ListPills: View {
    let projects: [Project]
    let tasks: [TaskItem]
    let store: TaskStore
    @Binding var selection: TaskList

    @State private var isNaming = false
    @State private var renaming: Project?
    @State private var pendingDeletion: Project?
    @State private var name = ""

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
                            projectMenu(project)
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
        .alert("New project", isPresented: $isNaming) {
            TextField("Project name", text: $name)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                if let project = store.createProject(named: name) {
                    selection = .project(project.id)
                }
            }
        }
        .alert("Rename", isPresented: isRenaming, presenting: renaming) { project in
            TextField("Project name", text: $name)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                store.rename(project, to: name)
            }
        }
        .confirmationDialog(
            Text("Delete “\(pendingDeletion?.name ?? "")” and all its tasks?"),
            isPresented: isConfirmingDeletion,
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { project in
            Button("Delete", role: .destructive) {
                delete(project)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var newProjectButton: some View {
        Button {
            name = ""
            isNaming = true
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

    @ViewBuilder
    private func projectMenu(_ project: Project) -> some View {
        Button("Rename") {
            name = project.name
            renaming = project
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
                Button("Move Left") {
                    moveProject(from: index, to: index - 1)
                }
            }
            if index < projects.count - 1 {
                Button("Move Right") {
                    moveProject(from: index, to: index + 2)
                }
            }
        }
        Button("Delete…", role: .destructive) {
            if (project.tasks ?? []).isEmpty {
                delete(project)
            } else {
                pendingDeletion = project
            }
        }
    }

    private var isRenaming: Binding<Bool> {
        Binding {
            renaming != nil
        } set: { isOn in
            if !isOn {
                renaming = nil
            }
        }
    }

    private var isConfirmingDeletion: Binding<Bool> {
        Binding {
            pendingDeletion != nil
        } set: { isOn in
            if !isOn {
                pendingDeletion = nil
            }
        }
    }

    private func count(in list: TaskList) -> Int {
        TaskQueries.ownOpenTasks(in: list, from: tasks, now: DayClock.shared.today).count
    }

    private func moveProject(from index: Int, to destination: Int) {
        withAnimation(.snappy) {
            store.moveProjects(from: IndexSet(integer: index), to: destination)
        }
    }

    private func delete(_ project: Project) {
        if selection == .project(project.id) {
            selection = .today
        }
        withAnimation(.snappy) {
            store.delete(project)
        }
    }

    private static func swatch(hex: String, isOn: Bool) -> UIImage {
        let symbol = UIImage(systemName: isOn ? "checkmark.circle.fill" : "circle.fill") ?? UIImage()
        return symbol.withTintColor(PlatformColor(hex: hex), renderingMode: .alwaysOriginal)
    }
}
