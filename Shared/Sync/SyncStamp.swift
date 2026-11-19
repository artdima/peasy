import Foundation

/// A hybrid logical clock reading: wall time in milliseconds, a counter for changes
/// within one millisecond and the device as the tiebreak. Readings stay ordered
/// even when the Macs' clocks disagree.
nonisolated struct SyncStamp: Hashable, Comparable, Codable, Sendable {
    var millis: Int64
    var counter: Int
    var device: String

    init(millis: Int64, counter: Int, device: String) {
        self.millis = millis
        self.counter = counter
        self.device = device
    }

    init?(text: String) {
        let parts = text.split(separator: "-", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3, let millis = Int64(parts[0]), let counter = Int(parts[1]) else { return nil }
        self.init(millis: millis, counter: counter, device: String(parts[2]))
    }

    var text: String {
        "\(millis)-\(counter)-\(device)"
    }

    static func < (lhs: SyncStamp, rhs: SyncStamp) -> Bool {
        (lhs.millis, lhs.counter, lhs.device) < (rhs.millis, rhs.counter, rhs.device)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let stamp = SyncStamp(text: text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a sync stamp: \(text)")
        }
        self = stamp
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }
}

nonisolated struct SyncClock: Sendable {
    let device: String
    private(set) var last: SyncStamp?

    init(device: String, last: SyncStamp?) {
        self.device = device
        self.last = last
    }

    mutating func tick(now: Date) -> SyncStamp {
        let wall = Int64((now.timeIntervalSince1970 * 1000).rounded(.down))
        let stamp: SyncStamp
        if let last, last.millis >= wall {
            stamp = SyncStamp(millis: last.millis, counter: last.counter + 1, device: device)
        } else {
            stamp = SyncStamp(millis: wall, counter: 0, device: device)
        }
        last = stamp
        return stamp
    }

    /// Keeps the next local reading ahead of everything seen from other Macs.
    mutating func observe(_ remote: SyncStamp) {
        if let last, (last.millis, last.counter) >= (remote.millis, remote.counter) {
            return
        }
        last = SyncStamp(millis: remote.millis, counter: remote.counter, device: device)
    }
}
