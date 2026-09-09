# P1-A1a 实施 Plan — Durable Work DDL + Store

> 状态：**R9 Candidate Frozen；Review09 Pending；Implementation Paused**
>
> 日期：2026-07-26
>
> 当前代码基线：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`
>
> 当前分支：`codex/personal-ai-ranch-p0`

## 0. 文档控制

本文件是 P1-A1a 的职责隔离执行副本。它不修改、不解释也不取代以下唯一规范源：

- 冻结 Stage：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md`
- Stage SHA-256：
  `330dfd6de888e3cca14927cb9d82d5d4b1e1b7057b2814736fa923e2a2df0190`
- 冻结 Plan：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md`
- Plan SHA-256：
  `19e57761a9da3b11905ce72cb40e0e5c1a7bbcec1cb5f9462ef1cb1260da6ee3`

本文件 §4 完整承载冻结 Plan §3.1。实现时还必须直接读取冻结 Stage §5.1、§6.1、
§6.2、§6.2.1、§6.2.2、§18.1、§20、§22、§23，以及冻结 Plan §1、§10–§13。
任何冲突或哈希漂移时，冻结原文优先并立即停止；不得在本 task 内自行修订规范。

## 1. 进入条件

以下条件已经打开 A1a，但不打开 A1b：

- P0 `acceptance.md` 已判定 `ACCEPTED`；
- Review08 已判定 `APPROVED — 0 P0 / 0 P1`；
- R9 已按同一 SQLite `NULL/UNKNOWN` 根因有界修订并重新冻结；职责隔离
  Review09 尚未判定，因此 A1a 产品代码恢复实施、acceptance、A1b 与其他产品代码
  仍关闭；
- 冻结 Stage/Plan 的 Open Questions 均精确为“无。”；
- 当前位于 `codex/` 分支，进入代码基线与 worktree 必须由 implementer 再记录；
- 没有获得数据重置、commit、push、merge、release、付款、公开沟通、外部操作或
  真实用户操作权限。

A1a 是第一个 Codex implementation invocation。它只建立 ledger/store，不接
production planning。A1a 必须独立 Review/acceptance；未通过不得开始 A1b，也不得
在同一次 invocation 跨入任何其他 slice。

## 2. 职责、产物与执行顺序

固定 task 目录是：

`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a1a-durable-work-store/`

职责与可写产物严格分离：

- planner 只写并冻结本 `plan.md`；implementer 只读；
- implementer 只写 `verify.log`、`build.log`、`impl-report.md`；
- 独立 reviewer 只写 `reviews/01-p1-a1a-review.md`；
- acceptance owner 只写 `acceptance.md`，且只能在 Review 无 P0/P1 后判定；
- implementer 不得代写 Review 或 acceptance；reviewer 不得回写实现或验证日志。

若风险门需要 `evidence/`，必须先按冻结 Plan 明确对应产物和 owner；本 planner
文件不把它追加到 implementer 的可写清单。

implementer 的顺序固定为：

1. 保存 branch、HEAD、worktree；
2. 复算冻结 Stage/Plan 与本 slice Plan 哈希；
3. 先写失败测试，证明旧实现缺口；
4. 实施本文件 §4 的最小根因修复；
5. 运行并完整保存权威测试、App build 和 migration matrix；
6. 写 `impl-report.md`；
7. 交给职责隔离独立 Review；
8. 修完全部 P0/P1 finding；
9. Review 无 P0/P1 后才允许 acceptance owner 判定。

当前停在步骤 2 与步骤 3 之间；只有 Review09 对上述新 Stage/Plan/leaf hashes
判定零 P0/P1，才恢复步骤 3。R9 不改变其余步骤、owner或顺序。

不得 commit。

## 3. 禁止红线与失败路径

以下冻结 Stage §22 红线全部继续生效：

1. P0 未通过不得开始 P1 产品代码。
2. 子阶段 Review 未通过不得进入下一个子阶段。
3. 不得用 watchdog 把卡住状态改成成功；恢复必须知道原 work 和幂等键。
4. 不得在 transaction 外先 claim schedule slot、先导航庆祝验收或先扣 Grant。
5. 不得把 `campId == nil` 解释为全局 Camp 权限。
6. 不得把 required MCP / 知识失败降级为空。
7. 不得使用 CLI `--last` / `--continue` 做会话续传。
8. 不得把模型自然语言当验证通过、验收、状态或成长事实。
9. 不得为了测试方便关闭 append-only、CAS、hash、permission 或 migration 约束。
10. 不得记录秘密、OAuth callback、账号标识、Keychain 值或原始敏感内容。
11. 不得重置真实数据、commit、push、release 或邀请真实用户。
12. 任何迁移 replay 失败、unknown failure、Open Questions 非空都会阻止 P1 完成。
13. 不得从 durable planning path 调用会独立 commit token/fallback/Card 的旧 API，
    不得让 Planner 内部 retry/fallback 吞掉 provider error。
14. 不得把 App termination 当作成功 release；只有 ledger adoption 或显式、原子
    user cancel 可以改变遗留 work。
15. adapter/Board tool 不得创建或终结 Run/Card；唯一执行真相 owner 是 kernel。
16. `requireActiveCampWrite` 不得接受 deletion flag/token；deletion permit不得进入
    generic DurableWork/Grant/Engine API，旧 permit任一版本漂移必须 stale。
17. 不得从 path prefix/name/extension、missing file 或 symlink 推断 App ownership；
    unresolved legacy artifact 只可 typed 重检或 detach-only，workspace external/
    unresolved 永不 unlink。
18. 不得绕过 provider dispatch/engine/Grant ledger直接启动 Camp-scoped external
    call；returned checkpoint存在时不得重新 call provider。
19. failed deletion work/attempt immutable；repair只能新建 replacement并 CAS job
    pointer，不能 reopen/cancel deletion或复活 Camp。
20. ordinary Ingestion 删除不得接受 caller-claimed row facts，也不得把已 committed
    receipt/scope/event/outbox当作后续 mutation capability；command只由 Store
    prepare，且无同 AppDatabase exact writer cell、同 transaction generation、同
    ordered step的 active SQL permit必须 fail closed。permit/evidence/outbox/
    mutation只允许 specialized Store，不得复制 actor/device identity进 safe JSON。

当前 slice 的失败处理逐字遵守冻结 Plan §13：

- red test：留在当前子阶段，保存完整日志，定位根因。
- migration 失败：不修 normal DB；用临时 DB 复现并修 migration。
- 计划外架构需求：写当前 task `blocked.md`，停止该 slice。
- Claude/reviewer 不可用：按协议重试一次；使用职责隔离、证据可追踪的获授权替代
  reviewer；实现者不得自批。
- 三轮 Review 仍有 P0/P1：升级牧场主，不跨门。
- App preview 无法证明错误 UI：保存启动/进程/日志证据，不用 build 代替。
- 真实 CLI 不可用：contract tests 可以继续，但 P1 acceptance 必须把 live gap
  写明；不得宣称真实可用。
- 任一子阶段发现总 spec 冲突：暂停并请求产品决定。

## 4. 冻结 Plan §3.1 精确执行范围

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

## 5. 验证与验收输出

implementer 必须运行并保存完整输出：

```bash
swift run RunTests
swift build --product AgentLoopApp
scripts/verify-p1-migrations-sqlite-matrix.sh --sqlite 3.51 --sqlite 3.52
git diff --check
git status --short --branch
```

其中 migration matrix 必须覆盖冻结 Plan §10 的 A1a fixtures：fresh、v7、
v8-coding-ranch、v9-evercamp、v10、v11；同一真实 GRDB migrator必须分别链接/运行
SQLite 3.51/3.52 lane，不能复制最终 schema。每条 fixture 必须成功 migrate、重复
migrate、通过 foreign key/integrity/DDL/guard/backfill/rollback gate，且不依赖
normal DB。

Canonical number 的 `token <= 128 bytes`、`coefficient <= 128 digits` 与 explicit
exponent `-324...324` 前置限制共同作用时，plain-decimal 输出的理论最大值约为
454 bytes，因此“单独越过 512-byte output cap”在冻结输入边界内不可独立到达。
这不修改冻结规范：实现仍必须保留并执行 512-byte cap；运行时测试覆盖全部可达的
token、coefficient、exponent 和复合超界拒绝，并用允许文件范围内的源码/结构断言
证明 512 cap 未被删除或绕过。`impl-report.md` 与 Review 必须诚实记录该分支是冗余
防御、不能在其他冻结上限均成立时被独立触发；不得伪造一个违反前置边界的成功解析
fixture，也不得因此删改冻结测试名或规范。

A1a acceptance 的唯一允许结论边界是：CanonicalJSON v1、durable-work v12
migration、ledger/store 与本 slice 的全部契约和测试门成立。即使 A1a Accepted，
也不得宣称 production planning 已接线或 R-01 已关闭。
