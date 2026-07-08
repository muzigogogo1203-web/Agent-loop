import Foundation

public struct FeedEntry: Sendable, Identifiable, Equatable {
    public enum Actor: Sendable, Equatable {
        case companion(id: String, name: String)
        case system
        case user
    }

    public enum Kind: Sendable, Equatable {
        case directive
        case planned
        case claimed
        case progress
        case question
        case blocked
        case delivered
        case canceled
        case statusChange
        case error
    }

    public let id: String
    public let timestamp: Date
    public let actor: Actor
    public let kind: Kind
    public let text: String
    public let cardId: String?
    public let userRequestId: String?

    public init(
        id: String,
        timestamp: Date,
        actor: Actor,
        kind: Kind,
        text: String,
        cardId: String?,
        userRequestId: String?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.actor = actor
        self.kind = kind
        self.text = text
        self.cardId = cardId
        self.userRequestId = userRequestId
    }
}

public enum ActivityFeed {
    public static func entries(
        events: [EventRecord],
        cards: [CardRecord],
        companions: [String: CompanionRecord]
    ) -> [FeedEntry] {
        let cardsById = Dictionary(cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return events.compactMap { event in
            let payload = (try? JSONValue.decoded(from: event.payloadJson)) ?? .object([:])
            let actor = actor(for: event, cardsById: cardsById, companions: companions)
            switch event.kind {
            case EventKind.missionCreated:
                return entry(event, actor: .user, kind: .directive,
                             text: payload["goal"]?.stringValue ?? "新行动")
            case EventKind.planCompleted:
                let count = payload["cardIds"]?.arrayValue?.count ?? 0
                return entry(event, actor: .system, kind: .planned,
                             text: "已规划 \(count) 个小目标")
            case EventKind.planFallback:
                let reason = payload["reason"]?.stringValue ?? "使用回退规划"
                return entry(event, actor: .system, kind: .planned,
                             text: "规划回退：\(reason)")
            case EventKind.cardStarted:
                return entry(event, actor: actor, kind: .claimed, text: "接下了小目标")
            case EventKind.progressNote:
                return entry(event, actor: actor, kind: .progress,
                             text: payload["text"]?.stringValue ?? "有新进展")
            case EventKind.userRequestCreated:
                return entry(
                    event,
                    actor: actor,
                    kind: .question,
                    text: payload["prompt"]?.stringValue ?? "需要用户补充",
                    userRequestId: payload["userRequestId"]?.stringValue
                )
            case EventKind.userRequestAnswered:
                return entry(
                    event,
                    actor: .user,
                    kind: .progress,
                    text: "已回复",
                    userRequestId: payload["userRequestId"]?.stringValue
                )
            case EventKind.cardBlocked:
                guard payload["reason"]?.stringValue != "needs_human_input" else { return nil }
                return entry(event, actor: actor, kind: .blocked,
                             text: payload["detail"]?.stringValue ?? "小目标受阻")
            case EventKind.cardCompleted:
                return entry(event, actor: actor, kind: .delivered,
                             text: payload["summary"]?.stringValue ?? "已交付")
            case EventKind.cardCanceled:
                return entry(event, actor: .system, kind: .canceled, text: "小目标已取消")
            case EventKind.missionStatusChanged:
                guard payload["to"]?.stringValue == MissionStatus.delivering.rawValue else { return nil }
                return entry(event, actor: .system, kind: .statusChange,
                             text: "全部小目标完成，等你收营")
            case EventKind.missionBudgetExhausted:
                return entry(event, actor: .system, kind: .statusChange,
                             text: "预算见底了，等你拿主意：加预算、就地收成果，或放弃")
            case EventKind.budgetAdded:
                let tokens = payload["tokens"]?.intValue ?? 0
                return entry(event, actor: .user, kind: .progress,
                             text: "追加了 \(tokens / 1000)k 预算，继续")
            case EventKind.missionAccepted:
                return entry(event, actor: .system, kind: .statusChange, text: "行动已收营")
            case EventKind.missionFailed:
                return entry(event, actor: .system, kind: .statusChange, text: "行动已失败")
            case EventKind.kernelError:
                return entry(event, actor: .system, kind: .error,
                             text: payload["message"]?.stringValue ?? "内核错误")
            case EventKind.mcpServerDown:
                let server = payload["serverName"]?.stringValue ?? "未知"
                return entry(event, actor: .system, kind: .blocked,
                             text: "驿站「\(server)」停摆了——它不会自动重启，可到「设置 → MCP 驿站」手动重启")
            default:
                return nil
            }
        }
    }

    public static func visiblePendingRequests(
        _ requests: [UserRequestRecord],
        cards: [CardRecord]
    ) -> [UserRequestRecord] {
        let cardsById = Dictionary(cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return requests.filter { request in
            guard let card = cardsById[request.cardId],
                  card.status == .blocked,
                  blockedUserRequestId(card) == request.id else {
                return false
            }
            return true
        }
    }

    private static func actor(
        for event: EventRecord,
        cardsById: [String: CardRecord],
        companions: [String: CompanionRecord]
    ) -> FeedEntry.Actor {
        guard let cardId = event.cardId,
              let assigneeId = cardsById[cardId]?.assigneeId,
              let companion = companions[assigneeId] else {
            return .system
        }
        return .companion(id: companion.id, name: companion.name)
    }

    private static func entry(
        _ event: EventRecord,
        actor: FeedEntry.Actor,
        kind: FeedEntry.Kind,
        text: String,
        userRequestId: String? = nil
    ) -> FeedEntry {
        FeedEntry(
            id: event.id,
            timestamp: event.createdAt,
            actor: actor,
            kind: kind,
            text: text,
            cardId: event.cardId,
            userRequestId: userRequestId
        )
    }

    private static func blockedUserRequestId(_ card: CardRecord) -> String? {
        guard let json = card.blockedReasonJson,
              let value = try? JSONValue.decoded(from: json),
              value["reason"]?.stringValue == "needs_human_input" else {
            return nil
        }
        return value["userRequestId"]?.stringValue
    }
}
