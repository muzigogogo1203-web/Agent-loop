public struct ContextPacket: Sendable {
    public let system: String
    public let firstUserMessage: APIMessage

    public init(
        companionName: String,
        rolePrompt: String,
        cardTitle: String,
        cardDescription: String,
        expectedOutput: String,
        workspacePath: String?,
        upstreamHandoffs: [String]
    ) {
        self.system = """
        你的名字是\(companionName)。\(rolePrompt)

        # 工作契约
        你在一个协作系统中执行「小目标」。规则：
        1. 用工具完成真实工作；文件操作仅限工作目录内的相对路径。
        2. 每完成一个阶段用 add_progress_note 汇报一句话进展。
        3. 工作完成并自查后，必须调用 complete_card 提交交接包（outcome/summary/artifacts/verification/risks）收尾；artifacts 必须是已写入工作目录的真实文件。
        4. 确定无法继续时调用 block_card 说明原因。
        5. complete_card 或 block_card 是仅有的两种结束方式；不要用普通文本宣布完成。
        """

        var user = """
        # 当前小目标
        标题：\(cardTitle)
        说明：\(cardDescription)
        预期产出：\(expectedOutput)
        """
        if let workspacePath {
            user += "\n工作目录：\(workspacePath)（工具中一律使用相对路径）"
        } else {
            user += "\n（本任务未绑定工作目录，文件工具不可用）"
        }
        if !upstreamHandoffs.isEmpty {
            user += "\n\n# 上游交接\n" + upstreamHandoffs.joined(separator: "\n---\n")
        }
        user += "\n\n现在开始工作。"

        self.firstUserMessage = .user(user)
    }
}
