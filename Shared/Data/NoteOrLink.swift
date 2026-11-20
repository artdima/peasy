import Foundation

enum NoteOrLink {
    static func split(_ text: String) -> (note: String, link: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: \.isWhitespace),
              let scheme = URL(string: trimmed)?.scheme?.lowercased(),
              scheme == "https" || scheme == "http"
        else { return (trimmed, "") }
        return ("", trimmed)
    }
}
