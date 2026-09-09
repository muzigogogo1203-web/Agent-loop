import Foundation
import UserNotifications
import AgentLoopCore
import AgentLoopApplication

@MainActor
final class ScheduledMissionNotifier {
    private let center: UNUserNotificationCenter
    private static let authorizationRequestedKey = "scheduledMissionNotificationAuthorizationRequested"

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    var canUseUserNotifications: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }

    func requestAuthorization() async throws -> ScheduleAuthorizationReceipt {
        guard canUseUserNotifications else {
            return ScheduleAuthorizationReceipt(disposition: .unavailable)
        }
        guard !UserDefaults.standard.bool(
            forKey: Self.authorizationRequestedKey
        ) else {
            return ScheduleAuthorizationReceipt(
                disposition: .alreadyRequested
            )
        }
        UserDefaults.standard.set(true, forKey: Self.authorizationRequestedKey)
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .sound]
            )
            return ScheduleAuthorizationReceipt(
                disposition: granted ? .granted : .denied
            )
        } catch {
            throw SchedulePlatformFailure.authorization
        }
    }

    func submit(
        _ request: ScheduleNotificationRequest
    ) async throws -> ScheduleNotificationReceipt {
        guard canUseUserNotifications else {
            return ScheduleNotificationReceipt(
                notificationId: request.notificationId,
                disposition: .unavailable
            )
        }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
        else {
            return ScheduleNotificationReceipt(
                notificationId: request.notificationId,
                disposition: .notAuthorized
            )
        }
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        content.userInfo = ["missionId": request.missionId]
        let platformRequest = UNNotificationRequest(
            identifier: request.notificationId,
            content: content,
            trigger: nil
        )
        do {
            try await center.add(platformRequest)
            return ScheduleNotificationReceipt(
                notificationId: request.notificationId,
                disposition: .submitted
            )
        } catch {
            throw SchedulePlatformFailure.notificationSubmission
        }
    }

    func port() -> ScheduleNotificationPort {
        ScheduleNotificationPort(
            requestAuthorization: { [weak self] in
                guard let self else {
                    throw SchedulePlatformFailure.authorization
                }
                return try await self.requestAuthorization()
            },
            submit: { [weak self] request in
                guard let self else {
                    throw SchedulePlatformFailure.notificationSubmission
                }
                return try await self.submit(request)
            }
        )
    }
}
