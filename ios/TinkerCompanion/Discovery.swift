// Bonjour resolves a paired desktop after DHCP changes. Discovery supplies only
// candidates; SyncCoordinator still requires the stored certificate and server ID.
import Foundation
import Darwin

@MainActor final class Discovery: NSObject, ObservableObject, NetServiceBrowserDelegate, NetServiceDelegate {
    @Published private(set) var endpoints: [String:String] = [:]
    private let browser = NetServiceBrowser()
    private var services: [NetService] = []
    override init() { super.init(); browser.delegate = self }
    func start() { browser.searchForServices(ofType:"_tinker._tcp.",inDomain:"local.") }
    func stop() { browser.stop(); services.forEach { $0.stop() }; services.removeAll(); endpoints.removeAll() }
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        services.append(service); service.delegate = self; service.resolve(withTimeout:5)
    }
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        endpoints.removeValue(forKey:service.name); services.removeAll { $0 == service }
    }
    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let addresses = sender.addresses else { return }
        for data in addresses {
            var hostname = [CChar](repeating:0,count:Int(NI_MAXHOST))
            let status = data.withUnsafeBytes { buffer -> Int32 in
                guard let address = buffer.baseAddress?.assumingMemoryBound(to:sockaddr.self) else { return -1 }
                return getnameinfo(address,socklen_t(data.count),&hostname,socklen_t(hostname.count),nil,0,NI_NUMERICHOST)
            }
            guard status == 0 else { continue }
            let endpoint = "https://" + String(cString:hostname) + ":" + String(sender.port)
            if (try? LocalEndpoint.validate(endpoint)) != nil { endpoints[sender.name] = endpoint; return }
        }
    }
}
