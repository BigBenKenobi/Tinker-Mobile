// On-device SQLite and transactional offline editing/outbox state.
// AppModel owns this MainActor store. Each edit commits its whole graph and durable
// upload in one transaction. Pulls never erase pending edits, and acknowledgement
// checks operation IDs so edits made during an upload cannot be accidentally removed.
import Foundation
import SQLite3
import Combine

@MainActor final class LocalStore: ObservableObject {
    private var database: OpaquePointer?
    @Published private(set) var records: [RecordVersion] = []
    @Published private(set) var conflicts: [Conflict] = []
    @Published private(set) var pendingCount = 0
    private let encoder: JSONEncoder = { let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]; return e }()
    private let decoder = JSONDecoder()
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(path: URL) throws {
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard sqlite3_open(path.path, &database) == SQLITE_OK else { throw CompanionError("Cannot open local database") }
        do {
            _ = try rows("PRAGMA journal_mode=WAL"); try execute("PRAGMA synchronous=FULL"); try execute("PRAGMA busy_timeout=5000")
            let schema = Int(try rows("PRAGMA user_version").first?[0] ?? "0") ?? 0
            guard schema <= 1 else { throw CompanionError("This database needs a newer Tinker build") }
            if schema == 0 {
                try transaction {
                    try execute("CREATE TABLE records(kind TEXT NOT NULL,id TEXT NOT NULL,revision INTEGER NOT NULL,value TEXT,PRIMARY KEY(kind,id))")
                    try execute("CREATE TABLE outbox(kind TEXT NOT NULL,id TEXT NOT NULL,op_id TEXT NOT NULL,mutation TEXT NOT NULL,PRIMARY KEY(kind,id))")
                    try execute("CREATE TABLE conflicts(id TEXT PRIMARY KEY,value TEXT NOT NULL)")
                    try execute("CREATE TABLE state(key TEXT PRIMARY KEY,value TEXT NOT NULL)")
                    try execute("PRAGMA user_version=1")
                }
            }
            let integrity = try rows("PRAGMA quick_check").first?[0] ?? ""
            guard integrity == "ok" else { throw CompanionError("Local database integrity check failed; preserve the file for recovery") }
            try refresh()
            // iOS file protection applies to the database and its SQLite sidecars.
            for suffix in ["", "-wal", "-shm"] {
                let p = path.path + suffix
                if FileManager.default.fileExists(atPath: p) { try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: p) }
            }
        } catch { sqlite3_close(database); database = nil; throw error }
    }
    deinit { sqlite3_close(database) }

    private func statement(_ sql: String, _ values: [String?]) throws -> OpaquePointer {
        var result: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &result, nil) == SQLITE_OK, let result else { throw failure() }
        for (index, value) in values.enumerated() {
            let status = value.map { sqlite3_bind_text(result, Int32(index + 1), $0, -1, transient) } ?? sqlite3_bind_null(result, Int32(index + 1))
            if status != SQLITE_OK { sqlite3_finalize(result); throw failure() }
        }
        return result
    }
    private func failure() -> CompanionError { CompanionError(String(cString: sqlite3_errmsg(database))) }
    private func execute(_ sql: String, _ values: [String?] = []) throws {
        let s = try statement(sql, values); defer { sqlite3_finalize(s) }
        guard sqlite3_step(s) == SQLITE_DONE else { throw failure() }
    }
    private func rows(_ sql: String, _ values: [String?] = []) throws -> [[String?]] {
        let s = try statement(sql, values); defer { sqlite3_finalize(s) }
        var result: [[String?]] = []
        while true {
            let status = sqlite3_step(s)
            if status == SQLITE_DONE { return result }
            guard status == SQLITE_ROW else { throw failure() }
            result.append((0..<sqlite3_column_count(s)).map { i in
                guard let bytes = sqlite3_column_text(s, i) else { return nil }; return String(cString: bytes)
            })
        }
    }
    private func transaction(_ operation: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE")
        do { try operation(); try execute("COMMIT") }
        catch { try? execute("ROLLBACK"); throw error }
    }
    private func json<T: Encodable>(_ value: T) throws -> String { String(decoding: try encoder.encode(value), as: UTF8.self) }
    private func decode<T: Decodable>(_ text: String, as: T.Type) throws -> T { try decoder.decode(T.self, from: Data(text.utf8)) }
    private func refresh() throws {
        records = try rows("SELECT kind,id,revision,value FROM records ORDER BY kind,id").map { r in
            RecordVersion(kind: r[0]!, id: r[1]!, revision: Int(r[2]!)!, value: try r[3].map { try decode($0, as: Graph.self) })
        }
        conflicts = try rows("SELECT value FROM conflicts ORDER BY id").map { try decode($0[0]!, as: Conflict.self) }.filter { !$0.resolved }
        pendingCount = Int(try rows("SELECT COUNT(*) FROM outbox")[0][0]!)!
    }
    func state(_ key: String) throws -> String? { try rows("SELECT value FROM state WHERE key=?", [key]).first?.first ?? nil }
    private func setState(_ key: String, _ value: String) throws {
        try execute("INSERT INTO state VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value", [key, value])
    }
    var cursor: Int? { get throws { try state("cursor").flatMap(Int.init) } }
    func uploads() throws -> [Mutation] { try rows("SELECT mutation FROM outbox ORDER BY kind,id LIMIT 100").map { try decode($0[0]!, as: Mutation.self) } }

    func edit(_ value: Graph?, kind: String, id: String, baseRevision: Int? = nil, resolveID: String? = nil) throws {
        // A dialog supplies its observed revision. A newer local draft for the same
        // root is preserved as a conflict instead of overwritten by an older dialog.
        try Graph.identifier(id); try value?.validate()
        guard ["note", "task", "event"].contains(kind), value == nil || (value?.id == id && value?.kind == kind) else { throw CompanionError("Item ownership mismatch") }
        try transaction {
            let old = try rows("SELECT revision FROM records WHERE kind=? AND id=?", [kind,id]).first
            let revision = Int(old?[0] ?? "0") ?? 0
            let existing = try rows("SELECT mutation FROM outbox WHERE kind=? AND id=?", [kind,id]).first
            let pending = try existing.map { try decode($0[0]!, as: Mutation.self) }
            if let observed = baseRevision, observed != revision, pending == nil { throw CompanionError("This item changed while you were editing. Reopen it; your draft remains here.") }
            let mutation = Mutation(op_id: Dates.id("operation"), kind: kind, id: id, base_revision: pending?.base_revision ?? baseRevision ?? revision, value: value, resolve_id: resolveID ?? pending?.resolve_id)
            try execute("INSERT INTO records VALUES(?,?,?,?) ON CONFLICT(kind,id) DO UPDATE SET value=excluded.value", [kind,id,String(revision),try value.map(json)])
            try execute("INSERT INTO outbox VALUES(?,?,?,?) ON CONFLICT(kind,id) DO UPDATE SET op_id=excluded.op_id,mutation=excluded.mutation", [kind,id,mutation.op_id,try json(mutation)])
        }
        try refresh()
    }
    func importEvents(_ graphs: [Graph]) throws {
        guard graphs.count <= 100 else { throw CompanionError("Import at most 100 events per file") }
        for graph in graphs { try graph.validate() }
        try transaction {
            for g in graphs {
                let old = try rows("SELECT revision FROM records WHERE kind='event' AND id=?", [g.id]).first
                let pendingRow = try rows("SELECT mutation FROM outbox WHERE kind='event' AND id=?", [g.id]).first
                let pending = try pendingRow.map { try decode($0[0]!, as: Mutation.self) }
                let revision = Int(old?[0] ?? "0") ?? 0
                let mutation = Mutation(op_id: Dates.id("operation"),kind:"event",id:g.id,base_revision:pending?.base_revision ?? revision,value:g,resolve_id:pending?.resolve_id)
                try execute("INSERT INTO records VALUES('event',?,?,?) ON CONFLICT(kind,id) DO UPDATE SET value=excluded.value",[g.id,String(revision),try json(g)])
                try execute("INSERT INTO outbox VALUES('event',?,?,?) ON CONFLICT(kind,id) DO UPDATE SET op_id=excluded.op_id,mutation=excluded.mutation",[g.id,mutation.op_id,try json(mutation)])
            }
        }
        try refresh()
    }
    private func apply(_ row: RecordVersion) throws {
        guard ["note","task","event"].contains(row.kind), row.revision >= 0 else { throw CompanionError("Unsupported record domain/revision") }
        try row.value?.validate()
        guard row.value == nil || (row.value?.id == row.id && row.value?.kind == row.kind) else { throw CompanionError("Invalid sync ownership") }
        let pending = try rows("SELECT op_id FROM outbox WHERE kind=? AND id=?", [row.kind,row.id])
        if pending.isEmpty {
            try execute("INSERT INTO records VALUES(?,?,?,?) ON CONFLICT(kind,id) DO UPDATE SET revision=excluded.revision,value=excluded.value",[row.kind,row.id,String(row.revision),try row.value.map(json)])
        }
    }
    private func apply(_ conflict: Conflict) throws {
        try conflict.current?.validate(); try conflict.incoming?.validate()
        try execute("INSERT INTO conflicts VALUES(?,?) ON CONFLICT(id) DO UPDATE SET value=excluded.value",[conflict.id,try json(conflict)])
    }
    func apply(_ snapshot: Snapshot) throws {
        guard snapshot.version == 1, snapshot.cursor >= 0 else { throw CompanionError("Unsupported sync version") }
        try transaction {
            if let previous = try state("server_id"), previous != snapshot.server_id { throw CompanionError("Pairing belongs to a different desktop. Keep local data and reconnect explicitly.") }
            // A full snapshot replaces only clean records. This also removes ghosts
            // after a desktop restore while retaining every local offline edit.
            try execute("DELETE FROM records WHERE NOT EXISTS(SELECT 1 FROM outbox WHERE outbox.kind=records.kind AND outbox.id=records.id)")
            for row in snapshot.records { try apply(row) }
            try execute("DELETE FROM conflicts")
            for conflict in snapshot.conflicts { try apply(conflict) }
            try setState("server_id",snapshot.server_id); try setState("cursor",String(snapshot.cursor))
        }
        try refresh()
    }
    func apply(_ page: Changes) throws {
        guard page.version == 1, try state("server_id") == page.server_id else { throw CompanionError("Sync identity/version mismatch") }
        try transaction {
            var previous = try cursor ?? 0
            for change in page.changes {
                guard change.seq > previous else { throw CompanionError("Changes are not ordered") }
                previous = change.seq
                if let conflict = change.conflict { try apply(conflict) }
                else { try apply(RecordVersion(kind:change.kind,id:change.id,revision:change.seq,value:change.graph)) }
            }
            guard page.cursor == previous else { throw CompanionError("Invalid sync cursor") }
            try setState("cursor",String(page.cursor))
        }
        try refresh()
    }
    func acknowledge(_ response: UploadResponse, sent: [Mutation]) throws {
        guard response.version == 1, try state("server_id") == response.server_id, response.results.count == sent.count else { throw CompanionError("Invalid upload acknowledgement") }
        try transaction {
            for (request,result) in zip(sent,response.results) {
                guard result.op_id == request.op_id, ["applied","conflict"].contains(result.status), result.revision >= 0 else { throw CompanionError("Mismatched upload operation") }
                let queued = try rows("SELECT mutation FROM outbox WHERE kind=? AND id=?",[request.kind,request.id]).first
                let newer = try queued.map { try decode($0[0]!, as: Mutation.self) }
                if newer?.op_id == request.op_id {
                    try execute("DELETE FROM outbox WHERE op_id=?",[request.op_id])
                    let value = result.status == "conflict" ? result.conflict?.current : request.value
                    try execute("UPDATE records SET revision=?,value=? WHERE kind=? AND id=?",[String(result.revision),try value.map(json),request.kind,request.id])
                } else if var next = newer, result.status == "applied" {
                    // Only this acknowledged operation advanced our local base.
                    // The newer graph remains queued and retains its own operation ID.
                    next.base_revision = result.revision
                    try execute("UPDATE outbox SET mutation=? WHERE op_id=?",[try json(next),next.op_id])
                    try execute("UPDATE records SET revision=? WHERE kind=? AND id=?",[String(result.revision),request.kind,request.id])
                }
                if let conflict = result.conflict { try apply(conflict) }
            }
        }
        try refresh()
    }
    func resolve(_ conflict: Conflict, useIncoming: Bool) throws {
        // Resolve exactly the versions the user inspected. A newer desktop edit
        // must conflict again rather than be overwritten using its unseen revision.
        let value = useIncoming ? conflict.incoming : conflict.current
        try transaction {
            guard try rows("SELECT op_id FROM outbox WHERE kind=? AND id=?",[conflict.kind,conflict.record_id]).isEmpty else {
                throw CompanionError("Sync this item's pending edits before resolving its conflict. All versions remain saved.")
            }
            let revision = records.first { $0.kind == conflict.kind && $0.id == conflict.record_id }?.revision ?? conflict.current_revision
            let mutation = Mutation(op_id:Dates.id("operation"),kind:conflict.kind,id:conflict.record_id,base_revision:conflict.current_revision,value:value,resolve_id:conflict.id)
            try execute("INSERT INTO records VALUES(?,?,?,?) ON CONFLICT(kind,id) DO UPDATE SET value=excluded.value",[conflict.kind,conflict.record_id,String(revision),try value.map(json)])
            try execute("INSERT INTO outbox VALUES(?,?,?,?) ON CONFLICT(kind,id) DO UPDATE SET op_id=excluded.op_id,mutation=excluded.mutation",[conflict.kind,conflict.record_id,mutation.op_id,try json(mutation)])
        }
        try refresh()
    }
    func resetSyncCursor() throws {
        // Unpairing retains all domain data and pending edits. New pairing cannot
        // silently transfer them to a different desktop identity.
        try execute("DELETE FROM state WHERE key='cursor'")
    }
}
