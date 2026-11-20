import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Project.order), SortDescriptor(\Project.createdAt)])
    private var projects: [Project]
    @Query private var tasks: [TaskItem]
    @AppStorage(TaskList.storageKey) private var selectedListValue = TaskList.today.storageValue
    @State private var draft = ""
    @FocusState private var isDraftFocused: Bool

    var body: some View {
        let store = TaskStore(context: modelContext)
        let list = selectedList
        let now = DayClock.shared.today
        let openTasks = TaskQueries.openTasks(in: list, from: tasks, now: now)
        let placeholder: LocalizedStringKey = list == .today ? "New task for today" : "New task"
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
                store: store
            )
            .padding(.top, 14)
        }
        .foregroundStyle(PanelStyle.primary)
        .background(PhoneStyle.background)
        .safeAreaInset(edge: .bottom) {
            TextField(placeholder, text: $draft)
                .focused($isDraftFocused)
                .onSubmit {
                    store.addTypedTask(draft, to: list)
                    draft = ""
                    isDraftFocused = true
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(PhoneStyle.pill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(PhoneStyle.background)
        }
    }

    private func header(now: Date) -> some View {
        HStack(spacing: 0) {
            Text(verbatim: ScheduleFormat.capitalized(now.formatted(.dateTime.weekday(.wide).day().month(.wide))))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PanelStyle.heading)
            Spacer(minLength: 8)
            Button {
                isDraftFocused = true
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
