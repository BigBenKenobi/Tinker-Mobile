// Calendar month/week/day and Files ICS presentation over AppModel local data.
// CalendarProjection bounds date expansion; visibility filters events and due
// tasks remain read-only projections. Editors delegate atomic saves to AppModel.
import SwiftUI
import UniformTypeIdentifiers

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
    @EnvironmentObject private var presentation: PresentationStore
    private var selectedDay: Date {
        get { (try? Dates.parse(presentation.selections["calendar.day"] ?? "")) ?? Date() }
        nonmutating set { presentation.selections["calendar.day"] = Dates.stamp(newValue) }
    }
    private var search: String { presentation.drafts["calendar.search"] ?? "" }
    private var mode: String { presentation.selections["calendar.mode"] ?? "Month" }
    @State private var editing: RecordVersion?
    @State private var newItem = false
    @State private var importing = false
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
    private var period: DateInterval { CalendarProjection.interval(containing:selectedDay,mode:mode) }
    private var visibleEvents: [Graph] {
        let visibleIDs = Set(calendars.filter { $0.value?.flag("visible") == true }.map(\.id))
        return events.filter { visibleIDs.contains($0.text("calendar_id")) }
    }
    private var expansion: (occurrences:[Occurrence], errors:[String]) {
        var result: [Occurrence] = []; var errors: [String] = []
        for graph in visibleEvents {
            do { result += try Occurrence.expand(graph,lower:period.start,upper:period.end) }
            catch { errors.append(graph.title + ": " + error.localizedDescription) }
        }
        return (result.sorted { $0.start < $1.start },errors)
    }
    private var occurrences: [Occurrence] { expansion.occurrences }
    private var dueTasks: [ProjectedDueTask] { CalendarProjection.dueTasks(model.store.records,interval:period) }

    var body: some View {
        List {
            Section { SyncStatus(model:model) }.phoneSection()
            Section("Calendars") {
                ForEach(calendars) { row in
                    HStack {
                        Circle().fill(Color(hex:row.value?.text("color") ?? "#67cf92")).frame(width:12,height:12).accessibilityHidden(true)
                        Button { editingCalendar = row } label: { Text(row.value?.text("name") ?? "Calendar") }
                        Spacer()
                        Toggle("Visible",isOn:Binding(get:{ row.value?.flag("visible") ?? false },set:{ value in
                            guard var graph = row.value else { return }; graph.record["visible"] = .bool(value)
                            do { try model.save(graph,observedRevision:row.revision) } catch { model.error = error.localizedDescription }
                        })).labelsHidden().accessibilityLabel("Show " + (row.value?.text("name") ?? "calendar"))
                    }
                }
                Button("Add calendar") { newCalendar = true }
            }.phoneSection()
            Section("Presentation") {
                Picker("Period",selection:presentation.selection("calendar.mode",fallback:"Month")) { ForEach(["Month","Week","Day"],id:\.self) { Text($0) } }.pickerStyle(.segmented)
                if mode == "Month" {
                    Text(selectedDay.formatted(.dateTime.month(.wide).year())).font(.headline)
                    LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:2),count:7),spacing:6) {
                        let calendar = Calendar.current
                        let offset = (calendar.component(.weekday,from:period.start) - calendar.firstWeekday + 7) % 7
                        ForEach(0..<7,id:\.self) { index in
                            Text(calendar.veryShortStandaloneWeekdaySymbols[(index + calendar.firstWeekday - 1) % 7]).font(.caption).accessibilityHidden(true)
                        }
                        ForEach(0..<offset,id:\.self) { _ in Color.clear.frame(height:44).accessibilityHidden(true) }
                        ForEach(CalendarProjection.days(in:period),id:\.self) { day in
                            Button { selectedDay = day } label: {
                                Text(day.formatted(.dateTime.day())).frame(maxWidth:.infinity,minHeight:44)
                                    .background(Calendar.current.isDate(day,inSameDayAs:selectedDay) ? Color.accentColor.opacity(0.2) : Color.clear,in:RoundedRectangle(cornerRadius:8))
                            }.accessibilityLabel(day.formatted(date:.complete,time:.omitted))
                        }
                    }
                }
                else if mode == "Week" {
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:70))]) {
                        ForEach(CalendarProjection.days(in:period),id:\.self) { day in
                            Button { selectedDay = day } label: { VStack { Text(day.formatted(.dateTime.weekday(.abbreviated))); Text(day.formatted(.dateTime.day())) }.frame(minWidth:44,minHeight:44) }
                        }
                    }
                } else { DatePicker("Selected day",selection:presentation.date("calendar.day"),displayedComponents:.date) }
                HStack {
                    Button("Previous") { shift(-1) }.frame(minHeight:44)
                    Spacer()
                    Button("Today") { selectedDay = Date() }.frame(minHeight:44)
                    Spacer()
                    Button("Next") { shift(1) }.frame(minHeight:44)
                }
            }.phoneSection()
            if !expansion.errors.isEmpty { Section("Calendar expansion errors") { ForEach(expansion.errors,id:\.self) { Text($0).foregroundStyle(.red) } }.phoneSection() }
            Section("Due tasks · projected") {
                if dueTasks.isEmpty { Text("No tasks due in this period").foregroundStyle(.secondary) }
                ForEach(dueTasks) { task in
                    VStack(alignment:.leading) { Text(task.title); Text(task.due.formatted()).font(.caption); if task.linkedNoteID != nil { Label("Linked note reminder",systemImage:"note.text").font(.caption) } }
                }
                Text("Tasks remain tasks; this view does not create calendar events.").font(.caption)
            }.phoneSection()
            Section(mode + " agenda") {
                if search.isEmpty {
                    if occurrences.isEmpty { Text("No visible events in this period").foregroundStyle(.secondary) }
                    ForEach(occurrences) { occurrence in
                        Button { edit(occurrence.graph) } label: {
                            VStack(alignment:.leading) { Text(occurrence.title.isEmpty ? "Untitled" : occurrence.title).font(.headline); Text(occurrence.start.formatted(date:.abbreviated,time:.omitted)).font(.caption); Text(occurrence.graph.flag("all_day") ? "All day" : occurrence.start.formatted(date:.omitted,time:.shortened) + " – " + occurrence.end.formatted(date:.omitted,time:.shortened)).font(.caption); Text(occurrence.graph.text("location")).font(.caption) }
                        }.swipeActions { Button("Delete series",role:.destructive) { deleting = row(occurrence.graph) } }
                    }
                } else {
                    ForEach(visibleEvents.filter { ($0.title + " " + $0.text("description") + " " + $0.text("location")).localizedCaseInsensitiveContains(search) }) { graph in
                        Button(graph.title.isEmpty ? "Untitled" : graph.title) { edit(graph) }
                    }
                }
            }.phoneSection()
        }.navigationTitle("Calendar").searchable(text:presentation.draft("calendar.search")).refreshable { await model.sync() }
        .toolbar {
            Button { if calendars.isEmpty { newCalendar = true } else { newItem = true } } label: { Label("New event",systemImage:"plus") }
            Menu {
                Button("Import ICS from Files") { importing = true }
                Button("Export ICS to Files") { do { document = CalendarFile(text:try ICS.export(events)); exporting = true } catch { model.error = error.localizedDescription } }
            } label: { Label("Calendar files",systemImage:"square.and.arrow.up") }
        }
        .sheet(item:$editing) { r in NavigationStack { GraphEditor(model:model,graph:r.value!,revision:r.revision) } }
        .sheet(isPresented:$newItem) { NavigationStack { GraphEditor(model:model,graph:draftEvent,revision:0) } }
        .sheet(item:$editingCalendar) { r in NavigationStack { GraphEditor(model:model,graph:r.value!,revision:r.revision) } }
        .sheet(isPresented:$newCalendar) { NavigationStack { GraphEditor(model:model,graph:Graph.new("calendar"),revision:0) } }
        .fileImporter(isPresented:$importing,allowedContentTypes:CalendarFile.readableContentTypes) { result in
            do {
                let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
                guard size <= 4*1024*1024 else { throw CompanionError("ICS exceeds 4 MiB") }
                let text = try String(contentsOf:url,encoding:.utf8).replacingOccurrences(of:"\u{FEFF}",with:"")
                try model.store.importEvents(ICS.parse(text)); Task { await model.reconcileReminders(); await model.sync() }
            } catch { model.error = error.localizedDescription }
        }
        .fileExporter(isPresented:$exporting,document:document,contentType:CalendarFile.readableContentTypes[0],defaultFilename:"Tinker.ics") { result in
            if case .failure(let error) = result { model.error = error.localizedDescription }
        }
        .confirmationDialog("Delete this entire event series and its reminders?",isPresented:Binding(get:{ deleting != nil },set:{ if !$0 { deleting = nil } }),titleVisibility:.visible) {
            Button("Delete series",role:.destructive) { if let row = deleting { do { try model.delete(row) } catch { model.error = error.localizedDescription } }; deleting = nil }
        }
    }
    /// Shift using calendar components, never fixed seconds across DST boundaries.
    private func shift(_ value: Int) {
        let component: Calendar.Component = mode == "Month" ? .month : mode == "Week" ? .weekOfYear : .day
        if let next = Calendar.current.date(byAdding:component,value:value,to:selectedDay) { selectedDay = next }
    }
    private func row(_ graph: Graph) -> RecordVersion? { model.store.records.first { $0.kind == "event" && $0.id == graph.id } }
    private func edit(_ graph: Graph) { editing = row(graph) }
}

