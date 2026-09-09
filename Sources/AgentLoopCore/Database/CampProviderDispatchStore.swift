import Foundation
import GRDB

/// A provider becomes callable only after it is wrapped by the P1-E dispatch
/// boundary. Global inference uses this registration without creating a Camp
/// dispatch row; Camp-scoped callers must additionally use the durable store.
package struct RegisteredProviderInferenceV1: Sendable {
    private let registeredProvider: any LLMProvider

    package init(_ registeredProvider: any LLMProvider) {
        self.registeredProvider = registeredProvider
    }

    package func turn(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        maxTokens: Int,
        onDelta: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> TurnResult {
        var result: TurnResult?
        for try await event in registeredProvider.streamTurn(
            system: system,
            history: history,
            tools: tools,
            toolChoice: .auto,
            maxTokens: maxTokens
        ) {
            switch event {
            case .textDelta(let text):
                onDelta(text)
            case .turn(let turn):
                guard result == nil else {
                    throw ProviderError.malformedStream(
                        "multiple registered provider turn results"
                    )
                }
                result = turn
            }
        }
        guard let result else {
            throw ProviderError.malformedStream(
                "no registered provider turn result"
            )
        }
        return result
    }

    package func singleTextTurn(
        system: String,
        user: String,
        maxTokens: Int
    ) async throws -> String {
        let result = try await turn(
            system: system,
            history: [.user(user)],
            tools: [],
            maxTokens: maxTokens
        )
        return result.content.compactMap { block -> String? in
            if case .text(let text) = block { return text }
            return nil
        }.joined()
    }
}

extension Distiller {
    public init(
        provider: any LLMProvider,
        maxTokens: Int = 2048
    ) {
        self.init(
            inference: RegisteredProviderInferenceV1(provider),
            maxTokens: maxTokens
        )
    }
}

extension GuideChatService {
    public init(db: AppDatabase, provider: any LLMProvider) {
        self.init(
            runtime: CampProviderRuntimeV1(
                database: db,
                registeredProvider: provider
            )
        )
    }
}

extension MemoryDistillService {
    public init(db: AppDatabase, provider: any LLMProvider) {
        let inference = RegisteredProviderInferenceV1(provider)
        self.init(
            db: db,
            distiller: Distiller(inference: inference),
            campRuntime: CampProviderRuntimeV1(
                database: db,
                registeredProvider: provider
            ),
            reporter: FailureReporter(database: db),
            traceFactory: .live
        )
    }

    package init(
        db: AppDatabase,
        provider: any LLMProvider,
        reporter: FailureReporter,
        traceFactory: OperationTraceFactory
    ) {
        let inference = RegisteredProviderInferenceV1(provider)
        self.init(
            db: db,
            distiller: Distiller(inference: inference),
            campRuntime: CampProviderRuntimeV1(
                database: db,
                registeredProvider: provider
            ),
            reporter: reporter,
            traceFactory: traceFactory
        )
    }
}

package struct CampProviderReturnedInferenceV1: Sendable, Equatable {
    package let claim: DurableWorkClaim
    package let dispatch: CampProviderDispatchSnapshotV1
    package let text: String
}

package enum CampProviderCallFailureCauseV1: Sendable, Equatable {
    case provider(ProviderError)
    case unknown(String)
}

package struct CampProviderCallFailureV1: Error, Sendable, Equatable {
    package let claim: DurableWorkClaim
    package let started: CampProviderDispatchSnapshotV1
    package let cause: CampProviderCallFailureCauseV1
}

package struct CampProviderRuntimeV1: Sendable {
    private static let leaseDuration: TimeInterval = 300

    private let database: AppDatabase
    private let dispatchStore: CampProviderDispatchStore
    private let inference: RegisteredProviderInferenceV1

    package init(
        database: AppDatabase,
        registeredProvider: any LLMProvider
    ) {
        self.database = database
        self.dispatchStore = CampProviderDispatchStore(database: database)
        self.inference = RegisteredProviderInferenceV1(registeredProvider)
    }

    package func beginMemoryPromotion(
        campId: String,
        aggregateId: String,
        inputJson: String,
        system: String,
        user: String,
        idempotencyKey: String,
        traceId: String
    ) async throws -> CampProviderReturnedInferenceV1 {
        _ = try CampProviderRoutePolicyV1.resolve(
            .guideDistillation(campId: campId)
        )
        let enqueued = try dispatchStore.enqueueMemoryPromotion(
            campId: campId,
            aggregateId: aggregateId,
            inputJson: inputJson,
            idempotencyKey: idempotencyKey,
            traceId: traceId,
            at: Date()
        )
        let claim = try DurableWorkStore(database: database).claim(
            workId: enqueued.id,
            workerId: "memory-provider:\(UUID().uuidString.lowercased())",
            now: Date(),
            leaseDuration: Self.leaseDuration
        )
        let requestJSON = try Self.requestJSON(
            system: system,
            history: [.user(user)],
            tools: [],
            maxTokens: 2048
        )
        let prepared = try dispatchStore.prepare(
            claim: claim,
            operationKind: .memoryPromotion,
            turnOrdinal: 0,
            requestJson: requestJSON,
            idempotencyKey: "\(claim.workId):\(claim.attempt):0",
            at: Date()
        )
        let started = try dispatchStore.start(
            dispatchId: prepared.id,
            expectedVersion: prepared.version,
            claim: claim,
            at: Date()
        )
        let turn: TurnResult
        do {
            turn = try await inference.turn(
                system: system,
                history: [.user(user)],
                tools: [],
                maxTokens: 2048
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as ProviderError {
            throw CampProviderCallFailureV1(
                claim: claim,
                started: started,
                cause: .provider(error)
            )
        } catch {
            throw CampProviderCallFailureV1(
                claim: claim,
                started: started,
                cause: .unknown(String(reflecting: type(of: error)))
            )
        }
        try Task.checkCancellation()
        let returned = try dispatchStore.recordReturned(
            dispatchId: started.id,
            expectedVersion: started.version,
            claim: claim,
            responseJson: try Self.responseJSON(turn),
            at: Date()
        )
        let text = turn.content.compactMap { block -> String? in
            if case .text(let value) = block { return value }
            return nil
        }.joined()
        return CampProviderReturnedInferenceV1(
            claim: claim,
            dispatch: returned,
            text: text
        )
    }

    package func consumeGuideDistillation(
        _ returned: CampProviderReturnedInferenceV1,
        note: CampNoteRecord?,
        capturedMessageIds: [String]
    ) throws -> CampProviderCompletionV1 {
        let capture = try ValidatedDistillationCapture(
            validating: capturedMessageIds
        )
        let outputJSON = try JSONValue.object([
            "noteId": note.map { .string($0.id) } ?? .null,
            "skipped": .bool(note == nil),
        ]).encodedString()
        return try dispatchStore.consume(
            dispatchId: returned.dispatch.id,
            expectedVersion: returned.dispatch.version,
            claim: returned.claim,
            outputJson: outputJSON,
            at: Date(),
            businessMutation: { transaction, _ in
                try AppDatabase.consumeCapturedDistillationMessages(
                    capture,
                    database: transaction
                )
                if let note {
                    guard note.campId == returned.dispatch.campId else {
                        throw CampProviderDispatchError.replayConflict
                    }
                    try note.insert(transaction)
                    _ = try AppDatabase.appendLegacyEventAndScope(
                        transaction,
                        missionId: nil,
                        cardId: nil,
                        runId: nil,
                        kind: EventKind.campNoteCreated,
                        payload: [
                            "noteId": .string(note.id),
                            "source": .string("guide_chat"),
                        ]
                    )
                }
            }
        )
    }

    package func consumeCampNote(
        _ returned: CampProviderReturnedInferenceV1,
        note: CampNoteRecord,
        missionId: String,
        source: String
    ) throws -> CampProviderCompletionV1 {
        guard note.campId == returned.dispatch.campId else {
            throw CampProviderDispatchError.replayConflict
        }
        let outputJSON = try JSONValue.object([
            "noteId": .string(note.id),
            "source": .string(source),
        ]).encodedString()
        return try dispatchStore.consume(
            dispatchId: returned.dispatch.id,
            expectedVersion: returned.dispatch.version,
            claim: returned.claim,
            outputJson: outputJSON,
            at: Date(),
            businessMutation: { transaction, _ in
                try note.insert(transaction)
                _ = try AppDatabase.appendLegacyEventAndScope(
                    transaction,
                    missionId: missionId,
                    cardId: nil,
                    runId: nil,
                    kind: EventKind.campNoteCreated,
                    payload: [
                        "noteId": .string(note.id),
                        "source": .string(source),
                    ]
                )
            }
        )
    }

    package func consumeCampFallback(
        _ failure: CampProviderCallFailureV1,
        note: CampNoteRecord,
        missionId: String
    ) throws -> CampProviderCompletionV1 {
        guard note.campId == failure.started.campId else {
            throw CampProviderDispatchError.replayConflict
        }
        let outputJSON = try JSONValue.object([
            "noteId": .string(note.id),
            "source": .string("fallback"),
        ]).encodedString()
        return try dispatchStore.completeStartedWithFallback(
            dispatchId: failure.started.id,
            expectedVersion: failure.started.version,
            claim: failure.claim,
            outputJson: outputJSON,
            at: Date(),
            businessMutation: { transaction, _ in
                try note.insert(transaction)
                _ = try AppDatabase.appendLegacyEventAndScope(
                    transaction,
                    missionId: missionId,
                    cardId: nil,
                    runId: nil,
                    kind: EventKind.campNoteCreated,
                    payload: [
                        "noteId": .string(note.id),
                        "source": .string("fallback"),
                    ]
                )
            }
        )
    }

    package func consumeCoworkMemory(
        _ returned: CampProviderReturnedInferenceV1,
        note: CompanionNoteRecord?,
        missionId: String
    ) throws -> CampProviderCompletionV1 {
        let outputJSON = try JSONValue.object([
            "noteId": note.map { .string($0.id) } ?? .null,
            "skipped": .bool(note == nil),
            "source": .string("cowork"),
        ]).encodedString()
        return try dispatchStore.consume(
            dispatchId: returned.dispatch.id,
            expectedVersion: returned.dispatch.version,
            claim: returned.claim,
            outputJson: outputJSON,
            at: Date(),
            businessMutation: { transaction, _ in
                if let note {
                    try LegacyContentScopeStore.recordCompanionNote(
                        note,
                        scope: .cowork(missionId: missionId),
                        expectedCampLifecycleVersion:
                            returned.dispatch.campLifecycleVersion,
                        in: transaction
                    )
                    _ = try AppDatabase.appendLegacyEventAndScope(
                        transaction,
                        missionId: missionId,
                        cardId: nil,
                        runId: nil,
                        kind: EventKind.companionNoteCreated,
                        payload: [
                            "companionId": .string(note.companionId),
                            "noteId": .string(note.id),
                            "source": .string("cowork"),
                        ]
                    )
                }
            }
        )
    }

    package func guideStream(
        campId: String,
        userText: String
    ) throws -> AsyncThrowingStream<GuideChatEvent, Error> {
        try CanonicalContractCodingV1.validateCampID(campId)
        try CanonicalContractCodingV1.validateNonempty(userText)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await runGuide(
                        campId: campId,
                        userText: userText,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func runGuide(
        campId: String,
        userText: String,
        continuation: AsyncThrowingStream<GuideChatEvent, Error>.Continuation
    ) async throws {
        let commandID = UUID().uuidString.lowercased()
        let enqueuedAt = Date()
        let preparation = try dispatchStore.enqueueGuideTurn(
            campId: campId,
            userText: userText,
            idempotencyKey: "guide-chat:\(campId):\(commandID)",
            traceId: "guide-chat:\(commandID)",
            at: enqueuedAt
        )
        let claim = try DurableWorkStore(database: database).claim(
            workId: preparation.work.id,
            workerId: "guide-provider:\(commandID)",
            now: Date(),
            leaseDuration: Self.leaseDuration
        )
        guard let guide = try database.guide(campId: campId) else {
            throw RecordNotFoundError(table: "companion(guide)", id: campId)
        }
        let historyBundle = try database.loadOrCreateGuideHistoryBundle(
            campId: campId
        )
        guard historyBundle.thread.id == preparation.thread.id else {
            throw CampProviderDispatchError.replayConflict
        }
        var history = historyBundle.messages.map { message in
            if let proposal = message.proposal {
                return APIMessage.assistant([
                    .text(proposal.historyPlaceholder),
                ])
            }
            return APIMessage(
                role: message.role == "user" ? .user : .assistant,
                content: [.text(message.text)]
            )
        }
        let system = Self.guideSystem(guide: guide)
        let executor = ToolExecutor(handlers: [
            "search_camp_notes": CampNotesSearchTool(
                db: database,
                campId: campId
            ),
            "camp_status": CampStatusTool(db: database, campId: campId),
        ])
        var replyParts: [String] = []
        var toolRounds = 0
        var turnOrdinal = 0

        while true {
            try Task.checkCancellation()
            let forceText = toolRounds >= GuideChatService.maxToolRounds
            let tools = forceText ? [] : ToolDef.guideTools
            let requestJSON = try Self.requestJSON(
                system: system,
                history: history,
                tools: tools,
                maxTokens: 4096
            )
            let prepared = try dispatchStore.prepare(
                claim: claim,
                operationKind: .guideChat,
                turnOrdinal: turnOrdinal,
                requestJson: requestJSON,
                idempotencyKey:
                    "\(claim.workId):\(claim.attempt):\(turnOrdinal)",
                at: Date()
            )
            let started = try dispatchStore.start(
                dispatchId: prepared.id,
                expectedVersion: prepared.version,
                claim: claim,
                at: Date()
            )
            let turn = try await inference.turn(
                system: system,
                history: history,
                tools: tools,
                maxTokens: 4096,
                onDelta: { text in continuation.yield(.textDelta(text)) }
            )
            try Task.checkCancellation()
            let returned = try dispatchStore.recordReturned(
                dispatchId: started.id,
                expectedVersion: started.version,
                claim: claim,
                responseJson: try Self.responseJSON(turn),
                at: Date()
            )
            let turnText = turn.content.compactMap { block -> String? in
                if case .text(let text) = block { return text }
                return nil
            }.joined()
            if !turnText.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty {
                replyParts.append(turnText)
            }

            if turn.stopReason == .toolUse,
               !turn.toolUses.isEmpty,
               !forceText
            {
                toolRounds += 1
                history.append(.assistant(turn.content))
                var results: [ContentBlock] = []
                for use in turn.toolUses {
                    continuation.yield(.toolActivity(name: use.name))
                    let outcome: ToolOutcome
                    do {
                        try CampProviderRoutePolicyV1.requireGuideTool(
                            use.name
                        )
                        if use.name == "propose_squad" {
                            outcome = try proposeSquad(
                                input: use.input,
                                useID: use.id,
                                workID: claim.workId,
                                turnOrdinal: turnOrdinal,
                                dispatch: returned,
                                threadID: preparation.thread.id,
                                continuation: continuation
                            )
                        } else {
                            outcome = await executor.execute(
                                name: use.name,
                                input: use.input
                            )
                        }
                    } catch {
                        outcome = .error(String(describing: error))
                    }
                    switch outcome {
                    case .result(let content):
                        results.append(.toolResult(
                            toolUseId: use.id,
                            content: content,
                            isError: false
                        ))
                    case .error(let message):
                        results.append(.toolResult(
                            toolUseId: use.id,
                            content: message,
                            isError: true
                        ))
                    case .completed, .blocked:
                        throw CampProviderDispatchError.invalidRoute
                    }
                }
                _ = try dispatchStore.consumeReturnedTurn(
                    dispatchId: returned.id,
                    expectedVersion: returned.version,
                    claim: claim,
                    at: Date()
                )
                history.append(.user(toolResults: results))
                turnOrdinal = try Self.increment(turnOrdinal)
                continue
            }

            let finalParts = try turn.content.map { block -> String in
                guard case .text(let text) = block else {
                    throw ProviderError.malformedStream(
                        "non-text final guide turn result"
                    )
                }
                return text
            }
            let finalText = finalParts.joined()
            guard !finalText.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty else {
                throw ProviderError.malformedStream(
                    "empty final guide turn result"
                )
            }
            let fullReply = replyParts.joined(separator: "\n\n")
            let outputJSON = try JSONValue.object([
                "text": .string(fullReply),
            ]).encodedString()
            _ = try dispatchStore.consume(
                dispatchId: returned.id,
                expectedVersion: returned.version,
                claim: claim,
                outputJson: outputJSON,
                at: Date(),
                businessMutation: { transaction, _ in
                    _ = try LegacyContentScopeStore.appendMessage(
                        threadId: preparation.thread.id,
                        role: "guide",
                        contentJson: outputJSON,
                        expectedCampLifecycleVersion:
                            returned.campLifecycleVersion,
                        in: transaction
                    )
                }
            )
            continuation.yield(.finished)
            return
        }
    }

    private func proposeSquad(
        input: JSONValue,
        useID: String,
        workID: String,
        turnOrdinal: Int,
        dispatch: CampProviderDispatchSnapshotV1,
        threadID: String,
        continuation: AsyncThrowingStream<GuideChatEvent, Error>.Continuation
    ) throws -> ToolOutcome {
        guard let name = input["name"]?.stringValue,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return .error("提案缺少小队名 name") }
        guard let goal = input["goal"]?.stringValue,
              !goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return .error("提案缺少行动目标 goal") }
        guard let rawIDs = input["memberIds"]?.arrayValue?
                .compactMap(\.stringValue),
              !rawIDs.isEmpty
        else { return .error("提案缺少成员 memberIds（至少 1 位）") }
        var seen = Set<String>()
        let memberIDs = rawIDs.filter { seen.insert($0).inserted }
        guard memberIDs.count <= 6 else {
            return .error("成员最多 6 位，当前 \(memberIDs.count) 位")
        }
        do {
            let members = try database.companions(ids: memberIDs)
            if let guide = members.first(where: { $0.kind != .regular }) {
                return .error(
                    "成员 \(guide.name) 不在名册里（向导不能被指派小目标），请只从名册伙伴中选择"
                )
            }
        } catch let error as RecordNotFoundError {
            return .error(
                "成员 id 不存在：\(error.id)。请用名册里的伙伴 id 重新提案"
            )
        }
        let budget = input["budget"]?.intValue
        if let budget, budget <= 0 {
            return .error("budget 必须是正整数（token 数）")
        }
        let block = SquadProposalBlock(
            proposalId: "guide:\(workID):\(turnOrdinal):\(useID)",
            name: name,
            memberIds: memberIDs,
            goal: goal,
            budget: budget,
            status: .pending
        )
        let messageID = try dispatchStore.recordGuideProposal(
            dispatchId: dispatch.id,
            workId: workID,
            turnOrdinal: turnOrdinal,
            toolUseId: useID,
            threadId: threadID,
            block: block,
            at: Date()
        )
        continuation.yield(.proposalCreated(messageId: messageID))
        return .result(
            "提案已生成，等待用户确认。不要重复提交相同提案；用户确认后系统会自动建队开工。"
        )
    }

    private static func guideSystem(guide: CompanionRecord) -> String {
        """
        你的名字是\(guide.name)。\(guide.rolePrompt)
        你是这个营地的常驻向导，与用户对话。你可以：
        - 用 search_camp_notes 检索营地笔记（往期经验）；
        - 用 camp_status 查看营地全景（行动进展、最近交付物）；
        - 用 propose_squad 提出组队开工提案。提案只是建议，用户确认后系统才会建队开工——不要替用户做决定，也不要重复提交相同提案。
        语气自然、有人情味，回答简洁。
        """
    }

    private static func requestJSON(
        system: String,
        history: [APIMessage],
        tools: [ToolDef],
        maxTokens: Int
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let historyData = try encoder.encode(history)
        guard let historyJSON = String(
            data: historyData,
            encoding: .utf8
        ) else {
            throw EncodingError.invalidValue(
                history,
                .init(
                    codingPath: [],
                    debugDescription: "guide history UTF-8 encoding failed"
                )
            )
        }
        return try JSONValue.object([
            "history": try JSONValue.decoded(from: historyJSON),
            "maxTokens": .number(Double(maxTokens)),
            "system": .string(system),
            "tools": .array(tools.map { tool in
                .object([
                    "description": .string(tool.description),
                    "inputSchema": tool.inputSchema,
                    "name": .string(tool.name),
                ])
            }),
        ]).encodedString()
    }

    private static func responseJSON(
        _ turn: TurnResult
    ) throws -> String {
        try JSONValue.object([
            "content": .array(turn.content.map(\.jsonValue)),
            "stopReason": .string(stopReason(turn.stopReason)),
            "usage": .object([
                "cacheReadTokens": .number(
                    Double(turn.usage.cacheReadTokens)
                ),
                "inputTokens": .number(Double(turn.usage.inputTokens)),
                "outputTokens": .number(Double(turn.usage.outputTokens)),
            ]),
        ]).encodedString()
    }

    private static func stopReason(_ reason: StopReason) -> String {
        switch reason {
        case .endTurn: return "end_turn"
        case .toolUse: return "tool_use"
        case .maxTokens: return "max_tokens"
        case .refusal: return "refusal"
        case .pauseTurn: return "pause_turn"
        case .stopSequence: return "stop_sequence"
        case .contextExceeded: return "model_context_window_exceeded"
        case .other(let value): return value
        }
    }

    private static func increment(_ value: Int) throws -> Int {
        let (next, overflow) = value.addingReportingOverflow(1)
        guard !overflow else { throw P1ContractValidationError.overflow }
        return next
    }
}

package enum CampMemoryPromotionEventV1: Sendable, Equatable {
    case campNoteCreated(missionId: String, noteId: String)
    case missionChanged(String)
    case failed(missionId: String, errorType: String)
}

package actor CampMemoryPromotionSupervisorV1 {
    private struct CloseoutInput: Sendable {
        let missionId: String
        let campId: String
        let model: String
        let goal: String
        let cards: [Distiller.CardDigest]
        let inputJson: String
    }

    private struct CoworkInput: Sendable {
        let missionId: String
        let campId: String
        let model: String
        let companion: CompanionRecord
        let actionName: String
        let messages: [(role: String, text: String)]
        let inputJson: String
    }

    private let database: AppDatabase
    private let makeProvider: @Sendable
        (String, String?) throws -> (any LLMProvider)?
    private let onEvent: @Sendable (CampMemoryPromotionEventV1) async -> Void
    private var running: [String: Task<Void, Never>] = [:]
    private var idleWaiters: [CheckedContinuation<Void, Never>] = []
    private var isShutDown = false

    package init(
        database: AppDatabase,
        makeProvider: @escaping @Sendable
            (String, String?) throws -> (any LLMProvider)?,
        onEvent: @escaping @Sendable
            (CampMemoryPromotionEventV1) async -> Void
    ) {
        self.database = database
        self.makeProvider = makeProvider
        self.onEvent = onEvent
    }

    package func enqueueCloseout(
        missionId: String,
        model: String
    ) throws {
        guard !isShutDown else {
            throw SupervisorAlreadyShutDownError()
        }
        guard running[missionId] == nil else { return }
        let input = try loadCloseoutInput(
            missionId: missionId,
            model: model
        )
        let work = try CampProviderDispatchStore(database: database)
            .enqueueMemoryPromotion(
                campId: input.campId,
                aggregateId: missionId,
                inputJson: input.inputJson,
                idempotencyKey: "closeout-memory:v1:\(missionId)",
                traceId: "closeout-memory:\(missionId)",
                at: Date()
            )
        guard work.state != .succeeded else { return }
        let task = Task {
            await executeCloseout(input)
            finish(missionId)
        }
        running[missionId] = task
    }

    package func waitUntilIdle() async {
        guard !running.isEmpty else { return }
        await withCheckedContinuation { continuation in
            if running.isEmpty {
                continuation.resume()
            } else {
                idleWaiters.append(continuation)
            }
        }
    }

    package func shutdown() async {
        isShutDown = true
        let tasks = Array(running.values)
        for task in tasks { task.cancel() }
        for task in tasks { await task.value }
        running.removeAll()
        wakeIdleWaiters()
    }

    private func executeCloseout(_ input: CloseoutInput) async {
        do {
            guard let provider = try makeProvider(input.model, nil) else {
                throw ProviderUnavailableError(
                    model: input.model,
                    companionId: nil
                )
            }
            let runtime = CampProviderRuntimeV1(
                database: database,
                registeredProvider: provider
            )
            let returned: CampProviderReturnedInferenceV1
            do {
                returned = try await runtime.beginMemoryPromotion(
                    campId: input.campId,
                    aggregateId: input.missionId,
                    inputJson: input.inputJson,
                    system: Distiller.closeoutSystem,
                    user: Distiller.closeoutPrompt(
                        goal: input.goal,
                        cards: input.cards
                    ),
                    idempotencyKey:
                        "closeout-memory:v1:\(input.missionId)",
                    traceId: "closeout-memory:\(input.missionId)"
                )
            } catch let failure as CampProviderCallFailureV1 {
                let fallback = Distiller.closeoutFallback(
                    goal: input.goal,
                    cards: input.cards
                )
                let now = Date()
                let note = CampNoteRecord(
                    id: failure.claim.workId,
                    campId: input.campId,
                    missionId: input.missionId,
                    title: fallback.title,
                    bodyMd: fallback.bodyMd,
                    pinned: false,
                    createdAt: now,
                    updatedAt: now
                )
                _ = try runtime.consumeCampFallback(
                    failure,
                    note: note,
                    missionId: input.missionId
                )
                await onEvent(.campNoteCreated(
                    missionId: input.missionId,
                    noteId: note.id
                ))
                await onEvent(.missionChanged(input.missionId))
                try await executeCoworkPromotions(input)
                return
            }
            let parsed: Distiller.Note
            let source: String
            do {
                switch try Distiller.parseNoteJSON(returned.text) {
                case .note(let title, let body):
                    parsed = Distiller.Note(title: title, bodyMd: body)
                    source = "closeout"
                case .skip:
                    parsed = Distiller.closeoutFallback(
                        goal: input.goal,
                        cards: input.cards
                    )
                    source = "fallback"
                }
            } catch {
                parsed = Distiller.closeoutFallback(
                    goal: input.goal,
                    cards: input.cards
                )
                source = "fallback"
            }
            let now = Date()
            let note = CampNoteRecord(
                id: returned.claim.workId,
                campId: input.campId,
                missionId: input.missionId,
                title: parsed.title,
                bodyMd: parsed.bodyMd,
                pinned: false,
                createdAt: now,
                updatedAt: now
            )
            _ = try runtime.consumeCampNote(
                returned,
                note: note,
                missionId: input.missionId,
                source: source
            )
            await onEvent(.campNoteCreated(
                missionId: input.missionId,
                noteId: note.id
            ))
            await onEvent(.missionChanged(input.missionId))
            try await executeCoworkPromotions(input)
        } catch {
            await onEvent(.failed(
                missionId: input.missionId,
                errorType: String(reflecting: type(of: error))
            ))
        }
    }

    private func executeCoworkPromotions(
        _ closeout: CloseoutInput
    ) async throws {
        let inputs = try loadCoworkInputs(closeout)
        for input in inputs {
            try Task.checkCancellation()
            guard let provider = try makeProvider(
                input.model,
                input.companion.id
            ) ?? makeProvider(input.model, nil) else {
                throw ProviderUnavailableError(
                    model: input.model,
                    companionId: input.companion.id
                )
            }
            let runtime = CampProviderRuntimeV1(
                database: database,
                registeredProvider: provider
            )
            let key = "cowork-memory:v1:\(input.missionId):\(input.companion.id)"
            let returned = try await runtime.beginMemoryPromotion(
                campId: input.campId,
                aggregateId: "\(input.missionId):\(input.companion.id)",
                inputJson: input.inputJson,
                system: Distiller.memorySystem,
                user: Distiller.memoryPrompt(
                    companionName: input.companion.name,
                    rolePrompt: input.companion.rolePrompt,
                    messages: input.messages
                ),
                idempotencyKey: key,
                traceId: key
            )
            let parsed: Distiller.Note?
            switch try Distiller.parseNoteJSON(returned.text) {
            case .note(let title, let body):
                parsed = Distiller.Note(title: title, bodyMd: body)
            case .skip:
                parsed = nil
            }
            let note = parsed.map { parsed in
                let now = Date()
                return CompanionNoteRecord(
                    id: returned.claim.workId,
                    companionId: input.companion.id,
                    sourceThreadId: nil,
                    title: "共事·\(input.actionName):\(parsed.title)",
                    bodyMd: parsed.bodyMd,
                    pinned: false,
                    createdAt: now,
                    updatedAt: now
                )
            }
            _ = try runtime.consumeCoworkMemory(
                returned,
                note: note,
                missionId: input.missionId
            )
            await onEvent(.missionChanged(input.missionId))
        }
    }

    private func loadCloseoutInput(
        missionId: String,
        model: String
    ) throws -> CloseoutInput {
        try database.pool.read { transaction in
            guard let mission = try MissionRecord.fetchOne(
                transaction,
                key: missionId
            ), let squad = try SquadRecord.fetchOne(
                transaction,
                key: mission.squadId
            ) else {
                throw RecordNotFoundError(
                    table: "mission/squad",
                    id: missionId
                )
            }
            let cards = try CardRecord
                .filter(
                    Column("missionId") == missionId
                        && Column("status") == CardStatus.done.rawValue
                )
                .order(Column("stage"))
                .fetchAll(transaction)
                .map { card -> Distiller.CardDigest in
                    let handoff = card.handoffJson.flatMap {
                        try? JSONDecoder().decode(
                            HandoffPayload.self,
                            from: Data($0.utf8)
                        )
                    }
                    return Distiller.CardDigest(
                        title: card.title,
                        outcome: handoff?.outcome ?? "（无交接包）",
                        summary: handoff?.summary ?? "",
                        risks: handoff?.risks ?? []
                    )
                }
            let goal = mission.goalRefined.isEmpty
                ? mission.goalRaw
                : mission.goalRefined
            let inputJSON = try JSONValue.object([
                "campId": .string(squad.campId),
                "cards": .array(cards.map { card in
                    .object([
                        "outcome": .string(card.outcome),
                        "risks": .array(card.risks.map(JSONValue.string)),
                        "summary": .string(card.summary),
                        "title": .string(card.title),
                    ])
                }),
                "goal": .string(goal),
                "missionId": .string(missionId),
                "model": .string(model),
                "source": .string("closeout"),
            ]).encodedString()
            return CloseoutInput(
                missionId: missionId,
                campId: squad.campId,
                model: model,
                goal: goal,
                cards: cards,
                inputJson: inputJSON
            )
        }
    }

    private func loadCoworkInputs(
        _ closeout: CloseoutInput
    ) throws -> [CoworkInput] {
        try database.pool.read { transaction in
            let mission = try MissionRecord.fetchOne(
                transaction,
                key: closeout.missionId
            )
            guard let mission else {
                throw RecordNotFoundError(
                    table: MissionRecord.databaseTableName,
                    id: closeout.missionId
                )
            }
            let cards = try CardRecord
                .filter(
                    Column("missionId") == closeout.missionId
                        && Column("status") == CardStatus.done.rawValue
                )
                .order(Column("stage"))
                .fetchAll(transaction)
            var grouped: [String: [CardRecord]] = [:]
            for card in cards {
                if let assigneeID = card.assigneeId {
                    grouped[assigneeID, default: []].append(card)
                }
            }
            let actionName = String(
                closeout.goal.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).prefix(20)
            )
            return try grouped.keys.sorted().compactMap { companionID in
                guard let companion = try CompanionRecord.fetchOne(
                    transaction,
                    key: companionID
                ), let assigned = grouped[companionID], !assigned.isEmpty
                else { return nil }
                let messages = assigned.map { card -> (
                    role: String,
                    text: String
                ) in
                    let handoff = card.handoffJson.flatMap {
                        try? JSONDecoder().decode(
                            HandoffPayload.self,
                            from: Data($0.utf8)
                        )
                    }
                    var lines = [
                        "行动目标：\(closeout.goal)",
                        "小目标：\(card.title)",
                        "结果：\(handoff?.outcome ?? "（无交接包）")",
                    ]
                    if let summary = handoff?.summary, !summary.isEmpty {
                        lines.append("摘要：\(summary)")
                    }
                    if let risks = handoff?.risks, !risks.isEmpty {
                        lines.append("风险：" + risks.joined(separator: "；"))
                    }
                    return (
                        role: "companion",
                        text: lines.joined(separator: "\n")
                    )
                }
                let inputJSON = try JSONValue.object([
                    "campId": .string(closeout.campId),
                    "companionId": .string(companion.id),
                    "messages": .array(messages.map { message in
                        .object([
                            "role": .string(message.role),
                            "text": .string(message.text),
                        ])
                    }),
                    "missionId": .string(mission.id),
                    "model": .string(closeout.model),
                    "source": .string("cowork"),
                ]).encodedString()
                return CoworkInput(
                    missionId: mission.id,
                    campId: closeout.campId,
                    model: closeout.model,
                    companion: companion,
                    actionName: actionName,
                    messages: messages,
                    inputJson: inputJSON
                )
            }
        }
    }

    private func finish(_ key: String) {
        running.removeValue(forKey: key)
        wakeIdleWaiters()
    }

    private func wakeIdleWaiters() {
        guard running.isEmpty else { return }
        let waiters = idleWaiters
        idleWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
    }
}

package enum CampProviderOperationKindV1:
    String, Codable, Sendable, Equatable
{
    case guideChat
    case memoryPromotion
}

package enum CampProviderReplayClassV1:
    String, Codable, Sendable, Equatable
{
    case replaySafeInference
    case idempotencyKeyed
    case nonReplayable
}

package enum CampProviderDispatchStateV1:
    String, Codable, Sendable, Equatable
{
    case prepared
    case started
    case returned
    case consumed
    case abandoned
}

package struct CampProviderDispatchSnapshotV1: Sendable, Equatable {
    package let id: String
    package let workId: String
    package let workAttempt: Int
    package let turnOrdinal: Int
    package let dispatchAttempt: Int
    package let replayOfDispatchId: String?
    package let idempotencyKey: String
    package let campId: String
    package let campLifecycleVersion: Int
    package let operationKind: CampProviderOperationKindV1
    package let replayClass: CampProviderReplayClassV1
    package let state: CampProviderDispatchStateV1
    package let requestJson: String
    package let requestHash: String
    package let responseJson: String?
    package let responseHash: String?
    package let version: Int
    package let preparedAt: Date
    package let startedAt: Date?
    package let returnedAt: Date?
    package let consumedAt: Date?
    package let abandonedAt: Date?
    package let redactedAt: Date?
}

package struct GuideProviderWorkPreparationV1: Sendable {
    package let thread: ChatThreadRecord
    package let messageId: String
    package let work: DurableWorkRecord
}

package struct CampProviderCompletionV1: Sendable, Equatable {
    package let dispatch: CampProviderDispatchSnapshotV1
    package let work: DurableWorkRecord
}

package enum CampProviderNextActionV1: Sendable, Equatable {
    case callProvider(requestJson: String)
    case requiresAbandonBeforeReplay
    case consumeReturned(responseJson: String)
    case terminal
}

package struct CampProviderRecoveryIntentV1: Sendable, Equatable {
    package let workId: String
    package let dispatchId: String
    package let errorCode: String
    package let requiresUrgentAttention: Bool
}

package enum CampProviderDispatchError: Error, Sendable, Equatable {
    case missingDispatch(String)
    case missingWork(String)
    case invalidWorkKind
    case invalidClaim
    case invalidState
    case replayConflict
    case noncanonicalJSON
    case invalidRoute
    case missingReturnedCheckpoint
    case guideProposalScopeMismatch
}

package enum CampProviderRouteV1: Sendable, Equatable {
    case guideChat(campId: String)
    case guideDistillation(campId: String)
    case closeoutDistillation(campId: String)
    case coworkDistillation(campId: String)
    case dmDistillation(cowId: String)
    case globalDistillation(ownerId: String)
    case connectionTest
    case externalWrite(name: String, campId: String)
}

package enum CampProviderRouteResolutionV1: Sendable, Equatable {
    case camp(
        campId: String,
        operationKind: CampProviderOperationKindV1,
        replayClass: CampProviderReplayClassV1
    )
    case global
}

package enum CampProviderRouteError: Error, Sendable, Equatable {
    case unregisteredExternalWrite
    case invalidIdentity
}

package enum GuideToolAuthorizationError: Error, Sendable, Equatable {
    case unregisteredTool
}

package enum CampProviderRoutePolicyV1 {
    package static let guideToolNames = [
        "camp_status", "propose_squad", "search_camp_notes",
    ]

    package static func resolve(
        _ route: CampProviderRouteV1
    ) throws -> CampProviderRouteResolutionV1 {
        switch route {
        case .guideChat(let campID):
            try requireIdentity(campID)
            return .camp(
                campId: campID,
                operationKind: .guideChat,
                replayClass: .replaySafeInference
            )
        case .guideDistillation(let campID),
             .closeoutDistillation(let campID),
             .coworkDistillation(let campID):
            try requireIdentity(campID)
            return .camp(
                campId: campID,
                operationKind: .memoryPromotion,
                replayClass: .replaySafeInference
            )
        case .dmDistillation(let cowID):
            try requireIdentity(cowID)
            return .global
        case .globalDistillation(let ownerID):
            try requireIdentity(ownerID)
            return .global
        case .connectionTest:
            return .global
        case .externalWrite:
            throw CampProviderRouteError.unregisteredExternalWrite
        }
    }

    package static func requireGuideTool(_ name: String) throws {
        guard guideToolNames.contains(name) else {
            throw GuideToolAuthorizationError.unregisteredTool
        }
    }

    private static func requireIdentity(_ value: String) throws {
        do {
            try CanonicalContractCodingV1.validateNonempty(value)
        } catch {
            throw CampProviderRouteError.invalidIdentity
        }
    }
}

package struct CampProviderDispatchStore: Sendable {
    private let database: AppDatabase

    package init(database: AppDatabase) {
        self.database = database
    }

    package func enqueueGuideTurn(
        campId: String,
        userText: String,
        idempotencyKey: String,
        traceId: String,
        at: Date
    ) throws -> GuideProviderWorkPreparationV1 {
        try Self.validateTime(at)
        try CanonicalContractCodingV1.validateCampID(campId)
        try CanonicalContractCodingV1.validateNonempty(idempotencyKey)
        try CanonicalContractCodingV1.validateNonempty(traceId)
        try CanonicalContractCodingV1.validateNonempty(userText)
        let contentJSON = try JSONValue.object([
            "text": .string(userText),
        ]).encodedString()
        return try database.pool.write { transaction in
            if let existing = try DurableWorkRecord.fetchOne(
                transaction,
                sql: """
                    SELECT * FROM durable_work
                    WHERE kind='guideChat' AND idempotencyKey=?
                    """,
                arguments: [idempotencyKey]
            ) {
                guard existing.campId == campId,
                      let input = try JSONValue.decoded(
                          from: existing.inputJson
                      ).objectValue,
                      let threadID = input["threadId"]?.stringValue,
                      let messageID = input["messageId"]?.stringValue,
                      let thread = try ChatThreadRecord.fetchOne(
                          transaction,
                          key: threadID
                      ),
                      let message = try ChatMessageRecord.fetchOne(
                          transaction,
                          key: messageID
                      ),
                      message.threadId == threadID,
                      message.contentJson == contentJSON
                else {
                    throw CampProviderDispatchError.replayConflict
                }
                return GuideProviderWorkPreparationV1(
                    thread: thread,
                    messageId: messageID,
                    work: existing
                )
            }
            let lifecycleVersion = try Self.activeLifecycleVersion(
                campId: campId,
                in: transaction
            )
            let thread = try LegacyContentScopeStore.findOrCreateGuideThread(
                campId: campId,
                expectedLifecycleVersion: lifecycleVersion,
                in: transaction
            )
            let messageID = try LegacyContentScopeStore.appendMessage(
                threadId: thread.id,
                role: "user",
                contentJson: contentJSON,
                expectedCampLifecycleVersion: lifecycleVersion,
                in: transaction
            )
            let inputJSON = try JSONValue.object([
                "campId": .string(campId),
                "messageId": .string(messageID),
                "threadId": .string(thread.id),
            ]).encodedString()
            let inputHash = CanonicalJSONV1.sha256Hex(
                Data(inputJSON.utf8)
            )
            let result = try DurableWorkStore.enqueue(
                campId: campId,
                kind: .guideChat,
                aggregateType: "chatThread",
                aggregateId: thread.id,
                inputJson: inputJSON,
                claimedInputHash: inputHash,
                idempotencyKey: idempotencyKey,
                maxAttempts: 4,
                traceId: traceId,
                now: at,
                in: transaction
            )
            return GuideProviderWorkPreparationV1(
                thread: thread,
                messageId: messageID,
                work: result.work
            )
        }
    }

    package func enqueueMemoryPromotion(
        campId: String,
        aggregateId: String,
        inputJson: String,
        idempotencyKey: String,
        traceId: String,
        at: Date
    ) throws -> DurableWorkRecord {
        try Self.validateCanonicalObject(inputJson)
        return try database.pool.write { transaction in
            let result = try DurableWorkStore.enqueue(
                campId: campId,
                kind: .memoryPromotion,
                aggregateType: "memoryPromotion",
                aggregateId: aggregateId,
                inputJson: inputJson,
                claimedInputHash: CanonicalJSONV1.sha256Hex(
                    Data(inputJson.utf8)
                ),
                idempotencyKey: idempotencyKey,
                maxAttempts: 4,
                traceId: traceId,
                now: at,
                in: transaction
            )
            return result.work
        }
    }

    package func prepare(
        claim: DurableWorkClaim,
        operationKind: CampProviderOperationKindV1,
        turnOrdinal: Int,
        requestJson: String,
        idempotencyKey: String,
        at: Date
    ) throws -> CampProviderDispatchSnapshotV1 {
        try Self.validateTime(at)
        try Self.validateCanonicalObject(requestJson)
        try CanonicalContractCodingV1.validateNonnegative(turnOrdinal)
        try CanonicalContractCodingV1.validateNonempty(idempotencyKey)
        let requestHash = CanonicalJSONV1.sha256Hex(Data(requestJson.utf8))
        return try database.pool.write { transaction in
            let graph = try Self.requireClaim(
                claim,
                operationKind: operationKind,
                in: transaction
            )
            if let existing = try Self.dispatch(
                idempotencyKey: idempotencyKey,
                in: transaction
            ) {
                guard existing.workId == claim.workId,
                      existing.workAttempt == claim.attempt,
                      existing.turnOrdinal == turnOrdinal,
                      existing.dispatchAttempt == 1,
                      existing.replayOfDispatchId == nil,
                      existing.campId == graph.campID,
                      existing.campLifecycleVersion
                        == graph.lifecycleVersion,
                      existing.operationKind == operationKind,
                      existing.replayClass == .replaySafeInference,
                      existing.requestJson == requestJson,
                      existing.requestHash == requestHash
                else {
                    throw CampProviderDispatchError.replayConflict
                }
                return existing
            }
            let snapshot = CampProviderDispatchSnapshotV1(
                id: UUID().uuidString,
                workId: claim.workId,
                workAttempt: claim.attempt,
                turnOrdinal: turnOrdinal,
                dispatchAttempt: 1,
                replayOfDispatchId: nil,
                idempotencyKey: idempotencyKey,
                campId: graph.campID,
                campLifecycleVersion: graph.lifecycleVersion,
                operationKind: operationKind,
                replayClass: .replaySafeInference,
                state: .prepared,
                requestJson: requestJson,
                requestHash: requestHash,
                responseJson: nil,
                responseHash: nil,
                version: 1,
                preparedAt: at,
                startedAt: nil,
                returnedAt: nil,
                consumedAt: nil,
                abandonedAt: nil,
                redactedAt: nil
            )
            try Self.insert(snapshot, in: transaction)
            return snapshot
        }
    }

    package func start(
        dispatchId: String,
        expectedVersion: Int,
        claim: DurableWorkClaim,
        at: Date
    ) throws -> CampProviderDispatchSnapshotV1 {
        try Self.validateTime(at)
        return try database.pool.write { transaction in
            let current = try Self.requireDispatch(dispatchId, in: transaction)
            guard current.state == .prepared,
                  current.version == expectedVersion,
                  current.workId == claim.workId,
                  current.workAttempt == claim.attempt
            else {
                throw CampProviderDispatchError.invalidState
            }
            _ = try Self.requireClaim(
                claim,
                operationKind: current.operationKind,
                expectedLifecycleVersion: current.campLifecycleVersion,
                in: transaction
            )
            try transaction.execute(
                sql: """
                    UPDATE camp_provider_dispatch
                    SET state='started',startedAt=?,version=version+1
                    WHERE id=? AND state='prepared' AND version=?
                    """,
                arguments: [at, dispatchId, expectedVersion]
            )
            guard transaction.changesCount == 1 else {
                throw CampProviderDispatchError.invalidState
            }
            try Self.insertProviderAttemptEvent(
                kind: "providerDispatchStarted",
                dispatchId: dispatchId,
                claim: claim,
                at: at,
                in: transaction
            )
            return try Self.requireDispatch(dispatchId, in: transaction)
        }
    }

    package func recordReturned(
        dispatchId: String,
        expectedVersion: Int,
        claim: DurableWorkClaim,
        responseJson: String,
        at: Date
    ) throws -> CampProviderDispatchSnapshotV1 {
        try Self.validateTime(at)
        try Self.validateCanonicalObject(responseJson)
        let responseHash = CanonicalJSONV1.sha256Hex(Data(responseJson.utf8))
        return try database.pool.write { transaction in
            let current = try Self.requireDispatch(dispatchId, in: transaction)
            guard current.state == .started,
                  current.version == expectedVersion,
                  current.workId == claim.workId,
                  current.workAttempt == claim.attempt
            else {
                throw CampProviderDispatchError.invalidState
            }
            _ = try Self.requireClaim(
                claim,
                operationKind: current.operationKind,
                expectedLifecycleVersion: current.campLifecycleVersion,
                in: transaction
            )
            try transaction.execute(
                sql: """
                    UPDATE camp_provider_dispatch
                    SET state='returned',responseJson=?,responseHash=?,
                        returnedAt=?,version=version+1
                    WHERE id=? AND state='started' AND version=?
                    """,
                arguments: [
                    responseJson, responseHash, at, dispatchId,
                    expectedVersion,
                ]
            )
            guard transaction.changesCount == 1 else {
                throw CampProviderDispatchError.invalidState
            }
            try Self.insertProviderAttemptEvent(
                kind: "providerResponseReturned",
                dispatchId: dispatchId,
                claim: claim,
                at: at,
                in: transaction
            )
            return try Self.requireDispatch(dispatchId, in: transaction)
        }
    }

    package func consume(
        dispatchId: String,
        expectedVersion: Int,
        claim: DurableWorkClaim,
        outputJson: String,
        at: Date,
        businessMutation: DurableWorkBusinessMutation = { _, _ in }
    ) throws -> CampProviderCompletionV1 {
        try Self.validateTime(at)
        try Self.validateCanonicalObject(outputJson)
        return try database.pool.write { transaction in
            let current = try Self.requireDispatch(dispatchId, in: transaction)
            guard current.state == .returned,
                  current.version == expectedVersion,
                  current.workId == claim.workId,
                  current.workAttempt == claim.attempt,
                  current.responseJson != nil
            else {
                throw CampProviderDispatchError.missingReturnedCheckpoint
            }
            _ = try Self.requireClaim(
                claim,
                operationKind: current.operationKind,
                expectedLifecycleVersion: current.campLifecycleVersion,
                in: transaction
            )
            try transaction.execute(
                sql: """
                    UPDATE camp_provider_dispatch
                    SET state='consumed',consumedAt=?,version=version+1
                    WHERE id=? AND state='returned' AND version=?
                    """,
                arguments: [at, dispatchId, expectedVersion]
            )
            guard transaction.changesCount == 1 else {
                throw CampProviderDispatchError.invalidState
            }
            let work = try DurableWorkStore.complete(
                claim: claim,
                outputJson: outputJson,
                now: at,
                businessMutation: businessMutation,
                in: transaction
            )
            return CampProviderCompletionV1(
                dispatch: try Self.requireDispatch(dispatchId, in: transaction),
                work: work
            )
        }
    }

    /// Marks a returned provider turn as durably incorporated into the next
    /// request without terminally completing the enclosing multi-turn work.
    package func consumeReturnedTurn(
        dispatchId: String,
        expectedVersion: Int,
        claim: DurableWorkClaim,
        at: Date
    ) throws -> CampProviderDispatchSnapshotV1 {
        try Self.validateTime(at)
        return try database.pool.write { transaction in
            let current = try Self.requireDispatch(
                dispatchId,
                in: transaction
            )
            guard current.state == .returned,
                  current.version == expectedVersion,
                  current.workId == claim.workId,
                  current.workAttempt == claim.attempt,
                  current.responseJson != nil
            else {
                throw CampProviderDispatchError.missingReturnedCheckpoint
            }
            _ = try Self.requireClaim(
                claim,
                operationKind: current.operationKind,
                expectedLifecycleVersion: current.campLifecycleVersion,
                in: transaction
            )
            try transaction.execute(
                sql: """
                    UPDATE camp_provider_dispatch
                    SET state='consumed',consumedAt=?,version=version+1
                    WHERE id=? AND state='returned' AND version=?
                    """,
                arguments: [at, dispatchId, expectedVersion]
            )
            guard transaction.changesCount == 1 else {
                throw CampProviderDispatchError.invalidState
            }
            return try Self.requireDispatch(dispatchId, in: transaction)
        }
    }

    package func completeStartedWithFallback(
        dispatchId: String,
        expectedVersion: Int,
        claim: DurableWorkClaim,
        outputJson: String,
        at: Date,
        businessMutation: DurableWorkBusinessMutation
    ) throws -> CampProviderCompletionV1 {
        try Self.validateTime(at)
        try Self.validateCanonicalObject(outputJson)
        return try database.pool.write { transaction in
            let current = try Self.requireDispatch(
                dispatchId,
                in: transaction
            )
            guard current.state == .started,
                  current.version == expectedVersion,
                  current.replayClass == .replaySafeInference,
                  current.workId == claim.workId,
                  current.workAttempt == claim.attempt
            else {
                throw CampProviderDispatchError.invalidState
            }
            _ = try Self.requireClaim(
                claim,
                operationKind: current.operationKind,
                expectedLifecycleVersion: current.campLifecycleVersion,
                in: transaction
            )
            try transaction.execute(
                sql: """
                    UPDATE camp_provider_dispatch
                    SET state='abandoned',abandonedAt=?,version=version+1
                    WHERE id=? AND state='started' AND version=?
                    """,
                arguments: [at, dispatchId, expectedVersion]
            )
            guard transaction.changesCount == 1 else {
                throw CampProviderDispatchError.invalidState
            }
            let work = try DurableWorkStore.complete(
                claim: claim,
                outputJson: outputJson,
                now: at,
                businessMutation: businessMutation,
                in: transaction
            )
            return CampProviderCompletionV1(
                dispatch: try Self.requireDispatch(
                    dispatchId,
                    in: transaction
                ),
                work: work
            )
        }
    }

    package func abandonStartedAndPrepareReplay(
        dispatchId: String,
        expectedVersion: Int,
        claim: DurableWorkClaim,
        at: Date
    ) throws -> CampProviderDispatchSnapshotV1 {
        try Self.validateTime(at)
        return try database.pool.write { transaction in
            let current = try Self.requireDispatch(dispatchId, in: transaction)
            guard current.state == .started,
                  current.version == expectedVersion,
                  current.replayClass == .replaySafeInference,
                  current.workId == claim.workId,
                  current.workAttempt == claim.attempt
            else {
                throw CampProviderDispatchError.invalidState
            }
            _ = try Self.requireClaim(
                claim,
                operationKind: current.operationKind,
                expectedLifecycleVersion: current.campLifecycleVersion,
                in: transaction
            )
            try transaction.execute(
                sql: """
                    UPDATE camp_provider_dispatch
                    SET state='abandoned',abandonedAt=?,version=version+1
                    WHERE id=? AND state='started' AND version=?
                    """,
                arguments: [at, dispatchId, expectedVersion]
            )
            guard transaction.changesCount == 1 else {
                throw CampProviderDispatchError.invalidState
            }
            let nextAttempt = try Self.checkedIncrement(
                current.dispatchAttempt
            )
            let replay = CampProviderDispatchSnapshotV1(
                id: UUID().uuidString,
                workId: current.workId,
                workAttempt: current.workAttempt,
                turnOrdinal: current.turnOrdinal,
                dispatchAttempt: nextAttempt,
                replayOfDispatchId: current.id,
                idempotencyKey: "\(current.idempotencyKey):replay:\(nextAttempt)",
                campId: current.campId,
                campLifecycleVersion: current.campLifecycleVersion,
                operationKind: current.operationKind,
                replayClass: current.replayClass,
                state: .prepared,
                requestJson: current.requestJson,
                requestHash: current.requestHash,
                responseJson: nil,
                responseHash: nil,
                version: 1,
                preparedAt: at,
                startedAt: nil,
                returnedAt: nil,
                consumedAt: nil,
                abandonedAt: nil,
                redactedAt: nil
            )
            try Self.insert(replay, in: transaction)
            return replay
        }
    }

    package func nextAction(
        dispatchId: String
    ) throws -> CampProviderNextActionV1 {
        let current = try requireDispatchOutsideTransaction(dispatchId)
        switch current.state {
        case .prepared:
            return .callProvider(requestJson: current.requestJson)
        case .started:
            return .requiresAbandonBeforeReplay
        case .returned:
            guard let response = current.responseJson else {
                throw CampProviderDispatchError.missingReturnedCheckpoint
            }
            return .consumeReturned(responseJson: response)
        case .consumed, .abandoned:
            return .terminal
        }
    }

    package func dispatch(
        id: String
    ) throws -> CampProviderDispatchSnapshotV1? {
        try database.pool.read { transaction in
            try Self.dispatch(id: id, in: transaction)
        }
    }

    package func dispatchCount() throws -> Int {
        try database.pool.read { transaction in
            try Int.fetchOne(
                transaction,
                sql: "SELECT COUNT(*) FROM camp_provider_dispatch"
            ) ?? 0
        }
    }

    package func recordGuideProposal(
        dispatchId: String,
        workId: String,
        turnOrdinal: Int,
        toolUseId: String,
        threadId: String,
        block: SquadProposalBlock,
        at: Date
    ) throws -> String {
        try CampProviderRoutePolicyV1.requireGuideTool("propose_squad")
        try Self.validateTime(at)
        try CanonicalContractCodingV1.validateNonempty(toolUseId)
        let blockJSON = try block.encodedString()
        let payloadJSON = try JSONValue.object([
            "block": try JSONValue.decoded(from: blockJSON),
            "dispatchId": .string(dispatchId),
            "threadId": .string(threadId),
            "toolUseId": .string(toolUseId),
            "turnOrdinal": .number(Double(turnOrdinal)),
            "workId": .string(workId),
        ]).encodedString()
        let payloadHash = CanonicalJSONV1.sha256Hex(Data(payloadJSON.utf8))
        let receiptKey = "guide-tool:v1:\(workId):\(turnOrdinal):\(toolUseId)"
        return try database.pool.write { transaction in
            if let receipt = try Row.fetchOne(
                transaction,
                sql: """
                    SELECT commandType,commandPayloadHash,resultJson
                    FROM domain_command_receipt WHERE idempotencyKey=?
                    """,
                arguments: [receiptKey]
            ) {
                guard (receipt["commandType"] as String)
                        == "p1e.guide-proposal.v1",
                      (receipt["commandPayloadHash"] as String) == payloadHash,
                      let messageID = try JSONValue.decoded(
                          from: receipt["resultJson"] as String
                      ).objectValue?["messageId"]?.stringValue,
                      try ChatMessageRecord.fetchOne(
                          transaction,
                          key: messageID
                      ) != nil
                else {
                    throw CampProviderDispatchError.replayConflict
                }
                return messageID
            }
            let current = try Self.requireDispatch(dispatchId, in: transaction)
            guard current.state == .returned,
                  current.operationKind == .guideChat,
                  current.workId == workId,
                  current.turnOrdinal == turnOrdinal
            else {
                throw CampProviderDispatchError.invalidState
            }
            guard let scope = try LegacyContentScopeStore.threadScope(
                id: threadId,
                in: transaction
            ), scope.scopeKind == .camp,
               scope.campId == current.campId
            else {
                throw CampProviderDispatchError.guideProposalScopeMismatch
            }
            let messageID = try LegacyContentScopeStore.appendMessage(
                threadId: threadId,
                role: "guide",
                contentJson: blockJSON,
                expectedCampLifecycleVersion: current.campLifecycleVersion,
                in: transaction
            )
            let resultJSON = try JSONValue.object([
                "messageId": .string(messageID),
            ]).encodedString()
            try transaction.execute(
                sql: """
                    INSERT INTO domain_command_receipt(
                      idempotencyKey,commandType,commandPayloadHash,eventCount,
                      resultJson,resultHash,createdAt
                    ) VALUES (?,'p1e.guide-proposal.v1',?,0,?,?,?)
                    """,
                arguments: [
                    receiptKey, payloadHash, resultJSON,
                    CanonicalJSONV1.sha256Hex(Data(resultJSON.utf8)), at,
                ]
            )
            return messageID
        }
    }

    package func reconcileHistoricUnsafeStarted(
        dispatchId: String,
        at: Date
    ) throws -> CampProviderRecoveryIntentV1 {
        try Self.validateTime(at)
        return try database.pool.write { transaction in
            let current = try Self.requireDispatch(dispatchId, in: transaction)
            guard current.state == .started else {
                throw CampProviderDispatchError.invalidState
            }
            guard let work = try DurableWorkRecord.fetchOne(
                transaction,
                key: current.workId
            ), work.state == .running,
               work.attempt == current.workAttempt,
               let workerID = work.leaseOwner
            else {
                throw CampProviderDispatchError.invalidClaim
            }
            let nextVersion = try Self.checkedIncrement(work.version)
            try transaction.execute(
                sql: """
                    UPDATE camp_provider_dispatch
                    SET state='abandoned',abandonedAt=?,version=version+1
                    WHERE id=? AND state='started' AND version=?
                    """,
                arguments: [at, current.id, current.version]
            )
            guard transaction.changesCount == 1 else {
                throw CampProviderDispatchError.invalidState
            }
            try transaction.execute(
                sql: """
                    UPDATE durable_work
                    SET state='failed',notBefore=NULL,leaseOwner=NULL,
                        leaseExpiresAt=NULL,outputJson=NULL,
                        errorCode='provider_effect_unknown',
                        errorMessage='provider dispatch started without a durable returned checkpoint',
                        version=?,updatedAt=?,finishedAt=?
                    WHERE id=? AND state='running' AND attempt=? AND version=?
                    """,
                arguments: [
                    nextVersion, at, at, work.id, work.attempt, work.version,
                ]
            )
            guard transaction.changesCount == 1 else {
                throw CampProviderDispatchError.invalidClaim
            }
            try transaction.execute(
                sql: """
                    UPDATE durable_work_attempt
                    SET endedAt=?,outcome='failed',
                        errorCode='provider_effect_unknown',
                        errorMessage='provider dispatch started without a durable returned checkpoint',
                        terminalWorkVersion=?
                    WHERE workId=? AND attempt=? AND endedAt IS NULL
                    """,
                arguments: [
                    at, nextVersion, work.id, work.attempt,
                ]
            )
            guard transaction.changesCount == 1 else {
                throw CampProviderDispatchError.invalidClaim
            }
            try Self.insertAttemptEvent(
                workId: work.id,
                attempt: work.attempt,
                kind: "failed",
                dispatchId: nil,
                workerId: workerID,
                workVersion: nextVersion,
                resultingState: "failed",
                errorCode: "provider_effect_unknown",
                errorMessage: "provider dispatch started without a durable returned checkpoint",
                at: at,
                in: transaction
            )
            return CampProviderRecoveryIntentV1(
                workId: work.id,
                dispatchId: current.id,
                errorCode: "provider_effect_unknown",
                requiresUrgentAttention: true
            )
        }
    }

    private func requireDispatchOutsideTransaction(
        _ id: String
    ) throws -> CampProviderDispatchSnapshotV1 {
        try database.pool.read { transaction in
            try Self.requireDispatch(id, in: transaction)
        }
    }

    private static func activeLifecycleVersion(
        campId: String,
        expectedVersion: Int? = nil,
        in database: Database
    ) throws -> Int {
        guard let row = try Row.fetchOne(
            database,
            sql: """
                SELECT lifecycle.state,lifecycle.version,camp.archived
                FROM camp_lifecycle AS lifecycle
                JOIN camp ON camp.id=lifecycle.campId
                WHERE lifecycle.campId=?
                """,
            arguments: [campId]
        ) else {
            throw CampLifecycleWriteAuthorizationError.missing
        }
        let version: Int = row["version"]
        if let expectedVersion, version != expectedVersion {
            throw CampLifecycleWriteAuthorizationError
                .lifecycleVersionMismatch(
                    expected: expectedVersion,
                    actual: version
                )
        }
        guard let state = CampLifecycleStateV1(
            rawValue: row["state"] as String
        ), state == .active else {
            throw CampLifecycleWriteAuthorizationError.inactive(
                CampLifecycleStateV1(
                    rawValue: row["state"] as String
                ) ?? .deletedTombstone
            )
        }
        guard (row["archived"] as Int) == 0 else {
            throw CampLifecycleWriteAuthorizationError.legacyArchived
        }
        return version
    }

    private static func requireClaim(
        _ claim: DurableWorkClaim,
        operationKind: CampProviderOperationKindV1,
        expectedLifecycleVersion: Int? = nil,
        in database: Database
    ) throws -> (campID: String, lifecycleVersion: Int) {
        guard let row = try Row.fetchOne(
            database,
            sql: """
                SELECT work.*,attempt.workerId AS attemptWorkerId,
                       attempt.endedAt AS attemptEndedAt
                FROM durable_work AS work
                JOIN durable_work_attempt AS attempt
                  ON attempt.workId=work.id AND attempt.attempt=work.attempt
                WHERE work.id=?
                """,
            arguments: [claim.workId]
        ) else {
            throw CampProviderDispatchError.missingWork(claim.workId)
        }
        let kind: String = row["kind"]
        guard kind == operationKind.rawValue else {
            throw CampProviderDispatchError.invalidWorkKind
        }
        let campID: String = row["campId"]
        let lifecycleVersion: Int = row["campLifecycleVersion"]
        guard (row["state"] as String) == DurableWorkState.running.rawValue,
              (row["attempt"] as Int) == claim.attempt,
              (row["version"] as Int) == claim.version,
              (row["leaseOwner"] as String?) == claim.workerId,
              (row["leaseExpiresAt"] as Date?) == claim.leaseExpiresAt,
              (row["attemptWorkerId"] as String) == claim.workerId,
              (row["attemptEndedAt"] as Date?) == nil,
              expectedLifecycleVersion == nil
                || expectedLifecycleVersion == lifecycleVersion
        else {
            throw CampProviderDispatchError.invalidClaim
        }
        let actual = try activeLifecycleVersion(
            campId: campID,
            expectedVersion: lifecycleVersion,
            in: database
        )
        assert(actual == lifecycleVersion)
        return (campID, lifecycleVersion)
    }

    private static func insertProviderAttemptEvent(
        kind: String,
        dispatchId: String,
        claim: DurableWorkClaim,
        at: Date,
        in database: Database
    ) throws {
        try insertAttemptEvent(
            workId: claim.workId,
            attempt: claim.attempt,
            kind: kind,
            dispatchId: dispatchId,
            workerId: claim.workerId,
            workVersion: claim.version,
            resultingState: DurableWorkState.running.rawValue,
            errorCode: nil,
            errorMessage: nil,
            at: at,
            in: database
        )
    }

    private static func insertAttemptEvent(
        workId: String,
        attempt: Int,
        kind: String,
        dispatchId: String?,
        workerId: String,
        workVersion: Int,
        resultingState: String,
        errorCode: String?,
        errorMessage: String?,
        at: Date,
        in database: Database
    ) throws {
        let sequence = try nextSequence(
            workId: workId,
            attempt: attempt,
            in: database
        )
        try database.execute(
            sql: """
                INSERT INTO durable_work_attempt_event(
                  id,workId,attempt,sequence,eventKind,providerDispatchId,
                  workerId,workVersion,resultingWorkState,errorCode,errorMessage,
                  occurredAt,redactedAt
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,NULL)
                """,
            arguments: [
                UUID().uuidString, workId, attempt, sequence, kind,
                dispatchId, workerId, workVersion, resultingState,
                errorCode, errorMessage, at,
            ]
        )
    }

    private static func nextSequence(
        workId: String,
        attempt: Int,
        in database: Database
    ) throws -> Int {
        guard let maximum = try Int.fetchOne(
            database,
            sql: """
                SELECT MAX(sequence) FROM durable_work_attempt_event
                WHERE workId=? AND attempt=?
                """,
            arguments: [workId, attempt]
        ) else {
            throw CampProviderDispatchError.invalidClaim
        }
        return try checkedIncrement(maximum)
    }

    private static func insert(
        _ snapshot: CampProviderDispatchSnapshotV1,
        in database: Database
    ) throws {
        try database.execute(
            sql: """
                INSERT INTO camp_provider_dispatch(
                  id,workId,workAttempt,turnOrdinal,dispatchAttempt,
                  replayOfDispatchId,idempotencyKey,campId,
                  campLifecycleVersion,operationKind,replayClass,state,
                  requestJson,requestHash,responseJson,responseHash,version,
                  preparedAt,startedAt,returnedAt,consumedAt,abandonedAt,
                  redactedAt
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """,
            arguments: [
                snapshot.id, snapshot.workId, snapshot.workAttempt,
                snapshot.turnOrdinal, snapshot.dispatchAttempt,
                snapshot.replayOfDispatchId, snapshot.idempotencyKey,
                snapshot.campId, snapshot.campLifecycleVersion,
                snapshot.operationKind.rawValue, snapshot.replayClass.rawValue,
                snapshot.state.rawValue, snapshot.requestJson,
                snapshot.requestHash, snapshot.responseJson,
                snapshot.responseHash, snapshot.version, snapshot.preparedAt,
                snapshot.startedAt, snapshot.returnedAt, snapshot.consumedAt,
                snapshot.abandonedAt, snapshot.redactedAt,
            ]
        )
    }

    private static func dispatch(
        id: String,
        in database: Database
    ) throws -> CampProviderDispatchSnapshotV1? {
        guard let row = try Row.fetchOne(
            database,
            sql: "SELECT * FROM camp_provider_dispatch WHERE id=?",
            arguments: [id]
        ) else { return nil }
        return try decode(row)
    }

    private static func dispatch(
        idempotencyKey: String,
        in database: Database
    ) throws -> CampProviderDispatchSnapshotV1? {
        guard let row = try Row.fetchOne(
            database,
            sql: """
                SELECT * FROM camp_provider_dispatch WHERE idempotencyKey=?
                """,
            arguments: [idempotencyKey]
        ) else { return nil }
        return try decode(row)
    }

    private static func requireDispatch(
        _ id: String,
        in database: Database
    ) throws -> CampProviderDispatchSnapshotV1 {
        guard let snapshot = try dispatch(id: id, in: database) else {
            throw CampProviderDispatchError.missingDispatch(id)
        }
        return snapshot
    }

    private static func decode(
        _ row: Row
    ) throws -> CampProviderDispatchSnapshotV1 {
        guard let operation = CampProviderOperationKindV1(
            rawValue: row["operationKind"] as String
        ), let replay = CampProviderReplayClassV1(
            rawValue: row["replayClass"] as String
        ), let state = CampProviderDispatchStateV1(
            rawValue: row["state"] as String
        ) else {
            throw CampProviderDispatchError.invalidState
        }
        return CampProviderDispatchSnapshotV1(
            id: row["id"],
            workId: row["workId"],
            workAttempt: row["workAttempt"],
            turnOrdinal: row["turnOrdinal"],
            dispatchAttempt: row["dispatchAttempt"],
            replayOfDispatchId: row["replayOfDispatchId"],
            idempotencyKey: row["idempotencyKey"],
            campId: row["campId"],
            campLifecycleVersion: row["campLifecycleVersion"],
            operationKind: operation,
            replayClass: replay,
            state: state,
            requestJson: row["requestJson"],
            requestHash: row["requestHash"],
            responseJson: row["responseJson"],
            responseHash: row["responseHash"],
            version: row["version"],
            preparedAt: row["preparedAt"],
            startedAt: row["startedAt"],
            returnedAt: row["returnedAt"],
            consumedAt: row["consumedAt"],
            abandonedAt: row["abandonedAt"],
            redactedAt: row["redactedAt"]
        )
    }

    private static func validateCanonicalObject(_ json: String) throws {
        do {
            let data = Data(json.utf8)
            let canonical = try CanonicalJSONV1.canonicalizeWithRootKind(
                rawUTF8: data
            )
            guard canonical.rootKind == .object,
                  canonical.data == data
            else {
                throw CampProviderDispatchError.noncanonicalJSON
            }
        } catch is CampProviderDispatchError {
            throw CampProviderDispatchError.noncanonicalJSON
        } catch {
            throw CampProviderDispatchError.noncanonicalJSON
        }
    }

    private static func validateTime(_ value: Date) throws {
        try CanonicalContractCodingV1.validateFinite(value)
    }

    private static func checkedIncrement(_ value: Int) throws -> Int {
        let (next, overflow) = value.addingReportingOverflow(1)
        guard !overflow else { throw P1ContractValidationError.overflow }
        return next
    }
}
