import Foundation

nonisolated enum SyncEntity: String, Codable, Sendable {
    case project = "p"
    case task = "t"
}

nonisolated struct RecordKey: Hashable, Comparable, Codable, Sendable {
    var entity: SyncEntity
    var id: UUID

    /// Projects first, so a task's project already exists when the task arrives.
    static func < (lhs: RecordKey, rhs: RecordKey) -> Bool {
        if lhs.entity != rhs.entity {
            return lhs.entity == .project
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

nonisolated enum FieldValue: Hashable, Codable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case text(String)

    /// Reference-date seconds round-trip exactly, unlike seconds since 1970.
    static func date(_ date: Date?) -> FieldValue {
        date.map { .number($0.timeIntervalSinceReferenceDate) } ?? .null
    }

    static func uuid(_ id: UUID?) -> FieldValue {
        id.map { .text($0.uuidString) } ?? .null
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let value): value
        default: nil
        }
    }

    var numberValue: Double? {
        switch self {
        case .number(let value): value
        default: nil
        }
    }

    var textValue: String? {
        switch self {
        case .text(let value): value
        default: nil
        }
    }

    var dateValue: Date? {
        numberValue.map(Date.init(timeIntervalSinceReferenceDate:))
    }

    var uuidValue: UUID? {
        textValue.flatMap(UUID.init(uuidString:))
    }

    var isEmpty: Bool {
        self == .null || self == .text("")
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else {
            self = .text(try container.decode(String.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .text(let value): try container.encode(value)
        }
    }
}

nonisolated enum SyncField {
    static let deleted = "_del"
    static let project = "project"
}

/// One field of one record set to a value at a moment; a deletion is the `_del` field.
nonisolated struct SyncOperation: Hashable, Codable, Sendable {
    var key: RecordKey
    var field: String
    var value: FieldValue
    var stamp: SyncStamp

    init(key: RecordKey, field: String, value: FieldValue, stamp: SyncStamp) {
        self.key = key
        self.field = field
        self.value = value
        self.stamp = stamp
    }

    static func deletion(of key: RecordKey, stamp: SyncStamp) -> SyncOperation {
        SyncOperation(key: key, field: SyncField.deleted, value: .bool(true), stamp: stamp)
    }

    private nonisolated enum CodingKeys: String, CodingKey {
        case entity = "e"
        case id = "i"
        case field = "f"
        case value = "v"
        case stamp = "s"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = RecordKey(
            entity: try container.decode(SyncEntity.self, forKey: .entity),
            id: try container.decode(UUID.self, forKey: .id)
        )
        field = try container.decode(String.self, forKey: .field)
        value = try container.decodeIfPresent(FieldValue.self, forKey: .value) ?? .null
        stamp = try container.decode(SyncStamp.self, forKey: .stamp)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key.entity, forKey: .entity)
        try container.encode(key.id, forKey: .id)
        try container.encode(field, forKey: .field)
        if value == .null {
            try container.encodeNil(forKey: .value)
        } else {
            try container.encode(value, forKey: .value)
        }
        try container.encode(stamp, forKey: .stamp)
    }
}
