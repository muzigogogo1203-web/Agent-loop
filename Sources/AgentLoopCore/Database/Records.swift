import Foundation
import GRDB

// MARK: - Card Status + Transition Machine

public enum CardStatus: String, Sendable, Codable, CaseIterable {
    case todo, ready, running, done, blocked, canceled

    /// spec §5.1 exhaustive transitions + §13/§14 supplemental pairs
    public func canTransition(to next: CardStatus) -> Bool {
        switch (self, next) {
        case (.todo, .ready), (.ready, .running), (.running, .done),
             (.running, .blocked), (.blocked, .ready), (.blocked, .canceled),
             (.todo, .canceled), (.ready, .canceled), (.ready, .blocked),
             (.running, .ready),    // §14 crash-recovery: interrupt returns card to ready
             (.running, .canceled), // §13 budget-exhausted early-close terminalization
             (.done, .ready):       // M9-D4: user returns a completed card for rework
            return true
        default: return false
        }
    }
}

public enum MissionStatus: String, Sendable, Codable {
    case planning, executing, delivering, accepted, failed
}

extension MissionStatus {
    public static func rollup(current: MissionStatus, cards: [CardStatus]) -> MissionStatus {
        switch current {
        case .accepted, .failed:
            return current
        case .planning, .executing, .delivering:
            break
        }

        guard !cards.isEmpty else {
            return .planning
        }

        let terminal: Set<CardStatus> = [.done, .canceled]
        if cards.contains(where: { !terminal.contains($0) }) {
            return .executing
        }

        if cards.contains(.done) {
            return .delivering
        }

        return .failed
    }
}

public struct CardTransitionError: Error, Equatable {
    public let from: CardStatus
    public let to: CardStatus
    public init(from: CardStatus, to: CardStatus) {
        self.from = from
        self.to = to
    }
}

public struct RecordNotFoundError: Error, Equatable {
    public let table: String
    public let id: String
    public init(table: String, id: String) {
        self.table = table
        self.id = id
    }
}

public struct StaleUserRequestError: Error, Equatable, Sendable {
    public let requestId: String
    public init(requestId: String) {
        self.requestId = requestId
    }
}

// MARK: - Kernel Control

/// Stable, durable dispatch modes. In-process transition phases such as
/// halting/resuming intentionally do not belong in this projection.
public enum DispatchMode: String, Codable, Sendable {
    case running, halted
}

public struct KernelControlRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "kernel_control"
    public var id: String
    public var dispatchMode: DispatchMode
    public var updatedAt: Date

    public init(id: String, dispatchMode: DispatchMode, updatedAt: Date) {
        self.id = id
        self.dispatchMode = dispatchMode
        self.updatedAt = updatedAt
    }
}

public struct StaleKernelControlStateError: Error, Equatable, Sendable {
    public let expected: DispatchMode
    public let actual: DispatchMode

    public init(expected: DispatchMode, actual: DispatchMode) {
        self.expected = expected
        self.actual = actual
    }
}

public struct CampArchivedError: Error, Equatable, Sendable {
    public let campId: String
    public init(campId: String) {
        self.campId = campId
    }
}

// MARK: - Camp

public struct CampRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "camp"
    public var id: String
    public var name: String
    public var archived: Bool
    public var createdAt: Date

    public init(id: String, name: String, archived: Bool = false, createdAt: Date) {
        self.id = id
        self.name = name
        self.archived = archived
        self.createdAt = createdAt
    }
}

// MARK: - Companion

public enum RuntimeProfileKind: String, Codable, Sendable, CaseIterable {
    case anthropicAPI = "anthropic_api"
    case openAIAPI = "openai_api"
    case chatGPTOAuth = "chatgpt_oauth"
    case cliCodex = "cli_codex"
    case cliClaude = "cli_claude"
}

extension RuntimeProfileKind {
    public var isCLI: Bool {
        switch self {
        case .cliCodex, .cliClaude:
            return true
        case .anthropicAPI, .openAIAPI, .chatGPTOAuth:
            return false
        }
    }
}

public enum CompanionModelPolicy: String, Codable, Sendable, CaseIterable {
    case inherit
    case pinned
}

public struct RuntimeProfileRecord: Codable, Sendable, FetchableRecord, PersistableRecord, Identifiable, Equatable {
    public static let databaseTableName = "runtime_profile"

    public var id: String
    public var kind: RuntimeProfileKind
    public var name: String
    public var baseURL: String?
    public var credentialAccount: String?
    public var isDefault: Bool
    public var createdAt: Date

    public init(
        id: String,
        kind: RuntimeProfileKind,
        name: String,
        baseURL: String?,
        credentialAccount: String?,
        isDefault: Bool,
        createdAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.baseURL = baseURL
        self.credentialAccount = credentialAccount
        self.isDefault = isDefault
        self.createdAt = createdAt
    }

    public static func new(
        kind: RuntimeProfileKind,
        name: String,
        baseURL: String? = nil,
        credentialAccount: String? = nil,
        isDefault: Bool = false
    ) -> RuntimeProfileRecord {
        RuntimeProfileRecord(
            id: UUID().uuidString,
            kind: kind,
            name: name,
            baseURL: baseURL,
            credentialAccount: credentialAccount,
            isDefault: isDefault,
            createdAt: Date()
        )
    }
}

public struct ReconciliationItem: Sendable, Equatable, Identifiable {
    public enum Scope: Sendable, Equatable {
        case companion(id: String, name: String)
        case defaultModel
        case distillModel
        case plannerModel
    }

    public let id: String
    public let scope: Scope
    public let model: String
    public let profileId: String
    public let profileName: String

    public init(scope: Scope, model: String, profileId: String, profileName: String) {
        self.scope = scope
        self.model = model
        self.profileId = profileId
        self.profileName = profileName
        switch scope {
        case .companion(let id, _):
            self.id = "companion:\(id):\(profileId):\(model)"
        case .defaultModel:
            self.id = "default:\(profileId):\(model)"
        case .distillModel:
            self.id = "distill:\(profileId):\(model)"
        case .plannerModel:
            self.id = "planner:\(profileId):\(model)"
        }
    }
}

public struct CompanionRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "companion"

    public enum Kind: String, Codable, Sendable {
        case regular, guide
    }

    public var id: String
    public var name: String
    public var color: String
    public var rolePrompt: String
    public var model: String
    public var toolsJson: String
    public var kind: Kind
    public var campId: String?
    public var runtimeProfileId: String?
    public var modelPolicy: CompanionModelPolicy
    public var createdAt: Date

    public init(id: String, name: String, color: String, rolePrompt: String,
                model: String, toolsJson: String, kind: Kind, campId: String?,
                runtimeProfileId: String? = nil, modelPolicy: CompanionModelPolicy = .pinned,
                createdAt: Date) {
        self.id = id
        self.name = name
        self.color = color
        self.rolePrompt = rolePrompt
        self.model = model
        self.toolsJson = toolsJson
        self.kind = kind
        self.campId = campId
        self.runtimeProfileId = runtimeProfileId
        self.modelPolicy = modelPolicy
        self.createdAt = createdAt
    }

    public static func new(name: String, color: String, rolePrompt: String, model: String,
                           kind: Kind = .regular, campId: String? = nil) -> CompanionRecord {
        .init(id: UUID().uuidString, name: name, color: color, rolePrompt: rolePrompt,
              model: model, toolsJson: "[]", kind: kind, campId: campId, createdAt: Date())
    }
}

// MARK: - Squad

public struct SquadRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "squad"
    public var id: String
    public var campId: String
    public var name: String
    public var memberIdsJson: String
    public var workspacePath: String?
    /// 安全作用域书签（M5-1）：沙箱下重启后恢复工作目录权限；nil = 纯 path 语义
    public var workspaceBookmark: Data?
    public var createdAt: Date

    public init(id: String, campId: String, name: String, memberIdsJson: String,
                workspacePath: String?, workspaceBookmark: Data? = nil, createdAt: Date) {
        self.id = id
        self.campId = campId
        self.name = name
        self.memberIdsJson = memberIdsJson
        self.workspacePath = workspacePath
        self.workspaceBookmark = workspaceBookmark
        self.createdAt = createdAt
    }
}

// MARK: - Mission

public struct MissionRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "mission"
    public var id: String
    public var squadId: String
    public var goalRaw: String
    public var goalRefined: String
    public var status: MissionStatus
    public var budgetTokens: Int
    public var spentTokens: Int
    public var revision: Int
    /// 自主档位（M7-D2，迁移 v5）：谨慎/标准/放手，决定审批矩阵
    public var autonomy: MissionAutonomy
    public var createdAt: Date

    public init(id: String, squadId: String, goalRaw: String, goalRefined: String,
                status: MissionStatus, budgetTokens: Int, spentTokens: Int, revision: Int,
                autonomy: MissionAutonomy = .standard, createdAt: Date) {
        self.id = id
        self.squadId = squadId
        self.goalRaw = goalRaw
        self.goalRefined = goalRefined
        self.status = status
        self.budgetTokens = budgetTokens
        self.spentTokens = spentTokens
        self.revision = revision
        self.autonomy = autonomy
        self.createdAt = createdAt
    }
}

// MARK: - Card

public struct CardRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "card"
    public var id: String
    public var missionId: String
    public var idemKey: String
    public var title: String
    public var descriptionText: String
    public var expectedOutput: String
    public var assigneeId: String?
    public var status: CardStatus
    public var blockedReasonJson: String?
    public var dependsOnJson: String
    public var handoffJson: String?
    public var stage: Int
    /// M9-D4：上游退回后标记下游 done 卡「待复核」
    public var reviewFlag: String?
    public var maxTurns: Int
    public var tokenBudget: Int
    public var createdAt: Date

    public init(id: String, missionId: String, idemKey: String, title: String,
                descriptionText: String, expectedOutput: String, assigneeId: String?,
                status: CardStatus, blockedReasonJson: String?, dependsOnJson: String,
                handoffJson: String?, stage: Int, reviewFlag: String? = nil,
                maxTurns: Int, tokenBudget: Int, createdAt: Date) {
        self.id = id
        self.missionId = missionId
        self.idemKey = idemKey
        self.title = title
        self.descriptionText = descriptionText
        self.expectedOutput = expectedOutput
        self.assigneeId = assigneeId
        self.status = status
        self.blockedReasonJson = blockedReasonJson
        self.dependsOnJson = dependsOnJson
        self.handoffJson = handoffJson
        self.stage = stage
        self.reviewFlag = reviewFlag
        self.maxTurns = maxTurns
        self.tokenBudget = tokenBudget
        self.createdAt = createdAt
    }
}

// MARK: - Run

public struct RunRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "run"
    public var id: String
    public var cardId: String
    public var attempt: Int
    public var outcome: String?
    public var turns: Int
    public var tokensIn: Int
    public var tokensOut: Int
    public var startedAt: Date
    public var endedAt: Date?

    public init(id: String, cardId: String, attempt: Int, outcome: String?,
                turns: Int, tokensIn: Int, tokensOut: Int, startedAt: Date, endedAt: Date?) {
        self.id = id
        self.cardId = cardId
        self.attempt = attempt
        self.outcome = outcome
        self.turns = turns
        self.tokensIn = tokensIn
        self.tokensOut = tokensOut
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

// MARK: - Event (append-only — no UPDATE/DELETE paths)

public struct EventRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "event"
    public var id: String
    public var missionId: String?
    public var cardId: String?
    public var runId: String?
    public var kind: String
    public var payloadJson: String
    public var createdAt: Date

    public init(id: String, missionId: String?, cardId: String?, runId: String?,
                kind: String, payloadJson: String, createdAt: Date) {
        self.id = id
        self.missionId = missionId
        self.cardId = cardId
        self.runId = runId
        self.kind = kind
        self.payloadJson = payloadJson
        self.createdAt = createdAt
    }
}

// MARK: - Artifact

public struct ArtifactRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "artifact"
    public var id: String
    public var cardId: String
    public var path: String
    public var kind: String
    public var label: String
    public var createdAt: Date

    public init(id: String, cardId: String, path: String, kind: String, label: String, createdAt: Date) {
        self.id = id
        self.cardId = cardId
        self.path = path
        self.kind = kind
        self.label = label
        self.createdAt = createdAt
    }
}

// MARK: - User Request

public struct UserRequestRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "user_request"

    public enum Kind: String, Codable, Sendable {
        case choice, confirm, text
        /// M7-D3：工具动作审批（复用 ask_user 持久门；optionsJson 存 {tool, input, inputHash}）
        case approval
    }

    public var id: String
    public var cardId: String
    public var kind: Kind
    public var prompt: String
    public var optionsJson: String?
    public var answerJson: String?
    public var createdAt: Date
    public var answeredAt: Date?

    public init(
        id: String,
        cardId: String,
        kind: Kind,
        prompt: String,
        optionsJson: String?,
        answerJson: String?,
        createdAt: Date,
        answeredAt: Date?
    ) {
        self.id = id
        self.cardId = cardId
        self.kind = kind
        self.prompt = prompt
        self.optionsJson = optionsJson
        self.answerJson = answerJson
        self.createdAt = createdAt
        self.answeredAt = answeredAt
    }

    public func humanAnswer() -> String {
        guard let answerJson,
              let answer = try? JSONValue.decoded(from: answerJson) else {
            return ""
        }

        switch kind {
        case .choice:
            guard let choice = answer["choice"]?.intValue else { return "" }
            let options = optionsJson.flatMap { json -> [String]? in
                try? JSONDecoder().decode([String].self, from: Data(json.utf8))
            } ?? []
            if options.indices.contains(choice) {
                return options[choice]
            }
            return "选项 \(choice + 1)"
        case .confirm:
            guard let confirm = answer["confirm"]?.boolValue else { return "" }
            return confirm ? "确认" : "否"
        case .text:
            return answer["text"]?.stringValue ?? ""
        case .approval:
            // M7-D4：{"decision":"approve"} 或 {"decision":"deny","reason":…}
            guard let decision = answer["decision"]?.stringValue else { return "" }
            if decision == "approve" { return "已批准" }
            let reason = answer["reason"]?.stringValue
            return reason.map { "已拒绝：\($0)" } ?? "已拒绝"
        }
    }
}

/// 行动花销分账（M7-D7）：run 表按伙伴聚合 + 规划轮事件；口径为本地估算
public struct MissionSpendBreakdown: Sendable, Equatable {
    public struct CompanionSpend: Sendable, Equatable, Identifiable {
        public var id: String { companionId ?? "unassigned" }
        public let companionId: String?
        public let name: String
        public let tokens: Int

        public init(companionId: String?, name: String, tokens: Int) {
            self.companionId = companionId
            self.name = name
            self.tokens = tokens
        }
    }

    public let planningTokens: Int
    public let companions: [CompanionSpend]

    public init(planningTokens: Int, companions: [CompanionSpend]) {
        self.planningTokens = planningTokens
        self.companions = companions
    }
}

public enum AskUserAnswer: Sendable, Equatable {
    case choice(Int)
    case confirm(Bool)
    case text(String)
    /// M7-D4：审批答复（approved=false 时可附拒绝理由）
    case approval(approved: Bool, reason: String?)
}

// MARK: - Chat Thread

public struct ChatThreadRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "chat_thread"

    public enum Kind: String, Codable, Sendable {
        case dm, guide
    }

    public var id: String
    public var kind: Kind
    public var companionId: String
    public var campId: String?
    public var createdAt: Date

    public init(id: String, kind: Kind, companionId: String, campId: String?, createdAt: Date) {
        self.id = id
        self.kind = kind
        self.companionId = companionId
        self.campId = campId
        self.createdAt = createdAt
    }
}

// MARK: - Chat Message

public struct ChatMessageRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "chat_message"
    public var id: String
    public var threadId: String
    public var role: String
    public var contentJson: String
    public var distilled: Bool
    public var createdAt: Date

    public init(id: String, threadId: String, role: String, contentJson: String,
                distilled: Bool, createdAt: Date) {
        self.id = id
        self.threadId = threadId
        self.role = role
        self.contentJson = contentJson
        self.distilled = distilled
        self.createdAt = createdAt
    }

    /// Decode the plain-text body from contentJson (format: {"text": "..."})
    public var text: String {
        guard let data = contentJson.data(using: .utf8),
              let json = try? JSONDecoder().decode([String: String].self, from: data)
        else { return contentJson }
        return json["text"] ?? contentJson
    }

    /// contentJson 为类型化组队提案块时解析（{"type":"squad_proposal",...}），否则 nil。
    public var proposal: SquadProposalBlock? {
        guard contentJson.contains("squad_proposal"),
              let block = try? JSONDecoder().decode(SquadProposalBlock.self, from: Data(contentJson.utf8)),
              block.type == SquadProposalBlock.typeName
        else { return nil }
        return block
    }
}

// MARK: - Squad Proposal Block（向导组队提案，存于 chat_message.contentJson，spec §10.2）

public struct SquadProposalBlock: Codable, Sendable, Equatable {
    public static let typeName = "squad_proposal"

    public enum Status: String, Codable, Sendable {
        case pending, confirmed, dismissed
    }

    public var type: String
    public var proposalId: String
    public var name: String
    public var memberIds: [String]
    public var goal: String
    public var budget: Int?
    public var status: Status
    public var missionId: String?

    public init(proposalId: String, name: String, memberIds: [String], goal: String,
                budget: Int?, status: Status, missionId: String? = nil) {
        self.type = Self.typeName
        self.proposalId = proposalId
        self.name = name
        self.memberIds = memberIds
        self.goal = goal
        self.budget = budget
        self.status = status
        self.missionId = missionId
    }

    /// 持久化编码（sortedKeys——写库字节确定性纪律）。
    public func encodedString() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let json = String(data: try encoder.encode(self), encoding: .utf8) else {
            throw EncodingError.invalidValue(self, .init(codingPath: [], debugDescription: "UTF-8 encoding failed"))
        }
        return json
    }

    /// 提案块进对话历史（发给 LLM）时的占位文本。
    public var historyPlaceholder: String {
        let statusText: String
        switch status {
        case .pending: statusText = "等待用户确认"
        case .confirmed: statusText = "用户已确认并开工"
        case .dismissed: statusText = "用户已驳回"
        }
        return "[组队提案「\(name)」：\(goal)（\(statusText)）]"
    }
}

// MARK: - Camp Note（营地笔记，spec §9）

public struct CampNoteRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "camp_note"
    public var id: String
    public var campId: String
    public var missionId: String?
    public var title: String
    public var bodyMd: String
    public var pinned: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: String, campId: String, missionId: String?, title: String,
                bodyMd: String, pinned: Bool, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.campId = campId
        self.missionId = missionId
        self.title = title
        self.bodyMd = bodyMd
        self.pinned = pinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func new(campId: String, missionId: String? = nil,
                           title: String, bodyMd: String) -> CampNoteRecord {
        let now = Date()
        return .init(id: UUID().uuidString, campId: campId, missionId: missionId,
                     title: title, bodyMd: bodyMd, pinned: false, createdAt: now, updatedAt: now)
    }
}

// MARK: - Companion Note（伙伴记忆，spec §10.1）

public struct CompanionNoteRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "companion_note"
    public var id: String
    public var companionId: String
    public var sourceThreadId: String?
    public var title: String
    public var bodyMd: String
    public var pinned: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: String, companionId: String, sourceThreadId: String?, title: String,
                bodyMd: String, pinned: Bool, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.companionId = companionId
        self.sourceThreadId = sourceThreadId
        self.title = title
        self.bodyMd = bodyMd
        self.pinned = pinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func new(companionId: String, sourceThreadId: String? = nil,
                           title: String, bodyMd: String) -> CompanionNoteRecord {
        let now = Date()
        return .init(id: UUID().uuidString, companionId: companionId, sourceThreadId: sourceThreadId,
                     title: title, bodyMd: bodyMd, pinned: false, createdAt: now, updatedAt: now)
    }
}

// MARK: - MCP Server（驿站，M8-D2：全局注册 + 营地级启用）

public struct McpServerRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "mcp_server"
    public var id: String
    /// 展示名，同时是工具名 `mcp__<server>__<tool>` 的 server 段来源——建后不可改名
    /// （改名会使伙伴白名单里的显式工具名失配，McpStore 层不提供改名入口）。
    public var name: String
    public var command: String
    public var argsJson: String
    public var envJson: String
    /// 敏感 env 的 key 名清单（JSON 数组）。值不落库，存 Keychain
    /// account `mcp-<serverId>-<key>`（M8-D5），启动时合成注入。
    public var secretEnvKeysJson: String
    public var experimental: Bool
    public var createdAt: Date

    public init(id: String, name: String, command: String, argsJson: String, envJson: String,
                secretEnvKeysJson: String, experimental: Bool, createdAt: Date) {
        self.id = id
        self.name = name
        self.command = command
        self.argsJson = argsJson
        self.envJson = envJson
        self.secretEnvKeysJson = secretEnvKeysJson
        self.experimental = experimental
        self.createdAt = createdAt
    }

    public static func new(name: String, command: String, args: [String],
                           env: [String: String] = [:], secretEnvKeys: [String] = [],
                           experimental: Bool = false) -> McpServerRecord {
        .init(id: UUID().uuidString, name: name, command: command,
              argsJson: Self.encodeJson(args), envJson: Self.encodeJson(env),
              secretEnvKeysJson: Self.encodeJson(secretEnvKeys),
              experimental: experimental, createdAt: Date())
    }

    public var args: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(argsJson.utf8))) ?? []
    }

    public var env: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(envJson.utf8))) ?? [:]
    }

    public var secretEnvKeys: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(secretEnvKeysJson.utf8))) ?? []
    }

    private static func encodeJson(_ value: some Encodable) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }
}

public struct CampMcpEnableRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "camp_mcp_enable"
    public var campId: String
    public var serverId: String

    public init(campId: String, serverId: String) {
        self.campId = campId
        self.serverId = serverId
    }
}
