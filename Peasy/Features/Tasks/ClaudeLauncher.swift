import AppKit
import Foundation

enum ClaudeLauncher {
    static func start(_ task: TaskItem, store: TaskStore) {
        guard !task.isDone else { return }
        var folder: String?
        if let project = task.project {
            let folders = ProjectFolders.shared
            guard let url = folders.url(for: project) ?? folders.choose(for: project, store: store) else { return }
            folder = path(of: url)
        }
        let prompt = ClaudeLaunch.prompt(title: task.title, id: task.id, project: task.project?.name, note: task.note, link: task.link)
        guard let link = ClaudeLaunch.url(prompt: prompt, folder: folder) else { return }
        if !task.isForClaude {
            store.assignToClaude(task)
        }
        NSWorkspace.shared.open(link)
    }

    private static func path(of url: URL) -> String {
        let path = url.standardizedFileURL.path(percentEncoded: false)
        return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }
}
