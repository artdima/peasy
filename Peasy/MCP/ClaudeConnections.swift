import Foundation
import Observation

@Observable
final class ClaudeConnections {
    /// Two and a half beats: a bridge killed before it could say goodbye drops out on its own.
    static let lifetime: TimeInterval = 150

    private struct Contact {
        var client: String
        var seenAt: Date
    }

    private var contacts: [String: Contact] = [:]

    func update(_ session: MCPSession, connected: Bool, at date: Date = .now) {
        contacts = contacts.filter { date.timeIntervalSince($0.value.seenAt) < Self.lifetime }
        contacts[session.id] = connected ? Contact(client: session.clientTitle, seenAt: date) : nil
    }

    func clients(at date: Date = .now) -> [String] {
        let live = contacts.values.filter { date.timeIntervalSince($0.seenAt) < Self.lifetime }
        return Set(live.map(\.client)).sorted()
    }

    func removeAll() {
        contacts.removeAll()
    }
}
