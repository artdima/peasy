import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: [SortDescriptor(\Project.order), SortDescriptor(\Project.createdAt)])
    private var projects: [Project]
    @Query private var tasks: [TaskItem]
    @AppStorage(TaskList.storageKey) private var selectedListValue = TaskList.today.storageValue
    @Bindable private var newTask = NewTaskPrompt.shared
    @State private var showsSettings = false

    var body: some View {
        let store = TaskStore(context: modelContext)
        let list = selectedList
        Group {
            if sizeClass == .regular {
                NavigationSplitView {
                    PadSidebar(projects: projects, tasks: tasks, store: store, selection: selection)
                        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
                } detail: {
                    content(list: list, store: store, isSplit: true)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItemGroup(placement: .primaryAction) {
                                newTaskButton
                                settingsButton
                            }
                        }
                }
            } else {
                content(list: list, store: store, isSplit: false)
            }
        }
        .sheet(isPresented: $newTask.isPresented) {
            NewTaskSheet(projectID: projectID(of: list))
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
                .presentationBackground(PhoneStyle.sheet)
        }
        .sheet(isPresented: $showsSettings) {
            SettingsSheet()
        }
    }

    private func content(list: TaskList, store: TaskStore, isSplit: Bool) -> some View {
        let now = DayClock.shared.today
        let openTasks = TaskQueries.openTasks(in: list, from: tasks, now: now)
        return VStack(alignment: .leading, spacing: 0) {
            header(now: now, showsButtons: !isSplit)

            VStack(alignment: .leading, spacing: 2) {
                title(for: list)
                    .font(.largeTitle.bold())
                    .foregroundStyle(PanelStyle.title)
                    .lineLimit(1)
                if !openTasks.isEmpty {
                    TaskCount.label(for: openTasks)
                        .font(.subheadline)
                        .foregroundStyle(PanelStyle.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 2)

            if !isSplit {
                ListPills(projects: projects, tasks: tasks, store: store, selection: selection)
                    .padding(.top, 14)
            }

            PhoneTaskList(
                list: list,
                openTasks: openTasks,
                completedTasks: TaskQueries.completedTasks(in: list, from: tasks, now: now),
                projects: projects,
                store: store
            )
            .padding(.top, 14)
        }
        .foregroundStyle(PanelStyle.primary)
        .background(PhoneStyle.background)
        .safeAreaInset(edge: .bottom) {
            Button {
                newTask.isPresented = true
            } label: {
                HStack(spacing: 10) {
                    Glyph(kind: .plus, size: 18)
                    Text("New task")
                        .font(.body)
                    Spacer(minLength: 8)
                    Text("@claude — hand to Claude")
                        .font(.footnote)
                        .lineLimit(1)
                }
                .foregroundStyle(PanelStyle.secondary)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(PhoneStyle.pill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .background(PhoneStyle.background)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(PanelStyle.separator)
                    .frame(height: 1)
            }
        }
    }

    private func header(now: Date, showsButtons: Bool) -> some View {
        HStack(spacing: 0) {
            Text(verbatim: ScheduleFormat.capitalized(now.formatted(.dateTime.weekday(.wide).day().month(.wide))))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PanelStyle.heading)
            Spacer(minLength: 8)
            if showsButtons {
                newTaskButton
                settingsButton
            }
        }
        .frame(height: 44)
        .padding(.leading, 20)
        .padding(.trailing, 6)
    }

    private var newTaskButton: some View {
        Button {
            newTask.isPresented = true
        } label: {
            Glyph(kind: .newTask, size: 20)
                .foregroundStyle(PanelStyle.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("New task"))
    }

    private var settingsButton: some View {
        Button {
            showsSettings = true
        } label: {
            Glyph(kind: .gear, size: 21)
                .foregroundStyle(PanelStyle.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Settings"))
    }

    private func title(for list: TaskList) -> Text {
        switch list {
        case .today: Text("Today")
        case .all: Text("All")
        case .project(let id): Text(projects.first { $0.id == id }?.name ?? "")
        }
    }

    private func projectID(of list: TaskList) -> UUID? {
        if case .project(let id) = list {
            return id
        }
        return nil
    }

    private var selectedList: TaskList {
        let list = TaskList(storageValue: selectedListValue)
        if case .project(let id) = list, !projects.contains(where: { $0.id == id }) {
            return .today
        }
        return list
    }

    private var selection: Binding<TaskList> {
        Binding {
            selectedList
        } set: {
            selectedListValue = $0.storageValue
        }
    }
}
