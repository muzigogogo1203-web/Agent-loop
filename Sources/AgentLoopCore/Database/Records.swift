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
             (.todo, .canceled), (.ready, .canceled),
             (.running, .ready),    // §14 crash-recovery: interrupt returns card to ready
             (.running, .canceled): // §13 budget-exhausted early-close terminalization
            return true
        default: return false
        }
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

// MARK: - Camp

public struct CampRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "camp"
    public var id: String
    public var name: String
    public var createdAt: Date

    public init(id: String, name: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

// MARK: - Companion

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
    public var createdAt: Date

    public init(id: String, name: String, color: String, rolePrompt: String,
                model: String, toolsJson: String, kind: Kind, campId: String?, createdAt: Date) {
        self.id = id
        self.name = name
        self.color = color
        self.rolePrompt = rolePrompt
        self.model = model
        self.toolsJson = toolsJson
        self.kind = kind
        self.campId = campId
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
    public var createdAt: Date

    public init(id: String, campId: String, name: String, memberIdsJson: String,
                workspacePath: String?, createdAt: Date) {
        self.id = id
        self.campId = campId
        self.name = name
        self.memberIdsJson = memberIdsJson
        self.workspacePath = workspacePath
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
    public var status: String
    public var budgetTokens: Int
    public var spentTokens: Int
    public var revision: Int
    public var createdAt: Date

    public init(id: String, squadId: String, goalRaw: String, goalRefined: String,
                status: String, budgetTokens: Int, spentTokens: Int, revision: Int, createdAt: Date) {
        self.id = id
        self.squadId = squadId
        self.goalRaw = goalRaw
        self.goalRefined = goalRefined
        self.status = status
        self.budgetTokens = budgetTokens
        self.spentTokens = spentTokens
        self.revision = revision
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
    public var maxTurns: Int
    public var tokenBudget: Int
    public var createdAt: Date

    public init(id: String, missionId: String, idemKey: String, title: String,
                descriptionText: String, expectedOutput: String, assigneeId: String?,
                status: CardStatus, blockedReasonJson: String?, dependsOnJson: String,
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
}

// MARK: - camp_note and user_request are schema-only in M1 (no Swift records needed yet)
