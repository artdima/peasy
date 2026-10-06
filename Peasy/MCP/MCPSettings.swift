import Foundation

/// Read by the app and by `Peasy --mcp`, which share one sandbox container and so one defaults domain.
nonisolated struct MCPSettings: Sendable {
    static let enabledKey = "claudeAccessEnabled"
    static let tokenKey = "claudeAccessToken"
    static let portKey = "claudeAccessPort"
    static let bridgeArgument = "--mcp"
    static let serverName = "peasy"

    /// One port per account, so two people signed in on one Mac each reach their own Peasy.
    static var defaultPort: UInt16 {
        UInt16(47_000 + Int(getuid() % 1_000))
    }

    let isEnabled: Bool
    let port: UInt16
    let token: String

    static func current(in defaults: UserDefaults = .standard) -> MCPSettings {
        let stored = defaults.integer(forKey: portKey)
        let port = (1024...65535).contains(stored) ? UInt16(stored) : defaultPort
        return MCPSettings(
            isEnabled: defaults.bool(forKey: enabledKey),
            port: port,
            token: defaults.string(forKey: tokenKey) ?? ""
        )
    }

    /// The secret both processes sign with; only this container can read it.
    @discardableResult
    static func ensureToken(in defaults: UserDefaults = .standard) -> String {
        if let token = defaults.string(forKey: tokenKey), !token.isEmpty {
            return token
        }
        let token = (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "").lowercased()
        defaults.set(token, forKey: tokenKey)
        return token
    }

    var endpoint: URL {
        URL(string: "http://127.0.0.1:\(port)/mcp")!
    }

    static var executablePath: String {
        Bundle.main.executablePath ?? "/Applications/Peasy.app/Contents/MacOS/Peasy"
    }

    /// Opened straight from Downloads or a disk image, the app runs from a random read-only
    /// copy that is gone after a restart, so a config pointing there would break.
    static var isTranslocated: Bool {
        executablePath.contains("/AppTranslocation/")
    }

    static var desktopConfig: String {
        let path = executablePath.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return """
            {
              "mcpServers": {
                "\(serverName)": {
                  "command": "\(path)",
                  "args": ["\(bridgeArgument)"]
                }
              }
            }
            """
    }

    static var claudeCodeCommand: String {
        let path = "'" + executablePath.replacingOccurrences(of: "'", with: "'\\''") + "'"
        return "claude mcp add --scope user \(serverName) -- \(path) \(bridgeArgument)"
    }
}
