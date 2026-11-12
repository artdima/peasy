import Foundation
import SwiftData

/// Answers one JSON-RPC message against the live store.
final class MCPHandler {
    private let container: () -> ModelContainer?
    var onEvent: (AgentEvent) -> Void = { _ in }
    var access: () -> MCPAccess = { MCPSettings.current().access }

    static let changingTools: Set<String> = ["add_task", "update_task", "set_task_status"]

    init(container: @escaping () -> ModelContainer?) {
        self.container = container
    }

    func handle(_ body: Data) -> MCPReply {
        switch MCPProtocol.route(body) {
        case .reply(let reply):
            reply
        case .callTool(let call):
            MCPReply(body: MCPProtocol.toolResult(run(call), for: call), httpStatus: 200)
        }
    }

    private func run(_ call: MCPToolCall) -> [String: Any] {
        if access() == .read, Self.changingTools.contains(call.name) {
            return MCPProtocol.toolFailure("Claude can only read tasks in Peasy. Ask the user to choose Full Access in Peasy Settings → General → Claude access.")
        }
        guard let container = container() else {
            return MCPProtocol.toolFailure("Peasy is still opening its tasks. Try again in a moment.")
        }
        let tools = PeasyTools(
            store: TaskStore(context: container.mainContext),
            now: DayClock.shared.today,
            session: call.session,
            onEvent: onEvent
        )
        do {
            return MCPProtocol.toolSuccess(try tools.call(call.name, arguments: call.arguments))
        } catch {
            return MCPProtocol.toolFailure(error.localizedDescription)
        }
    }
}
