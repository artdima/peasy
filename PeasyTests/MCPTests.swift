import Foundation
import SwiftData
import Testing
@testable import Peasy

@MainActor
struct MCPTests {
    let container: ModelContainer
    let store: TaskStore
    let handler: MCPHandler
    let modern: [String: Any] = ["io.modelcontextprotocol/protocolVersion": "2026-07-28"]

    init() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        self.container = container
        store = TaskStore(context: container.mainContext)
        handler = MCPHandler { container }
    }

    private func send(_ message: [String: Any]) throws -> [String: Any] {
        let reply = handler.handle(try JSONSerialization.data(withJSONObject: message))
        let body = try #require(reply.body)
        return try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    private func call(_ tool: String, _ arguments: [String: Any] = [:]) throws -> [String: Any] {
        let params: [String: Any] = ["name": tool, "arguments": arguments, "_meta": modern]
        let response = try send(["jsonrpc": "2.0", "id": 7, "method": "tools/call", "params": params])
        return try #require(response["result"] as? [String: Any])
    }

    private func titles(_ result: [String: Any]) -> [String] {
        let output = result["structuredContent"] as? [String: Any]
        let tasks = output?["tasks"] as? [[String: Any]] ?? []
        return tasks.compactMap { $0["title"] as? String }
    }

    @Test func discoveryWorksInBothEras() throws {
        let discover = try send(["jsonrpc": "2.0", "id": 1, "method": "server/discover", "params": ["_meta": modern]])
        let found = try #require(discover["result"] as? [String: Any])
        #expect(found["resultType"] as? String == "complete")
        #expect((found["supportedVersions"] as? [String])?.contains("2026-07-28") == true)

        let legacy = try send(["jsonrpc": "2.0", "id": 2, "method": "initialize", "params": ["protocolVersion": "2025-06-18"]])
        let initialized = try #require(legacy["result"] as? [String: Any])
        #expect(initialized["protocolVersion"] as? String == "2025-06-18")
        #expect((initialized["capabilities"] as? [String: Any])?["tools"] != nil)

        let future = try send(["jsonrpc": "2.0", "id": 3, "method": "initialize", "params": ["protocolVersion": "2099-01-01"]])
        #expect((future["result"] as? [String: Any])?["protocolVersion"] as? String == "2025-11-25")
    }

    @Test func unknownModernVersionIsRejectedWithTheSupportedOnes() throws {
        let message: [String: Any] = [
            "jsonrpc": "2.0", "id": 4, "method": "tools/list",
            "params": ["_meta": ["io.modelcontextprotocol/protocolVersion": "1900-01-01"]],
        ]
        let reply = handler.handle(try JSONSerialization.data(withJSONObject: message))
        #expect(reply.httpStatus == 400)
        let body = try #require(reply.body)
        let response = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let error = try #require(response["error"] as? [String: Any])
        #expect(error["code"] as? Int == -32022)
        #expect(((error["data"] as? [String: Any])?["supported"] as? [String])?.contains("2026-07-28") == true)
    }

    @Test func toolListIsCompleteAndCacheable() throws {
        let response = try send(["jsonrpc": "2.0", "id": 5, "method": "tools/list", "params": ["_meta": modern]])
        let result = try #require(response["result"] as? [String: Any])
        let names = (result["tools"] as? [[String: Any]])?.compactMap { $0["name"] as? String }
        #expect(names == ["list_projects", "list_tasks", "set_task_status"])
        #expect(result["resultType"] as? String == "complete")
        #expect(result["ttlMs"] as? Int != nil)
    }

    @Test func olderClientsGetBareResults() throws {
        let ping = try send(["jsonrpc": "2.0", "id": 1, "method": "ping"])
        #expect((ping["result"] as? [String: Any])?.isEmpty == true)
        let modernPing = try send(["jsonrpc": "2.0", "id": 2, "method": "ping", "params": ["_meta": modern]])
        #expect((modernPing["result"] as? [String: Any])?["resultType"] as? String == "complete")

        let list = try send(["jsonrpc": "2.0", "id": 3, "method": "tools/list"])
        let result = try #require(list["result"] as? [String: Any])
        #expect(result.keys.contains("tools"))
        #expect(!result.keys.contains("resultType"))
        #expect(!result.keys.contains("ttlMs"))

        let params: [String: Any] = ["name": "list_tasks", "arguments": [:] as [String: Any]]
        let legacyCall = try send(["jsonrpc": "2.0", "id": 4, "method": "tools/call", "params": params])
        let called = try #require(legacyCall["result"] as? [String: Any])
        #expect(called["isError"] as? Bool == false)
        #expect(!called.keys.contains("resultType"))
    }

    @Test func notificationsGetNoReply() {
        let body = Data(#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#.utf8)
        let reply = handler.handle(body)
        #expect(reply.body == nil)
        #expect(reply.httpStatus == 202)
    }

    @Test func listsTodayAProjectAndTheProjects() throws {
        let work = try #require(store.createProject(named: "Работа"))
        store.addTask("Release", project: work, isToday: true)
        store.addTask("Docs", project: work, isToday: false)
        store.addTask("Mail", project: nil, isToday: true)
        let done = try #require(store.addTask("Standup", project: nil, isToday: true))
        store.toggle(done)

        #expect(titles(try call("list_tasks")) == ["Release", "Mail"])
        #expect(titles(try call("list_tasks", ["include_completed": true])) == ["Release", "Mail", "Standup"])
        #expect(titles(try call("list_tasks", ["list": "работа"])) == ["Release", "Docs"])
        #expect(titles(try call("list_tasks", ["list": "all", "query": "DOC"])) == ["Docs"])

        let projects = try #require(try call("list_projects")["structuredContent"] as? [String: Any])
        #expect(projects["today_open_tasks"] as? Int == 2)
        let first = try #require((projects["projects"] as? [[String: Any]])?.first)
        #expect(first["name"] as? String == "Работа")
        #expect(first["open_tasks"] as? Int == 2)
    }

    @Test func setTaskStatusMarksDoneAndReopens() throws {
        let task = try #require(store.addTask("Call mom", to: .today))

        let finished = try call("set_task_status", ["task_id": task.id.uuidString, "done": true])
        #expect(finished["isError"] as? Bool == false)
        #expect(task.isDone)
        #expect(task.completedAt != nil)
        let output = try #require(finished["structuredContent"] as? [String: Any])
        #expect((output["task"] as? [String: Any])?["done"] as? Bool == true)

        _ = try call("set_task_status", ["task_id": task.id.uuidString, "done": false])
        #expect(!task.isDone)
        #expect(task.completedAt == nil)
    }

    @Test func mistakesComeBackAsToolErrors() throws {
        #expect(try call("set_task_status", ["task_id": UUID().uuidString, "done": true])["isError"] as? Bool == true)
        #expect(try call("set_task_status", ["task_id": "nope", "done": true])["isError"] as? Bool == true)
        #expect(try call("list_tasks", ["list": "Nowhere"])["isError"] as? Bool == true)

        let params: [String: Any] = ["name": "delete_everything", "arguments": [:] as [String: Any]]
        let unknown = try send(["jsonrpc": "2.0", "id": 9, "method": "tools/call", "params": params])
        #expect((unknown["error"] as? [String: Any])?["code"] as? Int == -32602)
    }

    @Test func requestsAreParsedOnlyWhenComplete() throws {
        let head = "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:47501\r\nContent-Length: 2\r\n\r\n"
        guard case .incomplete = HTTPRequest.parse(Data((head + "{").utf8)) else {
            Issue.record("A short body should wait for the rest")
            return
        }
        guard case .complete(let request) = HTTPRequest.parse(Data((head + "{}").utf8)) else {
            Issue.record("A full request should parse")
            return
        }
        #expect(request.method == "POST")
        #expect(request.path == "/mcp")
        #expect(request.headers["host"] == "127.0.0.1:47501")
        #expect(request.body == Data("{}".utf8))
    }

    private func signedRequest(
        _ message: [String: Any],
        method: String = "POST",
        host: String = "127.0.0.1:47501",
        token: String = "secret",
        sentAt: Date = .now,
        headers: [String: String] = [:]
    ) throws -> HTTPRequest {
        let body = try JSONSerialization.data(withJSONObject: message)
        let timestamp = String(Int(sentAt.timeIntervalSince1970))
        let nonce = MCPSignature.makeNonce()
        var all = headers
        all["host"] = host
        all[MCPSignature.timestampHeader.lowercased()] = timestamp
        all[MCPSignature.nonceHeader.lowercased()] = nonce
        all[MCPSignature.signatureHeader.lowercased()] = MCPSignature(token: token).signRequest(body, timestamp: timestamp, nonce: nonce)
        return HTTPRequest(method: method, path: "/mcp", headers: all, body: body)
    }

    @Test func serverChecksSignatureHostMethodAndHeaders() throws {
        let server = MCPServer(handler: handler)
        server.token = "secret"
        let discover: [String: Any] = ["jsonrpc": "2.0", "id": 1, "method": "server/discover", "params": ["_meta": modern]]
        let modernHeaders = ["mcp-protocol-version": "2026-07-28", "mcp-method": "server/discover"]

        let request = try signedRequest(discover, headers: modernHeaders)
        let response = server.response(for: request)
        #expect(response.status == 200)
        let nonce = try #require(request.headers[MCPSignature.nonceHeader.lowercased()])
        let proof = try #require(response.headers[MCPSignature.signatureHeader])
        #expect(MCPSignature(token: "secret").isValidResponse(response.body, nonce: nonce, signature: proof))
        #expect(!MCPSignature(token: "guess").isValidResponse(response.body, nonce: nonce, signature: proof))

        var unsigned = try signedRequest(discover, headers: modernHeaders)
        unsigned.headers[MCPSignature.signatureHeader.lowercased()] = nil
        #expect(server.response(for: unsigned).status == 401)
        #expect(server.response(for: try signedRequest(discover, token: "guess", headers: modernHeaders)).status == 401)
        #expect(server.response(for: try signedRequest(discover, host: "evil.example:47501", headers: modernHeaders)).status == 403)
        #expect(server.response(for: try signedRequest(discover, method: "GET", headers: modernHeaders)).status == 405)
        #expect(server.response(for: try signedRequest(discover)).status == 400)

        let params: [String: Any] = ["name": "list_tasks", "arguments": [:] as [String: Any], "_meta": modern]
        let callBody: [String: Any] = ["jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": params]
        var callHeaders = ["mcp-protocol-version": "2026-07-28", "mcp-method": "tools/call"]
        #expect(server.response(for: try signedRequest(callBody, headers: callHeaders)).status == 400)
        callHeaders["mcp-name"] = "list_tasks"
        #expect(server.response(for: try signedRequest(callBody, headers: callHeaders)).status == 200)
    }

    @Test func aSignedRequestWorksOnceAndOnlyWhileFresh() throws {
        let server = MCPServer(handler: handler)
        server.token = "secret"
        let ping: [String: Any] = ["jsonrpc": "2.0", "id": 1, "method": "ping"]

        let request = try signedRequest(ping)
        #expect(server.response(for: request).status == 200)
        #expect(server.response(for: request).status == 401)
        #expect(server.response(for: try signedRequest(ping, sentAt: .now - 300)).status == 401)
        #expect(server.response(for: try signedRequest(ping, sentAt: .now + 300)).status == 401)
    }

    @Test func bridgeAnswersWithoutTheAppWhenItCan() async throws {
        func reply(_ message: [String: Any]) async throws -> [String: Any] {
            let body = try JSONSerialization.data(withJSONObject: message)
            let data = try #require(await MCPBridge.reply(to: body))
            return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        }
        let list = try await reply(["jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": ["_meta": modern]])
        #expect(((list["result"] as? [String: Any])?["tools"] as? [[String: Any]])?.count == 3)

        let params: [String: Any] = ["name": "delete_everything", "arguments": [:] as [String: Any]]
        let unknown = try await reply(["jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": params])
        #expect((unknown["error"] as? [String: Any])?["code"] as? Int == -32602)

        let notification = Data(#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#.utf8)
        #expect(await MCPBridge.reply(to: notification) == nil)
    }

    @Test func workspaceComesFromClaudeCodeOrTheFolderItStartsIn() {
        let home = "/Users/dima"
        let project = "/Users/dima/Projects/peasy"
        #expect(MCPSession.workspace(environment: ["CLAUDE_PROJECT_DIR": project + "/"], currentDirectory: "/", home: home) == project)
        #expect(MCPSession.workspace(environment: [:], currentDirectory: project, home: home) == project)
        #expect(MCPSession.workspace(environment: ["CLAUDE_PROJECT_DIR": "peasy"], currentDirectory: project, home: home) == project)
        for directory in ["/", home, "/Users/dima/Library/Containers/com.artdima.Peasy/Data", ""] {
            #expect(MCPSession.workspace(environment: [:], currentDirectory: directory, home: home) == nil)
        }
    }

    @Test func bridgeTellsTheAppWhoIsCalling() async throws {
        let state = MCPBridgeState(id: "s1", workspace: "/Users/dima/Projects/peasy")
        let clientInfo: [String: Any] = ["name": "claude-code", "title": "Claude Code"]
        let initializeParams: [String: Any] = ["protocolVersion": "2025-06-18", "clientInfo": clientInfo]
        let initialize: [String: Any] = ["jsonrpc": "2.0", "id": 1, "method": "initialize", "params": initializeParams]
        _ = await state.observe(try JSONSerialization.data(withJSONObject: initialize))

        let spoofedMeta: [String: Any] = [MCPSession.workspaceKey: "/elsewhere", MCPSession.sessionKey: "other"]
        let params: [String: Any] = ["name": "list_tasks", "arguments": [:] as [String: Any], "_meta": spoofedMeta]
        let body = try JSONSerialization.data(withJSONObject: ["jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": params] as [String: Any])
        let session = await state.observe(body)
        #expect(session == MCPSession(id: "s1", workspace: "/Users/dima/Projects/peasy", client: "Claude Code"))

        guard case .callTool(let call) = MCPProtocol.route(try #require(MCPSession.adding(session, to: body))) else {
            Issue.record("Expected a tool call")
            return
        }
        #expect(call.session == session)

        let anywhere = MCPSession(id: "s2")
        guard case .callTool(let elsewhere) = MCPProtocol.route(try #require(MCPSession.adding(anywhere, to: body))) else {
            Issue.record("Expected a tool call")
            return
        }
        #expect(elsewhere.session == anywhere)
    }

    @Test func modernClientsNameThemselvesInEveryRequest() throws {
        var meta = modern
        meta[MCPSession.clientInfoKey] = ["name": "claude-ai"]
        let params: [String: Any] = ["name": "list_tasks", "arguments": [:] as [String: Any], "_meta": meta]
        let body = try JSONSerialization.data(withJSONObject: ["jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": params] as [String: Any])
        #expect(MCPSession.clientName(in: body) == "claude-ai")

        guard case .callTool(let call) = MCPProtocol.route(body) else {
            Issue.record("Expected a tool call")
            return
        }
        #expect(call.session.client == "claude-ai")
        #expect(call.session.workspace == nil)
    }

    @Test func stdinIsCutOnlyAtLineFeeds() {
        let first = "{\"query\":\"a\u{2028}b\u{85}c\"}"
        let input = Data((first + "\r\n \n{\"id\":1}").utf8)
        var buffer = LineBuffer()
        var lines: [Data] = []
        for byte in input {
            if let line = buffer.append(byte) {
                lines.append(line)
            }
        }
        if let line = buffer.finish() {
            lines.append(line)
        }
        #expect(lines == [Data(first.utf8), Data("{\"id\":1}".utf8)])
    }
}
