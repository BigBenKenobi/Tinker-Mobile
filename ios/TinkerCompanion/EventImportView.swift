// Files import review boundary. Parsing never writes storage; the user selects a
// calendar, reviews every add/replacement, then commits the token-checked plan.
// Failed previews/commits keep the parsed file available for another review.
import SwiftUI

struct ImportFile: Identifiable {
    let id = UUID()
    let graphs: [Graph]
}

struct EventImportView: View {
    @ObservedObject var model: AppModel
    let sources: [Graph]
    @Environment(\.dismiss) private var dismiss
    @State private var calendarID = ""
    @State private var plan: EventImportPlan?
    @State private var error: String?
    private var calendars: [RecordVersion] { model.store.records.filter { $0.kind == "calendar" && $0.value != nil } }

    var body: some View {
        Form {
            Section("Calendar for new events") {
                Picker("Calendar",selection:$calendarID) {
                    Text("Choose a calendar").tag("")
                    ForEach(calendars) { row in Text(row.value?.title ?? "Calendar").tag(row.id) }
                }.onChange(of:calendarID) { _,_ in plan = nil; error = nil }
                Text("Existing events stay in their current calendars. Pending edits and conflicts must be synced and resolved first.")
                Button("Preview import") { preview() }.disabled(calendarID.isEmpty)
            }
            if let plan {
                Section("Review changes") {
                    ForEach(plan.entries, id:\.graph.id) { entry in
                        VStack(alignment:.leading) {
                            Text(entry.graph.title.isEmpty ? "Untitled event" : entry.graph.title)
                            Text(entry.expected == .new ? "Add event" : "Replace event, reminders and exceptions").font(.caption)
                            Text(calendars.first(where:{ $0.id == entry.graph.text("calendar_id") })?.value?.title ?? "Calendar").font(.caption)
                        }
                    }
                    Text("Matching reminders keep their delivery device. New reminders notify on this iPhone.").font(.caption)
                }
                Button("Import reviewed changes") { commit(plan) }
            }
            if let error { Section { Text(error).foregroundStyle(.red).textSelection(.enabled) } }
        }.navigationTitle("Review calendar import")
        .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Cancel") { dismiss() } } }
    }

    private func preview() {
        do { plan = try model.store.previewEvents(sources,targetCalendarID:calendarID); error = nil }
        catch { plan = nil; self.error = error.localizedDescription }
    }
    private func commit(_ plan: EventImportPlan) {
        do {
            try model.store.importEvents(plan)
            Task { await model.reconcileReminders(); await model.sync() }
            dismiss()
        } catch { self.plan = nil; error = error.localizedDescription }
    }
}
