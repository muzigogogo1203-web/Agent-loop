/// 事件 kind 常量（M6-D2）。kind 是落库的持久化契约：常量值一经发布不可更改。
/// 测试断言刻意保留裸字符串（不用这些常量），钉住持久化值——常量被误改时测试必须变红。
public enum EventKind {
    // 小目标
    public static let cardStarted = "card_started"
    public static let cardCompleted = "card_completed"
    public static let cardBlocked = "card_blocked"
    public static let cardReady = "card_ready"
    public static let cardCanceled = "card_canceled"
    public static let cardInterrupted = "card_interrupted"

    // 行动
    public static let missionCreated = "mission_created"
    public static let missionStatusChanged = "mission_status_changed"
    public static let missionAccepted = "mission_accepted"
    public static let missionFailed = "mission_failed"
    public static let missionBudgetExhausted = "mission_budget_exhausted"

    // 规划
    public static let planStarted = "plan_started"
    public static let planCompleted = "plan_completed"
    public static let planNoop = "plan_noop"
    public static let planFallback = "plan_fallback"
    public static let planningTokens = "planning_tokens"
    public static let planningUsageOverflow = "planning_usage_overflow"

    // 执行与内核
    public static let runError = "run_error"
    public static let progressNote = "progress_note"
    public static let kernelError = "kernel_error"
    public static let budgetAdded = "budget_added"

    // 哨卡（M7）：审批 / 档位 / 收哨 / 限流
    public static let approvalRequested = "approval_requested"
    public static let approvalDecided = "approval_decided"
    public static let autonomyChanged = "autonomy_changed"
    public static let campHalted = "camp_halted"
    public static let campResumed = "camp_resumed"
    public static let rateLimitCooldown = "rate_limit_cooldown"

    // 人工门与提案
    public static let userRequestCreated = "user_request_created"
    public static let userRequestAnswered = "user_request_answered"
    public static let squadProposalConfirmed = "squad_proposal_confirmed"

    // 知识层
    public static let campNoteCreated = "camp_note_created"
    public static let companionNoteCreated = "companion_note_created"

    // Coding 牧场产品层
    public static let baseCowProvisioned = "base_cow_provisioned"
    public static let ingestionCreated = "ingestion_created"
    public static let ruminationCompleted = "rumination_completed"
    public static let ruminationFailed = "rumination_failed"
    public static let ruminationMaterialized = "rumination_materialized"
    public static let actionCandidateConverted = "action_candidate_converted"
    public static let cowUnlocked = "cow_unlocked"

    // 驿路（M8）：MCP server 停摆（挂在受影响行动上，UI 可渲染）
    public static let mcpServerDown = "mcp_server_down"

    // 归营清点（M9）：退回重做 / 待复核 / 营地归档
    public static let cardReturned = "card_returned"
    public static let cardReviewCleared = "card_review_cleared"
    public static let campArchived = "camp_archived"

    // 长明火（M10）：定时行动触发 / 错过
    public static let scheduleFired = "schedule_fired"
    public static let scheduleMissed = "schedule_missed"

    public static let allPersistedKinds: Set<String> = [
        cardStarted, cardCompleted, cardBlocked, cardReady, cardCanceled,
        cardInterrupted, missionCreated, missionStatusChanged, missionAccepted,
        missionFailed, missionBudgetExhausted, planStarted, planCompleted,
        planNoop, planFallback, planningTokens, planningUsageOverflow,
        runError, progressNote, kernelError, budgetAdded, approvalRequested,
        approvalDecided, autonomyChanged, campHalted, campResumed,
        rateLimitCooldown, userRequestCreated, userRequestAnswered,
        squadProposalConfirmed, campNoteCreated, companionNoteCreated,
        baseCowProvisioned, ingestionCreated, ruminationCompleted,
        ruminationFailed, ruminationMaterialized, actionCandidateConverted,
        cowUnlocked, mcpServerDown, cardReturned, cardReviewCleared,
        campArchived, scheduleFired, scheduleMissed,
    ]
}
// P1-C-BEGIN ControlContractVocabulary
package enum P1AggregateTypeV1: String, Codable, Sendable, Equatable, CaseIterable {
    case input
    case goal
    case coachSession
    case understanding
    case engineExecution = "engine_execution"
}

package enum P1CommandTypeV1: String, Codable, Sendable, Equatable, CaseIterable {
    case inputCapture = "input.capture.v1"
    case inputParseResult = "input.parse-result.v1"
    case inputParseFailure = "input.parse-failure.v1"
    case inputRequeueParsing = "input.requeue-parsing.v1"
    case inputCancelParsingAndDelete = "input.cancel-parsing-and-delete.v1"
    case inputRequestCampAssignment = "input.request-camp-assignment.v1"
    case inputRecordCampAmbiguity = "input.record-camp-ambiguity.v1"
    case inputAssignCamp = "input.assign-camp.v1"
    case inputArchive = "input.archive.v1"
    case inputMarkCoaching = "input.mark-coaching.v1"
    case inputConvertToGoal = "input.convert-to-goal.v1"
    case inputRequestDeletion = "input.request-deletion.v1"
    case inputCompleteDeletion = "input.complete-deletion.v1"
    case coachOpenSession = "coach.open-session.v1"
    case coachRecordQuestion = "coach.record-question.v1"
    case coachAnswerQuestion = "coach.answer-question.v1"
    case coachProposeUnderstanding = "coach.propose-understanding.v1"
    case coachRequestConfirmation = "coach.request-confirmation.v1"
    case coachConfirmUnderstanding = "coach.confirm-understanding.v1"
    case coachRequestUnderstandingRevision = "coach.request-understanding-revision.v1"
    case coachRecordWorkFailure = "coach.record-work-failure.v1"
    case goalAbandon = "goal.abandon.v1"
    case goalFail = "goal.fail.v1"
    case engineExecutionBegin = "engine.execution-begin.v1"
    case engineDispatchStart = "engine.dispatch-start.v1"
    case engineCancellationRequest = "engine.cancellation-request.v1"
    case engineEventAccept = "engine.event-accept.v1"
    case engineTerminalProposalRecord = "engine.terminal-proposal-record.v1"
    case engineTerminalCommit = "engine.terminal-commit.v1"
}

package enum P1EventTypeV1: String, Codable, Sendable, Equatable, CaseIterable {
    case inputCaptured = "input.captured.v1"
    case inputParseCommitted = "input.parse-committed.v1"
    case inputParseAttemptFailed = "input.parse-attempt-failed.v1"
    case inputParsingRequeued = "input.parsing-requeued.v1"
    case inputDeleted = "input.deleted.v1"
    case inputCampAssignmentRequired = "input.camp-assignment-required.v1"
    case inputCampAmbiguityRecorded = "input.camp-ambiguity-recorded.v1"
    case inputCampAssigned = "input.camp-assigned.v1"
    case inputArchived = "input.archived.v1"
    case inputCoachingStarted = "input.coaching-started.v1"
    case inputGoalCreated = "input.goal-created.v1"
    case inputDeletionRequested = "input.deletion-requested.v1"
    case goalCreated = "goal.created.v1"
    case coachSessionOpened = "coach.session-opened.v1"
    case coachQuestionRecorded = "coach.question-recorded.v1"
    case coachQuestionAnswered = "coach.question-answered.v1"
    case coachUnderstandingProposed = "coach.understanding-proposed.v1"
    case understandingProposed = "understanding.proposed.v1"
    case coachConfirmationRequested = "coach.confirmation-requested.v1"
    case understandingConfirmationRequested = "understanding.confirmation-requested.v1"
    case coachUnderstandingConfirmed = "coach.understanding-confirmed.v1"
    case understandingConfirmed = "understanding.confirmed.v1"
    case goalReady = "goal.ready.v1"
    case coachUnderstandingRevisionRequested = "coach.understanding-revision-requested.v1"
    case understandingWithdrawn = "understanding.withdrawn.v1"
    case coachWorkAttemptFailed = "coach.work-attempt-failed.v1"
    case coachSessionFailed = "coach.session-failed.v1"
    case coachSessionAbandoned = "coach.session-abandoned.v1"
    case goalAbandoned = "goal.abandoned.v1"
    case goalFailed = "goal.failed.v1"
    case engineExecutionBegan = "engine.execution-began.v1"
    case engineDispatchStarted = "engine.dispatch-started.v1"
    case engineCancellationRequested = "engine.cancellation-requested.v1"
    case engineEventAccepted = "engine.event-accepted.v1"
    case engineTerminalProposed = "engine.terminal-proposed.v1"
    case engineTerminalCommitted = "engine.terminal-committed.v1"
    case engineAttentionIntent = "engine.attention-intent.v1"
}

package enum P1ResultCodeV1: String, Codable, Sendable, Equatable, CaseIterable {
    case inputCaptured = "input_captured"
    case inputParseCommitted = "input_parse_committed"
    case inputParseRetryScheduled = "input_parse_retry_scheduled"
    case inputParseFailed = "input_parse_failed"
    case inputParsingRequeued = "input_parsing_requeued"
    case inputDeleted = "input_deleted"
    case inputCampAssignmentRequired = "input_camp_assignment_required"
    case inputCampAmbiguous = "input_camp_ambiguous"
    case inputCampAssigned = "input_camp_assigned"
    case inputArchived = "input_archived"
    case inputCoaching = "input_coaching"
    case inputGoalCreated = "input_goal_created"
    case inputDeletionRequested = "input_deletion_requested"
    case goalCreated = "goal_created"
    case coachSessionOpened = "coach_session_opened"
    case coachQuestionRecorded = "coach_question_recorded"
    case coachQuestionAnswered = "coach_question_answered"
    case coachUnderstandingProposed = "coach_understanding_proposed"
    case coachConfirmationRequested = "coach_confirmation_requested"
    case coachUnderstandingConfirmed = "coach_understanding_confirmed"
    case coachRevisionRequested = "coach_revision_requested"
    case understandingWithdrawn = "understanding_withdrawn"
    case coachWorkRetryScheduled = "coach_work_retry_scheduled"
    case coachWorkFailed = "coach_work_failed"
    case goalReady = "goal_ready"
    case goalAbandoned = "goal_abandoned"
    case goalFailed = "goal_failed"
    case engineExecutionBegan = "engine_execution_began"
    case engineDispatchStarted = "engine_dispatch_started"
    case engineCancellationRequested = "engine_cancellation_requested"
    case engineEventAccepted = "engine_event_accepted"
    case engineTerminalProposed = "engine_terminal_proposed"
    case engineTerminalCommitted = "engine_terminal_committed"
}

package enum P1AuditCodeV1: String, Codable, Sendable, Equatable, CaseIterable {
    case inputCaptured = "input_captured"
    case inputParseCommitted = "input_parse_committed"
    case inputParseRetryScheduled = "input_parse_retry_scheduled"
    case inputParseFailed = "input_parse_failed"
    case inputParsingRequeued = "input_parsing_requeued"
    case inputDeleted = "input_deleted"
    case inputCampAssignmentRequired = "input_camp_assignment_required"
    case inputCampAmbiguous = "input_camp_ambiguous"
    case inputCampAssigned = "input_camp_assigned"
    case inputArchived = "input_archived"
    case inputCoaching = "input_coaching"
    case inputGoalCreated = "input_goal_created"
    case inputDeletionRequested = "input_deletion_requested"
    case goalCreated = "goal_created"
    case coachSessionOpened = "coach_session_opened"
    case coachQuestionRecorded = "coach_question_recorded"
    case coachQuestionAnswered = "coach_question_answered"
    case coachUnderstandingProposed = "coach_understanding_proposed"
    case coachConfirmationRequested = "coach_confirmation_requested"
    case coachUnderstandingConfirmed = "coach_understanding_confirmed"
    case coachRevisionRequested = "coach_revision_requested"
    case understandingWithdrawn = "understanding_withdrawn"
    case coachWorkRetryScheduled = "coach_work_retry_scheduled"
    case coachWorkFailed = "coach_work_failed"
    case goalReady = "goal_ready"
    case goalAbandoned = "goal_abandoned"
    case goalFailed = "goal_failed"
    case engineExecutionBegan = "engine_execution_began"
    case engineDispatchStarted = "engine_dispatch_started"
    case engineCancellationRequested = "engine_cancellation_requested"
    case engineEventAccepted = "engine_event_accepted"
    case engineTerminalProposed = "engine_terminal_proposed"
    case engineTerminalCommitted = "engine_terminal_committed"
    case engineAttentionIntent = "engine_attention_intent"
}
// P1-C-END ControlContractVocabulary
