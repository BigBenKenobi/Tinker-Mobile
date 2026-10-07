// Application-owned coordination of local state, Keychain, Bonjour and foreground sync.
// SQLite edits remain available without a desktop/network. One serialized sync
// operation pulls, uploads immutable outbox batches, then pulls again. Status and
// errors remain visible; no retry can erase drafts or advance an uncommitted cursor.
import Foundation
import Network
import Combine

@MainActor final class AppModel: ObservableObject {
    let store: LocalStore
    let discovery = Discovery()
    let notifications: Notifications
    let isolated: Bool
    @Published private(set) var pairing: Pairing?
    @Published private(set) var connection = "Offline — local editing available"
    @Published private(set) var syncing = false
    @Published private(set) var syncFailure: String?
    @Published private(set) var hasCompletedSync = false
    /// A checkmark requires a successful sync on the current reachable connection.
    var cloudSyncStatus: CloudSyncState {
        if syncing { return .pending }
        if syncFailure != nil || !store.conflicts.isEmpty { return .error }
        if pairing == nil || !localNetwork { return .error }
        if store.pendingCount > 0 || !hasCompletedSync { return .pending }
        return .synced
    }
    @Published var error: String?
    private var active = false
    private var foregroundTask: Task<Void,Never>?
    private let monitor = NWPathMonitor()
    private var localNetwork = false
    private var subscriptions = Set<AnyCancellable>()

    init(store: LocalStore, isolated: Bool = false) throws {
        self.store = store; self.isolated = isolated
        notifications = Notifications(isolated:isolated)
        pairing = isolated ? nil : try PairingKeychain.load()
        store.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in:&subscriptions)
        discovery.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in:&subscriptions)
        notifications.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in:&subscriptions)
        guard !isolated else { return }
        monitor.pathUpdateHandler = { [weak self] path in
            let available = path.status == .satisfied && (path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet))
            Task { @MainActor in
                self?.localNetwork = available
                if !available { self?.hasCompletedSync = false }
                if self?.active == true { await self?.sync() }
            }
        }
        monitor.start(queue:DispatchQueue(label:"tinker-local-network"))
    }
    deinit { monitor.cancel(); foregroundTask?.cancel() }
    func foreground() {
        guard !isolated, !active else { return }; active = true; discovery.start()
        foregroundTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.sync()
                do { try await Task.sleep(for:.seconds(15)) } catch { return }
            }
        }
    }
    func background() {
        active = false; foregroundTask?.cancel(); foregroundTask = nil; discovery.stop()
    }
    func pair(qr: String) async {
        guard !isolated else { error = "Pairing is disabled in isolated tests"; return }
        guard !syncing else { return }; syncing = true; defer { syncing = false }
        do {
            let invitation = try JSONDecoder().decode(Invitation.self,from:Data(qr.utf8)); try invitation.validate()
            if let previous = try store.state("server_id"), previous != invitation.server_id { throw CompanionError("This local store belongs to another desktop. Keep it safe; use the same desktop for this milestone.") }
            let transport = try Transport(endpoint:invitation.endpoint,fingerprint:invitation.certificate_sha256,serverID:invitation.server_id)
            let body = try JSONSerialization.data(withJSONObject:["version":2,"code":invitation.code])
            let result = try await transport.request("/v2/pair",method:"POST",body:body,as:PairResponse.self)
            guard result.version == 2 else { throw CompanionError("Desktop protocol changed") }
            let paired = Pairing(server_id:result.server_id,endpoint:invitation.endpoint,certificate_sha256:invitation.certificate_sha256,peer_id:result.peer_id,credential:result.credential)
            try PairingKeychain.save(paired); pairing = paired; connection = "Paired — ready to sync"; error = nil
        } catch { self.error = error.localizedDescription }
        syncing = false
        await sync()
    }
    func unpair() async {
        guard !isolated else { return }
        guard !syncing else { error = "Wait for the current sync to finish before unpairing"; return }
        do {
            try PairingKeychain.remove(); pairing = nil; try store.resetSyncCursor(); await notifications.cancelAll()
            connection = "Unpaired — local edits retained"; error = nil; syncFailure = nil; hasCompletedSync = false
        } catch { self.error = error.localizedDescription }
    }
    func save(_ graph: Graph, observedRevision: Int? = nil) throws {
        try store.edit(graph,kind:graph.kind,id:graph.id,baseRevision:observedRevision)
        Task { await self.reconcileReminders(); await self.sync() }
    }
    func delete(_ row: RecordVersion) throws {
        try store.edit(nil,kind:row.kind,id:row.id,baseRevision:row.revision)
        Task { await self.reconcileReminders(); await self.sync() }
    }
    func reconcileReminders() async {
        guard !isolated else { return }
        // Unpaired installations may still schedule their own locally created
        // reminders. After unpair, synced reminders stay cancelled until enabled.
        if pairing == nil, (try? store.state("server_id")) != nil { await notifications.cancelAll(); return }
        do { try await notifications.reconcile(store.records) } catch { self.error = error.localizedDescription }
    }
    func sync() async {
        guard !isolated else { return }
        guard !syncing else { return }
        guard var paired = pairing else { connection = "Unpaired — local editing available"; return }
        guard localNetwork else { connection = "Offline — waiting for the same Wi-Fi network"; return }
        syncing = true; syncFailure = nil; connection = "Syncing…"; defer { syncing = false }
        do {
            if let discovered = discovery.endpoints[paired.server_id], discovered != paired.endpoint {
                // A discovery candidate is accepted only after pinned transport
                // succeeds. Saving a new address never weakens certificate trust.
                paired.endpoint = discovered
            }
            let transport = try Transport(endpoint:paired.endpoint,fingerprint:paired.certificate_sha256,serverID:paired.server_id,credential:paired.credential)
            if try store.cursor == nil {
                let snapshot = try await transport.request("/v2/snapshot",as:Snapshot.self); try store.apply(snapshot)
            } else { try await pull(transport) }
            // Limit each invocation to bounded work. Later foreground cycles drain
            // a large outbox without letting background refresh run indefinitely.
            for _ in 0..<10 {
                try Task.checkCancellation()
                let sent = try store.uploads(); if sent.isEmpty { break }
                struct Upload: Encodable { let version = 2; let mutations: [Mutation] }
                let response = try await transport.request("/v2/upload",method:"POST",body:JSONEncoder().encode(Upload(mutations:sent)),as:UploadResponse.self)
                try store.acknowledge(response,sent:sent)
            }
            try await pull(transport)
            try PairingKeychain.save(paired); pairing = paired
            connection = "Connected · " + Date().formatted(date:.omitted,time:.shortened); error = nil; syncFailure = nil; hasCompletedSync = true
            await reconcileReminders()
        } catch is CancellationError { connection = "Sync paused — edits saved locally" }
        catch { connection = "Disconnected — edits saved locally"; hasCompletedSync = false; syncFailure = error.localizedDescription; self.error = error.localizedDescription }
    }
    private func pull(_ transport: Transport) async throws {
        for _ in 0..<100 {
            try Task.checkCancellation()
            let cursor = try store.cursor ?? 0
            let page = try await transport.request("/v2/changes?after=\(cursor)",as:Changes.self)
            try store.apply(page)
            if !page.has_more { return }
        }
        throw CompanionError("Sync has more changes; continuing on the next foreground cycle")
    }
}
