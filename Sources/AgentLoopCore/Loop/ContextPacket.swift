import Foundation

public struct UpstreamHandoff: Sendable {
    public let cardTitle: String
    public let handoff: HandoffPayload
    public let workspaceRelativePaths: [String]
    public let durablePaths: [String]

    public init(
        cardTitle: String,
        handoff: HandoffPayload,
        workspaceRelativePaths: [String],
        durablePaths: [String]
    ) {
        self.cardTitle = cardTitle
        self.handoff = handoff
        self.workspaceRelativePaths = workspaceRelativePaths
        self.durablePaths = durablePaths
    }
}

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
        upstreamHandoffs: [UpstreamHandoff],
        answeredRequests: [(prompt: String, answer: String)] = [],
        campNotes: [NoteSnippet] = [],
        companionNotes: [NoteSnippet] = [],
        toolNames: [String] = ToolDef.agentTools.map(\.name)
    ) {
        // M6-D4：契约文本随实际工具集渲染——提示词里提到的工具必须真的在场
        let toolSet = Set(toolNames)
        let hasFileTools = !toolSet.isDisjoint(with: ["list_dir", "read_file", "write_file"])
        var rules: [String] = []
        rules.append("用工具完成真实工作。"
            + (hasFileTools ? "文件操作仅限工作目录内的相对路径。" : ""))
        rules.append("每完成一个阶段用 add_progress_note 汇报一句话进展。")
        rules.append("工作完成并自查后，必须调用 complete_card 提交交接包（outcome/summary/artifacts/verification/risks）收尾；artifacts 必须是已写入工作目录的真实文件。")
        rules.append("确定无法继续时调用 block_card 说明原因。")
        rules.append("complete_card 或 block_card 是仅有的两种结束方式；不要用普通文本宣布完成。")
        if toolSet.contains("write_file") {
            rules.append("写长文件（约超过 3000 字）时分多次 write_file：第一次不带 append 建立文件，之后每次 append: true 续写一段，每段控制在 3000 字以内。")
        }
        let contract = rules.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
        self.system = """
        你的名字是\(companionName)。\(rolePrompt)

        # 工作契约
        你在一个协作系统中执行「小目标」。规则：
        \(contract)
        """

        var user = """
        # 当前小目标
        标题：\(cardTitle)
        说明：\(cardDescription)
        预期产出：\(expectedOutput)
        """
        if let workspacePath, hasFileTools {
            user += "\n工作目录：\(workspacePath)（工具中一律使用相对路径）"
        } else {
            // 无工作目录 与 白名单剔除文件三件 共用同一套措辞（M6-D4）
            user += "\n（本任务文件工具不可用；如无文件产物，交接包用 noArtifactReason 说明）"
        }
        // 知识注入（spec §6.2-5/6）：营地笔记 + 伙伴记忆，位置在上游交接之前；空则整段省略
        if let campSection = NoteSnippet.renderSection(header: "营地笔记（往期经验）", snippets: campNotes) {
            user += "\n\n" + campSection
        }
        if let memorySection = NoteSnippet.renderSection(header: "你的记忆", snippets: companionNotes) {
            user += "\n\n" + memorySection
        }
        if !upstreamHandoffs.isEmpty {
            user += "\n\n# 上游交接\n" + upstreamHandoffs.map(Self.render).joined(separator: "\n---\n")
        }
        if !answeredRequests.isEmpty {
            let rendered = answeredRequests.enumerated().map { index, item in
                """
                \(index + 1). 问：\(item.prompt)
                   答：\(item.answer)
                """
            }.joined(separator: "\n")
            user += "\n\n# 此前你向用户提问的记录\n" + rendered
        }
        user += "\n\n现在开始工作。"

        self.firstUserMessage = .user(user)
    }

    private static func render(_ upstream: UpstreamHandoff) -> String {
        var lines: [String] = [
            "## \(upstream.cardTitle)",
            "结果：\(upstream.handoff.outcome)",
            "摘要：\(upstream.handoff.summary)",
        ]

        if upstream.handoff.verification.isEmpty {
            lines.append("验证：未提供")
        } else {
            lines.append("验证：")
            for item in upstream.handoff.verification {
                lines.append("- \(item.method)：\(item.passed ? "✓" : "✗") \(item.note)")
            }
        }

        if upstream.handoff.risks.isEmpty {
            lines.append("风险：无")
        } else {
            lines.append("风险：")
            for risk in upstream.handoff.risks {
                lines.append("- \(risk)")
            }
        }

        if let next = upstream.handoff.next, !next.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("建议下一步：\(next)")
        }

        if upstream.workspaceRelativePaths.isEmpty && upstream.durablePaths.isEmpty {
            lines.append("无文件产物：\(upstream.handoff.noArtifactReason ?? "未说明")")
        } else {
            lines.append("产物：")
            lines.append("工作目录内路径可直接用 read_file 读取：")
            if upstream.workspaceRelativePaths.isEmpty {
                lines.append("- 无")
            } else {
                for path in upstream.workspaceRelativePaths {
                    lines.append("- \(path)")
                }
            }
            lines.append("耐久备份绝对路径（信息性）：")
            if upstream.durablePaths.isEmpty {
                lines.append("- 无")
            } else {
                for path in upstream.durablePaths {
                    lines.append("- \(path)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }
}
