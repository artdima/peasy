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
        let head = "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:47823\r\nContent-Length: 2\r\n\r\n"
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
        #expect(request.headers["host"] == "127.0.0.1:47823")
        #expect(request.body == Data("{}".utf8))
    }

    @Test func serverChecksTokenHostMethodAndHeaders() throws {
        let server = MCPServer(handler: handler)
        server.token = "secret"
        func request(
            method: String = "POST",
            host: String = "127.0.0.1:47823",
            token: String? = "secret",
            headers: [String: String] = [:],
            body: [String: Any]
        ) throws -> HTTPRequest {
            var all = headers
            all["host"] = host
            if let token {
                all["authorization"] = "Bearer \(token)"
            }
            return HTTPRequest(method: method, path: "/mcp", headers: all, body: try JSONSerialization.data(withJSONObject: body))
        }
        let discover: [String: Any] = ["jsonrpc": "2.0", "id": 1, "method": "server/discover", "params": ["_meta": modern]]
        let modernHeaders = ["mcp-protocol-version": "2026-07-28", "mcp-method": "server/discover"]

        #expect(server.response(for: try request(headers: modernHeaders, body: discover)).status == 200)
        #expect(server.response(for: try request(token: nil, headers: modernHeaders, body: discover)).status == 401)
        #expect(server.response(for: try request(host: "evil.example:47823", headers: modernHeaders, body: discover)).status == 403)
        #expect(server.response(for: try request(method: "GET", headers: modernHeaders, body: discover)).status == 405)
        #expect(server.response(for: try request(body: discover)).status == 400)

        let params: [String: Any] = ["name": "list_tasks", "arguments": [:] as [String: Any], "_meta": modern]
        let callBody: [String: Any] = ["jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": params]
        var callHeaders = ["mcp-protocol-version": "2026-07-28", "mcp-method": "tools/call"]
        #expect(server.response(for: try request(headers: callHeaders, body: callBody)).status == 400)
        callHeaders["mcp-name"] = "list_tasks"
        #expect(server.response(for: try request(headers: callHeaders, body: callBody)).status == 200)
    }
}
