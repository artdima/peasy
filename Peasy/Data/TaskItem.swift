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

    init(title: String, order: Double, date: Date? = nil) {
        self.title = title
        self.order = order
        self.date = date
    }
}

extension TaskItem {
    func isDue(on day: Date, calendar: Calendar = .current) -> Bool {
        guard let date else { return false }
        return calendar.startOfDay(for: date) <= calendar.startOfDay(for: day)
    }

    func isOverdue(now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard !isDone, let date else { return false }
        return calendar.startOfDay(for: date) < calendar.startOfDay(for: now)
    }
}
