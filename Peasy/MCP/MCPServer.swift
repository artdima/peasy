import Foundation
import Network

nonisolated struct HTTPRequest: Sendable {
    var method: String
    var path: String
    /// Names lowercased.
    var headers: [String: String]
    var body: Data

    nonisolated enum Parse: Sendable {
        case complete(HTTPRequest)
        case incomplete
        case invalid
    }

    static func parse(_ data: Data) -> Parse {
        guard let headerEnd = data.firstRange(of: Data("\r\n\r\n".utf8)) else { return .incomplete }
        guard let head = String(data: data[data.startIndex..<headerEnd.lowerBound], encoding: .utf8) else { return .invalid }
        let lines = head.components(separatedBy: "\r\n")
        let requestLine = lines[0].split(separator: " ")
        guard requestLine.count >= 2 else { return .invalid }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            headers[name] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        let length = Int(headers["content-length"] ?? "0") ?? -1
        guard length >= 0 else { return .invalid }
        let bodyStart = headerEnd.upperBound
        guard data.distance(from: bodyStart, to: data.endIndex) >= length else { return .incomplete }
        let bodyEnd = data.index(bodyStart, offsetBy: length)
        return .complete(HTTPRequest(
            method: String(requestLine[0]),
            path: String(requestLine[1]),
            headers: headers,
            body: Data(data[bodyStart..<bodyEnd])
        ))
    }
}

nonisolated struct HTTPResponse: Sendable {
    var status: Int
    var body = Data()
    var headers: [String: String] = [:]

    var data: Data {
        var head = "HTTP/1.1 \(status) \(reason)\r\n"
        if !body.isEmpty {
            head += "Content-Type: application/json\r\n"
        }
        head += "Content-Length: \(body.count)\r\nConnection: close\r\n"
        for (name, value) in headers.sorted(by: { $0.key < $1.key }) {
            head += "\(name): \(value)\r\n"
        }
        head += "\r\n"
        return Data(head.utf8) + body
    }

    private var reason: String {
        switch status {
        case 200: "OK"
        case 202: "Accepted"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 403: "Forbidden"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 413: "Content Too Large"
        default: "Error"
        }
    }
}

/// Streamable HTTP on 127.0.0.1 only, for the stdio bridge and other local clients.
/// Every request needs the bearer token; Host and Origin are checked against DNS rebinding.
final class MCPServer {
    static let maximumRequestSize = 1 << 20

    private let handler: MCPHandler
    private var listener: NWListener?
    private(set) var port: UInt16?
    var token = ""

    init(handler: MCPHandler) {
        self.handler = handler
    }

    var isRunning: Bool {
        listener != nil
    }

    func start(port: UInt16, token: String) throws {
        if listener != nil, self.port == port, self.token == token { return }
        stop()
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else { return }
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: endpointPort)
        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in
            MainActor.assumeIsolated {
                guard let self else {
                    connection.cancel()
                    return
                }
                self.accept(connection)
            }
        }
        listener.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated {
                if case .failed = state {
                    self?.stop()
                }
            }
        }
        listener.start(queue: .main)
        self.listener = listener
        self.port = port
        self.token = token
    }

    func stop() {
        listener?.cancel()
        listener = nil
        port = nil
    }

    func response(for request: HTTPRequest) -> HTTPResponse {
        guard request.path.split(separator: "?").first.map(String.init) == "/mcp" else {
            return HTTPResponse(status: 404)
        }
        guard Self.isLocal(host: request.headers["host"]), Self.isLocal(origin: request.headers["origin"]) else {
            return HTTPResponse(status: 403)
        }
        guard !token.isEmpty, request.headers["authorization"] == "Bearer \(token)" else {
            return HTTPResponse(status: 401)
        }
        guard request.method == "POST" else {
            return HTTPResponse(status: 405, headers: ["Allow": "POST"])
        }
        if let mismatch = Self.headerMismatch(in: request) {
            return HTTPResponse(status: 400, body: mismatch)
        }
        let reply = handler.handle(request.body)
        return HTTPResponse(status: reply.httpStatus, body: reply.body ?? Data())
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: .main)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] content, _, isComplete, error in
            MainActor.assumeIsolated {
                guard let self else {
                    connection.cancel()
                    return
                }
                var buffer = buffer
                if let content {
                    buffer.append(content)
                }
                switch HTTPRequest.parse(buffer) {
                case .complete(let request):
                    self.send(self.response(for: request), on: connection)
                case .incomplete where buffer.count > Self.maximumRequestSize:
                    self.send(HTTPResponse(status: 413), on: connection)
                case .incomplete where error == nil && !isComplete:
                    self.receive(on: connection, buffer: buffer)
                case .incomplete, .invalid:
                    self.send(HTTPResponse(status: 400), on: connection)
                }
            }
        }
    }

    private func send(_ response: HTTPResponse, on connection: NWConnection) {
        connection.send(content: response.data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func isLocal(host: String?) -> Bool {
        guard let host else { return false }
        let name: Substring
        if host.hasPrefix("[") {
            name = host.split(separator: "]").first.map { $0.dropFirst() } ?? Substring(host)
        } else {
            name = host.split(separator: ":").first ?? Substring(host)
        }
        return ["127.0.0.1", "localhost", "::1"].contains(String(name))
    }

    private static func isLocal(origin: String?) -> Bool {
        guard let origin, origin != "null" else { return true }
        guard let host = URL(string: origin)?.host else { return false }
        return ["127.0.0.1", "localhost", "::1"].contains(host)
    }

    /// Modern requests mirror the version, method and tool name into headers, and the two must agree.
    private static func headerMismatch(in request: HTTPRequest) -> Data? {
        guard let message = (try? JSONSerialization.jsonObject(with: request.body)) as? [String: Any],
              let version = MCPProtocol.requestedVersion(in: message),
              MCPProtocol.modernVersions.contains(version)
        else { return nil }
        let id = message["id"]
        func mismatch(_ text: String) -> Data {
            MCPProtocol.error(id: id, code: MCPProtocol.headerMismatch, message: "Header mismatch: \(text)")
        }
        guard request.headers["mcp-protocol-version"] == version else {
            return mismatch("MCP-Protocol-Version must be \(version)")
        }
        let method = message["method"] as? String
        guard request.headers["mcp-method"] == method else {
            return mismatch("Mcp-Method must match the request method")
        }
        if method == "tools/call" {
            let name = (message["params"] as? [String: Any])?["name"] as? String
            guard decodedHeader(request.headers["mcp-name"]) == name else {
                return mismatch("Mcp-Name must match the tool name")
            }
        }
        return nil
    }

    private static func decodedHeader(_ value: String?) -> String? {
        guard let value, value.hasPrefix("=?base64?"), value.hasSuffix("?=") else { return value }
        let encoded = value.dropFirst("=?base64?".count).dropLast(2)
        return Data(base64Encoded: String(encoded)).map { String(decoding: $0, as: UTF8.self) }
    }
}
