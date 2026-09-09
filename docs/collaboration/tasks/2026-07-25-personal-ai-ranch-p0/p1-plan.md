# P1 实施 Plan — 可靠性与新契约地基

> 状态：**R27 永久 REJECTED_CONTAMINATED — 唯一 full 651/652；Shell timeout 测量边界失败；无 later gates/END；R28 Measurement-Boundary Candidate Frozen；fresh driver/235-entry manifest/freeze present；Review28 pending；A2 blocked**
>
> 日期：2026-08-10
>
> 阶段规格：同目录 `p1-stage-spec.md`
>
> 上位权威：`docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md`
>
> 实施纪律：P0 完成门通过后才可执行；每个 P1 子阶段独立实现、验证、Review、验收。

## 1. 执行方式

P1 不作为一次巨型 Codex 改动执行。创建：

```text
docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/
├── stage-spec.md
├── plan.md
├── p1-a1a-durable-work-store/
├── p1-a1b-durable-planning/
├── p1-a2-durable-rumination/
├── p1-a3-candidate-transaction/
├── p1-a4-schedule-fire/
├── p1-b-observability/
├── p1-c-control-contracts/
├── p1-d-outcome-contracts/
├── p1-e-identity-memory/
├── p1-f1-engine-coordination/
└── p1-f2-camp-retirement-integration/
```

每个子目录必须包含：

- `plan.md`：从本文复制该 slice 的精确范围，不得自行扩大；
- `verify.log`：完整 `swift run RunTests`；
- `build.log`：完整 `swift build --product AgentLoopApp`；
- `impl-report.md`；
- `reviews/NN-*.md`；
- `acceptance.md`；
- 风险需要时的 `evidence/`。

执行顺序严格为
P1-A1a → A1b → A2 → A3 → A4 → B → C → D → E → F1 → F2。每个 slice：

1. 保存 branch / HEAD / worktree；
2. 先写失败测试，证明旧实现问题；
3. 实施最小根因修复；
4. 运行权威测试和 App build；
5. 独立 Review；
6. 修完全部 P0/P1 finding；
7. 验收门通过后才进入下一子阶段。

禁止一次 Codex invocation 跨两个 slice；A1a 与 A1b 也不能合并。不得 commit。

## 2. 全阶段模块边界（非授权清单）

只有对应 slice 的“精确允许文件”可以改；本节只说明总体边界，**不授权**目录、
通配描述或清单外文件。全阶段涉及的现有模块类别：

- `Package.swift`
- `Sources/AgentLoopCore/Database/`
- `Sources/AgentLoopCore/Kernel/`
- `Sources/AgentLoopCore/Ingestion/`
- `Sources/AgentLoopCore/Rumination/`
- `Sources/AgentLoopCore/Product/`
- `Sources/AgentLoopCore/Loop/`
- `Sources/AgentLoopCore/Mcp/`
- `Sources/AgentLoopCore/Knowledge/`
- `Sources/AgentLoopCore/Support/`
- `Sources/AgentLoopCore/Tools/`
- `Sources/AgentLoopApp/AppStore.swift`
- `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift`
- `Sources/AgentLoopApp/CodingRanchContracts.swift`
- `Sources/AgentLoopApp/MissionScheduler.swift`
- `Sources/AgentLoopApp/McpStore.swift`
- SwiftUI view 只能是各 slice 逐路径列出的文件
- `Sources/AgentLoopTestSuite/`
- `Sources/RunTests/main.swift` 仅当新增 test target 注册确有需要
- `AGENTS.md`、`CLAUDE.md`、`README.md`、master spec 和 P1 task docs，仅用于同步已完成事实

新模块：

- `Sources/AgentLoopCore/Work/`
- `Sources/AgentLoopCore/Domain/`
- `Sources/AgentLoopCore/Observability/`
- `Sources/AgentLoopApplication/`

禁止触及：

- RanchArt 图片资源；
- 打包、签名和 entitlement 脚本，除非本阶段实际发现与新事实冲突且先修订 plan；
- normal / preview 数据文件；
- P2+ UI、云端、牛哒或商业代码。

## 3. P1-A — Durable Work 与四个崩溃窗口

### 3.1 P1-A1a：Durable Work DDL + Store

这是第一个 Codex invocation。它只建立 ledger/store，不接 production planning。
A1a 完成后必须独立 Review/acceptance；未通过不得开始 A1b。

#### A1a 允许文件

- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Package.swift`（仅新增 test-only migration-matrix runner target）
- 新 `Sources/AgentLoopCore/JSON/CanonicalJSON.swift`
- 新 `Sources/AgentLoopCore/Work/DurableWork.swift`
- 新 `Sources/AgentLoopCore/Database/DurableWorkStore.swift`
- 新 `Sources/P1MigrationMatrixRunner/main.swift`
- 新 `scripts/verify-p1-migrations-sqlite-matrix.sh`
- `Sources/AgentLoopTestSuite/DatabaseTests.swift`
- 新 `Sources/AgentLoopTestSuite/CanonicalJSONTests.swift`
- 新 `Sources/AgentLoopTestSuite/DurableWorkTests.swift`

A1a task 目录固定为
`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a1a-durable-work-store/`，
其中职责和可写文件严格分离：

- planner 写并冻结 `plan.md`；implementer 只读；
- implementer 只写 `verify.log`、`build.log`、`impl-report.md`；
- 独立 reviewer 只写 `reviews/01-p1-a1a-review.md`；
- acceptance owner 只写 `acceptance.md`，且只能在 Review 无 P0/P1 后判定。

runner 只能执行同一真实 GRDB migrator并切换 SQLite 3.51/3.52 link lane；不得复制
最终 schema或成为产品 dependency。不得修改 Orchestrator、Planner、App、
Rumination、Schedule、Candidate 或其他 test。
implementer 不得代写 Review 或 acceptance，reviewer 也不得回写实现或验证日志。

#### A1a 数据与类型

1. `AppDatabase.migrator` 只追加 `v12-p1-durable-work`，逐字实现 stage spec
   §18.1 三表、索引及
   `durable_work_attempt_event_reject_update/reject_delete` introduction-time pair；
   合法 insert 成功，ordinary/no-op UPDATE 与 DELETE 从 A1a 起即 abort。A1a 不建
   `schedule_fire`。
2. `CanonicalJSON.swift` 逐字实现 stage spec §5.1 的
   `CanonicalJSONV1` public API、strict UTF-8 parser、decimal-token normalizer 与
   byte serializer。typed `Encodable` 和 raw JSON 必须汇入同一 parser/serializer；
   实现必须是 private byte-backed AST（UTF-8 key/string、raw number token、pair
   array）；禁止引用既有 `JSONValue`，禁止以 `JSONEncoder`/`JSONSerialization`
   bytes直接 hash或用 raw `JSONDecoder` 代替 scanner，禁止新增第三方
   dependency。object-root/usage scalar只经同 AST internal extractor。A1a 建立后，
   所有后续 P1 slice 的 command/event/receipt/contract/
   Grant/work/engine request 与 terminal proposal hash 都只能复用此 API；prompt-only
   wire encoder 继续保留 `.sortedKeys`，但不是 hash source。
3. `DurableWork.swift` 定义：
   - `DurableWorkKind`，含
     planning/rumination/coach/guideChat/memoryPromotion/inputParsing/campDeletion；
   - `DurableWorkState`；
   - `DurableWorkRecord`；
   - mutable lifecycle `DurableWorkAttemptRecord`；
   - immutable `DurableWorkAttemptEventRecord/EventKind`；
   - `DurableWorkClaim(workId,attempt,workerId,version,leaseExpiresAt)`；
   - stage spec §6.2.2 的完整 `DurableWorkFailureDisposition`、
     `InvalidDurableWorkFailureError` 与 `DurableWorkFailure`；
   - `DurableWorkReplayConflictError`、`StaleDurableWorkClaimError`、
     `AttemptAlreadyClosedError`、`DurableWorkNotFoundError`、
     `DurableWorkInvalidCanonicalJSONError`、
     `InvalidDurableWorkOutputJSONError.invalidJSON|rootMustBeObject|notCanonical`、
     `DurableWorkInputHashMismatchError`、`InvalidDurableWorkStateError`、
     `BackoffOverflowError`；
   - `InvalidDurableWorkTimeError.nonFiniteNow|nonFiniteLeaseDuration|
     nonPositiveLeaseDuration|nonFiniteLeaseExpiration|
     nonAdvancingLeaseExpiration`；
   - `InvalidDurableWorkCancellationReasonError.empty|tooLong|
     containsControlScalar`、`CampDeletionRequiresRetirementCapabilityError`。
4. `DurableWorkStore` 是持有 `AppDatabase` 的 immutable `Sendable struct`，不另存
   connection：

```text
public enum DurableWorkFailureDisposition:
    String, Codable, Sendable, Equatable
{
    case transient
    case deterministic
}

public enum InvalidDurableWorkFailureError: Error, Sendable, Equatable {
    case invalidCode
    case emptyMessage
    case messageTooLong
    case messageContainsControlScalar
    case invalidUsageJson
}

public struct DurableWorkFailure: Codable, Sendable, Equatable {
    public let code: String
    public let message: String?
    public let disposition: DurableWorkFailureDisposition
    public let usageJson: String?

    public init(
        code: String,
        message: String?,
        disposition: DurableWorkFailureDisposition,
        usageJson: String?
    ) throws

    public init(from decoder: any Decoder) throws
    public func encode(to encoder: any Encoder) throws
}

public typealias DurableWorkBusinessMutation =
    (_ db: GRDB.Database, _ resultingWork: DurableWorkRecord) throws -> Void

public enum DurableWorkEnqueueDisposition: Sendable, Equatable {
    case inserted
    case replayed
}
public struct DurableWorkEnqueueResult: Sendable, Equatable {
    public let work: DurableWorkRecord
    public let disposition: DurableWorkEnqueueDisposition
}
public enum DurableWorkFailureResolution: Sendable, Equatable {
    case retryScheduled(work: DurableWorkRecord, notBefore: Date)
    case failed(work: DurableWorkRecord)
}
public enum DurableWorkCancelResult: Sendable, Equatable {
    case canceled(work: DurableWorkRecord)
    case alreadyCanceled(work: DurableWorkRecord)
}
public enum DurableWorkCancelActiveResult: Sendable, Equatable {
    case canceled(work: DurableWorkRecord)
    case noActiveWork
}

public struct DurableWorkStore: Sendable {
    public init(database: AppDatabase)

    public func enqueue(
        campId: String, kind: DurableWorkKind,
        aggregateType: String, aggregateId: String,
        inputJson: String, claimedInputHash: String,
        idempotencyKey: String, maxAttempts: Int, traceId: String, now: Date
    ) throws -> DurableWorkEnqueueResult

    public func claimNext(
        kinds: [DurableWorkKind], workerId: String, now: Date,
        leaseDuration: TimeInterval
    ) throws -> DurableWorkClaim?

    public func renewLease(
        claim: DurableWorkClaim, now: Date, leaseDuration: TimeInterval
    ) throws -> DurableWorkClaim

    public func complete(
        claim: DurableWorkClaim, outputJson: String?, now: Date,
        businessMutation: DurableWorkBusinessMutation
    ) throws -> DurableWorkRecord

    public func retryOrFail(
        claim: DurableWorkClaim, failure: DurableWorkFailure, now: Date,
        terminalBusinessMutation: DurableWorkBusinessMutation
    ) throws -> DurableWorkFailureResolution

    public func cancel(
        workId: String, expectedVersion: Int, reason: String, now: Date,
        businessMutation: DurableWorkBusinessMutation
    ) throws -> DurableWorkCancelResult

    public func cancelActive(
        kind: DurableWorkKind, aggregateType: String, aggregateId: String,
        reason: String, now: Date,
        businessMutation: DurableWorkBusinessMutation
    ) throws -> DurableWorkCancelActiveResult

    public func adoptInterrupted(
        kinds: [DurableWorkKind], currentWorkerId: String, now: Date
    ) throws -> [DurableWorkRecord]

    public func activeWork(
        kind: DurableWorkKind, aggregateType: String, aggregateId: String
    ) throws -> DurableWorkRecord?

    public func latestWork(
        kind: DurableWorkKind, aggregateType: String, aggregateId: String
    ) throws -> DurableWorkRecord?

    public func nextClaimableDate(
        kinds: [DurableWorkKind], now: Date
    ) throws -> Date?
}
```

   所有 public 方法都是同步 `throws`；每次 read 只开一个 `pool.read`，每次 write
   只开一个 `pool.write`。闭包 non-escaping，只能在该 write transaction 内同步
   执行，不能保存 `Database`、启动 Task 或跨 `await`。每个 public write 都有
   同名 internal static transaction helper，参数相同并追加
   `in db: GRDB.Database`，返回和错误完全相同；后续 projection-atomic command
   只能在外层 `pool.write` 调用 helper，禁止嵌套 `pool.write`。A1a 本身不得把
   helper 标成 public。
5. `DurableWorkFailure` 的 public initializer 与 custom decoder 都逐项执行 stage
   spec §6.2.2 的同一 validation：code regex；optional message 的非空、1000 scalar
   和 control-scalar guard；optional usageJson 的 §5.1 canonical byte equality、
   exact 三个 token keys 与 `0...Int64.max`；usage必须由 CanonicalJSON private
   AST extractor读取，不得 raw JSONDecoder。decode 失败必须是
   `DecodingError.dataCorrupted`，不得 synthesized decode 绕过；Codable shape
   固定四个 key，nil 写 explicit null，missing/extra key 均拒绝。`retryOrFail` 只
   根据 `.transient|.deterministic` 决定 retry/terminal；
   code/message/usageJson 不参与重新分类。
6. generic `enqueue` 首先在 SQL 前拒绝 `kind=.campDeletion`；然后把 `inputJson`
   转为 UTF-8 Data，要求 root 为 object，
   只调用 `CanonicalJSONV1.canonicalize` 并与原 Data 逐字比较。`campId` 必须是
   稳定 scope；A1a 同 transaction 在 replay lookup/任何 write 前验证 Camp：
   missing=`RecordNotFoundError(table:"camp",id:)`，legacy archived=
   `CampArchivedError`，archive后同-key replay也拒绝；E/F2 再把同一 seam 升级为
   `CampLifecycleStore.requireActiveCampWrite`；调用者字节不等于
   §5.1 唯一 canonical bytes 即
   `DurableWorkInvalidCanonicalJSONError`。Store 对 canonical bytes 自算 SHA-256
   lowercase hex；`claimedInputHash` 必须逐字匹配 `[0-9a-f]{64}` 且等于重算值，
   否则 `DurableWorkInputHashMismatchError`，零 DB 写。DB 只保存 canonical JSON
   与重算 hash；绝不信任 caller hash，也不得另走 JSONSerialization。
7. generic `enqueue/claimNext/nextClaimableDate/cancelActive/adoptInterrupted`
   对 `.campDeletion` 在 SQL 前抛 capability error；claim-scoped/cancel API在
   transaction读到该 kind后、任何 UPDATE/closure前抛同一错误。generic cancel
   永远不取消 deletion；A1a只允许 `activeWork/latestWork`观察保留 kind。F2 才新增
   opaque permit驱动的 specialized helper。
8. `claimNext` 直接 claim queued 或 due retryScheduled；claim/attempt row/claimed
   event 同事务。renew/complete/retryOrFail 使用最新
   id+attempt+version+leaseOwner；cancel 只用 work ID+expectedVersion，
   queued/retryScheduled 不要求 owner；adopt 选择 other-owner running，不要求 lease
   expiry 或旧 owner 参数。
9. 所有接受 `now` 的方法在 pool 前拒绝 non-finite now；claim/renew 还拒绝
   non-finite/non-positive duration、non-finite或不严格推进的 expiration。
   `nextClaimableDate` 与 claim 复用 exact predicate：empty kinds 合法时 nil，
   queued/due（含 equality）返回 caller now，无立即项返回最早 future retry，
   忽略 running/terminal/archived Camp。参数错误先于 empty快路且零 read/write。
10. success/terminal failure/running cancel/adopt 各关闭 attempt 一次并追加唯一
   terminal event。retry failure 关闭当前 attempt 为 failed，work 进入
   retryScheduled；下次 claim 使用 attempt+1。业务 closure 抛错时所有 ledger 写
   回滚。`terminalBusinessMutation` 只在确定性/耗尽后的 `.failed` 分支调用，进入
   `.retryScheduled` 时不调用。
   `complete.outputJson == nil` 合法；非 nil 时必须在进入 `pool.write` 前由
   `CanonicalJSONV1` 验证为 canonical object-root UTF-8。invalid JSON、非 object、
   alternate representation 分别抛上述三个 typed case，零 DB 写且不得调用
   `businessMutation`；成功只保存已验证的原字节。
11. retry policy 由 Store 唯一决定：transient 的第 1/2/3 次失败分别以
   `now + 5s/30s/120s` 进入 retryScheduled；第 4 次或任何
   `attempt >= maxAttempts` 直接 failed。deterministic 从第一次起直接 failed。
   日期计算先校验 `now.timeIntervalSinceReferenceDate.isFinite`，加法后再校验
   finite 且不倒退；任何不可表示值抛 `BackoffOverflowError` 并整笔回滚，不能
   trap、饱和或写入无穷日期。
12. work/attempt/event诊断逐字实现 stage spec §6.2.1矩阵和 §18.1 CHECK：
    claim清 retry/interrupted；failure三层复制；queued/retry cancel只改 work；
    running cancel三层 `work_canceled+reason`；adopt三层
    `worker_interrupted+nil`；success只有work optional canonical output且全层无
    error。cancel reason先经1…1000 scalar/no C0/C1 validation，绝不trim/截断。
13. replay 只按 `(kind,idempotencyKey)` 定位，再严格比较 camp ID、aggregate type/ID、
   canonical `inputJson`、重算 `inputHash` 与 maxAttempts；异内容 conflict。
   partial unique 保证一个 aggregate/kind 仅一个 active work。
14. `cancelActive` 在一个 `pool.write` 内通过 partial-unique active predicate 查询
   唯一 active row 与当时 version，并立刻调用同一 `Database` 上的 shared cancel
   helper 做 version-CAS、attempt close、event 和 business mutation。不存在 active
   row 是成功 `.noActiveWork`，不调用 mutation；重复调用仍为 `.noActiveWork`。
   SQLite serialized writer 下 terminal 与 cancel 谁先 commit 谁胜：后提交方重读
   后看到 no active；绝不能先 read、出 transaction，再按旧 version cancel。
   `cancel(workId:...)` 对已经 canceled 且 reason 相同返回 `.alreadyCanceled`；
   其他 terminal state 抛 `InvalidDurableWorkStateError`。

#### A1a 测试与门

- `durableWorkMigrationMatrixThroughV12`：fresh、v7、v8、v9、v10、v11；
- `durableWorkMigrationHasExactTablesIndexesChecksAndTriggers`；
- `durableWorkAttemptEventIsAppendOnlyFromIntroducingMigration`：合法 insert 后
  ordinary/no-op UPDATE 与 DELETE 分别 abort，失败 migration rollback 保留 guard；
- `canonicalTypedAndRawPathsProduceIdenticalBytes`：同一 typed DTO 与 raw tree
  （slash、`é中` value、Int、Double、negative zero）逐字相同；
- `canonicalSlashAndUnicodeGoldenBytes`：逐字断言 stage spec §5.1 的 slash、
  Unicode escape 与 raw composed/decomposed UTF-8 key-order vectors；
- `canonicalNumberGoldenBytes`：输入
  `{"i":42,"f":1.2300,"e":1e+3,"m":1e-3,"z":-0.0}`，逐字输出
  `{"e":1000,"f":1.23,"i":42,"m":0.001,"z":0}`；
- `canonicalRejectsDuplicateDecodedKeysAndInvalidUnicode`；
- `canonicalPreservesIntegerBeyondTwoToThe53`；
- `canonicalKeepsCanonicallyEquivalentButByteDistinctKeys`；
- `canonicalObjectRootInspectionDoesNotUseJSONValueOrRawJSONDecoder`；
- `canonicalRejectsInvalidOrOutOfBoundsNumbers`：覆盖 leading `+`/zero、缺数字、
  NaN/Infinity、超过 128 digit/token、exponent 越界和超过 512-byte output；
- `canonicalTypedNonConformingFloatThrows`；
- `validateCanonicalRejectsAlternateRepresentations`：空白、escaped slash、Unicode
  escape、float trailing zero、exponent、negative zero 虽可 canonicalize，也不能
  被当成已 canonical bytes；
- `sameIdempotencyAndPayloadReplaysButDifferentPayloadConflicts`；
- `enqueueMissingCampThrowsRecordNotFoundAndWritesNothing`；
- `enqueueArchivedCampThrowsCampArchivedAndWritesNothing`；
- `enqueueReplayAfterArchiveIsRejected`；
- `genericEnqueueClaimScheduleAndAdoptRejectCampDeletionBeforeSQL`；
- `genericClaimScopedAndCancelCommandsRejectExistingCampDeletionBeforeMutation`；
- `enqueueRejectsUppercaseOrNonHexClaimedInputHash`；
- `enqueueRejectsNonCanonicalJSONBeforeDatabaseWrite`；
- `sameClaimedHashWithDifferentPayloadIsRecomputedAndRejected`；
- `completeAcceptsNilOrCanonicalObjectOutput`；
- `completeRejectsInvalidNonObjectOrAlternateOutputBeforeWrite`；
- `invalidCompleteOutputSkipsBusinessMutationAndLeavesAttemptRunning`；
- `completeBusinessMutationFailureRollsBackValidatedOutputAndTerminalRows`；
- `failureDispositionRawValuesAndCodableRoundTripAreStable`；
- `failureInitializerAcceptsNilOrExactCanonicalUsage`；
- `failureInitializerRejectsInvalidCodeMessageAndUsageSchema`；
- `failureDecoderRevalidatesAndCannotBypassInitializer`：覆盖 explicit null、
  missing key、extra key；
- `retryOrFailUsesDispositionOnlyEvenWhenCodeIsIdentical`；
- `oneAggregateKindHasOneActiveWorkButKeepsTerminalHistory`；
- `claimQueuedAndDueRetryAreSingleOwner`；
- `queuedAndRetryCancellationDoNotRequireLeaseOwner`；
- `runningCancellationCommitsProjectionAndAttemptAtomically`；
- `cancelActiveNoRowIsIdempotentAndSkipsMutation`；
- `concurrentTerminalAndCancelHaveExactlyOneWinner`；
- `adoptionClosesExactlyOneInterruptedAttemptWithoutLeaseExpiry`；
- `leaseRenewalReturnsNewVersionAndOldClaimCannotComplete`；
- `nextClaimableDateEmptyKindsReturnsNil`；
- `nextClaimableDateRejectsNonFiniteNowBeforeRead`；
- `nextClaimableDateReturnsNowForQueued`；
- `nextClaimableDateReturnsNowForDueRetryIncludingEquality`；
- `nextClaimableDateReturnsEarliestFutureRetry`；
- `nextClaimableDateIgnoresRunningTerminalAndArchivedCampRows`；
- `claimNextUsesExactlyTheSameEligibilityPredicate`；
- `claimAndRenewRejectNaNInfinityZeroAndNegativeLeaseBeforeWrite`；
- `claimAndRenewRejectNonFiniteOrNonAdvancingExpirationBeforeWrite`；
- `invalidLeaseLeavesVersionLeaseAttemptsAndEventsUnchanged`；
- `oneTerminalAttemptOutcomePerClaim`；
- `businessMutationFailureRollsBackTerminalAndAttemptClose`；
- `transientRetryUsesFiveThirtyOneTwentySecondBackoff`；
- `deterministicFailureIsImmediatelyTerminal`；
- `retryExhaustionStopsAtMaxAttempts`；
- `retryDateOverflowThrowsAndRollsBack`；
- `claimClearsRetryAndInterruptedDiagnostics`；
- `retryFailureCopiesDiagnosticsToWorkAttemptAndEvent`；
- `terminalFailureCopiesDiagnosticsToWorkAttemptAndEvent`；
- `queuedAndRetryCancelWriteOnlyWorkCancellationDiagnostics`；
- `runningCancelCopiesCancellationDiagnosticsAtomically`；
- `adoptionCopiesInterruptedDiagnosticsAndNextClaimClearsWorkError`；
- `successStoresOnlyOptionalCanonicalOutputAndNoErrors`；
- `invalidOutputBackoffOverflowAndClosureFailureLeaveAllThreeLayersUnchanged`；
- `ddlRejectsOutputOutsideSucceeded`；
- `ddlRejectsEveryInvalidWorkAttemptEventErrorStatePair`；
- `ddlRequiresClaimedSequenceZeroAndExactEventResultingState`；
- `invalidCancellationReasonIsPreSQLAndSkipsBusinessMutation`；
- `attemptEventsRejectUpdateAndDelete`；
- `nextClaimableDateSelectsEarliestRetry`。

R9 把现有 `ddlRejectsEveryInvalidWorkAttemptEventErrorStatePair` 与 A1a migration
runner 固定为以下最小 mechanism sentinel、合法 branch control 与完整 normalized
diagnostics truth-table gate；7 个 sentinel 不代表全部非法 normalized rows，
不得只保留最先暴露的单一 open-attempt 反例：

- 7 个必须拒绝的 `NULL/UNKNOWN` 组合：
  1. canceled work：`errorCode=NULL`、reason non-null；
  2. open attempt：non-null `errorCode`、`errorMessage=NULL`；
  3. open attempt：`errorCode=NULL`、non-null `errorMessage`；
  4. canceled attempt：`errorCode=NULL`、reason non-null；
  5. interrupted attempt：`errorCode=NULL`、`errorMessage=NULL`；
  6. canceled event：`errorCode=NULL`、reason non-null；
  7. interrupted event：`errorCode=NULL`、`errorMessage=NULL`。
- v12 的 19 个必须继续成功的合法 branch control：
  - work 7 个：queued clear、queued `worker_interrupted`、running、
    retryScheduled、succeeded、failed、canceled；
  - attempt 5 个：open、succeeded、failed、canceled、interrupted；
  - event 7 个：claimed/running、leaseRenewed/running、succeeded/succeeded、
    failed/retryScheduled、failed/failed、canceled/canceled、
    interrupted/queued。

normalized truth table 固定使用 syntactically valid 的其他字段基线与以下有限域：

- work 56：
  `(state, outputPresence)` 7 值
  `{queued/null, running/null, retryScheduled/null, succeeded/null,
  succeeded/present('{}'), failed/null, canceled/null}`
  × `errorCode` 4 值
  `{NULL, worker_interrupted, work_canceled, other_error}`
  × `errorMessage` 2 值 `{NULL, present('safe message')}`；
- attempt 40：
  lifecycle 5 值
  `{open=(endedAt/outcome/terminalWorkVersion 全 NULL),
  succeeded, failed, canceled, interrupted}`；四个 closed 值各自使用
  non-null `endedAt`、同名 `outcome`、`terminalWorkVersion=1`，再乘同一
  code 4 × message 2；
- v12 event 288：
  kind 6
  `{claimed, leaseRenewed, succeeded, failed, canceled, interrupted}`
  × resulting state 6
  `{running, retryScheduled, succeeded, failed, canceled, queued}`
  × code 4 × message 2；claimed 使用 sequence 0，其余使用 sequence 1；
- v16 event 384：
  kind 8（在 v12 六类上增加 `providerDispatchStarted` 与
  `providerResponseReturned`）× state 6 × code 4 × message 2；两类 provider
  event 使用合法 non-null `providerDispatchId`，其余为 NULL，`redactedAt=NULL`。

精确 verdict counts 是：v12 work `56=18 legal/38 illegal`（修订前 1 个
UNKNOWN）、attempt `40=10/30`（9 个 UNKNOWN）、event `288=17/271`
（2 个 UNKNOWN），共 12 个 UNKNOWN；v16 event `384=19/365`
（2 个 UNKNOWN）。v12 合法 branch control总数是 19；v16 增加两类 provider
event 后是 21。每个非法 normalized row 都必须以 constraint failure拒绝，每个
合法 row 都必须成功，wrapper 后 matrix求值只能为 `0|1`、不得为 `NULL`。

A1a 必须在 §18.1 introducing checkpoint 让 7 sentinel、19 legal controls 与
v12 三表完整 normalized truth table全部通过 SQLite 3.51/3.52 的 literal 与同一
真实 GRDB migrator lane；任一计数漂移都阻止 A1a acceptance。P1-E 才负责在
§18.6 v16 rebuild 后复用同一 gate，并加入 v16 的21个 legal controls与384-row
event truth table；A1a 不提前实现或执行 v16。

A1a 只在 `swift run RunTests`、App build、migration checks 和独立 Review 全通过后
Accepted；此时 R-01 尚未关闭，不能宣称 planning 已修复。

### 3.2 P1-A1b：Durable Planning Supervisor + Integration

这是第二个 Codex invocation。入口是 A1a Accepted。A1b 不修改 Rumination、
Candidate transaction 或 Schedule claim/missed 产品语义。R11-1 的唯一
ScheduleStore 改动是修正 `ScheduleRecord.lastFiredAt` 的持久编码；另在既有
Orchestrator allowlist内增加 Coordinator non-finite pre-guard。二者都不能改变
value、valid finite slot、claim CAS、missed 或 schema。

#### A1b 精确允许文件

生产文件：

- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopCore/Database/EventKind.swift`
- `Sources/AgentLoopCore/Database/ScheduleStore.swift`
- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
- `Sources/AgentLoopCore/Kernel/Planner.swift`
- `Sources/AgentLoopCore/Provider/LLMProvider.swift`
- `Sources/AgentLoopCore/Work/DurableWork.swift`
- `Sources/AgentLoopCore/Database/DurableWorkStore.swift`
- 新 `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift`
- 新 `Sources/AgentLoopCore/Work/PlanningProviderResolver.swift`
- `Sources/AgentLoopApp/AppStore.swift`
- `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift`
- `Sources/AgentLoopApp/MissionScheduler.swift`

`createMissionShell`、`planMission`、`startMission` 或 Orchestrator initializer
签名受影响的测试调用点穷举如下，全部允许修改：

- `Sources/AgentLoopTestSuite/AskUserTests.swift`
- `Sources/AgentLoopTestSuite/BudgetTests.swift`
- `Sources/AgentLoopTestSuite/CrashRecoveryTests.swift`
- `Sources/AgentLoopTestSuite/DatabaseTests.swift`
- `Sources/AgentLoopTestSuite/GoldenPathTests.swift`
- `Sources/AgentLoopTestSuite/GuideChatTests.swift`
- `Sources/AgentLoopTestSuite/HaltAndCooldownTests.swift`
- `Sources/AgentLoopTestSuite/HarvestTests.swift`
- `Sources/AgentLoopTestSuite/KnowledgeGoldenPathTests.swift`
- `Sources/AgentLoopTestSuite/McpTests.swift`
- `Sources/AgentLoopTestSuite/MultiCampTests.swift`
- `Sources/AgentLoopTestSuite/OrchestratorTests.swift`
- `Sources/AgentLoopTestSuite/PlannerTests.swift`
- `Sources/AgentLoopTestSuite/PlanningTokensTests.swift`
- `Sources/AgentLoopTestSuite/RuntimeProfileTests.swift`
- `Sources/AgentLoopTestSuite/ScheduleTests.swift`
- `Sources/AgentLoopTestSuite/DurableWorkTests.swift`
- 新 `Sources/AgentLoopTestSuite/DurablePlanningTests.swift`
- 新 `Sources/AgentLoopTestSuite/PlanningTestFixtures.swift`

A1b test-only migration gate 另外只允许修改：

- `Sources/P1MigrationMatrixRunner/main.swift`
- `scripts/verify-p1-migrations-sqlite-matrix.sh`

这两个路径只能追加具名 `v12-durable` predecessor/replay fixture及其 SQLite
3.51/3.52 linked-lane assertions；不得修改 v12 DDL/literal、A1a 既有 fixture
verdict、产品 target、`Package.swift` 或 `Package.resolved`。

该清单来自本轮 `rg` 的全部现有调用点；不得靠默认参数或读取 current default 的
compatibility overload 避免迁移。若实施时编译器发现清单外的同签名调用点，停止
并修订 plan，不得擅自扩大。

#### A1b Planning API

1. `PlanningWorkInput` 是 immutable `Codable & Sendable & Equatable`，精确为
   `(plannerModel:String,runtimeProfileId:String,promptContractVersion:Int=1)`；
   只用 `CanonicalJSONV1.encode` 产生 inputJson/hash并随 work 持久化，不得增加
   第四字段。唯一 carve-out 是永不claim、attempt=0即terminal的
   `LegacyPlanningTerminalInputV1(contractVersion=1,terminalCode)`；allowed code
   只按Stage §6.3四值，不能进入resolver/Planner。
2. 新 `MissionPlanningStartIdentityV1` 同样 immutable，精确含
   `contractVersion=1`、goal、ordered companion IDs、workspace path、按现行规则
   规范化并实际持久化的 budget、resolved non-null Camp ID、autonomy与完整
   `PlanningWorkInput`。它只用 `CanonicalJSONV1` 编码，并直接成为唯一
   `mission_created.payloadJson`；trace 不进 identity/hash。
3. `Orchestrator.startMission` 的 required 参数固定为：

   ```swift
   startMission(
       goal: String,
       companionIds: [String],
       workspacePath: String?,
       plannerModel: String,
       runtimeProfileId: String,
       budgetTokens: Int,
       campId: String?,
       autonomy: MissionAutonomy,
       idempotencyKey: String,
       traceId: String
   ) async throws -> String
   ```

   四个入口不得使用 default 参数或 Core 内 current-default lookup：

   - AppStore manual：
     `mission-start:user:<UUID>:v1`，创建 Task 前同一 MainActor turn捕获
     command/trace UUID、profile/model/budget/autonomy；
   - Coding Ranch candidate：
     `mission-start:candidate:<draftId>:v1`，第一次 await前捕获；
   - schedule：
     `mission-start:schedule:<scheduleId>:<checked-UTC-milliseconds>:v1`；
     `scheduledFireDate.timeIntervalSince1970.isFinite` 是最先执行的 pre-guard，
     早于 UUID、runtime selection、preparation `Result` 与
     `claimScheduleFire`；non-finite 直接抛既有 package
     `InvalidSchedulePlanningFireTimeError` 且零写。只有 finite Date 才把 checked
     milliseconds/profile/model selection 捕获为同一个 Result，随后仍执行既有
     `claimScheduleFire`；finite 但 milliseconds 超出 `Int64` 或 selection
     failure 都在 claim winner 后走当前 exactly-once missed path，A1b 不改变
     valid slot 或 claim CAS；
   - confirmed proposal：
     `mission-start:proposal:<proposalId>:v1`，proposal block提供稳定 key。

   每次入口一次生成 trace；deterministic-key 重放不得覆盖首次 work trace。
4. 四入口的可执行 owner 是
   `Sources/AgentLoopCore/Kernel/Orchestrator.swift` 内的 package-only Core
   coordinator；不增加文件、target 或 public Core surface：

   ```swift
   package struct PlanningEntryRuntimeSelection: Sendable, Equatable {
       let runtimeProfileId: String
       let plannerModel: String
   }

   package struct PlanningMissionStartArguments: Sendable, Equatable {
       let goal: String
       let companionIds: [String]
       let workspacePath: String?
       let budgetTokens: Int
       let campId: String?
       let autonomy: MissionAutonomy
   }

   package struct ManualMissionStartSnapshot: Sendable, Equatable {
       let mission: PlanningMissionStartArguments
       let runtime: PlanningEntryRuntimeSelection
   }

   package struct PendingManualMissionStart: Sendable, Equatable {
       let snapshot: ManualMissionStartSnapshot
       let idempotencyKey: String
       let traceId: String
   }

   package struct CapturedCandidateMissionStart: Sendable, Equatable {
       let draftId: String
       let runtime: PlanningEntryRuntimeSelection
       let idempotencyKey: String
       let traceId: String
   }

   package struct CapturedProposalMissionStart: Sendable, Equatable {
       let messageId: String
       let proposalId: String
       let runtime: PlanningEntryRuntimeSelection
       let fallbackBudget: Int
       let autonomy: MissionAutonomy
       let idempotencyKey: String
       let traceId: String
   }

   package enum SchedulePlanningEntryOutcome: Sendable, Equatable {
       case notClaimed
       case started(missionId: String)
       case missed(reason: String)
   }

   @MainActor
   package final class PlanningEntryCoordinator {
       package init(
           db: AppDatabase,
           orchestrator: Orchestrator,
           makeUUIDString: @escaping @MainActor () -> String = {
               UUID().uuidString
           }
       )

       package func prepareManual(
           snapshot: ManualMissionStartSnapshot,
           pending: PendingManualMissionStart?,
           forceNewCommand: Bool
       ) -> PendingManualMissionStart

       package func startManual(
           _ command: PendingManualMissionStart
       ) async throws -> String

       package func clearManualAfterSuccess(
           current: PendingManualMissionStart?,
           completed: PendingManualMissionStart
       ) -> PendingManualMissionStart?

       package func captureCandidate(
           draftId: String,
           runtime: PlanningEntryRuntimeSelection
       ) -> CapturedCandidateMissionStart

       package func startCandidate(
           _ captured: CapturedCandidateMissionStart,
           mission: PlanningMissionStartArguments
       ) async throws -> String

       package func captureConfirmedProposal(
           messageId: String,
           runtime: PlanningEntryRuntimeSelection,
           fallbackBudget: Int,
           autonomy: MissionAutonomy
       ) throws -> CapturedProposalMissionStart

       package func startConfirmedProposal(
           _ captured: CapturedProposalMissionStart
       ) async throws -> String

       package func fireSchedule(
           schedule: ScheduleRecord,
           template: MissionTemplateRecord,
           companionIds: [String],
           budgetTokens: Int,
           scheduledFireDate: Date,
           calendar: Calendar,
           timeZone: TimeZone,
           selectRuntime:
               @MainActor () throws -> PlanningEntryRuntimeSelection
       ) async throws -> SchedulePlanningEntryOutcome
   }
   ```

   上述 DTO 的每个存储属性实际访问级别均精确为 `package`，并显式提供逐字段
   `package init`；代码块省略重复 initializer body，不得依赖 module-internal
   synthesized memberwise initializer。

   `prepareManual` 先把 snapshot 的 budget按既有 `max(1, value)`规范化，再对相同
   canonical snapshot且 `forceNewCommand=false` 复用 pending；输入改变
   或 force-new 生成新 key/trace。失败不清 pending；成功只按完整 completed command
   compare-and-clear，旧 Task 的迟到成功不得清掉新 pending。candidate owner固定
   `existingMissionId → startMission → linkConverted` 两步；link失败后重试复用
   deterministic key，不提前实现 A3。proposal capture只做只读 block snapshot，
   CAS/attach/revert/heal仍由 Orchestrator，start时必须验证 captured proposal ID。
   schedule owner先以
   `scheduledFireDate.timeIntervalSince1970.isFinite` pre-guard拒绝 non-finite：
   guard 位于 UUID、`selectRuntime`、preparation `Result` 与 claim 之前，抛既有
   `InvalidSchedulePlanningFireTimeError`，runtime selection调用数为零，Mission、
   work、event与`lastFiredAt`全部零写。finite Date才在claim前形成
   checked-milliseconds与throwing runtime selection的同一个 Result，随后执行既有
   claim；claim winner遇 selection/finite-milliseconds conversion failure或start
   error都恰写一次 missed，保持 A4 schema/CAS不变。
   claim loser返回`.notClaimed`且不写missed；start成功返回`.started`；missed
   persistence成功后返回`.missed`。只有claim数据库错误导致winner未知，或
   `recordScheduleMissed`失败时才throws；claim winner后的start error不得逃逸，
   caller也不得补写第二条missed。App UI reload、toast、broadcast与navigation不
   进入 coordinator。

   R11-1 的唯一 Schedule Store 改动是
   `ScheduleRecord.databaseDateEncodingStrategy(for:)`：只对`lastFiredAt`使用
   GRDB `.timeIntervalSince1970` numeric/Double encoding；其他 Date继续
   `.deferredToDate`。date decoding必须保持`.deferredToDate`，同时读既有
   `yyyy-MM-dd HH:mm:ss.SSS` TEXT和新numeric epoch seconds，禁止改为
   `.timeIntervalSince1970` decoder。`DATETIME` NUMERIC affinity可把无小数Double
   保存为INTEGER，因此`lastFiredAt` storage class允许INTEGER或REAL，禁止TEXT/
   空串，不得断言固定`typeof=REAL`。`ScheduleStore`不做finite判断、不复制
   checked/claim/missed owner，也不改migration、schema、slot、claim CAS或missed
   event。

   AppStore manual/proposal在创建 Task前调用 coordinator；candidate在第一次 await
   前 capture，并把 existing/start/link全委托；MissionScheduler只调用
   `fireSchedule`，不再直接 claim或 start。`AgentLoopTestSuite` 直接功能测试同一个
   package实现，再由 source-range/order tests验证三个 App文件真实委托且无 direct
   start/claim旁路。`Package.swift`、`Package.resolved`、
   `Sources/RunTests/main.swift` 与 target graph保持逐字不变。
5. `PlanningProviderResolver: Sendable` protocol 固定
   `resolvePlanningProvider(profileId:model:) throws -> any LLMProvider`。App
   concrete resolver逐行实现 Stage §6.3 权威表：official API只用 raw
   `cachedCatalog + manualModels`，custom API只用 raw profile-scoped
   `modelChoices + manualModels`，OAuth只用 static catalog并要求 primary token与
   `oauth-chatgpt-account-id`，CLI固定拒绝。Keychain读取使用
   fail-if-interaction-required，严格区分 not-found/other OSStatus。AppDatabase
   不构造 resolver/provider/OAuth refresher，也不读取 current default。
6. `AppDatabase.createMissionShell` 不再 public；改为
   `insertMissionPlanningProjection(...,database:)` private transaction helper。
   唯一 public 新开工 API 是：

   ```swift
   enqueueMissionPlanning(
       goal: String,
       companionIds: [String],
       workspacePath: String?,
       budgetTokens: Int,
       campId: String?,
       autonomy: MissionAutonomy,
       planningInput: PlanningWorkInput,
       idempotencyKey: String,
       traceId: String,
       planningProviderResolver: any PlanningProviderResolver
   ) throws -> (missionId: String, workId: String)
   ```

   固定顺序为 process-local dispatch gate → replay-first identity/work-graph
   validator → only-if-absent完整 resolver preflight → enqueue transaction →
   supervisor kick。replay相同即使当前 profile/credential已失效也返回原 IDs且零
   provider construction；conflict优先抛。transaction在 UUID/insert前再次验证
   winner、profile kind与 durable dispatch running；nil Camp只在此 transaction
   按稳定顺序解析/必要时创建，default Camp/Guide与全部 planning projection一起
   回滚。
7. 独立 commit 的 `recordPlanningTokens`、`recordPlanFallback`、`planMission`
   从 public surface 移除；现有 tests全部迁移到 `PlanningTestFixtures` 或新
   durable commands，不保留绕过 work 的 overload。
8. 新 planning transaction commands 固定为：

   - `commitPlanningSuccess(claim:result:now:)`；
   - `recordPlanningAttemptFailure(claim:failure:now:)`；
   - `recordPlanningUsageOverflow(claim:evidence:now:)`；
   - `cancelPlanning(workId:expectedVersion:reason:now:)`；
   - `cancelAllPlanningForEmergencyHalt(reason:now:)`；
   - `adoptInterruptedPlanning(currentWorkerId:now:)`；
   - `repairLegacyPlanningMissions(profileModels:now:)`。

   除唯一 public enqueue command 与 Store `work(id:)` 外，这些 planning-specific
   command/type保持 Core internal。返回类型固定为：

   ```swift
   enum PlanningSuccessCommitResult: Sendable, Equatable {
       case succeeded(work: DurableWorkRecord)
       case usageOverflow(work: DurableWorkRecord)
   }

   enum PlanningFailureCommitResult: Sendable, Equatable {
       case retryScheduled(work: DurableWorkRecord, notBefore: Date)
       case failed(work: DurableWorkRecord)
       case usageOverflow(work: DurableWorkRecord)
   }

   enum PlanningTerminalProposal: Sendable, Equatable {
       case success(PlanResult)
       case failure(PlanningAttemptFailure)
       case usageOverflow(PlanningUsageOverflowEvidenceV1)
   }
   ```

   `recordPlanningUsageOverflow` 返回 terminal `DurableWorkRecord`；
   `cancelPlanning` 返回现有 `DurableWorkCancelResult`；bulk halt返回按 Mission ID
   排序的受影响 IDs；adoption返回 adopted work；legacy repair无返回值。internal
   DB seams固定为
   `claimNextPlanning(workerId:now:leaseDuration:) -> DurableWorkClaim?`、
   `renewPlanningLease(claim:now:leaseDuration:) -> DurableWorkClaim` 与
   `nextClaimablePlanningDate(now:) -> Date?`，都在同一 read/write transaction
   验证 durable running。

   normal provider-path command和 enqueue/claim/renew/next-due都在同一 DB
   transaction/read transaction要求 durable dispatch running；单 work cancel与
   halt bulk cancel是允许在 halted 下写 terminal projection的控制路径。success
   要求 fallback nil，nil不写 event，non-nil `unexpected_planning_fallback`
   command零写，并由failure owner以deterministic failure及同一个result Usage
   收口；恰好一条 typed canonical `planning_tokens` 与一条
   `plan_completed`。failure/retry/cancel/halt也按 Stage §6.3原子提交。Store只新增
   `work(id:)` public read seam；halt bulk cancel和overflow deterministic-fail
   primitive保持 internal。

   R11-4 只增加一个 matching-DEBUG package test seam：
   `injectOwnedSuccessProposalForTesting(workId:result:)`。定义与调用该 seam 的
   `@Test`/helper 都必须位于匹配的 `#if DEBUG`；它只接收 owned work ID 与
   `PlanResult`，不暴露任意 `PlanningTerminalProposal`、task token或generation。
   entry不存在或不owned时 typed fail-fast；存在时从既有owned entry读取token/
   generation，并复用生产 provider-completion → pending proposal →
   `attemptPendingTerminalProposal` 路径及 generation/token/latest-claim gates。
   它不得直接调用Store、绕过transaction或重呼provider。SwiftPM debug
   Core/TestSuite/RunTests保持同一package identity与现有target graph；release Core
   不得包含该符号。

   A1b 同时新增 public empty typed
   `PlanningRequiresDurablePlanningCapabilityError: Error & Sendable & Equatable`，
   并把 `.planning` 从九个 generic Store mutation/dispatch API封死：
   `enqueue`与`cancelActive`保持kind-first；`claimNext`先执行now/lease validation，
   `nextClaimableDate`与`adoptInterrupted`先执行now validation，随后在打开pool/SQL
   前整次拒绝（mixed kinds不得过滤）；
   同时含planning/campDeletion时按caller顺序首个reserved kind抛对应typed error，
   validation完成后才去重；
   `renewLease/complete/retryOrFail/cancel` 在 transaction读取 target后、任何
   idempotent/state/CAS/update/event/business closure前拒绝。public与同名 internal
   generic helper使用同一 ban；generic cancel对 terminal planning也抛该错误。
   `activeWork/latestWork/work(id:)`只读允许。所有 specialized transaction共用
   `DurableWorkStore.swift` 内唯一 fileprivate planning ledger owner；AppDatabase
   是唯一 specialized边界，Supervisor不得调用 generic mutation。A1a generic tests
   改用普通 kind；A1a acceptance与 v12 DDL/literal/verdict不改。
9. `PlanningAttemptFailure: Error & Sendable & Equatable` 只公开由
   `(code,safeMessage,disposition,usage:Usage?)` 构造的 validating initializer；它先
   验证 non-negative Usage，用 typed Codable产生 exact usageJson，再构造同源
   `DurableWorkFailure`。不得公开接受可彼此不一致的
   `(usage,DurableWorkFailure)` initializer，也不得从 usageJson反解析 scalar。
   nil表示零个可计量 turn；non-nil全零仍是显式可计量 turn。
10. `PlanningUsageCountersV1` 固定三个 non-negative Int64 counter；
   `PlanningUsageOverflowEvidenceV1` 使用 custom Codable产生 Stage §6.2.2
   `turn_aggregate|mission_projection` 两种 exact shape；
   `UsageOverflowError` 只携该 evidence。`recordPlanningUsageOverflow` 不构造
   `DurableWorkFailure`，写 canonical `planning_usage_overflow` 后以
   `usage_overflow` deterministic terminalize；不写 token event、不改已有
   `spentTokens`、不 retry/建卡/fallback。
11. `Planner.proposeDurable` 替代 `propose`：Planner层无 loop/sleep/transport
    retry、无 provider fallback；最多一个 schema correction turn。Concrete
    Provider在单次 `streamTurn` 内既有 adapter retry/refresh/fallback不扩大。
    runtime error严格按 Stage §6.3映射为稳定 code/disposition与静态安全 message。
    两轮 usage用 three-temporary checked add；overflow携 exact operands并立即走
    专用 terminal path。每轮Usage先验证non-negative：首轮negative用
    `planning_usage_invalid/deterministic`且nil usage；correction negative保留此前
    valid accumulated usage。
12. 所有 planning identity/token/overflow numeric payload使用 private typed
    Codable → `CanonicalJSONV1.encode` → direct Event insert，禁止
    `JSONValue.number(Double)`。`missionSpendBreakdown` 改为 typed Int/Int64 decode
    与 checked sum。normal usage超预算但未整数溢出时仍 exact入账并建卡，随后由
    现有预算门阻止 Card dispatch。

#### A1b Supervisor 与 startup

`DurableWorkSupervisor` 是 actor。公开 API 与结果固定为：

```swift
public struct ShutdownReport: Sendable, Equatable {
    public let uncooperativeWorkIds: [String]
}

public func recoverOnStartup(
    profileModels: [String: String]
) async throws

public func startIfNeeded() throws
public func kick() throws

public func cancelPlanning(
    missionId: String,
    reason: String
) throws

public func waitUntilIdle() async throws
public func waitUntilTerminal(workId: String) async throws

public func shutdown(
    gracePeriod: Duration = .seconds(2)
) async -> ShutdownReport
```

唯一额外 internal activation API 固定为 actor-isolated
`activateAfterOrchestratorRecovery()`；它不进入 public surface。R11-4 的
`injectOwnedSuccessProposalForTesting(workId:result:)` 也只在匹配的
`#if DEBUG package`中存在。

Supervisor lifecycle 精确为
`initialized -> recovering -> recoveryReady -> running -> shuttingDown -> shutDown`；
`.recoveryReady`与`dispatchSuppressed`都只存在于进程内，不新增持久状态。
`dispatchSuppressed`初始化为`true`：

- `recoverOnStartup` 只可从 `initialized` 进入 `recovering`。失败回到
  `initialized`、保持 suppressed；读取到durable running时只进入
  `.recoveryReady + suppressed`，成功只执行一次；
- `activateAfterOrchestratorRecovery()` 原子要求 lifecycle为`.recoveryReady`、
  仍suppressed、无fatal、无halt cleanup pending，并在方法内部重读durable mode
  仍为running；满足后才切`.running`、打开gate、创建唯一pump/timer并kick恰好一次；
- `startIfNeeded` 只在 `running` 且未 suppressed 时幂等保证唯一 pump；从
  `initialized|recovering` 抛 `SupervisorRecoveryRequiredError`，
  `.recoveryReady`或其他suppressed状态抛
  `SupervisorDispatchSuppressedError`，shutdown 后抛
  `SupervisorAlreadyShutDownError`，不得绕过 recovery 或 restored halt；
- `kick` 只在 `running` 且未 suppressed 时取消并重建唯一 next-due timer，并立即
  drain；未来更早 work 会重置 timer，禁止固定间隔 polling；
- `cancelPlanning` 先用允许在 halted 下执行的控制 transaction 原子关闭
  work/attempt/Mission/events，再只取消匹配该 work token 的本地 provider Task；
- `waitUntilIdle` 等 owned Tasks 为空且当前没有 queued/due work；未来
  retryScheduled 不阻塞。`waitUntilTerminal` 只以持久 work 终态返回；两者都用
  actor continuations/状态变化唤醒，不轮询；
- lifecycle/invariant、missing/corrupt kernel control，或 claim/next-due/renew
  的非 stale Store错误进入可观察 fatal latch；不得 `try?`。fatal latch 后不再
  claim/renew/dispatch，保留 ledger与in-memory ownership、取消本地 provider，
  waiters收到 typed error。

冷启动严格拆为 recovery 与 activation 两阶段。Supervisor recovery顺序固定为：
legacy repair → interrupted planning adoption → exact durable dispatch mode：

- `running`：只进入`.recoveryReady + dispatchSuppressed=true`，零
  pump/timer/claim/resolver/provider；
- `halted`：保持 suppressed，以一个整体 transaction
  `cancelAllPlanningForEmergencyHalt` 收口全部 active planning；成功后 lifecycle
  为 `running` 但 quiescent，零 pump/timer/claim/resolver/provider；
- missing/corrupt 或 cleanup 失败：fail closed，保持 suppressed，错误可观察并可
  重试。cleanup 未完成时不得 resume。

只有Supervisor读到running并进入`.recoveryReady`后，Orchestrator才执行Card orphan
adoption与proposal healing，随后在调用activation前后重验同一个transition token。
`activateAfterOrchestratorRecovery()`内部durable-mode read是最终DB fence；全部成功
才线性化activation。Card recovery失败时durable mode保持running，Supervisor从未
激活，planning ledger零新增终态写、零halt bulk cleanup、零
`camp_halted/camp_resumed`；已合法提交的legacy repair/adoption事实不回滚、不重复。
仍满足`.recoveryReady`与有效startup eligibility/transition token的mode-read或
内部gate failure保持错误可观察、`.recoveryReady + suppressed`且可显式重试；
lifecycle/generation/eligibility/token已被control改变的stale activation必须保留
control-owned state并失败，不得还原`.recoveryReady`或再走startup carve-out。

repair/adoption 是 local gate suppressed时允许的 recovery-only control mutation：
它们可以在mode read前创建repair work或把interrupted attempt排回queued，但不得
建pump/timer或调用provider。mode-aware repair先收口workless legacy Mission；若
最终mode为halted，随后同一bulk cleanup必须覆盖repair/adopt留下的其余active
rows，结束后不得残留active planning。这不开放halted下普通enqueue/claim/renew/
  terminal proposal。当前post-failure
  `suppressForOrchestratorRecoveryFailure()`不是最终合同，必须删除，不能用reactive
  re-suppress掩盖提前dispatch窗口。

Legacy repair每个Mission transaction先读durable mode：halted时以
`LegacyPlanningTerminalInputV1(terminalCode:
"emergency_halt_during_planning")`创建queued attempt=0 work，并在同一transaction
复用queued cancel primitive收口为canceled work + failed Mission + terminal
`mission_failed`，零attempt rows/events；这是halt control owner的一部分。
running时才按profile/model规则创建queued work或三种`legacy_planning_*`
terminal failed work。legacy trace固定
`legacy-planning:<missionId>:trace:v1`。该mode read是线性化点，已提交running
legacy terminal不能被后来的halt改写。

running legacy Mission只要已有任意Card，必须在该Mission transaction任何mutation
前抛package
`LegacyPlanningHasCardsError: Error & Sendable & Equatable`。该类型只有package
initializer与固定`code == "legacy_planning_has_cards"`，不增加public API、
missionId或其他payload；该分支Mission/Card/work/attempt/event完整快照零变化。

内部调度合同固定：

- actor 使用 checked 单调 `generation`；每个 pump、timer、renewal、provider Task
  捕获 generation 与 unique task token。generation overflow 是 fatal error，
  不 wrap；
- 一个 work 恰有一个 owned entry：task token、mission ID、latest claim、
  provider Task、唯一 renewal Task、terminal-commit permission 与可选 pending
  terminal proposal；
- kick先按work ID排序重试owned pending terminal proposals，再claim新work；每次
  成功renew后只重试该entry的同一proposal一次。pump每次claim一条，循环至无
  claimable；lease固定60秒，每15秒renew；renew成功原子替换latest claim，stale
  renew只取消匹配token的Task；
- provider invocation 在 child Task 内执行，但 claim/renew/terminal DB proposal
  都回到 actor。每次同步 store write 前无 `await` 地重验 lifecycle=`running`、
  未 suppressed、generation、task token、terminal permission；SQLite transaction
  还重验 durable dispatch=`running`。任一 gate loser 零写；
- provider 已返回不等于可提交。success/failure/overflow proposal 先保存在 owned
  entry，再尝试 transaction。DB/store failure不得移除 ownership；entry继续续租并
  等待明确 kick/recovery 重试。只有 durable terminal commit 或 durable control
  cancel 才移除 entry、结束对应 waiters；
- stale claim/version、generation/token loser或durable halted是预期control race，
  只取消matching task或等待halt owner，不触发global fatal。terminal transaction
  的可回滚数据库错误保留typed pending proposal；只在后续lease renew成功或显式
  kick后重试，不重呼provider。terminal invariant corruption、missing/corrupt
  control，或claim/next-due/renew非stale错误进入fatal latch；pending期间renew
  非stale失败也fatal；
- Task cancellation 本身不把 work当 succeeded/failed、不 release；进程重启由
  adoption 关闭 interrupted attempt；
- completion callback 只 emit Mission changed，不直接写 App projection。

halt/resume 合同固定：

- `suppressForEmergencyStop()` 是 Orchestrator 使用的 internal actor hook。它在
  Supervisor 的第一个 actor turn、任何内部 `await` 前设置 suppressed、checked
  推进 generation、停止 pump/timer/renewal、撤销 terminal permission并 cancel
  provider Tasks；它也必须接受`.recoveryReady`。从该状态进入时，它在同一
  actor turn把 lifecycle 消费为`.running`、保持suppressed并设置
  `haltCleanupPending=true`，不得开gate/pump；这是control-only conversion，使
  后到activation因lifecycle gate失败，并原样复用既有
  `didCommitEmergencyPlanningCleanup`/halted resume路径；从
  `.initialized|.recovering`调用固定抛`SupervisorRecoveryRequiredError`且零状态
  mutation，不算control winner；
- Orchestrator 只有在上述 local suppression 完成后才持久化 durable halted，并
  调一个整体 planning bulk-cancel transaction。halt 持久化或 cleanup 失败都保持
  本进程 suppressed、错误可见并阻断 resume；
- resume 在 durable mode 仍为 halted 时先重试 bulk cleanup；全成功后才原子切换
  durable running，最后调用 `resumeAfterDurableRunning()` 打开 local gate并 kick
  恰好一次；
- generation + task token + durable gate 必须覆盖 halt-vs-enqueue/preflight、
  halt-after-response、halt-vs-claim/renew/terminal。halt bulk cancel 是唯一
  terminal owner，loser不得写 tokens、Cards、fallback或重复终态 event。
- emergencyStop、shutdown与activation以Supervisor actor顺序为线性化点：
  emergencyStop control先取得顺序时执行上述`.recoveryReady -> .running +
  suppressed + haltCleanupPending` conversion；shutdown先取得顺序时直接进入
  `.shuttingDown`。任一control winner都同时使running-startup first-phase retry
  eligibility、Card-retry eligibility与当前attempt transition token全部失效，
  即使durable halt持久化失败也不得误走任一durable-running startup retry。
  activation先取得顺序时，后到control继续既有suppression、durable transition与
  bulk cleanup，stale recovery不得覆盖control状态。
- `resume()`对durable-running startup failure只有两个互斥的process-local分支，
  都要求exact durable mode为running、无control/halt cleanup pending且本次retry
  attempt transition token有效：
  1. Supervisor第一阶段失败并回到`.initialized`时，只有first-phase retry
     eligibility为true才重跑完整`recoverOnStartup`；成功进入`.recoveryReady`后
     再继续Card recovery；
  2. Supervisor已在`.recoveryReady`时，只有Card-retry eligibility为true才走R11
     新增carve-out，仅重试Card adoption、proposal healing与activation，不重复
     planning repair/adoption。
  二者都不伪造durable transition或`camp_halted/camp_resumed`。durable-halted
  startup/cleanup failure或control已清除eligibility/token时继续走既有
  control/recovery路径，不得套用durable-running retry。

shutdown 合同固定：

- `shutdown` 可从`.initialized|.recovering|.recoveryReady|.running`进入；第一个
  actor turn进入 `shuttingDown`、清除全部startup retry eligibility/token、
  设置 suppressed、checked
  推进 generation、撤销所有 terminal permission、停 pump/timer/renewal并 cancel
  provider Tasks；不修改 durable ledger；
- bounded wait 必须用 actor-owned continuations 加独立 deadline Task；禁止用会在
  scope 退出时继续等待 cancellation-ignoring child 的 structured TaskGroup race；
- deadline 到达后不再 await provider。report 是 sorted unique
  `uncooperativeWorkIds`；Supervisor进入 `shutDown`，但不谎称这些 Task 已停止；
- late callback 被 lifecycle/generation/token gate 拒绝，且零 DB 写。

`Orchestrator`：

- initializer 新增 required `planningProviderResolver`，原 `makeProvider` 仍只服务
  Card/其他既有路径；
- `startMission` 使用本节冻结的 required profile/key/trace，执行 local dispatch
  gate → replay-first enqueue → supervisor kick；不得生成或替换 caller key/trace；
- `recoverAndReconcile` 固定顺序：
  StateDirectoryLock 已持有 → runtime profile bootstrap/reconcile 完成 →
  profile-model snapshot → supervisor recover/legacy repair/adopt并停在
  `.recoveryReady` → Card orphan adoption → proposal healing → transition-token与
  durable-mode重验 → `activateAfterOrchestratorRecovery()` → reconcile；
- `emergencyStop` 先调用 Supervisor local suppression，之后才做 durable halt 与
  projection-atomic planning bulk cancel；不做 release，也不等待不合作 provider；
- `resume` 的普通路径先在halted下完成planning cleanup，再durable running，最后
  打开Supervisor local gate；durable-running startup failure只按上文两个互斥
  predicate处理：`.initialized + first-phase retry eligibility`重跑完整Supervisor
  recovery，`.recoveryReady + Card-retry eligibility`只重试Card/healing/
  activation；两者都要求当前retry attempt transition token有效；
- `waitUntilIdle` 合并 supervisor idle；`shutdown` await supervisor，但不承诺
  App termination release；
- 删除 `planningTasks` 和旧裸 Task/catch kernel_error 路径。

App 接线：

- AppStore、Coding Ranch adapter 与 MissionScheduler 共同持有/调用 §3.2 的同一个
  package-only `PlanningEntryCoordinator`：AppStore在Orchestrator构造后只创建一次
  并作为required initializer参数传给MissionScheduler；adapter extension使用
  AppStore同一property。AppStore manual、Coding Ranch
  candidate 与 proposal 在创建 Task/第一次 await 前固定 exact
  profile/model/key/trace；CLI planning 显示
  `planning_profile_cli_unsupported`，不建 Mission；
- AppStore以process-local `PendingManualMissionStart`保存manual caller snapshot、
  key与trace。相同snapshot的preflight failure或post-enqueue/pre-return failure
  重试复用；收到Mission ID并完成start call后清除。输入/profile/model改变或明确
  新command生成新key/trace；进程重启后已提交work只由ledger recovery接管；
- `MissionScheduler` planner closure 变为
  `() throws -> (runtimeProfileId:String,plannerModel:String)`；checked UTC
  milliseconds 与 selection 只在finite Date pre-guard通过后、claim前捕获为同一个
  Result；non-finite在UUID/selection/claim前typed fail-fast且零写，finite
  success/failure都由coordinator继续既有 `claimScheduleFire`；claim成功后的
  milliseconds/selection/start failure由coordinator只写一次既有 missed，caller不
  补写；A1b不建`schedule_fire`、不改CAS/`lastFiredAt` value或missed语义，只按
  R11-1改变`lastFiredAt` encoding；
- Candidate 在 A1b 仍是现有 start→link 两步路径，只靠 deterministic key恢复 link
  失败后的原 Mission；不提前实现 A3 transaction；
- confirmed proposal 把 proposal ID 派生的 key、首次 trace、profile/model显式传入
  `startMission`；A1b不改变既有proposal CAS/attach/revert/heal状态机，也不承诺
  当前slice修复其独立补偿错误；
- legacy profile-model snapshot 由 profile-scoped defaults 生成后注入 Core；
  resolver 不得在执行时回读 default；
- 不修改 `AgentLoopApp.swift` 或 willTerminate observer；生产可靠性来自 ledger
  adoption，不宣称异步 termination 完成。

#### A1b 必测

原子开工、identity 与入口：

- `missionAndPlanningWorkCommitAtomically`；
- `sameMissionStartReplayRunsBeforeCredentialAndCatalogPreflight`；
- `sameMissionStartReplayAfterProfileDeletionReturnsOriginalIdsAndTrace`；
- `sameMissionStartReplayDoesNotConstructProvider`；
- `sameMissionStartConflictWinsOverCurrentProviderFailure`；
- `sameMissionStartPayloadOrGraphConflictFailsWithoutWrites`；
- `planningReplayPreservesFirstTrace`；
- `planningProfileKindDriftBetweenPreflightAndTransactionWritesNothing`；
- `manualMissionStartCapturesProfileModelKeyAndTraceBeforeTask`；
- `manualMissionStartReusesPendingCommandAfterPostEnqueueFailure`；
- `manualMissionStartInputChangeCreatesNewCommandAndSuccessClearsPending`；
- `lateManualMissionSuccessDoesNotClearNewPendingCommand`；
- `candidateMissionStartUsesDeterministicKeyAndReplaysAfterLinkFailure`；
- `confirmedProposalMissionStartUsesProposalKeyAndPreservesFirstTrace`；
- `scheduleMissionStartUsesCheckedUTCMillisecondsKey`；
- `scheduleMillisecondsOverflowClaimsSlotThenRecordsMissedWithoutMission`；
- `schedulePlannerSelectionFailureClaimsSlotThenRecordsMissedOnce`；
- `scheduleExtremeFiniteLastFiredAtPersistsNumericallyReloadsAndDedupes`；
- `scheduleLegacyTextLastFiredAtRemainsReadable`；
- `scheduleDateEncodingChangesOnlyLastFiredAt`；
- `nonFiniteScheduleFireFailsBeforeClaimWithoutWrites`；
- `a1bSchedulePathDoesNotCreateScheduleFireOrChangeClaimCAS`；
- `manualAppCallsiteCapturesCoordinatorCommandBeforeTask`；
- `candidateAppCallsiteCapturesCoordinatorCommandBeforeFirstAwait`；
- `proposalAppCallsiteCapturesCoordinatorCommandBeforeTask`；
- `scheduleAppCallsiteDelegatesClaimAndStartExclusively`；
- `appPlanningCallsitesContainNoDirectOrchestratorStart`。

原十项
`manualMissionStartCapturesProfileModelKeyAndTraceBeforeTask`、
`manualMissionStartReusesPendingCommandAfterPostEnqueueFailure`、
`manualMissionStartInputChangeCreatesNewCommandAndSuccessClearsPending`、
`lateManualMissionSuccessDoesNotClearNewPendingCommand`、
`candidateMissionStartUsesDeterministicKeyAndReplaysAfterLinkFailure`、
`confirmedProposalMissionStartUsesProposalKeyAndPreservesFirstTrace`、
`scheduleMissionStartUsesCheckedUTCMillisecondsKey`、
`scheduleMillisecondsOverflowClaimsSlotThenRecordsMissedWithoutMission`、
`schedulePlannerSelectionFailureClaimsSlotThenRecordsMissedOnce` 与
`a1bSchedulePathDoesNotCreateScheduleFireOrChangeClaimCAS` 直接调用真实 package
coordinator，不是同构 mock。上述 R11 non-finite test 是额外第十一项 coordinator
功能测试；其余三个 R11 Schedule encoding测试直接验证
`ScheduleRecord`/`ScheduleStore`。后五项 App source tests由
`PlanningTestFixtures.swift` 从 `#filePath` 定位 package root，以固定函数签名和
可失败的 balanced-brace scanner（跳过注释与字符串）截取真实 App函数，再验证唯一
coordinator调用、capture/task/await token顺序和 direct-call零命中；找不到、重复、
brace不平衡或 token顺序不符都失败。

resolver、provider 与 Planner：

- `capturedProfileAndModelDoNotDriftAfterDefaultChanges`；
- `cliPlanningProfileFailsPreflightWithoutMissionWrites`；
- `oauthPlanningUsesStaticCatalogAndBothCredentialAccounts`；
- `officialAPIPlanningUsesCachedPlusManualCatalog`；
- `customAPIPlanningAcceptsProfileScopedManualModel`；
- `planningPreflightRejectsMissingCatalogWithoutWrites`；
- `planningPreflightRejectsMissingPrimaryCredentialWithoutWrites`；
- `oauthPlanningRejectsMissingAccountIdWithoutWrites`；
- `planningCredentialReadFailureIsTypedAndDoesNotWrite`；
- `planningInvalidEndpointIsTypedAndDoesNotWrite`；
- `claimRevalidatesExactCapturedProfileModelAndCredentials`；
- `deletedOrUnsupportedCapturedProfileTerminalizesExistingWork`；
- `providerFailureIsNotConvertedToFallbackCard`；
- `planningContractInvalidDoesNotFallback`；
- `plannerRetriesOnlySchemaCorrectionAndPreservesFirstTurnUsage`。

usage、success/failure/cancel transaction：

- `genericPlanningKindAPIsRejectBeforeSQL`；
- `genericReservedKindOrderingUsesCallerOrderBeforeDeduplication`：对
  `claimNext`、`nextClaimableDate`、`adoptInterrupted` 分别覆盖
  `[.planning,.campDeletion]` 抛 planning capability error、反序抛 deletion
  capability error，并证明既有 time/lease 参数错误仍先于 reserved-kind 扫描；
- `genericPlanningTargetAPIsRejectBeforeMutationAndClosures`；
- `genericPlanningReadSeamsRemainAvailable`；
- `planningSpecificProviderLifecycleUsesSealedLedgerOwner`；
- `planningSpecificRecoveryAdoptsInterruptedWithoutGenericAPI`；
- `planningSpecificSingleAndBulkCancelRemainAvailableWhileHalted`；
- `planningIdentityAndTokenEventsPreserveIntegersAboveTwoTo53`；
- `planningUsageNilWritesNoTokenEvent`；
- `planningUsageZeroWritesExactTokenEvent`；
- `negativePlanningUsageFailsBeforeSQL`；
- `negativeFirstTurnPlanningUsageTerminalizesWithoutTokenEvent`；
- `negativeCorrectionUsagePreservesPriorValidUsage`；
- `turnAggregateUsageOverflowTerminalizesWithExactEvidence`；
- `inputOutputUsageOverflowTerminalizesWithExactEvidence`；
- `existingSpentUsageOverflowTerminalizesWithExactEvidence`；
- `planningUsageOverflowEvidencePreservesIntegersAboveTwoTo53`；
- `planningUsageOverflowEvidenceSortsDeduplicatesAndRejectsInvalidShape`；
- `planningUsageOverflowMutationRollbackIsTotal`；
- `planningSuccessWithNilFallbackWritesNoFallbackEvent`；
- `planningSuccessWithFallbackIsRejectedWithoutWrites`；
- `unexpectedPlanningFallbackTerminalizesThroughFailureOwner`：只能经matching
  `#if DEBUG package injectOwnedSuccessProposalForTesting(workId:result:)`进入既有
  owned completion/pending proposal owner；断言同一个typed Usage进入deterministic
  failure、零fallback event且provider调用数不增加；
- `planningSuccessCommitsTokensCardsRollupAndWorkOnce`；
- `transientFailureRecordsUsageAndUsesDurableBackoffOnly`；
- 在 usage guard、每张 Card、Mission rollup、event、attempt close、work terminal
  后逐点注入失败，`planningTerminalMutationRollbackIsTotal`；
- `planningCancelIsProjectionAtomicAndIdempotent`；
- `haltBulkPlanningCancelIsAllOrNothing`；
- `planningSuccessOverBudgetCreatesCardsButDispatchesNone`。

Supervisor、recovery、halt 与 shutdown：

- `leaseRenewalCompletionUsesLatestClaim`；
- `staleRenewCancelsOnlyMatchingOwnedTask`；
- `stalePlannerAfterCancelCannotWriteTokensOrCards`；
- `supervisorNextDueTimerWakesRetryWithoutPolling`；
- `waitUntilIdleIgnoresFutureRetryButWaitUntilTerminalDoesNot`；
- `terminalCommitStoreFailureRetainsOwnershipAndPendingProposal`；
- `terminalPendingProposalRetriesOnlyAfterRenewOrExplicitKick`；
- `claimOrNextDueStoreFailureLatchesFatalAndWakesWaiters`；
- `renewNonStaleFailureLatchesFatalWithoutDroppingLedgerOwnership`；
- `staleClaimAndGenerationLosersDoNotLatchFatal`；
- `terminalWaiterReturnsAfterDurableCancelWhileIdleWaitsForProviderExit`；
- `runningStartupDoesNotDispatchPlanningBeforeCardOrphanAdoptionCompletes`；
- `startupCardOrphanAdoptionFailureKeepsPlanningSuppressedWithoutDurableTransition`；
- `explicitRetryAfterStartupCardRecoveryFailureActivatesSupervisorExactlyOnce`；
- `startupRecoveryRetryWritesNoCampHaltedOrCampResumedEvent`；
- `staleStartupRecoveryCannotActivateAfterConcurrentControlTransition`；
- `haltedStartupRunsCleanupWithoutPumpTimerOrProvider`；
- `haltedStartupRepairsAndAdoptsBeforeAtomicCleanupWithoutDispatch`；
- `haltedStartupWithWorklessLegacyMissionLeavesNoActivePlanning`；
- `haltedWorklessUnresolvedLegacyMissionUsesEmergencyHaltAttemptZero`；
- `haltedStartupCleanupFailureRetriesRecoveryBeforeDurableRunning`；
- `haltPersistenceFailureKeepsSupervisorSuppressed`；
- `haltCleanupFailureKeepsSupervisorSuppressedAndBlocksResume`；
- `haltAfterProviderResponseCannotWriteTokensOrCards`；
- `haltRacingSameKeyReplayOrAbsentPreflightWritesNothing`；
- `haltRacingEnqueueClaimOrRenewHasControlWinnerOnly`；
- `haltRacingFailureOrOverflowTerminalHasSingleOwner`；
- `resumeOpensSupervisorOnlyAfterDurableRunningAndKicksOnce`；
- `missingOrCorruptKernelControlFailsPlanningClosed`；
- `shutdownWithCancellationIgnoringProviderReturnsBoundedly`；
- `shutdownReportSortsUniqueUncooperativeWorkIds`；
- `providerReturningAfterShutdownCannotCommit`；
- `shutdownRacingTerminalProposalHasOneActorSerializedWinner`；
- `nextProcessAdoptsShutdownRowAndCompletesExactlyOnce`；
- `restartAdoptsPlanningWorkAndCreatesCardsOnce`。

其中 recovery-retry event test必须含
`.initialized + first-phase retry eligibility`完整重跑与
`.recoveryReady + Card-retry eligibility` Card-only重试两个子场景；stale-control
test必须分别覆盖shutdown清first-phase eligibility/token与emergencyStop清Card
eligibility/token。

legacy 与范围：

- `legacyPlanningRepairUsesUniformMemberProfile`；
- `legacyPlanningRepairUsesExactlyOneDefaultOnly`；
- `legacyPlanningRepairConflictOrCliFailsMissionOnce`；
- `legacyPlanningFailureCreatesAttemptZeroWithoutAttemptRows`；
- `legacyPlanningModelUnavailableFailsMissionOnceWithExactCode`；
- `legacyPlanningWithCardsFailsClosedWithExactTypedErrorAndZeroWrites`；
- `runningUnresolvedLegacyMissionKeepsExactLegacyTerminalCode`；
- `legacyRepairRunningModeLinearizesBeforeConcurrentHalt`；
- `legacyRepairHaltedModeCreatesAndCancelsAttemptZeroAtomically`；
- `legacyPlanningRepairRunsBeforeCardAdoption`；
- 更新全部允许清单中的 compile call-site tests，helper 必须显式传 profile/key/trace；
- source sentinel 证明旧 public split planning API、`planningTasks`、10ms polling、
  compatibility overload、current-default lookup与
  `suppressForOrchestratorRecoveryFailure` production declaration/call site均为零；
  DEBUG seam及其 test/helper调用全部位于matching `#if DEBUG`，release Core
  object中无该符号。

#### P1-A1b 完成定义

- 职责隔离 Review11 必须先在 R11 Candidate 的 Stage/总 Plan/leaf exact hashes上给出
  `APPROVED — 0 P0 / 0 P1`；它只重新打开implementation，不替代implementation
  Review或acceptance；
- R-01 失败测试先复现、后关闭；
- production 无公开 shell/plan/token/fallback 分步写 API；
- generic DurableWork九个 mutation/dispatch API均无法处理 `.planning`，而
  specialized provider/recovery/cancel owner与三个 planning只读 seam均有正反例；
- `rg 'planningTasks' Sources/AgentLoopCore/Kernel/Orchestrator.swift` 无残留；
- App三个生产文件对 direct `Orchestrator.startMission` /
  `confirmSquadProposal` / schedule claim零命中，四入口 coordinator功能与 source
  order tests全绿；
- Schedule non-finite pre-guard、finite milliseconds overflow claim→missed、
  `lastFiredAt` numeric write、legacy TEXT/numeric decode及“其他Date编码不变”测试
  全绿，且schema/slot/CAS/missed产品语义不变；
- running startup在Card adoption、proposal healing、transition与durable-mode fences
  通过前始终`.recoveryReady + suppressed`；显式retry只activate一次、零伪造
  halt/resume event，stale control不能被recovery覆盖；
- `LegacyPlanningHasCardsError` exact type/code与完整零写快照成立；
- unexpected fallback只经matching-DEBUG narrow seam进入生产failure owner；release
  Core无该符号、不重呼provider、不写fallback event；
- `Package.swift`、`Package.resolved`、`Sources/RunTests/main.swift` 与 A1b进入
  指纹逐字不变；
- named `v12-durable` fixture 必须在 SQLite 3.51/3.52 两条真实 GRDB linked lane
  close/reopen/replay通过；不得复制最终 schema或改变 A1a literal/verdict；
- 全部命名测试、`swift run RunTests`、App build、独立 state preview、migration
  matrix、scope/hash证据、独立 A1b implementation Review 与 acceptance 全通过后，
  才关闭 R-01 并进入 A2。

R11 implementation 任一出现以下情况必须立即重新关闭 A1b：需要新增migration/
schema或第二个Schedule/planning owner；需要改变finite slot、claim CAS、
`lastFiredAt` value或missed语义；只能靠post-failure re-suppress、持久recovery
state、临时durable halt、bulk cancel或伪造camp event完成startup；DEBUG seam进入
release/public surface或绕过owned failure owner；Package/RunTests/target graph
漂移；任一红测、未知失败或Review P0/P1。不得以放宽测试或延后到A2/A4通过。

### 3.3 P1-A2：Durable Rumination

这是第三个、独立的 Codex implementation invocation。入口是 A1b Accepted。
Review12 已对旧 candidate 判定 `CHANGES REQUIRED — 0 P0 / 2 P1`；Review12A
又对 R12-C candidate 判定
`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`，immutable SHA-256 为
`a102c49138fcfc1f40b0c780990d8c3ad5ec2302b175b043bde9457164331337`。
Review12B 对 R12-D candidate 判定
`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`，immutable SHA-256 为
`66b81e9e5ea0f74e08706c7367f2e80180601a000c9e84c1bbd4357a9c3b4ec5`。
Review12C 已在 R12-F exact hashes上判定`APPROVED — 0 P0 / 0 P1`，只作为
immutable historical predecessor。Review13 又在 R13 exact hashes上判定
`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`，immutable SHA-256为
`5203057f2a4a7f04827d9f5e0f20b717e08a31125404483b11f5cad722bda66b`。
Review13B随后在R13B control candidate上判定`APPROVED — 0 P0 / 0 P1`并打开
有界implementation；该实现、技术验证与fresh isolated retry已完成，但职责隔离
implementation Review01因验证工具误启动installed App、实际打开normal
lock/DB/SHM/WAL判定`CHANGES REQUIRED — 0 P0 / 1 P1`。

R14没有重新打开下列产品/test文件的修改权限；其freeze
`66436eeeedba03e3e0a4411e208c3dd7993f5c2968952c7bff64446232ca011d`
与Review14
`5bc0adf787dabd1451c53c7fc13df817325b323b030478443f62030bbf28e405`
均为immutable predecessors。Review14 verdict为
`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`：R14禁止LaunchServices，但未冻结
source/build→App bundle→signed executable provenance，故从未打开任何执行。

R15关闭了该P1；Review15已在`evidence/plan-freeze-r15.md`记录的exact hashes上
判定`APPROVED — 0 P0 / 0 P1`。牧场主随后授权一次R15 clean invocation，但交互
执行器临时定义的zsh attestation helper在Review12C expected/actual hash逐字相等
时仍错误进入mismatch分支。R15在任何test/build/matrix/source/bundle/preview前
永久停止为`REJECTED_CONTAMINATED — BEGIN attestation false negative`；两处相等
operand只能证明仓库未漂移，不能证明该未复现的helper触发机制已修复。

Review16已批准R16 plan，牧场主也在后续新turn以四个final hashes授权；但R16
driver在pre-BEGIN正常`pgrep rc=1`缺席探针被全局`ERR` trap抢占后停止。四anchors
与110/110 manifest通过，授权未消费，12个runtime paths和两类fresh roots均未创建，
没有任何后续门或产品/test/App-script delta。

R17随后只根因级关闭13个status-capture blocks并增加Bash 3.2 probe；Review17静态
确认syntax、probe与115/115 manifest全绿，却因RanchArt exact-27/nonregular结构门
位于授权消费后而判定`CHANGES REQUIRED — 0 P0 / 1 P1`。R17没有plan approval，
caller/BEGIN及全部执行门从未运行，12个runtime paths和两类fresh roots均未创建。

R18曾尝试关闭该Review17 P1-01：使用单一phase-aware RanchArt verifier，在唯一授权消费
前把zero-write preflight作为最后fallible precondition；消费后立即从filesystem
重新调用同一verifier并写证据。R18-A又把R15 historical canonical-empty观察与
current `ABSENT`分层，把两个exact identities冻结为absorbing tombstones，并以联合
parent enumeration fail closed；一个inherited C职责一对一替换但13/14计数不变。
Review18已在该candidate上判定`CHANGES REQUIRED — 0 P0 / 1 P1`，唯一P1是newline
pathname transport collision，故R18从未执行。Review19随后在
`evidence/plan-freeze-r19.md`冻结的R19 Stage、总Plan、A2 leaf、control、reviewed
driver与123-entry manifest exact hashes上判定`APPROVED — 0 P0 / 0 P1`；牧场主又在
后续新turn按`freeze, Review19, driver, manifest`提供四hash并授权。R19到达
`BEGIN_ATTESTED`且41/41 A2 tests通过，但唯一一次未过滤权威`swift run RunTests`
为651/652；`slowActiveStreamDoesNotIdleTimeout`以`idle script exhausted`失败。
R19永久`REJECTED_CONTAMINATED`，不能重跑或继续后续门。当前唯一前瞻路径是Stage
§28.7与本Plan §18 R20节：先冻结、Review20，再等后续新turn四hash授权，只在两个
具名文件内建立deterministic-time shared verification seam并完成fresh R20全门。
R13 incident、旧报告/Review01/日志、R14 predecessors、R15失败证据、R16 planning/
pre-BEGIN零写入事实与R17/R18 rejected plan/not-executed事实全部immutable；旧retry、
R15/R16失败边界、R17/R18 candidate、R19 targeted green/failed boundary与现存
`.build/AgentLoop.app`都不构成R20 green input。
另一个不可放宽的A2 entry
invariant是当前产品同一state root只有一个
production writer：AppStore lifetime-held `StateDirectoryLock`必须在唯一
production `AppDatabase(path:)`之前成功取得；任一source/hash gate不成立都继续
冻结A2。

#### 精确允许文件

下列产品文件只是R13 historical allowlist；R15–R19各失败/rejected boundary及R20均不
允许修改其中任何byte：

- `Sources/AgentLoopCore/Work/DurableWork.swift`
- `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift`
- `Sources/AgentLoopCore/Database/DurableWorkStore.swift`
- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopCore/Ingestion/IngestionRecords.swift`
- `Sources/AgentLoopCore/Ingestion/FeedService.swift`
- `Sources/AgentLoopCore/Rumination/RuminationService.swift`
- `Sources/AgentLoopCore/Rumination/RuminationParser.swift`
- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
- `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift`
- `Sources/AgentLoopApp/AppStore.swift`，只接线和可见 state
- `Sources/AgentLoopApp/CodingRanchContracts.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/RuminationViews.swift`

下列测试文件只是R13 historical allowlist；R15–R19与R20同样不允许修改任何byte：

- `Sources/AgentLoopTestSuite/CodingRanchTests.swift`
- `Sources/AgentLoopTestSuite/DurableWorkTests.swift`

R12-A 只给 control tooling 一个例外：

- `scripts/verify-p1-migrations-sqlite-matrix.sh` 只允许把 line 115
  `expected_stage_hash` 的旧 64-hex 替换为当前最终 frozen Stage SHA-256；
- 把该 value 恢复为旧
  `add94117fc634add114bff62aefd7f77d71e4826d15c9bd1affba1a8d76366a2`
  时，整份 script 必须恢复 SHA-256
  `b51129fe71cc7074f644ba8d0969ddb98aa664253887ea6c3840baa6655e5be5`；
- fixture、literal、linked lanes、assertions、commands 与全部其他 bytes 不得改。

下列文件在 A2 必须 byte-identical：

- `Sources/AgentLoopCore/Support/StateDirectoryLock.swift`
- `Sources/AgentLoopTestSuite/SupportTests.swift`
- `Sources/AgentLoopCore/Work/PlanningProviderResolver.swift`
- `Sources/AgentLoopCore/Rumination/RuminationResult.swift`
- `Sources/AgentLoopCore/Rumination/RuminationMaterializer.swift`
- `Sources/AgentLoopCore/Database/EventKind.swift`
- `Sources/P1MigrationMatrixRunner/main.swift`
- `Package.swift`
- `Package.resolved`
- `Sources/RunTests/main.swift`
- `scripts/run-app.sh`
- `scripts/package-app.sh`
- `Sources/AgentLoopApp/Views/CodingRanch/RanchArtView.swift`
- `Sources/AgentLoopApp/Resources/RanchArt` 27-file canonical manifest

不得新增产品/test/script文件、target、dependency、migration、schema、DDL、
trigger、persistent phase或provider-returned checkpoint。R17–R19全部planning/review/
execution artifacts与R19两个exact empty rootsimmutable。

R20仅有一个经Stage §28.7明确授权的shared-verification prerequisite例外；Review20
通过且后续四hash授权后才可修改：

- `Sources/AgentLoopCore/Loop/AgentLoop.swift`，entry
  `5ec55a86b4548410b3f9ae876f7f8356d4a89e1024ef92f173412164c194a1bc`；
- `Sources/AgentLoopTestSuite/AgentLoopTests.swift`，entry
  `28f5b4287a1004daaca962db375c9ea24ac0f06d0f6abbd0c6ecd277696abfb2`。

该例外不打开P1-F1，不改变上述13+2历史allowlist，也不允许第三个source/test path。
现阶段R20 planning只允许六面、`evidence/r20-begin.sh`、
`evidence/r20-entry.sha256`、`evidence/plan-freeze-r20.md`及职责隔离Review20。出现
清单外compile requirement必须写A2`blocked.md`并停止，不能自行扩张。

#### 实施顺序与唯一 owner

1. **先写红测。** 只在两份允许 test 中建立下列 exact named gates；保存 targeted
   failure log，必须证明旧路径至少存在“start 无 durable work、legacy 无 repair、
   cancel 无 ledger、unowned App Task/current-default drift、重启伪造 reading”
   根因。编译失败、test 未发现、fixture 错误或 unknown red 不算有效根因证据。
2. **封闭 generic capability。** 在 DurableWork/Store 新增
   `RuminationRequiresDurableRuminationCapabilityError`，按 Stage §6.4.3 的 exact
   validation priority 封死 public/internal generic
   enqueue/claim/nextDue/renew/complete/retry/cancel/adopt；read-only 保留。
   既有 generic tests 的 ordinary `.rumination` fixture 机械改为 `.coach`，
   第二 ordinary kind 用 `.inputParsing`。
3. **建立 start/legacy/terminal specialized transactions。** AppDatabase/
   DurableWorkStore 实现 Stage §6.4.1、§6.4.6、§6.4.8 的同步 preparation、
   active replay、absent preflight 后 atomic start、legacy repair、
   success/failure/cancel/halt operations。全部 payload 只走 typed
   `CanonicalJSONV1`，`outputJson=nil`；legacy 必须逐格实现 Stage §6.4.6 的
   running|halted × valid|三种invalid 8-cell表，mode先线性化且halted绝对优先；
   禁止 transaction helper 内 nested pool。success、deterministic/exhausted
   failure、transient retry与actual user cancel必须返回真实resulting
   `DurableWorkRecord`；halt cleanup返回按work ID排序的actual-canceled
   `(phaseIdentity,workVersion)`，attempt允许queued未claim的0。workVersion只能取
   resulting work record，rollback/throw/no-active固定零commit identity。
   normal start specialized operation返回既有`DurableWorkEnqueueResult`：
   只有本次实际提交queued work+item ruminating+generation increment才是
   `work=<resulting queued attempt0 version=1 work>, disposition=.inserted`；同一
   transaction不得二次推进new work version；same-key/完整
   active graph只返回`work=<original work>, disposition=.replayed`且整次零写。
   preflight/conflict/rollback/throw不得返回
   inserted，也固定零barrier/reservation/sink/kick。App preparation直接返回的
   `replay(ingestionId,workId)`必须绕过resolver与specialized Store start；并发
   new-command在transaction重验时得到的Store `.replayed`是第二origin，两者统一交给
   Supervisor同一workId replay branch。
4. **把既有 Supervisor 扩为单一全局 owner。** 不创建第二 production instance。
   specialized claim/nextDue 使用 planning+rumination 全局
   `createdAt,rowid` FIFO；OwnedEntry 按 kind 持有 typed proposal；复用一个 pump、
   lease、timer、generation、fatal、wait、halt/resume/shutdown owner。唯一新增
   `onRuminationPhase(RuminationPhaseCommand) async` typed awaited sink 用 default
   no-op保留现有 non-rumination tests source compatibility；production显式接
   Orchestrator且不得包 `Task`。command exact cases只能是 identity-bound
   `.set`/`.invalidate`；所有正向 phase与清理共用该 sink，不得保留
   `RuminationPhaseEmission`或新增第二 callback。Supervisor actor内唯一
   `invalidateRuminationPhaseIfNeeded` 对 exact identity 提供 in-flight waiter、
   first-reason-wins与 exactly-once delivery；不得用 Task/timeout/cancellation拥有
   invalidation。ownership/control loss、halt/shutdown phase clear精确映射
   `.controlLoss`；DB/invariant/其他global fatal phase clear精确映射
   `.globalFatal`。terminal/retry/cancel commit只走下述projection milestone。
   每个set在
   await前登记set-in-flight；invalidator先revoke新set并等待该已登记set sink返回，
   再发送invalidate，不依赖跨actor mailbox FIFO。exact public identities为
   `RuminationPhaseIdentity(ingestionId,workId,attempt>=0)`与
   `RuminationProjectionCommitIdentity(phaseIdentity,workVersion>=1)`；positive
   set/phase clear另要求running/open attempt>=1。invalidate milestone exact cases
   只能是`.phase(identity:reason:)`与`.projectionCommitted(commitIdentity)`，reason
   只允许controlLoss/globalFatal。唯一projection publisher在Store commit后的同一
   actor turn、第一次await前reserve full identity，revoke committed
   claim/generation后续set/terminal，等待registered set并await同一sink；rollback
   零reserve。full commit identity exactly-once；同work更高version允许，unseen
   lower或same-version/different-identity fail-fast。每identity一个串行coordinator
   使set/phase/projection sink互不并发：commit-first时later phase等待且matching
   commit满足clear、零第二phase command；phase-first时later真实commit等待后仍发
   refresh且typed optional clear为nil。
   Orchestrator只保留start/retry public façade；唯一Supervisor actor执行absent
   preflight、调用specialized Store、解释`.inserted|.replayed`、发布start commit与
   kick。`.inserted`同步return后第一次await/reentrancy前必须validate resulting work
   为exact rumination/ingestion/<ingestionId>、queued attempt0/`version=1`，同时
   reserve full identity并登记Supervisor-owned
   process-local start-projection barrier。所有已有pump/timer/kick/global FIFO
   claim入口先查barrier：任一存在时planning+rumination均零DB claim且不得跨kind
   skip。await nonthrowing sink后release barrier，重读mode/work，仅
   running+active才kick/return；task cancellation不能跳过delivery/release。
   两种replay origin都零commit milestone，只按workId等待Supervisor保存的original
   inserted in-flight delivery；delivered或restart无waiter时零等待、零第二
   sink/event，禁止从current attempt/version构造identity。start delivery暂停时reentrant
   cancel/halt更高version在同coordinator严格排后，start恢复不得复活/claim。
   replay/restart freshness依赖并必须保留现有single-writer production boundary：
   `StateDirectoryLock`对同一appSupport root使用nonblocking exclusive
   `flock`，第二owner `EACCES|EAGAIN` fail-fast；AppStore以`private let`完整
   lifetime持锁，且lock acquisition先于production source tree唯一
   `AppDatabase(path:<same-root>/agentloop.sqlite)`。process death释放lock后，新
   owner先开DB再完成target-Camp snapshot ready gate；因此不存在另一production
   writer在已ready snapshot后commit的TOCTOU。A2不得改这两个lock文件、增加第二
   production opener/writer或为CLI/硬件绕锁；multi-writer须另开stage设计
   coordination/outbox。
5. **统一 Orchestrator lifecycle。** production 只走 Stage §6.4.5 的 exact startup
   order、two-phase activation、halt cleanup、emergency halt 和 shutdown。
   planning-only compatibility API 不得在 production bypass；发现 active rumination
   时必须 fail-fast。所有 production fatal state writer、`.fatal` classification、
   `latchFatal`/`latchReadFailure`与 revoke-all wrapper只要可能有rumination，都
   必须 await唯一
   `latchFatalAndInvalidateRumination(_:operation:workId:) async`；顺序锁为捕获sorted
   identities→revoke phase-set permission→await exactly-once phase invalidation→取消
   provider/renewal task→return/throw。同步 compatibility path只能在mutation前
   证明零 active/owned/set-in-flight/live rumination，否则 exact capability error
   fail-fast。emergency halt精确顺序为sorted pre-cancel phase clear→取消provider/
   renewal→persist halted→planning cleanup→rumination cleanup返回sorted actual
   commits→逐个projection milestone→didCommit/`haltStateChanged`→return；
   cleanup失败不为未commit row发milestone且保持suppressed/recovering，
   `haltStateChanged`不能兼任refresh owner。shutdown在取消task前同序phase clear，
   但自身无DB commit所以零projection milestone。terminal/retry/user-cancel只在
   业务transaction commit后发布full projection milestone；rollback保留live
   phase/claim/pending proposal。若halt/user-cancel在start projection sink暂停时
   actor重入，actual commit的更高version必须等待start `V` delivery后再发布；
   control完成后start owner重验为非active/halted，固定零kick/claim。
6. **拆 RuminationService并建立唯一 pre-parse handshake。** 删除其
   DB/start/cancel/process owner；唯一 provider API/path 是
   `produceValidatedTurn(ingestion:) async throws -> RuminationValidatedTurn`，
   在返回 opaque turn前完成 one-stream、exact-one-turn、tools empty与 exact
   non-negative Int64 usage validation。raw text/initializer fileprivate。Supervisor
   按 Stage §6.4.9 两次重验并 awaited 发 organizing后，才在同一 actor turn同步调用
   唯一 pure
   `parseValidatedTurn(_:) throws -> RuminationProduction`；它零 provider/DB/await，
   result与turn usage同源。禁止 mutable lastUsage、provider/usage/optional callback、
   unowned Task或第二 provider path；同步 Database transaction helper只消费 caller
   transaction。两次任一失权都抛 exact no-payload package control signal；owned
   provider task必须先await同一 identity invalidation，再显式 catch 后直接退出，
   不进入 failure/retry/terminal proposal。DB read/invariant fatal先await唯一
   global-fatal owner完成全部 invalidation；sink返回前不得取消 current task，
   sink不得因 Task cancellation early-return。
7. **冻结 captured resolver/failure。** App MainActor 在第一次 Task/await 前用同步
   preparation 捕获 profile/model/key/trace；Supervisor 对 absent command preflight，
   claim 再按 captured identity resolve；严格复用 byte-identical
   `StrictPlanningProviderResolver`，按 Stage §6.4.2/§6.4.7 映射 exact code、
   safe message、usage 与 5/30/120 retry。unknown resolver invariant 进入 global
   fatal，`CancellationError` 由 lifecycle owner 收口。
8. **接 App 与真实 phase。** AppStore production 显式传启动 snapshot并订阅
   Orchestrator 的 process-local `KernelEvent`；Adapter 的 start/retry/cancel 只
   delegate，不建 unowned Task、不构造 provider、不读 current default。
   Supervisor取得 opaque validated turn后，以
   `workId/attempt/ownershipToken/generation`进入唯一 handler，发 organizing前后
   都重验 actor lifecycle/OwnedEntry当前 latest claim与DB durable running；
   第二次仍valid才无await parse。Orchestrator actor唯一持有
   ingestion→exact identity/phase registry与last-invalidated tombstone，另以full
   commit identity持有process-local receipt并维护per-work最高version；`.set`
   只允许 exact identity有序推进且先registry后emit；`.invalidate(.phase)`只在
   identity全匹配时remove→tombstone→恰好一次typed
   `ruminationChanged(.phaseInvalidated(identity))`，stale/mismatch零事件且不能清
   新generation。`.invalidate(.projectionCommitted)`对full identity exactly-once/
   monotonic；exact registry时remove+tombstone并emit optional `.some(identity)`，
   empty/tombstoned/different-newer时registry不变、optional nil但仍恰好一次commit
   refresh。既有KernelEvent仍仅两个case：
   `ruminationChanged(RuminationChange)`与
   `ruminationPhase(ingestionId:workId:attempt:phase:)`。public
   `RuminationChange` exact cases为`.phaseInvalidated(identity)`与
   `.projectionCommitted(commitIdentity,invalidatedPhaseIdentity:)`；不增第三case/
   EventKind/schema。
   App live map保存identity+phase；单一MainActor `for await`直接await handler，不
   建per-case Task。phase event先从同一次DB snapshot重验item ruminating与active
   running exact workId/attempt再overlay；change只按typed exact optional clear，
   但无论clear与否都serial reload persisted projection并仅保留仍匹配snapshot的
   live entry。old version/new generation只reload；background Camp只更新loaded
   camp cache，不能切换selected Camp。Adapter completion零第二refresh owner。
   control/fatal失权零parse且在throw/cancel/return前await invalidation，即使
   persisted identity不变也收口为recovering。terminal/retry/cancel/halt commit
   路径经唯一projection publisher刷新；terminal rollback零milestone、不清phase。
   normal start/user retry inserted也经同一publisher发attempt-zero
   `workVersion=1` refresh并由
   start barrier保证先于claim/positive phase；attempt-zero event optional clear固定
   nil。App lifecycle/restart必须先用同一Adapter persisted snapshot path成功加载
   目标ingestion所属Camp并标记ready，才enable该start/retry action；load失败保持
   disabled并显示既有显式load failure，不能清startup pending后继续。新进程无start
   waiter/receipt时active graph由该snapshot显示recovering，replay不补event；
   background Camp readiness只更新对应cache、不切selected Camp。未知重启从empty registry
   映射 `.recovering`/`正在恢复`，不得 `?? .reading`。该freshness以第4步冻结的
   single-writer lock-before-DB-open entry invariant为前提，Adapter completion/
   direct reload仍不成为replay refresh owner。
9. **加 mutation fences。** Feed discard、Adapter ingestion delete 与 Camp archive
   在各自同一 transaction 同时检查 item status 和 active rumination work；
   `needsReview` 不能重开，所以 RuminationMaterializer 不改。
10. **完成验证与报告。** implementer 只写 A2 task 的 failure/verify/build/matrix/
    preview logs 与 `impl-report.md`；不得写 Review/acceptance。任何 red、未知失败、
    immutable hash drift、A1b regression 或清单外需求都阻止 Review。

上述第10步描述R13 implementation历史。R14没有回写这些artifact且Review14未开门。
R15 clean re-verification已只创建leaf §2.3冻结的distinct `r15-*` evidence与
`impl-report-r15.md`，并在BEGIN false negative后停止；其中八个未运行gate日志
保持0 bytes、preview smoke保持不存在，不能覆盖、补写或改名。R16 planning只新增
reviewed BEGIN driver、静态entry manifest、freeze与Review16；获四hash执行授权后
在pre-BEGIN status-capture false positive停止，未创建任何runtime evidence/root，
授权未消费。R17 planning只新增reviewed driver、Bash 3.2 probes、静态manifest、
freeze与Review17；Review17以`CHANGES REQUIRED — 0 P0 / 1 P1`关闭，故R17未获
四hash执行授权、没有创建任何runtime evidence/root。R18 planning新增reviewed
driver、119-entry静态manifest与freeze，复用immutable R17 Bash 3.2 probe；Review18
以`CHANGES REQUIRED — 0 P0 / 1 P1`拒绝newline pathname transport，故R18同样没有
执行或runtime evidence/root。R19随后获Review19批准及新四hash授权；它创建fresh
artifacts/roots并通过41/41，但权威full suite 651/652使boundary永久rejected，后续门
未运行且产品/test零漂移。11个R19 artifacts、缺失screenshot与两个exact empty roots
全部immutable。R20随后获Review20批准及新四hash授权；唯一full 652/652、同log 46/46、
debug build与LAUNCH_READY通过，但release Core automatic-product fallback触发DEBUG
caller/callee配置错配，boundary永久rejected，后续门未运行。R20 final两source bytes、
11 artifacts、absent screenshot、exact empty state root与含signed App的bundle parent全部
immutable。R21 planning只新增release-configuration reviewed driver、155-entry manifest与
freeze；Review21及后续新四hash授权前不得写fresh `r21-*` evidence、实施TestSuite三对
guards或运行任何门。

#### Exact named tests

下列 41 个名字在最终 `swift run RunTests` discovery/output 中各出现一次，不得改名、
alias、parameterized 隐藏或只由同构 helper 假装覆盖：

1. `ruminationStartAndWorkAreAtomic`
2. `ruminationCrashIsAdoptedAndCompletesOnce`
3. `ruminationFailurePersistenceFailureRemainsRecoverable`
4. `ruminationCancelRejectsStaleResponse`
5. `legacyRuminatingRowGetsOneRepairWork`
6. `repeatedRuminationCommandReturnsExistingWork`
7. `ruminationCancelAndQueuedProjectionRollbackTogether`
8. `ruminationAttemptClosesExactlyOnce`
9. `ruminationWorkInputUsesCanonicalCapturedIdentityAndFirstTrace`
10. `ruminationSameKeyDifferentCapturedIdentityConflictsWithoutResolution`
11. `ruminationTerminalRetryCreatesReplacementWhileActiveReplayReusesWork`
12. `ruminationCapturedProfileAndModelIgnoreDefaultDrift`
13. `ruminationClaimResolutionFailureMatrixIsStableSafeAndFailClosed`
14. `ruminationResolverNeverFallsBackToCurrentDefaultOrCompanion`
15. `ruminationTransientFailureRetriesAtFiveThirtyOneTwentyThenTerminates`
16. `ruminationDeterministicFailureDoesNotRetry`
17. `ruminationTerminalFailureAndProjectionCommitOrRollbackTogether`
18. `ruminationSuccessResultProjectionAndWorkCommitOrRollbackTogether`
19. `ruminationLeaseRenewalAllowsOnlyLatestClaimToCommit`
20. `ruminationTerminalCommitFailureRetainsProposalAndDoesNotRecallProvider`
21. `ruminationProcessRestartMayRecallProviderButCommitsOneResultAndTerminal`
22. `ruminationEmergencyHaltCancelsWorkAndQueuesProjectionAtomically`
23. `ruminationEmergencyHaltRejectsClaimResolveAndProviderDispatch`
24. `ruminationLateProviderResponseCannotOverrideEmergencyHalt`
25. `ruminationResumeDoesNotReviveCanceledWork`
26. `ruminationWaitUntilIdleIncludesDueRuminationAndIgnoresFutureRetry`
27. `ruminationLivePhaseEventsAreOwnedOrderedAndProcessLocal`
28. `legacyRuminationWithoutResolvableRuntimeFailsSafelyExactlyOnce`
29. `ruminationSanitizesPersistedAndVisibleDiagnostics`
30. `ruminationInvalidOutputIsDeterministicAndPreservesSource`
31. `ruminationProviderUsesNoToolsAndProducesOneCanonicalResult`
32. `singleOrchestratorSupervisorOwnsPlanningAndRuminationLifecycle`
33. `ruminationAdapterDelegatesStartRetryCancelWithoutUnownedTask`
34. `ruminationUnknownRestartRendersRecoveringWithoutInventingReading`
35. `ruminationPhaseProjectionUsesOnlyMatchingSupervisorEvents`
36. `genericDurableWorkAPIsSealRuminationWithExactPriority`
37. `supervisedWorkPumpIsGlobalFIFOWithoutPlanningRegression`
38. `ruminationStartupRemainsSuppressedUntilOrchestratorActivation`
39. `legacyRuminationRepairCoversValidHaltedAndEveryTerminalReason`
40. `ruminationUsageIsExactOrFailsBeforeAccounting`
41. `activeRuminationFencesDiscardDeleteAndArchiveRaces`

R20已冻结且R21原样继承五个deterministic-time exact names；同一次未过滤、失败不重跑的权威
`swift run RunTests`必须让上述41项与下列5项各discovery/PASS一次，机械形成46/46
subset audit，但不得运行`--filter`或用subset替代整个full suite全绿：

42. `slowActiveStreamDoesNotIdleTimeout`
43. `turnTimeoutRetriesOnceThenBlocks`
44. `timeoutThenSuccessDoesNotAccumulate`
45. `cancelWinsOverIdleTimeout`
46. `turnCompletesUnderTimeout`

五项语义精确来自Stage §28.7.3并由§28.8继承：总逻辑时长大于timeout但每段小于timeout时零retry；
两次armed deadline只产生一次timeout retry并blocked；timeoutCount按turn重置；armed后
先cancel并等待cancellation barrier确认waiter移除/恢复，再advance超过deadline，覆盖
cancel-before-register与register-before-cancel exactly-once且不宣称simultaneous tie；
零advance success取消watchdog且零waiter。
controlled provider不得`Task.sleep`，event acknowledgment须发生在真实`beat`之后才
advance，并以barrier避开exact-deadline race。

这 41 项的 required assertions 不以名字替代内容：

- input exact keys/canonical bytes/hash、normal/legacy key与trace、generation/attempt、
  replay/conflict、preflight zero-write、resolver exact matrix/default drift；
- #1/#6/#11/#22/#33/#34/#35共同锁normal/failed-user-retry `.inserted` resulting
  queued attempt0 exact `version=1` identity、同actor turn reserve+global claim barrier、
  delivery-before-claim/conditional-kick、existing pump零DB claim/零跨kind skip、
  preparation-replay绕过resolver/Store且两种replay origin只按workId等待original
  in-flight并在delivered/restart时零第二event、目标Camp snapshot load/ready先于
  command enable且failure保持disabled/显式失败、start `V`→cancel/halt `V+1`与rollback/
  conflict零barrier/reserve/sink/kick；AppStore lifetime-held single-writer lock
  先于唯一production DB open、second-owner fail-fast/release test与两个lock文件
  byte-identical；
- generic API public/internal 全封闭、mixed-kind error priority、read-only allowed；
- one Supervisor、global FIFO/no starvation、planning-only order、pending proposal不重呼；
- startup exact order、activation前零 dispatch、legacy 8-cell mode×snapshot表、
  mode优先级/restart/resume、halt/resume/shutdown/fatal/late response；
- provider恰好一 turn、tools empty、0/multi-turn、usage negative/overflow/exact
  success/parser failure、opaque validated-turn、唯一parse、全 failure/retry
  matrix、safe diagnostics；
- success/result/event、transient/terminal failure/event、cancel/projection/CAS/rollback、
  resulting workVersion、full commit milestone、lease 与 attempt exact once；
- phase exact顺序、stale fence、recovering UI、Adapter/App owner/source sentinels；
- discard/delete/archive 的 status/work 两维 race fence。

其中四项 phase/legacy tests 的 exact subcases 再钉死为：

- #27：reading/extracting后，one-turn+usage validation完成才进入 awaited sink；
  organizing在线性化后、parser前出现。第一次与第二次 revalidation 分别逐项注入
  lifecycle/suppression/fatal/generation/token/workId/ingestion/actorAttempt/
  providerExited/pending proposal/current latestClaim/durable mode/work/kind/
  aggregate/Camp/item/durableAttempt/version/lease owner/expiry loss；每格都必须抛 exact
  `RuminationPreParseAuthorizationLostError` 并由 owned task 专门 catch，zero
  parse、zero `RuminationAttemptFailure`、zero retry/failure/pending-or-terminal
  proposal/domain event/business write。每格在 throw/task cancel/owner return前
  都await同一 exact identity的 exactly-once invalidation；每轮`fatal`格只能复用
  unique global-fatal owner的`.globalFatal` first-winner delivery，其余格使用
  `.controlLoss`。第一次loss是zero organizing并清已有reading/extracting，第二次
  清已线性化organizing。
  断言 reentrant重复invalidator只有一次sink delivery、first-safe-reason wins、
  cancellation不能跳过、paused set期间control/fatal reentry必须
  revoke→wait set return→invalidate、invalidate后旧identity正向set不能复活；无
  unowned Task。再在同一test内覆盖per-identity coordinator两向race：
  projection-first暂停sink时later control/global phase只等待、matching commit满足
  clear且零第二phase sink；phase-first暂停sink时later真实commit等待后仍发一次
  refresh、typed optional clear=nil；两向sink最大并发数为1且无deadlock。
- #31：`produceValidatedTurn`是唯一 `streamTurn` callsite且每attempt一次、tools
  empty、0/multi-turn拒绝、usage在opaque turn构造前验证；
  `parseValidatedTurn`只解析该 fileprivate text一次并复用exact usage，provider
  调用数不增加。
- #35：对 #27 全部 expected-loss 格逐项证明只有 persisted active
  workId/attempt 可见，registry零泄漏且迟到 phase不可见。先覆盖queued normal
  start与failed user retry的`.inserted`：resulting work必须queued attempt0并使用
  exact `version=1`；Store return后第一次await/reentrancy前reserve full identity+
  global claim barrier。暂停sink时existing pump/timer/concurrent kick全部零DB claim
  且不能跳过rumination去claim planning；delivery后release、重读mode/work，仅
  running+active才kick。preparation-replay绕过resolver/Store start；concurrent
  transaction `.replayed`与其汇入同一branch，只按workId等待original in-flight，
  禁止从current attempt/version构造identity；delivered后或restart无waiter时零等待/
  零第二sink/event。restart必须先成功加载目标Camp persisted snapshot并标记ready，
  才enable command并显示recovering；load failure保持disabled/显式失败；同一
  state root的第二production owner必须在DB open前由lock fail-fast，release后
  replacement可取得锁。start
  rollback/throw/preflight/conflict为零barrier/reserve/sink/kick；
  sink暂停时cancel/halt更高version严格排在start后，start恢复零复活/claim。
  live与phase-less两组
  success、deterministic/exhausted failure、transient retry、actual user cancel都
  必须由Store返回resulting work/version并在commit后恰好一次full
  `.projectionCommitted`；rollback/throw/no-active固定零reservation/sink/event。
  同phase identity的retry `V+1`后cancel `V+2`与retry `V+1`后halt cleanup `V+2`
  都产生两个递增refresh；exact `V+1` duplicate第二sink/event为零但不吞`V+2`，
  unseen lower或same-version/different-identity在sink前fail-fast。并在第一次/
  第二次 `validateRuminationPhaseOwnership` 分别注入 DB read failure 与 invariant
  corruption，逐格必须 latch global fatal、zero parse，且不得进入 provider
  failure或 `RuminationAttemptFailure`、retry/pending-or-terminal proposal/domain
  event/business write；两轮都在 fatal return与task cancellation前await sorted
  exactly-once `.invalidate(.phase(identity:reason:.globalFatal))`，durable rows
  保持逐字不变。emergency halt逐步断言sorted pre-clear→cancel tasks→persist
  halted→planning cleanup→rumination cleanup返回actual sorted commits→逐个
  projection refresh→didCommit/`haltStateChanged`→return；persist/cleanup failure
  不为未commit row发milestone，queued attempt0 commit合法而no-active不能伪造，
  `haltStateChanged`不能代替refresh。逐项断言Orchestrator full-commit receipt与
  per-work monotonic version，以及exact/empty/tombstoned/different-newer registry：
  exact matching remove+tombstone并typed optional `.some(identity)`；其余registry
  不变、optional nil但commit refresh仍恰好一次。App phase event先用同一DB
  snapshot核对item+active running exact identity，change按typed exact optional
  clear且always serial reload；old version/new generation只reload，background Camp
  不切selected Camp。restart empty registry/tombstone也recovering，old positive
  set不能revive。
- #39：穷尽8-cell表，逐格断言input类型与适用时的terminalCode、work/attempt/
  item/error/domain-event、resolver/credential/provider调用数、restart第二
  work/event=0与resume不复活；running+valid是normal input且没有terminalCode；
  三个halted+invalid必须使用emergency-halt而非snapshot reason。

R13只关闭 implementation coverage audit发现的测试可达性缺口，不改变生产语义。
唯一seam位于`DurableWorkSupervisor.swift` matching `#if DEBUG`：

- `A2RuminationAuthorizationCheckpointForTesting` exact cases：
  `first|second`；
- `A2RuminationAuthorizationLossForTesting` exact cases：
  `lifecycle|suppression|fatal|generation|token|workId|ingestion|actorAttempt|
  providerExited|pendingProposal|latestClaim|durableMode|durableWork|durableKind|
  durableAggregate|durableCamp|durableItem|durableAttempt|durableVersion|
  durableLeaseOwner|durableExpiry|durableReadFailure|durableInvariantCorruption`；
- `A2RuminationAuthorizationScenarioForTesting`只允许
  `.inject(checkpoint:loss:)`；唯一package arm API为
  `armA2RuminationAuthorizationScenarioForTesting(_:identity:)`。

Scenario不接String/custom payload。Supervisor最多single armed；arm只接valid exact
`RuminationPhaseIdentity`，并要求enabled/running/unsuppressed/noFatal、当前
already-owned exact rumination/open attempt/coordinator，内部捕获token/generation，
拒绝重复/stale/non-owned。不得接Database/AppDatabase/path/provider/token/raw row/
Error/closure。private storage、arm、唯一consume helper和两个caller全部位于
matching `#if DEBUG`；first caller在首轮真实actor gate+真实DB validator均成功后、
organizing前，second caller在awaited organizing后、第二轮两项真实gate均成功后、
service lookup/parse前。matching consume先原子清storage再注入，wrong identity/
checkpoint不消费。

seam不得修改OwnedEntry/durable state、直接Store/validator/invalidator/fatal
owner、构造proposal/commit/result、调用provider/parser、发sink/event或返回成功；
consume只在真实gates成功后把closed loss抛入既有catch。该catch对
`fatal|durableReadFailure|durableInvariantCorruption`只await唯一async global-fatal
owner，其余20格只走typed control-loss owner。#27/#35以fresh
isolated DB+Supervisor逐项跑2×23=46格，actorAttempt与durableAttempt不得合并，
逐格证明one-shot、rows byte-identical、zero parse/failure/accounting/business
write与exact invalidation/visibility。

#31在既有名字内用`PlanningTestFixtures.uniqueFunction`锁
`produceValidatedTurn`与`parseValidatedTurn`各自唯一production Supervisor
callsite、前后ownership/usage顺序与每attempt provider一次；#40经Supervisor真实
provider→opaque turn→handler→Store端到端证明valid usage exact一次进入completed
payload/result，negative/invalid usage在parse/accounting前变成
`rumination_usage_invalid`且failure payload `usage=null`、零result/completed event；
#41以隔离fixture分别覆盖status-only/work-only/neither三维：前两维中Feed discard
与Camp archive动态零写拒绝，Adapter delete用真实unique brace-enclosed transaction
owner证明两维检查均在mutation前；neither维必须允许真实合法操作，防止永拒伪绿。
不得新增test name；41/41 names、13+2 allowlist、
schema/migration/DDL/EventKind、callback/KernelEvent、target/package graph保持不变。

Core ledger/Supervisor/resolver/race tests 归 `DurableWorkTests.swift`；既有 service、
downstream、App source/UI tests 归 `CodingRanchTests.swift`。TestSuite 不新增
AgentLoopApp dependency；UI ownership与ordering用 fail-fast source-range parser
和 isolated preview 共同证明，禁止只测复制的 helper。

#### A2 验证、matrix 与隔离 preview

- A2 migration row见 §10；schema 仍为 durable v12，必须跑
  fresh/v7/v8/v9/v10/v11/v12-durable 的 SQLite 3.51/3.52 literal + linked real
  GRDB aggregate matrix。runner、DDL、fixtures、verdict/count 与 target graph
  byte-identical；script 只允许 R12-A frozen Stage hash value。
- R21只在Review21批准及后续四hash执行授权后运行`swift run RunTests`、
  `swift build --product AgentLoopApp`、
  `swift build -c release --target AgentLoopCore`、
  `swift build -c release --target AgentLoopTestSuite`、双 matrix、
  `git diff --check` 与 status/hash manifests。Supervisor/Orchestrator/App/
  DurableWorkStore 被修改，所以 A1b 的完整 release/source/DEBUG seam gates必须
  原样重跑，不能只跑 A2 tests。
- A2 source gates至少 fail-fast 证明：production
  `DurableWorkSupervisor(` 精确一处且只在 Orchestrator；App/Adapter 不出现
  `RuminationService(db:`、旧 `process/start` owner、provider construction、
  `try? await` 或 unowned rumination Task；RuminationService 无旧 public bypass、
  无 `try? fail`，`streamTurn`只存在于`produceValidatedTurn`，raw turn不可由
  Supervisor/test读取，production `produceValidatedTurn` 与
  `parseValidatedTurn` callsite各精确一处且都在Supervisor，
  `parseValidatedTurn`零provider；唯一 rumination callback是typed awaited
  phase-command sink且exact enum只有 set/invalidate，milestone cases只有
  phase/projectionCommitted；production不包Task/不走default no-op；Store terminal/
  retry/cancel返回resulting work version，halt cleanup返回sorted actual commits；
  specialized Store start只有Supervisor callsite并返回`DurableWorkEnqueueResult`，
  Orchestrator只是façade；preparation-replay绕过resolver/Store，transaction replay
  汇入同一workId branch且两者零synthetic milestone；
  无 `?? .reading`；Adapter只delegate且completion零refresh；phase只接受matching
  work/attempt；App live map保存identity+phase、单listener直接await handler；
  recovering exact文案存在；目标Camp snapshot ready前command disabled/load failure
  显式；production无planning-only lifecycle bypass。source/hash gate还须证明
  `StateDirectoryLock.swift`与`SupportTests.swift`为冻结hash且不进13+2；
  AppStore `private let stateDirectoryLock` lifetime-held，same-root lock acquisition
  先于production唯一`AppDatabase(path:)`；lock继续使用
  `flock(LOCK_EX|LOCK_NB)`、`EACCES|EAGAIN` fail-fast和deinit unlock/close，既有
  `stateDirectoryLockRejectsSecondFileDescriptionAndReleases`在完整RunTests全绿。
- #27/#35 的 source-range/order gate 必须解析真实
  `handleValidatedRuminationTurn`、owned provider-task catch、validator、唯一
  invalidator、global fatal/control owners、Orchestrator registry handler与App
  event consumer的 enclosing ranges，证明两轮 actor gate 同序为
  lifecycle→suppression→fatal→generation→token→workId→ingestion→attempt→
  providerExited→pending proposal→读取当前 latestClaim，再同序调用 validator；
  durable graph gate 同序为 durable mode→work→kind→aggregate→Camp→item→
  attempt→version→lease owner→expiry。还必须证明 control signal 专门 catch 位于
  failure mapper之前/之外，DB/invariant error只进入唯一 async global fatal；
  所有 fatal writers/`.fatal` classification/latch wrappers/revoke-all paths均
  route该owner或mutation前证明零rumination；capture identities→revoke set→mark
  invalidation→await registered set-in-flight→await sorted invalidate→cancel
  tasks/return的call order成立。gate还枚举全部production milestone callsite，锁
  一个callback、unique exactly-once phase invalidator、unique projection
  publisher，证明phase/projection分别只经各自owner且无direct sink/event bypass；
  commit caller在第一次await前reserve、
  rollback零reserve、per-identity coordinator使phase/projection sink最大并发1且
  commit-first/phase-first无死锁；start exact order必须是Store transaction return→
  validate exact kind/aggregate/ingestion+queued attempt0/`version=1`→
  reserve full identity+register
  process-local global-claim barrier（第一次await/reentrancy前）→await delivery→
  release barrier→re-read mode/work→conditional kick→return；所有pump/timer/kick/
  global claim入口在barrier期间零DB claim/零跨kind skip。两种replay origin汇入同一
  workId waiter/conditional-kick branch，禁止identity construction/direct event/
  reload，delivered/restart零第二event；rollback/conflict零barrier/reserve/sink/kick。
  no Task/cancellation early return。halt顺序必须是
  sorted pre-clear→cancel tasks→persist→planning cleanup→rumination actual commits→
  projection deliveries→didCommit/haltStateChanged。Orchestrator锁full-commit
  receipt/per-work monotonic、exact-match remove→tombstone→typed optional emit、
  stale phase zero-event及empty/tombstoned/new-generation nil refresh；App锁
  same-snapshot phase reconcile、typed exact clear、always-reload FIFO、old version
  只reload、background Camp不导航、目标Camp load/ready后才enable command、
  load failure保持disabled/显式失败与restart-empty；AppStore lock-before-DB-open
  enclosing order、production DB opener count=1与lifetime ownership。
  substring/count-only、复制 helper或未锁 owner/call order必须 fail-fast。
- privacy gate同时扫描 DB/log/UI payload，测试 raw provider body、credential、
  account/OAuth/token 与 arbitrary Error 均不出现，只允许 frozen safe messages。
- R13 preview历史包含一次installed App normal-root访问，完整保留于旧evidence与
  Review01，不能由其后retry洗绿。Review14只因bundle provenance缺口退回R14，
  没有否定incident disposition。R15随后在BEGIN hash attestation false negative
  后永久停止；其boundary/hash-manifest/report、八个0-byte gate日志、缺失截图与
  containment时两个root的canonical-empty观察保持immutable，既不能补跑也不能作为
  R16/R18 root/artifact；current exact identities已为`ABSENT` absorbing tombstones，
  不得创建、删除、清理、复用或声称连续存在。
- R16在任何targeted/full test、build、matrix、source、bundle或preview命令前，
  由reviewed driver进入pre-BEGIN；四anchors与110/110 manifest通过，但
  `pgrep rc=1`被全局`ERR` trap抢占。授权未消费、runtime paths/roots均未创建，
  当前caller不得重跑或补写证据。
- R17 driver、immutable Bash 3.2 probe与115-entry manifest已通过静态验证，但
  Review17判定`CHANGES REQUIRED — 0 P0 / 1 P1`：RanchArt exact-27/nonregular门
  位于授权消费后。R17 caller/BEGIN及后续命令均未运行，全部runtime paths/roots
  不存在；不得使用Review17或R17四hash链执行、补写或重跑。
- R18 reviewed driver/119-entry manifest/freeze与Review18保持immutable。Review18
  已判定`CHANGES REQUIRED — 0 P0 / 1 P1`：newline pathname transport可在stable
  contaminated tree上假绿。R18 caller/BEGIN及后续命令均未运行，全部runtime
  paths/roots不存在；不得使用R18四hash链执行、补写或重跑。
- 以下R19条目是其freeze时的historical procedure；实际执行只到full test并以651/652
  永久失败，未到达后续build/preview条目。R19在任何targeted/full test、build、matrix、
  source、bundle或preview命令前，
  只可由reviewed `evidence/r19-begin.sh`经`/usr/bin/env -i`与
  `/bin/bash --noprofile --norc`启动。driver先用静态`evidence/r19-entry.sha256`
  执行`/usr/bin/shasum --strict -c`。123/123 manifest、branch/HEAD、process、
  R19/R18/R17/R16 runtime path与root-glob absence、R15 exact ABSENT tombstones/
  App/screenshot全部通过后，single phase-aware RanchArt verifier以单一
  `find -P -print0 | inline Bash 3.2 read -r -d ''` pipeline无损枚举全部direct
  children，按actual basename bytes、27-slot seen与`-f && ! -L`证明exact set/
  count/type；完整drain并拒绝partial record，失败不raw输出pathname。该zero-write
  preflight必须成为授权消费前最后一个fallible precondition。成功后才可
  exclusive-create `evidence/r19-clean-boundary.log`并写
  `authorization_consumed=true`；创建其他runtime artifact/root前必须从filesystem
  重新调用同一verifier并写R19结构证据，随后独立重跑post-activation 123-entry
  strict manifest。旧RanchArt `1S+4C`被一个P替换，current core为
  `3P/3S/3C=9`，加root-glob C后driver total为`3P/3S/4C=10`；immutable
  `r17-bash32-probes.sh`保持不变。BEGIN只记录frozen inputs、
  `r19-dev-bundle-v1` recipe、planned roots与no-process，不读取/复用/删除现存
  `.build/AgentLoop.app`。
- App debug build完成后、任何launch前，必须依leaf §11顺序写
  `POST_BUILD→PRE_SIGN→LAUNCH_READY`：记录SwiftPM executable/resource hashes；
  证明unsigned copy与build executable逐byte相等、source/generated/copied
  RanchArt 27-file manifests相等、inline Info.plist hash精确；只ad-hoc sign一次，
  strict verify后记录post-sign executable hash/UUID/CDHash与signed bundle
  manifest。codesign改变Mach-O bytes，post-sign hash不得与build hash比较，但UUID
  必须相同。
- bootstrap与cold start只可direct exec同一LAUNCH_READY full path/hash，PID取`$!`，
  UI只按path/PID绑定；两次顺序且零重叠，cold start禁止rebuild/re-copy/rewrite
  plist/re-sign。禁止`open`、display name、bundle id、frontmost/Dock/
  NSWorkspace/LaunchServices、`scripts/run-app.sh`与`scripts/package-app.sh`。
  bootstrap退出后只向isolated DB写non-sensitive synthetic`.ruminating` fixture；
  同root cold start须证明exact`正在恢复`、normal open count=0、preview mode零
  provider dispatch，最终own PID/child无残留。
- R19 boundary内任何static attestation/preflight/post-activation re-read/test/build/
  matrix/source失败、
  normal-root access、第二App、
  wrong/stale bundle、source/resource/plist/copy/signature/UUID/manifest drift、
  wrong path/env/PID、LAUNCH_READY后重建/重签、post-quit UI call或证据缺口都使
  整个invocation永久invalid并立即停止；不得在同一boundary换root、修补、retry或
  覆盖负证据，必须取得新的plan-level授权。

#### Review、acceptance 与停止条件

- Review19已批准plan，R19获四hash执行授权并到达BEGIN；41/41 targeted PASS不能覆盖
  authoritative full RunTests 651/652。R19 11个artifact、缺失screenshot、两个exact
  empty roots与zero-product/test-drift事实全部immutable，R19不得重跑或继续未开始门。
- Review20已批准并获四hash执行授权；R20唯一full 652/652、同log 46/46、debug build与
  LAUNCH_READY均通过，但release Core `--product`因automatic-product fallback/default
  graph触发DEBUG caller/callee配置错配。R20永久`REJECTED_CONTAMINATED`，后续门未运行，
  两个final source bytes、11 artifacts、缺失screenshot、empty state root与含signed App的
  bundle parent全部immutable。
- R21 planner唯一同步六个canonical/control surfaces，并新增
  `evidence/r21-begin.sh`、`evidence/r21-entry.sha256`与
  `evidence/plan-freeze-r21.md`。下一职责隔离plan reviewer只写
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/21-p1-plan-review.md`。
  Review21必须核对Stage §28.8与本Plan §18 R21节全部exact identities、155/155 entry、
  R20旧manifest exact-eight/132 preservation、完整R20 evidence/root/App、Core immutable、
  TestSuite one-file three-guard exception、strip-to-R20 hash proof、target-exact release
  commands、四object release-zero/debug-positive symbol gates、fresh R21 names、
  phase-aware 155→154+1 delta合同、owner separation与Open Questions。
- Review21达到`APPROVED — 0 P0 / 0 P1`只允许请求后续新用户turn按
  `freeze, Review21, driver, manifest`顺序给出四个final SHA-256。此前不得实施guard或
  运行任何门。获授权后只运行一次未过滤`swift run RunTests`；失败永久拒绝且不得重跑。
  full全绿后才从同一log机械生成46/46 subset audit，不执行`--filter`。全部R21 gates/
  END完成后，新的implementation reviewer只写
  `p1-a2-durable-rumination/reviews/02-p1-a2-review.md`；其零P0/P1后acceptance owner才可
  写A2`acceptance.md`，并同时披露R13、R15–R18、R19 651/652与R20 release失败历史。A2 acceptance前
  不得进入A3。

### 3.4 P1-A3：Candidate 原子转换

#### 允许文件

- `Sources/AgentLoopCore/Product/MissionDraftFactory.swift`
- `Sources/AgentLoopCore/Work/DurableWork.swift`
- `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift`
- `Sources/AgentLoopCore/Database/DurableWorkStore.swift`
- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
- `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift`
- `Sources/AgentLoopTestSuite/CodingRanchTests.swift`
- `Sources/AgentLoopTestSuite/DurablePlanningTests.swift`

#### 实施

1. `PlanningEntryCoordinator.startCandidate` 只委托唯一
   `convertCandidateAndEnqueuePlanning`，删除现有
   `existingMissionId → Orchestrator.startMission → linkConverted` 两步路由；App 只保留
   首次 `await` 前 capture 与 Coordinator delegate。
2. 输入：draft、cow ID、workspace、budget、autonomy、planner model、runtime profile、trace ID。
3. transaction 校验 active residency 的接缝先保留为 closure，P1-E 换成正式 store；P1-A 只验证 Cow 与 Camp 一致的当前 `companion.campId`，`nil` 不授权。
4. transaction 创建 Mission/Squad/planning work、更新 candidate、写事件；重放返回原 Mission + work。
5. 删除或降为 `internal` 的 `linkConverted`；App 不得调用。

#### 测试

- `candidateConversionRollsBackWhenWorkInsertFails`
- `candidateConversionReplayReturnsOneMission`
- `candidateConversionNeverLeavesUnlinkedMission`
- `candidateWithWrongCampCowFailsBeforeWrites`

### 3.5 P1-A4：Schedule Fire Evaluation/Commit

#### 允许文件

- `Sources/AgentLoopCore/Database/ScheduleStore.swift`
- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopCore/Work/DurableWork.swift`
- `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift`
- `Sources/AgentLoopCore/Database/DurableWorkStore.swift`
- `Sources/AgentLoopApp/MissionScheduler.swift`
- `Sources/AgentLoopTestSuite/ScheduleTests.swift`
- `Sources/AgentLoopTestSuite/DatabaseTests.swift`

#### 实施

1. 追加独立 migration `v12-p1-schedule-fire`，严格实现 stage spec §18.2 的
   `schedule_fire`（含 F2 预留的 nullable `redactedAt` 与 exact CHECK）、
   `schedule_evaluation_cursor`、partial unique/index/check；
   删除未使用的 intended 状态。
2. 删除 `claimScheduleFire` 及其全部调用；新代码只允许使用原子 `startScheduledMission`。
3. 新增 `startScheduledMission(scheduleId:scheduledAt:slotKey:plannerModel:runtimeProfileId:traceId:)`：
   - 在同一 write transaction 重读并校验 schedule/template/camp/cows/budget/autonomy；
   - duplicate 原始 `(scheduleId,slotKey)` 返回已存在 fire；
   - 校验失败写 failed fire + `schedule_missed` + evaluation cursor，不建
     Mission/work，不更新 `lastFiredAt`；
   - 成功创建 Mission/Squad/planning work，写 started fire +
     `schedule_fired`，更新 cursor，最后更新 `lastFiredAt`。
4. due scan 以 `schedule_evaluation_cursor.lastEvaluatedScheduledAt/slotKey` 为
   消费游标；failed slot 永久 missed，不自动重试、不造成 spin。
5. 新增
   `replayMissedScheduleFire(originalFireId:replayIdempotencyKey:
   replayPayloadHash:plannerModel:runtimeProfileId:traceId:)`。只允许引用 failed
   original；同 key 同 payload 返回原 replay，异 payload conflict；重放不改 cursor
   或 `lastFiredAt`。
6. slotKey 由 `ScheduleMath` 根据 schedule frequency、calendar identifier、time-zone identifier 和计划本地 slot 生成稳定字符串；DST repeated slot 必须区分实际 instant，spring-forward 使用已确定的 next-valid 结果。
7. `MissionScheduler.fire` transaction 成功后只 kick supervisor；broadcast / notification 独立错误，不反写 fire failed。

#### 测试

- `scheduleFireMigrationMatrixAndExactDDL`
- `scheduleValidationFailureAdvancesEvaluationCursorButNotLastFiredAt`
- `failedSlotDoesNotSpinOrAutoRetryAfterConfigurationFix`
- `explicitReplayUsesNewIdempotencyKeyAndDoesNotMoveCursor`
- `replaySamePayloadReturnsSameFireButConflictFails`
- `scheduleStartedTransactionSurvivesRestartBeforePlannerKick`
- `sameSlotReplayReturnsSameMission`
- `broadcastFailureDoesNotRewriteStartedFire`
- `scheduleFireDSTSlotKeysAreStable`
- `scheduleFireSchemaReservesRedactionWithoutAllowingOrdinaryMutation`
- 现有 schedule CRUD/math tests 保持全绿。

### 3.6 P1-A 验收

- R-01…R-04 全部关闭；
- A1a、A1b、A2、A3、A4 各自有独立 Review/acceptance；
- 用注入 gate 证明 crash、projection-atomic cancel、retry、lease renewal、
  stale response、idempotency conflict 和 terminal rollback；
- 保存一次隔离 preview 的 planning/rumination 可恢复证据；
- 独立 Review 不得留下 P0/P1。

## 4. P1-B — 错误可见性与应用层接缝

### 4.1 允许文件

- `Package.swift`
- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
- `Sources/AgentLoopCore/Mcp/McpServerManager.swift`
- `Sources/AgentLoopCore/Database/KnowledgeStore.swift`
- `Sources/AgentLoopCore/Knowledge/MemoryDistillService.swift`
- `Sources/AgentLoopCore/Rumination/RuminationService.swift`
- `Sources/AgentLoopCore/Support/KeychainStore.swift`
- `Sources/AgentLoopApp/AppStore.swift`
- `Sources/AgentLoopApp/McpStore.swift`
- `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift`
- `Sources/AgentLoopApp/CodingRanchContracts.swift`
- `Sources/AgentLoopApp/Views/RootView.swift`
- `Sources/AgentLoopApp/Views/RuntimeProfileViews.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchHomeView.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/RuminationViews.swift`
- `Sources/AgentLoopApp/Views/Components/McpStationSection.swift`
- `Sources/AgentLoopApp/Views/Components/NoteListPane.swift`
- 新 `Sources/AgentLoopCore/Observability/FailureRecord.swift`
- 新 `Sources/AgentLoopCore/Observability/FailureReporter.swift`
- 新 `Sources/AgentLoopCore/Observability/ContextDependencyLoader.swift`
- 新 `Sources/AgentLoopApplication/WorkflowLoadState.swift`
- 新 `Sources/AgentLoopApplication/MissionWorkflowController.swift`
- 新 `Sources/AgentLoopApplication/InputWorkflowController.swift`
- 新 `Sources/AgentLoopApplication/RuntimeProfileWorkflowController.swift`
- 新 `Sources/AgentLoopApplication/McpWorkflowController.swift`
- 新 `Sources/AgentLoopTestSuite/ApplicationWorkflowTests.swift`
- 新 `Sources/AgentLoopTestSuite/FailureVisibilityTests.swift`
- `Sources/AgentLoopTestSuite/McpTests.swift`
- `Sources/AgentLoopTestSuite/KnowledgeStoreTests.swift`
- `Sources/AgentLoopTestSuite/KnowledgeGoldenPathTests.swift`
- `Sources/AgentLoopTestSuite/MemoryDistillTests.swift`
- `Sources/AgentLoopTestSuite/RuntimeProfileTests.swift`

### 4.2 Target 与依赖

1. 新建 `AgentLoopApplication` library target，只依赖 Core。
2. `AgentLoopApp` 依赖 Core + Application。
3. `AgentLoopTestSuite` 依赖 Core + Application。
4. Application target 不 import SwiftUI、AppKit；系统 UI side effect 用 protocol 注入。

### 4.3 Failure API

新增：

- `FailureRecord` / `FailureSeverity`
- `OperationTrace`
- `FailureReporter`
- `WorkflowLoadState<Value>`：`idle/loading/loaded/failed(UserVisibleFailure)`
- `UserVisibleFailure(traceId, operation, message)`
- `ContextDependencyPolicy`
- `ContextDependencyLoader`

migration `v13-p1-observability` 严格按 stage spec §18.3 建表、索引与 check；
`failure_record` 必须显式 `scopeKind=camp|global` + nullable exact campId，
Camp row含 deletion redacted shape；`context_degradation` 含 detail redacted shape，
不得靠 scopeType字符串猜 Camp；
该 slice 运行 §10 的 through-v13 predecessor matrix。

`FailureReporter.capture`：

- 接收预先创建的 `OperationTrace`；
- 分类 typed errors；
- 净化并截断；
- 尝试落 DB；
- 同 trace ID 写 `os.Logger`；
- 返回 UserVisibleFailure。

### 4.4 应用层抽取

只抽取 P1 消费者：

- `MissionWorkflowController`：Mission load/start/cancel/reload/accept 接缝；
- `InputWorkflowController`：Feed/Rumination load/start/cancel；
- `RuntimeProfileWorkflowController`：profile + Keychain presence/read/write；
- `McpWorkflowController`：registry、secret、enabled state；
- `AcceptanceWorkflowController` 在 P1-D 补全。

AppStore 保持 composition root 和 SwiftUI projection；控制器返回 typed state，AppStore 不再把错误变成空集合。

### 4.5 `try?` inventory

生成子任务产物 `try-question-mark-inventory.md`，逐行列：

- 文件/行；
- 操作；
- 当前 fallback；
- 分类：business / parse / cleanup；
- 新行为；
- 测试。

必须覆盖 P0 R-05/R-06 列出的 AppStore、McpStore、Orchestrator、Rumination 和 CodingRanchStoreAdapter。

实现后验证：

```bash
rg -n 'try\\?' Sources/AgentLoopApp/AppStore.swift Sources/AgentLoopApp/McpStore.swift \
  Sources/AgentLoopCore/Kernel/Orchestrator.swift Sources/AgentLoopApp/CodingRanchStoreAdapter.swift
```

每个残留都必须在 inventory 中属于 parse/cleanup 且有注释；business 类残留数必须为 0。

### 4.6 MCP / 知识

1. `McpServerManager.SecretProvider` 改为 `throws`，不存在与读取失败分开。
2. `assembledTools` / registry query 改为 throws 或 typed result，不返回伪装空列表。
3. `ContextDependencyLoader` 根据 OutcomeContract：
   - required 失败 → Card `.blocked(context_unavailable)` + failure/degradation；
   - optionalApproved 失败 → degradation event + 显式 missing marker。
4. legacy 最近笔记使用 optionalApproved；显式 toolsJson 的 MCP 使用 required。
5. MemoryDistill 的“无增量/模型 skip/失败”改为 enum：
   - `.noEligibleInput`
   - `.skipped`
   - `.created(record)`
   - throw failure
   App 不再把失败展示成“没什么可记”。

### 4.7 测试

- DB read failure produces `.failed` with trace, not `.loaded([])`；
- Keychain not-found 是 absent，其他 OSStatus 是 failed；
- profile write/delete/reconcile failure 不显示成功；
- MCP registry failure blocks required dependency；
- optional MCP/knowledge failure creates degradation and continues；
- MemoryDistill provider / DB failure 与 skip 可区分；
- AppStore projection preserves prior loaded data while exposing refresh failure；
- Application target strict-concurrency build。

### 4.8 P1-B 验收

- R-05、R-06 关闭；
- R-07 只做消费者抽取，无全文件搬家；
- 注入失败的 preview UI 证据含 trace ID；
- tests/build/Review 全绿。

## 5. P1-C — Event、Input、Goal、Coach、Understanding

### 5.1 允许文件

- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopCore/Database/EventKind.swift`
- `Sources/AgentLoopCore/Work/DurableWork.swift`
- `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift`
- `Sources/AgentLoopCore/Database/DurableWorkStore.swift`
- 新：
  - `Sources/AgentLoopCore/Domain/CanonicalContractCoding.swift`
  - `Sources/AgentLoopCore/Domain/CommandEnvelope.swift`
  - `Sources/AgentLoopCore/Domain/DomainEvent.swift`
  - `Sources/AgentLoopCore/Domain/InputEnvelope.swift`
  - `Sources/AgentLoopCore/Domain/GoalController.swift`
  - `Sources/AgentLoopCore/Domain/CoachContracts.swift`
  - `Sources/AgentLoopCore/Domain/UnderstandingCard.swift`
  - `Sources/AgentLoopCore/Database/DomainEventStore.swift`
  - `Sources/AgentLoopCore/Database/InputGoalStore.swift`
  - `Sources/AgentLoopCore/Database/CoachUnderstandingStore.swift`
  - `Sources/AgentLoopCore/Work/InputParsingWorker.swift`
- `Sources/AgentLoopApplication/InputWorkflowController.swift`
- `Sources/AgentLoopApplication/LocalCaptureIdentity.swift`
- 新 tests：
  - `Sources/AgentLoopTestSuite/DomainEventContractTests.swift`
  - `Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift`
  - `Sources/AgentLoopTestSuite/GoalCoachContractTests.swift`
  - `Sources/AgentLoopTestSuite/ControlContractMigrationTests.swift`
- `Sources/AgentLoopTestSuite/DurableWorkTests.swift`

不修改 SwiftUI 流程。

### 5.2 Migration

追加 `v14-p1-control-contracts`，严格按 stage spec §18.4 建全部表、约束、索引和
append-only triggers；不得省略 `domain_command_receipt` 或 `goal_mission_link`。
`domain_command_receipt` 与 `domain_event` 在 v14 fence 尾部各自建立标准
UPDATE/DELETE pair，不能等 v16/F2 补装。
`inbox_message` 必须包含 sourceDevice/payload/error 的 exact
`rejected+camp_deleted+redactedAt` shape；command receipt/domain event/result从
出生即只允许 Camp-safe ID/hash/code/count，不能等待 F2 再擦正文。

迁移测试：

- 执行 §10 through-v14 的全部 predecessor fixtures；
- migrate 两次；
- 两张 append-only 表合法 insert，ordinary/no-op update 与 delete 均由各自
  introduction-time trigger 拒绝；
- duplicate aggregate version 失败；
- 单 aggregate command replay 返回旧 receipt，多 aggregate event ordinals 稳定；
- 同 command key 异 payload/eventCount conflict，且不得只追加一半 aggregate；
- 失败 migration 完整回滚。

### 5.3 CommandEnvelope

所有新领域命令接收：

- `idempotencyKey`
- actor type/id
- device ID
- correlation ID
- causation ID
- occurredAt

禁止 service 内自己假设 user actor。测试 helper 必须显式创建 user/system/coach actor。
`CommandEnvelopeV1` 是以上字段的完整 sealed value；command whole hash固定为
`CanonicalJSONV1({"envelope": envelope, "payload": typedPayload})`。envelope任一
字段/nullability变化都是 replay conflict。普通 user Ingestion删除还要求
actorType=user，actorId/deviceId/correlationId trimmed nonempty，causationId只能
NULL或 trimmed nonempty，occurredAt是 canonical UTC finite instant。
`CanonicalContractCoding` 只能是 typed DTO 到 A1a `CanonicalJSONV1` 的薄封装；
不得再实现、调用或 hash 第二套 JSONEncoder/JSONSerialization bytes。
`CampSafeCommandResultV1/CampSafeAuditPayloadV1` 使用 exact-key decoder并禁止
`actorRef/actorId/actorType/deviceId/accountId/accountIdentifier`；actor/device
identity只存在 sealed envelope和 `domain_event` 专列，不能复制进 append-only JSON。

### 5.4 Domain Event Store

提供 transaction-only：

- `executeCommand(receipt:orderedEvents:projectionMutations:outbox:database:)`
- `events(aggregateType:id:)`
- `applyInbox(envelope:handler:)`

`executeCommand` 先 insert-or-validate immutable receipt，再按稳定 ordinal 验证每个
aggregate expected version，写 projection/event/outbox/result；实际 event count 与
receipt 不同即回滚。command payload、resultJson 与 event payload/hash 全部复用
`CanonicalJSONV1`；event 必须有 non-null stable campId，payload/result 只用
CampSafe ID/hash/code/count 字段；event key 必须按 stage spec §8.1 公式派生。
每个 event的 actorType/id/deviceId/correlationId/causationId/occurredAt逐字段复制
CommandEnvelope，recordedAt由 owning Store生成；每个 event同 transaction插 exact
一个 initial pending `event_outbox`。P1-E specialized `IngestionDeletionStore` 是
该 command唯一 evidence/outbox writer，但只能逐字复用本节 envelope/safe JSON/
outbox合同，不得暴露或新增 generic callback。

### 5.5 Input Store

命令：

- `captureAndEnqueueParsing`
- `commitParseResult(claim:result:)`
- `recordParseFailure(claim:failure:)`
- `requeueParsing`
- `cancelParsingAndDelete`
- `requestCampAssignment`
- `recordCampAmbiguity`
- `assignCamp`
- `archive`
- `markCoaching`
- `convertToGoal`
- `requestDeletion`
- `completeDeletion`

每条只实现 stage spec 合法转移。`captureAndEnqueueParsing` 同事务写 Input
`captured` 与 inputParsing work；没有 `parsing` projection。worker 使用通用
lease/retry/adoption，success/failure/cancel 与 Input 状态同事务。重复
idempotency 返回旧结果；同 key 异内容报 conflict。

`LocalCaptureIdentity` 用注入的 key-value store 保存一次生成的本机安装 UUID
（key 固定为 `agentloop.localCaptureInstallationId`），只作为 P1 来源审计 ID，
不冒充 P4 账号/设备身份；tests 使用内存 store。App 本机捕获时 author actor 固定为
`user:local-owner`，不写真实账号标识。

### 5.6 Goal / Coach / Understanding

`GoalController` 命令：

- `createFromInput`
- `openCoachSession`
- `recordQuestion`
- `answerQuestion`
- `proposeUnderstanding`
- `requestConfirmation`
- `confirmUnderstanding`
- `abandon`
- `fail`

硬门：

- session 同时只有一个 open question；
- Coach actor 不能 confirm；
- Understanding edit 创建新 version；
- `confirmUnderstanding` 只把 Goal 推到 ready；P1-C 不暴露 active/paused/achieved；
- cross-Camp ambiguity 未解决不能 create Goal；
- 所有写入同事务 event + outbox。

`activate(outcomeContractRef:)`、pause/resume/achieve 明确移到 P1-D；C 的
completion gate 到 ready 为止，不允许 fake OutcomeContract validator。

### 5.7 Compatibility

- 新建 `LegacyIngestionAdapter` 只读映射旧 ingestion 到 display，不写假 InputEnvelope。
- P1 不回填历史 Mission 的 Goal。
- 新领域 store 不从 `campId=nil` 推断 Camp。

### 5.8 Tests

覆盖每个状态转移的合法/非法矩阵、CAS、重复命令、hash 漂移、actor 权限、删除
tombstone、outbox/inbox idempotency、Coach restart 和 one-open-question；另加：

- `captureAndInputParsingWorkCommitAtomically`；
- `inputParsingCrashIsAdopted`；
- `inputParsingRetriesBoundedlyThenParseFailed`；
- `inputParsingCancelRejectsStaleResult`；
- `inputParsingTerminalMutationRollbackIsTotal`；
- `inputSchemaHasNoParseAttemptColumn`；
- `inputSchemaRejectsDeletedStatusWithActiveRetention`；
- `activeInputRequiresExactlyOneInlineOrPayloadRef`；
- `inputTombstoneRetainsOnlyExactIdentityHashAndTimes`；
- `inputTombstoneNullsDeviceConnectorAuthorBodyRefErrorAndParent`；
- `inputTombstoneForcesEmptyCandidatesUnspecifiedIntentLocalOnlyAndEqualDeleteTime`；
- `inputSchemaRejectsTombstoneRetentionWithLiveStatus`；
- `goalReadyDoesNotRequireV15Schema`。

### 5.9 P1-C 验收

- stage spec §8–§11 与 §18.4 全契约测试；
- Input parsing 没有不可恢复的业务 in-flight projection；
- Goal 到 ready 完整，active 明确等待 P1-D；
- Open Questions 仍为空；
- tests/build/Review 全绿。

## 6. P1-D — Outcome、Verification、Acceptance、Grant

### 6.1 允许文件

- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopCore/Database/Records.swift`
- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
- `Sources/AgentLoopCore/Tools/ApprovalGate.swift`
- `Sources/AgentLoopCore/Tools/ApprovalPolicy.swift`
- `Sources/AgentLoopCore/Tools/ToolExecutor.swift`
- `Sources/AgentLoopCore/Tools/BoardTools.swift`
- `Sources/AgentLoopCore/Tools/FileTools.swift`
- `Sources/AgentLoopCore/Tools/ShellTool.swift`
- `Sources/AgentLoopCore/Tools/WebFetchTool.swift`
- `Sources/AgentLoopCore/Mcp/McpToolBridge.swift`
- `Sources/AgentLoopCore/Database/DomainEventStore.swift`
- 新：
  - `Sources/AgentLoopCore/Domain/OutcomeContract.swift`
  - `Sources/AgentLoopCore/Domain/Outcome.swift`
  - `Sources/AgentLoopCore/Domain/Verification.swift`
  - `Sources/AgentLoopCore/Domain/Acceptance.swift`
  - `Sources/AgentLoopCore/Domain/ApprovalGrant.swift`
  - `Sources/AgentLoopCore/Database/OutcomeStore.swift`
  - `Sources/AgentLoopCore/Database/ApprovalGrantStore.swift`
  - `Sources/AgentLoopCore/Tools/ExternalOperationAdapter.swift`
  - `Sources/AgentLoopApplication/ExternalOperationWorkflowCoordinator.swift`
  - `Sources/AgentLoopApplication/AcceptanceWorkflowController.swift`
- `Sources/AgentLoopApp/AppStore.swift`
- `Sources/AgentLoopApp/CodingRanchContracts.swift`
- `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchLiveHosts.swift`
- tests：
  - `Sources/AgentLoopTestSuite/OutcomeContractTests.swift`
  - `Sources/AgentLoopTestSuite/VerificationContractTests.swift`
  - `Sources/AgentLoopTestSuite/AcceptanceWorkflowTests.swift`
  - `Sources/AgentLoopTestSuite/ApprovalGrantContractTests.swift`
  - `Sources/AgentLoopTestSuite/OrchestratorTests.swift`
  - `Sources/AgentLoopTestSuite/ApprovalGateTests.swift`
  - `Sources/AgentLoopTestSuite/ApprovalPolicyTests.swift`
  - `Sources/AgentLoopTestSuite/BoardToolsTests.swift`
  - `Sources/AgentLoopTestSuite/ToolExecutorTests.swift`

### 6.2 Migration

追加 `v15-p1-outcome-contracts`，逐字实现 stage spec §18.5：

- outcome_contract_version
- verification_requirement_group
- verification_requirement
- outcome
- outcome_version
- verification_record
- verification_result_head
- verification_invalidation
- acceptance_policy_version
- acceptance_record
- outcome_metric_credit
- approval_grant
- approval_grant_use
- external_operation_receipt

Verification / invalidation / Acceptance / receipt 各自在 v15 建立标准
UPDATE/DELETE pair；外键引用精确 version/hash；v15 同时建立
Verification/Acceptance/external receipt 的
`redactedAt` 与 exact redacted-shape CHECK，UPDATE 此时仍一律拒绝，v16 才替换为
finalizing-only trigger；对应三个 DELETE guard 与
`verification_invalidation` 两枚标准 guard 永久保留。执行 §10 through-v15 全
predecessor matrix，并对四张表分别验证合法 insert、ordinary/no-op UPDATE、DELETE。

### 6.3 OutcomeContract

命令：

- create draft；
- revise（new version）；
- activate；
- supersede；
- fulfill/cancel。

activate 检查 Understanding ref/hash 与 required deterministic verifier。Coding outcome 没 deterministic requirement 时拒绝激活。

同 slice 才把 `GoalController` 增加：

- `activate(outcomeContractRef:)`：confirmed Understanding 与 active exact Contract
  同 Goal 才 `ready -> active`；
- `pause/resume/achieve`；
- stage spec §19 的 `achieved -> active` system reopen。

`goal_mission_link.outcomeContract*` 在 activate/start Mission transaction 更新。

### 6.4 Outcome / Verification

命令：

- `recordInitialOutcome`：只在不存在 Outcome 且 linked Mission
  `executing|delivering` 时原子创建 head + immutable v1=`produced`
- `recordNewOutcomeVersion`：只从
  `returned|revoked|invalidated|verificationFailed|blocked` 创建 currentVersion+1
  并进入 `verificationPending`
- `beginVerification`
- `recordVerification`
- `invalidateVerification`
- `markDelivered`
- `returnOutcome`

任何 manifest/content hash 改变必须 `version + 1`。Verifier actor 独立性在 store 层校验。
不存在 `recordProducedVersion` alias；initial 与 subsequent command/key/hash
replay space 分离。

`recordVerification` 必须：

1. 引用 exact requirement ID/version/hash；
2. 明确 supersede current head；
3. 插 immutable record、CAS head、运行 stage spec §12.3 all/any reducer；
4. 原子更新 Outcome derived state 和 events。

duplicate command 返回旧 record；并发旧 head 失败。`markDelivered` 只允许
`DeliveryCoordinator(system:delivery:v1)`，transaction 内重跑 reducer。

确定性 runner：

- 新建 `DeterministicVerifier` protocol；
- P1 内置 `CommandExitVerifier`、`ArtifactHashVerifier`；
- command verifier 通过注入 ProcessRunner 测试，timeout/nonzero/missing output fail-closed；
- verifier 无 workspace write grant。

### 6.5 Acceptance

`AcceptanceWorkflowController.accept` 唯一顺序：

1. 读取精确 Outcome/Contract/Verification；
2. 验证 user 或 policy；
3. 单 transaction 插 Acceptance、改 Outcome/Goal/Mission projection、写 events、upsert metric credit；
4. transaction 返回成功；
5. AppStore 更新 state；
6. SwiftUI 才导航/庆祝。

`returned/revoked/invalidate` 同事务 reverse credit 与依赖失效 enqueue。

P1-D 实现 stage spec §19 对当前已存在表的 Outcome/Verification/Acceptance/
Goal/Mission/metric 转移，并写唯一 dependency-invalidation domain event。Memory/
Growth 表此时尚不存在，因此不存在可更新行；P1-E/F 分别把同一 transaction
coordinator 扩展为 Memory/Growth mutation，并重跑跨层 integration。不得用 runtime
optional no-op hook；表引入前 API 没有该参数，引入后参数为 required store。

修改 `CodingRanchLiveHosts`：禁止先切页再等待 `closeoutCurrentMission`。失败留在当前页，显示 trace ID。

### 6.6 Legacy UI 真实性

- `hasViewedArtifact` 改为显式 UI session event，不再由 `artifacts.isEmpty` 推断。
- `usedKnowledge`、`writtenBackNotes` 没有真实记录时保持 unknown/empty 并标未接通，不生成肯定文案。
- legacy Mission acceptance 不计新北极星 metric；新 Contract-linked Mission 才走新 Acceptance。
- 不自动把旧 Handoff 伪造成 independent Verification。

### 6.7 ApprovalGrant

- ApprovalGate 请求批准仍使用现有 user request UI；用户批准后按 explicit
  campId/cardId/toolId/inputHash 创建 single-use Grant；campId 必须由
  Card→Mission scope 重算并与命令一致；现有 `ApprovalToken.hash` 必须
  改为 `CanonicalJSONV1.sha256Hex(CanonicalJSONV1.encode(input))`；toolId 已是
  独立 scope 字段，不混入 inputHash，不能继续直接 hash JSONEncoder bytes；
- Grant creation 使用 typed `grantorActorType`；policy actor 必须由
  `ApprovalPolicy.swift` 的 immutable exact ID/version/hash registry 解析，不能只
  传自由文本 actorId；nonReplayable raw/Store 双层限制 user + maxUses=1；
- `ExternalOperationAdapter` descriptor 必须声明
  replaySafe/idempotencyKeyed/nonReplayable，并提供
  `start(idempotencyKey:)` 与 `reconcile(idempotencyKey:operationId:)`；
- `ApprovalGrantStore` 是唯一 transition owner；每个 typed API 都接受
  `useId + expectedVersion + commandIdempotencyKey`。新增
  `AdapterNoEffectAttestation`，只有 adapter authority 可构造/验证；
  `ExternalOperationWorkflowCoordinator` 是唯一 async owner，按
  DB intent commit → adapter call → typed receipt commit/recovery 执行；
  ApprovalGate/ToolExecutor/adapter 不直接写 use/receipt 表；
- 执行顺序固定为 reserve → adapter 调用前
  dispatching+usedCount+dispatchIntent receipt → external call → adapter 实际返回
  accepted/operation ID 后才写 accepted+adapterAccepted receipt → effect/noEffect
  receipt → succeeded/failed/released；
- crash recovery 按 stage spec §13；nonReplayable 进入 crashUnknown + urgent
  Attention command intent，在 P1-F1 Attention 表存在后接通持久 projection；D 阶段
  先写 domain event，不自动 replay；
- reserved 且无 dispatchIntent 才能安全 release；dispatchIntent 后到
  adapterAccepted 前是明确的 ambiguous window，nonReplayable 同样不得 release；
- 只有 `AdapterNoEffectAttestation` 可写唯一 noEffect receipt 并退还一次；
  user resolution 只允许 `succeeded|abandonedUnknown`，均保持 consumed、不可
  replay/refund；timeout/EOF/用户猜测不能 release；
- 拒绝写 decision，不创建 active grant；
- expired/revoked/mismatched hash fail-closed。

### 6.8 Tests

- `recordInitialOutcome` creates only v1 from Mission executing/delivering and replays；
- `recordNewOutcomeVersion` covers each
  returned/revoked/invalidated/verificationFailed/blocked source，increments once，
  invalidates old verification/memory/growth；initial/subsequent keys cannot alias；
- Outcome content change invalidates verification；
- two all requirements need two current passes；
- any group passes with one alternative but every group remains required；
- duplicate/superseding Verification only affects its exact requirement；
- one invalidated current requirement reopens verified/accepted projections；
- stale evidence/version/hash never satisfies reducer；
- verifier == producer 被拒；
- model-only Coding verification 不能通过；
- missing evidence/timeout/nonzero/hash drift fail-closed；
- accepted Outcome can return, verificationFailed/blocked can re-enter verification；
- every Outcome command rejects every from/to pair absent from §12.2；
- acceptance commit failure does not navigate or mark accepted；
- duplicate acceptance counts once；
- return/revoke/invalidate reverse credit；
- new version reaccept restores same credit，不重复；
- first onboarding always requires user before policy lookup；
- first outcomeType always requires user before policy lookup；
- subjective creation always requires user before policy lookup；
- public release always requires user before policy lookup；
- payment always requires user before policy lookup；
- deletion always requires user before policy lookup；
- external send always requires user before policy lookup；
- high/irreversible risk and unverified reducer always require user before policy lookup；
- Grant wrong capability/scope/time/hash rejected；
- non-user nonReplayable Grant rejected by Store and raw SQL fixture；
- malformed grantor actor/policy-ref tuple rejected；Camp deletion redaction preserves
  actor type only and removes actor/policy identifiers；
- adapter-confirmed no-effect releases and refunds exactly once；
- receipt key/hash/ordinal replay同内容返回、异内容 conflict；
- receipt phase/result/authority SQL matrix rejects every invalid tuple；
- dispatch/accept one-shot guards + one combined
  adapter-outcome-or-user-resolution raw-SQL terminal guard；
- reconciliationFailed may repeat only with increasing ordinal/new key；
- user cannot attest no-effect or refund；
- crashUnknown user succeeds or abandons to consumed `abandonedUnknown`；
- adapter no-effect vs user resolution CAS has exactly one winner；
- no-effect refund reducer preserves revoked/expired and only reactivates an otherwise
  valid underused Grant；
- no-effect vs revoke and no-effect vs expiry CAS races converge without resurrection
  or double decrement；
- late reconcile cannot alter succeeded/abandonedUnknown or refund；
- receipt UPDATE/DELETE triggers reject ordinary mutation；
- ExternalOperationWorkflowCoordinator is the only adapter-call owner；
- concurrent single-use claims only one wins。
- policy expiry/revocation fail closed，且 policy schema 不存在任何 hard-guard allow 位；
- crash immediately before dispatchIntent leaves reserved and releases without use；
- crash immediately after dispatchIntent makes nonReplayable crashUnknown；
- crash immediately before actual adapterAccepted receipt remains ambiguous；
- adapterAccepted receipt is impossible before adapter returns acceptance；
- crash immediately after adapterAccepted reconciles with exact operation ID；
- replaySafe/idempotencyKeyed dispatching/accepted recover with same key；
- crash after external success before local receipt converges to one succeeded use；
- nonReplayable crashUnknown stops for user and never auto-replays；
- stage spec §19 每条 command 的 Goal/Mission/Outcome/metric 原子 rollback test。

### 6.9 P1-D 验收

- R-08、R-09 关闭；
- 真实 UI 注入 acceptance DB failure 显示 trace 且不导航；
- tests/build/Review 全绿。

## 7. P1-E — Cow、Residency、Camp lifecycle schema 与 Memory

### 7.1 允许文件

- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopCore/Database/Records.swift`
- `Sources/AgentLoopCore/Database/EventKind.swift`
- `Sources/AgentLoopCore/Database/DurableWorkStore.swift`
- `Sources/AgentLoopCore/Database/KnowledgeStore.swift`
- `Sources/AgentLoopCore/Database/OutcomeStore.swift`
- `Sources/AgentLoopCore/Database/DomainEventStore.swift`
- `Sources/AgentLoopCore/Ingestion/IngestionRecords.swift`
- `Sources/AgentLoopCore/Ingestion/FeedService.swift`
- `Sources/AgentLoopCore/Rumination/RuminationService.swift`
- `Sources/AgentLoopCore/Rumination/RuminationMaterializer.swift`
- `Sources/AgentLoopCore/Product/ProductBootstrapService.swift`
- `Sources/AgentLoopCore/Product/NewcomerUnlockPolicy.swift`
- `Sources/AgentLoopCore/Product/CowTemplate.swift`
- `Sources/AgentLoopCore/Chat/GuideChatService.swift`
- `Sources/AgentLoopCore/Chat/ChatService.swift`
- `Sources/AgentLoopCore/Knowledge/MemoryDistillService.swift`
- `Sources/AgentLoopCore/Knowledge/Distiller.swift`
- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
- `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift`
- 新：
  - `Sources/AgentLoopCore/Domain/CowIdentity.swift`
  - `Sources/AgentLoopCore/Domain/CampResidency.swift`
  - `Sources/AgentLoopCore/Domain/CampBridge.swift`
  - `Sources/AgentLoopCore/Domain/MemoryRecord.swift`
  - `Sources/AgentLoopCore/Domain/IngestionDeletion.swift`
  - `Sources/AgentLoopCore/Database/CowResidencyStore.swift`
  - `Sources/AgentLoopCore/Database/MemoryRecordStore.swift`
  - `Sources/AgentLoopCore/Database/CampLifecycleStore.swift`
  - `Sources/AgentLoopCore/Database/IngestionDeletionStore.swift`
  - `Sources/AgentLoopCore/Database/ActiveIngestionDeletionSQLPermit.swift`
  - `Sources/AgentLoopCore/Database/LegacyContentScopeStore.swift`
  - `Sources/AgentLoopCore/Database/LegacyEventScopeResolver.swift`
  - `Sources/AgentLoopCore/Database/CampProviderDispatchStore.swift`
- 新 `Sources/AgentLoopApplication/CowResidencyWorkflowController.swift`
- 新 `Sources/AgentLoopApplication/CampMemoryWorkflowController.swift`
- `Sources/AgentLoopApplication/InputWorkflowController.swift`
- `Sources/AgentLoopApp/AppStore.swift`
- `Sources/AgentLoopApp/CodingRanchContracts.swift`
- `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchLiveHosts.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/RuminationViews.swift`
- `Package.swift`（仅维护 A1a 已建 migration-matrix runner，并给
  `AgentLoopCore` 增加来自现有 `GRDB.swift` package的直接
  `.product(name: "GRDBSQLite", package: "GRDB.swift")` dependency；不得新增
  package、改变 GRDB version/revision、修改 `Package.resolved` 或改变其他
  target/dependency）
- `Sources/P1MigrationMatrixRunner/main.swift`
- `scripts/verify-p1-migrations-sqlite-matrix.sh`
- tests：
  - `Sources/AgentLoopTestSuite/CampLifecycleMigrationTests.swift`
  - `Sources/AgentLoopTestSuite/CowResidencyContractTests.swift`
  - `Sources/AgentLoopTestSuite/CampIsolationTests.swift`
  - `Sources/AgentLoopTestSuite/MemoryProvenanceTests.swift`
  - `Sources/AgentLoopTestSuite/MultiCampTests.swift`
  - `Sources/AgentLoopTestSuite/KnowledgeStoreTests.swift`
  - `Sources/AgentLoopTestSuite/KnowledgeGoldenPathTests.swift`
  - `Sources/AgentLoopTestSuite/OutcomeContractTests.swift`
  - `Sources/AgentLoopTestSuite/DomainEventContractTests.swift`
  - `Sources/AgentLoopTestSuite/VerificationContractTests.swift`
  - `Sources/AgentLoopTestSuite/DatabaseTests.swift`
  - `Sources/AgentLoopTestSuite/DurableWorkTests.swift`
  - `Sources/AgentLoopTestSuite/ChatServiceTests.swift`
  - `Sources/AgentLoopTestSuite/GuideChatTests.swift`
  - `Sources/AgentLoopTestSuite/MemoryDistillTests.swift`
  - `Sources/AgentLoopTestSuite/DistillerTests.swift`
  - `Sources/AgentLoopTestSuite/CodingRanchTests.swift`
  - `Sources/AgentLoopTestSuite/P1ContractIntegrationTests.swift`
  - 新 `Sources/AgentLoopTestSuite/LegacyScopeMigrationTests.swift`
  - 新 `Sources/AgentLoopTestSuite/CampProviderDispatchTests.swift`
  - 新 `Sources/AgentLoopTestSuite/IngestionDeletionContractTests.swift`
  - 新 `Sources/AgentLoopTestSuite/SQLiteMigrationCompatibilityTests.swift`

### 7.2 Migration 与 backfill

追加 `v16-p1-identity-memory`，严格按 stage spec §18.6：

- cow_identity
- camp_residency
- camp_bridge
- camp_lifecycle
- camp_deletion_job
- camp_deletion_artifact
- `user_request.lifecycleState/terminalReason/redactedAt`
- `user_request.lifecycleState` 精确包含
  `open|answered|withdrawn|redacted`；v16 trigger 允许 active Camp
  `open→answered`、deletionRequested/quiescing F2 permit
  `open→withdrawn`，以及 deleting/finalizing
  `answered|withdrawn→redacted`，不允许 open 直接擦除
- `approval_grant_use.redactedAt` 与 exact adapterOperationId redaction
- `ingestion_item` / `action_candidate` 的 version、terminalReason、redactedAt；
  `rumination_result` / `knowledge_source_link` 的 version、redactedAt；locator 采用
  explicit one-shot tombstone discriminator，不允许实施时自选无 discriminator
- `ingestion_item` 与 `rumination_result` 的既有 unconditional DELETE guard 原位
  替换为 stage §14.2/§18.6 exact active-lifecycle、receipt/event-bound且
  `agentloop_active_ingestion_deletion_permit_v1(...) = 1` 的 conditional guard；
  function缺失或无 matching connection-local transaction permit时 fail closed，
  trigger 数不变；`action_candidate` 与 `knowledge_source_link` DELETE永久
  unconditional abort
- v12 `schedule_fire.redactedAt` 的 v16 finalizing-only first-redaction exact
  validator、post-redaction full-row lock 与永久 DELETE guard；scope 只由 exact
  schedule/template/Camp（及 started mission/replay source一致性）解析
- v16 rebuild `durable_work/durable_work_attempt/durable_work_attempt_event`，加入无
  default `campLifecycleVersion`、provider attempt events与 `redactedAt`
- `camp_provider_dispatch`
- `legacy_chat_scope`、`legacy_companion_note_scope`、typed all-event
  `camp_event_scope`
- finalizing-only deletion redaction triggers（attempt event、Verification、
  Acceptance、external receipt、legacy event/scope）
- v12 attempt-event standard UPDATE 在 owning-table rebuild 前 exact drop，最终
  final-named table 同 transaction 建 special UPDATE 并重建同名 DELETE；失败
  rollback 必须恢复 v15 table/data/two guards；legacy event 与 v15
  Verification/Acceptance/external receipt 只 drop/replace UPDATE，DELETE 不动
- 每个 mutable redacted carrier 的 first-redaction validator、独立 post-redaction
  full-row lock 与永久 DELETE guard
- memory_record_version
- memory_dependency，以及在 v16 trigger phase 建立的标准 UPDATE/DELETE pair

backfill：

1. 每 Companion insert-or-ignore Cow Identity，同 ID。
2. `companion.campId` 非空且 Camp 存在 → 一条 active residency，idempotency key `legacy:<cowId>:<campId>`。
3. `campId=nil` → 不建 residency。
4. 损坏 camp FK / 重复关系必须让 migration 明确失败，不静默跳过。
5. 保留 Companion 表与 campId 作为 P1 compatibility projection。
6. 每个 Camp 先按 `camp.archived` backfill exact active/archived lifecycle v1；
   archived Camp 的 queued/running/retry work 按 normative SQL deterministic
   `camp_archived_backfill` cancel并关闭 open attempt/event；active/terminal保留，
   然后全部绑定 lifecycle v1。early campDeletion、copy count、FK任何不一致回滚。
7. chat/note严格按 stage spec §14.2 DM/Guide/source-thread/cowork/manualCow唯一规则
   backfill；thread/Cow、creator、Camp evidence冲突/缺失回滚，globalCow不得映到 Camp。
8. 每条 legacy event 都由 exhaustive resolver得到 camp/global scope；覆盖
   halt/resume、archive、bootstrap/unlock、ingestion/rumination/materialize、
   camp/companion note、schedule missed和所有 mission/card/run kind。
   `EventKind.allPersistedKinds == resolver.keys`、event/scope count相等；unknown/
   malformed/dangling/ambiguous/cross-Camp全部回滚。
9. 既有 ingestion/candidate/result/source-link rows 统一 backfill
   `version=1`、terminalReason/redactedAt=NULL；不得根据现有 status 或正文猜
   camp-deletion history。user request 仅按原 answerJson 有无 backfill
   open/answered，绝不生成 withdrawn/redacted。

`AppDatabase` 必须在 pool前创建并强持有 instance-owned registry，再把 exact
registry捕获到 `Configuration.prepareDatabase`；该 closure是 release/product
runtime中 `registry.installConnectionUDF(on: db)` 的唯一 caller。唯一 test-only
例外是 Permit文件内 `#if DEBUG` 封闭 scenario runner的内部自有 fixture。
`prepareDatabase` 在**每个 connection**建 exact pointer+nonce cell/context，但
runtime API只接受 `GRDB.Database`，caller不能传 raw pointer。
`ActiveIngestionDeletionSQLPermit.swift`
是唯一 raw owner，使用 raw `sqlite3_create_function_v2` +
`Unmanaged.passRetained(context)` + `xDestroy.takeRetainedValue`，不得使用
`DatabaseFunction`。注册参数 exact为 `nArg=-1`、flags=`SQLITE_UTF8`，不得
deterministic或 `SQLITE_DIRECTONLY`。Store只能按 exact instance/key lookup writer
cell；不得使用 process-global/current/nearest/last-writer/cross-connection fallback。
UDF registration不是 schema migration，v16不新增 table/column/version，两枚 DELETE
guard只原位加 outbox+UDF gate，trigger count仍67。`Package.swift`只按 §7.1 给
`AgentLoopCore`增加同一 GRDB package的 direct `GRDBSQLite` product；
`Package.resolved`逐字不变。external SQLite CLI不注册 UDF；即使 fixture有 matching
receipt/scope/event/outbox，raw DELETE也必须 fail closed。

实际 migration顺序固定为完整 tables/indexes与owning-table rebuild/rename →
copy/backfill/resolver/count/FK assertion barrier → 固定顺序、无 `IF EXISTS` 的
`event_no_update`、`verification_record_reject_update`、
`acceptance_record_reject_update`、
`external_operation_receipt_reject_update` 四项 drop → 最后创建**全部**
triggers。四项 drop后不得再执行 DML/resolver/backfill/assertion；rebuild前原位
drop的 `durable_work_attempt_event_reject_update` 保持原位，五个
`DROP TRIGGER` 的最大 ordinal必须小于第一个 `CREATE TRIGGER` 的最小 ordinal。
provider redaction trigger不得在 `camp_deletion_job`/barrier/four-drop block前创建，
且只允许 finalizing。through-v16 normative graph必须 exact 67 triggers；执行 §10
through-v16 全 predecessor matrix；必须包含 populated archived
running/queued/retry work closure、child-FK rename、provider FK cycle、chat/note/event
scope count、wrong-phase/ordinary/二次/extra-diff redaction、逐 retained-column
post-redaction raw SQL UPDATE、九表 ordinary/no-op UPDATE 与全部 DELETE guard。
`domain_event` DELETE rejection 后 `camp_event_scope` 必须仍为 exact 1:1。SQLite
3.51/3.52 runner使用同一真实 GRDB migrator。`Package.swift` 的唯一产品 dependency
变化就是 `AgentLoopCore` 对同一 resolved package的 direct `GRDBSQLite` product；
test-only runner维护仍按既有范围，除此不得改 Package，`Package.resolved`不得变化。
E 建立 lifecycle source of truth 与 deletion ledger；Camp archive/retirement
workflow 仍必须等 F1 engine/artifact owners 建成后由 F2 一次接通，不得在 E 提前
暴露半套 Camp retirement。stage §14.2 的 active-only普通 Ingestion 删除是独立
P1-E 完整功能，必须在 E 接通，不能延期到 F2。

### 7.3 授权读写

新增：

- `requireActiveResidency(cowId:campId:)`
- `residentCows(campId:)`
- `authorizedMemory(cowId:campId:bridges:)`

替换 Planner、Orchestrator dispatch、Schedule、knowledge injection 中的全局 companion query。无 residency 抛 `ResidencyAuthorizationError`。

### 7.4 Residency 与 lifecycle 基础

命令：

- request / authorize / activate / pause / resume / leave / revoke；
- create/revoke CampBridge；

重复 command 幂等；非法转移失败；left/revoked 不复活。
`CampLifecycleStore` 在 E 提供 `lifecycle(campId:)` 与 transaction-only
`requireActiveCampWrite`（active + exact version + legacy archived=false，永远不接受
deletion capability），并让 E 自己新增的 Residency/Bridge/Memory/provider writes
使用；
legacy `camp.archived` 仍由 compatibility adapter dual-read。E 不 expose
`archiveCamp/unarchiveCamp/requestCampDeletion`，也不运行 deletion worker；F2
在所有 P1 owners 存在后替换全局 legacy write path 并启用命令。

### 7.5 Legacy scope 与 Camp Provider dispatch

- `LegacyContentScopeStore` 是 thread/message/note 的唯一写入口。post-v16 先插
  immutable scope再插 content；Guide=.camp、DM=.globalCow、cowork note必须带
  mission evidence。封闭 raw CompanionNote/message insert。
- `LegacyEventScopeResolver` 覆盖 `EventKind.allPersistedKinds`；唯一
  `appendLegacyEventAndScope` 先插 typed scope再插 event。封闭 raw
  `AppDatabase.appendEvent/EventRecord.insert`。
- `CampProviderDispatchStore` 逐字实现 stage §14.2/§18.6：
  message+guideChat work同 transaction；prepare→start event→network→returned
  checkpoint event→consume/final success。returned不重呼 provider；started无
  response只可在 same active lifecycle/attempt budget 下 abandoned + exact replay。
- Guide与 guide/closeout/cowork distill 固定
  `replaySafeInference`；DM/global distill与 connection test typed global且不建 Camp
  dispatch。unknown external-write route在 dispatch前失败；Guide tool仅 read-only
  search/status和 command-receipt去重 propose_squad。
- 删除 `GuideChatService/MemoryDistillService/Distiller/Orchestrator` 内持有
  unregistered `LLMProvider` + fire-and-forget Task 的 authority；service只能交给
  supervisor/ledger。历史 unsafe started row terminal failed
  `provider_effect_unknown` + Attention intent。

### 7.6 Memory

命令：

- record raw/working；
- propose promotion；
- confirm promotion；
- record outcome-based skill；
- invalidate dependency；
- request deletion / tombstone。

旧 CampNote/CompanionNote 继续显示；新 promotion 只写 MemoryRecord。P2 再统一 UI。P1 不批量把旧 note 宣称为可信 Memory。

把 P1-D 的 downstream invalidation coordinator 扩展为 required
`MemoryRecordStore` 参数：stage spec §19 的 return/revoke/verification
invalidation/new Outcome version/dependency deletion 与 Memory
needsReview/invalidated/tombstone 在同一 transaction；任何 Memory mutation 失败使
上游 command 一起回滚。P1-E 不触及尚未存在的 Growth 表。

### 7.7 Active Ingestion 普通删除

本功能在 P1-E 完整交付，不借用、暴露或提前接通 Camp retirement：

1. 新 `Domain/IngestionDeletion.swift` 定义 sealed
   `ActiveIngestionDeletionCommandV1`、`IngestionDeletionScope`、
   `ActiveIngestionDeletionResult`、opaque
   `PendingActiveIngestionDeletion`、`ActiveIngestionDeletionPrepareRequestV1`、
   `ActiveIngestionDeletionExecutionResolutionV1`、
   `ActiveIngestionDeletionResolutionDispositionV1` 及 typed errors。resolution
   exact为 `committed|notCommitted|resolutionPending`，pending disposition exact为
   `commitOutcomeUnknown|integrityBlocked|terminalConflict`。prepare request只能含
   一次 confirmation生成并保留的完整既有
   `CommandEnvelopeV1`、campId、ingestionId、scope；不能带 lifecycle/version/status、
   row/result IDs、snapshot/hash或任何 affected/blocker count。
   `IngestionDeletionStore.prepareActiveIngestionDeletion(request:)` 是唯一 command
   factory owner：一次一致性 `pool.read` transaction重读 lifecycle/legacy bit、
   ingestion/result全行与五个 actual blocker counts，验证 scope，内部用
   `CanonicalJSONV1` 重算 full snapshots、envelope+payload whole hash并派生三项
   affected counts，返回 opaque command handle + safe preview。command factory/
   package init只有 Store authority能调用；Controller/Application/Adapter/UI不能
   铸造或改写。正文不进入 handle/preview/log，prepare零 DB写且不装 permit。
2. scope 必须逐字执行 Stage §14.2：
   - `resultOnly` 只接受 active、未 redacted/terminal 的 `needsReview` 或带旧 result
     的 `failed`，result exact 且未 materialize，零 link/candidate/nonterminal
     work/open attempt/provider；删除一条 result，再 CAS ingestion 到 queued、
     clear error、version+1，原 source/raw/contentHash 保留；counts 固定
     `1/0/1`，CAS affected count 必须 exact 1；
   - `sourceAndResult` 只接受 active
     `queued|failed|needsReview|discarded`、terminalReason/redactedAt=NULL、零
     projection/work/provider；optional result若存在必须 exact 且未 materialize，
     先删 0|1 result，再删 exact 一条 ingestion；counts 固定
     `0|1/1/0`；
   - `everythingIncludingProjection` 在任何 receipt/event/delete 前固定抛
     `projectionDeletionUnsupported`。candidate/link 永不被普通删除。
3. 新 `Database/ActiveIngestionDeletionSQLPermit.swift` 定义 package-internal
   sealed permit/cell与 AppDatabase-instance-owned
   `ActiveIngestionDeletionSQLPermitRegistryV1` 与
   `ActiveIngestionDeletionSQLFunctionContextV1`。该文件是本 UDF唯一
   `GRDBSQLite`/raw SQLite owner：独占
   `sqlite3_create_function_v2`、`sqlite3_user_data/value/result`、
   `sqlite3_db_readonly`/`sqlite3_get_autocommit`、C callbacks与相关
   `Unmanaged` ownership；其他文件不得实现 raw registration/callback。
   `AppDatabase.init` 必须先建并强持有 registry，再把 exact registry捕获进
   `Configuration.prepareDatabase`，最后才创建 pool。它是 release/product runtime
   中唯一 `registry.installConnectionUDF(on: db)` caller；唯一例外是本文件
   `#if DEBUG` test probe的内部 scenario fixture。setup/runtime APIs接收
   `GRDB.Database`，caller不能传 raw pointer。
   install内部从 `db.sqliteConnection`取得 pointer identity，以
   `sqlite3_db_readonly(pointer,"main")` exact `0=writer/1=readonly`标记 role（其他
   值 typed setup failure），并执行唯一 install state machine：
   - registry boundary内先拒绝 sticky fault；若 pointer已有
     `installing|installed` entry，设置 sticky
     `duplicateConnectionRegistration`、typed setup fail，零 C call/purge/
     replacement；
   - 同一 boundary内生成 random nonce、exact `(pointer identity,nonce)` key、
     cell/context，先发布 pointer→key `installing` 与 key→weak-cell；
   - 解锁后才 `Unmanaged.passRetained(context)` 并调用 raw C；任何可能同步触发
     callback/destructor的 SQLite C API都不得跨持 registry boundary；
   - 返回后重新加锁 reconcile：`SQLITE_OK` 要求同 pointer/key/cell installing
     entry仍在且无 sticky，然后只转 `installed`；failure要求同步 xDestroy已经
     remove entry/invalidate cell且无 sticky，否则设置 sticky并 typed setup fail。
   registry/cell/sticky lifecycle fault的 mutable state由该唯一 private
   synchronization boundary保护；registry不强持 context。`xFunc`/`xDestroy`必须是
   Permit文件中 file-private noncapturing top-level C-compatible functions并直接
   传入，禁止 global stored callback `let`/MainActor-isolated callback storage。
   注册调用只能是
   `sqlite3_create_function_v2(pointer,
   "agentloop_active_ingestion_deletion_permit_v1", -1, SQLITE_UTF8,
   retainedContext, xFunc, nil, nil, xDestroy)`；不使用 `DatabaseFunction`，不加
   `SQLITE_DETERMINISTIC` 或 `SQLITE_DIRECTONLY`。
   `xFunc` 只经 `sqlite3_user_data`读取 context；exact 53/63 arity、value
   type/nullability、step、key/generation/permit/cursor全部通过才
   `sqlite3_result_int(...,1)`。任一 reject只给稳定无正文 SQLite error
   `agentloop_active_ingestion_deletion_permit_rejected`；不 query/reenter DB、不访问
   其他 connection、不落盘/日志正文、不部分 consume。
   `xDestroy` 对 non-null pApp唯一
   `Unmanaged<ActiveIngestionDeletionSQLFunctionContextV1>
   .fromOpaque(...).takeRetainedValue()` exact once，先 invalidate cell全部 generation，
   再调用内部 typed `removeDestroyedConnection(exactKey:cellIdentity:)`，按同
   key+cell identity精确移除 pointer索引/weak entry。单次 callback内 missing/wrong/
   replaced设置 instance sticky lifecycle fault；后续 setup/mutation/resolution全部
   typed fail closed，不得全表清理或 fallback。SQLite是 retained pApp/destructor
   唯一 owner；产品和 tests都禁止手工调用 xDestroy或对同 pApp第二次
   `takeRetainedValue`。duplicate测试只能由下述封闭 DEBUG runner在内部仍强持
   typed fixture时对 remove helper做第二次注入，不是第二次 C destructor。
   registration failure也由
   SQLite调用 xDestroy，error branch不得手工 release/double-destroy。
   successful `sqlite3_close`在返回前 destroy；`SQLITE_BUSY`表示仍打开，故不 destroy
   且 entry/cell保留；`sqlite3_close_v2` zombie延迟到最后 statement/blob/backup
   释放时才 destroy。只有旧 context精确销毁后 pointer才可由新 connection复用；新
   install必须生成新 nonce/context/cell，旧 permit永不匹配。
   mutation-only `requireWriterCell(for: db)` exact lookup还验证
   pointer/key/nonce、writer role、`db.isInsideTransaction`、autocommit=0。第二个封闭的
   resolution-only
   `assertNoActiveGenerationForResolution(for: db)` 做同一
   AppDatabase exact pointer+nonce/writer lookup，但要求 not-in-transaction/
   autocommit=1，只读断言 cell无 active/finished generation并返回 `Void`；不返回
   cell/key/nonce、不 install/consume/finish/clear。registry只暴露这两个
   runtime path-specific API（另有唯一 setup API）；readonly/wrong/missing/stale/
   cross-AppDatabase、sticky lifecycle fault或残留 generation拒绝，resolver归为
   commitOutcomeUnknown；不暴露 caller-supplied nonce/raw-pointer/generic lookup。
   唯一 test例外是 Permit文件内 `#if DEBUG` + package visibility 的
   `ActiveIngestionDeletionSQLPermitTestProbeV1`。它只提供
   `runLifecycleScenario(_:)` 与 `injectCleanupMismatch(_:)` 两个封闭入口：前者
   exact enum为
   `registrationFailure|laterPrepareDatabaseSetupThrow|directPoolClose|
   duplicatePointerInstall|busyCloseThenRetry|closeV2ZombieFinalRelease|
   boundedPointerReuse`，后者 exact enum为
   `missing|wrongKey|wrongCell|replaced|duplicateCleanup`。scenario runner只在
   Permit文件内部创建并销毁自己拥有的隔离 in-memory/temporary fixture，内部复用
   同一 install state machine/private raw registration call site；不接受外部
   Database/AppDatabase/path/pointer/closure，bounded reuse固定最多256次。它只返回
   Stage列明的 immutable scenario tag、before/after counters/flags与布尔结果；
   helper runner内部强持 typed fixture但不把它返回。两者均不得返回 pointer/nonce/
   key/cell/context/permit/Database/closure或任何 lookup/enumerate/install/consume
   capability；mismatch runner必须在内部同一 fixture逐项证明 sticky之后 setup、
   mutation lookup、resolution lookup都 typed reject，并只返回相应 booleans。两个
   入口只能被列明 lifecycle tests调用。tests不得 import `GRDBSQLite`、引用 raw
   SQLite symbol或复制 registration。
4. 新 `IngestionDeletionStore` 持有 `AppDatabase`，是 source tree 中唯一可安装
   permit、调用 permit registry并执行 ingestion/result physical mutation的 owner。
   execute API固定为
   `executeActiveIngestionDeletion(preparedCommand:)`，只接 Store自己 factory产生的
   sealed handle；不接 generic callback，不返回 `Database`、evidence writer或
   permit。唯一 outcome resolver固定为 SELECT-only
   `resolveActiveIngestionDeletionExecution(preparedCommand:)`，同样只接 sealed
   handle；它唯一使用同 AppDatabase 的
   `DatabasePool.writeWithoutTransaction` writer queue；closure的第一个 executable
   operation只能调用
   `assertNoActiveGenerationForResolution(for: db)`。该 Permit-owned API内部先验证
   `!db.isInsideTransaction` 与 `sqlite3_get_autocommit==1`，再完成 exact
   pointer/key/nonce/writer/empty-generation assertion；Store不得 import
   `GRDBSQLite` 或直接引用 raw autocommit symbol。成功后才读 same-key receipt并按
   absent/notCommitted、identity-mismatch/terminalConflict、validator-failure/
   integrityBlocked、validator-success/committed分类。entry/assertion失败一律先成为
   commitOutcomeUnknown，不能用后来 graph掩盖 invariant failure；除此只调用下述
   `expectedCommand(sealedHandle)` shared graph validator。
   禁止 `pool.read`、`pool.write`、
   `barrierWriteWithoutTransaction`、新 transaction或 observer替代；不能安装 permit、
   调 UDF、执行 DML、重新 execute或 mint key。execute只开一个 serialized
   `pool.write`，transaction第一项处理
   receipt replay/conflict：committed replay必须调用
   `validateCommittedActiveIngestionDeletionGraphV1(.expectedCommand(sealedHandle))`，
   完整 graph与 handle逐字段通过后才返回且不装 permit；same-key absent的首次/new-key
   路径必须在 lookup writer cell、安装
   permit或写本 command任何 evidence前，重扫全部
   `commandType='activeIngestionDeletion.v1'` receipts并调用下述同一 validator的
   `selfContainedScan`。
   当前 ingestion fault或可信归属前 malformed分别 ingestion/global fail closed，
   零写/零 permit/零 mutation；scan通过后才全量重验 CommandEnvelope whole hash、
   active lifecycle/legacy bit、两个 full snapshot、scope与五项 live blocker=0。
   Store只在已打开 transaction中 exact lookup writer cell，要求无 active/finished
   generation后生成 nonce并安装；唯一 boundary机制是
   `db.afterNextTransaction(onCommit:onRollback:)`，两个 callback均 exact-generation
   invalidate/assert。write closure另以 `defer`无条件 exact-generation clear；
   manual/early boundary、next transaction、throw/rollback/commit或 connection reuse
   均不能消费旧 permit，finish后再次 consume失败。
   Store内唯一 private
   `validateCommittedActiveIngestionDeletionGraphV1` 必须由 execute replay、
   first/new-key execute preflight、resolver与 prepare relaunch scan共用，禁止多套
   近似实现。它逐条严格验证：
   receipt key/type、64-hex whole hash、eventCount=1、canonical resultJson、重算
   resultHash、23-key decoder；decoded Camp/ingestion/event IDs与
   `camp_event_scope` exact 1；same-command domain event actual count=1、identity/
   deterministic key/ordinal/aggregate+version/eventType、command identity、canonical
   payload/recomputed hash/21-key decoder与 receipt双向字段；完整 actor/device/
   correlation/causation/time专列；matching outbox actual count=1与合法 initial或
   progressed state。
   validator mode exact为 `expectedCommand(sealedHandle)`（execute same-key replay +
   resolver）或 `selfContainedScan`（prepare + first/new-key preflight）。两种模式都
   从 event专列重建 envelope exact
   `idempotencyKey/actorType/actorId/deviceId/correlationId/causationId/occurredAt`，
   从 safe JSON重建 typed payload exact
   `campId/expectedLifecycleVersion/ingestionId/oldIngestionVersion/
   oldIngestionStatus/ingestionContentHash/ingestionSnapshotHash/resultId/
   resultVersion/resultHash/scope/deletedResultCount/deletedIngestionCount/
   updatedIngestionCount/knowledgeSourceLinkCount/actionCandidateCount/
   nonterminalRuminationWorkCount/openRuminationAttemptCount/
   nonterminalProviderDispatchCount`，再按
   `CanonicalJSONV1({"envelope":...,"payload":...})` 重算 whole hash。
   `commandPayloadHash/eventId/eventPayloadHash/recordedAt` 禁止进入 hash material；
   typed payload的 `resultHash` 是 rumination-result snapshot hash，区别于 outer
   `domain_command_receipt.resultHash`。重算值必须同时匹配 receipt column、receipt
   result JSON与 event payload JSON。
   禁止只查 64-hex或 persisted copies相等。
   `expectedCommand` 还把重建 envelope、全部 typed payload fields与重算 hash逐字段
   exact匹配 sealed handle，execute replay和 resolver均不得省略；
   `selfContainedScan` 无 handle但做相同重算并按 decoded ingestionId归属。可信归属后
   任一 fault block该 ingestion；可信归属前 malformed使 ordinary deletion全局 fail
   closed。validator只 SELECT/decode/hash，不接 caller facts、不 DML/repair/reset
   outbox。
   execute/resolver不得把普通 throw留给 Controller猜 committedness：
   - exact matching receipt type/whole hash/`eventCount=1`，receipt
     resultJson/resultHash canonical + exact-key decoder、matching scope、unique event
     identity/payload hash/专列/decoder与 unique outbox全部通过，返回 `committed`；
     outbox允许合法推进状态但不得被 replay/reset；
   - 同 handle execute已经结束、SELECT-only resolver成功进入上述
     `writeWithoutTransaction` writer queue、registry无 active generation且同 key
     receipt absent，返回
     `notCommitted`；
   - read/writer queue无法判断返回
     `resolutionPending(commitOutcomeUnknown)`；receipt
     type/whole hash/`eventCount=1`任一 mismatch返回
     `resolutionPending(terminalConflict)`；同 key/type/hash/count匹配但 receipt
     resultJson/resultHash/canonical decoder、scope、event identity/payload/专列/
     decoder或 outbox graph任一 incomplete/corrupt，返回
     `resolutionPending(integrityBlocked)`。
   Store prepare还要 SELECT-only扫描
   `domain_command_receipt.commandType='activeIngestionDeletion.v1'` 全部 rows并逐条
   调用同一 shared validator的 `selfContainedScan`；当前 ingestion的任一 integrity
   fault直接
   `integrityBlocked`，可信归属前 malformed则 ordinary ingestion deletion全局 fail
   closed，直到 repair；不得用 relaunch/new key绕过。
5. Store 自己直接按序执行每条 statement并在下一步前立即读取真实
   `changesCount`：
   - cursor固定
     `receipt→scope→event→outbox→resultMutation→ingestionMutation→finish`；
     insert receipt、scope、event、outbox各 exact 1并推进；event专列逐字段复制
     CommandEnvelope，recordedAt由 Store生成；outbox为 matching eventId、
     pending/attempt0/version1、NULL schedule/lease/error/sent且
     createdAt=updatedAt=recordedAt；
   - exact result DELETE。expected=1时 trigger内 UDF从全部 `OLD` result字段重算
     canonical snapshot、匹配 permit/evidence并消费 `deleteResult`；expected=0时
     changes必须0且 Store记录 zero-result step；
   - `sourceAndResult` source DELETE的 UDF重算全部 `OLD` ingestion snapshot并
     消费 `deleteIngestion`，changes必须1；`resultOnly` exact CAS changes必须1，
     只改 queued/error/version/updatedAt，Store重读 expected post-row后消费
     `updateIngestion`；
   - transaction closure返回前强制 finish，重读并核对 ordered consumed steps、
     三项 observed affected counts、receipt/scope/event/outbox exact identity/count
     与五项 live blocker仍0。
   任何缺 outbox/步骤、乱序、重复、假 count、claimed-result但无 row、跳过 CAS、
   precommitted evidence或 arbitrary 64-hex snapshot hash都 throw并让整 transaction
   rollback；
   SQLite planner不保证 trigger `AND` 求值顺序，任一 guarded statement error后
   Store不得在同 transaction retry，必须立即 throw/rollback/clear permit。
   receipt/scope/event/outbox不能单独成为以后 transaction的 mutation authority。
6. event 固定 ordinal 0、deterministic key
   `<commandKey>#0000:ingestion:<ingestionId>`；同 command key实际 event count exact
   1，matching outbox count exact 1。receipt resultJson的 eventId/eventPayloadHash
   逐字匹配 event；command/receipt/event/permit绑定 Camp/key、expected lifecycle、
   ingestion/result ID/version/full snapshot hash、scope、三项 affected counts及五个
   fixed-zero blocker counts；完整 CommandEnvelope只由 whole hash、permit和
   `domain_event` 专列逐字段绑定，recordedAt由 Store绑定。receipt/event safe JSON
   exact-key decoder拒绝 actorRef/actorId/actorType/deviceId/account identifiers；
   不复制用户/设备 identity。UDF 53/63共同参数包含 envelope专列、recordedAt与
   initial outbox全 shape；missing/wrong/nullability/time/arity/type失败。
   live `NOT EXISTS`仍保留；任一 count漂移或 same-key改变均 conflict。event payload
   不含 receipt resultHash，避免 hash循环。
7. replay 必须先于当前 lifecycle/source revalidation：same key/type/whole
   hash/`eventCount=1` 且 receipt result/hash/decoder、scope、唯一 event/outbox graph
   完整时，在之后 archive、Camp deletion 或 source gone仍返回原 safe result，不追加
   event/outbox、不重复 DELETE；same-key type/hash/count mismatch conflict；
   identity匹配但 graph损坏 integrity blocked；new key source gone为 not found。
   receipt/event payload只含 Camp-safe IDs、旧 version/status、hash、scope、counts/time，
   不含 rawText/title/URL/result/candidate/link正文。
8. `FeedService`、`RuminationService` 与 `RuminationMaterializer` 的
   start/complete/fail/cancel/materialize transaction helper全部改为读取 active
   lifecycle并对 ingestion/result/work version CAS。普通删除、这些路径与 Camp
   deletion在同一 SQLite serialized writer 下单 winner；materialize先赢则 delete
   失败，delete先赢则 late worker/provider response不能重建 result/candidate/link
   或推进旧 work。
9. `InputWorkflowController` 持有
   `PendingActiveIngestionDeletion(envelope,preparedCommandHandle,selection,
   safePreview,committedResult?,traceId,phase,resolutionDisposition?)`；phase exact
   `prepared|executing|executionResolutionPending|committedRefreshPending`，
   disposition只在 resolution pending非 nil；必要时 `AppStore` 只映射其 view state。
   一次 confirmation只生成/保留一次完整 CommandEnvelope并只调用一次 Store prepare；
   double-click、view rebuild与 retry single-flight且不得重新 prepare。
   `CodingRanchStoreAdapter` 与
   `CodingRanchContracts` 删除旧 `deleteIngestion(ingestionId:scope:)` seam，改为
   `prepareActiveIngestionDeletion(request: envelope+campId+ingestionId+scope)` +
   `executeActiveIngestionDeletion(preparedCommand:)` +
   `resolveActiveIngestionDeletionExecution(preparedCommand:)`；adapter只能转交
   request/opaque handle和 typed resolution，不能查询 row facts或 mint/改写 command。
10. `prepared` 的 pre-execute cancel可清；`executing` 后 cancel/dismiss不得清 handle、
    取消底层 Task或把未知提交状态冒充未提交，必须等待 typed resolution。
    `notCommitted` 以同 handle/envelope/key回到 `prepared`，保留 selection/trace并
    显示失败；用户可 cancel或用同 handle重试，Store仍全量 live revalidate。
    `committed` 转 `committedRefreshPending`；refresh失败保留同
    command/result/trace，retry先 same-key receipt replay再 refresh。
    `executionResolutionPending(commitOutcomeUnknown)` 禁清/禁 mutation retry，只可
    同 handle SELECT-only resolve；`integrityBlocked` 禁清/禁 mutation并显示 stable
    trace + repair-required error；`terminalConflict` 禁该 handle再次 execute，只允许
    explicit `abandonConflict` 后普通 reload，再清 pending并重新确认生成新随机 key。
    commit后的 explicit dismiss只关闭已提交结果，不是撤销、不 mint key，后续普通
    reload刷新。除 prepared cancel、terminal-conflict abandon、refresh成功或
    committed dismiss外不得清 view state。
    pending明确为 session-local；process death/relaunch不恢复旧 trace/phase、不自动
    replay或 mint key，只从完整 committed projection+receipt graph或完整 rollback
    普通 reload。reload后仍 eligible且用户重新确认时才可产生新 key。
11. source sentinel test 对 adapter/UI/service与整个 module扫描：只允许
    `AppDatabase` 出现 v16 trigger SQL reference；release/product runtime只允许其
    `Configuration.prepareDatabase` 调用一次
    `registry.installConnectionUDF(on: db)`，唯一 test-only例外是 Permit文件内
    `#if DEBUG` scenario runner的内部自有 fixture；本 function不得出现任何
    `DatabaseFunction` registration。只允许
    `ActiveIngestionDeletionSQLPermit` 文件 import `GRDBSQLite`并出现
    `sqlite3_create_function_v2` 的唯一 production call site、function-name raw registration、
    `sqlite3_user_data/value/result/db_readonly/get_autocommit`、C callbacks、
    `Unmanaged.passRetained/takeRetainedValue`、context/cell/exact-key registry与
    sticky lifecycle fault；setup/mutation/resolution API都接收 `GRDB.Database`，
    Store/Controller不得 import `GRDBSQLite`、直接引用 autocommit/raw symbol或传
    caller raw pointer/nonce。sentinel还必须拒绝 `onConnectionWillClose`、GRDB patch、
    AppDatabase close wrapper、raw unregister/overwrite、任何手工 xDestroy/
    `release()` error branch、global stored callback `let`，并证明 registry boundary
    不跨唯一 raw C call；duplicate pointer install在 C call前 fail。
    `#if DEBUG` test probe只允许 Stage列明的两个入口、exact scenario/mismatch enums、
    immutable counters/flags/booleans与内部自有隔离 fixture；tests外调用、接受外部
    Database/AppDatabase/path/pointer/closure、返回 pointer/key/nonce/cell/context/
    permit/Database/closure或 production enumerate/install/lookup/consume一律失败。
    registration-failure scenario只能经同一 private raw call site内部的 invalid-name
    branch进入；later-setup scenario只能在内部同一 `prepareDatabase` fixture中先
    install后抛 fixed typed sentinel；不得复制第二个 registration call。测试文件
    import `GRDBSQLite`、引用 raw SQLite symbol或手工调用 xDestroy同样失败。
    `Package.swift` sentinel要求 direct `GRDBSQLite` product只增加到
    `AgentLoopCore`、仍来自现有 `GRDB.swift` dependency，`Package.resolved`逐字不变。
    runtime permit install/finish、command factory authority、specialized receipt/scope/event/
    outbox写入与 ingestion/result DELETE/CAS只能出现在 `IngestionDeletionStore`；
    outcome resolver在该 Store内也只能出现
    `writeWithoutTransaction` +
    `assertNoActiveGenerationForResolution` + shared graph validator，不得出现
    `read`/`write`/barrier variant、generic registry lookup、transaction、observer、
    DML/permit/UDF；shared validator只能定义一处并由 replay/new-key execute
    preflight/resolver/prepare调用。
    `DomainEventStore` 保持全局 CommandEnvelope/safe JSON/outbox合同 owner，但不向
    specialized Store暴露 generic mutation callback。其他位置出现 caller-fact
    command initializer、raw DELETE、`Record.deleteOne/deleteAll`、UDF runtime
    invocation、permit consume、evidence writer callback或自行删除 candidate/link
    即失败。
12. `CodingRanchContracts`、`CodingRanchLiveHosts` 与 `RuminationViews` 只展示两种
   可执行选择，文案明确“只删除尚未收进营地的资料/反刍结果；营地成果不会删除”；
   projection scope若由旧调用传入则展示 typed unsupported error。删除/refresh
   失败均留在原页、保留 pending selection并显示稳定 trace ID，不能 optimistic
   close或显示假成功；outcome unknown只显示“正在确认是否已提交”并触发只读 resolve，
   integrity block显示需修复且禁止重试删除，terminal conflict只展示
   abandon-and-reconfirm路径。

不新增 migration version/table/column；只复用 v14 receipt/event、v16 lifecycle 与
v14 event_outbox，以及原位加 UDF/outbox gate 的两枚 DELETE guard，trigger总数保持
67/84。
`CampLifecycleStore` 仅提供 active fence/read helper，不把 ordinary deletion塞进
Camp deletion permit API。联合信任边界只能表述为 persisted guards +
connection-local transaction UDF + 唯一 Store/source sentinel，禁止宣称 SQL
evidence rows独立授权未来 mutation。

### 7.8 Tests

- backfill replay no duplicates；
- nil camp creates no access；
- same Cow active in two Camps sees isolated memory；
- pause/leave/revoke blocks read/write；
- bridge grants only specified direction/scope and revoke takes effect；
- lifecycle backfill exactly mirrors legacy archived and replay is stable；
- archived running/queued/retry work closes exact projection/attempt/event, binds lifecycle
  v1；active/terminal unchanged；early deletion/copy/FK failure rollback；
- DM/Guide/cowork/manual note scopes、每个 nil-ref Camp/global EventKind fixture通过；
  unknown/dangling/malformed/multi-evidence/cross-Camp rollback；
- post-v16 thread/message/note/event/domain-event missing/mismatched scope insert abort；
- ordinary/wrong Camp/wrong job/wrong phase/second/extra-column redaction update 与所有
  append-only DELETE abort；
- provider message-written、prepared、started、returned、consume、final success各
  crash window恢复；returned never recalls provider；
- provider lifecycle fence race阻止post-fence dispatch/response/tool/reply commit；
- replay attempt必须exact previous abandoned，同work/turn/attempt budget；
- DM/global dispatch不进入Camp quiescence，Camp Guide/distill必须进入；
- lifecycle/deletion job/artifact DDL constraints and FK restrict are present；
- E-owned write guards reject non-active lifecycle；
- accepted Outcome promotion succeeds；
- returned/revoked/invalid Outcome invalidates dependent skill/growth；
- source deletion erases body ref and leaves non-sensitive tombstone；
- prepare request type/source sentinel证明 caller只能传完整既有 CommandEnvelope +
  campId/ingestionId/scope，无法注入 lifecycle/result/row hash/count；command
  initializer/factory authority在 Store外不可达，Controller/Application不能 mint；
- prepare在一次 `pool.read` snapshot内重读完整 rows/blockers并派生 facts，零写入；
  safe preview/opaque handle/log无正文。prepare→execute间逐项改变 lifecycle、row、
  result、blocker或 scope前提都由 writer全量 revalidation拒绝；
- ordinary deletion envelope逐项测 actorType=user、nonempty actorId/deviceId/
  correlationId、causationId唯一 optional、finite occurredAt；domain_event专列 exact，
  recordedAt由 Store产生。receipt/event exact 23/21-key decoder与 raw evidence均
  拒绝 missing/extra/duplicate key及 actorRef/actorId/actorType/deviceId/account
  identifier JSON key；
- `resultOnly` 对 needsReview/failed exact成功，其他 status、materialized result、
  missing/mismatched result/version/hash、每个 lifecycle/redacted/terminal shape拒绝；
- `sourceAndResult` 对 allowed status×optional result 0|1 exact成功，affected count
  mismatch rollback；`resultOnly=1/0/1`、`sourceAndResult=0|1/1/0` 三项 count
  任一漂移都 rollback；
- 五个 blocker的 command/whole hash、receipt、event、permit claim逐项验证：
  missing/nonzero、claim为0但 live row非零、claim在 prepare/execute间漂移、
  transaction内 race insert与 same-key count变化均 conflict/rollback；live
  link/candidate/nonterminal work/open attempt/provider各单独存在也拒绝且零写；
- `everythingIncludingProjection` 永久 typed reject，candidate/link raw DELETE
  永久 abort；
- same-key replay在 active/archived/deletionRequested/deleting/deletedTombstone 与
  source gone 后都不重复 event/delete；异 payload conflict；new key source gone
  not found；
- start/complete/fail/cancel/materialize/Camp deletion 与两种 ordinary deletion
  各跑双方 winner，late worker不能重建；
- raw missing/wrong event/ordinal/deterministic key/actual event count、
  receipt eventId/eventPayloadHash、command/result/ingestion snapshot hash、
  Camp/scope、envelope专列/nullability/time、recordedAt、outbox shape/count、
  lifecycle/version、三项 affected count与五项 blocker count均由 guard + UDF abort；
- 原始 P0 反例必须逐个跑在 SQLite 3.51/3.52 real GRDB lane：(a) evidence声称
  deletedResult=1但从未有 result后直删 source；(b) resultOnly删 result后跳过
  ingestion CAS；(c) receipt/scope/event/outbox先 commit、later transaction再 DELETE；
  (d) 任意自洽 64-hex result snapshot hash；四者都必须零持久 mutation或整
  transaction rollback；
- permit registry matrix覆盖 AppDatabase instances隔离、registry-before-pool、
  `prepareDatabase`唯一 release/product install caller及列明 DEBUG runner的唯一
  test-only internal-fixture例外、runtime API只接 `Database`、pointer+random nonce
  exact lookup、writer/readonly role、missing/wrong/cross-instance connection；
  raw registration逐参数断言 function name、`nArg=-1`、flags exact
  `SQLITE_UTF8`、无 deterministic/DIRECTONLY、零 `DatabaseFunction`；
  context强持 cell/registry/key、registry weak cell与 private synchronized state；
  install逐步断言 boundary内 preflight → provisional `installing` publish → unlock →
  唯一 C call → relock reconcile，且任何 callback-capable C API调用期间不持 boundary。
  duplicate pointer install必须在 C call前设置 sticky fault并以零 purge/replacement/
  registration失败；registration同步 failure则 provisional entry已由 xDestroy精确
  清除，随后 setup typed fail。`xDestroy.takeRetainedValue` exact-once覆盖 successful
  direct `pool.close()`立即 destroyed/alive=0、registration failure回调且 error
  branch零 manual release，以及 `prepareDatabase`中 UDF成功安装后的任一 later
  setup throw仍由 connection teardown精确清理；
  `sqlite3_close` BUSY不 destroy并保持 live、successful retry close才 destroy、
  `close_v2` zombie在最后 statement/blob/backup释放前不 destroy而后 exact destroy；
  pointer高频 reopen/reuse每次 old context先销毁、new nonce/cell不匹配旧 permit。
  封闭 DEBUG runner内部仍强持 typed fixture时，对 remove helper做
  `missing|wrongKey|wrongCell|replaced|duplicateCleanup`受控注入必须设置 sticky
  lifecycle fault，之后 setup/mutation/resolution全部 typed fail closed，不能
  registry-wide cleanup掩盖；不得第二次调用 C destructor或对同一 pApp再次
  `takeRetainedValue`。`ActiveIngestionDeletionSQLPermitTestProbeV1`的 exact lifecycle
  scenarios逐项覆盖 registration failure、later setup throw、direct pool close、
  duplicate pointer pre-C rejection、BUSY→retry、close_v2 final release与 fixed
  256次 bounded pointer reuse；只读 Stage列明的 immutable snapshot/result，且所有
  fixture/raw calls以及 sticky后的三条 typed rejection probe都留在 Permit文件内部。
  产品与 test caller均不得取得 pointer/key/cell/context/permit/Database/closure或
  lookup/install能力。UDF未注册、
  registered但 cell空、wrong autocommit/transaction/
  generation/step/order/key/hash/row/count、wrong 53/63 arity/type/nullability、
  duplicate consume与 finish后 consume都返回同一稳定无正文 reject error；
  `xFunc` DB reentry/正文日志/partial consume source sentinel为零。
  `afterNextTransaction` commit/rollback、throw、manual/early boundary、defer与
  next-transaction/connection reuse全部 invalidates；合法 `resultOnly`、
  `sourceAndResult(result=0)`、`sourceAndResult(result=1)`全部通过，任何 incomplete
  sequence在 commit前 rollback；
- outbox insert failure、missing/skip/wrong eventId/state/attempt/version/time/
  lease/error/sent shape、duplicate count均整 transaction rollback；same-key replay
  不追加第二 outbox，已提交 outbox之后的合法 dispatch状态推进不被 replay回退；
- SQLite 3.51/3.52 literal fence验证 schema/count及 external CLI matching evidence
  因无 UDF fail closed；同版本 real GRDB runner经 AppDatabase注册同一 UDF，验证
  conditional result/ingestion delete、snapshot canonical recompute、candidate/link
  permanent guard、67/84、FK/integrity 与 Camp deletion after ordinary deletion；
- v16 literal fence与真实 Swift migration trace逐 statement验证：
  barrier < `event_no_update` < `verification_record_reject_update` <
  `acceptance_record_reject_update` <
  `external_operation_receipt_reject_update` < first `CREATE TRIGGER`；四项均无
  `IF EXISTS`，且在它们之后无 DML/resolver/backfill/assertion。所有
  `CREATE TABLE|CREATE INDEX|ALTER TABLE|DROP TABLE|DROP TRIGGER|table rename`
  （含 rebuild前 owning-table drop在内的五个 trigger drops）最大 ordinal必须小于
  first-create最小 ordinal。每个 four-drop边界、last-drop→first-create及每个
  trigger-install midpoint的 failure injection都 rollback到逐字相同 v15
  schema/data/16-trigger snapshot；through-v16/v17仍67/84；
- execution resolution matrix覆盖 before-write failure、每个 injected rollback 与
  receipt absent均返回 `notCommitted`、同 handle回 prepared后 cancel/retry；
  resolver只经同 AppDatabase `writeWithoutTransaction`且入口
  not-in-transaction/autocommit=1，并只调用 exact
  `assertNoActiveGenerationForResolution`；该 API对 pointer+nonce/writer/empty
  generation逐维验证且不返回/修改 cell；valid writer通过，readonly、missing/stale/
  cross-instance、pointer reuse、active/finished residue、inside-transaction或
  autocommit错误逐项 typed reject并优先成为 commitOutcomeUnknown，即使同时存在完整
  graph也不得跳过；prior commit/rollback callback完成后才进入，
  resolver自身不触发 transaction boundary/observer、DML/UDF/permit；source sentinel
  拒绝 `pool.read`、`pool.write` 与 barrier variant；
  replay/new-key execute preflight/resolver/prepare必须命中同一 shared validator；
  execute replay/resolver只用 `expectedCommand(sealedHandle)`，prepare/new-key scan
  只用 `selfContainedScan`；两种模式都从 event envelope专列 + exact 19-field typed
  payload重建 `CanonicalJSONV1({"envelope":...,"payload":...})`，排除 command/event
  hash、eventId与 recordedAt，重算 whole hash并匹配 receipt column/result/event
  payload；把三处 command hash同步替换为任意 64-hex并重算 resultHash/eventPayloadHash
  的 forged-but-self-consistent graph仍必须失败。execute replay还逐字段比对 sealed
  handle envelope/payload/hash，逐个 envelope/payload drift都不得返回 committed；
  matching receipt
  key/type/hash/eventCount/canonical resultJson/resultHash/23-key decoder +
  scope + event actual count/identity/key/ordinal/aggregate/version/type/command/
  canonical payload/hash/21-key decoder/专列 + outbox完整 graph返回 committed且不回退
  合法 progressed outbox；resolver read/writer-queue
  failure只进入 commitOutcomeUnknown且只读重试；same-key type/hash/eventCount
  mismatch进入 terminalConflict并只能 abandon+reload+reconfirm；matching identity下
  receipt result/hash/decoder、scope、event identity/payload/专列/decoder或 outbox任一
  损坏进入 integrityBlocked、禁止 mutation；prepare按
  `commandType='activeIngestionDeletion.v1'`扫描，当前 ingestion incomplete graph与
  无法归属 ingestion的 malformed同型 receipt均不能用新 key绕过；对上述 receipt
  result/hash/decoder、scope、event count/identity/key/ordinal/aggregate/version/type/
  command/payload/hash/decoder/专列与 outbox每一个 fault分别注入 session loss/relaunch，
  新 confirmation/prepare都仍按同一 validator block；
  prepare scan通过后、execute writer开始前分别注入上述每一种可归属 fault与
  可信归属前 malformed；new-key execute必须在 own evidence/permit前重扫并以零
  receipt/scope/event/outbox写、零 permit install、零 ingestion/result mutation失败；
- UI single-flight覆盖 double-click/view rebuild/retry不重复 prepare；prepared
  cancel可清，executing cancel/dismiss不清 handle也不把 Task cancel冒充未提交，
  commit-vs-cancel race按 typed resolution收敛；executionResolutionPending三种
  disposition分别验证允许/禁止动作；commit后 explicit dismiss只关已提交结果且
  后续 ordinary reload刷新、不 mint key；process death分别注入 commit前/后，relaunch
  只普通 reload完整 rollback或完整 committed facts，不恢复旧 pending、不自动 replay/
  mint key；UI success先 refresh再关闭，尤其
  commit→refresh failure→同一 pending command/key receipt replay→refresh
  success→close，不得追加 event/outbox/delete或 mint新 key。
  source sentinel证明 Store外零 direct ingestion/result delete、零 permit install/
  consume/UDF call/generic mutation callback。

### 7.9 P1-E 验收

- Camp isolation runtime tests 不依赖 UI filter；
- memory provenance graph 可回溯；
- Camp retirement schema 仅就绪、未对产品暴露；active-only普通 Ingestion 删除已按
  Store-only prepare factory、instance-owned registry/generation-bound raw
  `sqlite3_create_function_v2+xDestroy` UDF permit、
  CommandEnvelope/outbox/privacy、fixed-zero blocker、typed execution resolution与
  四 phase session-local pending-command合同交付；F2 retirement gate 仍未完成；
- tests/build/Review 全绿。

## 8. P1-F1 — Engine、Artifact、Discussion、Attention 与 Growth

### 8.1 允许文件

- `Sources/AgentLoopCore/Loop/CardExecutionBackend.swift`
- `Sources/AgentLoopCore/Loop/CardRunner.swift`
- `Sources/AgentLoopCore/Loop/CliProcessBackend.swift`
- `Sources/AgentLoopCore/Loop/ContextPacket.swift`
- `Sources/AgentLoopCore/Loop/AgentLoop.swift`
- `Sources/AgentLoopCore/Loop/BoardToolServer.swift`
- `Sources/AgentLoopCore/Loop/BoardServerBridgeMain.swift`
- `Sources/AgentLoopCore/Tools/BoardTools.swift`
- `Sources/AgentLoopCore/Tools/ToolExecutor.swift`
- `Sources/AgentLoopCore/Tools/ApprovalGate.swift`
- `Sources/AgentLoopCore/Tools/HandoffPayload.swift`
- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopCore/Database/Records.swift`
- `Sources/AgentLoopCore/Database/BoardCardTransactions.swift`
- `Sources/AgentLoopCore/Database/OutcomeStore.swift`
- `Sources/AgentLoopCore/Database/DomainEventStore.swift`
- `Sources/AgentLoopCore/Database/MemoryRecordStore.swift`
- `Sources/AgentLoopCore/Database/CampLifecycleStore.swift`
- `Sources/AgentLoopCore/Knowledge/ExpeditionReport.swift`
- 新：
  - `Sources/AgentLoopCore/Domain/ExecutionEngine.swift`
  - `Sources/AgentLoopCore/Domain/EngineExecutionReceipt.swift`
  - `Sources/AgentLoopCore/Loop/ArtifactStager.swift`
  - `Sources/AgentLoopCore/Loop/ArtifactOwnershipVerifier.swift`
  - `Sources/AgentLoopCore/Loop/ModelLoopEngineAdapter.swift`
  - `Sources/AgentLoopCore/Loop/CliEngineAdapter.swift`
  - `Sources/AgentLoopCore/Database/EngineExecutionStore.swift`
  - `Sources/AgentLoopCore/Database/EngineSessionStore.swift`
  - `Sources/AgentLoopCore/Database/ArtifactBlobStore.swift`
  - `Sources/AgentLoopCore/Database/ArtifactStorageOriginStore.swift`
  - `Sources/AgentLoopCore/Knowledge/ManagedExpeditionReportStore.swift`
  - `Sources/AgentLoopCore/Domain/Discussion.swift`
  - `Sources/AgentLoopCore/Domain/AttentionItem.swift`
  - `Sources/AgentLoopCore/Domain/GrowthEvidence.swift`
  - `Sources/AgentLoopCore/Database/CoordinationStore.swift`
- `Sources/AgentLoopApplication/MissionWorkflowController.swift`
- `Sources/AgentLoopApplication/AcceptanceWorkflowController.swift`
- `Sources/AgentLoopApp/AppStore.swift`
- `Sources/AgentLoopApp/CodingRanchContracts.swift`
- `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift`
- `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchLiveHosts.swift`
- `Package.swift`（仅维护 migration-matrix runner target）
- `Sources/P1MigrationMatrixRunner/main.swift`
- `scripts/verify-p1-migrations-sqlite-matrix.sh`
- tests：
  - `Sources/AgentLoopTestSuite/ExecutionEngineConformanceTests.swift`
  - `Sources/AgentLoopTestSuite/EngineExecutionStoreTests.swift`
  - `Sources/AgentLoopTestSuite/EngineTerminalProposalTests.swift`
  - `Sources/AgentLoopTestSuite/ArtifactBlobStoreTests.swift`
  - 新 `Sources/AgentLoopTestSuite/ArtifactStorageOriginTests.swift`
  - 新 `Sources/AgentLoopTestSuite/ArtifactOwnershipVerifierTests.swift`
  - `Sources/AgentLoopTestSuite/SQLiteMigrationCompatibilityTests.swift`
  - `Sources/AgentLoopTestSuite/EngineSessionTests.swift`
  - `Sources/AgentLoopTestSuite/DiscussionContractTests.swift`
  - `Sources/AgentLoopTestSuite/AttentionGrowthContractTests.swift`
  - `Sources/AgentLoopTestSuite/P1ContractIntegrationTests.swift`
  - `Sources/AgentLoopTestSuite/CliBackendTests.swift`
  - `Sources/AgentLoopTestSuite/CardRunnerTests.swift`
  - `Sources/AgentLoopTestSuite/BoardServerTests.swift`
  - `Sources/AgentLoopTestSuite/BoardToolsTests.swift`
  - `Sources/AgentLoopTestSuite/AgentLoopTests.swift`
  - `Sources/AgentLoopTestSuite/GoldenPathTests.swift`
  - `Sources/AgentLoopTestSuite/OrchestratorTests.swift`
  - `Sources/AgentLoopTestSuite/CrashRecoveryTests.swift`
  - `Sources/AgentLoopTestSuite/HaltAndCooldownTests.swift`
  - `Sources/AgentLoopTestSuite/ApprovalGateTests.swift`
  - `Sources/AgentLoopTestSuite/ContextPacketTests.swift`
  - `Sources/AgentLoopTestSuite/HarvestTests.swift`

### 8.2 Migration

追加 `v17-p1-engine-coordination`，严格按 stage spec §18.7：

- engine_execution
- engine_terminal_proposal
- engine_proposal_artifact
- camp_deletion_proposal_blob
- engine_session
- artifact_blob
- artifact_blob_reference
- artifact_storage_origin
- discussion
- discussion_turn
- attention_item
- growth_evidence

`engine_execution` 必须包含不可变、进入 request/whole hash 的
`campLifecycleVersion`；receipt 加
`committedProposal|invalidProtocolError|invalidCampDeletion` disposition。
同时加入 proposal artifact path/kind/label `redactedAt` + finalizing trigger，
Discussion turn contentRef `redactedAt` + append-only finalizing trigger。每条 legacy
artifact只 backfill active `unresolved/legacyUnknown` + original/classification
evidence hashes，不访问filesystem、不按 path猜；origin DDL 同时建立
active/tombstoned、verified-outside、terminal disposition/authority/redactedAt exact
shape。v17 先建完整 Engine/Proposal/Artifact/Discussion/cleanup graph和backfill，
通过显式 migration phase barrier 完成 count/FK assertions 后，最后安装任何
trigger；through-v17 exact trigger count=84；按 stage spec constraints、stable Camp scope 与 append-only
要求建表，并执行 §10 through-v17 全
predecessor matrix。

### 8.3 Engine protocol

1. 定义 stage spec §16 的 descriptor/request/event/terminal/error。Descriptor 以
   typed `executionReplayClass(for:)` 独占 engine invocation replay semantics；
   Store 从 exact adapter version/derived session scope 调用并持久化，caller 不可
   覆盖；它与 Grant tool-effect replayClass 完全分离。
2. `ExecutionEngineAdapter` API：
   - `descriptor(profile:)`
   - `execute(request:) -> AsyncThrowingStream<EngineExecutionEvent, Error>`
   - `cancel(executionId:)`
3. ModelLoop 与 CLI 均 adapter 化。
4. Orchestrator 只按 required capabilities 选择 adapter；不再直接 `if profile.kind.isCLI` 构造 backend。
5. adapter event sequence 单调，terminal 精确一次；重复/乱序 terminal 是 protocol error。
6. usage 用 `addingReportingOverflow`；发生 overflow 抛 `UsageOverflowError`，该 execution 进入 failed 并记录 trace，不做饱和成功。
7. kernel ownership API 固定：
   - `beginEngineExecution(requestFields:idempotencyKey:) ->
     EngineExecutionRequest`，store 只用 `CanonicalJSONV1.encode` 编码全 request
     并自算 requestHash；单 transaction 分配 execution+Run 并 Card
     ready→running；同 transaction 读取 active lifecycle，把不可变
     campLifecycleVersion 写入 request/row/hash；同 key 异 hash conflict；
   - `beginEngineExecution` 在 SQL 前验证
     `EngineContextEnvelopeV1` canonical object，重算 context hash；冻结
     `ContextPacket -> EngineContextEnvelopeV1` 唯一转换，prompt rendering bytes
     不参与 identity；Store 另从 exact request fields 构造
     `EngineSessionScopeV1`、canonicalize并重算 scope hash，caller JSON/hash绝不
     作为权威；
   - `markEngineDispatchStarted(executionId:expectedVersion:requestHash:
     commandIdempotencyKey:now:)` 单 transaction CAS prepared→started；
     `.startNow(exactRequest)` 才能 call adapter，重放 `.alreadyStarted` 绝不 call；
   - `commitEnginePreDispatchFailure(...)` 对 prepared descriptor/capability/setup
     mismatch 单 transaction terminalize 全 projection/receipt，且
     dispatchStartedAt 保持 nil；
   - `acceptEngineEvent(executionId:sequence:event:)` 只推进 sequence/progress；
   - `recordEngineTerminalProposal(_:)` 只用 `CanonicalJSONV1` 持久化并 hash
     whole `EngineTerminalProposalContentV1`：kind/subtype/full payload + 按 explicit
     ordinal normalized 的 artifact declarations；caller 不提供 artifactId，首次
     record tx 生成，重放返回 exact rows。payload/manifest subhash 不作 identity；
   - `commitEngineTerminal(proposalId:checkedUsage:now:)` 重验 prepared blobs，单
     transaction 更新 handoff/artifacts、engine_execution、Run、Card、Mission
     rollup、events；
   - `commitEngineAskUser(proposalId:checkedUsage:now:)` 单 transaction 插
     user_request、Card `needs_human_input` block、Run/engine/Mission/events；
   - `invalidateProposalAndCommitProtocolError(...)` 单 transaction proposal
     pending→invalid 并以 kernel-owned blocked terminal 收口全 projection、safe
     events/Attention；同 command重放 typed `EngineTerminalCommitReceipt`；
   - typed receipt 必含
     `committedProposal|invalidProtocolError|invalidCampDeletion` disposition；F1
     只实现前两种 schema/type，F2 才开放第三种 specialized command；
   - `recoverInterruptedEngineExecutions(now:)` 对 begin 后未终结的 row 由 kernel
     严格按 stage spec §16.3 recovery matrix 收口，adapter 无写 DB 权限。
8. 从 `CardRunner`、`CliProcessBackend`、ModelLoop/CLI adapters、BoardTools/
   BoardToolServer 删除 `startRun/finishRun/completeCard/blockCard` authority。
   Board terminal tool 只经 injected `EngineTerminalSink` 返回完整
   `EngineTerminalProposal`；ask_user 也只形成
   `blocked + needsHumanInput` proposal，
   progress 不获得 terminal authority。
9. terminal taxonomy 只有 completed/blocked/failed/canceled；ask_user 是
   blocked + needsHumanInput。terminal receipt hash 等于 domain command
   `resultHash` 且有 receipt key FK，不等于 proposalHash。同 execution/key + whole
   proposal hash 重放返回旧 proposal/receipt；payload相同但 manifest/ordinal/字段
   漂移也 conflict；terminal 内容冲突、
   sequence 跳号/乱序/第二 terminal 全部 fail-closed。terminal transaction 任一
   mutation failure 全回滚。
10. `ArtifactStager` + `ArtifactBlobStore` 严格执行 stage spec §16.3：
    先验证已有 blob，缺失才读 workspace source；workspace scope/hash/size 验证 →
    `.staging` temp+fsync → content-addressed blob atomic rename → DB commit 引用；
    rename-before-row crash 可恢复；GC live set精确执行：
    pending proposal 的 `engine_proposal_artifact.contentHash`（declared/prepared）
    UNION active `artifact_blob_reference.contentHash` UNION nonterminal
    `camp_deletion_proposal_blob.contentHash`；`proposalHash` 永远不是 blob root。
    仅 >24h 且不在该 contentHash集合才 GC。deletedTombstone 同 hash再次使用必须
    重新验证/restage bytes并 CAS 新 version，不能复活空 path。
11. recovery precedence 逐字实现 §16.3：pending proposal first；nonReplayable
    started/sessionBound external-effect-unknown 优先于 cancellation；prepared cancel
    才可直接 canceled；四个 dispatch crash window 都有 failure injection。
    `blocked+externalEffectUnknown` 是 engine自身 safe terminal，不借用 Grant
    resolution、不重放/no-effect/success；F2 deletion permit只能触发这条既有
    terminal transaction。
12. bind/resume 同 transaction 强校验 session/execution
    camp/profile/adapter/version/sessionScopeHash/workspace exact equality。每次
    execution contextHash 独立 canonical/recompute；user answer 后 context 可变但
    immutable session scope 不可变。
13. `ArtifactStorageOriginStore` 是 artifact provenance唯一 DB owner，
    `ArtifactOwnershipVerifier` 是 root capability/no-follow 证明唯一 owner：
    new managed只接受 `PreparedArtifact`，new external只接受
    `WorkspaceExternalArtifactReference`，artifact/origin/ref同 transaction。
    `BoardCardTransactions.completeCard` 删除 String durablePath overload；legacy
    upgrade只接受 verifier 的 managed 或
    `verifiedOutsideAllManagedRoots` evidence；prefix/name/ext/missing/symlink/
    permission/root unavailable均不能自动声明 managed/external。origin active/
    tombstoned、terminal disposition/authority hash/redactedAt 和 post-redaction lock
    逐字实现 stage DDL。
14. `ManagedExpeditionReportStore` 接管 Orchestrator report与 AppStore
    `ensureReport` 的两个旧 filesystem直写，按 mission→Camp登记 registry owner，
    trusted root/no-follow、job cursor可恢复；旧直写函数删除。

### 8.4 CLI session

Codex：

- parser 识别真实 JSONL thread/session ID event；
- 首轮 `codex exec ... --json`；
- resume `codex exec resume <exact-id> ... --json`；
- 重新传 ranchboard config 与安全 flags。

Claude：

- 首轮生成 UUID，传 `--session-id`；
- parser/最终 result 校验回传相同 session ID；
- resume `--resume <exact-id>`；
- 重新传 strict MCP config、permission mode 和 workspace。

共同：

- 不使用 `--last` / `--continue`；
- session ref 持久化后才对外 emit `sessionBound`；
- profile/workspace/session-scope/adapter 不匹配拒绝 resume；
- descriptor 与本机 CLI `--help` 能力不符时明确 unsupported；
- fake CLI contract tests 不要求真实登录。

### 8.5 Conformance suite

同一 suite 对 ModelLoop、Codex fake CLI、Claude fake CLI 运行：

- descriptor truthfulness；
- descriptor-owned replayClass truthfulness and row revalidation；
- completed/blocked/failed/canceled；
- EOF without terminator；
- cancellation process cleanup；
- usage/cost；
- session bind/resume；
- resume mismatch；
- board terminal exactly once；
- secret-free error。

### 8.6 Discussion / Attention / Growth

按 stage spec §17 实现 records/store/commands，不加完整 UI。

Discussion：

- create 校验 participant、round、budget；
- append turn 原子扣 budget；
- materialize 必须引用真实对象；
- over round/budget terminalize failed/blocked。

Attention：

- source event + dedupe key 唯一；
- level 转换只允许规则表；
- recordOnly/summary 不触发系统通知 side effect；
- needsAction/urgent 由 Application 层投影。

Growth：

- capability evidence 必须校验 Outcome/Verification/Acceptance；
- invalidation 传播；
- store API 不依赖 ApprovalGrant，schema 无 permission 字段。
- 把 downstream invalidation coordinator 再扩展为 required
  `CoordinationStore`：stage spec §19 命令与 Growth invalidation 同 transaction；
  到此 Matrix 的 Outcome/Goal/Mission/metric/Memory/Growth 全链闭合。

### 8.7 P1 整合测试

新增 `P1ContractIntegrationTests.swift`：

1. capture Input；
2. resolve Camp；
3. Coach + confirmed Understanding；
4. active OutcomeContract；
5. active Cow residency；
6. enqueue Mission planning work；
7. Engine fake adapter terminal；
8. Outcome version；
9. deterministic Verification；
10. user Acceptance；
11. metric credit；
12. Memory/Growth evidence；
13. return/invalidate 反向传播。

另测在步骤 2、3、6、7、9、10 的 crash/replay；每步幂等且不重复计数。

Engine ownership 额外测试：

- kernel allocates exact execution/run once；
- context typed/raw golden bytes/hash；invalid/nonobject/noncanonical/hash mismatch
  before SQL 且零 Run/Card/event 写；
- session scope golden bytes/hash；caller spoof/mismatch before SQL zero-write；
- model/contract/profile/adapter/workspace/Camp drift changes derived scope and cannot
  resume，input/memory/answered-request context change does not change scope；
- ContextPacket only converts through EngineContextEnvelopeV1 and render prompt drift
  does not change context identity；
- dispatch CAS first call returns startNow once；same-command replay alreadyStarted
  never invokes adapter；stale version/hash conflict；
- prepared descriptor/capability/setup failure commits blocked/failed atomically with
  nil dispatchStartedAt；raw SQL rejects fake completed/canceled terminal shapes；
- crash before CAS / after CAS-before-call / after call-before-event / after session bind
  follows the exact recovery matrix；
- ModelLoop/CLI/Board adapter cannot start or finish Run directly；
- board terminal receipt commits Run/Card/Mission once；
- complete proposal replays full HandoffPayload and durable artifacts；
- same terminal key + same whole proposal replays generated artifact IDs；same payload
  with manifest/ordinal/path/label/hash drift conflicts；caller array reorder with unchanged
  explicit ordinals is identical；
- blocked proposal preserves exact reason/detail；
- terminal kind SQL/API rejects waitingForUser；ask_user atomically creates request and
  commits blocked+needsHumanInput；
- crash before/during/after blob prepare never leaves DB pointing at missing artifact；
- recovery covers valid blob+missing source, missing blob+valid source, both missing,
  corrupt blob, rename-before-row；
- path escape/missing/mismatch invalidates one proposal and atomically commits one
  engineProtocolError receipt; failure at each projection/event mutation fully rolls back；
- GC at 23h retains；at 25h逐个 exact contentHash验证 pending
  engine_proposal_artifact（declared/prepared）、active artifact_blob_reference 与
  nonterminal camp_deletion_proposal_blob UNION；`proposalHash`即使相等也不能保活，
  shared blob remains；
- v17 legacy artifact全部 unresolved/legacyUnknown且 migration不访问filesystem；
- typed managed/external create atomic；raw String path completeCard API不存在；
- classification fixtures覆盖 trusted managed、explicit external、managed missing=
  alreadyAbsent、verified outside all roots、unknown missing/symlink/prefix spoof/
  permission/root unavailable/identity/hash drift 的 typed unresolved evidence、
  hardlink额外 link、pending proposal、cross-Camp ref与 concurrent ref/snapshot；
- Orchestrator closeout 与 AppStore ensureReport只调用 ManagedExpeditionReportStore；
  raw report-root write source sentinel为0，failure/restart cursor不漏文件；
- begin same key/different Contract/grants/budget/workspace request hash conflicts；
- EOF/throw/cancel uses kernel terminal transaction；
- duplicate same terminal replays, conflicting/second/skip-sequence rejects；
- failure injection after each Run/Card/Mission/execution/event mutation fully rolls back；
- recovery matrix covers prepared, pending proposal, exact session resume,
  replaySafe/idempotencyKeyed replay, nonReplayable crashUnknown, explicit
  cancel and parser/EOF branches without double terminalization。
- local cancellation after nonReplayable dispatch cannot outrank externalEffectUnknown；
- session bind rejects Camp/profile/adapter/version/session-scope/workspace mismatch；
- user answer creates a new execution/contextHash while exact sessionScopeHash safely
  resumes；regression fixture proves `ContextPacket.answeredRequests` prompt+answer changes
  context bytes；scope drift starts a new session；
- terminal execution has domain receipt key/resultHash linkage for committed and invalid
  proposals，且 proposalHash is never used as receiptHash；
- engine DDL enforces `state != running` iff `dispatchState=terminal`；
- each adapter conformance fixture covers its declared engine replay class；
- descriptor/row replayClass mismatch blocks recovery with protocol error/Attention；
- tool Grant replayClass changes never alter engine execution recovery class。

### 8.8 P1-F1 验收

- unified engine conformance 全绿；
- Discussion/Attention/Growth contracts 全绿；
- Engine/Artifact/Discussion/Attention/Growth integration 全绿；
- Camp retirement 尚未启用，不能宣称 P1 总完成；
- tests/build/Review 全绿。

## 9. P1-F2 — Camp archive/delete 与全链路整合门

F2 只能在 E 与 F1 acceptance 都通过后开始；这是 P1 最后一个实现 slice。它不
引入第三套 schema，而是把 v12–v17 已存在的 stable Camp scope、lifecycle、
deletion ledger、engine/artifact owners 一次接通。F2 前不得 expose
archive/delete 命令。

### 9.1 精确允许文件

- `Sources/AgentLoopCore/Database/AppDatabase.swift`
- `Sources/AgentLoopCore/Database/Records.swift`
- `Sources/AgentLoopCore/Database/BoardCardTransactions.swift`
- `Sources/AgentLoopCore/Database/DurableWorkStore.swift`
- `Sources/AgentLoopCore/Database/DomainEventStore.swift`
- `Sources/AgentLoopCore/Database/InputGoalStore.swift`
- `Sources/AgentLoopCore/Database/CoachUnderstandingStore.swift`
- `Sources/AgentLoopCore/Database/OutcomeStore.swift`
- `Sources/AgentLoopCore/Database/ApprovalGrantStore.swift`
- `Sources/AgentLoopCore/Database/CowResidencyStore.swift`
- `Sources/AgentLoopCore/Database/MemoryRecordStore.swift`
- `Sources/AgentLoopCore/Database/CampLifecycleStore.swift`
- `Sources/AgentLoopCore/Database/EngineExecutionStore.swift`
- `Sources/AgentLoopCore/Database/EngineSessionStore.swift`
- `Sources/AgentLoopCore/Database/ArtifactBlobStore.swift`
- `Sources/AgentLoopCore/Database/ArtifactStorageOriginStore.swift`
- `Sources/AgentLoopCore/Database/LegacyContentScopeStore.swift`
- `Sources/AgentLoopCore/Database/LegacyEventScopeResolver.swift`
- `Sources/AgentLoopCore/Database/CampProviderDispatchStore.swift`
- `Sources/AgentLoopCore/Database/CoordinationStore.swift`
- `Sources/AgentLoopCore/Database/KnowledgeStore.swift`
- `Sources/AgentLoopCore/Database/ScheduleStore.swift`
- `Sources/AgentLoopCore/Database/McpDatabase.swift`
- `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift`
- `Sources/AgentLoopCore/Work/InputParsingWorker.swift`
- `Sources/AgentLoopCore/Ingestion/FeedService.swift`
- `Sources/AgentLoopCore/Rumination/RuminationService.swift`
- `Sources/AgentLoopCore/Rumination/RuminationMaterializer.swift`
- `Sources/AgentLoopCore/Product/MissionDraftFactory.swift`
- `Sources/AgentLoopCore/Product/NewcomerUnlockPolicy.swift`
- `Sources/AgentLoopCore/Product/ProductBootstrapService.swift`
- `Sources/AgentLoopCore/Chat/GuideChatService.swift`
- `Sources/AgentLoopCore/Chat/ChatService.swift`
- `Sources/AgentLoopCore/Knowledge/MemoryDistillService.swift`
- `Sources/AgentLoopCore/Knowledge/Distiller.swift`
- `Sources/AgentLoopCore/Knowledge/ManagedExpeditionReportStore.swift`
- `Sources/AgentLoopCore/Kernel/Planner.swift`
- `Sources/AgentLoopCore/Kernel/Orchestrator.swift`
- `Sources/AgentLoopCore/Loop/CardExecutionBackend.swift`
- `Sources/AgentLoopCore/Loop/CardRunner.swift`
- `Sources/AgentLoopCore/Loop/CliProcessBackend.swift`
- `Sources/AgentLoopCore/Loop/AgentLoop.swift`
- `Sources/AgentLoopCore/Loop/BoardToolServer.swift`
- `Sources/AgentLoopCore/Loop/ArtifactStager.swift`
- `Sources/AgentLoopCore/Loop/ArtifactOwnershipVerifier.swift`
- `Sources/AgentLoopCore/Loop/ModelLoopEngineAdapter.swift`
- `Sources/AgentLoopCore/Loop/CliEngineAdapter.swift`
- `Sources/AgentLoopCore/Loop/ContextPacket.swift`
- `Sources/AgentLoopCore/Tools/ApprovalGate.swift`
- `Sources/AgentLoopCore/Tools/ToolExecutor.swift`
- `Sources/AgentLoopCore/Tools/BoardTools.swift`
- `Sources/AgentLoopCore/Tools/HandoffPayload.swift`
- `Sources/AgentLoopCore/Database/EventKind.swift`
- `Sources/AgentLoopCore/Ingestion/IngestionRecords.swift`
- `Sources/AgentLoopCore/Rumination/RuminationResult.swift`
- `Sources/AgentLoopCore/Knowledge/ExpeditionReport.swift`
- `Sources/AgentLoopCore/Feed/ActivityFeed.swift`
- `Sources/AgentLoopCore/Presentation/CompanionAnimState.swift`
- `Sources/AgentLoopCore/Domain/InputEnvelope.swift`
- `Sources/AgentLoopCore/Domain/GoalController.swift`
- `Sources/AgentLoopCore/Domain/CoachContracts.swift`
- `Sources/AgentLoopCore/Domain/UnderstandingCard.swift`
- `Sources/AgentLoopCore/Domain/OutcomeContract.swift`
- `Sources/AgentLoopCore/Domain/Outcome.swift`
- `Sources/AgentLoopCore/Domain/Verification.swift`
- `Sources/AgentLoopCore/Domain/Acceptance.swift`
- `Sources/AgentLoopCore/Domain/ApprovalGrant.swift`
- `Sources/AgentLoopCore/Domain/MemoryRecord.swift`
- `Sources/AgentLoopCore/Domain/ExecutionEngine.swift`
- `Sources/AgentLoopCore/Domain/EngineExecutionReceipt.swift`
- `Sources/AgentLoopCore/Domain/Discussion.swift`
- `Sources/AgentLoopCore/Mcp/McpToolBridge.swift`
- `Sources/AgentLoopApplication/InputWorkflowController.swift`
- `Sources/AgentLoopApplication/AcceptanceWorkflowController.swift`
- `Sources/AgentLoopApplication/ExternalOperationWorkflowCoordinator.swift`
- `Sources/AgentLoopApplication/CowResidencyWorkflowController.swift`
- `Sources/AgentLoopApplication/CampMemoryWorkflowController.swift`
- `Sources/AgentLoopApplication/MissionWorkflowController.swift`
- 新 `Sources/AgentLoopApplication/CampRetirementWorkflowController.swift`
- 新 `Sources/AgentLoopCore/Work/CampDeletionWorker.swift`
- `Sources/AgentLoopApp/AppStore.swift`
- `Sources/AgentLoopApp/CodingRanchContracts.swift`
- `Sources/AgentLoopApp/CodingRanchStoreAdapter.swift`
- `Sources/AgentLoopApp/MissionScheduler.swift`
- `Sources/AgentLoopApp/McpStore.swift`
- `Sources/AgentLoopApp/Views/Components/CardDetailInspector.swift`
- `Sources/AgentLoopApp/Views/ScheduleManagerView.swift`
- `Sources/AgentLoopApp/Views/Components/AskUserPromptView.swift`
- tests：
  - 新 `Sources/AgentLoopTestSuite/CampArchiveQuiescenceTests.swift`
  - 新 `Sources/AgentLoopTestSuite/CampDeletionWorkflowTests.swift`
  - 新 `Sources/AgentLoopTestSuite/CampDeletionArtifactTests.swift`
  - 新 `Sources/AgentLoopTestSuite/CampDeletionEngineProposalTests.swift`
  - 新 `Sources/AgentLoopTestSuite/CampWriteFenceTests.swift`
  - 新 `Sources/AgentLoopTestSuite/CampProjectionRegistryTests.swift`
  - 新 `Sources/AgentLoopTestSuite/CampOwnerRegistryTests.swift`
  - `Sources/AgentLoopTestSuite/DatabaseTests.swift`
  - `Sources/AgentLoopTestSuite/DurableWorkTests.swift`
  - `Sources/AgentLoopTestSuite/InputEnvelopeContractTests.swift`
  - `Sources/AgentLoopTestSuite/GoalCoachContractTests.swift`
  - `Sources/AgentLoopTestSuite/OutcomeContractTests.swift`
  - `Sources/AgentLoopTestSuite/VerificationContractTests.swift`
  - `Sources/AgentLoopTestSuite/ApprovalGrantContractTests.swift`
  - `Sources/AgentLoopTestSuite/CowResidencyContractTests.swift`
  - `Sources/AgentLoopTestSuite/MemoryProvenanceTests.swift`
  - `Sources/AgentLoopTestSuite/EngineExecutionStoreTests.swift`
  - `Sources/AgentLoopTestSuite/EngineTerminalProposalTests.swift`
  - `Sources/AgentLoopTestSuite/ArtifactBlobStoreTests.swift`
  - `Sources/AgentLoopTestSuite/ArtifactStorageOriginTests.swift`
  - `Sources/AgentLoopTestSuite/ArtifactOwnershipVerifierTests.swift`
  - `Sources/AgentLoopTestSuite/SQLiteMigrationCompatibilityTests.swift`
  - `Sources/AgentLoopTestSuite/AskUserTests.swift`
  - `Sources/AgentLoopTestSuite/LegacyScopeMigrationTests.swift`
  - `Sources/AgentLoopTestSuite/CampProviderDispatchTests.swift`
  - `Sources/AgentLoopTestSuite/AttentionGrowthContractTests.swift`
  - `Sources/AgentLoopTestSuite/ScheduleTests.swift`
  - `Sources/AgentLoopTestSuite/KnowledgeStoreTests.swift`
  - `Sources/AgentLoopTestSuite/FeedTests.swift`
  - `Sources/AgentLoopTestSuite/McpTests.swift`
  - `Sources/AgentLoopTestSuite/OrchestratorTests.swift`
  - `Sources/AgentLoopTestSuite/ToolExecutorTests.swift`
  - `Sources/AgentLoopTestSuite/CardRunnerTests.swift`
  - `Sources/AgentLoopTestSuite/CliBackendTests.swift`
  - `Sources/AgentLoopTestSuite/BoardServerTests.swift`
  - `Sources/AgentLoopTestSuite/ChatServiceTests.swift`
  - `Sources/AgentLoopTestSuite/GuideChatTests.swift`
  - `Sources/AgentLoopTestSuite/MemoryDistillTests.swift`
  - `Sources/AgentLoopTestSuite/DistillerTests.swift`
  - `Sources/AgentLoopTestSuite/HarvestTests.swift`
  - `Sources/AgentLoopTestSuite/P1ContractIntegrationTests.swift`

清单外的 Camp-reachable owner 不是“顺手补文件”：先把
`CampProjectionRegistryTests` 的 sentinel failure 写入 `blocked.md`，修订 plan
并独立 Review 后才可继续。

### 9.2 Owner registry 与 write fence

1. compile-time `CampRetirementProjectionOwner` 逐表列 stage §14.2
   query/quiesce/erase/sentinel；schema/FK graph 发现未登记 owner即
   `UnregisteredCampProjectionError`，发现未登记 Camp-reachable TEXT/BLOB/ref
   column即 `UnregisteredCampPrivateColumnError`。globalCow/global memory/
   acceptance policy/cow_identity的 exemption也必须逐项注册，不能 wildcard。
2. compile-time `CampMutationOwnerRegistry` 至少逐函数登记
   AppDatabase、BoardCardTransactions、KnowledgeStore、ScheduleStore、McpDatabase、
   Feed/Rumination/Materializer/MissionDraft、NewcomerUnlock、ProductBootstrap、
   Orchestrator、BoardTools、两个 CodingRanchStoreAdapter writes，以及全部 P1
   Store/worker/controller。source sentinel 扫 raw `pool.write` 与 scoped filesystem
   write，未注册即 gate失败。
3. compile-time `CampExternalDispatchOwnerRegistry` 登记 Planner planning work、
   Rumination work、Guide guideChat、guide/closeout/cowork memoryPromotion、
   CardRunner/CLI F1 Engine、MCP/tool/network/shell Grant、BoardTools prepared
   artifact；DM/global routes显式 global。source sentinel 扫
   `provider.streamTurn`/unregistered Task；未登记即 gate失败。
4. 普通 path统一在同一 transaction调用
   `CampLifecycleStore.requireActiveCampWrite` 验证 active/exact lifecycle
   version/legacy archived=false；不得 UI filter、transaction外 preflight、
   optional no-op或 deletion flag。
5. 封闭/删除 raw authority：
   `setCampArchived`、public `completeCard(String path)`、raw
   `appendEvent/EventRecord.insert`、raw CompanionNote/Guide message insert、
   service-held LLMProvider/unregistered Task。Orchestrator report与 AppStore
   `ensureReport` 只能走 `ManagedExpeditionReportStore`。
6. durable_work/domain_event/inbox/outbox/legacy scope/provider dispatch/
   engine_session/engine_execution/artifact origin均有 stable Camp/global scope +
   FK/index contract；禁止临时 join猜 scope。启动与 finalize都运行全部 registry。

### 9.3 Lifecycle commands

- `archiveCamp`：user actor、expected version、whole hash；逐类 quiescence为零后
  active→archived，dual projection + receipt/safe event/outbox同事务。
- `unarchiveCamp` 是 dedicated command，不调用 active fence：验证 archived、
  legacy bit、expected version、无 deletion job后 archived→active；不启用 schedule。
  与 request deletion并发只有一个 CAS winner。
- `requestCampDeletion`：exact confirmation object/hash，固定
  `unknownArtifactDisposition=detachOnlyNeverUnlink`，UI 明示 unknown/external只
  解绑、原文件可能仍存在且 App 绝不删除；同 transaction lifecycle validate 后用 specialized helper插
  campDeletion work(campLifecycleVersion=N+1)，再插 FK-linked job，CAS lifecycle
  → deletionRequested/write fence，最后 safe event/outbox。开始后无
  generic cancel/unarchive。
- `CampDeletionClaim/Permit` 无 public init、不持久化；每个 transaction重验
  camp/lifecycle、job/version/confirmation、current work/version/attempt/lease、
  phase、operation、target/version与 command key/hash。renew/adopt/cursor/
  replacement/transition均使旧 permit stale。
- F2为 deletion新增 specialized enqueue/claim/renew/fail/complete/adopt helper；
  generic DurableWork API仍拒绝 kind。quiescence只排除 exact current job/work +
  exact open running claim，wrong attempt/lease/work一律 blocker；final transaction
  再重验同 claim并一次 terminalize work/attempt/event/job/lifecycle/event/outbox。
- `CampLifecycleStore.withdrawOpenUserRequestForCampDeletion` 是唯一 pre-finalization
  user-request authority：target 无 public initializer，绑定 exact claim/request/card/
  Camp/version/hash；只在 lifecycle=`deletionRequested` + job=`quiescing` CAS
  `open→withdrawn(terminalReason=camp_deleted)`，保留 prompt/options，且
  answerJson/answeredAt/redactedAt 保持 NULL。`AppDatabase.answerUserRequest` 与
  Orchestrator 普通 answer 只接受 active Camp；answer、request-deletion、withdraw
  通过 expected lifecycle/request-state CAS 只有一个 winner。quiescence query 只数
  `lifecycleState=open`；finalizing 只能将 `answered|withdrawn` one-shot redaction，
  open 不得直接擦除。
- `CampLifecycleStore.discardIngestionForCampDeletion` 与 candidate sibling command
  只接受 claim-derived opaque target。在 deletionRequested/quiescing 的一个
  transaction 内先关闭 matching rumination work/provider checkpoint（无 work 的
  queued item也必须可达），再以 expected status/version CAS ingestion
  `queued|ruminating|needsReview→discarded(camp_deleted)`；candidate
  `proposed|accepted→dismissed(camp_deleted)`。两者保留正文且 redactedAt=NULL。
  Feed/Rumination normal cancel/materialize/convert只接受 active Camp，并与 deletion
  command 单 winner；same command receipt replay稳定，异状态/work/version/hash
  conflict。既有 terminal history不伪改状态，只在 finalizing擦除。
- `ApprovalGrantStore.releaseReservedGrantUseForCampDeletion` 是 reserved use 的唯一
  deletion closeout：只接受 exact reserved、无 dispatchIntent/adapter acceptance/
  adapterOperationId/finishedAt、无 external receipt 的 claim-bound target，CAS
  released + finishedAt/version，Grant usedCount/status/version保持不变。它不调用
  adapter、不追加 external receipt、不 refund 已派发 use；ordinary release/
  dispatch/request-deletion race 单 winner，replay/异 hash行为由 safe command
  receipt固定。dispatching/accepted/crashUnknown 继续只走既有 attested/user
  resolution。
- existing Grant only可在 permit下调用 adapter-attested no-effect或 user
  succeeded|abandonedUnknown；不得reserve/dispatch/refund/resurrect。Engine
  nonReplayable started/sessionBound/no proposal独立走 F1
  `blocked+externalEffectUnknown` safe terminal，不 replay/no-effect/success，收口后
  不再 block；独立 unresolved Grant仍block。
- pending terminal proposal 只允许
  `CampLifecycleStore.supersedePendingEngineProposalForCampDeletion`：target 由当前
  claim 读取产生，逐项重验两个 lifecycle generations、job/work/attempt/lease/phase、
  execution/proposal ID+version+hash。proposal `pending->invalid(camp_deleted)` 并保留
  原 kind/subtype/hash，execution/Run/Card/Mission进入删除终态；不创建 handoff/
  artifact/ref/origin/user_request/Attention，不读 workspace、不调用 stager/adapter/
  provider/tool/resume。safe outbox 出生即 failed/no-dispatch；generic Engine API
  绝不增加 permit。declared/partial/all-prepared artifacts 在同 transaction 全部登记
  `camp_deletion_proposal_blob`。
- 第4次/耗尽 failure保持旧 work/attempt immutable failed、job cursor与 Camp fence。
  user-only `repairCampDeletion` 带 exact confirmation/job/current failed
  work/version/attempt/cursor hash，插 replacement(maxAttempts=4,input含 predecessor/
  cursor)，CAS job.workId/version + receipt/event/outbox；不 reopen旧work、不回退
  phase，并发/replay确定性。它不能改变 artifact ownership 或制造 evidence。
- `resolveCampDeletionArtifact(retryTrustedInspection|detachOnlyNeverUnlink)` 是独立
  user-only command，绑定 exact job/current failed work/origin/deletion-artifact
  versions、artifact/ref/cursor/confirmation hashes；retry 只运行 verifier，detach
  只授权 DB tombstone并创建 replacement work。用户/Agent不能自称 managed。

### 9.4 Erasure 与 artifact phase

1. `ArtifactOwnershipVerifier` 独占 managed-root capability/no-follow 读取，只签发
   `VerifiedManagedArtifactEvidence`、explicit external、
   `verifiedOutsideAllManagedRoots` 或 typed unresolved reason。所有 roots 必须可用才
   能证明 outside；prefix/name/ext/missing/symlink/permission/root unavailable/
   identity/content drift 永不推断 managed/external。
2. `camp_deletion_artifact` 逐字实现
   `pendingInspection|awaitingResolution|detachAuthorized|unlinkPrepared|
   retryableFailure|detached|retainedShared|deleted|alreadyAbsent` 与
   unresolved/managedExclusive/managedShared/workspaceExternal CHECK。known managed
   missing=`alreadyAbsent`；unknown missing走 detach-only；active managed origins、
   refs、pending proposal、hardlink/cross-Camp identity共同决定 shared。
3. external/unresolved 的 detach 是纯 DB transaction：artifact/path、origin/ref
   tombstone并 terminal detached；filesystem调用次数必须为零。只有 transaction-
   local `ManagedArtifactUnlinkPermit` 可操作 managedExclusive；API不接受 URL/String。
   prepare tx 建 reservation/quarantine并持久化 root/object/hash snapshot，随后
   trusted fd `unlinkat`，terminal tx清除 locator。reservation/unlink/DB commit 每个
   crash edge由 ledger恢复；identity/hash漂移改走安全 resolution。
4. proposal blob cleanup 与 artifact snapshot/ref insert/new ref/finalize在同一
   serialized writer竞争；其他 root先赢→shared，reservation先赢→新 ref拒绝/重试。
   cleanup nonterminal是GC root/finalize blocker；same-hash deleted blob必须重新
   validate/restage 后CAS available。
5. quiescence同时 drain provider dispatch prepared/started/returned与普通work，
   按work/attempt去重；permit只做 safe abandon/cancel terminalization，不能消费
   旧response或新派发，provider request/response redaction严格延后到
   deleting/finalizing，erasing 阶段 exact redaction 也必须 abort。
6. final transaction逐表逐列实现 stage §14.2 exhaustive privacy registry，包括
   inbox device/payload/error、Verification、Acceptance、Discussion turn、proposal
   artifact path/label、origin、proposal cleanup、legacy Camp chat/note/event、
   provider dispatch、user request discriminator、grant-use operation ID与 Engine
   cancellation/invalid reason。Card exact为 blockedReason `{}`、dependsOn `[]`、
   handoff NULL。typed JSON 先检查 redacted/tombstone，deleted row不得 normal decode/
   hash/resume/filesystem。ingestion/rumination/candidate/knowledge-link 的
   terminalReason/redactedAt/version 与 marker逐列实现；materialized/failed/
   discarded、dismissed/converted history保留原 terminal state，只擦正文。
   `ScheduleStore` 是 schedule_fire row/scope owner，fire 只按 exact
   schedule/template/Camp + started mission/replay source一致性 redaction；
   dangling/cross-Camp/template drift fail-closed。
7. append-only first-redaction trigger无列过滤且 one-shot；每个 retained column
   `IS OLD`。所有 mutable carrier另有 post-redaction full-row lock，所有 DELETE guard
   永久；provider first redaction只允许 finalizing。through-v17 normative graph
   trigger count固定为 84；v16/v17 每个 trigger 都在该 fence 的完整 table/index
   graph及 copy/backfill/rename之后安装。command/domain events从出生安全，
   globalCow/global exemption不改。
8. 最后重验exact permit/claim，terminalize lifecycle/job/work/attempt/event与safe
   tombstone event/outbox。任何 owner/private-column/sentinel/event失败全DB
   rollback；永不 DELETE Camp或用户workspace文件。

### 9.5 必测矩阵

- lifecycle fresh/v11/v15/v16/v17 backfill/replay、legacy archived dual projection；
- archive 每一个 quiescence category 单独非零时返回 exact count、零写入；
- Card、open Run/UserRequest、Ingestion逐个
  queued|ruminating|needsReview、ActionCandidate逐个 proposed|accepted、Grant、
  engine/proposal/artifact、provider prepared|started|returned、Discussion、Camp
  inbox/outbox、deletion job不得漏项；open request quiescing exact→withdrawn且正文
  不变，answered/withdrawn finalizing→redacted，open direct redaction拒绝；
  Ingestion每状态（含无work queued、matching work/provider、restart）
  exact→discarded/camp_deleted，candidate exact→dismissed/camp_deleted，finalizing前
  正文不变；
- archive CAS 与并发新 write 只有一个 winner；archive event failure total rollback；
- archived read works but every listed write/dispatch/reserve/claim path rejects；
- unarchive idempotent且不恢复 disabled schedule/revoked permission；unarchive/delete
  race只有一个winner；
- deletion confirmation wrong actor/false/hash/version/key/missing-or-changed
  unknownArtifactDisposition rejected before writes；
- request transaction crash injection at lifecycle/job/work/event/outbox each edge全回滚；
- request replay returns one job/work；异 confirmation conflict；
- raw job insert/update with wrong work kind/Camp/aggregate/id rejected by v16 triggers；
- restart adoption at every quiesce/erase/finalize cursor不重复副作用；
- every permit dimension（Camp/lifecycle/job/jobVersion/confirmation/work/workVersion/
  attempt/lease/phase/operation/target/version/key/hash）wrong/stale/cross-Camp均零写；
- open user-request answer vs request-deletion/withdraw CAS 两种 winner；withdraw
  replay稳定、异 request/version/hash conflict，quiescence只统计 open；
- reserved Grant use 无 dispatchIntent/receipt/adapter op 时 specialized release
  exact→released且 usedCount/grant version不变；有任一 dispatch evidence、wrong
  Camp/job/use/grant/version/phase均零写；ordinary release/dispatch/delete race、
  receipt replay与每个 transaction failure edge只收口一次；
- ingestion normal cancel/materialize/worker result、candidate convert 与 deletion
  terminalization 各种 CAS winner；terminal history不改状态；final redaction后
  IngestionRecords/RuminationResult/candidate/link reader先返回 redacted，decoder=0；
- exact self-exclusion只排除current deletion claim；wrong/second deletion work block；
- active owner quiesces deterministically；engine-only nonReplayable unknown收口后继续，
  unresolved Grant仍fenced/blocker；Grant resolution/finalize race一个winner；
- 每种 pending proposal kind/subtype × zero/declared/partial/all-prepared artifacts：
  原 proposal identity保留、effective canceled、零 handoff/artifact/ref/origin/
  user_request/Attention/workspace-read/stager/adapter/provider/tool；specialized receipt
  stable replay，generic Engine deletion authority编译期/运行期拒绝；
- proposal cleanup ledger 覆盖 tmp/rename/blob-row/prepared-CAS、shared/missing/corrupt/
  unlink/DB failure/restart、新 ref race、same-hash deletedTombstone restage；nonterminal
  必为GC root/finalize blocker，safe outbox永不 pending/dispatching；
- fourth failure leaves immutable failed work；repair replay/concurrent repair/crash edges
  只建一个replacement，old attempt不变、cursor继续；
- exact Input tombstone retains/nulls every named field；active row enforces payload XOR；
- Goal/Coach/Understanding、Mission/Card/Run/UserRequest、Memory、Grant/receipt、
  Engine/session/proposal、Outcome/Verification/Acceptance/metric/Growth 各有逐字段
  sentinel test；
- failure/degradation、schedule_fire、durable attempt/event、Camp provider、
  proposal artifact、Discussion turn与 inbox sourceDevice/payload/error逐列 sentinel；
- engine execution/session exact `sessionScopeJson -> {}`、proposal manifest `-> []`
  且 pre-redaction hashes retained、resume forbidden；
- legacy note/ingestion/rumination/candidate/chat/companion-note/MCP authorization
  正文或权限不残留；
- legacy event/Verification/Acceptance/receipt/attempt-event/Discussion普通或 wrong
  phase/job/Camp/second/no-op/extra-diff UPDATE均拒；每个 retained column 在独立
  post-redaction statement逐项篡改均拒；marker replay、redactedAt clear、全部DELETE
  拒绝；只有 first finalizing exact redaction允许；provider/proposal artifact/
  failure/degradation/inbox/grant/session/execution/proposal/origin/new carrier 的
  post-redaction full-row lock逐项验证；schedule fire exact scope、ingestion/
  rumination/candidate/link的first/second/post-lock/delete逐列验证；provider在
  erasing exact UPDATE必须 abort、只有 finalizing允许；domain safe event从未含正文；
- globalCow DM/note、global memory/Cow/policy与另一Camp rows逐字不变；
- managed exclusive unlink once；known managed missing alreadyAbsent；shared/
  hardlink/pending/cross-Camp ref retains；explicit/verified-outside external file与
  unknown missing/symlink/prefix/permission/root unavailable/drift 原 bytes/hash/inode
  不变、DB ref detached、unlink spy=0；所有 roots不全时不得签发 verified-outside；
- artifact resolution wrong actor/job/Camp/origin/deletion row/ref/cursor/hash/version
  零写；retry evidence vs detach、verifier vs user、新 ref vs reservation并发只有一个
  winner；repair不能改变 ownership；
- source/blob missing/corrupt、filesystem failure、DB failure在每个artifact edge收敛；
- concurrent new blob ref vs deletion snapshot/finalize只有一个 winner；
- finalization detects an injected unregistered Camp projection and refuses completion；
- source sentinels证明 BoardCardTransactions/NewcomerUnlock/ProductBootstrap、
  Guide/Chat/MemoryDistill/Distiller/Orchestrator/AppStore/BoardTools/所有P1 Stores
  无 raw write/provider/filesystem authority；任一 synthetic owner/private column失败；
- provider message-written/pre-start/started/returned/commit与 lifecycle fence races
  不产生post-fence dispatch/tool/reply；returned checkpoint不重呼provider；
- final transaction任一 mutation/event/outbox failure keeps deleting/fenced；
- Card/Understanding/Outcome/Rumination/Mission/Handoff/Engine deleted rows先返回
  typed redacted/unavailable，normal DTO decoder/hash/resume/filesystem调用均为零；
- completed deletion replay returns same tombstone；new command不能复活；
- physical `DELETE FROM camp`、FK cascade、cross-Camp erase 均被测试拒绝；
- full P1 golden path仍通过，并追加“创建成果→验收→memory/growth→archive/unarchive→
  confirmed delete”端到端，不重复 metric/event/work。

### 9.6 P1-F2 验收

- 所有 lifecycle/write-fence/quiescence/erasure/ownership/restart/sentinel tests 全绿；
- through-v17 aggregate migration matrix 全绿；
- `swift run RunTests` 与 App build 全绿；
- 独立 Review 无 P0/P1 finding；
- 只有此门通过，P1 才可进入总 acceptance。

## 10. 每个 Slice 的 Migration 门

Migration matrix 不得延后到 P1-F1/F2。每个 introducing slice 在自己的 Review 前运行
fresh + 每个仍支持的 predecessor fixture：

| Slice | 目标 migration | 必跑来源 fixture |
|---|---|---|
| A1a | `v12-p1-durable-work` | fresh、v7、v8-coding-ranch、v9-evercamp、v10、v11 |
| A1b | schema 仍为 durable v12 | fresh、v7、v8、v9、v10、v11、v12-durable |
| A2 | schema 仍为 durable v12 | fresh、v7、v8、v9、v10、v11、v12-durable |
| A4 | `v12-p1-schedule-fire` | fresh、v7、v8、v9、v10、v11、v12-durable |
| B | `v13-p1-observability` | fresh、v7、v8、v9、v10、v11、v12-durable、v12-schedule |
| C | `v14-p1-control-contracts` | 上行全部 + v13 |
| D | `v15-p1-outcome-contracts` | 上行全部 + v14 |
| E | `v16-p1-identity-memory` + durable/provider/scope rebuild | 上行全部 + v15，另含 populated archived active-work 与全部 legacy scope fixtures |
| F1 | `v17-p1-engine-coordination` + artifact origin | 上行全部 + v16，另含 legacy artifact unresolved fixtures |
| F2 | schema 仍为 v17；Camp retirement integration | 上行全部 + v17 |

P1-A1b 的 named predecessor gate 精确为：

- runner 的 `Fixture` 增加
  `case v12Durable = "v12-durable"`，其 checkpoint 是真实
  `AppDatabase.migrator.migrate(..., upTo: "v12-p1-durable-work")`，不是复制最终
  schema；
- 该 fixture 与旧 predecessor 不同：checkpoint 必须已经存在三张 durable table
  及四个 append-only guards，并预置合法 running planning work、open attempt 与
  claimed event；随后 close，保存 canonical logical schema/data snapshot，reopen，
  对同一真实 migrator再跑两次，snapshot逐字不变；
- replay 后仍跑 FK/integrity、DDL/index/trigger、append-only和完整 normalized
  diagnostics；输出至少包含
  `fixture.v12-durable.replay|fk|integrity|ddl|append_only=pass` 与
  `diagnostics.real.v12-durable.*`；
- script 必须把 `v12-durable` 加进两条 linked runner lane的 exact fixture/scope
  assertions；SQLite 3.51 与 3.52 都必须出现这些 sentinel。literal lane仍以 v11
  引入 v12，不对已有 v12 checkpoint重复执行 literal；
- R11 implementation只允许把runner/script中既有Stage-hash expectation同步为
  Review11批准的未来frozen Stage hash；不得改变`v12-durable` fixture逻辑、
  sentinels、checkpoint、DDL/literal hash、A1a fixture verdict/count、
  `Package.swift`或`Package.resolved` hash。既有R10-P1-02 package-access Core
  coordinator保持，不改`Sources/RunTests/main.swift`或任何target/dependency
  graph。

“上行全部”表示保留前一行列出的每一个 fixture，不是只测立即前一版本。A1a 创建
test-only runner 后，A1a、C、D、E、F1 每个 append-only carrier introducing slice
都必须在自己的 Review 前通过
`scripts/verify-p1-migrations-sqlite-matrix.sh`：同一 literal fence 分别喂给 SQLite
3.51/3.52 CLI，同时让同一真实 GRDB migrator分别链接/运行两个 lane，不能只做其中
一种。E 的 literal CLI lane故意不注册 app UDF，只验证 structure/count与
matching-evidence raw DELETE fail closed；E 的合法 deletion与 permit sequence只在
经 `AppDatabase` 注册同一 UDF 的 real GRDB 3.51/3.52 lane通过。不得给 CLI 装一个
放宽版 test function冒充产品 registration。A4/B 与 F2 继续运行 aggregate matrix，
不得删除上游 guard fixtures。固定
sqlite_master checkpoint 是 v11=2、v12-durable=4、v12-schedule=4、v13=4、v14=8、
v15=16、v16=67、v17=84。P1-F1/F2 再重复 aggregate matrix：

```text
fresh/v7/v8/v9/v10/v11/v12-durable/v12-schedule/v13/v14/v15/v16/v17 -> v17
```

每个 slice 的每条 fixture 都必须：

- migrate 成功；
- migrate 再跑一次；
- foreign key check；
- integrity check；
- 必需表、索引、trigger、check 存在；
- 每个 append-only table 在 introducing checkpoint 合法 insert 成功，
  ordinary/no-op UPDATE 与 DELETE 均 abort；
- backfill 数量与关系正确；
- 不依赖 normal DB fixture。
- migration failure 前后 schema/data snapshot 逐字一致；
- A1a 在 v12 introducing checkpoint必须执行 §3.1 的 exact 7 sentinel、
  19 legal controls、56/40/288-row normalized diagnostics truth table；
  E 在 v16 rebuild checkpoint复用同一 gate并扩为21 legal controls与384-row
  event table。SQLite 3.51/3.52 各自同时通过 literal 与同一真实 GRDB migrator
  lane，禁止把 `NULL/UNKNOWN` 当作成功，也禁止只测最先暴露的 open-attempt
  反例；
- E 另在旧 v12/v15 schema分别预置 parent work、attempt、event 至少各一条旧
  diagnostics matrix会接受的 UNKNOWN 非法行；v16 migration必须 fail fast，
  canonical logical schema/data/trigger snapshot逐字不变，且
  `foreign_key_check`/`integrity_check`保持。不得静默修复 poison row，也不得用
  不稳定的物理数据库文件 bytes冒充逐字 snapshot；该 negative gate归 P1-E，
  A1a 不得跨 slice提前实现或执行；
- E fixture另实测 child-FK rebuild/rename、archived open attempt closure、provider
  dispatch/event cycle、scope row count、v15 populated Verification/Acceptance/receipt、
  early campDeletion/dangling/cross-Camp/malformed scope负例；literal fence与真实
  Swift trace都必须证明完整 graph/rebuild/rename/backfill/assertion barrier成功后，
  才按固定顺序、无 IF EXISTS执行四个 surviving-table UPDATE-guard drops，之后无
  DML/resolver/backfill/assertion并才安装任何 trigger。五个 `DROP TRIGGER` 全计入
  ordinal；每个 drop、last-drop→first-create与 trigger中途失败都恢复逐字一致 v15
  schema/data/16-trigger snapshot。另验证五张 deletion-redactable append-only table 的 exact
  first finalizing UPDATE、wrong phase/second/no-op/extra-column/DELETE；v16
  durable rebuild failure rollback恢复 v15 attempt-event table/data/two standard
  guards；Verification/Acceptance/external receipt DELETE guards跨 v16保持；
  domain-command/event/invalidation/memory dependency持续 immutable，拒绝
  domain_event DELETE 后 matching scope仍 exact 1:1；child rows必须经
  transaction-local TEMP staging后直接回填到 final-named tables，并逐项断言
  `PRAGMA foreign_key_list` 只指向 `durable_work`/`durable_work_attempt`/
  `camp_provider_dispatch`，绝不残留 `_v16`、`_legacy` 或 staging target；
  external CLI matching receipt/scope/event/outbox DELETE因 UDF缺失 fail closed；
  real GRDB lane覆盖合法三路径、原四个 P0 incomplete/forged counterexamples、
  Store-only prepare/TOCTOU、instance/pointer+nonce registry、raw
  `sqlite3_create_function_v2` exact flags/context/xFunc/xDestroy ownership、
  封闭 DEBUG scenario runner经唯一 raw call覆盖 registration failure/later setup
  throw/direct pool close/duplicate pointer/BUSY/close_v2 zombie/256次 pointer reuse，
  helper-only sticky mismatch且零能力泄漏、53/63 arity/type/nullability、
  CommandEnvelope专列、initial outbox、
  commit/rollback/manual boundary/connection reuse、five blocker drift、snapshot
  canonical recompute、defer cleanup与整 transaction rollback，trigger count仍为67；
- F1 fixture另实测 artifact origin count/Camp/path hash、proposal artifact/
  cleanup ledger、discussion exact first/wrong/second/no-op/extra/delete redaction
  trigger；3.51/3.52 均断言精确
  tables/indexes/triggers、FK无行、integrity ok。

不得通过复制最终 schema 跳过历史 migrations。任何当前 slice matrix 红测阻止该
slice Review/acceptance，不能以“P1-F1/F2 再测”延期。

## 11. 验证命令

Review11 是已经完成的 A1b named predecessor，A1b 的最终 implementation Review
与 acceptance 也已通过；这些历史证据不替代 A2 plan review。Review12 已在旧
candidate 上判定 `CHANGES REQUIRED — 0 P0 / 2 P1`，也是 immutable predecessor。
Review12A 在 R12-C candidate 上判定
`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`，SHA-256
`a102c49138fcfc1f40b0c780990d8c3ad5ec2302b175b043bde9457164331337`，同样是
immutable predecessor。Review12B 在 R12-D candidate 判定
`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`，SHA-256
`66b81e9e5ea0f74e08706c7367f2e80180601a000c9e84c1bbd4357a9c3b4ec5`，也是
immutable predecessor。Review12C 是R12-F的immutable approved predecessor；
Review13在R13 exact hashes上判定
`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`，SHA-256为
`5203057f2a4a7f04827d9f5e0f20b717e08a31125404483b11f5cad722bda66b`。
Review13B后来批准implementation opening；R13技术实现完成后，Review01因
normal-root incident判定`CHANGES REQUIRED — 0 P0 / 1 P1`，两者现在都是immutable
predecessors。Review14又以bundle provenance缺口判定
`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`。Review15随后批准了R15 bundle-
provenance计划，但获授权的R15 execution在BEGIN attestation false negative后、
任何技术门前永久`REJECTED_CONTAMINATED`。Review16随后批准R16 plan，牧场主也
提供四hash授权；R16 external checks全绿后在pre-BEGIN`pgrep rc=1`被全局ERR trap
抢占，授权未消费且零写入、零后续门。Review17随后在R17 frozen hashes上判定
`CHANGES REQUIRED — 0 P0 / 1 P1`，R17未执行；该finding只允许R18把单一
phase-aware RanchArt exact-27/nonregular verifier的zero-write preflight移到授权
消费前最后位置，并在消费后同源重读、写证据。随后获明确授权的R18-A只关闭
pre-freeze发现的R15 volatile-root current-state drift：历史empty观察不变，current
exact paths是absorbing `ABSENT` tombstones，联合parent enumeration及任一node重现/
indeterminate都fail closed；一个C职责替换但inherited 13/driver-total 14计数不变。
Review18随后以newline pathname transport collision判定
`CHANGES REQUIRED — 0 P0 / 1 P1`，R18未执行。Review19已批准R19，牧场主也提供后续
四hash授权；R19 41/41 A2 gate通过，但authoritative full RunTests 651/652，因此永久
rejected且没有运行build/matrix/source/bundle/preview。Review20随后批准R20并获四hash
授权；R20唯一full 652/652、同log 46/46、debug build与LAUNCH_READY通过，但release
Core `--product`触发automatic-product fallback/default graph及DEBUG caller/callee配置
错配，故永久rejected，后续symbol/matrix/source/preview/END未运行。

只有职责隔离Review21在`evidence/plan-freeze-r21.md`记录的R21 Stage、总Plan、A2
leaf、control、`evidence/r21-begin.sh`与`evidence/r21-entry.sha256` exact hashes上给出
`APPROVED — 0 P0 / 0 P1`，且牧场主在后续新turn以四个最终hash再次授权，才可开始
新的R21 one-file guard implementation/clean re-verification。此前不得以既有green、
R19 41/41、R20 652/652/46/46、isolated run或serial/filter替代R21 full suite，也不得
实施TestSuite guards或修改Core及任何其他产品/test byte。批准并另获执行授权后，完整
SQLite 3.51/3.52 matrix、
全部既有/R11/A2 命名测试、source sentinels 与 diff/hash checks 仍是不可跳过的
硬门。实施与最终验证期间以下进入指纹必须逐字不变：

- `Package.swift`：
  `577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d`
- `Package.resolved`：
  `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a`
- `Sources/RunTests/main.swift`：
  `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3`
- `scripts/run-app.sh`：
  `5b34e5e98a0e91b4087e20525c3aba81e7955475865d2af70e6ae65736e7997b`
- `scripts/package-app.sh`：
  `7891aef62cfe26caef766572b5258f0fe206b7ccd8b6f039700834276e6a1705`
- dev Info.plist literal：
  `5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58`
- RanchArt 27-file canonical source manifest：
  `4f73a80e821faa64d0a29d797cc12e20d5f88248bbb186e74972af49798ddbab`

每个 slice 至少：

```bash
set -euo pipefail

swift run RunTests
swift build --product AgentLoopApp
scripts/verify-p1-migrations-sqlite-matrix.sh --sqlite 3.51 --sqlite 3.52
git diff --check
git status --short --branch
```

A1b 另必须执行并保存以下 fail-fast source/release gates；任一空输入、计数不符或
命中都失败：

```bash
set -euo pipefail

assert_rg_absent() {
  local pattern="$1"
  shift
  local matches
  local status
  if matches="$(rg -n -- "$pattern" "$@")"; then
    printf '%s\n' "$matches" >&2
    return 1
  else
    status=$?
    if test "$status" -eq 1; then
      return 0
    fi
    return "$status"
  fi
}

swift build -c release --target AgentLoopCore

assert_rg_absent 'suppressForOrchestratorRecoveryFailure' \
  Sources/AgentLoopCore

core_total="$(rg -o 'injectOwnedSuccessProposalForTesting' \
  Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift | wc -l | tr -d ' ')"
core_guarded="$(perl -0ne \
  'while (/#if DEBUG\b((?:(?!#endif).)*)#endif/sg) {$b=$1; $n += () = $b =~ /injectOwnedSuccessProposalForTesting/g} END {print $n+0}' \
  Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift)"
test "$core_total" = 1
test "$core_guarded" = 1

test_total="$(rg -o 'injectOwnedSuccessProposalForTesting' \
  Sources/AgentLoopTestSuite/DurablePlanningTests.swift \
  Sources/AgentLoopTestSuite/PlanningTestFixtures.swift | wc -l | tr -d ' ')"
test_guarded="$(perl -0ne \
  'while (/#if DEBUG\b((?:(?!#endif).)*)#endif/sg) {$b=$1; $n += () = $b =~ /injectOwnedSuccessProposalForTesting/g} END {print $n+0}' \
  Sources/AgentLoopTestSuite/DurablePlanningTests.swift \
  Sources/AgentLoopTestSuite/PlanningTestFixtures.swift)"
test "$test_total" -gt 0
test "$test_guarded" = "$test_total"

release_object_list="$(
  find .build -type f \
    -path '*/release/AgentLoopCore.build/*.o' -print
)"
test -n "$release_object_list"
release_nm_output="$(
  while IFS= read -r release_object; do
    test -n "$release_object"
    object_nm="$(nm "$release_object")" || exit $?
    printf '%s\n' "$object_nm"
  done <<< "$release_object_list"
)"
if release_matches="$(
  printf '%s\n' "$release_nm_output" |
    rg -n 'injectOwnedSuccessProposalForTesting'
)"; then
  printf '%s\n' "$release_matches" >&2
  exit 1
else
  release_status=$?
  test "$release_status" -eq 1
fi
```

P1-A2 R13还必须在release build后执行并保存以下零符号/DEBUG caller gate。pattern
覆盖scenario types/cases、storage、arm与consume token；空输入、任何release
match或任何unguarded occurrence均失败：

```bash
set -euo pipefail

a2_seam_pattern='A2RuminationAuthorization(Checkpoint|Loss|Scenario)ForTesting|a2RuminationAuthorizationScenarioForTesting|armA2RuminationAuthorizationScenarioForTesting|consumeA2RuminationAuthorizationScenarioForTesting'
a2_core='Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift'
a2_tests='Sources/AgentLoopTestSuite/CodingRanchTests.swift Sources/AgentLoopTestSuite/DurableWorkTests.swift'

swift build -c release --target AgentLoopCore
a2_root='/Users/muzi/Agent-loop'
a2_release_bin="$(swift build -c release --show-bin-path)"
test -d "$a2_release_bin" && test ! -L "$a2_release_bin"
test "$(/bin/realpath "$a2_release_bin")" = "$a2_release_bin"
a2_release_rel="${a2_release_bin#"$a2_root/.build/"}"
[[ "$a2_release_rel" =~ ^[^/]+/release$ ]]
a2_release_object="$a2_release_bin/AgentLoopCore.build/DurableWorkSupervisor.swift.o"
test -f "$a2_release_object" && test ! -L "$a2_release_object"
if a2_release_nm="$(
  set -o pipefail
  nm -j "$a2_release_object" | xcrun swift-demangle
)"; then
  :
else
  exit $?
fi
test -n "$a2_release_nm"
if printf '%s\n' "$a2_release_nm" | rg -ni -- "$a2_seam_pattern"; then
  exit 1
else
  test "$?" -eq 1
fi

for source in "$a2_core" $a2_tests; do
  total="$(rg -o -- "$a2_seam_pattern" "$source" | wc -l | tr -d ' ')"
  guarded="$(perl -0ne '
    while (/#if DEBUG\b((?:(?!#endif).)*)#endif/sg) {
      $b=$1;
      while ($b =~ /A2RuminationAuthorization(?:Checkpoint|Loss|Scenario)ForTesting|a2RuminationAuthorizationScenarioForTesting|armA2RuminationAuthorizationScenarioForTesting|consumeA2RuminationAuthorizationScenarioForTesting/g) {$n++}
    }
    END {print $n+0}
  ' "$source")"
  test "$total" -gt 0
  test "$guarded" = "$total"
done

a2_debug_bin="$(swift build -c debug --show-bin-path)"
test -d "$a2_debug_bin" && test ! -L "$a2_debug_bin"
test "$(/bin/realpath "$a2_debug_bin")" = "$a2_debug_bin"
a2_debug_rel="${a2_debug_bin#"$a2_root/.build/"}"
[[ "$a2_debug_rel" =~ ^[^/]+/debug$ ]]
a2_debug_object="$a2_debug_bin/AgentLoopCore.build/DurableWorkSupervisor.swift.o"
test -f "$a2_debug_object" && test ! -L "$a2_debug_object"
if a2_debug_nm="$(
  set -o pipefail
  nm -j "$a2_debug_object" | xcrun swift-demangle
)"; then
  :
else
  exit $?
fi
test -n "$a2_debug_nm"
printf '%s\n' "$a2_debug_nm" | rg -ni -- "$a2_seam_pattern" >/dev/null
```

#27/#31/#35的source-order assertions必须调用既有
`PlanningTestFixtures.uniqueFunction`，使用masked comments/strings与唯一
brace-enclosed range；不得以`codingRanchSourceRange`、substring/count-only或复制
helper证明handler、validator、provider/parse callsites、consume caller或owner
顺序。它必须锁consume caller只在`handleValidatedRuminationTurn`的
first-after-real-gates-before-organizing与
second-after-awaited-organizing-and-real-gates-before-parse两处，
且两个caller均在matching `#if DEBUG`；release caller与上述全部seam符号为0。

R21另须按Stage §28.8.3与A2 leaf §10执行新增四object双向门。release命令必须依次为
`swift build -c release --target AgentLoopCore`与
`swift build -c release --target AgentLoopTestSuite`。只从canonical
`swift build -c release|debug --show-bin-path`构造exact
`AgentLoopCore.build/AgentLoop.swift.o`与
`AgentLoopTestSuite.build/AgentLoopTests.swift.o`；禁止`find -quit`、glob、候选fallback或
固定共享`/tmp` nm文件。Core `idleClockForTesting`必须release=0/debug>0；R21冻结的
TestSuite六helper/function tokens与五test tokens必须逐项release=0/debug>0；每个
`nm -j | xcrun swift-demangle` pipeline任一端非零或空输出都失败。release Core object
在第二条target build前后hash必须相同。source gate还必须证明TestSuite恰有三对direct
non-nested DEBUG guards，并在只移除六行directives后精确恢复R20 final TestSuite hash。

R15/R16 failure containment、R17/R18 not-executed与R19/R20 rejected evidence证明matrix
从未在这些失败边界完成；R21 planner与Review21也不修改matrix script，current entry
script SHA-256保持
`75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c`。
Review21批准、新用户以四个最终hash授权、static manifest全绿且R21 BEGIN已写入
后、R21 matrix执行前，只允许继承R12-A例外机械同步该script唯一
`expected_stage_hash` 64-hex为`plan-freeze-r21.md`冻结的R21最终Stage hash；
matrix完成或失败后必须恢复predecessor Stage value
`a8ca6e7a56a32e945bae185724a51d4e0015d61676bf02d9637fedc2c27d9b6f`
与上述entry script hash，其他bytes不得改变。恢复是mandatory containment，不得
继续失败的gate；R21 END必须再次证明final script delta=0。
R12-F/R15 restoration与containment proof继续作为immutable历史，不替代本轮
current-value restoration gate。

P1-A/B/D/E 还必须：

```bash
scripts/run-app.sh --preview
```

上面是其他slice的历史通用命令，**明确不适用于A2 R21**。A2 R21禁止执行或截取
`scripts/run-app.sh`与`scripts/package-app.sh`，禁止`open`/LaunchServices，只能
在Review21批准并另获四hash执行授权后，执行A2 leaf §11冻结的fresh bundle assembly与
exact-path direct exec。

P1-A1b 还必须在同一 frozen hashes 上执行并保存完整输出：

```bash
set -euo pipefail

assert_rg_absent() {
  local pattern="$1"
  shift
  local matches
  local status
  if matches="$(rg -n -- "$pattern" "$@")"; then
    printf '%s\n' "$matches" >&2
    return 1
  else
    status=$?
    if test "$status" -eq 1; then
      return 0
    fi
    return "$status"
  fi
}

swift run RunTests
swift build --product AgentLoopApp
scripts/verify-p1-migrations-sqlite-matrix.sh --sqlite 3.51 --sqlite 3.52
scripts/run-app.sh --preview
assert_rg_absent 'planningTasks' \
  Sources/AgentLoopCore/Kernel/Orchestrator.swift
printf 'source.planning_tasks=pass\n'
assert_rg_absent \
  '\b(createMissionShell|recordPlanningTokens|recordPlanFallback|planMission)\s*\(' \
  Sources/AgentLoopCore Sources/AgentLoopApp
printf 'source.split_planning_api=pass\n'
assert_rg_absent \
  '\borchestrator\.(startMission|confirmSquadProposal)\s*\(' \
  Sources/AgentLoopApp/AppStore.swift \
  Sources/AgentLoopApp/CodingRanchStoreAdapter.swift \
  Sources/AgentLoopApp/MissionScheduler.swift
assert_rg_absent '\bdb\.claimScheduleFire\s*\(' \
  Sources/AgentLoopApp/MissionScheduler.swift
assert_rg_absent '\b(factory\.)?linkConverted\s*\(' \
  Sources/AgentLoopApp/CodingRanchStoreAdapter.swift
printf 'source.app_planning_entry_delegation=pass\n'
assert_rg_absent \
  'public func (claimNextPlanning|renewPlanningLease|nextClaimablePlanningDate|adoptInterruptedPlanning|commitPlanningSuccess|recordPlanningAttemptFailure|recordPlanningUsageOverflow|cancelPlanning|cancelAllPlanningForEmergencyHalt|repairLegacyPlanningMissions)\b' \
  Sources/AgentLoopCore/Database/AppDatabase.swift \
  Sources/AgentLoopCore/Database/DurableWorkStore.swift
printf 'source.planning_specialized_api_internal=pass\n'
assert_rg_absent \
  'kind: DurableWorkKind = \.planning|kinds: \[DurableWorkKind\] = \[\.planning\]' \
  Sources/AgentLoopTestSuite/DurableWorkTests.swift
printf 'source.generic_durable_work_fixture_not_planning=pass\n'
ledger_owner_count="$(
  rg -n '^fileprivate enum PlanningDurableWorkLedgerOwner\b' \
    Sources/AgentLoopCore/Database/DurableWorkStore.swift |
    wc -l | tr -d ' '
)"
test "$ledger_owner_count" = 1
printf 'source.planning_ledger_owner_fileprivate=pass\n'
git diff --check
git status --short --branch
shasum -a 256 \
  docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md \
  docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md \
  docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a1b-durable-planning/plan.md
```

这些 sentinel 与 §3.2 的 source-order tests共同构成零旁路门：命中旧定义或调用、
compatibility overload、`planningTasks`、App direct start/claim、public
specialized mutation或 generic planning默认 fixture都失败；唯一 fileprivate ledger
owner必须恰好一处。测试 fixture 中对历史名字的字符串断言不算 production命中。
本 code block 是 A1b 全量 source sentinel 的唯一可执行版本；leaf §14 的旧代码块
只保留命令/regex inventory，不得直接整块执行。所有实际运行必须经过这里的
`set -euo pipefail` 与 `assert_rg_absent`，不得把 `rg` error 当作 no-match，也不得
在失败 `test` 后打印 pass。
另保存 allowlist 对照、实现前后产品/测试/Package/RunTests hashes、R-01
failure-first、failure-injection 与 named `v12-durable` 两 lane sentinels。完整输出分别写 A1b
task 目录的 `verify.log`、`build.log`、`migration-matrix.log`、`preview.log`，
不得以摘要或 A1a 历史日志替代。

使用独立 `AGENTLOOP_STATE_DIR`，不得指向 normal root。UI smoke 保存启动命令、state root、进程、截图和注入故障方式。
P1-E smoke 必须分别保存普通 Ingestion 删除成功后 inbox/dashboard 已刷新再关页，
以及 Store/refresh 注入失败后仍留页并显示 trace ID 的证据；另保存
commit→refresh failure→相同 pending command/key receipt replay→refresh
success→close，全程未生成第二 key/event/outbox/delete 的持久化证据；另保存
prepared cancel、verified rollback后同 handle回 prepared、executing cancel与
commit竞态、三种 executionResolutionPending disposition、committed dismiss后普通
reload，以及 process death在 commit前/后只恢复持久事实的四 phase证据。

P1-F1/F2：

- fake CLI conformance 是权威自动测试；
- 若当前 Codex/Claude CLI 登录可用，再做固定、低风险、无秘密的 live smoke；
- live 失败如实记录，不以 contract fake 冒充真实供给线；
- 不修改、删除或重登用户凭据。

完整输出写对应 task 的 `verify.log` / `build.log`，不能只保存摘要。

## 12. Review 清单

每个 Review 除协议标准项外必须检查：

- 是否只改当前子阶段允许文件；
- migration 是否 append-only、可重放、无数据依赖；
- transaction 是否同时提交 projection/event/work/outbox；
- 所有 running/in-flight 是否有 restart/cancel/failure；
- idempotency key 同内容重放与异内容冲突；
- stale lease/version 是否 fail；
- hash-bearing JSON 是否唯一经 CanonicalJSONV1，prompt-only transport 的
  sortedKeys 是否保持且未冒充 hash 真相；
- Int/backoff/usage 是否防 overflow；
- DB/Keychain/MCP/knowledge 错误是否仍有空 fallback；
- Camp auth 是否只看 active residency / bridge；
- ordinary Camp write与 opaque deletion permit是否完全职责隔离，generic
  campDeletion authority是否仍 sealed；
- owner/private-column registry是否覆盖 schema、raw write、provider dispatch与
  scoped filesystem，legacy globalCow是否不被过删；
- provider returned checkpoint是否不重呼，pending proposal是否只走 F2 specialized
  supersession，cleanup ledger是否进入GC/finalize；artifact ownership是否只凭 typed
  provenance/no-follow proof，unresolved是否只可typed重检或detach-only且永不unlink；
- every redacted carrier是否 one-shot、逐 retained-column exact、post-redaction
  full-row immutable、DELETE guarded；deleted typed JSON 是否 redacted-first；
- 九张 append-only carrier 是否从 introducing migration 起就有完整 pair；v16 是否
  只替换五张 UPDATE、在 committed boundary 保留/重建 DELETE；exact checkpoint
  2/4/4/4/8/16/67/84 与双 SQLite literal/GRDB 两类证据是否同时成立；
- ordinary deletion command是否只由 Store prepare factory从 caller-free request
  与一致性 DB snapshot铸造；Controller/Application能否注入 row facts或绕过
  prepare；execute是否全量 revalidate TOCTOU；
- registry是否 AppDatabase instance-owned、pool前建立并由 AppDatabase强持有，
  `prepareDatabase`是否为唯一 release/product install caller且只有列明 DEBUG
  scenario runner的 internal-fixture例外；runtime lookup是否也只接 `Database`，
  pointer+nonce/role/weak-cell exact且 readonly/cross-connection fail closed；Permit
  file是否 raw SQLite/GRDBSQLite/context/callback/Unmanaged唯一
  owner，registration是否 exact `nArg=-1 + SQLITE_UTF8`、无
  deterministic/DIRECTONLY/`DatabaseFunction`；xFunc是否严格53/63 arity/type/
  nullability且无 DB reentry/正文；install是否在同一 private boundary内完成
  preflight/provisional publish，解锁后才调用 callback-capable C API，返回后再
  reconcile，duplicate pointer是否在 C call前以 sticky typed failure且零
  purge/replacement结束；xDestroy是否 takeRetained exact once、先 invalidate再
  exact remove，registration failure是否零 manual release，later setup throw是否
  仍由 teardown exact cleanup；successful close、BUSY、close_v2 zombie、pointer
  reuse是否逐项按合同收敛；missing/wrong/replaced/duplicateCleanup是否只经 runner
  内部仍强持 typed fixture的 helper注入，绝不二次调用 destructor；DEBUG package
  probe是否只有 exact lifecycle/mismatch enums、内部自有隔离 fixture与 immutable
  counters/flags/booleans，是否复用唯一 raw call、不接外部
  Database/AppDatabase/path/pointer/closure、不泄漏任何 capability且只被列明 lifecycle
  tests调用；mismatch runner是否内部逐项验证 sticky后的
  setup/mutation/resolution typed rejection；Permit-owned resolution assertion是否独占 raw
  `sqlite3_get_autocommit`，Store/Controller不 import GRDBSQLite或引用 raw symbol；
  Package是否只给 AgentLoopCore增加同一 GRDB package的 direct
  GRDBSQLite product且 Package.resolved不变；afterNextTransaction +
  exact-generation defer是否覆盖 commit/rollback/throw/manual boundary/reuse；
- command whole hash/permit/finish是否绑定完整 CommandEnvelope；event专列、
  Store recordedAt与 initial outbox是否 exact；receipt/event JSON是否拒绝 actor/
  device/account identifiers；cursor是否包含 outbox且 replay不追加第二 outbox；
- receipt/event/permit是否双向绑定 lifecycle/version、两个 snapshot、三项 affected
  count与五项 fixed-zero blocker，live NOT EXISTS是否保留，candidate/link永久不可删；
- adapter/controller/UI是否只有 prepare/execute/SELECT-only resolve opaque pending
  seam且 single-flight；prepared/executing/executionResolutionPending/
  committedRefreshPending 的 cancel/dismiss/commit/refresh race是否以 typed
  resolution收敛；verified rollback是否同 handle回 prepared；unknown/integrity/
  conflict是否按 receipt type/hash/eventCount/result与完整 event graph穷尽互斥，
  并分别限制为只读 resolve/repair block/abandon-reconfirm；同型 malformed receipt
  是否 fail closed；session-local relaunch是否只信 persisted truth，无 direct DB
  delete、permit调用、automatic replay/new key或 optimistic success；
- resolver是否唯一经同 AppDatabase `DatabasePool.writeWithoutTransaction`，入口
  not-in-transaction/autocommit=1，是否只调用封闭
  `assertNoActiveGenerationForResolution`并 exact验证 pointer+nonce/writer/empty
  generation、不返回或修改 cell；replay/new-key execute preflight/resolver/prepare
  是否共用唯一完整 graph validator；expectedCommand/selfContainedScan模式是否
  精确，是否从 event专列+19-field typed payload重建 canonical command whole hash并
  与三处 persisted copy及 sealed handle匹配，而非只查64-hex/互相相等；new-key
  preflight是否在 own evidence/permit前
  重扫并关闭 prepare→execute integrity race；是否拒绝 generic lookup、pool
  read/write/barrier variant、新 transaction/
  observer与任何 DML/UDF/permit；
- v16/v17任何 trigger是否只在完整 graph/rebuild/rename/backfill/assertion barrier后
  安装；v16四个 surviving-table drops是否 barrier后固定顺序、无 IF EXISTS、其后无
  DML，五个 DROP TRIGGER最大 ordinal是否小于first CREATE TRIGGER最小 ordinal；
  每个 drop/last-drop→first-create/trigger中途 rollback snapshot是否逐字恢复，
  3.51/3.52是否跑同一真实 migrator；
- verifier 与 producer 是否独立；
- acceptance 是否先持久化后导航；
- Grant 是否 scope/time/capability 完整；
- CLI resume 是否使用 exact session ID；
- error/log 是否无秘密；
- 新 UI 状态是否来自事实而非动画推断。
- A2 R21是否完整保留R13 `REJECTED_CONTAMINATED` incident、Review01、mutation
  unknown、R14 freeze/Review14 finding与R15 BEGIN false-negative boundary；
  R15的freeze/Review15/boundary/hash-manifest/report、八个空日志、缺失截图和
  containment时canonical-empty观察是否immutable；current两个exact paths是否作为
  absorbing `ABSENT` tombstones以parent enumeration证明、只记录per-path observed
  state/proof identity/`disappearance_cause=UNKNOWN`且任何node重现/indeterminate都
  fail closed；R16 driver/manifest/freeze/Review16、未消费授权与全部runtime/root
  absence、R17 driver/probe/manifest/freeze/Review17/not-executed absence，以及R18
  driver/manifest/freeze/Review18/not-executed absence是否全部immutable；zero
  normal-data access是否只限定到新的R21 one-shot clean
  boundary；
- R19 reviewed Bash driver及其实际BEGIN/41-pass/full-651-of-652 rejection是否完整
  保留为immutable历史；其11个artifacts、缺失screenshot与两个exact empty roots是否
  未被补写、删除、清理、复用或洗绿；R20唯一full 652/652、46/46、LAUNCH_READY与
  release build rejection是否完整保留，R20两个final sources、11 artifacts、absent
  screenshot、exact empty state root与含signed App的bundle parent是否immutable；R21
  reviewed Bash driver是否在clean environment
  中只消费静态
  `r21-entry.sha256`并执行`shasum --strict -c`，没有复用R15临时zsh helper或动态
  expected/actual map；static manifest全绿后BEGIN是否在任何test/build/matrix/
  source/bundle/preview前只记录frozen inputs、planned fresh bundle/state paths与
  no-process，而没有伪造尚未生成的final hash；single phase-aware verifier是否在
  授权消费前最后一次zero-write读取exact-27/zero-nonregular，消费后是否从filesystem
  同源重读并写结构证据，随后是否独立重跑155-entry strict manifest逐文件复核27个
  RanchArt bytes，且没有把冻结identity constant写成derived proof或虚构atomic
  filesystem lock；actual pathname是否由单一NUL pipeline无损transport、完整drain、
  actual-byte seen/type proof后才safe serialize；R19 historical
  `3P/3S/3C=9`/driver-total `3P/3S/4C=10`与R20 historical
  `5P/3S/7C=15`/driver-total `5P/3S/8C=16`是否保持immutable，R21 current
  `8P/4S/8C=20`/driver-total `8P/4S/9C=21`是否精确，immutable Bash 3.2 probe
  是否继续覆盖S/P/C真实status；
  POST_BUILD/PRE_SIGN/LAUNCH_READY是否完整证明source/build executable、
  RanchArt resources、inline plist、unsigned copy、ad-hoc signature、post-sign
  hash/UUID/CDHash/signed manifest链；
- bootstrap/cold start是否复用同一LAUNCH_READY bundle、只按full path/own PID
  direct exec且禁止display-name/bundle-id/Dock/frontmost/NSWorkspace/
  LaunchServices、两个App scripts及LAUNCH_READY后rebuild/re-sign；
- R21是否保持`AgentLoop.swift` R20 final bytes，只让`AgentLoopTests.swift`新增三对
  exact direct DEBUG guards、其他产品/test/App/RunTests/matrix-script零漂移并只写distinct
  全新`r21-*` artifacts；entry时155/155、implementation后是否exact 154 unchanged + 1
  authorized mismatch；移除六directive lines后是否恢复R20 TestSuite hash；target-exact
  Core/TestSuite release builds是否都成功，四exact objects是否canonical且
  `idleClockForTesting` Core release=0/debug>0、11个TestSuite tokens逐项
  release=0/debug>0；未过滤full suite是否一次
  全绿、五项+原41是否从同一日志机械审计46/46且没有`--filter`/retry；
  matrix临时单值
  delta是否恢复；任一normal-root access/第二进程/wrong bundle/path/env/PID/
  provenance或证据缺口是否即整轮停止且同boundary零retry；Review02与acceptance
  是否同时披露历史incident、R15 false negative、R16 pre-BEGIN未消费/零写入
  false positive、R17/R18 plan rejection/not-executed、R19 full rejection及R20 release
  rejection，并只声明R21 boundary内zero access。

## 13. 子阶段失败与回退

- red test：留在当前子阶段，保存完整日志，定位根因。
- migration 失败：不修 normal DB；用临时 DB 复现并修 migration。
- 计划外架构需求：写当前 task `blocked.md`，停止该 slice。
- Claude/reviewer 不可用：按协议重试一次；使用职责隔离、证据可追踪的获授权替代 reviewer；实现者不得自批。
- 三轮 Review 仍有 P0/P1：升级牧场主，不跨门。
- App preview 无法证明错误 UI：保存启动/进程/日志证据，不用 build 代替。
- 以下两项是R19历史fail-once合同且其full-test rejection已经消费/关闭该boundary，
  不重新开门。A2 R19在boundary exclusive-create前发生static-attestation、R15 tombstone parent
  enumeration indeterminate/任何node重现或其他preflight failure：零repository/runtime
  write立即停止，`authorization_consumed=false`，不得虚构`REJECTED_CONTAMINATED`
  active boundary或在同一授权下重试；保留console事实并请求新的plan-level有界授权。
- boundary exclusive-create并写`authorization_consumed=true`后发生post-activation
  re-read failure、normal-root access、第二App、display-name/
  LaunchServices lookup、wrong/stale bundle、source/resource/plist/copy/signature/
  UUID/manifest drift、LAUNCH_READY后rebuild/re-sign、wrong path/env/PID或证据
  缺口：整轮标记`REJECTED_CONTAMINATED`并立即停止，不得在同一boundary换root、
  修补或retry；保留evidence并请求新的plan-level有界授权。
- A2 R21在boundary前任一anchor、155-entry、R19/R20 immutable root/artifact/App或fresh-name
  preflight失败：保持零写入/授权未消费并停止。BEGIN后任一实现、unfiltered full test、
  46-name mechanical audit、target build/object symbol/matrix/source/provenance/preview失败，
  或出现第二个source
  delta：整轮永久`REJECTED_CONTAMINATED`，只做安全process containment，不得在同一
  boundary修补、换root、filter/serial/重跑或继续未开始门。
- 真实 CLI 不可用：contract tests 可以继续，但 P1 acceptance 必须把 live gap 写明；不得宣称真实可用。
- 任一子阶段发现总 spec 冲突：暂停并请求产品决定。

## 14. P1 最终交付

P1-F2 后创建：

- P1 `impl-report.md`：逐 R-01…R-09 映射；
- P1 `acceptance.md`：逐 stage spec §21 完成门；
- `migration-matrix.log`；
- `try-question-mark-inventory.md`；
- `engine-conformance.log`；
- `evidence/` 下匹配风险的 preview / live 证据；
- master spec 路线事实更新；
- `AGENTS.md` / `CLAUDE.md` / `README.md` 只同步已经成立的事实。

只有独立 reviewer 判定 P1 全部通过，才把 master P1 改为 Completed、P2 改为 Ready。不得在同一未 Review diff 中直接开始 P2。

## 15. Round 4 finding resolution matrix

这是 planner 对 authorized Round 5 revision 的映射证据，不是 Review 结论；冻结后
必须由职责隔离 reviewer 逐项复核，零 P0/P1 前 A1a仍禁止实施。

| Finding | Stage authority | Plan exact owner | Required test gate |
|---|---|---|---|
| R4-P0-1 retirement authority/recovery | Stage §6.2/§14.2/§16.3/§18.6 | A1a generic sealing；D Grant；E schema；F1 engine；F2 CampLifecycleStore/CampDeletionWorker | stale/wrong permit all dimensions、unarchive race、self-exclusion、engine-vs-Grant、4th failure/replacement/raw job trigger |
| R4-P0-2 privacy erasure | Stage §14.2 matrix；§18.4–18.7 exact fields/triggers | C inbox；D Verification/Acceptance/receipt；E attempt/event/legacy trigger；F1 proposal/discussion；F2 registry | each retained/null/default field；ordinary/wrong phase/second/extra diff/delete rejected；global no-overerase |
| R4-P0-3 legacy scope | Stage §14.2 resolvers；§18.6 three scope tables | E LegacyContentScopeStore/LegacyEventScopeResolver；F2 wiring | every nil-ref/global kind、DM/Guide/cowork/manual note、unknown/dangling/ambiguous/cross-Camp、post-v16 missing scope |
| R4-P0-4 owner/provider gap | Stage §14.2 provider ledger + owner registries；§18.6 dispatch DDL | E services/CampProviderDispatchStore；F1 engine/artifact/report；F2 mutation/dispatch registries | message/pre-start/started/returned/consume windows、fence races、all named source sentinels |
| R4-P1-1 candidate status | Stage §14.2 split quiescence/deletion + explicit ingestion/candidate preterminal transitions | F2 CampLifecycleStore、FeedService、RuminationService、IngestionRecords/Materializer | each status、no-work/work/provider、queued/ruminating/needsReview→discarded、proposed/accepted→dismissed、normal CAS race/restart |
| R4-P1-2 Outcome command | Stage §12.2/§19 | D OutcomeStore | initial v1 plus each five-source new version/downstream invalidation |
| R4-P1-3 GC root | Stage §16.3/§18.7 exact UNION | F1 ArtifactBlobStore | exact contentHash 23h/25h；proposalHash never root |
| R4-P1-4 artifact classification | Stage §14.2/§18.7 origin | F1 ArtifactStorageOriginStore；F2 classifier | managed/external/missing/symlink/prefix/permission/hardlink/pending/cross-Camp/concurrent |

## 16. Round 5 finding resolution matrix

这是 planner 对本轮获授权修订的追踪表，**不是 Review 结论**。冻结后必须由职责隔离
reviewer 独立复核；在其结论前 A1a 与全部产品代码实施继续关闭。

| Finding | Stage authority | Plan exact owner / allowed files | Required test gate |
|---|---|---|---|
| R5-P0-1 pending/in-flight deletion deadlocks | Stage §13/§14.2 specialized proposal/request/ingestion/candidate/reserved-use closeouts、§16.3 recovery | F1 Engine schema/stores；F2 CampLifecycleStore、ApprovalGrantStore、Feed/Rumination、CampDeletionWorker；EngineProposal/AskUser/Grant/Ingestion tests | proposal全shape；open request answer race；ingestion no-work/work；reserved no-dispatch evidence；permit/version/replay/crash、zero new side effects |
| R5-P0-2 legacy artifact resolution | Stage §14.2 confirmation/verifier/state machine；§18.6/18.7 ledgers | F1/F2 `ArtifactOwnershipVerifier`、ArtifactStorageOriginStore、ArtifactBlobStore、CampRetirementWorkflowController、CodingRanchContracts/UI | every unresolved reason、retry/detach authority、external/unknown unlink=0、managed-only permit、CAS/race/repair |
| R5-P0-3 privacy/origin/typed tombstone shape | Stage §14.2 exact matrix/redacted-first；§18.6/18.7 discriminators | F2 Stores + DTO/decoder/UI paths；user request、ingestion/candidate terminalReason/redactedAt/version、rumination/link/schedule redactedAt、origin/use/Engine | exact sentinel/terminal history；deleted decoder/hash/resume/filesystem=0；global/cross-Camp unchanged |
| R5-P0-4 mutable audit evidence | Stage §14.2 finalizing-only trigger contract；v16/v17 exact/post locks | AppDatabase migrations + every owning Store；Schedule/Ingestion/Provider/Deletion tests | first/second/no-op/extra diff、each retained column、DELETE；provider erasing abort；schedule scope drift；wrong phase/job/Camp |
| R5-P1-1 SQLite trigger order | Stage §18.6/18.7 full graph + phase barriers + dual lane | runner paths + SQLiteMigrationCompatibilityTests；through-v16/v17 exact 67/84 triggers | statement ordinal + same real migrator 3.51/3.52 fresh/v11/v15 populated/negative/replay/FK/integrity/snapshot rollback |

## 17. Round 6 / R8 finding resolution matrix

这是 R8 对 Review06、冻结前 pre-review findings 与 Review07 两个 P1 的
plan-level closure，**不是 Review08 结论**。本轮只按 E-071 的两个有界路径改写
既有合同；重新冻结并由职责隔离 reviewer在新 hashes上独立复核为零 P0/P1前，
P0 acceptance、A1a与产品代码实施继续关闭。

| Finding | Stage authority | Plan exact owner / allowed files | Required test gate |
|---|---|---|---|
| R6-P0-1 append-only guards 缺失 | Stage §18 introduction-time pair、五个 v16 UPDATE replacements、durable committed-boundary rebuild、67/84 | A1a AppDatabase/runner；C command/event；D Verification/invalidation/Acceptance/receipt；E memory/rebuild；F1 discussion；SQLiteMigrationCompatibilityTests | 每表 legal insert + ordinary/no-op update/delete；五表 exact first/wrong/second/extra/delete；domain-event scope 1:1；checkpoint 2/4/4/4/8/16/67/84；3.51/3.52 literal + real GRDB、failure rollback |
| R6-P1-1 现有普通 Ingestion 删除无 v16 后合同 | Stage §14.2 sealed command/SQL permit三 scope、UDF-gated guards、race/replay | P1-E AppDatabase、Permit registry、DomainEventStore、CampLifecycleStore、IngestionDeletion domain/store、Feed/Rumination/Materializer、Controller/App/Adapter/Contracts/LiveHosts/RuminationViews及列明 tests | 三 scope×status/lifecycle、五 blockers、affected counts、event identity、same-key replay/conflict、all races、raw wrong evidence/UDF、candidate/link permanent、dual SQLite、pending UI sentinel |
| R7-pre-P0-1 evidence-only DELETE 可跨 transaction或跳步骤 | Stage §14.2 connection/generation/ordered-step permit与 full snapshot重算；§18.6原位 UDF gates | AppDatabase instance registry；pointer+nonce cell；IngestionDeletionStore唯一 install/direct SQL；不增 migration/trigger | 虚报 result、跳 CAS、precommit receipt/scope/event/outbox、伪64-hex hash四反例；wrong connection/transaction/reuse；三合法路径 |
| R7-pre-P1-1 blocker identity 不完整 | Stage command/whole hash + receipt/event/permit五项 fixed-zero count，live NOT EXISTS | Domain command factory、Store、两枚 trigger/UDF与 Contract tests | 每项 missing/nonzero/live drift/race、same-key count change conflict，零 mutation |
| R7-pre-P1-2 refresh retry 会 mint新 command | Stage opaque pending prepare-once/execute/replay四 phase | InputWorkflowController pending owner；AppStore view state；Adapter/Contracts/LiveHosts/RuminationViews | commit→refresh fail→same-key replay→success；prepared cancel可清、executing不清、committed dismiss非撤销 |
| R7-pre2-P1-1 prepare boundary允许 caller facts | Stage request仅 envelope+Camp/ingestion/scope；Store read-snapshot唯一 factory；writer全量 revalidate | IngestionDeletionStore prepare/execute；sealed authority；Controller/App/Adapter只持 opaque handle | caller facts不可表示；safe preview无正文；prepare零写；TOCTOU逐维；single-flight |
| R7-pre2-P1-2 connection/transaction plumbing含 fallback | Stage instance registry、pointer+nonce weak exact cell、Database-only mutation/resolution lookup、53/63 raw UDF、generation + afterNextTransaction + defer | AppDatabase registry-before-pool + prepareDatabase唯一production install；Permit file raw context/xFunc/xDestroy registry及封闭 DEBUG fixture；Store两条封闭 lookup | readonly/wrong/cross-instance、close/destroy cleanup与pointer reuse、txn/no-txn、empty generation、arity/type、commit/rollback/throw/manual boundary/finish/reuse |
| R7-pre2-P1-3 Envelope/outbox/privacy/UI phase未闭合 | Stage whole envelope/event columns、Store recordedAt、safe JSON禁 identity、cursor含 initial outbox、pending四 phase | specialized Store evidence/outbox；DomainEventStore global contract；Controller/App/UI | nullability/time、identity-key拒绝、missing/wrong outbox、same-key no duplicate、prepared/executing/resolution/committed races |
| R7-pre3-P1-1 execute rollback 后 pending phase未定义 | Stage按 receipt type/hash/eventCount/result/完整 event graph返回 typed committed/notCommitted/resolutionPending；resolver唯一 writeWithoutTransaction + resolution assertion；shared validator唯一；session-local relaunch | IngestionDeletionStore execute/SELECT-only resolver/shared validator；Controller/App四 phase；Adapter opaque seam | rollback+receipt absent回同 handle prepared；writeWithoutTransaction no-txn/autocommit + exact empty-generation assertion；unknown只读 resolve；type/hash/count conflict abandon-reconfirm；每个 receipt/event/scope/outbox损坏 integrity block且 relaunch不可绕；同型 malformed receipt全局 deletion fail closed；relaunch committed-or-rollback reload |
| R7-pre4-P1-1 prepare integrity scan 存在 TOCTOU | Stage same-key absent后、permit/evidence前重扫全部同型 receipts并调用唯一 validator | IngestionDeletionStore new-key writer preflight；source sentinel只允许 shared validator | prepare→逐维注入可归属 fault或无法归属 malformed→execute零 own evidence/permit/mutation；scan通过才可 live revalidate/install |
| R7-pre5-P1-1 shared validator 未重算 command whole hash | Stage expectedCommand/selfContainedScan；event envelope专列+19-field typed payload重建 canonical whole hash；execute replay/resolver逐字段绑定 handle | IngestionDeletionStore唯一 validator/hash material；DomainEventStore CanonicalJSONV1 | arbitrary 64-hex三处copy + outer result/event hashes自洽仍拒绝；每个 envelope/payload drift replay失败；prepare/new-key scan也重算 |
| R7-P1-1 v16 fence 与 ordinal gate矛盾 | Stage §18.6 barrier后四个 fixed-order surviving-table drops、其后零DML、所有 trigger统一末相；五个 drops全计入 ordinal | E `AppDatabase.migrator`/matrix runner/`SQLiteMigrationCompatibilityTests`；不新增 migration/schema/trigger | literal+Swift trace证明 barrier<four drops<first create、无 IF EXISTS；all structural/drop max<first create；每个drop/last-drop→first-create/trigger midpoint rollback逐字恢复v15 schema/data/16 triggers；3.51/3.52仍67/84 |
| R7-P1-2 GRDB DatabaseFunction无法在connection close立即清cell | Stage §14.2 raw `sqlite3_create_function_v2+xDestroy`唯一ownership、provisional install/reconcile及SQLite真实销毁语义 | E `ActiveIngestionDeletionSQLPermit.swift`唯一raw owner；AppDatabase registry-before-pool/prepare唯一production install；Permit内封闭 DEBUG fixture；Package仅AgentLoopCore direct GRDBSQLite，resolved不变 | Swift6/GRDB7 source sentinel；preflight/provisional publish/unlock-C-call/reconcile；封闭 DEBUG scenario runner复用唯一 raw call，覆盖 duplicate pointer零C、registration failure/later setup throw/direct pool close/BUSY/close_v2 zombie/helper-only sticky mismatch/256次 bounded pointer reuse且零能力泄漏；setup/mutation/resolution fail closed |

### 17.1 R9 SQLite diagnostics `NULL/UNKNOWN` closure

这是 R9 对 A1a 实测暴露之同一 SQLite `CHECK(NULL)` 根因的 plan-level closure，
**不是 Review09 结论**。

| Finding | Stage authority | Plan exact owner / allowed files | Required test gate |
|---|---|---|---|
| R9-P0-1 三张 durable-work 表的最终 diagnostics matrix 可在 NULL/UNKNOWN 时 fail open | Stage §18.1 与 §18.6 只给六个既有 matrix 外包 `COALESCE(..., 0)`；inner matrix不变 | A1a 只在既有 AppDatabase/test/runner允许文件修正 v12；E 后续只在既有 v16 owner/runner/tests复现同一 wrapper；不增 schema/API/dependency | exact 7 mechanism sentinels；v12 19/v16 21 legal controls；56/40/288/384 normalized truth tables及固定 verdict counts；A1a v12、E v16各跑3.51/3.52 literal+real GRDB；旧 v12/v15 三类 poison→v16 fail+canonical logical snapshot rollback |

新 hashes 上职责隔离 Review09 判定零 P0/P1 前，A1a acceptance、A1b 和其他产品
代码实施继续关闭。

## 18. R12–R21 closure and freeze gate

R12 只关闭 A2 `blocked.md` 的 B1–B5，并把决定落实到 Stage §6.4、本文 §3.3/
§10/§11、A2 leaf 与控制索引；不改变任何已验收 A1a/A1b 产品语义或证据。

| Finding | Exact owner / scope | Hard evidence |
|---|---|---|
| recovering UI | Contracts、RuminationViews、Adapter/App接线 | source-range gate + isolated preview |
| single Supervisor | DurableWorkSupervisor、Orchestrator | production instance count、global FIFO、unified lifecycle tests |
| captured runtime/legacy | AppDatabase/Store、Orchestrator/AppStore、byte-identical strict resolver | canonical identity、drift/error/legacy matrix |
| terminal/usage/pending proposal | RuminationService、Supervisor、Store/AppDatabase | single typed production path、rollback/no-recall/restart tests |
| complete acceptance | 两份允许 tests 与 A2 evidence | 41 exact names、A1b regression、release/source/matrix/privacy/preview |

R12-A 只允许 planner 将
`scripts/verify-p1-migrations-sqlite-matrix.sh` line 115 的
`expected_stage_hash` 同步为最终 R12 Stage hash；恢复旧 value 时整份 script
必须恢复旧 SHA-256 `b51129fe71cc7074f644ba8d0969ddb98aa664253887ea6c3840baa6655e5be5`。
Review12 核对此 delta、candidate hashes 与 immutable manifests，且判定
`APPROVED — 0 P0 / 0 P1` 前，A2 产品/测试 implementation gate 保持关闭。

Review12 对原 candidate 的 immutable 报告 SHA-256 为
`f27379bfc96a224715e7c6a59ad62fa79d8d97c4d73cf41e890a6ce16957a7c3`，verdict
`CHANGES REQUIRED — 0 P0 / 2 P1`。R12-B 不扩大 allowlist，只在 B3/B4 既有授权内
机械关闭：

| Review12 finding | R12-B exact closure | Required re-review |
|---|---|---|
| P1-1 organizing-before-parse 无 owner/API | Stage §6.4.7/§6.4.9 与本文 §3.3 冻结 opaque validated turn、唯一 provider/parse API、Supervisor两次 ownership/latest-claim revalidation、唯一 awaited phase-only sink及 control-loss收口 | tests #27/#31/#35 exact subcases + source gate |
| P1-2 halted+invalid legacy 未定义 | Stage §6.4.6 冻结完整8-cell表；durable mode先线性化，halted对四种snapshot统一 emergency-halt canceled | test #39穷尽8格、restart/resume/external-call=0 |

旧 `reviews/12-p1-plan-review.md` 与旧
`p1-a2-durable-rumination/evidence/plan-freeze.md` 必须 byte-identical；R12-B
另写 `evidence/plan-freeze-r12b.md`。职责隔离 Review12A 在新 exact hashes 上判定
`APPROVED — 0 P0 / 0 P1` 前，A2 implementation gate继续关闭。

R12-B phase pre-audit 未创建报告文件，冻结结论为 `0 P0 / 1 P1 / 0 P2`：既有
Stage §6.4.9 control/fatal语义没有变化，但 completion/source gate 未机械穷尽两轮
出口。R12-C 只把该同根因补入现有 #27/#35 exact subcases、Stage completion与
真实 enclosing-range/call-order source gate；#31、41 test names、13+2 allowlist、
API/架构均不变。旧 Review12、旧 freeze 与 R12-B
`evidence/plan-freeze-r12b.md` 必须 byte-identical；R12-C 另写
`evidence/plan-freeze-r12c.md`。Review12A 仍是唯一下一门。

职责隔离 Review12A 已在 R12-C exact candidate 写出 immutable
`reviews/12a-p1-plan-review.md`，SHA-256
`a102c49138fcfc1f40b0c780990d8c3ad5ec2302b175b043bde9457164331337`，verdict
`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`。唯一 P1 是：第二轮 control loss 或
DB/invariant global fatal必须零业务写，persisted workId/attempt因而可保持不变；
positive-only sink没有 identity-bound invalidation producer，无法保证清除已发
organizing。

R12-D 只在该根因内把同一个 awaited callback payload改为 exact
`RuminationPhaseCommand.set|invalidate`，不增加 callback、KernelEvent、schema、
allowlist或test name。Supervisor唯一 invalidator对identity exactly-once，
唯一 async fatal/control owner按 capture→revoke positive set→await sorted
invalidate→cancel/return；Orchestrator exact identity registry/tombstone只在
matching invalidate时remove并发一次既有 changed event，App FIFO先clear再reload。
tests #27/#35 与真实 enclosing-range source gate覆盖两轮 expected loss、
DB/invariant、cancellation、stale/new-generation、positive revival、
terminal/retry/cancel/halt registry clear和restart recovering；#31、41 exact names
与13+2 allowlist不变。

旧 Review12、Review12A、`evidence/plan-freeze.md`、
`evidence/plan-freeze-r12b.md` 与 `evidence/plan-freeze-r12c.md` 必须
byte-identical；R12-D 另写 `evidence/plan-freeze-r12d.md`。未参与修订的 reviewer
只可创建 `reviews/12b-p1-plan-review.md`。Review12B 已写出 immutable
`reviews/12b-p1-plan-review.md`，SHA-256
`66b81e9e5ea0f74e08706c7367f2e80180601a000c9e84c1bbd4357a9c3b4ec5`，verdict
`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`：R12-D能清live phase，但phase-less
terminal commit与halt cleanup commit没有最终App persisted-projection refresh。

R12-E 只关闭该唯一P1，不新增callback、KernelEvent case、schema/migration/DDL、
EventKind、persistent phase/receipt、allowlist、test name或#31 subcase。唯一
invalidate command以
`RuminationInvalidationMilestone.phase(identity:reason:)|projectionCommitted(commitIdentity)`
承载两种milestone；public phase identity允许attempt0，positive phase操作要求
running/open attempt>=1，projection identity另带Store实际resulting
workVersion>=1。Store terminal/retry/cancel返回resulting work，halt cleanup返回
sorted actual commit identities；Supervisor同actor turn第一次await前reserve，
per-identity coordinator保证phase/projection sink串行。Orchestrator以full identity
receipt/per-work monotonic发typed optional-clear event；App按payload exact clear并
always serial reload。halt精确执行pre-clear→cancel tasks→persist→planning
cleanup→rumination commits→projection deliveries→didCommit/haltStateChanged。

旧 Review12、Review12A、Review12B、`evidence/plan-freeze.md`、
`evidence/plan-freeze-r12b.md`、`evidence/plan-freeze-r12c.md`与
`evidence/plan-freeze-r12d.md`必须byte-identical；R12-E另写
`evidence/plan-freeze-r12e.md`。未参与修订的reviewer只可创建
`reviews/12c-p1-plan-review.md`；R12-E freeze当时要求Review12C在该exact hashes
上判定`APPROVED — 0 P0 / 0 P1`前保持A2 implementation gate关闭，随后由下述
R12-F exact hashes取代。

R12-E candidate 后续有界审计（无 Review12C 报告）发现
`0 P0 / 2 P1 / 1 P2`：normal start/user retry commit没有projection refresh
publisher；仅在commit后await refresh仍会因actor reentrancy让既有pump先claim；
active replay若按current version合成milestone则会重复或碰撞新live generation。

获授权R12-F只关闭两个P1，不引入P2持久outbox/receipt。Orchestrator只作façade；
Supervisor唯一调用Store start，Store返回既有`DurableWorkEnqueueResult`。
`.inserted`在同步return后第一次await/reentrancy前validate queued attempt0/
exact `version=1`、reserve full identity并登记process-local global-claim barrier；
所有pump/timer/kick/claim入口零DB claim且零跨kind skip。delivery后release barrier、
重读mode/work、仅running+active才kick。preparation replay绕过resolver/Store，
transaction `.replayed`与其汇入同一workId waiter branch；两者零synthetic
milestone，delivered/restart无waiter时零第二event。目标ingestion所属Camp的
persisted snapshot必须成功load/ready后才enable command；failure保持disabled/
显式失败。start delivery暂停时cancel/halt更高version经既有coordinator严格排后。

R12-F独立预检（无Review12C文件）又给出`0 P0 / 1 P1 / 1 P2`：若同state root可有
第二production writer，target-Camp ready之后存在外部commit freshness窗口；同时
new insert可收紧exact version。closure选择冻结现有production single-writer合同，
不扩大event/replay refresh API：AppStore以lifetime-held
`StateDirectoryLock`在唯一同root production `AppDatabase(path:)`之前取得
`flock(LOCK_EX|LOCK_NB)`，第二owner fail-fast，process death/deinit释放；下一
owner必须重走startup snapshot ready。故该跨进程TOCTOU在当前产品不可达，replay
仍零milestone/零reload。new inserted work与start full identity exact
`version=1`；两个lock文件保持byte-identical、既有exclusive/release test必须全绿。
未来CLI/硬件同root写入须另开stage设计coordination/outbox，A2不得绕锁。

旧Review12/12A/12B与`evidence/plan-freeze.md`、
`evidence/plan-freeze-r12b.md`、`evidence/plan-freeze-r12c.md`、
`evidence/plan-freeze-r12d.md`、`evidence/plan-freeze-r12e.md`保持
byte-identical；R12-F另写`evidence/plan-freeze-r12f.md`。未参与修订的reviewer
仍只可创建`reviews/12c-p1-plan-review.md`；Review12C在R12-F exact hashes上判定
`APPROVED — 0 P0 / 0 P1`前，A2 implementation gate继续关闭。

### R14 Review01 P1-01 incident disposition

Review13B已在其exact candidate上判定`APPROVED — 0 P0 / 0 P1`。随后的R13
implementation完成41-name、652-test、build/release、双SQLite matrix、source/
privacy/hash gates与一个fresh isolated retry；但首次preview的UI display-name
lookup自动启动installed App PID 74836，并实际打开normal state root的
lock/DB/SHM/WAL。职责隔离Review01因此判定
`CHANGES REQUIRED — 0 P0 / 1 P1`。该整次R13 invocation固定为
`REJECTED_CONTAMINATED`，mutation因无pre-incident content hash保持`UNKNOWN`。

牧场主授权R14只在plan层定义一次前瞻性clean completion boundary：

- 旧`impl-report.md`、Review01、全部旧logs/evidence/screenshot与R13成功retry均为
  immutable历史；不追加、不覆盖、不重分类，成功retry不算R14 completion；
- R14 planner只改Stage、总Plan、A2 leaf、三个control surfaces并新建
  `evidence/plan-freeze-r14.md`；产品/test与matrix script保持entry bytes；
- Review14最终只写`reviews/14-p1-plan-review.md`，SHA-256
  `5bc0adf787dabd1451c53c7fc13df817325b323b030478443f62030bbf28e405`，
  verdict `CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`；
- 唯一P1-01是R14禁止LaunchServices却没有冻结non-LaunchServices
  source/build→bundle→signed executable provenance。R14因此从未打开任何
  test/build/matrix/source/preview、Review02/acceptance或A3，也未创建`r14-*`
  execution artifacts。

R14不扩大产品/test、schema/API/event/package、commit、push、merge、release、
normal-data、外部操作或真实用户权限。完整同义合同见Stage §28.1与A2 leaf
§1/§2.3/§10–§12。

### R15 Review14 P1-01 bundle-provenance closure

牧场主授权R15只关闭上述P1，不修改产品/test/App scripts：

- 当时的candidate gate统一为R15 freeze与职责隔离Review15；Review15只写
  `reviews/15-p1-plan-review.md`，零P0/P1也只允许请求后续新的用户授权turn；
- BEGIN在任何执行前消费一次授权，但只记录frozen inputs、no-process、recipe与
  planned fresh bundle/state roots；final executable identity延后到App build后的
  `POST_BUILD→PRE_SIGN→LAUNCH_READY`；
- leaf §11 inline冻结dev bundle assembly、Info.plist literal
  `5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58`、
  RanchArt 27-file manifest
  `4f73a80e821faa64d0a29d797cc12e20d5f88248bbb186e74972af49798ddbab`、
  unsigned copy/resource equality、single ad-hoc codesign与post-sign
  executable/UUID/CDHash/bundle manifest；
- fresh bundle不得读取、复用、删除或覆盖现存`.build/AgentLoop.app`；
  `scripts/run-app.sh`与`scripts/package-app.sh`保持immutable且禁止执行；
- bootstrap/cold start顺序复用同一LAUNCH_READY bundle，只以exact path/own PID
  direct exec；任一provenance/isolation/技术门失败永久拒绝且同boundary零修补/retry；
- matrix script只继承既有唯一Stage-hash临时delta，matrix后mandatory恢复entry
  value/hash，END必须证明产品/test/App scripts/final matrix script零drift；
- R15只写distinct `r15-*` evidence与`impl-report-r15.md`；Review02与acceptance
  继续保留R13 incident/mutation unknown，只能声明R15 boundary内zero
  normal-data access。

R15不扩大schema/API/event/package、commit/push/merge/release、normal-data、外部或
真实用户权限。完整同义合同见Stage §28.2与A2 leaf §1/§2.3/§10–§12。

### R16 R15 BEGIN false-negative closure and static attestation freeze

R15 freeze `evidence/plan-freeze-r15.md` SHA-256为
`e5ad3967f2e2b26a2bbf8b2ef7be405e8430cc30a82d51a7cb5f51926a99e3d7`。
Review15已写出
`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/15-p1-plan-review.md`，
SHA-256
`fbaa9612588c39cb5d99e95d9b68e00a234510e325abf5823c15f0b1eb8ecc05`，
verdict为`APPROVED — 0 P0 / 0 P1`。牧场主随后在新turn授权一次R15 clean
invocation；该boundary在任何test/build/matrix/source/bundle/preview前发生：

- `evidence/r15-clean-boundary.log`永久记录
  `REJECTED_CONTAMINATED`与`reason=hash_mismatch:review12c`，SHA-256
  `53eb91b840c5c8997fbc9da02d391f210f27b45d73b5e2431a6280a36110ab3b`；
- `evidence/r15-hash-manifest.log`同时记录Review12C expected与actual均为
  `db94c2cd473cd311c79aa61b8a32b634409b9485b5b5fcef775b71ecf1f2a109`，
  SHA-256
  `1589d8d29cf3f8ca9e558c4ac6d4008bdd591194c7e975ecf2fd045e6a935399`；
- 失败后只读诊断证明两operand长度均为64且逐字相等，独立probe也相等。由此只能
  关闭为**executor attestation false negative，而非仓库bytes drift**；原临时zsh
  helper为何错误分支仍未从现有证据复现，不得宣称已定位或修复；
- `impl-report-r15.md` SHA-256为
  `e6b0226b3440da997f7e08571d8e5e5229d66069ea5ad6485ee146c249dbe72e`；
  八个未运行gate日志均为0 bytes与empty-file SHA-256
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`，
  exact为`r15-targeted-tests.log`、`r15-verify.log`、`r15-build.log`、
  `r15-migration-matrix.log`、`evidence/r15-bundle-provenance.log`、
  `evidence/r15-source-gates.log`、`evidence/r15-preview-bootstrap.log`与
  `evidence/r15-preview-cold-start.log`；`evidence/r15-preview-smoke.png`保持
  不存在；
- R15 state root `/private/tmp/agentloop-r15-state.Zq6Jvm`与bundle parent
  `/private/tmp/agentloop-r15-bundle.2xROcy`在R16只读preflight仍存在且为空，
  planned App不存在、matching App process为0；R16不得清理、复用、补写或把这些
  failed-boundary对象改名为green evidence。

牧场主授权R16只修订本attestation执行器边界：

1. planner只同步六个canonical/control surfaces，新增reviewed
   `p1-a2-durable-rumination/evidence/r16-begin.sh`、静态
   `p1-a2-durable-rumination/evidence/r16-entry.sha256`与
   `p1-a2-durable-rumination/evidence/plan-freeze-r16.md`；产品/test/App/matrix
   scripts及全部R15 evidence逐字不变；
2. `r16-begin.sh`只以`/usr/bin/env -i`和`/bin/bash --noprofile --norc`进入固定
   clean environment，`set -euo pipefail`，不读取用户profile/function/alias；
   hash attestation只消费reviewed static manifest并调用
   `/usr/bin/shasum --strict -c`，不得动态生成expected map、复用R15 zsh helper或
   自写循环比较器吞掉/改判exit status；
3. 无环信任链固定为
   `immutable inputs + r16-begin.sh → r16-entry.sha256 → plan-freeze-r16.md →
   Review16 → 新用户授权`。Review16只写
   `reviews/16-p1-plan-review.md`；其零P0/P1结论本身不执行任何门。后续新用户
   授权必须按`freeze, Review16, driver, manifest`顺序逐字给出四个最终SHA-256；
4. static manifest全绿后，driver才可exclusive-create全新的`r16-*` execution
   artifacts与两个fresh roots并append BEGIN。BEGIN前或后任一失败均fail closed；
   BEGIN一旦写入即消费授权，同boundary不得修补、重写manifest、换root或retry；
5. R16 execution只写leaf §2.3冻结的`r16-targeted-tests.log`、
   `r16-verify.log`、`r16-build.log`、`r16-migration-matrix.log`、
   `impl-report-r16.md`、`evidence/r16-clean-boundary.log`、
   `evidence/r16-bundle-provenance.log`、`evidence/r16-source-gates.log`、
   `evidence/r16-hash-manifest.log`、`evidence/r16-preview-bootstrap.log`、
   `evidence/r16-preview-cold-start.log`与`evidence/r16-preview-smoke.png`。
   R15路径、roots与缺失截图不是R16输出；
6. planning、freeze与Review16期间matrix script保持SHA-256
   `75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c`，
   line 115保持predecessor
   `a8ca6e7a56a32e945bae185724a51d4e0015d61676bf02d9637fedc2c27d9b6f`。
   只有Review16批准、四hash新授权、static attestation与BEGIN全绿后，matrix前才可
   临时机械替换唯一Stage hash为R16 freeze值；无论matrix成败都先恢复entry
   value/hash，失败则停止，R16 END再以static manifest证明final delta=0；
7. Review16达到`APPROVED — 0 P0 / 0 P1`前，继续禁止test、build、matrix、source
   gate、bundle/sign、preview、产品/test/App script实施、Review02/acceptance、
   A3、commit、push、merge、release、normal-data、外部与真实用户操作。

R16不改变R15已经冻结的source→build→fresh bundle→single ad-hoc sign→same-bundle
direct-exec provenance，也不扩大schema/API/event/package或产品权限；它只把
BEGIN输入证明替换为reviewed Bash driver与静态manifest，并保留全部负证据。该段
现在只保存R16 freeze时的historical plan合同；真实结果是Review16批准且四hash授权
后，external anchors与110/110 manifest全绿，但driver在pre-BEGIN
`pgrep rc=1`被全局`ERR` trap抢占。唯一消费文件未创建，授权未消费，全部R16
runtime paths/roots不存在，任何后续门均未运行。

### R17 Bash ERR-trap/status-capture bounded closure

本节是immutable R17 historical plan，不再具有开门权。R17 freeze
`bdbbbd025bbe7cf57032ae2276a6a559043f60e47cebad1ceac43f992e644e1f`、Review17
`c6838d3c5a9fcfef80dc9db4abf560af712e3175372a163edccb72197daf3dbe`、driver
`cf1baab60b3e799b1780b20d1dfc7887bdd2c7e85e241fdb8abcd4ad8c04321f`、probe
`5ee154b56d10322fd70ad34698a7f0fd81122862d25b9bbb05b1db18bee67199`与manifest
`7d10c5c6747cdf0e557befc76a62ea101f2fc4168a49d8076bedd3331d8cbd17`
均冻结。Review17 verdict为`CHANGES REQUIRED — 0 P0 / 1 P1`，R17 caller/BEGIN及
全部执行门未运行，全部runtime paths/roots不存在。以下future-tense条目只保存R17
当时合同；R20历史见下方R20节，唯一current gate见下方R21节。

牧场主当时授权R17只关闭上述同一Bash根因：

1. then-current六面统一为
   `R15 BEGIN REJECTED_CONTAMINATED；R16 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED；R17 Status-Capture Candidate Frozen；Review17 Pending；A2 Clean Re-verification Frozen`；
2. R16 freeze、Review16、driver、manifest及其12个runtime paths/两类fresh roots
   absence全部immutable；不得修改、补写、重跑或改写为BEGIN/
   `REJECTED_CONTAMINATED`；
3. planner只同步六个canonical/control surfaces并新增
   `evidence/r17-begin.sh`、`evidence/r17-bash32-probes.sh`、
   `evidence/r17-entry.sha256`与`evidence/plan-freeze-r17.md`；产品/test/App/
   matrix scripts零delta；
4. reviewed driver一次修订13个status-capture blocks：pre/post anchors、
   pre/post manifest、`pgrep`、empty-directory find、R15/fresh-root realpath及
   RanchArt file-find/transform/diff/nonregular-find/count。simple command只用
   conditional capture；pipeline在then/else第一条立即复制`PIPESTATUS`；command
   substitution在subshell内`trap - ERR`后由外层conditional捕获。禁止
   `set +e` bare capture、`|| true`、silent fallback、status inversion或specific
   reason generic化；
5. `r17-bash32-probes.sh`只可在planning/Review阶段以clean macOS Bash 3.2运行，
   必须覆盖`pgrep=1`、`diff=1`、indeterminate `rc=2`、pipeline component
   nonzero及command-substitution nonzero，且不得调用driver或产品执行门；
6. static R17 manifest固定115项：继承R16 110项coverage并增加R17 driver/probe、
   immutable `r16-entry.sha256`、R16 freeze与Review16。它不包含自身、R17
   freeze、Review17或runtime R17 artifacts；
7. 无环链为
   `immutable predecessors + final six surfaces + r17-begin.sh +
   r17-bash32-probes.sh → r17-entry.sha256 → plan-freeze-r17.md → Review17 →
   later four-hash user authorization`；
8. Review17唯一写`reviews/17-p1-plan-review.md`。它达到零P0/P1也不执行；
   后续新用户turn仍须按`freeze, Review17, driver, manifest`顺序逐字提供四个
   final SHA-256；
9. R17 driver pre-BEGIN除既有anchors/manifest/branch/HEAD/process/R15保全门外，
   还必须证明12个R16 runtime paths与两类R16 fresh-root glob仍不存在。只有排他
   创建`evidence/r17-clean-boundary.log`并写`authorization_consumed=true`才消费
   授权，之后才可创建fresh `r17-*` artifacts与两个`agentloop-r17-*` roots；
10. Review17与后续四hash授权前，继续禁止caller/BEGIN、test、build、matrix、
    source、bundle/sign、preview、产品/test/App-script修改、Review02/acceptance、
    A3、commit、push、merge、release、normal-data、外部与真实用户操作。

R17 BEGIN若获后续授权并成功，只机械继承Stage §28.2.2–§28.2.4、§28.4.4与A2 leaf
§10–§12的四阶段provenance、matrix restoration、same-bundle direct exec、
isolation、fail-once、Review02和scoped acceptance合同。acceptance必须披露R13
incident/mutation unknown/Review01、R15 rejected BEGIN与R16 pre-BEGIN
authorization-unconsumed/zero-write false positive，只能声明R17 boundary内zero
normal-data access。

### R18/R18-A RanchArt preflight and R15 tombstone bounded closure

本节保存已被Review18拒绝且从未执行的R18/R18-A candidate。牧场主先授权R18关闭Review17 P1-01；随后又明确授权R18-A按Stage §28.5与A2
`blocked.md` §24关闭pre-freeze发现的R15 volatile-root current-state drift。该delta
不修改产品/test/App/matrix scripts，不改schema/API/event/package，也不重开R17执行：

1. current六面统一为
   `R15 BEGIN REJECTED_CONTAMINATED；R16 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED；R17 PLAN CHANGES REQUIRED — NOT EXECUTED；R18-A Tombstone Candidate Frozen；Review18 Pending；A2 Clean Re-verification Frozen`；
2. R15全部rejected evidence、R16 approved-plan/pre-BEGIN未消费零写入历史及R17
   driver/probe/manifest/freeze/Review17/not-executed absence全部immutable；Review17
   `CHANGES REQUIRED — 0 P0 / 1 P1`不再有开门权。R15 durable evidence只证明
   containment时两个roots为canonical empty；2026-08-02 current复核已证明两个exact
   paths为`ABSENT`、消失原因`UNKNOWN`，不得声称连续保全；
3. planner只同步六个canonical/control surfaces并新增`evidence/r18-begin.sh`、
   `evidence/r18-entry.sha256`与`evidence/plan-freeze-r18.md`；复用且不得修改
   `evidence/r17-bash32-probes.sh`，不新增第二probe/verifier；
4. `r18-begin.sh`只有一个phase-aware RanchArt verifier。它以同一expected 27-path
   set和同一Bash 3.2-safe实现，每次重新读取source tree，证明exact regular set、
   exact count与zero symlink/nonregular。所有其他pre-BEGIN门通过后，
   `phase=pre_consumption`调用是授权消费前最后一个fallible precondition，禁止
   temp/artifact/root/log写入；失败保持`authorization_consumed=false`。成功后下一
   filesystem mutation才是exclusive-create boundary并写
   `authorization_consumed=true`；创建其他runtime artifacts/roots前立即以
   `phase=post_activation`重新读取同一verifier并写结构证据，禁止复用缓存结果。
   verifier只检查path/node/count；随后独立重跑post-activation 119-entry strict
   manifest逐文件复核包括27个RanchArt files在内的bytes。冻结的RanchArt manifest
   SHA只记录expected identity，不是verifier生成的derived proof；
5. 两个exact R15 paths是absorbing `ABSENT` tombstones，禁止重建、删除、清理或
   复用。pre-BEGIN必须以成功的exact `/private/tmp` parent enumeration证明两个
   basenames都不存在，并以final `-e || -L`重检收窄重现窗口；parent异常、probe
   nonzero或任何directory/file/symlink/dangling symlink/special node重现都fail
   closed，不能把probe failure当作absent。boundary evidence只记录
   `r15_state_root_pre_begin_observed_state=ABSENT`、
   `r15_bundle_parent_pre_begin_observed_state=ABSENT`、
   `r15_state_root_current_absent=true`、`r15_bundle_parent_current_absent=true`、
   `r15_absence_proof_identity=private_tmp_parent_enumeration_exact_basename_v1`与
   `disappearance_cause=UNKNOWN`；
6. R18-A只把inherited preserved-root `realpath` command-substitution C一对一替换为
   上述联合parent-enumeration C；其他12个inherited blocks不变，计数仍为
   `2P / 4S / 7C = 13`。另计既有root-glob absence C后driver总数仍为
   `2P / 4S / 8C = 14`；immutable probe继续复用且不新增probe；
7. 双读不声称filesystem transaction、atomic snapshot或目录锁。preflight关闭
   “已有extra/nonregular节点仍先消费授权”的P1；post-read检测观测间可见变化并在
   failure时永久拒绝该boundary。两次读取间改变后恢复或第二次读取后改变不由本门
   单独保证，后者仍须由source/resource/build/bundle/END manifests fail closed；
8. static `r18-entry.sha256`固定119项：以final hashes继承R17的115-path coverage，
   仅增加R18 driver、immutable `r17-entry.sha256`、R17 freeze与Review17。immutable
   probe已在115项内。manifest不得包含自身、R18 freeze、Review18或runtime R18
   artifacts；
9. 无环链为
   `immutable predecessors + final six surfaces + immutable probe + reviewed r18-begin.sh + r17-entry.sha256 + R17 freeze + Review17 → r18-entry.sha256 → plan-freeze-r18.md → Review18 → later four-hash user authorization`；
10. Review18唯一写`reviews/18-p1-plan-review.md`，核对119/119、single verifier、
   pre-consumption zero-write最后顺序、post-activation同源重读/结构证据、独立
   119-entry bytes复核、证据分层、明确TOCTOU边界、R17 P1-01关闭、fresh names、
   R15 historical-empty/current-ABSENT分层、absorbing tombstone、联合parent
   enumeration、inherited 13/driver-total 14计数、历史保全与零产品/test/App-script
   drift。它
   达到零P0/P1也不执行；后续新用户turn必须按
   `freeze, Review18, driver, manifest`顺序逐字提供四个final SHA-256；
11. R18使用12个fresh paths：`r18-targeted-tests.log`、`r18-verify.log`、
   `r18-build.log`、`r18-migration-matrix.log`、`impl-report-r18.md`、
   `evidence/r18-clean-boundary.log`、`evidence/r18-bundle-provenance.log`、
   `evidence/r18-source-gates.log`、`evidence/r18-hash-manifest.log`、
   `evidence/r18-preview-bootstrap.log`、`evidence/r18-preview-cold-start.log`与
   `evidence/r18-preview-smoke.png`，以及fresh
   `/private/tmp/agentloop-r18-state.*`、`/private/tmp/agentloop-r18-bundle.*`；
   pre-BEGIN必须证明它们及全部R17/R16 paths/root globs不存在，并证明R15 roots
   exact identities继续`ABSENT`、planned App/screenshot absent；
12. Review18与后续四hash授权前，继续禁止caller/BEGIN、test、build、matrix、
    source、bundle/sign、preview、产品/test/App-script修改、Review02/acceptance、
    A3、commit、push、merge、release、normal-data、外部与真实用户操作。

R18获后续四hash授权并BEGIN成功后，只机械继承Stage §28.2.2–§28.2.4、§28.5.4与
A2 leaf §10–§12的四阶段provenance、matrix restoration、same-bundle direct exec、
isolation、fail-once、Review02和scoped acceptance合同。acceptance必须披露R13
incident/mutation unknown/Review01、R15 rejected BEGIN、R16 pre-BEGIN
authorization-unconsumed/zero-write false positive及R17 rejected plan/not-executed，
只能声明R18 boundary内zero normal-data access，且不得虚构atomic filesystem lock。

### R19 lossless pathname transport bounded closure

以下是R19 freeze时的historical plan；实际执行结果及current R20 gate见本节末。

职责隔离Review18 SHA-256
`e0ee95f3703d73810d756410373c1da65fb1e08b08f6d7f74555e8095a12608b`以
`CHANGES REQUIRED — 0 P0 / 1 P1`拒绝R18/R18-A。唯一P1-01是RanchArt actual
pathname经newline text、command substitution与line-oriented transform/diff/count后
不再是单射：含LF的一个regular basename可伪装成两个expected lines，使stable
contamination先消费授权。R18 driver/BEGIN及所有execution gates从未运行；R18
runtime paths/roots保持absent。其freeze/Review/driver/manifest hashes依次为
`62bbf93031371659e7ad2d4c60aac002eb13ed0915854f741e40251c9c2c1e76`、
`e0ee95f3703d73810d756410373c1da65fb1e08b08f6d7f74555e8095a12608b`、
`911bbbc70556e41122cfdcc90048e504eee3480246b338131153856d524d7af9`、
`71e512a25e6e9bc0d024a53ad2502b55a378a82b39044a341930e1df440cfc2a`，
只作immutable失败审计链。

牧场主已在新的明确用户turn授权R19只关闭同一根因。执行计划为：

1. 六面current status逐字同步为
   `R15 BEGIN REJECTED_CONTAMINATED；R16 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED；R17 PLAN CHANGES REQUIRED — NOT EXECUTED；R18/R18-A PLAN CHANGES REQUIRED — NOT EXECUTED；R19 Pathname-Exact Candidate Frozen；Review19 Pending；A2 Clean Re-verification Frozen`；
2. planner写集仅为六面与fresh `r19-begin.sh`、`r19-entry.sha256`、
   `plan-freeze-r19.md`；隔离reviewer唯一写`reviews/19-p1-plan-review.md`。R18完整
   chain、R17 probe、产品/test/App/matrix与R15–R17历史全部immutable；
3. `r19-begin.sh`只有一个phase-aware verifier与一个runtime检查为27项且unique的
   ASCII expected array；pre/post都以单一
   `find -P ... -print0 | inline Bash 3.2 read -r -d '' validator`重新读取filesystem，
   NUL stream不得进入`$()`、line split、sort/diff/wc或raw log；
4. validator完整drain stream并检测partial final record；在`LC_ALL=C`、关闭
   `nocasematch`后比较enumeration返回的actual basename bytes，使用27-slot seen map
   与饱和count，且每个actual node必须`-f && ! -L`。all-node universe包括dotfiles、
   symlink/dangling、directory与special nodes；任何missing/extra/case/LF/CR/Unicode/
   nonregular均fail closed，失败不得raw serialize pathname；
5. producer与validator只形成一个P capture，then/else首命令复制两个
   `PIPESTATUS`。旧RanchArt `1S + 4C`五block整体移除，current core inventory为
   `3P / 3S / 3C = 9`，加R16–R19 root-glob C后driver total为
   `3P / 3S / 4C = 10`。immutable R17 probe保持原bytes；只允许零文件写入的
   in-memory/stdin Bash 3.2 NUL micro-probe，不新增probe artifact；
6. 只有完整exact/type/count proof与两个pipeline status均0后，parent才按已证明安全的
   expected ASCII固定顺序写transport id、exact-set block、regular=27、nonregular=0、
   symlink=0；pre sink仅`/dev/stderr`，post sink为fresh hash log；
7. pre verifier仍是boundary exclusive-create前最后一个fallible precondition，之后
   下一mutation才消费授权；post verifier是fresh hash log后的立即重读，随后才独立
   strict-check 123-entry content manifest。pre失败零写入/未消费，post失败永久
   `REJECTED_CONTAMINATED`；不声称atomic FS lock，也不扩大hardlink/inode合同；
8. `r19-entry.sha256`精确为R18 119 paths加R19 driver、immutable R18 manifest、R18
   freeze与Review18，共123项。六面更新后旧R18 manifest必须恰好six mismatch、其余
   113 unchanged；R19 manifest必须123/123，排除自身/R19 freeze/Review19/runtime；
9. 无环链为
   `immutable predecessors + final six surfaces + R17 probe/R18 chain + r19-begin → r19-entry → plan-freeze-r19.md → Review19 → later four-hash user authorization`；
10. R19使用fresh 12个`r19-*`/report paths与两个`agentloop-r19-*` roots；pre-BEGIN
    必须证明它们及全部R16/R17/R18 runtime/root globs absent，并保持R15两个exact
    `ABSENT` absorbing tombstones；
11. Review19重新核对123/123、only-six/113 preservation、NUL lossless semantics、
    full drain/partial handling、actual byte spelling、safe evidence、9/10 capture、
    pre/post顺序、tombstone/absence、无环链、零产品/test/App-script delta与owner
    separation；达到`APPROVED — 0 P0 / 0 P1`也不执行；
12. 只有后续新的用户turn按`freeze, Review19, driver, manifest`顺序逐字提供四个final
    SHA-256并明确授权，才可打开一次clean external caller。此前继续禁止caller/
    BEGIN、test、build、matrix、source、bundle/sign、preview、产品/test/App-script
    修改、Review02/acceptance、A3、commit/push/merge/release、normal-data、外部和
    真实用户操作。

R19若在后续四-hash授权下BEGIN成功，只机械继承Stage §28.2.2–§28.2.4、§28.6.4与
A2 leaf §10–§12的四阶段provenance、matrix restoration、same-bundle direct exec、
isolation、fail-once、Review02与scoped acceptance合同；acceptance只能声明R19
boundary内zero normal-data access，并必须披露R13、R15、R16、R17与R18全部历史。

R19后来获Review19 `APPROVED — 0 P0 / 0 P1`及后续四hash授权，成功BEGIN并通过
41/41 targeted；但唯一一次未过滤权威full suite为651/652，
`slowActiveStreamDoesNotIdleTimeout`以`idle script exhausted`失败。R19永久
`REJECTED_CONTAMINATED`，11个实际artifacts、缺失screenshot、两个exact empty roots、
zero product/test drift与全部未运行后续门均immutable。

### R20 historical deterministic-time bounded closure

本节保存R20当时的planning合同；R20现已按下述计划执行并在release Core build永久
rejected，不再具有current开门权。唯一current合同为Stage §28.8、本Plan下方R21节与
A2 leaf。R20当时执行计划是：

1. 六面current status统一为
   `R15 BEGIN REJECTED_CONTAMINATED；R16 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED；R17 PLAN CHANGES REQUIRED — NOT EXECUTED；R18/R18-A PLAN CHANGES REQUIRED — NOT EXECUTED；R19 BEGIN REJECTED_CONTAMINATED — AUTHORITATIVE FULL TEST 651/652；R20 Deterministic-Time Candidate Frozen；Review20 Pending；A2 Clean Re-verification Frozen`；
2. planning写集只含六面、fresh `r20-begin.sh`、`r20-entry.sha256`与
   `plan-freeze-r20.md`；职责隔离reviewer唯一写`reviews/20-p1-plan-review.md`；
3. future implementation只允许`AgentLoop.swift`与`AgentLoopTests.swift`。前者用private
   factory与单一`IdleWatchdog<C: Clock>`保持public init逐字不变、production默认
   `ContinuousClock`；仅`#if DEBUG` package generic init以exact external label
   `idleClockForTesting`注入test Clock。后者用NSLock+checked continuation的
   `ManualAgentLoopClock`，锁外resume、advance/cancel exactly once；release
   `AgentLoop.swift.o` demangled token count=0、debug count>0；
4. 五个exact deterministic names及语义见Stage §28.7.3。controlled provider零
   `Task.sleep`，event ack发生在真实`beat`后再advance，以barrier避开deadline race；
5. 禁止放大timeout/间隔余量、`.serialized`、skip/filter、改变RunTests并发、失败重跑、
   复制scripted step、吞错、fake watchdog、public/release testing API或旧green替代；
6. 140-entry manifest精确继承R19 123 paths并增加R20 driver、R19 manifest/freeze/
   Review19、11个R19 runtime/failure artifacts与两个source baselines。六面更新后旧R19
   manifest为117/123 unchanged+six mismatch；R20 implementation前140/140，之后必须
   exact 138 unchanged+two authorized mismatches；第三个mismatch即失败；
7. R20使用fresh 12个`r20-*`/report paths与两个`agentloop-r20-*` roots。R19 11个
   artifacts、缺失screenshot与两个exact empty roots只读保留，不得清理/复用；
8. Review20批准且牧场主后续按`freeze, Review20, driver, manifest`给出四hash前，
   禁止caller/BEGIN、两个source/test修改及全部执行门；Review20本身不执行；
9. 获执行授权后，只运行一次未过滤`swift run RunTests`写`r20-verify.log`；失败永久
   stop且不得重跑。full全绿后从同一log机械审计原41+新增5各exact一次并写
   `r20-targeted-tests.log`，不执行第二次test/filter。随后才运行build/release/matrix/
   source/provenance/preview/END；
10. 全部门与R20 END完成后才打开Review02；其零P0/P1后才打开independent acceptance，
    acceptance必须披露R19 651/652 rejection且只声明R20 boundary内zero normal access。

### R21 release-configuration bounded closure

R20实际结果及R21 plan source of truth见Stage §28.8、A2 leaf §1/§2.3/§2.7/§10–§12与
`blocked.md` §29。R21不新增产品决定，只关闭SwiftPM automatic-product fallback与
DEBUG caller/callee configuration mismatch这一同一根因。执行计划为：

1. 六面current status统一为
   `R15 BEGIN REJECTED_CONTAMINATED；R16 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED；R17 PLAN CHANGES REQUIRED — NOT EXECUTED；R18/R18-A PLAN CHANGES REQUIRED — NOT EXECUTED；R19 BEGIN REJECTED_CONTAMINATED — AUTHORITATIVE FULL TEST 651/652；R20 BEGIN REJECTED_CONTAMINATED — RELEASE CORE BUILD FAILURE AFTER AUTHORITATIVE FULL 652/652；R21 Release-Configuration Candidate Frozen；Review21 Pending；A2 Clean Re-verification Frozen`；
2. R20四hash
   `0b698b59f214f23c26db88fd53763c4a600becaf898a716344f9d666ac2e8e07`、
   `e70ea918e00c334a452f87e4fa8f44d5bfc754b042872a9f0a0ec13015e7c68e`、
   `840edee2dad7710f17e1b9bb8dcaa1484224ba0784b636f472bc2934f7e7eaeb`、
   `2f8a6f4f786a2b5f432b2dbf7dcdc7208788d0b9ef5b9cdaa9de422bfaf88e81`
   与invocation `r20-98452cde-0ff4-4b66-b3f6-8085eb045a6f`全部immutable。R20唯一full
   652/652、同log 46/46、debug App build、LAUNCH_READY是真实partial evidence；release
   Core failure boundary固定为phase=`release_core_build`、
   reason=`release_AgentLoopCore_build_failed_rc_1`、exit=1、retry=false；
3. R20 final Core/TestSuite hashes分别为
   `c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`与
   `66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26`。
   11个runtime artifacts、absent screenshot、real empty state root
   `/private/tmp/agentloop-r20-state.3QwlQa`、含exact signed `AgentLoop.app`的bundle
   parent `/private/tmp/agentloop-r20-bundle.30V5RH`及其executable/plist/bundle hashes
   全部保留，不得写入、删除、清理、启动、重签或复用；
4. planning写集只含六面、fresh `r21-begin.sh`、155-entry `r21-entry.sha256`与
   `plan-freeze-r21.md`；职责隔离reviewer唯一写`reviews/21-p1-plan-review.md`；
5. future implementation必须保持`AgentLoop.swift` R20 final bytes；唯一source delta是
   `AgentLoopTests.swift`原地新增三对direct matching `#if DEBUG/#endif`：helpers block
   `ManualAgentLoopClock`至`OneShotGate`、只含`startControlledLoop`的function block、
   以及`turnTimeoutRetriesOnceThenBlocks`至`turnCompletesUnderTimeout`的五test block。
   不移动/重排/修改既有逻辑或其他bytes，不加else/elseif/nesting/第四对guard；删除且
   只删除六directive lines必须恢复R20 final TestSuite hash；
6. 禁止Package.swift、产品逻辑、public/package API、target/dependency/package edge、
   schema/migration、其他产品/test/App/RunTests/matrix-script修改。source parser必须证明
   Core既有DEBUG guard不变、TestSuite恰三对direct regions及11 tokens全部guarded；
7. release顺序精确为
   `swift build -c release --target AgentLoopCore`后
   `swift build -c release --target AgentLoopTestSuite`。用canonical
   `--show-bin-path`精确构造release/debug Core/Test四个objects；禁止find/glob/fallback/
   固定共享tmp。Core `idleClockForTesting` release=0/debug>0，TestSuite 11 tokens逐项
   release=0/debug>0；nm/demangle非零或空输出、path/type/layout异常都fail closed，且
   release Core object hash在第二条target build前后不变；
8. R21 manifest完整继承R20 140 paths并增加R21 driver、R20 manifest/freeze/Review20与
   11 runtime artifacts，共155项。六面同步后旧R20 manifest必须132 unchanged+8
   mismatch；R21实施前155/155，实施后154 unchanged+`AgentLoopTests.swift`唯一mismatch，
   Core继续匹配entry；
9. R21使用fresh 12个`r21-*`/report paths与两个`agentloop-r21-*` roots。reviewed
   BEGIN-only driver在消费前后保全R19/R20 evidence与R20 signed App；后者以all-node NUL
   pipeline精确锁36 nodes（6 directories + 30 regular files）、逐文件hash并从固定safe
   literals复算signed manifest，禁止`-type`过滤与actual pathname文本序列化，失败只写
   四段safe numeric statuses。capture inventory按ERR-trap-facing outer unique parent
   blocks计数，inline validator子状态不重复计数：core `8P/4S/8C=20`、driver-total
   `8P/4S/9C=21`；
10. Review21达到`APPROVED — 0 P0 / 0 P1`本身不执行。只有后续新的用户turn按
    `freeze, Review21, driver, manifest`顺序给出四个final hashes并授权，才可运行一次
    caller/BEGIN、实施one-file guards、唯一unfiltered full RunTests、同log 46/46，然后
    严格按debug App build → fresh bundle assembly/sign及LAUNCH_READY → pre-release
    guard-shape/strip source sub-gate → target-exact releases → 四object gates → matrix →
    remaining source/privacy/final-hash gates → same-bundle preview → END执行。任一失败永久
    stop且不得retry；Review02/acceptance必须披露R20 failure并只声明R21 boundary内zero
    normal access。

Review21与后续四hash授权前继续禁止caller/BEGIN、test/build/matrix/source/bundle/sign/
preview、test guard实施及其他产品/test/App-script修改，也禁止Review02/acceptance、A3、
commit、push、merge、release、normal-data、外部与真实用户操作。

### R22 volatile-containment and automatic-attestation closure

Stage §28.9、A2 leaf §13与`blocked.md` §30构成R22唯一current执行合同；上方R21合同只作
immutable predecessor。R21四锚依次为freeze
`82ec117359bb0172867ed476c0da4a8d7d0fc60c5bd24f25c0f42e360f7996a4`、Review21
`13f75ac2979a25c8cf643e83f264663087c6bc18836696c518b247d7f6d3176b`、driver
`c56db7b465ae3d54923d958892e07e5575d4cf67b8b4946c7d6793e4f1bfb835`、manifest
`d5567a05e61e61a94b732814e24a89ecdb8e2a988d970dac33939f31798a9d86`。R21 caller四锚与
155/155通过后，driver在`pre_begin_r19_containment`以70停止；boundary未写、authority
未消费、12 runtime paths与fresh roots均ABSENT，Core/TestSuite保持R20 final bytes。

R22只修该volatile-root状态漂移：R19两个exact roots与R20 state root按
`HISTORICAL_CANONICAL_EMPTY → ABSENT_TOMBSTONE`冻结，ABSENT absorbing；R20 bundle只允
`VERIFIED_RETAINED → VERIFIED_RETAINED|ABSENT_TOMBSTONE`或
`ABSENT_TOMBSTONE → ABSENT_TOMBSTONE`。每次分类都必须在`-e || -L`bookends间完整NUL-safe
枚举`/private/tmp` top-level；retained分支继续逐项验证exact child、36-node set/file hashes、
aggregate与strict codesign，验证失败不得伪装成disappearance；alternate/reappeared root
一律失败。R20第一次完整分类另存immutable first-observed state；重复pre与多次post逐次
使用同一单向表，同一次hash/codesign/late-bookend内不得把retained消失当成合法transition。

牧场主standing Goal允许Review22通过后agent自动继续，不再要求用户逐轮回传hash。职责隔离
reviewer唯一写Review22，并同时给出唯一exact human verdict行
`Verdict: APPROVED — 0 P0 / 0 P1`、零个其他`Verdict:`行与唯一12-line machine block：authority mode、standing Goal已验证、
reviewer independence已attest、write scope仅Review22、无需用户hash echo、machine verdict、
freeze/driver/manifest三hash、固定branch/HEAD及`manifest_count=159`。automatic caller先
确认没有更新用户turn撤销authority，再机械计算Review22 SHA；driver只接收该一个SHA并独立
重读Review22。该机制只证明local filesystem consistency，不是human anti-rewrite或外部签名。

R22 manifest为`159 = R21完整155 + r22-begin.sh + R21 manifest/freeze/Review21`，排除
自身、R22 freeze/Review22与runtime。旧R21 manifest必须精确149 unchanged + six-surface
mismatches；R22 implementation前159/159，之后158 unchanged + `AgentLoopTests.swift`唯一
authorized mismatch，Core仍匹配R20 final。R22使用全新12个`r22-*`/report paths与两个
`agentloop-r22-*` roots，并在消费前后重证R21零写入及全部historical containment。boundary
只能由本进程exclusive-create成功后消费；EEXIST零append，partial initialization永久拒绝；
消费后第一批只读动作立即重证R21/R19/R20 lifecycle。

future产品delta、一次unfiltered full RunTests、同log 46/46、debug bundle、target-exact
release、四object symbol、matrix/source/privacy、same-bundle preview、END顺序与§28.8相同。
Review22之前禁止caller/BEGIN、任何test/build/matrix/source/bundle/sign/preview与产品/test/
App-script修改；Review22通过后automatic caller无需新的用户hash turn，但任何failure仍永久
拒绝且不得retry。Review02只在R22 END后由新的职责隔离reviewer写；acceptance必须披露R19/
R20 root lifecycle、R20 bundle最终状态和R21 pre-BEGIN零写入/未消费。

### R23 erosion-snapshot and automatic-attestation closure

Stage §28.10、A2 leaf §14与`blocked.md` §31构成R23唯一current execution contract。
Review22 SHA
`bf007443ac2b1932fbde93cf908a99b50cb4878de3e485118092bb24552050b5`
的唯一verdict为`CHANGES REQUIRED — 0 P0 / 1 P1`：R20 bundle parent/App仍存在，但App
只剩六个historical directories、零files，故R22 retained/absent二态无法进入BEGIN。
R22没有approval machine block、caller、BEGIN、runtime write、fresh root、test或source
delta；R22六面/driver/manifest/freeze与Review22全部immutable。

R23只修该同一planner根因，不重建、不清理、不删除或修改R20 root。固定38-bit universe为
bundle parent、App与R20既有36-node顺序；Review22的8/38 snapshot逐字冻结为
`11101011100000000000000000000000000010`。首次完整capture A前必须验证该baseline到A只含
`1→0`，所以Review22已观察为0的30 files及其他missing nodes不得重现；之后所有
`LATEST→A→B`同样只允许erosion。允许shape仅为全absent、parent-only，或parent+App加
baseline node bits的任意子集。remaining dirs/files必须保持exact type/hash；extra、
alternate、symlink、special、wrong type/hash及indeterminate observation全部fail closed。

每次observation使用两个完整capture。单capture依次full-NUL-drain `/private/tmp`、
exact parent child与App subtree；App validator在同一次drain内直接产出36-bit mask与三项
counts，随后重验parent/App presence、type、canonical realpath与child shape。验证失败不得
被编码为missing。CAPTURE/counts只是诊断working registers，A/B capture会在比较前
reset/mutate，失败时可保留incomplete/A/B staging；它们不是accepted lifecycle state。
pair只在`BASELINE/LATEST→A`与`A→B`全部通过后提交FIRST/LATEST及accepted mode-B；FIRST
固定为首个A，LATEST固定为B，并在同一defer-only段把诊断CAPTURE/counts最终normalize为B。
capture/comparison失败时只保证pair开始前的FIRST/LATEST与accepted mode-B不变，诊断
CAPTURE/counts必须诚实反映失败点staging。该assignment段完成后立即恢复fail handlers并按
任一deferred signal拒绝。partial状态永远只引用historical signed hashes；只有
all-one完整set、aggregate与strict codesign同时通过才可声称current signed App，而该分支
受current baseline约束不可达。

R23不提供filesystem transaction、filesystem lock或atomic snapshot，也不证明
inode/hardlink、xattr或resource fork不变，不能消除TOCTOU；完全发生并消失在两个capture
可见窗口之外的短暂节点可能不被观察到。本文的“原子”只指所有比较通过后，当前进程一次性
提交FIRST/LATEST变量。若未来要求原子文件系统保证，必须另开stage并重新Review。

R23 static manifest为
`163 = R22完整159 + r23-begin.sh + R22 manifest + R22 freeze + Review22`，排除自身、
R23 freeze/Review23/runtime/temp roots。planner六面改动后旧R22 manifest应为153+六个
surface mismatches；R23实施前163/163，TestSuite guard edit后162+Test唯一mismatch。
R22 12 paths与root globs必须在pre、final-pre、immediate-post与post-root持续ABSENT；R23
只用fresh 12 paths与`agentloop-r23-*` roots。driver unique outer capture inventory冻结为
`8P / 4S / 13C = 25`，inline validator不重复计数。

Review23由未写R23 planner artifacts的职责隔离reviewer唯一写，只允许一个exact human
approval verdict与唯一12-line machine block；authority mode为
`standing_goal_automatic_after_review23`，manifest count为163。Review23零P0/P1且无更新
用户turn撤销Goal后，automatic caller只传机械计算的Review23 SHA，不要求新hash echo。
boundary只在exclusive-create成功后消费authority，名为
`R23_EROSION_SNAPSHOT_AND_RELEASE_CONFIGURATION_REPAIR`；消费后的fail path永久记录
baseline/FIRST/LATEST/current capture。

产品delta及顺序零变化：TestSuite只加三对/六行matching direct DEBUG directives，Core与
其他产品/test/App-script bytes不变；随后一次unfiltered full RunTests → same-log 46/46 →
debug App/fresh bundle/sign/LAUNCH_READY → guard-shape/strip → target-exact Core/TestSuite
release → four exact objects → matrix/restoration → remaining source/privacy/hash →
same-bundle preview → END。任一failure永久reject，不重试、不换root/object、不补丁。
Review23前上述全部执行、Review02/acceptance与A3关闭；commit/push/merge/release、
normal-data、R20 mutation、外部与真实用户操作继续未授权。

### R24 in-driver Bash full-test status-capture closure

Stage §28.11、A2 leaf §15与`blocked.md` §32构成R24唯一current execution contract。
R23已按approved freeze完成BEGIN与六行DEBUG guard delta；唯一full-test log终端为652/652，
但zsh wrapper读取未定义的Bash-only `PIPESTATUS`，Swift/tee rc均未捕获，故R23永久
`REJECTED_CONTAMINATED`，十个logs、final report、两个empty roots与缺失screenshot immutable，
后续门全部未运行。R24不得修改或补齐R23 evidence，也不再修改任何source；Core/Test final
分别固定为`c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`与
`37fad0b3b123d248f6a52128f5f5d60559587cb8d291b6a6a6da1d615ad87967`。

R24 driver在同一reviewed Bash 3.2 process中完成BEGIN后唯一运行unfiltered
`swift run RunTests | tee`。then/else第一条均复制exact two-element `PIPESTATUS`，两个rc从
`UNKNOWN`到numeric后最后commit captured flag，只有0/0与唯一652/652 summary开放handoff；
verify log必须fresh zero-byte regular non-symlink并在handoff冻结SHA/bytes。caller使用
`env -i`、绝对system Bash、固定locale/tmp/path/Git环境，明确unset BASH_ENV/ENV/CDPATH；
driver验证canonical self identity、Bash 3.2、exact cwd和全部anchors，外层shell不得读取
`PIPESTATUS`。后续每个Bash-only capture同样必须在显式clean Bash block内完成。

R24 manifest为`178 = complete R23 163 + R24 driver + R23 manifest/freeze/Review23 + R23
10 runtime logs + impl-report-r23.md`，排除自身、R24 freeze/Review/runtime/temp。source delta=0
只指产品/test/App与永久script bytes；entry、每个mutation前、matrix恢复后与END为178/178。
既有matrix窗口只允许matrix script line115 Stage hash单值临时delta，精确177+script唯一mismatch；
所有退出路径mandatory恢复，失败只能恢复并永久reject。旧R23 manifest只允许156+七mismatch。

R23两个fresh empty roots由fixed two-bit baseline `11`进入双complete A/B、只1→0 lifecycle；
present必须exact real non-symlink canonical empty且alternate identities失败，absent absorbing。
UNCHANGED写`NOT_OBSERVED`，erosion原因只能写`UNKNOWN`。R20 38-bit合同、R19 tombstone与
R16–R18/R21/R22 zero-write继续继承；pre/final-pre、immediate-post、post-root、post-manifest、
post-full-test、所有后续mutation前与final pre-END共享LATEST并复证。
R24不提供filesystem transaction/lock/atomic snapshot，也不证明inode/hardlink/xattr/resource
fork不变或消除capture窗口外TOCTOU；变量commit不等于filesystem atomicity。

Review24唯一写`reviews/24-p1-plan-review.md`，须有唯一approval verdict与12-line machine
block，authority mode=`standing_goal_automatic_after_review24`、count=178。批准且Goal未撤销后
automatic caller仅传Review24 SHA。driver handoff后顺序仍为same-log 46/46、debug bundle、
formal source strip、target-exact/four-object、matrix/source/privacy、same-bundle preview、
final lifecycle、END；任一失败永久reject。Review24前全部执行、Review02/acceptance/A3关闭，
commit/push/merge/release/normal-data/外部/真实用户权限不扩大。

#### R24 final single-process clean-execution contract

本段是六个控制面的同一份最终 current override；它取代本轮较早的 R24 `handoff`、普通
`mv`、`kill -0` ownership 与 boundary 忽略信号措辞，但不改写 R15–R23 immutable 历史。
R24 仍是 source delta 0：Core 固定
`c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`，TestSuite 固定
`37fad0b3b123d248f6a52128f5f5d60559587cb8d291b6a6a6da1d615ad87967`；178-path manifest
方程、R23 的 156 unchanged + 7 expected mismatches、R23 163 paths + 15 additions、
R20/R23/R15 历史与 zero-write red lines 全部保持。R24 manifest 排除自身、freeze、Review24、
12 个 R24 runtime paths、两个 fresh roots，以及 invocation-owned hidden publish stages。

1. caller 只可用冻结的 clean `env -i` 与 system Bash 3.2 调用 driver，并只传 Review24 SHA。
   从 BEGIN、唯一 full test、全部 mechanical gates、两次 preview 到 END 必须在同一个 reviewed
   Bash process 内完成，不存在 caller continuation 或 handoff。canonical cwd/self、exact env、
   branch/HEAD、Review24 machine block、178/178、predecessors 与 source hashes 在 preflight 和
   final pre-BEGIN 重证。BEGIN boundary 使用 defer-only HUP/INT/TERM window 与 O_EXCL；成功后先
   `BOUNDARY_ACTIVE=true`、恢复 fail traps并立即消费 deferred signal。EEXIST 只 pre-BEGIN fail，
   不 append、不消费 authority；成功消费后的任一普通 signal/failure永久
   `REJECTED_CONTAMINATED`。

2. driver 独占创建 fresh verify log，并在同一顶层 Bash 运行唯一 unfiltered
   `swift run RunTests | tee`；then/else 第一条都复制 exact two-element `PIPESTATUS`，随后在
   defer-only commit 中写 Swift rc、tee rc、`status_captured=true`。只允许 `0/0`、唯一
   `652/652`、7 suites/0 failures 与 same-log 46/46 继续。之后顺序固定为 debug build → fresh
   signed bundle → guard strip → target-exact Core/TestSuite release → four object symbol gates →
   matrix 177+1 window及mandatory restore → source/privacy → same-bundle preview → final reproof →
   staged report/END。matrix backup、mutated stage、restore stage各有独立 OWNED flag，只能在各自
   O_EXCL成功后置true；禁止预删，copy/write只落到owned path，成功publish/cleanup即清flag；
   EEXIST保留unowned path并reject。success/error/signal只按exact ownership恢复或清理；恢复失败
   只能继续containment并永久reject。

3. R24 fresh state/bundle roots初始都必须 exact real non-symlink empty。current phase 只允许：
   `empty`；`bundle_ready`；`preview_live` 时 state exact
   `{.agentloop.lock, agentloop.sqlite, agentloop.sqlite-shm, agentloop.sqlite-wal}`；
   `preview_quiescent` 时 exact base two，且 WAL/SHM 必须成对同时 absent 或同时为 regular file，
   禁止 extra。R23 two-bit baseline `11`与R20 38-bit universe继续以完整 A/B capture只允
   1→0；R15 exact tombstones、alternate identities与全部 predecessor zero-write逐门 fail closed。

4. fresh bundle 使用 invocation-unique合法 `CFBundleIdentifier`，signed `Info.plist` 只带 exact
   `LSEnvironment` 的 isolated state root 与 preview=1；bootstrap 与 cold 都直接执行同一个 exact
   signed executable，显式传两项 env、stdin `/dev/null`、PID 只取 `$!`，不得用 `open`、display
   name、bundle-id fallback或 `pgrep` 建立 ownership。launch 前将 signals 改成 defer-only，覆盖
   fork、`$!` assignment、PPID/lstart capture；identity commit后恢复 fail traps并消费 deferred。
   containment与正常 Quit 都以两轮稳定 `jobs -pr`/`jobs -ps` running+stopped membership为 Bash
   active-job gate；TERM/KILL 前即时再验 `PPID==driver $$`，已 commit 时还须 exact `lstart`。
   pre-exec command mismatch只作诊断，不能阻止已证明 owned child的containment；active set absent
   才消费 cached `wait`，禁止用 `kill -0` 对可能已复用的 OS PID 作 kill authorization。

5. bootstrap B01–B06 exact flow 为 onboarding → `进入我的营地` → dashboard 唯一 feed hero且
   `查看全部` 0 → App menu → 唯一 `Quit AgentLoop` → Quit；随后只在 isolated DB 事务安装
   `a2-preview-ingestion-recovering` / `a2-preview-work-recovering` fixture，标题`隔离恢复验证`、
   raw text `A2 isolated synthetic rumination fixture`、ruminating attempt 1、queued attempt 0/
   max 4、canonical input/trace/idempotency/nullables/FK/integrity均 exact。cold C01–C09 为
   dashboard `查看全部 1`唯一 → inbox fixture/`查看进度`唯一 → recovering detail；C05 exact
   metrics 是标题1、`保存原文，已完成` 2、`正在恢复，正在进行` 3、后三阶段0；C06只复制 C05
   已有 screenshot URL 到 exact raw path，不再读取 UI 或执行 UI action；随后 menu/Quit。
   每个观察使用完整 app path、full state、`disableDiff=true`、nonce exact reply、unique label
   count；坐标与 fallback 禁止，B06/C09 后不得再调 UI。

6. screenshot raw file先验 magic/bytes/SHA；normalization stage必须在 evidence 同目录以
   invocation path O_EXCL 创建并标记 owned，`sips`只写该 owned path，随后完成 PNG header/IHDR、
   dimensions、full decode/MIME/SHA。publish 前即时重证 fixed final absent，使用 `mv -n`，且
   stage absent、final regular non-symlink、final SHA等于 staged SHA才发布成功。no-op/EEXIST
   只能清本 invocation owned stage，绝不覆盖或删除 unowned final；成功后 raw/stage清理，failure
   的 isolated raw保留为 contaminated evidence。

7. `impl-report-r24.md`同样先写 task 同目录 invocation-owned O_EXCL hidden stage，完成内容、
   privacy、type 与 SHA 后才发布。final 前即时 absent，`mv -n`后必须 stage absent、final regular
   non-symlink且 exact staged SHA；active failure只可删除 owned stage，或在 END 尚未 commit 且
   published final仍匹配 exact staged SHA时删除，绝不删除 unowned/tampered final。report publish
   window 的 deferred signals在 postconditions 后恢复 normal traps并立即永久reject。唯一
   commit-wins 例外只从随后 fresh tiny END-append window 开始：一次写入以 `status=END`、
   `result=PASS`结尾的完整 block；成功后同一 simple command设置 `END_COMMITTED=true` 与
   `BOUNDARY_ACTIVE=false`，再清 traps。END 前或 append failure都清理未提交 PASS report并写
   `REJECTED_CONTAMINATED`；END commit后不得再追加 rejected。

8. evidence 只允许声称所有已观察 preview processes 为 exact isolated direct children、normal
   root observed-open count为0、未观察到replacement；不得声称覆盖未观察区间、filesystem
   transaction/lock、零 preference write或绝对没有 TOCTOU。invocation-unique UserDefaults
   onboarding write必须在report披露。Review24仍须职责隔离、唯一 `APPROVED — 0 P0 / 0 P1`
   与唯一12-line machine block（standing Goal automatic/no hash echo、three hashes、branch/
   HEAD、count 178）。Review24与新 freeze/manifest完成前继续禁止 caller/BEGIN、所有 execution
   gates、Review02/acceptance/A3及任何产品/test/App/permanent-script修改；commit/push/merge/
   release、normal-data、外部沟通与真实用户操作始终未授权。

#### R25 final numeric-rendering clean-execution contract

本段是六个控制面的同一份最终 current override；它不改写 R15–R24 immutable
历史，只把 R24 已证明的 harness false negative 与 R25 的唯一修订路线设为 current。
R25 的 source/product/test/App/permanent-script delta 精确为 0；Core 固定
`c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`，TestSuite 固定
`37fad0b3b123d248f6a52128f5f5d60559587cb8d291b6a6a6da1d615ad87967`，matrix script 固定
`75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c`。R25 不重新解释、
补写、清理、删除、重命名或复用任何 R24 evidence/root。

1. R24 freeze `f22a7ffd954ddf6d9b2d804a5f3be58807373c388634b9200d260f1a8eb66746`、
   Review24 `a9ef2cab24afa65290f563b85ac03022b958d39253c025017d1c91b689926c0e`、
   driver `1b224f442d1fdea856433d12141e5ea9f74190a380e554e4ec94872ba0b8655f`
   与 178-entry manifest
   `55a6c2e8a657166de8b983cd0edfb2a7b1ae1943dc291819c0c2ea417338a80c`
   均 immutable。R24 唯一 BEGIN 内的 authoritative Swift/tee rc 是 `0/0`，terminal
   `652/652`、7 suites/0 failures、same-log `46/46`、debug build、fresh signed bundle 与
   `LAUNCH_READY`均通过；随后 guard gate 以
   `reason=core_guard_shape_1:1::0:1:1`、phase `guard_shape_and_strip`、exit 70
   永久 `REJECTED_CONTAMINATED`。这些 partial green 既不等于 END，也不得替代 R25 的
   full rerun、Review02 或 acceptance。

2. 同一根因是 awk 未初始化数字在字符串拼接时渲染为空：Core parser 的 `bad` 实际为数值
   0，却输出 `1:1::0:1:1`；未到达的 TestSuite parser 具有同样潜在输出
   `3:3:6::0:1`。R25 只做 render-only numeric closure，不改变任何 predicate、token、
   guard line、source byte、test logic、build command、API、schema、migration 或产品语义：
   Core 六字段 `opens/closes/bad/depth/token/guarded`、TestSuite 六字段
   `opens/closes/directives/bad/depth/ok`均以 `+ 0`输出；same-log 顶层七个计数
   `run_started/test_started/test_passed/suite_started/suite_passed/failure_markers/summary`
   同样以 `+ 0`输出；matrix 两个 line scanner 只把 diagnostic
   `count/line`渲染为 `(count + 0):(line + 0)`。逻辑条件与失败语义逐字保持。

3. Core 与 TestSuite guard parser 各只有一个 pure helper。preflight 与 final pre-BEGIN
   都复用同一 helper，必须在 authority consumption、verify-log 创建和 full test 前分别得到
   exact `1:1:0:0:1:1`与`3:3:6:0:0:1`；active
   `guard_shape_and_strip`再次调用同一 helper，不复制第二套 parser。任何空字段、非 exact
   output、read failure 或 source drift 都在对应边界 fail closed；pre-BEGIN failure保持
   零 repository write且不消费 authority，BEGIN 后 failure永久reject。

4. R24 的十个既有 runtime files由 R25 逐一以 exact SHA、regular/non-symlink type和关键
   boundary事实重证：唯一 rejection、captured `0/0`、652/652、46/46、launch-ready、
   matrix restore-attempt count 0、matrix未mutation、无preview owned process、无END。
   `r24-migration-matrix.log`、source、bootstrap与cold logs是合法zero-byte historical
   artifacts；`impl-report-r24.md`与`r24-preview-smoke.png`必须继续 absent。R24 state root
   `/private/tmp/agentloop-r24-state.Qko2Y3`与bundle root
   `/private/tmp/agentloop-r24-bundle.OPfuVv`只作为historical observation，不是R25运行输入。

5. R24 root lifecycle固定39-bit universe：state root、bundle parent、App与exact 36个
   descendants（6 directories、30 regular files），planning baseline为39个`1`。present
   state必须exact canonical empty；present bundle/App/node必须exact identity、type与每文件hash，
   无extra/symlink/special/wrong type/hash；full 36-node set另须aggregate
   `1871d346bed8b7978f7456e2893218a97cad7b8dc643c84bba9cd87cb81c8b5e`、
   strict codesign与CDHash
   `17bd20ada27ef9e69d0de007b49c53d01ddf48a6`。每次observation完整A/B双capture，
   `BASELINE/LATEST→A→B`只允1→0；FIRST/LATEST/accepted-B只在全部比较通过后的同一
   defer-signal commit写入，0→1、alternate、indeterminate或substitution永久reject。R25从不
   mutate/clean这些roots；R23 two-bit、R20 38-bit、R15 tombstones及所有zero-write
   predecessor gates继续保留。该观察不提供filesystem transaction/lock，不证明inode/hardlink、
   xattr/resource fork或消除TOCTOU；未观察区间不能外推。

6. R25 static manifest精确为`192 = R24 178 + 14`：完整R24 path set，加fresh R25 driver、
   immutable R24 manifest/freeze/Review24及十个R24 runtime files。六面同步后旧R24 manifest
   必须精确`172 unchanged + 6 expected control-surface mismatches`；TestSuite不再是mismatch。
   manifest排除自身、R25 freeze、Review25、12个R25 runtime paths、两个fresh roots与全部
   invocation-owned hidden stages。entry、每个mutation边界、matrix restore后与END必须
   `192/192`；唯一matrix窗口只允许`191 unchanged + matrix script 1 expected mismatch`，
   三个independent OWNED flags、O_EXCL、no-pre-delete、owned-stage replacement/exact
   restoration与fail-once
   containment合同全部继承且不放宽。

7. R25 caller只可用冻结的clean `env -i`与system Bash 3.2调用fresh
   `r25-begin.sh`，只传自动计算的current Review25 SHA。R25使用全新的12个runtime names、
   `agentloop-r25-state.*`/`agentloop-r25-bundle.*` roots、invocation ID、bundle identifier、
   hidden stages与boundary；不得复用R24 root、bundle、binary、verify log或测试结论。从BEGIN、
   唯一unfiltered `swift run RunTests | tee`及即时two-element `PIPESTATUS` capture、
   same-log 46/46、debug build/fresh signed bundle、guard/strip、target-exact releases、
   four-object gates、191+1 matrix/restoration、source/privacy、same-bundle bootstrap/cold
   preview、staged report到END，必须在同一个reviewed Bash process内完整重跑，禁止handoff、
   caller continuation、重跑、patch-on-failure或换root/object。

8. R24 final contract中的O_EXCL boundary与deferred-signal consumption、fresh-root phase/type
   gates、direct `$!` launch、stable Bash jobs + PPID/lstart containment、禁止以`kill -0`
   授权kill、exact B01–B06/C01–C09 UI与isolated fixture、screenshot/report `mv -n`
   no-clobber publish、
   privacy/source gates以及唯一tiny END commit-wins window全部逐字继承。R25 evidence只能声称
   已观察process为exact isolated direct child、已观察normal-root open count为0且未观察到
   replacement；不得声称覆盖未观察区间、绝对无TOCTOU或zero preference write，且report必须
   披露invocation-unique UserDefaults onboarding write。

9. Review25必须职责隔离：reviewer不得写R25六面、driver、manifest或freeze，唯一repository
   write只能是`reviews/25-p1-plan-review.md`；正文只可有一个
   `Verdict: APPROVED — 0 P0 / 0 P1`及唯一12-line `R25_MACHINE_BLOCK`，authority mode为
   `standing_goal_automatic_after_review25`、`reviewer_write_scope=review25_only`、
   `user_hash_echo_required=false`，并绑定current freeze/driver/manifest三hash、固定
   branch/HEAD与`manifest_count=192`。Review25通过且无更新user turn撤销standing Goal后，
   root agent自动计算Review25 SHA并调用冻结caller，不再要求用户echo hashes。

10. R25 manifest、freeze与独立Review25完成前，caller/BEGIN、test/build/matrix/source/
    bundle/preview及任何产品/test/App/permanent-script修改继续禁止。只有R25 exact END及全部
    technical gates通过后，才可由新的职责隔离reviewer写`reviews/02-p1-a2-review.md`；只有
    Review02零P0/P1才打开独立acceptance，A3及以后slice始终关闭。commit、push、merge、
    release、数据重置、normal-data access、付款、公开沟通、外部操作与真实用户操作均未授权。
    任何新架构、范围、依赖、测试门、语义或证据缺口必须重新进入正式有界修订与职责隔离Review，
    不得由本段或standing Goal自行扩权。


#### R26 final ERR-subshell clean-execution contract

本段是六个控制面的同一份 current override；它不改写 R15–R25 immutable 历史，只把
R25 已证明的 Bash `ERR` trap/status-capture 根因与 R26 唯一有界路线设为 current。
R26 的 source/product/test/App/Package/schema/migration/permanent-script delta 精确为 0；Core、
TestSuite 与 matrix script bytes 分别继续固定为
`c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`、
`37fad0b3b123d248f6a52128f5f5d60559587cb8d291b6a6a6da1d615ad87967`与
`75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c`。R26 不重新解释、
补写、清理、删除、重命名或复用任何 R25 evidence/root。

1. R25 freeze `8e6d97aca80591f544b40a8b645c01f1c5624f0f120d5ac12cedf37b94ffbeca`、
   Review25 `65b738e9c977e97ec6acdfbadad938d43ff97213c42e3b56297e67998dec237e`、
   driver `1eee61d199c5bb1c5b0149989f17508e9a75eacfbc2bac3b1a2f0063f0ab68bb`与
   192-entry manifest
   `462be6ff554b3d38bea76ac8351a77f780b575a1a9aeae4a461e42dd303655ba`均
   immutable。R25 唯一 BEGIN 内 full test 是 captured Swift/tee `0/0`、terminal
   `652/652`、7 suites/0 failures；same-log `46/46`、debug build、fresh signed bundle、
   guard/strip、Core/TestSuite target-exact releases、four-object symbols、SQLite 3.51/3.52
   matrix restore、source/privacy/final hashes与pre-preview `192/192`均通过。R25 未收到任何
   UI challenge，未写 screenshot/report，且无 END，因此永久 `REJECTED_CONTAMINATED`，不得
   替代 R26 full rerun、Review02 或 acceptance。

2. R25 在 `preview_bootstrap_direct_start`依次留下三个 rejection blocks：child substitution
   内 `/usr/bin/pgrep -x "${r25_name}"` rc 1、同一 child function 的显式
   `return "${r25_rc}"` rc 1，随后 root caller 因 app 已被 child containment终止而以
   `preview_command_read_failed_bootstrap_ready` exit 70。根因不是产品、bundle、SQLite、UI或
   process identity失败，而是全局 `set -E`把 root `ERR` trap继承进 command-substitution
   subshell；child将预期 absent/transient nonzero误当成 root failure并执行root-owned cleanup。
   R25 final containment最终reap exact child，AgentLoop/AgentLoopApp均不存在，但三次reject与
   no-END事实不可合并、删除或美化成一次成功边界。

3. R26 的唯一 causal fix 位于 fresh `r26_err_trap`最前：先保存真实`$?`与
   `${BASH_COMMAND}`，随后在任何日志、active/pre-BEGIN failure或cleanup之前执行
   `if (( BASH_SUBSHELL != 0 )); then trap - ERR; exit "${r26_status}"; fi`。child只把原始
   status传播给root caller，绝不执行active/pre-BEGIN containment；root shell
   `BASH_SUBSHELL == 0`时仍逐字走原 fail-fast 路径。禁止增加child-local `EXIT` trap、全局
   关闭ERR、`|| true`、吞错、改caller分类或packet/fallback旁路。该一处root fix统一覆盖
   exact-name absent/caller、`pgrep -P` no-child、launch identity `ps` retry、startup
   readiness `ps/lsof`、signal authorization/live-proof与quit-wait `ps` disappearance；
   rc > 1、malformed、duplicate、unexpected payload与identity mismatch仍fail closed。

4. final pre-BEGIN必须通过一个静态guard/inventory门与八类system Bash 3.2 micro-probes。
   静态门证明guard在root cleanup之前、全driver无`EXIT` trap，并把同根nested capture精确
   清点为15个`/bin/ps`、2个`/usr/bin/pgrep`、3个`/usr/sbin/lsof`。micro-probes必须证明：
   legacy形态产生两次child cleanup；fresh guard下exact-name absent、exact-name present、
   no-child、transient ps retry、transient lsof safe subset与rc 2 indeterminate分别保留原rc/
   payload且child active side-effect为0；最后raw未捕获`x="$(false)"`向root传播并恰好触发
   一次root fail-fast。任何probe/inventory/guard-order偏差在BEGIN前零repository-write停止且
   不消费authority。

5. R25 的十个实际runtime files继续以exact SHA、regular/non-symlink type及关键boundary
   事实重证：targeted、verify、build、matrix、boundary、bundle、source、hash、bootstrap与
   cold logs分别固定为
   `538cf3ff68d95318ab7da9dc7a685648f4c7651668ca0c6fcf4dc35c8a48e532`、
   `9a0d772ac0f36cf56b2340c741d237dfbc2a4a6a9ecd4314bb5b95319f7b8b5f`、
   `cc50f7f484bb397052dae2be64307361e99255fd27169648cb4ac36aa75dd703`、
   `7c0e55705520fe79281e7a38b409177515f00fedc89eb8c8bf68fc0f4f74dca9`、
   `2d1dabc7872b31b7d330700c0979857563af84491ff39391b3bf9279ff50c0d4`、
   `5bdfdad577d4f9c0c029463c59cf442b83122939f76e59c435e89371e682e3d5`、
   `8d995eeb44fbccd42d9f83a0b64088d35f326ac8dd0051198327320ca2f0466f`、
   `bba9e1ffd51e2f8fb066d00226fc18f9e4f66b9c32f1917129522b471706564a`及
   两个empty SHA。`impl-report-r25.md`与`r25-preview-smoke.png`必须继续absent；任何R26
   evidence不得声称R25到达UI或END。

6. R25结束后，一次职责隔离evidence audit用SQLite read-only URI打开了R25 WAL-mode state
   database；它未改repository、bundle、normal-data或用户root，但可能更新`-shm`，且缺少
   before hash/mtime，故R25 state root从此明确标记
   `POST_REJECTION_READ_PROBE_CONTAMINATED`。R26对R25 state root
   `/private/tmp/agentloop-r25-state.fs7Cz2`与bundle root
   `/private/tmp/agentloop-r25-bundle.Ozi6d3`只允许coarse two-bit root-entry lstat/type A/B
   observation：baseline `11`，每轮完整A/B，仅允许equality或1→0，0→1、alternate、symlink、
   wrong type或indeterminate拒绝。本项的alternate只指这两个exact path的root-entry shape不是
   约定real directory；固定two-bit universe不扩张到parent/glob扫描，也不声称检测same-type
   inode replacement。严禁进入、枚举、hash、open或clean任一R25 root/descendant，
   严禁把R25 state contents/hash当作original terminal evidence或R26运行输入；FIRST/LATEST/
   accepted-B仍只在全部比较通过后同一defer-signal commit。R23、R24、R20 lifecycle与R15
   tombstones继续按既有合同观察。

7. R26 static manifest必须精确为`206 = R25 192 + 14`：完整R25 path set，加fresh R26
   driver、immutable R25 manifest/freeze/Review25及十个实际R25 runtime files；R25 driver已在
   old 192内，不得重复。六面同步后旧R25 manifest分区必须精确
   `186 unchanged + 6 expected control-surface mismatches`。R26 manifest排除自身、R26
   freeze、Review26、12个fresh runtime/report paths、两个fresh roots与全部invocation-owned
   hidden stages。entry、mutation边界、restore后与END必须`206/206`；唯一matrix窗口只允许
   `205 unchanged + 1 owned matrix-script mismatch`，既有O_EXCL、no-pre-delete、三OWNED flags、
   exact restoration与fail-once containment均不放宽。

8. R26使用全新12个runtime names、`agentloop-r26-state.*`/
   `agentloop-r26-bundle.*` roots、invocation ID、bundle identifier、hidden stages与boundary。
   从BEGIN、唯一unfiltered `swift run RunTests | tee`及即时two-element`PIPESTATUS`、same-log
   46/46、debug build/fresh signed bundle、guard/strip、target-exact releases、four-object gates、
   205+1 matrix/restoration、source/privacy、same-bundle B01–B06/C01–C09 preview、staged
   screenshot/report到tiny commit-wins END，必须在同一reviewed Bash 3.2 process完整重跑。
   禁止复用R25 root/binary/log/result，禁止handoff、caller continuation、retry、patch-on-failure
   或换root/object；UI evidence claim继续限制为observed intervals，不外推绝对无TOCTOU、绝对
   zero normal-root open或zero preference write。

9. Review26必须职责隔离：reviewer不得写R26六面、driver、manifest或freeze，唯一repository
   write只能是`reviews/26-p1-plan-review.md`；正文只可有一个
   `Verdict: APPROVED — 0 P0 / 0 P1`及唯一12-line`R26_MACHINE_BLOCK`，authority mode为
   `standing_goal_automatic_after_review26`、`reviewer_write_scope=review26_only`、
   `user_hash_echo_required=false`，并绑定current freeze/driver/manifest、branch/HEAD与
   `manifest_count=206`。Review26通过且无更新user turn撤销standing Goal后，root agent自动
   计算Review26 SHA并调用冻结caller，不要求用户echo任何hash。

10. R26六面、fresh driver、exact 206-entry manifest与freeze均已冻结；Review26此刻仍absent，
    caller/BEGIN、test/build/matrix/source/bundle/preview、Review02、acceptance及任何产品/test/
    App/Package/permanent-script修改继续禁止。只有manifest/freeze完成并由独立Review26零P0/P1
    批准后才自动执行；只有R26 exact END及全部technical gates通过后才可创建独立Review02；
    只有Review02零P0/P1才打开A2 acceptance，A3及以后slice仍关闭。commit、push、merge、
    release、数据重置、normal-data access、付款、公开沟通、外部操作与真实用户操作均未授权。
    任何新架构、范围、依赖、测试门、语义或证据缺口必须重新进入正式有界修订与职责隔离Review，
    不得由本段或standing Goal自行扩权。

## 20. Open Questions

无。

## R27 current override — compound-if status capture root-cause closure

本段是六个 current control surfaces 的 byte-identical override。R15–R25 历史继续
immutable；R26 也永久保留为 `REJECTED_CONTAMINATED`。R27 不重新解释、补写、清理、删除、
重命名或复用任何 R26 evidence/root，且 source/product/test/App/Package/schema/migration/
permanent-script delta 精确为 0。Core、TestSuite 与 matrix script bytes 继续固定为
`c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`、
`37fad0b3b123d248f6a52128f5f5d60559587cb8d291b6a6a6da1d615ad87967`与
`75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c`。

1. R26 predecessor 四锚固定为 freeze
   `0306f000961e6ed7b129307475495cb3a798df2adb833a9da830e5ddc70ef7cb`、Review26
   `8d9cc6b3acaeda72204b1a71f209996344215b61747b8c516d7afbf067880ba9`、driver
   `937a8cb4e737480f5cf44409d9dedbcdd581f627c46726957352a7b56f5c296d`与206-entry manifest
   `f9d697f35227e6db7df1e8e1b87c4969a184b0a7f65a3d6c70f7c8bfe5d7a22d`。R26 唯一 BEGIN
   已 captured Swift/tee `0/0`、terminal `652/652`、7 suites/0 failures；same-log `46/46`、
   debug build、fresh signed bundle、guard/strip、target-exact releases、four-object gates、
   SQLite 3.51/3.52 matrix restore、source/privacy/final hashes及pre-preview `206/206`均通过。

2. R26 到达真实 same-bundle bootstrap preview，B01–B06 的六个 challenge 与六个 result
   全部 PASS；B06 后 App 已正常退出。随后在 `preview_bootstrap_direct_start`以唯一
   `quit_wait_job_table_indeterminate_bootstrap_0`拒绝。cold log empty；C01–C09、fixture、
   screenshot、impl report与END均未发生，因此上述结果不能替代R27 full rerun、Review02或
   acceptance。R26 final containment后exact child已reap，且无残留AgentLoop/AgentLoopApp。

3. 唯一根因是Bash 3.2 compound-`if` status语义：生产路径精确五处采用
   `if r26_preview_active_job_exact; then ...; fi`后再读`$?`。当helper真实返回1（stable
   `ABSENT`）时，无`else`且未执行then-body的compound `if`自身状态为0，故caller读到0并误报
   indeterminate；这不是job-table classification、UI、process identity、bundle或产品错误。
   R27只把这五处改为`else`分支第一语句立即保存`r27_job_rc="$?"`。其余8处既有explicit-else
   capture、helper的0/1/2分类、signal/kill/wait/containment算法及所有fail-closed边界逐字保留。

4. 为关闭R26 evidence audit指出的P1可观测性缺口，job-table helper只新增三个安全global
   diagnostics：last previous state、last latest state与returned rc；state值只来自
   `UNOBSERVED/RUNNING/STOPPED/ABSENT/TRANSITION`，rc只来自`UNSET/0/1/2`，绝不保存或输出
   任意jobs/ps/lsof payload。正常quit log必须记录真实job rc与state pair；rejection boundary
   必须记录containment后的latest diagnostic。诊断不改变任何classification、retry、signal、
   cleanup或acceptance语义，rc 2继续indeterminate fail closed。

5. 两轮final pre-BEGIN（均在caller/BEGIN及任何repository write前）各自依次执行既有
   ERR-subshell static guard与八类Bash 3.2 probes，再执行fresh compound-if static gate与
   Bash 3.2 probes。fresh static gate必须证明production helper精确13 calls/13 immediate
   else captures、上述五个causal sites精确存在、production中`fi`后或同一行后读`$?`为0，
   diagnostics assignment只属于安全enum。fresh probes必须证明rc 0、rc 1、rc 2逐字捕获，
   rc 1 diagnostics为stable absence，rc 2 diagnostics与classification保持fail closed，并以
   legacy no-else probe证明helper rc 2会被compound `if`错误映射为0。任何偏差pre-BEGIN零写入
   停止，且不消费standing Goal authority。

6. R26十个runtime files必须以regular/non-symlink type、exact SHA与exact bytes重证，顺序为
   boundary `814ad7bfc50dfa6e5de65b10f470c8dee3bdbfed3ee2532776ad7011658b2280`
   /14381，hash `7041b3fc36c6fcc5a0686d9deb95cb4c6738425579f62b904dfbcd83aebf3198`
   /6063，verify `212a205b2baaf8d052513f148199ea8679ab625d0d607255e58a2d6807b61ea8`
   /96130，targeted `24b321736976667737b38eefcd79c11ecfc90322b9a495e63d7f6fcf52436fea`
   /4718，build `068e012ddb71725eac797c2b76f56972a403048ff0fed5010a7d14ad0ffc6fc6`
   /729，matrix `124b28b317581ea19b7647dfa084ebc7e3c3394fe02c9a40fd80d2de20006932`
   /44058，bundle `c5604214b12c265fe0100a500491a08eeff7ab95d543b753d2ee433ad459d906`
   /2661，source `58c90e5840c6c14d529ecb53f1b6ada95d2707a4b99d4c18fedee1c253767b76`
   /2998，bootstrap `d10ee7940284ccb289ba48a40284e3c539f421054e39718b02d7a94499b53733`
   /6557及cold empty SHA/0 bytes。`impl-report-r26.md`与`r26-preview-smoke.png`必须absent；
   boundary的BEGIN/652/652/46/46/launch/source/206/206/B01–B06/rejection/no-END关键事实必须重证。

7. R27对R26 state root `/private/tmp/agentloop-r26-state.JlHsbi`与bundle root
   `/private/tmp/agentloop-r26-bundle.mCj70H`只允许按此固定顺序对两个exact root entries执行
   `os.lstat` A/B，baseline为`11`；只接受real directory或absent，允许equality或1→0，拒绝
   0→1、symlink、wrong type与indeterminate。固定two-entry universe不扩张到parent/glob扫描，
   也不声称检测same-type inode replacement。严禁进入、枚举、hash、open、clean或复用任何
   R26 root/descendant；FIRST/LATEST/accepted-B仍只在整轮比较通过后的defer-signal窗口提交。

8. R27 static manifest必须精确为`220 = R26 206 + 14`：完整R26 path set，加fresh R27
   driver、immutable R26 manifest/freeze/Review26及十个R26 runtime files；R26 driver已在old
   206内不得重复。六面同步后old partition必须`200 unchanged + 6 expected control-surface
   mismatches`。manifest排除自身、R27 freeze、Review27、12个fresh runtime/report paths、
   两个fresh roots与全部invocation-owned hidden stages。normal/restore/END为`220/220`；唯一
   matrix窗口为`219 unchanged + 1 owned matrix-script mismatch`，既有O_EXCL、no-pre-delete、
   ownership与exact restore/fail-once containment不放宽。

9. R27使用全新12个runtime names、`agentloop-r27-state.*`/`agentloop-r27-bundle.*`、
   invocation ID、bundle identifier、hidden stages与boundary；从BEGIN、唯一unfiltered full
   test及即时two-element `PIPESTATUS`到same-log、build、release/object/matrix/source/privacy、
   B01–B06/C01–C09、staged screenshot/report与tiny commit-wins END，仍须在同一reviewed Bash
   3.2 process完整重跑。禁止复用R26 root/binary/log/result、handoff、caller continuation、
   retry、换root/object或patch-on-failure；UI claim仍只限observed intervals。

10. Review27必须职责隔离：reviewer不得写六面、driver、manifest或freeze，唯一repository
    write为`reviews/27-p1-plan-review.md`；正文只允许一个`Verdict: APPROVED — 0 P0 / 0 P1`
    及唯一12-line `R27_MACHINE_BLOCK`，authority mode为
    `standing_goal_automatic_after_review27`、scope为`review27_only`、
    `user_hash_echo_required=false`，并绑定current freeze/driver/manifest、branch/HEAD与
    `manifest_count=220`。Review27通过且standing Goal未撤销后，root agent自动计算review SHA
    并调用冻结caller，不要求用户echo hash。

11. R27六面、fresh `r27-begin.sh`、exact 220-entry manifest与R27 freeze均已冻结；Review27、
    所有R27 runtime/report/root/stage仍absent pending。独立Review27批准前，
    禁止caller/BEGIN、test/build/matrix/source/bundle/preview、Review02、acceptance及产品/test/
    App/Package/schema/migration/permanent-script修改。只有R27 exact END及全部technical gates
    通过后才可创建独立Review02；只有Review02零P0/P1才打开A2 acceptance，A3及以后仍关闭。
    commit、push、merge、release、数据重置、normal-data access、付款、公开沟通、外部操作与
    真实用户操作均未授权；任何超出本段的决策必须重新进入有界修订与职责隔离review。

## R28 current override — Shell timeout measurement-boundary root-cause closure

本 override 是六个 control surface 的唯一 current R28 入口；此前全部 R15–R27 历史与
immutable evidence 保留且不得重解释、补写、清理、删除或用后继结果替代。

1. R27 clean invocation 已永久 `REJECTED_CONTAMINATED`。四个 immutable anchors 为：

   - freeze `6d45ecf515861c9aa022ebeea994fc309350e4f33fb7425d01a700777425dd41`；
   - Review27 `74d20ed9909ba576beaba86659672c423686a7f798adf5bfbc6929607f606e5f`；
   - driver `770d0a413b449e4ea14db4bd8f7dc880f134c20a013b3ef76f684ba3e0f7432d`；
   - manifest `178af4f5f5fa30fd4a070125b8eafbfc0268fc74ad9703293e5dca124a37262e`。

   R27 的十个 actual runtime files 均为 immutable regular non-symlink evidence：

   | Runtime evidence | Bytes | SHA-256 |
   |---|---:|---|
   | `r27-targeted-tests.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
   | `r27-verify.log` | 96,330 | `6279dadbdfbd37d6fb6730fbf037a0d0dfd40fbfab8acb4f91b01967f79297ea` |
   | `r27-build.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
   | `r27-migration-matrix.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
   | `evidence/r27-clean-boundary.log` | 8,066 | `f7807793b9cea03b0611af134918380cd4521d687fe0a3bb1e4c2955dd874310` |
   | `evidence/r27-bundle-provenance.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
   | `evidence/r27-source-gates.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
   | `evidence/r27-hash-manifest.log` | 3,091 | `01b8cb95805e52703fb394d56b8c38f344286a02ed7b7a443ed886b2ed6c3a21` |
   | `evidence/r27-preview-bootstrap.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
   | `evidence/r27-preview-cold-start.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

   `evidence/r27-preview-smoke.png` 与 `impl-report-r27.md` 均 absent。R27 只有唯一
   unfiltered authoritative full test：651/652，唯一 issue 为
   `shellTimeoutTerminatesProcess()` 的 elapsed assertion；targeted、build、release、
   object、matrix、source、privacy、bundle、UI、screenshot、report 与 END 均未发生。
   Exact predecessor roots 仅为 `/private/tmp/agentloop-r27-state.rc7ama` 与
   `/private/tmp/agentloop-r27-bundle.6Q3UjM`；fixed exact-root `lstat`-only baseline
   固定为 state=1、bundle=1，即 `11`。R28 只允许对这两个已解析 exact pathname 做 fixed
   `lstat` lifecycle observation；绝不进入、枚举、打开、读取或哈希任何 descendant，也绝不
   把 root contents 当作 R28 input。

2. R27 的同一根因被精确限定为 measurement-boundary contamination。现有
   `shellTimeoutTerminatesProcess()` 在调用 `tool.execute` 前启动 `ContinuousClock`；而
   `ShellTool.execute` 会先 `await LoginShellEnvironment.shared.environment()`，再
   `process.run()`，真正的 command deadline 在环境解析与 process start 之后建立。
   Login-shell capture 自身有合法的 5 秒 safety guard，command timeout 为 300ms，终止 grace
   仍为 300ms；因此 cold environment capture 加 command timeout/grace 合法超过测试的 5 秒
   wall-clock ceiling。R27 实测 elapsed 为 5.13908825 秒，只有 `< .seconds(5)` 这一断言
   记录 issue；这不证明 ShellTool 的 300ms command deadline 失效。

3. R28 唯一允许的实施文件为
   `Sources/AgentLoopTestSuite/ShellToolTests.swift`。其 exact pre-patch SHA-256 必须为
   `c4c75d66540c2cc0760f0edaef0650a93e2e589a45a5d8b932ab3b2bdc091350`。只允许在
   `shellTimeoutTerminatesProcess()` 内、现有 `let clock = ContinuousClock()` 的正前方
   新增且只新增以下一行：

   ```swift
   _ = await LoginShellEnvironment.shared.environment()
   ```

   Exact final SHA-256 必须为
   `37b9e97c567cc599b98899fe1ca6c1deb9383b2889d52c2c42d3236dd2535a29`。
   从 final bytes 删除且只删除这一条 exact newline-terminated line 必须恢复 exact pre-patch
   SHA；这就是 mandatory strip proof。既有 `< .seconds(5)`、300ms timeout、300ms grace、
   error/message/output/registry assertions、函数位置与其余 bytes 全部不变。

4. `Sources/AgentLoopCore/Tools/ShellTool.swift` 必须保持 SHA-256
   `e5980b4fb7d756656a7271ea646a54d49355c7a64f683245c6689254d76f2faf`；
   `Sources/AgentLoopCore/Support/ShellProcessRegistry.swift` 必须保持 SHA-256
   `260896d845d031e5cf46865303cfd00e944fa1c212278482c0d9a29d1001e6d1`。
   禁止提高或删除 threshold，禁止修改 timeout/grace，禁止为 environment 引入 injection、
   single-flight、public/package API 或产品逻辑，禁止修改 test order/filter，禁止 retry、
   sleep、重复 full run 或其他产品/test/App/Package/schema/migration/permanent-script 改动。
   Login-shell capture single-flight 只登记为 P2 后续候选，不属于 R28。

5. 实施顺序固定为：先同步本六面、生成 fresh R28 driver、exact 235-entry manifest 与
   R28 freeze；再由职责隔离 reviewer 执行 Review28；Review28 exact approval 后，root agent
   才能用 `apply_patch` 在 pre-BEGIN 窗口应用第 3 项 exact one-line change。若 pre-patch
   SHA、唯一上下文、final SHA 或 strip proof 任一不符，必须 fail closed 且不得 BEGIN。
   Frozen driver 不得写源码；它只在内部重新证明 final SHA、strip proof、两个 immutable
   product hashes 与 phase-aware manifest，然后由同一个 reviewed Bash 3.2 process 完成
   BEGIN 至 terminal END 的 full chain。

6. R28 static manifest 必须精确为 `235 = R27 220 + 15`。十五个 additions 只能是：fresh
   R28 driver；immutable R27 manifest、freeze、Review27；十个 R27 runtime files；以及
   `ShellToolTests.swift` pre-patch baseline。六面同步后相对旧 R27 manifest 的 partition
   必须为 `214 unchanged + 6 expected control-surface mismatches`；应用 one-line 后该 old
   partition 仍必须为 `214 + 6`。R28 pre-patch gate 为 `235/235`；实施后正常 phase 只能是
   `234 unchanged + 1 ShellToolTests mismatch`；matrix mutation window 只能是
   `233 unchanged + 1 ShellToolTests mismatch + 1 owned matrix-script mismatch`；exact
   restore 与 END 只能回到 `234 + 1`。任何额外 missing、addition、type drift 或 mismatch
   都必须拒绝。Manifest 排除自身、R28 freeze、Review28、fresh R28 runtime/report paths、
   两个 fresh roots与全部 invocation-owned hidden stages；既有 O_EXCL、no-pre-delete、
   ownership、no-clobber publication、exact restore 与 fail-once containment 不放宽。

7. R28 必须使用全新 runtime/report names、`agentloop-r28-state.*`、
   `agentloop-r28-bundle.*`、invocation ID、bundle identifier、hidden stages 与 boundary。
   同一 Bash process 必须运行唯一 unfiltered `swift run RunTests` 并得到 full 652/652、
   same-log exact 46/46、debug build、release Core/TestSuite targets、debug/release object
   symbol gates、migration matrix、source/privacy、bundle provenance、B01–B06、C01–C09、
   staged screenshot、implementation report 与 tiny commit-wins END。禁止复用 R27 root、
   binary、log 或结果，禁止 handoff、caller continuation、换 root/object、patch-on-failure
   或任何 retry；UI claim 仍只限 observed intervals。

8. Review28 必须职责隔离。Reviewer 不得写六面、driver、manifest、freeze、source 或
   runtime evidence，唯一 repository write 为
   `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/28-p1-plan-review.md`。
   Review 必须只含一个 `Verdict: APPROVED — 0 P0 / 0 P1` 与唯一 machine block，并绑定
   current six-body identity、freeze、driver、manifest、branch、HEAD、
   `authority_mode=standing_goal_automatic_after_review28`、`scope=review28_only`、
   `user_hash_echo_required=false`、`manifest_count=235`。Review28 通过且 standing Goal
   未撤销后，root agent 自动执行 exact pre-BEGIN patch 与 frozen caller，不要求用户 echo
   hash。

9. Review28 exact approval 前，禁止 one-line implementation、caller/BEGIN、test、build、
   matrix、source、bundle、preview、Review02、acceptance 及任何其他产品/test/App/Package/
   schema/migration/permanent-script 修改。只有 R28 exact END 与全部 technical gates 通过后
   才能创建职责隔离 Review02；只有 Review02 零 P0/P1 才打开 A2 acceptance。A3 及以后仍
   关闭。Commit、push、merge、release、数据重置、normal-data access、付款、公开沟通、
   外部操作与真实用户操作均未授权；任何超出本 override 的架构、依赖、语义、测试或证据
   决策都必须重新进入有界修订与职责隔离 review。
