import SwiftUI

@main
struct AgentLoopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup("Coding 牧场") {
            RootView()
                .environment(store)
                .frame(minWidth: 640, minHeight: 680)
                .onOpenURL { url in
                    store.handleOAuthCallback(url)
                }
                // 开发用：AGENTLOOP_FORCE_DARK=1 强制暗色（篝火夜景验证）
                .preferredColorScheme(
                    ProcessInfo.processInfo.environment["AGENTLOOP_FORCE_DARK"] == "1" ? .dark : nil
                )
        }
        .commands {
            CommandMenu("放牛任务") {
                Button {
                    store.emergencyStopCamp()
                } label: {
                    if store.haltPersistencePending {
                        Text("重试保存停营")
                    } else if store.haltOperationState == .stopping {
                        Text("正在收哨…")
                    } else if store.haltOperationState == .resuming {
                        Text("正在恢复…")
                    } else {
                        Text("紧急收哨")
                    }
                }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(!store.canRequestEmergencyStop)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
