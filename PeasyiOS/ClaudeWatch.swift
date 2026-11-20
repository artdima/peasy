import Foundation

/// Claude works through Peasy on the Mac, so the iPhone learns what it did only from
/// the changes sync brings in. Each look compares Claude's tasks with the previous one.
final class ClaudeWatch {
    struct Look {
        var events: [AgentEvent] = []
        var handedToClaude = false
    }

    private struct State {
        let isForClaude: Bool
        let isDone: Bool
        let agentStatus: TaskItem.AgentState
    }

    private var known: [UUID: State]?

    /// The first look only takes stock.
    func look(at tasks: [TaskItem]) -> Look {
        let current = Dictionary(
            tasks.map { ($0.id, State(isForClaude: $0.isForClaude, isDone: $0.isDone, agentStatus: $0.agentStatus)) },
            uniquingKeysWith: { first, _ in first }
        )
        defer { known = current }
        guard let known else { return Look() }
        var look = Look()
        for task in tasks {
            let before = known[task.id]
            if task.agentStatus == .returned, !task.isDone, before?.agentStatus != .returned {
                look.events.append(.handedBack(taskID: task.id, title: task.title, question: task.note))
            } else if task.isForClaude, task.isDone, before?.isDone == false, before?.agentStatus == .working {
                // Only Claude's claim tells its finish from someone ticking the task off.
                look.events.append(.finished(taskID: task.id, title: task.title, note: task.note))
            }
            if task.isForClaude, !task.isDone, before?.isForClaude != true {
                look.handedToClaude = true
            }
        }
        return look
    }
}
