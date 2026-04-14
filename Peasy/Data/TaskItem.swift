import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID = UUID()
    var title: String = ""
    var isDone: Bool = false
    var isToday: Bool = false
    var completedAt: Date?
    var createdAt: Date = Date()
    var order: Double = 0
    var project: Project?

    init(title: String, order: Double, isToday: Bool = false) {
        self.title = title
        self.order = order
        self.isToday = isToday
    }
}
