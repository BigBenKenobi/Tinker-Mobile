// Pairing identity and certificate-pinned local transport.
// AppModel owns one Keychain-backed pairing and each short-lived transport. The
// QR supplies a two-minute code and desktop certificate fingerprint out of band.
// Bonjour changes an address only; it never establishes trust. Redirects, public
// endpoints and a different desktop identity/certificate are rejected.
import Foundation
import Security
import CryptoKit

struct Invitation: Codable {
    let version: Int
    let server_id: String
    let endpoint: String
    let certificate_sha256: String
    let code: String
    let expires_at: Int
    func validate() throws {
        guard version == 2, expires_at > Int(Date().timeIntervalSince1970), expires_at <= Int(Date().timeIntervalSince1970) + 180,
              certificate_sha256.range(of:"^[a-f0-9]{64}$",options:.regularExpression) != nil,
              (20...200).contains(code.count) else { throw CompanionError("Pairing QR is invalid or expired") }
        try Graph.identifier(server_id); _ = try LocalEndpoint.validate(endpoint)
    }
}
struct Pairing: Codable {
    var server_id: String
    var endpoint: String
    var certificate_sha256: String
    var peer_id: String
    var credential: String
}
struct PairResponse: Codable { let version: Int; let server_id: String; let peer_id: String; let credential: String }

enum LocalEndpoint {
    static func validate(_ endpoint: String) throws -> URL {
        guard let parts = URLComponents(string:endpoint), parts.scheme == "https", let host = parts.host, let port = parts.port,
              (1...65535).contains(port), parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              parts.path.isEmpty, let url = parts.url else { throw CompanionError("Expected a local HTTPS endpoint") }
        let pieces = host.split(separator:".",omittingEmptySubsequences:false)
        guard pieces.count == 4 else { throw CompanionError("Pairing requires a local IPv4 address") }
        let bytes = pieces.compactMap { Int($0) }
        guard bytes.count == 4, bytes.allSatisfy({ (0...255).contains($0) }),
              bytes.map(String.init).joined(separator:".") == host else { throw CompanionError("Invalid IPv4 address") }
        let local = bytes[0] == 10 || (bytes[0] == 172 && (16...31).contains(bytes[1])) || (bytes[0] == 192 && bytes[1] == 168) || (bytes[0] == 169 && bytes[1] == 254)
        guard local else { throw CompanionError("Sync works only on your local network") }
        return url
    }
}

/// App-owned Keychain item; device-only accessibility prevents cloud/backups from copying the bearer.
enum PairingKeychain {
    private static let query: [String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"com.bigbenkenobi.tinker.companion",kSecAttrAccount as String:"desktop-pairing"]
    static func load() throws -> Pairing? {
        var q = query; q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?; let status = SecItemCopyMatching(q as CFDictionary,&value)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = value as? Data else { throw CompanionError("Keychain could not load desktop pairing") }
        return try JSONDecoder().decode(Pairing.self,from:data)
    }
    static func save(_ pairing: Pairing) throws {
        let data = try JSONEncoder().encode(pairing)
        let updated = SecItemUpdate(query as CFDictionary,[kSecValueData as String:data] as CFDictionary)
        if updated == errSecSuccess { return }
        guard updated == errSecItemNotFound else { throw CompanionError("Keychain could not update desktop pairing") }
        var q = query; q[kSecValueData as String] = data; q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(q as CFDictionary,nil) == errSecSuccess else { throw CompanionError("Keychain could not save desktop pairing") }
    }
    static func remove() throws {
        let result = SecItemDelete(query as CFDictionary)
        guard result == errSecSuccess || result == errSecItemNotFound else { throw CompanionError("Keychain could not remove pairing") }
    }
}

/// URLSession authenticates a self-signed server by the exact QR-pinned DER certificate.
final class PinnedSession: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    private let fingerprint: String
    private let host: String
    init(fingerprint: String, host: String) { self.fingerprint = fingerprint; self.host = host }
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host == host, let trust = challenge.protectionSpace.serverTrust,
              let certificates = SecTrustCopyCertificateChain(trust) as? [SecCertificate], certificates.count == 1 else { completionHandler(.cancelAuthenticationChallenge,nil); return }
        let digest = SHA256.hash(data:SecCertificateCopyData(certificates[0]) as Data).map { String(format:"%02x",$0) }.joined()
        guard digest == fingerprint else { completionHandler(.cancelAuthenticationChallenge,nil); return }
        // Trust only the pinned certificate, retaining expiration/signature checks.
        SecTrustSetAnchorCertificates(trust,[certificates[0]] as CFArray)
        SecTrustSetAnchorCertificatesOnly(trust,true)
        SecTrustSetPolicies(trust,SecPolicyCreateBasicX509())
        guard SecTrustEvaluateWithError(trust,nil) else { completionHandler(.cancelAuthenticationChallenge,nil); return }
        completionHandler(.useCredential,URLCredential(trust:trust))
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

/// Each sync operation owns an ephemeral session; no bearer goes into URLs/cookies/logs.
final class Transport {
    private let base: URL
    private let serverID: String
    private let credential: String?
    private let session: URLSession
    private let delegate: PinnedSession
    init(endpoint: String, fingerprint: String, serverID: String, credential: String? = nil) throws {
        base = try LocalEndpoint.validate(endpoint); self.serverID = serverID; self.credential = credential
        delegate = PinnedSession(fingerprint:fingerprint,host:base.host!)
        let config = URLSessionConfiguration.ephemeral; config.timeoutIntervalForRequest = 10; config.timeoutIntervalForResource = 20
        config.httpCookieStorage = nil; config.urlCache = nil; config.waitsForConnectivity = false
        session = URLSession(configuration:config,delegate:delegate,delegateQueue:nil)
    }
    deinit { session.invalidateAndCancel() }
    func request<T: Decodable>(_ path: String, method: String = "GET", body: Data? = nil, as type: T.Type) async throws -> T {
        guard let url = URL(string:base.absoluteString + path), url.host == base.host else { throw CompanionError("Invalid local request") }
        var request = URLRequest(url:url); request.httpMethod = method; request.httpBody = body
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        if let credential { request.setValue("Bearer " + credential,forHTTPHeaderField:"Authorization") }
        let (data,response) = try await session.data(for:request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw CompanionError(status == 401 ? "Desktop pairing rejected. Your offline edits are still saved." : "Desktop sync failed (\(status)). Your offline edits are still saved.")
        }
        guard data.count <= 32 * 1024 * 1024 else { throw CompanionError("Desktop response exceeds the milestone limit") }
        try Self.validateEnvelope(data, serverID:serverID)
        return try JSONDecoder().decode(type,from:data)
    }
    static func validateEnvelope(_ data: Data, serverID: String) throws {
        let envelope = try JSONSerialization.jsonObject(with:data) as? [String:Any]
        guard envelope?["version"] as? Int == 2, envelope?["server_id"] as? String == serverID else {
            throw CompanionError("Desktop identity/version mismatch")
        }
    }
}
