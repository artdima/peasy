import SwiftUI

struct PhoneTaskRow: View {
    let task: TaskItem
    let list: TaskList
    let store: TaskStore

    @Environment(\.openURL) private var openURL
    @State private var isChecking = false

    var body: some View {
        let place = task.isDone ? nil : placeAndDate()
        HStack(alignment: .top, spacing: 12) {
            CheckRing(color: accent, isOn: task.isDone || isChecking, mark: task.ringMark, size: 24, hitSize: 44, action: toggle)
                .padding(.vertical, -10)
                .padding(.leading, -10)
                .padding(.trailing, -6)
                .accessibilityLabel(task.isDone ? LocalizedStringKey("Mark as not done") : "Mark as done")
                .sensoryFeedback(.impact(weight: .light), trigger: isChecking) { _, checking in checking }

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.body)
                    .foregroundStyle(task.isDone ? PanelStyle.tertiary : PanelStyle.primary)

                if let note = task.noteLabel {
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

            if let url = webLink {
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
