import Foundation
import WidgetKit

nonisolated struct TodayEntry: TimelineEntry {
    nonisolated struct Row: Identifiable {
        let id: UUID
        let title: String
        let colorHex: String
        let due: Date?
        let hasTime: Bool
        let isOverdue: Bool
        let isForClaude: Bool
        let isWorking: Bool
    }

    nonisolated struct Question {
        let id: UUID
        let text: String
        let title: String
    }

    static let shownRows = 3

    let date: Date
    let openCount: Int
    let doneCount: Int
    let rows: [Row]
    let question: Question?
    let workingCount: Int
    let waitingCount: Int

    var totalCount: Int {
        openCount + doneCount
    }

    /// Today turns over at midnight and Claude's claims run out, so look again within the hour.
    var nextRefresh: Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        return min(tomorrow, date.addingTimeInterval(60 * 60))
    }

    static let placeholder = TodayEntry(
        date: .now,
        openCount: 5,
        doneCount: 3,
        rows: [
            Row(id: UUID(), title: "Book the tyre change", colorHex: "#FF9F0A", due: .now, hasTime: false, isOverdue: false, isForClaude: false, isWorking: false),
            Row(id: UUID(), title: "Send the quarterly report", colorHex: "#0A84FF", due: nil, hasTime: false, isOverdue: false, isForClaude: false, isWorking: false),
            Row(id: UUID(), title: "Add STRIPE_KEY to CI secrets", colorHex: "#30D158", due: nil, hasTime: false, isOverdue: false, isForClaude: true, isWorking: false),
        ],
        question: Question(id: UUID(), text: "Old token or new?", title: "Pick a token for the new API"),
        workingCount: 1,
        waitingCount: 0
    )

    @MainActor
    static func load(now: Date = .now) -> TodayEntry {
        let entry = SharedStore.read { store in
            let tasks = store.allTasks()
            let open = TaskQueries.openTasks(in: .today, from: tasks, now: now)
            let questions = TaskQueries.sorted(tasks.filter { !$0.isDone && $0.agentStatus == .returned })
            let claude = tasks.filter { $0.isForClaude && !$0.isDone }
            let working = claude.filter { $0.isClaimed(now: now) }.count
            return TodayEntry(
                date: now,
                openCount: open.count,
                doneCount: TaskQueries.todayProgress(from: tasks, now: now).done,
                rows: open.prefix(shownRows).map { task in
                    Row(
                        id: task.id,
                        title: task.title,
                        colorHex: task.project?.colorHex ?? ProjectPalette.noProject,
                        due: task.date,
                        hasTime: task.hasTime,
                        isOverdue: task.isOverdue(now: now),
                        isForClaude: task.isForClaude,
                        isWorking: task.isClaimed(now: now)
                    )
                },
                question: questions.first.map { Question(id: $0.id, text: $0.note, title: $0.title) },
                workingCount: working,
                waitingCount: claude.count - working
            )
        }
        return entry ?? TodayEntry(date: now, openCount: 0, doneCount: 0, rows: [], question: nil, workingCount: 0, waitingCount: 0)
    }
}

nonisolated struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        Task { @MainActor in
            completion(TodayEntry.load())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        Task { @MainActor in
            let entry = TodayEntry.load()
            completion(Timeline(entries: [entry], policy: .after(entry.nextRefresh)))
        }
    }
}
