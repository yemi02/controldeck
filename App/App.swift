import SwiftUI
import ServiceManagement

@main
struct ControlDeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = Engine()
    func applicationDidFinishLaunching(_ n: Notification) {
        try? SMAppService.mainApp.register()   // start helper at login
        engine.start()
    }
    func application(_ app: NSApplication, open urls: [URL]) { urls.forEach(engine.handle) }
}
