import Foundation

/// The Claude session a tool call comes from, as the bridge reports it inside the signed body.
nonisolated struct MCPSession: Sendable, Equatable {
    static let workspaceKey = "com.artdima.peasy/workspace"
    static let clientKey = "com.artdima.peasy/client"
    static let sessionKey = "com.artdima.peasy/session"
    static let clientInfoKey = "io.modelcontextprotocol/clientInfo"
    static let projectDirectoryVariable = "CLAUDE_PROJECT_DIR"

    var id: String
    var workspace: String?
    var client: String?

    init(id: String, workspace: String? = nil, client: String? = nil) {
        self.id = id
        self.workspace = workspace
        self.client = client
    }

    init(meta: [String: Any]) {
        id = meta[Self.sessionKey] as? String ?? ""
        workspace = meta[Self.workspaceKey] as? String
        client = meta[Self.clientKey] as? String ?? Self.name(ofClient: meta[Self.clientInfoKey])
    }

    static func workspace(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        currentDirectory: String = FileManager.default.currentDirectoryPath,
        home: String? = realHome
    ) -> String? {
        if let directory = environment[projectDirectoryVariable].flatMap(normalized) {
            return directory
        }
        guard let directory = normalized(currentDirectory),
              directory != "/",
              directory != home.flatMap(normalized),
              !directory.contains("/Library/Containers/")
        else { return nil }
        return directory
    }

    static func clientName(in body: Data) -> String? {
        guard let message = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any],
              let params = message["params"] as? [String: Any]
        else { return nil }
        let meta = params["_meta"] as? [String: Any]
        return name(ofClient: params["clientInfo"]) ?? name(ofClient: meta?[clientInfoKey])
    }

    static func adding(_ session: MCPSession, to body: Data) -> Data? {
        guard var message = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] else { return nil }
        var params = message["params"] as? [String: Any] ?? [:]
        var meta = params["_meta"] as? [String: Any] ?? [:]
        meta[sessionKey] = session.id
        meta[workspaceKey] = session.workspace
        meta[clientKey] = session.client
        params["_meta"] = meta
        message["params"] = params
        return MCPProtocol.encode(message)
    }

    private static func name(ofClient info: Any?) -> String? {
        guard let info = info as? [String: Any] else { return nil }
        let title = (info["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (info["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return [title, name].compactMap { $0 }.first { !$0.isEmpty }
    }

    private static func normalized(_ path: String) -> String? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return nil }
        return (trimmed as NSString).standardizingPath
    }

    static var realHome: String? {
        guard let entry = getpwuid(getuid()) else { return nil }
        return String(cString: entry.pointee.pw_dir)
    }
}

/// What one `Peasy --mcp` process knows about its Claude session across requests.
actor MCPBridgeState {
    private var session: MCPSession

    init(id: String = UUID().uuidString, workspace: String? = MCPSession.workspace()) {
        session = MCPSession(id: id, workspace: workspace)
    }

    func observe(_ body: Data) -> MCPSession {
        if let client = MCPSession.clientName(in: body) {
            session.client = client
        }
        return session
    }
}
