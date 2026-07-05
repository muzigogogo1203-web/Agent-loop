import SwiftUI

@main
struct AgentLoopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup("AgentLoop") {
            RootView()
                .environment(store)
                .frame(minWidth: 1060, minHeight: 680)
                // 开发用：AGENTLOOP_FORCE_DARK=1 强制暗色（篝火夜景验证）
                .preferredColorScheme(
                    ProcessInfo.processInfo.environment["AGENTLOOP_FORCE_DARK"] == "1" ? .dark : nil
                )
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
