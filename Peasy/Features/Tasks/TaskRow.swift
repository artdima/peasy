import SwiftUI

struct TaskRow: View {
    let task: TaskItem
    let list: TaskList
    let store: TaskStore
    @Bindable var model: NotchViewModel

    @AppStorage(PanelSettings.multilineTasksKey) private var isMultiline = false
    @State private var isHovered = false
    @State private var isChecking = false
    @State private var dateButtonFrame: CGRect = .zero
    @FocusState private var isEditorFocused: Bool

    private var isEditing: Bool { model.editingTaskID == task.id }
    private var isSelected: Bool { model.selectedTaskID == task.id }
    private var isScheduling: Bool { model.schedulingTaskID == task.id }
    private var showsDateButton: Bool { isHovered || isScheduling }

    var body: some View {
        let wraps = isMultiline && !isEditing
        HStack(alignment: wraps ? .top : .center, spacing: 8) {
            CheckRing(color: accent, isOn: task.isDone || isChecking, action: toggle)
                .accessibilityLabel(task.isDone ? LocalizedStringKey("Mark as not done") : "Mark as done")
                .padding(.top, wraps ? 4 : 0)

            if isEditing {
                TextField("Task", text: $model.editingDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($isEditorFocused)
                    .onSubmit(model.commitEditing)
                    .onExitCommand(perform: model.cancelEditing)
                    .onAppear {
                        isEditorFocused = true
                    }
                    .onChange(of: isEditorFocused) { _, focused in
                        if !focused, isEditing {
                            model.commitEditing()
                        }
                    }
            } else {
                Text(task.title)
                    .font(.system(size: 14))
                    .foregroundStyle(task.isDone ? PanelStyle.tertiary : PanelStyle.primary)
                    .lineLimit(wraps ? nil : 1)
                    .lineSpacing(wraps ? 3 : 0)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: wraps)
                    .padding(.vertical, wraps ? 10.5 : 0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture(count: 2, perform: startEditing)
            }

            if !task.isDone {
                HStack(spacing: 6) {
                    if let meta {
                        meta
                            .font(.system(size: 12))
                            .foregroundStyle(PanelStyle.tertiary)
                            .lineLimit(1)
                            .padding(.trailing, showsDateButton ? 0 : 2)
                    }
                    if showsDateButton {
                        RowActionButton(glyph: .calendar, label: "Date and Time", isActive: isScheduling, action: openSchedule)
                    }
                }
                .background(alignment: .trailing) {
                    Color.clear
                        .frame(width: 24, height: 24)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                            dateButtonFrame = frame
                        }
                }
                .frame(minWidth: 24, minHeight: 24, alignment: .trailing)
                .padding(.top, wraps ? 7 : 0)
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 8)
        .frame(minHeight: 38)
        .background(
            isSelected || isScheduling ? PanelStyle.strongHover : isHovered ? PanelStyle.hover : .clear,
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { model.selectedTaskID = task.id })
        .onHover { isHovered = $0 }
        .onDisappear {
            if isScheduling {
                model.schedulingTaskID = nil
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .contextMenu {
            Button(task.isDone ? LocalizedStringKey("Mark as Not Done") : "Mark as Done", action: toggle)
            Button(task.isDue(on: .now) ? LocalizedStringKey("Remove from Today") : "Add to Today") {
                withAnimation(.snappy) {
                    store.setToday(task, !task.isDue(on: .now))
                }
            }
            if !task.isDone {
                Button("Date and Time…", action: openSchedule)
            }
            Button("Edit", action: startEditing)
            Divider()
            Button("Delete", role: .destructive, action: delete)
        }
    }

    private var accent: Color {
        Color(hex: task.project?.colorHex ?? ProjectPalette.inbox)
    }

    private var meta: Text? {
        let now = DayClock.shared.today
        let date = isScheduling ? model.scheduleDraft.date : task.date
        let hasTime = isScheduling ? model.scheduleDraft.hasTime : task.hasTime
        let when = TaskScheduleLabel.text(date: date, hasTime: hasTime, isDone: task.isDone, inToday: list == .today, now: now)
            .map { label in
                if isScheduling {
                    return label.foregroundStyle(PanelStyle.green)
                }
                return task.isOverdue(now: now) ? label.foregroundStyle(Color(nsColor: .systemRed)) : label
            }
        switch list {
        case .today:
            let place = task.project.map { Text(verbatim: $0.name) } ?? Text("Inbox")
            return when.map { place + Text(verbatim: " · ") + $0 } ?? place
        case .inbox, .project:
            return when
        }
    }

    private func openSchedule() {
        model.openSchedule(for: task, anchor: dateButtonFrame)
    }

    private func toggle() {
        if task.isDone {
            withAnimation(.snappy) {
                store.toggle(task)
            }
            return
        }
        guard !isChecking else { return }
        isChecking = true
        Task {
            try? await Task.sleep(for: .milliseconds(520))
            withAnimation(.snappy) {
                store.toggle(task)
            }
            isChecking = false
        }
    }

    private func startEditing() {
        model.startEditing(task)
    }

    private func delete() {
        if isSelected {
            model.selectedTaskID = nil
        }
        withAnimation(.snappy) {
            store.delete(task)
        }
    }
}

struct CheckRing: View {
    let color: Color
    let isOn: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color.opacity(isOn ? 1 : isHovered ? 0.24 : 0))
                Circle()
                    .strokeBorder(color, lineWidth: 1.5)
                Glyph(kind: .check, size: 10)
                    .foregroundStyle(.black)
                    .opacity(isOn ? 1 : 0)
                    .scaleEffect(isOn ? 1 : 0.6)
            }
            .frame(width: 18, height: 18)
            .frame(width: 30, height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.18), value: isOn)
    }
}

struct RowActionButton: View {
    let glyph: Glyph.Kind
    let label: LocalizedStringKey
    var isActive = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Glyph(kind: glyph, size: 12)
                .foregroundStyle(isHovered || isActive ? PanelStyle.primary : PanelStyle.secondary)
                .frame(width: 24, height: 24)
                .background(isActive ? PanelStyle.pressed : isHovered ? PanelStyle.strongHover : .clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}
