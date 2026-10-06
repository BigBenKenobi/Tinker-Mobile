// Explicitly labelled UI-test data owned by a disposable launch store. This
// service is inaccessible without isolated mode; it never touches pairing,
// networking, notifications or production SQLite. Normal launches remain empty.
import Foundation

@MainActor enum LaunchFixture {
    static func seed(_ model: AppModel, name: String) throws {
        guard model.isolated else { throw CompanionError("Fixtures require isolated launch mode") }
        guard ["empty","populated","error"].contains(name) else { throw CompanionError("Unknown isolated fixture") }
        if name == "error" { model.error = "Preview/test fixture: simulated sync error"; return }
        guard name == "populated", model.store.records.isEmpty else { return }
        var calendar = Graph.new("calendar"); calendar.set("name","Preview calendar"); calendar.set("color","#67cf92")
        var note = Graph.new("note"); note.set("title","Preview note"); note.set("body","# A thought to keep\n\nA **labelled test fixture**, never production content."); note.record["pinned"] = .bool(true)
        var task = Graph.new("task"); task.set("title","Preview due task"); task.set("due_at",Dates.stamp(Date().addingTimeInterval(3600)))
        var event = Graph.new("event"); event.set("title","Preview event"); event.set("calendar_id",calendar.id)
        for graph in [calendar,note,task,event] { try model.store.edit(graph,kind:graph.kind,id:graph.id) }
    }
}
