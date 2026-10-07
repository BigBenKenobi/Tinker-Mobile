// Regression tests for optimistic local saves and atomic, reviewed Files imports.
// Each test owns an isolated SQLite file; no Keychain, LAN or notification effects.
// Assert retained durable content/outbox/cursors, not only the presence of errors.
import XCTest
@testable import TinkerCompanion

@MainActor final class DataSafetyTests: XCTestCase {
    private func path() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("safety.sqlite3") }
    private func store(_ graphs: [Graph], path: URL? = nil, revision: Int = 6) throws -> LocalStore {
        let store = try LocalStore(path:path ?? self.path())
        try store.apply(Snapshot(version:2,server_id:"desktop_fixture",cursor:revision,
                                 records:graphs.map { RecordVersion(kind:$0.kind,id:$0.id,revision:revision,value:$0) },conflicts:[]))
        return store
    }
    private func row(_ store: LocalStore, _ graph: Graph) throws -> RecordVersion {
        try XCTUnwrap(store.records.first { $0.kind == graph.kind && $0.id == graph.id })
    }
    private func calendar(_ id: String) -> Graph { var g = Graph.new("calendar"); g.set("id",id); return g }
    private func event(_ calendar: Graph) -> Graph { var g = Graph.new("event"); g.set("calendar_id",calendar.id); return g }

    func testStaleOfflineEditorAndDeletionKeepNewerPendingVersion() throws {
        var graph = Graph.new("note")
        let store = try store([graph]); let opening = try row(store,graph).editToken
        graph.set("title","Newer offline draft")
        try store.edit(graph,kind:graph.kind,id:graph.id,expected:opening)
        let queued = try XCTUnwrap(store.uploads().first)
        var stale = graph; stale.set("title","Older editor")
        XCTAssertThrowsError(try store.edit(stale,kind:graph.kind,id:graph.id,expected:opening))
        XCTAssertThrowsError(try store.edit(nil,kind:graph.kind,id:graph.id,expected:opening))
        XCTAssertEqual(try row(store,graph).value?.title,"Newer offline draft")
        XCTAssertEqual(try store.uploads().first?.op_id,queued.op_id)
        XCTAssertEqual(try store.uploads().first?.value?.title,"Newer offline draft")
    }
    func testStaleServerRevisionCannotBypassGuardWithPendingMutation() throws {
        var graph = Graph.new("note"); let store = try store([graph])
        let opening = try row(store,graph).editToken
        try store.apply(Snapshot(version:2,server_id:"desktop_fixture",cursor:7,
                                 records:[RecordVersion(kind:graph.kind,id:graph.id,revision:7,value:graph)],conflicts:[]))
        XCTAssertThrowsError(try store.edit(graph,kind:graph.kind,id:graph.id,expected:opening))
        graph.set("title","Local after revision seven")
        try store.edit(graph,kind:graph.kind,id:graph.id,expected:try row(store,graph).editToken)
        XCTAssertThrowsError(try store.edit(nil,kind:graph.kind,id:graph.id,expected:opening))
        XCTAssertEqual(try row(store,graph).value?.title,"Local after revision seven")
        XCTAssertEqual(try store.uploads().first?.base_revision,7)
    }
    func testLatestLocalTokenAllowsCoalescingAndSurvivesReopen() throws {
        let location = path(); var graph = Graph.new("note")
        let store = try store([graph],path:location)
        try store.edit(graph,kind:graph.kind,id:graph.id,expected:try row(store,graph).editToken)
        let first = try row(store,graph)
        let reopened = try LocalStore(path:location)
        XCTAssertEqual(try row(reopened,graph).editToken,first.editToken)
        graph.set("title","Second edit")
        try reopened.edit(graph,kind:graph.kind,id:graph.id,expected:first.editToken)
        XCTAssertEqual(reopened.pendingCount,1)
        XCTAssertEqual(try reopened.uploads().first?.base_revision,6)
        XCTAssertNotEqual(try row(reopened,graph).editToken,first.editToken)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(first)) as? [String:Any])
        XCTAssertEqual(Set(json.keys),Set(["kind","id","revision","value"]))
    }
    func testUploadAcknowledgementInvalidatesEarlierOpeningToken() throws {
        var graph = Graph.new("note"); let store = try store([graph])
        try store.edit(graph,kind:graph.kind,id:graph.id,expected:try row(store,graph).editToken)
        let opening = try row(store,graph).editToken; let sent = try store.uploads()
        try store.acknowledge(UploadResponse(version:2,server_id:"desktop_fixture",results:[UploadResult(op_id:sent[0].op_id,status:"applied",revision:7,conflict:nil)]),sent:sent)
        graph.set("title","Still-open draft")
        XCTAssertThrowsError(try store.edit(graph,kind:graph.kind,id:graph.id,expected:opening))
        XCTAssertEqual(store.pendingCount,0)
        XCTAssertNotEqual(try row(store,graph).value?.title,graph.title)
    }
    func testReimportKeepsCalendarAndMatchingChildIdentityAndOwner() throws {
        let a = calendar("calendar_a"), b = calendar("calendar_b"); var original = event(b)
        original.reminders = [Reminder(id:"alarm_owned",owner_kind:"event",owner_id:original.id,fire_at:original.text("start_at"),message:"Remember",notification_owner:"desktop",completed:true)]
        original.exceptions = [EventException(id:"exception_owned",event_id:original.id,occurrence_at:original.text("start_at"),cancelled:true,start_at:nil,end_at:nil,title:nil)]
        let store = try store([a,b,original])
        var imported = original; imported.set("id","event_imported"); imported.set("title","Imported title")
        imported.reminders[0].id = "alarm_new"; imported.reminders[0].notification_owner = "phone"; imported.reminders[0].completed = false
        imported.exceptions[0].id = "exception_new"
        let plan = try store.previewEvents([imported],targetCalendarID:a.id)
        XCTAssertEqual(store.pendingCount,0)
        try store.importEvents(plan)
        let result = try XCTUnwrap(row(store,original).value)
        XCTAssertEqual(result.text("calendar_id"),b.id)
        XCTAssertEqual(result.title,"Imported title")
        XCTAssertEqual(result.reminders[0].id,"alarm_owned")
        XCTAssertEqual(result.reminders[0].owner_id,original.id)
        XCTAssertEqual(result.reminders[0].notification_owner,"desktop")
        XCTAssertTrue(result.reminders[0].completed)
        XCTAssertEqual(result.exceptions[0].id,"exception_owned")
        XCTAssertEqual(result.exceptions[0].event_id,original.id)
    }
    func testPendingEditBlocksEntireImportIncludingUnrelatedNewEvent() throws {
        let calendar = calendar("calendar_a"); var graph = event(calendar)
        let store = try store([calendar,graph]); let imported = graph
        graph.set("title","Offline edit")
        try store.edit(graph,kind:graph.kind,id:graph.id,expected:try row(store,graph).editToken)
        let operation = try store.uploads().first?.op_id
        XCTAssertThrowsError(try store.previewEvents([event(calendar),imported],targetCalendarID:calendar.id))
        XCTAssertEqual(store.records.count,2); XCTAssertEqual(store.pendingCount,1)
        XCTAssertEqual(try row(store,graph).value?.title,"Offline edit")
        XCTAssertEqual(try store.uploads().first?.op_id,operation)
    }
    func testChangedEventAfterPreviewRejectsWholeCommit() throws {
        let calendar = calendar("calendar_a"); var graph = event(calendar)
        let store = try store([calendar,graph])
        let plan = try store.previewEvents([graph,event(calendar)],targetCalendarID:calendar.id)
        graph.set("title","New desktop version")
        try store.apply(Snapshot(version:2,server_id:"desktop_fixture",cursor:7,records:[
            RecordVersion(kind:"calendar",id:calendar.id,revision:6,value:calendar),
            RecordVersion(kind:"event",id:graph.id,revision:7,value:graph)],conflicts:[]))
        XCTAssertThrowsError(try store.importEvents(plan))
        XCTAssertEqual(store.records.count,2); XCTAssertEqual(store.pendingCount,0)
        XCTAssertEqual(try row(store,graph).value?.title,"New desktop version")
    }
    func testCalendarChangeAfterPreviewRequiresFreshReview() throws {
        var calendar = calendar("calendar_a"); let store = try store([calendar])
        let plan = try store.previewEvents([event(calendar)],targetCalendarID:calendar.id)
        calendar.set("name","Renamed")
        try store.edit(calendar,kind:calendar.kind,id:calendar.id,expected:try row(store,calendar).editToken)
        XCTAssertThrowsError(try store.importEvents(plan))
        XCTAssertEqual(store.records.count,1); XCTAssertEqual(store.pendingCount,1)
    }
    func testPendingDeletionAndAmbiguousUIDCannotBeReimported() throws {
        let calendar = calendar("calendar_a"), graph = event(calendar)
        let store = try store([calendar,graph])
        try store.edit(nil,kind:graph.kind,id:graph.id,expected:try row(store,graph).editToken)
        XCTAssertThrowsError(try store.previewEvents([graph],targetCalendarID:calendar.id))
        XCTAssertNil(try row(store,graph).value)
        var duplicate = graph; duplicate.set("id","event_duplicate")
        let ambiguous = try self.store([calendar,graph,duplicate])
        XCTAssertThrowsError(try ambiguous.previewEvents([graph],targetCalendarID:calendar.id))
        XCTAssertEqual(ambiguous.pendingCount,0)
    }
    func testNewImportRequiresExplicitLiveCalendarAndDistinctUIDs() throws {
        let a = calendar("calendar_a"), b = calendar("calendar_b"), graph = event(a)
        let store = try store([a,b])
        XCTAssertThrowsError(try store.previewEvents([graph],targetCalendarID:""))
        XCTAssertThrowsError(try store.previewEvents([graph,graph],targetCalendarID:b.id))
        try store.importEvents(store.previewEvents([graph],targetCalendarID:b.id))
        XCTAssertEqual(try row(store,graph).value?.text("calendar_id"),b.id)
    }
    func testAlarmDurationBoundariesAndMalformedComponents() throws {
        XCTAssertEqual(try ICS.alarmDuration("-PT1S"),1)
        XCTAssertEqual(try ICS.alarmDuration("-P1DT2H3M4S"),93784)
        XCTAssertEqual(try ICS.alarmDuration("-P366D"),31622400)
        for value in ["-P106751991167301D","-PT9223372036854775807H","-PT9223372036854775807M1S",
                      "-P999999999999999999999999DT1S","-P367D","-P366DT1S","-P","-PT","-P1DT",
                      "-PT0S","-PT-1S","-PT1.5S","-PTxH1S","-PT1S\n"] {
            XCTAssertThrowsError(try ICS.alarmDuration(value),value)
        }
    }
    func testOverflowingAlarmFileFailsBeforeStorage() throws {
        let source = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        UID:alarm-overflow
        DTSTART:20261008T090000Z
        BEGIN:VALARM
        ACTION:DISPLAY
        TRIGGER:-P106751991167301D
        END:VALARM
        END:VEVENT
        END:VCALENDAR
        """
        XCTAssertThrowsError(try ICS.parse(source))
        XCTAssertEqual(try ICS.parse(source.replacingOccurrences(of:"-P106751991167301D",with:"-PT1S")).count,1)
    }
}
