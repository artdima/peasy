import SwiftUI
import UIKit

struct PhoneTaskRow: View {
    enum EditingField {
        case title
        case note
    }

    let task: TaskItem
    let list: TaskList
    let projects: [Project]
    let store: TaskStore
    let onSchedule: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var isChecking = false
    @State private var editing: EditingField?
    @State private var draft = ""
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        let place = task.isDone ? nil : placeAndDate()
        HStack(alignment: .top, spacing: 12) {
            CheckRing(color: accent, isOn: task.isDone || isChecking, mark: task.ringMark, size: 24, hitSize: 44, action: toggle)
                .padding(.vertical, -10)
                .padding(.leading, -10)
                .padding(.trailing, -6)
                .accessibilityLabel(task.isDone ? LocalizedStringKey("Mark as not done") : "Mark as done")
                .accessibilityValue(agentState)
                .sensoryFeedback(.impact(weight: .light), trigger: isChecking) { _, checking in checking }

            VStack(alignment: .leading, spacing: 3) {
                if editing == .title {
                    TextField("Task", text: $draft)
                        .font(.body)
                        .foregroundStyle(PanelStyle.primary)
                        .focused($isEditorFocused)
                        .submitLabel(.done)
                        .onSubmit(commit)
                        .onAppear {
                            isEditorFocused = true
                        }
                } else {
                    Text(task.title)
                        .font(.body)
                        .foregroundStyle(task.isDone ? PanelStyle.tertiary : PanelStyle.primary)
                }

                if editing == .note {
                    TextField("Note", text: $draft, axis: .vertical)
                        .font(.subheadline)
                        .foregroundStyle(PanelStyle.primary)
                        .lineLimit(1...6)
                        .focused($isEditorFocused)
                        .onAppear {
                            isEditorFocused = true
                        }
                } else if let note = task.noteLabel {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        if task.showsNoteMark {
                            Glyph(kind: .sparkle, size: 10, filled: true)
                                .foregroundStyle(task.isDone ? PanelStyle.tertiary : PanelStyle.claude)
                        }
                        note
                            .lineLimit(2)
                    }
                    .font(.subheadline)
                    .foregroundStyle(PanelStyle.secondary)
                    .onTapGesture {
                        if editing == nil {
                            startEditing(.note)
                        }
                    }
                }

                if !task.isDone, task.isForClaude || place != nil {
                    TimelineView(.everyMinute) { context in
                        let parts = [place, task.agentLabel(now: context.date)].compactMap { $0 }
                        if let first = parts.first {
                            parts.dropFirst().reduce(first) { $0 + Text(verbatim: " · ") + $1 }
                                .font(.subheadline)
                                .foregroundStyle(PanelStyle.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                if editing == nil {
                    startEditing(.title)
                }
            }

            if let url = webLink, editing == nil {
                Button {
                    openURL(url)
                } label: {
                    Glyph(kind: .link, size: 13)
                        .foregroundStyle(PanelStyle.primary)
                        .frame(width: 32, height: 32)
                        .background(PhoneStyle.control, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, -6)
                .padding(.trailing, -6)
                .accessibilityLabel(Text("Open Link"))
            }
        }
        .padding(.vertical, 11)
        .onChange(of: isEditorFocused) { _, focused in
            if !focused {
                commit()
            }
        }
        .toolbar {
            if editing == .note {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isEditorFocused = false
                    }
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: delete) {
                Label("Delete", systemImage: "trash")
            }
            .tint(Color(hex: "#D70015"))
            if !task.isDone {
                Button(action: toggleClaude) {
                    Label(task.isForClaude ? LocalizedStringKey("Take Back from Claude") : "Hand to Claude", systemImage: "sparkle")
                }
                .tint(Color(hex: "#B44A25"))
                Button(action: onSchedule) {
                    Label("Date", systemImage: "calendar")
                }
                .tint(Color(hex: "#0064D2"))
            }
        }
        .contextMenu {
            Button(task.isDone ? LocalizedStringKey("Mark as Not Done") : "Mark as Done", action: toggle)
            Button(task.isDue(on: .now) ? LocalizedStringKey("Remove from Today") : "Add to Today") {
                withAnimation(.snappy) {
                    store.setToday(task, !task.isDue(on: .now))
                }
            }
            if !task.isDone {
                Button("Date and Time…", action: onSchedule)
            }
            Button("Edit") {
                startEditing(.title)
            }
            Button("Note…") {
                startEditing(.note)
            }
            Divider()
            if !task.isDone {
                Button(task.isForClaude ? LocalizedStringKey("Take Back from Claude") : "Hand to Claude", action: toggleClaude)
            }
            Menu("Move to Project") {
                projectButton(nil, title: Text("No Project"))
                ForEach(projects) { project in
                    projectButton(project, title: Text(project.name))
                }
            }
            if let url = webLink {
                Button("Open Link") {
                    openURL(url)
                }
            }
            Button("Copy Text") {
                UIPasteboard.general.string = task.title
            }
            Divider()
            Button("Delete", role: .destructive, action: delete)
        }
    }

    private var agentState: Text {
        switch task.ringMark {
        case .own: Text(verbatim: "")
        case .waiting: Text("Waiting for Claude")
        case .working: Text("Claude is working")
        }
    }

    private var accent: Color {
        Color(hex: task.project?.colorHex ?? ProjectPalette.noProject)
    }

    private var webLink: URL? {
        guard let url = URL(string: task.link),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http"
        else { return nil }
        return url
    }

    private func projectButton(_ project: Project?, title: Text) -> some View {
        Button {
            withAnimation(.snappy) {
                store.move(task, to: project)
            }
        } label: {
            if task.project?.id == project?.id {
                Label {
                    title
                } icon: {
                    Image(systemName: "checkmark")
                }
            } else {
                title
            }
        }
    }

    private func placeAndDate() -> Text? {
        let now = DayClock.shared.today
        let when = TaskScheduleLabel.text(date: task.date, hasTime: task.hasTime, isDone: task.isDone, inToday: list == .today, now: now)
            .map { task.isOverdue(now: now) ? $0.foregroundStyle(PanelStyle.overdue) : $0 }
        switch list {
        case .today, .all:
            guard let place = task.project.map({ Text(verbatim: $0.name) }) else { return when }
            return when.map { place + Text(verbatim: " · ") + $0 } ?? place
        case .project:
            return when
        }
    }

    private func startEditing(_ field: EditingField) {
        draft = field == .title ? task.title : task.note
        editing = field
    }

    private func commit() {
        guard let field = editing else { return }
        editing = nil
        switch field {
        case .title:
            store.renameTypedTask(task, to: draft)
        case .note:
            store.setNote(draft, for: task)
        }
    }

    private func toggleClaude() {
        withAnimation(.snappy) {
            if task.isForClaude {
                store.takeBack(task)
            } else {
                store.assignToClaude(task)
            }
        }
    }

    private func delete() {
        withAnimation(.snappy) {
            store.delete(task)
        }
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
}
