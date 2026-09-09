# P1-A1b 实施 Plan — Durable Planning Supervisor + Integration

> 状态：**R11 Candidate Frozen；Review11 Pending；Implementation Frozen**
>
> 日期：2026-07-27
>
> 当前代码基线：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`
>
> 当前分支：`codex/personal-ai-ranch-p0`

## 0. 文档控制

本文件是 P1-A1b 的职责隔离执行副本。它不替代以下唯一规范源：

- Stage：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md`
- P1 总 Plan：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md`
- 上位产品 SSOT：
  `docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md`
- A1a acceptance：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a1a-durable-work-store/acceptance.md`
  - SHA-256：
    `070a2b6815ef85323d1041d3023ebc28ec5f98737513746ec9bdf961183a0032`

R11 freeze owner 会在 canonical Stage、总 Plan 与本 leaf 都完成有界修订后，从
文件外部计算三份 SHA-256 并写入：

`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/evidence/r11-freeze-validation.md`

本 leaf 不写自己的 hash。Review11 与实现者进入时都必须独立复算三份 canonical
hash；任何 drift、冲突、Open Questions 非空或未列明决定都写入本目录
`blocked.md` 并停止，不得在 Review 或实现中自行解释。

本 leaf 直接承载冻结 Stage §6.2.2、§6.3，以及总 Plan §3.2、§10、§11 的 A1b
执行细节；其他 Stage/Plan 条款仍直接适用。若 leaf 与上位冻结原文冲突，上位原文
优先，当前 slice fail closed。

## 1. 进入条件与当前停机点

已成立：

- P0 acceptance 为 `ACCEPTED`；
- A1a independent Review 为 `APPROVED — 0 P0 / 0 P1`；
- A1a independent acceptance 为 `ACCEPTED`；
- branch 满足大规模改动必须在 `codex/` 分支的仓库规则；
- Review10A 报告
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/10a-p1-plan-review.md`
  已对 R10 Candidate 2 给出 `APPROVED — 0 P0 / 0 P1`，因此曾打开 A1b
  implementation；
- R10 implementation 发现的四个合同缺口已在 `blocked.md` §8–§10 收敛为
  `0 P0 / 4 P1`，pre-R11 职责隔离边界复审为
  `APPROVED — 0 P0 / 0 P1`；
- 用户已明确授权 R11，只允许按上述四个根因有界修订 canonical Stage、总 Plan、
  本 leaf、两个执行索引与 freeze/review 控制产物；
- 旧 Review10 报告
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/10-p1-plan-review.md`
  与 Review10A 都保持不可变，只作为历史证据。

尚未成立：

- R11 freeze owner 尚未从外部记录三份 canonical hashes 与零代码漂移证据；
- 未参与 R11 planner 修订的职责隔离 reviewer 尚未在这些精确 hashes 上给出
  `APPROVED — 0 P0 / 0 P1`。

因此当前停在“R11 Candidate Frozen → external freeze evidence → independent
Review11”之间。Review11 通过前：

- 不得修改本文件 §3 的任何产品或测试路径；
- 不得继续已有 R10 implementation；
- 不得运行或伪造 A1b acceptance；
- 不得进入 A2；
- 不得 commit、push、merge、release、重置数据或执行真实用户/外部操作。

Review11 只重新打开 A1b 实施，不等于 implementation Review 或 A1b acceptance。

## 2. 职责、任务产物与 owner

固定 task 目录：

`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a1b-durable-planning/`

职责隔离如下：

- planner：
  - 写并冻结本 `plan.md`；
  - 写 R11 freeze evidence、控制索引与 blocker resolution；
  - 不写实现日志、implementation Review 或 acceptance。
- independent R11 plan reviewer：
  - 未参与 R11 canonical 文档修订；
  - 只写
    `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/11-p1-plan-review.md`；
  - 不修改 canonical 文档、产品、测试、Package、日志或 implementation evidence。
- implementer：
  - 只按本 leaf 修改 §3 allowlist；
  - 写 `verify.log`、`build.log`、`migration-matrix.log`、`preview.log`、
    `impl-report.md`；
  - 写 `evidence/preflight.txt`、`evidence/scope-and-hashes.txt`、
    `evidence/preview-observation.md`、`evidence/final-hashes.txt`；
  - 不写 Review 或 acceptance。
- independent implementation reviewer：
  - 只写 `reviews/01-p1-a1b-review.md`；
  - 不修改产品、测试、日志或 Plan。
- independent acceptance owner：
  - 只写 `acceptance.md`；
  - 只有 implementation Review 零 P0/P1 且所有完成门有原始证据时才可判定。

必需 preview 截图固定为 `evidence/preview-smoke.png`。任何新证据文件必须先属于
上述 owner 和当前 slice，不得把 normal App 数据、credential、account ID 或
OAuth callback 写入证据。

## 3. 精确允许文件

### 3.1 生产文件

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

### 3.2 现有测试文件

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

### 3.3 新测试与 test-only matrix 文件

- 新 `Sources/AgentLoopTestSuite/DurablePlanningTests.swift`
- 新 `Sources/AgentLoopTestSuite/PlanningTestFixtures.swift`
- `Sources/P1MigrationMatrixRunner/main.swift`
- `scripts/verify-p1-migrations-sqlite-matrix.sh`

runner/script 只允许加入 named `v12-durable` predecessor/replay fixture、两条 linked
lane assertions 与新 frozen Stage hash。不得修改 v12 DDL/literal、A1a verdict、
产品 target、`Package.swift` 或 `Package.resolved`。

R10-P1-02 的关闭不新增文件或 target：package-only
`PlanningEntryCoordinator`及 DTO 放入已允许的 `Orchestrator.swift`；功能与
source-order tests放入已允许的 `DurablePlanningTests.swift` 和
`PlanningTestFixtures.swift`。`Package.swift`、`Package.resolved` 与
`Sources/RunTests/main.swift` 必须保持进入指纹逐字不变。

编译器若发现 allowlist 外的真实签名调用点，立即停止并写 `blocked.md`；不得靠
default 参数、compatibility overload、动态 current-default lookup或扩大文件范围
绕过。

## 4. 非目标与跨 slice 红线

A1b 只关闭 R-01 durable planning 根因，不实施：

- A2 Rumination durable integration；
- A3 `convertCandidateAndEnqueuePlanning` 原子 Candidate transaction；
- A4 `schedule_fire` / `schedule_evaluation_cursor` migration与 claim 语义；
- concrete Anthropic/OpenAI/OAuth Provider 内部 retry/refresh/fallback 改造；
- Camp retirement、deletion permit、Engine coordination或其他 P1 slice；
- App termination observer 或真实进程 release 保证。

硬红线：

1. 不新增 migration，不改 v12 schema/literal。
2. 不保留旧 public
   `createMissionShell/recordPlanningTokens/recordPlanFallback/planMission` durable
   planning 绕行。
3. 不保留 `planningTasks`、10ms polling、watchdog成功兜底或 unowned provider
   execution。
4. 不读取 current default 代替 captured runtime profile/model。
5. 不使用 resolver/provider fallback、`try?` credential/catalog/endpoint读取。
6. 不把 provider error转成 fallback Card；success 不写 `plan_fallback`。
7. 不让 identity/token/overflow numeric payload经过
   `JSONValue.number(Double)`、`JSONSerialization` 或第二 canonical parser。
8. 不 saturation、不截断、不记 prefix usage、不用 nil冒充已发生但 overflow 的
   provider usage。
9. 不等待 cancellation-ignoring provider 才开始 emergency halt。
10. 不用 structured TaskGroup race冒充 bounded shutdown。
11. 不因 callback、renew或terminal DB failure丢弃仍 active 的 owned work。
12. 不改变 Candidate link、Schedule claim CAS、slot判断、`lastFiredAt`逻辑值、
    missed或schema语义。唯一 encoding carve-out 是
    `ScheduleRecord.lastFiredAt` 新写入改用 numeric epoch seconds，并继续用
    `.deferredToDate` 同时读取旧 TEXT 与新 INTEGER/REAL；其他 Date encoding不变。
13. 不修改、打印或测试真实 Keychain/UserDefaults；resolver tests只用内存 source。
14. 不 commit、push、merge、release、重置真实数据或执行真实用户操作。
15. 不让 generic DurableWork API 对 `.planning` 保留 mutation/dispatch capability。
16. 不用同构 Core mock或字符串存在性检查冒充真实四入口委托与顺序验证。

## 5. 冻结类型与 API

### 5.1 Planning input 与 immutable start identity

```swift
public struct PlanningWorkInput: Codable, Sendable, Equatable {
    public let plannerModel: String
    public let runtimeProfileId: String
    public let promptContractVersion: Int
}

struct MissionPlanningStartIdentityV1:
    Codable, Sendable, Equatable
{
    let contractVersion: Int
    let goal: String
    let companionIds: [String]
    let workspacePath: String?
    let budgetTokens: Int
    let campId: String
    let autonomy: MissionAutonomy
    let planningInput: PlanningWorkInput
}

struct LegacyPlanningTerminalInputV1:
    Codable, Sendable, Equatable
{
    let contractVersion: Int
    let terminalCode: String
}
```

不变量：

- 两个 contract version 都必须精确为 `1`；构造或 decode其他值 fail fast；
- planner model、profile ID、goal、companion ID与Camp ID执行现有非空验证，不
  trim成另一身份；
- `companionIds` 保持 caller order；
- `workspacePath` custom Codable编码 explicit `null`；
- `budgetTokens` 采用现行 `max(1, callerValue)`，identity 保存实际落库值；
- `campId` 是 transaction解析后的 existing/non-archived non-null Camp；
- trace 不属于 identity；
- identity 只能由 `CanonicalJSONV1.encode` 产生，并直接成为唯一
  `mission_created.payloadJson`；根级 `goal`自然保留；
- `PlanningWorkInput` 只能由 `CanonicalJSONV1` 产生 work `inputJson/inputHash`，
  不增加第四字段。

`LegacyPlanningTerminalInputV1`是唯一carve-out：仅供永不claim、attempt=0即
terminal的legacy recovery work。version精确1；allowed terminalCode精确为：

- `emergency_halt_during_planning`
- `legacy_planning_profile_unresolved`
- `legacy_planning_model_unavailable`
- `legacy_planning_profile_cli_unsupported`

它同样只经`CanonicalJSONV1`编码/hash；不能进入resolver、Planner或normal replay
validator。

### 5.2 Typed usage、同源 failure 与 overflow

```swift
struct PlanningUsageCountersV1: Codable, Sendable, Equatable {
    let cacheReadTokens: Int64
    let inputTokens: Int64
    let outputTokens: Int64
}

struct PlanningAttemptFailure: Error, Sendable, Equatable {
    let failure: DurableWorkFailure
    let usage: Usage?

    init(
        code: String,
        safeMessage: String?,
        disposition: DurableWorkFailureDisposition,
        usage: Usage?
    ) throws
}

enum PlanningUsageOverflowField:
    String, Codable, Sendable, Equatable
{
    case cacheReadTokens
    case inputTokens
    case outputTokens
    case attemptBillableTokens
    case spentTokens
}

enum PlanningUsageOverflowEvidenceV1:
    Codable, Sendable, Equatable
{
    case turnAggregate(
        priorAccumulatedUsage: PlanningUsageCountersV1,
        incomingUsage: PlanningUsageCountersV1,
        overflowFields: [PlanningUsageOverflowField]
    )
    case missionProjection(
        existingSpentTokens: Int64,
        attemptUsage: PlanningUsageCountersV1,
        overflowFields: [PlanningUsageOverflowField]
    )
}

struct UsageOverflowError: Error, Sendable, Equatable {
    let evidence: PlanningUsageOverflowEvidenceV1
}
```

`PlanningAttemptFailure` 不公开 `(usage, failure)` initializer。唯一 initializer
先验证 Usage 三字段 non-negative，再从同一 typed value生成 canonical
`usageJson`和 `DurableWorkFailure`：

- nil：本 attempt零个完成的可计量 provider turn；
- non-nil全零：已完成可计量 turn，三个值均为零；
- 不从 `usageJson` 反解 scalar或重新猜 disposition。

Overflow custom Codable 精确输出两种互斥 object：

- turn：
  `contractVersion,reason,priorAccumulatedUsage,incomingUsage,overflowFields`，
  `reason="turn_aggregate"`；
- Mission：
  `contractVersion,reason,existingSpentTokens,attemptUsage,overflowFields`，
  `reason="mission_projection"`。

`contractVersion=1`。fields必须 non-empty、去重并按 UTF-8 bytes排序：

- turn只允许 `cacheReadTokens|inputTokens|outputTokens`；
- Mission只允许 `attemptBillableTokens|spentTokens`。

Evidence 保存 exact representable operands，不保存不可表示的和；只经 typed
Codable → `CanonicalJSONV1.encode` → direct `EventRecord` insert，kind精确
`planning_usage_overflow`。持久 terminal code精确 `usage_overflow`。

### 5.3 Resolver

```swift
public protocol PlanningProviderResolver: Sendable {
    func resolvePlanningProvider(
        profileId: String,
        model: String
    ) throws -> any LLMProvider
}

struct PlanningProviderResolutionError:
    LocalizedError, Sendable, Equatable
{
    let code: String
    let safeMessage: String
    var errorDescription: String? { safeMessage }
}
```

错误 `code` 必须来自 Stage §6.3 resolver表；safeMessage是按 code 固定的静态文案。
不得将 OSStatus、credential/account、endpoint secret、raw provider error/body写入
持久 message或 UI日志。

### 5.4 AppDatabase / Store commands

唯一 public 新开工 command：

```swift
public func enqueueMissionPlanning(
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

Core internal transaction结果：

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

Internal planning commands：

```swift
func claimNextPlanning(
    workerId: String,
    now: Date,
    leaseDuration: TimeInterval
) throws -> DurableWorkClaim?

func renewPlanningLease(
    claim: DurableWorkClaim,
    now: Date,
    leaseDuration: TimeInterval
) throws -> DurableWorkClaim

func nextClaimablePlanningDate(now: Date) throws -> Date?

func commitPlanningSuccess(
    claim: DurableWorkClaim,
    result: PlanResult,
    now: Date
) throws -> PlanningSuccessCommitResult

func recordPlanningAttemptFailure(
    claim: DurableWorkClaim,
    failure: PlanningAttemptFailure,
    now: Date
) throws -> PlanningFailureCommitResult

func recordPlanningUsageOverflow(
    claim: DurableWorkClaim,
    evidence: PlanningUsageOverflowEvidenceV1,
    now: Date
) throws -> DurableWorkRecord

func cancelPlanning(
    workId: String,
    expectedVersion: Int,
    reason: String,
    now: Date
) throws -> DurableWorkCancelResult

func cancelAllPlanningForEmergencyHalt(
    reason: String,
    now: Date
) throws -> [String]

func adoptInterruptedPlanning(
    currentWorkerId: String,
    now: Date
) throws -> [DurableWorkRecord]

func repairLegacyPlanningMissions(
    profileModels: [String: String],
    now: Date
) throws
```

Bulk result是 sorted unique Mission IDs。`DurableWorkStore` 唯一新增 public seam：

```swift
public func work(id: String) throws -> DurableWorkRecord?
```

Store其他新增 primitive保持 internal；不扩大 generic DurableWork public surface。

新增稳定公开错误：

```swift
public struct PlanningRequiresDurablePlanningCapabilityError:
    Error, Sendable, Equatable
{
    public init() {}
}
```

A1b 必须把 `.planning` 从 generic Store 的 mutation/dispatch capability封死：

| Generic API | `.planning` contract |
|---|---|
| `enqueue` | kind guard保持第一优先级；在time/JSON/hash/pool/SQL/UUID前抛上述错误，insert/replay都拒绝 |
| `claimNext` | 先执行既有now/lease validation；kinds含planning即整次在pool/SQL前拒绝，mixed kinds不筛除 |
| `nextClaimableDate` | 先执行now validation；kinds含planning即整次在pool/read前拒绝 |
| `cancelActive` | kind-first拒绝，早于now/reason/pool/SQL，不能返回`noActiveWork` |
| `adoptInterrupted` | 先执行now validation；kinds含planning即整次在pool/SQL前拒绝 |
| `renewLease` | 先执行now/lease validation；transaction fetch target后、version/CAS/update/event前拒绝 |
| `complete` | 先执行now/output validation；fetch后、CAS/update/attempt/event/closure前拒绝 |
| `retryOrFail` | 先执行now validation；fetch后、attempt/state/backoff/CAS/update/closure前拒绝 |
| `cancel` | 先执行now/reason validation；fetch后、same-reason replay/state/version/update/closure前拒绝，包括terminal planning |

public与同名 Core-internal generic helpers执行同一 ban。`activeWork`、
`latestWork`、`work(id:)` 对 planning仍可读。specialized commands不得调用上述
generic helpers；`DurableWorkStore.swift` 中必须恰有一个
`fileprivate enum PlanningDurableWorkLedgerOwner`，由同文件的 AppDatabase
specialized extension封装 raw ledger transition。AppDatabase是唯一 transaction
边界，Supervisor只调用 specialized commands与 read seams。A1a generic state-machine
tests改用普通 kind；DDL diagnostics和 direct seeded planning read/negative fixtures
可保留。

list API若同时含planning/campDeletion，按caller原顺序遇到的第一个reserved kind抛
对应typed error，完成全部kind validation后才去重；不得用排序改变错误优先级。

### 5.5 Package-only 四入口 coordinator

以下类型精确放在已允许的 `Orchestrator.swift`，全部为 `package` 而非 `public`：

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

Coordinator只拥有捕获、顺序与委托。manual先按既有`max(1,value)`规范化budget，
相同canonical snapshot复用pending，失败保留，
成功以完整completed command compare-and-clear，迟到旧Task不能清新pending。
candidate保持`existingMissionId → startMission → linkConverted`两步；proposal
capture只读block，CAS/attach/revert/heal仍归Orchestrator并在start验证proposal ID。
schedule先在UUID、runtime selection、preparation Result与claim之前执行
non-finite pre-guard；non-finite直接抛
`InvalidSchedulePlanningFireTimeError`且完整零写。只有finite Date才形成
checked-milliseconds/runtime-selection Result，再claim；claim winner的selection/
finite-milliseconds overflow failure或start error恰好持久化一次missed。claim
loser返回`.notClaimed`且不写missed；start成功返回`.started`；missed persistence
成功后返回`.missed`。只有claim数据库错误导致winner未知，或
`recordScheduleMissed`失败时才throws；claim winner后的start error不得逃逸，
caller也不得补写第二条missed。
UI side effects仍在App。

不修改 `Package.swift`、`Package.resolved`、`Sources/RunTests/main.swift`，不新增
target或import AgentLoopApp。现有 `AgentLoopTestSuite` 直接调用上述 package
implementation；App source-order tests使用固定函数签名与能跳过Swift注释/字符串的
balanced-brace scanner，找不到、重复、无法解析或顺序错误均失败。

### 5.6 Orchestrator 与 Supervisor

`Orchestrator.startMission` required signature：

```swift
public func startMission(
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

不得增加 default或 compatibility overload。initializer新增 required
`planningProviderResolver`；旧 `makeProvider`只服务 Card/其他既有路径。

Supervisor public shape：

```swift
public struct ShutdownReport: Sendable, Equatable {
    public let uncooperativeWorkIds: [String]
}

public actor DurableWorkSupervisor {
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

    package func activateAfterOrchestratorRecovery() throws

    #if DEBUG
    package func injectOwnedSuccessProposalForTesting(
        workId: String,
        result: PlanResult
    ) throws
    #endif
}
```

`activateAfterOrchestratorRecovery()` 是唯一允许把 running-mode startup
`.recoveryReady` 转为 `.running` 并打开 local dispatch gate 的 actor-isolated
internal API；它的 exact gate 与线性化顺序见 §9.2–§9.4。`recoverOnStartup`
本身不得在 durable running 时启动 pump/timer、claim、resolver 或 provider。

`injectOwnedSuccessProposalForTesting(workId:result:)` 是唯一 R11 test seam：

- production declaration 与调用它的 `@Test`/helper 都必须位于 matching
  `#if DEBUG`；SwiftPM debug 的 Core/TestSuite/RunTests 使用同一 package identity，
  release Core 不包含该符号；
- 只接受已由 Supervisor owned 的 work ID 与 `PlanResult`，不得接受任意
  `PlanningTerminalProposal`、task token 或 generation；
- entry 不存在或已失去 ownership 时抛既有 typed
  `SupervisorGenerationExpiredError(workId:)`；
- 方法从 owned entry 内部读取 token/generation，复用生产
  provider-completion → pending proposal → `attemptPendingTerminalProposal`
  路径及 generation/token/latest-claim gates；
- 不直接调用 Store、不绕过 transaction、不重呼 provider，也不扩大
  `Package.swift`、target graph 或 release API。

Typed lifecycle errors至少精确区分：

```swift
public struct SupervisorRecoveryRequiredError:
    LocalizedError, Sendable, Equatable
{
    public init()
    public var errorDescription: String? {
        "规划恢复尚未完成，暂不能派发。"
    }
}

public struct SupervisorDispatchSuppressedError:
    LocalizedError, Sendable, Equatable
{
    public init()
    public var errorDescription: String? {
        "牧场当前已停营，规划派发已关闭。"
    }
}

public struct SupervisorAlreadyShutDownError:
    LocalizedError, Sendable, Equatable
{
    public init()
    public var errorDescription: String? {
        "规划监督器已经关闭。"
    }
}

public struct SupervisorGenerationExpiredError:
    LocalizedError, Sendable, Equatable
{
    public let workId: String
    public var errorDescription: String? {
        "规划任务所有权已经失效。"
    }
}

public enum SupervisorFatalCode:
    String, Sendable, Equatable
{
    case generationOverflow = "generation_overflow"
    case storeFailure = "store_failure"
    case invalidLifecycle = "invalid_lifecycle"
}

public struct SupervisorFatalError:
    LocalizedError, Sendable, Equatable
{
    public let code: SupervisorFatalCode
    public let safeMessage: String
    public var errorDescription: String? { safeMessage }
}
```

这些错误不吞 underlying cause；对用户显示只用安全摘要，诊断日志保存 error type、
trace/work ID和生命周期，不保存 provider body或秘密。

## 6. Replay-first enqueue 合同

固定顺序：

1. Orchestrator local dispatch gate。
2. AppDatabase read snapshot要求 exact durable dispatch=`running`，查
   `(kind=planning,idempotencyKey)`。
3. same-key existing执行 persisted identity/work-graph validator。
4. only-if-absent读取 exact profile snapshot并完整 resolver preflight；丢弃该
   短生命周期 provider。
5. 一个 write transaction重验 durable running、concurrent winner、profile
   existence/kind、Camp，然后写完整 projection。
6. commit 后 Supervisor kick。

Replay validator必须在任何 UUID、credential/catalog/endpoint/provider construction
前执行：

- decode并 canonical re-encode唯一 `mission_created` identity；
- 验证 work kind=`planning`、aggregateType=`mission`、aggregate ID、
  `maxAttempts=4`、inputJson/inputHash、Mission→Squad→Camp、ordered roster与
  identity一致；
- current Mission status、budget与autonomy是可变 projection，不能替代或否定首写
  identity；
- incoming explicit Camp必须等于 persisted Camp；incoming nil采用 persisted
  identity Camp，不解析 current default；
- exact相同返回原 `(missionId,workId)`，零写、零 provider construction、保留首次
  work trace，即使 profile/credential/catalog已删除；
- 任一 identity/graph/hash差异优先抛 `DurableWorkReplayConflictError`；
- durable halted/missing/corrupt仍 fail closed，replay不能越过 dispatch gate。

Absent-key preflight顺序：

`profile → CLI reject → catalog → exact model membership → primary account →
primary credential → OAuth secondary credential → endpoint → provider construction`

Write transaction：

- 第一条业务动作前再次读取 durable running；
- 先查并发 winner；存在时复用同一 validator，same返回 winner，conflict回滚；
- 重读 exact profile ID，kind必须等于preflight snapshot；missing/CLI/kind drift
  零业务写；
- 显式 Camp必须存在且未 archived；nil按现有稳定 default-Camp规则在transaction内
  解析/必要时创建；
- 构造 resolved identity与planning input canonical bytes；
- 所有验证完成后才生成 Camp（若需要）、Squad、Mission、work UUID；
- 原子写 default Camp/Guide（若需要）、Squad、Mission、唯一
  `mission_created`、唯一 `plan_started`与 planning work；
- work固定 `maxAttempts=4`、首次 trace、canonical input/hash；
- 任一 insert/event/hash/failure injection整体 rollback。

## 7. Provider resolver 与 Planner

### 7.1 Resolver authority

App concrete resolver严格实现：

- official Anthropic/OpenAI：
  raw `cachedCatalog + manualModels`，两者都空为 `model_catalog_unavailable`；
- custom Anthropic/OpenAI：
  raw profile-scoped `modelChoices + manualModels`，不使用 global/built-in fallback；
- ChatGPT OAuth：
  只用 `KernelDefaults.chatGPTStaticModels`，要求 primary access token与固定
  `oauth-chatgpt-account-id` secondary credential，忽略 API catalogs；
- CLI：
  固定 `planning_profile_cli_unsupported`，不读目录、不构造 provider。

official/custom唯一用 `ModelCatalogService.isOfficialCatalogProfile`。所有模型先按
现有规则 trim/de-duplicate，再 exact string match。Keychain使用
fail-if-interaction-required；`errSecItemNotFound` 与其他 OSStatus分别映射
not-found/read-failed。endpoint必须经 `ProviderEndpoint.normalizedBaseURL`。
不得调用 AppStore 现有带 default/fallback/side-effect的 provider helper。

Preflight和claim execution都调用同一 resolver实例；claim时profile/model来自 work，
不回读 default。失效 profile/catalog/credential/endpoint映射 deterministic
planning failure并由 durable transaction收口。

### 7.2 Planner durable attempt

`Planner.proposeDurable` 替代 durable path中的 `propose`：

- 一次 attempt最多一个 initial `streamTurn`；
- 只有 tool/schema contract invalid才允许一个 correction `streamTurn`；
- 第二轮仍无效：
  `planning_contract_invalid/deterministic`；
- Planner自身无 retry loop、sleep或fallback；concrete provider单次
  `streamTurn`内部已有 transport retry/OAuth refresh/stream fallback保持；
- `CancellationError`原样抛出，由 cancel/halt owner收口；
- error mapping逐字使用 Stage §6.3：
  - `URLError` → `planning_transport_error/transient`
  - HTTP 429/5xx、`overloadedRetriesExhausted`、API type
    `overloaded_error|rate_limit_error|server_error` →
    `planning_provider_unavailable/transient`
  - malformed stream → `planning_provider_malformed_response/transient`
  - unauthorized → `planning_provider_unauthorized/deterministic`
  - 其他 HTTP → `planning_provider_http_error/deterministic`
  - 其他 API → `planning_provider_api_error/deterministic`
  - unknown → `planning_provider_failed/deterministic`
- safeMessage按 code静态映射，不保存 raw Error/body。

Usage累加先对三字段分别 `addingReportingOverflow` 到三个临时变量，全部成功才替换
accumulator。任一字段 overflow立即抛携 exact prior/incoming operands的
`UsageOverflowError`，不部分累计、不再调用 provider。第二轮 provider失败时，
`PlanningAttemptFailure`仍携第一轮 exact usage。

每个turn在进入accumulator前先验证三字段non-negative：

- 首轮negative：
  `planning_usage_invalid/deterministic`，`usage=nil`，不写token event；
- correction negative：
  同一code/disposition，但`usage`为此前valid accumulated Usage；
- 不保存negative counter、不夹紧为零、不再调用provider。

Worker claim后从持久 Mission/Squad读取 goal、ordered roster、workspace与Camp；
profile/model只从 `PlanningWorkInput`。不得使用 captured in-memory command payload
作为执行真相。

## 8. Planning transaction 合同

### 8.1 Shared gates

每个 planning claim、next-due read、renew、success、failure、overflow transaction
都要求：

- exact `kernel_control.global`存在且可 decode；
- durable dispatch mode=`running`；
- latest claim attempt/worker/version/lease有效；
- work kind、aggregateType、Mission/Squad关系有效。

missing/corrupt/halted全部零 provider-path写入。显式 single cancel与halt bulk cancel
是唯一可在 halted 下写 terminal projection的 planning control mutation。
Legacy repair/adoption是§9.3专列的 suppressed recovery-only写：它们不属于
provider path，且若restored mode为halted，必须在pump启动前被同一个bulk cleanup
全部收口。

上述 shared gate不能只靠调用约定：九个 generic Store mutation/dispatch API对
`.planning` 必须按§5.4 fail closed。provider、recovery、single/bulk cancel只调用
AppDatabase specialized owner；Store只读 seam不能接受 business closure或返回
mutation capability。

### 8.2 Success

`commitPlanningSuccess`在任何 mutation前：

- 验证 proposal与 roster；
- 验证 Mission仍为 planning且没有 Cards；
- 要求 `fallbackReason == nil`。nil不写 event；non-nil抛
  `UnexpectedPlanningFallbackError`且整 command零写。Supervisor保留同一个 owned
  entry、latest claim与 result，把同一个 result Usage放入 code 精确为
  `unexpected_planning_fallback` 的 deterministic `PlanningAttemptFailure`，再通过
  同一个 pending proposal / `attemptPendingTerminalProposal` failure owner收口；
  不能丢usage、写 fallback event或再次调用provider。

生产 `Planner.proposeDurable` 的 success result固定 `fallbackReason=nil`。唯一可构造
non-nil Supervisor-owned success proposal的路径，是 §5.6 matching-`#if DEBUG`
`injectOwnedSuccessProposalForTesting(workId:result:)`；该 seam只进入上述生产
provider-completion与failure owner，不是第二个 terminal owner。

同一 transaction：

1. 把 `Usage` checked转成 non-negative Int64 counters；
2. checked计算 `inputTokens + outputTokens`；
3. checked计算 existing `spentTokens + attemptBillableTokens`；
4. overflow时不抛出事务后再处理，而在当前 transaction改走 §8.4 terminal branch
   并返回 `.usageOverflow`；
5. normal path直接插入恰好一条 typed canonical `planning_tokens`，即使三个值全零；
6. 按 proposal创建全部 Cards与 dependency IDs；
7. 更新 goalRefined、spentTokens与 Mission rollup；
8. 写恰好一条 `plan_completed`；
9. 关闭 attempt/event/work并返回 `.succeeded`。

usage guard、每张 Card、rollup、event、attempt close、work close任一点注入失败必须
全部 rollback。normal usage超过budget但没有整数overflow仍 exact入账并建卡；
既有预算门随后阻止 Card dispatch。

### 8.3 Failure

`recordPlanningAttemptFailure`只接同源 typed failure：

- nil usage不写 `planning_tokens`；
- nonnil zero写 exact zero token event；
- nonnil positive写 exact typed token event并checked更新 spent；
- projection overflow在同一 transaction走 §8.4并返回 `.usageOverflow`；
- transient且attempt未耗尽：
  token/accounting + attempt/event close + 5/30/120秒 retryScheduled同一transaction，
  Mission保持 planning；
- deterministic或attempt耗尽：
  token/accounting + attempt/event/work terminal + Mission failed +
  `mission_failed`同一transaction。

不得从 error code或usageJson重新猜 disposition/Usage。

### 8.4 Overflow

两个入口：

- Planner turn aggregate overflow；
- success/failure对 Mission projection的
  `attemptBillableTokens|spentTokens` overflow。

专用 terminal branch/command在一个 transaction：

- 验证 shared gates与 Mission planning；
- direct insert exact canonical `planning_usage_overflow` evidence；
- 以 `usage_overflow`关闭 attempt/work；
- Mission置 failed并写终态 events；
- 不写 `planning_tokens`；
- 不改原有 `spentTokens`；
- 不 retry、不建 Card、不写 fallback、不返回 success。

任一 failure injection使 evidence、attempt/work/Mission/event全部 rollback。相同
claim重试由 CAS拒绝，不能重复 terminal。

### 8.5 Cancel / halt / legacy repair

Single cancel：

- work/attempt/event与 Mission failed/event同一transaction；
- reason结构先验证；
- same reason replay零新写；stale expectedVersion fail；
- durable commit后才取消匹配的 local provider Task。

Emergency bulk：

- active planning按 work ID、Mission ID稳定排序；
- 一个整体 SQLite transaction全部执行
  `emergency_halt_during_planning`等价 projection；
- 任一点失败全部 rollback；
- 返回 sorted unique Mission IDs。

Interrupted adoption：

- 只调用 `adoptInterruptedPlanning(currentWorkerId:now:)`；
- 在 process-local suppressed 且 pump/timer尚未建立时运行；
- 不要求 durable running，不调用 generic `adoptInterrupted`；
- 原子关闭旧 attempt为 interrupted并把 work排回 queued；
- restored halted时随后同一个 emergency bulk transaction必须覆盖刚 adopted 的
  active planning。

Legacy repair：

- `DurableWorkStore.swift` 定义唯一 package typed error：

  ```swift
  package struct LegacyPlanningHasCardsError:
      Error, Sendable, Equatable
  {
      package let code = "legacy_planning_has_cards"
      package init() {}
  }
  ```

  它没有 missionId 或其他 payload，不扩大 public API；
- Mission ID排序、每个 Mission单独 transaction；
- 只处理 `.planning`且没有任何 planning work的 Mission；
- transaction第一步读取exact durable mode；missing/corrupt fail closed；
- halted：
  - 不解析profile/model；
  - 用`LegacyPlanningTerminalInputV1(
    terminalCode:"emergency_halt_during_planning")`和
    `legacy-planning:<missionId>:v1`创建queued attempt=0 work；
  - 同一transaction立即复用queued cancel primitive，得到canceled work +
    failed Mission + 恰好一条`mission_failed`，零attempt rows/events；
    work errorCode=`work_canceled`、errorMessage为halt reason；
  - 这是halt control owner的一部分，不是第三种halted terminal语义；
- running：
  - 有 Card固定抛 `LegacyPlanningHasCardsError`，调用方可直接观察 exact
    `code == "legacy_planning_has_cards"`；该 Mission transaction零写，
    Mission/Card/planning-work/event完整前后快照逐字不变，不得退化为无 payload
    `InvalidDurableWorkStateError`；
  - 全部 Squad成员 non-null profile且unique set恰为一时用该profile；
  - 否则仅数据库恰好一个default profile时使用；
  - planner model只从启动注入的`profileModels[profileId]`；
  - profile不存在/不唯一、CLI、model missing分别使用三种exact
    `legacy_planning_*` code与terminal input，创建attempt=0 terminal failed
    work、Mission failed、恰好一条同code的`mission_failed`、零attempt
    rows/events；work errorCode为同code、errorMessage=nil；
  - 可解析时同key创建queued work；
- legacy work固定`maxAttempts=4`，trace固定
  `legacy-planning:<missionId>:trace:v1`；
- replay验证input/aggregate/Camp/maxAttempts/trace/terminal reason并不重复写；
- mode read是该Mission的线性化点；running下已提交legacy terminal先于后来halt，
  不得被改写。

## 9. Supervisor 并发、恢复、halt 与 shutdown

### 9.1 Ownership 与依赖

`DurableWorkSupervisor` initializer持有：

- `AppDatabase`
- `DurableWorkStore`
- 同一个 `PlanningProviderResolver`
- stable `workerId`
- `@Sendable () -> Date`
- cancellation-aware `@Sendable (Duration) async throws -> Void`
- 只用于发出 Mission changed的 completion callback

Internal initializer固定为：

```swift
init(
    database: AppDatabase,
    planningProviderResolver: any PlanningProviderResolver,
    workerId: String,
    now: @escaping @Sendable () -> Date,
    sleep: @escaping @Sendable (Duration) async throws -> Void,
    onMissionChanged: @escaping @Sendable (String) -> Void
)
```

它从同一个`database`构造`DurableWorkStore`；不接受第二个database/connection。
`workerId`由Orchestrator lazy初始化时生成一次并保持到本进程结束，不在每次claim
重生成。

production `now/sleep`使用 system clock与 `Task.sleep`；tests注入可控 actor，不用
real sleeps。Orchestrator以 actor-isolated lazy property创建Supervisor，closure只
把 `.missionChanged`送回Orchestrator event stream；不伪造成功事件、不写DB、
不直接写App projection。既有 reconcile/tick仍是Card dispatch owner。

每个 owned entry至少含：

- unique task token
- captured generation
- Mission ID
- latest claim
- provider Task
-唯一 renewal Task
- terminal-commit permission
- optional pending terminal proposal

### 9.2 Lifecycle 与 pump

Lifecycle：

durable-running startup 的完整路径精确为：

`initialized -> recovering -> recoveryReady -> running -> shuttingDown -> shutDown`

`.recoveryReady` 只存在于当前进程内，不落库、不产生新的 durable mode。restored
halted cleanup成功仍可从 `recovering` 直接进入 `running + suppressed` quiescent；
任一 recovery failure回到 `initialized + suppressed`。

另有 `dispatchSuppressed`：

- init为true；
- recovery失败回initialized，仍suppressed；
- recovery读取 durable running后进入`.recoveryReady`，仍suppressed；
- `.recoveryReady`不能创建pump/timer、claim、resolve或调用provider；
- `startIfNeeded`只在running且unsuppressed幂等；
- initialized/recovering调用dispatch API固定抛
  `SupervisorRecoveryRequiredError`；recoveryReady或其他suppressed状态固定抛
  `SupervisorDispatchSuppressedError`，不得打开gate；
- suppressed调用抛`SupervisorDispatchSuppressedError`；
- shutdown后start/recover/kick抛`SupervisorAlreadyShutDownError`。

唯一可打开 dispatch gate 的 `.recoveryReady -> running` owner 是
`activateAfterOrchestratorRecovery()`；§9.4 的 emergency control-only conversion
是唯一不打开 gate/pump 的例外。同一个actor turn内、任何状态 mutation前，
activation必须原子验证：

1. lifecycle仍为`.recoveryReady`；
2. `dispatchSuppressed == true`；
3. fatal为空且halt cleanup不pending；
4. 内部重读exact durable mode仍为running。

全部成立后才切lifecycle为running、unsuppress、建立唯一pump/必要的next-due timer并
kick恰好一次。若 lifecycle仍为`.recoveryReady`且 startup eligibility/transition
token仍有效，mode-read或其他内部gate失败保持`.recoveryReady + suppressed`、零
pump/timer/claim/provider，错误可观察且允许显式重试；若 lifecycle、generation、
eligibility或token已被control改变，stale activation必须保留control-owned state并
失败，不得还原`.recoveryReady`或再走startup carve-out。不得先开gate再回滚。
当前 reactive `suppressForOrchestratorRecoveryFailure()` 不属于最终 API或合同，
production source与call site必须删除。

Pump：

- 同时最多一个；
- 每次claim一条直到无claimable；
- 一个work一个provider Task；
- next-due只有一个timer，kick/更早due取消并替换；
- kick先按work ID排序重试owned entries的pending terminal proposals，再claim新
  work；每次成功lease renew后只重试该entry的同一proposal一次；
- 禁止固定interval polling；
- lease 60秒、每15秒renew；
- renew成功替换latest claim；stale renew只取消matching token；
- fatal Store/lifecycle错误进入observable fatal latch，停止新dispatch且唤醒waiters；
- terminal transaction失败保留ownership/pending proposal并继续renew，等待明确
  kick/recovery重试。

Error ownership matrix：

| 操作/错误 | owner 与后果 |
|---|---|
| stale claim/version；generation/token loser | expected control race；cancel/remove matching owned task，零global fatal |
| durable halted | 保持suppressed，等待halt bulk owner；零terminal proposal写 |
| success/failure/overflow transaction的可回滚数据库错误 | 保留ownership与typed pending proposal；不重呼provider；只在后续renew成功或显式kick后重试 |
| terminal validation/invariant corruption | `SupervisorFatalError(.invalidLifecycle)`；保留ledger，cancel providers，waiters抛错 |
| missing/corrupt kernel control | fatal fail-closed；零新dispatch |
| claim/next-due的非stale Store错误 | `SupervisorFatalError(.storeFailure)`；停pump/timer，保留ledger |
| renew的stale claim | expected ownership loss；只取消matching task |
| renew的其他错误，包括pending proposal期间 | fatal；保留ledger，不谎报idle/terminal |
| checked generation overflow | `SupervisorFatalError(.generationOverflow)`；不wrap |

Fatal latch不清空owned entries或durable rows；shutdown仍可报告未退出Task，下一进程
通过ledger adoption恢复。

Provider callback必须回到actor，在无await的邻接store write前重验：

- lifecycle running
- unsuppressed
- captured generation
- task token仍匹配
- terminal permission仍存在
- latest claim仍属于entry

随后DB transaction再次检查durable running。任何loser零写。

### 9.3 Startup

Orchestrator在持有StateDirectoryLock且完成runtime profile bootstrap/reconcile后生成
profile-model snapshot，再调用Supervisor recovery：

1. legacy repair；
2. adoptInterrupted planning；
3. 读取exact durable dispatch mode。

Mode：

- running：
  Supervisor只进入`.recoveryReady + suppressed`，不建pump/timer、不claim、不
  resolver/provider；
- halted：
  保持suppressed，运行一个整体bulk cleanup；成功后lifecycle=running但quiescent，
  不建pump/timer、不claim、不resolver/provider；
- missing/corrupt：
  fail closed，保持suppressed；
- cleanup failure：
  整体rollback，保持suppressed，留下可观察可重试错误。

repair/adoption在mode read前是明确允许的recovery-only control mutation：

- 它们只能在suppressed状态运行；
- 不建pump/timer、不claim、不resolver/provider；
- mode-aware repair先用halt cancel语义收口workless legacy Mission；halted bulk
  cleanup覆盖其他刚创建的repair work与刚adopt回queued的work；
- cleanup成功后active planning count必须为零；cleanup失败则该bulk transaction
  整体回滚，只有先前repair/adopt已提交的recovery事实留待下一次完整cleanup收口，
  全程绝不dispatch。

durable-running的第二阶段固定为：

1. Orchestrator在持有 startup transition token 时执行既有 Card orphan adoption；
2. 完成 proposal healing；
3. 重验 transition token 与 exact durable mode仍为running；
4. 调用 `activateAfterOrchestratorRecovery()`；该方法内部的durable-mode read是最终
   DB fence；
5. 返回后再次重验同一个 transition token，才可标记 planning recovery complete、
   把 Orchestrator local phase置running并进入reconcile。

Card adoption或proposal healing失败时，durable mode保持running，Supervisor保持
`.recoveryReady + suppressed`且从未激活；该 failure handling不新增planning
terminal write、halt bulk cleanup或`camp_halted/camp_resumed`。此前合法提交的
legacy repair/interrupted adoption事实不回滚、不重复。Orchestrator只留下可观察的
process-local startup recovery failure，不能伪造durable transition。

Retry严格分流：

- durable-running但Supervisor第一阶段失败并回到`.initialized`时，显式`resume()`
  只有在process-local first-phase retry eligibility为true、无control/halt cleanup
  pending且本次retry attempt transition token有效时，才从suppressed重跑完整
  `recoverOnStartup`；legacy repair/interrupted adoption按既有幂等合同执行，成功
  进入`.recoveryReady`后再继续Card recovery；
- durable-running且Supervisor已完成第一阶段、仍处于`.recoveryReady`时，显式
  `resume()`只有在Card-retry eligibility为true、无control/halt cleanup pending且
  本次retry attempt transition token有效时，才只重试未完成的Card adoption、
  proposal healing与activation；不得重跑legacy repair/interrupted planning
  adoption；
- durable-halted startup/cleanup failure或任一control已清除eligibility/token时，
  继续走既有control/recovery路径，不能套用running carve-out，也不能先把durable
  mode切running。

restored halt成功路径之后才执行不产生dispatch的既有Card恢复；它不产生任何planning
provider dispatch。

### 9.4 Emergency halt / resume

`suppressForEmergencyStop`只可从`.recoveryReady`或`.running`进入；从
`.initialized|.recovering`调用固定抛`SupervisorRecoveryRequiredError`且零状态
mutation，不算control winner。合法进入时在Supervisor首个actor turn、任何
内部await前：

- suppressed=true；
- 若原 lifecycle为`.recoveryReady`，把它消费为`.running`并设置
  `haltCleanupPending=true`；这是control-only conversion，不得打开gate/pump；
- checked generation++；
- 停pump/next-due/renewal；
- 撤销所有terminal permission；
- cancel local provider Tasks。

activation与emergencyStop/shutdown以Supervisor actor顺序为线性化点：

- emergency control先取得顺序时，上述`.recoveryReady -> .running +
  suppressed + haltCleanupPending` conversion使后到activation因lifecycle gate
  失败，并原样复用既有
  `didCommitEmergencyPlanningCleanup`/halted resume路径；
- shutdown先取得顺序时从当前非终态lifecycle直接进入`.shuttingDown`；
- 任一control winner同时使running-startup first-phase retry eligibility、
  Card-retry eligibility与当前attempt transition token全部失效，即使durable halt
  持久化失败也不得误走任一durable-running startup retry；
- activation先取得顺序时，后到control继续按既有running suppression、durable
  transition与bulk cleanup收口；
- Orchestrator在activation await前后都重验transition token，stale startup不得覆盖
  control phase。

Orchestrator随后：

1. 持久化durable halted；
2. 一个transaction bulk cancel全部active planning；
3. 再继续既有Card/进程halt流程，不等待不合作provider。

Durable halt或cleanup失败都保持本进程suppressed、错误可见、resume blocked。

Resume：

常规halt resume：

1. durable mode仍为halted；
2. 重试并完成planning bulk cleanup；
3. 原子切durable running；
4. `resumeAfterDurableRunning`只打开local gate并kick一次。

§9.3 的两个durable-running startup retry分支是常规halt resume的唯一例外：
`.initialized + first-phase retry eligibility`重跑完整Supervisor recovery，
`.recoveryReady + Card-retry eligibility`只重试Card/healing/activation；二者都
必须满足exact durable mode为running、无control/halt cleanup pending且本次retry
attempt transition token有效。只有第二项是R11新增Card-recovery carve-out。两个
分支都不写durable transition、不运行bulk cleanup、不写camp halt/resume event。
eligible activation failure保持suppressed并传播可观察错误；control loser保留
control-owned state。不得用临时durable halt、bulk cancel、伪造camp event或
post-failure reactive re-suppress代替。

Generation + token + durable gate覆盖
halt-vs-enqueue/preflight/claim/renew/response/terminal。halt bulk cancel是唯一终态
owner。

### 9.5 Wait 与 shutdown

- `waitUntilTerminal(workId:)`读取持久work；durable terminal立即唤醒，即使一个
  cancellation-ignoring provider Task尚未退出；
- `waitUntilIdle()`等待owned Tasks为空且当前queued/due work为零；future
  retryScheduled不阻塞；
- waiters通过actor continuations与状态变化唤醒，不轮询；
- shutdown可从`.initialized|.recovering|.recoveryReady|.running`进入；首个turn
  进入shuttingDown、清除全部startup retry eligibility/token、suppressed=true、
  checked generation++、
  撤permission、停pump/timer/renewal、cancel providers；
- shutdown不修改ledger；
- bounded wait用actor-owned continuations + 独立deadline Task；不得用structured
  TaskGroup race；
- deadline后不await provider，返回sorted unique
  `uncooperativeWorkIds`并进入shutDown；
- late callback因lifecycle/generation/token gate零写。

## 10. Orchestrator 与四入口接线

四入口全部使用 §5.5 的同一个 `PlanningEntryCoordinator`。AppStore在Orchestrator
构造后只创建一次，保存required property并作为required initializer参数传给
MissionScheduler；adapter extension使用AppStore同一property。App target不得复制
key/pending/schedule ordering helper；TestSuite测试的就是生产调用的 package实现。

### 10.1 Orchestrator

- initializer required注入同一个 resolver；Core不得重建；
- 删除`planningTasks`、`finishPlanning`与旧裸Task/catch kernel_error路径；
- `startMission`先local dispatch gate，再调用 replay-first enqueue，commit后kick，
  返回Mission ID；
- `recoverAndReconcile`先让Supervisor完成§9.3第一阶段并停在
  `.recoveryReady + suppressed`，再完成Card orphan adoption与proposal healing；
  activation前后都重验同一transition token，并在调用前重读durable mode；
  `activateAfterOrchestratorRecovery()`内部再执行最终durable-mode DB fence，成功后
  才标记recovery complete与reconcile；
- 任一Card/healing/activation failure都保持local dispatch closed并留下可观察错误；
  不调用或保留`suppressForOrchestratorRecoveryFailure`一类 reactive re-suppress
  hook，不伪造durable halt/resume；
- `emergencyStop`使用§9.4顺序，可与`.recoveryReady` activation按Supervisor actor
  顺序线性化，不release planning；
- `resume`对正常durable halted先cleanup再切running；durable-running startup
  failure只按§9.3两个互斥predicate处理：`.initialized + first-phase retry
  eligibility`重跑完整Supervisor recovery，`.recoveryReady + Card-retry
  eligibility`只重试Card/healing/activation；二者都要求当前retry attempt
  transition token有效；
- `waitUntilIdle`合并Supervisor idle；
- `shutdown` await bounded Supervisor report，不宣称App termination release。

### 10.2 Manual

AppStore在创建Task前同一MainActor turn调用`prepareManual`并捕获：

- exact active runtime profile ID
- exact planner model
- budget/autonomy/camp/goal/roster/workspace snapshot
- command UUID与trace UUID

Key精确：

`mission-start:user:<UUID>:v1`

AppStore持有 §5.5 package `PendingManualMissionStart?`。Task只接收 captured
command，并调用`startManual`；不得在Task内回读profile/model/budget/autonomy。
同一snapshot在preflight失败、或enqueue已提交但kick/return失败后重试，复用
key/trace。收到Mission ID并完成当前start call后调用
`clearManualAfterSuccess(current:completed:)`；只有完整command匹配才清除。上述任一
field改变，或用户明确开始新的command，使用`forceNewCommand=true`生成新key/trace。
进程重启不恢复该临时对象；已提交work由ledger recovery接管。CLI或selection失败在
任何Mission写前显示typed safe error。

### 10.3 Coding Ranch Candidate

第一次await前调用`captureCandidate`捕获profile/model/trace，key精确：

`mission-start:candidate:<draftId>:v1`

knowledge/goal组装完成后只调用`startCandidate(captured,mission:)`。Coordinator
保留existing→start→link两步；link失败后的重试用same key找回原Mission再link，
不创建第二Mission。Adapter不得直接调用`orchestrator.startMission`或
`MissionDraftFactory.linkConverted`。不得实现A3 transaction或改变candidate状态机。

### 10.4 Schedule

Key：

`mission-start:schedule:<scheduleId>:<checked-UTC-milliseconds>:v1`

`PlanningEntryCoordinator.fireSchedule`是唯一 checked/claim/start owner：

- 第一条指令先检查
  `scheduledFireDate.timeIntervalSince1970.isFinite`。该 pre-guard位于生成UUID、
  调用`selectRuntime`、构造preparation `Result`与调用`claimScheduleFire`之前；
  non-finite直接抛现有package
  `InvalidSchedulePlanningFireTimeError`，runtime selection调用数为零，且
  Mission/work/event/`lastFiredAt`全部零写；
- 只有通过pre-guard的finite Date才计算
  `timeIntervalSince1970 * 1000`并要求结果finite且在Int64范围；
- `.rounded(.towardZero)`后checked conversion；
- finite timestamp的checked conversion与throwing profile/model selection在existing
  claim前捕获成同一个`Result`；
- 无论Result success/failure，仍先执行既有`claimScheduleFire`；
- finite但checked milliseconds超`Int64`属于Result failure，仍
  `claim → missed`，不得改成pre-claim throw；
- claim成功后Result failure或start failure都由coordinator写既有missed一次并返回
  `.missed`；claim loser返回`.notClaimed`，start成功返回`.started`；
- 只有claim数据库错误导致winner未知或missed persistence失败才throws，caller不
  补写missed；
- A1b不建`schedule_fire`、不改claim CAS、`lastFiredAt`或missed语义。

`ScheduleRecord`的唯一 persistence carve-out固定为：

```swift
public static func databaseDateEncodingStrategy(
    for column: String
) -> DatabaseDateEncodingStrategy {
    column == "lastFiredAt" ? .timeIntervalSince1970 : .deferredToDate
}

public static func databaseDateDecodingStrategy(
    for column: String
) -> DatabaseDateDecodingStrategy {
    .deferredToDate
}
```

因此新`lastFiredAt`写 numeric epoch seconds；其他 Date仍是
`.deferredToDate`。decoder必须继续`.deferredToDate`，同时读取既有
`yyyy-MM-dd HH:mm:ss.SSS` TEXT与新numeric值；禁止改成
`.timeIntervalSince1970` decoder。`DATETIME` NUMERIC affinity可把无小数Double
保存为INTEGER，因此合法storage class是INTEGER或REAL，必须拒绝TEXT/空串，测试
不得固定`typeof=REAL`。`ScheduleStore`只拥有该编码与既有claim，不处理non-finite
missed，不复制Coordinator checked/claim owner，也不改schema、slot判断或CAS。

MissionScheduler不得再直接调用`db.claimScheduleFire`或
`orchestrator.startMission`；它只消费
`notClaimed|started(missionId:)|missed(reason:)`结果并执行既有 UI/broadcast
side effects。

### 10.5 Confirmed proposal

Key：

`mission-start:proposal:<proposalId>:v1`

AppStore在Task前调用`captureConfirmedProposal`只读捕获proposal
ID/profile/model/trace；Task只调用`startConfirmedProposal`。Coordinator委托
Orchestrator的CAS/attach/revert/heal owner，并验证实际block proposal ID等于
captured proposal ID。AppStore不得直接调用`orchestrator.confirmSquadProposal`。
A1b不改变既有proposal CAS/attach/revert/heal状态机，不承诺在本slice修复其独立
补偿错误；不得在Core读取default。

## 11. 实施顺序与每步 gate

只有职责隔离 Review11 在R11 Candidate Stage/总 Plan/leaf精确hashes上给出
`APPROVED — 0 P0 / 0 P1`，implementer才可从当前R10 implementation状态继续，并
严格按下列顺序关闭全部既有欠账与R11合同；Review10A只是历史predecessor，不能替代
Review11。

### Step 1 — 进入快照与 failure-first tests

- 保存branch/HEAD/worktree、三份frozen hashes、allowlist fingerprints；
- 保存Review11 verdict/hash与R11 freeze evidence，确认Package/RunTests进入指纹
  未漂移；
- 保留既有failure-first与完整suite原始日志，不覆盖R10红测证据；
- 证明现有R-01：
  - shell/tokens/cards是分步事务；
  - provider failure遗留planning；
  - old usage addition可trap/失真；
  - halted/late provider缺durable terminal gate；
- 先添加replay、overflow、halt、shutdown红测；
- 先让R11四个 blocker的五类 regression因精确根因失败：Schedule extreme finite
  persistence + non-finite pre-guard、running startup early activation、legacy
  cards typed error与 unexpected fallback owner；
- 红测必须因目标根因失败，不得因fixture编译错误冒充。

Gate：`evidence/preflight.txt`包含失败名、失败原因与未改production hashes。

### Step 2 — Types、canonical evidence与 EventKind

修改：

- `DurableWork.swift`
- `LLMProvider.swift`
- `EventKind.swift`
- test fixtures

实施§5.1–§5.2、checked Usage conversion与
`planning_usage_overflow`。先跑type/canonical/`>2^53`/negative/shape tests。

Rollback seam：invalid contractVersion、negative usage、unsorted fields、wrong shape
都在SQL前失败。

### Step 3 — Store/AppDatabase replay与transaction primitives

修改：

- `DurableWorkStore.swift`
- `AppDatabase.swift`
- `ScheduleStore.swift`
- database/durable planning tests

顺序：

1. `ScheduleRecord.lastFiredAt` numeric encoder、deferred decoder与旧TEXT/new numeric
   compatibility tests；不得改schema或claim CAS；
2. 新 error与九个 generic `.planning` ban；把 A1a generic fixtures迁到普通 kind；
3. `work(id:)`与唯一 fileprivate planning ledger owner；
4. durable-gated planning claim/renew/next-due；
5. specialized interrupted adoption；
6. replay validator；
7. enqueue transaction；
8. success/failure/overflow transactions；
9. single cancel/bulk halt；
10. legacy repair，并把running legacy-with-Cards分支改为exact
    `LegacyPlanningHasCardsError`与完整零写快照。

先跑全部 generic ban/read seam/specialized owner tests，再做每个 transaction逐点
failure injection；不得等到UI集成后再测rollback。

### Step 4 — Resolver

新建`PlanningProviderResolver.swift`并增加in-memory sources/factory fixtures。
逐行跑profile/catalog/credential/OAuth/endpoint/factory tests；不得读取真实
Keychain/UserDefaults。

### Step 5 — Planner durable attempt

修改`Planner.swift`，删除durable path的Planner retry/fallback，保留concrete
provider内部边界。跑initial/correction/error mapping/first-turn usage/overflow测试。

### Step 6 — Supervisor

完成并修订`DurableWorkSupervisor.swift`：先实现含process-local
`.recoveryReady`的state machine/gates与唯一
`activateAfterOrchestratorRecovery()`，再pump/lease，再wait/shutdown；禁止先写
happy path后用局部guard补race。删除现有reactive
`suppressForOrchestratorRecoveryFailure()`最终路径。

跑可控clock与race tests：next due、latest claim、terminal failure ownership、
halt-after-response、running two-phase startup、restored halt、running/halted retry
分流、resume、uncooperative shutdown。matching-`#if DEBUG`
`injectOwnedSuccessProposalForTesting`只能从owned entry进入生产
provider-completion/failure owner；同时验证release Core无该符号。

### Step 7 — Orchestrator

修改`Orchestrator.swift`：

- required resolver与lazy Supervisor；
- start/two-phase recover/activation/halt/running-vs-halted resume/wait/shutdown；
- §5.5 package-only coordinator与immutable DTO；
- Schedule non-finite pre-guard必须先于UUID、selection、Result与claim；finite
  milliseconds overflow继续claim→missed；
- 删除`planningTasks`与旧split write路径；
- 删除post-failure reactive re-suppress hook；
- completion只emit。

跑Orchestrator、CrashRecovery、HaltAndCooldown、Budget、GoldenPath，以及直接调用
coordinator的manual/candidate/proposal/schedule功能测试。

### Step 8 — App四入口与compile call sites

修改：

- `AppStore.swift`
- `CodingRanchStoreAdapter.swift`
- `MissionScheduler.swift`
- allowlist中的全部受影响tests

先迁移required profile/key/trace，再让三个 App文件全部委托coordinator；运行
manual/candidate/schedule/proposal功能测试与五个真实 source-range/order tests。
App direct start/confirm/schedule-claim sentinel必须零命中，Package/RunTests hashes
必须不变。A1b不得借编译错误扩大到A3/A4文件。

### Step 9 — named v12-durable matrix fixture

只修改runner/script：

- runner `Fixture.v12Durable = "v12-durable"`；
- 真实migrator到`v12-p1-durable-work`；
- 预置合法Camp/work/attempt/claimed event；
- close + canonical snapshot + reopen + migrator两次；
- 验证snapshot、FK、integrity、DDL、guards、diagnostics；
- script两条linked lane断言exact sentinels；
- 更新new frozen Stage hash；
- literal/A1a verdict/Package hashes不变。

### Step 10 — 完整验证与报告

按§14执行全部命令、保存full logs、隔离preview、scope/hash diff，写
`impl-report.md`。任何red/unknown/范围外文件都停止，不进入Review。

### Step 11 — Independent implementation Review

reviewer只写`reviews/01-p1-a1b-review.md`。任何P0/P1回implementer有界修复并重跑
受影响门；reviewer复审。该Review必须把Review11 approval作为predecessor，并逐项
覆盖R11四合同；零P0/P1只打开acceptance。

### Step 12 — Independent acceptance

acceptance owner逐项核对§15并写`acceptance.md`。Accepted前R-01不关闭、A2不开。

## 12. 命名测试矩阵

以下全部必测；允许按test suite命名风格加prefix，但语义不得合并或省略。

### 12.1 Identity / replay / entry

- `missionAndPlanningWorkCommitAtomically`
- `sameMissionStartReplayRunsBeforeCredentialAndCatalogPreflight`
- `sameMissionStartReplayAfterProfileDeletionReturnsOriginalIdsAndTrace`
- `sameMissionStartReplayDoesNotConstructProvider`
- `sameMissionStartConflictWinsOverCurrentProviderFailure`
- `sameMissionStartPayloadOrGraphConflictFailsWithoutWrites`
- `planningReplayPreservesFirstTrace`
- `planningProfileKindDriftBetweenPreflightAndTransactionWritesNothing`
- `manualMissionStartCapturesProfileModelKeyAndTraceBeforeTask`
- `manualMissionStartReusesPendingCommandAfterPostEnqueueFailure`
- `manualMissionStartInputChangeCreatesNewCommandAndSuccessClearsPending`
- `lateManualMissionSuccessDoesNotClearNewPendingCommand`
- `candidateMissionStartUsesDeterministicKeyAndReplaysAfterLinkFailure`
- `confirmedProposalMissionStartUsesProposalKeyAndPreservesFirstTrace`
- `scheduleMissionStartUsesCheckedUTCMillisecondsKey`
- `scheduleMillisecondsOverflowClaimsSlotThenRecordsMissedWithoutMission`
- `schedulePlannerSelectionFailureClaimsSlotThenRecordsMissedOnce`
- `a1bSchedulePathDoesNotCreateScheduleFireOrChangeClaimCAS`
- `scheduleExtremeFiniteLastFiredAtPersistsNumericallyReloadsAndDedupes`
- `scheduleLegacyTextLastFiredAtRemainsReadable`
- `scheduleDateEncodingChangesOnlyLastFiredAt`
- `nonFiniteScheduleFireFailsBeforeClaimWithoutWrites`
- `manualAppCallsiteCapturesCoordinatorCommandBeforeTask`
- `candidateAppCallsiteCapturesCoordinatorCommandBeforeFirstAwait`
- `proposalAppCallsiteCapturesCoordinatorCommandBeforeTask`
- `scheduleAppCallsiteDelegatesClaimAndStartExclusively`
- `appPlanningCallsitesContainNoDirectOrchestratorStart`

原十个入口测试
`manualMissionStartCapturesProfileModelKeyAndTraceBeforeTask`、
`manualMissionStartReusesPendingCommandAfterPostEnqueueFailure`、
`manualMissionStartInputChangeCreatesNewCommandAndSuccessClearsPending`、
`lateManualMissionSuccessDoesNotClearNewPendingCommand`、
`candidateMissionStartUsesDeterministicKeyAndReplaysAfterLinkFailure`、
`confirmedProposalMissionStartUsesProposalKeyAndPreservesFirstTrace`、
`scheduleMissionStartUsesCheckedUTCMillisecondsKey`、
`scheduleMillisecondsOverflowClaimsSlotThenRecordsMissedWithoutMission`、
`schedulePlannerSelectionFailureClaimsSlotThenRecordsMissedOnce` 与
`a1bSchedulePathDoesNotCreateScheduleFireOrChangeClaimCAS` 必须直接调用生产
package coordinator。上述R11 non-finite test是额外第十一个coordinator功能测试；
另外三个encoding测试直接验证真实
`ScheduleRecord`/`ScheduleStore`。后五个 App source tests读取三个真实
App源文件：`PlanningTestFixtures.swift`从
`#filePath`定位 package root，以固定函数签名和跳过注释/字符串的 balanced-brace
scanner截取函数；missing/duplicate/unbalanced/token order错误立即失败，不能只
检查简单substring。

三个encoding测试直接验证真实`ScheduleRecord`/`ScheduleStore`：新
`lastFiredAt` raw storage只能为INTEGER/REAL、旧TEXT与新numeric都可由
`.deferredToDate`读取、其他Date仍保持TEXT/deferred encoding，禁止固定
`typeof=REAL`。`nonFiniteScheduleFire...`直接调用生产package coordinator，并断言
UUID/selection/claim之前typed throw、selection调用数为零及完整零写。

### 12.2 Resolver / Planner

- `capturedProfileAndModelDoNotDriftAfterDefaultChanges`
- `cliPlanningProfileFailsPreflightWithoutMissionWrites`
- `oauthPlanningUsesStaticCatalogAndBothCredentialAccounts`
- `officialAPIPlanningUsesCachedPlusManualCatalog`
- `customAPIPlanningAcceptsProfileScopedManualModel`
- `planningPreflightRejectsMissingCatalogWithoutWrites`
- `planningPreflightRejectsMissingPrimaryCredentialWithoutWrites`
- `oauthPlanningRejectsMissingAccountIdWithoutWrites`
- `planningCredentialReadFailureIsTypedAndDoesNotWrite`
- `planningInvalidEndpointIsTypedAndDoesNotWrite`
- `claimRevalidatesExactCapturedProfileModelAndCredentials`
- `deletedOrUnsupportedCapturedProfileTerminalizesExistingWork`
- `providerFailureIsNotConvertedToFallbackCard`
- `planningContractInvalidDoesNotFallback`
- `plannerRetriesOnlySchemaCorrectionAndPreservesFirstTurnUsage`

### 12.3 Usage / transactions

- `genericPlanningKindAPIsRejectBeforeSQL`
- `genericReservedKindOrderingUsesCallerOrderBeforeDeduplication`：对
  `claimNext`、`nextClaimableDate`、`adoptInterrupted` 分别覆盖
  `[.planning,.campDeletion]` 抛 planning capability error、反序抛 deletion
  capability error，并证明既有 time/lease 参数错误仍先于 reserved-kind 扫描
- `genericPlanningTargetAPIsRejectBeforeMutationAndClosures`
- `genericPlanningReadSeamsRemainAvailable`
- `planningSpecificProviderLifecycleUsesSealedLedgerOwner`
- `planningSpecificRecoveryAdoptsInterruptedWithoutGenericAPI`
- `planningSpecificSingleAndBulkCancelRemainAvailableWhileHalted`
- `planningIdentityAndTokenEventsPreserveIntegersAboveTwoTo53`
- `planningUsageNilWritesNoTokenEvent`
- `planningUsageZeroWritesExactTokenEvent`
- `negativePlanningUsageFailsBeforeSQL`
- `negativeFirstTurnPlanningUsageTerminalizesWithoutTokenEvent`
- `negativeCorrectionUsagePreservesPriorValidUsage`
- `turnAggregateUsageOverflowTerminalizesWithExactEvidence`
- `inputOutputUsageOverflowTerminalizesWithExactEvidence`
- `existingSpentUsageOverflowTerminalizesWithExactEvidence`
- `planningUsageOverflowEvidencePreservesIntegersAboveTwoTo53`
- `planningUsageOverflowEvidenceSortsDeduplicatesAndRejectsInvalidShape`
- `planningUsageOverflowMutationRollbackIsTotal`
- `planningSuccessWithNilFallbackWritesNoFallbackEvent`
- `planningSuccessWithFallbackIsRejectedWithoutWrites`
- `unexpectedPlanningFallbackTerminalizesThroughFailureOwner`：production
  provider已被调用恰好一次且work已owned后，只用matching-`#if DEBUG`
  `injectOwnedSuccessProposalForTesting`注入non-nil fallback success；断言同源Usage
  由既有failure owner deterministic terminalize，零fallback event、零provider重呼
- `planningSuccessCommitsTokensCardsRollupAndWorkOnce`
- `planningTerminalMutationRollbackIsTotal`
- `transientFailureRecordsUsageAndUsesDurableBackoffOnly`
- `planningCancelIsProjectionAtomicAndIdempotent`
- `haltBulkPlanningCancelIsAllOrNothing`
- `planningSuccessOverBudgetCreatesCardsButDispatchesNone`

### 12.4 Supervisor / recovery / halt / shutdown

- `leaseRenewalCompletionUsesLatestClaim`
- `staleRenewCancelsOnlyMatchingOwnedTask`
- `stalePlannerAfterCancelCannotWriteTokensOrCards`
- `supervisorNextDueTimerWakesRetryWithoutPolling`
- `waitUntilIdleIgnoresFutureRetryButWaitUntilTerminalDoesNot`
- `terminalCommitStoreFailureRetainsOwnershipAndPendingProposal`
- `terminalPendingProposalRetriesOnlyAfterRenewOrExplicitKick`
- `claimOrNextDueStoreFailureLatchesFatalAndWakesWaiters`
- `renewNonStaleFailureLatchesFatalWithoutDroppingLedgerOwnership`
- `staleClaimAndGenerationLosersDoNotLatchFatal`
- `terminalWaiterReturnsAfterDurableCancelWhileIdleWaitsForProviderExit`
- `runningStartupDoesNotDispatchPlanningBeforeCardOrphanAdoptionCompletes`
- `startupCardOrphanAdoptionFailureKeepsPlanningSuppressedWithoutDurableTransition`
- `explicitRetryAfterStartupCardRecoveryFailureActivatesSupervisorExactlyOnce`
- `startupRecoveryRetryWritesNoCampHaltedOrCampResumedEvent`
- `staleStartupRecoveryCannotActivateAfterConcurrentControlTransition`
- `haltedStartupRunsCleanupWithoutPumpTimerOrProvider`
- `haltedStartupRepairsAndAdoptsBeforeAtomicCleanupWithoutDispatch`
- `haltedStartupWithWorklessLegacyMissionLeavesNoActivePlanning`
- `haltedWorklessUnresolvedLegacyMissionUsesEmergencyHaltAttemptZero`
- `haltedStartupCleanupFailureRetriesRecoveryBeforeDurableRunning`
- `haltPersistenceFailureKeepsSupervisorSuppressed`
- `haltCleanupFailureKeepsSupervisorSuppressedAndBlocksResume`
- `haltAfterProviderResponseCannotWriteTokensOrCards`
- `haltRacingSameKeyReplayOrAbsentPreflightWritesNothing`
- `haltRacingEnqueueClaimOrRenewHasControlWinnerOnly`
- `haltRacingFailureOrOverflowTerminalHasSingleOwner`
- `resumeOpensSupervisorOnlyAfterDurableRunningAndKicksOnce`
- `missingOrCorruptKernelControlFailsPlanningClosed`
- `shutdownWithCancellationIgnoringProviderReturnsBoundedly`
- `shutdownReportSortsUniqueUncooperativeWorkIds`
- `providerReturningAfterShutdownCannotCommit`
- `shutdownRacingTerminalProposalHasOneActorSerializedWinner`
- `nextProcessAdoptsShutdownRowAndCompletesExactlyOnce`
- `restartAdoptsPlanningWorkAndCreatesCardsOnce`

其中 recovery-retry event test必须含
`.initialized + first-phase retry eligibility`完整重跑与
`.recoveryReady + Card-retry eligibility` Card-only重试两个子场景；stale-control
test必须分别覆盖shutdown清first-phase eligibility/token与emergencyStop清Card
eligibility/token。

### 12.5 Legacy / scope

- `legacyPlanningRepairUsesUniformMemberProfile`
- `legacyPlanningRepairUsesExactlyOneDefaultOnly`
- `legacyPlanningRepairConflictOrCliFailsMissionOnce`
- `legacyPlanningFailureCreatesAttemptZeroWithoutAttemptRows`
- `runningUnresolvedLegacyMissionKeepsExactLegacyTerminalCode`
- `legacyPlanningModelUnavailableFailsMissionOnceWithExactCode`
- `legacyPlanningWithCardsFailsClosedWithExactTypedErrorAndZeroWrites`
- `legacyRepairRunningModeLinearizesBeforeConcurrentHalt`
- `legacyRepairHaltedModeCreatesAndCancelsAttemptZeroAtomically`
- `legacyPlanningRepairRunsBeforeCardAdoption`
- compile-call-site coverage for every §3.2 test file
- source sentinel：旧split planning API、`planningTasks`、10ms polling、
  compatibility overload、Core current-default lookup与
  `suppressForOrchestratorRecoveryFailure` production declaration/call site为零；
  DEBUG seam和调用test/helper必须有matching `#if DEBUG`，release Core无该符号；
  §14 的旧 command/source blocks只保留inventory，不得直接整块执行；可执行
  fail-fast命令唯一以总 Plan §11 的 A1b full/source/release gates为准，必须
  `set -euo pipefail`并区分`rg` no-match与error。

## 13. Migration matrix

Runner fixture精确为：

```swift
case v12Durable = "v12-durable"
```

与旧fixture不同：

1. 用真实`AppDatabase.migrator`迁到`v12-p1-durable-work`；
2. checkpoint证明durable三表与四guards已存在；
3. 插入合法Camp、running planning work、open attempt、claimed event；
4. 保存canonical logical schema/data snapshot；
5. close pool；
6. reopen并跑真实migrator两次；
7. snapshot逐字不变；
8. FK/integrity、DDL/index/trigger、append-only、完整56/40/288 diagnostics通过。

两条linked lane都必须输出：

- `fixture.v12-durable.replay=pass`
- `fixture.v12-durable.fk=pass`
- `fixture.v12-durable.integrity=pass`
- `fixture.v12-durable.ddl=pass`
- `fixture.v12-durable.append_only=pass`
- `diagnostics.real.v12-durable.*`

Literal lane继续以v11引入v12；不对existing v12重复literal。不得复制最终schema。

## 14. 验证命令与证据

Authoritative commands：

```bash
swift run RunTests
swift build --product AgentLoopApp
scripts/verify-p1-migrations-sqlite-matrix.sh --sqlite 3.51 --sqlite 3.52
scripts/run-app.sh --preview
git diff --check
git status --short --branch
```

Source sentinels：

```bash
test -z "$(rg -n 'planningTasks' \
  Sources/AgentLoopCore/Kernel/Orchestrator.swift || true)"
printf 'source.planning_tasks=pass\n'

test -z "$(rg -n \
  '\b(createMissionShell|recordPlanningTokens|recordPlanFallback|planMission)\s*\(' \
  Sources/AgentLoopCore Sources/AgentLoopApp || true)"
printf 'source.split_planning_api=pass\n'

test -z "$(rg -n \
  '\borchestrator\.(startMission|confirmSquadProposal)\s*\(' \
  Sources/AgentLoopApp/AppStore.swift \
  Sources/AgentLoopApp/CodingRanchStoreAdapter.swift \
  Sources/AgentLoopApp/MissionScheduler.swift || true)"
test -z "$(rg -n '\bdb\.claimScheduleFire\s*\(' \
  Sources/AgentLoopApp/MissionScheduler.swift || true)"
test -z "$(rg -n '\b(factory\.)?linkConverted\s*\(' \
  Sources/AgentLoopApp/CodingRanchStoreAdapter.swift || true)"
printf 'source.app_planning_entry_delegation=pass\n'

test -z "$(rg -n \
  'public func (claimNextPlanning|renewPlanningLease|nextClaimablePlanningDate|adoptInterruptedPlanning|commitPlanningSuccess|recordPlanningAttemptFailure|recordPlanningUsageOverflow|cancelPlanning|cancelAllPlanningForEmergencyHalt|repairLegacyPlanningMissions)\b' \
  Sources/AgentLoopCore/Database/AppDatabase.swift \
  Sources/AgentLoopCore/Database/DurableWorkStore.swift || true)"
printf 'source.planning_specialized_api_internal=pass\n'

test -z "$(rg -n \
  'kind: DurableWorkKind = \.planning|kinds: \[DurableWorkKind\] = \[\.planning\]' \
  Sources/AgentLoopTestSuite/DurableWorkTests.swift || true)"
printf 'source.generic_durable_work_fixture_not_planning=pass\n'

test "$(rg -n '^fileprivate enum PlanningDurableWorkLedgerOwner\b' \
  Sources/AgentLoopCore/Database/DurableWorkStore.swift | wc -l | tr -d ' ')" = 1
printf 'source.planning_ledger_owner_fileprivate=pass\n'
```

Production命中必须为零；唯一 fileprivate ledger owner必须恰好一个；test fixture
的历史字符串assertion不算production命中。功能测试而非sentinel才是九个 API
fail-closed与coordinator行为的主证据。

Hash：

```bash
shasum -a 256 \
  docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md \
  docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md \
  docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a1b-durable-planning/plan.md \
  docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a1a-durable-work-store/acceptance.md
```

Evidence mapping：

| Gate | 完整证据 |
|---|---|
| failure-first / full tests | `verify.log` |
| App build | `build.log` |
| SQLite 3.51/3.52 linked + literal matrix | `migration-matrix.log` |
| isolated preview | `preview.log`、`evidence/preview-smoke.png`、`evidence/preview-observation.md` |
| allowlist / before-after hashes | `evidence/preflight.txt`、`evidence/scope-and-hashes.txt`、`evidence/final-hashes.txt` |
| implementation summary/deviations | `impl-report.md` |
| independent Review | `reviews/01-p1-a1b-review.md` |
| independent acceptance | `acceptance.md` |

Preview必须使用新临时`AGENTLOOP_STATE_DIR`，保存命令、absolute state root、进程、
关键可见状态与退出证据；不得指向normal root。Build不能替代preview。完整日志不能
只保存摘要。

## 15. 完成门

A1b只有全部成立才完成：

1. Review11对R11 Candidate Stage/Plan/leaf精确hashes为
   `APPROVED — 0 P0 / 0 P1`。
2. 实际diff只在§3 allowlist与当前task的owner产物。
3. v12 schema/literal、A1a verdict、`Package.swift`、`Package.resolved`、
   `Sources/RunTests/main.swift`与target graph不变。
4. R-01 failure-first被真实复现并由根因修复关闭。
5. generic九个 mutation/dispatch API对planning全部fail closed；read seams与唯一
   specialized provider/recovery/cancel owner全部通过正反例。
6. 四入口真实委托同一个package coordinator；功能与source-order/direct-call
   sentinels全部通过。
7. Schedule extreme finite `lastFiredAt`只写numeric并可exact reload/dedupe；旧TEXT
   与新INTEGER/REAL都由deferred decoder读取，其他Date encoding不变。
8. non-finite schedule fire在UUID/selection/Result/claim前抛现有typed error且完整
   零写；finite checked-ms overflow仍claim→missed一次，claim CAS/schema不变。
9. Mission+planning work原子；same-key replay-first/conflict/first trace全部成立。
10. Resolver完整preflight且无current-default/credential/catalog fallback。
11. Planner无自身retry/fallback；provider errors进入durable retry/fail。
12. success/failure/overflow/cancel/halt projection全部transaction-atomic。
13. nil/zero/overflow/`>2^53` usage事实与event逐字准确，无trap/saturation/prefix。
14. running startup保持`.recoveryReady + suppressed`直到Card recovery/healing与
    双token/durable fences完成；activation恰好一次，running/halted retry分流通过。
15. restored halt、halt races、resume、late provider、bounded shutdown全部通过；
    production无post-failure reactive re-suppress。
16. running legacy-with-Cards抛exact `LegacyPlanningHasCardsError`且完整零写；
    unexpected fallback只经matching-DEBUG窄seam进入同一failure owner，release无seam。
17. old split planning API、`planningTasks`与R11禁止项production sentinel零命中。
18. named`v12-durable`在SQLite 3.51/3.52两条真实linked lane通过。
19. `swift run RunTests`、App build、matrix、isolated preview、diff/hash checks全绿。
20. `impl-report.md`列明changed files、完整logs与任何deviation；未解释的deviation
    为blocker。
21. independent implementation Review为0 P0/0 P1。
22. independent acceptance判定`ACCEPTED`。

只有第22项成立，才关闭R-01并打开A2。Review通过但acceptance未通过时，A2仍关闭。

## 16. Stop conditions 与 Open Questions

任一情况立即停止：

- frozen hash drift；
- Review11未在R11 Candidate精确hashes上给出`APPROVED — 0 P0 / 0 P1`；
- allowlist外真实调用点或必改文件；
- 需要新migration/dependency/concrete Provider改动；
- 需要修改Package/RunTests target graph才能验证App入口；
- generic planning capability无法在不破坏specialized recovery/control owner时封死；
- Schedule numeric/deferred兼容只能靠migration/schema、固定`typeof=REAL`、改claim
  CAS/slot/missed或第二Schedule owner才能通过；
- non-finite schedule只能靠claim后missed、selection side effect或测试放宽才能通过；
- running startup无法在Card recovery完成前保持`.recoveryReady + suppressed`，或只能
  靠post-failure reactive re-suppress、临时durable halt/bulk cancel/camp event收口；
- startup retry无法区分durable-running Card carve-out与durable-halted cleanup；
- unexpected fallback测试需要release-visible seam、任意proposal/token/generation
  injection、直接Store调用或provider重呼；
- `legacy_planning_has_cards`无法以无额外payload的package typed error和完整零写实现；
- Candidate transaction必须改变才能通过；
- red/unknown test、matrix/build/preview failure；
- recovery/halt/shutdown只能靠silent fallback或unbounded wait通过；
- identity/usage evidence无法保持canonical exact integer；
- Review存在P0/P1；
- acceptance证据不完整。

Open Questions：无。
