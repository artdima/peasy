import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID = UUID()
    var title: String = ""
    var isDone: Bool = false
    var isToday: Bool = false
    var date: Date?
    var hasTime: Bool = false
    var completedAt: Date?
    var createdAt: Date = Date()
    var order: Double = 0
    var project: Project?
    var assignee: String = ""
    var agentState: String = ""
    var claimedAt: Date?
    var claimedBy: String = ""
    var note: String = ""
    var link: String = ""
    var origin: String = ""

    init(title: String, order: Double, date: Date? = nil) {
        self.title = title
        self.order = order
        self.date = date
    }
}

extension TaskItem {
    static let claude = "claude"
    static let claimLifetime: TimeInterval = 2 * 60 * 60

    enum AgentState: String {
        case idle = ""
        case working
        case returned
    }

    var isForClaude: Bool {
        assignee == Self.claude
    }

    var agentStatus: AgentState {
        AgentState(rawValue: agentState) ?? .idle
    }

    func isClaimed(now: Date = .now) -> Bool {
        guard isForClaude, !isDone, agentStatus == .working, let claimedAt else { return false }
        return now.timeIntervalSince(claimedAt) < Self.claimLifetime
    }

    func isDue(on day: Date, calendar: Calendar = .current) -> Bool {
        guard let date else { return false }
        return calendar.startOfDay(for: date) <= calendar.startOfDay(for: day)
    }

    func isOverdue(now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard !isDone, let date else { return false }
        return calendar.startOfDay(for: date) < calendar.startOfDay(for: now)
    }
}
