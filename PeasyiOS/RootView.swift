import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Project.order), SortDescriptor(\Project.createdAt)])
    private var projects: [Project]
    @Query private var tasks: [TaskItem]
    @AppStorage(TaskList.storageKey) private var selectedListValue = TaskList.today.storageValue
    @State private var showsNewTask = false

    var body: some View {
        let store = TaskStore(context: modelContext)
        let list = selectedList
        let now = DayClock.shared.today
        let openTasks = TaskQueries.openTasks(in: list, from: tasks, now: now)
        VStack(alignment: .leading, spacing: 0) {
            header(now: now)

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

            ListPills(projects: projects, tasks: tasks, selection: selection)
                .padding(.top, 14)

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
                showsNewTask = true
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
        .sheet(isPresented: $showsNewTask) {
            NewTaskSheet(projectID: projectID(of: list))
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
                .presentationBackground(PhoneStyle.sheet)
        }
    }

    private func header(now: Date) -> some View {
        HStack(spacing: 0) {
            Text(verbatim: ScheduleFormat.capitalized(now.formatted(.dateTime.weekday(.wide).day().month(.wide))))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PanelStyle.heading)
            Spacer(minLength: 8)
            Button {
                showsNewTask = true
            } label: {
                Glyph(kind: .newTask, size: 20)
                    .foregroundStyle(PanelStyle.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("New task"))
        }
        .frame(height: 44)
        .padding(.leading, 20)
        .padding(.trailing, 6)
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
