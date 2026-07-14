import Foundation
import AgentLoopCore
import os

struct ScheduleCatchup: Identifiable, Equatable, Sendable {
    var id: String { scheduleId }
    let scheduleId: String
    let templateId: String
    let fireDate: Date
    let reason: String
}

@MainActor
final class MissionScheduler {
    private let db: AppDatabase
    private let orchestrator: Orchestrator
    private let notifier: ScheduledMissionNotifier
    private let plannerModel: @MainActor () -> String
    private let logger = Logger(subsystem: "com.muzi.agentloop", category: "mission-scheduler")
    private var activitySchedulers: [String: NSBackgroundActivityScheduler] = [:]
    private var started = false

    private var calendar: Calendar {
        Calendar(identifier: .gregorian)
    }

    private var timeZone: TimeZone {
        .current
    }

    private(set) var pendingCatchups: [ScheduleCatchup] = []
    var onPendingCatchupsChanged: (@MainActor ([ScheduleCatchup]) -> Void)?
    var onScheduleFired: (@MainActor (String) -> Void)?

    init(
        db: AppDatabase,
        orchestrator: Orchestrator,
        notifier: ScheduledMissionNotifier,
        plannerModel: @escaping @MainActor () -> String
    ) {
        self.db = db
        self.orchestrator = orchestrator
        self.notifier = notifier
        self.plannerModel = plannerModel
    }

    func start() {
        guard !started else { return }
        started = true
        checkStartupMisfires()
        refresh()
    }

    func stop() {
        started = false
        for scheduler in activitySchedulers.values {
            scheduler.invalidate()
        }
        activitySchedulers.removeAll()
    }

    func refresh() {
        guard started else { return }
        let enabled: [EnabledScheduleRecord]
        do {
            enabled = try db.enabledSchedules()
        } catch {
            logger.error("failed to load enabled schedules: \(String(describing: error), privacy: .public)")
            return
        }

        let liveIds = Set(enabled.map(\.schedule.id))
        for id in activitySchedulers.keys where !liveIds.contains(id) {
            activitySchedulers[id]?.invalidate()
            activitySchedulers[id] = nil
        }
        for item in enabled {
            register(item)
        }
    }

    private func register(_ item: EnabledScheduleRecord) {
        guard let next = ScheduleMath.nextFireDate(
            after: Date(),
            frequency: item.schedule.frequency,
            hour: item.schedule.hour,
            minute: item.schedule.minute,
            weekday: item.schedule.weekday,
            calendar: calendar,
            timeZone: timeZone
        ) else {
            logger.error("invalid schedule math for schedule \(item.schedule.id, privacy: .public)")
            return
        }

        activitySchedulers[item.schedule.id]?.invalidate()
        let scheduler = NSBackgroundActivityScheduler(
            identifier: "com.muzi.agentloop.schedule.\(item.schedule.id)"
        )
        scheduler.repeats = false
        scheduler.interval = max(1, next.timeIntervalSinceNow)
        scheduler.tolerance = 300
        scheduler.qualityOfService = .utility
        scheduler.schedule { [weak self] completion in
            Task { @MainActor in
                guard let self else {
                    completion(.finished)
                    return
                }
                await self.fire(scheduleId: item.schedule.id, scheduledFireDate: next)
                completion(.finished)
                self.refresh()
            }
        }
        activitySchedulers[item.schedule.id] = scheduler
    }

    private func checkStartupMisfires(now: Date = Date()) {
        let enabled: [EnabledScheduleRecord]
        do {
            enabled = try db.enabledSchedules()
        } catch {
            logger.error("failed to load schedules for misfire check: \(String(describing: error), privacy: .public)")
            return
        }

        var catchups: [ScheduleCatchup] = []
        for item in enabled {
            guard let missed = ScheduleMath.missedFireDate(
                now: now,
                createdAt: item.schedule.createdAt,
                lastFiredAt: item.schedule.lastFiredAt,
                frequency: item.schedule.frequency,
                hour: item.schedule.hour,
                minute: item.schedule.minute,
                weekday: item.schedule.weekday,
                calendar: calendar,
                timeZone: timeZone
            ) else {
                continue
            }
            let reason = "上一次计划触发点未执行"
            do {
                try db.recordScheduleMissed(
                    scheduleId: item.schedule.id,
                    templateId: item.template.id,
                    missedFireDate: missed,
                    reason: reason
                )
            } catch {
                logger.error("failed to record schedule_missed: \(String(describing: error), privacy: .public)")
            }
            catchups.append(
                ScheduleCatchup(
                    scheduleId: item.schedule.id,
                    templateId: item.template.id,
                    fireDate: missed,
                    reason: reason
                )
            )
        }
        pendingCatchups = catchups
        onPendingCatchupsChanged?(catchups)
    }

    private func fire(scheduleId: String, scheduledFireDate: Date) async {
        let schedule: ScheduleRecord
        let template: MissionTemplateRecord
        do {
            guard let loadedSchedule = try db.schedule(id: scheduleId) else { return }
            guard loadedSchedule.enabled else { return }
            guard let loadedTemplate = try db.missionTemplate(id: loadedSchedule.templateId) else {
                try db.recordScheduleMissed(
                    scheduleId: loadedSchedule.id,
                    templateId: loadedSchedule.templateId,
                    missedFireDate: scheduledFireDate,
                    reason: "日程引用的模板不存在"
                )
                return
            }
            schedule = loadedSchedule
            template = loadedTemplate
        } catch {
            logger.error("failed to load schedule \(scheduleId, privacy: .public): \(String(describing: error), privacy: .public)")
            return
        }

        let budgetTokens: Int
        let companionIds: [String]
        do {
            budgetTokens = try template.validateForScheduledMission()
            companionIds = try template.companionIds()
            guard try db.camp(id: template.campId) != nil else {
                throw RecordNotFoundError(table: "camp", id: template.campId)
            }
            _ = try db.companions(ids: companionIds)
        } catch {
            await recordMissed(
                schedule: schedule,
                template: template,
                fireDate: scheduledFireDate,
                reason: readableError(error)
            )
            return
        }

        do {
            guard try db.claimScheduleFire(
                scheduleId: schedule.id,
                fireDate: scheduledFireDate,
                calendar: calendar,
                timeZone: timeZone
            ) else {
                return
            }
            let missionId = try await orchestrator.startMission(
                goal: template.goal,
                companionIds: companionIds,
                workspacePath: template.workspacePath,
                plannerModel: plannerModel(),
                budgetTokens: budgetTokens,
                campId: template.campId,
                autonomy: template.autonomy
            )
            try db.appendScheduleFiredEvent(
                scheduleId: schedule.id,
                templateId: template.id,
                missionId: missionId,
                firedAt: scheduledFireDate
            )
            try db.appendGuideBroadcast(
                campId: template.campId,
                text: "定时行动「\(template.name)」已出发：\(template.goal)"
            )
            onScheduleFired?(missionId)
        } catch {
            await recordMissed(
                schedule: schedule,
                template: template,
                fireDate: scheduledFireDate,
                reason: readableError(error)
            )
        }
    }

    private func recordMissed(
        schedule: ScheduleRecord,
        template: MissionTemplateRecord,
        fireDate: Date,
        reason: String
    ) async {
        do {
            try db.recordScheduleMissed(
                scheduleId: schedule.id,
                templateId: template.id,
                missedFireDate: fireDate,
                reason: reason
            )
            _ = try? db.appendGuideBroadcast(
                campId: template.campId,
                text: "定时行动「\(template.name)」没有出发：\(reason)"
            )
        } catch {
            logger.error("failed to record missed schedule \(schedule.id, privacy: .public): \(String(describing: error), privacy: .public)")
        }
    }

    private func readableError(_ error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return String(describing: error)
    }
}
