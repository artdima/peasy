import Foundation

enum ClaudeMention {
    static let token = "@claude"

    static func parse(_ text: String) -> (title: String, isForClaude: Bool) {
        var words: [Substring] = []
        var found = false
        for word in text.split(whereSeparator: \.isWhitespace) {
            if word.lowercased() == token {
                found = true
            } else {
                words.append(word)
            }
        }
        guard found else { return (text, false) }
        return (words.joined(separator: " "), true)
    }
}
