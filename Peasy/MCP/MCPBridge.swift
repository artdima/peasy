import Foundation

/// `Peasy --mcp`: the stdio server Claude Desktop and Claude Code launch. It answers
/// discovery itself and hands tool calls to the running app, which owns the store.
nonisolated enum MCPBridge {
    static func run() async {
        let output = StandardOutput()
        await withDiscardingTaskGroup { group in
            var lines = LineBuffer()
            do {
                for try await byte in FileHandle.standardInput.bytes {
                    if let line = lines.append(byte) {
                        group.addTask { await MCPBridge.respond(to: line, through: output) }
                    }
                }
            } catch {
                FileHandle.standardError.write(Data("peasy: \(error.localizedDescription)\n".utf8))
            }
            if let line = lines.finish() {
                group.addTask { await MCPBridge.respond(to: line, through: output) }
            }
        }
        exit(0)
    }

    static func reply(to body: Data) async -> Data? {
        switch MCPProtocol.route(body) {
        case .reply(let reply):
            return reply.body
        case .callTool(let call):
            return await forward(body, call)
        }
    }

    private static func respond(to line: Data, through output: StandardOutput) async {
        guard let answer = await reply(to: line) else { return }
        await output.write(answer)
    }

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        // Straight to loopback, even with a system proxy or a PAC file set.
        configuration.connectionProxyDictionary = [:]
        configuration.timeoutIntervalForRequest = 30
        return URLSession(configuration: configuration)
    }()

    private static func forward(_ body: Data, _ call: MCPToolCall) async -> Data {
        let settings = MCPSettings.current()
        guard settings.isEnabled, !settings.token.isEmpty else {
            return failure("Claude access is turned off in Peasy. Ask the user to turn it on in Peasy Settings → General → Claude access.", for: call)
        }
        let signature = MCPSignature(token: settings.token)
        let nonce = MCPSignature.makeNonce()
        let timestamp = String(Int(Date().timeIntervalSince1970))
        var request = URLRequest(url: settings.endpoint)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue(call.version ?? MCPProtocol.legacyVersions[0], forHTTPHeaderField: "MCP-Protocol-Version")
        request.setValue("tools/call", forHTTPHeaderField: "Mcp-Method")
        request.setValue(call.name, forHTTPHeaderField: "Mcp-Name")
        request.setValue(timestamp, forHTTPHeaderField: MCPSignature.timestampHeader)
        request.setValue(nonce, forHTTPHeaderField: MCPSignature.nonceHeader)
        request.setValue(signature.signRequest(body, timestamp: timestamp, nonce: nonce), forHTTPHeaderField: MCPSignature.signatureHeader)

        let exchange: (Data, URLResponse)
        do {
            exchange = try await session.data(for: request)
        } catch {
            return failure("Peasy isn't running or can't take requests. Ask the user to open Peasy and check Settings → General → Claude access.", for: call)
        }
        let (data, response) = exchange
        let http = response as? HTTPURLResponse
        // JSON-RPC errors such as a version mismatch come through as Peasy wrote them.
        guard let proof = http?.value(forHTTPHeaderField: MCPSignature.signatureHeader),
              signature.isValidResponse(data, nonce: nonce, signature: proof),
              !data.isEmpty
        else {
            let status = http?.statusCode ?? 0
            return failure("The reply on port \(settings.port) didn't come from Peasy (HTTP \(status)), so it was ignored. Ask the user to quit whatever else uses that port, or to turn Claude access off and on.", for: call)
        }
        return data
    }

    private static func failure(_ message: String, for call: MCPToolCall) -> Data {
        MCPProtocol.toolResult(MCPProtocol.toolFailure(message), for: call)
    }
}

/// Cuts stdin at LF only: a JSON string may hold U+2028 or NEL, where `bytes.lines` cuts too.
nonisolated struct LineBuffer {
    private var pending = Data()

    /// The line a LF ends, without a trailing CR; nil while the line goes on or when it is blank.
    mutating func append(_ byte: UInt8) -> Data? {
        guard byte == 0x0A else {
            pending.append(byte)
            return nil
        }
        return finish()
    }

    /// Whatever is left once input ends.
    mutating func finish() -> Data? {
        var line = pending
        pending = Data()
        if line.last == 0x0D {
            line.removeLast()
        }
        return line.allSatisfy { $0 == 0x20 || $0 == 0x09 || $0 == 0x0D } ? nil : line
    }
}

/// Replies to requests handled side by side go out one whole line at a time.
private actor StandardOutput {
    func write(_ reply: Data) {
        var line = reply
        line.append(0x0A)
        try? FileHandle.standardOutput.write(contentsOf: line)
    }
}
