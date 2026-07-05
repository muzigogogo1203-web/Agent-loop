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
        answeredRequests: [(prompt: String, answer: String)] = []
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
        6. 写长文件（约超过 3000 字）时分多次 write_file：第一次不带 append 建立文件，之后每次 append: true 续写一段，每段控制在 3000 字以内。
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
