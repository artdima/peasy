import Observation
import SwiftUI

/// The rows carry out the requests, so a key animates the same as a tap.
@Observable
final class TaskKeyboard {
    var selectedID: UUID?
    var editingID: UUID?
    var editRequest: UUID?
    var toggleRequest: UUID?
}

struct PhoneTaskList: View {
    let list: TaskList
    let openTasks: [TaskItem]
    let completedTasks: [TaskItem]
    let projects: [Project]
    let store: TaskStore

    @State private var showsCompleted = false
    @State private var schedulingTask: TaskItem?
    @State private var scheduledTask: TaskItem?
    @State private var scheduleDraft = ScheduleDraft()
    @State private var keyboard = TaskKeyboard()
    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            rows
                .environment(keyboard)
                .focusable(keyboard.editingID == nil)
                .focused($isFocused)
                .focusEffectDisabled()
                .onKeyPress(keys: [.upArrow, .downArrow, .space, .return, .escape]) { press in
                    handle(press.key, proxy: proxy)
                }
                .onChange(of: keyboard.editingID) { _, id in
                    if id == nil {
                        isFocused = true
                    }
                }
                .onAppear {
                    isFocused = true
                }
        }
    }

    private var rows: some View {
        List {
            ForEach(openTasks) { task in
                PhoneTaskRow(task: task, list: list, projects: projects, store: store) {
                    schedule(task)
                }
                .taskRow(isSelected: keyboard.selectedID == task.id)
                .id(task.id)
            }
            .onMove { source, destination in
                withAnimation(.snappy) {
                    store.moveOpenTasks(in: list, from: source, to: destination)
                }
            }

            if openTasks.isEmpty {
                Text("All done")
                    .font(.body)
                    .foregroundStyle(PanelStyle.tertiary)
                    .padding(.vertical, 11)
                    .taskRow()
                    .listRowSeparator(.hidden)
            }

            if !completedTasks.isEmpty {
                Button {
                    withAnimation(.snappy) {
                        showsCompleted.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Glyph(kind: .chevron, size: 11)
                            .rotationEffect(.degrees(showsCompleted ? 90 : 0))
                        Text("Completed · \(completedTasks.count)")
                    }
                    .font(.subheadline)
                    .foregroundStyle(PanelStyle.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(showsCompleted ? .isSelected : [])
                .taskRow()
                .listRowSeparator(.hidden)

                if showsCompleted {
                    ForEach(completedTasks) { task in
                        PhoneTaskRow(task: task, list: list, projects: projects, store: store) {
                            schedule(task)
                        }
                        .taskRow(isSelected: keyboard.selectedID == task.id)
                        .id(task.id)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: list) {
            showsCompleted = false
            keyboard.selectedID = nil
        }
        .sheet(item: $schedulingTask, onDismiss: commitSchedule) { task in
            ScheduleSheet(title: task.title, draft: $scheduleDraft)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
                .presentationBackground(PhoneStyle.sheet)
        }
    }

    private func handle(_ key: KeyEquivalent, proxy: ScrollViewProxy) -> KeyPress.Result {
        let ids = (openTasks + (showsCompleted ? completedTasks : [])).map(\.id)
        let selected = keyboard.selectedID.flatMap { ids.contains($0) ? $0 : nil }
        switch key {
        case .upArrow, .downArrow:
            guard !ids.isEmpty else { return .ignored }
            let step = key == .upArrow ? -1 : 1
            let index = selected.flatMap { ids.firstIndex(of: $0) }.map { min(max($0 + step, 0), ids.count - 1) }
                ?? (step > 0 ? 0 : ids.count - 1)
            keyboard.selectedID = ids[index]
            withAnimation(.snappy) {
                proxy.scrollTo(ids[index])
            }
        case .space:
            guard let selected else { return .ignored }
            keyboard.toggleRequest = selected
        case .return:
            guard let selected else { return .ignored }
            keyboard.editRequest = selected
        case .escape:
            guard keyboard.selectedID != nil else { return .ignored }
            keyboard.selectedID = nil
        default:
            return .ignored
        }
        return .handled
    }

    private func schedule(_ task: TaskItem) {
        scheduleDraft = ScheduleDraft(date: task.date, hasTime: task.hasTime)
        scheduledTask = task
        schedulingTask = task
    }

    private func commitSchedule() {
        guard let task = scheduledTask else { return }
        scheduledTask = nil
        withAnimation(.snappy) {
            store.schedule(task, on: scheduleDraft.date, hasTime: scheduleDraft.hasTime)
        }
    }
}

private extension View {
    func taskRow(isSelected: Bool = false) -> some View {
        listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 16))
            .listRowBackground(isSelected ? PanelStyle.strongHover : Color.clear)
            .listRowSeparatorTint(PanelStyle.separator)
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
    }
}
