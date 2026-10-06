// Shared read-only sync summary observes AppModel and its local store.
// Status, pending edits, conflicts and errors remain visible while offline;
// rendering this component never starts sync or writes a domain graph.
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

