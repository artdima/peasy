import AppIntents
import SwiftUI
import WidgetKit

struct TodayListWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayList", provider: TodayProvider()) { entry in
            TodayListView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("Today’s tasks, ticked off right from the Home Screen.")
        .supportedFamilies([.systemMedium])
    }
}

struct TodayProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayProgress", provider: TodayProvider()) { entry in
            TodayProgressView(entry: entry)
        }
        .configurationDisplayName("Progress")
        .description("How much of today is already done.")
        .supportedFamilies([.systemSmall])
    }
}

struct ClaudeQuestionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ClaudeQuestion", provider: TodayProvider()) { entry in
            ClaudeQuestionView(entry: entry)
        }
        .configurationDisplayName("Claude asks")
        .description("What Claude needs from you.")
        .supportedFamilies([.systemSmall])
    }
}

private enum WidgetStyle {
    static let background = Color.themed(dark: "#1C1C1E", light: "#FFFFFF")
    static let track = Color.themed(white: 0.12, black: 0.08)
    static let count = Font.system(size: 40, weight: .bold)
}

private struct TodayListView: View {
    let entry: TodayEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                SproutIcon()
                    .frame(width: 22, height: 22)
                Spacer(minLength: 4)
                Text(entry.openCount, format: .number)
                    .font(WidgetStyle.count)
                    .foregroundStyle(PanelStyle.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("Today")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PanelStyle.green)
            }
            .frame(width: 84, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 0) {
                if entry.rows.isEmpty {
                    Text("All done")
                        .font(.subheadline)
                        .foregroundStyle(PanelStyle.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ForEach(entry.rows) { row in
                        WidgetTaskRow(row: row, now: entry.date)
                    }
                    Spacer(minLength: 0)
                    if entry.openCount > entry.rows.count {
                        Text("\(entry.openCount - entry.rows.count) more")
                            .font(.caption)
                            .foregroundStyle(PanelStyle.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .foregroundStyle(PanelStyle.primary)
        .widgetURL(AppLink.today.url)
        .containerBackground(for: .widget) {
            WidgetStyle.background
        }
    }
}

private struct WidgetTaskRow: View {
    let row: TodayEntry.Row
    let now: Date

    var body: some View {
        HStack(spacing: 0) {
            Button(intent: ToggleTaskIntent(taskID: row.id)) {
                WidgetRing(color: Color(hex: row.colorHex), isForClaude: row.isForClaude, isWorking: row.isWorking)
                    .frame(width: 16, height: 16)
                    .frame(width: 25, height: 36, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Mark as Done"))

            Text(verbatim: row.title)
                .font(.subheadline)
                .lineLimit(1)
            Spacer(minLength: 6)
            meta
        }
        .frame(height: 36)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PanelStyle.separator)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var meta: some View {
        if row.isForClaude {
            Glyph(kind: .sparkle, size: 10, filled: true)
                .foregroundStyle(PanelStyle.claude)
        } else if let label = TaskScheduleLabel.text(date: row.due, hasTime: row.hasTime, isDone: false, inToday: true, now: now) {
            label
                .font(.caption)
                .foregroundStyle(row.isOverdue ? PanelStyle.overdue : PanelStyle.secondary)
                .lineLimit(1)
        }
    }
}

private struct WidgetRing: View {
    let color: Color
    let isForClaude: Bool
    let isWorking: Bool

    var body: some View {
        if isWorking {
            WorkingRing()
        } else if isForClaude {
            Circle()
                .strokeBorder(color, style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 2]))
        } else {
            Circle()
                .strokeBorder(color, lineWidth: 1.5)
        }
    }
}

/// The app spins this arc; a widget can only hold it still.
private struct WorkingRing: View {
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(PanelStyle.claude.opacity(0.25), lineWidth: 2)
            Circle()
                .trim(from: 0, to: 0.33)
                .stroke(PanelStyle.claude, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .padding(1)
                .rotationEffect(.degrees(-90))
        }
    }
}

private struct TodayProgressView: View {
    let entry: TodayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SproutIcon()
                .frame(width: 22, height: 22)
            Text(entry.openCount, format: .number)
                .font(WidgetStyle.count)
                .foregroundStyle(PanelStyle.title)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, 10)
            Text("left for today")
                .font(.footnote)
                .foregroundStyle(PanelStyle.secondary)
                .lineLimit(1)
            Spacer(minLength: 6)
            progressBar
            Text("\(entry.doneCount) done")
                .font(.caption)
                .foregroundStyle(PanelStyle.secondary)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .widgetURL(AppLink.today.url)
        .containerBackground(for: .widget) {
            WidgetStyle.background
        }
    }

    private var progressBar: some View {
        let fraction = entry.totalCount > 0 ? CGFloat(entry.doneCount) / CGFloat(entry.totalCount) : 0
        return Capsule()
            .fill(WidgetStyle.track)
            .frame(height: 5)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(PanelStyle.green)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .accessibilityHidden(true)
    }
}

private struct ClaudeQuestionView: View {
    let entry: TodayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Glyph(kind: .sparkle, size: 16, filled: true)
                if entry.question == nil {
                    Text(verbatim: "Claude")
                } else {
                    Text("Claude asks")
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(PanelStyle.claude)

            if let question = entry.question {
                Text(verbatim: question.text.isEmpty ? question.title : question.text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PanelStyle.title)
                    .lineLimit(3)
                    .padding(.top, 10)
                if !question.text.isEmpty {
                    Text(verbatim: question.title)
                        .font(.caption)
                        .foregroundStyle(PanelStyle.secondary)
                        .lineLimit(2)
                        .padding(.top, 4)
                }
            } else {
                Text("No questions")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PanelStyle.title)
                    .padding(.top, 10)
                idleNote
                    .font(.caption)
                    .foregroundStyle(PanelStyle.secondary)
                    .lineLimit(2)
                    .padding(.top, 4)
            }

            Spacer(minLength: 4)

            if entry.workingCount > 0 {
                HStack(spacing: 6) {
                    WorkingRing()
                        .frame(width: 14, height: 14)
                    Group {
                        if entry.question == nil {
                            Text("\(entry.workingCount) in progress")
                        } else {
                            Text("Also \(entry.workingCount) in progress")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(PanelStyle.secondary)
                    .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .widgetURL(entry.question.map { AppLink.task($0.id).url } ?? AppLink.today.url)
        .containerBackground(for: .widget) {
            WidgetStyle.background
        }
    }

    @ViewBuilder
    private var idleNote: some View {
        if entry.waitingCount > 0 {
            Text("\(entry.waitingCount) with Claude")
        } else if entry.workingCount == 0 {
            Text("Type @claude in a task")
        }
    }
}
