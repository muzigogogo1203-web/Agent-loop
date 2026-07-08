public enum KernelDefaults {
    public static let maxTurns = 30
    public static let cardTokenBudget = 200_000
    public static let missionBudget = 200_000
    public static let maxTokensPerTurn = 8192
    public static let planMaxCards = 6
    public static let turnTimeout: Duration = .seconds(120)
    /// 卡片执行的传输层重试间隔（网关抖动多给机会）；Planner 维持自己的快速失败节奏。
    public static let transportRetryDelays: [Duration] = [.seconds(2), .seconds(5), .seconds(10), .seconds(20)]
    /// 全局同时执行的卡上限（M5-2：多营地并发失控防线）
    public static let maxConcurrentCardRuns = 4
    /// 上下文压缩触发线（M5-3，spec §6.3：约 200k 窗口的 75%）
    public static let contextCompactionThreshold = 150_000
    /// 压缩时保留原文的最近消息数（含配对的工具往返）
    public static let compactionKeepRecentMessages = 6
    /// 向导伙伴的出厂默认模型（M6-D12：收敛原先散落在 AppDatabase 两处的字面量）
    public static let defaultGuideModel = "claude-sonnet-4-6"
    /// shell 命令超时（M7-D6）
    public static let shellTimeout: Duration = .seconds(120)
}
