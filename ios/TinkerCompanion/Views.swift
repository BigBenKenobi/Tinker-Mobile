// Native iPhone Notes, Tasks, Calendar, conflicts and pairing presentation.
// Screens observe AppModel's SQLite state. Editors hold independent graph drafts
// and close only after successful local commits; network availability never gates
// ordinary editing. Files/QR/notification permissions are requested in context.
import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        TabView {
            NavigationStack { DomainView(model:model,kind:"note") }.tabItem { Label("Notes",systemImage:"note.text") }
            NavigationStack { DomainView(model:model,kind:"task") }.tabItem { Label("Tasks",systemImage:"checklist") }
            NavigationStack { CalendarView(model:model) }.tabItem { Label("Calendar",systemImage:"calendar") }
            NavigationStack { CompanionView(model:model) }.tabItem { Label("Companion",systemImage:"iphone.and.arrow.forward") }
        }
        .tint(.orange)
    }
}

struct SyncStatus: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment:.leading,spacing:4) {
            Label(model.connection,systemImage:model.syncing ? "arrow.triangle.2.circlepath" : "network")
            Text("\(model.store.pendingCount) pending edits · \(model.store.conflicts.count) conflicts").font(.caption)
            if let error = model.error { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
        }.font(.footnote).padding(.vertical,4).accessibilityElement(children:.combine)
    }
}

struct DomainView: View {
    @ObservedObject var model: AppModel
    let kind: String
    @State private var search = ""
    @State private var showArchived = false
    @State private var editing: RecordVersion?
    @State private var newItem = false
    @State private var deleting: RecordVersion?
    private var rows: [RecordVersion] {
        model.store.records.filter { row in
            guard row.kind == kind, let g = row.value else { return false }
            if kind == "note", g.flag("archived") != showArchived { return false }
            return search.isEmpty || (g.title + " " + g.text(kind == "note" ? "body" : "description")).localizedCaseInsensitiveContains(search)
        }.sorted { lhs,rhs in
            let l = lhs.value!, r = rhs.value!
            if kind == "note", l.flag("pinned") != r.flag("pinned") { return l.flag("pinned") }
            return l.text("updated_at") > r.text("updated_at")
        }
    }
    var body: some View {
        List {
            Section { SyncStatus(model:model) }
            if kind == "note" { Toggle("Show archived notes",isOn:$showArchived) }
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
        }.navigationTitle(kind == "note" ? "Notes" : "Tasks")
        .searchable(text:$search).refreshable { await model.sync() }
        .toolbar { Button { newItem = true } label: { Label("Create",systemImage:"plus") } }
        .sheet(item:$editing) { row in NavigationStack { GraphEditor(model:model,graph:row.value!,token:row.editToken) } }
        .sheet(isPresented:$newItem) { NavigationStack { GraphEditor(model:model,graph:Graph.new(kind),token:.new) } }
        .confirmationDialog("Delete this item and its linked reminders?",isPresented:Binding(get:{ deleting != nil },set:{ if !$0 { deleting = nil } }),titleVisibility:.visible) {
            Button("Delete",role:.destructive) { if let row = deleting { do { try model.delete(row) } catch { model.error = error.localizedDescription } }; deleting = nil }
        }
    }
    private func complete(_ row: RecordVersion) {
        guard var graph = row.value else { return }; graph.set("status","completed"); graph.set("updated_at",Dates.stamp(Date()))
        do { try model.save(graph,expected:row.editToken) } catch { model.error = error.localizedDescription }
    }
}

struct GraphEditor: View {
    @ObservedObject var model: AppModel
    @State var graph: Graph
    let token: EditToken
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    @State private var editingReminder: Reminder?
    @State private var addReminder = false
    @State private var editingException: EventException?
    @State private var addException = false
    private func text(_ key: String) -> Binding<String> { Binding(get:{ graph.text(key) },set:{ graph.set(key,$0) }) }
    private func flag(_ key: String) -> Binding<Bool> { Binding(get:{ graph.flag(key) },set:{ graph.record[key] = .bool($0) }) }
    private func date(_ key: String) -> Binding<Date> { Binding(get:{ (try? Dates.parse(graph.text(key))) ?? Date() },set:{ graph.set(key,Dates.stamp($0)) }) }
    var body: some View {
        Form {
            Section {
                if graph.kind == "calendar" {
                    TextField("Calendar name",text:text("name"))
                    TextField("Colour (#RRGGBB)",text:text("color"))
                    Toggle("Visible",isOn:flag("visible"))
                } else {
                    TextField("Title",text:text("title"))
                    TextEditor(text:text(graph.kind == "note" ? "body" : "description")).frame(minHeight:150).accessibilityLabel("Text")
                }
            }
            if graph.kind == "note" {
                Section { Toggle("Pinned",isOn:flag("pinned")); Toggle("Archived",isOn:flag("archived")) }
                Section("Note reminder") {
                    Toggle("Remind me",isOn:Binding(get:{ graph.linked_task != nil },set:{ enabled in
                        if enabled {
                            let stamp = Dates.stamp(Date())
                            graph.linked_task = ["id": .string(Dates.id("task")), "title": .string(graph.title),
                                "description": .string(""), "status": .string("pending"),
                                "due_at": .string(Dates.stamp(Date().addingTimeInterval(3600))),
                                "created_at": .string(stamp), "updated_at": .string(stamp), "metadata_json": .string("{}"),
                                "kind": .string("reminder"), "timezone_name": .string(TimeZone.current.identifier),
                                "recurrence": .string("none"), "recurrence_anchor": .null, "paused": .bool(false),
                                "last_fired_at": .null, "note_id": .string(graph.id), "notification_owner": .string("phone")]
                        } else { graph.linked_task = nil; graph.activity = [] }
                    }))
                    if graph.linked_task != nil {
                        DatePicker("Due",selection:Binding(get:{ (try? Dates.parse(graph.linked_task?["due_at"]?.text ?? "")) ?? Date() },
                            set:{ graph.linked_task?["due_at"] = .string(Dates.stamp($0)) }))
                        Picker("Repeat",selection:Binding(get:{ graph.linked_task?["recurrence"]?.text ?? "none" },
                            set:{ graph.linked_task?["recurrence"] = .string($0) })) {
                            ForEach(["none","daily","weekly","monthly","yearly"],id:\.self) { Text($0.capitalized).tag($0) }
                        }
                    }
                }
            }
            if graph.kind == "task" {
                Section("Task") {
                    Picker("Status",selection:text("status")) { ForEach(["pending","completed","cancelled"],id:\.self) { Text($0.replacingOccurrences(of:"_",with:" ")).tag($0) } }
                    Toggle("Due date",isOn:Binding(get:{ !graph.text("due_at").isEmpty },set:{ graph.record["due_at"] = $0 ? .string(Dates.stamp(Date())) : .null }))
                    if !graph.text("due_at").isEmpty {
                        DatePicker("Due",selection:date("due_at"))
                        Picker("Repeat",selection:text("recurrence")) { ForEach(["none","daily","weekly","monthly","yearly"],id:\.self) { Text($0.capitalized).tag($0) } }
                        Text("This iPhone will deliver reminders created here. Desktop-owned reminders remain on Fedora.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if graph.kind == "event" {
                Section("Event") {
                    Picker("Calendar",selection:text("calendar_id")) {
                        ForEach(model.store.records.filter { $0.kind == "calendar" && $0.value != nil }) { row in
                            Text(row.value?.text("name") ?? "Calendar").tag(row.id)
                        }
                    }
                    Toggle("All day",isOn:flag("all_day"))
                    DatePicker("Starts",selection:date("start_at"),displayedComponents:graph.flag("all_day") ? [.date] : [.date,.hourAndMinute])
                    DatePicker("Ends",selection:date("end_at"),displayedComponents:graph.flag("all_day") ? [.date] : [.date,.hourAndMinute])
                    TextField("Location",text:text("location"))
                    TextField("Timezone",text:text("timezone")).textInputAutocapitalization(.never).autocorrectionDisabled()
                    RecurrenceEditor(rule:Binding(get:{ graph.text("recurrence") },set:{ graph.optional("recurrence",$0) }))
                }
                Section("Recurring event exceptions") {
                    ForEach(graph.exceptions) { exception in
                        Button { editingException = exception } label: { Text(exception.occurrence_at + (exception.cancelled ? " · cancelled" : " · changed")) }
                    }.onDelete { graph.exceptions.remove(atOffsets:$0) }
                    if !graph.text("recurrence").isEmpty { Button("Change one occurrence") { addException = true } }
                }
            }
            if graph.kind == "event" { Section("Event reminders") {
                ForEach(graph.reminders) { reminder in
                    Button { editingReminder = reminder } label: {
                        VStack(alignment:.leading) { Text((try? Dates.parse(reminder.fire_at).formatted()) ?? reminder.fire_at); Text(reminder.message + " · " + reminder.notification_owner).font(.caption) }
                    }
                }.onDelete { graph.reminders.remove(atOffsets:$0) }
                Button("Add reminder") { addReminder = true }
                Text("Each reminder notifies on one device. A reminder's delivery device is fixed after creation.").font(.caption).foregroundStyle(.secondary)
            } }
            if let error { Section { Text(error).foregroundStyle(.red) } }
        }.navigationTitle(graph.kind == "note" ? "Note" : graph.kind == "task" ? "Task" : graph.kind == "calendar" ? "Calendar" : "Event")
        .toolbar {
            ToolbarItem(placement:.cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement:.confirmationAction) { Button("Save") { save() } }
        }
        .sheet(item:$editingReminder) { value in NavigationStack { ReminderEditor(reminder:value,isNew:false) { updated in graph.reminders.removeAll { $0.id == updated.id }; graph.reminders.append(updated) } } }
        .sheet(isPresented:$addReminder) { NavigationStack { ReminderEditor(reminder:Reminder(id:Dates.id("reminder"),owner_kind:graph.kind,owner_id:graph.id,fire_at:Dates.stamp(Date().addingTimeInterval(3600)),message:graph.title),isNew:true) { graph.reminders.append($0) } } }
        .sheet(item:$editingException) { value in NavigationStack { ExceptionEditor(exception:value) { updated in graph.exceptions.removeAll { $0.id == updated.id }; graph.exceptions.append(updated) } } }
        .sheet(isPresented:$addException) { NavigationStack { ExceptionEditor(exception:EventException(id:Dates.id("exception"),event_id:graph.id,occurrence_at:graph.text("start_at"),cancelled:true,start_at:nil,end_at:nil,title:nil)) { graph.exceptions.append($0) } } }
    }
    private func save() {
        if graph.kind != "calendar" { graph.set("updated_at",Dates.stamp(Date())) }
        if graph.kind == "note", graph.linked_task != nil {
            graph.linked_task?["title"] = .string(graph.title)
            graph.linked_task?["updated_at"] = .string(Dates.stamp(Date()))
        }
        if graph.kind == "event", graph.flag("all_day") {
            var calendar = Calendar(identifier:.gregorian); calendar.timeZone = TimeZone(identifier:graph.text("timezone")) ?? .current
            if let start = try? Dates.parse(graph.text("start_at")), let end = try? Dates.parse(graph.text("end_at")) {
                graph.set("start_at",Dates.stamp(calendar.startOfDay(for:start)))
                graph.set("end_at",Dates.stamp(max(calendar.startOfDay(for:end),calendar.date(byAdding:.day,value:1,to:calendar.startOfDay(for:start))!)))
            }
        }
        do { try model.save(graph,expected:token); dismiss() } catch { self.error = error.localizedDescription }
    }
}

struct RecurrenceEditor: View {
    @Binding var rule: String
    private var parsed: Recurrence? { try? Recurrence(rule) }
    private var frequency: String { parsed?.frequency ?? "NONE" }
    private func build(frequency: String? = nil, interval: Int? = nil, count: Int? = nil, until: Date? = nil, clearEnding: Bool = false, weekdays: Set<String>? = nil) {
        let freq = frequency ?? self.frequency
        guard freq != "NONE" else { rule = ""; return }
        var parts = ["FREQ=" + freq]
        let step = interval ?? parsed?.interval ?? 1
        if step > 1 { parts.append("INTERVAL=\(step)") }
        if !clearEnding {
            if let end = until ?? parsed?.until {
                let formatter = DateFormatter(); formatter.locale = Locale(identifier:"en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT:0); formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
                parts.append("UNTIL=" + formatter.string(from:end))
            } else if let limit = count ?? ((parsed?.count ?? 10000) < 10000 ? parsed?.count : nil) { parts.append("COUNT=\(limit)") }
        }
        let days = weekdays ?? parsed?.weekdays
        if freq == "WEEKLY", let days, !days.isEmpty { parts.append("BYDAY=" + Recurrence.days.filter(days.contains).joined(separator:",")) }
        rule = parts.joined(separator:";")
    }
    var body: some View {
        Picker("Repeat",selection:Binding(get:{ frequency },set:{ build(frequency:$0) })) {
            Text("Never").tag("NONE"); Text("Daily").tag("DAILY"); Text("Weekly").tag("WEEKLY"); Text("Monthly").tag("MONTHLY"); Text("Yearly").tag("YEARLY")
        }
        if frequency != "NONE" {
            Stepper("Every \(parsed?.interval ?? 1) period(s)",value:Binding(get:{ parsed?.interval ?? 1 },set:{ build(interval:$0) }),in:1...366)
            Picker("Ends",selection:Binding(get:{ parsed?.until != nil ? "date" : (parsed?.count ?? 10000) < 10000 ? "count" : "never" },set:{ mode in
                if mode == "never" { build(clearEnding:true) }
                else if mode == "date" { build(until:Date().addingTimeInterval(30*86400)) }
                else { rule = "FREQ=" + frequency + ";INTERVAL=\(parsed?.interval ?? 1);COUNT=10" }
            })) { Text("Never").tag("never"); Text("After occurrences").tag("count"); Text("On a date").tag("date") }
            if parsed?.until != nil { DatePicker("Repeat until",selection:Binding(get:{ parsed?.until ?? Date() },set:{ build(until:$0) })) }
            else if (parsed?.count ?? 10000) < 10000 { Stepper("\(parsed?.count ?? 10) occurrences",value:Binding(get:{ parsed?.count ?? 10 },set:{ build(count:$0) }),in:1...9999) }
            if frequency == "WEEKLY" {
                DisclosureGroup("Weekdays") {
                    ForEach(Array(zip(Recurrence.days,["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"])),id:\.0) { day,label in
                        Toggle(label,isOn:Binding(get:{ parsed?.weekdays?.contains(day) ?? false },set:{ selected in
                            var days = parsed?.weekdays ?? []; if selected { days.insert(day) } else { days.remove(day) }; build(weekdays:days)
                        }))
                    }
                    Text("With no weekdays selected, repeats on the original weekday.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ReminderEditor: View {
    @State var reminder: Reminder
    let isNew: Bool
    let save: (Reminder) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Form {
            DatePicker("Notify",selection:Binding(get:{ (try? Dates.parse(reminder.fire_at)) ?? Date() },set:{ reminder.fire_at = Dates.stamp($0) }))
            TextField("Message",text:$reminder.message)
            Picker("Notify on",selection:$reminder.notification_owner) { Text("iPhone").tag("phone"); Text("Fedora").tag("desktop") }.disabled(!isNew)
            Toggle("Completed",isOn:$reminder.completed)
        }.navigationTitle("Reminder").toolbar {
            ToolbarItem(placement:.cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement:.confirmationAction) { Button("Done") { save(reminder); dismiss() } }
        }
    }
}

struct ExceptionEditor: View {
    @State var exception: EventException
    let save: (EventException) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Form {
            DatePicker("Original occurrence",selection:Binding(get:{ (try? Dates.parse(exception.occurrence_at)) ?? Date() },set:{ exception.occurrence_at = Dates.stamp($0) }))
            Toggle("Cancel this occurrence",isOn:$exception.cancelled)
            if !exception.cancelled {
                DatePicker("New start",selection:Binding(get:{ (try? Dates.parse(exception.start_at ?? exception.occurrence_at)) ?? Date() },set:{ exception.start_at = Dates.stamp($0); if exception.end_at == nil { exception.end_at = Dates.stamp($0.addingTimeInterval(3600)) } }))
                DatePicker("New end",selection:Binding(get:{ (try? Dates.parse(exception.end_at ?? exception.occurrence_at)) ?? Date().addingTimeInterval(3600) },set:{ exception.end_at = Dates.stamp($0); if exception.start_at == nil { exception.start_at = exception.occurrence_at } }))
                TextField("Override title",text:Binding(get:{ exception.title ?? "" },set:{ exception.title = $0.isEmpty ? nil : $0 }))
            }
        }.navigationTitle("One occurrence").toolbar {
            ToolbarItem(placement:.cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement:.confirmationAction) { Button("Done") { save(exception); dismiss() } }
        }
    }
}

struct CalendarFile: FileDocument {
    static var readableContentTypes: [UTType] { [UTType(filenameExtension:"ics") ?? .plainText] }
    var text: String = ""
    init(text: String = "") { self.text = text }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents, let text = String(data:data,encoding:.utf8) else { throw CompanionError("Calendar file must be UTF-8") }; self.text = text
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents:Data(text.utf8)) }
}

struct CalendarView: View {
    @ObservedObject var model: AppModel
    @State private var selectedDay = Date()
    @State private var search = ""
    @State private var editing: RecordVersion?
    @State private var newItem = false
    @State private var importing = false
    @State private var importFile: ImportFile?
    @State private var exporting = false
    @State private var document = CalendarFile()
    @State private var deleting: RecordVersion?
    @State private var editingCalendar: RecordVersion?
    @State private var newCalendar = false
    private var events: [Graph] { model.store.records.filter { $0.kind == "event" }.compactMap(\.value) }
    private var calendars: [RecordVersion] { model.store.records.filter { $0.kind == "calendar" && $0.value != nil } }
    private var draftEvent: Graph {
        var graph = Graph.new("event",now:selectedDay)
        if let calendar = calendars.first { graph.set("calendar_id",calendar.id) }
        return graph
    }
    private var occurrences: [Occurrence] {
        let start = Calendar.current.startOfDay(for:selectedDay), end = Calendar.current.date(byAdding:.day,value:1,to:start)!
        return events.flatMap { (try? Occurrence.expand($0,lower:start,upper:end)) ?? [] }.sorted { $0.start < $1.start }
    }
    var body: some View {
        List {
            Section { SyncStatus(model:model) }
            Section("Calendars") {
                ForEach(calendars) { row in
                    Button { editingCalendar = row } label: {
                        Label(row.value?.text("name") ?? "Calendar", systemImage:"calendar")
                    }
                }
                Button("Add calendar") { newCalendar = true }
            }
            Section { DatePicker("Selected day",selection:$selectedDay,displayedComponents:.date).datePickerStyle(.graphical) }
            Section(selectedDay.formatted(date:.complete,time:.omitted)) {
                if search.isEmpty {
                    if occurrences.isEmpty { Text("No events this day").foregroundStyle(.secondary) }
                    ForEach(occurrences) { occurrence in
                        Button { edit(occurrence.graph) } label: {
                            VStack(alignment:.leading) { Text(occurrence.title.isEmpty ? "Untitled" : occurrence.title).font(.headline); Text(occurrence.graph.flag("all_day") ? "All day" : occurrence.start.formatted(date:.omitted,time:.shortened) + " – " + occurrence.end.formatted(date:.omitted,time:.shortened)).font(.caption); Text(occurrence.graph.text("location")).font(.caption) }
                        }.swipeActions { Button("Delete series",role:.destructive) { deleting = row(occurrence.graph) } }
                    }
                } else {
                    ForEach(events.filter { ($0.title + " " + $0.text("description") + " " + $0.text("location")).localizedCaseInsensitiveContains(search) }) { graph in
                        Button(graph.title.isEmpty ? "Untitled" : graph.title) { edit(graph) }
                    }
                }
            }
        }.navigationTitle("Calendar").searchable(text:$search).refreshable { await model.sync() }
        .toolbar {
            Button { if calendars.isEmpty { newCalendar = true } else { newItem = true } } label: { Label("New event",systemImage:"plus") }
            Menu {
                Button("Import ICS from Files") { importing = true }
                Button("Export ICS to Files") { do { document = CalendarFile(text:try ICS.export(events)); exporting = true } catch { model.error = error.localizedDescription } }
            } label: { Label("Calendar files",systemImage:"square.and.arrow.up") }
        }
        .sheet(item:$editing) { r in NavigationStack { GraphEditor(model:model,graph:r.value!,token:r.editToken) } }
        .sheet(isPresented:$newItem) { NavigationStack { GraphEditor(model:model,graph:draftEvent,token:.new) } }
        .sheet(item:$editingCalendar) { r in NavigationStack { GraphEditor(model:model,graph:r.value!,token:r.editToken) } }
        .sheet(isPresented:$newCalendar) { NavigationStack { GraphEditor(model:model,graph:Graph.new("calendar"),token:.new) } }
        .fileImporter(isPresented:$importing,allowedContentTypes:CalendarFile.readableContentTypes) { result in
            do {
                let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
                guard size <= 4*1024*1024 else { throw CompanionError("ICS exceeds 4 MiB") }
                let text = try String(contentsOf:url,encoding:.utf8).replacingOccurrences(of:"\u{FEFF}",with:"")
                importFile = ImportFile(graphs:try ICS.parse(text))
            } catch { model.error = error.localizedDescription }
        }
        .sheet(item:$importFile) { file in NavigationStack { EventImportView(model:model,sources:file.graphs) } }
        .fileExporter(isPresented:$exporting,document:document,contentType:CalendarFile.readableContentTypes[0],defaultFilename:"Tinker.ics") { result in
            if case .failure(let error) = result { model.error = error.localizedDescription }
        }
        .confirmationDialog("Delete this entire event series and its reminders?",isPresented:Binding(get:{ deleting != nil },set:{ if !$0 { deleting = nil } }),titleVisibility:.visible) {
            Button("Delete series",role:.destructive) { if let row = deleting { do { try model.delete(row) } catch { model.error = error.localizedDescription } }; deleting = nil }
        }
    }
    private func row(_ graph: Graph) -> RecordVersion? { model.store.records.first { $0.kind == "event" && $0.id == graph.id } }
    private func edit(_ graph: Graph) { editing = row(graph) }
}

struct CompanionView: View {
    @ObservedObject var model: AppModel
    @State private var scanning = false
    @State private var qr = ""
    @State private var unpairing = false
    var body: some View {
        List {
            Section("Connection") {
                SyncStatus(model:model)
                if let paired = model.pairing { Text(paired.endpoint).font(.caption); Button("Sync now") { Task { await model.sync() } }.disabled(model.syncing); Button("Unpair",role:.destructive) { unpairing = true }.disabled(model.syncing) }
                else {
                    Button("Scan desktop pairing QR") { scanning = true }
                    DisclosureGroup("Paste pairing QR text") {
                        TextEditor(text:$qr).frame(minHeight:100).textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button("Pair") { let code = qr; qr = ""; Task { await model.pair(qr:code) } }.disabled(model.syncing)
                    }
                }
                Text("Open Tinker on Fedora, enable local sync on its LAN address, then show its pairing QR. Both devices must be on the same network.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Reminders") {
                Text(model.notifications.status)
                Button("Enable iPhone notifications") { Task { await model.notifications.authorize(); await model.reconcileReminders() } }
            }
            Section("Conflicts · \(model.store.conflicts.count)") {
                if model.store.conflicts.isEmpty { Text("No conflicts").foregroundStyle(.secondary) }
                ForEach(model.store.conflicts) { conflict in NavigationLink { ConflictView(model:model,conflict:conflict) } label: { Text(conflict.current?.title ?? conflict.incoming?.title ?? "Deleted item") } }
            }
        }.navigationTitle("Companion")
        .sheet(isPresented:$scanning) { QRScanner { code in scanning = false; Task { await model.pair(qr:code) } } }
        .confirmationDialog("Unpair and cancel iPhone reminders? Local items and offline edits stay on this phone.",isPresented:$unpairing,titleVisibility:.visible) { Button("Unpair",role:.destructive) { Task { await model.unpair() } } }
    }
}

struct ConflictView: View {
    @ObservedObject var model: AppModel
    let conflict: Conflict
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            version("Desktop / current",conflict.current)
            version("Offline / incoming",conflict.incoming)
            Section {
                Button("Keep current version") { resolve(false) }
                Button("Use incoming version") { resolve(true) }
                Text("Both copies stay preserved until the desktop accepts your resolution. If another edit arrives, it is preserved as a new conflict.").font(.caption)
            }
        }.navigationTitle("Resolve conflict")
    }
    private func version(_ title: String,_ graph: Graph?) -> some View {
        Section(title) {
            if let g = graph {
                Text(g.title).font(.headline)
                Text(g.text(g.kind == "note" ? "body" : "description")).textSelection(.enabled)
                if g.kind == "note" { Text((g.flag("pinned") ? "Pinned · " : "") + (g.flag("archived") ? "Archived" : "Active note")).font(.caption) }
                if g.kind == "task" { Text(g.text("status").replacingOccurrences(of:"_",with:" ")); if !g.text("due_at").isEmpty { Text("Due: " + ((try? Dates.parse(g.text("due_at")).formatted()) ?? g.text("due_at"))) } }
                if g.kind == "event" {
                    Text("Starts: " + ((try? Dates.parse(g.text("start_at")).formatted()) ?? g.text("start_at")))
                    Text("Ends: " + ((try? Dates.parse(g.text("end_at")).formatted()) ?? g.text("end_at")))
                    Text(g.text("location")); Text(g.text("recurrence")).font(.caption)
                }
                ForEach(g.reminders) { reminder in Text(reminder.message + " · " + ((try? Dates.parse(reminder.fire_at).formatted()) ?? reminder.fire_at) + " · " + reminder.notification_owner).font(.caption) }
                ForEach(g.exceptions) { exception in Text(exception.occurrence_at + (exception.cancelled ? " · cancelled" : " · changed")).font(.caption) }
            }
            else { Text("Deleted") }
        }
    }
    private func resolve(_ incoming: Bool) {
        do { try model.store.resolve(conflict,useIncoming:incoming); Task { await model.sync() }; dismiss() }
        catch { model.error = error.localizedDescription }
    }
}
