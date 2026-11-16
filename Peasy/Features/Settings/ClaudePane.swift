import AppKit
import SwiftUI

struct ClaudePane: View {
    var failure: MCPServer.Failure?
    @AppStorage(MCPSettings.accessKey) private var access = MCPAccess.off
    @AppStorage(ClaudeNotifications.needsHelpKey) private var notifiesNeedsHelp = true
    @AppStorage(ClaudeNotifications.finishedKey) private var notifiesFinished = false

    private var isOn: Bool {
        access != .off
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            accessCard
            if isOn, !MCPSettings.isTranslocated {
                connectCard
            }
            if access == .full {
                SettingsCard(note: "Shown as soon as Claude hands a task back or finishes one you gave it.") {
                    SettingsToggleRow(title: "Claude needs help", subtitle: nil, isOn: $notifiesNeedsHelp, minHeight: 44)
                    SettingsToggleRow(title: "Claude finished a task", subtitle: nil, isOn: $notifiesFinished, minHeight: 44, separated: true)
                }
            }
        }
        .onChange(of: access) { _, access in
            UserDefaults.standard.set(access != .off, forKey: MCPSettings.enabledKey)
        }
    }

    private var accessCard: some View {
        SettingsCard(note: accessNote) {
            SettingsRow(minHeight: 44) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Claude access")
                        .settingsTitle()
                    Text(subtitle)
                        .settingsSubtitle()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                SettingsPopUp(options: MCPAccess.allCases.map { ($0, $0.title) }, selection: $access)
            }
            if isOn, let warning {
                Text(warning)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            }
        }
    }

    private var connectCard: some View {
        SettingsCard(note: "Peasy has to be running. For Claude Desktop add the config to claude_desktop_config.json in ~/Library/Application Support/Claude and restart Claude; for Claude Code run the command in Terminal.") {
            SettingsRow(minHeight: 44) {
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

    private var subtitle: LocalizedStringKey {
        switch access {
        case .off: "Claude can’t see your tasks"
        case .read: "Reads your tasks"
        case .full: "Reads tasks, adds and updates them"
        }
    }

    private var accessNote: LocalizedStringKey? {
        isOn ? nil : "Lets Claude read your tasks through MCP and, with full access, add tasks for you and work on the ones you hand over. On this Mac only."
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
