import Foundation

nonisolated enum AgentEvent: Equatable, Sendable {
    case added(colorHex: String)
    case finished(taskID: UUID, title: String, note: String)
    case handedBack(taskID: UUID, title: String, question: String)
}
