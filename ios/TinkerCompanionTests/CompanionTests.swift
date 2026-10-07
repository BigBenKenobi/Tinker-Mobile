// Xcode-only acceptance tests. These tests are checked in but remain unexecuted
// until a Mac/Simulator is available; Linux syntax parsing is not an iOS build.
import XCTest
@testable import TinkerCompanion

@MainActor final class CompanionTests: XCTestCase {
    private func location() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("test.sqlite3") }
    private func snapshot(_ records: [RecordVersion] = [], cursor: Int = 0) -> Snapshot {
        Snapshot(version:2,server_id:"desktop_fixture",cursor:cursor,records:records,conflicts:[])
    }
    private func task(_ title: String, due: String, recurrence: String = "none", anchor: String? = nil) -> Graph {
        var graph = Graph.new("task"); graph.set("title",title); graph.set("due_at",due)
        graph.set("kind","reminder"); graph.set("timezone_name","Pacific/Auckland"); graph.set("recurrence",recurrence)
        graph.record["recurrence_anchor"] = anchor.map(JSONValue.string) ?? .null
        return graph
    }
    private func allDayWire() throws -> Data {
        let replacement: [String:Any] = ["id":"event_all_day","calendar_id":"calendar_fixture","title":"Moved",
            "all_day":true,"start":"date:2026-10-04","end":"date:2026-10-04","timezone_name":"Pacific/Auckland",
            "location":"","notes":"","ics_uid":"all_day@example","created_at":"2026-09-01T00:00:00Z","updated_at":"2026-09-01T00:00:00Z"]
        let replacementData = try JSONSerialization.data(withJSONObject:replacement,options:[.sortedKeys])
        let record: [String:Any] = ["id":"event_all_day","calendar_id":"calendar_fixture","title":"DST day","all_day":true,
            "start_value":"date:2026-09-27","end_value":"date:2026-09-27","timezone_name":"Pacific/Auckland",
            "location":"","notes":"","recurrence_frequency":NSNull(),"recurrence_interval":NSNull(),
            "recurrence_weekdays":NSNull(),"recurrence_count":NSNull(),"recurrence_until":NSNull(),
            "ics_uid":"all_day@example","created_at":"2026-09-01T00:00:00Z","updated_at":"2026-09-01T00:00:00Z"]
        let exceptions: [[String:Any]] = [
            ["event_id":"event_all_day","original_start":"date:2026-09-27","kind":"cancelled","replacement_json":NSNull()],
            ["event_id":"event_all_day","original_start":"date:2026-10-04","kind":"override","replacement_json":String(decoding:replacementData,as:UTF8.self)]
        ]
        return try JSONSerialization.data(withJSONObject:["kind":"event","record":record,"linked_task":NSNull(),"activity":[],"exceptions":exceptions,"reminders":[]])
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
        graph.set("title","Newer"); try store.edit(graph,kind:"task",id:graph.id,expected:try XCTUnwrap(store.records.first).editToken)
        try store.acknowledge(UploadResponse(version:2,server_id:"desktop_fixture",results:[UploadResult(op_id:sent[0].op_id,status:"applied",revision:1,conflict:nil)]),sent:sent)
        XCTAssertEqual(store.pendingCount,1); XCTAssertEqual(store.records.first?.value?.title,"Newer")
        XCTAssertEqual(try store.uploads().first?.base_revision,1)
    }
    func testDeletionIsAnOfflineTombstone() throws {
        let store = try LocalStore(path:location()); let graph = Graph.new("note")
        try store.apply(snapshot([RecordVersion(kind:"note",id:graph.id,revision:2,value:graph)],cursor:2))
        try store.edit(nil,kind:"note",id:graph.id,expected:try XCTUnwrap(store.records.first).editToken)
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
        XCTAssertThrowsError(try store.previewEvents([good,bad],targetCalendarID:calendar.id)); XCTAssertEqual(store.records.count,1); XCTAssertEqual(store.pendingCount,0)
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
    func testAllDayNativeDatesAndExceptionsRoundTripInEventTimezone() throws {
        let graph = try JSONDecoder().decode(Graph.self,from:allDayWire())
        XCTAssertEqual(graph.text("start_at"),"2026-09-26T12:00:00Z")
        XCTAssertEqual(graph.text("end_at"),"2026-09-27T11:00:00Z")
        XCTAssertEqual(graph.exceptions[0].occurrence_at,"2026-09-26T12:00:00Z")
        XCTAssertEqual(graph.exceptions[1].start_at,"2026-10-03T11:00:00Z")
        XCTAssertEqual(graph.exceptions[1].end_at,"2026-10-04T11:00:00Z")
        let wire = try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(graph)) as? [String:Any])
        let record = try XCTUnwrap(wire["record"] as? [String:Any])
        XCTAssertEqual(record["start_value"] as? String,"date:2026-09-27")
        XCTAssertEqual(record["end_value"] as? String,"date:2026-09-27")
        let exceptions = try XCTUnwrap(wire["exceptions"] as? [[String:Any]])
        XCTAssertEqual(exceptions[0]["original_start"] as? String,"date:2026-09-27")
        XCTAssertEqual(exceptions[1]["original_start"] as? String,"date:2026-10-04")
        let replacement = try XCTUnwrap(exceptions[1]["replacement_json"] as? String)
        let replacementObject = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(replacement.utf8)) as? [String:Any])
        XCTAssertEqual(replacementObject["start"] as? String,"date:2026-10-04")
        XCTAssertEqual(replacementObject["end"] as? String,"date:2026-10-04")
    }
    func testNotificationPlannerSkipsIneligibleTasksAndFindsOldRecurrences() throws {
        let now = try Dates.parse("2026-10-01T00:00:00Z"), due = "2026-10-01T01:00:00Z"
        var valid = task("Valid",due:due)
        var paused = task("Paused",due:due); paused.record["paused"] = .bool(true)
        var completed = task("Completed",due:due); completed.set("status","completed")
        var running = task("Running",due:due); running.set("status","running")
        var desktop = task("Desktop",due:due); desktop.set("notification_owner","desktop")
        var todo = task("Todo",due:due); todo.set("kind","todo")
        let rows = [valid,paused,completed,running,desktop,todo].map { RecordVersion(kind:"task",id:$0.id,revision:0,value:$0) }
        XCTAssertEqual(try NotificationPlanner.plan(rows,now:now).map(\.title),["Valid"])

        valid = task("Old daily",due:"2026-06-01T21:00:00Z",recurrence:"daily",anchor:"2026-06-01T21:00:00Z")
        let old = try NotificationPlanner.plan([RecordVersion(kind:"task",id:valid.id,revision:0,value:valid)],now:now)
        XCTAssertFalse(old.isEmpty); XCTAssertTrue(old.allSatisfy { $0.date > now })
        XCTAssertEqual(Dates.stamp(old[0].date),"2026-10-01T20:00:00Z")
    }
    func testNotificationPlannerPreservesDSTAndMonthEndAnchorsAndGlobalLimit() throws {
        let dstNow = try Dates.parse("2026-09-20T12:00:00Z")
        let weekly = task("Weekly",due:"2026-09-19T14:30:00Z",recurrence:"weekly",anchor:"2026-09-19T14:30:00Z")
        let dst = try NotificationPlanner.plan([RecordVersion(kind:"task",id:weekly.id,revision:0,value:weekly)],now:dstNow)
        var calendar = Calendar(identifier:.gregorian); calendar.timeZone = TimeZone(identifier:"Pacific/Auckland")!
        XCTAssertEqual(dst.prefix(2).map { calendar.component(.hour,from:$0.date) },[3,2])

        let marchNow = try Dates.parse("2026-03-01T00:00:00Z")
        let monthly = task("Monthly",due:"2026-01-30T20:00:00Z",recurrence:"monthly",anchor:"2026-01-30T20:00:00Z")
        let month = try NotificationPlanner.plan([RecordVersion(kind:"task",id:monthly.id,revision:0,value:monthly)],now:marchNow)
        XCTAssertEqual(month.first.map { Dates.stamp($0.date) },"2026-03-30T20:00:00Z")

        let many = (0..<3).map { index -> RecordVersion in
            let graph = task("Daily \(index)",due:"2026-09-30T20:00:00Z",recurrence:"daily",anchor:"2026-09-30T20:00:00Z")
            return RecordVersion(kind:"task",id:graph.id,revision:0,value:graph)
        }
        let limited = try NotificationPlanner.plan(many,now:try Dates.parse("2026-10-01T00:00:00Z"))
        XCTAssertEqual(limited.count,60)
        XCTAssertEqual(limited.map(\.date),limited.map(\.date).sorted())
        XCTAssertEqual(Set(limited.map(\.identifier)).count,60)
    }
    func testICSUnicodeRecurrenceAndExceptionsRoundtrip() throws {
        var graph = Graph.new("event"); graph.set("calendar_id","calendar_fixture"); graph.set("title",String(repeating:"🎉 café ",count:30)); graph.set("description","lines\ncomma, semicolon; slash\\")
        graph.set("ics_uid","urn:uuid:external_uid@calendar")
        graph.set("start_at","2026-10-01T09:00:00Z"); graph.set("end_at","2026-10-01T10:00:00Z"); graph.set("timezone","Pacific/Auckland"); graph.set("recurrence","FREQ=DAILY;COUNT=5")
        graph.reminders = [Reminder(id:"reminder_fixture",owner_kind:"event",owner_id:graph.id,fire_at:"2026-10-01T08:45:00Z",message:"Remember")]
        graph.exceptions = [EventException(id:"exception_fixture",event_id:graph.id,occurrence_at:"2026-10-02T09:00:00Z",cancelled:true,start_at:nil,end_at:nil,title:nil)]
        let source = try ICS.export([graph]); XCTAssertTrue(source.components(separatedBy:"\r\n").allSatisfy { $0.utf8.count <= 75 })
        XCTAssertTrue(source.contains("UID:urn:uuid:external_uid@calendar\r\n"))
        let restored = try XCTUnwrap(ICS.parse(source).first)
        XCTAssertNotEqual(restored.id,graph.id); XCTAssertEqual(restored.text("ics_uid"),"urn:uuid:external_uid@calendar")
        XCTAssertEqual(restored.title,graph.title); XCTAssertEqual(restored.text("description"),graph.text("description"))
        XCTAssertEqual(restored.reminders.first?.fire_at,graph.reminders.first?.fire_at); XCTAssertTrue(restored.exceptions[0].cancelled)

        let store = try LocalStore(path:location()); var calendar = Graph.new("calendar"); calendar.set("id","calendar_fixture")
        try store.apply(snapshot([RecordVersion(kind:"calendar",id:calendar.id,revision:1,value:calendar),RecordVersion(kind:"event",id:graph.id,revision:2,value:graph)],cursor:2))
        try store.importEvents(store.previewEvents([restored],targetCalendarID:calendar.id))
        let mutation = try XCTUnwrap(store.uploads().first)
        XCTAssertEqual(mutation.id,graph.id); XCTAssertEqual(mutation.value?.text("ics_uid"),"urn:uuid:external_uid@calendar")
        XCTAssertEqual(store.records.filter { $0.kind == "event" }.count,1)
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
                XCTAssertEqual(record["start_value"] as? String,"datetime:2026-10-01T09:00:00+00:00")
                XCTAssertEqual(record["end_value"] as? String,"datetime:2026-10-01T10:00:00+00:00")
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
