import Foundation

enum NoteOrLink {
    /// One field takes both: a lone web address becomes the link, anything else the note.
    static func split(_ text: String) -> (note: String, link: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: \.isWhitespace),
              let scheme = URL(string: trimmed)?.scheme?.lowercased(),
              scheme == "https" || scheme == "http"
        else { return (trimmed, "") }
        return ("", trimmed)
    }
}
