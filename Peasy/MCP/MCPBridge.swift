import Foundation

/// `Peasy --mcp`: the stdio server Claude Desktop and Claude Code launch. It answers
/// discovery itself and hands tool calls to the running app, which owns the store.
nonisolated enum MCPBridge {
    static func run() async {
        do {
            for try await line in FileHandle.standardInput.bytes.lines {
                let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty, let reply = await reply(to: Data(text.utf8)) else { continue }
                var output = reply
                output.append(0x0A)
                try FileHandle.standardOutput.write(contentsOf: output)
            }
        } catch {
            FileHandle.standardError.write(Data("peasy: \(error.localizedDescription)\n".utf8))
        }
        exit(0)
    }

    static func reply(to body: Data) async -> Data? {
        guard let message = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] else {
            return MCPProtocol.error(id: nil, code: MCPProtocol.parseError, message: "Parse error")
        }
        guard let id = message["id"], let method = message["method"] as? String else { return nil }
        let params = message["params"] as? [String: Any] ?? [:]
        let version = MCPProtocol.requestedVersion(in: message)
        if let version, !MCPProtocol.supportedVersions.contains(version) {
            return MCPProtocol.unsupportedVersionError(id: id, requested: version)
        }
        switch method {
        case "initialize":
            return MCPProtocol.response(id: id, result: MCPProtocol.initializeResult(requested: params["protocolVersion"] as? String))
        case "server/discover":
            return MCPProtocol.response(id: id, result: MCPProtocol.discoverResult())
        case "ping":
            return MCPProtocol.response(id: id, result: MCPProtocol.complete([:]))
        case "tools/list":
            return MCPProtocol.response(id: id, result: MCPProtocol.toolsListResult())
        case "tools/call":
            return await forward(body, id: id, version: version, toolName: params["name"] as? String)
        default:
            return MCPProtocol.error(id: id, code: MCPProtocol.methodNotFound, message: "Method not found: \(method)")
        }
    }

    private static func forward(_ body: Data, id: Any, version: String?, toolName: String?) async -> Data {
        let settings = MCPSettings.current()
        guard settings.isEnabled, !settings.token.isEmpty else {
            return MCPProtocol.response(id: id, result: MCPProtocol.toolFailure(
                "Claude access is turned off in Peasy. Ask the user to turn it on in Peasy Settings → General → Claude."
            ))
        }
        var request = URLRequest(url: settings.endpoint, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(settings.token)", forHTTPHeaderField: "Authorization")
        request.setValue(version ?? MCPProtocol.legacyVersions[0], forHTTPHeaderField: "MCP-Protocol-Version")
        request.setValue("tools/call", forHTTPHeaderField: "Mcp-Method")
        if let toolName {
            request.setValue(headerValue(toolName), forHTTPHeaderField: "Mcp-Name")
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200, !data.isEmpty else {
                return MCPProtocol.response(id: id, result: MCPProtocol.toolFailure("Peasy couldn't run the tool (HTTP \(status))."))
            }
            return data
        } catch {
            return MCPProtocol.response(id: id, result: MCPProtocol.toolFailure(
                "Peasy isn't running. Ask the user to open Peasy, then try again."
            ))
        }
    }

    /// Plain ASCII as is, anything else in the Base64 form the transport defines.
    private static func headerValue(_ value: String) -> String {
        let isPlain = value.unicodeScalars.allSatisfy { $0.value >= 0x21 && $0.value <= 0x7E }
        if isPlain, !(value.hasPrefix("=?base64?") && value.hasSuffix("?=")) {
            return value
        }
        return "=?base64?\(Data(value.utf8).base64EncodedString())?="
    }
}
