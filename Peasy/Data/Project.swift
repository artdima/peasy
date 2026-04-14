import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#0A84FF"
    var order: Double = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \TaskItem.project)
    var tasks: [TaskItem]? = []

    init(name: String, order: Double, colorHex: String) {
        self.name = name
        self.order = order
        self.colorHex = colorHex
    }
}
