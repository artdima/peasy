import SwiftUI

struct ProjectFolderMenu: View {
    let project: Project
    let store: TaskStore

    var body: some View {
        let folders = ProjectFolders.shared
        if folders.hasFolder(for: project) {
            Menu {
                Button("Choose Another Folder…") {
                    folders.choose(for: project, store: store)
                }
                Button("Remove Folder") {
                    folders.remove(for: project, store: store)
                }
            } label: {
                if project.folder.isEmpty {
                    Text("Folder")
                } else {
                    Text("Folder: \(project.folder)")
                }
            }
        } else {
            Button("Project Folder…") {
                folders.choose(for: project, store: store)
            }
        }
    }
}
