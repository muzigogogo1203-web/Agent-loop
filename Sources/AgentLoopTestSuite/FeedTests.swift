import Testing
import Foundation
import GRDB
import AgentLoopCore

@Test func feedMapsEventKindsToEntries() throws {
    let companion = CompanionRecord(
        id: "companion-a",
        name: "甲",
        color: "blue",
        rolePrompt: "r",
        model: "m",
        toolsJson: "[]",
        kind: .regular,
        campId: nil,
        createdAt: Date()
    )
    let card = CardRecord(
        id: "card-a",
        missionId: "mission-a",
        idemKey: "k",
        title: "A",
        descriptionText: "d",
        expectedOutput: "e",
        assigneeId: companion.id,
        status: .running,
        blockedReasonJson: nil,
        dependsOnJson: "[]",
        handoffJson: nil,
        stage: 1,
        maxTurns: 3,
        tokenBudget: 100,
        createdAt: Date()
    )
    let now = Date()
    let events: [EventRecord] = [
        event(kind: "mission_created", payload: ["goal": "做事"], createdAt: now),
        event(kind: "plan_completed", payload: ["cardIds": ["a", "b"]], createdAt: now.addingTimeInterval(1)),
        event(kind: "plan_fallback", payload: ["reason": "fallback"], createdAt: now.addingTimeInterval(2)),
        event(kind: "card_started", cardId: card.id, payload: [:], createdAt: now.addingTimeInterval(3)),
        event(kind: "progress_note", cardId: card.id, payload: ["text": "到一半"], createdAt: now.addingTimeInterval(4)),
        event(kind: "user_request_created", cardId: card.id, payload: [
            "kind": "choice",
            "prompt": "选？",
            "userRequestId": "request-a",
        ], createdAt: now.addingTimeInterval(5)),
        event(kind: "user_request_answered", cardId: card.id, payload: ["userRequestId": "request-a"], createdAt: now.addingTimeInterval(6)),
        event(kind: "card_blocked", cardId: card.id, payload: ["reason": "tool_failure", "detail": "坏了"], createdAt: now.addingTimeInterval(7)),
        event(kind: "card_blocked", cardId: card.id, payload: ["reason": "needs_human_input", "detail": "问题"], createdAt: now.addingTimeInterval(8)),
        event(kind: "card_completed", cardId: card.id, payload: ["summary": "完成了"], createdAt: now.addingTimeInterval(9)),
        event(kind: "card_canceled", cardId: card.id, payload: [:], createdAt: now.addingTimeInterval(10)),
        event(kind: "mission_status_changed", payload: ["to": "delivering"], createdAt: now.addingTimeInterval(11)),
        event(kind: "mission_status_changed", payload: ["to": "executing"], createdAt: now.addingTimeInterval(12)),
        event(kind: "mission_accepted", payload: [:], createdAt: now.addingTimeInterval(13)),
        event(kind: "mission_failed", payload: ["reason": "abandoned"], createdAt: now.addingTimeInterval(14)),
        event(kind: "kernel_error", payload: ["message": "boom"], createdAt: now.addingTimeInterval(15)),
        event(kind: "plan_started", payload: [:], createdAt: now.addingTimeInterval(16)),
    ]

    let entries = ActivityFeed.entries(events: events, cards: [card], companions: [companion.id: companion])
    #expect(entries.map(\.kind) == [
        .directive,
        .planned,
        .planned,
        .claimed,
        .progress,
        .question,
        .progress,
        .blocked,
        .delivered,
        .canceled,
        .statusChange,
        .statusChange,
        .statusChange,
        .error,
    ])
    #expect(entries[0].text.contains("做事"))
    #expect(entries.contains { $0.kind == .blocked && $0.text.contains("坏了") })
    #expect(!entries.contains { $0.text.contains("问题") && $0.kind == .blocked })
    #expect(entries.last?.text.contains("boom") == true)
}

@Test func feedQuestionCarriesRequestId() throws {
    let card = CardRecord(
        id: "card-a",
        missionId: "mission-a",
        idemKey: "k",
        title: "A",
        descriptionText: "d",
        expectedOutput: "e",
        assigneeId: nil,
        status: .blocked,
        blockedReasonJson: nil,
        dependsOnJson: "[]",
        handoffJson: nil,
        stage: 1,
        maxTurns: 3,
        tokenBudget: 100,
        createdAt: Date()
    )
    let entries = ActivityFeed.entries(
        events: [event(kind: "user_request_created", cardId: card.id, payload: [
            "kind": "text",
            "prompt": "补充？",
            "userRequestId": "request-1",
        ])],
        cards: [card],
        companions: [:]
    )
    #expect(entries.count == 1)
    #expect(entries[0].userRequestId == "request-1")
    #expect(entries[0].cardId == card.id)
}

@Test func feedHandlesDuplicateCardIds() throws {
    let first = feedCard(id: "card-a", status: .running)
    let duplicate = feedCard(id: "card-a", status: .running)
    let entries = ActivityFeed.entries(
        events: [event(kind: "progress_note", cardId: "card-a", payload: ["text": "ok"])],
        cards: [first, duplicate],
        companions: [:]
    )

    #expect(entries.count == 1)
    #expect(entries[0].text == "ok")
}

@Test func pendingRequestForCanceledCardIsHidden() throws {
    let requestId = "request-a"
    let visibleCard = feedCard(
        id: "card-visible",
        status: .blocked,
        blockedReasonJson: try JSONValue.object([
            "reason": .string("needs_human_input"),
            "userRequestId": .string(requestId),
        ]).encodedString()
    )
    let canceledCard = feedCard(
        id: "card-canceled",
        status: .canceled,
        blockedReasonJson: try JSONValue.object([
            "reason": .string("needs_human_input"),
            "userRequestId": .string("request-canceled"),
        ]).encodedString()
    )
    let requests = [
        UserRequestRecord(
            id: requestId,
            cardId: visibleCard.id,
            kind: .choice,
            prompt: "选？",
            optionsJson: #"["A","B"]"#,
            answerJson: nil,
            createdAt: Date(),
            answeredAt: nil
        ),
        UserRequestRecord(
            id: "request-canceled",
            cardId: canceledCard.id,
            kind: .text,
            prompt: "旧问题",
            optionsJson: nil,
            answerJson: nil,
            createdAt: Date(),
            answeredAt: nil
        ),
    ]

    let visible = ActivityFeed.visiblePendingRequests(requests, cards: [visibleCard, canceledCard])
    #expect(visible.map(\.id) == [requestId])
}

@Test func feedCapsAtLimit() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let db = try AppDatabase(path: dir.appendingPathComponent("test.sqlite").path)
    let ids = try db.createSingleCardMission(
        campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e",
        assigneeId: nil, maxTurns: 3)
    try db.startRun(cardId: ids.cardId, runId: "run")
    try db.appendDiagnosticEvent(cardId: ids.cardId, runId: "run", kind: "progress_note", payload: ["text": "2"])
    try db.appendDiagnosticEvent(cardId: ids.cardId, runId: "run", kind: "progress_note", payload: ["text": "3"])

    let events = try db.events(missionId: ids.missionId, limit: 2)
    #expect(events.map(\.kind) == ["progress_note", "progress_note"])
    #expect(events[0].payloadJson.contains("2"))
    #expect(events[1].payloadJson.contains("3"))
}

private func feedCard(
    id: String,
    status: CardStatus,
    blockedReasonJson: String? = nil
) -> CardRecord {
    CardRecord(
        id: id,
        missionId: "mission-a",
        idemKey: "k-\(id)",
        title: "A",
        descriptionText: "d",
        expectedOutput: "e",
        assigneeId: nil,
        status: status,
        blockedReasonJson: blockedReasonJson,
        dependsOnJson: "[]",
        handoffJson: nil,
        stage: 1,
        maxTurns: 3,
        tokenBudget: 100,
        createdAt: Date()
    )
}

private func event(
    kind: String,
    cardId: String? = nil,
    payload: JSONValue,
    createdAt: Date = Date()
) -> EventRecord {
    EventRecord(
        id: UUID().uuidString,
        missionId: "mission-a",
        cardId: cardId,
        runId: nil,
        kind: kind,
        payloadJson: (try? payload.encodedString()) ?? "{}",
        createdAt: createdAt
    )
}
