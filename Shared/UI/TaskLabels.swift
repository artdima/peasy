import SwiftUI

extension TaskItem {
    var ringMark: CheckRing.Mark {
        guard isForClaude, !isDone else { return .own }
        return isClaimed() ? .working : .waiting
    }

    func agentLabel(now: Date) -> Text? {
        guard isForClaude, !isDone else { return nil }
        guard isClaimed(now: now), let since = claimedAt else {
            return Text(verbatim: "Claude")
        }
        let minutes = max(1, Int(now.timeIntervalSince(since) / 60))
        return Text(verbatim: "Claude · ") + Text("working \(minutes) min").foregroundStyle(PanelStyle.claude)
    }

    var noteLabel: Text? {
        guard !note.isEmpty else { return nil }
        let text = Text(verbatim: note)
        if agentStatus == .returned {
            return Text("Claude asks:").foregroundStyle(PanelStyle.claude) + Text(verbatim: " ") + text
        }
        if isFromAgent || (isForClaude && isDone) {
            let prefix = Text(verbatim: "Claude:")
            return (isDone ? prefix : prefix.foregroundStyle(PanelStyle.claude)) + Text(verbatim: " ") + text
        }
        return text
    }

    var showsNoteMark: Bool {
        agentStatus == .returned || isFromAgent || (isForClaude && isDone)
    }
}

enum TaskCount {
    static func label(for openTasks: [TaskItem]) -> Text {
        let claude = openTasks.filter(\.isForClaude).count
        let own = openTasks.count - claude
        let count = Text("\(own) tasks")
        return claude > 0 ? count + Text(verbatim: " · ") + Text("\(claude) with Claude") : count
    }
}
