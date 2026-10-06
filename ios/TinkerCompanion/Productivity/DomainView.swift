// Native iPhone Notes, Tasks, Calendar, conflicts and pairing presentation.
// Screens observe AppModel's SQLite state. Editors hold independent graph drafts
// and close only after successful local commits; network availability never gates
// ordinary editing. Files/QR/notification permissions are requested in context.
import SwiftUI
import UniformTypeIdentifiers

struct DomainView: View {
    @ObservedObject var model: AppModel
    let kind: String
    @State private var search = ""
    @State private var showArchived = false
    @State private var pinnedOnly = false
    @State private var layout = "List"
    @State private var taskSection = "Active"
    @State private var editing: RecordVersion?
    @State private var newItem = false
    @State private var deleting: RecordVersion?
    private var rows: [RecordVersion] {
        model.store.records.filter { row in
            guard row.kind == kind, let g = row.value else { return false }
            if kind == "note", g.flag("archived") != showArchived { return false }
            if kind == "note", pinnedOnly && !g.flag("pinned") { return false }
            if kind == "task", taskSection == "Active", ["completed","cancelled"].contains(g.text("status")) { return false }
            if kind == "task", taskSection == "Completed", g.text("status") != "completed" { return false }
            return search.isEmpty || (g.title + " " + g.text(kind == "note" ? "body" : "description")).localizedCaseInsensitiveContains(search)
        }.sorted { lhs,rhs in
            let l = lhs.value!, r = rhs.value!
            if kind == "note", l.flag("pinned") != r.flag("pinned") { return l.flag("pinned") }
            return l.text("updated_at") > r.text("updated_at")
        }
    }
    var body: some View {
        List {
            Section { SyncStatus(model:model) }.phoneSection()
            if kind == "note" {
                Section("View") {
                    Toggle("Show archived notes",isOn:$showArchived)
                    Toggle("Pinned only",isOn:$pinnedOnly)
                    Picker("Layout",selection:$layout) { Text("List").tag("List"); Text("Grid").tag("Grid") }.pickerStyle(.segmented)
                }.phoneSection()
            } else {
                Picker("Section",selection:$taskSection) { ForEach(["Active","Completed","Activity"],id:\.self) { Text($0) } }.pickerStyle(.segmented)
            }
            if kind == "task", taskSection == "Activity" {
                Section("Stored activity") {
                    let activity = model.store.records.compactMap(\.value).flatMap(\.activity)
                    if activity.isEmpty { Text("No stored task activity").foregroundStyle(.secondary) }
                    ForEach(Array(activity.enumerated()),id:\.offset) { _,item in
                        VStack(alignment:.leading) {
                            Text(item["detail"]?.text ?? "Activity")
                            Text(item["occurrence_at"]?.text ?? item["created_at"]?.text ?? "").font(.caption)
                        }
                    }
                }.phoneSection()
            } else if kind == "note", layout == "Grid" {
                LazyVGrid(columns:[GridItem(.adaptive(minimum:140))],spacing:12) {
                    ForEach(rows) { row in
                        Button { editing = row } label: {
                            VStack(alignment:.leading,spacing:8) {
                                Text(row.value?.title.isEmpty == false ? row.value!.title : "Untitled").font(.headline)
                                Text(row.value?.text("body") ?? "").lineLimit(4)
                            }.frame(maxWidth:.infinity,minHeight:100,alignment:.topLeading).padding().background(.quaternary,in:RoundedRectangle(cornerRadius:12))
                        }.buttonStyle(.plain)
                    }
                }
            } else {
            if rows.isEmpty { ContentUnavailableView(kind == "note" ? "No notes" : "No tasks",systemImage:kind == "note" ? "note.text" : "checklist",description:Text("Create one here. Your edits work offline.")) }
            ForEach(rows) { row in
                Button { editing = row } label: {
                    VStack(alignment:.leading,spacing:5) {
                        HStack {
                            if kind == "note", row.value!.flag("pinned") { Image(systemName:"pin.fill") }
                            Text(row.value!.title.isEmpty ? "Untitled" : row.value!.title).font(.headline)
                        }
                        Text(row.value!.text(kind == "note" ? "body" : "description")).lineLimit(2).foregroundStyle(.secondary)
                        if kind == "task" { Text(row.value!.text("status").replacingOccurrences(of:"_",with:" ") + (row.value!.text("due_at").isEmpty ? "" : " · " + ((try? Dates.parse(row.value!.text("due_at")).formatted()) ?? row.value!.text("due_at")))).font(.caption) }
                        if !row.value!.reminders.isEmpty { Label("\(row.value!.reminders.count) reminders",systemImage:"bell").font(.caption) }
                    }.foregroundStyle(.primary)
                }.swipeActions {
                    Button("Delete",role:.destructive) { deleting = row }
                    if kind == "task" { Button("Complete") { complete(row) }.tint(.green) }
                }
            }
            }
        }.navigationTitle(kind == "note" ? "Notes" : "Tasks")
        .searchable(text:$search).refreshable { await model.sync() }
        .toolbar { Button { newItem = true } label: { Label("Create",systemImage:"plus") } }
        .sheet(item:$editing) { row in NavigationStack { GraphEditor(model:model,graph:row.value!,revision:row.revision) } }
        .sheet(isPresented:$newItem) { NavigationStack { GraphEditor(model:model,graph:Graph.new(kind),revision:0) } }
        .confirmationDialog("Delete this item and its linked reminders?",isPresented:Binding(get:{ deleting != nil },set:{ if !$0 { deleting = nil } }),titleVisibility:.visible) {
            Button("Delete",role:.destructive) { if let row = deleting { do { try model.delete(row) } catch { model.error = error.localizedDescription } }; deleting = nil }
        }
    }
    private func complete(_ row: RecordVersion) {
        guard var graph = row.value else { return }; graph.set("status","completed"); graph.set("updated_at",Dates.stamp(Date()))
        do { try model.save(graph,observedRevision:row.revision) } catch { model.error = error.localizedDescription }
    }
}

