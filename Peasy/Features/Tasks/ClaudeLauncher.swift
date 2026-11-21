import AppKit
import Foundation

enum ClaudeLauncher {
    private static let claudeApp = URL(string: "claude://")!
    private static let downloadPage = URL(string: "https://claude.ai/download")!

    static func start(_ task: TaskItem, store: TaskStore) {
        guard !task.isDone else { return }
        guard NSWorkspace.shared.urlForApplication(toOpen: claudeApp) != nil else {
            offerDownload()
            return
        }
        var folder: String?
        if let project = task.project {
            let folders = ProjectFolders.shared
            guard let url = folders.url(for: project) ?? folders.choose(for: project, store: store) else { return }
            // A renamed folder keeps its bookmark; its new name is what Claude Code's session will report.
            store.setFolder(url.lastPathComponent, for: project)
            folder = path(of: url)
        }
        let prompt = ClaudeLaunch.prompt(title: task.title, id: task.id, project: task.project?.name, note: task.note, link: task.link)
        guard let link = ClaudeLaunch.url(prompt: prompt, folder: folder), NSWorkspace.shared.open(link) else { return }
        if !task.isForClaude {
            store.assignToClaude(task)
        }
    }

    private static func path(of url: URL) -> String {
        let path = url.standardizedFileURL.path(percentEncoded: false)
        return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    private static func offerDownload() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Claude Desktop isn’t installed")
        alert.informativeText = String(localized: "Peasy starts tasks in Claude Code inside Claude Desktop. Install it, sign in, and start the task again.")
        alert.addButton(withTitle: String(localized: "Download Claude"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(downloadPage)
        }
    }
}
