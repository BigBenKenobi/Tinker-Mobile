// Version-one companion wire models and strict shared data rules.
// The store owns durable graphs; UI edits copies and sync transfers whole parent
// graphs. JSON values preserve desktop metadata and exact stable IDs. Credentials
// are modeled separately and are never part of SQLite, ICS, or domain exports.
import Foundation

indirect enum JSONValue: Codable, Equatable {
    case string(String), bool(Bool), number(Int), null, array([JSONValue]), object([String: JSONValue])
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Int.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .null: try c.encodeNil()
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }
    var text: String { if case .string(let v) = self { return v }; return "" }
    var flag: Bool { if case .bool(let v) = self { return v }; return false }
}

struct CompanionError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
    init(_ message: String) { self.message = message }
}

/// Shared UTC conversion. All persisted instants include an offset; UI uses the device timezone.
enum Dates {
    static func parse(_ value: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        if let d = formatter.date(from: value) { return d }
        formatter.formatOptions.insert(.withFractionalSeconds)
        if let d = formatter.date(from: value) { return d }
        throw CompanionError("Invalid timestamp: \(value)")
    }
    static func stamp(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
    static func id(_ kind: String) -> String {
        kind + "_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }
}

/// Owned reminder; only its explicit notification owner may schedule the occurrence.
struct Reminder: Codable, Equatable, Identifiable {
    var id: String
    var owner_kind: String
    var owner_id: String
    var fire_at: String
    var message: String
    var notification_owner: String = "phone"
    var completed: Bool = false
}

/// A recurrence override keeps the original occurrence identity even if its time moves.
struct EventException: Codable, Equatable, Identifiable {
    var id: String
    var event_id: String
    var occurrence_at: String
    var cancelled: Bool
    var start_at: String?
    var end_at: String?
    var title: String?
    // Python requires explicit nulls in complete child graphs.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(event_id, forKey: .event_id)
        try c.encode(occurrence_at, forKey: .occurrence_at); try c.encode(cancelled, forKey: .cancelled)
        try c.encode(start_at, forKey: .start_at); try c.encode(end_at, forKey: .end_at); try c.encode(title, forKey: .title)
    }
}

/// Atomic parent and children. Editors mutate a copy; validation runs before persistence/upload.
struct Graph: Codable, Equatable, Identifiable {
    var kind: String
    var record: [String: JSONValue]
    var reminders: [Reminder]
    var exceptions: [EventException]
    var id: String { record["id"]?.text ?? "" }
    var title: String { record["title"]?.text ?? "" }
    func text(_ key: String) -> String { record[key]?.text ?? "" }
    func flag(_ key: String) -> Bool { record[key]?.flag ?? false }
    mutating func set(_ key: String, _ value: String) { record[key] = .string(value) }
    mutating func optional(_ key: String, _ value: String) { record[key] = value.isEmpty ? .null : .string(value) }
    static func new(_ kind: String, now: Date = Date()) -> Graph {
        let id = Dates.id(kind), stamp = Dates.stamp(now)
        var r: [String: JSONValue] = ["id": .string(id), "title": .string(""), "created_at": .string(stamp), "updated_at": .string(stamp), "metadata_json": .string("{}")]
        if kind == "note" { r["body"] = .string(""); r["archived"] = .bool(false); r["pinned"] = .bool(false) }
        else if kind == "task" { r["description"] = .string(""); r["status"] = .string("pending"); r["due_at"] = .null }
        else {
            r["description"] = .string(""); r["location"] = .string("")
            r["start_at"] = .string(stamp); r["end_at"] = .string(Dates.stamp(now.addingTimeInterval(3600)))
            r["timezone"] = .string(TimeZone.current.identifier); r["all_day"] = .bool(false); r["recurrence"] = .null
        }
        return Graph(kind: kind, record: r, reminders: [], exceptions: [])
    }
    func validate() throws {
        let common: Set<String> = ["id", "title", "created_at", "updated_at", "metadata_json"]
        let fields: [String: Set<String>] = ["note": ["body", "archived", "pinned"], "task": ["description", "status", "due_at"], "event": ["description", "location", "start_at", "end_at", "all_day", "timezone", "recurrence"]]
        guard let extra = fields[kind], Set(record.keys) == common.union(extra) else { throw CompanionError("Unsupported record fields") }
        try Self.identifier(id)
        for (key, value) in record {
            if ["archived", "pinned", "all_day"].contains(key) {
                guard case .bool = value else { throw CompanionError("Invalid flag") }
            } else if ["due_at", "recurrence"].contains(key) && value == .null { continue }
            else {
                guard case .string(let text) = value, !text.contains("\0"), text.utf8.count <= 262144 else { throw CompanionError("Invalid or oversized text") }
            }
        }
        for key in ["created_at", "updated_at", "due_at", "start_at", "end_at"] where record[key] != nil && record[key] != .null { _ = try Dates.parse(text(key)) }
        let data = Data(text("metadata_json").utf8)
        guard let metadata = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw CompanionError("Metadata must be an object") }
        try Self.checkMetadata(metadata)
        if kind == "task", !["pending", "in_progress", "completed", "cancelled"].contains(text("status")) { throw CompanionError("Invalid task status") }
        if kind == "event" {
            guard TimeZone(identifier: text("timezone")) != nil else { throw CompanionError("Unknown timezone") }
            guard try Dates.parse(text("end_at")) > Dates.parse(text("start_at")) else { throw CompanionError("End must follow start") }
            _ = try Recurrence(text("recurrence"))
        }
        guard reminders.count <= 1000, exceptions.count <= 1000,
              Set(reminders.map(\.id)).count == reminders.count,
              Set(exceptions.map(\.id)).count == exceptions.count,
              Set(exceptions.map(\.occurrence_at)).count == exceptions.count else { throw CompanionError("Invalid child collection") }
        for r in reminders {
            try Self.identifier(r.id)
            guard r.owner_kind == kind, r.owner_id == id, ["phone", "desktop"].contains(r.notification_owner), r.message.utf8.count <= 262144 else { throw CompanionError("Invalid reminder ownership") }
            _ = try Dates.parse(r.fire_at)
        }
        for e in exceptions {
            try Self.identifier(e.id)
            guard kind == "event", e.event_id == id, (e.start_at == nil) == (e.end_at == nil) else { throw CompanionError("Invalid exception ownership") }
            let original = try Dates.parse(e.occurrence_at)
            let starts = try Recurrence(text("recurrence")).occurrences(start:Dates.parse(text("start_at")),timezone:text("timezone"),lower:original,upper:original.addingTimeInterval(1))
            guard starts.contains(original) else { throw CompanionError("Exception is not an occurrence of this event") }
            if let start = e.start_at, let end = e.end_at {
                guard try Dates.parse(end) > Dates.parse(start) else { throw CompanionError("Invalid exception duration") }
            }
        }
    }
    static func identifier(_ value: String) throws {
        guard value.range(of: "^[A-Za-z0-9_.@-]{1,200}$", options: .regularExpression) != nil else { throw CompanionError("Invalid stable ID") }
    }
    private static func checkMetadata(_ value: Any) throws {
        // Match the desktop's recursive structured-credential exclusion.
        if let object = value as? [String: Any] {
            let markers = ["password", "passwd", "secret", "token", "api_key", "apikey", "private_key", "credential", "auth_key"]
            for (key, child) in object {
                let normalized = key.trimmingCharacters(in: .whitespaces).lowercased().replacingOccurrences(of: "-", with: "_").replacingOccurrences(of: " ", with: "_")
                guard !markers.contains(where: normalized.contains) else { throw CompanionError("Credentials cannot be stored in record metadata") }
                try checkMetadata(child)
            }
        } else if let array = value as? [Any] { for child in array { try checkMetadata(child) } }
    }
}

struct RecordVersion: Codable, Identifiable {
    var kind: String
    var id: String
    var revision: Int
    var value: Graph?
}
struct Conflict: Codable, Identifiable {
    var id: String
    var kind: String
    var record_id: String
    var current: Graph?
    var incoming: Graph?
    var current_revision: Int
    var resolved: Bool
}
struct Mutation: Codable, Identifiable {
    var op_id: String
    var kind: String
    var id: String
    var base_revision: Int
    var value: Graph?
    var resolve_id: String?
    enum CodingKeys: String, CodingKey { case op_id, kind, id, base_revision, value, resolve_id }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(op_id, forKey: .op_id); try c.encode(kind, forKey: .kind); try c.encode(id, forKey: .id)
        try c.encode(base_revision, forKey: .base_revision); try c.encode(value, forKey: .value); try c.encode(resolve_id, forKey: .resolve_id)
    }
}
struct UploadResult: Codable { let op_id: String; let status: String; let revision: Int; let conflict: Conflict? }
struct UploadResponse: Codable { let version: Int; let server_id: String; let results: [UploadResult] }
struct Snapshot: Codable { let version: Int; let server_id: String; let cursor: Int; let records: [RecordVersion]; let conflicts: [Conflict] }
struct Change: Codable {
    let seq: Int
    let kind: String
    let id: String
    let graph: Graph?
    let conflict: Conflict?
    enum CodingKeys: String, CodingKey { case seq, kind, id, value }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        seq = try c.decode(Int.self, forKey: .seq); kind = try c.decode(String.self, forKey: .kind); id = try c.decode(String.self, forKey: .id)
        if kind == "conflict" { conflict = try c.decode(Conflict.self, forKey: .value); graph = nil }
        else { graph = try c.decodeIfPresent(Graph.self, forKey: .value); conflict = nil }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(seq, forKey: .seq); try c.encode(kind, forKey: .kind); try c.encode(id, forKey: .id)
        if kind == "conflict" { try c.encode(conflict, forKey: .value) } else { try c.encode(graph, forKey: .value) }
    }
}
struct Changes: Codable { let version: Int; let server_id: String; let cursor: Int; let has_more: Bool; let changes: [Change] }
