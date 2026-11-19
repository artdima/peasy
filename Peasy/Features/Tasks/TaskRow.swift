import AppKit
import SwiftUI

struct TaskRow: View {
    let task: TaskItem
    let list: TaskList
    let store: TaskStore
    @Bindable var model: PanelViewModel

    @AppStorage(PanelSettings.multilineTasksKey) private var isMultiline = false
    @State private var isHovered = false
    @State private var isChecking = false
    @State private var dateButtonFrame: CGRect = .zero
    @FocusState private var isEditorFocused: Bool

    private var isEditing: Bool { model.editingTaskID == task.id }
    private var isEditingTitle: Bool { isEditing && model.editingField == .title }
    private var isEditingNote: Bool { isEditing && model.editingField == .note }
    private var isSelected: Bool { model.selectedTaskID == task.id }
    private var isScheduling: Bool { model.schedulingTaskID == task.id }
    private var showsDateButton: Bool { isHovered || isScheduling }
    private var showsLinkButton: Bool { isHovered && !isEditing && !task.link.isEmpty }

    var body: some View {
        let wraps = isMultiline && !isEditing
        let showsNote = !isEditingTitle && (isEditingNote || task.noteLabel != nil)
        let topAligned = wraps || showsNote
        HStack(alignment: topAligned ? .top : .center, spacing: 14) {
            CheckRing(color: accent, isOn: task.isDone || isChecking, mark: task.ringMark, action: toggle)
                .accessibilityLabel(task.isDone ? LocalizedStringKey("Mark as not done") : "Mark as done")
                .padding(.top, topAligned ? 7 : 0)

            if isEditingTitle {
                TextField("Task", text: $model.editingDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
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
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.system(size: 15))
                        .foregroundStyle(task.isDone ? PanelStyle.tertiary : PanelStyle.primary)
                        .lineLimit(wraps ? nil : 1)
                        .lineSpacing(wraps ? 3 : 0)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: wraps)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture(count: 2, perform: startEditing)

                    if isEditingNote {
                        noteEditor
                    } else if let noteText = task.noteLabel {
                        noteLine(noteText)
                            .onTapGesture(count: 2, perform: startEditingNote)
                    }
                }
                .padding(.vertical, topAligned ? 10 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !task.isDone {
                HStack(spacing: 6) {
                    if task.isForClaude || meta != nil {
                        TimelineView(.everyMinute) { context in
                            if let meta = metaText(now: context.date) {
                                meta
                                    .font(.system(size: 14))
                                    .foregroundStyle(PanelStyle.tertiary)
                                    .lineLimit(1)
                                    .padding(.trailing, showsDateButton ? 0 : 2)
                            }
                        }
                    }
                    if showsLinkButton {
                        linkButton
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
                .padding(.top, topAligned ? 8 : 0)
            } else if showsLinkButton {
                linkButton
                    .padding(.top, topAligned ? 8 : 0)
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 8)
        .frame(minHeight: 42)
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
            Button("Note…", action: startEditingNote)
            Divider()
            if !task.isDone {
                if task.isForClaude {
                    Button("Take Back from Claude") {
                        withAnimation(.snappy) {
                            store.takeBack(task)
                        }
                    }
                } else {
                    Button("Hand to Claude") {
                        withAnimation(.snappy) {
                            store.assignToClaude(task)
                        }
                    }
                }
            }
            if !task.link.isEmpty {
                Button("Open Link", action: openLink)
            }
            Button("Copy Text", action: copyTitle)
            Divider()
            Button("Delete", role: .destructive, action: delete)
        }
    }

    private var accent: Color {
        Color(hex: task.project?.colorHex ?? ProjectPalette.noProject)
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
                return task.isOverdue(now: now) ? label.foregroundStyle(PanelStyle.overdue) : label
            }
        switch list {
        case .today, .all:
            guard let place = task.project.map({ Text(verbatim: $0.name) }) else { return when }
            return when.map { place + Text(verbatim: " · ") + $0 } ?? place
        case .project:
            return when
        }
    }

    private func metaText(now: Date) -> Text? {
        let parts = [meta, task.agentLabel(now: now)].compactMap { $0 }
        guard let first = parts.first else { return nil }
        return parts.dropFirst().reduce(first) { $0 + Text(verbatim: " · ") + $1 }
    }

    private func noteLine(_ text: Text) -> some View {
        HStack(spacing: 5) {
            if task.showsNoteMark {
                Glyph(kind: .sparkle, size: 9, filled: true)
                    .foregroundStyle(task.isDone ? PanelStyle.tertiary : PanelStyle.claude)
            }
            text
                .font(.system(size: 12.5))
                .foregroundStyle(PanelStyle.tertiary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .help(task.note)
    }

    private var noteEditor: some View {
        TextField("Note", text: $model.editingDraft, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: 12.5))
            .lineLimit(1...4)
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
    }

    private var linkButton: some View {
        RowActionButton(glyph: .link, label: "Open Link", help: task.link, action: openLink)
    }

    private func openLink() {
        guard let url = URL(string: task.link),
              let scheme = url.scheme?.lowercased(),
              PeasyTools.linkSchemes.contains(scheme)
        else { return }
        if !NSWorkspace.shared.open(url), url.isFileURL {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private func copyTitle() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(task.title, forType: .string)
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

    private func startEditingNote() {
        model.startEditingNote(task)
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

struct RowActionButton: View {
    let glyph: Glyph.Kind
    let label: LocalizedStringKey
    var isActive = false
    var help: String?
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
        .help(help.map { Text(verbatim: $0) } ?? Text(label))
        .accessibilityLabel(label)
    }
}
