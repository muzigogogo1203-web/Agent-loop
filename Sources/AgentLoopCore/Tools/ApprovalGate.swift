import Foundation
import CryptoKit

/// 审批门（M7-D3/D4）：包裹非只读工具 handler 的装饰层。
/// 放行判据 = 档位矩阵 + 一次性授权令牌（同卡、同工具、同参数哈希，用过即耗）。
/// 挂起复用 ask_user 持久门语义（blocked(needsHumanInput) + user_request 行），
/// 批准后卡片冷启动重跑，重跑时令牌放行同一动作；拒绝则该调用返回 is_error 让模型改道。

public struct ApprovalDecision: Sendable, Equatable {
    public let tool: String
    public let inputHash: String
    public let approved: Bool
    public let reason: String?

    public init(tool: String, inputHash: String, approved: Bool, reason: String?) {
        self.tool = tool
        self.inputHash = inputHash
        self.approved = approved
        self.reason = reason
    }
}

public enum ApprovalToken {
    /// 参数哈希：SHA256(tool + 规范化 JSON)。sortedKeys 保证键序无关。
    public static func hash(tool: String, input: JSONValue) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(input)) ?? Data()
        var hasher = SHA256()
        hasher.update(data: Data(tool.utf8))
        hasher.update(data: data)
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// 审批弹卡的人话描述（动作实体内容在 UI 层从 optionsJson 全文渲染）
    public static func prompt(tool: String, input: JSONValue) -> String {
        switch tool {
        case "run_shell":
            let command = input["command"]?.stringValue ?? ""
            return "伙伴想执行命令：\(command)"
        case "write_file":
            let path = input["path"]?.stringValue ?? "?"
            let bytes = input["content"]?.stringValue?.utf8.count ?? 0
            return "伙伴想写入文件 \(path)（约 \(bytes) 字节）"
        default:
            return "伙伴想使用 \(ToolDef.displayName(tool))"
        }
    }
}

/// 一次性令牌罐：本次 run 的已决审批快照，批准令牌用过即耗（严格一次）。
public actor ApprovalTokenJar {
    private var decisions: [ApprovalDecision]

    public init(_ decisions: [ApprovalDecision]) {
        self.decisions = decisions
    }

    /// 取用匹配令牌：批准令牌消耗式返回；拒绝记录不消耗（同参数反复调用一直拒）。
    public func consume(tool: String, inputHash: String) -> ApprovalDecision? {
        guard let index = decisions.firstIndex(where: { $0.tool == tool && $0.inputHash == inputHash }) else {
            return nil
        }
        let decision = decisions[index]
        if decision.approved {
            decisions.remove(at: index)
        }
        return decision
    }
}

public struct ApprovalGateHandler: ToolHandler {
    let inner: any ToolHandler
    let toolName: String
    let autonomy: MissionAutonomy
    let jar: ApprovalTokenJar
    let db: AppDatabase
    let cardId: String
    let runId: String

    public init(
        inner: any ToolHandler, toolName: String, autonomy: MissionAutonomy,
        jar: ApprovalTokenJar, db: AppDatabase, cardId: String, runId: String
    ) {
        self.inner = inner
        self.toolName = toolName
        self.autonomy = autonomy
        self.jar = jar
        self.db = db
        self.cardId = cardId
        self.runId = runId
    }

    public func execute(input: JSONValue) async -> ToolOutcome {
        guard autonomy.requiresApproval(risk: ToolDef.risk(toolName)) else {
            return await inner.execute(input: input)
        }
        let hash = ApprovalToken.hash(tool: toolName, input: input)
        if let decision = await jar.consume(tool: toolName, inputHash: hash) {
            if decision.approved {
                return await inner.execute(input: input)
            }
            let reasonSuffix = decision.reason.map { "：\($0)" } ?? ""
            return .error("用户拒绝了此操作\(reasonSuffix)。请换一种做法，或用 block_card 说明无法继续。")
        }
        // 无令牌 → 挂起审批（持久门，崩溃恢复语义随 ask_user 继承）
        do {
            _ = try db.suspendCardForApproval(
                cardId: cardId,
                runId: runId,
                prompt: ApprovalToken.prompt(tool: toolName, input: input),
                tool: toolName,
                input: input,
                inputHash: hash
            )
            return .blocked(reason: "needs_human_input", detail: "等待你批准：\(ToolDef.displayName(toolName))")
        } catch {
            return .error("审批请求落库失败：\(error)")
        }
    }
}
