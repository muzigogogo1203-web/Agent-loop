import Foundation

public enum ExpeditionReport {
    public static func markdown(_ input: ExpeditionReportInput) -> String {
        let missionTitle = title(for: input.mission)
        let artifactsByCard = Dictionary(grouping: input.artifacts, by: \.cardId)
        let feed = ActivityFeed.entries(
            events: input.events,
            cards: input.cards,
            companions: input.companions
        )

        var lines = [
            "# 远征报告：\(inline(missionTitle))",
            "",
            "- 营地：\(inline(input.camp.name))",
            "- 小队：\(inline(input.squad.name))",
            "- 状态：\(statusName(input.mission.status))",
            "- 预算：\(input.mission.budgetTokens) tokens",
            "- 花销：\(input.mission.spentTokens) tokens",
        ]

        if let acceptedAt = input.events.last(where: { $0.kind == EventKind.missionAccepted })?.createdAt {
            lines.append("- 收营时间：\(timestamp(acceptedAt))")
        }

        lines.append(contentsOf: ["", "## 小目标", ""])
        if input.cards.isEmpty {
            lines.append("- 没有小目标记录。")
        }
        for card in input.cards {
            let companionName = card.assigneeId.flatMap { input.companions[$0]?.name } ?? "未指派"
            let handoff = card.handoffJson.flatMap {
                try? JSONDecoder().decode(HandoffPayload.self, from: Data($0.utf8))
            }
            lines.append("### \(card.stage). \(inline(card.title))")
            lines.append("")
            lines.append("- 伙伴：\(inline(companionName))")
            lines.append("- 状态：\(cardStatusName(card.status))")
            if let handoff {
                lines.append("- 结果：\(inline(handoff.outcome))")
                lines.append("- 摘要：\(inline(handoff.summary))")
                if !handoff.verification.isEmpty {
                    let verification = handoff.verification.map {
                        "\($0.passed ? "通过" : "未通过") \(inline($0.method))：\(inline($0.note))"
                    }.joined(separator: "；")
                    lines.append("- 验证：\(verification)")
                }
                if !handoff.risks.isEmpty {
                    lines.append("- 风险：\(handoff.risks.map(inline).joined(separator: "；"))")
                }
            } else {
                lines.append("- 结果：没有交接包")
            }
            let cardArtifacts = artifactsByCard[card.id] ?? []
            if cardArtifacts.isEmpty {
                lines.append("- 交付物：无文件")
            } else {
                lines.append("- 交付物：" + cardArtifacts.map { inline($0.label) }.joined(separator: "、"))
            }
            lines.append("")
        }

        lines.append(contentsOf: ["## 交付物", ""])
        if input.artifacts.isEmpty {
            lines.append("- 本次行动没有文件交付物。")
        } else {
            for artifact in input.artifacts {
                lines.append("- \(inline(artifact.label))：`\(artifact.path.replacingOccurrences(of: "`", with: "\\`"))`")
            }
        }

        lines.append(contentsOf: ["", "## 花销", ""])
        lines.append("- 规划：\(input.spend.planningTokens) tokens")
        if input.spend.companions.isEmpty {
            lines.append("- 执行：0 tokens")
        } else {
            for companion in input.spend.companions {
                lines.append("- \(inline(companion.name))：\(companion.tokens) tokens")
            }
        }
        lines.append("- 合计：\(input.mission.spentTokens) tokens")

        lines.append(contentsOf: ["", "## 时间线", ""])
        if feed.isEmpty {
            lines.append("- 没有可展示的行动事件。")
        } else {
            for entry in feed {
                lines.append("- \(timestamp(entry.timestamp)) · \(actorName(entry.actor))：\(inline(entry.text))")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func title(for mission: MissionRecord) -> String {
        let refined = mission.goalRefined.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = mission.goalRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = refined.isEmpty ? raw : refined
        return source.split(whereSeparator: \.isNewline).first.map(String.init) ?? "未命名行动"
    }

    private static func statusName(_ status: MissionStatus) -> String {
        switch status {
        case .planning: return "规划中"
        case .executing: return "进行中"
        case .delivering: return "待收营"
        case .accepted: return "已收营"
        case .failed: return "已失败"
        }
    }

    private static func cardStatusName(_ status: CardStatus) -> String {
        switch status {
        case .todo: return "排队中"
        case .ready: return "待启动"
        case .running: return "进行中"
        case .done: return "已完成"
        case .blocked: return "受阻"
        case .canceled: return "已取消"
        }
    }

    private static func actorName(_ actor: FeedEntry.Actor) -> String {
        switch actor {
        case .companion(_, let name): return inline(name)
        case .system: return "系统"
        case .user: return "你"
        }
    }

    private static func inline(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
