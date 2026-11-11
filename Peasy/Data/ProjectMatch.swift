import Foundation

enum ProjectMatch {
    static func project(for workspace: String?, in projects: [Project]) -> Project? {
        guard let workspace, let folder = folderName(of: workspace).map(key), !folder.isEmpty else { return nil }
        let byFolder = projects.filter { !$0.folder.isEmpty && key($0.folder) == folder }
        if !byFolder.isEmpty {
            return byFolder.count == 1 ? byFolder[0] : nil
        }
        let byName = projects.filter { $0.folder.isEmpty && key($0.name) == folder }
        return byName.count == 1 ? byName[0] : nil
    }

    static func folderName(of workspace: String) -> String? {
        let name = (workspace as NSString).lastPathComponent
        return name.isEmpty || name == "/" ? nil : name
    }

    static func key(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .filter { !$0.isWhitespace && $0 != "-" && $0 != "_" }
    }
}
