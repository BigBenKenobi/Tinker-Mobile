// Recovery, invalid-envelope and quiet-work regressions over isolated data.
// Timing samples describe Simulator workloads only; they do not assert physical
// battery/latency acceptance. No timing threshold makes correctness machine-dependent.
import XCTest
import Combine
@testable import TinkerCompanion

@MainActor final class MaintenanceTests: XCTestCase {
    private func store() throws -> LocalStore {
        try LocalStore(path:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("test.sqlite3"))
    }
    private func snapshot(_ graphs: [Graph]) -> Snapshot {
        Snapshot(version:2,server_id:"desktop_fixture",cursor:6,records:graphs.map { RecordVersion(kind:$0.kind,id:$0.id,revision:6,value:$0) },conflicts:[])
    }
    func testRecoveryBackupRetainsPendingDataAndLocalTokens() throws {
        let source = try store(); let graph = Graph.new("note")
        try source.apply(snapshot([])); try source.edit(graph,kind:graph.kind,id:graph.id)
        let copy = try source.exportRecovery()
        let recovered = try LocalStore(path:copy)
        XCTAssertEqual(recovered.records,source.records)
        XCTAssertEqual(recovered.pendingCount,1)
        XCTAssertEqual(try recovered.uploads().first?.op_id,try source.uploads().first?.op_id)
        XCTAssertEqual(try recovered.cursor,try source.cursor)
        try FileManager.default.removeItem(at:copy.deletingLastPathComponent())
    }
    func testIncompleteAcknowledgementKeepsOutboxAndGraph() throws {
        let store = try store(); let graph = Graph.new("note")
        try store.apply(snapshot([])); try store.edit(graph,kind:graph.kind,id:graph.id)
        let sent = try store.uploads()
        let response = UploadResponse(version:2,server_id:"desktop_fixture",results:[UploadResult(op_id:sent[0].op_id,status:"conflict",revision:7,conflict:nil)])
        XCTAssertThrowsError(try store.acknowledge(response,sent:sent))
        XCTAssertEqual(store.records.first?.value,graph)
        XCTAssertEqual(try store.uploads().first?.op_id,sent[0].op_id)
        XCTAssertEqual(try store.cursor,6)
    }
    func testInvalidPageRollsBackAppliedRecordsAndCursor() throws {
        let store = try store(); var graph = Graph.new("note"); try store.apply(snapshot([graph]))
        let before = store.records
        graph.set("title","Must roll back")
        let value = try JSONSerialization.jsonObject(with:JSONEncoder().encode(graph))
        let change: [String:Any] = ["seq":7,"kind":"note","id":graph.id,"value":value]
        let data = try JSONSerialization.data(withJSONObject:["version":2,"server_id":"desktop_fixture","cursor":7,"has_more":false,"changes":[change,change]])
        XCTAssertThrowsError(try store.apply(JSONDecoder().decode(Changes.self,from:data)))
        XCTAssertEqual(store.records,before); XCTAssertEqual(try store.cursor,6)
    }
    func testUnchangedNotificationsNeedNoReplacement() {
        let now = Date(timeIntervalSince1970:1791446400)
        let first = PlannedNotification(identifier:"one",date:now,title:"Title",message:"Message")
        let changed = PlannedNotification(identifier:"one",date:now,title:"Updated title",message:"Message")
        XCTAssertTrue(Notifications.changedRequests([first],scheduled:[first]).isEmpty)
        XCTAssertEqual(Notifications.changedRequests([changed],scheduled:[first]),[changed])
        XCTAssertEqual(Notifications.changedRequests([first],scheduled:[]),[first])
        let empty = PlannedNotification(identifier:"two",date:now,title:"",message:"")
        let displayed = PlannedNotification(identifier:"two",date:now,title:"Tinker reminder",message:"")
        XCTAssertTrue(Notifications.changedRequests([empty],scheduled:[displayed]).isEmpty)
    }
    func testLargeStoreEmptyPullPublishesNothing() throws {
        let note = Graph.new("note")
        for count in [1000,10000] {
            let store = try store()
            let graphs = (0..<count).map { index -> Graph in var graph = note; graph.set("id","note_\(index)"); return graph }
            try store.apply(snapshot(graphs))
            let generation = store.recordGeneration
            var publications = 0
            let subscription = store.objectWillChange.sink { publications += 1 }
            let start = Date()
            for _ in 0..<100 { try store.apply(Changes(version:2,server_id:"desktop_fixture",cursor:6,has_more:false,changes:[])) }
            print("TINKER_BENCHMARK empty_pull records=\(count) cycles=100 seconds=\(Date().timeIntervalSince(start)) publications=\(publications)")
            XCTAssertEqual(publications,0); XCTAssertEqual(store.recordGeneration,generation)
            XCTAssertEqual(store.records.count,count); XCTAssertEqual(try store.cursor,6)
            XCTAssertThrowsError(try store.apply(Changes(version:2,server_id:"desktop_fixture",cursor:7,has_more:false,changes:[])))
            subscription.cancel()
        }
    }
    func testCalendarCacheMatchesColdProjectionAndInvalidates() throws {
        let lower = try Dates.parse("2026-10-01T00:00:00Z"), upper = try Dates.parse("2026-11-01T00:00:00Z")
        var event = Graph.new("event"); event.set("calendar_id","calendar_fixture")
        event.set("start_at","2020-01-01T09:00:00Z"); event.set("end_at","2020-01-01T10:00:00Z")
        event.set("timezone","Pacific/Auckland"); event.set("recurrence","FREQ=MONTHLY")
        let note = Graph.new("note")
        for count in [1000,10000] {
            var records = (1..<count).map { RecordVersion(kind:"note",id:"note_\($0)",revision:1,value:note) }
            records.append(RecordVersion(kind:"event",id:event.id,revision:1,value:event))
            let cache = CalendarOccurrenceCache()
            let start = Date()
            let cold = cache.projection(records:records,generation:1,calendars:["calendar_fixture"],lower:lower,upper:upper,timezone:"Pacific/Auckland")
            let coldSeconds = Date().timeIntervalSince(start)
            let repeated = Date()
            for _ in 0..<100 {
                let result = cache.projection(records:records,generation:1,calendars:["calendar_fixture"],lower:lower,upper:upper,timezone:"Pacific/Auckland")
                XCTAssertEqual(result.occurrences.map(\.id),cold.occurrences.map(\.id)); XCTAssertTrue(result.errors.isEmpty)
            }
            print("TINKER_BENCHMARK calendar records=\(count) cold_seconds=\(coldSeconds) cached_100_seconds=\(Date().timeIntervalSince(repeated))")
            XCTAssertFalse(cold.occurrences.isEmpty)
            XCTAssertTrue(cache.projection(records:records,generation:1,calendars:[],lower:lower,upper:upper,timezone:"Pacific/Auckland").occurrences.isEmpty)
            records.removeLast()
            XCTAssertTrue(cache.projection(records:records,generation:2,calendars:["calendar_fixture"],lower:lower,upper:upper,timezone:"Pacific/Auckland").occurrences.isEmpty)
        }
    }
}
