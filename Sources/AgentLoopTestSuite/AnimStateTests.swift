import Testing
import Foundation
import AgentLoopCore

@Test func deriveMatrixCoversAllPriorities() throws {
    let companion = "companion-a"
    let other = "companion-b"

    #expect(AnimStateDeriver.derive(
        companionId: companion,
        cards: [],
        phases: [:],
        recentlyCompletedCardIds: []
    ) == .idle)

    #expect(AnimStateDeriver.derive(
        companionId: companion,
        cards: [animCard(id: "other-ready", assigneeId: other, status: .ready)],
        phases: [:],
        recentlyCompletedCardIds: []
    ) == .idle)

    #expect(AnimStateDeriver.derive(
        companionId: companion,
        cards: [animCard(id: "ready", assigneeId: companion, status: .ready)],
        phases: [:],
        recentlyCompletedCardIds: []
    ) == .napping)

    #expect(AnimStateDeriver.derive(
        companionId: companion,
        cards: [animCard(id: "running", assigneeId: companion, status: .running)],
        phases: ["running": .waitingProvider],
        recentlyCompletedCardIds: []
    ) == .thinking)

    #expect(AnimStateDeriver.derive(
        companionId: companion,
        cards: [animCard(id: "running", assigneeId: companion, status: .running)],
        phases: ["running": .streaming],
        recentlyCompletedCardIds: []
    ) == .thinking)

    #expect(AnimStateDeriver.derive(
        companionId: companion,
        cards: [animCard(id: "running", assigneeId: companion, status: .running)],
        phases: ["running": .toolRunning],
        recentlyCompletedCardIds: []
    ) == .working)

    #expect(AnimStateDeriver.derive(
        companionId: companion,
        cards: [animCard(
            id: "ask",
            assigneeId: companion,
            status: .blocked,
            blockedReasonJson: #"{"detail":"p","reason":"needs_human_input","userRequestId":"r"}"#
        )],
        phases: [:],
        recentlyCompletedCardIds: []
    ) == .asking)

    #expect(AnimStateDeriver.derive(
        companionId: companion,
        cards: [animCard(
            id: "blocked",
            assigneeId: companion,
            status: .blocked,
            blockedReasonJson: #"{"detail":"bad","reason":"tool_failure"}"#
        )],
        phases: [:],
        recentlyCompletedCardIds: []
    ) == .scratching)

    #expect(AnimStateDeriver.derive(
        companionId: companion,
        cards: [
            animCard(
                id: "ask",
                assigneeId: companion,
                status: .blocked,
                blockedReasonJson: #"{"detail":"p","reason":"needs_human_input","userRequestId":"r"}"#
            ),
            animCard(id: "done", assigneeId: companion, status: .done),
        ],
        phases: [:],
        recentlyCompletedCardIds: ["done"]
    ) == .celebrating)

    #expect(AnimStateDeriver.derive(
        companionId: companion,
        cards: [animCard(id: "done", assigneeId: companion, status: .done)],
        phases: [:],
        recentlyCompletedCardIds: []
    ) == .idle)
}

@Test func humanAnswerRendering() {
    let created = Date()
    let choice = UserRequestRecord(
        id: "choice",
        cardId: "card",
        kind: .choice,
        prompt: "p",
        optionsJson: #"["A","B"]"#,
        answerJson: #"{"choice":1}"#,
        createdAt: created,
        answeredAt: created
    )
    let outOfBounds = UserRequestRecord(
        id: "choice-2",
        cardId: "card",
        kind: .choice,
        prompt: "p",
        optionsJson: #"["A","B"]"#,
        answerJson: #"{"choice":4}"#,
        createdAt: created,
        answeredAt: created
    )
    let confirm = UserRequestRecord(
        id: "confirm",
        cardId: "card",
        kind: .confirm,
        prompt: "p",
        optionsJson: nil,
        answerJson: #"{"confirm":false}"#,
        createdAt: created,
        answeredAt: created
    )
    let text = UserRequestRecord(
        id: "text",
        cardId: "card",
        kind: .text,
        prompt: "p",
        optionsJson: nil,
        answerJson: #"{"text":"补充"}"#,
        createdAt: created,
        answeredAt: created
    )

    #expect(choice.humanAnswer() == "B")
    #expect(outOfBounds.humanAnswer() == "选项 5")
    #expect(confirm.humanAnswer() == "否")
    #expect(text.humanAnswer() == "补充")
}

private func animCard(
    id: String,
    assigneeId: String?,
    status: CardStatus,
    blockedReasonJson: String? = nil
) -> CardRecord {
    CardRecord(
        id: id,
        missionId: "mission",
        idemKey: id,
        title: id,
        descriptionText: "d",
        expectedOutput: "e",
        assigneeId: assigneeId,
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
