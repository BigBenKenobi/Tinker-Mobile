// SwiftUI app entry point and best-effort BGAppRefresh lifecycle.
// LocalStore creation fails visibly without replacing a damaged database. Scene
// transitions start/stop active sync; iOS chooses whether/when refresh tasks run.
// No background socket/listener or remote account is required for offline editing.
import SwiftUI
import BackgroundTasks
import UIKit

@main struct TinkerCompanionApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var bootstrap = Bootstrap()
    var body: some Scene {
        WindowGroup {
            if let model = bootstrap.model {
                RootView(model:model).onAppear { AppDelegate.model = model; model.foreground(); Task { await model.reconcileReminders() } }
                    .onChange(of:scenePhase) { _,phase in
                        if phase == .active { model.foreground() }
                        else if phase == .background { model.background(); AppDelegate.scheduleRefresh() }
                    }
            } else {
                ContentUnavailableView("Tinker could not open local data",systemImage:"externaldrive.badge.exclamationmark",description:Text(bootstrap.error ?? "Unknown startup error. The database has been preserved."))
            }
        }
    }
}

/// App-created startup owner; optional model keeps failures recoverable and observable.
@MainActor final class Bootstrap: ObservableObject {
    let model: AppModel?
    let error: String?
    init() {
        do {
            let root = try FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true)
            model = try AppModel(store:LocalStore(path:root.appendingPathComponent("Tinker/companion.sqlite3")))
            error = nil
            AppDelegate.model = model
        } catch { model = nil; self.error = error.localizedDescription }
    }
}

@MainActor final class AppDelegate: NSObject, UIApplicationDelegate {
    static weak var model: AppModel?
    static let refreshID = "com.bigbenkenobi.tinker.refresh"
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey:Any]? = nil) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier:Self.refreshID,using:nil) { task in
            guard let refresh = task as? BGAppRefreshTask else { task.setTaskCompleted(success:false); return }
            let operation = Task { @MainActor in
                guard let model = Self.model else { refresh.setTaskCompleted(success:false); return }
                await model.sync(); await model.reconcileReminders()
                refresh.setTaskCompleted(success:!Task.isCancelled && model.error == nil)
                Self.scheduleRefresh()
            }
            refresh.expirationHandler = { operation.cancel() }
        }
        return true
    }
    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier:refreshID)
        request.earliestBeginDate = Date().addingTimeInterval(15*60)
        do { try BGTaskScheduler.shared.submit(request) }
        catch { /* Foreground synchronization remains available when iOS declines refresh. */ }
    }
}
