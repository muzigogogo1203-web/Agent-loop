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

    // 执行与内核
    public static let runError = "run_error"
    public static let progressNote = "progress_note"
    public static let kernelError = "kernel_error"
    public static let budgetAdded = "budget_added"

    // 人工门与提案
    public static let userRequestCreated = "user_request_created"
    public static let userRequestAnswered = "user_request_answered"
    public static let squadProposalConfirmed = "squad_proposal_confirmed"

    // 知识层
    public static let campNoteCreated = "camp_note_created"
    public static let companionNoteCreated = "companion_note_created"
}
