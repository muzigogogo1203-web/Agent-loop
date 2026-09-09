import Foundation
import AgentLoopCore
import AgentLoopApplication

struct ScheduleCatchup: Identifiable, Equatable, Sendable {
    var id: String { fireId }
    let fireId: String
    let scheduleId: String
    let templateId: String
    let fireDate: Date
    let reason: String
    let title: String
}

@MainActor
final class MissionScheduler {
    private var activitySchedulers:
        [String: NSBackgroundActivityScheduler] = [:]
    private var desiredRegistrations:
        [String: ScheduleActivityRegistration] = [:]
    private var started = false

    var onFire:
        (@Sendable (
            ScheduleFireRequest,
            @escaping @Sendable () -> Void
        ) -> Void)?

    func start() {
        guard !started else { return }
        started = true
        buildAndSwap(Array(desiredRegistrations.values))
    }

    func stop() {
        guard started else { return }
        started = false
        let previous = activitySchedulers
        activitySchedulers = [:]
        for scheduler in previous.values {
            scheduler.invalidate()
        }
    }

    func registrationPort() -> ScheduleRegistrationPort {
        ScheduleRegistrationPort { [weak self] registrations in
            guard let self else {
                throw SchedulePlatformFailure.registration
            }
            return try self.replaceAll(registrations)
        }
    }

    private func replaceAll(
        _ registrations: [ScheduleActivityRegistration]
    ) throws -> ScheduleRegistrationReceipt {
        var validated: [String: ScheduleActivityRegistration] = [:]
        for registration in registrations {
            guard validated[registration.scheduleId] == nil else {
                throw SchedulePlatformFailure.registration
            }
            validated[registration.scheduleId] = registration
        }
        if started {
            buildAndSwap(registrations)
        } else {
            desiredRegistrations = validated
        }
        return ScheduleRegistrationReceipt(
            registeredScheduleIds: validated.keys.sorted()
        )
    }

    private func buildAndSwap(
        _ registrations: [ScheduleActivityRegistration]
    ) {
        let fireHandler = onFire
        var nextDesired: [String: ScheduleActivityRegistration] = [:]
        var nextSchedulers: [String: NSBackgroundActivityScheduler] = [:]
        var scheduled:
            [(ScheduleActivityRegistration, NSBackgroundActivityScheduler)] = []
        for registration in registrations {
            nextDesired[registration.scheduleId] = registration
            let scheduler = makeActivityScheduler(registration)
            nextSchedulers[registration.scheduleId] = scheduler
            scheduled.append((registration, scheduler))
        }

        let previous = activitySchedulers
        desiredRegistrations = nextDesired
        activitySchedulers = nextSchedulers
        for scheduler in previous.values {
            scheduler.invalidate()
        }
        for (registration, scheduler) in scheduled {
            scheduler.schedule { completion in
                guard let fireHandler else {
                    completion(.finished)
                    return
                }
                fireHandler(registration.request) {
                    completion(.finished)
                }
            }
        }
    }

    private func makeActivityScheduler(
        _ registration: ScheduleActivityRegistration
    ) -> NSBackgroundActivityScheduler {
        let scheduler = NSBackgroundActivityScheduler(
            identifier:
                "com.muzi.agentloop.schedule.\(registration.scheduleId)"
        )
        scheduler.repeats = false
        scheduler.interval = max(
            1,
            registration.request.context.scheduledAt.timeIntervalSinceNow
        )
        scheduler.tolerance = 300
        scheduler.qualityOfService = .utility
        return scheduler
    }
}
