// Native iPhone Notes, Tasks, Calendar, conflicts and pairing presentation.
// Screens observe AppModel's SQLite state. Editors hold independent graph drafts
// and close only after successful local commits; network availability never gates
// ordinary editing. Files/QR/notification permissions are requested in context.
import SwiftUI
import UniformTypeIdentifiers

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
                    Button("Scan desktop pairing QR") { scanning = true }.disabled(model.isolated)
                    DisclosureGroup("Paste pairing QR text") {
                        TextEditor(text:$qr).frame(minHeight:100).textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button("Pair") { let code = qr; qr = ""; Task { await model.pair(qr:code) } }.disabled(model.syncing)
                    }
                }
                Text("Open Tinker on Fedora, enable local sync on its LAN address, then show its pairing QR. Both devices must be on the same network.").font(.caption).foregroundStyle(.secondary)
            }.phoneSection()
            Section("Reminders") {
                Text(model.notifications.status)
                Button("Enable iPhone notifications") { Task { await model.notifications.authorize(); await model.reconcileReminders() } }
            }.phoneSection()
            Section("Pending edits") {
                switch Result(catching:{ try model.store.uploads() }) {
                case .success(let edits):
                    if edits.isEmpty { Text("No pending edits").foregroundStyle(.secondary) }
                    ForEach(edits,id:\.op_id) { edit in
                        VStack(alignment:.leading) {
                            Text(edit.value?.title ?? "Deleted " + edit.kind)
                            Text(edit.kind + " · base revision " + String(edit.base_revision)).font(.caption)
                        }
                    }
                    if model.store.pendingCount > 100 { Text("Showing the next 100 edits. Remaining edits sync in subsequent batches.").font(.caption) }
                case .failure(let error): Text(error.localizedDescription).foregroundStyle(.red)
                }
            }.phoneSection()
            Section("Conflicts · \(model.store.conflicts.count)") {
                if model.store.conflicts.isEmpty { Text("No conflicts").foregroundStyle(.secondary) }
                ForEach(model.store.conflicts) { conflict in NavigationLink { ConflictView(model:model,conflict:conflict) } label: { Text(conflict.current?.title ?? conflict.incoming?.title ?? "Deleted item") } }
            }.phoneSection()
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
            }.phoneSection()
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
        }.phoneSection()
    }
    private func resolve(_ incoming: Bool) {
        do { try model.store.resolve(conflict,useIncoming:incoming); Task { await model.sync() }; dismiss() }
        catch { model.error = error.localizedDescription }
    }
}
