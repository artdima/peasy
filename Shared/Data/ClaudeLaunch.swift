import Foundation

enum ClaudeLaunch {
    /// Claude Desktop cuts the prompt at about 14,000 characters; stay under it with room to spare.
    static let promptLimit = 12_000

    static func prompt(title: String, id: UUID, project: String?, note: String, link: String, limit: Int = promptLimit) -> String {
        let task = id.uuidString
        var parts = [
            project.map { String(localized: "Take the Peasy task “\(title)” (id \(task)) in the \($0) project.") }
                ?? String(localized: "Take the Peasy task “\(title)” (id \(task))."),
            String(localized: "Mark it working in Peasy before you start, then finish it with a short report. If you need something from me, hand it back with a question."),
        ]
        let link = link.trimmingCharacters(in: .whitespacesAndNewlines)
        if !link.isEmpty {
            parts.append(String(localized: "Link: \(link)"))
        }
        var note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty {
            let excess = (parts + [String(localized: "Note: \(note)")]).joined(separator: "\n\n").count - limit
            if excess > 0 {
                note = String(note.prefix(max(0, note.count - excess - 1))) + "…"
            }
            parts.append(String(localized: "Note: \(note)"))
        }
        return String(parts.joined(separator: "\n\n").prefix(limit))
    }

    static func url(prompt: String, folder: String?) -> URL? {
        var query = "q=" + encoded(prompt)
        if let folder, !folder.isEmpty {
            query += "&folder=" + encoded(folder)
        }
        return URL(string: "claude://code/new?" + query)
    }

    /// Only the unreserved characters stay as they are, so `&`, `+` and `#` in a task can't break the link.
    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    private static func encoded(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }
}
