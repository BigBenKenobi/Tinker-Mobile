// Xcode-only acceptance tests. These tests are checked in but remain unexecuted
// until a Mac/Simulator is available; Linux syntax parsing is not an iOS build.
import XCTest
@testable import TinkerCompanion

@MainActor final class CompanionTests: XCTestCase {
    private func location() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("test.sqlite3") }
    private func snapshot(_ records: [RecordVersion] = [], cursor: Int = 0) -> Snapshot {
        Snapshot(version:2,server_id:"desktop_fixture",cursor:cursor,records:records,conflicts:[])
    }
    func testTransportAcceptsOnlyMatchingProtocolTwoDesktop() throws {
        let valid = Data(#"{"version":2,"server_id":"desktop_fixture"}"#.utf8)
        XCTAssertNoThrow(try Transport.validateEnvelope(valid,serverID:"desktop_fixture"))
        XCTAssertThrowsError(try Transport.validateEnvelope(valid,serverID:"another_desktop"))
        let old = Data(#"{"version":1,"server_id":"desktop_fixture"}"#.utf8)
        XCTAssertThrowsError(try Transport.validateEnvelope(old,serverID:"desktop_fixture"))
    }
    func testOfflineEditsAndStableIDsSurviveReopen() throws {
        let path = location(); let graph = Graph.new("note")
        do { let store = try LocalStore(path:path); try store.edit(graph,kind:"note",id:graph.id); XCTAssertEqual(store.pendingCount,1) }
        let reopened = try LocalStore(path:path)
        XCTAssertEqual(reopened.records.first?.value?.id,graph.id)
        XCTAssertEqual(try reopened.uploads().first?.base_revision,0)
    }
    func testSnapshotCannotErasePendingOfflineEdit() throws {
        let store = try LocalStore(path:location()); var graph = Graph.new("note"); graph.set("title","Offline")
        try store.edit(graph,kind:"note",id:graph.id)
        var desktop = graph; desktop.set("title","Desktop")
        try store.apply(snapshot([RecordVersion(kind:"note",id:graph.id,revision:4,value:desktop)],cursor:4))
        XCTAssertEqual(store.records.first?.value?.title,"Offline")
        XCTAssertEqual(try store.uploads().first?.base_revision,0)
        XCTAssertEqual(try store.cursor,4)
    }
    func testAcknowledgementPreservesEditMadeDuringUpload() throws {
        let store = try LocalStore(path:location()); try store.apply(snapshot())
        var graph = Graph.new("task"); graph.set("title","First")
        try store.edit(graph,kind:"task",id:graph.id); let sent = try store.uploads()
        graph.set("title","Newer"); try store.edit(graph,kind:"task",id:graph.id)
        try store.acknowledge(UploadResponse(version:2,server_id:"desktop_fixture",results:[UploadResult(op_id:sent[0].op_id,status:"applied",revision:1,conflict:nil)]),sent:sent)
        XCTAssertEqual(store.pendingCount,1); XCTAssertEqual(store.records.first?.value?.title,"Newer")
        XCTAssertEqual(try store.uploads().first?.base_revision,1)
    }
    func testDeletionIsAnOfflineTombstone() throws {
        let store = try LocalStore(path:location()); let graph = Graph.new("note")
        try store.apply(snapshot([RecordVersion(kind:"note",id:graph.id,revision:2,value:graph)],cursor:2))
        try store.edit(nil,kind:"note",id:graph.id,baseRevision:2)
        XCTAssertNil(store.records.first?.value); XCTAssertNil(try store.uploads().first?.value)
        XCTAssertEqual(try store.uploads().first?.base_revision,2)
    }
    func testConflictKeepsBothVersionsAndResolutionUsesInspectedRevision() throws {
        let store = try LocalStore(path:location()); var current = Graph.new("note"); current.set("title","Current")
        var incoming = current; incoming.set("title","Offline")
        let conflict = Conflict(id:"conflict_fixture",kind:"note",record_id:current.id,current:current,incoming:incoming,current_revision:2,resolved:false)
        try store.apply(Snapshot(version:2,server_id:"desktop_fixture",cursor:4,records:[RecordVersion(kind:"note",id:current.id,revision:4,value:current)],conflicts:[conflict]))
        try store.resolve(conflict,useIncoming:true)
        XCTAssertEqual(try store.uploads().first?.base_revision,2)
        XCTAssertEqual(store.conflicts.count,1)
        XCTAssertEqual(store.conflicts[0].current?.title,"Current"); XCTAssertEqual(store.conflicts[0].incoming?.title,"Offline")
    }
    func testInvalidImportIsAtomic() throws {
        let store = try LocalStore(path:location()); let calendar = Graph.new("calendar")
        try store.apply(snapshot([RecordVersion(kind:"calendar",id:calendar.id,revision:1,value:calendar)],cursor:1))
        var good = Graph.new("event"); good.set("calendar_id",calendar.id)
        var bad = Graph.new("event"); bad.set("calendar_id",calendar.id); bad.set("end_at",bad.text("start_at"))
        XCTAssertThrowsError(try store.importEvents([good,bad])); XCTAssertEqual(store.records.count,1); XCTAssertEqual(store.pendingCount,0)
    }
    func testStrictSharedFieldsAndCredentialMetadata() throws {
        var graph = Graph.new("note"); graph.set("metadata_json","{\"access_token\":\"secret\"}")
        XCTAssertThrowsError(try graph.validate())
        graph.set("metadata_json","{}"); graph.record["unsupported"] = .string("oops")
        XCTAssertThrowsError(try graph.validate())
    }
    func testRecurrenceAcrossDSTAndMonthEnd() throws {
        let start = try Dates.parse("2026-09-25T21:00:00Z")
        let days = try Recurrence("FREQ=DAILY;COUNT=4").occurrences(start:start,timezone:"Pacific/Auckland",lower:Dates.parse("2026-09-25T00:00:00Z"),upper:Dates.parse("2026-09-30T00:00:00Z"))
        XCTAssertEqual(days.map(Dates.stamp),["2026-09-25T21:00:00Z","2026-09-26T20:00:00Z","2026-09-27T20:00:00Z","2026-09-28T20:00:00Z"])
        let monthly = try Recurrence("FREQ=MONTHLY;COUNT=3").occurrences(start:Dates.parse("2026-01-31T09:00:00Z"),timezone:"UTC",lower:Dates.parse("2026-01-01T00:00:00Z"),upper:Dates.parse("2026-07-01T00:00:00Z"))
        XCTAssertEqual(monthly.map(Dates.stamp),["2026-01-31T09:00:00Z","2026-03-31T09:00:00Z","2026-05-31T09:00:00Z"])
        XCTAssertThrowsError(try Recurrence("FREQ=HOURLY"))
    }
    func testICSUnicodeRecurrenceAndExceptionsRoundtrip() throws {
        var graph = Graph.new("event"); graph.set("calendar_id","calendar_fixture"); graph.set("title",String(repeating:"🎉 café ",count:30)); graph.set("description","lines\ncomma, semicolon; slash\\")
        graph.set("start_at","2026-10-01T09:00:00Z"); graph.set("end_at","2026-10-01T10:00:00Z"); graph.set("timezone","Pacific/Auckland"); graph.set("recurrence","FREQ=DAILY;COUNT=5")
        graph.reminders = [Reminder(id:"reminder_fixture",owner_kind:"event",owner_id:graph.id,fire_at:"2026-10-01T08:45:00Z",message:"Remember")]
        graph.exceptions = [EventException(id:"exception_fixture",event_id:graph.id,occurrence_at:"2026-10-02T09:00:00Z",cancelled:true,start_at:nil,end_at:nil,title:nil)]
        let source = try ICS.export([graph]); XCTAssertTrue(source.components(separatedBy:"\r\n").allSatisfy { $0.utf8.count <= 75 })
        let restored = try XCTUnwrap(ICS.parse(source).first)
        XCTAssertEqual(restored.id,graph.id); XCTAssertEqual(restored.title,graph.title); XCTAssertEqual(restored.text("description"),graph.text("description"))
        XCTAssertEqual(restored.reminders.first?.fire_at,graph.reminders.first?.fire_at); XCTAssertTrue(restored.exceptions[0].cancelled)
    }
    func testPublicEndpointsAndExpiredQRFailBeforeNetwork() throws {
        XCTAssertThrowsError(try LocalEndpoint.validate("https://8.8.8.8:443"))
        XCTAssertThrowsError(try LocalEndpoint.validate("https://100.66.93.44:443"))
        XCTAssertThrowsError(try LocalEndpoint.validate("https://user:pass@192.168.1.2:443"))
        XCTAssertNoThrow(try LocalEndpoint.validate("https://192.168.1.2:1234"))
        let invitation = Invitation(version:2,server_id:"desktop_fixture",endpoint:"https://192.168.1.2:1234",certificate_sha256:String(repeating:"a",count:64),code:String(repeating:"x",count:43),expires_at:0)
        XCTAssertThrowsError(try invitation.validate())
    }
    func testSharedDesktopSnapshotFixture() throws {
        let url = try XCTUnwrap(Bundle(for:Self.self).url(forResource:"snapshot-v2",withExtension:"json"))
        let value = try JSONDecoder().decode(Snapshot.self,from:Data(contentsOf:url))
        XCTAssertEqual(value.version,2); XCTAssertEqual(value.records.count,4)
        for row in value.records { try row.value?.validate() }
        let store = try LocalStore(path:location()); try store.apply(value); XCTAssertEqual(store.records.count,4)
    }
    func testNativeGraphRoundTripKeepsOwnershipAndExceptions() throws {
        let url = try XCTUnwrap(Bundle(for:Self.self).url(forResource:"snapshot-v2",withExtension:"json"))
        let fixture = try JSONDecoder().decode(Snapshot.self,from:Data(contentsOf:url))
        for version in fixture.records {
            let graph = try XCTUnwrap(version.value)
            let encoded = try JSONEncoder().encode(graph)
            let wire = try XCTUnwrap(JSONSerialization.jsonObject(with:encoded) as? [String:Any])
            let record = try XCTUnwrap(wire["record"] as? [String:Any])
            XCTAssertEqual(record["id"] as? String,version.id)
            if version.kind == "note" {
                let linked = try XCTUnwrap(wire["linked_task"] as? [String:Any])
                XCTAssertEqual(linked["note_id"] as? String,version.id)
                XCTAssertEqual((wire["activity"] as? [[String:Any]])?.count,1)
            }
            if version.kind == "event" {
                XCTAssertNil(record["start_at"])
                XCTAssertEqual(record["recurrence_frequency"] as? String,"DAILY")
                let exceptions = try XCTUnwrap(wire["exceptions"] as? [[String:Any]])
                XCTAssertEqual(exceptions.first?["kind"] as? String,"cancelled")
                XCTAssertEqual(exceptions.first?["event_id"] as? String,version.id)
                let alarms = try XCTUnwrap(wire["reminders"] as? [[String:Any]])
                XCTAssertEqual(alarms.first?["event_id"] as? String,version.id)
            }
        }
    }
}
