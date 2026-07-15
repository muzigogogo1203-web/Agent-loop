import Foundation
import UserNotifications
import os

@MainActor
final class ScheduledMissionNotifier {
    private let center: UNUserNotificationCenter
    private let logger = Logger(subsystem: "com.muzi.agentloop", category: "scheduled-notifications")
    private static let authorizationRequestedKey = "scheduledMissionNotificationAuthorizationRequested"

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    var canUseUserNotifications: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }

    func requestAuthorizationOnFirstScheduleEnable() async {
        guard canUseUserNotifications else { return }
        guard !UserDefaults.standard.bool(forKey: Self.authorizationRequestedKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.authorizationRequestedKey)
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            logger.error("notification authorization request failed: \(String(describing: error), privacy: .public)")
        }
    }

    func postCloseout(missionId: String, title: String) async {
        await post(
            missionId: missionId,
            title: "定时行动已收营",
            body: title
        )
    }

    func postFailure(missionId: String, title: String) async {
        await post(
            missionId: missionId,
            title: "定时行动受阻",
            body: title
        )
    }

    func postBudgetExhausted(missionId: String, title: String) async {
        await post(
            missionId: missionId,
            title: "定时行动预算用尽",
            body: title
        )
    }

    private func post(missionId: String, title: String, body: String) async {
        guard canUseUserNotifications else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["missionId": missionId]
        let request = UNNotificationRequest(
            identifier: "agentloop.scheduled.\(missionId).\(title)",
            content: content,
            trigger: nil
        )
        do {
            try await center.add(request)
        } catch {
            logger.error("posting scheduled notification failed: \(String(describing: error), privacy: .public)")
        }
    }
}
