import Foundation
import SwiftData

struct MCPReply {
    var body: Data?
    /// What Streamable HTTP answers with; stdio only carries the body.
    var httpStatus: Int
}

/// Answers one JSON-RPC message against the live store.
final class MCPHandler {
    private let container: () -> ModelContainer?

    init(container: @escaping () -> ModelContainer?) {
        self.container = container
    }

    func handle(_ body: Data) -> MCPReply {
        guard let message = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] else {
            return MCPReply(body: MCPProtocol.error(id: nil, code: MCPProtocol.parseError, message: "Parse error"), httpStatus: 400)
        }
        guard let method = message["method"] as? String else {
            return MCPReply(body: MCPProtocol.error(id: message["id"], code: MCPProtocol.invalidRequest, message: "Invalid request"), httpStatus: 400)
        }
        guard let id = message["id"] else {
            return MCPReply(body: nil, httpStatus: 202)
        }
        let params = message["params"] as? [String: Any] ?? [:]
        let version = MCPProtocol.requestedVersion(in: message)
        if let version, !MCPProtocol.supportedVersions.contains(version) {
            return MCPReply(body: MCPProtocol.unsupportedVersionError(id: id, requested: version), httpStatus: 400)
        }

        switch method {
        case "initialize":
            let result = MCPProtocol.initializeResult(requested: params["protocolVersion"] as? String)
            return MCPReply(body: MCPProtocol.response(id: id, result: result), httpStatus: 200)
        case "server/discover":
            return MCPReply(body: MCPProtocol.response(id: id, result: MCPProtocol.discoverResult()), httpStatus: 200)
        case "ping":
            return MCPReply(body: MCPProtocol.response(id: id, result: MCPProtocol.complete([:])), httpStatus: 200)
        case "tools/list":
            return MCPReply(body: MCPProtocol.response(id: id, result: MCPProtocol.toolsListResult()), httpStatus: 200)
        case "tools/call":
            let name = params["name"] as? String ?? ""
            guard MCPProtocol.toolNames.contains(name) else {
                return MCPReply(body: MCPProtocol.error(id: id, code: MCPProtocol.invalidParams, message: "Unknown tool: \(name)"), httpStatus: 200)
            }
            let arguments = params["arguments"] as? [String: Any] ?? [:]
            return MCPReply(body: MCPProtocol.response(id: id, result: callTool(name, arguments: arguments)), httpStatus: 200)
        default:
            let status = version == nil ? 200 : 404
            return MCPReply(body: MCPProtocol.error(id: id, code: MCPProtocol.methodNotFound, message: "Method not found: \(method)"), httpStatus: status)
        }
    }

    private func callTool(_ name: String, arguments: [String: Any]) -> [String: Any] {
        guard let container = container() else {
            return MCPProtocol.toolFailure("Peasy is still opening its tasks. Try again in a moment.")
        }
        let tools = PeasyTools(store: TaskStore(context: container.mainContext), now: DayClock.shared.today)
        do {
            return MCPProtocol.toolSuccess(try tools.call(name, arguments: arguments))
        } catch {
            return MCPProtocol.toolFailure(error.localizedDescription)
        }
    }
}
