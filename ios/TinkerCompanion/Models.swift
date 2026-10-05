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
    var integer: Int? { if case .number(let v) = self { return v }; return nil }
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

/// Device-owned event alarm. Task alarms live in the task record itself.
struct Reminder: Codable, Equatable, Identifiable {
    var id: String
    var owner_kind: String
    var owner_id: String
    var fire_at: String
    var message: String
    var notification_owner: String = "phone"
    var completed: Bool = false
}

/// UI projection of a native calendar exception; original_start is its stable key.
struct EventException: Codable, Equatable, Identifiable {
    var id: String
    var event_id: String
    var occurrence_at: String
    var cancelled: Bool
    var start_at: String?
    var end_at: String?
    var title: String?
    var originalValue: [String: JSONValue]? = nil
}

/// UI drafts use familiar fields, while Codable speaks exact desktop protocol two.
struct Graph: Codable, Equatable, Identifiable {
    var kind: String
    var record: [String: JSONValue]
    var reminders: [Reminder]
    var exceptions: [EventException]
    var linked_task: [String: JSONValue]? = nil
    var activity: [[String: JSONValue]] = []
    private var native: [String: JSONValue] = [:]
    var id: String { record["id"]?.text ?? "" }
    var title: String { text(kind == "calendar" ? "name" : "title") }
    func text(_ key: String) -> String { record[key]?.text ?? "" }
    func flag(_ key: String) -> Bool { record[key]?.flag ?? false }
    mutating func set(_ key: String, _ value: String) { record[key] = .string(value) }
    mutating func optional(_ key: String, _ value: String) { record[key] = value.isEmpty ? .null : .string(value) }

    static func new(_ kind: String, now: Date = Date()) -> Graph {
        let id = Dates.id(kind), stamp = Dates.stamp(now)
        var r: [String: JSONValue] = ["id": .string(id)]
        switch kind {
        case "note":
            r.merge(["title": .string(""), "body": .string(""), "archived": .bool(false), "pinned": .bool(false),
                     "created_at": .string(stamp), "updated_at": .string(stamp), "metadata_json": .string("{}")]) { _, new in new }
        case "task":
            r.merge(["title": .string(""), "description": .string(""), "status": .string("pending"), "due_at": .null,
                     "created_at": .string(stamp), "updated_at": .string(stamp), "metadata_json": .string("{}"),
                     "kind": .string("todo"), "timezone_name": .string(TimeZone.current.identifier), "recurrence": .string("none"),
                     "recurrence_anchor": .null, "paused": .bool(false), "last_fired_at": .null,
                     "note_id": .null, "notification_owner": .string("phone")]) { _, new in new }
        case "calendar":
            r.merge(["name": .string("New calendar"), "color": .string("#729240"), "visible": .bool(true), "sort_order": .number(0)]) { _, new in new }
        default:
            r.merge(["title": .string(""), "description": .string(""), "location": .string(""),
                     "start_at": .string(stamp), "end_at": .string(Dates.stamp(now.addingTimeInterval(3600))),
                     "timezone": .string(TimeZone.current.identifier), "all_day": .bool(false), "recurrence": .null,
                     "created_at": .string(stamp), "updated_at": .string(stamp), "calendar_id": .string(""),
                     "ics_uid": .string(id + "@tinker")]) { _, new in new }
        }
        return Graph(kind: kind, record: r, reminders: [], exceptions: [])
    }

    enum CodingKeys: String, CodingKey { case kind, record, linked_task, activity, exceptions, reminders }
    init(kind: String, record: [String: JSONValue], reminders: [Reminder], exceptions: [EventException]) {
        self.kind = kind; self.record = record; self.reminders = reminders; self.exceptions = exceptions
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(String.self, forKey: .kind)
        native = try c.decode([String: JSONValue].self, forKey: .record)
        linked_task = try c.decodeIfPresent([String: JSONValue].self, forKey: .linked_task)
        activity = try c.decode([[String: JSONValue]].self, forKey: .activity)
        record = native
        if kind == "event" {
            record["description"] = native["notes"] ?? .string("")
            record["timezone"] = native["timezone_name"] ?? .string("UTC")
            record["start_at"] = .string(Self.instant(native["start_value"]?.text ?? ""))
            let end = Self.instant(native["end_value"]?.text ?? "")
            record["end_at"] = .string(native["all_day"]?.flag == true ? Self.dayAfter(end) : end)
            record["recurrence"] = .string(Self.rule(native))
        }
        let alarmRows: [[String: JSONValue]] = try c.decode([[String: JSONValue]].self, forKey: .reminders)
        reminders = alarmRows.map { row in
            Reminder(id:row["id"]?.text ?? "", owner_kind:"event", owner_id:row["event_id"]?.text ?? "",
                     fire_at:row["fire_at"]?.text ?? "", message:row["message"]?.text ?? "",
                     notification_owner:row["notification_owner"]?.text ?? "phone", completed:row["completed"]?.flag ?? false)
        }
        let exceptionRows: [[String: JSONValue]] = try c.decode([[String: JSONValue]].self, forKey: .exceptions)
        exceptions = exceptionRows.map { row in
            let original = row["original_start"]?.text ?? ""
            let replacement = row["replacement_json"]?.text ?? ""
            let object = (try? JSONDecoder().decode([String: JSONValue].self, from:Data(replacement.utf8))) ?? [:]
            return EventException(id:original, event_id:row["event_id"]?.text ?? "", occurrence_at:Self.instant(original),
                                  cancelled:row["kind"]?.text == "cancelled", start_at:object["start"]?.text.map(Self.instant),
                                  end_at:object["end"]?.text.map(Self.instant), title:object["title"]?.text, originalValue:object)
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey:.kind)
        var r = native.isEmpty ? record : native
        switch kind {
        case "note":
            for key in ["id","title","body","archived","pinned","created_at","updated_at","metadata_json"] { r[key] = record[key] }
        case "task":
            for key in ["id","title","description","status","due_at","created_at","updated_at","metadata_json"] { r[key] = record[key] }
            for key in ["recurrence","paused","notification_owner"] { if let value = record[key] { r[key] = value } }
            if native.isEmpty {
                r.merge(["kind": .string(record["due_at"] == .null ? "todo" : "reminder"), "timezone_name": .string(TimeZone.current.identifier),
                         "recurrence": .string("none"), "recurrence_anchor": .null, "paused": .bool(false),
                         "last_fired_at": .null, "note_id": .null, "notification_owner": .string("phone")]) { _, new in new }
            }
            if record["due_at"] != .null { r["kind"] = .string("reminder") }
            else { r["kind"] = .string("todo"); r["recurrence"] = .string("none") }
        case "event":
            if native.isEmpty {
                for key in ["description","start_at","end_at","timezone","recurrence"] { r.removeValue(forKey:key) }
            }
            for key in ["id","title","location","all_day","created_at","updated_at","calendar_id","ics_uid"] { r[key] = record[key] }
            r["notes"] = record["description"] ?? .string("")
            r["timezone_name"] = record["timezone"] ?? .string("UTC")
            r["start_value"] = .string(Self.dateValue(text("start_at"), allDay:flag("all_day")))
            r["end_value"] = .string(Self.dateValue(flag("all_day") ? Self.dayBefore(text("end_at")) : text("end_at"), allDay:flag("all_day")))
            let repeatRule = try Recurrence(text("recurrence"))
            if let frequency = repeatRule.frequency {
                r["recurrence_frequency"] = .string(frequency)
                r["recurrence_interval"] = .number(repeatRule.interval)
                let weekdays = repeatRule.weekdays?.compactMap { Recurrence.days.firstIndex(of:$0) } ?? []
                r["recurrence_weekdays"] = .string(String(data:try JSONEncoder().encode(weekdays.sorted()),encoding:.utf8)!)
                r["recurrence_count"] = repeatRule.count == 10000 ? .null : .number(repeatRule.count)
                r["recurrence_until"] = repeatRule.until.map { .string(String(Dates.stamp($0).prefix(10))) } ?? .null
            } else {
                for key in ["recurrence_frequency","recurrence_interval","recurrence_weekdays","recurrence_count","recurrence_until"] { r[key] = .null }
            }
        default: break
        }
        try c.encode(r, forKey:.record)
        try c.encode(linked_task, forKey:.linked_task)
        try c.encode(activity, forKey:.activity)
        try c.encode(reminders.map { reminder in
            ["id": .string(reminder.id), "event_id": .string(reminder.owner_id), "fire_at": .string(reminder.fire_at),
             "message": .string(reminder.message), "notification_owner": .string(reminder.notification_owner),
             "completed": .bool(reminder.completed)] as [String: JSONValue]
        }, forKey:.reminders)
        try c.encode(exceptions.map { item -> [String: JSONValue] in
            if item.cancelled { return ["event_id": .string(item.event_id), "original_start": .string(Self.dateValue(item.occurrence_at,allDay:flag("all_day"))), "kind": .string("cancelled"), "replacement_json": .null] }
            var value = item.originalValue ?? [:]
            value["id"] = .string(item.event_id); value["title"] = .string(item.title ?? title)
            value["start"] = .string(Self.dateValue(item.start_at ?? item.occurrence_at,allDay:flag("all_day")))
            value["end"] = .string(Self.dateValue(flag("all_day") ? Self.dayBefore(item.end_at ?? text("end_at")) : item.end_at ?? text("end_at"),allDay:flag("all_day")))
            value["calendar_id"] = record["calendar_id"] ?? .string("")
            value["all_day"] = record["all_day"] ?? .bool(false)
            value["timezone_name"] = record["timezone"] ?? .string("UTC")
            value["location"] = record["location"] ?? .string("")
            value["notes"] = record["description"] ?? .string("")
            value["ics_uid"] = record["ics_uid"] ?? .string("")
            value["created_at"] = record["created_at"] ?? .string("")
            value["updated_at"] = record["updated_at"] ?? .string("")
            let bytes = (try? JSONEncoder().encode(value)) ?? Data("{}".utf8)
            return ["event_id": .string(item.event_id), "original_start": .string(Self.dateValue(item.occurrence_at,allDay:flag("all_day"))), "kind": .string("override"), "replacement_json": .string(String(decoding:bytes,as:UTF8.self))]
        }, forKey:.exceptions)
    }
    private static func instant(_ value: String) -> String {
        if value.hasPrefix("datetime:") { return String(value.dropFirst(9)) }
        if value.hasPrefix("date:") { return String(value.dropFirst(5)) + "T00:00:00Z" }
        return value
    }
    private static func dateValue(_ value: String, allDay: Bool) -> String {
        (allDay ? "date:" + String(value.prefix(10)) : "datetime:" + value)
    }
    private static func dayAfter(_ value: String) -> String {
        guard let date = try? Dates.parse(value) else { return value }
        return Dates.stamp(date.addingTimeInterval(86400))
    }
    private static func dayBefore(_ value: String) -> String {
        guard let date = try? Dates.parse(value) else { return value }
        return Dates.stamp(date.addingTimeInterval(-86400))
    }
    private static func rule(_ row: [String: JSONValue]) -> String {
        guard let frequency = row["recurrence_frequency"]?.text, !frequency.isEmpty else { return "" }
        var parts = ["FREQ=" + frequency, "INTERVAL=" + String(row["recurrence_interval"]?.integer ?? 1)]
        if let count = row["recurrence_count"]?.integer { parts.append("COUNT=" + String(count)) }
        if let until = row["recurrence_until"]?.text, !until.isEmpty {
            parts.append("UNTIL=" + until.replacingOccurrences(of:"-",with:"") + "T235959Z")
        }
        if let weekdays = row["recurrence_weekdays"]?.text,
           let values = try? JSONDecoder().decode([Int].self,from:Data(weekdays.utf8)), !values.isEmpty {
            parts.append("BYDAY=" + values.compactMap { Recurrence.days.indices.contains($0) ? Recurrence.days[$0] : nil }.joined(separator:","))
        }
        return parts.joined(separator:";")
    }
    func validate() throws {
        try Self.identifier(id)
        guard ["note","task","calendar","event"].contains(kind) else { throw CompanionError("Unsupported item kind") }
        let legal: [String: Set<String>] = [
            "note": ["id","title","body","archived","pinned","created_at","updated_at","metadata_json"],
            "task": ["id","title","description","status","due_at","created_at","updated_at","metadata_json","kind","timezone_name","recurrence","recurrence_anchor","paused","last_fired_at","note_id","notification_owner"],
            "calendar": ["id","name","color","visible","sort_order"],
            "event": ["id","calendar_id","title","all_day","start_value","end_value","timezone_name","location","notes","recurrence_frequency","recurrence_interval","recurrence_weekdays","recurrence_count","recurrence_until","ics_uid","created_at","updated_at","description","start_at","end_at","timezone","recurrence"]
        ]
        guard Set(record.keys).isSubset(of:legal[kind] ?? []),
              !record.values.contains(where:{ if case .string(let text) = $0 { return text.contains("\0") || text.utf8.count > 262144 }; return false }) else {
            throw CompanionError("Invalid or oversized record field")
        }
        if kind == "event" {
            guard !text("calendar_id").isEmpty else { throw CompanionError("Choose a calendar before saving") }
            guard try Dates.parse(text("end_at")) > Dates.parse(text("start_at")) else { throw CompanionError("End must follow start") }
            _ = try Recurrence(text("recurrence"))
        }
        if kind == "calendar" {
            guard !text("name").trimmingCharacters(in:.whitespaces).isEmpty,
                  text("color").range(of:"^#[0-9A-Fa-f]{6}$",options:.regularExpression) != nil else {
                throw CompanionError("Calendar needs a name and #RRGGBB colour")
            }
        }
        if kind == "task", !["pending","completed","cancelled","running","failed"].contains(text("status")) { throw CompanionError("Invalid task status") }
        if kind == "task", !text("due_at").isEmpty { _ = try Dates.parse(text("due_at")) }
        if kind == "note" || kind == "task" {
            let data = Data(text("metadata_json").utf8)
            guard let metadata = try JSONSerialization.jsonObject(with:data) as? [String: Any] else { throw CompanionError("Metadata must be an object") }
            try Self.checkMetadata(metadata)
        }
        guard reminders.count <= 1000, exceptions.count <= 1000, activity.count <= 1000 else { throw CompanionError("Too many linked records") }
        guard reminders.allSatisfy({ kind == "event" && $0.owner_id == id && $0.notification_owner == "phone" || kind == "event" && $0.owner_id == id && $0.notification_owner == "desktop" }),
              exceptions.allSatisfy({ kind == "event" && $0.event_id == id }) else { throw CompanionError("Invalid linked record ownership") }
    }
    static func identifier(_ value: String) throws {
        guard value.range(of:"^[A-Za-z0-9_.@-]{1,200}$",options:.regularExpression) != nil else { throw CompanionError("Invalid stable ID") }
    }
    private static func checkMetadata(_ value: Any) throws {
        if let object = value as? [String: Any] {
            let markers = ["password","passwd","secret","token","api_key","apikey","private_key","credential","auth_key"]
            for (key, child) in object {
                let normalized = key.trimmingCharacters(in:.whitespaces).lowercased().replacingOccurrences(of:"-",with:"_").replacingOccurrences(of:" ",with:"_")
                guard !markers.contains(where:normalized.contains) else { throw CompanionError("Credentials cannot be stored in record metadata") }
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
