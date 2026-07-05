public enum KernelDefaults {
    public static let maxTurns = 30
    public static let cardTokenBudget = 200_000
    public static let missionBudget = 200_000
    public static let maxTokensPerTurn = 8192
    public static let planMaxCards = 6
    public static let turnTimeout: Duration = .seconds(120)
    /// 卡片执行的传输层重试间隔（网关抖动多给机会）；Planner 维持自己的快速失败节奏。
    public static let transportRetryDelays: [Duration] = [.seconds(2), .seconds(5), .seconds(10), .seconds(20)]
}
