import SwiftUI

@main
enum PeasyMain {
    /// `Peasy --mcp` runs headless as the stdio MCP server; anything else starts the app.
    static func main() {
        if CommandLine.arguments.contains(MCPSettings.bridgeArgument) {
            Task.detached {
                await MCPBridge.run()
            }
            dispatchMain()
        }
        PeasyApp.main()
    }
}

struct PeasyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
