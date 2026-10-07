// User-initiated recovery exports. A live store uses SQLite's backup API; failed
// startup copies the closed database and all surviving WAL sidecars together.
// Copies stay in Documents for Files sharing and exclude Keychain credentials.
import Foundation
import SwiftUI

enum BuildIdentity {
    static var label: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "development"
        let build = info["CFBundleVersion"] as? String ?? "development"
        let source = info["TinkerSourceRevision"] as? String ?? "development"
        return "Tinker \(version) (\(build)) · \(source)"
    }
}

enum RecoveryFiles {
    static func directory() throws -> URL {
        let root = try FileManager.default.url(for:.documentDirectory,in:.userDomainMask,appropriateFor:nil,create:true)
        var result = root.appendingPathComponent("Tinker Recovery/" + UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:result,withIntermediateDirectories:true)
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try result.setResourceValues(values)
        return result
    }
    static func protect(_ url: URL) throws {
        try FileManager.default.setAttributes([.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication],ofItemAtPath:url.path)
    }
    /// Called only after startup has closed a rejected store. Never open, repair,
    /// checkpoint or replace the original; every surviving sidecar is retained.
    static func copyClosedStore() throws -> [URL] {
        let root = try FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:false)
        let source = root.appendingPathComponent("Tinker/companion.sqlite3")
        let destination = try directory()
        var files: [URL] = []
        for suffix in ["","-wal","-shm"] {
            let input = URL(fileURLWithPath:source.path + suffix)
            guard FileManager.default.fileExists(atPath:input.path) else { continue }
            let output = destination.appendingPathComponent(input.lastPathComponent)
            try FileManager.default.copyItem(at:input,to:output)
            try protect(output); files.append(output)
        }
        guard !files.isEmpty else { throw CompanionError("No preserved local database was found") }
        return files
    }
}

struct RecoveryExportView: View {
    let store: LocalStore?
    @State private var files: [URL] = []
    @State private var error: String?
    var body: some View {
        VStack(alignment:.leading) {
            Button("Prepare recovery copy") {
                do {
                    if let store { files = [try store.exportRecovery()] }
                    else { files = try RecoveryFiles.copyClosedStore() }
                    error = nil
                } catch { self.error = error.localizedDescription }
            }
            if !files.isEmpty { ShareLink(items:files) { Label("Save recovery files",systemImage:"square.and.arrow.up") } }
            Text("Recovery files contain your local content and pending edits. Save all files together to a location you trust. Pairing credentials stay in Keychain.").font(.caption)
            if let error { Text(error).foregroundStyle(.red) }
        }
    }
}
