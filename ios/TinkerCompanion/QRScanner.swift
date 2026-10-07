// On-device VisionKit QR capture; only explicit camera use starts the scanner.
// Simulator/unsupported camera states show a readable fallback. Recognized codes
// stay process-local and are passed to the pairing coordinator, never to a log.
import SwiftUI
import VisionKit
import Vision

struct QRScanner: View {
    let scanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    ScannerView(scanned:scanned).ignoresSafeArea(edges:.bottom)
                } else { ContentUnavailableView("Camera scanner unavailable",systemImage:"qrcode.viewfinder",description:Text("Allow camera access in iPhone Settings, or use Paste pairing QR text in Companion.")) }
            }.navigationTitle("Pair with Fedora").toolbar { ToolbarItem(placement:.cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

struct ScannerView: UIViewControllerRepresentable {
    let scanned: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(scanned:scanned) }
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(recognizedDataTypes:[.barcode(symbologies:[.qr])],qualityLevel:.balanced,recognizesMultipleItems:false,isHighFrameRateTrackingEnabled:false,isHighlightingEnabled:true)
        controller.delegate = context.coordinator
        do { try controller.startScanning() } catch { context.coordinator.error = error.localizedDescription }
        return controller
    }
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}
    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) { uiViewController.stopScanning() }
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let scanned: (String) -> Void
        var finished = false
        var error: String?
        init(scanned: @escaping (String) -> Void) { self.scanned = scanned }
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !finished else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let text = barcode.payloadStringValue {
                    finished = true; dataScanner.stopScanning(); scanned(text); return
                }
            }
        }
    }
}
