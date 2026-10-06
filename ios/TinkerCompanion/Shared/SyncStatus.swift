// Native iPhone Notes, Tasks, Calendar, conflicts and pairing presentation.
// Screens observe AppModel's SQLite state. Editors hold independent graph drafts
// and close only after successful local commits; network availability never gates
// ordinary editing. Files/QR/notification permissions are requested in context.
import SwiftUI
import UniformTypeIdentifiers

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

