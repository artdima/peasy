import SwiftUI

struct ProjectFolderMenu: View {
    let project: Project
    let store: TaskStore

    var body: some View {
        let folders = ProjectFolders.shared
        if let folder = folders.url(for: project) {
            Menu("Folder: \(folder.lastPathComponent)") {
                Button("Choose Another Folder…") {
                    folders.choose(for: project, store: store)
                }
                Button("Remove Folder") {
                    folders.remove(for: project, store: store)
                }
            }
        } else {
            Button("Project Folder…") {
                folders.choose(for: project, store: store)
            }
        }
    }
}
