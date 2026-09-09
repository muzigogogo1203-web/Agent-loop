import Foundation
import os

public enum DistillerError: Error, Sendable, Equatable {
    case invalidPayload
}

/// 知识蒸馏（spec §9/§10.1，plan D1）：单轮无工具 LLM 调用，强制 JSON 提示 + 宽松解析。
/// 蒸馏是旁路增强——收营蒸馏失败走确定性回退（任何路径都产出一张笔记）；
/// 记忆蒸馏失败向上抛，调用方静默留水位下次再试。
public struct Distiller: Sendable {
    public struct CardDigest: Sendable {
        public let title: String
        public let outcome: String
        public let summary: String
        public let risks: [String]

        public init(title: String, outcome: String, summary: String, risks: [String]) {
            self.title = title
            self.outcome = outcome
            self.summary = summary
            self.risks = risks
        }
    }

    public struct Note: Sendable, Equatable {
        public let title: String
        public let bodyMd: String

        public init(title: String, bodyMd: String) {
            self.title = title
            self.bodyMd = bodyMd
        }
    }

    private let inference: RegisteredProviderInferenceV1
    let maxTokens: Int
    private static let logger = Logger(subsystem: "com.muzi.agentloop", category: "distiller")
    /// 笔记标题上限（plan D1：≤30 字，代码强制兜底）
    package static let titleLimit = 30

    package init(
        inference: RegisteredProviderInferenceV1,
        maxTokens: Int = 2048
    ) {
        self.inference = inference
        self.maxTokens = maxTokens
    }

    // MARK: - 收营蒸馏（失败确定性回退，不抛错）

    /// 输入行动目标 + 各 done 卡交接摘要，输出营地笔记。fallback=true 表示走了回退拼接。
    public func distillCloseout(goal: String, cards: [CardDigest]) async -> (note: Note, fallback: Bool) {
        let prompt = Self.closeoutPrompt(goal: goal, cards: cards)
        do {
        let raw = try await inference.singleTextTurn(
            system: Self.closeoutSystem,
            user: prompt,
            maxTokens: maxTokens
        )
            if case .note(let title, let body) = try Self.parseNoteJSON(raw) {
                return (Note(title: title, bodyMd: body), false)
            }
            Self.logger.info("closeout distillation unparseable, falling back")
        } catch {
            Self.logger.info("closeout distillation failed, falling back: \(String(describing: error), privacy: .public)")
        }
        return (Self.closeoutFallback(goal: goal, cards: cards), true)
    }

    // MARK: - 记忆蒸馏（skip 约定；失败 throws，调用方留水位重试）

    /// 输入伙伴名/职责 + 未蒸馏消息增量。返回 nil = 模型判定无值得记的内容（{"skip":true}）。
    public func distillMemory(
        companionName: String, rolePrompt: String, messages: [(role: String, text: String)]
    ) async throws -> Note? {
        let prompt = Self.memoryPrompt(companionName: companionName, rolePrompt: rolePrompt, messages: messages)
        let raw = try await inference.singleTextTurn(
            system: Self.memorySystem,
            user: prompt,
            maxTokens: maxTokens
        )
        switch try Self.parseNoteJSON(raw) {
        case .note(let title, let body):
            return Note(title: title, bodyMd: body)
        case .skip:
            return nil
        }
    }

    /// 向导对话手动沉淀为营地笔记（D9，spec §10.2）；skip/失败语义与记忆蒸馏一致。
    public func distillGuideChat(messages: [(role: String, text: String)]) async throws -> Note? {
        let prompt = Self.guideChatPrompt(messages: messages)
        let raw = try await inference.singleTextTurn(
            system: Self.guideChatSystem,
            user: prompt,
            maxTokens: maxTokens
        )
        switch try Self.parseNoteJSON(raw) {
        case .note(let title, let body):
            return Note(title: title, bodyMd: body)
        case .skip:
            return nil
        }
    }

    // MARK: - 解析（剥围栏 → 严格 JSON）

    package enum ParsedNote: Equatable {
        case note(title: String, body: String)
        case skip
    }

    package static func parseNoteJSON(_ raw: String) throws -> ParsedNote {
        let stripped = stripCodeFence(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stripped.isEmpty,
              let object = try? JSONValue.decoded(from: stripped).objectValue
        else {
            throw DistillerError.invalidPayload
        }
        if object.count == 1, object["skip"]?.boolValue == true {
            return .skip
        }
        guard object.count == 2,
              let title = object["title"]?.stringValue,
              let body = object["body"]?.stringValue,
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw DistillerError.invalidPayload
        }
        return .note(title: String(title.prefix(titleLimit)), body: body)
    }

    package static func stripCodeFence(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix("```") else { return text }
        // 去掉首行 ```json / ```
        if let firstNewline = text.firstIndex(of: "\n") {
            text = String(text[text.index(after: firstNewline)...])
        } else {
            return ""
        }
        if let closing = text.range(of: "```", options: .backwards) {
            text = String(text[..<closing.lowerBound])
        }
        return text
    }

    // MARK: - 回退拼接（确定性，无时间戳）

    package static func closeoutFallback(goal: String, cards: [CardDigest]) -> Note {
        let firstLine = goal.split(whereSeparator: \.isNewline).first.map(String.init) ?? goal
        let title = String(firstLine.prefix(titleLimit))
        var lines: [String] = ["# 行动复盘（自动拼接）", "", "目标：\(goal)"]
        for card in cards {
            lines.append("")
            lines.append("## \(card.title)")
            lines.append("结果：\(card.outcome)")
            lines.append("摘要：\(card.summary)")
            if !card.risks.isEmpty {
                lines.append("风险：" + card.risks.joined(separator: "；"))
            }
        }
        return Note(title: title.isEmpty ? "行动复盘" : title, bodyMd: lines.joined(separator: "\n"))
    }

    // MARK: - Prompt 模板（固定文案，无时间戳）

    package static let closeoutSystem = """
    你是营地的复盘记录员。根据一次行动的目标与各小目标的交接摘要，蒸馏一张营地笔记，供后续行动复用经验。
    只输出一个 JSON 对象，不要任何其他文字：{"title":"...","body":"..."}
    title 不超过 30 字。body 是 markdown，必须包含四节：## 做了什么、## 什么做法有效、## 关键产物在哪、## 踩了什么坑。
    """

    package static func closeoutPrompt(goal: String, cards: [CardDigest]) -> String {
        var lines: [String] = ["行动目标：\(goal)", "", "各小目标交接摘要："]
        for (index, card) in cards.enumerated() {
            lines.append("\(index + 1). \(card.title)")
            lines.append("   结果：\(card.outcome)")
            lines.append("   摘要：\(card.summary)")
            if !card.risks.isEmpty {
                lines.append("   风险：" + card.risks.joined(separator: "；"))
            }
        }
        return lines.joined(separator: "\n")
    }

    package static let memorySystem = """
    你是伙伴的记忆整理员。根据伙伴与用户的这段私聊增量，提炼值得长期记住的信息（用户的偏好、约定、背景事实、待办承诺），写成一条伙伴记忆。
    只输出一个 JSON 对象，不要任何其他文字。
    有值得记的内容时输出：{"title":"...","body":"..."}（title 不超过 30 字，body 是 markdown 要点）。
    这段对话没有值得长期记住的内容时输出：{"skip":true}
    """

    package static func memoryPrompt(
        companionName: String, rolePrompt: String, messages: [(role: String, text: String)]
    ) -> String {
        var lines: [String] = ["伙伴：\(companionName)（职责：\(rolePrompt)）", "", "未沉淀的对话增量："]
        for message in messages {
            lines.append("\(message.role == "user" ? "用户" : companionName)：\(message.text)")
        }
        return lines.joined(separator: "\n")
    }

    package static let guideChatSystem = """
    你是营地的笔记整理员。根据用户与向导的这段对话增量，提炼值得沉淀为营地笔记的信息（决策、结论、约定、经验），供全营地后续行动复用。
    只输出一个 JSON 对象，不要任何其他文字。
    有值得沉淀的内容时输出：{"title":"...","body":"..."}（title 不超过 30 字，body 是 markdown 要点）。
    没有值得沉淀的内容时输出：{"skip":true}
    """

    package static func guideChatPrompt(messages: [(role: String, text: String)]) -> String {
        var lines: [String] = ["未沉淀的对话增量："]
        for message in messages {
            lines.append("\(message.role == "user" ? "用户" : "向导")：\(message.text)")
        }
        return lines.joined(separator: "\n")
    }
}
