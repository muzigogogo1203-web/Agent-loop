public enum KernelDefaults {
    public static let maxTurns = 30
    public static let cardTokenBudget = 200_000
    public static let missionBudget = 200_000
    public static let maxTokensPerTurn = 8192
    public static let planMaxCards = 6
    public static let turnTimeout: Duration = .seconds(120)
}
