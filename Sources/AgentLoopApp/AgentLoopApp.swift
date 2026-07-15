import SwiftUI
@preconcurrency import UserNotifications
import AgentLoopCore

@main
struct AgentLoopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var store = AppStore()

    init() {
        BoardServerBridgeMain.exitIfRequested()
    }

    var body: some Scene {
        WindowGroup("Coding 牧场") {
            RootView()
                .environment(store)
                .frame(minWidth: 640, minHeight: 680)
                .onAppear {
                    delegate.configure(
                        emergencyStopAction: { store.emergencyStopCamp() },
                        openMissionAction: { missionId in
                            store.selectMission(missionId)
                            store.navigateToMissionId = missionId
                        },
                        nextScheduleTitle: { store.nextScheduleMenuTitle() }
                    )
                }
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

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate {
    static let menuBarResidencyDefaultsKey = "menuBarResidencyEnabled"

    private var statusItem: NSStatusItem?
    private var emergencyStopAction: (() -> Void)?
    private var openMissionAction: ((String) -> Void)?
    private var nextScheduleTitle: (() -> String)?

    var menuBarResidencyEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.menuBarResidencyDefaultsKey)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        UNUserNotificationCenter.current().delegate = self
        refreshMenuBarResidency()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !menuBarResidencyEnabled
    }

    func configure(
        emergencyStopAction: @escaping () -> Void,
        openMissionAction: @escaping (String) -> Void,
        nextScheduleTitle: @escaping () -> String
    ) {
        self.emergencyStopAction = emergencyStopAction
        self.openMissionAction = openMissionAction
        self.nextScheduleTitle = nextScheduleTitle
        refreshMenuBarResidency()
    }

    func setMenuBarResidencyEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.menuBarResidencyDefaultsKey)
        refreshMenuBarResidency()
    }

    func refreshMenuBarResidency() {
        if menuBarResidencyEnabled {
            ensureStatusItem()
        } else {
            if let statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
            statusItem = nil
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildStatusMenu()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        if let missionId = response.notification.request.content.userInfo["missionId"] as? String {
            await openMissionFromNotification(missionId)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    private func openMissionFromNotification(_ missionId: String) {
        openMissionAction?(missionId)
        openRanch()
    }

    private func ensureStatusItem() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItem?.button?.image = NSImage(
                systemSymbolName: "flame.fill",
                accessibilityDescription: "Coding 牧场"
            )
            statusItem?.button?.imagePosition = .imageOnly
        }
        rebuildStatusMenu()
    }

    private func rebuildStatusMenu() {
        guard let statusItem else { return }
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(NSMenuItem(title: "打开牧场", action: #selector(openRanch), keyEquivalent: ""))
        let next = NSMenuItem(title: nextScheduleTitle?() ?? "下次日程：暂无", action: nil, keyEquivalent: "")
        next.isEnabled = false
        menu.addItem(next)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "紧急收哨", action: #selector(emergencyStop), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func openRanch() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func emergencyStop() {
        emergencyStopAction?()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
