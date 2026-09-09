import Foundation
import GRDB
import Testing
import AgentLoopCore

@Test func packetContainsContractAndCard() {
    let packet = ContextPacket(
        companionName: "阿规",
        rolePrompt: "你是产品伙伴",
        cardTitle: "写装备清单",
        cardDescription: "整理一份露营装备清单",
        expectedOutput: "一份分类清晰的 markdown 清单文件",
        workspacePath: "/tmp/ws",
        upstreamHandoffs: []
    )
    #expect(packet.system.contains("你是产品伙伴"))
    #expect(packet.system.contains("complete_card"))
    #expect(packet.system.contains("block_card"))
    guard case .text(let user) = packet.firstUserMessage.content[0] else { return }
    #expect(user.contains("写装备清单"))
    #expect(user.contains("分类清晰"))
    #expect(user.contains("/tmp/ws"))
}

// MARK: - 知识注入（M4，spec §6.2-5/6 + plan D2）

@Test func packetRendersCampNotesAndMemorySections() {
    let packet = ContextPacket(
        companionName: "阿规",
        rolePrompt: "r",
        cardTitle: "写清单",
        cardDescription: "d",
        expectedOutput: "o",
        workspacePath: nil,
        upstreamHandoffs: [],
        campNotes: [NoteSnippet(title: "上次的教训", body: "别在雨天搭帐篷")],
        companionNotes: [NoteSnippet(title: "用户偏好", body: "交付物要 markdown")]
    )
    guard case .text(let user) = packet.firstUserMessage.content[0] else {
        Issue.record("expected text user message")
        return
    }
    #expect(user.contains("# 营地笔记（往期经验）"))
    #expect(user.contains("## 上次的教训"))
    #expect(user.contains("别在雨天搭帐篷"))
    #expect(user.contains("# 你的记忆"))
    #expect(user.contains("交付物要 markdown"))
    // 渲染顺序：营地笔记 → 记忆
    let campIndex = user.range(of: "# 营地笔记")!.lowerBound
    let memoryIndex = user.range(of: "# 你的记忆")!.lowerBound
    #expect(campIndex < memoryIndex)
}

@Test func packetOmitsEmptyKnowledgeSections() {
    let packet = ContextPacket(
        companionName: "阿规", rolePrompt: "r", cardTitle: "A", cardDescription: "a",
        expectedOutput: "o", workspacePath: nil, upstreamHandoffs: [])
    guard case .text(let user) = packet.firstUserMessage.content[0] else { return }
    #expect(!user.contains("营地笔记"))
    #expect(!user.contains("你的记忆"))
}

@Test func knowledgeSectionsRenderBeforeUpstreamHandoffs() {
    let handoff = HandoffPayload(
        outcome: "上游完成", summary: "s", artifacts: [], noArtifactReason: "无",
        verification: [], risks: [])
    let packet = ContextPacket(
        companionName: "阿规", rolePrompt: "r", cardTitle: "A", cardDescription: "a",
        expectedOutput: "o", workspacePath: nil,
        upstreamHandoffs: [UpstreamHandoff(cardTitle: "上游卡", handoff: handoff,
                                           workspaceRelativePaths: [], durablePaths: [])],
        campNotes: [NoteSnippet(title: "笔记", body: "b")]
    )
    guard case .text(let user) = packet.firstUserMessage.content[0] else { return }
    let notesIndex = user.range(of: "# 营地笔记")!.lowerBound
    let upstreamIndex = user.range(of: "# 上游交接")!.lowerBound
    #expect(notesIndex < upstreamIndex)
}

@Test func noteSnippetTruncationLimits() {
    // D2：置顶 801 字 → 800 + 省略号；最近 150 字上限
    let long = String(repeating: "长", count: 801)
    var pinnedNote = CampNoteRecord.new(campId: "c", title: "钉", bodyMd: long)
    pinnedNote.pinned = true
    let recentNote = CampNoteRecord.new(campId: "c", title: "近", bodyMd: long)

    let snippets = NoteSnippet.from(pinned: [pinnedNote], recent: [recentNote])
    #expect(snippets.count == 2)
    #expect(snippets[0].body.count == 801) // 800 + "…"
    #expect(snippets[0].body.hasSuffix("…"))
    #expect(snippets[1].body.count == 151) // 150 + "…"
    #expect(snippets[1].body.hasSuffix("…"))

    // 恰好 800 字不截断
    var exact = CampNoteRecord.new(campId: "c", title: "整", bodyMd: String(repeating: "字", count: 800))
    exact.pinned = true
    let exactSnippet = NoteSnippet.from(pinned: [exact], recent: [])
    #expect(exactSnippet[0].body.count == 800)
    #expect(!exactSnippet[0].body.hasSuffix("…"))
}

@Test func renderSectionDeterministicAndNilWhenEmpty() {
    #expect(NoteSnippet.renderSection(header: "营地笔记（往期经验）", snippets: []) == nil)
    let snippets = [NoteSnippet(title: "t", body: "b")]
    let first = NoteSnippet.renderSection(header: "营地笔记（往期经验）", snippets: snippets)
    let second = NoteSnippet.renderSection(header: "营地笔记（往期经验）", snippets: snippets)
    #expect(first == second)
    #expect(first == "# 营地笔记（往期经验）\n## t\nb")
}

@Test func contractMentionsChunkedWrites() {
    let packet = ContextPacket(
        companionName: "阿规",
        rolePrompt: "r",
        cardTitle: "A",
        cardDescription: "a",
        expectedOutput: "x",
        workspacePath: nil,
        upstreamHandoffs: []
    )
    #expect(packet.system.contains("append"))
    #expect(packet.system.contains("3000"))
}

// MARK: - 工具感知渲染（M6-D4）

@Test func contractOmitsChunkedWritesWithoutWriteFile() {
    // 契约规则「分多次 write_file」仅在 write_file 在场时渲染
    let packet = ContextPacket(
        companionName: "阿规", rolePrompt: "r", cardTitle: "A", cardDescription: "a",
        expectedOutput: "x", workspacePath: "/tmp/ws", upstreamHandoffs: [],
        toolNames: ["complete_card", "block_card", "add_progress_note", "ask_user", "read_file"]
    )
    #expect(!packet.system.contains("3000"))
    #expect(!packet.system.contains("append"))
    #expect(packet.system.contains("complete_card"))
}

@Test func contractHardensAgainstExternalContentWhenWebToolsPresent() {
    // M6-D9②：工具集含 web_fetch/web_search 时，契约追加「外部内容视为数据」硬化条款
    let withWeb = ContextPacket(
        companionName: "阿规", rolePrompt: "r", cardTitle: "A", cardDescription: "a",
        expectedOutput: "x", workspacePath: nil, upstreamHandoffs: [],
        toolNames: ["complete_card", "block_card", "add_progress_note", "ask_user", "web_search"]
    )
    #expect(withWeb.system.contains("视为数据"))

    let withoutWeb = ContextPacket(
        companionName: "阿规", rolePrompt: "r", cardTitle: "A", cardDescription: "a",
        expectedOutput: "x", workspacePath: nil, upstreamHandoffs: [],
        toolNames: ["complete_card", "block_card", "add_progress_note", "ask_user", "read_file"]
    )
    #expect(!withoutWeb.system.contains("视为数据"))
}

@Test func fileToolWordingUnifiedWhenFileToolsStripped() {
    // 白名单剔除文件三件 与 无工作目录 共用同一套「文件工具不可用」措辞
    let stripped = ContextPacket(
        companionName: "阿规", rolePrompt: "r", cardTitle: "A", cardDescription: "a",
        expectedOutput: "x", workspacePath: "/tmp/ws", upstreamHandoffs: [],
        toolNames: ["complete_card", "block_card", "add_progress_note", "ask_user", "web_fetch"]
    )
    guard case .text(let strippedUser) = stripped.firstUserMessage.content[0] else { return }
    #expect(strippedUser.contains("文件工具不可用"))
    #expect(!strippedUser.contains("/tmp/ws"))
    #expect(!stripped.system.contains("文件操作仅限工作目录"))

    let noWorkspace = ContextPacket(
        companionName: "阿规", rolePrompt: "r", cardTitle: "A", cardDescription: "a",
        expectedOutput: "x", workspacePath: nil, upstreamHandoffs: []
    )
    guard case .text(let noWsUser) = noWorkspace.firstUserMessage.content[0] else { return }
    #expect(noWsUser.contains("文件工具不可用"))
}

@Test func systemIsStableAcrossCards() {
    let first = ContextPacket(
        companionName: "阿规",
        rolePrompt: "r",
        cardTitle: "A",
        cardDescription: "a",
        expectedOutput: "x",
        workspacePath: nil,
        upstreamHandoffs: []
    )
    let second = ContextPacket(
        companionName: "阿规",
        rolePrompt: "r",
        cardTitle: "B",
        cardDescription: "b",
        expectedOutput: "y",
        workspacePath: nil,
        upstreamHandoffs: []
    )
    #expect(first.system == second.system)
}

private func p1f1d080DependencyLoader(
    _ database: AppDatabase,
    manager: McpServerManager? = nil,
    searchKey: String? = nil
) -> ContextDependencyLoader {
    ContextDependencyLoader(
        database: database,
        manager: manager,
        reporter: FailureReporter(database: database),
        searchCredential: { searchKey },
        knowledge: .live(database: database),
        makeTrace: { operation, scope in
            OperationTraceFactory.live.generated(
                operation: operation,
                scope: scope
            )
        }
    )
}

private func p1f1d080RenderedText(
    _ packet: ContextPacket
) throws -> String {
    guard case .text(let user) = packet.firstUserMessage.content[0] else {
        throw EngineContextValidationErrorV1()
    }
    return packet.system + "\n" + user
}

private func p1f1d080Fields(
    fixture: P1F1DCanonicalExecutionFixture,
    expected: P1F1DCanonicalExpectedContext,
    resolved: EngineResolvedContextTransportV1,
    predecessorExecutionId: String?
) throws -> EngineExecutionRequestFieldsV1 {
    let base = try fixture.fields(
        predecessorExecutionId: predecessorExecutionId,
        context: expected
    )
    var capabilities = base.requiredCapabilities
    if !capabilities.contains(.sessionResume) {
        capabilities.append(.sessionResume)
    }
    return try EngineExecutionRequestFieldsV1(
        campId: base.campId,
        cardId: base.cardId,
        contract: base.contract,
        profileId: base.profileId,
        engineKind: base.engineKind,
        model: base.model,
        contextJson: resolved.canonicalEnvelopeJSON,
        contextHash: resolved.hash,
        requiredCapabilities: capabilities,
        approvalGrantIds: base.approvalGrantIds,
        budget: base.budget,
        workspace: base.workspace,
        sessionSelection: nil,
        predecessorExecutionId: predecessorExecutionId,
        claimedSessionScopeJson: base.claimedSessionScopeJson,
        claimedSessionScopeHash: base.claimedSessionScopeHash
    )
}

private func p1f1d080SchemaOneRequest(
    fixture: P1F1DCanonicalExecutionFixture,
    variant: EnginePreparedContextVariantV1
) throws -> EngineContextResolveRequestV1 {
    let toolNames = variant.toolBindings.map(\.providerVisibleName)
    let instructionBytes = try CanonicalJSONV1.encode(
        P1F1DCanonicalInstructionContextV1(
            schemaVersion: 1,
            outcomeContract: fixture.contract.ref,
            autonomy: fixture.mission.autonomy,
            contextPacketRenderVersion: 1,
            toolNames: toolNames
        )
    )
    let references = try EngineContextReferencesV1(
        inputRefs: variant.resolved.envelope.inputRefs,
        memoryRefs: variant.resolved.envelope.memoryRefs,
        resourceRefs: variant.resolved.envelope.resourceRefs,
        priorHandoffRefs: variant.resolved.envelope.priorHandoffRefs,
        instructionBlocks: [EngineContextReferenceV1(
            type: "instruction",
            id: fixture.contract.ref.id,
            version: fixture.contract.ref.version,
            hash: CanonicalJSONV1.sha256Hex(instructionBytes)
        )]
    )
    let packet = ContextPacket(
        companionName: fixture.companion.name,
        rolePrompt: fixture.companion.rolePrompt,
        cardTitle: fixture.card.title,
        cardDescription: fixture.card.descriptionText,
        expectedOutput: fixture.card.expectedOutput,
        workspacePath: fixture.workspaceURL.path,
        upstreamHandoffs: [],
        toolNames: toolNames,
        engineContextReferences: references
    )
    let envelope = try EngineContextEnvelopeV1.from(
        packet: packet,
        scope: EngineContextScopeV1(
            campId: fixture.camp.id,
            goalId: fixture.goal.id,
            missionId: fixture.mission.id,
            cardId: fixture.card.id,
            outcomeContract: fixture.contract.ref
        )
    )
    let bytes = try CanonicalJSONV1.encode(envelope)
    return try EngineContextResolveRequestV1(
        campId: fixture.camp.id,
        cardId: fixture.card.id,
        companionId: fixture.companion.id,
        contextJson: String(decoding: bytes, as: UTF8.self),
        contextHash: CanonicalJSONV1.sha256Hex(bytes)
    )
}

private enum P1F1D080UnexpectedEffect: Error, Sendable, Equatable {
    case cliDriver
    case processSignal
}

private final class P1F1D080RecoveryProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var initialProviders = 0
    private var recoveryProviders = 0
    private var cliDrivers = 0
    private var processSnapshots = 0
    private var processSignals = 0
    private var processGroupChecks = 0

    func recordInitialProvider() {
        lock.withLock { initialProviders += 1 }
    }

    func recordRecoveryProvider() {
        lock.withLock { recoveryProviders += 1 }
    }

    func recordCLIDriver() {
        lock.withLock { cliDrivers += 1 }
    }

    func recordProcessSnapshot() {
        lock.withLock { processSnapshots += 1 }
    }

    func recordProcessSignal() {
        lock.withLock { processSignals += 1 }
    }

    func recordProcessGroupCheck() {
        lock.withLock { processGroupChecks += 1 }
    }

    var snapshot: (
        initialProviders: Int,
        recoveryProviders: Int,
        cliDrivers: Int,
        processSnapshots: Int,
        processSignals: Int,
        processGroupChecks: Int
    ) {
        lock.withLock {
            (
                initialProviders,
                recoveryProviders,
                cliDrivers,
                processSnapshots,
                processSignals,
                processGroupChecks
            )
        }
    }
}

private struct P1F1D080ProcessInspector:
    EngineRuntimeProcessInspectingV1, Sendable
{
    let probe: P1F1D080RecoveryProbe

    func snapshots() throws -> [EngineRuntimeProcessSnapshotV1] {
        probe.recordProcessSnapshot()
        return []
    }

    func send(signal: Int32, processGroupId: Int32) throws {
        _ = signal
        _ = processGroupId
        probe.recordProcessSignal()
        throw P1F1D080UnexpectedEffect.processSignal
    }

    func processGroupExists(_ processGroupId: Int32) throws -> Bool {
        _ = processGroupId
        probe.recordProcessGroupCheck()
        return false
    }
}

private func p1f1d080Environment(
    fixture: P1F1DCanonicalExecutionFixture,
    probe: P1F1D080RecoveryProbe
) throws -> EngineExecutionEnvironmentV1 {
    let artifacts = fixture.root.appendingPathComponent("r9f080-artifacts")
    let claude = fixture.root.appendingPathComponent("r9f080-claude")
    let executables = fixture.root.appendingPathComponent("r9f080-executables")
    for directory in [artifacts, claude, executables] {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }
    let provider = MockProvider(script: [])
    let inspector = P1F1D080ProcessInspector(probe: probe)
    return try EngineExecutionEnvironmentV1(
        database: fixture.db,
        stateDirectoryLock: StateDirectoryLock(directoryURL: fixture.root),
        artifactStoreRoot: artifacts,
        bridgeExecutablePath: nil,
        boardSocketDirectoryAuthority: nil,
        validateCodexManagedPolicy: nil,
        validateClaudeManagedPolicy: nil,
        claudeConfigDirectory: claude,
        cliExecutableDirectory: executables,
        processInspector: inspector,
        dependencyLoader: p1f1d080DependencyLoader(fixture.db),
        resolveInitialModelLoopProvider: {
            profile, companionId, companionModel, _ in
            guard profile == fixture.profile,
                  companionId == fixture.companion.id
            else {
                throw EngineAdapterSelectionErrorV1.descriptorMismatch
            }
            probe.recordInitialProvider()
            return try EngineModelLoopProviderAuthorityV1(
                profileId: profile.id,
                effectiveModel: companionModel,
                makeProvider: { provider }
            )
        },
        resolveRecoveryModelLoopProvider: {
            profile, companionId, persistedModel in
            guard profile == fixture.profile,
                  companionId == fixture.companion.id
            else {
                throw EngineAdapterSelectionErrorV1.descriptorMismatch
            }
            probe.recordRecoveryProvider()
            return try EngineModelLoopProviderAuthorityV1(
                profileId: profile.id,
                effectiveModel: persistedModel,
                makeProvider: { provider }
            )
        },
        helpProbe: CliHelpProbeV1(processInspector: inspector),
        makeCliProcessDriver: {
            probe.recordCLIDriver()
            throw P1F1D080UnexpectedEffect.cliDriver
        },
        clock: { P1F1DCanonicalExecutionFixture.now }
    )
}

private func p1f1d080AssertSchemaOneRunningRecoveryHalt()
    async throws
{
    let fixture = try P1F1DCanonicalExecutionFixture(
        replayClass: .idempotencyKeyed,
        profileKind: .openAIAPI
    )
    let probe = P1F1D080RecoveryProbe()
    let runtime = EngineExecutionRuntimeV1(
        environment: try p1f1d080Environment(
            fixture: fixture,
            probe: probe
        ),
        eventObserver: { _, _ in }
    )
    try await fixture.db.pool.write { database in
        try AppDatabase.appendEvent(
            database,
            missionId: fixture.mission.id,
            cardId: fixture.card.id,
            runId: nil,
            kind: EventKind.cardReady,
            payload: .object([:])
        )
    }
    let cause = try await fixture.db.pool.read { database in
        try fixture.db.resolveEngineCardReadyCause(
            for: fixture.card,
            in: database
        )
    }
    let prepared = try await runtime.prepare(
        EngineDispatchIdentityV1(
            campId: fixture.camp.id,
            cardId: fixture.card.id,
            companionId: fixture.companion.id,
            cause: cause
        )
    )
    let baselineEffects = probe.snapshot
    #expect(baselineEffects.initialProviders == 1)
    #expect(baselineEffects.recoveryProviders == 0)
    let registry = try await runtime.registry(
        requestedProfileKinds: [.openAIAPI]
    )
    let store = EngineExecutionStore(
        database: fixture.db,
        descriptorResolver: { profile, requiredCapabilities in
            try registry.resolve(
                profile: profile,
                requiredCapabilities: requiredCapabilities
            ).descriptor
        },
        clock: { P1F1DCanonicalExecutionFixture.now }
    )
    let schemaOne = try p1f1d080SchemaOneRequest(
        fixture: fixture,
        variant: prepared.context.modelLoop
    )
    let base = prepared.requestFields
    let schemaOneFields = try EngineExecutionRequestFieldsV1(
        campId: base.campId,
        cardId: base.cardId,
        contract: base.contract,
        profileId: base.profileId,
        engineKind: base.engineKind,
        model: base.model,
        contextJson: schemaOne.contextJson,
        contextHash: schemaOne.contextHash,
        requiredCapabilities: base.requiredCapabilities,
        approvalGrantIds: base.approvalGrantIds,
        budget: base.budget,
        workspace: base.workspace,
        sessionSelection: base.sessionSelection,
        predecessorExecutionId: base.predecessorExecutionId,
        claimedSessionScopeJson: base.claimedSessionScopeJson,
        claimedSessionScopeHash: base.claimedSessionScopeHash
    )
    let request = try store.beginEngineExecution(
        requestFields: schemaOneFields,
        idempotencyKey: prepared.idempotencyKey
    )
    let before = try await fixture.db.pool.read { database in
        try #require(
            try EngineExecutionRecord.fetchOne(
                database,
                key: request.executionId
            )
        )
    }
    #expect(before.state == .running)
    #expect(before.dispatchState == .prepared)
    await #expect(throws: EngineContextValidationErrorV1.self) {
        _ = try await runtime.recover(
            missionId: fixture.mission.id,
            now: P1F1DCanonicalExecutionFixture.now.addingTimeInterval(1)
        )
    }
    let after = try await fixture.db.pool.read { database in
        try #require(
            try EngineExecutionRecord.fetchOne(
                database,
                key: request.executionId
            )
        )
    }
    #expect(after == before)
    let effects = probe.snapshot
    #expect(effects.initialProviders == baselineEffects.initialProviders)
    #expect(effects.recoveryProviders == 0)
    #expect(effects.cliDrivers == 0)
    #expect(effects.processSnapshots == 0)
    #expect(effects.processSignals == 0)
    #expect(effects.processGroupChecks == 0)
    let active = await runtime.activeExecutions.snapshotCounts()
    #expect(active.live == 0)
    #expect(active.pending == 0)
    #expect(active.inFlight == 0)
    #expect(await runtime.completionRegistry.snapshotCount() == 0)
    try await runtime.closeRuntimeAuthorities()
}

@Test func p1f1_080AnsweredRequestChangesContextNotSessionScope()
    async throws
{
    let firstSeed = P1F1DCanonicalAnsweredRequestSeed.first
    let secondSeed = P1F1DCanonicalAnsweredRequestSeed.second
    let fixture = try P1F1DCanonicalExecutionFixture(
        answeredRequests: [firstSeed]
    )
    let resolver = EngineContextTransportResolverV1(
        database: fixture.db,
        dependencyLoader: p1f1d080DependencyLoader(fixture.db)
    )
    let firstPrepared = try await resolver.prepareCurrent(
        campId: fixture.camp.id,
        cardId: fixture.card.id,
        companionId: fixture.companion.id
    )
    let firstExpected = try fixture.expectedContext()

    // Mutation caught: deriving profile/model/policy/contract/limits outside
    // the frozen graph snapshot would make one of these persisted-row values
    // disagree with the preparation result.
    #expect(firstPrepared.profile == fixture.profile)
    #expect(firstPrepared.contract == fixture.contract.ref)
    #expect(firstPrepared.companionId == fixture.companion.id)
    #expect(firstPrepared.companionModel == fixture.companion.model)
    #expect(
        firstPrepared.companionModelPolicy == fixture.companion.modelPolicy
    )
    #expect(firstPrepared.autonomy == fixture.mission.autonomy)
    #expect(firstPrepared.cardMaxTurns == fixture.card.maxTurns)
    #expect(firstPrepared.cardTokenBudget == fixture.card.tokenBudget)

    let boardLogicalNames = [
        "complete_card",
        "block_card",
        "add_progress_note",
        "ask_user",
    ]
    let expectedModelBindings = boardLogicalNames.map {
        EngineContextToolBindingV1(
            logicalName: $0,
            providerVisibleName: $0
        )
    }
    let expectedCliBindings = boardLogicalNames.map {
        EngineContextToolBindingV1(
            logicalName: $0,
            providerVisibleName: "mcp__ranchboard__\($0)"
        )
    }
    let expectedCliInstructionBindings = boardLogicalNames.map {
        P1F1DCanonicalToolBindingV2(
            logicalName: $0,
            providerVisibleName: "mcp__ranchboard__\($0)"
        )
    }
    let expectedBoardDefinitions: [ToolDef] = [
        .completeCard,
        .blockCard,
        .addProgressNote,
        .askUser,
    ]
    let expectedBoardCliDefinitions = zip(
        expectedBoardDefinitions,
        expectedCliBindings
    ).map { definition, binding in
        ToolDef(
            name: binding.providerVisibleName,
            description: definition.description,
            inputSchema: definition.inputSchema
        )
    }

    // Mutation caught: reordering Board definitions, deriving the variants
    // independently, or binding a CLI name without the exact namespace prefix.
    #expect(
        firstPrepared.capabilityTools.logicalDefinitions
            == expectedBoardDefinitions
    )
    #expect(
        firstPrepared.capabilityTools.modelLoopDefinitions
            == expectedBoardDefinitions
    )
    #expect(
        firstPrepared.capabilityTools.cliDefinitions
            == expectedBoardCliDefinitions
    )
    #expect(firstPrepared.modelLoop.namespace == .modelLoop)
    #expect(firstPrepared.cli.namespace == .ranchMCP)
    #expect(firstPrepared.modelLoop.toolBindings == expectedModelBindings)
    #expect(firstPrepared.cli.toolBindings == expectedCliBindings)
    #expect(firstPrepared.cli.request == firstExpected.contextRequest)
    #expect(
        firstPrepared.modelLoop.request.contextHash
            != firstPrepared.cli.request.contextHash
    )

    let boundBoardOnly = try firstPrepared.capabilityTools
        .makeCapabilityTools(fixture.workspaceURL)
    #expect(
        boundBoardOnly.logicalDefinitions
            == firstPrepared.capabilityTools.logicalDefinitions
    )
    #expect(boundBoardOnly.capabilityTools.isEmpty)

    // Mutation caught: schema 1/render 1/toolNames re-emission, reordered
    // bindings, or a hash computed from any bytes other than the literal v2 DTO.
    let independentlyEncodedInstruction = try CanonicalJSONV1.encode(
        P1F1DCanonicalInstructionContextV2(
            schemaVersion: 2,
            outcomeContract: fixture.contract.ref,
            autonomy: fixture.mission.autonomy,
            contextPacketRenderVersion: 2,
            toolBindings: expectedCliInstructionBindings
        )
    )
    #expect(
        firstExpected.goldens.instructionBytes
            == independentlyEncodedInstruction
    )
    #expect(
        firstExpected.envelope.instructionBlocks[0].hash
            == CanonicalJSONV1.sha256Hex(independentlyEncodedInstruction)
    )
    guard case .object(let instructionObject) = try JSONValue.decoded(
        from: String(
            decoding: independentlyEncodedInstruction,
            as: UTF8.self
        )
    ) else {
        Issue.record("expected schema-2 instruction object")
        return
    }
    #expect(Set(instructionObject.keys) == [
        "autonomy",
        "contextPacketRenderVersion",
        "outcomeContract",
        "schemaVersion",
        "toolBindings",
    ])
    #expect(instructionObject["schemaVersion"]?.intValue == 2)
    #expect(instructionObject["contextPacketRenderVersion"]?.intValue == 2)
    #expect(instructionObject["toolNames"] == nil)
    let encodedToolBindings = try #require(
        instructionObject["toolBindings"]?.arrayValue
    )
    #expect(encodedToolBindings.count == boardLogicalNames.count)
    for (index, value) in encodedToolBindings.enumerated() {
        guard case .object(let object) = value else {
            Issue.record("schema-2 tool binding must be an object")
            return
        }
        #expect(Set(object.keys) == [
            "logicalName",
            "providerVisibleName",
        ])
        #expect(
            object["logicalName"]?.stringValue == boardLogicalNames[index]
        )
        #expect(
            object["providerVisibleName"]?.stringValue
                == "mcp__ranchboard__\(boardLogicalNames[index])"
        )
    }

    // Mutation caught: rendering logical CLI names instead of the bound names.
    let modelText = try p1f1d080RenderedText(firstPrepared.modelLoop.resolved.packet)
    let cliText = try p1f1d080RenderedText(firstPrepared.cli.resolved.packet)
    for logicalName in [
        "complete_card",
        "block_card",
        "add_progress_note",
    ] {
        let providerName = "mcp__ranchboard__\(logicalName)"
        #expect(modelText.contains(logicalName))
        #expect(!modelText.contains(providerName))
        #expect(cliText.contains(providerName))
        #expect(
            !cliText.replacingOccurrences(
                of: providerName,
                with: ""
            ).contains(logicalName)
        )
    }

    let first = try await resolver.assemble(firstExpected.contextRequest)

    #expect(first.canonicalEnvelopeJSON == firstExpected.canonicalJSON)
    #expect(first.hash == firstExpected.hash)
    #expect(first.envelope == firstExpected.envelope)
    #expect(
        first.packet.engineContextReferences
            == firstExpected.goldens.references
    )
    #expect(
        first.envelope.inputRefs
            == firstExpected.goldens.references.inputRefs
    )
    #expect(
        first.envelope.resourceRefs
            == firstExpected.goldens.references.resourceRefs
    )
    #expect(
        first.envelope.instructionBlocks
            == firstExpected.goldens.references.instructionBlocks
    )
    #expect(first.envelope.inputRefs.count == 2)
    #expect(first.envelope.memoryRefs.isEmpty)
    #expect(first.envelope.resourceRefs.count == 2)
    #expect(first.envelope.priorHandoffRefs.isEmpty)
    #expect(first.envelope.instructionBlocks.count == 1)
    #expect(
        first.envelope.inputRefs.count
            + first.envelope.memoryRefs.count
            + first.envelope.resourceRefs.count
            + first.envelope.priorHandoffRefs.count
            + first.envelope.instructionBlocks.count
            == 5
    )
    #expect(
        Set(first.envelope.inputRefs.map(\.id))
            == [fixture.card.id, firstSeed.id]
    )

    let firstAnswerBytes = try #require(
        firstExpected.goldens.answeredBytesByID[firstSeed.id]
    )
    let firstAnswer = try JSONDecoder().decode(
        EngineAnsweredRequestContextV1.self,
        from: firstAnswerBytes
    )
    let firstAnswerJSON = try JSONValue.decoded(
        from: String(decoding: firstAnswerBytes, as: UTF8.self)
    )
    #expect(firstAnswer.userRequestId == firstSeed.id)
    #expect(firstAnswer.cardId == fixture.card.id)
    #expect(firstAnswer.prompt == firstSeed.prompt)
    #expect(firstAnswer.answeredAt == firstSeed.answeredAt)
    #expect(
        firstAnswerJSON["answeredAt"]?.intValue
            == Int(firstSeed.answeredAt.timeIntervalSince1970 * 1_000)
    )

    // The supplied envelope is only an expected golden. Rebuild must reject
    // a self-consistent caller claim whose answered-row hash is forged.
    let firstAnswerRef = try #require(
        firstExpected.goldens.references.inputRefs.first {
            $0.id == firstSeed.id
        }
    )
    let forgedJSON = firstExpected.canonicalJSON.replacingOccurrences(
        of: firstAnswerRef.hash,
        with: String(repeating: "0", count: 64)
    )
    let forgedRequest = try EngineContextResolveRequestV1(
        campId: fixture.camp.id,
        cardId: fixture.card.id,
        companionId: fixture.companion.id,
        contextJson: forgedJSON,
        contextHash: CanonicalJSONV1.sha256Hex(Data(forgedJSON.utf8))
    )
    await #expect(throws: EngineContextValidationErrorV1.self) {
        _ = try await resolver.assemble(forgedRequest)
    }

    let workspaceResolver = EngineWorkspaceResolverV1(database: fixture.db)
    let preparedWorkspace = try workspaceResolver.prepareCurrent(
        cardId: fixture.card.id,
        campId: fixture.camp.id
    )
    #expect(preparedWorkspace.request == firstExpected.workspaceRequest)
    #expect(preparedWorkspace.workspace == firstExpected.workspaceReference)
    let resolvedWorkspace = try workspaceResolver.resolve(
        preparedWorkspace.request
    )
    #expect(resolvedWorkspace.identity.workspacePath == fixture.workspaceURL.path)
    resolvedWorkspace.release()

    // Mutation caught: trusting a caller-forged workspace hash instead of the
    // identity rebuilt from the card/mission/squad/camp graph.
    let forgedWorkspaceRequest = try EngineWorkspaceResolveRequestV1(
        cardId: fixture.card.id,
        campId: fixture.camp.id,
        expectedWorkspace: EngineWorkspaceRefV1(
            reference: preparedWorkspace.workspace.reference,
            hash: String(repeating: "0", count: 64)
        )
    )
    #expect(throws: EngineContextValidationErrorV1.self) {
        _ = try workspaceResolver.resolve(forgedWorkspaceRequest)
    }

    let legacyPersistedRequest = try p1f1d080SchemaOneRequest(
        fixture: fixture,
        variant: firstPrepared.cli
    )

    // Mutation caught: rewriting/rebinding schema-1 evidence or guessing a
    // namespace inside reloadPrepared instead of exposing both rebuilt variants.
    let legacyRequestBytesBefore = Data(legacyPersistedRequest.contextJson.utf8)
    let rebuiltFromLegacy = try await resolver.reloadPrepared(
        legacyPersistedRequest
    )
    #expect(Data(legacyPersistedRequest.contextJson.utf8) == legacyRequestBytesBefore)
    #expect(legacyPersistedRequest != rebuiltFromLegacy.modelLoop.request)
    #expect(legacyPersistedRequest != rebuiltFromLegacy.cli.request)
    #expect(rebuiltFromLegacy.modelLoop.request == firstPrepared.modelLoop.request)
    #expect(rebuiltFromLegacy.cli.request == firstPrepared.cli.request)
    await #expect(throws: EngineContextValidationErrorV1.self) {
        _ = try await resolver.reload(legacyPersistedRequest)
    }
    try await p1f1d080AssertSchemaOneRunningRecoveryHalt()

    let predecessorFields = try p1f1d080Fields(
        fixture: fixture,
        expected: firstExpected,
        resolved: first,
        predecessorExecutionId: nil
    )
    #expect(
        predecessorFields.requiredCapabilities.contains(.sessionResume)
    )
    let predecessor = try fixture.begin(
        key: "p1f1d-080-predecessor",
        fields: predecessorFields
    )
    let prepared = try p1f1ExecutionRow(
        fixture.db,
        id: predecessor.executionId
    )
    _ = try fixture.store.markEngineDispatchStarted(
        executionId: predecessor.executionId,
        expectedVersion: prepared["version"],
        requestHash: predecessor.requestHash,
        commandIdempotencyKey: "p1f1d-080-predecessor-dispatch",
        now: P1F1DCanonicalExecutionFixture.now.addingTimeInterval(1)
    )
    try fixture.store.acceptEngineEvent(
        executionId: predecessor.executionId,
        sequence: 0,
        event: EngineExecutionEvent(
            executionId: predecessor.executionId,
            sequence: 0,
            payload: .sessionBound(externalSessionId: "codex-thread-080")
        )
    )
    let recorded = try fixture.store.recordEngineTerminalProposal(
        EngineTerminalProposalContentV1(
            protocolVersion: "agentloop.execution.v1",
            executionId: predecessor.executionId,
            runId: predecessor.runId,
            cardId: predecessor.cardId,
            sequence: 1,
            terminalIdempotencyKey: "p1f1d-080-predecessor-terminal",
            terminalKind: .canceled,
            terminalSubtype: nil,
            payload: .canceled(
                reasonCode: "engine_canceled",
                detail: "eligible predecessor"
            ),
            artifacts: []
        )
    )
    _ = try fixture.store.commitEngineTerminal(
        proposalId: recorded.proposal.id,
        checkedUsage: .zero,
        now: P1F1DCanonicalExecutionFixture.now.addingTimeInterval(2)
    )
    let predecessorRow = try p1f1ExecutionRow(
        fixture.db,
        id: predecessor.executionId
    )
    let predecessorSessionId: String = try #require(
        predecessorRow["sessionId"]
    )
    let predecessorState: String = predecessorRow["state"]
    #expect(predecessorState != "running")

    try fixture.insertAnsweredRequest(secondSeed)
    await #expect(throws: EngineContextValidationErrorV1.self) {
        _ = try await resolver.reload(firstExpected.contextRequest)
    }

    let secondExpected = try fixture.expectedContext()
    let second = try await resolver.assemble(secondExpected.contextRequest)
    #expect(second.canonicalEnvelopeJSON == secondExpected.canonicalJSON)
    #expect(second.hash == secondExpected.hash)
    #expect(second.envelope == secondExpected.envelope)
    #expect(
        second.packet.engineContextReferences
            == secondExpected.goldens.references
    )
    #expect(second.hash != first.hash)
    #expect(second.envelope.inputRefs.count == 3)
    #expect(second.envelope.memoryRefs.isEmpty)
    #expect(second.envelope.resourceRefs.count == 2)
    #expect(second.envelope.priorHandoffRefs.isEmpty)
    #expect(second.envelope.instructionBlocks.count == 1)
    #expect(
        second.envelope.inputRefs.count
            + second.envelope.memoryRefs.count
            + second.envelope.resourceRefs.count
            + second.envelope.priorHandoffRefs.count
            + second.envelope.instructionBlocks.count
            == 6
    )
    #expect(
        Set(second.envelope.inputRefs.map(\.id))
            == [fixture.card.id, firstSeed.id, secondSeed.id]
    )

    // Answer growth changes only the answered-input set. Every other source
    // byte and reference remains stable across the real database rebuild.
    #expect(
        firstExpected.goldens.cardBytes
            == secondExpected.goldens.cardBytes
    )
    #expect(
        firstExpected.goldens.companionBytes
            == secondExpected.goldens.companionBytes
    )
    #expect(
        firstExpected.goldens.workspaceBytes
            == secondExpected.goldens.workspaceBytes
    )
    #expect(
        firstExpected.goldens.instructionBytes
            == secondExpected.goldens.instructionBytes
    )
    #expect(
        firstExpected.goldens.answeredBytesByID[firstSeed.id]
            == secondExpected.goldens.answeredBytesByID[firstSeed.id]
    )
    #expect(secondExpected.goldens.answeredBytesByID.count == 2)
    #expect(
        first.envelope.resourceRefs == second.envelope.resourceRefs
    )
    #expect(
        first.envelope.instructionBlocks
            == second.envelope.instructionBlocks
    )
    #expect(first.envelope.memoryRefs == second.envelope.memoryRefs)
    #expect(
        first.envelope.priorHandoffRefs
            == second.envelope.priorHandoffRefs
    )
    let firstCardRef = try #require(
        first.envelope.inputRefs.first { $0.id == fixture.card.id }
    )
    let secondCardRef = try #require(
        second.envelope.inputRefs.first { $0.id == fixture.card.id }
    )
    #expect(firstCardRef == secondCardRef)

    let persistedFirstAnswerBytes = try #require(
        secondExpected.goldens.answeredBytesByID[firstSeed.id]
    )
    let secondAnswerBytes = try #require(
        secondExpected.goldens.answeredBytesByID[secondSeed.id]
    )
    let persistedFirstAnswer = try JSONDecoder().decode(
        EngineAnsweredRequestContextV1.self,
        from: persistedFirstAnswerBytes
    )
    let secondAnswer = try JSONDecoder().decode(
        EngineAnsweredRequestContextV1.self,
        from: secondAnswerBytes
    )
    let secondAnswerJSON = try JSONValue.decoded(
        from: String(decoding: secondAnswerBytes, as: UTF8.self)
    )
    #expect(persistedFirstAnswer.answeredAt == firstSeed.answeredAt)
    #expect(secondAnswer.userRequestId == secondSeed.id)
    #expect(secondAnswer.cardId == fixture.card.id)
    #expect(secondAnswer.prompt == secondSeed.prompt)
    #expect(secondAnswer.answeredAt == secondSeed.answeredAt)
    #expect(
        secondAnswerJSON["answeredAt"]?.intValue
            == Int(secondSeed.answeredAt.timeIntervalSince1970 * 1_000)
    )

    let successorFields = try p1f1d080Fields(
        fixture: fixture,
        expected: secondExpected,
        resolved: second,
        predecessorExecutionId: predecessor.executionId
    )
    let successor = try fixture.begin(
        key: "p1f1d-080-successor",
        fields: successorFields
    )
    let successorJSON = try JSONValue.decoded(from: successor.requestJson)
    #expect(
        successorJSON["predecessorExecutionId"]?.stringValue
            == predecessor.executionId
    )
    #expect(predecessor.contextHash != successor.contextHash)
    #expect(predecessor.sessionScopeHash == successor.sessionScopeHash)
    #expect(successor.sessionRef?.sessionId == predecessorSessionId)
    #expect(successor.sessionRef?.externalSessionId == "codex-thread-080")
    #expect(
        fixture.descriptor.support(for: .sessionResume) == .supported
    )

    let selectedCapabilityNames = [
        "list_dir",
        "mcp__github__list_issues",
        "read_file",
        "run_shell",
        "search_camp_notes",
        "web_fetch",
        "write_file",
    ]
    let capabilityFixture = try P1F1DCanonicalExecutionFixture(
        toolsJson: ToolAccess.explicitJson(
            allow: Set(selectedCapabilityNames)
        )
    )
    let githubServer = McpServerRecord.new(
        name: "github",
        command: "must-not-launch",
        args: []
    )
    try capabilityFixture.db.addMcpServer(githubServer)
    try capabilityFixture.db.setMcpServerEnabled(
        campId: capabilityFixture.camp.id,
        serverId: githubServer.id,
        enabled: true
    )
    let mcpTransports = LockedArrayBox<FakeMcpTransport>()
    let mcpManager = McpServerManager(
        db: capabilityFixture.db,
        transportFactory: { _, _ in
            let transport = FakeMcpTransport()
            mcpTransports.append(transport)
            return transport
        },
        secretProvider: { _, _ in nil },
        baseEnvironment: { [:] }
    )
    let capabilityResolver = EngineContextTransportResolverV1(
        database: capabilityFixture.db,
        dependencyLoader: p1f1d080DependencyLoader(
            capabilityFixture.db,
            manager: mcpManager
        )
    )
    let capabilityPrepared = try await capabilityResolver.prepareCurrent(
        campId: capabilityFixture.camp.id,
        cardId: capabilityFixture.card.id,
        companionId: capabilityFixture.companion.id
    )
    let allLogicalNames = boardLogicalNames + selectedCapabilityNames

    // Mutation caught: nondeterministic suffix order, graph drift between
    // namespace variants, or definitions rebuilt independently of bindings.
    #expect(
        capabilityPrepared.capabilityTools.logicalDefinitions.map(\.name)
            == allLogicalNames
    )
    #expect(
        capabilityPrepared.capabilityTools.modelLoopDefinitions
            == capabilityPrepared.capabilityTools.logicalDefinitions
    )
    #expect(
        capabilityPrepared.capabilityTools.cliDefinitions
            == capabilityPrepared.capabilityTools.logicalDefinitions.map {
                ToolDef(
                    name: "mcp__ranchboard__\($0.name)",
                    description: $0.description,
                    inputSchema: $0.inputSchema
                )
            }
    )
    #expect(
        capabilityPrepared.modelLoop.toolBindings
            == allLogicalNames.map {
                EngineContextToolBindingV1(
                    logicalName: $0,
                    providerVisibleName: $0
                )
            }
    )
    #expect(
        capabilityPrepared.cli.toolBindings
            == allLogicalNames.map {
                EngineContextToolBindingV1(
                    logicalName: $0,
                    providerVisibleName: "mcp__ranchboard__\($0)"
                )
            }
    )
    #expect(capabilityPrepared.capabilityTools.requiresWorkspaceWrite)
    for (logical, cli) in zip(
        capabilityPrepared.capabilityTools.modelLoopDefinitions,
        capabilityPrepared.capabilityTools.cliDefinitions
    ) {
        #expect(cli.name == "mcp__ranchboard__\(logical.name)")
        #expect(cli.description == logical.description)
        #expect(cli.inputSchema == logical.inputSchema)
    }

    let boundCapabilities = try capabilityPrepared.capabilityTools
        .makeCapabilityTools(capabilityFixture.workspaceURL)
    #expect(
        boundCapabilities.logicalDefinitions
            == capabilityPrepared.capabilityTools.logicalDefinitions
    )
    #expect(
        boundCapabilities.capabilityTools.map(\.def)
            == Array(
                capabilityPrepared.capabilityTools.logicalDefinitions
                    .dropFirst(boardLogicalNames.count)
            )
    )
    #expect(
        Set(boundCapabilities.capabilityTools.map(\.def.name))
            .isDisjoint(with: Set(boardLogicalNames))
    )

    let handlerByLogicalName = Dictionary(
        uniqueKeysWithValues: boundCapabilities.capabilityTools.map {
            ($0.def.name, $0.handler)
        }
    )

    // Mutation caught: replacing any selected read-only handler with a fixed
    // unavailable handler, the wrong file operation, or a non-camp query.
    let readOnlyDirectoryURL = capabilityFixture.workspaceURL
        .appendingPathComponent("fixture-dir")
    try FileManager.default.createDirectory(
        at: readOnlyDirectoryURL,
        withIntermediateDirectories: true
    )
    let readOnlyFileURL = capabilityFixture.workspaceURL
        .appendingPathComponent("read-only-fixture.txt")
    try "deterministic read fixture".write(
        to: readOnlyFileURL,
        atomically: true,
        encoding: .utf8
    )

    let listHandler = try #require(handlerByLogicalName["list_dir"])
    guard case .result(let directoryListing) = await listHandler.execute(
        input: ["path": ""]
    ) else {
        Issue.record("list_dir must execute the real workspace list handler")
        return
    }
    #expect(
        directoryListing
            == "[dir] fixture-dir\n[file] read-only-fixture.txt"
    )

    let readHandler = try #require(handlerByLogicalName["read_file"])
    guard case .result(let fileText) = await readHandler.execute(
        input: ["path": "read-only-fixture.txt"]
    ) else {
        Issue.record("read_file must execute the real workspace read handler")
        return
    }
    #expect(fileText == "deterministic read fixture")

    let webFetchHandler = try #require(handlerByLogicalName["web_fetch"])
    guard case .error(let webFetchMessage) = await webFetchHandler.execute(
        input: ["url": "file:///must-not-be-fetched"]
    ) else {
        Issue.record("web_fetch must execute its real HTTPS validation")
        return
    }
    #expect(webFetchMessage == "需要一个 https:// 开头的合法 URL")

    let noteSearchToken = "r9b-read-only-handler-token"
    try capabilityFixture.db.saveCampNote(.new(
        campId: capabilityFixture.camp.id,
        title: "R9-B handler fixture",
        bodyMd: "stable \(noteSearchToken) body"
    ))
    let noteSearchHandler = try #require(
        handlerByLogicalName["search_camp_notes"]
    )
    guard case .result(let noteSearchText) = await noteSearchHandler.execute(
        input: ["query": .string(noteSearchToken)]
    ) else {
        Issue.record(
            "search_camp_notes must execute the real camp-scoped handler"
        )
        return
    }
    #expect(
        noteSearchText
            == "## R9-B handler fixture\nstable \(noteSearchToken) body"
    )

    for unavailableName in ["run_shell", "mcp__github__list_issues"] {
        let handler = try #require(handlerByLogicalName[unavailableName])
        guard case .error(let message) = await handler.execute(input: [:]) else {
            Issue.record("\(unavailableName) must be fixed unavailable in F1D")
            return
        }
        #expect(message == "engine_approval_required")
    }
    #expect(await mcpManager.status(serverId: githubServer.id) == .stopped)
    #expect(mcpTransports.values.isEmpty)
    let writeHandler = try #require(handlerByLogicalName["write_file"])
    guard case .result = await writeHandler.execute(input: [
        "path": "r9-b-standard.txt",
        "content": "standard-write",
    ]) else {
        Issue.record("standard autonomy must retain the real write handler")
        return
    }
    #expect(
        try String(
            contentsOf: capabilityFixture.workspaceURL.appendingPathComponent(
                "r9-b-standard.txt"
            ),
            encoding: .utf8
        ) == "standard-write"
    )

    // Mutation caught: treating `.free` as careful/unavailable, omitting its
    // workspace-write claim, or binding anything except the real write handler.
    let freeFixture = try P1F1DCanonicalExecutionFixture(
        toolsJson: ToolAccess.explicitJson(allow: ["write_file"]),
        autonomy: .free
    )
    let freePrepared = try await EngineContextTransportResolverV1(
        database: freeFixture.db,
        dependencyLoader: p1f1d080DependencyLoader(freeFixture.db)
    ).prepareCurrent(
        campId: freeFixture.camp.id,
        cardId: freeFixture.card.id,
        companionId: freeFixture.companion.id
    )
    #expect(freePrepared.capabilityTools.requiresWorkspaceWrite)
    let freeBound = try freePrepared.capabilityTools.makeCapabilityTools(
        freeFixture.workspaceURL
    )
    let freeWrite = try #require(
        freeBound.capabilityTools.first { $0.def.name == "write_file" }
    )
    guard case .result = await freeWrite.handler.execute(input: [
        "path": "r9-b-free.txt",
        "content": "free-write",
    ]) else {
        Issue.record("free autonomy must retain the real write handler")
        return
    }
    #expect(
        try String(
            contentsOf: freeFixture.workspaceURL.appendingPathComponent(
                "r9-b-free.txt"
            ),
            encoding: .utf8
        ) == "free-write"
    )

    // Mutation caught: safety decisions consulting provider-visible names or
    // any prompt callsite leaking a bare logical name in the CLI variant.
    let richCliText = try p1f1d080RenderedText(
        capabilityPrepared.cli.resolved.packet
    )
    for logicalName in [
        "complete_card",
        "block_card",
        "add_progress_note",
        "web_fetch",
        "write_file",
    ] {
        let providerName = "mcp__ranchboard__\(logicalName)"
        #expect(richCliText.contains(providerName))
        #expect(
            !richCliText.replacingOccurrences(
                of: providerName,
                with: ""
            ).contains(logicalName)
        )
    }

    let carefulFixture = try P1F1DCanonicalExecutionFixture(
        toolsJson: ToolAccess.explicitJson(allow: ["write_file"]),
        autonomy: .careful
    )
    let carefulPrepared = try await EngineContextTransportResolverV1(
        database: carefulFixture.db,
        dependencyLoader: p1f1d080DependencyLoader(carefulFixture.db)
    ).prepareCurrent(
        campId: carefulFixture.camp.id,
        cardId: carefulFixture.card.id,
        companionId: carefulFixture.companion.id
    )
    #expect(!carefulPrepared.capabilityTools.requiresWorkspaceWrite)
    let carefulBound = try carefulPrepared.capabilityTools
        .makeCapabilityTools(carefulFixture.workspaceURL)
    let carefulWrite = try #require(
        carefulBound.capabilityTools.first {
            $0.def.name == "write_file"
        }
    )
    guard case .error(let carefulMessage) = await carefulWrite.handler.execute(
        input: ["path": "forbidden.txt", "content": "must-not-write"]
    ) else {
        Issue.record("careful write_file must be fixed unavailable")
        return
    }
    #expect(carefulMessage == "engine_approval_required")
    #expect(
        !FileManager.default.fileExists(
            atPath: carefulFixture.workspaceURL.appendingPathComponent(
                "forbidden.txt"
            ).path
        )
    )

    // Mutation caught: collapsing duplicate allow entries into a Set or
    // accepting a logical name that collides with the Ranch MCP namespace.
    let duplicateFixture = try P1F1DCanonicalExecutionFixture(
        toolsJson: #"{"allow":["read_file","read_file"],"v":2}"#
    )
    let duplicateResolver = EngineContextTransportResolverV1(
        database: duplicateFixture.db,
        dependencyLoader: p1f1d080DependencyLoader(duplicateFixture.db)
    )
    await #expect(throws: EngineContextValidationErrorV1.self) {
        _ = try await duplicateResolver.prepareCurrent(
            campId: duplicateFixture.camp.id,
            cardId: duplicateFixture.card.id,
            companionId: duplicateFixture.companion.id
        )
    }
    let prefixFixture = try P1F1DCanonicalExecutionFixture(
        toolsJson: #"{"allow":["mcp__ranchboard__evil"],"v":2}"#
    )
    let prefixResolver = EngineContextTransportResolverV1(
        database: prefixFixture.db,
        dependencyLoader: p1f1d080DependencyLoader(prefixFixture.db)
    )
    await #expect(throws: EngineContextValidationErrorV1.self) {
        _ = try await prefixResolver.prepareCurrent(
            campId: prefixFixture.camp.id,
            cardId: prefixFixture.card.id,
            companionId: prefixFixture.companion.id
        )
    }
}
