import AppKit
import Foundation
import Observation

/// Paths differ from Mac to Mac, so each Mac keeps its own and only the folder's name syncs;
/// a bookmark keeps up with a folder that was moved or renamed.
@Observable
final class ProjectFolders {
    static let shared = ProjectFolders()
    static let storageKey = "projectFolders"

    private let defaults: UserDefaults
    private var bookmarks: [String: Data]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        bookmarks = defaults.dictionary(forKey: Self.storageKey) as? [String: Data] ?? [:]
    }

    func hasFolder(for project: Project) -> Bool {
        bookmarks[project.id.uuidString] != nil
    }

    func url(for project: Project) -> URL? {
        guard let data = bookmarks[project.id.uuidString] else { return nil }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &isStale),
              Self.isUsable(url)
        else {
            return nil
        }
        if isStale {
            // Menus read this while drawing, so the fresh bookmark is stored afterwards.
            Task {
                self.renew(url, for: project)
            }
        }
        return url
    }

    @discardableResult
    func choose(for project: Project, store: TaskStore) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = url(for: project)
        panel.prompt = String(localized: "Choose")
        panel.message = String(localized: "Choose the folder of “\(project.name)”. Claude Code opens there when you start one of its tasks in Claude.")
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        save(url, for: project)
        store.setFolder(url.lastPathComponent, for: project)
        return url
    }

    func remove(for project: Project, store: TaskStore) {
        bookmarks[project.id.uuidString] = nil
        defaults.set(bookmarks, forKey: Self.storageKey)
        store.setFolder("", for: project)
    }

    /// A deleted folder can still resolve, to its place in the Trash.
    private static func isUsable(_ url: URL) -> Bool {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return (try? url.checkResourceIsReachable()) == true && !url.pathComponents.contains(".Trash")
    }

    private func renew(_ url: URL, for project: Project) {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        save(url, for: project)
    }

    private func save(_ url: URL, for project: Project) {
        guard let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) else {
            return
        }
        bookmarks[project.id.uuidString] = data
        defaults.set(bookmarks, forKey: Self.storageKey)
    }
}
