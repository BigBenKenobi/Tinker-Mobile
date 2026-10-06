// Native iPhone Notes, Tasks, Calendar, conflicts and pairing presentation.
// Screens observe AppModel's SQLite state. Editors hold independent graph drafts
// and close only after successful local commits; network availability never gates
// ordinary editing. Files/QR/notification permissions are requested in context.
import SwiftUI
import UniformTypeIdentifiers

struct GraphEditor: View {
    @ObservedObject var model: AppModel
    @State var graph: Graph
    private let initialGraph: Graph
    @State private var discard = false
    @State private var preview = false
    let revision: Int
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    @State private var editingReminder: Reminder?
    @State private var addReminder = false
    @State private var editingException: EventException?
    @State private var addException = false
    /// Each sheet owns a graph copy; compare against the opening draft before discard.
    init(model: AppModel, graph: Graph, revision: Int) {
        self.model = model; self.revision = revision; initialGraph = graph
        _graph = State(initialValue:graph)
    }
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
            }.phoneSection()
            if graph.kind == "note" {
                Section("Markdown") {
                    Toggle("Preview",isOn:$preview)
                    if preview { Text(safeMarkdown(graph.text("body"))).textSelection(.enabled) }
                }.phoneSection()
                Section { Toggle("Pinned",isOn:flag("pinned")); Toggle("Archived",isOn:flag("archived")) }.phoneSection()
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
                }.phoneSection()
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
                }.phoneSection()
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
                }.phoneSection()
                Section("Recurring event exceptions") {
                    ForEach(graph.exceptions) { exception in
                        Button { editingException = exception } label: { Text(exception.occurrence_at + (exception.cancelled ? " · cancelled" : " · changed")) }
                    }.onDelete { graph.exceptions.remove(atOffsets:$0) }
                    if !graph.text("recurrence").isEmpty { Button("Change one occurrence") { addException = true } }
                }.phoneSection()
            }
            if graph.kind == "event" { Section("Event reminders") {
                ForEach(graph.reminders) { reminder in
                    Button { editingReminder = reminder } label: {
                        VStack(alignment:.leading) { Text((try? Dates.parse(reminder.fire_at).formatted()) ?? reminder.fire_at); Text(reminder.message + " · " + reminder.notification_owner).font(.caption) }
                    }
                }.onDelete { graph.reminders.remove(atOffsets:$0) }
                Button("Add reminder") { addReminder = true }
                Text("Each reminder notifies on one device. A reminder's delivery device is fixed after creation.").font(.caption).foregroundStyle(.secondary)
            }.phoneSection() }
            if let error { Section { Text(error).foregroundStyle(.red) }.phoneSection() }
        }.navigationTitle(graph.kind == "note" ? "Note" : graph.kind == "task" ? "Task" : graph.kind == "calendar" ? "Calendar" : "Event")
        .toolbar {
            ToolbarItem(placement:.cancellationAction) { Button("Cancel") { if graph != initialGraph { discard = true } else { dismiss() } } }
            ToolbarItem(placement:.confirmationAction) { Button("Save") { save() } }
        }
        .interactiveDismissDisabled(graph != initialGraph)
        .confirmationDialog("Discard unsaved changes?",isPresented:$discard,titleVisibility:.visible) {
            Button("Discard",role:.destructive) { dismiss() }
            Button("Keep editing",role:.cancel) {}
        }
        .sheet(item:$editingReminder) { value in NavigationStack { ReminderEditor(reminder:value,isNew:false) { updated in graph.reminders.removeAll { $0.id == updated.id }; graph.reminders.append(updated) } } }
        .sheet(isPresented:$addReminder) { NavigationStack { ReminderEditor(reminder:Reminder(id:Dates.id("reminder"),owner_kind:graph.kind,owner_id:graph.id,fire_at:Dates.stamp(Date().addingTimeInterval(3600)),message:graph.title),isNew:true) { graph.reminders.append($0) } } }
        .sheet(item:$editingException) { value in NavigationStack { ExceptionEditor(exception:value) { updated in graph.exceptions.removeAll { $0.id == updated.id }; graph.exceptions.append(updated) } } }
        .sheet(isPresented:$addException) { NavigationStack { ExceptionEditor(exception:EventException(id:Dates.id("exception"),event_id:graph.id,occurrence_at:graph.text("start_at"),cancelled:true,start_at:nil,end_at:nil,title:nil)) { graph.exceptions.append($0) } } }
    }
    /// Native Markdown renders text formatting only; strip URL attributes so no
    /// imported note can trigger navigation, networking or an external scheme.
    private func safeMarkdown(_ source: String) -> AttributedString {
        var result = (try? AttributedString(markdown:source)) ?? AttributedString(source)
        let ranges = result.runs.compactMap { $0.link != nil ? $0.range : nil }
        for range in ranges { result[range].link = nil }
        return result
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
        do { try model.save(graph,observedRevision:revision); dismiss() } catch { self.error = error.localizedDescription }
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

