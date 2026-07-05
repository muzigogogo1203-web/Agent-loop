import Foundation

public enum TurnPhase: Sendable, Equatable {
    case waitingProvider
    case streaming
    case toolRunning
}

public enum CompanionAnimState: Sendable, Equatable {
    case idle
    case thinking
    case working
    case asking
    case scratching
    case celebrating
    case napping
}

public enum AnimStateDeriver {
    public static func derive(
        companionId: String,
        cards: [CardRecord],
        phases: [String: TurnPhase],
        recentlyCompletedCardIds: Set<String>
    ) -> CompanionAnimState {
        let ownCards = cards.filter { $0.assigneeId == companionId }
        guard !ownCards.isEmpty else { return .idle }

        if ownCards.contains(where: { recentlyCompletedCardIds.contains($0.id) }) {
            return .celebrating
        }
        if ownCards.contains(where: { $0.status == .blocked && blockedReason($0) == "needs_human_input" }) {
            return .asking
        }
        if ownCards.contains(where: { $0.status == .blocked }) {
            return .scratching
        }
        if ownCards.contains(where: { $0.status == .running && phases[$0.id] == .toolRunning }) {
            return .working
        }
        if ownCards.contains(where: { card in
            guard card.status == .running else { return false }
            return phases[card.id] == .waitingProvider || phases[card.id] == .streaming || phases[card.id] == nil
        }) {
            return .thinking
        }
        if ownCards.contains(where: { !isTerminal($0.status) }) {
            return .napping
        }
        return .idle
    }

    private static func blockedReason(_ card: CardRecord) -> String? {
        guard let json = card.blockedReasonJson,
              let value = try? JSONValue.decoded(from: json) else {
            return nil
        }
        return value["reason"]?.stringValue
    }

    private static func isTerminal(_ status: CardStatus) -> Bool {
        status == .done || status == .canceled
    }
}
