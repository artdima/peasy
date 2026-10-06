import AppKit
import SwiftUI

struct ClaudeAccessCard: View {
    var failure: MCPServer.Failure?
    @AppStorage(MCPSettings.enabledKey) private var isOn = false

    var body: some View {
        SettingsCard(note: note) {
            SettingsToggleRow(title: "Claude access", subtitle: "Read tasks and mark them done", isOn: $isOn, minHeight: 44)
            if isOn, let warning {
                Text(warning)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            }
            if isOn, !MCPSettings.isTranslocated {
                SettingsRow(minHeight: 44, separated: true) {
                    Text("Claude Desktop")
                        .settingsTitle()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    CopyButton(title: "Copy Config", text: MCPSettings.desktopConfig)
                }
                SettingsRow(minHeight: 44, separated: true) {
                    Text("Claude Code")
                        .settingsTitle()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    CopyButton(title: "Copy Command", text: MCPSettings.claudeCodeCommand)
                }
            }
        }
    }

    private var warning: LocalizedStringKey? {
        if MCPSettings.isTranslocated {
            return "Move Peasy to Applications and open it from there: macOS is running a temporary copy that Claude won’t find after a restart."
        }
        let port = Int(MCPSettings.current().port)
        switch failure {
        case .portInUse:
            return "Another app is using port \(port), so Claude can’t reach Peasy. Quit that app, then turn Claude access off and on."
        case .other(let reason):
            return "Peasy couldn’t open port \(port): \(reason). Turn Claude access off and on to try again."
        case nil:
            return nil
        }
    }

    private var note: LocalizedStringKey {
        if isOn {
            return "Peasy has to be running. In Claude Desktop paste the config in Settings → Developer → Edit Config and restart it; for Claude Code run the command in Terminal."
        }
        return "Lets Claude list your tasks and mark them done through MCP, on this Mac only."
    }
}

struct CopyButton: View {
    let title: LocalizedStringKey
    let text: String

    @State private var isCopied = false

    var body: some View {
        SettingsTextButton(title: isCopied ? "Copied" : title) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            isCopied = true
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                isCopied = false
            }
        }
    }
}
