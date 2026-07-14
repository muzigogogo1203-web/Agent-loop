import Foundation

/// Coding 牧场的内置牛模板。稳定 id 是持久化契约，用于幂等初始化与解锁。
public enum CowTemplate {
    public static let baseCowId = "coding-ranch-base-cow-v1"
    public static let testCowId = "coding-ranch-test-cow-v1"

    public static func baseCow(campId: String) -> CompanionRecord {
        CompanionRecord(
            id: baseCowId,
            name: "基础牛",
            color: "orange",
            rolePrompt: """
            你是 Coding 牧场里的基础牛，一只面向新手的教学型 Coding 通才。
            你会先读取营地笔记和用户确认的需求，再把目标拆成可验证的小步骤。
            你擅长生成单页 HTML、简单表单和小工具，并在关键决策、修改与验收时用清楚的人话引导用户。
            不要假装完成未验证的工作；交付前必须检查真实文件和验收项。
            """,
            model: KernelDefaults.defaultGuideModel,
            toolsJson: ToolAccess.explicitJson(allow: Set(ToolAccess.builtinCapabilityNames)),
            kind: .regular,
            campId: campId,
            createdAt: Date()
        )
    }

    public static func testCow(campId: String) -> CompanionRecord {
        CompanionRecord(
            id: testCowId,
            name: "测试牛",
            color: "green",
            rolePrompt: """
            你是 Coding 牧场里的测试牛，负责依据用户确认的验收标准检查真实成果。
            你要覆盖主要流程、边界条件、失败提示和产物可用性，并把问题写成可执行的修改建议。
            不要只看实现说明；优先检查真实文件、运行结果和验证记录。
            """,
            model: KernelDefaults.defaultGuideModel,
            toolsJson: ToolAccess.explicitJson(allow: [
                "list_dir", "read_file", "run_shell", "search_camp_notes",
            ]),
            kind: .regular,
            campId: campId,
            createdAt: Date()
        )
    }
}

public struct CodingRanchBootstrapResult: Sendable {
    public let camp: CampRecord
    public let baseCow: CompanionRecord?
    public let newcomerMode: Bool

    public init(camp: CampRecord, baseCow: CompanionRecord?, newcomerMode: Bool) {
        self.camp = camp
        self.baseCow = baseCow
        self.newcomerMode = newcomerMode
    }
}
