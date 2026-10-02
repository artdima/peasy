import Foundation

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
        [
            "resultType": "complete",
            "supportedVersions": supportedVersions,
            "capabilities": capabilities,
            "instructions": instructions,
            "_meta": [serverInfoKey: serverInfo],
            "ttlMs": 3_600_000,
            "cacheScope": "private",
        ]
    }

    static func toolsListResult() -> [String: Any] {
        [
            "resultType": "complete",
            "tools": tools,
            "_meta": [serverInfoKey: serverInfo],
            "ttlMs": 3_600_000,
            "cacheScope": "private",
        ]
    }

    /// A finished result, tagged as the 2026-07-28 revision asks; older clients ignore the extra keys.
    static func complete(_ result: [String: Any]) -> [String: Any] {
        var result = result
        result["resultType"] = "complete"
        result["_meta"] = [serverInfoKey: serverInfo]
        return result
    }

    static func toolSuccess(_ output: [String: Any]) -> [String: Any] {
        complete([
            "content": [["type": "text", "text": encodeString(output)]],
            "structuredContent": output,
            "isError": false,
        ])
    }

    /// An error the model can act on, reported inside a normal result.
    static func toolFailure(_ message: String) -> [String: Any] {
        complete([
            "content": [["type": "text", "text": message]],
            "isError": true,
        ])
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
