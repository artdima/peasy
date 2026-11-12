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
    @State private var isCopied = false
    @State private var dateButtonFrame: CGRect = .zero
    @FocusState private var isEditorFocused: Bool

    private var isEditing: Bool { model.editingTaskID == task.id }
    private var isEditingTitle: Bool { isEditing && model.editingField == .title }
    private var isEditingNote: Bool { isEditing && model.editingField == .note }
    private var isSelected: Bool { model.selectedTaskID == task.id }
    private var isScheduling: Bool { model.schedulingTaskID == task.id }
    private var showsDateButton: Bool { isHovered || isScheduling }
    private var showsCopyButton: Bool { isHovered && !isEditing }
    private var showsLinkButton: Bool { isHovered && !isEditing && !task.link.isEmpty }

    var body: some View {
        let wraps = isMultiline && !isEditing
        let showsNote = !isEditingTitle && (isEditingNote || noteText != nil)
        let topAligned = wraps || showsNote
        HStack(alignment: topAligned ? .top : .center, spacing: 14) {
            CheckRing(color: accent, isOn: task.isDone || isChecking, mark: agentMark, action: toggle)
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
                    } else if let noteText {
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
                    if showsCopyButton {
                        copyButton
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
            } else if showsCopyButton {
                HStack(spacing: 6) {
                    if showsLinkButton {
                        linkButton
                    }
                    copyButton
                }
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

    private var agentMark: CheckRing.Mark {
        guard task.isForClaude, !task.isDone else { return .own }
        return task.isClaimed() ? .working : .waiting
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

    private func agentMeta(now: Date) -> Text? {
        guard task.isForClaude, !task.isDone else { return nil }
        guard task.isClaimed(now: now), let since = task.claimedAt else {
            return Text(verbatim: "Claude")
        }
        let minutes = max(1, Int(now.timeIntervalSince(since) / 60))
        return Text(verbatim: "Claude · ") + Text("working \(minutes) min").foregroundStyle(PanelStyle.claude)
    }

    private func metaText(now: Date) -> Text? {
        let parts = [meta, agentMeta(now: now)].compactMap { $0 }
        guard let first = parts.first else { return nil }
        return parts.dropFirst().reduce(first) { $0 + Text(verbatim: " · ") + $1 }
    }

    private var noteText: Text? {
        guard !task.note.isEmpty else { return nil }
        let note = Text(verbatim: task.note)
        if task.agentStatus == .returned {
            return Text("Claude asks:").foregroundStyle(PanelStyle.claude) + Text(verbatim: " ") + note
        }
        if task.isFromAgent || (task.isForClaude && task.isDone) {
            let prefix = Text(verbatim: "Claude:")
            return (task.isDone ? prefix : prefix.foregroundStyle(PanelStyle.claude)) + Text(verbatim: " ") + note
        }
        return note
    }

    private var showsNoteMark: Bool {
        task.agentStatus == .returned || task.isFromAgent || (task.isForClaude && task.isDone)
    }

    private func noteLine(_ text: Text) -> some View {
        HStack(spacing: 5) {
            if showsNoteMark {
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

    private var copyButton: some View {
        RowActionButton(glyph: isCopied ? .check : .copy, label: isCopied ? LocalizedStringKey("Copied") : "Copy Text", action: copyTitle)
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
        isCopied = true
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            isCopied = false
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

struct CheckRing: View {
    enum Mark {
        case own
        case waiting
        case working
    }

    let color: Color
    let isOn: Bool
    var mark: Mark = .own
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color.opacity(isOn ? 1 : isHovered ? 0.24 : 0))
                switch mark {
                case .own:
                    Circle()
                        .strokeBorder(color, lineWidth: 2)
                case .waiting:
                    Circle()
                        .strokeBorder(color, style: StrokeStyle(lineWidth: 2, dash: [3, 2.4]))
                case .working:
                    Circle()
                        .strokeBorder(color.opacity(0.35), lineWidth: 2)
                    WorkingArc()
                }
                if mark != .own, !isOn {
                    Glyph(kind: .sparkle, size: 9, filled: true)
                        .foregroundStyle(PanelStyle.claude)
                }
                Glyph(kind: .check, size: 12)
                    .foregroundStyle(.black)
                    .opacity(isOn ? 1 : 0)
                    .scaleEffect(isOn ? 1 : 0.6)
            }
            .frame(width: 22, height: 22)
            .frame(width: 30, height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.18), value: isOn)
    }
}

private struct WorkingArc: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSpinning = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.3)
            .stroke(PanelStyle.claude, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .padding(1)
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .animation(reduceMotion ? nil : .linear(duration: 1.6).repeatForever(autoreverses: false), value: isSpinning)
            .onAppear {
                isSpinning = !reduceMotion
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
