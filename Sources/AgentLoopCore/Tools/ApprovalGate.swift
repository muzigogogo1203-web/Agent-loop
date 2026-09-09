import Foundation

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
    /// 参数哈希只覆盖 canonical input；tool ID 是 Grant 的独立 scope。
    public static func hash(input: JSONValue) throws -> String {
        CanonicalJSONV1.sha256Hex(try CanonicalJSONV1.encode(input))
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

public struct ApprovalGateHandler: ToolHandler {
    let inner: any ToolHandler
    let toolName: String
    let autonomy: MissionAutonomy
    let db: AppDatabase
    let cardId: String
    let runId: String
    let campId: String?
    let workflow: (any ExternalOperationWorkflowPortV1)?

    public init(
        inner: any ToolHandler, toolName: String, autonomy: MissionAutonomy,
        db: AppDatabase, cardId: String, runId: String, campId: String?
    ) {
        self.init(
            inner: inner,
            toolName: toolName,
            autonomy: autonomy,
            db: db,
            cardId: cardId,
            runId: runId,
            campId: campId,
            workflow: nil
        )
    }

    package init(
        inner: any ToolHandler, toolName: String, autonomy: MissionAutonomy,
        db: AppDatabase, cardId: String, runId: String, campId: String?,
        workflow: (any ExternalOperationWorkflowPortV1)?
    ) {
        self.inner = inner
        self.toolName = toolName
        self.autonomy = autonomy
        self.db = db
        self.cardId = cardId
        self.runId = runId
        self.campId = campId
        self.workflow = workflow
    }

    public func execute(input: JSONValue) async -> ToolOutcome {
        let hash: String
        do {
            hash = try ApprovalToken.hash(input: input)
        } catch {
            return .error("审批参数无法规范化：\(error)")
        }

        let match: ApprovalGrantMatchV1
        do {
            match = try ApprovalGrantStore(database: db).matchGrant(
                cardId: cardId,
                toolId: toolName,
                inputHash: hash,
                at: Date()
            )
        } catch {
            return .error(
                "审批授权读取失败：\(String(reflecting: type(of: error)))"
            )
        }
        switch match {
        case let .authorized(grant):
            guard let workflow, let campId else {
                return .error("外部操作协调器不可用，已阻止工具执行。")
            }
            do {
                let adapter = try ToolHandlerExternalOperationAdapterV1(
                    toolId: toolName,
                    inner: inner
                )
                let acknowledgment = try await workflow.execute(
                    grantId: grant.id,
                    expectedGrantVersion: grant.version,
                    capability: grant.capability,
                    campId: campId,
                    cardId: cardId,
                    toolId: toolName,
                    input: input,
                    adapter: adapter
                )
                if let local = await adapter.takeLocalOutcome(
                    useId: acknowledgment.useId
                ) {
                    return local
                }
                switch acknowledgment.state {
                case .succeeded:
                    return .result("该操作已有成功的持久化回执。")
                case .failedFinal:
                    return .error("该操作已有失败的持久化回执。")
                case .abandonedUnknown, .crashUnknown:
                    return .error("该操作结果仍需用户确认，未自动重放。")
                case .released:
                    return .error("适配器确认操作未发生，请重新发起审批。")
                case .reserved, .dispatching, .accepted:
                    return .error("外部操作未进入终态，已停止继续执行。")
                }
            } catch {
                return .error(
                    "外部操作未完成：\(String(reflecting: type(of: error)))"
                )
            }

        case let .denied(reason):
            let reasonSuffix = reason.map { "：\($0)" } ?? ""
            return .error("用户拒绝了此操作\(reasonSuffix)。请换一种做法，或用 block_card 说明无法继续。")

        case .unavailable, .absent:
            do {
                let compatibilitySuffix = autonomy.requiresApproval(
                    risk: ToolDef.risk(toolName)
                ) ? "" : "（显式 Grant 必需）"
                _ = try db.suspendCardForApproval(
                    cardId: cardId,
                    runId: runId,
                    prompt: ApprovalToken.prompt(
                        tool: toolName,
                        input: input
                    ),
                    tool: toolName,
                    input: input,
                    inputHash: hash
                )
                return .blocked(
                    reason: "needs_human_input",
                    detail: "等待你批准：\(ToolDef.displayName(toolName))\(compatibilitySuffix)"
                )
            } catch {
                return .error("审批请求落库失败：\(error)")
            }
        }
    }
}
