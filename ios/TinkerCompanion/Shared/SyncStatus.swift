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
            if let date = model.lastSuccessfulSync { Text("Last successful sync: " + date.formatted(date:.abbreviated,time:.standard)).font(.caption) }
            if let error = model.error { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
        }.font(.footnote).padding(.vertical,4).accessibilityElement(children:.combine)
    }
}


// Compact cloud indicator reads sync coordination and local pending/conflict state.
// The shell opens Companion for details; rendering never initiates network work.
enum CloudSyncState {
    case synced, pending, error
    var badge: String {
        switch self {
        case .synced: return "checkmark"
        case .pending: return "clock"
        case .error: return "exclamationmark"
        }
    }
    var label: String {
        switch self {
        case .synced: return "Last sync completed; desktop availability is checked on the next sync"
        case .pending: return "Pending syncs"
        case .error: return "Sync error or unavailable connection"
        }
    }
}
struct CloudSyncIndicator: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Image(systemName: "cloud").font(.system(size: 20, weight: .regular))
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: model.cloudSyncStatus.badge)
                    .font(.system(size: 8, weight: .bold))
                    .padding(3).background(.background, in: Circle())
                    .offset(x: 4, y: 3)
            }.accessibilityHidden(true)
    }
}
