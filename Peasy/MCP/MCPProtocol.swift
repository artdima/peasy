import Foundation

nonisolated struct MCPReply: Sendable {
    var body: Data?
    /// What Streamable HTTP answers with; stdio only carries the body.
    var httpStatus: Int
}

/// A tools/call for a known tool, past the checks every request goes through.
nonisolated struct MCPToolCall {
    let id: Any
    let name: String
    let arguments: [String: Any]
    /// The version from `params._meta`, which only 2026-07-28 clients send.
    let version: String?
    let meta: [String: Any]

    var isModern: Bool {
        version.map { MCPProtocol.modernVersions.contains($0) } ?? false
    }

    var session: MCPSession {
        MCPSession(meta: meta)
    }
}

nonisolated enum MCPRoute {
    /// Answered without the store.
    case reply(MCPReply)
    case callTool(MCPToolCall)
}

/// JSON-RPC and MCP shapes shared by the in-app server and the stdio bridge.
/// Speaks both eras: `initialize` for clients on 2025-11-25 and earlier, and the
/// stateless 2026-07-28 revision with `server/discover` and per-request `_meta`.
nonisolated enum MCPProtocol {
    static let modernVersions = ["2026-07-28"]
    static let legacyVersions = ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"]
    static let supportedVersions = modernVersions + legacyVersions

    static let versionKey = "io.modelcontextprotocol/protocolVersion"
    static let serverInfoKey = "io.modelcontextprotocol/serverInfo"

    static let parseError = -32700
    static let invalidRequest = -32600
    static let methodNotFound = -32601
    static let invalidParams = -32602
    static let headerMismatch = -32020
    static let unsupportedVersion = -32022

    static let cacheLifetime = 3_600_000

    static var serverInfo: [String: Any] {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return ["name": "peasy", "title": "Peasy", "version": version]
    }

    static let instructions = """
        Peasy is the user's to-do list on this Mac. Tasks belong to at most one project; \
        Today holds tasks planned for today or earlier. Call list_tasks before \
        set_task_status, and pass the task id it returns.
        """

    static var capabilities: [String: Any] {
        ["tools": ["listChanged": false]]
    }

    /// The version a modern request declares in `params._meta`, if it is one.
    static func requestedVersion(in message: [String: Any]) -> String? {
        let params = message["params"] as? [String: Any]
        let meta = params?["_meta"] as? [String: Any]
        return meta?[versionKey] as? String
    }

    /// Everything but running a tool, so the app and the bridge answer alike.
    static func route(_ body: Data) -> MCPRoute {
        guard let message = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] else {
            return .reply(MCPReply(body: error(id: nil, code: parseError, message: "Parse error"), httpStatus: 400))
        }
        guard let method = message["method"] as? String else {
            return .reply(MCPReply(body: error(id: message["id"], code: invalidRequest, message: "Invalid request"), httpStatus: 400))
        }
        guard let id = message["id"] else {
            return .reply(MCPReply(body: nil, httpStatus: 202))
        }
        let params = message["params"] as? [String: Any] ?? [:]
        let version = requestedVersion(in: message)
        if let version, !supportedVersions.contains(version) {
            return .reply(MCPReply(body: unsupportedVersionError(id: id, requested: version), httpStatus: 400))
        }
        let isModern = version.map { modernVersions.contains($0) } ?? false
        func answer(_ result: [String: Any]) -> MCPRoute {
            .reply(MCPReply(body: response(id: id, result: result), httpStatus: 200))
        }

        switch method {
        case "initialize":
            return answer(initializeResult(requested: params["protocolVersion"] as? String))
        case "server/discover":
            return answer(discoverResult())
        case "ping":
            return answer(tagged([:], modern: isModern))
        case "tools/list":
            return answer(toolsListResult(modern: isModern))
        case "tools/call":
            let name = params["name"] as? String ?? ""
            guard toolNames.contains(name) else {
                return .reply(MCPReply(body: error(id: id, code: invalidParams, message: "Unknown tool: \(name)"), httpStatus: 200))
            }
            let arguments = params["arguments"] as? [String: Any] ?? [:]
            let meta = params["_meta"] as? [String: Any] ?? [:]
            return .callTool(MCPToolCall(id: id, name: name, arguments: arguments, version: version, meta: meta))
        default:
            let notFound = error(id: id, code: methodNotFound, message: "Method not found: \(method)")
            return .reply(MCPReply(body: notFound, httpStatus: isModern ? 404 : 200))
        }
    }

    static func initializeResult(requested: String?) -> [String: Any] {
        let version = requested.flatMap { legacyVersions.contains($0) ? $0 : nil } ?? legacyVersions[0]
        return [
            "protocolVersion": version,
            "capabilities": capabilities,
            "serverInfo": serverInfo,
            "instructions": instructions,
        ]
    }

    static func discoverResult() -> [String: Any] {
        let result: [String: Any] = [
            "supportedVersions": supportedVersions,
            "capabilities": capabilities,
            "instructions": instructions,
            "ttlMs": cacheLifetime,
            "cacheScope": "private",
        ]
        return tagged(result, modern: true)
    }

    static func toolsListResult(modern: Bool) -> [String: Any] {
        guard modern else { return ["tools": tools] }
        let result: [String: Any] = ["tools": tools, "ttlMs": cacheLifetime, "cacheScope": "private"]
        return tagged(result, modern: true)
    }

    /// 2026-07-28 marks each result finished and names the server. Older clients get the
    /// bare result: the TypeScript SDK rejects a ping result with any extra key.
    static func tagged(_ result: [String: Any], modern: Bool) -> [String: Any] {
        guard modern else { return result }
        var result = result
        result["resultType"] = "complete"
        result["_meta"] = [serverInfoKey: serverInfo]
        return result
    }

    static func toolSuccess(_ output: [String: Any]) -> [String: Any] {
        [
            "content": [["type": "text", "text": encodeString(output)]],
            "structuredContent": output,
            "isError": false,
        ]
    }

    /// An error the model can act on, reported inside a normal result.
    static func toolFailure(_ message: String) -> [String: Any] {
        [
            "content": [["type": "text", "text": message]],
            "isError": true,
        ]
    }

    static func toolResult(_ result: [String: Any], for call: MCPToolCall) -> Data {
        response(id: call.id, result: tagged(result, modern: call.isModern))
    }

    static func response(id: Any, result: [String: Any]) -> Data {
        encode(["jsonrpc": "2.0", "id": id, "result": result] as [String: Any])
    }

    static func error(id: Any?, code: Int, message: String, data: Any? = nil) -> Data {
        var error: [String: Any] = ["code": code, "message": message]
        if let data {
            error["data"] = data
        }
        return encode(["jsonrpc": "2.0", "id": id ?? NSNull(), "error": error] as [String: Any])
    }

    static func unsupportedVersionError(id: Any, requested: String) -> Data {
        error(
            id: id,
            code: unsupportedVersion,
            message: "Unsupported protocol version",
            data: ["supported": supportedVersions, "requested": requested] as [String: Any]
        )
    }

    static func encode(_ object: Any) -> Data {
        (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data("{}".utf8)
    }

    static func encodeString(_ object: Any) -> String {
        String(decoding: encode(object), as: UTF8.self)
    }

    static var tools: [[String: Any]] {
        [listProjectsTool, listTasksTool, setTaskStatusTool]
    }

    private static var listProjectsTool: [String: Any] {
        let schema: [String: Any] = ["type": "object", "additionalProperties": false]
        let annotations: [String: Any] = ["readOnlyHint": true, "openWorldHint": false]
        return [
            "name": "list_projects",
            "title": "List projects",
            "description": "Lists the user's projects with how many open tasks each has, plus the open task counts of Today and All.",
            "inputSchema": schema,
            "annotations": annotations,
        ]
    }

    private static var listTasksTool: [String: Any] {
        let properties: [String: [String: String]] = [
            "list": [
                "type": "string",
                "description": "\"today\" (default), \"all\", or a project's name or id from list_projects.",
            ],
            "include_completed": [
                "type": "boolean",
                "description": "Also return finished tasks. Today only keeps tasks finished today.",
            ],
            "query": [
                "type": "string",
                "description": "Only tasks whose title contains this text, ignoring case.",
            ],
        ]
        let schema: [String: Any] = ["type": "object", "properties": properties, "additionalProperties": false]
        let annotations: [String: Any] = ["readOnlyHint": true, "openWorldHint": false]
        return [
            "name": "list_tasks",
            "title": "List tasks",
            "description": "Lists tasks in Today, in All or in one project, with their id, title, project, planned date and whether they are done or overdue. Open tasks come first, in the user's order.",
            "inputSchema": schema,
            "annotations": annotations,
        ]
    }

    private static var setTaskStatusTool: [String: Any] {
        let properties: [String: [String: String]] = [
            "task_id": ["type": "string", "description": "The task's id from list_tasks."],
            "done": ["type": "boolean", "description": "true marks the task done, false reopens it."],
        ]
        let schema: [String: Any] = [
            "type": "object",
            "properties": properties,
            "required": ["task_id", "done"],
            "additionalProperties": false,
        ]
        let annotations: [String: Any] = ["readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false]
        return [
            "name": "set_task_status",
            "title": "Set task status",
            "description": "Marks a task as done or as not done again. Returns the task as it is now.",
            "inputSchema": schema,
            "annotations": annotations,
        ]
    }

    static var toolNames: Set<String> {
        Set(tools.compactMap { $0["name"] as? String })
    }
}
