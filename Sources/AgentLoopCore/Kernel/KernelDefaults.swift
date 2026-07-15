import Foundation

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
    /// ChatGPT OAuth 没有公开模型目录接口，运行时档案先使用内置静态清单。
    public static let chatGPTStaticModels = ["gpt-5.5"]
    /// CLI 供给线不在牧场内选模型，目录只暴露占位项。
    public static let cliStaticModels = ["cli-default"]
    /// CLI 卡片默认超时（V1.1b-D9）：20 分钟。
    public static let cliCardTimeout: Duration = .seconds(1200)
    /// CLI stderr 诊断尾部上限（V1.1b-D9）。
    public static let cliStderrTailBytes = 20 * 1024
    /// Codex CLI 必须显式带模型与推理档位；环境变量用于本机配置覆盖。
    public static let codexCliDefaultModel =
        ProcessInfo.processInfo.environment["AGENTLOOP_CODEX_MODEL"] ?? "gpt-5.5"  // 0.132.0 CLI 上 gpt-5.6-sol 被 API 拒(需更新 CLI),用 gpt-5.5 兜底
    public static let codexCliReasoningEffort =
        ProcessInfo.processInfo.environment["AGENTLOOP_CODEX_REASONING_EFFORT"] ?? "xhigh"
    /// Claude CLI 模型可由 Claude 自身默认接管；设置环境变量时才显式传入。
    public static let claudeCliModel =
        ProcessInfo.processInfo.environment["AGENTLOOP_CLAUDE_MODEL"]
    /// shell 命令超时（M7-D6）
    public static let shellTimeout: Duration = .seconds(120)
    /// 429 重试耗尽后的全局派发冷却（M7-D8）
    public static let rateLimitCooldown: Duration = .seconds(15)
    /// MCP 握手（initialize + tools/list）超时（M8-D3）。
    /// 60s：npx 首启要现场下包（真机实测 15s 必超时），冷启动是常态不是异常。
    public static let mcpInitTimeout: Duration = .seconds(60)
    /// MCP 工具单次调用超时（M8-D4）
    public static let mcpCallTimeout: Duration = .seconds(30)
}
