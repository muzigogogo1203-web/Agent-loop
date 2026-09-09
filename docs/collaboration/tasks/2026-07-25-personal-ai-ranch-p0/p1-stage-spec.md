# P1 阶段 Spec — 可靠性与新契约地基

> 状态：**R27 永久 REJECTED_CONTAMINATED — 唯一 full 651/652；Shell timeout 测量边界失败；无 later gates/END；R28 Measurement-Boundary Candidate Frozen；fresh driver/235-entry manifest/freeze present；Review28 pending；A2 blocked**
>
> 日期：2026-08-10
>
> 上位权威：`docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md`
>
> 规划依据：P0 `current-state-evidence.md` 的 R-01…R-09
>
> 本文只定义 P1；P0 完成门通过前不得开始产品代码实施。

## 1. 阶段目标

P1 必须在不扩张完整产品 UI 的前提下完成两件事：

1. 修复当前系统会永久停在 `planning`、`ruminating`、错误 schedule slot 或半转换状态的根因，并让 App、Keychain、MCP 与知识关键路径失败可见、可追踪、可恢复。
2. 为 P2 的“教练 → 执行 → 成果 → 验证 → 验收 → 复利”金路径建立版本化、可回放、可测试的数据与运行契约。

P1 继续保留并加固现有 Mission / Card / Run、行动板终结工具、Runtime Profile 和 CLI 后端。P1 不重写现有可靠内核，也不以兼容当前测试数据为由削弱新契约。

## 2. 进入条件

只有下列条件全部成立，P1 才能开始：

- P0 `acceptance.md` 判定 P0 完成门通过；
- P0 的权威测试、App build、真实 App 和 Provider / CLI 基线证据仍可定位；
- 本文和 `p1-plan.md` 通过与规划者、实现者职责分离的独立 Review；
- Review 没有未解决的 P0 / P1 finding；
- Open Questions 为空；
- 当前工作在 `codex/` 分支，且进入时 branch、HEAD、worktree 已记录；
- 没有未授权的数据重置、commit、push、发布或真实用户操作。

## 3. 非目标

P1 不做：

- 云端同步、多设备、Web / 移动端和牛哒；
- P2 的完整教练 UI、统一 URL / 文件真实摄取、自动组牛体验和端到端 onboarding；
- 大规模像素视觉扩张；
- 最终母品牌、bundle id、target 名和状态目录迁移；
- 公开 SDK、第三方扩展分发和商业计费；
- 为“文件变整齐”而整体重写 `AppStore.swift`；
- 把所有历史 Mission 强行伪装成已经拥有新 Understanding / Outcome / Verification；
- 重置 normal 或 preview 数据；
- 用模型评分代替确定性验证。

## 4. P1 架构边界

### 4.1 保留的内核

- `MissionRecord`、`CardRecord`、`RunRecord` 继续承担现有行动执行。
- 工作卡仍只能通过 `complete_card` / `block_card` 终结。
- `Orchestrator` 继续控制 Mission/Card 派工、预算、取消、收哨与恢复。
- `RuntimeProfileRecord` 继续是运行供给线事实源。
- 现有 `event` 表继续保存旧 Mission/Card 事件，不改名、不删除、不重写历史。

### 4.2 新增的边界

P1 新增三类基础设施：

1. **Durable Work Ledger**：所有关键异步转换先落库，再由具名 worker 领取；进程重启后可收编。
2. **Domain Contract Store**：Goal、Input、Understanding、Outcome、Verification、Acceptance、Grant、Memory、Cow/Residency 等版本化契约。
3. **Application Workflow Layer**：只抽出被 P1 修改的工作流控制器，使它们可以在不启动 SwiftUI 的情况下做应用层 workflow test；未触及的旧 UI 逻辑继续留在 App target。

建议新增 `AgentLoopApplication` target，依赖 `AgentLoopCore`，不得依赖 SwiftUI 或 AppKit。`AgentLoopApp` 负责 composition 和可见状态，不能自行编排跨表事务。

## 5. 全局标识、版本、时间与编码

所有 P1 新契约统一遵守：

- ID：随机 UUID 字符串；稳定 aggregate 的后续版本复用 aggregate ID。
- 版本：从 `1` 开始单调递增；CAS 写必须带 expected version。
- 时间：SQLite `datetime`，进程内使用 UTC `Date`；展示时才转本地时区。
- JSON：所有进入 hash、幂等比较、receipt、event、work、Grant、Contract、Request
  或持久化 canonical JSON 字段的字节，唯一权威都是下述
  `AgentLoopCanonicalJSON.v1`；不得直接 hash `JSONEncoder`、`JSONSerialization`
  或调用者原始字节。
- 内容 hash：canonical JSON 或耐久内容字节的 SHA-256 小写十六进制。
- 幂等：外部命令、输入、设备重放、work、schedule slot、验收和 outbox 都有唯一 idempotency key。
- 错误：持久化稳定 `errorCode`、净化后的用户信息和 `traceId`；秘密、OAuth 回调、账号标识和 API key 不进入日志。
- 不可变版本：已确认 Understanding、已激活 OutcomeContract、OutcomeVersion 和 VerificationRecord 不原地改正文；变化产生新版本。

### 5.1 `AgentLoopCanonicalJSON.v1`

P1 中所有“canonical JSON”均专指本节算法。实现为
`CanonicalJSONV1`，只用 Swift 6 + Foundation/CryptoKit，不新增第三方依赖：

```text
public enum CanonicalJSONV1 {
    public static func encode<T: Encodable>(_ value: T) throws -> Data
    public static func canonicalize(rawUTF8: Data) throws -> Data
    public static func validateCanonical(rawUTF8: Data) throws
    public static func sha256Hex(_ canonicalBytes: Data) -> String
}
```

两条入口只有一个真相：

1. typed `Encodable` 先用固定 JSONEncoder 产生中间 JSON：
   `outputFormatting = [.sortedKeys, .withoutEscapingSlashes]`、
   `keyEncodingStrategy = .useDefaultKeys`、
   `dateEncodingStrategy = .millisecondsSince1970`、
   `dataEncodingStrategy = .base64`、
   `nonConformingFloatEncodingStrategy = .throw`；然后仍必须进入同一个 strict parser
   和 serializer，不能直接返回或 hash JSONEncoder bytes。
2. 任意 raw JSON 直接进入同一个 strict parser 和 serializer。parser 由本地 Swift
   UTF-8 scanner 实现；不得使用会丢失重复 key 或原始 number token 的
   `JSONSerialization` / `JSONDecoder` 作为 raw parser。
3. 因而相同 decoded JSON tree 必须得到逐字相同 bytes。`validateCanonical` 调用
   `canonicalize` 后做 Data byte equality；不相等即
   `CanonicalJSONNotCanonicalError`。所有 SHA-256 只对 canonicalizer 返回值计算。

实现唯一选择是 `CanonicalJSON.swift` 内的 private byte-backed AST：string 与 key
保存 decoded UTF-8 bytes，number 保存原 token，object 保存 pair array；key 判重和
排序都直接比较 bytes，绝不进入 `Dictionary<String,...>`。Store 判断 object root
只能调用该文件的 internal `canonicalizeWithRootKind` / typed scalar extractor。
`CanonicalJSON.swift` 与 `DurableWorkStore.swift` 都不得引用既有 `JSONValue`、
`JSONSerialization`，也不得用 raw `JSONDecoder` 代替 scanner；typed `Decodable`
只可消费已经由 scanner 验证并投影出的 typed scalar。

strict parser/serializer 的逐字规则固定为：

- 输入必须是无 BOM 的有效 UTF-8 和单一 RFC 8259 JSON value；canonicalize 可消费
  value 前后的 RFC JSON whitespace 并在输出移除，最后一个允许 whitespace 后的
  任何 trailing byte 均拒绝。另拒绝 lone surrogate、非 JSON number、重复的
  decoded object key。object key 不做 Unicode normalization；排序按 decoded
  key 的 UTF-8 unsigned bytes
  lexicographic ascending，因此 composed/decomposed Unicode 保持不同且顺序稳定。
  parser 的 key identity/hash 也必须基于这些 UTF-8 bytes，不能用具有 canonical
  equivalence 的 Swift `String ==` / `Dictionary<String,...>` 判重。
- 输出无空格、无换行；object 使用 `:`/`,`，array 使用 `,`。string 保留 decoded
  Unicode scalar sequence，不做 NFC/NFD；`"`、`\` 分别写 `\"`、`\\`，
  U+0008/U+0009/U+000A/U+000C/U+000D 写 `\b/\t/\n/\f/\r`，其他
  U+0000...U+001F 写 lowercase `\u00xx`；其余 scalar 直接写 UTF-8。`/` 永不
  escape，U+2028/U+2029 和非 ASCII 字符不转义。
- number 只接受 RFC 8259 grammar。token 最多 128 UTF-8 bytes，coefficient
  （整数位+小数位）最多 128 digits，显式 exponent 必须以 checked decimal parse
  落在 `-324...324`；越界、overflow、NaN、Infinity、前导 `+`、非法 leading
  zero、缺整数/小数/exponent digits 全部 fail-fast。
- number 不经过 `Double`、`Decimal` 或 locale。令
  `digits = integerDigits + fractionDigits`，
  `decimalExponent = explicitExponent - fractionDigits.count`；全零输出 `0`
  （包括 `-0`/`-0.0`）。否则移除 leading zeros，再移除 trailing zeros且每移除
  一位令 decimalExponent + 1；按 decimalExponent 插入小数点或零，始终输出普通
  十进制、永不输出 exponent、无多余小数零，非零负数才保留 `-`。单个 canonical
  number 最多 512 bytes，超过即 `CanonicalJSONNumberOutOfRangeError`。

规范样例：

| 输入 JSON value | 唯一 canonical UTF-8 |
|---|---|
| `{"s":"a\/b"}` | `{"s":"a/b"}` |
| `{"u":"\u00e9中"}` | `{"u":"é中"}` |
| `{"n":1.2300,"e":1e+3,"z":-0.0,"m":1e-3}` | `{"e":1000,"m":0.001,"n":1.23,"z":0}` |
| `{"é":1,"e\u0301":2}` | `{"é":2,"é":1}` |

现有 prompt-cache / provider wire encoder 的 `.sortedKeys` 不变量继续保留；若其
bytes 参与 P1 identity/hash，必须再经 `CanonicalJSONV1`。`.sortedKeys` 是稳定
prompt transport 的要求，不是第二套 canonical/hash 算法。

## 6. Durable Work Ledger

### 6.1 数据契约

迁移 `v12-p1-durable-work` 只新建 `durable_work`、
`durable_work_attempt` 和 `durable_work_attempt_event`。`schedule_fire` 延后到
P1-A4 的独立迁移 `v12-p1-schedule-fire`，避免 A1a 提前引入尚未实现的
Schedule schema。全部规范性 DDL、约束、索引与 trigger 见 §18；本节定义运行语义。
`guideChat` 与 `campDeletion` 仅在 v12 保留 kind；A1a 的所有 generic
mutation/scheduling API 都拒绝 `campDeletion`，guide chat 接线则延后到 v16。

#### `durable_work`

work 是当前投影。幂等身份固定为 `(kind, idempotencyKey)`；重放时
`campId`、`aggregateType`、`aggregateId`、canonical `inputJson`、Store 重算的
`inputHash`、`maxAttempts` 必须全部相同，否则抛
`DurableWorkReplayConflictError`，不能返回旧 work。enqueue 只接受 object-root
的 §5.1 canonical bytes；Store 在 SQL 前用 `CanonicalJSONV1.canonicalize`
重算并逐字验证，自算 SHA-256 lowercase hex，并要求 caller claimed hash 为
`[0-9a-f]{64}` 且完全相同。非 canonical、uppercase/non-hex 或 hash mismatch
全部零写入，绝不把 caller hash 当真相。活动态
`queued|running|retryScheduled` 对 `(kind, aggregateType, aggregateId)` 建 partial
unique index，所以同一 aggregate/kind 只有一个活动 work；终态历史可以有多条。
`work(kind:aggregateType:aggregateId:)` 只返回活动 work，
`latestWork(...)` 才返回最新历史，禁止把多条历史误当单数。

#### `durable_work_attempt`

这是**可变的当前/历史 attempt 生命周期投影**，不是 append-only event。主键为
`(workId, attempt)`，并有唯一 `id`。claim 时插入开放行；关闭 attempt 的同一事务
只允许把 `endedAt/outcome/error*` 从 NULL 写一次，应用层以
`WHERE endedAt IS NULL` CAS，0 行即 `AttemptAlreadyClosedError`。attempt 从 1
开始，每次成功 claim 将 work.attempt 加 1；retry 到期后的再次 claim 产生下一
attempt，不复用旧编号。

#### `durable_work_attempt_event`

这是不可变审计账本。事件为
`claimed|leaseRenewed|succeeded|failed|canceled|interrupted`，以
`(workId, attempt, sequence)` 唯一；UPDATE/DELETE abort trigger。每个 attempt
只能有一个 `succeeded|failed|canceled|interrupted` terminal event。attempt
投影关闭和 terminal event 插入必须同一事务，因此每次 claim 最终恰有一个终结
结果；lease renewal 只追加事件并更新 work lease/version，不关闭 attempt。

### 6.2 状态机

```text
queued ──claim──> running
running ──success──> succeeded
running ──transient failure──> retryScheduled ──claim when due──> running
running ──deterministic/exhausted failure──> failed
queued/retryScheduled/running ──explicit cancel──> canceled
running ──process restart adoption──> queued
```

规则：

- `claimNext` 在单一 write transaction 中直接选择 `queued` 或
  `retryScheduled AND notBefore <= now`；不再存在未定义的
  `retryScheduled -> queued` 命令。它更新 work、插入 attempt 和 `claimed`
  event 后返回含最新 work version/attempt/lease owner 的 claim。
- 每条 work 有 non-null stable `campId`。A1a 的 generic `enqueue` 在 replay
  lookup/INSERT 前于同一 transaction 验证 Camp 存在且 `camp.archived=false`；
  missing 抛 `RecordNotFoundError(table:"camp",id:)`，archived 抛
  `CampArchivedError`，包括 archive 后同 key replay。v16 backfill 后每条 work
  还保存无 default 的 `campLifecycleVersion`；普通 enqueue/claim 必须在同一
  transaction 读 active lifecycle 并写/校验 exact version。
- `campDeletion` 是 sealed reserved kind。generic `enqueue`、`claimNext`、
  `nextClaimableDate`、`cancelActive`、`adoptInterrupted` 在打开 SQL 前发现它即抛
  `CampDeletionRequiresRetirementCapabilityError`；`renewLease`、`complete`、
  `retryOrFail`、`cancel` 在 transaction 读到目标 work 是该 kind后、任何
  UPDATE/closure 前抛同一错误。只有 `activeWork/latestWork` 可只读查询。
  F2 另建由 §14.2 opaque deletion permit 驱动的 specialized helper；generic
  cancel 永远不能取消 deletion work。
- 同一 work 同时只有一个有效 lease owner。
- claim-scoped 命令 `renewLease`、`complete`、`retryOrFail` 必须带
  `id + attempt + latest version + leaseOwner` CAS；renew 成功返回新 claim，
  后续 terminal commit 必须使用它，不能继续用领取时的旧 version。
- `complete.outputJson` 可为 nil；非 nil 时必须是 §5.1
  `CanonicalJSONV1` 的 canonical **object** UTF-8 bytes。Store 在进入
  `pool.write` 前调用 canonicalizer、验证 root、再做逐字 equality；invalid JSON、
  非 object、alternate representation 分别抛
  `InvalidDurableWorkOutputJSONError.invalidJSON|rootMustBeObject|notCanonical`。
  任一错误均零 DB 写且不得调用 `businessMutation`；成功时只保存已经验证的原字节。
- work-scoped `cancel` 使用 `id + expectedVersion` CAS；对
  queued/retryScheduled 不要求 leaseOwner，对 running 则原子关闭当前 attempt、
  清 lease 并追加 canceled event。`cancel` 必须接收并在同一 transaction 执行的
  projection mutation；Mission cancel 置 failed，Rumination cancel 把
  Ingestion 退回 queued。mutation 失败则 work 也不 canceled。
- `cancelActive` 必须在同一个 serialized write transaction 内查询 partial-unique
  active row/current version 并立即复用 cancel CAS；不能先读后另开事务。没有
  active row 成功返回 `noActiveWork` 且不调用 projection mutation；terminal 与
  cancel 并发时先 commit 者胜，后者重读后看到 no active，不得覆盖终态。
- 当前本地 App 依靠 `StateDirectoryLock` 保证单进程。冷启动
  `adoptInterrupted` 在同一 write transaction 内选择
  `running AND leaseOwner != currentWorkerId`；它不要求旧 leaseOwner CAS，也不等
  lease 到期，直接关闭旧 attempt 为 interrupted、清 lease、把 work 置 queued。
  当前 worker 自己的 running work 不得被收编。
- AppKit termination 没有可靠的可等待 async completion，因此 P1 **不承诺**
  graceful shutdown 把 work release 为 queued。Supervisor 有单调 `generation`
  和 `initialized|recovering|recoveryReady|running|shuttingDown|shutDown`
  lifecycle；每个 owned
  Task 捕获 generation。`shutdown()` 必须在 actor 内先进入 shuttingDown、递增
  generation、停止 pump/timer 并 cancel Tasks，再最多等待注入的
  `shutdownGracePeriod`（production 固定 2 秒）。期限到即返回
  `ShutdownReport(uncooperativeWorkIds:)` 并进入 shutDown；不能继续无限 await，
  也不能宣称忽略取消的 Task 已停止。
- renew、next-due scheduling 和 provider terminal proposal 都必须回到 supervisor
  actor，并在**无任何 await 紧邻数据库写之前**验证 lifecycle 仍为 running、
  captured generation 等于当前 generation、work entry 仍由该 Task 持有。gate 与
  同步 DB commit 在同一 actor turn 完成。shutdown 一旦递增 generation，旧 Task
  即使以后返回也只能收到 `SupervisorGenerationExpiredError`，不得 renew、commit
  或 schedule；durable row 保持 running，供下一进程 adoption。
- shutdown 不改 ledger；下一次持有 StateDirectoryLock 的进程按 adoption 规则恢复。
  显式用户 cancel 才进入 canceled。
- transient 分类仅限网络断开、408、429、5xx 和明确的临时资源错误；第 1/2/3 次
  transient failure 后重试间隔固定为 5s、30s、120s，第 4 次或
  `attempt >= maxAttempts` terminal failed，默认 maxAttempts=4。计算 notBefore
  前后必须验证 Date interval finite 且不倒退；不可表示时
  `BackoffOverflowError` 整笔回滚，不 trap 或写无穷日期。
- 解析、schema、缺权限、缺记录、契约冲突与 4xx（408/429 除外）是确定性失败，不自动重试。
- success、terminal failure、cancel 时，目标 projection、旧/新事件、
  attempt close、attempt terminal event 和 work terminal 必须同一事务。
- stale worker 的 terminal CAS 若为 0 行，整笔 transaction 回滚，不记 usage、不写
  fallback、不建 Card、不改 projection，也不另行关闭 attempt；真正 owner 的
  cancel/adoption/terminal command 负责关闭它。

#### 6.2.1 时间、claimability 与三层诊断矩阵

所有接受 `now` 的 DurableWorkStore API 都在任何 `pool.read/write` 前验证
`now.timeIntervalSinceReferenceDate.isFinite`。`claimNext/renewLease` 还在 SQL 前
验证 `leaseDuration.isFinite && leaseDuration > 0`，计算 expiration 后验证它
finite 且严格 `> now`；分别抛：

```text
InvalidDurableWorkTimeError.nonFiniteNow
InvalidDurableWorkTimeError.nonFiniteLeaseDuration
InvalidDurableWorkTimeError.nonPositiveLeaseDuration
InvalidDurableWorkTimeError.nonFiniteLeaseExpiration
InvalidDurableWorkTimeError.nonAdvancingLeaseExpiration
```

因此 `-0.0`、NaN、±Infinity、负 duration 和因精度未推进的极小正 duration 均
零写入。参数检查先于 empty-kinds 快路：合法 `now` 且 kinds 为空时
`nextClaimableDate/claimNext` 返回 nil，后者不打开 write transaction。
`nextClaimableDate` 与 `claimNext` 复用同一个 eligibility predicate：指定 kind、
普通 work 的 Camp 当前可写、queued 或 due retry；有 queued 或
`notBefore <= now` 即返回 caller exact `now`，否则返回最早 future `notBefore`；
running/terminal/archived Camp 全忽略，重复 kind 先去重。`notBefore == now` 为 due。

取消 reason 必须通过
`InvalidDurableWorkCancellationReasonError.empty|tooLong|containsControlScalar`：
1…1000 Unicode scalar、无 C0/C1 control scalar；不 trim、不截断、不替换，SQL 前
失败且不调用 business mutation。固定系统码只有用户取消 `work_canceled`、冷启动
收编 `worker_interrupted`。三层唯一矩阵如下；attempt/event 不复制 output，
`durable_work.outputJson` 是唯一成功输出事实：

| 转换 | work error/output | 当前 attempt | 新 event |
|---|---|---|---|
| enqueue → queued | nil / nil | 无 | 无 |
| claim queued/due retry | 清空 error / nil | open，error nil | claimed/running，error nil |
| renew | error nil / nil | open 不变 | leaseRenewed/running，error nil |
| complete | error nil / nil 或 canonical object | succeeded，error nil | succeeded/succeeded，error nil |
| transient retry | failure code/message / nil | failed，同 code/message | failed/retryScheduled，同 code/message |
| deterministic/耗尽 | failure code/message / nil | failed，同 code/message | failed/failed，同 code/message |
| cancel queued | `work_canceled` + reason / nil | 无 | 无 |
| cancel retryScheduled | `work_canceled` + reason / nil | 历史 failed attempt/event 不变 | 无 |
| cancel running | `work_canceled` + reason / nil | canceled，同 code/reason | canceled/canceled，同 code/reason |
| adopt running | `worker_interrupted` + nil / nil | interrupted，同 code/nil | interrupted/queued，同 code/nil |
| claim adopted queued | 清空 error / nil | 新 open/error nil | claimed/running/error nil |

stale CAS、invalid output、time/backoff overflow 或 closure failure 必须让 work、
attempt、event 三层逐字不变。§18.1 的 CHECK 独立执行同一状态矩阵。

#### 6.2.2 `DurableWorkFailure`

retry 分类的唯一输入是以下可编译契约：

```swift
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

private struct DurableWorkFailureCodingKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int? = nil

    init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        return nil
    }
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
    ) throws {
        let codeBytes = Array(code.utf8)
        let isLower = { (byte: UInt8) in byte >= 97 && byte <= 122 }
        let isDigit = { (byte: UInt8) in byte >= 48 && byte <= 57 }
        guard (1...64).contains(codeBytes.count),
              let first = codeBytes.first,
              isLower(first),
              codeBytes.dropFirst().allSatisfy({
                  isLower($0) || isDigit($0) || $0 == 95
              })
        else {
            throw InvalidDurableWorkFailureError.invalidCode
        }

        if let message {
            let scalars = message.unicodeScalars
            guard !scalars.isEmpty else {
                throw InvalidDurableWorkFailureError.emptyMessage
            }
            guard scalars.count <= 1_000 else {
                throw InvalidDurableWorkFailureError.messageTooLong
            }
            guard !scalars.contains(where: {
                $0.value <= 0x1F || (0x7F...0x9F).contains($0.value)
            }) else {
                throw InvalidDurableWorkFailureError
                    .messageContainsControlScalar
            }
        }

        if let usageJson {
            do {
                let data = Data(usageJson.utf8)
                try CanonicalJSONV1.validateCanonical(rawUTF8: data)
                try CanonicalJSONV1.validateDurableWorkUsageObject(
                    rawUTF8: data
                )
            } catch {
                throw InvalidDurableWorkFailureError.invalidUsageJson
            }
        }

        self.code = code
        self.message = message
        self.disposition = disposition
        self.usageJson = usageJson
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(
            keyedBy: DurableWorkFailureCodingKey.self
        )
        let expected = Set([
            "code", "message", "disposition", "usageJson",
        ])
        guard Set(container.allKeys.map(\.stringValue)) == expected else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "DurableWorkFailure has an invalid shape"
            ))
        }

        let codeKey = DurableWorkFailureCodingKey("code")
        let messageKey = DurableWorkFailureCodingKey("message")
        let dispositionKey = DurableWorkFailureCodingKey("disposition")
        let usageKey = DurableWorkFailureCodingKey("usageJson")
        let decodedCode = try container.decode(String.self, forKey: codeKey)
        let decodedMessage = try container.decodeIfPresent(
            String.self, forKey: messageKey
        )
        let decodedDisposition = try container.decode(
            DurableWorkFailureDisposition.self, forKey: dispositionKey
        )
        let decodedUsage = try container.decodeIfPresent(
            String.self, forKey: usageKey
        )

        do {
            try self.init(
                code: decodedCode,
                message: decodedMessage,
                disposition: decodedDisposition,
                usageJson: decodedUsage
            )
        } catch {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "DurableWorkFailure validation failed"
            ))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(
            keyedBy: DurableWorkFailureCodingKey.self
        )
        try container.encode(
            code, forKey: .init("code")
        )
        if let message {
            try container.encode(message, forKey: .init("message"))
        } else {
            try container.encodeNil(forKey: .init("message"))
        }
        try container.encode(
            disposition, forKey: .init("disposition")
        )
        if let usageJson {
            try container.encode(usageJson, forKey: .init("usageJson"))
        } else {
            try container.encodeNil(forKey: .init("usageJson"))
        }
    }
}
```

- raw values 逐字为 `transient` / `deterministic`。`code` 必须匹配
  `[a-z][a-z0-9_]{0,63}`；不自动 lowercase 或截断。
- `message` 可为 nil；非 nil 必须非空、最多 1000 Unicode scalars，且不含
  U+0000...U+001F 或 U+007F...U+009F。它只能来自按 code 建立的静态用户安全摘要
  或显式 redactor，不能传 raw Error/provider body、credential、account ID、
  OAuth callback 或秘密；initializer 对结构不合规值 fail-fast，不截断。
- `usageJson` 可为 nil；nil 表示本 attempt 没有可计量 provider turn。非 nil
  必须是已经通过 §5.1 byte validation 的 object，且 keys **恰好**为
  `cacheReadTokens,inputTokens,outputTokens`，值均为 canonical 非负整数
  `0...Int64.max`，无额外 key；标准零值为
  `{"cacheReadTokens":0,"inputTokens":0,"outputTokens":0}`。
- §6.3 的 planning-specific usage overflow 不是
  `DurableWorkFailure(usageJson:nil)`：已有可计量 provider turn 后，若 exact
  operands 的 aggregate 无法放入 Int64，必须走专用
  `PlanningUsageOverflowEvidenceV1` terminal path。该路径不改变本节 nil 的唯一
  含义，也不得向通用 `retryOrFail` 伪造 nil、prefix 或 saturated usage。
- `PlanningUsageOverflowEvidenceV1` 是 private typed canonical evidence，固定
  两种互斥 JSON shape：
  - turn aggregate 恰有
    `contractVersion=1`、`reason="turn_aggregate"`、
    `priorAccumulatedUsage`、`incomingUsage`、`overflowFields`；
  - Mission projection 恰有
    `contractVersion=1`、`reason="mission_projection"`、
    `existingSpentTokens`、`attemptUsage`、`overflowFields`。
  每个 Usage operand 恰有 non-negative Int64
  `cacheReadTokens,inputTokens,outputTokens`；`existingSpentTokens` 也是
  non-negative Int64。`overflowFields` 非空、去重并按 UTF-8 bytes 升序：
  turn aggregate 只允许三个 token field；Mission projection 只允许
  `attemptBillableTokens|spentTokens`。
- evidence 保存造成 overflow 的 exact representable operands，不保存无法表示的
  aggregate。它只能由 private typed Codable → `CanonicalJSONV1.encode` 生成，
  并直接插入 kind=`planning_usage_overflow` 的 Event；不得经过 `JSONValue`、
  `Double`、raw `JSONSerialization` 或第二 canonical parser。
- `UsageOverflowError` 只是 planning 控制信号；持久 work/attempt/Mission 的稳定
  error code 固定 `usage_overflow`。专用 overflow terminal command 不构造
  `DurableWorkFailure`，也不给本节 Codable shape 增加第五个 key。
- `validateDurableWorkUsageObject` 是 `CanonicalJSONV1` 的 internal typed scalar
  extractor：它只读取同一个 private byte-backed AST，要求 exact 三 key 与
  canonical non-negative Int64 token；不得调用 `JSONDecoder` 或建立第二 parser。
- public initializer 验证全部不变量；custom `init(from:)` decode 后必须调用同一
  validation 并把失败映射为 `DecodingError.dataCorrupted`，禁止 synthesized
  decoder 绕过。Codable object 必须恰有
  `code,message,disposition,usageJson` 四个 key、不得有额外 key；两个 optional
  为 nil 时仍编码 explicit JSON `null`，缺 key 不等于 nil。全部属性 immutable，
  成功构造后 `encode(to:)` 按此固定 shape 编码。
- `retryOrFail` 只 switch `failure.disposition`：
  `.deterministic` 首次即 terminal failed；`.transient` 且
  `claim.attempt < work.maxAttempts` 才按 5/30/120 秒 schedule，否则 terminal
  failed。不得从 code/message/usageJson、HTTP 状态或 Error 类型再次猜 disposition。
  调用方负责在构造 failure 前完成外部错误分类；invalid failure 在 transaction 前
  抛出且零写入。
- A1a acceptance 之后，A1b 必须把 `planning` 封为 generic mutation/dispatch
  reserved kind，但不改 A1a 的历史 verdict。generic `enqueue` 发现
  `kind=.planning` 时，在任何 time/JSON/hash/pool/SQL/UUID 前抛公开稳定
  `PlanningRequiresDurablePlanningCapabilityError`；`claimNext`、
  `nextClaimableDate`、`cancelActive`、`adoptInterrupted` 对包含 `.planning` 的
  kinds（包括 mixed kinds）整次拒绝，不得过滤后继续。它们保持既有参数验证优先级，
  随后在打开 pool/SQL 前抛同一错误；若 kinds 同时含 planning/campDeletion，按
  caller原顺序遇到的第一个 reserved kind抛其对应typed error，validation后才去重。
  这是A1b phase对§6.2 dual-reserved list case的精化；单独campDeletion的既有错误
  不变。
  `renewLease`、`complete`、
  `retryOrFail`、`cancel` 先执行不需要 target kind 的既有参数验证，再在 transaction
  读取目标 work 后、任何 state/idempotent branch/CAS/UPDATE/event/closure 前抛
  同一错误；generic cancel 对已 canceled planning 也不得返回
  `alreadyCanceled`。public 与同名 Core-internal generic helpers 使用同一 ban。
  `activeWork/latestWork/work(id:)` 仍是允许读取 planning 的无 mutation seam。
  planning enqueue/claim/next-due/renew/adopt/terminal/cancel 只能经 §6.3 的
  specialized owner；不得调用 generic helper 绕过 durable mode 与 Mission
  projection。

### 6.3 Planning

- `PlanningWorkInput` 精确只含
  `plannerModel:String`、`runtimeProfileId:String`、
  `promptContractVersion:Int = 1`；只用 `CanonicalJSONV1` 产生 work
  `inputJson/inputHash`。worker 仍从持久 Mission/Squad 读取 goal、ordered roster、
  workspace 与 Camp；不得在领取时读取“当前默认供给线”造成漂移。
- 唯一例外是永不 claim、attempt=0即 terminal 的 legacy recovery work：其
  `LegacyPlanningTerminalInputV1` exact shape为
  `contractVersion=1,terminalCode:String`，allowed terminalCode只含
  `emergency_halt_during_planning|legacy_planning_profile_unresolved|
  legacy_planning_model_unavailable|legacy_planning_profile_cli_unsupported`。
  它同样只经 `CanonicalJSONV1` 编码/hash；不得给 `PlanningWorkInput` 增第四字段，
  不得让该 terminal-only input进入resolver/Planner。
- 新建不可变 `MissionPlanningStartIdentityV1`，字段精确为：
  `contractVersion = 1`、`goal`、ordered `companionIds`、`workspacePath`、
  按现行规则规范化并实际持久化的 `budgetTokens`、resolved non-null `campId`、
  `autonomy` 与完整 `planningInput`。它只用 `CanonicalJSONV1` 编码，并作为首写
  唯一 `mission_created.payloadJson`；payload 根级继续保留 `goal`。
  `traceId` 不属于 identity。
- 新开工唯一 public command 是
  `enqueueMissionPlanning(...,planningInput:idempotencyKey:traceId:
  planningProviderResolver:) throws -> (missionId,workId)`。顺序固定为：
  process-local dispatch gate → same-key persisted identity/work-graph validation →
  仅 absent-key 执行完整 resolver preflight → 单一 transaction 重验 race/profile/
  Camp 并写 Squad、Mission、`mission_created`、`plan_started` 与 planning work →
  supervisor kick。
- same-key 已存在时，必须在生成任何 Squad/Mission/work UUID、读取 credential/
  catalog 或调用 provider factory 前，验证原 work：
  `kind=planning`、`aggregateType=mission`、`maxAttempts=4`、canonical
  input/hash、aggregate Mission、Squad/Camp 与唯一 `mission_created` identity
  全部逐字相同。相同则零写返回原 `(missionId,workId)`，保留首次 work trace；
  任一差异抛 `DurableWorkReplayConflictError`。replay 不依赖当前 profile、
  credential、catalog 或 endpoint，但仍不得越过 dispatch halt gate。incoming
  `campId` 非 nil 时必须等于 persisted resolved Camp；incoming 为 nil 时复用
  persisted identity 的 Camp，不重新解析当前 default。
- same-key absent 时才做只读 planning preflight。它必须明确 Runtime Profile
  存在、不是 `cli_codex|cli_claude`、model 在该 profile 的可信 catalog 中；
  CLI profile 固定为 `planning_profile_cli_unsupported`。preflight 在任何
  Squad/Mission/work 或默认 Camp 写入前完成。transaction 首先再次检查并发
  winner；存在则复用同一 validator。仍 absent 才重读 exact profile ID/kind、
  以稳定顺序解析显式或默认 Camp，并在所有验证完成后生成 IDs。需要创建默认
  Camp/Guide 时也必须与 Mission/work 在同一 transaction 回滚，不能留下半开工。
- 四个入口的 idempotency key 与捕获规则固定为：
  - 手动开工：`mission-start:user:<UUID>:v1`；AppStore 在创建 Task 前的同一
    MainActor turn 一次捕获 command UUID、trace UUID、exact profile ID/model、
    budget 与 autonomy，同一次命令重试复用；
  - Coding Ranch candidate：
    `mission-start:candidate:<draftId>:v1`；
  - schedule：
    `mission-start:schedule:<scheduleId>:<checked-UTC-milliseconds>:v1`；
    `scheduledFireDate.timeIntervalSince1970.isFinite` 是有效 slot 的前置条件。
    Coordinator 必须在生成 UUID、调用 `selectRuntime`、构造 preparation `Result`
    与调用 `claimScheduleFire` 前检查；non-finite 直接抛现有 package
    `InvalidSchedulePlanningFireTimeError`，runtime selection 调用数为零，且
    Mission/work/event/`lastFiredAt` 全部零写。finite 时 timestamp/profile/model
    selection 在既有 claim 前只读捕获为同一个 `Result`；checked UTC milliseconds
    超出 `Int64` 仍保留为该 `Result.failure`，先沿用 `claimScheduleFire` 占有
    slot，再恰好写一次 missed 且不创建 Mission；
  - confirmed proposal：
    `mission-start:proposal:<proposalId>:v1`。
  非手动入口在第一次 `await` 前一次捕获 exact key、trace UUID、profile ID 与
  planner model；确定性 key 的跨进程 replay仍以首次 work trace 为权威。
- AppStore 以 process-local `PendingManualMissionStart` 保存手动入口捕获的完整
  caller snapshot、command key 与 trace：相同 snapshot 的 preflight失败或
  enqueue已提交但 kick/返回失败后重试必须复用；收到 Mission ID并完成当前
  start call 后清除。goal/ordered roster/workspace/normalized budget/explicit
  Camp/autonomy/profile/model 任一改变，或用户明确开始新的 command，必须生成新
  key/trace。进程重启不恢复该临时对象；已提交 work由 ledger recovery接管，不能
  因缺少内存 command而重复 enqueue。
- 四入口的可执行验证 owner 固定为
  `Sources/AgentLoopCore/Kernel/Orchestrator.swift` 内的
  `@MainActor package final class PlanningEntryCoordinator` 及其 package-only
  immutable DTO。`package` 让同一实现同时被 `AgentLoopApp` 与现有
  `AgentLoopTestSuite` target调用，但不扩大 AgentLoopCore public API，也不修改
  `Package.swift`、`Package.resolved`、`Sources/RunTests/main.swift` 或 target
  graph。Coordinator只拥有入口捕获、manual pending compare-and-clear、
  candidate `existing → start → link` 两步顺序、proposal pre-Task capture，以及
  schedule
  `non-finite preguard → finite checked milliseconds + runtime selection Result →
  existing claim → start/missed` 顺序；durable planning状态机仍只属于
  AppDatabase/Supervisor。
  AppStore manual/proposal必须在创建 Task 前委托，candidate必须在第一次 await前
  capture并把 start/link全部委托，MissionScheduler不得再直接 claim或调用
  `Orchestrator.startMission`。UI reload/toast/broadcast/navigation仍留在 App。
  TestSuite必须直接功能测试该 package coordinator，并以可失败的 source-range
  parser检查三个 App文件的真实委托与 token order；只测同构 helper或简单 substring
  不算通过。
- Schedule 持久化只允许一个编码边界变更：
  `ScheduleRecord.databaseDateEncodingStrategy(for:)` 只对 `lastFiredAt` 使用 GRDB
  `.timeIntervalSince1970` numeric/Double encoding，其他 Date 列继续
  `.deferredToDate`；database decoder 必须继续为 `.deferredToDate`，同时读取既有
  `yyyy-MM-dd HH:mm:ss.SSS` TEXT 与新 numeric epoch seconds，禁止改成
  `.timeIntervalSince1970` decoder。`DATETIME` NUMERIC affinity 可把无小数 Double
  保存为 INTEGER，因此 `lastFiredAt` storage class 允许 INTEGER/REAL，禁止 TEXT
  与空串，不得固定 `typeof=REAL`。这不改变 schema/DDL/literal、claim CAS、有效
  finite slot、逻辑 `lastFiredAt` 值或 claim 后 missed 语义；ScheduleStore 不检查
  non-finite、不把它转成 missed，也不成为第二个 checked/claim owner。
- `PlanningProviderResolver.resolvePlanningProvider(profileId:model:) throws`
  是独立 typed contract；`enqueueMissionPlanning` 必须接收 required
  `planningProviderResolver:any PlanningProviderResolver`。Orchestrator initializer
  持有并向 enqueue 与 Supervisor 传递同一 resolver。AppDatabase 不构造 resolver、
  OAuth token refresher 或 provider，也不读 current default。resolver 只按传入 ID
  读取 profile，绝不 fallback 到 Companion/default profile。规范表如下：

| RuntimeProfileKind | 允许模型的权威来源 | 必需凭据 | endpoint / provider | 固定失败码 |
|---|---|---|---|---|
| `anthropic_api` official host | `unique(cachedCatalog + manualModels)`；两者都空即失败，不读取全局 fallback/modelChoices | `profile.credentialAccount` 非空且该 Keychain 项为非空值 | `ProviderEndpoint.normalizedBaseURL(profile.baseURL)`；`LLMProviderFactory` + `anthropicMessages` | profile 缺失 `runtime_profile_not_found`；catalog 空 `model_catalog_unavailable`；模型不在集合 `planning_model_unsupported`；account 字段空 `credential_account_missing`；项不存在/空 `credential_not_found`；非 not-found OSStatus `credential_read_failed`；URL 无效 `endpoint_invalid`；构造失败 `provider_construction_failed` |
| `openai_api` official host | 同上 | 同上 | normalized base URL；`LLMProviderFactory` + `openAIChatCompletions` | 同上 |
| `anthropic_api` / `openai_api` custom host | `unique(profile-scoped modelChoices + manualModels)`；refresh 写入的 custom remote models 属于 modelChoices；两者都空即 `model_catalog_unavailable`；不得使用 built-in/global fallback | 同 API 行 | normalized custom base URL；按 kind 选择上述 factory format | 同 API 行 |
| `chatgpt_oauth` | 只读 `KernelDefaults.chatGPTStaticModels`；忽略 cached/modelChoices/manual；静态表空为 `model_catalog_unavailable` | primary：`profile.credentialAccount` 对应 access token；secondary：固定 Keychain account `oauth-chatgpt-account-id` | profile.baseURL 不参与 transport；固定 `OpenAIResponsesProvider(accessToken,accountID,model,tokenRefresher)` | primary account 字段空/项缺失/读取失败沿用 `credential_account_missing|credential_not_found|credential_read_failed`；secondary 缺失/空 `oauth_account_id_not_found`，读取失败 `oauth_account_id_read_failed`；其他同上 |
| `cli_codex` / `cli_claude` | P1 planning 不读取目录 | 不读取 | 不构造 | `planning_profile_cli_unsupported` |

official/custom 判定唯一使用 `ModelCatalogService.isOfficialCatalogProfile`；catalog
条目在 trim + 去重后精确字符串匹配 model。任何 Keychain `errSecItemNotFound`
映射“not_found”，其他 OSStatus 映射“read_failed”，不得用 `try?` 合并。

absent-key preflight 在任何 Squad/Mission/work/default-Camp 写入前完整执行上表：
读取 exact profile、catalog、全部凭据、normalize endpoint 并成功构造 provider，
然后丢弃该短生命周期实例。enqueue transaction 在任何 insert/UUID 前还要重读
exact profile ID/kind，并要求
`kernel_control.global.dispatchMode == running`；missing/corrupt/halted、profile
missing、CLI kind 或 kind drift 都零业务写。claim 后使用 work 中捕获的同一
profile ID/model 再完整执行上表；catalog/model、credential 或 endpoint 已失效时
deterministic terminal failure。两次都禁止 default fallback。测试注入 in-memory
profile/catalog/credential sources 和 provider factory，不读真实
Keychain/UserDefaults。
- `Planner.proposeDurable` 每个 durable attempt 最多做一次初始 provider turn；
  schema/tool-use 无效时允许一次带错误反馈的纠正 turn，但 transport/provider
  error 立即抛含稳定 code、retry disposition 和已消耗 usage 的
  `PlanningAttemptFailure`。Planner 层不得 loop/sleep/retry，也不把 provider
  error 变成 fallback card；concrete Provider 在同一次 `streamTurn` 内既有的
  transport adapter retry、OAuth refresh 或 stream fallback 保持原边界，不算第二个
  Planner turn。第二次仍无效则
  `planning_contract_invalid` deterministic failure。P1 durable path 不调用旧
  `Planner.propose`/`Planner.fallback`。
- runtime provider error mapping 固定为：
  `URLError -> planning_transport_error/transient`；
  HTTP `429|500...599`、`overloadedRetriesExhausted` 以及 API type
  `overloaded_error|rate_limit_error|server_error ->
  planning_provider_unavailable/transient`；
  `malformedStream -> planning_provider_malformed_response/transient`；
  unauthorized → `planning_provider_unauthorized/deterministic`；
  其他 HTTP → `planning_provider_http_error/deterministic`；
  其他 API error → `planning_provider_api_error/deterministic`；
  未分类 Error → `planning_provider_failed/deterministic`。
  `CancellationError` 不构造 failure，由 cancel/halt owner 收口。持久 message
  只能是 code 对应的静态安全摘要，不得保存 raw Error、HTTP body、credential、
  account ID 或 OAuth callback。
- 初始 turn 与 correction turn 的 Usage 必须逐字段用
  `addingReportingOverflow` 先算三个临时值，三字段全部成功后才替换累计 Usage。
  任一字段 overflow 立即抛携带 §6.2.2 exact turn-aggregate evidence 的
  deterministic `UsageOverflowError`；不得触发 Swift trap、部分累计、饱和
  success 或再次调用 provider。
- 每个 provider turn 的 Usage 在成为“可计量 turn”前必须验证三字段 non-negative。
  首轮出现负值时，以 `planning_usage_invalid/deterministic` 且 `usage=nil` 收口，
  因为没有完成有效计量；correction turn出现负值时，同一 failure必须携此前已完成
  的 exact valid accumulated Usage。不得保存负 counter、写 token event、继续调用
  provider或把 invalid value夹紧为零。
- `commitPlanningSuccess(claim,result,now:)` 是唯一规划成功写 API。单一
  transaction 在任何 mutation 前验证 latest claim CAS、durable dispatch mode 为
  `running`、Mission 仍为 planning，并要求 `result.fallbackReason == nil`：
  nil 不写 `plan_fallback`；non-nil 以稳定码
  `unexpected_planning_fallback` 拒绝本次 success，command 零写，随后只由
  planning failure owner以 deterministic failure和同一个result exact Usage收口。
  normal success 以 checked arithmetic 处理 exact
  usage，写恰好一条 canonical `planning_tokens`，创建全部 Card、更新
  goalRefined/Mission rollup，写恰好一条 `plan_completed` 并关闭
  attempt/event/work。fallback failure-injection 点只测试 nil-policy guard，不表示
  nil 时落 event。任何一步失败都完整回滚。现有 `recordPlanningTokens`、
  `recordPlanFallback`、`planMission` 不得从 durable planning path 调用。
- unexpected fallback 的唯一生产测试接缝固定为
  matching-`#if DEBUG` 中的 package actor method
  `injectOwnedSuccessProposalForTesting(workId:result:)`。它只接收已 owned 的
  `workId` 与 `PlanResult`，不得暴露或接收任意 `PlanningTerminalProposal`、token
  或 generation；entry 不存在或不 owned 时 typed fail-fast。实现必须从既有 owned
  entry 读取 token/generation，并复用生产
  provider-completion → pending proposal → `attemptPendingTerminalProposal`
  路径，继续经过 generation/token/latest-claim gate；不得直接调用 Store、绕过
  transaction 或重呼 provider。调用它的 `@Test`/helper 必须位于匹配的
  `#if DEBUG`；release Core 不得包含该符号，Package/target graph 保持不变。
- `planning_tokens` payload 恰有
  `cacheReadTokens,inputTokens,outputTokens` 三个 non-negative Int64 key，只能由
  private typed Codable → `CanonicalJSONV1.encode` → direct Event insert；
  不得经过 `JSONValue.number(Double)`。Mission `spentTokens` 只 checked 累加
  input+output；cache-read 原值只在 event。nil usage 不写 token event；non-nil
  explicit zero usage 仍写标准零值 event；negative usage 在 SQL 前拒绝。
- `recordPlanningAttemptFailure` 接收同源 typed `PlanningAttemptFailure`。该类型
  只允许由 `code/safeMessage/disposition/usage:Usage?` validating initializer
  构造；initializer 先验证 non-negative Usage，再从同一个 typed usage 生成
  canonical `usageJson` 与 `DurableWorkFailure`。不得公开接受可彼此不一致的
  `(usage,DurableWorkFailure)` initializer。transient failure 在同一 transaction
  记 exact usage、关闭 attempt、追加 failed event并设 retryScheduled；
  deterministic 或耗尽 failure 在同一 transaction 进一步把 Mission 从 planning
  置 failed、写 `mission_failed` 并 terminalize work。claim、dispatch、usage 或
  projection 任一步失败全部回滚；不得从裸 `usageJson` 反解析 Usage。
- turn aggregate overflow 与 Mission projection overflow 都走 planning-only
  overflow terminal command。它在单一 transaction 验证 latest claim、
  planning work/Mission 关系与 durable dispatch mode，写 exact canonical
  `planning_usage_overflow` evidence，以 `usage_overflow` 关闭 attempt/work、
  把 Mission 置 failed并写终态 events。它不写 `planning_tokens`、不改变 Mission
  原有 exact `spentTokens`、不 retry、不建 Card、不写 fallback、不返回 success；
  即使原始 provider error 为 transient，usage rollup overflow也由此 deterministic
  终止。
- normal success/failure usage mutation先 checked 计算
  `inputTokens + outputTokens`，再 checked 计算与 existing Mission
  `spentTokens` 的和。前者 overflow evidence 使用
  `overflowFields=["attemptBillableTokens"]`，后者使用 `["spentTokens"]`；
  多字段时去重排序。projection overflow 必须在当前 transaction 内改走上述
  terminal branch，不能先提交，也不能抛出后再让普通 failure transaction对同一
  usage 二次求和。无整数 overflow 但 usage 超预算时仍 exact 入账并建卡，随后由
  既有预算门阻止 Card dispatch。
- legacy repair 固定 API 为
  `repairLegacyPlanningMissions(profileModels:now:)`。它按 Mission ID 排序逐条
  transaction 处理 `.planning` 且不存在任何 planning work 的 Mission：
  1. transaction 首先读取 exact durable dispatch mode；missing/corrupt立即
     fail-closed；
  2. mode=`halted` 时不解析 profile/model：用 idempotency key
     `legacy-planning:<missionId>:v1` 在同一 transaction 创建 queued attempt=0
     work并立即复用 queued-work cancel primitive，以
     `reason="emergency_halt_during_planning"` 得到 canceled work + failed Mission
     + 恰好一条 `mission_failed`，且零 attempt rows/attempt events。work
     errorCode=`work_canceled`、errorMessage为上述reason。该分支是 halt control
     owner的一部分，不是第三种 halted terminal语义；
  3. mode=`running` 时，有任何 Card 必须抛 package
     `LegacyPlanningHasCardsError` fail-closed；其 exact shape 为
     `package struct LegacyPlanningHasCardsError: Error, Sendable, Equatable`，
     且只含 `package let code = "legacy_planning_has_cards"` 与
     `package init() {}`，不增加 public API、missionId 或额外 payload。该分支
     必须零 DB 写，error type、exact code 以及 Mission/Card/work/event 完整
     transaction snapshot 前后不变都必须可直接断言；
  4. 若所有 Squad 成员存在、每人 `runtimeProfileId` 非空且唯一集合恰为一个，使用
     该 ID；
  5. 否则仅当数据库恰有一个 `isDefault = true` profile 时使用它；
  6. 从启动时注入的 `profileModels[profileId]` 取得非空 planner model；
  7. profile解析不存在/不唯一使用
     `legacy_planning_profile_unresolved`；CLI使用
     `legacy_planning_profile_cli_unsupported`；model missing/empty使用
     `legacy_planning_model_unavailable`。以该code构造
     `LegacyPlanningTerminalInputV1`，插入 idempotency key
     `legacy-planning:<missionId>:v1` 的 attempt=0 terminal failed work，并原子把
     Mission 置 failed、写恰好一条含同code的 `mission_failed`；work errorCode为
     同code、errorMessage=nil，且零attempt rows/attempt events；绝不猜；
  8. 可用时以同一 key 创建 queued repair work。
  所有legacy work固定 `maxAttempts=4`，trace固定
  `legacy-planning:<missionId>:trace:v1`。同 key 重放验证
  inputHash/aggregate/Camp/maxAttempts/trace与 terminal reason；重复启动不创建
  第二条 work。mode在每个Mission transaction内线性化：读到running后已提交
  的legacy terminal事实先于随后发生的halt，不得被改写；读到halted则只能走上述
  emergency-halt cancel语义。
- generic Store `.planning` ban 不得妨碍 suppressed startup recovery。唯一
  interrupted recovery command固定为 Core-internal
  `adoptInterruptedPlanning(currentWorkerId:now:)`；它与
  `claimNextPlanning/nextClaimablePlanningDate/renewPlanningLease`、success/
  failure/overflow/single cancel/bulk cancel及 legacy repair共同使用
  `DurableWorkStore.swift` 内唯一 fileprivate planning ledger owner。AppDatabase
  是这些 specialized transaction 的唯一调用边界；Supervisor只能调用
  AppDatabase specialized commands与 Store read seams，不能调用 generic
  mutation/dispatch API。adoption在 process-local suppressed下执行，不要求 durable
  running；随后 restored halted 的同一 bulk cleanup必须收口刚 adopted 的 rows。
- `DurableWorkSupervisor` 持有独立于 lifecycle 的 process-local
  `dispatchSuppressed` 门闩，初始化即 suppressed；lifecycle 新增同样只存在于
  进程内的 `.recoveryReady`，二者都不是新持久状态。持久化 halt 失败时本进程仍
  保持 suppressed，不能因 SQLite 仍显示 running 而重开 provider。
- `recoverOnStartup` 顺序固定为：持有 StateDirectoryLock → runtime profile
  bootstrap/reconcile 完成并生成 profile-model snapshot → legacy repair →
  adoptInterrupted planning → 读取 exact
  `kernel_control.global.dispatchMode`：
  - `running`：Supervisor 只进入
    `lifecycle=.recoveryReady + dispatchSuppressed=true`，不得创建
    pump/timer、claim、resolve 或调用 provider。随后 Orchestrator 完成 Card
    orphan adoption 与 proposal healing，并重验 transition ownership 与 durable
    mode；全部成功后才允许 activation；
  - `halted`：保持 suppressed，在一个整体 SQLite transaction 中对全部 active
    planning 执行与
    `cancelPlanning(...,reason:"emergency_halt_during_planning")` 相同的 work
    terminal + Mission failed projection；全部成功后 Supervisor lifecycle 可为
    running，但保持 quiescent，不建 pump/timer、不 claim、不 resolve/call
    provider，随后只执行不产生 dispatch 的既有恢复步骤；
  - missing/corrupt：fail closed，保持 suppressed，零 provider-path 写入并留下
    可观察错误。
  halted cleanup 任一点失败必须整体回滚、保持 suppressed 和可重试证据；
  `resume` 不得先把 durable mode 改为 running。
- 唯一 actor-isolated internal activation API 是
  `activateAfterOrchestratorRecovery()`。它必须原子要求 lifecycle 仍为
  `.recoveryReady`、仍 suppressed、无 fatal latch、无 halt cleanup pending，并在
  方法内部重读 exact durable mode 仍为 `running`；全部成立才切
  lifecycle=`.running`、打开 gate、创建唯一 pump/timer并 kick 恰好一次。
  任何内部 suspension 返回 actor 后都必须重验上述全部 activation 前置与 control
  generation；切 lifecycle、开 gate、创建 pump/timer 与 kick 构成同一个无
  suspension 线性化段，禁止依赖随后排队的 re-suppress Task 修正时序。
  Orchestrator 在 Card adoption + proposal healing 后、调用 activation 前后都必须
  重验 transition token；activation 内部 durable-mode read 是最终 DB fence。
  仍满足 `.recoveryReady` 与有效 startup eligibility/transition token 的
  mode-read或内部 gate failure，必须保持错误可观察、
  `.recoveryReady + suppressed` 且可显式重试；若 lifecycle、generation、
  eligibility或transition token 已被 control 改变，则 stale activation 必须保留
  control-owned state并失败，不得还原 `.recoveryReady` 或再走 startup carve-out。
  既有 post-failure `suppressForOrchestratorRecoveryFailure()` 不得作为最终合同。
- Card recovery 失败时 durable mode 保持 `running`、Supervisor 保持
  `.recoveryReady + suppressed` 且从未激活；不得新增 planning terminal write、
  halt bulk cleanup 或
  `camp_halted/camp_resumed`。此前合法提交的 legacy repair/adoption 事实不回滚、
  不重复。显式`resume()`对durable-running startup failure只有两个互斥的
  process-local分支，二者都要求exact durable mode仍为running、无control/halt
  cleanup pending且当前retry attempt transition token有效：
  1. 第一阶段失败并回到`.initialized`时，只有first-phase retry eligibility为true
     才重跑完整`recoverOnStartup`；成功进入`.recoveryReady`后再继续Card recovery；
  2. 已在`.recoveryReady`时，只有Card-retry eligibility为true才走R11新增
     carve-out，仅重试Card adoption、proposal healing与activation，不得重复
     planning repair/adoption。
  二者都不得伪造durable transition。durable-halted startup/cleanup failure或任一
  control已清除eligibility/token时继续走既有control/recovery路径，不得套用
  durable-running retry。
- `emergencyStop` 与 shutdown 都可从 `.recoveryReady` 进入；shutdown还可从
  `.initialized|.recovering` 直接进入`.shuttingDown`并清除全部startup retry
  eligibility/token。`suppressForEmergencyStop()`在`.initialized|.recovering`
  固定抛`SupervisorRecoveryRequiredError`且零状态mutation，因此不算control
  winner。合法control与activation以Supervisor actor顺序作为线性化点。
  `suppressForEmergencyStop()` 先取得顺序时，
  必须在同一个 actor turn、任何 internal await 前把 `.recoveryReady` 消费为
  `.running + dispatchSuppressed=true + haltCleanupPending=true`，checked 推进
  generation并停止/撤销全部本地 dispatch ownership；这是 control-only
  conversion，不得开 gate/pump，使后到 activation 因 lifecycle gate 失败，并
  原样复用既有 `didCommitEmergencyPlanningCleanup` 与 halted resume control
  路径。shutdown 先取得顺序时从当前非终态lifecycle直接进入 `.shuttingDown`。
  任一 control winner 同时使当前 running-startup first-phase retry eligibility、
  Card-retry eligibility与当前attempt transition token全部失效，即使 durable halt
  持久化失败也不得误走任一durable-running startup retry。activation先取得顺序时，
  后到control继续沿
  既有 suppression、durable transition 与 bulk cleanup 合同收口。任何 stale
  startup recovery 都不得覆盖已线性化的 control 状态。
- 上述 legacy repair 与 interrupted adoption 是 process-local gate 已 suppressed
  时的 recovery-only control mutation，不是 provider path：它们允许在读取
  restored durable mode 前创建 repair work、把 interrupted attempt 关闭并排回
  queued，但全程不得创建 pump/timer、claim、resolve 或调用 provider。随后若读到
  `halted`，workless legacy Mission已经由 mode-aware repair使用同一halt cancel
  语义收口；同一个 bulk cleanup继续覆盖刚 repair/adopt 的其余 active rows。
  结束后不得遗留 queued/running/retryScheduled planning。此例外不开放 halted下的
  普通 enqueue/claim/renew/terminal proposal。
- `enqueueMissionPlanning`、planning claim、next-due read、lease renew、
  success/failure/overflow terminal proposal 的每个 SQLite transaction 都必须
  要求 `kernel_control.global.dispatchMode == running`。missing、corrupt 或
  halted 时 provider-path 零写入。显式单 work cancel 与 halt bulk cancel 是唯一
  允许在 halted 下写 planning terminal projection 的控制路径。
- `emergencyStop` 进入 Supervisor 的第一个 actor turn、任何 `await` 前必须设置
  suppressed、checked 推进 generation、停止 pump/next-due/renewal、撤销 owned
  attempt terminal-commit permission，并向本地 provider Task 传播 cancellation。
  随后持久化 durable halted，再以一个整体 SQLite transaction bulk-cancel 全部
  active planning，reason 固定 `emergency_halt_during_planning`；任一
  work/attempt/Mission/event mutation 失败，整个 bulk cancel 回滚。不得等待不合作
  provider 后才开始 halt、Card 或进程清理。
- durable halt 持久化失败或 planning cleanup 失败时，本进程都继续
  suppressed，错误必须可见，resume 被阻断。除上述 durable-running
  startup-recovery carve-out 外，`resume` 必须要求 durable mode 已为 halted，并
  先完成或重试全部 planning cleanup；只有 cleanup 全成功后才原子切换 durable
  mode 为 running，最后打开 process-local gate并 kick 恰好一次。
- generation gate 与 durable dispatch gate 必须共同覆盖
  halt-vs-enqueue/preflight、halt-after-response、halt-vs-claim、
  halt-vs-renew、halt-vs-success/failure/overflow terminal proposal。任一 loser
  零 tokens、Cards、fallback 或重复 terminal event；halt bulk cancel 成为唯一
  terminal owner。
- Supervisor error ownership固定为：
  - stale claim/version、generation/task-token loser和 durable halted 是预期控制
    竞争；只取消/移除匹配 owned Task或等待 halt owner，不进入全局 fatal；
  - success/failure/overflow terminal transaction 的可回滚数据库错误保留
    ownership与 typed pending proposal；只有下一次 lease renew成功或显式 kick
    后才重试同一 proposal，不重呼 provider；
  - terminal validation/invariant corruption、missing/corrupt kernel control，
    以及 claim/next-due/renew 的非 stale错误进入 observable fatal latch：
    保持 ledger、不再派发、取消本地 provider并让 waiters收到 typed fatal error；
  - pending proposal期间若 renew出现非 stale错误，同样进入 fatal latch。任何
    fatal path都不得用 `try?`、移除持久 work或谎报 idle/terminal。
- App 重启会收编 planning work；不能只收编 `running` Card。
- provider 忽略取消时，stale lease / version CAS 必须阻止其记账或建卡。
- R11 最小命名测试固定为：
  `scheduleExtremeFiniteLastFiredAtPersistsNumericallyReloadsAndDedupes`、
  `scheduleLegacyTextLastFiredAtRemainsReadable`、
  `scheduleDateEncodingChangesOnlyLastFiredAt`、
  `nonFiniteScheduleFireFailsBeforeClaimWithoutWrites`、
  `runningStartupDoesNotDispatchPlanningBeforeCardOrphanAdoptionCompletes`、
  `startupCardOrphanAdoptionFailureKeepsPlanningSuppressedWithoutDurableTransition`、
  `explicitRetryAfterStartupCardRecoveryFailureActivatesSupervisorExactlyOnce`、
  `startupRecoveryRetryWritesNoCampHaltedOrCampResumedEvent`、
  `staleStartupRecoveryCannotActivateAfterConcurrentControlTransition`、
  `legacyPlanningWithCardsFailsClosedWithExactTypedErrorAndZeroWrites` 与
  `unexpectedPlanningFallbackTerminalizesThroughFailureOwner`。最后一项必须证明
  unexpected fallback 连同同一个 typed Usage 由 failure owner deterministic
  terminalize，且不写 fallback event、不重呼 provider。
  其中 recovery-retry event test必须含
  `.initialized + first-phase retry eligibility`完整重跑与
  `.recoveryReady + Card-retry eligibility` Card-only重试两个子场景；stale-control
  test必须分别覆盖shutdown清first-phase eligibility/token与emergencyStop清Card
  eligibility/token。
- R11 不授权新增 migration/schema/持久 recovery state/`schedule_fire`，不授权
  修改 Schedule claim CAS、有效 finite slot、逻辑 `lastFiredAt`/missed 产品语义、
  既有 DDL/literal，也不授权以 post-failure re-suppress、临时 durable halt、bulk
  cancel 或伪造 camp event 代替两阶段 activation。禁止新增 release-visible test
  API、第二 planning/Schedule owner、真实 sleep/轮询、`try?`、测试放宽，禁止修改
  `Package.swift`、`Package.resolved`、`Sources/RunTests/main.swift` 或 target
  graph；Review11 通过前 A1b 产品与测试代码继续冻结。

### 6.4 Rumination

#### 6.4.1 命令、输入、generation 与原子开工

- `RuminationWorkInput` 是 normal durable rumination 的唯一输入，exact Codable
  keys 为 `model:String`、`runtimeProfileId:String`、
  `pipelineVersion:String`，不得缺 key 或含额外 key。`model` 与
  `runtimeProfileId` 必须 nonblank，按捕获原值逐字保存，不 trim/normalize；
  `pipelineVersion` 必须精确为 `coding-ranch-v1`。输入只经
  `CanonicalJSONV1` 编码、hash 和验证。
- normal work 固定 `kind=rumination`、`aggregateType=ingestion`、
  `aggregateId=ingestion.id`、`maxAttempts=4`。`IngestionItem.attempt` 表示用户
  发起的 rumination generation，不表示 ledger 内部 durable retry：只有新用户
  command 原子 checked `+1`，同一 work 的 5/30/120 秒重试不再增加它。
- normal idempotency key 精确为
  `rumination-start:<ingestionId>:<generation>:v1`；generation 是 transaction
  所见前一 `IngestionItem.attempt + 1`。任一 Int overflow 在 SQL 前 fail-fast。
  legacy key 精确为 `legacy-rumination:<ingestionId>`，不得追加 `:v1`；legacy
  trace 精确为 `legacy-rumination:<ingestionId>:trace:v1`。
- App normal command 的 trace UUID 必须在 MainActor 同一 turn、第一次
  `Task`/`await` 前只生成一次。package 同步
  `AppDatabase.prepareRuminationStart(ingestionId:)` 在该 turn 返回不可变 DTO：
  `replay(ingestionId,workId)`，或
  `new(ingestionId,expectedPreviousAttempt,generation,idempotencyKey)`。
  replay 不读取 current default/resolver；new 在同一 turn 捕获 exact default
  profile ID、该 profile 的 distill model（为空时使用该 profile 的
  `defaultModel`）、固定 pipeline 与 trace，组成唯一 `RuminationStartCommand`。
- 新 command 只允许 `IngestionItem.status=queued|failed`。`needsReview`、
  `materialized`、`discarded` 均拒绝；`ruminating` 且存在完整 active rumination
  graph 时返回原 work，不读取 resolver/default，也不增加 attempt；`ruminating`
  但没有完整 active graph 是 typed recovery-required/corruption，不得在用户入口
  临时修补。
- `Orchestrator` 只是 normal start/user retry 的 public façade，不得直接调用
  specialized Store start transaction、发布 projection milestone 或先行 kick。它把
  immutable preparation 与适用的唯一 `RuminationStartCommand` 交给自己私有持有的
  单一 Supervisor actor；Supervisor 是 absent preflight、start transaction、
  post-commit milestone 与后续 kick 的唯一 owner。
- specialized Store start operation 必须在 transaction 内重验 preparation 的
  ingestion、Camp、expected previous attempt、generation、key、status 与 active
  graph，并返回既有 `DurableWorkEnqueueResult`。只有本次 transaction 实际原子写入
  queued work、把 item 置 `ruminating`、checked 增加 `IngestionItem.attempt`、
  清 `errorText` 时才返回
  `work=<resulting queued work>, disposition=.inserted`；完整 same-key/active graph
  已存在时只可返回该原 work与`.replayed`，且整次 operation 必须零写。两种结果都
  不删除旧 result。相同 prepared DTO 若与不同 captured input 组合，必须在 resolver
  前按 same-key conflict 零写拒绝。
- `.inserted` 的 resulting work 必须是 exact `kind=.rumination`、
  `aggregateType=ingestion`、`aggregateId=ingestionId`、`attempt=0`、
  `state=queued` 且`version=1`；specialized transaction只做最小work insert与item
  update，不得在同一transaction二次推进新work version。Supervisor 在 Store
  同步返回后的**同一 actor turn、第一次 await
  或 actor reentrancy 前**，从该 resulting work构造
  `RuminationProjectionCommitIdentity(
  phaseIdentity:(ingestionId,work.id,attempt:0),
  workVersion:work.version)`，并原子 reserve §6.4.9 既有唯一 projection publisher
  与 Supervisor-owned process-local start-projection barrier。统一 global FIFO
  claim入口必须在任何 DB claim前检查全部 barrier：任一存在时，本轮对
  planning/rumination 都零 DB claim且不得跳过被挡住的 rumination head去 claim
  其他 work。已有 pump、timer、kick或 actor reentrancy均不能绕过。
  该 delivery 返回前不得解除 barrier、kick、claim、resolve/call provider、发送
  positive phase或向 Orchestrator return/throw；nonthrowing sink返回后才解除
  barrier，再重读 lifecycle、durable mode与该 work。只有仍
  running+active时才kick；control 已取消的 row绝不能被 claim。这样 queued work即使
  长时间未 claim，也先有唯一 App persisted-projection refresh。task cancellation/
  early return不得跳过已reserve delivery或barrier release。
- 两种 replay origin 必须在同一 Supervisor branch按 returned workId归一：
  App preparation 的 `replay(ingestionId,workId)` 不调用resolver或specialized Store
  start；concurrent new-command已完成absent preflight、但transaction重验时由Store
  返回`work=<original work>, disposition=.replayed`。两者本次都没有 DB commit，
  因此不得 reserve/synthesize
  `.projectionCommitted`、不得建立新 receipt或发第二 sink/event。同进程并发 replay
  只能按归一后的 `workId`查询 Supervisor保存的 original inserted delivery：
  若且仅若该 workId仍有 in-flight start barrier，等待/共用该既有 delivery，再
  conditional kick/return；二者都不得从 replay时的 current attempt/version
  构造identity。
  delivery已完成、barrier已移除时零等待、零第二 event。进程重启后 in-memory
  waiter/receipt均为空，
  App lifecycle必须先成功加载目标ingestion所属Camp的persisted Coding Ranch
  projection并标记ready、把active graph投影为`.recovering`，才允许normal
  start/retry command；load failure保持disabled/显式失败。此后的 replay仍为
  零 milestone，绝不能根据 current work version合成 refresh。同步 Store commit 到
  同 actor turn reservation之间没有可 await 的进程内窗口；若进程在其间死亡，只由
  上述 restart initial load恢复，不新增持久 receipt/checkpoint。
- 上述 replay/restart freshness 合同以当前产品的**同一 state root 单一
  production writer**为进入条件，不是假设。`AppStore`必须以
  `private let stateDirectoryLock: StateDirectoryLock`在自身完整lifetime强持有同一
  appSupport目录的锁，并在唯一production
  `AppDatabase(path:<same-root>/agentloop.sqlite)`调用前成功取得它。
  `StateDirectoryLock`必须继续使用`flock(fd, LOCK_EX | LOCK_NB)`；第二owner的
  `EACCES|EAGAIN`必须fail-fast，process/deinit释放descriptor与lock。production
  source tree（排除TestSuite）中`AppDatabase(path:)`调用点必须精确为1且位于
  AppStore该lock acquisition之后；任何第二production DB opener/writer、lock
  acquisition后移、锁成员不再lifetime-held或绕过同一state root lock都立即关闭
  A2 entry/completion gate。因而“本进程完成target-Camp ready snapshot后，另一
  production进程再commit active work”的TOCTOU在当前产品不可达；若owner进程在
  commit与process-local delivery之间死亡，OS释放lock，新进程只能先重新取得lock、
  再打开DB，并完成目标Camp persisted snapshot ready gate后才enable command。
  未来CLI、硬件或其他进程若要写同一state root，必须先开独立stage设计跨进程
  coordination/outbox；A2禁止绕锁或把它解释为已支持multi-writer。replay继续零
  milestone、零direct reload。
- start transaction、preflight、same-key conflict任一步 throw/rollback 都固定
  零 barrier/reservation/sink/event/kick，`IngestionItem.attempt`不变；下一次 prepare生成同一
  generation/key。commit后 delivery、return或 kick失败，下一次 prepare发现active
  graph并 replay首次 work/trace；terminal后用户 retry才生成下一generation/key。

#### 6.4.2 Captured runtime 与唯一 resolver 合同

- Supervisor 对 new command 的只读 preflight 顺序固定为：durable mode 必须 `running` →
  same-key/active graph replay validation → 仅 absent new command 执行完整
  `StrictPlanningProviderResolver` provider construction 并立即丢弃 → 单一
  transaction 重验 durable mode、exact profile ID/kind、Camp/ingestion graph 后
  enqueue。preflight 任一步失败零业务写。claim 时只用 work 中捕获的 exact
  profile/model 再 resolve；永不读取 current default、Companion model 或 fallback。
- `Sources/AgentLoopCore/Work/PlanningProviderResolver.swift` 与
  `StrictPlanningProviderResolver` 的已验收实现只读复用、byte-identical。A2 只能
  在既有允许文件中把其 typed planning resolution errors 映射为下列 rumination
  code 和静态安全中文；未知 resolver error 是全局 invariant/fatal，不得伪装成
  deterministic work failure：

| Rumination code | 唯一安全文案 |
|---|---|
| `rumination_profile_not_found` | `反刍所用运行配置不存在。` |
| `rumination_model_catalog_unavailable` | `反刍所用模型目录不可用。` |
| `rumination_model_unsupported` | `反刍所用模型不受该运行配置支持。` |
| `rumination_credential_account_missing` | `反刍运行配置缺少凭据账户。` |
| `rumination_credential_not_found` | `反刍所需凭据不存在。` |
| `rumination_credential_read_failed` | `反刍所需凭据读取失败。` |
| `rumination_endpoint_invalid` | `反刍运行配置的服务地址无效。` |
| `rumination_provider_construction_failed` | `反刍服务初始化失败。` |
| `rumination_oauth_account_id_not_found` | `反刍所需 OAuth 账户信息不存在。` |
| `rumination_oauth_account_id_read_failed` | `反刍所需 OAuth 账户信息读取失败。` |
| `rumination_profile_cli_unsupported` | `当前 CLI 运行配置不支持耐久反刍。` |

raw provider body、Error description、credential、account ID、OAuth callback/token
和秘密不得进入 DB、OS log 或 UI。

#### 6.4.3 封闭 generic `.rumination` 能力

- A2 新增 public no-payload
  `RuminationRequiresDurableRuminationCapabilityError`。generic public 与同名
  Core-internal mutation/scheduling API 全部拒绝 `.rumination`，rumination 只能经
  本节 specialized owner；`activeWork/latestWork/work(id:)` 继续允许只读。
- validation/error priority 固定为：
  - generic `enqueue` 在 time/JSON/hash/pool/SQL/UUID 前先抛 rumination ban；
  - `claimNext` 先执行现有 lease validation，再按 caller kinds 原顺序遇到的第一
    reserved kind 抛错；`nextClaimableDate`、`adoptInterrupted` 先 validate now，
    再按 caller 原顺序 ban；
  - `cancelActive` 按 caller 原顺序 ban，再 validate now、reason；
  - `renewLease` 先 lease validation；`complete` 先 now/output validation；
    `retryOrFail` 先 now/failure validation；`cancel` 先 now/reason validation；
    随后 transaction 读取 target，在任何 state/idempotent/CAS/UPDATE/event/
    business closure 前 ban。已 canceled rumination 也不得从 generic cancel 返回
    `alreadyCanceled`；
  - mixed `planning|rumination|campDeletion` kinds 始终按 caller 原顺序选择
    reserved error，validation 后才去重，不得过滤 reserved kind 后继续。
- `DurableWorkTests` 中把 `.rumination` 当普通 generic fixture 的旧用法必须机械改为
  `.coach`；确需第二 ordinary kind 时用 `.inputParsing`。`.rumination` 只保留给
  capability ban 与 A2 specialized tests，不得靠放宽 generic API 保旧测试。

#### 6.4.4 单一 Supervisor、全局 FIFO 与生命周期

- production 全局只能有一个由 `Orchestrator` 私有持有的
  `DurableWorkSupervisor`；App、Adapter、RuminationService 不得创建第二 owner。
  该 actor 同时拥有 planning 与 rumination 的 recovery、claim、lease renewal、
  pending terminal proposal、timer、idle/terminal wait、fatal latch、
  emergency halt/resume 和 bounded shutdown。
- specialized global claim/next-due 同时覆盖 `planning|rumination`，每个
  claim入口先执行 §6.4.1 start-projection barrier gate；任一 barrier存在时零DB
  claim且不得跨kind跳过。无 barrier时每个 transaction 先要求 durable
  mode=`running`，再按
  `createdAt ASC, rowid ASC` 做全局 FIFO；不得给任一 kind 固定优先级或造成饥饿，
  planning-only 相对顺序必须保持。现有 pump concurrency cap 不变；kick 先按
  `workId` 排序重试全部 owned pending proposals，再按全局 FIFO claim。
- `OwnedEntry` 增加 kind/aggregate identity，并只在内存保存对应 kind 的完整 typed
  terminal proposal。lease renewal、terminal commit、generation、wait 与 shutdown
  依 kind 选择 specialized operation，但共同使用一个 actor lifecycle。
- 同一 actor还唯一拥有 normal start/user retry 的 specialized Store调用、
  `.inserted|.replayed` 判定、attempt-zero start commit delivery gate与
  delivery-before-kick顺序；Orchestrator/App/Adapter/Service不得直接调用该 Store
  start operation或自行补 refresh。
- 为避免扩大 A2 文件，现有约 8 个 Supervisor 与约 56 个 Orchestrator 直接
  initializer 调用保持 source-compatible：§6.4.9 唯一新增 rumination
  phase-command sink默认 no-op；该默认值只允许既有 non-rumination tests使用，
  省略参数的 instance 不得 enqueue、adopt、claim、own 或发送任何 rumination
  command。AppStore production composition 与 production Orchestrator 必须显式
  传入 sink；source gate必须逐个锁定 production/省略-default callsite，证明不存在
  no-op production bypass。Orchestrator 的 legacy rumination snapshot 参数提供
  production-safe `.legacyProfileUnresolved` 默认值，只用于既有
  non-rumination tests。AppStore 的 production composition 必须显式传入启动时
  捕获的 snapshot。不得新增会读取 current default 的兼容 overload。

#### 6.4.5 Startup、halt、resume 与 shutdown

- startup 保持派发 suppressed，恢复顺序精确为：legacy planning repair →
  planning adoption → legacy rumination repair → rumination adoption → 单次读取
  durable mode。mode=`running` 只进入 `.recoveryReady`；Orchestrator 完成既有
  Card adopt/heal 后才统一 activate。activate 前不得 claim、resolve provider、
  调 provider 或发 phase。
- mode=`halted` 时，先完成既有 planning bulk cleanup，再以一个 rumination
  cleanup transaction 按 work ID 排序取消全部 active rumination、关闭开放
  attempt，并把 matching item 置 `queued`、`errorText=nil`；transaction 必须返回
  每个实际 canceled work 的 exact
  `RuminationProjectionCommitIdentity(phaseIdentity,workVersion)`，其中 attempt
  可为尚未 claim 的 `0`，workVersion 只能取 resulting work record。Supervisor
  按相同稳定顺序逐个 awaited 发布 `.projectionCommitted`；全部 delivery 完成后
  才统一发布 didCommit/`haltStateChanged`。任一 cleanup 或 committed projection
  delivery 未完成都保持 suppressed/cleanupPending；未 commit 的 row 零
  milestone，且不得为 no-active/queued loser 伪造 commit。halted resume 必须按
  同一顺序幂等重跑；durable mode 仍 halted 时不开放 gate；此前 canceled
  rumination 不复活。
- emergency halt 的第一个 Supervisor actor turn 必须 generation checked `+1`，
  先按 `workId,ingestionId,attempt` 稳定排序捕获全部可能 live 的 rumination
  identities并 revoke 两种 kind 的 generation/terminal/phase-set permission，
  再按 §6.4.9 awaited发布每个尚未被更早 matching projection满足的
  `.phase(identity:reason:.controlLoss)`；只有全部 pre-cancel phase-cleared
  obligation 完成后才 cancel 两种 kind 的 provider/renewal task。随后精确顺序为：
  持久化 global halted → planning bulk cleanup → rumination cleanup transaction
  返回按 work ID 排序的 actual-canceled commit identities → 逐个 awaited
  `.projectionCommitted` → 发布 didCommit/`haltStateChanged` → return。若 phase
  first，后续真实 projection 仍必须发送 refresh且
  `invalidatedPhaseIdentity=nil`；若 matching projection 已 first，则 phase caller
  只等待并零第二 clear。generation 失效或 stale provider response 的所有
  terminal/phase 写均为零。任一持久化/cleanup失败都不为未 commit row发
  projection milestone，保持 suppressed/recovering且不恢复旧 phase；
  `haltStateChanged` 只报告 durable halt state，绝不是 rumination refresh owner。
  任一 kind 的 fatal latch 都 suppress 两种 kind。
- shutdown 同样先 revoke phase-set permission并 awaited invalidation，再取消两种
  kind 的 provider/renewal/timer task，但不伪造 ledger release；最多等待 2 秒，
  按 work ID 排序报告仍不合作的两种 work。重启 adoption 可以重新调 provider；
  shutdown 自身没有 DB projection commit，因而不得伪造
  `.projectionCommitted`。A2 不承诺 provider 恰好调用一次，只承诺
  result/terminal commit恰好一次。
- 既有 planning-only package compatibility API 可保留给历史 tests，但 production
  Orchestrator 必须只走 unified lifecycle；planning-only cleanup 若发现 active
  rumination 必须 fail-fast，source sentinel 必须证明 production 无 bypass。

#### 6.4.6 Legacy `ruminating` repair

- normal input 不承载 legacy 缺失身份。另建
  `LegacyRuminationTerminalInputV1`，exact keys 为
  `contractVersion:Int=1,terminalCode:String`，terminalCode 只允许
  `emergency_halt_during_rumination|
  legacy_rumination_profile_unresolved|
  legacy_rumination_model_unavailable|
  legacy_rumination_profile_cli_unsupported`；只经 `CanonicalJSONV1`。
- `LegacyRuminationStartupSnapshot` 是 immutable package enum，exact cases 为
  `.valid(runtimeProfileId:model:)`、`.legacyProfileUnresolved`、
  `.legacyModelUnavailable`、`.legacyProfileCLIUnsupported`。AppStore production
  composition 在 Orchestrator 初始化前同步捕获 exact DB default profile ID，以及
  该 profile 的 distill model（空则该 profile `defaultModel`），构造上述 snapshot；
  三种 invalid case 只记录对应静态 terminal reason，不读取 credential、不构造
  provider。Orchestrator 默认 `.legacyProfileUnresolved` 只为 source
  compatibility，不能成为 AppStore 的 current-default fallback。
- snapshot 构造优先级固定为：default profile missing/corrupt/ambiguous →
  `.legacyProfileUnresolved`；否则 profile kind为 `cli_codex|cli_claude` →
  `.legacyProfileCLIUnsupported`，不再检查model；否则 profile-scoped
  distill-or-default model blank/missing → `.legacyModelUnavailable`；其余才是
  `.valid`。该捕获不读 credential/catalog/endpoint、不构造 resolver/provider。
- repair 按 ingestion ID 排序、每个 ID 独立 transaction；transaction 重读 durable
  mode、item 仍为 `ruminating`、Camp/ingestion graph，并要求该 ingestion 不存在
  **任何**历史 rumination work。已有任一历史即不是 legacy，绝不生成第二条。
- status/history/Camp graph 是进入下表的共同前置条件；任一不满足均 fail-closed、
  零写。随后 transaction **先读取 durable mode 作为线性化点**，mode=`halted`
  对 snapshot 拥有绝对优先级，不能再根据 snapshot 自行选择 failed/fatal。完整
  8-cell 状态表固定为：

| Durable mode | Startup snapshot | work input | work/attempt | item projection | domain event / external calls |
|---|---|---|---|---|---|
| `running` | `.valid(profile,model)` | normal `RuminationWorkInput(profile,model,coding-ranch-v1)` | `queued,attempt=0,maxAttempts=4,error*=nil`；零 attempt rows/events | 保持 `ruminating`、原 item.attempt 不变、`errorText=nil` | 零 domain event；repair 内 resolver/credential/provider=0，后续 claim 才 resolve |
| `running` | `.legacyProfileUnresolved` | terminal input code `legacy_rumination_profile_unresolved` | `failed,attempt=0,maxAttempts=4,errorCode=<code>,errorMessage=nil`；零 attempt rows/events | `failed`、attempt不变、errorText=对应安全文案 | 恰好一条 typed `rumination_failed`；resolver/credential/provider=0 |
| `running` | `.legacyModelUnavailable` | terminal input code `legacy_rumination_model_unavailable` | 同上，code为本行 reason | 同上，使用 model unavailable 安全文案 | 同上，event code为本行 reason；external calls=0 |
| `running` | `.legacyProfileCLIUnsupported` | terminal input code `legacy_rumination_profile_cli_unsupported` | 同上，code为本行 reason | 同上，使用 CLI unsupported 安全文案 | 同上，event code为本行 reason；external calls=0 |
| `halted` | `.valid(profile,model)` | terminal input code `emergency_halt_during_rumination` | 先 `queued,attempt=0`，同一 transaction 复用 queued cancel primitive 得到 `canceled,errorCode=work_canceled,errorMessage=emergency_halt_during_rumination,maxAttempts=4`；零 attempt rows/events | `queued`、原 attempt不变、`errorText=nil` | 零 domain event；resolver/credential/provider=0 |
| `halted` | `.legacyProfileUnresolved` | **仍为** terminal input code `emergency_halt_during_rumination` | 与 halted+valid 完全相同 | 与 halted+valid 完全相同 | 与 halted+valid 完全相同；snapshot reason不落 work/item/event |
| `halted` | `.legacyModelUnavailable` | **仍为** terminal input code `emergency_halt_during_rumination` | 与 halted+valid 完全相同 | 与 halted+valid 完全相同 | 与 halted+valid 完全相同；snapshot reason不落 work/item/event |
| `halted` | `.legacyProfileCLIUnsupported` | **仍为** terminal input code `emergency_halt_during_rumination` | 与 halted+valid 完全相同 | 与 halted+valid 完全相同 | 与 halted+valid 完全相同；snapshot reason不落 work/item/event |

- 八格 work 均使用同一 legacy key/trace、canonical input/hash，`attempt=0`、
  `notBefore/leaseOwner/leaseExpiresAt/outputJson=nil`，且零 attempt rows/events。
  running-valid queued 的 `finishedAt=nil`；三格 running-invalid failed与四格 halted
  canceled 的 `finishedAt=now`。item/work `updatedAt=now`。
- running invalid 的唯一 `rumination_failed` payload 沿用 §6.4.8 exact keys：
  `workId,ingestionId,attempt=0,traceId,code,terminal=true,usage=null`。halted 的四行
  均不写 `rumination_failed|rumination_completed`，因为它们是 halt control cancel，
  不是 provider failure。
- 每行 transaction rollback 后可用同一 key重试；commit 后任一 historical
  rumination work 都让后续启动 skip，因此 restart 不生成第二 work/event。读到
  `running` 后提交的 valid/invalid事实先于之后的 halt，halt bulk cleanup只会取消
  仍 active 的 valid queued work，不改写已 failed legacy事实；读到 `halted` 后
  四种 snapshot 都只能提交 emergency-halt canceled事实。resume 不复活 canceled
  work、不重放 invalid snapshot；halted行的 item保持 queued，用户只能在 running
  后用新的 normal command重试。
- legacy 安全文案固定为：profile unresolved
  `旧反刍任务缺少可恢复的运行配置。`；model unavailable
  `旧反刍任务缺少可恢复的模型。`；CLI unsupported
  `旧反刍任务的 CLI 运行配置不受支持。`。halt reason 固定
  `emergency_halt_during_rumination`，普通用户 cancel reason 固定
  `rumination_deferred_by_user`。

#### 6.4.7 Provider、usage 与 failure

- `RuminationService` 移除 DB/start/cancel/process owner，只保留 provider 与
  `maxTokens=3072`。唯一 provider API/path 精确为
  `package func produceValidatedTurn(ingestion: IngestionItemRecord) async throws
  -> RuminationValidatedTurn`；它是唯一调用 `streamTurn` 的位置。
  `RuminationValidatedTurn` 为 package opaque `Sendable` value，只公开 immutable
  `usage:RuminationUsageCountersV1`，raw validated text 与 initializer 均
  `fileprivate`，Supervisor/test不能读取、替换或自行 parse。
- 同一次 attempt 的 `produceValidatedTurn` 精确调用一次 `streamTurn`、
  `tools=[]`，不做第二模型修复 turn；消费 stream 完毕后要求恰好一个 `.turn`，
  0或多 turn均 malformed；随后先把该 turn usage逐字段 exact转换/验证为
  `RuminationUsageCountersV1`，只有此时才构造/返回 opaque turn。它不调用 parser。
- 唯一 parse API 精确为
  `package func parseValidatedTurn(_ turn: RuminationValidatedTurn) throws
  -> RuminationProduction`。它只能读取同一 opaque turn 的 fileprivate text，
  恰好调用一次 `RuminationParser.parse`，并返回 immutable
  `RuminationProduction(result:usage:)`，其中 usage 必须逐字复用 turn.usage。
  该同步 pure method 不调用 provider、DB、callback/Task，也不能生成第二 turn。
  parser failure 由 Supervisor 使用同一 turn.usage 构造 failure。
- 禁止 mutable `lastUsage`、任意 provider/usage callback、optional callback、
  unowned Task、第二 provider API/path，或在 transaction helper 内另开
  `pool.read/write`。唯一允许新增的 rumination callback 是 §6.4.9 的 typed、
  awaited、process-local phase-command Supervisor sink；其 payload只能是
  identity-bound `.set` 或 `.invalidate`，看不到 raw text、usage、result或任意
  `Error`，不属于 provider path。不得为 invalidation 增加第二 callback。
- `RuminationUsageCountersV1` exact Codable keys 为
  `cacheReadTokens,inputTokens,outputTokens`，三者均为 non-negative Int64；从
  provider `Usage` 必须逐字段 exact 转换。任一 negative/overflow 为
  `rumination_usage_invalid/deterministic` 且 `usage=nil`，不得 clamp、部分记录
  或继续 parse。
- provider/failure mapping 唯一为：
  - `URLError` → `rumination_transport_error/transient`；
  - HTTP `408|429|500...599`、overloaded，以及 API
    `overloaded_error|rate_limit_error|server_error` →
    `rumination_provider_unavailable/transient`；
  - 0/multi-turn 或 malformed stream →
    `rumination_provider_malformed_response/transient`；
  - unauthorized → `rumination_provider_unauthorized/deterministic`；
  - 其他 HTTP → `rumination_provider_http_error/deterministic`；
  - 其他 API → `rumination_provider_api_error/deterministic`；
  - `RuminationParseError` →
    `rumination_contract_invalid/deterministic`；
  - 未分类 Error → `rumination_provider_failed/deterministic`。
  `CancellationError` 不构造 failure，由 lifecycle owner 收口。
- safeMessage exact map 为：transport `反刍服务网络连接失败。`；unavailable
  `反刍服务暂时不可用。`；malformed `反刍服务返回了无效响应。`；unauthorized
  `反刍服务认证失败。`；HTTP `反刍服务请求失败。`；API
  `反刍服务返回错误。`；contract `反刍结果格式无效。`；provider failed
  `反刍服务执行失败。`；usage invalid `反刍用量数据无效。`。
- `RuminationAttemptFailure` 只能由
  `code/safeMessage/disposition/usage` 的 validating initializer 构造，并由同一
  source 派生 `DurableWorkFailure`/canonical usage；不得接受可互相矛盾的 pair。
  retry policy 只看 disposition：transient 且 attempt<4 按 5/30/120 秒，
  deterministic 或耗尽立即 terminal。

#### 6.4.8 Terminal transactions 与 pending proposal

- success owner 接收同一 provider path 的 `RuminationProduction`。单一 transaction
  先重验 durable mode=`running`、latest claim、generation、work/input、Camp、
  ingestion 仍 `.ruminating`；随后关闭 work/attempt/event 为 succeeded，
  `outputJson=nil`；canonical 编码 result，upsert 唯一 `rumination_result`，
  若已存在则保留 `id/createdAt`，替换 pipeline/result，清
  `userEditedJson/materializedAt`；仅在 item.title 为 nil 时写 suggested title，
  item 置 `needsReview`、清 error；最后写既有
  `EventKind.ruminationCompleted`。payload exact keys 为
  `workId,ingestionId,attempt,pipelineVersion,traceId,usage`，usage 是 exact
  三-key object。transaction 必须返回实际 resulting `DurableWorkRecord`；任一步
  失败整体 rollback。
- transient failure 同一 transaction 关闭当前 attempt、写 failed attempt event、
  work=`retryScheduled`、写既有 `rumination_failed`，item 保持
  `ruminating/errorText=nil`；deterministic/exhausted 同一 transaction
  terminalize work、item=`failed`、写 safe error/event。failure event payload
  exact keys 为 `workId,ingestionId,attempt,traceId,code,terminal,usage`，usage
  必须显式 object 或 JSON null。所有 event payload 由 private typed Codable →
  `CanonicalJSONV1` 直接插入，不经 `JSONValue`/`Double`；`EventKind.swift`
  byte-identical。transient retry 与 deterministic/exhausted terminal operation
  都必须返回实际 resulting `DurableWorkRecord`。
- user cancel 与 emergency halt 都在 specialized transaction 原子关闭 matching
  active work/open attempt并把 item 置 `queued`、清 error。actual user cancel
  必须返回 resulting work；emergency halt cleanup 必须返回按 work ID 稳定排序的
  actual-canceled `(RuminationPhaseIdentity,workVersion)`，queued attempt-zero
  cancel 合法返回 attempt `0`。stale claim、stale response、旧 generation、
  no-active 与 cancel loser 全部零业务写、零 resulting commit identity。
- success、deterministic/exhausted failure、transient retry 与 actual user cancel
  的 transaction commit 后，Store caller只能从 resulting work 的 exact
  `version` 构造 §6.4.9 projection commit identity；同一 Supervisor actor turn在
  第一次 await 前 reserve milestone，再 revoke committed claim/generation 的后续
  set/terminal permission、等待已登记 set-in-flight并 awaited发布一次 commit
  refresh。Store throw/rollback/invariant failure均零 reservation/零 milestone，
  不能用 expectedVersion、旧 claim 或手工 `+1` 伪造。
- provider 返回后，完整 typed terminal proposal 只存在对应 `OwnedEntry`。terminal
  DB error/rollback 保留 claim/proposal并继续 lease；只有一次成功 renewal 后或
  explicit kick 才重试同一 proposal，不重调 provider。stale/control-loss 丢弃，
  invariant error 触发全局 fatal。若进程死亡，内存 proposal 可丢失，重启 adoption
  可重调 provider，但最终只允许一个 result 与一个 terminal commit；不得在 A2
  新增 P1-F provider-returned checkpoint。

#### 6.4.9 真实 phase、UI 投影与 mutation fences

- `KernelEvent`仍只有R12-D已规划的两个process-local rumination cases，不新增
  第三case：
  `ruminationChanged(RuminationChange)`与
  `ruminationPhase(ingestionId:workId:attempt:phase:)`；phase exact enum为
  `reading|extracting|organizing`。public typed envelope精确为：

  ```swift
  public enum RuminationChange: Sendable, Equatable {
      case phaseInvalidated(RuminationPhaseIdentity)
      case projectionCommitted(
          RuminationProjectionCommitIdentity,
          invalidatedPhaseIdentity: RuminationPhaseIdentity?
      )
  }
  ```

  event stream保持现有unbounded process-local carrier，不新增schema、
  `EventKind`、持久phase或持久projection receipt。
- 只有 valid owner/generation/latest claim 可发 phase：context load 完成后
  `reading`；captured resolver 成功且 `streamTurn` 前 `extracting`；恰好一个
  valid turn且usage验证完成、parse 前 `organizing`。
- 单一 process-local command contract精确为：

  ```swift
  public struct RuminationPhaseIdentity: Sendable, Hashable, Equatable {
      public let ingestionId: String
      public let workId: String
      public let attempt: Int
  }

  public struct RuminationProjectionCommitIdentity:
      Sendable, Hashable, Equatable
  {
      public let phaseIdentity: RuminationPhaseIdentity
      public let workVersion: Int
  }

  public enum RuminationPhaseInvalidationReason: Sendable, Equatable {
      case controlLoss
      case globalFatal
  }

  public enum RuminationInvalidationMilestone: Sendable, Equatable {
      case phase(
          identity: RuminationPhaseIdentity,
          reason: RuminationPhaseInvalidationReason
      )
      case projectionCommitted(RuminationProjectionCommitIdentity)
  }

  package enum RuminationPhaseCommand: Sendable, Equatable {
      case set(identity: RuminationPhaseIdentity, phase: RuminationPhase)
      case invalidate(RuminationInvalidationMilestone)
  }
  ```

  public identity的`ingestionId/workId`必须nonblank；`attempt` exact来自resulting
  durable work且允许`0...Int.max`。`RuminationProjectionCommitIdentity.workVersion`
  必须`>=1`且只能取自Store transaction真实返回的resulting work.version，禁止
  caller预测、旧claim复制或手工`+1`。positive `.set`与`.phase` live
  invalidation另要求`attempt>=1`、work running且存在matching open attempt；
  queued尚未claim的user-cancel/halt可产生attempt=0 projection commit，但绝不能
  伪造phase/live invalidation。package validating initializer对blank、negative
  attempt或workVersion<1在任何sink/event前fail-fast。

  command不得携带 raw text、usage、result、任意 Error/string diagnostics、DB
  record或业务terminal projection内容。Supervisor initializer 唯一新增 rumination
  sink 精确为
  `onRuminationPhase: @escaping @Sendable (RuminationPhaseCommand) async -> Void
  = { _ in }`。所有 reading/extracting/organizing 与 invalidation 共用该一个
  awaited sink；不得保留 `RuminationPhaseEmission`、增加第二 callback或把调用包
  在 `Task` 中。default no-op只保持既有 non-rumination tests source-compatible；
  production Orchestrator必须显式传入。不得增加第二callback、observer、
  per-command Task或新KernelEvent case。
- Supervisor actor是command与milestone的唯一生产owner。所有正向phase必须经唯一
  private owned-set owner，使用 OwnedEntry 当时的 exact
  `RuminationPhaseIdentity`，在 awaited `.set` 前线性化“set in flight”，sink返回
  后先清该标记并唤醒该identity的checked-continuation waiter，再重新验证同一
  generation/token/latest claim；control/fatal 已 revoke 后不得再接受或发送任何
  正向set。
- phase invalidation只经同一actor的唯一private
  `invalidateRuminationPhaseIfNeeded(identity:reason:) async`，不得直接另发
  `ruminationChanged`代替。reason mapping精确为：expected ownership/control
  loss、halt与shutdown使用`.controlLoss`；DB read/invariant或其他global fatal
  使用`.globalFatal`。并发时由首个
  actor-linearized winner决定first reason，后续caller只等待同一delivery。
- `invalidateRuminationPhaseIfNeeded` 对每个 exact identity 提供 process-local
  exactly-once/idempotent delivery：首个 actor-linearized caller 在任何 await 前
  记录 `inFlight(reason)`并revoke后续set；若该identity已有set sink in flight，
  invalidator必须先以checked continuation等待那一次set delivery返回，随后才调用
  invalidate sink，不能假设跨actor mailbox天然FIFO。同 identity 的 reentrant
  invalidation caller不得再调用 sink，而以checked continuation等待同一次
  invalidate delivery；nonthrowing sink返回后记录
  `delivered(reason)` 并唤醒全部 waiter。首个安全 enum reason获胜；后续
  `controlLoss|globalFatal` 不改变 reason且零第二 emission。不得用 unowned
  `Task`、timeout、task-completion巧合或取消作为 delivery owner；identity状态只可
  在对应 OwnedEntry、generation和全部 producer已不可达后回收。
- durable projection commit只经唯一private
  `publishRuminationProjectionCommitIfNeeded(_ commitIdentity: RuminationProjectionCommitIdentity) async`。
  normal start/user retry 的`.inserted`、terminal success、
  deterministic/exhausted failure、transient retry与actual user cancel的同步Store
  transaction必须返回resulting work及其真实`version`；其中new start `.inserted`
  必须exact `version=1`，start commit使用attempt-zero identity且不对应live phase，
  其余使用实际claim attempt。commit caller在同一
  Supervisor actor turn、第一次await前构造并reserve完整commit identity；terminal/
  retry/cancel caller同时revoke该已commit claim/generation的后续set/terminal
  permission并等待已登记set-in-flight，attempt-zero start caller则保持
  kick/claim关闭直到delivery完成。最后await同一sink的
  `.invalidate(.projectionCommitted(commitIdentity))`。store throw/rollback/
  invariant failure为零reservation、零projection milestone，保留适用的claim、
  pending proposal与live phase；不得从expectedVersion或旧claim猜version。
- projection delivery以完整`phaseIdentity+workVersion`为key exactly-once。相同
  commit identity in-flight/delivered的duplicate只等待同一delivery且零第二sink；
  同workId严格更高workVersion允许并按reservation顺序串行delivery，因此retry
  `V+1`后cancel/halt`V+2`必须产生两次projection refresh。若`workVersion`低于同
  workId已见最高值且该完整identity从未见过，或同version却phase identity不同，
  属于version regression/corruption，必须在sink/event前fail-fast；不得静默drop。
  receipt不得简化为`Set<RuminationPhaseIdentity>`，只可在全部相关producer与
  duplicate不可达后有界回收。
- attempt-zero start `Vstart` delivery暂停时，reentrant actual user cancel或halt
  cleanup可提交同work严格更高的`Vcontrol`，但必须在同一coordinator排在
  `Vstart`之后并等待其delivery；App FIFO先见start refresh、再见最终control
  refresh。start caller恢复后必须重验，不能kick/claim已canceled work。start
  rollback或`.replayed`没有reservation，因而绝不能据current version补造
  `Vstart`。
- 每个phase identity的set、phase invalidation与projection milestone共用一个
  actor-isolated串行delivery coordinator，两个helper不得并发调用sink：
  - projection milestone先reserve时，后来的control/global phase caller先等待该
    projection delivery；matching projection本身满足phase-cleared obligation，
    caller记录first reason但零第二`.phase` clear command；
  - phase milestone先reserve/完成时，后来真实projection commit仍先reserve并等待
    phase delivery，随后必须发送commit refresh；其Orchestrator payload的
    `invalidatedPhaseIdentity=nil`；
  - 任一方向都先在actor turn登记状态、再用checked continuation等待，完成者先
    更新state并唤醒waiter；不得互等、递归await同一continuation、并发sink、Task
    或依赖executor FIFO。tests/source gate必须覆盖commit-first与
    fatal/control-first两向race和无deadlock。
- production global-fatal 的唯一 writer/revoke-all owner精确为
  `private func latchFatalAndInvalidateRumination(_ fatal: SupervisorFatalError, operation: String, workId: String?) async`。任何
  provider/resolver/DB read/invariant `.fatal` 分类、`fatalError` state writer、
  `latchFatal`/`latchReadFailure` wrapper或 revoke-all callsite，只要 production
  中可能存在 active、owned、set-in-flight 或 live rumination，都必须 route/await
  该 owner；不得先经同步 wrapper mutate fatal/suppression或取消 task。该 owner
  与 cancel/halt/control owner 的顺序精确为：
  1. Supervisor actor 先线性化 fatal/suppression 或对应 control winner；
  2. 在删除 OwnedEntry 或 revoke-all 前捕获全部可能 live 的
     `RuminationPhaseIdentity`（只含running/open attempt>=1），按`workId`，再按
     ingestionId/attempt稳定排序；
  3. 在同一 actor turn revoke generation/token/terminal/phase-set permission，
     使任何 resumed positive set均不能通过；
  4. 对每个identity标记phase invalidation in-flight；
  5. 依上述顺序逐个进入同identity串行coordinator：先等待已登记set或更早reserve的
     projection delivery；若phase clear尚未被projection满足，则await同一sink的
     `.invalidate(.phase(identity:reason:))`；等待全部phase-cleared obligation完成；
  6. 只有 delivery返回后才可取消 current/all provider与renewal task、移除 owner、
     唤醒 waiter，并向外 return/throw。
  invalidation不得由将被取消的 provider task生命周期拥有；该 task即使发现第二轮
  control loss，也必须先await同一 idempotent owner，再抛
  `RuminationPreParseAuthorizationLostError`。
- `onRuminationPhase` 是 nonthrowing sink。Supervisor 与 Orchestrator sink path
  不得以 `Task.isCancelled`、`CancellationError`、early return 或 cancellation
  handler跳过已经要求的 `.invalidate`；Orchestrator callback body在actor上同步
  完成 registry mutation与event emit，不含内部 await/Task。fatal/control owner
  只能在 sink返回后取消 provider task，因此 cancellation不能使 invalidation
  丢失。
- 允许为既有 planning-only tests保留同步 compatibility path，但它在任何
  fatal/suppression/revoke mutation前必须证明零 active、owned、set-in-flight、
  live rumination；否则在 mutation前以
  `RuminationRequiresDurableRuminationCapabilityError` fail-fast。production
  不得调用该 path。不能静态证明为纯 planning 的 caller必须改为 async并 route
  `latchFatalAndInvalidateRumination`；不得保留第二 fatal writer作为旁路。
- production Orchestrator actor唯一持有process-local current registry
  `[ingestionId: (identity: RuminationPhaseIdentity, phase: RuminationPhase)]`
  与每个ingestion至少最后一个invalidated identity tombstone；另持有以完整
  `RuminationProjectionCommitIdentity`为key的projection receipts和每workId最高
  已见workVersion。处理command的精确规则为：
  - `.set`：registry为空时只接受未命中 tombstone的新 identity的 `.reading`；
    identity必须attempt>=1，且Supervisor已验证running/open attempt；
    registry已有值时只接受 exact same identity 的幂等同 phase或下一个
    `reading→extracting→organizing`；幂等同 phase零 event，合法推进先更新
    registry，再同步 `emit(.ruminationPhase(...))`。已有不同 identity、已
    tombstoned identity、倒退或跳级不得覆盖当前 generation；stale/mismatched
    command零 event，非法非 stale transition作为 programmer invariant fail-fast。
  - `.invalidate(.phase(identity:reason:))`：只有registry中
    `ingestionId/workId/attempt`全匹配时，才先remove、记录exact tombstone，再同步
    恰好一次
    `emit(.ruminationChanged(.phaseInvalidated(identity)))`；registry empty、
    已tombstoned、stale/mismatched identity均零event且绝不能清新generation。
  - `.invalidate(.projectionCommitted(commitIdentity))`：先校验full receipt与
    same-work monotonic version。exact duplicate in-flight/delivered为零第二event；
    严格更高version允许；低于最高且unseen、或同version不同phase identity为
    invariant fail-fast。若current registry exact匹配commitIdentity.phaseIdentity，
    先remove并tombstone，令`invalidatedPhaseIdentity`为该identity；若registry
    empty、已tombstoned或持有different/newer identity，registry逐字不动且optional
    为nil。随后先记录full receipt/highest version，再恰好一次同步
    `emit(.ruminationChanged(.projectionCommitted(
    commitIdentity,invalidatedPhaseIdentity:<exact-or-nil>)))`。即使phase-less或
    mismatch也必须emit commit refresh，绝不能用phaseIdentity set去重或吞掉更高
    version。attempt-zero start commit绝不能创建live phase/tombstone或清任何
    attempt>=1 registry，`invalidatedPhaseIdentity`固定为nil。
  新identity只可在旧registry exact clear后从`.reading`开始。Orchestrator不得把
  milestone降格为identityless changed、用`Set<RuminationPhaseIdentity>`代替
  commit receipt、把registry/receipt放到App/持久层，或让`haltStateChanged`
  兼任rumination refresh owner。
- Supervisor按上述set-in-flight handoff保证同identity的set sink调用先于
  invalidate sink调用，同identity phase/projection也由Supervisor串行，不依赖
  跨actor executor调度顺序；Orchestrator callback在actor上先完成registry/
  receipt mutation再emit，现有AsyncStream按该actor实际处理顺序FIFO。
- AppStore live map精确保存
  `[ingestionId:(identity:RuminationPhaseIdentity,phase:RuminationPhase)]`，不得只
  存stage。现有单一lifecycle-owned MainActor event listener使用一个
  `for await`并直接`await handleKernelEvent`；case body与Adapter command
  completion不得创建Task、observer、polling或导航refresh owner。
- App lifecycle/restart必须先经同一Adapter persisted snapshot path成功加载**目标
  ingestion所属Camp**的Coding Ranch projection并把该Camp标记ready，再启用该
  ingestion的normal start/retry action。load失败保持该action disabled并显示现有
  显式load failure，不能清startup-pending/ready后在无投影状态继续。active graph但
  本进程registry/start-delivery waiter为空时，该snapshot精确显示`.recovering`；
  background Camp readiness/load只更新对应cache，绝不能切selected Camp。不得靠
  command replay、Adapter completion或current-version synthetic event补初始刷新。
- `ruminationPhase`到达时，App必须先经Adapter从同一次DB read snapshot读取
  `campId,item.status,active rumination workId/attempt/state`；只有item仍
  `.ruminating`、active work仍`.running`且workId/attempt与event identity exact
  匹配时，才以该snapshot重建persisted projection并overlay live phase。attempt=0、
  queued/retryScheduled/terminal、missing/mismatch event均不得成为live phase。
- `ruminationChanged(change)`到达时，App只在typed payload的
  `phaseInvalidated(identity)`或
  `projectionCommitted(_,invalidatedPhaseIdentity:.some(identity))`与当前live
  identity exact匹配时clear；nil/stale/old version/old generation绝不能清当前
  phase。**无论是否clear**，都在同一串行handler中reload persisted projection，
  再只保留仍与reload snapshot中active running workId/attempt exact匹配的live
  entry；其余移除。old V commit与new generation并发只能触发reload，不能清新
  phase。
- handler必须记录本次DB read得到的loaded camp ID与snapshot；background Camp
  event只更新其对应cache/projection，不得切换selected Camp、当前页面或foreground
  UI。Adapter start/retry/cancel completion只delegate/return，不能补发changed、
  直接reload或成为第二refresh owner。
- registry/tombstone只存在当前进程；restart精确从 empty registry/tombstone开始。
  因而 DB仍为 `.ruminating` 且没有本进程 matching `.set` 时只能显示
  `.recovering`。global fatal不改 durable work/item/attempt/result/domain event；
  matching phase invalidation清除live phase后，即使reload snapshot仍是相同
  persisted active workId/attempt，也因live map已移除而只能投影`.recovering`；
  可同时显示既有global-fatal error surface，但不得继续显示organizing或新增业务
  fatal status。
- owned provider task取得 opaque `RuminationValidatedTurn` 后，只能
  `await` Supervisor actor 的 exact private API
  `handleValidatedRuminationTurn(workId:String,attempt:Int,ownershipToken:UUID,
  generation:Int,turn:RuminationValidatedTurn) async throws -> Void`。该 method 的顺序
  固定为：
  1. 在 actor 内验证 lifecycle=`running`、无 fatal/suppression、generation与
     ownership token相等、OwnedEntry仍是同一 rumination work/ingestion/attempt、
     provider未退出且无 terminal proposal；
  2. 从 OwnedEntry 读取**当前** `latestClaim`，同步调用 exact package read API
     `validateRuminationPhaseOwnership(claim:ingestionId:now:) throws -> Void`，
     重验 durable mode=`running`、work仍 running、kind/aggregate/Camp/item、
     attempt/version/leaseOwner/未过期 lease与该 latest claim逐字相等；该 validator
     零写、不得 resolve/provider；
  3. awaited调用唯一 owned-set owner，经同一 typed sink发送
     `.set(identity:<exact current identity>,phase:.organizing)`；
  4. sink返回后完整重复步骤1–2；仍 valid时在同一 Supervisor actor turn、无任何
     `await` 地调用 `parseValidatedTurn`，再创建同源 success/failure proposal。
- 第一次或第二次 revalidation失权时抛 package typed control signal
  `RuminationPreParseAuthorizationLostError`；其 exact shape 为
  `package struct RuminationPreParseAuthorizationLostError:
  Error, Sendable, Equatable { package init() {} }`，不含 raw turn、usage、work ID
  或 message。Service绝不 parse，Supervisor不把它记录为 provider failure/retry。
  两次任一失权都必须先await同一 idempotent invalidator，再抛control signal：
  除 actor `fatal` gate外使用
  `invalidateRuminationPhaseIfNeeded(identity:reason:.controlLoss)`；`fatal` gate
  只可能在唯一global-fatal owner已先线性化后可见，必须等待该owner已标记/发送的
  `.globalFatal` delivery，不得再产生`.controlLoss` emission。若 control
  transition在 organizing set前线性化，则零 organizing/
  零 parse，并清理此前可能存在的 reading/extracting；若 set先线性化而
  cancel/halt/terminal在 awaited sink期间获胜，则第二次重验保证零 parse，同一
  identity invalidate在 throw/cancel/return前清 live phase。persisted row可保持
  相同 active workId/attempt，但 registry tombstone与 FIFO changed event仍保证
  不得留下或复活 visible stale phase。
- handler把 expected stale/halted/terminal/lease-loss映射为上述 control signal；
  DB读取失败或 graph invariant corruption 必须await
  `latchFatalAndInvalidateRumination`，二者都零parse、零业务写。
  owned provider task必须显式 catch
  `RuminationPreParseAuthorizationLostError` 并作为 control-loss正常退出，绝不转成
  `RuminationAttemptFailure`、retry或terminal proposal；其他throw仍按既有
  failure/fatal分类。
- 既有 named tests #1/#6/#11/#22/#33/#34/#35 必须共同穷尽 start projection
  barrier，不新增名字：queued normal start与failed user retry分别证明
  `.inserted` resulting work为queued attempt0且exact `version=1`，Store return后第一次
  await/reentrancy前完成full identity reserve+barrier；暂停sink期间已有pump、timer、
  concurrent kick与global FIFO入口都零DB claim，且不得跳过rumination去claim
  planning。delivery返回后先release barrier、再重读mode/work，只有仍
  running+active才kick；cancel/halt已提交则零stale kick/claim。same-process
  `.replayed`只按workId等待original inserted in-flight delivery，不能从current
  attempt/version构造identity；delivery已完成或新进程无waiter时零等待、零第二
  milestone/event，kick失败只可重试kick。restart必须在目标ingestion所属Camp的
  persisted snapshot成功load并标记ready后才enable command；失败保持disabled/
  显式失败，active graph显示recovering；并以byte-identical
  `StateDirectoryLock.swift`/`SupportTests.swift`证明同state root第二owner
  fail-fast、释放后replacement可取得锁，production唯一`AppDatabase(path:)`严格
  位于AppStore lifetime-held lock acquisition之后。Adapter completion仍零refresh。start
  rollback/throw/preflight/same-key conflict固定零barrier/reserve/sink/kick；
  paused start `V`期间user cancel/halt `V+1`按同一coordinator严格delivery且start
  恢复后不复活。task cancellation不能跳过start delivery/barrier release。
- A2 test #27/#35 的 exact completion matrix 必须在第一次与第二次 revalidation
  分别逐项注入以下 expected loss：lifecycle、suppression、fatal、generation、
  token、workId、ingestion、actor attempt、providerExited、pending proposal、当前
  `latestClaim`、durable mode、work、kind、aggregate、Camp、item、durable attempt、
  version、lease owner、expiry。每格都必须由 handler 抛 exact
  `RuminationPreParseAuthorizationLostError`，再由 owned provider task 的专门
  catch 显式吞并；结果固定为 zero parse、zero `RuminationAttemptFailure`、zero
  retry/failure/pending-or-terminal proposal、zero domain event 与 zero business
  write。reason断言精确为：每轮`fatal`格恰好一次`.globalFatal`，其余expected-loss
  格恰好一次`.controlLoss`；所有duplicate caller只等待first-winner delivery。
  第一次失权还必须 zero organizing phase，并以一次 matching invalidate
  清除此前 reading/extracting（若存在）；第二次失权在 organizing 已线性化后，
  必须在 control signal throw/task cancel/owner return前完成同一 identity 的
  exactly-once invalidate。两种情形均断言 Orchestrator registry/tombstone与
  changed→App-clear-before-reload FIFO，persisted workId/attempt保持相同时也不得
  留下或复活 stale phase；特别要强制pause set sink，证明fatal/control reentry先
  revoke、等待该set返回、再invalidate，绝不能由跨actor调度产生invalidate→set。
- 同一 matrix 还必须在第一次与第二次
  `validateRuminationPhaseOwnership` 分别注入 DB read failure 与 graph invariant
  corruption：两类都 latch global fatal、zero parse，且不得映射为 provider
  failure或 `RuminationAttemptFailure`、retry/pending-or-terminal proposal、
  domain event 或 business write；
  第一次注入清此前 live phase，第二次注入若 organizing 已发则都必须在 fatal
  return/task cancellation前完成 sorted exactly-once global-fatal invalidation；
  durable work/item/attempt/result保持逐字不变，App只能 recovering，不得依赖
  matching fence拒绝相同 identity。
- #27/#35 还必须在既有名字内穷尽 durable projection milestone：
  1. queued normal start与failed user retry的`.inserted`从resulting queued
     attempt-zero work/exact `version=1`构造full identity，Store return后第一次await前
     reserve+start barrier；暂停sink时所有global claim入口零DB claim/零跨kind
     skip，delivery后release→revalidate→conditional kick。long-unclaimed row仍先
     刷新；立即cancel/halt的更高version严格排在start后，start恢复不复活；
  2. preparation `replay(ingestionId,workId)`绕过resolver/Store start，concurrent
     transaction-race `.replayed`汇入同一Supervisor branch；original inserted
     delivery in-flight时两者只按workId等待，不构造identity/receipt/事件；
     delivered后或restart无waiter时零等待、零第二event。restart必须在目标Camp
     persisted snapshot成功load/ready后才enable command并显示recovering，load
     failure保持disabled/显式失败。preflight/
     conflict/Store rollback/throw为零barrier/reservation/sink/kick；
  3. live-phase 与 phase-less 两组 success、deterministic/exhausted failure、
     transient retry及actual user cancel，Store逐格返回resulting work与真实
     `workVersion`；commit后恰好一次
     `.projectionCommitted(phaseIdentity,workVersion)`，rollback/throw/no-active
     固定零reservation、零sink、零event；
  4. 同一个phase identity的retry `V+1`后cancel `V+2`，以及retry `V+1`后halt
     cleanup `V+2`，都必须有两个按version递增的refresh；exact `V+1` duplicate只
     等待原delivery且第二sink/event为零，但不得吞`V+2`；unseen lower version与
     same-version/different-identity在sink前fail-fast；
  5. emergency halt逐字验证sorted pre-cancel phase clears → cancel provider/
     renewal → persist halted → planning cleanup → rumination cleanup返回sorted
     actual commits →逐个projection refresh → didCommit/`haltStateChanged` →
     return；persist/cleanup失败不发未commit milestone，保持suppressed/recovering，
     不为queued/no-active伪造commit，`haltStateChanged`调用数不能替代refresh；
  6. commit-first race暂停projection sink时，later control/global phase waiter不得
     并发调sink，matching projection完成即满足phase-cleared且零第二clear；
     fatal/control-first race暂停phase sink时，later真实commit等待phase后仍发
     refresh，typed `invalidatedPhaseIdentity=nil`；两向都无deadlock；
  7. Orchestrator分别覆盖exact current registry、empty、tombstoned与different/newer
     generation：只有exact match remove/tombstone并在typed envelope回传
     `.some(identity)`，其余registry逐字不动、optional为nil但commit refresh仍恰好
     一次；App对`.phaseInvalidated(identity)`和projection的optional identity只做
     exact clear，old version/new generation只reload；
  8. App每个phase event先用同一DB snapshot校验item仍ruminating及active work
     running/exact workId+attempt，再overlay live；每个change event无论clear与否都
     在同一MainActor FIFO handler reload persisted projection，只保留仍匹配snapshot
     的live identity。background Camp只更新其loaded camp cache，不能切selected
     Camp；Adapter command completion零第二refresh owner。
- R13 只为上述不可由外部 provider/phase/Store 时序安全到达的授权矩阵，允许在
  `DurableWorkSupervisor.swift` 内新增一个 release-absent 的封闭 DEBUG seam。其
  exact surface全部位于matching `#if DEBUG`，package visibility仅为：

  ```swift
  package enum A2RuminationAuthorizationCheckpointForTesting:
      Sendable, Equatable, CaseIterable
  {
      case first
      case second
  }

  package enum A2RuminationAuthorizationLossForTesting:
      Sendable, Equatable, CaseIterable
  {
      case lifecycle
      case suppression
      case fatal
      case generation
      case token
      case workId
      case ingestion
      case actorAttempt
      case providerExited
      case pendingProposal
      case latestClaim
      case durableMode
      case durableWork
      case durableKind
      case durableAggregate
      case durableCamp
      case durableItem
      case durableAttempt
      case durableVersion
      case durableLeaseOwner
      case durableExpiry
      case durableReadFailure
      case durableInvariantCorruption
  }

  package enum A2RuminationAuthorizationScenarioForTesting:
      Sendable, Equatable
  {
      case inject(
          checkpoint: A2RuminationAuthorizationCheckpointForTesting,
          loss: A2RuminationAuthorizationLossForTesting
      )
  }

  package func armA2RuminationAuthorizationScenarioForTesting(
      _ scenario: A2RuminationAuthorizationScenarioForTesting,
      identity: RuminationPhaseIdentity
  ) throws
  ```

  `Scenario`不得增加String/custom payload或其他case。actor同一时刻最多一个armed
  scenario；arm只接受valid exact `RuminationPhaseIdentity`并同步要求dispatch
  enabled、lifecycle running、未suppressed、无fatal，且该identity当前恰有一个
  Supervisor-owned `.rumination`/`ingestion` running open attempt与coordinator，
  provider未退出、无pending proposal、terminal仍permitted。它从OwnedEntry内部
  捕获exact token/generation；不接受外部 Database/AppDatabase/path/provider/token/
  raw row/Error/closure。
  不满足、重复arm或消费时identity已不exact均以既有typed invariant fail-fast，
  不得静默忽略或转移到replacement work。
- private storage、arm、唯一private
  `consumeA2RuminationAuthorizationScenarioForTesting` helper及其两个caller必须
  各自完整位于matching `#if DEBUG`。first caller精确位于
  `handleValidatedRuminationTurn`第一次真实`validatedRuminationHandlerEntry`与
  真实`database.validateRuminationPhaseOwnership`均成功之后、organizing之前；
  second caller精确位于awaited organizing返回后、第二次上述两项真实gate均成功
  之后、service lookup/parse之前。
  matching scenario在任何await/throw前原子清除armed storage，只消费一次；wrong
  work/checkpoint不消费。每个matrix cell使用fresh isolated DB+Supervisor，不能让
  fatal或control state污染下一格。
- seam不得修改OwnedEntry或durable state来伪造loss；consume只能在上述真实gate成功
  后按closed loss抛入该checkpoint既有catch，不能直调invalidator/global-fatal
  owner/Store/validator/sink、构造proposal/commit/result、发phase/event、调用
  parser/provider、返回成功或绕过owned task catch。20个非fatal loss由既有catch
  只走typed control-loss owner；`fatal`、`durableReadFailure`与
  `durableInvariantCorruption`由同一catch只await唯一async
  `latchFatalAndInvalidateRumination` global-fatal owner。每checkpoint必须动态跑
  23格，共46格；actorAttempt与durableAttempt是不同格。每格前后durable rows逐字
  相同，除冻结合同本就要求的真实control transaction外不得有业务写。
- 既有名字内同时关闭三个相邻覆盖缺口：#31用
  `PlanningTestFixtures.uniqueFunction`锁Supervisor production
  `produceValidatedTurn`/`parseValidatedTurn`各唯一callsite与每attempt provider
  一次；#40经真实Supervisor链路覆盖valid exact usage、parse-failure同源usage及
  invalid-before-accounting（`rumination_usage_invalid`、failure
  `usage=null`、零result/completed event）；#41动态覆盖Feed discard/Camp archive
  的status-only、work-only与neither，前两维零写拒绝、neither真实允许，并以Adapter
  delete真实unique brace-enclosed transaction owner锁两道fence均在mutation前。
- fail-fast source-range/order gate 必须解析真实 handler、owned-task catch 与
  fatal/control owners、Orchestrator command registry与App event consumer的
  enclosing ranges，不得只找字符串。该gate必须复用既有
  `PlanningTestFixtures.uniqueFunction`，以masked comments/strings后的唯一
  brace-enclosed function range证明owner与call order；不得再以
  `codingRanchSourceRange`、substring/count-only或复制helper充当这些owner的证据。
  它必须证明两轮 actor gate
  逐项同序为 lifecycle → suppression → fatal → generation → token → workId →
  ingestion → actorAttempt → providerExited → pending proposal → 读取**当前**
  `latestClaim`，随后都调用同一 validator；validator 的 durable graph gate 同序为
  durable mode → work → kind → aggregate → Camp → item → attempt → version →
  lease owner → expiry。gate 还必须证明 typed control signal 只进入专门 catch，
  且该 catch 位于 failure mapper 之前/之外；DB read/invariant error 只进入唯一
  async global-fatal owner，不能落入 provider failure mapper。gate还必须证明：
  exact command enum只有 set/invalidate且invalidate milestone精确含
  `.phase(identity:reason:)|.projectionCommitted(commitIdentity)`；Supervisor只有
  一个rumination callback、唯一phase invalidator、唯一projection publisher与
  per-identity串行coordinator；gate必须枚举全部production milestone callsite，
  证明所有`.phase`只经phase owner、所有`.projectionCommitted`只经commit
  publisher且无direct sink/event bypass；所有 fatal state writers、`.fatal` classification、
  `latchFatal`/`latchReadFailure` 和 revoke-all wrapper都 route async owner或先
  fail-fast证明零 rumination；顺序为 capture identities → revoke set permission →
  mark invalidation → await registered set-in-flight → await sorted invalidate →
  cancel tasks/return；sink path没有
  `Task.isCancelled`/`CancellationError` early exit或 `Task`；terminal/retry/
  cancel Store methods返回resulting work version，commit caller第一次await前
  reserve、rollback零reserve。gate还必须证明normal start specialized Store仅由
  Supervisor调用且返回既有`DurableWorkEnqueueResult`，Orchestrator只是façade；
  `.inserted`真实顺序为transaction return→validate exact kind/aggregate/ingestion+
  queued attempt0/`version=1`→reserve full identity+register process-local
  global-claim barrier（均在
  第一次await/reentrancy前）→await delivery→release barrier→re-read mode/work→
  conditional kick→return。全部pump/timer/kick/global claim入口在barrier期间零DB
  claim且零跨kind skip；preparation-replay绕过resolver/Store start，transaction
  `.replayed`与其汇入同一按workId waiter/conditional-kick分支，禁止identity
  construction/reserve/direct event/reload，delivered/restart无waiter为零等待/
  零第二event；start rollback/conflict零barrier/reserve/sink/kick。
  halt的pre-clear→cancel→persist→planning cleanup→
  rumination commits→projection deliveries→didCommit/`haltStateChanged`顺序成立；
  production显式传sink，default-use tests不拥有rumination。它还须锁
  Orchestrator full-commit receipt/monotonic version、exact-match
  remove→tombstone→typed emit、empty/tombstoned/new-generation仍emit nil refresh，
  以及 App one-listener/direct-await、same-snapshot reconcile、typed exact clear、
  always-reload、background Camp不导航、目标ingestion所属Camp的startup
  persisted snapshot成功load/ready后才enable command、load failure保持disabled/
  显式失败与restart-empty→recovering。gate还必须解析真实AppStore initializer与
  lock类型，证明`private let stateDirectoryLock`由AppStore lifetime持有、
  `StateDirectoryLock(directoryURL:appSupport)`成功发生在唯一production
  `AppDatabase(path:<same-root>/agentloop.sqlite)`之前，production DB opener
  callsite精确为1；并锁定`StateDirectoryLock`的nonblocking exclusive
  `flock`、`EACCES|EAGAIN` fail-fast与deinit unlock/close。既有
  `stateDirectoryLockRejectsSecondFileDescriptionAndReleases`必须在完整
  `swift run RunTests`全绿；`StateDirectoryLock.swift`与`SupportTests.swift`
  byte-identical且不进入13+2 allowlist。并证明
  phase/projection两个helper不并发sink、commit-first与fatal/control-first都等待同一
  coordinator且无Task/死锁；还须证明DEBUG consume caller在该真实handler中精确为
  first-after-real-gates-before-organizing与
  second-after-awaited-organizing-and-real-gates-before-parse两处且均被matching
  `#if DEBUG`包围，release caller为0。
  复制 helper、substring/count-only
  sentinel 或未锁 enclosing owner/call order 均不算通过。
- normal start/user retry inserted、terminal success、deterministic/exhausted
  failure、retry transition或actual user cancel transaction成功后，只经该
  resulting work的完整
  `.projectionCommitted(commitIdentity)` milestone发布刷新；matching registry可
  由该commit event原子清除并在payload带exact optional identity，phase-less、
  tombstoned或different/newer registry仍必须发refresh且optional为nil。projection
  milestone先reserve时，later control/global phase caller等待它并零第二clear；
  phase invalidation先reserve/完成时，later真实projection仍发送一次refresh且
  optional为nil。persistence rollback不得 reserve/deliver projection milestone，
  必须保留live phase、claim与适用pending proposal。
  start attempt-zero `workVersion=1` commit另由global-claim barrier保证refresh delivery先于任何
  claim/positive phase；replay为零commit milestone，只可等待同进程既有in-flight
  start delivery。start `V`与reentrant cancel/halt `V+1`必须顺序refresh，start
  恢复后重验且不得kick已canceled work。
  halt/global-fatal是actor control winner，按§6.4.5和本节先完成sorted phase
  clear再取消task；halt cleanup真实commit后仍逐个发布projection refresh，即使
  phase已清。后续halt persistence/cleanup失败保持suppressed/recovering，不恢复
  旧phase且不为未commit row发milestone。每一terminal/retry/cancel/halt路径都必须
  测试registry零泄漏、full commit identity exactly-once、same phase identity的
  higher workVersion不被吞、unseen lower version fail-fast与stale phase invalidation
  零事件。App只接受与持久active work ID、attempt精确匹配的live event；stale
  phase不得覆盖。
- DB 为 `.ruminating` 但进程内无 matching live phase 时，UI 显式使用新增
  `.recovering`，exact 文案 `正在恢复`，不得 `?? .reading`。recovering 的阶段列
  精确为 `[saved,recovering]`；live 阶段列精确为
  `[saved,reading,extracting,organizing]`。
- A2 不允许从 `needsReview` 再 start，所以不修改 `RuminationMaterializer`。
  `FeedService.discard` 与 Adapter 的 ingestion delete scope 必须在同一 transaction
  先拒绝 item `.ruminating` **或**任何 active rumination work；两项 race 均由
  transaction fence 收口。`AppDatabase.setCampArchived(true)` 同一 transaction
  拒绝 Camp 内 active rumination。`RuminationResult.swift`、
  `RuminationMaterializer.swift`、`EventKind.swift` 与
  `PlanningProviderResolver.swift` 均保持 byte-identical。

### 6.5 Candidate 转 Mission

- 唯一合法命令是 `convertCandidateAndEnqueuePlanning`。
- 事务内完成：校验 candidate / note / cow residency → 创建 Squad/Mission → candidate `.converted` + `missionId` → planning work → 事件。
- 重放返回原 Mission ID。
- `Orchestrator.startMission` 后再 `linkConverted` 的两步路径在 P1-A 删除；`linkConverted` 不再是 App 可调用 API。

### 6.6 Schedule

P1-A4 的 `v12-p1-schedule-fire` 新建 `schedule_fire` 与
`schedule_evaluation_cursor`，DDL 见 §18。没有未使用的 `intended` 状态；一次
transaction 的结果只能是 `started` 或 `failed`。

- 原始 slot 只允许一条 `(scheduleId, slotKey, replayOfFireId IS NULL)` fire。
- schedule slot 不再先更新 `lastFiredAt`。原始 slot 无论成功或校验失败，transaction
  最后都推进 `schedule_evaluation_cursor`，所以 scheduler 不会围绕 failed slot
  无限重放；只有成功 started 才更新 `schedule.lastFiredAt`。
- `startScheduledMission` 单事务插入 started fire、Mission/Squad、planning work、
  `schedule_fired`，更新 evaluation cursor，并在最后更新 `lastFiredAt`。
- 如果校验失败，单事务写 failed fire、`schedule_missed` 和 evaluation cursor；
  不建 Mission/work、不更新 `lastFiredAt`。该原始 slot 永久标记为 missed，不会因
  配置后来修复而自动重试。
- 用户明确“重放错过时段”才可调用
  `replayMissedScheduleFire(originalFireId,replayIdempotencyKey,...)`；它必须引用
  failed 原始 fire，以全局唯一 replay key 新建一条 `replayOfFireId` fire。重放
  重新校验并产生自己的 started/failed 终态，不改变历史 evaluation cursor 或
  `lastFiredAt`。同 key/同 payload 返回原结果，同 key/异 payload 抛 conflict。
- 事务成功后即视为“已出发”；内存 planner 是否立即启动不影响 slot，因 planning work 可恢复。
- guide broadcast / notification 失败不能把已创建 Mission 说成“未出发”，应写独立 failure。

## 7. 失败、追踪与显式降级

迁移 `v13-p1-observability` 新建：

### 7.1 `failure_record`

字段：`id`（即 trace ID）、`operation`、`scopeType`、`scopeId`、`severity`、`errorCode`、`userMessage`、`diagnosticJson`、`state(open|resolved)`、`firstSeenAt`、`lastSeenAt`、`occurrenceCount`。

规则：

- 每次用户发起或后台调度的顶层 operation 先创建 trace ID。
- 数据库可写时持久化 failure；数据库本身不可写时，至少用 `os.Logger` 输出相同 trace ID，UI 显示同一 ID。
- UI 文案格式固定为“操作失败……追踪 ID：XXXXXXXX”；不显示秘密、原始凭据或完整外部响应。
- 成功空列表和加载失败是不同状态；失败不能投影为 `[]`、`nil`、`false` 或默认成功。

### 7.2 `context_degradation`

字段：`id`、`missionId`、`cardId`、`dependencyType`、`dependencyId`、`policy(required|optionalApproved)`、`traceId`、`detail`、`createdAt`。

规则：

- 明确选入 Understanding / OutcomeContract 的知识、MCP、文件或工具为 required；读取失败必须阻塞受影响 Card。
- 只有契约明确标为 optional 的依赖可继续；继续前写 degradation 记录和事件，UI 可见。
- legacy Mission 的自动“最近笔记”是 optionalApproved，但读取失败必须记录 degradation，不能静默返回空。
- 已在 Cow 工具白名单显式选择的 MCP 工具视为 required。
- MCP registry 查询失败、秘密读取错误与启动失败必须可区分；Keychain `errSecItemNotFound` 才是正常“不存在”。

### 7.3 `try?` 处置规则

P1 必须建立逐项 inventory 并分类：

1. **业务读写、Keychain、权限、MCP、知识、状态机**：禁止 `try?`；使用 typed error + failure reporter。
2. **可验证的解析投影**：允许返回显式 `.invalid(traceId)`，不允许伪装为空。
3. **取消后的 sleep、幂等 cleanup**：可保留 best-effort，但必须有注释；cleanup 失败若影响安全或数据完整性仍需记录。

`AppStore.swift` 只按 P1 契约消费者抽取 Runtime、Mission、Input/Rumination、Acceptance 与 Failure 工作流；OAuth callback 和未触及的历史 UI 不做无目标搬家。

## 8. 全局领域事件与信封

迁移 `v14-p1-control-contracts` 新建 `domain_command_receipt`、`domain_event`、
`event_outbox`、`inbox_message` 以及 §9–§11 的 projection/version 表；精确 DDL
见 §18。

### 8.1 Command receipt 与 `domain_event`

每个新领域写命令只有一个 `commandIdempotencyKey`。事务开始先
insert-or-validate `domain_command_receipt`：

- 新 key 写 `commandType`、canonical `commandPayloadHash`、预期 `eventCount`；
- 已存在且 type/hash/eventCount 相同，返回 receipt 中的 canonical `resultJson`；
- 同 key 的 type、hash 或 eventCount 任一不同，抛
  `DomainCommandReplayConflictError`；
- receipt、全部 aggregate projection、全部 events、全部 outbox 和最终 result
  必须在同一 transaction，所以不存在只追加一半 aggregate 的重放状态。
- `resultJson` 只能是 `CampSafeCommandResultV1`（IDs/hash/code/version/count/time），
  不得复制 Input/Goal/prompt/path/URL/session/operation 正文；其 hash 仍按 §5.1。

所有 command 的 `CommandEnvelopeV1` 固定包含
`idempotencyKey/actorType/actorId/deviceId/correlationId/causationId/occurredAt`。
`commandPayloadHash` 是
`CanonicalJSONV1({"envelope": <完整 envelope>, "payload": <typed payload>})`
的 whole hash，缺字段、nullability变化或 envelope任一值变化都 replay conflict。
`actorId/deviceId` 只允许存在 sealed in-memory envelope与 `domain_event` 专列；
`domain_command_receipt.resultJson` 和 `domain_event.payloadJson` 的 exact-key decoder
必须拒绝 `actorRef/actorId/actorType/deviceId/accountId/accountIdentifier` 等用户、
设备或账号标识 key。receipt/event safe JSON不得靠“后续再擦”容纳这些字段。

一个多 aggregate 命令按 plan 规定的稳定顺序从 0 编号 event ordinal。每个 event
保存 `commandIdempotencyKey` 与 `eventOrdinal`，其
`eventIdempotencyKey` 固定派生为：

```text
<commandIdempotencyKey>#<4位十进制ordinal>:<aggregateType>:<aggregateId>
```

`eventIdempotencyKey` 全局 unique，`(commandIdempotencyKey,eventOrdinal)` 也
unique；不再把一个 command key 直接作为多条 event 的 unique 值。事务提交前校验
实际 event 数等于 receipt.eventCount，序号从 0 连续且无缺口。

`domain_event` 仍以 `(aggregateType,aggregateId,aggregateVersion)` unique；
每条 event 直接保存稳定 `campId`。payload 只能是
`CampSafeAuditPayloadV1` canonical object：aggregate/ref ID、hash、稳定 code、
枚举值、version、count 与时间；禁止正文、prompt、文件 path/URL、外部 session/
operation ID、用户/设备账号标识。正文只留在可擦除 projection/blob 中。actor type 固定为
`user|system|coach|cow|engine|device`。receipt/event 均以 abort trigger 禁止
UPDATE/DELETE。旧 `event` 不迁移、不伪造 actor；Mission/Card 在 P1 中参与新契约
的命令采用 dual append，新 domain event payload 引用旧 event ID。
每条 event 的 `actorType/actorId/deviceId/correlationId/causationId/occurredAt`
必须逐字段等于 command envelope；`recordedAt` 由 owning Store 在 transaction内生成，
不得由 caller 提供。user UI command要求 non-null deviceId；correlationId始终
non-null；causationId 依 envelope 保持 exact nullable。missing/wrong/nullability或
`recordedAt < occurredAt` 均 rollback。
普通 Ingestion 删除的 envelope合法 shape更窄且唯一：
`actorType='user'`，actorId/deviceId/correlationId均为 trimmed nonempty string；
causationId是唯一 optional identity，只能为 NULL或 trimmed nonempty string；
occurredAt必须是 canonical UTC、可排序的 finite instant。空字符串、invalid/nonfinite
time或 caller提供 recordedAt都无法 prepare。

### 8.2 Outbox / Inbox

- `event_outbox`：`eventId` unique、
  `state(pending|dispatching|sent|failed)`、`attempt`、`notBefore`、lease、
  `lastError`；Camp scope 由 `domain_event.campId` 唯一推出。P1 只验证本地 enqueue /
  claim/release/idempotent mark，不发送云端。
- `inbox_message`：`id`、nullable稳定 `campId`、`sourceDeviceId`、
  `idempotencyKey` unique、`payloadHash`、
  `state(received|applied|rejected)`、`receivedAt`、`appliedAt`、`errorCode`。只有已
  routing 的 message 才有 campId；P1 只做本地 contract tests。
- payload hash 或 idempotency key 相同但内容不同必须拒绝并记录冲突。

## 9. InputEnvelope

### 9.1 字段

`input_envelope`：

- `id`、`schemaVersion = 1`、`aggregateVersion`
- `idempotencyKey`
- `sourceType`：`text` / `url` / `file` / `image` / `audio` / `device` / `connector`
- `sourceDeviceId`、`connectorId`、`authorId` nullable；本机 App 捕获时 `sourceDeviceId` 使用稳定本机安装 ID，只有外部来源未知时才可为空
- `capturedAt`
- `inlineText` 或 `payloadRef`（非 tombstone **恰好一个**，不能把大二进制塞进 DB）
- `contentHash`
- `candidateCampIdsJson`
- `campId` nullable
- `explicitIntent`：`unspecified` / `archiveOnly` / `organize` / `createGoal` / `startNow`
- `privacyLevel`：`localOnly` / `encryptedSync` / `cloudExecution`
- `status`
- `errorCode`、`errorMessage`；解析 attempt 只来自 active/latest
  `durable_work.attempt`，InputEnvelope 不复制计数
- `parentInputId` nullable
- `retentionState`：`active` / `deletionRequested` / `deletedTombstone`
- `createdAt`、`updatedAt`、`deletedAt`

### 9.2 状态机

```text
captured
  ├─> campAssignmentRequired / campAmbiguous / coaching / archived / goalCreated
  ├─> parseFailed ─> captured
  └─> deletedTombstone

campAssignmentRequired / campAmbiguous ─> coaching / archived / goalCreated
coaching ─> archived / goalCreated
```

- `capture` 必须在同一 transaction 插入 InputEnvelope 和 durable work kind
  `inputParsing`；Input projection 保持 `captured`，异步进行中只由 work
  `queued|running|retryScheduled` 表达，不再复制一个可能永久卡住的 `parsing`
  projection。
- input parsing 使用 §6 的 claim、lease、attempt、有限重试、adoption、cancel 与
  stale-result 规则。success 同一 transaction 更新 Input terminal routing
  status、写 events 并 terminalize work；deterministic/exhausted failure 同一
  transaction 置 `parseFailed`；删除/cancel 同一 transaction cancel work 并置
  tombstone。`parseFailed -> captured` 的 `requeueParsing` 创建新幂等 work。
- `startNow` 仍必须产生最小 UnderstandingCard 和 OutcomeContract。
- 无法确定 Camp 时必须停在 assignment / ambiguous，不能选择默认 Camp。
- 单条 Input 删除以及 Camp 删除传播都使用同一 tombstone 形状：保留
  `id/schemaVersion/aggregateVersion/idempotencyKey/sourceType/capturedAt/contentHash/
  campId/createdAt`；清空 `sourceDeviceId/connectorId/authorId/inlineText/payloadRef/
  errorCode/errorMessage/parentInputId`；固定
  `candidateCampIdsJson='[]'`、`explicitIntent='unspecified'`、
  `privacyLevel='localOnly'`、`status=retentionState='deletedTombstone'`，
  `updatedAt=deletedAt` 且 `deletedAt` 非空。Store 和 DDL 必须逐字段强制此形状，
  不得把可能含隐私的 routing、author、device 或错误正文留在 tombstone。
- Store 与 DDL 强制
  `status == deletedTombstone` 当且仅当
  `retentionState == deletedTombstone`；两者必须在同一 deletion transaction
  改变，不能出现 active retention 的 deleted status 或相反组合。
- P1 为旧 `ingestion_item` 提供兼容 adapter；不批量伪造历史 InputEnvelope。新 P2 入口只写 InputEnvelope。

## 10. Goal Controller 与 Coding 教练

### 10.1 Goal

`goal_controller` 字段：

- `id`、`campId`、`title`、`rawIntent`
- `status`：`clarifying` / `ready` / `active` / `paused` / `achieved` / `abandoned` /
  `failed` / deletion-only terminal `deletedTombstone`
- `currentUnderstandingVersion` nullable
- `currentOutcomeContractId` / `currentOutcomeContractVersion` nullable
- `aggregateVersion`
- `createdByActorId`、`createdAt`、`updatedAt`

合法转移：

```text
clarifying -> ready / abandoned / failed
ready -> abandoned / failed
active -> paused / achieved / abandoned / failed
paused -> active / abandoned / failed
achieved -> active / abandoned / failed
```

- `ready` 要求存在已确认 UnderstandingCard。
- P1-C 只实现到 `ready`，不暴露 activate/active/paused/achieved 命令；它的完成门不
  依赖尚未存在的 v15 schema。
- P1-D 创建 OutcomeContract 后才增加 `activate/pause/resume/achieve`：`active`
  要求已确认 UnderstandingCard + active OutcomeContract。下游 return/revoke/
  invalidation/new OutcomeVersion 可用系统命令把 `achieved -> active`，不得伪留
  achieved。
- Mission 必须通过 `goal_mission_link` 关联 Goal；该表的精确 schema 见 §18。
  P1 前历史 Mission 可保持无 link，但不能进入新金路径指标。

### 10.2 教练 actor

P1 固定教练为系统职责，不先做成 Cow：

- actor type：`coach`
- actor ID：`system:coach:v1`
- 它负责澄清、解释为什么需要信息、生成 Understanding 草案和提出问题；
- 它不能确认 Understanding、授予权限、替用户验收或修改 OutcomeContract；
- 工作记忆归 Goal / CoachSession；经确认的营地事实进入 Camp Memory；跨营地偏好必须独立晋升；
- 所有问题、回答、草案版本和失败写 domain event。

`coach_session` 字段：`id`、`goalId`、`inputId`、`actorId`、`status(interviewing|waitingForUser|readyForConfirmation|confirmed|canceled|failed)`、`currentUnderstandingVersion`、`pendingQuestionId`、`traceId`、`aggregateVersion`、时间。

`coach_question` 字段：`id`、`sessionId`、`decisionKey`、`prompt`、`recommendation`、`reason`、`answerJson`、`state(open|answered|withdrawn)`、时间。每个 session 同时最多一个 open question。

教练异步调用使用 durable work kind `coach`；重启后从 session、问题和 Understanding 版本恢复，不依赖聊天内存。

## 11. UnderstandingCard

`understanding_card_version` 使用 `(id, version)` 复合主键，字段：

- `goalId`
- `problem`
- `scenario`
- `targetAudience`
- `goalsJson`
- `nonGoalsJson`
- `deliverablesJson`
- `constraintsJson`
- `acceptanceCriteriaJson`
- `verificationPlanJson`
- `resourceRefsJson`
- `requiredCapabilitiesJson`
- `budgetPolicyJson`
- `assumptionsJson`
- `acceptedRisksJson`
- `status(draft|awaitingConfirmation|confirmed|superseded|withdrawn)`
- `contentHash`
- `createdByActorId`
- `confirmedByActorId` / `confirmedAt`
- `createdAt`

规则：

- 修改正文总是新版本。
- 只有 user actor 可以确认首次和发生实质变化的版本。
- `startNow` 可以把创建 + 用户点击作为同一明确版本的确认，仍必须留记录。
- confirmed 内容不可原地更新；新确认版本把旧版置 superseded。
- 所有开工命令必须引用精确 `(understandingId, version, hash)`。

## 12. OutcomeContract、Outcome、Verification 与 Acceptance

迁移 `v15-p1-outcome-contracts`。

### 12.1 OutcomeContract

`outcome_contract_version` 以 `(id,version)` 为主键，并精确引用 Goal 与 confirmed
Understanding version/hash。deliverables、acceptance criteria、依赖、风险、
acceptance owner/policy 和 content hash 均进入不可变版本。

Verification requirements 不再只藏在不透明 JSON 中。权威结构为：

- `verification_requirement_group`：稳定 `groupId`、`mode(all|any)`、ordinal；
- `verification_requirement`：稳定 `requirementId`、独立
  `requirementVersion`、group、verifier type/id、method、rule ID/version、
  canonical config 与 `requirementHash`。

Contract 激活要求至少一个 group 且每组至少一个 requirement；Coding outcome 至少
一个 `deterministic` requirement。`verificationRequirementsJson` 只可作为由上述行
canonical 编码生成的快照，hash/行不一致时拒绝激活。激活后正文和 requirement 行
不可变；新 Contract version 追加版本并使旧版未完成 verification 不再适用。

### 12.2 Outcome

`outcome` 是 head：`id`、`goalId`、`missionId`、`contractId/version`、`currentVersion`、`state`、`aggregateVersion`、时间。

`outcome_version` 是不可变内容：

- `(outcomeId, version)`
- contract ID/version/hash
- `producerActorId`、`runIdsJson`
- `manifestJson`（文件、URL、外部对象或状态回执）
- `contentHash`
- `createdAt`

下表是 Outcome **唯一权威状态机**；§19 只能引用本表，不能另增边：

| 命令 | 允许 from | 唯一合法 to |
|---|---|---|
| `recordInitialOutcome` | 不存在 Outcome；linked Mission 为 `executing|delivering` | 原子创建 head + immutable version 1，state=`produced` |
| `beginVerification` | `produced` / `verificationFailed` / `blocked` | `verificationPending` |
| `reduceVerification` | `verificationPending` / `verificationFailed` / `blocked` | `verificationPending` / `verified` / `verificationFailed` / `blocked`，由 reducer 唯一决定 |
| `markDelivered` | `verified` | `delivered` |
| `acceptOutcome` | `delivered` | `accepted` |
| `returnOutcome` | `delivered` / `accepted` | `returned` |
| `revokeAcceptance` | `accepted` | `revoked` |
| `invalidateVerification` | `verificationPending` / `verificationFailed` / `blocked` / `verified` / `delivered` / `accepted` | 非 `accepted` 一律 `verificationPending`；`accepted` 唯一到 `invalidated` |
| `recordNewOutcomeVersion` | `returned` / `revoked` / `invalidated` / `verificationFailed` / `blocked` | `verificationPending`，并令 currentVersion + 1 |

其他 from/to 一律 `InvalidOutcomeTransitionError`；`recordInitialOutcome` 只创建
v1，`recordNewOutcomeVersion` 只创建后续版本；不存在
`recordProducedVersion` 别名或表外 invalidation 边。

成果正文、manifest 或依赖改变必须产生新 OutcomeVersion，旧 Verification 自动失效。

### 12.3 Verification

`verification_record` append-only：

- `id`、command idempotency key
- contract ID/version/hash
- requirement ID/version/hash
- outcome ID/version/hash
- `verifierType(cow|deterministic)`
- `verifierId`
- `method(command|tests|build|artifactHash|externalReceipt|modelSupplement)`
- `ruleId` / `ruleVersion`
- `environmentJson`
- `commandOrRuleJson`
- `rawResultRef`
- `evidenceHash`
- `result(passed|failed|blocked|invalid)`；`invalid` 只表示本次 verifier 无法形成有效结论
- `supersedesVerificationId` nullable
- `createdAt`

`verification_result_head` 是每个 OutcomeVersion/requirement 的 mutable CAS
projection，指向当前 VerificationRecord 并保存派生 result/version。新 record
必须显式 supersede 当前 head（首条为 NULL）；重复 idempotency 返回同一 record，
旧 head 或并发结果不能覆盖新 head。

`verification_invalidation` append-only：`id`、`verificationId`、
`reasonCode`、`dependencyType`、`dependencyId/version/hash`、`eventId`、`createdAt`。
同一 verification/reason/dependency 唯一。存在任何 invalidation 行时，该
VerificationRecord 派生状态为 invalid；若它仍是 result head，失效事务把 head
派生状态置 invalid。不得 UPDATE 原 VerificationRecord。

Reducer 固定为：

1. 只读取当前 OutcomeVersion 与 active Contract exact version/hash 下、每个
   requirement 的 result head；
2. head 缺失、record/hash/version 不匹配、record 为 failed/blocked/invalid、存在
   invalidation，均不算 passed；
3. `all` group 要求组内每个 requirement 当前均 passed；`any` group 要求至少一个
   当前 requirement passed；
4. **每一个 group 都必须满足**，Outcome 才可
   `verificationPending|verificationFailed|blocked -> verified`；
5. failed 但仍可重跑的 head 使 Outcome 为 `verificationFailed`，blocked 使其
   `blocked`；缺失/失效为 `verificationPending`。新有效 record 可把三者重新归约；
6. duplicate record 由 command receipt 返回旧结果；superseding record 只替换同一
   requirement head，不能抵销别的 requirement。

独立性：

- Cow verifier 不能等于该 OutcomeVersion 的 producer actor。
- 确定性 verifier 在同一步骤中只读被验证成果；若要修复，退回执行并创建新 OutcomeVersion。
- Coding 成果至少一个 deterministic record 通过；model supplement 不能单独通过。

fail-closed：

- 缺证据、超时、非零退出、hash 不符、规则版本未知、环境缺失、结果无法解析均不得变成 passed。
- Outcome、Contract、规则或依赖 evidence hash 改变，必须追加 verification invalidation。
- `markDelivered` 只能由 `DeliveryCoordinator` 以 system actor
  `system:delivery:v1` 调用，且必须在同一 transaction 重跑 reducer，确认当前
  OutcomeVersion 为 verified、无 active invalidation、manifest refs 均可读；user、
  Cow、adapter 和 UI 不能直接调用。

### 12.4 Acceptance

`acceptance_policy_version` 的精确字段/约束见 §18，固定：
policy/version、outcome type、最大 risk class、适用 actor、validFrom/validUntil、
最大 Outcome 年龄、要求全 verification、status/revocation、contentHash。
Policy schema **没有**允许首次 onboarding、首次成果类型、主观创作、公开发布、
付款、删除或外部发送的 override 位。
P1 store 只允许 `policy` actor 使用 active、未过期、hash 匹配的版本。

`acceptance_record` append-only：

- `id`、idempotency key
- contract ref
- outcome ref + hash
- `subjectType(user|policy)`、`subjectId`
- `policyId/version` nullable
- `decision(accepted|returned|revoked)`
- `reason`
- `createdAt`

规则：

- Policy store 在读取 policy **之前**先执行不可绕过 hard guard：首次 onboarding、
  该 user 的首次 outcomeType、Contract 标记主观创作/公开发布/付款/删除/外部发送、
  riskClass high/irreversible 或 reducer 未 verified 任一为真，立即
  `user_acceptance_required`。这些事实来自 acceptance history 和不可变
  OutcomeContract 显式布尔字段，不接受调用者自报。只有全部为假，才继续验证
  active policy、时间、outcomeType、normal-or-lower risk、age 和 actor。
- Acceptance 事务同时写 record、Outcome head、Goal/Mission 投影、domain event 和指标 credit / reversal。
- UI 只有在事务成功后导航或庆祝；失败保持验收页并显示 trace ID。
- 退回创建新执行分支或 OutcomeVersion，不能重写旧证据。

### 12.5 北极星计数

`outcome_metric_credit` 以 `outcomeId` 唯一：

- 只有当前 OutcomeVersion 已验证且 accepted 时 active；
- 重跑、换引擎、重复 acceptance 不重复计数；
- returned、revoked、Verification invalid 或依赖失效时 reversed；
- 同一个 Outcome 的新版本重新 accepted 只恢复同一 credit；
- 真正不同交付物必须有不同 Outcome ID 与 Contract deliverable。

## 13. ApprovalGrant

Grant 的 scope 不使用 opaque `allowanceJson`。`approval_grant` 显式保存：

- `scopeVersion = 1`、`cardId`、`toolId`、`approvedInputHash`；
- typed grantor actor + optional exact policy ref、grantee、capability、purpose、dataLevel；
- validFrom/validUntil、maxUses/usedCount、status/revocation。

`approval_grant_use` 是 external operation 当前 projection，显式重复 tool/input
用于 DB match，状态为
`reserved|dispatching|accepted|succeeded|failedFinal|released|crashUnknown|
abandonedUnknown`。
另有 append-only
`external_operation_receipt`，phase 为
`dispatchIntent|adapterAccepted|effectConfirmed|noEffectConfirmed|
reconciliationFailed|userResolved`，
保存 non-null receipt idempotency key、per-use ordinal、canonical
`receiptJson/receiptHash`、typed authority、adapter operation ID 与净化 receipt
ref；完整 DDL 见 §18。

规则：

- capability、scope、time 三者缺一不可。
- 单次工具审批生成 `maxUses = 1`，并精确匹配 Card + tool ID + canonical input hash。
- `MissionAutonomy` 只是“何时要求审批”的兼容策略，不等于 Grant。
- 工具 adapter descriptor 必须声明
  `replaySafe|idempotencyKeyed|nonReplayable`。执行前 `reserveUse` 原子验证
  capability/scope/time/次数并建 reserved；同 idempotency key 同 payload 返回旧
  use，异 payload conflict。
- 只有仍为 `reserved` 且尚无 `dispatchIntent` receipt 时，才能证明 dispatch
  没开始并 `reserved -> released`，不增加 usedCount。
- Camp deletion 不复用 adapter no-effect resolution 来处理尚未派发的 reserve。
  F2-only
  `ApprovalGrantStore.releaseReservedGrantUseForCampDeletion` 接受无 public
  initializer、由 current deletion claim 生成的 target；每次 transaction 重验
  Camp/grant/use/job/work/attempt/lease/phase、expected use/grant versions、command
  key/whole hash，并要求 use exact `reserved`、`dispatchIntentAt/
  adapterAcceptedAt/adapterOperationId/finishedAt` 全 NULL、且不存在任何
  `external_operation_receipt`。它只 CAS `reserved -> released`、写
  `finishedAt`/version 与 safe command receipt/event；不新增 external receipt，
  不改 Grant `usedCount/status/version`，不 dispatch、refund 或处理任何已派发 use。
  ordinary release/dispatch、request deletion 与 specialized release 由 serialized
  writer + version CAS 竞争，只有一个 winner；replay 返回同 receipt，异
  use/version/job/hash conflict。
- 非事务调用前先原子写
  `reserved -> dispatching`、增加 usedCount、追加正确命名的
  `dispatchIntent` receipt；然后把**同一 use idempotency key**交给 adapter。此
  commit 只说明本地准备派发，不声称 adapter 已接受。
- 只有 adapter 实际返回 accepted/operation ID 后，才追加 `adapterAccepted`
  receipt 并 `dispatching -> accepted`。外部成功后
  `dispatching|accepted -> succeeded` 并追加 `effectConfirmed`；确定已发生但
  业务失败为 `failedFinal`，仍消耗次数。
- crash 发现 dispatching/accepted 但无 effect/no-effect receipt：
  - replaySafe：以同 key 安全重跑并收敛；
  - idempotencyKeyed：调用 adapter reconcile/同 key replay 取得同一 operation
    回执；
  - nonReplayable：无论 crash 位于 dispatchIntent commit 后、真实调用前、调用中
    或 adapter acceptance 后，都原子进入 crashUnknown，禁止自动重放/自动 release，
    保留已消耗次数并创建 urgent Attention。
- fail-closed resolution 只有两类，均要求
  `useId + expectedVersion + commandIdempotencyKey`：
  1. adapter 以 typed `AdapterNoEffectAttestation`（adapter authority、exact use/key、
     operation ref、canonical evidence）调用 `confirmAdapterNoEffect`；
     `dispatching|accepted|crashUnknown -> released`，且只允许一次减少 usedCount；
  2. user 调用 `resolveExternalOperation` 只能确认 `succeeded`，或承认无法判断并进入
     consumed terminal `abandonedUnknown`；两者都不退款、不 replay。
  user 不能声明 no-effect，不能 release/refund。`noEffectConfirmed` 与
  `userResolved` CAS 并发只有一个 winner；一旦 `succeeded|abandonedUnknown`，
  后到 reconcile 永远不能退款或改写。`userResolved` receipt 的 result 只允许
  `succeeded|abandonedUnknown`。本地超时、EOF、用户猜测都不是 no-effect 证明。
- `confirmAdapterNoEffect` 同时带 expected use/grant version。唯一 refund 后 Grant
  status 的确定性 reducer 是：已经 revoked 永远 revoked；`now >= validUntil` 或已
  expired 永远 expired；否则新 `usedCount < maxUses` 才 active，等于 maxUses 仍
  exhausted。no-effect 不能撤销 revoke/expiry。与 revoke/expire 并发时单一
  transaction/CAS winner 后 loser 重读并按上述 reducer 收敛，绝不二次减 count。
- 所有 Grant use transition 只暴露 `ApprovalGrantStore` typed API；
  `ApprovalGate`/adapter 不直接写表。异步
  `ExternalOperationWorkflowCoordinator` 唯一拥有
  “DB dispatch intent commit → adapter call → receipt commit/recovery”边界。
- Camp 已进入 `deletionRequested|deleting` 时，普通 active-Camp authority 全部
  失效；只有绑定同 Camp/job/use 的 §14.2 deletion permit 可调用上述
  `releaseReservedGrantUseForCampDeletion`，或两个**既有已派发未决 use 的收口**：
  adapter-attested `confirmAdapterNoEffect`，或 user
  `resolveExternalOperation(succeeded|abandonedUnknown)`。它不得 reserve、
  dispatch、新增 use、恢复 permission 或把 consumed 次数退回；target use/grant/
  job/Camp/version 任一不符均零写入。
- nonReplayable 动作只能使用当次、single-use user Grant，禁止长期/批量自动 Grant；
  idempotencyKeyed/replaySafe 才可使用长期 Grant。
- “全开”只能批量创建明确 grants。
- 发布、付款、删除和外部发送不能由 P1 默认 grant。

## 14. Cow Identity、Camp Residency 与 Camp 隔离

迁移 `v16-p1-identity-memory`。

### 14.1 Cow Identity

`cow_identity`：

- `id`（沿用已有 Companion ID）
- `displayName`、`appearanceRef`、`personality`
- `baseRole`
- `defaultEnginePolicyJson`
- `status(active|retired)`
- `aggregateVersion`
- 时间

现有每条 Companion 各 backfill 一条 Cow Identity，ID 不变；P1 不删除 Companion 表。

### 14.2 Residency 与 Camp lifecycle

`camp_residency`：

- `id`、`cowId`、`campId`
- `role`
- `status(requested|authorized|active|paused|left|revoked)`
- `joinedAt`、`pausedAt`、`leftAt`、`revokedAt`
- `aggregateVersion`
- 时间

建立 partial unique index：同一 `(cowId, campId)` 在
`requested` / `authorized` / `active` / `paused` 中最多一行；`left` / `revoked`
历史可以保留多行。

合法转移：

```text
requested -> authorized -> active <-> paused
authorized/active/paused -> left / revoked
```

- 同一 Cow 可在多个 Camp active；每个 residency 的权限与记忆独立。
- 离营后保留历史，但不得读取新 Camp 内容或继续写入。
- 再次加入产生新 residency ID，不复活已 left/revoked 行。
- P1 backfill：`companion.campId` 有效时创建 active residency；`campId == nil` 不创建 residency，也绝不代表全 Camp 权限。
- 旧 UI 可把无 residency Cow 标为“未驻场”，但 Orchestrator、Planner、Schedule 和知识读取必须以 active residency 做授权。

#### Camp source of truth 与统一 write fence

`camp_lifecycle` 是唯一权威，状态机固定：

```text
active <-> archived
active|archived -> deletionRequested -> deleting -> deletedTombstone
```

`camp.archived` 仅是 legacy compatibility projection：`active=false`，
其余状态均 `true`；每次转移在同一 transaction dual-write，不允许独立更新。
普通 Camp-scoped mutation/dispatch/reserve/worker claim/session start 必须在同一
write transaction 调用 `requireActiveCampWrite(campId,
expectedLifecycleVersion:)`，只接受 lifecycle `active`、exact version 和
`camp.archived=false`；它永远不接受/解析 deletion permit。`archived` 返回 typed
read-only error；`deletionRequested|deleting|deletedTombstone` 永久禁止普通扩张
写。历史 read 对 archived 仍可见；deletedTombstone 只返回最小 tombstone。

退休权限不是这个 guard 的例外 flag，而是无 public initializer 的 opaque
`CampDeletionClaim` 与 transaction-local `CampDeletionPermit`。每次 specialized
transaction 都重验 exact `campId/lifecycleVersion/jobId/jobVersion/
confirmationHash/workId/workVersion/attempt/leaseOwner/job phase/allowed operation/
targetId+targetVersion/command key+whole hash` 后才临时构造 permit；它不是持久 bearer
token。lease renew/adopt、cursor/job/work replacement、lifecycle transition 任一发生
都会使旧 permit stale。状态白名单固定：

| lifecycle | 唯一允许写 |
|---|---|
| active | ordinary write、archive、request deletion |
| archived | dedicated unarchive、request deletion |
| deletionRequested | F2-only exact reserved Grant-use release、existing dispatched Grant resolution、engine safe terminalization、pending-proposal supersession、open user-request/ingestion/candidate terminalization、deletion claim/quiesce/artifact resolution/repair/enter deleting |
| deleting | exact resolution/terminalization、erase/repair/finalize |
| deletedTombstone | 只返回 already-committed receipt replay |

permit 不得创建普通 work/Goal/Mission/Grant/engine execution，不得读取新正文再派发，
也不得扩大 target set。

Camp scope 必须可直接或可证明枚举：`durable_work`、`domain_event`、
`input_envelope`、Goal/Outcome/Grant/Memory、`engine_session`、
`engine_execution`、proposal/artifact reference、Discussion/Attention/Growth
都有稳定 `campId` 或不可变 FK path；`event_outbox` 经 `domain_event.campId`，
legacy `event` 经 typed all-event `camp_event_scope`；legacy chat/note 经
`legacy_chat_scope/legacy_companion_note_scope` 区分 `camp|globalCow`。任何新
Camp-reachable table 未登记
`CampRetirementProjectionOwner` registry 时，archive/delete/finalize
`UnregisteredCampProjectionError` fail-closed；任一未登记的 Camp-reachable
TEXT/BLOB/ref column 则 `UnregisteredCampPrivateColumnError` fail-closed。

#### Legacy chat/note/event 的稳定 scope

v16 为每条 legacy chat thread 和 companion note 建不可变 scope：
`scopeKind=camp|globalCow`、Camp 可空、exact Cow 与 evidence kind。唯一 backfill：

- DM + `chat_thread.campId IS NULL` → `globalCow/dmThread`；
- Guide + non-null valid Camp → `camp/guideThread`；
- 其他 thread shape、missing Cow、thread/Cow mismatch 全 migration rollback；
- note 有 sourceThread 时继承 thread scope且 Cow 必须相同；
- 无 thread但有唯一 `companion_note_created -> mission -> Camp` cowork evidence 时
  为 Camp；无 creator event 为 `manualCow/globalCow`；
- 多 creator、dangling、cross-Camp 或互相冲突均 rollback。

post-v16 find/create thread 必须同 transaction 插 `legacy_chat_scope`；append
message先要求 scope row。note API 必须接 typed `LegacyContentScope`：
cowork 从 mission evidence 固定 Camp，DM distill固定 globalCow；raw note/message
insert authority被封闭。删除只选择 scopeKind=camp + exact campId，globalCow 永不
被 Camp deletion 改写。

`camp_event_scope` 覆盖**每一条** legacy `event` 与 `domain_event`，scopeKind 为
`camp|global`；domain event 只允许 Camp。resolver 无 default：

- `camp_halted|camp_resumed` 只有 refs/payload 均无 Camp 才是 global；
- `camp_archived` 从 payload exact camp；
- `base_cow_provisioned` 从 Camp+Companion，`cow_unlocked` 从 Camp+Cow；
- `ingestion_created` 从 payload/row，rumination completed/failed 经 ingestion，
  materialized 必须 ingestion+note 同 Camp；
- `camp_note_created` 经 note，`companion_note_created` 经 note scope；
- `schedule_missed` 经 schedule→template；
- 其余 `EventKind.allPersistedKinds` 必须由所有 non-null mission/card/run path
  推到同一个 Camp。

unknown kind、malformed payload、dangling ref、两条路径不同 Camp 均整笔 rollback；
event count 必须等于 scope count。v16 后唯一 package-internal
`appendLegacyEventAndScope` 同 transaction 插 event+scope；raw
`appendEvent`/`EventRecord.insert` 被封闭，缺 scope 的 event insert 由 trigger
abort。`EventKind.allPersistedKinds == resolver.keys` 是 migration/contract gate。

#### 可逆 archive

`archiveCamp` 仅在同一 transaction 得到以下逐项为零的
`CampQuiescenceReport` 后，CAS `active -> archived`：

- enabled schedule；
- `planning|executing|delivering` Mission；
- `todo|ready|running|blocked` Card；
- `endedAt IS NULL` Run 与 `lifecycleState='open'` 的 `user_request`；
- `queued|running|retryScheduled` durable work；
- 已归营且 `captured|campAssignmentRequired|campAmbiguous|coaching` Input；
- `clarifying|ready|active|paused` Goal、非终态 CoachSession；
- legacy Ingestion `queued|ruminating|needsReview`；
- ActionCandidate `proposed|accepted`；
- Grant use `reserved|dispatching|accepted|crashUnknown`；
- running engine execution、pending terminal proposal/proposal artifact prepare；
- `camp_provider_dispatch` 的 `prepared|started|returned`，与对应 active
  `guideChat|memoryPromotion` work 按 `(workId,attempt)` 去重后计数；
- `proposed|running|blocked` Discussion；
- Camp-scoped `received` inbox 与 `dispatching` outbox；
- 非终态 deletion job（理论上 lifecycle fence 已使其冲突）。

任一非零抛 `CampArchiveRequiresQuiescenceError(report:)` 且零写入。成功 transaction
只更新 lifecycle + `camp.archived`、command receipt、safe
`camp_archived` event/outbox；不 revoke residency/bridge、不 erase 正文、不自动改
Goal/Mission/Input。`unarchiveCamp` 是 dedicated user transition，不调用 active
fence：同 transaction 验证 archived、legacy bit=true、expected version、没有
deletion job，CAS `archived -> active`、dual-write compatibility bit、receipt/safe
event/outbox；不会自动启用 schedule。它与 request deletion 并发只有一个 CAS
winner。archive/unarchive 同 command key/whole payload hash 重放，异 payload
conflict。

#### Active Camp 中的普通 Ingestion 删除

普通 Feed 删除不是 Camp retirement 权限，也不能借用 `CampDeletionPermit`。P1-E
定义 `IngestionDeletionStore.prepareActiveIngestionDeletion(request:)` 为
`ActiveIngestionDeletionCommandV1` 的唯一 factory owner。prepare request只能含：

- 一次用户确认时已生成并由 controller原样保留的完整既有
  `CommandEnvelopeV1`：user actor、idempotency key、device/correlation/causation
  identity与 occurredAt；
- `campId`、`ingestionId`、`scope`。

request不得接受 lifecycle/version/status/content/snapshot/result ID、任何 affected
或 blocker count，以及 caller声称的 hash/row事实。Store在一次一致性 `pool.read`
transaction中重读 active lifecycle、legacy archived bit、ingestion完整行、optional
result完整行与五类 blocker actual counts，验证唯一 scope语义，再内部使用
`CanonicalJSONV1` 重算两个 full snapshot、完整 envelope+payload whole hash并派生
三项 affected counts。prepare返回 opaque sealed command handle与只含
ID/status/scope/count的 safe preview；rawText/title/URL/resultJson/userEditedJson
不进入 handle/preview/log。command的 package initializer/factory authority只有
Store持有，`InputWorkflowController`、Application、Adapter与 UI均不能铸造、复制
或改写 command。prepare只是快照，不持久化 receipt/event/outbox，也不安装 permit；
execute仍须在 writer中全量 revalidate，因此 prepare/execute TOCTOU fail closed。

sealed `ActiveIngestionDeletionCommandV1` 绑定：

- 完整 exact `CommandEnvelopeV1`、`campId`、expected active lifecycle version；
- ingestion ID/version/status/contentHash，以及
  `id/campId/sourceType/title/rawText/sourceURL/author/userIntent/contentHash/status/
  attempt/errorText/createdAt/updatedAt/version/terminalReason/redactedAt` 经
  `CanonicalJSONV1` 得到的 `ingestionSnapshotHash`；正文只参与调用端与
  transaction-local permit 的重算，永不进入 receipt/event/log；
- `scope(resultOnly|sourceAndResult|everythingIncludingProjection)`；
- optional result ID/version/snapshot hash；snapshot hash 是
  `id/ingestionId/pipelineVersion/resultJson/userEditedJson/materializedAt/createdAt/
  updatedAt/version/redactedAt` 全字段的 §5.1 canonical safe snapshot SHA-256；
  result正文只在调用端与 transaction-local UDF 中重算，不写进 event/log；
- expected `deletedResultCount/deletedIngestionCount/updatedIngestionCount`；
- fixed-zero `knowledgeSourceLinkCount/actionCandidateCount/
  nonterminalRuminationWorkCount/openRuminationAttemptCount/
  nonterminalProviderDispatchCount`；五项都进入 whole payload hash，缺失或非零
  command 无法构造；
- 不含自引用 hash字段、覆盖完整 envelope与上述全部派生事实的 canonical whole
  hash。

普通首次执行只允许 lifecycle=`active`、exact version 且
`camp.archived=false`。`archived|deletionRequested|deleting|deletedTombstone`，
以及 ingestion/结果任一 `redactedAt != NULL` 时都返回 typed lifecycle/deleted
error，零写入。唯一例外是 transaction 第一项先查
`domain_command_receipt`：同 key、同 command type、同 whole hash、同
`eventCount=1`，且 receipt result/hash/decoder 与 matching scope、唯一 event/outbox
完整的已提交 replay，即使 Camp 后来 archive/进入 deletion 或 source已经不存在，
也返回原 safe result；同 key type/hash/count任一维度不同仍 conflict，identity匹配
但 graph损坏则 integrity blocked。新 key 在 source已物理删除后返回 not found，
不能伪造第二次成功。

三个 scope 的唯一语义：

1. `resultOnly`
   - ingestion 必须是 `needsReview`，或是仍带旧 result 的 `failed`；两者的
     `terminalReason/redactedAt` 均为 NULL；
   - result 必须存在、ID/version/snapshot hash exact、`materializedAt=NULL`；
   - 不得存在 `knowledge_source_link`、任何 `action_candidate`、matching
     nonterminal rumination work/attempt/provider checkpoint；
   - transaction 物理删除 exact 一条 result，再 CAS ingestion
     `status -> queued`、`errorText=NULL`、`version+1`、`updatedAt=command time`；
     sourceType/title/rawText/sourceURL/author/userIntent/contentHash/attempt/
     createdAt 保留，terminalReason/redactedAt 仍 NULL；
   - expected counts 固定为 deletedResult=1、deletedIngestion=0、
     updatedIngestion=1；CAS affected count 必须 exact 1，不能把“未删除 ingestion”
     误当成“未检查 ingestion mutation”。
2. `sourceAndResult`
   - ingestion 必须为 `queued|failed|needsReview|discarded`，
     `terminalReason/redactedAt=NULL`；
   - 不得存在 link、candidate、matching nonterminal work/attempt/provider；
   - result 可不存在；存在时必须 ID/version/snapshot hash exact 且
     `materializedAt=NULL`；
   - 同 transaction 先删除 optional result，再删除 exact ingestion；expected
     counts 固定为 deletedResult=0|1、deletedIngestion=1、
     updatedIngestion=0，三项实际 affected count 都必须 exact；
   - 永不物理删除 candidate/link，也不通过 cascade 绕过它们。
3. `everythingIncludingProjection`
   - 永久在任何 receipt/event/projection write 前抛 typed
     `projectionDeletionUnsupported`；P1 不提供“顺便删除营地成果”的隐藏路径。

首次成功使用已有 v14 `domain_command_receipt` 与 `domain_event`，不增加
migration/table/column。package-internal sealed
`ActiveIngestionDeletionSQLPermitV1` 是唯一 mutation permit；它没有 public
initializer，不是 Camp deletion capability，也不能被 generic callback、其他 Store
或 test convenience 构造。

每个 `AppDatabase` instance在创建 `DatabasePool` 前先创建并强持有自己的非 global
`ActiveIngestionDeletionSQLPermitRegistryV1`，随后把该 exact registry捕获进
`Configuration.prepareDatabase`。`prepareDatabase` 是 release/product runtime
中唯一调用 `registry.installConnectionUDF(on: db)` 的位置；唯一 test-only例外是
下述 Permit 文件内 `#if DEBUG` 封闭 scenario runner的内部自有 fixture。setup API
接收 `GRDB.Database`，不能让 caller传 raw pointer。每个实际 SQLite connection只
安装一次。

`ActiveIngestionDeletionSQLPermit.swift` 是本合同唯一 raw SQLite ownership owner：
它独占 `GRDBSQLite` import、`sqlite3_create_function_v2`、C callbacks、
`sqlite3_user_data/value/result`、raw pointer role/autocommit读取与本 UDF所需的
`Unmanaged` ownership。为此 `AgentLoopCore` 可在 `Package.swift` 中增加来自**同一个
已解析 `GRDB.swift` package** 的直接 `GRDBSQLite` product dependency；不得新增
package、改变 GRDB version/revision或修改 `Package.resolved`，其他 target/dependency
不变。

install内部从 `db.sqliteConnection`取得 pointer identity，并以
`sqlite3_db_readonly(pointer, "main")` exact `0=writer/1=readonly` 标记 role；
其他返回值 setup fail closed。install固定执行下列唯一状态机：

1. 在 registry唯一 private synchronization boundary内先检查 sticky lifecycle
   fault；pointer索引必须不存在。若同一 pointer已有 `installing|installed` entry，
   立即设置 sticky `duplicateConnectionRegistration` 并抛 typed setup error，
   **零 SQLite C 调用、零 purge、零 replacement**；
2. 生成 random connection nonce、exact
   key=`(raw sqlite pointer identity, random connectionNonce)`、独立 cell与
   `ActiveIngestionDeletionSQLFunctionContextV1`，并在同一 boundary内先发布
   pointer→exact-key `installing` entry与 exact-key→weak-cell entry；
3. 释放 synchronization boundary，才执行
   `Unmanaged.passRetained(context).toOpaque()` 与唯一 raw registration call；
   `sqlite3_create_function_v2` 可能在返回前同步调用 `xDestroy`，所以任何可能触发
   SQLite callback/destructor的 C API都不得跨持 registry boundary；
4. raw call返回后重新进入 boundary。`SQLITE_OK` 必须仍有同 pointer/key/cell 的
   `installing` entry且无 sticky fault，随后只把 phase改为 `installed`；非
   `SQLITE_OK` 必须已经由同步 `xDestroy` 清除 entry并 invalidate cell，且不得留下
   sticky fault。任一 reconcile mismatch都设置 sticky typed lifecycle fault并使
   setup失败。

SQLite经 `pApp` 强持有 context，而 context强持有**同一 cell、同一 registry与同一
exact key**，不存在 registry→context强引用。registry/cell/lifecycle-fault mutable
state全部在上述同一 private synchronization boundary内访问；不得持有该 boundary
调用 raw registration。`xFunc` 与 `xDestroy` 必须是 Permit 文件内 file-private、
noncapturing top-level C-compatible functions并直接传入，不得保存为 global callback
`let` 或引入 MainActor-isolated callback storage。

唯一注册调用逐字为
`sqlite3_create_function_v2(pointer,
"agentloop_active_ingestion_deletion_permit_v1", -1, SQLITE_UTF8, pApp,
xFunc, nil, nil, xDestroy)`：`nArg=-1`，flags只有 `SQLITE_UTF8`，不标
`SQLITE_DETERMINISTIC`，也不得标 `SQLITE_DIRECTONLY`（规范 trigger必须调用它），
不得为本函数创建/保存 GRDB `DatabaseFunction`。`pApp` 只能来自
`Unmanaged.passRetained(context).toOpaque()`。

`xFunc` 只从 `sqlite3_user_data`取得 context；不捕获 `Database`、不查询/reenter
SQLite、不访问其他 connection、不落盘、不记录正文。合法调用只在 exact 53/63
arity、SQLite value type/nullability、step、exact key、cell generation、ordered
cursor与 active permit全部通过后返回 integer `1`；任一失败只返回稳定、无正文的
SQLite error `agentloop_active_ingestion_deletion_permit_rejected`，不得部分 consume
或泄漏输入。

`xDestroy` 对 non-null `pApp` 唯一执行
`Unmanaged<ActiveIngestionDeletionSQLFunctionContextV1>
.fromOpaque(pApp).takeRetainedValue()`，exact once；固定顺序是先使 cell及其 active/
finished generation全部失效，再只调用内部 typed
`removeDestroyedConnection(exactKey:cellIdentity:)` helper，让 context中的 registry
按**同一个 exact key与同一个 cell identity**删除 pointer索引和 weak entry。单次
callback内不存在、wrong key/cell或已被别的 connection替换均设置该 AppDatabase
registry的 sticky typed lifecycle fault；此后 connection setup、mutation lookup与
resolution lookup全部 fail closed。不得以 nearest/current/last-writer或清空全
registry掩盖 mismatch。

SQLite是 retained `pApp` 与 C destructor的唯一 owner；产品与 tests都不得手工调用
`xDestroy`，也不得对同一 `pApp` 第二次执行 `takeRetainedValue`。所谓 duplicate
cleanup测试只能由下述封闭 DEBUG scenario runner在内部仍强持 typed
key/cell/context时，对上述 registry remove helper做第二次受控注入；它必须设置
sticky fault，但**绝不是**第二次调用 C destructor。

`sqlite3_create_function_v2` 注册失败时 SQLite仍调用同一个 `xDestroy`；error branch
只把 SQLite code映射为 typed setup error，**不得**再手工 `release` context。成功
注册后，即使同一个 `prepareDatabase` 随后的其他 setup operation抛错，connection
teardown也必须触发同一 `xDestroy` 并精确清理，不能遗留 active entry/context。成功
`sqlite3_close` 在返回前触发 destroy/失效/精确清理；`sqlite3_close` 返回
`SQLITE_BUSY` 表示 connection仍打开，因而不 destroy、不清 entry且 cell继续对应该
connection；`sqlite3_close_v2` zombie只在最后一个 statement/blob/backup释放、真实
connection object销毁时触发 destroy。旧 context销毁并精确移除后，复用同一 pointer
identity的新 connection必须生成新 nonce/context/cell；旧 key/permit永不匹配。

`IngestionDeletionStore` 的 mutation path只可调用该 AppDatabase instance的
`requireWriterCell(for: db)`；runtime API接收 `GRDB.Database` 而不是 caller raw
pointer，内部以该 `Database` 的 pointer查询 exact key/weak cell，再验证 nonce、
role=writer、`db.isInsideTransaction` 且 `sqlite3_get_autocommit == 0`。
resolution path只可调用第二个封闭 API
`assertNoActiveGenerationForResolution(for: db)`：同样接收 `GRDB.Database` 并做
同一 AppDatabase exact pointer+nonce lookup与 writer-role验证，但要求
`!db.isInsideTransaction`、autocommit=1，只读断言 cell既无 active也无 finished
generation，返回 `Void`，不得返回 cell/key/nonce、install/consume/finish或清理任何
状态。readonly、wrong/missing pointer、stale weak entry、cross-AppDatabase、sticky
lifecycle fault或残留 generation一律 typed reject；resolver把该 reject归为
`commitOutcomeUnknown`。除唯一 setup API外，registry runtime surface只有上述两个
path-specific API，不暴露 enumerate、set-current、generic lookup或
caller-supplied nonce/raw-pointer API。

唯一例外是 Permit 文件内 `#if DEBUG` + package visibility 的
`ActiveIngestionDeletionSQLPermitTestProbeV1`。它只可提供两个封闭入口：

1. `runLifecycleScenario(_:)` 只接受 exact enum
   `registrationFailure|laterPrepareDatabaseSetupThrow|directPoolClose|
   duplicatePointerInstall|busyCloseThenRetry|closeV2ZombieFinalRelease|
   boundedPointerReuse`。runner不接外部 `Database`、AppDatabase、path、raw pointer、
   closure或任意 caller fixture；它只在 Permit 文件内部创建并销毁自己拥有的隔离
   in-memory/temporary connection fixture，复用**同一 install状态机与同一 private
   raw registration call site**。`boundedPointerReuse` 固定最多 256 次 reopen，
   不接受 caller iteration count；
2. `injectCleanupMismatch(_:)` 只接受 exact enum
   `missing|wrongKey|wrongCell|replaced|duplicateCleanup`，runner内部在注入期间强持
   typed fixture，只调用 registry remove helper，绝不调用第二次 C destructor；注入
   后由 runner内部同一 fixture逐项调用 setup、mutation lookup与resolution lookup，
   验证三者都因 sticky lifecycle fault typed fail closed。

两者只返回 immutable scenario tag、before/after counters/flags 与必要布尔结果：
install attempts、raw registration calls、successful registrations、xDestroy calls、
context deinits、active entries、sticky-fault-present、first/second close result class、
destroy-before/after-final-release、duplicate-rejected-before-raw-call、pointer reuse
count、old-context-destroyed-before-reuse，以及 subsequent-setup/mutation/resolution-
rejected；不得返回 pointer、nonce、exact key、cell、context、permit、Database、
closure或任意 lookup/enumeration/install/consume能力。
runner内部执行 install不是向 caller暴露 install capability。registration-failure
场景只能在同一 private raw call site内部使用无效 function name；later-setup场景
只能在同一 `Configuration.prepareDatabase` fixture中先成功 install、随后抛固定 typed
sentinel error。source sentinel要求 probe只被列明 lifecycle tests调用，release
product与 Store/Controller/Application不可见、不可调用；tests不得 import
`GRDBSQLite`、引用 raw SQLite symbol或复制 raw registration。

UDF是 variadic registration，但按 step discriminator只接受两种唯一签名：
`deleteIngestion` exact **53 arguments**，`deleteResult` exact **63 arguments**。
共同前 36 项依序为 step、command key/whole hash、event ID/payload hash、
`domain_event` 专列 actorType/actorId/deviceId/correlationId/causationId/occurredAt/
recordedAt、Camp/lifecycle/scope、ingestion/result snapshot hashes、三项 affected
counts、五项 blocker counts，以及 `event_outbox` 的
eventId/state/attempt/notBefore/leaseOwner/leaseExpiresAt/lastError/version/createdAt/
updatedAt/sentAt；其后分别是 17 项完整 ingestion `OLD` 字段，`deleteResult` 再加
10 项完整 result `OLD` 字段。wrong arity/type/nullability/step均 fail closed。UDF
不得 query/reenter SQLite、访问其他 connection、落盘或记录正文；只读取 captured
cell并做 canonical snapshot/permit比较。

cell绑定 sealed command/whole hash、完整 CommandEnvelope、Camp/lifecycle、
ingestion/result full snapshot、五项 fixed-zero blocker counts、三项 expected
affected counts、connection key、transaction generation nonce与下列 ordered cursor。
安装要求 cell没有 active/finished generation；finish后 cell立即 terminal，任何再次
consume失败。无注册 function、无 active permit、错误 connection/transaction/
generation/step/key/hash/row/count、重复 consume或 reuse都 fail closed。

`IngestionDeletionStore.executeActiveIngestionDeletion(preparedCommand:)` 是唯一执行
API，只接该 Store factory产生的 sealed handle。Store在**已经打开的 serialized
`pool.write` transaction** 中 exact lookup writer cell、安装 permit并直接执行全部
SQL；绝不把 `Database`、permit、evidence writer或任意 mutation callback暴露给
caller。首次执行固定为：

1. transaction 第一项查 receipt replay/conflict；same-key committed replay必须
   以 `expectedCommand(sealedHandle)` 调用 shared validator，完整 graph与 handle
   逐字段通过后才直接返回；不安装 permit、不追加第二 event/outbox；
2. same-key absent 的首次/new-key路径，在 lookup writer cell、安装 permit或写入本
   command任何 receipt/scope/event/outbox之前，必须扫描全部
   `commandType='activeIngestionDeletion.v1'` receipts并调用同一个
   `validateCommittedActiveIngestionDeletionGraphV1(.selfContainedScan)`。可归属当前
   ingestion的任一 fault与可信归属前 malformed分别按 ingestion/global integrity
   block失败，整个 transaction零写、零 permit、零 mutation；
3. 全量重读并 exact 验证完整 CommandEnvelope whole hash、active lifecycle、legacy
   archived bit、ingestion/result full snapshot、scope与五类 blocker实际 count均0；
4. exact writer cell在 `db.isInsideTransaction/autocommit=0` 且无 active generation
   时生成 transaction-generation nonce并安装 permit。Store立即为该 generation注册
   唯一边界机制 `db.afterNextTransaction(onCommit:onRollback:)`；不得另加 transaction
   observer、fallback或下一次 transaction近似。commit/rollback callback都以 exact
   `(connection key,generation)` invalidate并断言 cell不再 active；
5. expected cursor固定为
   `receipt → scope → event → outbox → resultMutation → ingestionMutation → finish`。
   Store依次插一条 immutable receipt、matching `camp_event_scope`、一条 safe
   `active_ingestion_deleted_v1` event与一条 `event_outbox`；每条 statement 后立即
   读取 `changesCount == 1` 并推进 cursor。event专列逐字段复制 sealed envelope，
   `recordedAt`由 Store生成且不早于 occurredAt。outbox固定
   `eventId=event.id,state=pending,attempt=0,notBefore/leaseOwner/leaseExpiresAt/
   lastError/sentAt=NULL,version=1,createdAt=updatedAt=event.recordedAt`；
6. Store 自己执行 exact result DELETE，并立即读取真实 changes count。若 expected
   result count=1，`rumination_result` DELETE trigger 内的 UDF必须先以全部 `OLD`
   result字段重算 §5.1 snapshot hash、匹配 permit/evidence并消费 exact
   `deleteResult` step；若 expected=0，DELETE 的真实 changes必须为0，再由 Store
   记录 exact zero-result step。claimed=1但 row不存在、claimed=0但 row存在、任意
   自洽伪 64-hex hash都 rollback；
7. `sourceAndResult` 的 `ingestion_item` DELETE trigger 内 UDF以全部 `OLD`
   ingestion字段重算 snapshot hash并消费 exact `deleteIngestion` step，statement
   后真实 changes必须为1。`resultOnly` 则执行一个 exact predicate CAS，只更新
   status/errorText/version/updatedAt；真实 changes必须为1，Store重读 expected
   post-snapshot后才让 permit消费 `updateIngestion` step；
8. transaction closure 返回前，Store 强制 `finish`：UDF/Store已消费的 ordered
   steps、三项 observed affected counts、receipt/scope/event/outbox identity与各自
   exact count=1，以及五项仍为零的 live blocker counts必须与
   permit/receipt/event完全一致；缺 outbox/步骤、假 count、乱序、重复或 CAS被跳过
   都会 throw，使整个 transaction连同先写 evidence全部 rollback。finish把 generation
   置为 terminal；finish后的 consume立即失败；
9. write closure用 `defer` 无条件执行 exact-generation clear。正常 commit、
   rollback、throw、manual/early transaction boundary均还会触发同 generation
   boundary callback：boundary发生在 finish前时先 invalidate并记 violation，后续
   UDF/finish失败；finish后 callback只接受 terminal或已由 defer exact-clear的同
   generation。next transaction、pointer reuse或 connection reuse不能观察/消费旧
   permit。SQLite planner不承诺 `AND` 求值顺序，因此任一 guarded statement error
   后 Store不得在同 transaction retry，必须立即 throw/rollback。

receipt/scope/event/outbox 先 committed、以后再执行 DELETE的序列没有当前
transaction generation，必须失败。联合信任边界固定为 persisted guards +
connection-local transaction permit/UDF + 唯一 Store/source sentinel；不得再宣称
仅凭历史 evidence rows就足以授权未来 mutation。

receipt result 与 event payload 只含 Camp/ingestion/result/event IDs、
旧 version/status、content/ingestion-snapshot/result-snapshot/command hashes、
scope、三项 affected count、五项 fixed-zero blocker count与时间；receipt result
另保存 matching event ID/payload hash；绝不复制 rawText、title、URL、resultJson、
userEditedJson、actor/device/account identifier或 candidate/link 正文。两者使用
exact-key decoder，出现 `actorRef/actorId/actorType/deviceId/accountId/
accountIdentifier` 即拒绝。
receipt result的唯一 23-key allowlist是
`commandIdempotencyKey/commandPayloadHash/eventId/eventPayloadHash/campId/
expectedLifecycleVersion/ingestionId/oldIngestionVersion/oldIngestionStatus/
ingestionContentHash/ingestionSnapshotHash/resultId/resultVersion/resultHash/scope/
deletedResultCount/deletedIngestionCount/updatedIngestionCount/
knowledgeSourceLinkCount/actionCandidateCount/nonterminalRuminationWorkCount/
openRuminationAttemptCount/nonterminalProviderDispatchCount`；event payload唯一
21-key allowlist是前述集合去掉 `eventId/eventPayloadHash`。缺 key、额外 key或重复
key均拒绝；两枚 raw guard也以 `json_each` exact 23/21 count封闭。
event 的 aggregate 固定为 ingestion、aggregate version=`old ingestion version+1`，
`eventOrdinal=0`，event key 固定为
`<commandKey>#0000:ingestion:<ingestionId>`。receipt 的 `eventId/eventPayloadHash`
必须分别等于 event ID/payloadHash；同 command key 的 domain event 实际 COUNT
必须 exact 1，matching outbox实际 COUNT也必须 exact 1。receipt result与 event
payload双向重复并交叉验证 Camp、command key/hash、expectedLifecycleVersion、ingestion
ID/version/status/contentHash/full snapshot hash、optional result ID/version/full
snapshot hash、scope、三个 affected counts及五个 fixed-zero blocker counts；
完整 actor/device/correlation/causation/occurredAt只经 command whole hash、
permit与 `domain_event` 专列绑定，不重复进 safe JSON。event payload不包含 receipt
result hash，避免 hash自引用环。

v16 的 `rumination_result` 与 `ingestion_item` DELETE guard 同时要求上述
event-bound evidence与返回 1 的 transaction-local UDF consume；任一
missing/wrong event/outbox、receipt/hash/Camp/envelope专列、scope/state/version/count、非零或
缺失 blocker、non-active lifecycle、无 UDF/permit、错误 connection/transaction/
generation/step/row/reuse都 abort。live `NOT EXISTS` blocker检查继续保留，且
receipt、event、permit三处的五项 claimed count必须各自 exact 0。`action_candidate` 与
`knowledge_source_link` DELETE guard永久无例外。typed Store/UDF必须重算
ingestion/result snapshot、command/result/event hashes并验证 canonical bytes；
SQL evidence与 caller claimed 64-hex hash都不单独被信任。

start/complete/fail/cancel/materialize、普通删除和 Camp deletion 共享同一 serialized
writer，并以 lifecycle + ingestion/result/work version CAS 竞争，只有一个 winner。
materialize 先赢后普通删除必须失败；普通删除先赢后 late worker/provider callback
不得重建 result、candidate、link 或推进旧 work。same-key replay 不追加第二条
event/outbox、不重复 DELETE；new key 不把已删除 source 当成功。

`IngestionDeletionStore` 内唯一 private
`validateCommittedActiveIngestionDeletionGraphV1` 必须同时被 execute replay、
首次/new-key execute preflight、SELECT-only resolver与 prepare relaunch scan复用，
不得各写一套近似 validator。它对
每个 `domain_command_receipt.commandType='activeIngestionDeletion.v1'` 精确验证：

1. receipt key/type、64-hex command whole hash、`eventCount=1`，resultJson逐字
   canonical、resultHash重算一致且 exact 23-key decoder通过；
2. 从 safe result取得 ingestion/Camp/event IDs与 eventPayloadHash，再验证 matching
   `camp_event_scope` exact 1、scope Camp一致；
3. 同 command key 的 `domain_event` actual count exact 1，event identity、
   deterministic key、ordinal、aggregate/version、eventType=
   `active_ingestion_deleted_v1`、command key/hash、payload canonical bytes/
   recomputed hash/exact 21-key decoder与 receipt safe fields双向一致；
4. event actorType/user、actorId/deviceId/correlationId/optional causationId、occurredAt/
   recordedAt专列满足完整 CommandEnvelope nullability/time合同；expected-command
   模式还要逐字段 exact匹配 sealed handle envelope；
5. matching outbox actual count exact 1、eventId一致、当前 shape/state是合法 initial
   或合法 dispatch推进状态，validator绝不回退 outbox。

validator模式 exact为：

- `expectedCommand(sealedHandle)`：用于 execute same-key replay与 resolver；
- `selfContainedScan`：用于 prepare relaunch scan与 first/new-key execute preflight。

两种模式都必须从 persisted graph重建 exact
`CanonicalJSONV1({"envelope":...,"payload":...})` hash material。envelope exact为
event专列重建的
`idempotencyKey/actorType/actorId/deviceId/correlationId/causationId/occurredAt`；
payload exact为 decoded safe fields：
`campId/expectedLifecycleVersion/ingestionId/oldIngestionVersion/oldIngestionStatus/
ingestionContentHash/ingestionSnapshotHash/resultId/resultVersion/resultHash/scope/
deletedResultCount/deletedIngestionCount/updatedIngestionCount/
knowledgeSourceLinkCount/actionCandidateCount/nonterminalRuminationWorkCount/
openRuminationAttemptCount/nonterminalProviderDispatchCount`。`commandPayloadHash`、
`eventId`、`eventPayloadHash` 与 `recordedAt` 都不是 typed command payload，禁止放入
hash material；这里 payload field `resultHash` 是 rumination-result snapshot hash，
与 outer `domain_command_receipt.resultHash` 不是同一值。validator用
`CanonicalJSONV1` 重算 whole hash，并要求它同时 exact
等于 receipt column、receipt resultJson与 event payloadJson的
`commandPayloadHash`；不得只检查 64-hex或 persisted copies彼此相等。

`expectedCommand` 还必须把重建的完整 envelope、上述全部 typed payload fields及
重算 whole hash逐字段与 sealed handle exact匹配；execute replay与 resolver都不得
省略该 handle binding。`selfContainedScan` 不需要 handle，但必须完成同一重算。
validator只 SELECT/decode/hash，不接 caller facts、不 DML、不 repair。scan模式按
decoded ingestionId归属；任一步在取得可信 ingestionId后失败，均把该 ingestion标为
`integrityBlocked`；在可信归属前失败，则 ordinary ingestion deletion全局 fail
closed。这样 resolver的每一个 integrity fault都不能在 process relaunch后被 new key
绕过。

`executeActiveIngestionDeletion` 不得把一个未分类的 throw交给 Controller猜测是否
提交。它与唯一 SELECT-only
`resolveActiveIngestionDeletionExecution(preparedCommand:)` 都只接同一 sealed
handle，并返回
`ActiveIngestionDeletionExecutionResolutionV1`：

- `committed(result)`：matching receipt 的 command type/whole hash exact、
  `eventCount=1`，receipt resultJson/resultHash canonical且 exact-key decoder通过；
  matching scope、唯一 event的 identity/payload hash/专列/safe decoder，以及唯一
  outbox全部完整。outbox可处于合法推进后的 state，但 resolver不得把它重置为
  initial pending；
- `notCommitted(error)`：同 handle的 execute invocation已经结束、SELECT-only
  resolver成功进入同 AppDatabase 的 `DatabasePool.writeWithoutTransaction` writer
  queue、registry无 active generation，且同 key receipt absent；因此此前 transaction
  只能是未开始或完整 rollback；
- `resolutionPending(disposition)`：只可为
  `commitOutcomeUnknown|integrityBlocked|terminalConflict`。

resolver唯一调度 API 是同 AppDatabase 的
`DatabasePool.writeWithoutTransaction`；closure的第一个 executable operation固定为
调用 `assertNoActiveGenerationForResolution(for: db)`。该 Permit-owned API内部先
验证 `!db.isInsideTransaction` 与 `sqlite3_get_autocommit(db.sqliteConnection)==1`，
再完成 exact pointer/key/nonce/writer/empty-generation assertion；Store不得 import
`GRDBSQLite` 或直接引用 raw autocommit symbol。成功后才读取 same-key receipt，并按
absent → `notCommitted`、identity mismatch → `terminalConflict`、shared validator
failure → `integrityBlocked`、validator success → `committed` 分类。entry/assertion
任一步失败都先收敛为 `commitOutcomeUnknown`，不得用后来读到的 graph掩盖 registry
invariant failure。receipt identity匹配时只可调用上述
`expectedCommand(sealedHandle)` shared validator。禁止以
`pool.read`、`pool.write`、`barrierWriteWithoutTransaction`、新 transaction或
transaction observer替代；不得安装 permit、调用 UDF、执行 DML、重新 execute或
mint command。读取/writer queue本身无法确定时是 `commitOutcomeUnknown`；receipt 的
type/whole hash/`eventCount=1` 任一不匹配是已确定的 `terminalConflict`，不能伪装成
unknown；同 key/type/hash/count均匹配，但 receipt resultJson/resultHash/canonical
exact-key decoder、matching scope、event identity/payload hash/专列/decoder或
outbox graph任一缺失/损坏，是 `integrityBlocked`，不能伪装成 rollback。
`IngestionDeletionStore.prepareActiveIngestionDeletion` 必须扫描上述 commandType的
全部 receipts并逐条调用同一 validator的 `selfContainedScan`；当前 ingestion的任一
integrity fault必须拒绝，同型 receipt在可信归属前 malformed则按上述规则全局 fail
closed，直到另行授权 repair。上述 conflict/integrity检查不信任 caller JSON或 row
facts。

`InputWorkflowController`（必要时由 `AppStore` 映射为 view state）持有
`PendingActiveIngestionDeletion`，其中只暴露 opaque prepared-command handle、
完整既有 envelope、用户选择、safe preview、result/trace state、
`resolutionDisposition?` 与唯一 phase：
`prepared|executing|executionResolutionPending|committedRefreshPending`。
`resolutionDisposition` 只在 `executionResolutionPending` 非 nil。一次
confirmation只生成一次 envelope、调用一次 Store prepare并持有同 handle；
double-click、view rebuild与 retry均 single-flight，不重新 prepare/mint key。
UI/adapter protocol只能
`prepareActiveIngestionDeletion(request:)` 后
`executeActiveIngestionDeletion(preparedCommand:)`，以及在 resolution pending时调用
SELECT-only `resolveActiveIngestionDeletionExecution(preparedCommand:)`；该 resolver
只能使用上述 `writeWithoutTransaction` seam。

`prepared` 尚未 execute时 user cancel可清 pending；进入 `executing` 后 cancel/
dismiss不得清 handle、取消底层 Task或把“未知是否已提交”冒充未提交，必须等待 Store
返回 typed resolution。`notCommitted` 必须以**同一 handle/envelope/key**回到
`prepared`、保留 selection/trace并显示失败；此时可 cancel，或用同 handle重试，
但 Store仍全量重验 live facts。`committed` 转
`committedRefreshPending`；refresh失败保留同 command/result/trace，retry先以同
command命中 receipt replay再 refresh。

`resolutionPending(commitOutcomeUnknown)` 禁清 pending、禁 mutation retry，只允许
同 handle只读 resolve；`integrityBlocked` 同样禁清/禁 mutation并显示 stable trace
与 repair-required typed error，直到另行授权的 repair恢复完整 graph；
`terminalConflict` 禁止该 handle再次 execute/resolve成成功，只允许用户 explicit
`abandonConflict` 后先普通 reload，再清 pending并重新确认生成新随机 key。
commit后的 explicit dismiss只关闭已提交结果的 UI，不是撤销、不得 mint key或重新
删除；后续普通 reload读取持久化事实。除 prepared cancel、
terminal-conflict explicit abandon、refresh成功关闭，或 committed-result explicit
dismiss外不得清 pending。

pending是 session-local UI state，本 stage不新增 durable pending schema。process
death/relaunch后不得凭旧 UI state自动重放或自动 mint key：SQLite单 transaction只会
留下完整 committed projection+receipt graph或完整 rollback，startup ordinary reload
先读取这些持久事实；只有 reload后 source仍满足 eligibility且用户重新确认，才可生成
新 key。不得声称 relaunch会恢复原 pending trace/phase。

#### 用户确认的 irreversible deletion

`requestCampDeletion` 只允许 user actor，输入必须包含 exact `campId`、
`expectedLifecycleVersion`、随机 `confirmationId`、`confirmed=true` 与 canonical
confirmation object/hash；confirmation 固定包含
`unknownArtifactDisposition=detachOnlyNeverUnlink`，并明示“能证明为 App 托管的正文
不可恢复；workspace 外部文件和无法证明归属的历史成果只解除数据库引用，原文件可能
仍存在，App 绝不删除它”。该字段不能由 UI 省略、降级成普通 bool 或由 Agent 代选。
单 transaction：

1. validate command receipt/whole hash 与 lifecycle `active|archived`；
2. 生成 stable job/work IDs，先 enqueue unique
   `durable_work(kind=campDeletion, aggregateType=camp, aggregateId=campId,
   campLifecycleVersion=expectedVersion+1)`；只可调用 specialized retirement helper；
3. insert unique `camp_deletion_job` 并以 FK 引用刚插入的 work；
4. CAS lifecycle -> `deletionRequested`、`camp.archived=1`，立即永久 write fence；
5. 写只含 ID/hash/code/count 的 safe event/outbox。

同 confirmation replay 返回同 job；同 key/hash 不同或对已删除 Camp 的新
confirmation conflict。进入 `deletionRequested` 后不能 unarchive/cancel/回到
active。worker restart 由 durable-work adoption 恢复。

deletion worker 只通过 specialized enqueue/claim/renew/fail/complete/adopt helper
运行。quiescence 排除项只有 permit 已重验的 exact `job.id + job.workId` 与
exact running claim（kind=campDeletion、aggregate=该 Camp、attempt/lease/open
attempt 全匹配）；任何别的 deletion work/attempt 都是 blocker，archive 则一个也
不排除。worker 禁用 schedule、撤销 active Grant/Residency/Bridge，cancel
Input/Goal/Coach/Discussion/普通 durable work 与 provider dispatch，终结
Mission/Card/Run/engine，关闭 inbox/outbox；ActionCandidate
`proposed|accepted -> dismissed(reason=camp_deleted)`，其余 terminal 状态不变。

已有 open `user_request` 不允许提前擦除，也不能继续阻塞 retirement。F2 唯一
package-internal
`CampLifecycleStore.withdrawOpenUserRequestForCampDeletion` 接受由当前 claim 生成、
无 public initializer 的 exact target，并在每次 transaction 重验完整 permit、
request/card/Camp identity 与 request 仍为 `open`。它只允许 lifecycle
`deletionRequested` + job `quiescing` 时 CAS
`open -> withdrawn(terminalReason='camp_deleted')`；`prompt/optionsJson` 原样保留，
`answerJson/answeredAt/redactedAt` 仍为 NULL，不读取或擦除正文，不创建新的
`user_request`、Card 或 Attention。普通 `answerUserRequest` 只允许 active Camp。
answer 与 deletion request/withdrawal 由 serialized writer + expected
lifecycle/request state CAS 竞争：answer 先赢则 request 为 answered；deletion fence
先赢则普通 answer 拒绝且 withdrawal 唯一获胜。重放返回同 safe receipt，异
target/hash conflict。quiescence 只统计 `lifecycleState='open'`，
withdrawn/answered 均不再阻塞 `deletionRequested -> deleting`。

legacy Ingestion 也有唯一 pre-finalization closeout：
`CampLifecycleStore.discardIngestionForCampDeletion` 只接受当前 claim 生成的
opaque target，绑定 ingestion ID/version/status、Camp、matching rumination
work/attempt/provider checkpoint（如存在）、job cursor 与 whole command hash。
在 lifecycle=`deletionRequested` + job=`quiescing` 的一个 transaction 内，它先
按 existing durable-work terminal protocol 关闭 matching active rumination work，
再 CAS `queued|ruminating|needsReview -> discarded`、
`terminalReason='camp_deleted'`、version+1；title/raw/source/error 等正文原样保留，
`redactedAt` 仍 NULL。无 work 的 queued item 走同一 transition，不得成为永久
blocker。普通 cancel 仍只在 active Camp 做 `ruminating -> queued`；normal
materialize/worker result、cancel、deletion closeout 以 lifecycle + status/version
CAS 竞争，只有一个 winner。same command replay 返回原 receipt，异
status/version/work/hash conflict。

同阶段用 exact permit 将 `action_candidate proposed|accepted -> dismissed`、
`terminalReason='camp_deleted'`、version+1，仍保留 title/detail；normal
accepted/converted flow 与它 CAS 单 winner。已有
`materialized|failed|discarded` ingestion 和 `dismissed|converted` candidate
本来就是 terminal history，不做伪造的 quiescing 状态转换。它们与 deletion
terminal rows 都只在 finalizing 才 one-shot 擦除；`rumination_result` 和
`knowledge_source_link.locatorJson` 也只在 finalizing 擦除并设置各自
`redactedAt`。所有 reader 必须先检查 redactedAt，再决定是否 decode
`RuminationResult`/candidate detail/locator；已 redacted 行不走 normal decoder。

worker 先用 §13 specialized API 将 exact `reserved + no dispatch evidence` use
收口为 released；任何 receipt/dispatch intent/adapter op 出现即拒绝这条路径。
未决 `dispatching|accepted|crashUnknown` Grant use 是硬 blocker，只能按 §13
已派发路径收口。
engine replay class 与 Grant 独立：`nonReplayable + started|sessionBound + no
proposal` 必须直接走 F1 既有 safe terminal
`blocked + externalEffectUnknown`、durable receipt 和 urgent Attention；不 replay、
不标 success/no-effect，它本身收口后不再阻止 deletion。

已经存在 pending terminal proposal 时，普通 Engine commit/prepare 仍被 active fence
拒绝；F2 只增加 package-internal
`CampLifecycleStore.supersedePendingEngineProposalForCampDeletion`，绝不把 permit
参数加入 `recordEngineTerminalProposal`、artifact prepared CAS、
`commitEngineTerminal`、`commitEngineAskUser` 或
`invalidateProposalAndCommitProtocolError`。它只接受无 public initializer 的
`PendingEngineProposalDeletionTarget`，由同 Store 在当前 claim 下读取产生，并逐次
重验 `campId/sourceLifecycleVersion/deletionLifecycleVersion/jobId/jobVersion/
confirmationHash/work/workVersion/attempt/lease/phase/executionId+version/
proposalId+version+proposalHash`。首次 closeout 只允许 lifecycle
`deletionRequested`、job `quiescing`、execution 的不可变
`campLifecycleVersion=sourceLifecycleVersion`、proposal `pending`；进入
`deleting|finalizing|deletedTombstone` 后只可 replay 已存在 receipt。

该 specialized transaction 对所有原 proposal kind/subtype 使用同一结果：

- proposal `pending -> invalid`、`invalidReason='camp_deleted'`；原
  `terminalKind/terminalSubtype/proposalHash/payloadHash/artifactManifestHash` 保留；
- execution/Run/Card 进入 `canceled`/`camp_deleted`，Mission 只做现有确定性 rollup；
  只结转已持久化 usage，不接收新 usage delta；
- 不创建 handoff、artifact/ref/origin、`user_request`、Attention 或新普通 work；
  不读 workspace，不调用 stager/adapter/provider/tool/session resume；
- event payload 只含安全 ID/hash/code/version/count/time；对应 outbox 出生即
  `failed(lastError='camp_deleted')`，永不进入 pending/dispatching；
- `EngineTerminalCommitReceipt.disposition=invalidCampDeletion`，保存原
  proposalId/hash、effective `canceled`、空 artifactIds。stable command hash 只含
  schemaVersion、Camp 两个 lifecycle generations、job/confirmation、proposal
  ID/hash 与 disposition；lease renew/adopt/replacement 后由新 claim 返回同 receipt。

proposal 中每条 declared/部分 prepared/全 prepared artifact 必须在 proposal
invalidation 同 transaction 插入 `camp_deletion_proposal_blob`。该 ledger 的
`pending|reserved|unlinkReady|retryableFailure` 是 GC root 和 finalize blocker；
它不保存 source path/label。清理时 serialized writer 重新检查其他 pending proposal
与 active blob ref：存在即 `retainedShared`；否则 reservation 获胜后只对 exact
managed content-addressed object no-follow unlink，missing 为 `alreadyAbsent`。
unlink 后、DB terminal 前 crash 由 `unlinkReady + missing -> deleted` 恢复。新 ref
与 reservation 只有一个 winner。`artifact_blob.deletedTombstone` 对以后别的 active
Camp 同 hash 必须先重新验证/restage bytes，再以 version CAS 回到 available；不能
把旧空 path tombstone 直接复活。

所有 mutable/in-flight owner、`lifecycleState='open'` user request、pending
proposal 和 proposal-blob cleanup blocker 归零后，permit 才可 CAS
`deletionRequested -> deleting`；该 transition 前必须已通过上述 specialized
withdrawal 关闭全部 open request。

deletion work 的第 4 次 transient failure/耗尽仍把旧 work/attempt immutable
terminal failed；job 保留 exact phase/cursor/safe error，Camp 继续 fenced 并产生
urgent Attention。唯一恢复命令 `repairCampDeletion` 只允许 user，且必须带 exact
confirmation/job version/current failed work version+attempt/phaseCursorHash；同
transaction 创建 maxAttempts=4 的 replacement campDeletion work（input 含
jobId/confirmationHash/predecessorWorkId/phaseCursorHash），CAS `job.workId` 与
job version并写 receipt/safe event/outbox。它不 reopen 旧 work/attempt、不回退已
完成 phase，也不能改变 artifact ownership、伪造 verifier evidence 或授权 detach。
same command replay 返回同 replacement；并发 repair 只有一个 winner。

artifact ownership 等待不是 transient repair。专用 user-only
`resolveCampDeletionArtifact(choice=retryTrustedInspection|detachOnlyNeverUnlink)`
必须带 exact job/current failed work/origin/deletion-artifact versions、artifactId、
originalRefHash、phaseCursorHash、confirmation/whole hash。前者只创建 replacement
work 让 trusted verifier 重检；后者只产生 DB-detach authority。用户、Agent 和
adapter 都不能通过该命令自称 managed/external。

#### Camp Provider dispatch 耐久边界

v16 的 `camp_provider_dispatch` 是 Guide chat 与 Camp-scoped memory distillation
唯一 provider returned checkpoint；`durable_work.outputJson` 只保存整个 work 最终
成功输出。operation/replay class 固定：

- Guide、guide/closeout/cowork distill：
  `guideChat|memoryPromotion + replaySafeInference`；
- DM/global distill 与 provider connection test：typed global route，不建 Camp row、
  不进入 Camp retirement；
- 未登记 external-write/tool route 在 dispatch 前拒绝，不能伪装 inference。

每轮固定为 message+work 同 transaction → claim/recheck lifecycle generation →
prepare canonical request row → start CAS + `providerDispatchStarted` attempt event +
fence commit → network → return CAS + response checkpoint +
`providerResponseReturned` event + fence commit → 只从 checkpoint 执行 tool/next turn →
final reply/note/watermark + dispatch consumed + work succeeded 同 transaction。
returned row 永不重新 call provider。started 且无 returned 只能先 abandoned，再在
Camp 仍 active、同 lifecycle generation、同 work attempt budget 下建立
`dispatchAttempt+1/replayOf`；历史无法证明 safe 的 started row必须 work failed
`provider_effect_unknown` + urgent Attention。

Guide tool 只允许 search/status read-only，以及以
`(workId,turnOrdinal,toolUseId)` command receipt 去重的 `propose_squad`；任何外部写
必须走 §13 Grant ledger。archive/delete quiescence 统计
prepared|started|returned。网络已经 started 不能倒流“未发送”，但 lifecycle fence
获胜后禁止新读取/dispatch/response/tool/reply commit，worker必须等待 cancel/
terminal；deletion permit 只可 abandon/cancel/redact，不可继续消费内容。

`CampMutationOwnerRegistry` 与 `CampExternalDispatchOwnerRegistry` 是 compile-time
exhaustive registry，并有 source sentinel 扫描 raw `pool.write`、
`provider.streamTurn` 与 scoped filesystem write。至少覆盖 AppDatabase/
BoardCardTransactions、Knowledge/Schedule/MCP、Feed/Rumination/Materializer/
MissionDraft、NewcomerUnlock/ProductBootstrap、Orchestrator、BoardTools、两个
CodingRanchStoreAdapter write、全部 P1 Store/worker/controller，以及 planning、
Guide、guide/closeout/cowork distill、F1 Engine、Grant tool/network/shell 与
prepared artifact dispatch。DM/global route必须显式标 global。Orchestrator
expedition report 与 AppStore `ensureReport` 必须改由 registered
`ManagedExpeditionReportStore` 唯一读写：mission→Camp scope、trusted report root、
no-follow unlink、job cursor recovery；两个旧直写路径均删除。

#### Erasure、artifact ownership 与 finalize

`artifact_storage_origin` 是分类事实源；所有 legacy artifact 在 v17 一律 backfill
为 active `unresolved/legacyUnknown`，migration 不读 filesystem、不根据路径形状猜。
新 managed artifact 只可由 `ArtifactBlobStore.prepare` 的 unforgeable
`PreparedArtifact` 在 artifact/origin/ref 同 transaction 建立；外部文件必须用
explicit `WorkspaceExternalArtifactReference`。`completeCard` 不再接受 String
path。

唯一只读 `ArtifactOwnershipVerifier` 持有 trusted managed-root registry。它只返回
无 public initializer 的：

- `VerifiedManagedArtifactEvidence`：root capability、object、regular-file identity、
  content hash 全匹配；
- `VerifiedWorkspaceExternalEvidence.explicitReference`；
- `VerifiedWorkspaceExternalEvidence.verifiedOutsideAllManagedRoots`：所有登记 root
  均可打开、registry generation/root-set hash 固定，且以 fd ancestry/no-follow
  证明目标在全部 root 外；
- typed `UnresolvedArtifactEvidence(reason)`，reason 仅可为
  `unknownMissing|symlink|permissionDenied|managedRootUnavailable|irregularFile|
  identityDrift|contentDrift|incompleteRootSet|ambiguousHardlink`。

prefix、文件名、扩展名绝不是 ownership evidence；任一 managed root unavailable
时不得签发 verified-outside。用户只能请求重检或 detach-only，不能构造 evidence。
已知 managed provenance + missing file 才是
`managedExclusive/alreadyAbsent`。hardlink count 超出 active managed-origin/ref
registry、其他 Camp identity 或 pending proposal root 时 retain shared/ambiguous，
不 unlink。

`camp_deletion_artifact` 在任何 detach/unlink 前登记 artifact ID、origin version、
original ref/evidence/reference-set hashes，`resolutionClass` 固定为
`unresolved|managedExclusive|managedShared|workspaceExternal`，状态机固定：

```text
pendingInspection
  -> awaitingResolution
  -> detachAuthorized -> detached
  -> unlinkPrepared -> deleted | alreadyAbsent | retryableFailure
  -> retainedShared

awaitingResolution
  -> pendingInspection       // retryTrustedInspection
  -> detachAuthorized        // detachOnlyNeverUnlink

retryableFailure
  -> unlinkPrepared          // exact replacement work/permit
```

- `workspaceExternal|unresolved` 只能 `detachAuthorized -> detached`，managed
  locator/hash 必须为空，任何状态都绝不进入 unlink API；
- `managedShared` 只在一个 DB transaction tombstone 当前 Camp artifact/origin/ref，
  终态 `retainedShared`，blob 保持 available；
- `managedExclusive` 只有在 serialized writer 内重验 active managed origins、
  active blob refs、pending proposals、hardlink/cross-Camp identity 后，才可持久化
  deletion reservation 和 `unlinkPrepared`；
- `alreadyAbsent` 只允许完整 managed provenance；unknown missing 必须走
  detach-only，不能谎称物理删除；
- confirmation 的 `detachOnlyNeverUnlink` 产生 job-scoped
  `UnknownArtifactDetachAuthority`，使每个 unresolved reason 都有有界 DB 擦除路径；
  如 command 明确选择先重检，则 work 以 `artifact_resolution_required` 安全失败，
  专用 resolution command 建 replacement 后继续；
- 只有 transaction-local `ManagedArtifactUnlinkPermit` 能调用
  `ArtifactBlobStore.unlinkManagedObject`；它绑定 job/work/attempt/lease/phase、
  artifact/origin/deletion-row versions、root/object/content/file identity。API 不接受
  URL/String path。

external/unresolved detach 是单一 DB transaction：重验 permit 后把
`artifact.path=''`,`kind='tombstone'`,`label='[deleted]'`，origin/ref 进入 tombstone，
deletion row 进入 `detached`；整个路径不得调用 filesystem。若这两类 origin 意外存在
active blob ref，报 schema corruption 且零写入。

managed exclusive 先在 DB transaction CAS blob `available -> quarantined`（legacy
managed object 则建立 root/object deletion reservation）、tombstone目标
artifact/origin/ref 并持久化 `unlinkPrepared` snapshot；提交后只用已打开 trusted
root fd、component-by-component no-follow、`unlinkat` 删除，再在第二 transaction
把 blob/ledger terminal 并清除 root/object live locator。crash 在 reservation 前无
副作用；reservation 后重试同 snapshot；unlink 后、terminal commit 前以
`unlinkPrepared + known-managed missing -> alreadyAbsent` 收敛。prepare 后任一
identity/hash drift 都不得 unlink，改走安全 resolution。

origin upgrade、用户 detach、snapshot、新 ref/proposal insert、finalize 使用同一
serialized writer 和 version CAS：verifier 先赢则按新 class；detach 先赢则 verifier
stale，永不复活。reservation 先赢则新 ref 拒绝/重试；新 ref 先赢则删除转 shared。
ownership live set 包含 active managed origins、active blob refs 和 pending proposal
roots；legacy managed 没有 blob ref 时也不能被误判 exclusive。terminal replay
返回同 receipt，绝不重复 unlink。

GC live set 精确为 pending `engine_proposal_artifact.contentHash`、active
`artifact_blob_reference.contentHash` 与非终态
`camp_deletion_proposal_blob.contentHash` 的并集。

finalize 前必须重新验证 quiescence、所有 deletion artifacts terminal、projection
registry 无遗漏，并在一个 transaction 完成以下**逐字段**传播：

| table / scope | 删除后保留 | exact 清空/反转 |
|---|---|---|
| `camp/camp_lifecycle/camp_deletion_*` | IDs、version、confirmation/original hashes、safe error code、times | `camp.name='[deleted camp]'`、archived=1、lifecycle tombstone；job/work terminal |
| `companion` target-Camp projection | global Cow identity全部字段 | 仅 `companion.campId = NULL`；绝不改另一 Camp/global Cow |
| `squad/mission/card/run` | IDs、budget/usage、safe terminal code、times | squad `name='[deleted]'`,`memberIdsJson='[]'`,`workspacePath/workspaceBookmark=NULL`；mission `goalRaw/goalRefined='[deleted]'`；card `title/descriptionText/expectedOutput='[deleted]'`,`blockedReasonJson='{}'`,`dependsOnJson='[]'`,`handoffJson=NULL`,`reviewFlag=NULL`；open Card/Run canceled 且 run `outcome='camp_deleted'` |
| `artifact/artifact_storage_origin` | ID/card/Camp、origin/evidence class、content/file/original/evidence/authority hashes、times | artifact path=`''`, kind=`tombstone`, label=`[deleted]`；origin state=tombstoned、managedRootId/objectId=NULL、terminalDisposition exact；外部/unknown只 detach |
| `camp_note/user_request` | IDs/FKs/kind/times | quiescing 先用 F2 permit 将 open request exact `open→withdrawn(terminalReason='camp_deleted')`，保留 prompt/options 且不设 redactedAt；finalizing 仅将 answered/withdrawn request one-shot 改为 `prompt='[deleted]'`,`optionsJson/answerJson=NULL`,`answeredAt=NULL`,`lifecycleState='redacted'`,`terminalReason='camp_deleted'`,`redactedAt` set；note `title/bodyMd='[deleted]'`, pinned=0；open 判定只看 lifecycleState |
| `chat_thread/chat_message` with `legacy_chat_scope=camp` | IDs/thread/role/times | `contentJson='{"redacted":"camp_deleted"}'`, distilled=1；`globalCow` rows untouched |
| `companion_note` with Camp note scope | IDs/Cow/times | `title/bodyMd='[deleted]'`, `sourceThreadId=NULL`, pinned=0；globalCow note untouched |
| `ingestion_item/rumination_result/knowledge_source_link/action_candidate` | IDs/contentHash/pipeline/status/times | quiescing 用 F2 permit 将 ingestion `queued|ruminating|needsReview→discarded(camp_deleted)`、candidate `proposed|accepted→dismissed(camp_deleted)`，保留全部正文且 redactedAt=NULL；finalizing 才令 ingestion `title/sourceURL/author/userIntent/errorText=NULL`,`rawText='[deleted]'`，rumination `resultJson='{}',userEditedJson=NULL`，link `locatorJson=NULL`，candidate `title='[deleted]',detailJson='{}'`，各自 redactedAt set；既有 terminal history只执行 finalizing redaction |
| `mission_template/schedule/camp_mcp_enable` | IDs/timing/budget | template `name/goal='[deleted]'`,`companionIdsJson='[]'`,`workspacePath=NULL`; schedule enabled=0；目标 Camp enable rows物理删除，global `mcp_server` untouched |
| `durable_work/attempt/event` | IDs/kind/state/attempt/trace/safe errorCode/times | work `inputJson='{}'`并重算 inputHash、`outputJson/errorMessage=NULL`；attempt/event `errorMessage=NULL`、event `redactedAt` set；非 deletion work terminal |
| `schedule_fire/failure_record/context_degradation` | IDs/scope/state/code/count/times | `schedule_fire.errorMessage=NULL`；failure `userMessage='[deleted]',diagnosticJson='{}'`；degradation `detail='[deleted]'`，各自 redactedAt set |
| `domain_command_receipt/domain_event` | 全行 | 必须自出生即为 `CampSafeAuditPayloadV1`（仅 ID/hash/code/count）；无 deletion exception |
| `event_outbox/inbox_message` | IDs/Camp/hash/version/times | outbox pending/dispatching→failed、lease clear、`lastError='camp_deleted'`；inbox `sourceDeviceId='[deleted]'`,`payloadJson='{}'`,state=rejected,`errorCode='camp_deleted'`,redactedAt set |
| `input_envelope` | §9 exact tombstone ID/hash/source type/time | §9 exact sourceDevice/connector/author/body/ref/routing/error/parent null/default matrix |
| `goal_controller/coach_session/coach_question/understanding_card_version` | IDs/versions/original hashes/status/times | Goal tombstone、title/rawIntent marker、current refs null；Coach canceled；question withdrawn且 prompt/recommendation/reason marker、answer `{}`；Understanding 先置 withdrawn/redacted discriminator，`problem/scenario/targetAudience='[deleted]'`，所有复数列表 JSON=`[]`，仅 budgetPolicyJson=`{}` |
| `outcome_contract_version/verification_requirement/outcome_version` | IDs/versions/original hashes/risk/status/times | Contract 先置 tombstone discriminator，deliverables/criteria/verification/deviation/required/optional dependency refs 全 `[]`；requirement configJson=`{}`；outcome manifest/run refs=`[]` |
| `verification_record/acceptance_record` | IDs/exact refs/original hashes/result/decision/time | Verification `environmentJson/commandOrRuleJson='{}'`,`rawResultRef=NULL`, redactedAt；Acceptance `reason='[deleted]'`, redactedAt；current acceptance/metric credit reversed、verification invalidation appended |
| `approval_grant/use/external_operation_receipt` | IDs/scope hashes/state/usedCount/grantor type/receiptHash/result/time | active grant revoked；purpose/grantorActorId marker、policy refs null；**use.adapterOperationId=NULL**；receipt adapterOperationId/receiptRef=NULL,receiptJson marker,authorityId marker,redactedAt；未决 use阻止 finalize |
| `camp_residency/camp_bridge/memory_record_version` | relation IDs/Camp/Cow/layer/source/hash/time | live relation revoked、role/grantor marker、scope `{}`；Camp memory tombstone、title marker、body/ref null、applicability `{}`，dependency invalidated |
| `camp_provider_dispatch` | IDs/work/attempt/replay/hash/state/time | terminal consumed/abandoned；`requestJson='{}',responseJson/responseHash=NULL`,redactedAt |
| `engine_session/engine_execution/engine_terminal_proposal` | IDs/whole pre-redaction hashes/kind/subtype/state/usage/time | session invalid + external ref NULL/scope `{}`；execution terminal + request/context/scope `{}`，若 cancellationRequestedAt NULL 则 cancellationReason NULL，否则 `camp_deleted`；proposal须 committed/invalid、invalid 时 invalidReason=`camp_deleted`、proposal/payload `{}`、manifest `[]`，redactedAt |
| `artifact_blob/reference/engine_proposal_artifact/camp_deletion_proposal_blob` | content/original hashes、state/time | exclusive blob path tombstone（shared untouched）；target ref tombstoned；proposal artifact `sourceRelativePath=''`,`kind='tombstone'`,`label='[deleted]'`,redactedAt；cleanup ledger 必须 terminal 且不保留 locator |
| `discussion/discussion_turn/attention_item/growth_evidence` | IDs/safe enums/hash/time；Attention dedupe自出生为 opaque safe hash | discussion canceled、purpose/participants marker；turn `contentRef=''`,redactedAt；Growth invalidated |
| legacy `event` / typed scope | IDs/type/ref/time | 只把 Camp row payload改 `{"redacted":"camp_deleted"}` 并设置 scope.payloadRedactedAt；global event untouched |

`schedule_fire` 的删除 scope 只允许由 immutable
`fire.scheduleId + fire.templateId -> schedule.templateId -> mission_template.campId`
得到一个 exact Camp；started fire 的 mission→squad Camp 与 replay source 的
schedule/template 也必须相同。dangling、cross-Camp、template drift 或任何无法得到
唯一 Camp 的 row 均 fail-closed，不能按 error text/slot 猜 scope。

`acceptance_policy_version`、`cow_identity`、global memory、`globalCow` DM/note 是
explicit global exemptions。除此之外，registry 发现新的 Camp-reachable
TEXT/BLOB/ref 即拒绝 finalize。原始 hash 可保留作 pre-redaction evidence，但
redaction 后不得再以旧 hash 对新 marker 做 byte-equality 验证。

append-only privacy exception 只适用于 user-confirmed deletion：v16/v17 的 exact
trigger 必须是无列过滤 `BEFORE UPDATE ON ...`，要求 unique target Camp、
lifecycle=`deleting`、该 Camp 唯一 deletion job
state=`finalizing`、OLD.redactedAt IS NULL/NEW.redactedAt non-null，并逐列要求除上表
列出的 replacement 外全部 `IS` identical。适用表固定为
`durable_work_attempt_event`、`verification_record`、`acceptance_record`、
`external_operation_receipt`、`discussion_turn` 与 legacy event scope/payload。
普通/wrong Camp/wrong job/wrong phase/二次 redaction/额外 column diff 全 abort；
所有 DELETE guard 永不移除。legacy `event` 还必须要求
`OLD.payloadJson <> '{"redacted":"camp_deleted"}'`，因此第二次相同 marker UPDATE
也 abort。

所有可变 redacted carrier 除 first-redaction exact validator 外，必须另有无列过滤的
post-redaction full-row lock：`OLD.redactedAt IS NOT NULL` 时任何 UPDATE 均 abort。
至少覆盖 `schedule_fire`、`ingestion_item`、`rumination_result`、
`knowledge_source_link`、`action_candidate`、`failure_record`、
`context_degradation`、`inbox_message`、
`approval_grant`、`camp_provider_dispatch`、`engine_session`、`engine_execution`、
`engine_terminal_proposal`、`engine_proposal_artifact`、
`artifact_storage_origin`、`discussion_turn` 与本轮任何新增 redactedAt carrier。
不得只监视 private column，因为删后单改 retained hash/version 同样破坏审计真相。

typed JSON carrier 一律 redacted-first：reader 在 normal decode/hash/resume/filesystem
访问前先检查 row `redactedAt`、明确 tombstone status 或所属 Camp lifecycle；删除行
返回 typed `.redacted/.unavailable`，不得把 `{}`/`[]` marker 送入 normal DTO
decoder，不得重算旧 payload hash、解析 refs、resume 或访问 filesystem。只有 active
row 才执行 canonical decode/hash validation。Rumination、Mission detail、Handoff、
Understanding、Outcome 与 Engine context/session scope 的 decoder/UI 消费点全部进入
owner registry 和 source sentinel。

新 `domain_event` payload 从一开始必须是 `CampSafeAuditPayloadV1`
（ID/hash/code/count only），不得复制正文。
具体到 session scope，`engine_session.sessionScopeJson` 与
`engine_execution.sessionScopeJson` 都改为 `{}`，derived sessionScopeHash 保留为
pre-redaction evidence；删除后不得再用 JSON/hash byte-equality 做 resume，session
必须 invalid，execution 必须 terminal。F2 sentinel 逐列验证两张表。

最后 transaction 必须再次重验 exact current job/work/attempt/lease permit，才可
同时 CAS `deleting -> deletedTombstone`、job completed、work/attempt/event
succeeded 并写 safe tombstone event/outbox。任一 sentinel/owner/event 失败整笔 DB rollback；
Camp 继续 deleting/fenced。Camp row永不物理 DELETE，所有 FK `ON DELETE RESTRICT`。

### 14.3 跨 Camp 桥

`camp_bridge` 字段：`id`、`sourceCampId`、`targetCampId`、`mode(reference|copy|searchGrant)`、`contentScopeJson`、`grantedBy`、`validUntil`、`status(active|revoked)`、时间。

没有 active bridge 时，任何跨 Camp query 必须返回 typed authorization error，而不是空数组。

## 15. 分层 Memory 与 provenance

`memory_record_version`：

- `(id, version)`
- `layer(rawSource|working|campKnowledge|globalPreference|globalSkill)`
- `ownerType(user|goal|camp|cow)`、`ownerId`
- `campId` nullable
- `title`
- `bodyText` nullable、`contentRef` nullable、`contentHash`；active 版本两种正文载体恰有一个存在，tombstone 两者都为空
- `status(proposed|active|needsReview|invalidated|deletedTombstone)`
- `sourceType(userConfirmed|independentSource|outcomeExperience|inference)`
- `applicabilityJson`
- `createdByActorId`
- `confirmedByActorId` nullable
- 时间

`memory_dependency` append-only：`memoryId/version`、`dependencyType(input|outcome|verification|acceptance|memory)`、`dependencyId`、`dependencyVersion`、`dependencyHash`。

晋升：

- rawSource / working 可以自动建立，但不自动可信。
- 用户确认事实或偏好、独立资料整理可晋升 Camp Knowledge / Global Preference，并保留确认与来源。
- 从行动经验产生的 Skill、Cow 能力和成长只能引用 accepted Outcome + valid Verification。
- 推断必须标 `sourceType = inference`，不能混成用户自述。
- dependency returned/revoked/invalid/deleted 时，依赖 Memory 原子进入 `needsReview` 或 `invalidated`。
- 删除敏感正文后只留 tombstone，不在审计 payload 复制正文。

## 16. 统一运行引擎协议

迁移 `v17-p1-engine-coordination` 增加 `engine_execution` 与
`engine_session`；代码协议版本固定为 `agentloop.execution.v1`。P1 选择
**kernel-owned Run**，adapter 只是无数据库终结权限的 transport。

### 16.1 Descriptor

`ExecutionEngineDescriptor`：

- `adapterId`、`adapterVersion`
- `profileKind`
- descriptor-owned `executionReplayClass(for:) ->
  replaySafe|idempotencyKeyed|nonReplayable`；它是整个 engine invocation 的恢复语义，
  由 adapter ID/version + exact session scope 纯函数决定
- capabilities：`streamingProgress`、`boardTerminal`、`toolBridge`、`cancellation`、`sessionResume`、`usageMetering`、`workspaceRead`、`workspaceWrite`、`network`
- 每项为 `supported` / `unsupported` / `conditional(reasonCode)`，不得谎报。

此 replay class 与 §13 单个 external tool effect 的 Grant
`adapterReplayClass` 是两条独立事实，不得互相复制或推导。

### 16.2 Request

`EngineExecutionRequest`：

- `protocolVersion`
- `executionId`、`idempotencyKey`
- `runId`、`cardId`
- OutcomeContract ref
- Runtime Profile ID、engine kind、model、store-derived engine invocation replayClass
- `contextJson`、`contextHash`、store-derived `sessionScopeJson/sessionScopeHash`
- required capabilities
- ApprovalGrant IDs
- token / cost / wall-clock budget
- workspace ref
- optional `sessionRef`

`contextJson` 的唯一 typed 真相固定为 `EngineContextEnvelopeV1: Codable`：
`schemaVersion=1`、`campId`、`goalId` nullable、`missionId`、`cardId`、
OutcomeContract exact ref/hash、`inputRefs`、`memoryRefs`、`resourceRefs`、
`priorHandoffRefs` 与 `instructionBlocks`；所有 ref/block array 按
`type,id,version,hash` 排序。`ContextPacket` 只能经
`EngineContextEnvelopeV1.from(packet:scope:)` 一次转换；adapter prompt 是由
envelope 渲染出的 transport，不参与 context identity。Store 在任何
`pool.write` 前把 `contextJson` 当 §5.1 canonical object 解码/再编码，逐字验证，
重算 SHA-256 并与 claimed `contextHash` 比较；invalid、非 object、非 canonical、
hash mismatch 均 typed error、零 DB 写。

`EngineSessionScopeV1: Codable` 是另一份 immutable canonical object，只包含
`schemaVersion=1/campId/profileId/adapterId+version/engineKind/model/
workspaceHash/contractId+version+hash`，不含本轮 Input、Memory 或 user answer。
Store 从 begin request 的 exact fields 构造、canonical encode 并自算
sessionScopeHash；caller 不能提供权威 scope JSON/hash。若 API 为 transport
diagnostic 接受 claimed hash，只能与重算值比较，绝不入库当真相；spoof/mismatch
在任何 SQL 前失败。回答后创建的新 execution 可以有新的 contextJson/contextHash，
但只有 derived sessionScopeHash 完全相同才可复用 session；scope 漂移必须新开
session。

`beginEngineExecution` 在同 transaction 读取 active Camp lifecycle version，把
不可变 `campLifecycleVersion` 写入 request/row 并纳入 whole request hash，再从 exact
descriptor/version 调
`executionReplayClass(for: derivedScope)` 并写入 request/row；caller 不得覆盖。
recovery 重新加载同 adapter version 的 descriptor 并校验 row class；descriptor/
row mismatch fail-closed 为 `engine_protocol_error` + Attention，不得临时换 class
以选择更宽松 recovery。

在 `beginEngineExecution` 内，上述所有字段（Grant IDs 排序后）编码为 canonical
`requestJson` 并由 store 自算 `requestHash`。idempotency key 重放只有 hash 完全
一致才返回原 execution/run/request；同 key 不同 Camp、Contract、Grant、budget、
workspace、profile、model、context 或 session ref 均抛
`EngineExecutionReplayConflictError`。

adapter dispatch 有唯一耐久边界：

```text
markEngineDispatchStarted(
    executionId: String,
    expectedVersion: Int,
    requestHash: String,
    commandIdempotencyKey: String,
    now: Date
) throws -> EngineDispatchStartResult
```

它在单一 transaction CAS `prepared -> started`、写 `dispatchStartedAt` 与 event。
首次命令返回 `.startNow(exactPersistedRequest)`；同命令重放返回
`.alreadyStarted`，调用方在后一分支**不得**调用 adapter。adapter 只能在
`.startNow` transaction commit 后执行。四个 crash window 固定为：

| crash 位置 | 持久事实与恢复 |
|---|---|
| dispatch CAS 前 | `prepared`，可首次 mark/start |
| CAS commit 后、adapter call 前 | `started`，已不可证明未调用 |
| adapter 已调用、首个 event 前 | `started`，同样按 replay class 收敛 |
| exact session bind commit 后 | `sessionBound`，只 exact resume |

descriptor/capability/setup mismatch 若在已有 prepared execution 上确定发生，必须走
kernel `commitEnginePreDispatchFailure`：一个 transaction 产生
blocked+engineProtocolError（或 typed failed）proposal/receipt，终结
execution/Run/Card/Mission/events，保持 `dispatchStartedAt=NULL`。不得为满足 CHECK
伪造 dispatch started。重复 command 同 failure 重放，异 failure conflict。

### 16.3 Event 与终态

`EngineExecutionEvent` 带 `executionId` 和单调 sequence：

- `accepted`
- `sessionBound`
- `progress`
- `toolActivity`
- `usage`
- `terminal`

terminal kind 精确一次且只有 `completed|blocked|failed|canceled`。blocked 的
`terminalSubtype` 只有
`ordinary|needsHumanInput|engineProtocolError|externalEffectUnknown`；
`ask_user` 使用 `blocked + needsHumanInput`，稳定 reason raw value
`needs_human_input`，不是第五种 terminal kind。EOF、未知输出、缺 board
terminator、parser error 都是 `blocked + engineProtocolError` 或 failed，绝不算
completed。

`EngineTerminalProposalContentV1` 是 proposal identity 的唯一 canonical object：

- 公共 envelope：protocolVersion、executionId/runId/cardId、sequence、
  terminalIdempotencyKey、terminal kind/subtype、完整 typed payload；
- completed payload：完整可 decode/validate 的 `HandoffPayload`，以及每件 artifact
  declaration 的 explicit contiguous `ordinal`、normalized workspace-relative
  source path、kind、label、byteCount、SHA-256；declaration 按 ordinal 排序后嵌入
  whole object。caller 不提供 artifactId；首次 record transaction 为 normalized
  rows 生成并持久化 artifactId，重放返回这些 exact IDs；
- blocked payload：稳定 reason code + 净化 detail；
- needs-human-input 是 blocked subtype，另含 user-request kind、prompt、
  canonical options；不得降成普通 detail；
- failed/canceled payload：稳定 code/reason + 净化 detail。

Store 对整个 `EngineTerminalProposalContentV1` 一次 canonical encode，保存
`proposalJson/proposalHash`；`payloadHash` 和 `artifactManifestHash` 只是内部完整性
子 hash，不能替代 identity。同 terminal idempotency key 只有 whole proposalHash
一致才重放；即使 payload 相同，只改变 artifact manifest/order/label/path/hash 也
必须 conflict。仅调用方 array 顺序变化而 explicit ordinals/字段不变不会改变
identity；任一 ordinal 或字段变化会 conflict。`engine_execution.terminalReceiptHash` 在 commit 后等于 typed
`EngineTerminalCommitReceipt` 所在
`domain_command_receipt.resultHash`，并以
`terminalReceiptIdempotencyKey` 真实 FK 定位 receipt。proposalHash 只表示
proposal identity；valid/invalid terminal 都必须能重放同一 durable commit
receipt，二者不得混用。

kernel 收到 proposal 后用 `recordEngineTerminalProposal` 在一个 transaction 插入
state=pending 的 proposal 及 normalized `engine_proposal_artifact` rows；声明的每个
expected contentHash 从此立即是 GC root。payload/proposal 是恢复真相。

artifact 跨文件系统/SQLite 的协议固定为：

1. kernel 在记录 pending proposal 后调用 `ArtifactStager.prepare`；只允许读取该
   execution 的 workspace。恢复时先检查已登记 content-addressed blob：存在且
   byteCount/hash 正确即可继续，即使 workspace source 已不存在；blob 缺失时才读
   source。两者都缺失或任一现存 blob corrupt 属确定性 protocol failure。
2. 先复制到 `artifactStoreRoot/.staging/<executionId>/<artifactId>.tmp`，fsync 后
   原子 rename 到 content-addressed
   `artifactStoreRoot/blobs/<sha256>`；同 hash 已存在则验证后复用，然后 upsert
   `artifact_blob` 并把 proposal-artifact CAS prepared。crash 在 rename 后/DB
   upsert 前由 expected hash 路径发现并补登记。此时尚不写 artifact/handoff/Run
   terminal，所以 blob 不对产品可见。
3. `commitEngineTerminal` transaction 重读 pending proposal，重验所有 blob
   size/hash，随后一次插 artifact rows（path 指向 immutable blob）及
   `artifact_blob_reference`、完整 handoff、Run/Card/Mission/engine
   terminal/events，并把 proposal committed。数据库永不引用 staging/tmp 或尚不
   存在的 blob。
4. crash 在 prepare 前/中/后都由 active Camp 的 pending proposal 重放同一
   prepare+commit；deletionRequested Camp 改走 §14.2 specialized supersession，
   不再 prepare/commit。`.tmp` 启动清理。GC live set 是 committed active
   `artifact_blob_reference`、pending proposal-artifact expected hashes与 nonterminal
   `camp_deletion_proposal_blob` hashes 的并集；
   只有不在 live set 且 `createdAt <= now-24h` 的 blob 才由持有
   StateDirectoryLock 的 `ArtifactBlobStore` 删除。commit 失败保留 blob 供重放。

path escape、声明 source/blob 都缺失、size/hash mismatch 或 corrupt blob 必须调用：

```text
invalidateProposalAndCommitProtocolError(
    proposalId: String,
    expectedVersion: Int,
    failure: EngineTerminalPreparationFailure,
    commandIdempotencyKey: String,
    now: Date
) throws -> EngineTerminalCommitReceipt
```

`EngineTerminalCommitReceipt` 是 canonical typed result：
`receiptIdempotencyKey/executionId/proposalId/proposalHash/disposition/
terminalKind/terminalSubtype/reasonCode/artifactIds/committedEventIds/finishedAt`；
`disposition` 只有
`committedProposal|invalidProtocolError|invalidCampDeletion`。invalid preparation
使用原 proposalId/hash、`invalidProtocolError + blocked+engineProtocolError` 和空
artifactIds；F2 specialized closeout 使用
`invalidCampDeletion + canceled + camp_deleted`。其 canonical resultHash 是
execution 的 terminal receipt hash。

该命令单 transaction 把 pending proposal 置 invalid，保存稳定 invalid reason，并
以 kernel-owned `blocked + engineProtocolError` 一次终结
execution/Run/Card/Mission，写 events/outbox 和 urgent Attention intent；禁止创建
第二 proposal。同 command/failure 重放同 receipt，异 failure conflict；任一
projection/event 失败整笔回滚，proposal 仍 pending 可恢复。

所有权和事务边界固定为：

1. kernel 的 `beginEngineExecution` 在一个 transaction 分配
   `executionId + runId`、插入 `engine_execution` 与 `run`、把 Card
   `ready -> running`、写事件；adapter 收到的 request 必须使用这些 exact IDs。
2. `CardRunner`、`CliProcessBackend`、ModelLoop/CLI adapter、BoardTools 和
   BoardToolServer 不得调用 `startRun`、`finishRun`、`completeCard`、
   `blockCard` 或直接更改 Card/Mission。
3. `complete_card` / `block_card` 仍是模型必须使用的语义终结工具，但 handler 只
   形成上述完整 proposal 并交给 kernel-owned terminal sink。`add_progress_note`
   保持非 terminal 命令。
4. `ask_user` 只能调用 kernel
   `commitEngineAskUser(proposal:usage:now:)`：单 transaction 插 exact
   `user_request`、以 reason=`needs_human_input` 把 Card blocked、finish Run 为
   blocked、更新 engine execution/Mission/events/proposal。BoardTools/adapter
   不直接插 request 或 block Card；用户回答后由既有 answer command 令 Card ready，
   新建下一次 execution，不能复活已终结 Run。
5. kernel 的 `commitEngineTerminal` 校验 execution 仍 running、完整
   proposal/IDs/hash/sequence 匹配且没有 committed terminal；随后以一个
   transaction 校验 usage overflow、更新 Run outcome/usage、Card
   completed/blocked/ready 状态、完整 handoff/artifacts、Mission rollup、
   engine_execution terminal、旧/新 events。任何一步失败整笔回滚。
6. adapter EOF/throw/cancel 也只产生 terminal proposal；由 kernel 用同一 API
   提交。重复 terminal 同 payload 返回原 receipt，异 terminal、跳号或乱序为
   `engine_terminal_conflict`，不得二次改 Run/Card。
7. interrupted recovery 不得猜，固定矩阵如下：

| 持久事实 | 恢复动作 |
|---|---|
| pending terminal proposal，Camp lifecycle active | 重放 artifact prepare，并 commit exact proposal |
| pending terminal proposal，Camp lifecycle deletionRequested | 只走 F2 specialized supersession；不 prepare、不正常 commit、不 dispatch |
| `nonReplayable` + `started|sessionBound` 且没有 pending proposal | **优先于 cancellation**，commit `blocked + externalEffectUnknown`，reason `external_effect_unknown`，创建 urgent Attention，不重放 |
| cancellation 已记录且 `prepared` | adapter 明确从未调用；commit canceled。普通 cancel Card→ready，Mission/Camp halt→canceled |
| cancellation 已记录且 `started|sessionBound`、replaySafe/idempotencyKeyed | 以 same key cancel/reconcile，只有 adapter terminal evidence 后 commit；不得仅凭本地请求猜 canceled |
| `prepared` 且没有 cancellation（adapter 从未调用） | 以同 request/execution key 首次启动 |
| active exact engine_session 且 descriptor 支持 resume | exact session resume |
| 无 session，adapter replayClass=`replaySafe|idempotencyKeyed` | 以同 execution/request idempotency key 重放 |
| parser error、EOF、session mismatch 或 descriptor 不支持所需恢复 | commit blocked reason `engine_protocol_error`；不得标 completed |

所有 recovery branch 最终仍走 kernel terminal transaction。
Camp retirement 对 started/sessionBound nonReplayable execution 复用同一
`externalEffectUnknown` terminal transaction；deletion permit 只授权这次 safe
terminalization，不提供 replay/no-effect/success authority。该 execution terminal
后不再作为 deletion blocker；独立的 unresolved `approval_grant_use` 仍按 §13
继续阻止 finalize。

### 16.4 Session continuation

`engine_session` 保存：`id`、稳定 `campId`、`adapterId/version`、`profileId`、
`externalSessionId`、`workspaceHash`、store-derived
`sessionScopeJson/sessionScopeHash`、
`state(active|closed|invalid)`、`createdAt`、`updatedAt`。execution 通过真实 FK
保存 exact `sessionId`；不得只存自由文本，也不得保存 credential。

- Codex 首轮从 JSONL 的 session/thread event 取得精确 ID；续传使用 `codex exec resume <ID>`。
- Claude 首轮由牧场生成 UUID 并传 `--session-id <ID>`；续传使用 `--resume <ID>`。
- 禁止 `--last` 或 `-c/--continue`，避免串到别的对话。
- resume 必须重新注入 ranchboard MCP、权限、workspace 与当前 Contract；workspace/profile/adapter 不匹配时 fail-closed。
- bind/resume transaction 必须同时验证 session 与 execution 的
  `campId/profileId/adapterId+version/sessionScopeHash/workspaceHash` 全部相同；
  execution 的 contextHash 仍逐次 canonical/recompute，但不要求跨 execution
  相同；任一 scope 漂移
  `EngineSessionScopeMismatchError` 且零写入。
- 如果某 CLI 版本的实际输出/flags 与 descriptor 不符，sessionResume 变为 unsupported 并显示能力降级；不得猜 flag。

现有 ModelLoop、Codex CLI、Claude CLI 都通过 adapter 实现此协议；CardRunner
不直接按 profile kind 分叉创建 backend，任何 adapter 都不持有 `AppDatabase`。

## 17. 有限讨论、主动性、注意力和双轨成长

### 17.1 有限讨论

`discussion`：

- `id`、Goal/Mission/Card ref、`purpose`
- participant actor IDs
- `maxRounds`（1...3）
- `tokenBudget`、`spentTokens`
- `status(proposed|running|completed|blocked|canceled|failed)`
- `requiredMaterialization`
- aggregate version 和时间

`discussion_turn` append-only：round、speaker、contentRef/hash、usage、createdAt。

默认 helper 提议 2 轮，预算为 Mission 剩余预算的 10%、上限 20,000 tokens；调用方必须把最终值写入 Discussion，不能无限讨论。

完成必须物化为 `decision`、`handoff`、`outcome`、`verification`、`cardRevision` 或 `planRevision` 之一；没有物化对象则 Discussion failed。

### 17.2 注意力

`attention_item`：

- source event ref
- level：`recordOnly` / `summary` / `needsAction` / `urgent`
- dedupe key
- `status(open|acknowledged|dismissed|resolved)`
- target Camp/Goal/Mission
- due / escalation time nullable
- 时间

只有缺用户决定/审批/验收、计划冲突进入 `needsAction`；成本异常、数据风险、安全与不可恢复失败进入 `urgent`。系统不得把普通进展升级成打扰。

### 17.3 双轨成长

`growth_evidence`：

- `id`
- `track(capability|relationship|world)`
- Cow/Camp/World subject ref
- source Outcome/Verification/Acceptance ref nullable
- `evidenceHash`
- `status(proposed|active|invalidated)`
- `createdAt`、`invalidatedAt`

能力成长必须引用 accepted Outcome 和 valid Verification；关系/世界可引用共事与里程碑事件。任何 growth 都不能创建 ApprovalGrant、提升模型档位或扩大权限。

## 18. 规范性 Migration Schema

本节是 v12–v17 的数据库权威定义；前文的字段清单只是解释。实现可使用 GRDB
table builder，但生成结果必须与下列 SQL 等价。所有 FK 均在 migration test 中以
`PRAGMA foreign_key_check` 验证；所有带 canonical/hash/receipt/request 语义的
JSON TEXT 均由 §5.1 `CanonicalJSONV1` 产生。只用于 prompt transport 的既有 JSON
仍保留 `.sortedKeys`，但不得成为另一份 hash 真相。未写 `ON UPDATE` 的 FK 均为
`ON UPDATE RESTRICT`。

以下 append-only 表统一创建两个 abort trigger：

```text
durable_work_attempt_event, domain_command_receipt, domain_event,
verification_record, verification_invalidation, acceptance_record,
external_operation_receipt, memory_dependency, discussion_turn
```

trigger 名固定为 `<table>_reject_update` 与 `<table>_reject_delete`，分别在
`BEFORE UPDATE` / `BEFORE DELETE` 执行
`RAISE(ABORT, '<table> is append-only')`。version/content 表由 store 只追加正文；
允许的 head/status CAS 不能改 content/hash。
每一对标准 guard 必须在 owning table 的 introducing migration 提交前建立，而不是
等 F2 或最终 aggregate migration 补装。每个 introducing-slice gate 都要先证明合法
INSERT，再证明普通 UPDATE、no-op UPDATE 与 DELETE 均 abort。
v16 在 user-confirmed Camp deletion 的 `deleting` + job `finalizing` fence 下，
用更严格 trigger 替换 `durable_work_attempt_event`、`verification_record`、
`acceptance_record`、`external_operation_receipt` 与 legacy `event` 的 UPDATE
guard；v17 的 `discussion_turn` 从创建起使用同一规则。只允许 §14.2 exact
redaction column diff；DELETE guard 在任何 committed schema 中永不缺失，普通
UPDATE仍 abort。v16 的 durable child-table rebuild 是唯一物理例外：旧
`durable_work_attempt_event` table 被 DROP 时 SQLite 同 transaction 自动移除其
DELETE trigger；新 final-named table 必须在同 migration 提交前用相同名字重建
DELETE guard。失败 rollback 必须恢复旧 table/data 与两枚 v12 标准 guards，不能
留下已提交的无 guard 窗口。

### 18.1 `v12-p1-durable-work`（P1-A1a）

```sql
CREATE TABLE durable_work (
  id TEXT PRIMARY KEY NOT NULL,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  kind TEXT NOT NULL CHECK (kind IN
    ('planning','rumination','coach','guideChat','memoryPromotion','inputParsing',
     'campDeletion')),
  aggregateType TEXT NOT NULL,
  aggregateId TEXT NOT NULL,
  idempotencyKey TEXT NOT NULL,
  state TEXT NOT NULL CHECK (state IN
    ('queued','running','retryScheduled','succeeded','failed','canceled')),
  attempt INTEGER NOT NULL DEFAULT 0 CHECK (attempt >= 0),
  maxAttempts INTEGER NOT NULL DEFAULT 4 CHECK (maxAttempts >= 1),
  notBefore DATETIME,
  leaseOwner TEXT,
  leaseExpiresAt DATETIME,
  inputJson TEXT NOT NULL,
  inputHash TEXT NOT NULL CHECK (
    length(inputHash) = 64 AND inputHash NOT GLOB '*[^0-9a-f]*'
  ),
  outputJson TEXT,
  errorCode TEXT,
  errorMessage TEXT CHECK (
    errorMessage IS NULL OR length(errorMessage) BETWEEN 1 AND 1000
  ),
  traceId TEXT NOT NULL,
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  finishedAt DATETIME,
  UNIQUE(kind, idempotencyKey),
  CHECK (
    (state = 'running' AND leaseOwner IS NOT NULL AND leaseExpiresAt IS NOT NULL)
    OR
    (state <> 'running' AND leaseOwner IS NULL AND leaseExpiresAt IS NULL)
  ),
  CHECK (
    (state = 'retryScheduled' AND notBefore IS NOT NULL)
    OR
    (state <> 'retryScheduled' AND notBefore IS NULL)
  ),
  CHECK (
    (state IN ('succeeded','failed','canceled') AND finishedAt IS NOT NULL)
    OR
    (state IN ('queued','running','retryScheduled') AND finishedAt IS NULL)
  ),
  CHECK (outputJson IS NULL OR state = 'succeeded'),
  CHECK (
    errorCode IS NULL OR (
      length(errorCode) BETWEEN 1 AND 64
      AND substr(errorCode, 1, 1) GLOB '[a-z]'
      AND errorCode NOT GLOB '*[^a-z0-9_]*'
    )
  ),
  CHECK (COALESCE((
    (state = 'queued'
      AND outputJson IS NULL
      AND (
        (errorCode IS NULL AND errorMessage IS NULL)
        OR
        (errorCode = 'worker_interrupted' AND errorMessage IS NULL)
      ))
    OR
    (state IN ('running','succeeded')
      AND errorCode IS NULL AND errorMessage IS NULL)
    OR
    (state IN ('retryScheduled','failed') AND errorCode IS NOT NULL
      AND outputJson IS NULL)
    OR
    (state = 'canceled' AND errorCode = 'work_canceled'
      AND errorMessage IS NOT NULL AND outputJson IS NULL)
  ), 0))
);
CREATE UNIQUE INDEX durable_work_one_active_aggregate
  ON durable_work(kind, aggregateType, aggregateId)
  WHERE state IN ('queued','running','retryScheduled');
CREATE INDEX durable_work_claimable
  ON durable_work(campId, kind, state, notBefore, createdAt);
CREATE INDEX durable_work_aggregate_history
  ON durable_work(aggregateType, aggregateId, createdAt);

CREATE TABLE durable_work_attempt (
  workId TEXT NOT NULL REFERENCES durable_work(id) ON DELETE RESTRICT,
  attempt INTEGER NOT NULL CHECK (attempt >= 1),
  id TEXT NOT NULL UNIQUE,
  workerId TEXT NOT NULL,
  startedAt DATETIME NOT NULL,
  endedAt DATETIME,
  outcome TEXT CHECK (outcome IS NULL OR outcome IN
    ('succeeded','failed','canceled','interrupted')),
  errorCode TEXT,
  errorMessage TEXT CHECK (
    errorMessage IS NULL OR length(errorMessage) BETWEEN 1 AND 1000
  ),
  traceId TEXT NOT NULL,
  terminalWorkVersion INTEGER CHECK
    (terminalWorkVersion IS NULL OR terminalWorkVersion >= 1),
  PRIMARY KEY(workId, attempt),
  CHECK (
    (endedAt IS NULL AND outcome IS NULL AND terminalWorkVersion IS NULL)
    OR
    (endedAt IS NOT NULL AND outcome IS NOT NULL AND terminalWorkVersion IS NOT NULL)
  ),
  CHECK (
    errorCode IS NULL OR (
      length(errorCode) BETWEEN 1 AND 64
      AND substr(errorCode, 1, 1) GLOB '[a-z]'
      AND errorCode NOT GLOB '*[^a-z0-9_]*'
    )
  ),
  CHECK (COALESCE((
    (endedAt IS NULL AND errorCode IS NULL AND errorMessage IS NULL)
    OR
    (outcome = 'succeeded' AND errorCode IS NULL AND errorMessage IS NULL)
    OR
    (outcome = 'failed' AND errorCode IS NOT NULL)
    OR
    (outcome = 'canceled' AND errorCode = 'work_canceled'
      AND errorMessage IS NOT NULL)
    OR
    (outcome = 'interrupted' AND errorCode = 'worker_interrupted'
      AND errorMessage IS NULL)
  ), 0))
);

CREATE TABLE durable_work_attempt_event (
  id TEXT PRIMARY KEY NOT NULL,
  workId TEXT NOT NULL,
  attempt INTEGER NOT NULL,
  sequence INTEGER NOT NULL CHECK (sequence >= 0),
  eventKind TEXT NOT NULL CHECK (eventKind IN
    ('claimed','leaseRenewed','succeeded','failed','canceled','interrupted')),
  workerId TEXT NOT NULL,
  workVersion INTEGER NOT NULL CHECK (workVersion >= 1),
  resultingWorkState TEXT NOT NULL CHECK (resultingWorkState IN
    ('running','retryScheduled','succeeded','failed','canceled','queued')),
  errorCode TEXT,
  errorMessage TEXT CHECK (
    errorMessage IS NULL OR length(errorMessage) BETWEEN 1 AND 1000
  ),
  occurredAt DATETIME NOT NULL,
  FOREIGN KEY(workId, attempt)
    REFERENCES durable_work_attempt(workId, attempt) ON DELETE RESTRICT,
  UNIQUE(workId, attempt, sequence),
  CHECK ((sequence = 0) = (eventKind = 'claimed')),
  CHECK (
    errorCode IS NULL OR (
      length(errorCode) BETWEEN 1 AND 64
      AND substr(errorCode, 1, 1) GLOB '[a-z]'
      AND errorCode NOT GLOB '*[^a-z0-9_]*'
    )
  ),
  CHECK (COALESCE((
    (eventKind IN ('claimed','leaseRenewed')
      AND resultingWorkState = 'running'
      AND errorCode IS NULL AND errorMessage IS NULL)
    OR
    (eventKind = 'succeeded' AND resultingWorkState = 'succeeded'
      AND errorCode IS NULL AND errorMessage IS NULL)
    OR
    (eventKind = 'failed'
      AND resultingWorkState IN ('retryScheduled','failed')
      AND errorCode IS NOT NULL)
    OR
    (eventKind = 'canceled' AND resultingWorkState = 'canceled'
      AND errorCode = 'work_canceled' AND errorMessage IS NOT NULL)
    OR
    (eventKind = 'interrupted' AND resultingWorkState = 'queued'
      AND errorCode = 'worker_interrupted' AND errorMessage IS NULL)
  ), 0))
);
CREATE UNIQUE INDEX durable_work_attempt_one_terminal
  ON durable_work_attempt_event(workId, attempt)
  WHERE eventKind IN ('succeeded','failed','canceled','interrupted');
CREATE INDEX durable_work_attempt_event_work
  ON durable_work_attempt_event(workId, attempt, sequence);

CREATE TRIGGER durable_work_attempt_event_reject_update
BEFORE UPDATE ON durable_work_attempt_event
BEGIN
  SELECT RAISE(ABORT, 'durable_work_attempt_event is append-only');
END;
CREATE TRIGGER durable_work_attempt_event_reject_delete
BEFORE DELETE ON durable_work_attempt_event
BEGIN
  SELECT RAISE(ABORT, 'durable_work_attempt_event is append-only');
END;
```

### 18.2 `v12-p1-schedule-fire`（P1-A4）

```sql
CREATE TABLE schedule_fire (
  id TEXT PRIMARY KEY NOT NULL,
  scheduleId TEXT NOT NULL REFERENCES schedule(id) ON DELETE RESTRICT,
  templateId TEXT NOT NULL REFERENCES mission_template(id) ON DELETE RESTRICT,
  slotKey TEXT NOT NULL,
  scheduledAt DATETIME NOT NULL,
  replayOfFireId TEXT REFERENCES schedule_fire(id) ON DELETE RESTRICT,
  replayIdempotencyKey TEXT,
  replayPayloadHash TEXT CHECK
    (replayPayloadHash IS NULL OR length(replayPayloadHash) = 64),
  state TEXT NOT NULL CHECK (state IN ('started','failed')),
  missionId TEXT REFERENCES mission(id) ON DELETE RESTRICT,
  traceId TEXT NOT NULL,
  errorCode TEXT,
  errorMessage TEXT CHECK (errorMessage IS NULL OR length(errorMessage) <= 1000),
  createdAt DATETIME NOT NULL,
  redactedAt DATETIME,
  CHECK (
    (replayOfFireId IS NULL AND replayIdempotencyKey IS NULL
      AND replayPayloadHash IS NULL)
    OR
    (replayOfFireId IS NOT NULL AND replayIdempotencyKey IS NOT NULL
      AND replayPayloadHash IS NOT NULL)
  ),
  CHECK (
    (state = 'started' AND missionId IS NOT NULL
      AND errorCode IS NULL AND errorMessage IS NULL)
    OR
    (state = 'failed' AND missionId IS NULL AND errorCode IS NOT NULL)
  ),
  CHECK (redactedAt IS NULL OR errorMessage IS NULL)
);
CREATE UNIQUE INDEX schedule_fire_original_slot
  ON schedule_fire(scheduleId, slotKey) WHERE replayOfFireId IS NULL;
CREATE UNIQUE INDEX schedule_fire_replay_key
  ON schedule_fire(replayIdempotencyKey)
  WHERE replayIdempotencyKey IS NOT NULL;
CREATE INDEX schedule_fire_schedule_time
  ON schedule_fire(scheduleId, scheduledAt, createdAt);

CREATE TABLE schedule_evaluation_cursor (
  scheduleId TEXT PRIMARY KEY NOT NULL REFERENCES schedule(id) ON DELETE CASCADE,
  lastEvaluatedSlotKey TEXT NOT NULL,
  lastEvaluatedScheduledAt DATETIME NOT NULL,
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  updatedAt DATETIME NOT NULL
);
```

### 18.3 `v13-p1-observability`

```sql
CREATE TABLE failure_record (
  id TEXT PRIMARY KEY NOT NULL,
  operation TEXT NOT NULL,
  scopeKind TEXT NOT NULL CHECK (scopeKind IN ('camp','global')),
  campId TEXT REFERENCES camp(id) ON DELETE RESTRICT,
  scopeType TEXT NOT NULL,
  scopeId TEXT NOT NULL,
  severity TEXT NOT NULL CHECK (severity IN ('info','warning','error','critical')),
  errorCode TEXT NOT NULL,
  userMessage TEXT NOT NULL CHECK (length(userMessage) <= 1000),
  diagnosticJson TEXT NOT NULL,
  state TEXT NOT NULL CHECK (state IN ('open','resolved')),
  firstSeenAt DATETIME NOT NULL,
  lastSeenAt DATETIME NOT NULL,
  occurrenceCount INTEGER NOT NULL DEFAULT 1 CHECK (occurrenceCount >= 1),
  resolvedAt DATETIME,
  redactedAt DATETIME,
  CHECK (
    (scopeKind = 'camp' AND campId IS NOT NULL)
    OR
    (scopeKind = 'global' AND campId IS NULL)
  ),
  CHECK (
    redactedAt IS NULL
    OR (scopeKind = 'camp' AND userMessage = '[deleted]'
      AND diagnosticJson = '{}')
  )
);
CREATE INDEX failure_record_open_scope
  ON failure_record(scopeKind, campId, state, scopeType, scopeId, lastSeenAt);

CREATE TABLE context_degradation (
  id TEXT PRIMARY KEY NOT NULL,
  missionId TEXT REFERENCES mission(id) ON DELETE RESTRICT,
  cardId TEXT REFERENCES card(id) ON DELETE RESTRICT,
  dependencyType TEXT NOT NULL,
  dependencyId TEXT NOT NULL,
  policy TEXT NOT NULL CHECK (policy IN ('required','optionalApproved')),
  traceId TEXT NOT NULL,
  detail TEXT NOT NULL CHECK (length(detail) <= 1000),
  createdAt DATETIME NOT NULL,
  redactedAt DATETIME,
  CHECK (missionId IS NOT NULL OR cardId IS NOT NULL),
  CHECK (redactedAt IS NULL OR detail = '[deleted]')
);
CREATE INDEX context_degradation_mission
  ON context_degradation(missionId, createdAt);
CREATE INDEX context_degradation_card
  ON context_degradation(cardId, createdAt);
```

### 18.4 `v14-p1-control-contracts`

```sql
CREATE TABLE domain_command_receipt (
  idempotencyKey TEXT PRIMARY KEY NOT NULL,
  commandType TEXT NOT NULL,
  commandPayloadHash TEXT NOT NULL CHECK (length(commandPayloadHash) = 64),
  eventCount INTEGER NOT NULL CHECK (eventCount >= 0),
  resultJson TEXT NOT NULL,
  resultHash TEXT NOT NULL CHECK (length(resultHash) = 64),
  createdAt DATETIME NOT NULL
);

CREATE TABLE domain_event (
  id TEXT PRIMARY KEY NOT NULL,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  aggregateType TEXT NOT NULL,
  aggregateId TEXT NOT NULL,
  aggregateVersion INTEGER NOT NULL CHECK (aggregateVersion >= 1),
  eventType TEXT NOT NULL,
  payloadVersion INTEGER NOT NULL CHECK (payloadVersion >= 1),
  payloadJson TEXT NOT NULL,
  payloadHash TEXT NOT NULL CHECK (length(payloadHash) = 64),
  actorType TEXT NOT NULL CHECK (actorType IN
    ('user','system','coach','cow','engine','device')),
  actorId TEXT NOT NULL,
  deviceId TEXT,
  causationId TEXT,
  correlationId TEXT NOT NULL,
  commandIdempotencyKey TEXT NOT NULL
    REFERENCES domain_command_receipt(idempotencyKey) ON DELETE RESTRICT,
  eventOrdinal INTEGER NOT NULL CHECK (eventOrdinal >= 0),
  eventIdempotencyKey TEXT NOT NULL UNIQUE,
  occurredAt DATETIME NOT NULL,
  recordedAt DATETIME NOT NULL,
  UNIQUE(aggregateType, aggregateId, aggregateVersion),
  UNIQUE(commandIdempotencyKey, eventOrdinal)
);
CREATE INDEX domain_event_correlation ON domain_event(correlationId, recordedAt);
CREATE INDEX domain_event_camp ON domain_event(campId, recordedAt);
CREATE INDEX domain_event_aggregate
  ON domain_event(aggregateType, aggregateId, aggregateVersion);

CREATE TABLE event_outbox (
  eventId TEXT PRIMARY KEY NOT NULL
    REFERENCES domain_event(id) ON DELETE RESTRICT,
  state TEXT NOT NULL CHECK
    (state IN ('pending','dispatching','sent','failed')),
  attempt INTEGER NOT NULL DEFAULT 0 CHECK (attempt >= 0),
  notBefore DATETIME,
  leaseOwner TEXT,
  leaseExpiresAt DATETIME,
  lastError TEXT CHECK (lastError IS NULL OR length(lastError) <= 1000),
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  sentAt DATETIME,
  CHECK (
    (state = 'dispatching' AND leaseOwner IS NOT NULL AND leaseExpiresAt IS NOT NULL)
    OR
    (state <> 'dispatching' AND leaseOwner IS NULL AND leaseExpiresAt IS NULL)
  ),
  CHECK (
    (state = 'sent' AND sentAt IS NOT NULL)
    OR
    (state <> 'sent' AND sentAt IS NULL)
  )
);
CREATE INDEX event_outbox_pending ON event_outbox(state, notBefore, createdAt);

CREATE TABLE inbox_message (
  id TEXT PRIMARY KEY NOT NULL,
  campId TEXT REFERENCES camp(id) ON DELETE RESTRICT,
  sourceDeviceId TEXT NOT NULL,
  idempotencyKey TEXT NOT NULL UNIQUE,
  payloadJson TEXT NOT NULL,
  payloadHash TEXT NOT NULL CHECK (length(payloadHash) = 64),
  state TEXT NOT NULL CHECK (state IN ('received','applied','rejected')),
  receivedAt DATETIME NOT NULL,
  appliedAt DATETIME,
  errorCode TEXT,
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  redactedAt DATETIME,
  CHECK (
    redactedAt IS NULL
    OR
    (campId IS NOT NULL
      AND sourceDeviceId = '[deleted]'
      AND payloadJson = '{}'
      AND state = 'rejected'
      AND errorCode = 'camp_deleted')
  )
);
CREATE INDEX inbox_message_camp_state
  ON inbox_message(campId, state, receivedAt);

CREATE TABLE input_envelope (
  id TEXT PRIMARY KEY NOT NULL,
  schemaVersion INTEGER NOT NULL DEFAULT 1 CHECK (schemaVersion = 1),
  aggregateVersion INTEGER NOT NULL DEFAULT 1 CHECK (aggregateVersion >= 1),
  idempotencyKey TEXT NOT NULL UNIQUE,
  sourceType TEXT NOT NULL CHECK (sourceType IN
    ('text','url','file','image','audio','device','connector')),
  sourceDeviceId TEXT,
  connectorId TEXT,
  authorId TEXT,
  capturedAt DATETIME NOT NULL,
  inlineText TEXT,
  payloadRef TEXT,
  contentHash TEXT NOT NULL CHECK (length(contentHash) = 64),
  candidateCampIdsJson TEXT NOT NULL,
  campId TEXT REFERENCES camp(id) ON DELETE RESTRICT,
  explicitIntent TEXT NOT NULL CHECK (explicitIntent IN
    ('unspecified','archiveOnly','organize','createGoal','startNow')),
  privacyLevel TEXT NOT NULL CHECK (privacyLevel IN
    ('localOnly','encryptedSync','cloudExecution')),
  status TEXT NOT NULL CHECK (status IN
    ('captured','parseFailed','campAssignmentRequired','campAmbiguous',
     'coaching','archived','goalCreated','deletedTombstone')),
  errorCode TEXT,
  errorMessage TEXT CHECK (errorMessage IS NULL OR length(errorMessage) <= 1000),
  parentInputId TEXT REFERENCES input_envelope(id) ON DELETE RESTRICT,
  retentionState TEXT NOT NULL CHECK (retentionState IN
    ('active','deletionRequested','deletedTombstone')),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  deletedAt DATETIME,
  CHECK (
    (status = 'deletedTombstone' AND retentionState = 'deletedTombstone')
    OR
    (status <> 'deletedTombstone' AND retentionState <> 'deletedTombstone')
  ),
  CHECK (
    (retentionState = 'deletedTombstone'
      AND sourceDeviceId IS NULL
      AND connectorId IS NULL
      AND authorId IS NULL
      AND inlineText IS NULL
      AND payloadRef IS NULL
      AND candidateCampIdsJson = '[]'
      AND explicitIntent = 'unspecified'
      AND privacyLevel = 'localOnly'
      AND errorCode IS NULL
      AND errorMessage IS NULL
      AND parentInputId IS NULL
      AND deletedAt IS NOT NULL
      AND updatedAt = deletedAt)
    OR
    (retentionState <> 'deletedTombstone'
      AND ((inlineText IS NOT NULL) <> (payloadRef IS NOT NULL))
      AND deletedAt IS NULL)
  )
);
CREATE INDEX input_envelope_status ON input_envelope(status, updatedAt);
CREATE INDEX input_envelope_camp ON input_envelope(campId, capturedAt);

CREATE TABLE goal_controller (
  id TEXT PRIMARY KEY NOT NULL,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  sourceInputId TEXT REFERENCES input_envelope(id) ON DELETE RESTRICT,
  title TEXT NOT NULL,
  rawIntent TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN
    ('clarifying','ready','active','paused','achieved','abandoned','failed',
     'deletedTombstone')),
  currentUnderstandingId TEXT,
  currentUnderstandingVersion INTEGER,
  currentOutcomeContractId TEXT,
  currentOutcomeContractVersion INTEGER,
  aggregateVersion INTEGER NOT NULL DEFAULT 1 CHECK (aggregateVersion >= 1),
  createdByActorId TEXT NOT NULL,
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  CHECK (
    (currentUnderstandingId IS NULL AND currentUnderstandingVersion IS NULL)
    OR
    (currentUnderstandingId IS NOT NULL AND currentUnderstandingVersion >= 1)
  ),
  CHECK (
    (currentOutcomeContractId IS NULL AND currentOutcomeContractVersion IS NULL)
    OR
    (currentOutcomeContractId IS NOT NULL AND currentOutcomeContractVersion >= 1)
  )
);
CREATE INDEX goal_controller_camp_status
  ON goal_controller(campId, status, updatedAt);

CREATE TABLE goal_mission_link (
  missionId TEXT PRIMARY KEY NOT NULL REFERENCES mission(id) ON DELETE RESTRICT,
  goalId TEXT NOT NULL REFERENCES goal_controller(id) ON DELETE RESTRICT,
  outcomeContractId TEXT,
  outcomeContractVersion INTEGER,
  state TEXT NOT NULL CHECK (state IN ('active','detached')),
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  CHECK (
    (outcomeContractId IS NULL AND outcomeContractVersion IS NULL)
    OR
    (outcomeContractId IS NOT NULL AND outcomeContractVersion >= 1)
  )
);
CREATE INDEX goal_mission_link_goal ON goal_mission_link(goalId, state);

CREATE TABLE coach_session (
  id TEXT PRIMARY KEY NOT NULL,
  goalId TEXT NOT NULL REFERENCES goal_controller(id) ON DELETE RESTRICT,
  inputId TEXT REFERENCES input_envelope(id) ON DELETE RESTRICT,
  actorId TEXT NOT NULL CHECK (actorId = 'system:coach:v1'),
  status TEXT NOT NULL CHECK (status IN
    ('interviewing','waitingForUser','readyForConfirmation',
     'confirmed','canceled','failed')),
  currentUnderstandingVersion INTEGER,
  pendingQuestionId TEXT,
  traceId TEXT NOT NULL,
  aggregateVersion INTEGER NOT NULL DEFAULT 1 CHECK (aggregateVersion >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL
);
CREATE INDEX coach_session_goal ON coach_session(goalId, status, updatedAt);

CREATE TABLE coach_question (
  id TEXT PRIMARY KEY NOT NULL,
  sessionId TEXT NOT NULL REFERENCES coach_session(id) ON DELETE RESTRICT,
  decisionKey TEXT NOT NULL,
  prompt TEXT NOT NULL,
  recommendation TEXT NOT NULL,
  reason TEXT NOT NULL,
  answerJson TEXT,
  state TEXT NOT NULL CHECK (state IN ('open','answered','withdrawn')),
  createdAt DATETIME NOT NULL,
  answeredAt DATETIME
);
CREATE UNIQUE INDEX coach_question_one_open
  ON coach_question(sessionId) WHERE state = 'open';
CREATE UNIQUE INDEX coach_question_decision
  ON coach_question(sessionId, decisionKey);

CREATE TABLE understanding_card_version (
  id TEXT NOT NULL,
  version INTEGER NOT NULL CHECK (version >= 1),
  goalId TEXT NOT NULL REFERENCES goal_controller(id) ON DELETE RESTRICT,
  problem TEXT NOT NULL,
  scenario TEXT NOT NULL,
  targetAudience TEXT NOT NULL,
  goalsJson TEXT NOT NULL,
  nonGoalsJson TEXT NOT NULL,
  deliverablesJson TEXT NOT NULL,
  constraintsJson TEXT NOT NULL,
  acceptanceCriteriaJson TEXT NOT NULL,
  verificationPlanJson TEXT NOT NULL,
  resourceRefsJson TEXT NOT NULL,
  requiredCapabilitiesJson TEXT NOT NULL,
  budgetPolicyJson TEXT NOT NULL,
  assumptionsJson TEXT NOT NULL,
  acceptedRisksJson TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN
    ('draft','awaitingConfirmation','confirmed','superseded','withdrawn')),
  contentHash TEXT NOT NULL CHECK (length(contentHash) = 64),
  createdByActorId TEXT NOT NULL,
  confirmedByActorId TEXT,
  confirmedAt DATETIME,
  createdAt DATETIME NOT NULL,
  PRIMARY KEY(id, version),
  UNIQUE(id, version, contentHash),
  CHECK (
    (status IN ('confirmed','superseded')
      AND confirmedByActorId IS NOT NULL AND confirmedAt IS NOT NULL)
    OR
    (status NOT IN ('confirmed','superseded')
      AND confirmedByActorId IS NULL AND confirmedAt IS NULL)
  )
);
CREATE INDEX understanding_goal ON understanding_card_version(goalId, version);

CREATE TRIGGER domain_command_receipt_reject_update
BEFORE UPDATE ON domain_command_receipt
BEGIN
  SELECT RAISE(ABORT, 'domain_command_receipt is append-only');
END;
CREATE TRIGGER domain_command_receipt_reject_delete
BEFORE DELETE ON domain_command_receipt
BEGIN
  SELECT RAISE(ABORT, 'domain_command_receipt is append-only');
END;
CREATE TRIGGER domain_event_reject_update
BEFORE UPDATE ON domain_event
BEGIN
  SELECT RAISE(ABORT, 'domain_event is append-only');
END;
CREATE TRIGGER domain_event_reject_delete
BEFORE DELETE ON domain_event
BEGIN
  SELECT RAISE(ABORT, 'domain_event is append-only');
END;
```

`coach_session.pendingQuestionId` 是防循环引用而不建 FK 的 denormalized pointer；
store 每次写时必须验证其等于同 session 唯一 open question，清除时与 question
terminal 同事务。Goal 的 OutcomeContract FK 在 v15 创建后由 store 强校验；
SQLite 不后加跨 migration FK。

### 18.5 `v15-p1-outcome-contracts`

```sql
CREATE TABLE acceptance_policy_version (
  id TEXT NOT NULL,
  version INTEGER NOT NULL CHECK (version >= 1),
  outcomeType TEXT NOT NULL,
  maxRiskClass TEXT NOT NULL CHECK (maxRiskClass IN ('low','normal')),
  policyActorId TEXT NOT NULL,
  validFrom DATETIME NOT NULL,
  validUntil DATETIME NOT NULL,
  maxOutcomeAgeSeconds INTEGER NOT NULL CHECK (maxOutcomeAgeSeconds > 0),
  requireAllVerification INTEGER NOT NULL DEFAULT 1
    CHECK (requireAllVerification = 1),
  status TEXT NOT NULL CHECK (status IN ('active','revoked','expired')),
  revokedAt DATETIME,
  createdByActorId TEXT NOT NULL,
  contentHash TEXT NOT NULL CHECK (length(contentHash) = 64),
  createdAt DATETIME NOT NULL,
  PRIMARY KEY(id, version),
  UNIQUE(id, version, contentHash),
  CHECK (validUntil > validFrom),
  CHECK (
    (status = 'revoked' AND revokedAt IS NOT NULL)
    OR
    (status <> 'revoked' AND revokedAt IS NULL)
  )
);
CREATE INDEX acceptance_policy_applicability
  ON acceptance_policy_version(outcomeType, status, validFrom, validUntil);

CREATE TABLE outcome_contract_version (
  id TEXT NOT NULL,
  version INTEGER NOT NULL CHECK (version >= 1),
  goalId TEXT NOT NULL REFERENCES goal_controller(id) ON DELETE RESTRICT,
  understandingId TEXT NOT NULL,
  understandingVersion INTEGER NOT NULL CHECK (understandingVersion >= 1),
  understandingHash TEXT NOT NULL CHECK (length(understandingHash) = 64),
  outcomeType TEXT NOT NULL,
  deliverablesJson TEXT NOT NULL,
  acceptanceCriteriaJson TEXT NOT NULL,
  verificationRequirementsJson TEXT NOT NULL,
  unacceptableDeviationsJson TEXT NOT NULL,
  requiredDependencyRefsJson TEXT NOT NULL,
  optionalDependencyRefsJson TEXT NOT NULL,
  requiresSubjectiveJudgment INTEGER NOT NULL DEFAULT 0
    CHECK (requiresSubjectiveJudgment IN (0,1)),
  includesPublicRelease INTEGER NOT NULL DEFAULT 0
    CHECK (includesPublicRelease IN (0,1)),
  includesPayment INTEGER NOT NULL DEFAULT 0 CHECK (includesPayment IN (0,1)),
  includesDeletion INTEGER NOT NULL DEFAULT 0 CHECK (includesDeletion IN (0,1)),
  includesExternalSend INTEGER NOT NULL DEFAULT 0
    CHECK (includesExternalSend IN (0,1)),
  riskClass TEXT NOT NULL CHECK
    (riskClass IN ('low','normal','high','irreversible')),
  acceptanceOwner TEXT NOT NULL CHECK (acceptanceOwner IN ('user','policy')),
  acceptancePolicyId TEXT,
  acceptancePolicyVersion INTEGER,
  status TEXT NOT NULL CHECK
    (status IN ('draft','active','superseded','fulfilled','canceled')),
  contentHash TEXT NOT NULL CHECK (length(contentHash) = 64),
  createdByActorId TEXT NOT NULL,
  activatedByActorId TEXT,
  createdAt DATETIME NOT NULL,
  activatedAt DATETIME,
  PRIMARY KEY(id, version),
  UNIQUE(id, version, contentHash),
  FOREIGN KEY(understandingId, understandingVersion, understandingHash)
    REFERENCES understanding_card_version(id, version, contentHash)
    ON DELETE RESTRICT,
  FOREIGN KEY(acceptancePolicyId, acceptancePolicyVersion)
    REFERENCES acceptance_policy_version(id, version) ON DELETE RESTRICT,
  CHECK (
    (acceptanceOwner = 'user'
      AND acceptancePolicyId IS NULL AND acceptancePolicyVersion IS NULL)
    OR
    (acceptanceOwner = 'policy'
      AND acceptancePolicyId IS NOT NULL AND acceptancePolicyVersion >= 1)
  ),
  CHECK (
    (status IN ('active','superseded','fulfilled')
      AND activatedByActorId IS NOT NULL AND activatedAt IS NOT NULL)
    OR
    (status IN ('draft','canceled')
      AND activatedByActorId IS NULL AND activatedAt IS NULL)
  )
);
CREATE INDEX outcome_contract_goal
  ON outcome_contract_version(goalId, status, version);

CREATE TABLE verification_requirement_group (
  contractId TEXT NOT NULL,
  contractVersion INTEGER NOT NULL,
  groupId TEXT NOT NULL,
  mode TEXT NOT NULL CHECK (mode IN ('all','any')),
  ordinal INTEGER NOT NULL CHECK (ordinal >= 0),
  PRIMARY KEY(contractId, contractVersion, groupId),
  UNIQUE(contractId, contractVersion, ordinal),
  FOREIGN KEY(contractId, contractVersion)
    REFERENCES outcome_contract_version(id, version) ON DELETE RESTRICT
);

CREATE TABLE verification_requirement (
  contractId TEXT NOT NULL,
  contractVersion INTEGER NOT NULL,
  groupId TEXT NOT NULL,
  requirementId TEXT NOT NULL,
  requirementVersion INTEGER NOT NULL CHECK (requirementVersion >= 1),
  ordinal INTEGER NOT NULL CHECK (ordinal >= 0),
  verifierType TEXT NOT NULL CHECK (verifierType IN ('cow','deterministic')),
  verifierId TEXT NOT NULL,
  method TEXT NOT NULL CHECK (method IN
    ('command','tests','build','artifactHash','externalReceipt','modelSupplement')),
  ruleId TEXT NOT NULL,
  ruleVersion INTEGER NOT NULL CHECK (ruleVersion >= 1),
  configJson TEXT NOT NULL,
  requirementHash TEXT NOT NULL CHECK (length(requirementHash) = 64),
  PRIMARY KEY(contractId, contractVersion, requirementId),
  UNIQUE(contractId, contractVersion, requirementId, requirementVersion),
  UNIQUE(contractId, contractVersion, groupId, ordinal),
  FOREIGN KEY(contractId, contractVersion, groupId)
    REFERENCES verification_requirement_group(contractId, contractVersion, groupId)
    ON DELETE RESTRICT
);
CREATE INDEX verification_requirement_group_order
  ON verification_requirement(contractId, contractVersion, groupId, ordinal);

CREATE TABLE outcome (
  id TEXT PRIMARY KEY NOT NULL,
  goalId TEXT NOT NULL REFERENCES goal_controller(id) ON DELETE RESTRICT,
  missionId TEXT NOT NULL REFERENCES mission(id) ON DELETE RESTRICT,
  contractId TEXT NOT NULL,
  contractVersion INTEGER NOT NULL,
  contractHash TEXT NOT NULL CHECK (length(contractHash) = 64),
  currentVersion INTEGER NOT NULL CHECK (currentVersion >= 1),
  state TEXT NOT NULL CHECK (state IN
    ('produced','verificationPending','verificationFailed','blocked','verified',
     'delivered','accepted','returned','revoked','invalidated')),
  aggregateVersion INTEGER NOT NULL DEFAULT 1 CHECK (aggregateVersion >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  FOREIGN KEY(contractId, contractVersion, contractHash)
    REFERENCES outcome_contract_version(id, version, contentHash)
    ON DELETE RESTRICT
);
CREATE INDEX outcome_goal ON outcome(goalId, state, updatedAt);
CREATE INDEX outcome_mission ON outcome(missionId, state, updatedAt);

CREATE TABLE outcome_version (
  outcomeId TEXT NOT NULL REFERENCES outcome(id) ON DELETE RESTRICT,
  version INTEGER NOT NULL CHECK (version >= 1),
  contractId TEXT NOT NULL,
  contractVersion INTEGER NOT NULL,
  contractHash TEXT NOT NULL CHECK (length(contractHash) = 64),
  producerActorId TEXT NOT NULL,
  runIdsJson TEXT NOT NULL,
  manifestJson TEXT NOT NULL,
  contentHash TEXT NOT NULL CHECK (length(contentHash) = 64),
  createdAt DATETIME NOT NULL,
  PRIMARY KEY(outcomeId, version),
  UNIQUE(outcomeId, version, contentHash),
  FOREIGN KEY(contractId, contractVersion, contractHash)
    REFERENCES outcome_contract_version(id, version, contentHash)
    ON DELETE RESTRICT
);

CREATE TABLE verification_record (
  id TEXT PRIMARY KEY NOT NULL,
  commandIdempotencyKey TEXT NOT NULL UNIQUE,
  contractId TEXT NOT NULL,
  contractVersion INTEGER NOT NULL,
  contractHash TEXT NOT NULL CHECK (length(contractHash) = 64),
  requirementId TEXT NOT NULL,
  requirementVersion INTEGER NOT NULL,
  requirementHash TEXT NOT NULL CHECK (length(requirementHash) = 64),
  outcomeId TEXT NOT NULL,
  outcomeVersion INTEGER NOT NULL,
  outcomeHash TEXT NOT NULL CHECK (length(outcomeHash) = 64),
  verifierType TEXT NOT NULL CHECK (verifierType IN ('cow','deterministic')),
  verifierId TEXT NOT NULL,
  method TEXT NOT NULL CHECK (method IN
    ('command','tests','build','artifactHash','externalReceipt','modelSupplement')),
  ruleId TEXT NOT NULL,
  ruleVersion INTEGER NOT NULL CHECK (ruleVersion >= 1),
  environmentJson TEXT NOT NULL,
  commandOrRuleJson TEXT NOT NULL,
  rawResultRef TEXT,
  evidenceHash TEXT NOT NULL CHECK (length(evidenceHash) = 64),
  result TEXT NOT NULL CHECK (result IN ('passed','failed','blocked','invalid')),
  supersedesVerificationId TEXT REFERENCES verification_record(id) ON DELETE RESTRICT,
  createdAt DATETIME NOT NULL,
  redactedAt DATETIME,
  FOREIGN KEY(contractId, contractVersion, contractHash)
    REFERENCES outcome_contract_version(id, version, contentHash)
    ON DELETE RESTRICT,
  FOREIGN KEY(contractId, contractVersion, requirementId, requirementVersion)
    REFERENCES verification_requirement(
      contractId, contractVersion, requirementId, requirementVersion)
    ON DELETE RESTRICT,
  FOREIGN KEY(outcomeId, outcomeVersion, outcomeHash)
    REFERENCES outcome_version(outcomeId, version, contentHash)
    ON DELETE RESTRICT,
  CHECK (
    redactedAt IS NULL
    OR
    (environmentJson = '{}' AND commandOrRuleJson = '{}'
      AND rawResultRef IS NULL)
  )
);
CREATE INDEX verification_record_requirement
  ON verification_record(
    outcomeId, outcomeVersion, requirementId, requirementVersion, createdAt);

CREATE TABLE verification_result_head (
  outcomeId TEXT NOT NULL,
  outcomeVersion INTEGER NOT NULL,
  contractId TEXT NOT NULL,
  contractVersion INTEGER NOT NULL,
  requirementId TEXT NOT NULL,
  requirementVersion INTEGER NOT NULL,
  currentVerificationId TEXT NOT NULL
    REFERENCES verification_record(id) ON DELETE RESTRICT,
  derivedResult TEXT NOT NULL CHECK
    (derivedResult IN ('passed','failed','blocked','invalid')),
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  updatedAt DATETIME NOT NULL,
  PRIMARY KEY(
    outcomeId, outcomeVersion, contractId, contractVersion,
    requirementId, requirementVersion),
  FOREIGN KEY(outcomeId, outcomeVersion)
    REFERENCES outcome_version(outcomeId, version) ON DELETE RESTRICT,
  FOREIGN KEY(contractId, contractVersion, requirementId, requirementVersion)
    REFERENCES verification_requirement(
      contractId, contractVersion, requirementId, requirementVersion)
    ON DELETE RESTRICT
);

CREATE TABLE verification_invalidation (
  id TEXT PRIMARY KEY NOT NULL,
  verificationId TEXT NOT NULL
    REFERENCES verification_record(id) ON DELETE RESTRICT,
  reasonCode TEXT NOT NULL,
  dependencyType TEXT NOT NULL,
  dependencyId TEXT NOT NULL,
  dependencyVersion INTEGER,
  dependencyHash TEXT CHECK
    (dependencyHash IS NULL OR length(dependencyHash) = 64),
  eventId TEXT NOT NULL REFERENCES domain_event(id) ON DELETE RESTRICT,
  createdAt DATETIME NOT NULL,
  UNIQUE(
    verificationId, reasonCode, dependencyType,
    dependencyId, dependencyVersion, dependencyHash)
);
CREATE INDEX verification_invalidation_record
  ON verification_invalidation(verificationId, createdAt);

CREATE TABLE acceptance_record (
  id TEXT PRIMARY KEY NOT NULL,
  commandIdempotencyKey TEXT NOT NULL UNIQUE,
  contractId TEXT NOT NULL,
  contractVersion INTEGER NOT NULL,
  contractHash TEXT NOT NULL CHECK (length(contractHash) = 64),
  outcomeId TEXT NOT NULL,
  outcomeVersion INTEGER NOT NULL,
  outcomeHash TEXT NOT NULL CHECK (length(outcomeHash) = 64),
  subjectType TEXT NOT NULL CHECK (subjectType IN ('user','policy')),
  subjectId TEXT NOT NULL,
  policyId TEXT,
  policyVersion INTEGER,
  decision TEXT NOT NULL CHECK (decision IN ('accepted','returned','revoked')),
  reason TEXT NOT NULL,
  supersedesAcceptanceId TEXT
    REFERENCES acceptance_record(id) ON DELETE RESTRICT,
  createdAt DATETIME NOT NULL,
  redactedAt DATETIME,
  FOREIGN KEY(contractId, contractVersion, contractHash)
    REFERENCES outcome_contract_version(id, version, contentHash)
    ON DELETE RESTRICT,
  FOREIGN KEY(outcomeId, outcomeVersion, outcomeHash)
    REFERENCES outcome_version(outcomeId, version, contentHash)
    ON DELETE RESTRICT,
  FOREIGN KEY(policyId, policyVersion)
    REFERENCES acceptance_policy_version(id, version) ON DELETE RESTRICT,
  CHECK (
    (subjectType = 'user' AND policyId IS NULL AND policyVersion IS NULL)
    OR
    (subjectType = 'policy' AND policyId IS NOT NULL AND policyVersion >= 1)
  ),
  CHECK (redactedAt IS NULL OR reason = '[deleted]')
);
CREATE INDEX acceptance_record_outcome
  ON acceptance_record(outcomeId, createdAt);

CREATE TABLE outcome_metric_credit (
  outcomeId TEXT PRIMARY KEY NOT NULL REFERENCES outcome(id) ON DELETE RESTRICT,
  state TEXT NOT NULL CHECK (state IN ('active','reversed')),
  creditedOutcomeVersion INTEGER NOT NULL CHECK (creditedOutcomeVersion >= 1),
  acceptanceId TEXT NOT NULL REFERENCES acceptance_record(id) ON DELETE RESTRICT,
  reversedByEventId TEXT REFERENCES domain_event(id) ON DELETE RESTRICT,
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  creditedAt DATETIME NOT NULL,
  reversedAt DATETIME
);

CREATE TABLE approval_grant (
  id TEXT PRIMARY KEY NOT NULL,
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  scopeVersion INTEGER NOT NULL DEFAULT 1 CHECK (scopeVersion = 1),
  grantorActorType TEXT NOT NULL CHECK
    (grantorActorType IN ('user','policy','system')),
  grantorActorId TEXT NOT NULL,
  grantorPolicyId TEXT,
  grantorPolicyVersion INTEGER CHECK
    (grantorPolicyVersion IS NULL OR grantorPolicyVersion >= 1),
  grantorPolicyHash TEXT CHECK
    (grantorPolicyHash IS NULL OR length(grantorPolicyHash) = 64),
  granteeType TEXT NOT NULL CHECK (granteeType IN ('cow','engine','system')),
  granteeId TEXT NOT NULL,
  capability TEXT NOT NULL,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  cardId TEXT NOT NULL REFERENCES card(id) ON DELETE RESTRICT,
  toolId TEXT NOT NULL,
  approvedInputHash TEXT NOT NULL CHECK (length(approvedInputHash) = 64),
  purpose TEXT NOT NULL,
  dataLevel TEXT NOT NULL CHECK
    (dataLevel IN ('local','workspace','external','sensitive')),
  adapterReplayClass TEXT NOT NULL CHECK (adapterReplayClass IN
    ('replaySafe','idempotencyKeyed','nonReplayable')),
  validFrom DATETIME NOT NULL,
  validUntil DATETIME NOT NULL,
  maxUses INTEGER NOT NULL CHECK (maxUses >= 1),
  usedCount INTEGER NOT NULL DEFAULT 0 CHECK
    (usedCount >= 0 AND usedCount <= maxUses),
  status TEXT NOT NULL CHECK
    (status IN ('active','exhausted','revoked','expired')),
  revokedAt DATETIME,
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  redactedAt DATETIME,
  CHECK (validUntil > validFrom),
  CHECK (
    redactedAt IS NOT NULL
    OR
    (grantorActorType = 'policy'
      AND grantorPolicyId IS NOT NULL
      AND grantorPolicyVersion IS NOT NULL
      AND grantorPolicyHash IS NOT NULL)
    OR
    (grantorActorType IN ('user','system')
      AND grantorPolicyId IS NULL
      AND grantorPolicyVersion IS NULL
      AND grantorPolicyHash IS NULL)
  ),
  CHECK (
    redactedAt IS NULL
    OR
    (grantorActorId = '[deleted]'
      AND grantorPolicyId IS NULL
      AND grantorPolicyVersion IS NULL
      AND grantorPolicyHash IS NULL
      AND purpose = '[deleted]')
  ),
  CHECK (
    adapterReplayClass <> 'nonReplayable'
    OR
    (grantorActorType = 'user' AND maxUses = 1)
  )
);
CREATE INDEX approval_grant_match
  ON approval_grant(campId, cardId, toolId, approvedInputHash, status, validUntil);

CREATE TABLE approval_grant_use (
  id TEXT PRIMARY KEY NOT NULL,
  grantId TEXT NOT NULL REFERENCES approval_grant(id) ON DELETE RESTRICT,
  idempotencyKey TEXT NOT NULL UNIQUE,
  toolId TEXT NOT NULL,
  inputHash TEXT NOT NULL CHECK (length(inputHash) = 64),
  adapterId TEXT NOT NULL,
  adapterReplayClass TEXT NOT NULL CHECK (adapterReplayClass IN
    ('replaySafe','idempotencyKeyed','nonReplayable')),
  state TEXT NOT NULL CHECK (state IN
    ('reserved','dispatching','accepted','succeeded','failedFinal',
     'released','crashUnknown','abandonedUnknown')),
  adapterOperationId TEXT,
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  reservedAt DATETIME NOT NULL,
  dispatchIntentAt DATETIME,
  adapterAcceptedAt DATETIME,
  finishedAt DATETIME,
  CHECK (
    (state = 'reserved'
      AND dispatchIntentAt IS NULL AND adapterAcceptedAt IS NULL
      AND finishedAt IS NULL)
    OR
    (state = 'dispatching'
      AND dispatchIntentAt IS NOT NULL AND adapterAcceptedAt IS NULL
      AND finishedAt IS NULL)
    OR
    (state = 'accepted'
      AND dispatchIntentAt IS NOT NULL AND adapterAcceptedAt IS NOT NULL
      AND finishedAt IS NULL)
    OR
    (state = 'crashUnknown'
      AND dispatchIntentAt IS NOT NULL AND finishedAt IS NULL)
    OR
    (state IN ('succeeded','failedFinal','abandonedUnknown')
      AND dispatchIntentAt IS NOT NULL AND finishedAt IS NOT NULL)
    OR
    (state = 'released' AND finishedAt IS NOT NULL)
  )
);
CREATE INDEX approval_grant_use_recovery
  ON approval_grant_use(state, adapterReplayClass, dispatchIntentAt);

CREATE TABLE external_operation_receipt (
  id TEXT PRIMARY KEY NOT NULL,
  grantUseId TEXT NOT NULL REFERENCES approval_grant_use(id) ON DELETE RESTRICT,
  receiptIdempotencyKey TEXT NOT NULL UNIQUE,
  ordinal INTEGER NOT NULL CHECK (ordinal >= 0),
  phase TEXT NOT NULL CHECK (phase IN
    ('dispatchIntent','adapterAccepted','effectConfirmed','noEffectConfirmed',
     'reconciliationFailed','userResolved')),
  result TEXT NOT NULL CHECK (result IN
    ('pending','succeeded','failedFinal','noEffect','unknown',
     'abandonedUnknown')),
  adapterOperationId TEXT,
  receiptRef TEXT,
  receiptJson TEXT NOT NULL,
  receiptHash TEXT NOT NULL CHECK (
    length(receiptHash) = 64 AND receiptHash NOT GLOB '*[^0-9a-f]*'
  ),
  authorityKind TEXT NOT NULL CHECK
    (authorityKind IN ('system','adapter','user')),
  authorityId TEXT NOT NULL,
  createdAt DATETIME NOT NULL,
  redactedAt DATETIME,
  UNIQUE(grantUseId, ordinal),
  CHECK (
    (phase = 'dispatchIntent'
      AND result = 'pending' AND authorityKind = 'system')
    OR
    (phase = 'adapterAccepted'
      AND result = 'pending' AND authorityKind = 'adapter')
    OR
    (phase = 'effectConfirmed'
      AND result IN ('succeeded','failedFinal')
      AND authorityKind = 'adapter')
    OR
    (phase = 'noEffectConfirmed'
      AND result = 'noEffect' AND authorityKind = 'adapter')
    OR
    (phase = 'reconciliationFailed'
      AND result = 'unknown' AND authorityKind = 'adapter')
    OR
    (phase = 'userResolved'
      AND result IN ('succeeded','abandonedUnknown')
      AND authorityKind = 'user')
  ),
  CHECK (
    redactedAt IS NULL
    OR
    (adapterOperationId IS NULL AND receiptRef IS NULL
      AND receiptJson = '{"redacted":"camp_deleted"}'
      AND authorityId = '[deleted]')
  )
);
CREATE INDEX external_operation_receipt_use
  ON external_operation_receipt(grantUseId, ordinal);
CREATE UNIQUE INDEX external_operation_one_dispatch_intent
  ON external_operation_receipt(grantUseId)
  WHERE phase = 'dispatchIntent';
CREATE UNIQUE INDEX external_operation_one_adapter_acceptance
  ON external_operation_receipt(grantUseId)
  WHERE phase = 'adapterAccepted';
CREATE UNIQUE INDEX external_operation_one_terminal_resolution
  ON external_operation_receipt(grantUseId)
  WHERE phase IN ('effectConfirmed','noEffectConfirmed','userResolved');

CREATE TRIGGER verification_record_reject_update
BEFORE UPDATE ON verification_record
BEGIN
  SELECT RAISE(ABORT, 'verification_record is append-only');
END;
CREATE TRIGGER verification_record_reject_delete
BEFORE DELETE ON verification_record
BEGIN
  SELECT RAISE(ABORT, 'verification_record is append-only');
END;
CREATE TRIGGER verification_invalidation_reject_update
BEFORE UPDATE ON verification_invalidation
BEGIN
  SELECT RAISE(ABORT, 'verification_invalidation is append-only');
END;
CREATE TRIGGER verification_invalidation_reject_delete
BEFORE DELETE ON verification_invalidation
BEGIN
  SELECT RAISE(ABORT, 'verification_invalidation is append-only');
END;
CREATE TRIGGER acceptance_record_reject_update
BEFORE UPDATE ON acceptance_record
BEGIN
  SELECT RAISE(ABORT, 'acceptance_record is append-only');
END;
CREATE TRIGGER acceptance_record_reject_delete
BEFORE DELETE ON acceptance_record
BEGIN
  SELECT RAISE(ABORT, 'acceptance_record is append-only');
END;
CREATE TRIGGER external_operation_receipt_reject_update
BEFORE UPDATE ON external_operation_receipt
BEGIN
  SELECT RAISE(ABORT, 'external_operation_receipt is append-only');
END;
CREATE TRIGGER external_operation_receipt_reject_delete
BEFORE DELETE ON external_operation_receipt
BEGIN
  SELECT RAISE(ABORT, 'external_operation_receipt is append-only');
END;
```

Store 额外约束：`approval_grant_use.toolId/inputHash/adapterReplayClass` 必须与 Grant
完全一致；Grant `campId` 必须等于 Card→Mission 的 Camp，且 reserve 时 Camp 必须
writable。Store 不信自由文本 actor：`grantorActorType` 来自 typed command actor；
policy grant 必须携带 immutable ApprovalPolicy exact ID/version/hash 并由
ApprovalPolicy registry 验证，user/system 不得伪带 policy ref。nonReplayable
Grant 必须 `maxUses=1` 且由 user actor 创建；SQL CHECK 也独立强制。
`receiptJson` 必须是 §5.1 canonical object，包含 exact use/key/ordinal/phase/result/
authority 与 typed evidence的**hash/ref摘要**，不得复制外部正文；Store 在任何
SQL 前自算 receiptHash。同 key 同 whole
hash 返回原 receipt，异 hash conflict；每个新 receipt 的 ordinal 必须等于当前
`MAX(ordinal)+1`，`reconciliationFailed` 可按新 key/ordinal 重复追加，其余受 partial
unique index 限制一次。只有 typed `AdapterNoEffectAttestation` 可写
`noEffectConfirmed` 并执行唯一 refund；user-resolution 与它用 use version CAS
竞争；refund 同时 CAS Grant version，并按 §13 reducer 保留 revoked/expired。
SQL CHECK
无法跨行表达的 group 非空、verifier/producer 独立、policy 风险排序、head
supersede chain 与 usedCount 变更，都由 transaction store 强校验并有 contract test。
Camp deletion 只把 mutable/raw `adapterOperationId/receiptRef` 置空并把
receiptJson 换成 redaction marker；receiptHash 作为 pre-redaction evidence 留存，
该 deletion exception 后不再用 JSON byte-equality验证旧 hash。

### 18.6 `v16-p1-identity-memory`

```sql
CREATE TABLE camp_lifecycle (
  campId TEXT PRIMARY KEY NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  state TEXT NOT NULL CHECK (state IN
    ('active','archived','deletionRequested','deleting','deletedTombstone')),
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  deletionRequestedAt DATETIME,
  deletedAt DATETIME,
  CHECK (
    (state IN ('active','archived')
      AND deletionRequestedAt IS NULL AND deletedAt IS NULL)
    OR
    (state IN ('deletionRequested','deleting')
      AND deletionRequestedAt IS NOT NULL AND deletedAt IS NULL)
    OR
    (state = 'deletedTombstone'
      AND deletionRequestedAt IS NOT NULL AND deletedAt IS NOT NULL)
  )
);
CREATE INDEX camp_lifecycle_state
  ON camp_lifecycle(state, updatedAt);

INSERT INTO camp_lifecycle(
  campId, state, version, createdAt, updatedAt,
  deletionRequestedAt, deletedAt
)
SELECT id,
       CASE WHEN archived = 1 THEN 'archived' ELSE 'active' END,
       1, createdAt, createdAt, NULL, NULL
FROM camp;

-- user_request answerJson NULL no longer means "open": deletion withdrawal and
-- redaction both clear it, so v16 installs an explicit lifecycle discriminator.
ALTER TABLE user_request ADD COLUMN lifecycleState TEXT NOT NULL DEFAULT 'open'
  CHECK (lifecycleState IN ('open','answered','withdrawn','redacted'));
ALTER TABLE user_request ADD COLUMN terminalReason TEXT;
ALTER TABLE user_request ADD COLUMN redactedAt DATETIME;
UPDATE user_request
SET lifecycleState = CASE
  WHEN answerJson IS NULL THEN 'open' ELSE 'answered'
END;
ALTER TABLE approval_grant_use ADD COLUMN redactedAt DATETIME;

ALTER TABLE ingestion_item ADD COLUMN version INTEGER NOT NULL DEFAULT 1
  CHECK (version >= 1);
ALTER TABLE ingestion_item ADD COLUMN terminalReason TEXT
  CHECK (
    terminalReason IS NULL
    OR (status = 'discarded' AND terminalReason = 'camp_deleted')
  );
ALTER TABLE ingestion_item ADD COLUMN redactedAt DATETIME
  CHECK (
    redactedAt IS NULL
    OR
    (rawText = '[deleted]' AND title IS NULL AND sourceURL IS NULL
      AND author IS NULL AND userIntent IS NULL AND errorText IS NULL)
  );

ALTER TABLE rumination_result ADD COLUMN version INTEGER NOT NULL DEFAULT 1
  CHECK (version >= 1);
ALTER TABLE rumination_result ADD COLUMN redactedAt DATETIME
  CHECK (
    redactedAt IS NULL
    OR (resultJson = '{}' AND userEditedJson IS NULL)
  );

ALTER TABLE action_candidate ADD COLUMN version INTEGER NOT NULL DEFAULT 1
  CHECK (version >= 1);
ALTER TABLE action_candidate ADD COLUMN terminalReason TEXT
  CHECK (
    terminalReason IS NULL
    OR (status = 'dismissed' AND terminalReason = 'camp_deleted')
  );
ALTER TABLE action_candidate ADD COLUMN redactedAt DATETIME
  CHECK (
    redactedAt IS NULL
    OR (title = '[deleted]' AND detailJson = '{}')
  );

-- Locator bytes are private Camp data too.  A dedicated discriminator makes
-- their one-shot finalizing redaction and subsequent immutability expressible.
ALTER TABLE knowledge_source_link ADD COLUMN version INTEGER NOT NULL DEFAULT 1
  CHECK (version >= 1);
ALTER TABLE knowledge_source_link ADD COLUMN redactedAt DATETIME
  CHECK (redactedAt IS NULL OR locatorJson IS NULL);

-- campDeletion has been sealed since v12; F2 has not run yet.
CREATE TEMP TABLE v16_assert_no_early_camp_deletion (
  count INTEGER NOT NULL CHECK (count = 0)
);
INSERT INTO v16_assert_no_early_camp_deletion(count)
SELECT COUNT(*) FROM durable_work WHERE kind = 'campDeletion';
DROP TABLE v16_assert_no_early_camp_deletion;

-- Deterministically close every archived Camp's pre-v16 active work before
-- binding all rows to lifecycle version 1.
INSERT INTO durable_work_attempt_event(
  id, workId, attempt, sequence, eventKind, workerId, workVersion,
  resultingWorkState, errorCode, errorMessage, occurredAt
)
SELECT 'v16-archive-cancel:' || a.workId || ':' || a.attempt,
       a.workId, a.attempt,
       COALESCE((
         SELECT MAX(e.sequence) + 1
         FROM durable_work_attempt_event e
         WHERE e.workId = a.workId AND e.attempt = a.attempt
       ), 1),
       'canceled', a.workerId, w.version + 1, 'canceled',
       'work_canceled', 'camp_archived_backfill', CURRENT_TIMESTAMP
FROM durable_work_attempt a
JOIN durable_work w ON w.id = a.workId
JOIN camp c ON c.id = w.campId
WHERE c.archived = 1 AND w.state = 'running' AND a.endedAt IS NULL;

UPDATE durable_work_attempt
SET endedAt = CURRENT_TIMESTAMP,
    outcome = 'canceled',
    errorCode = 'work_canceled',
    errorMessage = 'camp_archived_backfill',
    terminalWorkVersion = (
      SELECT w.version + 1 FROM durable_work w
      WHERE w.id = durable_work_attempt.workId
    )
WHERE endedAt IS NULL
  AND workId IN (
    SELECT w.id FROM durable_work w
    JOIN camp c ON c.id = w.campId
    WHERE c.archived = 1 AND w.state = 'running'
  );

UPDATE durable_work
SET state = 'canceled',
    notBefore = NULL,
    leaseOwner = NULL,
    leaseExpiresAt = NULL,
    outputJson = NULL,
    errorCode = 'work_canceled',
    errorMessage = 'camp_archived_backfill',
    version = version + 1,
    updatedAt = CURRENT_TIMESTAMP,
    finishedAt = CURRENT_TIMESTAMP
WHERE campId IN (SELECT id FROM camp WHERE archived = 1)
  AND state IN ('queued','running','retryScheduled');

CREATE TABLE durable_work_v16 (
  id TEXT PRIMARY KEY NOT NULL,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  campLifecycleVersion INTEGER NOT NULL CHECK (campLifecycleVersion >= 1),
  kind TEXT NOT NULL CHECK (kind IN
    ('planning','rumination','coach','guideChat','memoryPromotion','inputParsing',
     'campDeletion')),
  aggregateType TEXT NOT NULL,
  aggregateId TEXT NOT NULL,
  idempotencyKey TEXT NOT NULL,
  state TEXT NOT NULL CHECK (state IN
    ('queued','running','retryScheduled','succeeded','failed','canceled')),
  attempt INTEGER NOT NULL DEFAULT 0 CHECK (attempt >= 0),
  maxAttempts INTEGER NOT NULL DEFAULT 4 CHECK (maxAttempts >= 1),
  notBefore DATETIME,
  leaseOwner TEXT,
  leaseExpiresAt DATETIME,
  inputJson TEXT NOT NULL,
  inputHash TEXT NOT NULL CHECK (
    length(inputHash) = 64 AND inputHash NOT GLOB '*[^0-9a-f]*'
  ),
  outputJson TEXT,
  errorCode TEXT,
  errorMessage TEXT CHECK (
    errorMessage IS NULL OR length(errorMessage) BETWEEN 1 AND 1000
  ),
  traceId TEXT NOT NULL,
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  finishedAt DATETIME,
  UNIQUE(kind, idempotencyKey),
  CHECK (
    (state = 'running' AND leaseOwner IS NOT NULL AND leaseExpiresAt IS NOT NULL)
    OR
    (state <> 'running' AND leaseOwner IS NULL AND leaseExpiresAt IS NULL)
  ),
  CHECK (
    (state = 'retryScheduled' AND notBefore IS NOT NULL)
    OR
    (state <> 'retryScheduled' AND notBefore IS NULL)
  ),
  CHECK (
    (state IN ('succeeded','failed','canceled') AND finishedAt IS NOT NULL)
    OR
    (state IN ('queued','running','retryScheduled') AND finishedAt IS NULL)
  ),
  CHECK (outputJson IS NULL OR state = 'succeeded'),
  CHECK (
    errorCode IS NULL OR (
      length(errorCode) BETWEEN 1 AND 64
      AND substr(errorCode, 1, 1) GLOB '[a-z]'
      AND errorCode NOT GLOB '*[^a-z0-9_]*'
    )
  ),
  CHECK (COALESCE((
    (state = 'queued' AND outputJson IS NULL
      AND ((errorCode IS NULL AND errorMessage IS NULL)
        OR (errorCode = 'worker_interrupted' AND errorMessage IS NULL)))
    OR
    (state IN ('running','succeeded')
      AND errorCode IS NULL AND errorMessage IS NULL)
    OR
    (state IN ('retryScheduled','failed') AND errorCode IS NOT NULL
      AND outputJson IS NULL)
    OR
    (state = 'canceled' AND errorCode = 'work_canceled'
      AND errorMessage IS NOT NULL AND outputJson IS NULL)
  ), 0))
);
INSERT INTO durable_work_v16(
  id, campId, campLifecycleVersion, kind, aggregateType, aggregateId,
  idempotencyKey, state, attempt, maxAttempts, notBefore, leaseOwner,
  leaseExpiresAt, inputJson, inputHash, outputJson, errorCode, errorMessage,
  traceId, version, createdAt, updatedAt, finishedAt
)
SELECT id, campId, 1, kind, aggregateType, aggregateId, idempotencyKey, state,
       attempt, maxAttempts, notBefore, leaseOwner, leaseExpiresAt, inputJson,
       inputHash, outputJson, errorCode, errorMessage, traceId, version,
       createdAt, updatedAt, finishedAt
FROM durable_work;

-- Child rows are staged without foreign keys.  The final-named child tables are
-- created only after the parent has its final name; this is deliberate and is
-- required to make the migration independent of legacy_alter_table behavior.
CREATE TEMP TABLE p1_durable_work_attempt_stage AS
SELECT workId, attempt, id, workerId, startedAt, endedAt, outcome, errorCode,
       errorMessage, traceId, terminalWorkVersion
FROM durable_work_attempt;

CREATE TEMP TABLE p1_durable_work_attempt_event_stage AS
SELECT id, workId, attempt, sequence, eventKind,
       NULL AS providerDispatchId, workerId, workVersion, resultingWorkState,
       errorCode, errorMessage, occurredAt, NULL AS redactedAt
FROM durable_work_attempt_event;

-- v12 guarantees this guard exists.  Drop it explicitly and fail fast before
-- rebuilding the owning table; the v12 DELETE guard is not explicitly dropped.
-- SQLite removes that DELETE trigger with the old table, and the final trigger
-- phase below recreates it under the same name before this transaction commits.
DROP TRIGGER durable_work_attempt_event_reject_update;
DROP TABLE durable_work_attempt_event;
DROP TABLE durable_work_attempt;
DROP TABLE durable_work;
ALTER TABLE durable_work_v16 RENAME TO durable_work;

CREATE TABLE durable_work_attempt (
  workId TEXT NOT NULL REFERENCES durable_work(id) ON DELETE RESTRICT,
  attempt INTEGER NOT NULL CHECK (attempt >= 1),
  id TEXT NOT NULL UNIQUE,
  workerId TEXT NOT NULL,
  startedAt DATETIME NOT NULL,
  endedAt DATETIME,
  outcome TEXT CHECK (outcome IS NULL OR outcome IN
    ('succeeded','failed','canceled','interrupted')),
  errorCode TEXT,
  errorMessage TEXT CHECK (
    errorMessage IS NULL OR length(errorMessage) BETWEEN 1 AND 1000
  ),
  traceId TEXT NOT NULL,
  terminalWorkVersion INTEGER CHECK
    (terminalWorkVersion IS NULL OR terminalWorkVersion >= 1),
  PRIMARY KEY(workId, attempt),
  CHECK (
    (endedAt IS NULL AND outcome IS NULL AND terminalWorkVersion IS NULL)
    OR
    (endedAt IS NOT NULL AND outcome IS NOT NULL AND terminalWorkVersion IS NOT NULL)
  ),
  CHECK (
    errorCode IS NULL OR (
      length(errorCode) BETWEEN 1 AND 64
      AND substr(errorCode, 1, 1) GLOB '[a-z]'
      AND errorCode NOT GLOB '*[^a-z0-9_]*'
    )
  ),
  CHECK (COALESCE((
    (endedAt IS NULL AND errorCode IS NULL AND errorMessage IS NULL)
    OR (outcome = 'succeeded' AND errorCode IS NULL AND errorMessage IS NULL)
    OR (outcome = 'failed' AND errorCode IS NOT NULL)
    OR (outcome = 'canceled' AND errorCode = 'work_canceled'
      AND errorMessage IS NOT NULL)
    OR (outcome = 'interrupted' AND errorCode = 'worker_interrupted'
      AND errorMessage IS NULL)
  ), 0))
);
INSERT INTO durable_work_attempt
SELECT * FROM p1_durable_work_attempt_stage;

CREATE TABLE camp_provider_dispatch (
  id TEXT PRIMARY KEY NOT NULL,
  workId TEXT NOT NULL,
  workAttempt INTEGER NOT NULL,
  turnOrdinal INTEGER NOT NULL CHECK (turnOrdinal >= 0),
  dispatchAttempt INTEGER NOT NULL CHECK (dispatchAttempt >= 1),
  replayOfDispatchId TEXT REFERENCES camp_provider_dispatch(id) ON DELETE RESTRICT,
  idempotencyKey TEXT NOT NULL UNIQUE,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  campLifecycleVersion INTEGER NOT NULL CHECK (campLifecycleVersion >= 1),
  operationKind TEXT NOT NULL CHECK
    (operationKind IN ('guideChat','memoryPromotion')),
  replayClass TEXT NOT NULL CHECK
    (replayClass IN ('replaySafeInference','idempotencyKeyed','nonReplayable')),
  state TEXT NOT NULL CHECK
    (state IN ('prepared','started','returned','consumed','abandoned')),
  requestJson TEXT NOT NULL,
  requestHash TEXT NOT NULL CHECK (
    length(requestHash) = 64 AND requestHash NOT GLOB '*[^0-9a-f]*'
  ),
  responseJson TEXT,
  responseHash TEXT CHECK (
    responseHash IS NULL OR
    (length(responseHash) = 64 AND responseHash NOT GLOB '*[^0-9a-f]*')
  ),
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  preparedAt DATETIME NOT NULL,
  startedAt DATETIME,
  returnedAt DATETIME,
  consumedAt DATETIME,
  abandonedAt DATETIME,
  redactedAt DATETIME,
  FOREIGN KEY(workId, workAttempt)
    REFERENCES durable_work_attempt(workId, attempt) ON DELETE RESTRICT,
  UNIQUE(workId, turnOrdinal, dispatchAttempt),
  CHECK (
    (dispatchAttempt = 1 AND replayOfDispatchId IS NULL)
    OR
    (dispatchAttempt > 1 AND replayOfDispatchId IS NOT NULL)
  ),
  CHECK (
    (state = 'prepared'
      AND startedAt IS NULL AND returnedAt IS NULL
      AND consumedAt IS NULL AND abandonedAt IS NULL
      AND responseJson IS NULL AND responseHash IS NULL)
    OR
    (state = 'started'
      AND startedAt IS NOT NULL AND returnedAt IS NULL
      AND consumedAt IS NULL AND abandonedAt IS NULL
      AND responseJson IS NULL AND responseHash IS NULL)
    OR
    (state = 'returned'
      AND startedAt IS NOT NULL AND returnedAt IS NOT NULL
      AND consumedAt IS NULL AND abandonedAt IS NULL
      AND responseJson IS NOT NULL AND responseHash IS NOT NULL)
    OR
    (state = 'consumed'
      AND startedAt IS NOT NULL AND returnedAt IS NOT NULL
      AND consumedAt IS NOT NULL AND abandonedAt IS NULL
      AND (
        (redactedAt IS NULL AND responseJson IS NOT NULL AND responseHash IS NOT NULL)
        OR
        (redactedAt IS NOT NULL AND responseJson IS NULL AND responseHash IS NULL)
      ))
    OR
    (state = 'abandoned'
      AND consumedAt IS NULL AND abandonedAt IS NOT NULL
      AND (returnedAt IS NULL OR startedAt IS NOT NULL)
      AND (
        (redactedAt IS NULL
          AND ((returnedAt IS NULL AND responseJson IS NULL AND responseHash IS NULL)
            OR (returnedAt IS NOT NULL
              AND responseJson IS NOT NULL AND responseHash IS NOT NULL)))
        OR
        (redactedAt IS NOT NULL AND responseJson IS NULL AND responseHash IS NULL)
      ))
  ),
  CHECK (
    redactedAt IS NULL
    OR
    (state IN ('consumed','abandoned')
      AND requestJson = '{}' AND responseJson IS NULL AND responseHash IS NULL)
  )
);
CREATE UNIQUE INDEX camp_provider_dispatch_one_returned
  ON camp_provider_dispatch(workId, turnOrdinal)
  WHERE state IN ('returned','consumed');
CREATE INDEX camp_provider_dispatch_quiescence
  ON camp_provider_dispatch(campId, state, preparedAt);
CREATE TABLE durable_work_attempt_event (
  id TEXT PRIMARY KEY NOT NULL,
  workId TEXT NOT NULL,
  attempt INTEGER NOT NULL,
  sequence INTEGER NOT NULL CHECK (sequence >= 0),
  eventKind TEXT NOT NULL CHECK (eventKind IN
    ('claimed','leaseRenewed','providerDispatchStarted',
     'providerResponseReturned','succeeded','failed','canceled','interrupted')),
  providerDispatchId TEXT
    REFERENCES camp_provider_dispatch(id) ON DELETE RESTRICT,
  workerId TEXT NOT NULL,
  workVersion INTEGER NOT NULL CHECK (workVersion >= 1),
  resultingWorkState TEXT NOT NULL CHECK (resultingWorkState IN
    ('running','retryScheduled','succeeded','failed','canceled','queued')),
  errorCode TEXT,
  errorMessage TEXT CHECK (
    errorMessage IS NULL OR length(errorMessage) BETWEEN 1 AND 1000
  ),
  occurredAt DATETIME NOT NULL,
  redactedAt DATETIME,
  FOREIGN KEY(workId, attempt)
    REFERENCES durable_work_attempt(workId, attempt) ON DELETE RESTRICT,
  UNIQUE(workId, attempt, sequence),
  UNIQUE(providerDispatchId, eventKind),
  CHECK ((sequence = 0) = (eventKind = 'claimed')),
  CHECK (
    (eventKind IN ('providerDispatchStarted','providerResponseReturned')
      AND providerDispatchId IS NOT NULL)
    OR
    (eventKind NOT IN ('providerDispatchStarted','providerResponseReturned')
      AND providerDispatchId IS NULL)
  ),
  CHECK (
    errorCode IS NULL OR (
      length(errorCode) BETWEEN 1 AND 64
      AND substr(errorCode, 1, 1) GLOB '[a-z]'
      AND errorCode NOT GLOB '*[^a-z0-9_]*'
    )
  ),
  CHECK (COALESCE((
    (eventKind IN ('claimed','leaseRenewed','providerDispatchStarted',
      'providerResponseReturned')
      AND resultingWorkState = 'running'
      AND errorCode IS NULL AND errorMessage IS NULL)
    OR
    (eventKind = 'succeeded' AND resultingWorkState = 'succeeded'
      AND errorCode IS NULL AND errorMessage IS NULL)
    OR
    (eventKind = 'failed'
      AND resultingWorkState IN ('retryScheduled','failed')
      AND errorCode IS NOT NULL)
    OR
    (eventKind = 'canceled' AND resultingWorkState = 'canceled'
      AND errorCode = 'work_canceled' AND errorMessage IS NOT NULL)
    OR
    (eventKind = 'interrupted' AND resultingWorkState = 'queued'
      AND errorCode = 'worker_interrupted' AND errorMessage IS NULL)
  ), 0)),
  CHECK (redactedAt IS NULL OR errorMessage IS NULL)
);
INSERT INTO durable_work_attempt_event(
  id, workId, attempt, sequence, eventKind, providerDispatchId, workerId,
  workVersion, resultingWorkState, errorCode, errorMessage, occurredAt, redactedAt
)
SELECT id, workId, attempt, sequence, eventKind, providerDispatchId, workerId,
       workVersion, resultingWorkState, errorCode, errorMessage, occurredAt,
       redactedAt
FROM p1_durable_work_attempt_event_stage;

DROP TABLE p1_durable_work_attempt_event_stage;
DROP TABLE p1_durable_work_attempt_stage;

CREATE UNIQUE INDEX durable_work_one_active_aggregate
  ON durable_work(kind, aggregateType, aggregateId)
  WHERE state IN ('queued','running','retryScheduled');
CREATE INDEX durable_work_claimable
  ON durable_work(campId, kind, state, notBefore, createdAt);
CREATE INDEX durable_work_aggregate_history
  ON durable_work(aggregateType, aggregateId, createdAt);
CREATE UNIQUE INDEX durable_work_attempt_one_terminal
  ON durable_work_attempt_event(workId, attempt)
  WHERE eventKind IN ('succeeded','failed','canceled','interrupted');
CREATE INDEX durable_work_attempt_event_work
  ON durable_work_attempt_event(workId, attempt, sequence);

CREATE TABLE camp_deletion_job (
  id TEXT PRIMARY KEY NOT NULL,
  campId TEXT NOT NULL UNIQUE REFERENCES camp(id) ON DELETE RESTRICT,
  workId TEXT NOT NULL UNIQUE REFERENCES durable_work(id) ON DELETE RESTRICT,
  requestIdempotencyKey TEXT NOT NULL UNIQUE,
  confirmationId TEXT NOT NULL UNIQUE,
  confirmationHash TEXT NOT NULL CHECK (
    length(confirmationHash) = 64
    AND confirmationHash NOT GLOB '*[^0-9a-f]*'
  ),
  unknownArtifactDisposition TEXT NOT NULL CHECK
    (unknownArtifactDisposition = 'detachOnlyNeverUnlink'),
  requestedByActorId TEXT NOT NULL,
  state TEXT NOT NULL CHECK
    (state IN ('requested','quiescing','erasing','finalizing','completed')),
  phaseCursorJson TEXT NOT NULL,
  lastErrorCode TEXT,
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  completedAt DATETIME,
  CHECK (
    (state = 'completed' AND completedAt IS NOT NULL)
    OR
    (state <> 'completed' AND completedAt IS NULL)
  )
);
CREATE INDEX camp_deletion_job_recovery
  ON camp_deletion_job(state, updatedAt);
CREATE TABLE camp_deletion_artifact (
  id TEXT PRIMARY KEY NOT NULL,
  jobId TEXT NOT NULL REFERENCES camp_deletion_job(id) ON DELETE RESTRICT,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  artifactId TEXT NOT NULL REFERENCES artifact(id) ON DELETE RESTRICT,
  originVersion INTEGER NOT NULL CHECK (originVersion >= 1),
  resolutionClass TEXT NOT NULL CHECK (resolutionClass IN
    ('unresolved','managedExclusive','managedShared','workspaceExternal')),
  evidenceKind TEXT CHECK (evidenceKind IS NULL OR evidenceKind IN
    ('typedPreparedArtifact','verifiedManagedRootCapability',
     'explicitWorkspaceExternal','verifiedOutsideAllManagedRoots',
     'legacyUnknown','userConfirmedUnknownDetach')),
  managedRootId TEXT,
  objectId TEXT,
  contentHash TEXT CHECK (
    contentHash IS NULL OR
    (length(contentHash) = 64 AND contentHash NOT GLOB '*[^0-9a-f]*')
  ),
  fileIdentityHash TEXT CHECK (
    fileIdentityHash IS NULL OR
    (length(fileIdentityHash) = 64
      AND fileIdentityHash NOT GLOB '*[^0-9a-f]*')
  ),
  originalRefHash TEXT NOT NULL CHECK (
    length(originalRefHash) = 64
    AND originalRefHash NOT GLOB '*[^0-9a-f]*'
  ),
  evidenceHash TEXT CHECK (
    evidenceHash IS NULL OR
    (length(evidenceHash) = 64 AND evidenceHash NOT GLOB '*[^0-9a-f]*')
  ),
  referenceSetHash TEXT CHECK (
    referenceSetHash IS NULL OR
    (length(referenceSetHash) = 64
      AND referenceSetHash NOT GLOB '*[^0-9a-f]*')
  ),
  authorityHash TEXT CHECK (
    authorityHash IS NULL OR
    (length(authorityHash) = 64 AND authorityHash NOT GLOB '*[^0-9a-f]*')
  ),
  state TEXT NOT NULL CHECK
    (state IN ('pendingInspection','awaitingResolution','detachAuthorized',
      'unlinkPrepared','retryableFailure','detached','retainedShared',
      'deleted','alreadyAbsent')),
  attempt INTEGER NOT NULL DEFAULT 0 CHECK (attempt >= 0),
  lastErrorCode TEXT,
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  finishedAt DATETIME,
  UNIQUE(jobId, artifactId),
  CHECK (
    (resolutionClass IN ('workspaceExternal','unresolved')
      AND managedRootId IS NULL AND objectId IS NULL
      AND contentHash IS NULL AND fileIdentityHash IS NULL)
    OR
    (resolutionClass IN ('managedExclusive','managedShared')
      AND contentHash IS NOT NULL AND fileIdentityHash IS NOT NULL)
  ),
  CHECK (
    (state IN ('unlinkPrepared','retryableFailure')
      AND resolutionClass = 'managedExclusive'
      AND managedRootId IS NOT NULL AND objectId IS NOT NULL
      AND authorityHash IS NOT NULL AND finishedAt IS NULL)
    OR
    (state = 'detachAuthorized'
      AND resolutionClass IN ('workspaceExternal','unresolved')
      AND authorityHash IS NOT NULL AND finishedAt IS NULL)
    OR
    (state = 'awaitingResolution'
      AND resolutionClass = 'unresolved'
      AND lastErrorCode IS NOT NULL AND finishedAt IS NULL)
    OR
    (state = 'pendingInspection' AND finishedAt IS NULL)
    OR
    (state IN ('detached','retainedShared','deleted','alreadyAbsent')
      AND finishedAt IS NOT NULL)
  ),
  CHECK (
    (state = 'detached'
      AND resolutionClass IN ('workspaceExternal','unresolved'))
    OR state <> 'detached'
  ),
  CHECK (
    (state = 'retainedShared' AND resolutionClass = 'managedShared')
    OR state <> 'retainedShared'
  ),
  CHECK (
    (state IN ('deleted','alreadyAbsent')
      AND resolutionClass = 'managedExclusive')
    OR state NOT IN ('deleted','alreadyAbsent')
  ),
  CHECK (
    state NOT IN ('detached','retainedShared','deleted','alreadyAbsent')
    OR (managedRootId IS NULL AND objectId IS NULL)
  )
);
CREATE INDEX camp_deletion_artifact_recovery
  ON camp_deletion_artifact(jobId, state, updatedAt);

CREATE TABLE legacy_chat_scope (
  threadId TEXT PRIMARY KEY NOT NULL
    REFERENCES chat_thread(id) ON DELETE RESTRICT,
  scopeKind TEXT NOT NULL CHECK (scopeKind IN ('globalCow','camp')),
  campId TEXT REFERENCES camp(id) ON DELETE RESTRICT,
  cowId TEXT NOT NULL REFERENCES companion(id) ON DELETE RESTRICT,
  evidenceKind TEXT NOT NULL CHECK
    (evidenceKind IN ('dmThread','guideThread')),
  createdAt DATETIME NOT NULL,
  CHECK (
    (scopeKind = 'globalCow' AND campId IS NULL)
    OR
    (scopeKind = 'camp' AND campId IS NOT NULL)
  )
);
CREATE INDEX legacy_chat_scope_camp
  ON legacy_chat_scope(scopeKind, campId, cowId);

CREATE TABLE legacy_companion_note_scope (
  noteId TEXT PRIMARY KEY NOT NULL
    REFERENCES companion_note(id) ON DELETE RESTRICT,
  scopeKind TEXT NOT NULL CHECK (scopeKind IN ('globalCow','camp')),
  campId TEXT REFERENCES camp(id) ON DELETE RESTRICT,
  cowId TEXT NOT NULL REFERENCES companion(id) ON DELETE RESTRICT,
  sourceThreadId TEXT REFERENCES chat_thread(id) ON DELETE RESTRICT,
  evidenceKind TEXT NOT NULL CHECK
    (evidenceKind IN ('dmThread','guideThread','coworkEvent','manualCow')),
  createdAt DATETIME NOT NULL,
  CHECK (
    (scopeKind = 'globalCow' AND campId IS NULL)
    OR
    (scopeKind = 'camp' AND campId IS NOT NULL)
  )
);
CREATE INDEX legacy_companion_note_scope_camp
  ON legacy_companion_note_scope(scopeKind, campId, cowId);

CREATE TABLE camp_event_scope (
  sourceTable TEXT NOT NULL CHECK (sourceTable IN ('event','domain_event')),
  eventId TEXT NOT NULL,
  scopeKind TEXT NOT NULL CHECK (scopeKind IN ('camp','global')),
  campId TEXT REFERENCES camp(id) ON DELETE RESTRICT,
  payloadRedactedAt DATETIME,
  PRIMARY KEY(sourceTable, eventId),
  CHECK (
    (scopeKind = 'camp' AND campId IS NOT NULL)
    OR
    (scopeKind = 'global' AND campId IS NULL)
  ),
  CHECK (sourceTable <> 'domain_event' OR scopeKind = 'camp')
);
CREATE INDEX camp_event_scope_camp
  ON camp_event_scope(scopeKind, campId, sourceTable, eventId);

INSERT INTO camp_event_scope(
  sourceTable, eventId, scopeKind, campId, payloadRedactedAt
)
SELECT 'domain_event', id, 'camp', campId, NULL FROM domain_event;

CREATE TABLE cow_identity (
  id TEXT PRIMARY KEY NOT NULL REFERENCES companion(id) ON DELETE RESTRICT,
  displayName TEXT NOT NULL,
  appearanceRef TEXT,
  personality TEXT NOT NULL,
  baseRole TEXT NOT NULL,
  defaultEnginePolicyJson TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('active','retired')),
  aggregateVersion INTEGER NOT NULL DEFAULT 1 CHECK (aggregateVersion >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL
);

CREATE TABLE camp_residency (
  id TEXT PRIMARY KEY NOT NULL,
  cowId TEXT NOT NULL REFERENCES cow_identity(id) ON DELETE RESTRICT,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  role TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN
    ('requested','authorized','active','paused','left','revoked')),
  idempotencyKey TEXT NOT NULL UNIQUE,
  joinedAt DATETIME,
  pausedAt DATETIME,
  leftAt DATETIME,
  revokedAt DATETIME,
  aggregateVersion INTEGER NOT NULL DEFAULT 1 CHECK (aggregateVersion >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  CHECK ((status = 'paused') = (pausedAt IS NOT NULL)),
  CHECK ((status = 'left') = (leftAt IS NOT NULL)),
  CHECK ((status = 'revoked') = (revokedAt IS NOT NULL))
);
CREATE UNIQUE INDEX camp_residency_one_live
  ON camp_residency(cowId, campId)
  WHERE status IN ('requested','authorized','active','paused');
CREATE INDEX camp_residency_camp_status
  ON camp_residency(campId, status, cowId);

CREATE TABLE camp_bridge (
  id TEXT PRIMARY KEY NOT NULL,
  sourceCampId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  targetCampId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  mode TEXT NOT NULL CHECK (mode IN ('reference','copy','searchGrant')),
  contentScopeJson TEXT NOT NULL,
  grantedByActorId TEXT NOT NULL,
  validUntil DATETIME,
  status TEXT NOT NULL CHECK (status IN ('active','revoked')),
  revokedAt DATETIME,
  aggregateVersion INTEGER NOT NULL DEFAULT 1 CHECK (aggregateVersion >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  CHECK (sourceCampId <> targetCampId),
  CHECK (
    (status = 'revoked' AND revokedAt IS NOT NULL)
    OR
    (status = 'active' AND revokedAt IS NULL)
  )
);
CREATE INDEX camp_bridge_lookup
  ON camp_bridge(sourceCampId, targetCampId, status, validUntil);

CREATE TABLE memory_record_version (
  id TEXT NOT NULL,
  version INTEGER NOT NULL CHECK (version >= 1),
  layer TEXT NOT NULL CHECK (layer IN
    ('rawSource','working','campKnowledge','globalPreference','globalSkill')),
  ownerType TEXT NOT NULL CHECK (ownerType IN ('user','goal','camp','cow')),
  ownerId TEXT NOT NULL,
  campId TEXT REFERENCES camp(id) ON DELETE RESTRICT,
  title TEXT NOT NULL,
  bodyText TEXT,
  contentRef TEXT,
  contentHash TEXT NOT NULL CHECK (length(contentHash) = 64),
  status TEXT NOT NULL CHECK (status IN
    ('proposed','active','needsReview','invalidated','deletedTombstone')),
  sourceType TEXT NOT NULL CHECK
    (sourceType IN ('userConfirmed','independentSource','outcomeExperience','inference')),
  applicabilityJson TEXT NOT NULL,
  createdByActorId TEXT NOT NULL,
  confirmedByActorId TEXT,
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  PRIMARY KEY(id, version),
  UNIQUE(id, version, contentHash),
  CHECK (
    (status = 'deletedTombstone' AND bodyText IS NULL AND contentRef IS NULL)
    OR
    (status <> 'deletedTombstone'
      AND ((bodyText IS NOT NULL) <> (contentRef IS NOT NULL)))
  ),
  CHECK (
    (layer IN ('rawSource','working'))
    OR
    (sourceType = 'inference')
    OR
    (confirmedByActorId IS NOT NULL)
  )
);
CREATE INDEX memory_record_owner
  ON memory_record_version(ownerType, ownerId, status, version);
CREATE INDEX memory_record_camp
  ON memory_record_version(campId, layer, status);

CREATE TABLE memory_dependency (
  id TEXT PRIMARY KEY NOT NULL,
  memoryId TEXT NOT NULL,
  memoryVersion INTEGER NOT NULL,
  dependencyType TEXT NOT NULL CHECK (dependencyType IN
    ('input','outcome','verification','acceptance','memory')),
  dependencyId TEXT NOT NULL,
  dependencyVersion INTEGER,
  dependencyHash TEXT NOT NULL CHECK (length(dependencyHash) = 64),
  createdAt DATETIME NOT NULL,
  FOREIGN KEY(memoryId, memoryVersion)
    REFERENCES memory_record_version(id, version) ON DELETE RESTRICT,
  UNIQUE(
    memoryId, memoryVersion, dependencyType,
    dependencyId, dependencyVersion, dependencyHash)
);
CREATE INDEX memory_dependency_source
  ON memory_dependency(
    dependencyType, dependencyId, dependencyVersion, dependencyHash);

-- MIGRATION PHASE BARRIER: the real Swift migrator runs all v16 copy/backfill
-- resolvers and count/FK assertions here.  Only after that callback succeeds may
-- it execute the four ordered surviving-table UPDATE-guard drops below.
-- These v15/legacy guards deliberately remain installed through all data work.
-- No IF EXISTS is allowed: a missing predecessor guard is schema corruption.
DROP TRIGGER event_no_update;
DROP TRIGGER verification_record_reject_update;
DROP TRIGGER acceptance_record_reject_update;
DROP TRIGGER external_operation_receipt_reject_update;

-- No DML, resolver, copy/backfill, or assertion may follow the four drops.
-- Every v16 CREATE TRIGGER, including same-table guards, starts only here, after
-- the complete graph, durable-work rename, successful barrier, and all five
-- v16 DROP TRIGGER statements (the owning-table drop occurred before rebuild).
CREATE TRIGGER memory_dependency_reject_update
BEFORE UPDATE ON memory_dependency
BEGIN
  SELECT RAISE(ABORT, 'memory_dependency is append-only');
END;
CREATE TRIGGER memory_dependency_reject_delete
BEFORE DELETE ON memory_dependency
BEGIN
  SELECT RAISE(ABORT, 'memory_dependency is append-only');
END;

CREATE TRIGGER camp_provider_dispatch_validate_replay
BEFORE INSERT ON camp_provider_dispatch
WHEN NEW.dispatchAttempt > 1 AND NOT EXISTS (
  SELECT 1 FROM camp_provider_dispatch p
  WHERE p.id = NEW.replayOfDispatchId
    AND p.workId = NEW.workId
    AND p.turnOrdinal = NEW.turnOrdinal
    AND p.dispatchAttempt = NEW.dispatchAttempt - 1
    AND p.state = 'abandoned'
)
BEGIN
  SELECT RAISE(ABORT, 'provider replay must follow exact abandoned attempt');
END;
CREATE TRIGGER camp_deletion_job_validate_work_insert
BEFORE INSERT ON camp_deletion_job
WHEN NOT EXISTS (
  SELECT 1 FROM durable_work w
  WHERE w.id = NEW.workId AND w.campId = NEW.campId
    AND w.kind = 'campDeletion'
    AND w.aggregateType = 'camp' AND w.aggregateId = NEW.campId
)
BEGIN
  SELECT RAISE(ABORT, 'deletion job work binding mismatch');
END;
CREATE TRIGGER camp_deletion_job_validate_work_update
BEFORE UPDATE OF workId, campId ON camp_deletion_job
WHEN NOT EXISTS (
  SELECT 1 FROM durable_work w
  WHERE w.id = NEW.workId AND w.campId = NEW.campId
    AND w.kind = 'campDeletion'
    AND w.aggregateType = 'camp' AND w.aggregateId = NEW.campId
)
BEGIN
  SELECT RAISE(ABORT, 'deletion job replacement work binding mismatch');
END;

CREATE TRIGGER camp_provider_dispatch_first_redaction_exact
BEFORE UPDATE ON camp_provider_dispatch
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.id = OLD.id
  AND NEW.workId = OLD.workId
  AND NEW.workAttempt = OLD.workAttempt
  AND NEW.turnOrdinal = OLD.turnOrdinal
  AND NEW.dispatchAttempt = OLD.dispatchAttempt
  AND NEW.replayOfDispatchId IS OLD.replayOfDispatchId
  AND NEW.idempotencyKey = OLD.idempotencyKey
  AND NEW.campId = OLD.campId
  AND NEW.campLifecycleVersion = OLD.campLifecycleVersion
  AND NEW.operationKind = OLD.operationKind
  AND NEW.replayClass = OLD.replayClass
  AND NEW.state = OLD.state
  AND NEW.requestJson = '{}'
  AND NEW.requestHash = OLD.requestHash
  AND NEW.responseJson IS NULL AND NEW.responseHash IS NULL
  AND NEW.version = OLD.version + 1
  AND NEW.preparedAt = OLD.preparedAt
  AND NEW.startedAt IS OLD.startedAt
  AND NEW.returnedAt IS OLD.returnedAt
  AND NEW.consumedAt IS OLD.consumedAt
  AND NEW.abandonedAt IS OLD.abandonedAt
  AND EXISTS (
    SELECT 1 FROM camp_lifecycle l
    JOIN camp_deletion_job j ON j.campId = l.campId
    WHERE l.campId = OLD.campId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN
  SELECT RAISE(ABORT, 'provider redaction diff is invalid');
END;
CREATE TRIGGER camp_provider_dispatch_reject_private_update
BEFORE UPDATE ON camp_provider_dispatch
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NULL
  AND NEW.requestJson IS NOT OLD.requestJson
BEGIN
  SELECT RAISE(ABORT, 'provider request is immutable');
END;
CREATE TRIGGER camp_provider_dispatch_post_redaction_lock
BEFORE UPDATE ON camp_provider_dispatch
WHEN OLD.redactedAt IS NOT NULL
BEGIN
  SELECT RAISE(ABORT, 'provider row is immutable after redaction');
END;
CREATE TRIGGER camp_provider_dispatch_reject_delete
BEFORE DELETE ON camp_provider_dispatch
BEGIN
  SELECT RAISE(ABORT, 'provider row may not be deleted');
END;

CREATE TRIGGER user_request_validate_state_insert
BEFORE INSERT ON user_request
WHEN NOT (
  (NEW.lifecycleState = 'open'
    AND NEW.answerJson IS NULL AND NEW.answeredAt IS NULL
    AND NEW.terminalReason IS NULL AND NEW.redactedAt IS NULL)
  OR
  (NEW.lifecycleState = 'answered'
    AND NEW.answerJson IS NOT NULL AND NEW.answeredAt IS NOT NULL
    AND NEW.terminalReason IS NULL AND NEW.redactedAt IS NULL)
)
BEGIN
  SELECT RAISE(ABORT, 'invalid user request lifecycle');
END;
CREATE TRIGGER user_request_validate_update_and_redaction
BEFORE UPDATE ON user_request
WHEN NOT (
  (OLD.lifecycleState = 'open' AND NEW.lifecycleState = 'answered'
    AND NEW.id = OLD.id AND NEW.cardId = OLD.cardId AND NEW.kind = OLD.kind
    AND NEW.prompt = OLD.prompt AND NEW.optionsJson IS OLD.optionsJson
    AND NEW.answerJson IS NOT NULL AND NEW.answeredAt IS NOT NULL
    AND NEW.createdAt = OLD.createdAt
    AND NEW.terminalReason IS NULL AND NEW.redactedAt IS NULL
    AND EXISTS (
      SELECT 1 FROM card c
      JOIN mission m ON m.id = c.missionId
      JOIN squad s ON s.id = m.squadId
      JOIN camp_lifecycle l ON l.campId = s.campId
      JOIN camp p ON p.id = s.campId
      WHERE c.id = OLD.cardId
        AND l.state = 'active' AND p.archived = 0
    ))
  OR
  (OLD.lifecycleState = 'open' AND NEW.lifecycleState = 'withdrawn'
    AND NEW.id = OLD.id AND NEW.cardId = OLD.cardId AND NEW.kind = OLD.kind
    AND NEW.prompt = OLD.prompt AND NEW.optionsJson IS OLD.optionsJson
    AND NEW.answerJson IS NULL AND NEW.answeredAt IS NULL
    AND NEW.createdAt = OLD.createdAt
    AND NEW.terminalReason = 'camp_deleted' AND NEW.redactedAt IS NULL
    AND EXISTS (
      SELECT 1 FROM card c
      JOIN mission m ON m.id = c.missionId
      JOIN squad s ON s.id = m.squadId
      JOIN camp_lifecycle l ON l.campId = s.campId
      JOIN camp_deletion_job j ON j.campId = s.campId
      WHERE c.id = OLD.cardId
        AND l.state = 'deletionRequested' AND j.state = 'quiescing'
    ))
  OR
  (OLD.redactedAt IS NULL
    AND OLD.lifecycleState IN ('answered','withdrawn')
    AND NEW.lifecycleState = 'redacted'
    AND NEW.id = OLD.id AND NEW.cardId = OLD.cardId AND NEW.kind = OLD.kind
    AND NEW.prompt = '[deleted]' AND NEW.optionsJson IS NULL
    AND NEW.answerJson IS NULL AND NEW.answeredAt IS NULL
    AND NEW.createdAt = OLD.createdAt
    AND NEW.terminalReason = 'camp_deleted' AND NEW.redactedAt IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM card c
      JOIN mission m ON m.id = c.missionId
      JOIN squad s ON s.id = m.squadId
      JOIN camp_lifecycle l ON l.campId = s.campId
      JOIN camp_deletion_job j ON j.campId = s.campId
      WHERE c.id = OLD.cardId
        AND l.state = 'deleting' AND j.state = 'finalizing'
    ))
)
BEGIN
  SELECT RAISE(ABORT, 'invalid user request update');
END;
CREATE TRIGGER user_request_post_redaction_lock
BEFORE UPDATE ON user_request
WHEN OLD.redactedAt IS NOT NULL
BEGIN
  SELECT RAISE(ABORT, 'user request is immutable after redaction');
END;
CREATE TRIGGER user_request_reject_delete
BEFORE DELETE ON user_request
BEGIN
  SELECT RAISE(ABORT, 'user request may not be deleted');
END;

CREATE TRIGGER ingestion_item_validate_deletion_terminal
BEFORE UPDATE ON ingestion_item
WHEN NEW.terminalReason IS NOT OLD.terminalReason
AND NOT (
  OLD.terminalReason IS NULL
  AND OLD.redactedAt IS NULL AND NEW.redactedAt IS NULL
  AND OLD.status IN ('queued','ruminating','needsReview')
  AND NEW.id = OLD.id AND NEW.campId = OLD.campId
  AND NEW.sourceType = OLD.sourceType
  AND NEW.title IS OLD.title AND NEW.rawText = OLD.rawText
  AND NEW.sourceURL IS OLD.sourceURL AND NEW.author IS OLD.author
  AND NEW.userIntent IS OLD.userIntent
  AND NEW.contentHash = OLD.contentHash
  AND NEW.status = 'discarded'
  AND NEW.attempt = OLD.attempt AND NEW.errorText IS OLD.errorText
  AND NEW.createdAt = OLD.createdAt AND NEW.updatedAt = OLD.updatedAt
  AND NEW.version = OLD.version + 1
  AND NEW.terminalReason = 'camp_deleted'
  AND EXISTS (
    SELECT 1 FROM camp_lifecycle l
    JOIN camp_deletion_job j ON j.campId = l.campId
    WHERE l.campId = OLD.campId
      AND l.state = 'deletionRequested' AND j.state = 'quiescing'
  )
)
BEGIN SELECT RAISE(ABORT, 'ingestion deletion terminal diff is invalid'); END;
CREATE TRIGGER ingestion_item_deletion_terminal_lock
BEFORE UPDATE ON ingestion_item
WHEN OLD.terminalReason = 'camp_deleted'
  AND OLD.redactedAt IS NULL AND NEW.redactedAt IS NULL
BEGIN SELECT RAISE(ABORT, 'deletion-terminal ingestion is immutable'); END;
CREATE TRIGGER ingestion_item_first_redaction_exact
BEFORE UPDATE ON ingestion_item
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  OLD.status IN ('materialized','failed','discarded')
  AND NEW.id = OLD.id AND NEW.campId = OLD.campId
  AND NEW.sourceType = OLD.sourceType
  AND NEW.title IS NULL AND NEW.rawText = '[deleted]'
  AND NEW.sourceURL IS NULL AND NEW.author IS NULL
  AND NEW.userIntent IS NULL
  AND NEW.contentHash = OLD.contentHash
  AND NEW.status = OLD.status
  AND NEW.attempt = OLD.attempt AND NEW.errorText IS NULL
  AND NEW.createdAt = OLD.createdAt AND NEW.updatedAt = OLD.updatedAt
  AND NEW.version = OLD.version + 1
  AND NEW.terminalReason IS OLD.terminalReason
  AND EXISTS (
    SELECT 1 FROM camp_lifecycle l
    JOIN camp_deletion_job j ON j.campId = l.campId
    WHERE l.campId = OLD.campId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN SELECT RAISE(ABORT, 'ingestion redaction diff is invalid'); END;
CREATE TRIGGER ingestion_item_post_redaction_lock
BEFORE UPDATE ON ingestion_item WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'ingestion is immutable after redaction'); END;
CREATE TRIGGER ingestion_item_reject_delete
BEFORE DELETE ON ingestion_item
WHEN NOT EXISTS (
  SELECT 1
  FROM camp_lifecycle l
  JOIN camp c ON c.id = l.campId
  JOIN domain_event e
    ON e.campId = l.campId
   AND e.aggregateType = 'ingestion'
   AND e.aggregateId = OLD.id
   AND e.aggregateVersion = OLD.version + 1
   AND e.eventType = 'active_ingestion_deleted_v1'
   AND e.payloadVersion = 1
   AND e.eventOrdinal = 0
   AND e.eventIdempotencyKey =
     e.commandIdempotencyKey || '#0000:ingestion:' || OLD.id
  JOIN domain_command_receipt r
    ON r.idempotencyKey = e.commandIdempotencyKey
  JOIN event_outbox o
    ON o.eventId = e.id
  JOIN camp_event_scope s
    ON s.sourceTable = 'domain_event' AND s.eventId = e.id
   AND s.scopeKind = 'camp' AND s.campId = OLD.campId
  WHERE l.campId = OLD.campId
    AND l.state = 'active' AND c.archived = 0
    AND OLD.status IN ('queued','failed','needsReview','discarded')
    AND OLD.terminalReason IS NULL AND OLD.redactedAt IS NULL
    AND r.commandType = 'activeIngestionDeletion.v1'
    AND r.eventCount = 1
    AND (
      SELECT COUNT(*) FROM domain_event one_event
      WHERE one_event.commandIdempotencyKey = r.idempotencyKey
    ) = 1
    AND length(r.commandPayloadHash) = 64
    AND r.commandPayloadHash NOT GLOB '*[^0-9a-f]*'
    AND length(r.resultHash) = 64
    AND r.resultHash NOT GLOB '*[^0-9a-f]*'
    AND length(e.payloadHash) = 64
    AND e.payloadHash NOT GLOB '*[^0-9a-f]*'
    AND json_valid(r.resultJson) AND json_valid(e.payloadJson)
    AND (SELECT COUNT(*) FROM json_each(r.resultJson)) = 23
    AND (SELECT COUNT(*) FROM json_each(e.payloadJson)) = 21
    AND json_type(r.resultJson, '$.actorRef') IS NULL
    AND json_type(r.resultJson, '$.actorId') IS NULL
    AND json_type(r.resultJson, '$.actorType') IS NULL
    AND json_type(r.resultJson, '$.deviceId') IS NULL
    AND json_type(r.resultJson, '$.accountId') IS NULL
    AND json_type(r.resultJson, '$.accountIdentifier') IS NULL
    AND json_type(e.payloadJson, '$.actorRef') IS NULL
    AND json_type(e.payloadJson, '$.actorId') IS NULL
    AND json_type(e.payloadJson, '$.actorType') IS NULL
    AND json_type(e.payloadJson, '$.deviceId') IS NULL
    AND json_type(e.payloadJson, '$.accountId') IS NULL
    AND json_type(e.payloadJson, '$.accountIdentifier') IS NULL
    AND e.actorType = 'user'
    AND length(e.actorId) > 0
    AND e.deviceId IS NOT NULL AND length(e.deviceId) > 0
    AND length(e.correlationId) > 0
    AND (e.causationId IS NULL OR length(e.causationId) > 0)
    AND length(e.occurredAt) > 0 AND length(e.recordedAt) > 0
    AND e.recordedAt >= e.occurredAt
    AND o.state = 'pending' AND o.attempt = 0
    AND o.notBefore IS NULL AND o.leaseOwner IS NULL
    AND o.leaseExpiresAt IS NULL AND o.lastError IS NULL
    AND o.version = 1 AND o.createdAt = e.recordedAt
    AND o.updatedAt = e.recordedAt AND o.sentAt IS NULL
    AND (
      SELECT COUNT(*) FROM event_outbox one_outbox
      WHERE one_outbox.eventId = e.id
    ) = 1
    AND json_extract(r.resultJson, '$.commandIdempotencyKey')
      = e.commandIdempotencyKey
    AND json_extract(r.resultJson, '$.eventId') = e.id
    AND json_extract(r.resultJson, '$.eventPayloadHash') = e.payloadHash
    AND json_extract(r.resultJson, '$.campId') = OLD.campId
    AND json_extract(r.resultJson, '$.expectedLifecycleVersion') = l.version
    AND json_extract(r.resultJson, '$.ingestionId') = OLD.id
    AND json_extract(r.resultJson, '$.oldIngestionVersion') = OLD.version
    AND json_extract(r.resultJson, '$.oldIngestionStatus') = OLD.status
    AND json_extract(r.resultJson, '$.ingestionContentHash') = OLD.contentHash
    AND length(json_extract(r.resultJson, '$.ingestionSnapshotHash')) = 64
    AND json_extract(r.resultJson, '$.ingestionSnapshotHash')
      NOT GLOB '*[^0-9a-f]*'
    AND json_extract(r.resultJson, '$.scope') = 'sourceAndResult'
    AND json_extract(r.resultJson, '$.deletedIngestionCount') = 1
    AND json_extract(r.resultJson, '$.updatedIngestionCount') = 0
    AND json_extract(r.resultJson, '$.knowledgeSourceLinkCount') = 0
    AND json_extract(r.resultJson, '$.actionCandidateCount') = 0
    AND json_extract(r.resultJson, '$.nonterminalRuminationWorkCount') = 0
    AND json_extract(r.resultJson, '$.openRuminationAttemptCount') = 0
    AND json_extract(r.resultJson, '$.nonterminalProviderDispatchCount') = 0
    AND json_extract(e.payloadJson, '$.campId') = OLD.campId
    AND json_extract(e.payloadJson, '$.commandIdempotencyKey')
      = e.commandIdempotencyKey
    AND json_extract(e.payloadJson, '$.expectedLifecycleVersion') = l.version
    AND json_extract(e.payloadJson, '$.commandPayloadHash')
      = r.commandPayloadHash
    AND json_extract(e.payloadJson, '$.ingestionId') = OLD.id
    AND json_extract(e.payloadJson, '$.oldIngestionVersion') = OLD.version
    AND json_extract(e.payloadJson, '$.oldIngestionStatus') = OLD.status
    AND json_extract(e.payloadJson, '$.ingestionContentHash') = OLD.contentHash
    AND length(json_extract(e.payloadJson, '$.ingestionSnapshotHash')) = 64
    AND json_extract(e.payloadJson, '$.ingestionSnapshotHash')
      NOT GLOB '*[^0-9a-f]*'
    AND json_extract(r.resultJson, '$.ingestionSnapshotHash')
      = json_extract(e.payloadJson, '$.ingestionSnapshotHash')
    AND json_extract(e.payloadJson, '$.scope') = 'sourceAndResult'
    AND json_extract(e.payloadJson, '$.deletedIngestionCount') = 1
    AND json_extract(e.payloadJson, '$.updatedIngestionCount') = 0
    AND json_extract(e.payloadJson, '$.deletedResultCount') IN (0, 1)
    AND json_extract(e.payloadJson, '$.knowledgeSourceLinkCount') = 0
    AND json_extract(e.payloadJson, '$.actionCandidateCount') = 0
    AND json_extract(e.payloadJson, '$.nonterminalRuminationWorkCount') = 0
    AND json_extract(e.payloadJson, '$.openRuminationAttemptCount') = 0
    AND json_extract(e.payloadJson, '$.nonterminalProviderDispatchCount') = 0
    AND json_extract(r.resultJson, '$.commandPayloadHash')
      = json_extract(e.payloadJson, '$.commandPayloadHash')
    AND json_extract(r.resultJson, '$.scope')
      = json_extract(e.payloadJson, '$.scope')
    AND json_extract(r.resultJson, '$.deletedResultCount')
      = json_extract(e.payloadJson, '$.deletedResultCount')
    AND (
      (json_extract(e.payloadJson, '$.deletedResultCount') = 0
        AND json_type(e.payloadJson, '$.resultId') = 'null'
        AND json_type(e.payloadJson, '$.resultVersion') = 'null'
        AND json_type(e.payloadJson, '$.resultHash') = 'null'
        AND json_type(r.resultJson, '$.resultId') = 'null'
        AND json_type(r.resultJson, '$.resultVersion') = 'null'
        AND json_type(r.resultJson, '$.resultHash') = 'null')
      OR
      (json_extract(e.payloadJson, '$.deletedResultCount') = 1
        AND json_type(e.payloadJson, '$.resultId') = 'text'
        AND json_type(e.payloadJson, '$.resultVersion') = 'integer'
        AND json_extract(e.payloadJson, '$.resultVersion') >= 1
        AND length(json_extract(e.payloadJson, '$.resultHash')) = 64
        AND json_extract(e.payloadJson, '$.resultHash')
          NOT GLOB '*[^0-9a-f]*'
        AND json_extract(r.resultJson, '$.resultId')
          = json_extract(e.payloadJson, '$.resultId')
        AND json_extract(r.resultJson, '$.resultVersion')
          = json_extract(e.payloadJson, '$.resultVersion')
        AND json_extract(r.resultJson, '$.resultHash')
          = json_extract(e.payloadJson, '$.resultHash'))
    )
    AND NOT EXISTS (
      SELECT 1 FROM rumination_result rr WHERE rr.ingestionId = OLD.id
    )
    AND NOT EXISTS (
      SELECT 1 FROM knowledge_source_link k WHERE k.ingestionId = OLD.id
    )
    AND NOT EXISTS (
      SELECT 1 FROM action_candidate a WHERE a.ingestionId = OLD.id
    )
    AND NOT EXISTS (
      SELECT 1 FROM durable_work w
      WHERE w.campId = OLD.campId AND w.kind = 'rumination'
        AND w.aggregateType = 'ingestion' AND w.aggregateId = OLD.id
        AND w.state IN ('queued','running','retryScheduled')
    )
    AND NOT EXISTS (
      SELECT 1 FROM durable_work_attempt a
      JOIN durable_work w ON w.id = a.workId
      WHERE w.campId = OLD.campId AND w.kind = 'rumination'
        AND w.aggregateType = 'ingestion' AND w.aggregateId = OLD.id
        AND a.endedAt IS NULL
    )
    AND NOT EXISTS (
      SELECT 1 FROM camp_provider_dispatch p
      JOIN durable_work w ON w.id = p.workId
      WHERE w.campId = OLD.campId AND w.kind = 'rumination'
        AND w.aggregateType = 'ingestion' AND w.aggregateId = OLD.id
        AND p.state IN ('prepared','started','returned')
    )
    AND agentloop_active_ingestion_deletion_permit_v1(
      'deleteIngestion',
      e.commandIdempotencyKey, r.commandPayloadHash, e.id, e.payloadHash,
      e.actorType, e.actorId, e.deviceId, e.correlationId, e.causationId,
      e.occurredAt, e.recordedAt, OLD.campId, l.version,
      json_extract(e.payloadJson, '$.scope'),
      json_extract(e.payloadJson, '$.ingestionSnapshotHash'),
      json_extract(e.payloadJson, '$.resultHash'),
      json_extract(e.payloadJson, '$.deletedResultCount'),
      json_extract(e.payloadJson, '$.deletedIngestionCount'),
      json_extract(e.payloadJson, '$.updatedIngestionCount'),
      json_extract(e.payloadJson, '$.knowledgeSourceLinkCount'),
      json_extract(e.payloadJson, '$.actionCandidateCount'),
      json_extract(e.payloadJson, '$.nonterminalRuminationWorkCount'),
      json_extract(e.payloadJson, '$.openRuminationAttemptCount'),
      json_extract(e.payloadJson, '$.nonterminalProviderDispatchCount'),
      o.eventId, o.state, o.attempt, o.notBefore, o.leaseOwner,
      o.leaseExpiresAt, o.lastError, o.version, o.createdAt, o.updatedAt,
      o.sentAt,
      OLD.id, OLD.campId, OLD.sourceType, OLD.title, OLD.rawText,
      OLD.sourceURL, OLD.author, OLD.userIntent, OLD.contentHash, OLD.status,
      OLD.attempt, OLD.errorText, OLD.createdAt, OLD.updatedAt, OLD.version,
      OLD.terminalReason, OLD.redactedAt
    ) = 1
)
BEGIN
  SELECT RAISE(ABORT, 'ingestion delete requires exact transaction permit');
END;

CREATE TRIGGER rumination_result_first_redaction_exact
BEFORE UPDATE ON rumination_result
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.id = OLD.id AND NEW.ingestionId = OLD.ingestionId
  AND NEW.pipelineVersion = OLD.pipelineVersion
  AND NEW.resultJson = '{}' AND NEW.userEditedJson IS NULL
  AND NEW.materializedAt IS OLD.materializedAt
  AND NEW.createdAt = OLD.createdAt AND NEW.updatedAt = OLD.updatedAt
  AND NEW.version = OLD.version + 1
  AND EXISTS (
    SELECT 1 FROM ingestion_item i
    JOIN camp_lifecycle l ON l.campId = i.campId
    JOIN camp_deletion_job j ON j.campId = i.campId
    WHERE i.id = OLD.ingestionId
      AND i.status IN ('materialized','failed','discarded')
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN SELECT RAISE(ABORT, 'rumination result redaction diff is invalid'); END;
CREATE TRIGGER rumination_result_post_redaction_lock
BEFORE UPDATE ON rumination_result WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'rumination result is immutable after redaction'); END;
CREATE TRIGGER rumination_result_reject_delete
BEFORE DELETE ON rumination_result
WHEN NOT EXISTS (
  SELECT 1
  FROM ingestion_item i
  JOIN camp_lifecycle l ON l.campId = i.campId
  JOIN camp c ON c.id = i.campId
  JOIN domain_event e
    ON e.campId = i.campId
   AND e.aggregateType = 'ingestion'
   AND e.aggregateId = i.id
   AND e.aggregateVersion = i.version + 1
   AND e.eventType = 'active_ingestion_deleted_v1'
   AND e.payloadVersion = 1
   AND e.eventOrdinal = 0
   AND e.eventIdempotencyKey =
     e.commandIdempotencyKey || '#0000:ingestion:' || i.id
  JOIN domain_command_receipt r
    ON r.idempotencyKey = e.commandIdempotencyKey
  JOIN event_outbox o
    ON o.eventId = e.id
  JOIN camp_event_scope s
    ON s.sourceTable = 'domain_event' AND s.eventId = e.id
   AND s.scopeKind = 'camp' AND s.campId = i.campId
  WHERE i.id = OLD.ingestionId
    AND l.state = 'active' AND c.archived = 0
    AND i.terminalReason IS NULL AND i.redactedAt IS NULL
    AND OLD.redactedAt IS NULL AND OLD.materializedAt IS NULL
    AND r.commandType = 'activeIngestionDeletion.v1'
    AND r.eventCount = 1
    AND (
      SELECT COUNT(*) FROM domain_event one_event
      WHERE one_event.commandIdempotencyKey = r.idempotencyKey
    ) = 1
    AND length(r.commandPayloadHash) = 64
    AND r.commandPayloadHash NOT GLOB '*[^0-9a-f]*'
    AND length(r.resultHash) = 64
    AND r.resultHash NOT GLOB '*[^0-9a-f]*'
    AND length(e.payloadHash) = 64
    AND e.payloadHash NOT GLOB '*[^0-9a-f]*'
    AND json_valid(r.resultJson) AND json_valid(e.payloadJson)
    AND (SELECT COUNT(*) FROM json_each(r.resultJson)) = 23
    AND (SELECT COUNT(*) FROM json_each(e.payloadJson)) = 21
    AND json_type(r.resultJson, '$.actorRef') IS NULL
    AND json_type(r.resultJson, '$.actorId') IS NULL
    AND json_type(r.resultJson, '$.actorType') IS NULL
    AND json_type(r.resultJson, '$.deviceId') IS NULL
    AND json_type(r.resultJson, '$.accountId') IS NULL
    AND json_type(r.resultJson, '$.accountIdentifier') IS NULL
    AND json_type(e.payloadJson, '$.actorRef') IS NULL
    AND json_type(e.payloadJson, '$.actorId') IS NULL
    AND json_type(e.payloadJson, '$.actorType') IS NULL
    AND json_type(e.payloadJson, '$.deviceId') IS NULL
    AND json_type(e.payloadJson, '$.accountId') IS NULL
    AND json_type(e.payloadJson, '$.accountIdentifier') IS NULL
    AND e.actorType = 'user'
    AND length(e.actorId) > 0
    AND e.deviceId IS NOT NULL AND length(e.deviceId) > 0
    AND length(e.correlationId) > 0
    AND (e.causationId IS NULL OR length(e.causationId) > 0)
    AND length(e.occurredAt) > 0 AND length(e.recordedAt) > 0
    AND e.recordedAt >= e.occurredAt
    AND o.state = 'pending' AND o.attempt = 0
    AND o.notBefore IS NULL AND o.leaseOwner IS NULL
    AND o.leaseExpiresAt IS NULL AND o.lastError IS NULL
    AND o.version = 1 AND o.createdAt = e.recordedAt
    AND o.updatedAt = e.recordedAt AND o.sentAt IS NULL
    AND (
      SELECT COUNT(*) FROM event_outbox one_outbox
      WHERE one_outbox.eventId = e.id
    ) = 1
    AND json_extract(r.resultJson, '$.commandIdempotencyKey')
      = e.commandIdempotencyKey
    AND json_extract(r.resultJson, '$.eventId') = e.id
    AND json_extract(r.resultJson, '$.eventPayloadHash') = e.payloadHash
    AND json_extract(r.resultJson, '$.campId') = i.campId
    AND json_extract(r.resultJson, '$.expectedLifecycleVersion') = l.version
    AND json_extract(r.resultJson, '$.ingestionId') = i.id
    AND json_extract(r.resultJson, '$.oldIngestionVersion') = i.version
    AND json_extract(r.resultJson, '$.oldIngestionStatus') = i.status
    AND json_extract(r.resultJson, '$.ingestionContentHash') = i.contentHash
    AND length(json_extract(r.resultJson, '$.ingestionSnapshotHash')) = 64
    AND json_extract(r.resultJson, '$.ingestionSnapshotHash')
      NOT GLOB '*[^0-9a-f]*'
    AND json_extract(r.resultJson, '$.resultId') = OLD.id
    AND json_extract(r.resultJson, '$.resultVersion') = OLD.version
    AND json_extract(r.resultJson, '$.knowledgeSourceLinkCount') = 0
    AND json_extract(r.resultJson, '$.actionCandidateCount') = 0
    AND json_extract(r.resultJson, '$.nonterminalRuminationWorkCount') = 0
    AND json_extract(r.resultJson, '$.openRuminationAttemptCount') = 0
    AND json_extract(r.resultJson, '$.nonterminalProviderDispatchCount') = 0
    AND json_extract(e.payloadJson, '$.campId') = i.campId
    AND json_extract(e.payloadJson, '$.commandIdempotencyKey')
      = e.commandIdempotencyKey
    AND json_extract(e.payloadJson, '$.expectedLifecycleVersion') = l.version
    AND json_extract(e.payloadJson, '$.commandPayloadHash')
      = r.commandPayloadHash
    AND json_extract(e.payloadJson, '$.ingestionId') = i.id
    AND json_extract(e.payloadJson, '$.oldIngestionVersion') = i.version
    AND json_extract(e.payloadJson, '$.oldIngestionStatus') = i.status
    AND json_extract(e.payloadJson, '$.ingestionContentHash') = i.contentHash
    AND length(json_extract(e.payloadJson, '$.ingestionSnapshotHash')) = 64
    AND json_extract(e.payloadJson, '$.ingestionSnapshotHash')
      NOT GLOB '*[^0-9a-f]*'
    AND json_extract(r.resultJson, '$.ingestionSnapshotHash')
      = json_extract(e.payloadJson, '$.ingestionSnapshotHash')
    AND json_extract(e.payloadJson, '$.resultId') = OLD.id
    AND json_extract(e.payloadJson, '$.resultVersion') = OLD.version
    AND length(json_extract(e.payloadJson, '$.resultHash')) = 64
    AND json_extract(e.payloadJson, '$.resultHash')
      NOT GLOB '*[^0-9a-f]*'
    AND json_extract(r.resultJson, '$.commandPayloadHash')
      = json_extract(e.payloadJson, '$.commandPayloadHash')
    AND json_extract(r.resultJson, '$.scope')
      = json_extract(e.payloadJson, '$.scope')
    AND json_extract(r.resultJson, '$.resultHash')
      = json_extract(e.payloadJson, '$.resultHash')
    AND json_extract(r.resultJson, '$.deletedResultCount') = 1
    AND json_extract(e.payloadJson, '$.deletedResultCount') = 1
    AND json_extract(e.payloadJson, '$.knowledgeSourceLinkCount') = 0
    AND json_extract(e.payloadJson, '$.actionCandidateCount') = 0
    AND json_extract(e.payloadJson, '$.nonterminalRuminationWorkCount') = 0
    AND json_extract(e.payloadJson, '$.openRuminationAttemptCount') = 0
    AND json_extract(e.payloadJson, '$.nonterminalProviderDispatchCount') = 0
    AND (
      (json_extract(e.payloadJson, '$.scope') = 'resultOnly'
        AND i.status IN ('needsReview','failed')
        AND json_extract(r.resultJson, '$.deletedIngestionCount') = 0
        AND json_extract(e.payloadJson, '$.deletedIngestionCount') = 0
        AND json_extract(r.resultJson, '$.updatedIngestionCount') = 1
        AND json_extract(e.payloadJson, '$.updatedIngestionCount') = 1)
      OR
      (json_extract(e.payloadJson, '$.scope') = 'sourceAndResult'
        AND i.status IN ('queued','failed','needsReview','discarded')
        AND json_extract(r.resultJson, '$.deletedIngestionCount') = 1
        AND json_extract(e.payloadJson, '$.deletedIngestionCount') = 1
        AND json_extract(r.resultJson, '$.updatedIngestionCount') = 0
        AND json_extract(e.payloadJson, '$.updatedIngestionCount') = 0)
    )
    AND NOT EXISTS (
      SELECT 1 FROM knowledge_source_link k WHERE k.ingestionId = i.id
    )
    AND NOT EXISTS (
      SELECT 1 FROM action_candidate a WHERE a.ingestionId = i.id
    )
    AND NOT EXISTS (
      SELECT 1 FROM durable_work w
      WHERE w.campId = i.campId AND w.kind = 'rumination'
        AND w.aggregateType = 'ingestion' AND w.aggregateId = i.id
        AND w.state IN ('queued','running','retryScheduled')
    )
    AND NOT EXISTS (
      SELECT 1 FROM durable_work_attempt a
      JOIN durable_work w ON w.id = a.workId
      WHERE w.campId = i.campId AND w.kind = 'rumination'
        AND w.aggregateType = 'ingestion' AND w.aggregateId = i.id
        AND a.endedAt IS NULL
    )
    AND NOT EXISTS (
      SELECT 1 FROM camp_provider_dispatch p
      JOIN durable_work w ON w.id = p.workId
      WHERE w.campId = i.campId AND w.kind = 'rumination'
        AND w.aggregateType = 'ingestion' AND w.aggregateId = i.id
        AND p.state IN ('prepared','started','returned')
    )
    AND agentloop_active_ingestion_deletion_permit_v1(
      'deleteResult',
      e.commandIdempotencyKey, r.commandPayloadHash, e.id, e.payloadHash,
      e.actorType, e.actorId, e.deviceId, e.correlationId, e.causationId,
      e.occurredAt, e.recordedAt, i.campId, l.version,
      json_extract(e.payloadJson, '$.scope'),
      json_extract(e.payloadJson, '$.ingestionSnapshotHash'),
      json_extract(e.payloadJson, '$.resultHash'),
      json_extract(e.payloadJson, '$.deletedResultCount'),
      json_extract(e.payloadJson, '$.deletedIngestionCount'),
      json_extract(e.payloadJson, '$.updatedIngestionCount'),
      json_extract(e.payloadJson, '$.knowledgeSourceLinkCount'),
      json_extract(e.payloadJson, '$.actionCandidateCount'),
      json_extract(e.payloadJson, '$.nonterminalRuminationWorkCount'),
      json_extract(e.payloadJson, '$.openRuminationAttemptCount'),
      json_extract(e.payloadJson, '$.nonterminalProviderDispatchCount'),
      o.eventId, o.state, o.attempt, o.notBefore, o.leaseOwner,
      o.leaseExpiresAt, o.lastError, o.version, o.createdAt, o.updatedAt,
      o.sentAt,
      i.id, i.campId, i.sourceType, i.title, i.rawText, i.sourceURL, i.author,
      i.userIntent, i.contentHash, i.status, i.attempt, i.errorText,
      i.createdAt, i.updatedAt, i.version, i.terminalReason, i.redactedAt,
      OLD.id, OLD.ingestionId, OLD.pipelineVersion, OLD.resultJson,
      OLD.userEditedJson, OLD.materializedAt, OLD.createdAt, OLD.updatedAt,
      OLD.version, OLD.redactedAt
    ) = 1
)
BEGIN
  SELECT RAISE(ABORT, 'rumination result delete requires exact transaction permit');
END;

CREATE TRIGGER action_candidate_validate_deletion_terminal
BEFORE UPDATE ON action_candidate
WHEN NEW.terminalReason IS NOT OLD.terminalReason
AND NOT (
  OLD.terminalReason IS NULL
  AND OLD.redactedAt IS NULL AND NEW.redactedAt IS NULL
  AND OLD.status IN ('proposed','accepted')
  AND NEW.id = OLD.id AND NEW.ingestionId = OLD.ingestionId
  AND NEW.campId = OLD.campId AND NEW.type = OLD.type
  AND NEW.title = OLD.title AND NEW.detailJson = OLD.detailJson
  AND NEW.status = 'dismissed' AND NEW.missionId IS OLD.missionId
  AND NEW.idemKey = OLD.idemKey
  AND NEW.createdAt = OLD.createdAt AND NEW.updatedAt = OLD.updatedAt
  AND NEW.version = OLD.version + 1
  AND NEW.terminalReason = 'camp_deleted'
  AND EXISTS (
    SELECT 1 FROM ingestion_item i
    JOIN camp_lifecycle l ON l.campId = i.campId
    JOIN camp_deletion_job j ON j.campId = i.campId
    WHERE i.id = OLD.ingestionId AND i.campId = OLD.campId
      AND l.state = 'deletionRequested' AND j.state = 'quiescing'
  )
)
BEGIN SELECT RAISE(ABORT, 'candidate deletion terminal diff is invalid'); END;
CREATE TRIGGER action_candidate_deletion_terminal_lock
BEFORE UPDATE ON action_candidate
WHEN OLD.terminalReason = 'camp_deleted'
  AND OLD.redactedAt IS NULL AND NEW.redactedAt IS NULL
BEGIN SELECT RAISE(ABORT, 'deletion-terminal candidate is immutable'); END;
CREATE TRIGGER action_candidate_first_redaction_exact
BEFORE UPDATE ON action_candidate
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  OLD.status IN ('dismissed','converted')
  AND NEW.id = OLD.id AND NEW.ingestionId = OLD.ingestionId
  AND NEW.campId = OLD.campId AND NEW.type = OLD.type
  AND NEW.title = '[deleted]' AND NEW.detailJson = '{}'
  AND NEW.status = OLD.status AND NEW.missionId IS OLD.missionId
  AND NEW.idemKey = OLD.idemKey
  AND NEW.createdAt = OLD.createdAt AND NEW.updatedAt = OLD.updatedAt
  AND NEW.version = OLD.version + 1
  AND NEW.terminalReason IS OLD.terminalReason
  AND EXISTS (
    SELECT 1 FROM ingestion_item i
    JOIN camp_lifecycle l ON l.campId = i.campId
    JOIN camp_deletion_job j ON j.campId = i.campId
    WHERE i.id = OLD.ingestionId AND i.campId = OLD.campId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN SELECT RAISE(ABORT, 'candidate redaction diff is invalid'); END;
CREATE TRIGGER action_candidate_post_redaction_lock
BEFORE UPDATE ON action_candidate WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'candidate is immutable after redaction'); END;
CREATE TRIGGER action_candidate_reject_delete
BEFORE DELETE ON action_candidate
BEGIN SELECT RAISE(ABORT, 'candidate may not be deleted'); END;

CREATE TRIGGER knowledge_source_link_first_redaction_exact
BEFORE UPDATE ON knowledge_source_link
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.id = OLD.id
  AND NEW.campNoteId = OLD.campNoteId
  AND NEW.ingestionId = OLD.ingestionId
  AND NEW.locatorJson IS NULL
  AND NEW.createdAt = OLD.createdAt
  AND NEW.version = OLD.version + 1
  AND EXISTS (
    SELECT 1 FROM camp_note n
    JOIN ingestion_item i ON i.id = OLD.ingestionId
    JOIN camp_lifecycle l ON l.campId = i.campId
    JOIN camp_deletion_job j ON j.campId = i.campId
    WHERE n.id = OLD.campNoteId AND n.campId = i.campId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN SELECT RAISE(ABORT, 'knowledge source redaction diff is invalid'); END;
CREATE TRIGGER knowledge_source_link_post_redaction_lock
BEFORE UPDATE ON knowledge_source_link WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'knowledge source is immutable after redaction'); END;
CREATE TRIGGER knowledge_source_link_reject_delete
BEFORE DELETE ON knowledge_source_link
BEGIN SELECT RAISE(ABORT, 'knowledge source may not be deleted'); END;

CREATE TRIGGER schedule_fire_first_redaction_exact
BEFORE UPDATE ON schedule_fire
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.id = OLD.id
  AND NEW.scheduleId = OLD.scheduleId
  AND NEW.templateId = OLD.templateId
  AND NEW.slotKey = OLD.slotKey
  AND NEW.scheduledAt = OLD.scheduledAt
  AND NEW.replayOfFireId IS OLD.replayOfFireId
  AND NEW.replayIdempotencyKey IS OLD.replayIdempotencyKey
  AND NEW.replayPayloadHash IS OLD.replayPayloadHash
  AND NEW.state = OLD.state
  AND NEW.missionId IS OLD.missionId
  AND NEW.traceId = OLD.traceId
  AND NEW.errorCode IS OLD.errorCode
  AND NEW.errorMessage IS NULL
  AND NEW.createdAt = OLD.createdAt
  AND EXISTS (
    SELECT 1 FROM schedule s
    JOIN mission_template t ON t.id = s.templateId
    JOIN camp_lifecycle l ON l.campId = t.campId
    JOIN camp_deletion_job j ON j.campId = t.campId
    WHERE s.id = OLD.scheduleId
      AND s.templateId = OLD.templateId
      AND l.state = 'deleting' AND j.state = 'finalizing'
      AND (
        OLD.missionId IS NULL
        OR EXISTS (
          SELECT 1 FROM mission m
          JOIN squad q ON q.id = m.squadId
          WHERE m.id = OLD.missionId AND q.campId = t.campId
        )
      )
      AND (
        OLD.replayOfFireId IS NULL
        OR EXISTS (
          SELECT 1 FROM schedule_fire parent
          WHERE parent.id = OLD.replayOfFireId
            AND parent.scheduleId = OLD.scheduleId
            AND parent.templateId = OLD.templateId
        )
      )
  )
)
BEGIN SELECT RAISE(ABORT, 'schedule fire redaction diff is invalid'); END;
CREATE TRIGGER schedule_fire_post_redaction_lock
BEFORE UPDATE ON schedule_fire WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'schedule fire is immutable after redaction'); END;
CREATE TRIGGER schedule_fire_reject_delete
BEFORE DELETE ON schedule_fire
BEGIN SELECT RAISE(ABORT, 'schedule fire may not be deleted'); END;

CREATE TRIGGER failure_record_first_redaction_exact
BEFORE UPDATE ON failure_record
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.id = OLD.id
  AND NEW.operation = OLD.operation
  AND NEW.scopeKind = OLD.scopeKind
  AND NEW.campId IS OLD.campId
  AND NEW.scopeType = OLD.scopeType
  AND NEW.scopeId = OLD.scopeId
  AND NEW.severity = OLD.severity
  AND NEW.errorCode = OLD.errorCode
  AND NEW.userMessage = '[deleted]'
  AND NEW.diagnosticJson = '{}'
  AND NEW.state = OLD.state
  AND NEW.firstSeenAt = OLD.firstSeenAt
  AND NEW.lastSeenAt = OLD.lastSeenAt
  AND NEW.occurrenceCount = OLD.occurrenceCount
  AND NEW.resolvedAt IS OLD.resolvedAt
  AND OLD.scopeKind = 'camp' AND OLD.campId IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM camp_lifecycle l
    JOIN camp_deletion_job j ON j.campId = l.campId
    WHERE l.campId = OLD.campId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN SELECT RAISE(ABORT, 'failure record redaction diff is invalid'); END;
CREATE TRIGGER failure_record_post_redaction_lock
BEFORE UPDATE ON failure_record WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'failure record is immutable after redaction'); END;
CREATE TRIGGER failure_record_reject_delete
BEFORE DELETE ON failure_record
BEGIN SELECT RAISE(ABORT, 'failure record may not be deleted'); END;

CREATE TRIGGER context_degradation_first_redaction_exact
BEFORE UPDATE ON context_degradation
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.id = OLD.id
  AND NEW.missionId IS OLD.missionId
  AND NEW.cardId IS OLD.cardId
  AND NEW.dependencyType = OLD.dependencyType
  AND NEW.dependencyId = OLD.dependencyId
  AND NEW.policy = OLD.policy
  AND NEW.traceId = OLD.traceId
  AND NEW.detail = '[deleted]'
  AND NEW.createdAt = OLD.createdAt
  AND EXISTS (
    SELECT 1 FROM camp_lifecycle l
    JOIN camp_deletion_job j ON j.campId = l.campId
    WHERE l.state = 'deleting' AND j.state = 'finalizing'
      AND (
        EXISTS (
          SELECT 1 FROM mission m JOIN squad s ON s.id = m.squadId
          WHERE m.id = OLD.missionId AND s.campId = l.campId
        )
        OR EXISTS (
          SELECT 1 FROM card c
          JOIN mission m ON m.id = c.missionId
          JOIN squad s ON s.id = m.squadId
          WHERE c.id = OLD.cardId AND s.campId = l.campId
        )
      )
      AND NOT EXISTS (
        SELECT 1 FROM mission m JOIN squad s ON s.id = m.squadId
        WHERE m.id = OLD.missionId AND s.campId <> l.campId
      )
      AND NOT EXISTS (
        SELECT 1 FROM card c
        JOIN mission m ON m.id = c.missionId
        JOIN squad s ON s.id = m.squadId
        WHERE c.id = OLD.cardId AND s.campId <> l.campId
      )
  )
)
BEGIN SELECT RAISE(ABORT, 'degradation redaction diff is invalid'); END;
CREATE TRIGGER context_degradation_post_redaction_lock
BEFORE UPDATE ON context_degradation WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'degradation is immutable after redaction'); END;
CREATE TRIGGER context_degradation_reject_delete
BEFORE DELETE ON context_degradation
BEGIN SELECT RAISE(ABORT, 'degradation may not be deleted'); END;

CREATE TRIGGER inbox_message_first_redaction_exact
BEFORE UPDATE ON inbox_message
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.id = OLD.id
  AND NEW.campId = OLD.campId AND OLD.campId IS NOT NULL
  AND NEW.sourceDeviceId = '[deleted]'
  AND NEW.idempotencyKey = OLD.idempotencyKey
  AND NEW.payloadJson = '{}'
  AND NEW.payloadHash = OLD.payloadHash
  AND NEW.state = 'rejected'
  AND NEW.receivedAt = OLD.receivedAt
  AND NEW.appliedAt IS OLD.appliedAt
  AND NEW.errorCode = 'camp_deleted'
  AND NEW.version = OLD.version + 1
  AND EXISTS (
    SELECT 1 FROM camp_lifecycle l
    JOIN camp_deletion_job j ON j.campId = l.campId
    WHERE l.campId = OLD.campId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN SELECT RAISE(ABORT, 'inbox redaction diff is invalid'); END;
CREATE TRIGGER inbox_message_post_redaction_lock
BEFORE UPDATE ON inbox_message WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'inbox row is immutable after redaction'); END;
CREATE TRIGGER inbox_message_reject_delete
BEFORE DELETE ON inbox_message
BEGIN SELECT RAISE(ABORT, 'inbox row may not be deleted'); END;

CREATE TRIGGER approval_grant_first_redaction_exact
BEFORE UPDATE ON approval_grant
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.id = OLD.id
  AND NEW.version = OLD.version + 1
  AND NEW.scopeVersion = OLD.scopeVersion
  AND NEW.grantorActorType = OLD.grantorActorType
  AND NEW.grantorActorId = '[deleted]'
  AND NEW.grantorPolicyId IS NULL
  AND NEW.grantorPolicyVersion IS NULL
  AND NEW.grantorPolicyHash IS NULL
  AND NEW.granteeType = OLD.granteeType
  AND NEW.granteeId = OLD.granteeId
  AND NEW.capability = OLD.capability
  AND NEW.campId = OLD.campId
  AND NEW.cardId = OLD.cardId
  AND NEW.toolId = OLD.toolId
  AND NEW.approvedInputHash = OLD.approvedInputHash
  AND NEW.purpose = '[deleted]'
  AND NEW.dataLevel = OLD.dataLevel
  AND NEW.adapterReplayClass = OLD.adapterReplayClass
  AND NEW.validFrom = OLD.validFrom
  AND NEW.validUntil = OLD.validUntil
  AND NEW.maxUses = OLD.maxUses
  AND NEW.usedCount = OLD.usedCount
  AND (
    (OLD.status = 'active'
      AND NEW.status = 'revoked' AND NEW.revokedAt = NEW.redactedAt)
    OR
    (OLD.status IN ('exhausted','revoked','expired')
      AND NEW.status = OLD.status AND NEW.revokedAt IS OLD.revokedAt)
  )
  AND NEW.createdAt = OLD.createdAt
  AND NEW.updatedAt = NEW.redactedAt
  AND EXISTS (
    SELECT 1 FROM camp_lifecycle l
    JOIN camp_deletion_job j ON j.campId = l.campId
    WHERE l.campId = OLD.campId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN SELECT RAISE(ABORT, 'grant redaction diff is invalid'); END;
CREATE TRIGGER approval_grant_post_redaction_lock
BEFORE UPDATE ON approval_grant WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'grant is immutable after redaction'); END;
CREATE TRIGGER approval_grant_reject_delete
BEFORE DELETE ON approval_grant
BEGIN SELECT RAISE(ABORT, 'grant may not be deleted'); END;
CREATE TRIGGER approval_grant_use_first_redaction_exact
BEFORE UPDATE ON approval_grant_use
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.id = OLD.id AND NEW.grantId = OLD.grantId
  AND NEW.idempotencyKey = OLD.idempotencyKey
  AND NEW.toolId = OLD.toolId AND NEW.inputHash = OLD.inputHash
  AND NEW.adapterId = OLD.adapterId
  AND NEW.adapterReplayClass = OLD.adapterReplayClass
  AND NEW.state = OLD.state AND NEW.adapterOperationId IS NULL
  AND NEW.version = OLD.version + 1
  AND NEW.reservedAt = OLD.reservedAt
  AND NEW.dispatchIntentAt IS OLD.dispatchIntentAt
  AND NEW.adapterAcceptedAt IS OLD.adapterAcceptedAt
  AND NEW.finishedAt IS OLD.finishedAt
  AND OLD.state IN ('succeeded','failedFinal','released','abandonedUnknown')
  AND EXISTS (
    SELECT 1 FROM approval_grant g
    JOIN camp_lifecycle l ON l.campId = g.campId
    JOIN camp_deletion_job j ON j.campId = g.campId
    WHERE g.id = OLD.grantId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN
  SELECT RAISE(ABORT, 'grant use redaction diff is invalid');
END;
CREATE TRIGGER approval_grant_use_post_redaction_lock
BEFORE UPDATE ON approval_grant_use WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'grant use is immutable after redaction'); END;
CREATE TRIGGER approval_grant_use_reject_delete
BEFORE DELETE ON approval_grant_use
BEGIN SELECT RAISE(ABORT, 'grant use may not be deleted'); END;

CREATE TRIGGER event_require_typed_scope
AFTER INSERT ON event
WHEN NOT EXISTS (
  SELECT 1 FROM camp_event_scope s
  WHERE s.sourceTable = 'event' AND s.eventId = NEW.id
)
BEGIN
  SELECT RAISE(ABORT, 'legacy event requires typed scope');
END;
CREATE TRIGGER domain_event_require_matching_scope
AFTER INSERT ON domain_event
WHEN NOT EXISTS (
  SELECT 1 FROM camp_event_scope s
  WHERE s.sourceTable = 'domain_event' AND s.eventId = NEW.id
    AND s.scopeKind = 'camp' AND s.campId = NEW.campId
)
BEGIN
  SELECT RAISE(ABORT, 'domain event requires matching Camp scope');
END;

CREATE TRIGGER camp_event_scope_reject_update_except_redaction
BEFORE UPDATE ON camp_event_scope
WHEN NOT (
  NEW.sourceTable = OLD.sourceTable
  AND NEW.eventId = OLD.eventId
  AND NEW.scopeKind = OLD.scopeKind
  AND NEW.campId IS OLD.campId
  AND OLD.payloadRedactedAt IS NULL
  AND NEW.payloadRedactedAt IS NOT NULL
  AND OLD.sourceTable = 'event'
  AND OLD.scopeKind = 'camp'
  AND EXISTS (
    SELECT 1 FROM camp_lifecycle l
    JOIN camp_deletion_job j ON j.campId = l.campId
    WHERE l.campId = OLD.campId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN
  SELECT RAISE(ABORT, 'event scope is immutable except final redaction');
END;
CREATE TRIGGER camp_event_scope_reject_delete
BEFORE DELETE ON camp_event_scope
BEGIN
  SELECT RAISE(ABORT, 'event scope is immutable');
END;

CREATE TRIGGER event_reject_update_except_camp_redaction
BEFORE UPDATE ON event
WHEN NOT (
  NEW.id = OLD.id
  AND NEW.missionId IS OLD.missionId
  AND NEW.cardId IS OLD.cardId
  AND NEW.runId IS OLD.runId
  AND NEW.kind = OLD.kind
  AND NEW.createdAt = OLD.createdAt
  AND OLD.payloadJson <> '{"redacted":"camp_deleted"}'
  AND NEW.payloadJson = '{"redacted":"camp_deleted"}'
  AND EXISTS (
    SELECT 1 FROM camp_event_scope s
    JOIN camp_lifecycle l ON l.campId = s.campId
    JOIN camp_deletion_job j ON j.campId = s.campId
    WHERE s.sourceTable = 'event' AND s.eventId = OLD.id
      AND s.scopeKind = 'camp' AND s.payloadRedactedAt IS NOT NULL
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN
  SELECT RAISE(ABORT, 'event is append-only');
END;

CREATE TRIGGER durable_work_attempt_event_reject_update_except_camp_redaction
BEFORE UPDATE ON durable_work_attempt_event
WHEN NOT (
  NEW.id = OLD.id
  AND NEW.workId = OLD.workId
  AND NEW.attempt = OLD.attempt
  AND NEW.sequence = OLD.sequence
  AND NEW.eventKind = OLD.eventKind
  AND NEW.providerDispatchId IS OLD.providerDispatchId
  AND NEW.workerId = OLD.workerId
  AND NEW.workVersion = OLD.workVersion
  AND NEW.resultingWorkState = OLD.resultingWorkState
  AND NEW.errorCode IS OLD.errorCode
  AND NEW.errorMessage IS NULL
  AND NEW.occurredAt = OLD.occurredAt
  AND OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM durable_work w
    JOIN camp_lifecycle l ON l.campId = w.campId
    JOIN camp_deletion_job j ON j.campId = w.campId
    WHERE w.id = OLD.workId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN
  SELECT RAISE(ABORT, 'durable_work_attempt_event is append-only');
END;
CREATE TRIGGER durable_work_attempt_event_reject_delete
BEFORE DELETE ON durable_work_attempt_event
BEGIN
  SELECT RAISE(ABORT, 'durable_work_attempt_event is append-only');
END;

-- The three v15 DELETE guards remain installed.  Their UPDATE guards were
-- dropped in the ordered post-barrier block and are replaced here by the exact
-- finalizing exceptions.
CREATE TRIGGER verification_record_reject_update_except_camp_redaction
BEFORE UPDATE ON verification_record
WHEN NOT (
  NEW.id = OLD.id
  AND NEW.commandIdempotencyKey = OLD.commandIdempotencyKey
  AND NEW.contractId = OLD.contractId
  AND NEW.contractVersion = OLD.contractVersion
  AND NEW.contractHash = OLD.contractHash
  AND NEW.requirementId = OLD.requirementId
  AND NEW.requirementVersion = OLD.requirementVersion
  AND NEW.requirementHash = OLD.requirementHash
  AND NEW.outcomeId = OLD.outcomeId
  AND NEW.outcomeVersion = OLD.outcomeVersion
  AND NEW.outcomeHash = OLD.outcomeHash
  AND NEW.verifierType = OLD.verifierType
  AND NEW.verifierId = OLD.verifierId
  AND NEW.method = OLD.method
  AND NEW.ruleId = OLD.ruleId
  AND NEW.ruleVersion = OLD.ruleVersion
  AND NEW.environmentJson = '{}'
  AND NEW.commandOrRuleJson = '{}'
  AND NEW.rawResultRef IS NULL
  AND NEW.evidenceHash = OLD.evidenceHash
  AND NEW.result = OLD.result
  AND NEW.supersedesVerificationId IS OLD.supersedesVerificationId
  AND NEW.createdAt = OLD.createdAt
  AND OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM outcome o
    JOIN goal_controller g ON g.id = o.goalId
    JOIN camp_lifecycle l ON l.campId = g.campId
    JOIN camp_deletion_job j ON j.campId = g.campId
    WHERE o.id = OLD.outcomeId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN
  SELECT RAISE(ABORT, 'verification_record is append-only');
END;

CREATE TRIGGER acceptance_record_reject_update_except_camp_redaction
BEFORE UPDATE ON acceptance_record
WHEN NOT (
  NEW.id = OLD.id
  AND NEW.commandIdempotencyKey = OLD.commandIdempotencyKey
  AND NEW.contractId = OLD.contractId
  AND NEW.contractVersion = OLD.contractVersion
  AND NEW.contractHash = OLD.contractHash
  AND NEW.outcomeId = OLD.outcomeId
  AND NEW.outcomeVersion = OLD.outcomeVersion
  AND NEW.outcomeHash = OLD.outcomeHash
  AND NEW.subjectType = OLD.subjectType
  AND NEW.subjectId = OLD.subjectId
  AND NEW.policyId IS OLD.policyId
  AND NEW.policyVersion IS OLD.policyVersion
  AND NEW.decision = OLD.decision
  AND NEW.reason = '[deleted]'
  AND NEW.supersedesAcceptanceId IS OLD.supersedesAcceptanceId
  AND NEW.createdAt = OLD.createdAt
  AND OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM outcome o
    JOIN goal_controller g ON g.id = o.goalId
    JOIN camp_lifecycle l ON l.campId = g.campId
    JOIN camp_deletion_job j ON j.campId = g.campId
    WHERE o.id = OLD.outcomeId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN
  SELECT RAISE(ABORT, 'acceptance_record is append-only');
END;

CREATE TRIGGER external_operation_receipt_reject_update_except_camp_redaction
BEFORE UPDATE ON external_operation_receipt
WHEN NOT (
  NEW.id = OLD.id
  AND NEW.grantUseId = OLD.grantUseId
  AND NEW.receiptIdempotencyKey = OLD.receiptIdempotencyKey
  AND NEW.ordinal = OLD.ordinal
  AND NEW.phase = OLD.phase
  AND NEW.result = OLD.result
  AND NEW.adapterOperationId IS NULL
  AND NEW.receiptRef IS NULL
  AND NEW.receiptJson = '{"redacted":"camp_deleted"}'
  AND NEW.receiptHash = OLD.receiptHash
  AND NEW.authorityKind = OLD.authorityKind
  AND NEW.authorityId = '[deleted]'
  AND NEW.createdAt = OLD.createdAt
  AND OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM approval_grant_use u
    JOIN approval_grant g ON g.id = u.grantId
    JOIN camp_lifecycle l ON l.campId = g.campId
    JOIN camp_deletion_job j ON j.campId = g.campId
    WHERE u.id = OLD.grantUseId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN
  SELECT RAISE(ABORT, 'external_operation_receipt is append-only');
END;

```

两枚 DELETE trigger 中
`agentloop_active_ingestion_deletion_permit_v1` 的名字、step discriminator与参数顺序
都是规范的一部分，exact arity只能是 `deleteIngestion=53`、
`deleteResult=63`。两者都先核专列 CommandEnvelope、Store recordedAt与 initial
outbox shape；`deleteResult` 再从全部 `i.*` 与 `OLD.*` 字段分别重建
ingestion/result `CanonicalJSONV1` snapshot并比较 permit + receipt + event；
`deleteIngestion` 必须重建全部 `OLD.*` ingestion snapshot、确认 resultMutation 已按
0|1 exact完成后才消费 source step。function注册固定为 Permit owner中的 raw
`sqlite3_create_function_v2`：`nArg=-1`、flags exact `SQLITE_UTF8`、非
deterministic、非 `SQLITE_DIRECTONLY`，不得使用 GRDB `DatabaseFunction`；`xFunc`
不得 query/reenter DB或在 context/cell外持久化任何输入，`xDestroy`拥有唯一 retained
context释放与 connection真实销毁清理。
没有注册 UDF 的 external SQLite CLI 即使构造出 matching
receipt/scope/event/outbox，DELETE仍必须以 `no such function` 或 trigger abort
fail closed；literal SQL fence只负责 schema/trigger count与这种 no-permit负例。
SQLite 3.51/3.52 的真实 GRDB runner必须走 `AppDatabase` 的同一 connection
registration，并负责合法三路径、完整/不完整 receipt→scope→event→outbox→mutation
sequence、错误 arity/type/connection/transaction/generation/reuse、snapshot重算、
afterNextTransaction commit/rollback invalidation与 rollback正负例。两枚 guard只是
原位增加 UDF/outbox gate，不新增 trigger；through-v16/v17 count仍为 67/84。

backfill ID 固定：Cow ID 复用 Companion ID；Residency ID 为
`legacy-residency:<cowId>:<campId>`，idempotency key 为
`legacy:<cowId>:<campId>`。损坏 Camp FK、重复 live residency 或 non-null campId
找不到 Camp 时 migration 抛错并完整回滚；`campId IS NULL` 不插 residency。
`camp_lifecycle` 必须先 backfill version 1；上面 normative rebuild 关闭 archived
Camp 的全部 nonterminal work/开放 attempt/event 后，给每条 work 绑定无 default
`campLifecycleVersion=1`。active Camp work保留；terminal history保留；任何 early
campDeletion row、未被关闭的 archived active row 或 copy count mismatch 使 migration
rollback。

v16/v17 的实际 Swift migration顺序是规范的一部分：先创建完整 table/index graph，
完成 owning-table rebuild/rename与全部 copy/backfill/resolver/count/FK assertion；
v16 barrier成功后，再按 fence中的固定顺序、无 `IF EXISTS` 删除四个 surviving-table
UPDATE guards；四项之后不得再执行任何 DML/resolver/backfill/assertion，最后才创建
**任何** trigger（不区分 same-table/cross-table）。owning-table
`durable_work_attempt_event_reject_update` 仍只在 rebuild前原位 drop，因此五个
`DROP TRIGGER` 的最大 statement ordinal都必须小于第一个 `CREATE TRIGGER` 的最小
ordinal。v16不得在 `camp_deletion_job` 创建或 barrier完成前安装 provider redaction
trigger；job/work、event/scope、privacy triggers全部在完整 graph和五个 drops后统一
安装。v17同样先建立 Engine/Proposal/Artifact/Discussion/cleanup ledger并通过
barrier，再安装任何 trigger。不得依赖 SQLite 对 unresolved trigger table 的宽松
行为。normative fence完成后 trigger count固定为 through-v16 `67`、
through-v17 `84`。checkpoint count 固定为 v11=`2`、v12-durable=`4`、
v12-schedule=`4`、v13=`4`、v14=`8`、v15=`16`、v16=`67`、v17=`84`：
v12 attempt-event 两枚 introduction guards 在 v16 owning-table rebuild 中被
special UPDATE + 同名 DELETE 替换，最终净增为零；相对旧 56 图的十一枚最终增量
精确来自 v14 command/event `+4`、v15 invalidation pair 与三个 preserved DELETE
`+5`、v16 memory dependency `+2`。migration compatibility test必须同时检查 literal
fence与真实 Swift migration trace，并按 SQL statement ordinal证明：

- barrier < 四项 fixed-order surviving-table drops < first `CREATE TRIGGER`；
- 每个 `CREATE TRIGGER` 都晚于同 fence最后一条
  `CREATE TABLE|CREATE INDEX|ALTER TABLE|DROP TABLE|DROP TRIGGER|table rename`
  statement；五个 `DROP TRIGGER` 全计入，不得只检查 structural drops；
- 四项 drop逐字无 `IF EXISTS`，last drop后到first create之间无
  DML/resolver/backfill/assertion；
- 每个 drop边界、last-drop→first-create边界及 trigger installation中途注入失败，
  都逐字恢复 migration前 v15 schema/data与16-trigger snapshot。

最终 `sqlite_master` count本身不能替代这些 ordinal/rollback证明。

v16 durable-work rebuild 还不得依赖 `ALTER TABLE ... RENAME` 是否改写子表 FK：
先把 attempt/event 行复制到无 FK 的 transaction-local TEMP staging table，drop 旧
child/parent，把 `durable_work_v16` 改为最终 `durable_work`，再直接以最终表名创建
`durable_work_attempt`、`camp_provider_dispatch`、`durable_work_attempt_event`
并回填。迁移断言必须逐项读取 `PRAGMA foreign_key_list`，任何 FK target 含
`_v16`、`_legacy` 或 staging 名立即 rollback。

Swift migration 在提交前必须逐条运行 §14.2 唯一
`LegacyContentScopeResolver/LegacyEventScopeResolver` 并填满三个 scope table：
chat/note/event source count 必须分别等于 scope count；`domain_event` row必须 exact
matching Camp。`EventKind.allPersistedKinds` 与 resolver key set 必须相等；unknown、
dangling、malformed、global/Camp shape mismatch、两条 evidence 不同 Camp 均
rollback，不提供 fallback。`phaseCursorJson` 必须是 safe canonical object。

v16 后，`DomainEventStore` 与 package-internal `appendLegacyEventAndScope` 都先在
同 transaction 插 typed scope，再插 event；AFTER INSERT trigger验证 exact row，
scope/event任一失败全回滚。thread/note raw insert同样封闭为 typed scope helper。
deletion redaction先 CAS scope.redactedAt，再更新 payload/append-only row，且必须在
同一 finalizing transaction；普通/二次/额外 diff/全部 DELETE继续 abort。

provider dispatch Store还强校验：work kind与 operationKind相同、Camp/lifecycle/
attempt均匹配且 attempt open；`providerResponseReturned.sequence` 大于对应
`providerDispatchStarted.sequence`；dispatchAttempt>1 exact replay previous
abandoned；returned/consumed 唯一 checkpoint。DDL不能跨表表达的这些不变量都有
transaction tests。

同一真实 GRDB migrator 必须在 SQLite 3.51 与 3.52 两条 lane 运行
fresh、v11 sparse/populated、v15 empty/populated → v17；populated fixture 至少含
两 Camps、archived Camp queued/running/retryScheduled work、open attempt/event、
terminal history、Verification/Acceptance/receipt、legacy DM/Guide/note/event
scope。early campDeletion、dangling/cross-Camp/malformed scope 是 rollback 负例。
每条 lane 都验证第二次启动/replay、精确 tables/indexes/triggers/row counts、
`foreign_key_check` 无行、`integrity_check='ok'`，失败前后 schema/data snapshot
逐字一致。

### 18.7 `v17-p1-engine-coordination`

```sql
CREATE TABLE engine_session (
  id TEXT PRIMARY KEY NOT NULL,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  adapterId TEXT NOT NULL,
  adapterVersion TEXT NOT NULL,
  profileId TEXT NOT NULL REFERENCES runtime_profile(id) ON DELETE RESTRICT,
  externalSessionId TEXT,
  workspaceHash TEXT NOT NULL CHECK (length(workspaceHash) = 64),
  sessionScopeJson TEXT NOT NULL,
  sessionScopeHash TEXT NOT NULL CHECK (length(sessionScopeHash) = 64),
  state TEXT NOT NULL CHECK (state IN ('active','closed','invalid')),
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  redactedAt DATETIME,
  CHECK (
    (state IN ('active','closed') AND externalSessionId IS NOT NULL
      AND redactedAt IS NULL)
    OR
    (state = 'invalid')
  ),
  CHECK (
    redactedAt IS NULL
    OR
    (state = 'invalid' AND externalSessionId IS NULL
      AND sessionScopeJson = '{}')
  )
);
CREATE UNIQUE INDEX engine_session_external_identity
  ON engine_session(adapterId, profileId, externalSessionId)
  WHERE externalSessionId IS NOT NULL;
CREATE INDEX engine_session_resume
  ON engine_session(campId, profileId, adapterId, state, updatedAt);

CREATE TABLE engine_execution (
  id TEXT PRIMARY KEY NOT NULL,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  campLifecycleVersion INTEGER NOT NULL CHECK (campLifecycleVersion >= 1),
  idempotencyKey TEXT NOT NULL UNIQUE,
  runId TEXT NOT NULL UNIQUE REFERENCES run(id) ON DELETE RESTRICT,
  cardId TEXT NOT NULL REFERENCES card(id) ON DELETE RESTRICT,
  adapterId TEXT NOT NULL,
  adapterVersion TEXT NOT NULL,
  profileId TEXT NOT NULL REFERENCES runtime_profile(id) ON DELETE RESTRICT,
  engineKind TEXT NOT NULL,
  model TEXT NOT NULL,
  requestJson TEXT NOT NULL,
  requestHash TEXT NOT NULL CHECK (length(requestHash) = 64),
  contextJson TEXT NOT NULL,
  contextHash TEXT NOT NULL CHECK (length(contextHash) = 64),
  sessionScopeJson TEXT NOT NULL,
  sessionScopeHash TEXT NOT NULL CHECK (length(sessionScopeHash) = 64),
  sessionId TEXT REFERENCES engine_session(id) ON DELETE RESTRICT,
  replayClass TEXT NOT NULL CHECK
    (replayClass IN ('replaySafe','idempotencyKeyed','nonReplayable')),
  dispatchState TEXT NOT NULL CHECK
    (dispatchState IN ('prepared','started','sessionBound','terminalProposed','terminal')),
  state TEXT NOT NULL CHECK (state IN
    ('running','completed','blocked','failed','canceled')),
  terminalSubtype TEXT CHECK (terminalSubtype IS NULL OR terminalSubtype IN
    ('ordinary','needsHumanInput','engineProtocolError','externalEffectUnknown')),
  nextSequence INTEGER NOT NULL DEFAULT 0 CHECK (nextSequence >= 0),
  terminalReceiptIdempotencyKey TEXT
    REFERENCES domain_command_receipt(idempotencyKey) ON DELETE RESTRICT,
  terminalReceiptHash TEXT CHECK
    (terminalReceiptHash IS NULL OR
      (length(terminalReceiptHash) = 64
       AND terminalReceiptHash NOT GLOB '*[^0-9a-f]*')),
  inputTokens INTEGER NOT NULL DEFAULT 0 CHECK (inputTokens >= 0),
  outputTokens INTEGER NOT NULL DEFAULT 0 CHECK (outputTokens >= 0),
  cacheReadTokens INTEGER NOT NULL DEFAULT 0 CHECK (cacheReadTokens >= 0),
  costMicros INTEGER NOT NULL DEFAULT 0 CHECK (costMicros >= 0),
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  dispatchStartedAt DATETIME,
  cancellationRequestedAt DATETIME,
  cancellationReason TEXT,
  finishedAt DATETIME,
  redactedAt DATETIME,
  CHECK (
    (state = 'running'
      AND terminalReceiptIdempotencyKey IS NULL
      AND terminalReceiptHash IS NULL AND finishedAt IS NULL)
    OR
    (state <> 'running'
      AND terminalReceiptIdempotencyKey IS NOT NULL
      AND terminalReceiptHash IS NOT NULL AND finishedAt IS NOT NULL)
  ),
  CHECK (
    (state = 'running' AND dispatchState <> 'terminal')
    OR
    (state <> 'running' AND dispatchState = 'terminal')
  ),
  CHECK (
    (state = 'blocked' AND terminalSubtype IS NOT NULL)
    OR
    (state <> 'blocked' AND terminalSubtype IS NULL)
  ),
  CHECK (
    (dispatchState = 'prepared' AND dispatchStartedAt IS NULL
      AND state = 'running')
    OR
    (dispatchState IN ('started','sessionBound','terminalProposed')
      AND dispatchStartedAt IS NOT NULL AND state = 'running')
    OR
    (dispatchState = 'terminal'
      AND (
        (state = 'completed' AND dispatchStartedAt IS NOT NULL)
        OR
        (state = 'canceled'
          AND (dispatchStartedAt IS NOT NULL OR cancellationRequestedAt IS NOT NULL))
        OR
        state IN ('blocked','failed')
      ))
  ),
  CHECK (
    (sessionId IS NULL AND dispatchState <> 'sessionBound')
    OR
    (sessionId IS NOT NULL AND dispatchState IN ('sessionBound','terminalProposed','terminal'))
  ),
  CHECK (
    (cancellationRequestedAt IS NULL AND cancellationReason IS NULL)
    OR
    (cancellationRequestedAt IS NOT NULL AND cancellationReason IS NOT NULL)
  ),
  CHECK (
    redactedAt IS NULL
    OR
    (state <> 'running' AND requestJson = '{}' AND contextJson = '{}'
      AND sessionScopeJson = '{}'
      AND (
        (cancellationRequestedAt IS NULL AND cancellationReason IS NULL)
        OR
        (cancellationRequestedAt IS NOT NULL
          AND cancellationReason = 'camp_deleted')
      ))
  )
);
CREATE INDEX engine_execution_recovery
  ON engine_execution(campId, state, dispatchState, updatedAt);
CREATE INDEX engine_execution_card
  ON engine_execution(cardId, createdAt);

CREATE TABLE engine_terminal_proposal (
  id TEXT PRIMARY KEY NOT NULL,
  executionId TEXT NOT NULL UNIQUE
    REFERENCES engine_execution(id) ON DELETE RESTRICT,
  terminalIdempotencyKey TEXT NOT NULL UNIQUE,
  sequence INTEGER NOT NULL CHECK (sequence >= 0),
  terminalKind TEXT NOT NULL CHECK
    (terminalKind IN ('completed','blocked','failed','canceled')),
  terminalSubtype TEXT CHECK (terminalSubtype IS NULL OR terminalSubtype IN
    ('ordinary','needsHumanInput','engineProtocolError','externalEffectUnknown')),
  proposalJson TEXT NOT NULL,
  proposalHash TEXT NOT NULL CHECK (
    length(proposalHash) = 64 AND proposalHash NOT GLOB '*[^0-9a-f]*'
  ),
  payloadJson TEXT NOT NULL,
  payloadHash TEXT NOT NULL CHECK (length(payloadHash) = 64),
  artifactManifestJson TEXT NOT NULL,
  artifactManifestHash TEXT NOT NULL CHECK (length(artifactManifestHash) = 64),
  state TEXT NOT NULL CHECK (state IN ('pending','committed','invalid')),
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  createdAt DATETIME NOT NULL,
  committedAt DATETIME,
  invalidReason TEXT,
  invalidatedAt DATETIME,
  redactedAt DATETIME,
  CHECK (
    (terminalKind = 'blocked' AND terminalSubtype IS NOT NULL)
    OR
    (terminalKind <> 'blocked' AND terminalSubtype IS NULL)
  ),
  CHECK (
    (state = 'pending' AND committedAt IS NULL
      AND invalidReason IS NULL AND invalidatedAt IS NULL)
    OR
    (state = 'committed' AND committedAt IS NOT NULL
      AND invalidReason IS NULL AND invalidatedAt IS NULL)
    OR
    (state = 'invalid' AND committedAt IS NULL
      AND invalidReason IS NOT NULL AND invalidatedAt IS NOT NULL)
  ),
  CHECK (
    redactedAt IS NULL
    OR
    (state IN ('committed','invalid')
      AND proposalJson = '{}' AND payloadJson = '{}'
      AND artifactManifestJson = '[]'
      AND (
        (state = 'committed' AND invalidReason IS NULL)
        OR
        (state = 'invalid' AND invalidReason = 'camp_deleted')
      ))
  )
);
CREATE INDEX engine_terminal_proposal_pending
  ON engine_terminal_proposal(state, createdAt);
CREATE TABLE artifact_blob (
  contentHash TEXT PRIMARY KEY NOT NULL CHECK (
    length(contentHash) = 64 AND contentHash NOT GLOB '*[^0-9a-f]*'
  ),
  byteCount INTEGER NOT NULL CHECK (byteCount >= 0),
  relativePath TEXT NOT NULL,
  state TEXT NOT NULL CHECK
    (state IN ('available','quarantined','deletedTombstone')),
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  createdAt DATETIME NOT NULL,
  verifiedAt DATETIME NOT NULL,
  deletedAt DATETIME,
  CHECK (
    (state = 'deletedTombstone' AND relativePath = '' AND deletedAt IS NOT NULL)
    OR
    (state <> 'deletedTombstone' AND relativePath <> '' AND deletedAt IS NULL)
  )
);
CREATE UNIQUE INDEX artifact_blob_path
  ON artifact_blob(relativePath) WHERE relativePath <> '';
CREATE INDEX artifact_blob_gc
  ON artifact_blob(state, createdAt);

CREATE TABLE engine_proposal_artifact (
  id TEXT PRIMARY KEY NOT NULL,
  proposalId TEXT NOT NULL
    REFERENCES engine_terminal_proposal(id) ON DELETE RESTRICT,
  artifactId TEXT NOT NULL,
  ordinal INTEGER NOT NULL CHECK (ordinal >= 0),
  sourceRelativePath TEXT NOT NULL,
  kind TEXT NOT NULL,
  label TEXT NOT NULL,
  byteCount INTEGER NOT NULL CHECK (byteCount >= 0),
  contentHash TEXT NOT NULL CHECK (
    length(contentHash) = 64 AND contentHash NOT GLOB '*[^0-9a-f]*'
  ),
  state TEXT NOT NULL CHECK (state IN ('declared','prepared')),
  preparedAt DATETIME,
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  redactedAt DATETIME,
  UNIQUE(proposalId, artifactId),
  UNIQUE(proposalId, ordinal),
  CHECK (
    (state = 'declared' AND preparedAt IS NULL)
    OR
    (state = 'prepared' AND preparedAt IS NOT NULL)
  ),
  CHECK (
    redactedAt IS NULL
    OR
    (sourceRelativePath = '' AND kind = 'tombstone' AND label = '[deleted]')
  )
);
CREATE INDEX engine_proposal_artifact_gc_root
  ON engine_proposal_artifact(contentHash, proposalId, state);
CREATE TABLE camp_deletion_proposal_blob (
  id TEXT PRIMARY KEY NOT NULL,
  jobId TEXT NOT NULL REFERENCES camp_deletion_job(id) ON DELETE RESTRICT,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  proposalArtifactId TEXT NOT NULL
    REFERENCES engine_proposal_artifact(id) ON DELETE RESTRICT,
  contentHash TEXT NOT NULL CHECK (
    length(contentHash) = 64 AND contentHash NOT GLOB '*[^0-9a-f]*'
  ),
  expectedBlobVersion INTEGER CHECK (
    expectedBlobVersion IS NULL OR expectedBlobVersion >= 1
  ),
  state TEXT NOT NULL CHECK (state IN
    ('pending','reserved','unlinkReady','retryableFailure',
     'retainedShared','deleted','alreadyAbsent')),
  attempt INTEGER NOT NULL DEFAULT 0 CHECK (attempt >= 0),
  lastErrorCode TEXT,
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  createdAt DATETIME NOT NULL,
  reservedAt DATETIME,
  finishedAt DATETIME,
  UNIQUE(jobId, proposalArtifactId),
  CHECK (
    (state IN ('pending','retryableFailure')
      AND reservedAt IS NULL AND finishedAt IS NULL)
    OR
    (state IN ('reserved','unlinkReady')
      AND reservedAt IS NOT NULL AND finishedAt IS NULL)
    OR
    (state IN ('retainedShared','deleted','alreadyAbsent')
      AND finishedAt IS NOT NULL)
  )
);
CREATE INDEX camp_deletion_proposal_blob_recovery
  ON camp_deletion_proposal_blob(jobId, state, contentHash);

CREATE TABLE artifact_blob_reference (
  artifactId TEXT PRIMARY KEY NOT NULL
    REFERENCES artifact(id) ON DELETE RESTRICT,
  proposalArtifactId TEXT NOT NULL UNIQUE
    REFERENCES engine_proposal_artifact(id) ON DELETE RESTRICT,
  executionId TEXT NOT NULL
    REFERENCES engine_execution(id) ON DELETE RESTRICT,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  contentHash TEXT NOT NULL
    REFERENCES artifact_blob(contentHash) ON DELETE RESTRICT,
  state TEXT NOT NULL CHECK (state IN ('active','tombstoned')),
  createdAt DATETIME NOT NULL,
  tombstonedAt DATETIME,
  CHECK (
    (state = 'active' AND tombstonedAt IS NULL)
    OR
    (state = 'tombstoned' AND tombstonedAt IS NOT NULL)
  )
);
CREATE INDEX artifact_blob_reference_live
  ON artifact_blob_reference(contentHash, state);
CREATE INDEX artifact_blob_reference_camp
  ON artifact_blob_reference(campId, state);

CREATE TABLE artifact_storage_origin (
  artifactId TEXT PRIMARY KEY NOT NULL
    REFERENCES artifact(id) ON DELETE RESTRICT,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  state TEXT NOT NULL DEFAULT 'active' CHECK
    (state IN ('active','tombstoned')),
  storageClass TEXT NOT NULL CHECK
    (storageClass IN ('managed','workspaceExternal','unresolved')),
  evidenceKind TEXT NOT NULL CHECK
    (evidenceKind IN
      ('typedPreparedArtifact','verifiedManagedRootCapability',
       'explicitWorkspaceExternal','verifiedOutsideAllManagedRoots',
       'legacyUnknown')),
  managedRootId TEXT,
  objectId TEXT,
  contentHash TEXT CHECK (
    contentHash IS NULL OR
    (length(contentHash) = 64 AND contentHash NOT GLOB '*[^0-9a-f]*')
  ),
  fileIdentityHash TEXT CHECK (
    fileIdentityHash IS NULL OR
    (length(fileIdentityHash) = 64
      AND fileIdentityHash NOT GLOB '*[^0-9a-f]*')
  ),
  originalRefHash TEXT NOT NULL CHECK (
    length(originalRefHash) = 64
    AND originalRefHash NOT GLOB '*[^0-9a-f]*'
  ),
  classificationEvidenceHash TEXT NOT NULL CHECK (
    length(classificationEvidenceHash) = 64
    AND classificationEvidenceHash NOT GLOB '*[^0-9a-f]*'
  ),
  terminalDisposition TEXT CHECK (
    terminalDisposition IS NULL OR terminalDisposition IN
      ('managedDeleted','managedAlreadyAbsent','managedSharedDetached',
       'workspaceExternalDetached','unresolvedDetached')
  ),
  terminalAuthorityHash TEXT CHECK (
    terminalAuthorityHash IS NULL OR
    (length(terminalAuthorityHash) = 64
      AND terminalAuthorityHash NOT GLOB '*[^0-9a-f]*')
  ),
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  classifiedAt DATETIME NOT NULL,
  redactedAt DATETIME,
  CHECK (
    (state = 'active' AND storageClass = 'managed'
      AND evidenceKind IN
        ('typedPreparedArtifact','verifiedManagedRootCapability')
      AND managedRootId IS NOT NULL AND objectId IS NOT NULL
      AND contentHash IS NOT NULL AND fileIdentityHash IS NOT NULL
      AND terminalDisposition IS NULL AND terminalAuthorityHash IS NULL
      AND redactedAt IS NULL)
    OR
    (state = 'active' AND storageClass = 'workspaceExternal'
      AND evidenceKind IN
        ('explicitWorkspaceExternal','verifiedOutsideAllManagedRoots')
      AND managedRootId IS NULL AND objectId IS NULL
      AND contentHash IS NULL AND fileIdentityHash IS NULL
      AND terminalDisposition IS NULL AND terminalAuthorityHash IS NULL
      AND redactedAt IS NULL)
    OR
    (state = 'active' AND storageClass = 'unresolved'
      AND evidenceKind = 'legacyUnknown'
      AND managedRootId IS NULL AND objectId IS NULL
      AND contentHash IS NULL AND fileIdentityHash IS NULL
      AND terminalDisposition IS NULL AND terminalAuthorityHash IS NULL
      AND redactedAt IS NULL)
    OR
    (state = 'tombstoned' AND storageClass = 'managed'
      AND evidenceKind IN
        ('typedPreparedArtifact','verifiedManagedRootCapability')
      AND managedRootId IS NULL AND objectId IS NULL
      AND contentHash IS NOT NULL AND fileIdentityHash IS NOT NULL
      AND terminalDisposition IN
        ('managedDeleted','managedAlreadyAbsent','managedSharedDetached')
      AND terminalAuthorityHash IS NOT NULL AND redactedAt IS NOT NULL)
    OR
    (state = 'tombstoned' AND storageClass = 'workspaceExternal'
      AND evidenceKind IN
        ('explicitWorkspaceExternal','verifiedOutsideAllManagedRoots')
      AND managedRootId IS NULL AND objectId IS NULL
      AND contentHash IS NULL AND fileIdentityHash IS NULL
      AND terminalDisposition = 'workspaceExternalDetached'
      AND terminalAuthorityHash IS NOT NULL AND redactedAt IS NOT NULL)
    OR
    (state = 'tombstoned' AND storageClass = 'unresolved'
      AND evidenceKind = 'legacyUnknown'
      AND managedRootId IS NULL AND objectId IS NULL
      AND contentHash IS NULL AND fileIdentityHash IS NULL
      AND terminalDisposition = 'unresolvedDetached'
      AND terminalAuthorityHash IS NOT NULL AND redactedAt IS NOT NULL)
  )
);
CREATE INDEX artifact_storage_origin_camp
  ON artifact_storage_origin(campId, state, storageClass, classifiedAt);
CREATE TABLE discussion (
  id TEXT PRIMARY KEY NOT NULL,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  goalId TEXT REFERENCES goal_controller(id) ON DELETE RESTRICT,
  missionId TEXT REFERENCES mission(id) ON DELETE RESTRICT,
  cardId TEXT REFERENCES card(id) ON DELETE RESTRICT,
  purpose TEXT NOT NULL,
  participantActorIdsJson TEXT NOT NULL,
  maxRounds INTEGER NOT NULL CHECK (maxRounds BETWEEN 1 AND 3),
  tokenBudget INTEGER NOT NULL CHECK (tokenBudget > 0),
  spentTokens INTEGER NOT NULL DEFAULT 0 CHECK
    (spentTokens >= 0 AND spentTokens <= tokenBudget),
  status TEXT NOT NULL CHECK (status IN
    ('proposed','running','completed','blocked','canceled','failed')),
  requiredMaterialization TEXT NOT NULL CHECK (requiredMaterialization IN
    ('decision','handoff','outcome','verification','cardRevision','planRevision')),
  materializationType TEXT,
  materializationId TEXT,
  aggregateVersion INTEGER NOT NULL DEFAULT 1 CHECK (aggregateVersion >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  CHECK (goalId IS NOT NULL OR missionId IS NOT NULL OR cardId IS NOT NULL),
  CHECK (
    (status = 'completed'
      AND materializationType = requiredMaterialization
      AND materializationId IS NOT NULL)
    OR
    (status <> 'completed'
      AND materializationType IS NULL AND materializationId IS NULL)
  )
);

CREATE TABLE discussion_turn (
  id TEXT PRIMARY KEY NOT NULL,
  discussionId TEXT NOT NULL REFERENCES discussion(id) ON DELETE RESTRICT,
  round INTEGER NOT NULL CHECK (round BETWEEN 1 AND 3),
  sequence INTEGER NOT NULL CHECK (sequence >= 0),
  speakerActorId TEXT NOT NULL,
  contentRef TEXT NOT NULL,
  contentHash TEXT NOT NULL CHECK (length(contentHash) = 64),
  inputTokens INTEGER NOT NULL DEFAULT 0 CHECK (inputTokens >= 0),
  outputTokens INTEGER NOT NULL DEFAULT 0 CHECK (outputTokens >= 0),
  createdAt DATETIME NOT NULL,
  redactedAt DATETIME,
  UNIQUE(discussionId, sequence),
  CHECK (redactedAt IS NULL OR contentRef = '')
);
CREATE INDEX discussion_turn_round
  ON discussion_turn(discussionId, round, sequence);
CREATE TABLE attention_item (
  id TEXT PRIMARY KEY NOT NULL,
  sourceEventId TEXT NOT NULL REFERENCES domain_event(id) ON DELETE RESTRICT,
  level TEXT NOT NULL CHECK
    (level IN ('recordOnly','summary','needsAction','urgent')),
  dedupeKey TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL CHECK
    (status IN ('open','acknowledged','dismissed','resolved')),
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  goalId TEXT REFERENCES goal_controller(id) ON DELETE RESTRICT,
  missionId TEXT REFERENCES mission(id) ON DELETE RESTRICT,
  dueAt DATETIME,
  escalationAt DATETIME,
  aggregateVersion INTEGER NOT NULL DEFAULT 1 CHECK (aggregateVersion >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL
);
CREATE INDEX attention_item_open
  ON attention_item(status, level, dueAt, escalationAt);

CREATE TABLE growth_evidence (
  id TEXT PRIMARY KEY NOT NULL,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  track TEXT NOT NULL CHECK (track IN ('capability','relationship','world')),
  subjectType TEXT NOT NULL CHECK (subjectType IN ('cow','camp','world')),
  subjectId TEXT NOT NULL,
  outcomeId TEXT REFERENCES outcome(id) ON DELETE RESTRICT,
  outcomeVersion INTEGER,
  verificationId TEXT
    REFERENCES verification_record(id) ON DELETE RESTRICT,
  acceptanceId TEXT REFERENCES acceptance_record(id) ON DELETE RESTRICT,
  sourceEventId TEXT REFERENCES domain_event(id) ON DELETE RESTRICT,
  evidenceHash TEXT NOT NULL CHECK (length(evidenceHash) = 64),
  status TEXT NOT NULL CHECK (status IN ('proposed','active','invalidated')),
  invalidatedByEventId TEXT REFERENCES domain_event(id) ON DELETE RESTRICT,
  createdAt DATETIME NOT NULL,
  invalidatedAt DATETIME,
  CHECK (
    (track = 'capability'
      AND outcomeId IS NOT NULL AND outcomeVersion IS NOT NULL
      AND verificationId IS NOT NULL AND acceptanceId IS NOT NULL)
    OR
    (track IN ('relationship','world') AND sourceEventId IS NOT NULL)
  ),
  CHECK (
    (status = 'invalidated'
      AND invalidatedByEventId IS NOT NULL AND invalidatedAt IS NOT NULL)
    OR
    (status <> 'invalidated'
      AND invalidatedByEventId IS NULL AND invalidatedAt IS NULL)
  )
);
CREATE INDEX growth_evidence_subject
  ON growth_evidence(subjectType, subjectId, track, status);

-- MIGRATION PHASE BARRIER: the real Swift migrator performs legacy artifact
-- origin backfill plus count/FK assertions here.  Trigger installation is the
-- final phase and is skipped entirely if backfill/assertion fails.
-- Every v17 trigger is installed only after the complete
-- Engine/Artifact/Discussion/Attention/Growth table and index graph exists.
CREATE TRIGGER engine_session_first_redaction_exact
BEFORE UPDATE ON engine_session
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.id = OLD.id
  AND NEW.campId = OLD.campId
  AND NEW.adapterId = OLD.adapterId
  AND NEW.adapterVersion = OLD.adapterVersion
  AND NEW.profileId = OLD.profileId
  AND NEW.externalSessionId IS NULL
  AND NEW.workspaceHash = OLD.workspaceHash
  AND NEW.sessionScopeJson = '{}'
  AND NEW.sessionScopeHash = OLD.sessionScopeHash
  AND NEW.state = 'invalid'
  AND NEW.version = OLD.version + 1
  AND NEW.createdAt = OLD.createdAt
  AND NEW.updatedAt = NEW.redactedAt
  AND EXISTS (
    SELECT 1 FROM camp_lifecycle l
    JOIN camp_deletion_job j ON j.campId = l.campId
    WHERE l.campId = OLD.campId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN SELECT RAISE(ABORT, 'engine session redaction diff is invalid'); END;
CREATE TRIGGER engine_session_post_redaction_lock
BEFORE UPDATE ON engine_session WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'engine session is immutable after redaction'); END;
CREATE TRIGGER engine_session_reject_delete
BEFORE DELETE ON engine_session
BEGIN SELECT RAISE(ABORT, 'engine session may not be deleted'); END;

CREATE TRIGGER engine_execution_first_redaction_exact
BEFORE UPDATE ON engine_execution
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.id = OLD.id
  AND NEW.campId = OLD.campId
  AND NEW.campLifecycleVersion = OLD.campLifecycleVersion
  AND NEW.idempotencyKey = OLD.idempotencyKey
  AND NEW.runId = OLD.runId
  AND NEW.cardId = OLD.cardId
  AND NEW.adapterId = OLD.adapterId
  AND NEW.adapterVersion = OLD.adapterVersion
  AND NEW.profileId = OLD.profileId
  AND NEW.engineKind = OLD.engineKind
  AND NEW.model = OLD.model
  AND NEW.requestJson = '{}'
  AND NEW.requestHash = OLD.requestHash
  AND NEW.contextJson = '{}'
  AND NEW.contextHash = OLD.contextHash
  AND NEW.sessionScopeJson = '{}'
  AND NEW.sessionScopeHash = OLD.sessionScopeHash
  AND NEW.sessionId IS OLD.sessionId
  AND NEW.replayClass = OLD.replayClass
  AND NEW.dispatchState = OLD.dispatchState
  AND OLD.dispatchState = 'terminal'
  AND NEW.state = OLD.state AND OLD.state <> 'running'
  AND NEW.terminalSubtype IS OLD.terminalSubtype
  AND NEW.nextSequence = OLD.nextSequence
  AND NEW.terminalReceiptIdempotencyKey IS OLD.terminalReceiptIdempotencyKey
  AND NEW.terminalReceiptHash IS OLD.terminalReceiptHash
  AND NEW.inputTokens = OLD.inputTokens
  AND NEW.outputTokens = OLD.outputTokens
  AND NEW.cacheReadTokens = OLD.cacheReadTokens
  AND NEW.costMicros = OLD.costMicros
  AND NEW.version = OLD.version + 1
  AND NEW.createdAt = OLD.createdAt
  AND NEW.updatedAt = NEW.redactedAt
  AND NEW.dispatchStartedAt IS OLD.dispatchStartedAt
  AND NEW.cancellationRequestedAt IS OLD.cancellationRequestedAt
  AND (
    (OLD.cancellationRequestedAt IS NULL AND NEW.cancellationReason IS NULL)
    OR
    (OLD.cancellationRequestedAt IS NOT NULL
      AND NEW.cancellationReason = 'camp_deleted')
  )
  AND NEW.finishedAt IS OLD.finishedAt
  AND EXISTS (
    SELECT 1 FROM camp_lifecycle l
    JOIN camp_deletion_job j ON j.campId = l.campId
    WHERE l.campId = OLD.campId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN SELECT RAISE(ABORT, 'engine execution redaction diff is invalid'); END;
CREATE TRIGGER engine_execution_post_redaction_lock
BEFORE UPDATE ON engine_execution WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'engine execution is immutable after redaction'); END;
CREATE TRIGGER engine_execution_reject_delete
BEFORE DELETE ON engine_execution
BEGIN SELECT RAISE(ABORT, 'engine execution may not be deleted'); END;

CREATE TRIGGER engine_terminal_proposal_first_redaction_exact
BEFORE UPDATE ON engine_terminal_proposal
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.id = OLD.id
  AND NEW.executionId = OLD.executionId
  AND NEW.terminalIdempotencyKey = OLD.terminalIdempotencyKey
  AND NEW.sequence = OLD.sequence
  AND NEW.terminalKind = OLD.terminalKind
  AND NEW.terminalSubtype IS OLD.terminalSubtype
  AND NEW.proposalJson = '{}'
  AND NEW.proposalHash = OLD.proposalHash
  AND NEW.payloadJson = '{}'
  AND NEW.payloadHash = OLD.payloadHash
  AND NEW.artifactManifestJson = '[]'
  AND NEW.artifactManifestHash = OLD.artifactManifestHash
  AND NEW.state = OLD.state AND OLD.state IN ('committed','invalid')
  AND NEW.version = OLD.version + 1
  AND NEW.createdAt = OLD.createdAt
  AND NEW.committedAt IS OLD.committedAt
  AND (
    (OLD.state = 'committed' AND NEW.invalidReason IS NULL)
    OR
    (OLD.state = 'invalid' AND NEW.invalidReason = 'camp_deleted')
  )
  AND NEW.invalidatedAt IS OLD.invalidatedAt
  AND EXISTS (
    SELECT 1 FROM engine_execution x
    JOIN camp_lifecycle l ON l.campId = x.campId
    JOIN camp_deletion_job j ON j.campId = x.campId
    WHERE x.id = OLD.executionId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN SELECT RAISE(ABORT, 'engine proposal redaction diff is invalid'); END;
CREATE TRIGGER engine_terminal_proposal_post_redaction_lock
BEFORE UPDATE ON engine_terminal_proposal WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'engine proposal is immutable after redaction'); END;
CREATE TRIGGER engine_terminal_proposal_reject_delete
BEFORE DELETE ON engine_terminal_proposal
BEGIN SELECT RAISE(ABORT, 'engine proposal may not be deleted'); END;

CREATE TRIGGER engine_proposal_artifact_reject_private_field_update
BEFORE UPDATE ON engine_proposal_artifact
WHEN (
  NEW.sourceRelativePath IS NOT OLD.sourceRelativePath
  OR NEW.kind IS NOT OLD.kind
  OR NEW.label IS NOT OLD.label
  OR NEW.redactedAt IS NOT OLD.redactedAt
)
AND NOT (
  NEW.id = OLD.id
  AND NEW.proposalId = OLD.proposalId
  AND NEW.artifactId = OLD.artifactId
  AND NEW.ordinal = OLD.ordinal
  AND NEW.sourceRelativePath = ''
  AND NEW.kind = 'tombstone'
  AND NEW.label = '[deleted]'
  AND NEW.byteCount = OLD.byteCount
  AND NEW.contentHash = OLD.contentHash
  AND NEW.state = OLD.state
  AND NEW.preparedAt IS OLD.preparedAt
  AND NEW.version = OLD.version
  AND OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM engine_terminal_proposal p
    JOIN engine_execution x ON x.id = p.executionId
    JOIN camp_lifecycle l ON l.campId = x.campId
    JOIN camp_deletion_job j ON j.campId = x.campId
    WHERE p.id = OLD.proposalId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN
  SELECT RAISE(ABORT, 'proposal artifact private fields are immutable');
END;
CREATE TRIGGER engine_proposal_artifact_post_redaction_lock
BEFORE UPDATE ON engine_proposal_artifact
WHEN OLD.redactedAt IS NOT NULL
BEGIN
  SELECT RAISE(ABORT, 'proposal artifact is immutable after redaction');
END;
CREATE TRIGGER engine_proposal_artifact_reject_delete
BEFORE DELETE ON engine_proposal_artifact
BEGIN
  SELECT RAISE(ABORT, 'proposal artifact may not be deleted');
END;

CREATE TRIGGER artifact_storage_origin_first_redaction_exact
BEFORE UPDATE ON artifact_storage_origin
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.artifactId = OLD.artifactId
  AND NEW.campId = OLD.campId
  AND NEW.state = 'tombstoned'
  AND NEW.storageClass = OLD.storageClass
  AND NEW.evidenceKind = OLD.evidenceKind
  AND NEW.managedRootId IS NULL AND NEW.objectId IS NULL
  AND NEW.contentHash IS OLD.contentHash
  AND NEW.fileIdentityHash IS OLD.fileIdentityHash
  AND NEW.originalRefHash = OLD.originalRefHash
  AND NEW.classificationEvidenceHash = OLD.classificationEvidenceHash
  AND NEW.terminalDisposition IS NOT NULL
  AND NEW.terminalAuthorityHash IS NOT NULL
  AND NEW.version = OLD.version + 1
  AND NEW.classifiedAt = OLD.classifiedAt
  AND EXISTS (
    SELECT 1 FROM camp_lifecycle l
    JOIN camp_deletion_job j ON j.campId = l.campId
    WHERE l.campId = OLD.campId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN
  SELECT RAISE(ABORT, 'artifact origin redaction diff is invalid');
END;
CREATE TRIGGER artifact_storage_origin_post_redaction_lock
BEFORE UPDATE ON artifact_storage_origin
WHEN OLD.redactedAt IS NOT NULL
BEGIN
  SELECT RAISE(ABORT, 'artifact origin is immutable after redaction');
END;
CREATE TRIGGER artifact_storage_origin_reject_delete
BEFORE DELETE ON artifact_storage_origin
BEGIN
  SELECT RAISE(ABORT, 'artifact origin may not be deleted');
END;

CREATE TRIGGER discussion_turn_reject_update_except_camp_redaction
BEFORE UPDATE ON discussion_turn
WHEN NOT (
  NEW.id = OLD.id
  AND NEW.discussionId = OLD.discussionId
  AND NEW.round = OLD.round
  AND NEW.sequence = OLD.sequence
  AND NEW.speakerActorId = OLD.speakerActorId
  AND NEW.contentRef = ''
  AND NEW.contentHash = OLD.contentHash
  AND NEW.inputTokens = OLD.inputTokens
  AND NEW.outputTokens = OLD.outputTokens
  AND NEW.createdAt = OLD.createdAt
  AND OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM discussion d
    JOIN camp_lifecycle l ON l.campId = d.campId
    JOIN camp_deletion_job j ON j.campId = d.campId
    WHERE d.id = OLD.discussionId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN
  SELECT RAISE(ABORT, 'discussion_turn is append-only');
END;
CREATE TRIGGER discussion_turn_reject_delete
BEFORE DELETE ON discussion_turn
BEGIN
  SELECT RAISE(ABORT, 'discussion_turn is append-only');
END;

```

`engine_execution.runId/cardId` 与既有 Run/Card 真相在 kernel transaction 内交叉
验证；`nextSequence` 是下一条可接受 adapter event sequence。Discussion token
加法、engine usage/cost 加法全部使用 overflow-reporting；overflow 使命令失败并
保持旧 projection。
Store 还必须强校验：execution/session 的
camp/profile/adapter/version/sessionScopeHash/workspace exact equality（contextHash
只在单个 execution 内与 contextJson 匹配）；每次 begin/bind/recovery 都从
`sessionScopeJson` decode exact typed scope、重算 hash，并和行列/request fields
交叉验证，绝不信 caller claimed hash；terminal execution
的 `terminalReceiptIdempotencyKey` 指向 receipt，且
`terminalReceiptHash == domain_command_receipt.resultHash`；proposalHash 不得写入
receiptHash。proposal artifact ordinal 从 0 连续，caller 不提供 artifactId，首次
record transaction 生成；whole proposal canonicalization 按 ordinal。GC live set
固定为下述 contentHash 集合，绝不使用 proposalHash：

```sql
SELECT a.contentHash
FROM engine_proposal_artifact a
JOIN engine_terminal_proposal p ON p.id = a.proposalId
WHERE p.state = 'pending' AND a.state IN ('declared','prepared')
UNION
SELECT r.contentHash
FROM artifact_blob_reference r
WHERE r.state = 'active'
UNION
SELECT b.contentHash
FROM camp_deletion_proposal_blob b
WHERE b.state IN ('pending','reserved','unlinkReady','retryableFailure');
```

v17 Swift migration 必须给每条已有 `artifact` 插入 exact 一条
`artifact_storage_origin`：Camp 由 card→mission→squad确定，
`state='active'`,`storageClass='unresolved'`,`evidenceKind='legacyUnknown'`，managed、
terminal、redacted fields全 NULL，`originalRefHash` 为旧 path canonical UTF-8 的
SHA-256，`classificationEvidenceHash` 为包含 artifact/card/Camp IDs 与
originalRefHash 的 canonical legacy attestation SHA-256；不得访问 filesystem 或按
prefix/name/ext分类。source/origin count、Camp path 任一不一致 rollback。F1 后新
artifact 只可由 `PreparedArtifact` 或 `WorkspaceExternalArtifactReference` typed
API 创建；legacy unresolved 后续升级只接受 verifier 签发的 managed 或
`verifiedOutsideAllManagedRoots` evidence，CAS version；missing/symlink/permission/
root unavailable/drift 不会被默认成 external。v17 尚未实施，所以直接修正 v17，
不增加补丁式 v18。

## 19. 下游失效与 Projection 转移矩阵

所有下列命令都使用一个 domain command receipt，并在同一 transaction 写
Outcome/Goal/Mission/Verification head/Acceptance/metric，以及枚举出的
Memory/Growth 失效和全部 events/outbox。任何一项失败整笔回滚。

| 命令 | Outcome | Verification / Acceptance | Goal | Mission | Metric | Memory | Growth |
|---|---|---|---|---|---|---|---|
| `recordInitialOutcome` | linked Mission `executing|delivering` 且无 Outcome时创建 head/version 1=`produced` | 无旧 record | 保持 active | 保持 executing/delivering | 无 | 无 | 无 |
| `returnOutcome` | `delivered|accepted -> returned` | 追加 returned Acceptance；当前 verification 保留历史 | `active|achieved -> active` | `delivering|accepted -> delivering` | active → reversed | 引用该 acceptance/outcome 的 active memory → needsReview | active → invalidated |
| `revokeAcceptance` | `accepted -> revoked` | 追加 revoked Acceptance | `achieved -> active`；其他非终态保持 | `accepted -> delivering` | active → reversed | active → needsReview | active → invalidated |
| `invalidateVerification` | 未验收 outcome → verificationPending；accepted → invalidated | 追加 invalidation，current head → invalid | `achieved -> active`；clarifying/ready/active/paused 保持 | `accepted -> delivering`；planning/executing/delivering 保持 | active → reversed | 直接依赖 verification 的 → invalidated；仅依赖 outcome 的 → needsReview | active → invalidated |
| `recordNewOutcomeVersion` | `returned|verificationFailed|blocked|invalidated|revoked -> verificationPending`，currentVersion+1 | 旧 version current records 各追加 `outcome_version_superseded` invalidation；旧 Acceptance 仅保留历史 | `achieved -> active`；其余非终态保持 | `accepted -> delivering`；其余保持 | active → reversed | 依赖旧 version → needsReview | 依赖旧 version → invalidated |
| `deleteOrInvalidateDependency` | 受影响 current verification 失效；按上行归约 | 每个受影响 record 追加 dependency invalidation | 按 invalidateVerification | 按 invalidateVerification | active → reversed | 直接依赖被删源 → invalidated；正文按删除规则 tombstone | active → invalidated |

补充规则：

- `clarifying`、`ready`、`active`、`paused` 都允许 user `abandon` 和 system
  deterministic `fail`；abandon/fail 同事务 cancel 其活动 coach/input parsing/
  planning work。`paused` 可 resume 到 active。`achieved` 只在仍有有效 accepted
  Outcome 时成立；失效命令必须 reopen 到 active。
- P1 不把 Mission 新增成另一套状态机：return/revoke/invalidate 对既有
  `MissionStatus.accepted` 明确转回 `.delivering`，后续新增 rework Card 时再由
  rollup 进入 `.executing`；需要相应修改 `MissionStatus.rollup`，不能继续把
  accepted 当不可逆终态。
- invalidated/revoked Outcome 不能直接 accepted；必须创建新 OutcomeVersion、
  重跑全部当前 requirement、重新 delivered 后再验收。
- `MemoryRecord.needsReview` 保留正文但不得作为 required fact 自动注入；
  `invalidated` 禁止注入。Growth invalidation 永不反向扩大权限或自动恢复。

## 20. 有序子阶段

### P1-A — Durable Work 与四个崩溃窗口

范围：§6；修 planning、rumination、candidate 和 schedule。

完成门：

- A1 必须再拆为 A1a（DDL + Store）与 A1b（Planning supervisor + integration）；
  两次 invocation 之间有独立 Review/acceptance，A1a 不改生产 planning；
- A1a 必须先用 golden bytes 证明 typed/raw 共用 §5.1 唯一 canonicalizer，覆盖
  slash、Unicode、integer/float/exponent/negative-zero 与所有明定拒绝边界；所有
  后续 hash-bearing payload 复用该实现；
- `DurableWorkFailure` initializer/Codable validation、稳定 raw disposition、
  canonical usageJson 和“retry 只依赖 disposition”测试全绿；
- byte-backed parser 不引用 JSONValue/raw JSONDecoder；time/lease preflight、
  empty/due/future claimability、Camp missing/archived/replay fence、campDeletion
  generic API sealing与三层 error/output DDL matrix tests 全绿；
- 四个风险分别有失败注入复现、根因修复和回归测试；
- restart adoption、projection-atomic cancel、finite retry、lease renewal、stale
  completion、同 payload replay/异 payload conflict、terminal rollback 全部测试；
- captured Runtime Profile 不随 default 改变；CLI planning 明确前置拒绝/legacy
  terminal fail；legacy repair 启动顺序和幂等有测试；
- 不再存在 App 先写 in-flight、再丢给无持有 Task 的关键路径。
- A2 的 41 个 exact named tests 各发现一次并全绿；normal/legacy key、generation、
  captured profile/model、resolver/failure/usage matrix、generic rumination sealing、
  legacy 8-cell mode×snapshot、global FIFO、single Supervisor、opaque
  validated-turn/provider→phase→parse handshake、pending proposal、
  startup/halt/resume/shutdown、phase truth、terminal/cancel rollback 与 mutation
  fences 均有根因级证据；
- A2 #1/#6/#11/#22/#33/#34/#35共同证明normal start/failed user retry
  `.inserted` attempt-zero exact `version=1` resulting identity、同actor turn reserve+global claim
  barrier、delivery-before-claim/conditional-kick、existing pump零DB claim/零跨kind
  skip、preparation-replay绕过resolver/Store且两种replay origin只按workId等待
  original delivery、delivered/restart零第二event、目标Camp snapshot ready先于
  command enable且load failure保持disabled/显式失败、start `V`→cancel/halt `V+1`与
  rollback/conflict零barrier/reserve/sink/kick；同state root single-writer contract
  还须证明AppStore lifetime-held `StateDirectoryLock`先于唯一production
  `AppDatabase(path:)`，第二owner fail-fast且释放后可重新取得，两个既有lock文件
  byte-identical；
- A2 #27/#35 在两轮 revalidation 穷尽 §6.4.9 的全部 expected control loss 与
  DB-read/invariant-fatal 注入，逐格证明 exact control catch 或 global fatal、
  zero parse/attempt failure/retry/proposal/domain event/business write、已发 phase
  在 throw/cancel/return前经同一 exact identity exactly-once invalidation清除；
  另覆盖cancellation不能跳过、stale/mismatched invalidate不能清新generation、
  invalidated旧positive set不能复活；live与phase-less success/failure/retry/cancel
  的resulting work version、commit/rollback milestone，retry `V+1`后cancel/halt
  `V+2`、exact duplicate/更高/未见更低version，halt pre-clear与post-cleanup
  delivery/failure，commit-first与fatal/control-first串行race，typed optional exact
  clear、empty/tombstoned/new-generation refresh及App same-snapshot FIFO reconcile
  全部闭环。fail-fast source-range/order gate锁定两轮
  actor/current-claim/durable-graph顺序、唯一invalidator、全部fatal callsite owner、
  capture→revoke set→await invalidate→cancel/return、Store resulting-version与
  commit-before-first-await reservation、start transaction→barrier→delivery→
  release→revalidate→conditional kick与所有global claim barrier checks、replay
  no-identity/no-event、halt完整顺序、单callback/per-identity
  milestone coordinator、Orchestrator full-commit receipt/remove/tombstone/typed
  emit与App direct-await/snapshot-reconcile/always-reload；
- A2 不改变 schema/EventKind/strict resolver/target graph；SQLite 3.51/3.52 的
  fresh/v7/v8/v9/v10/v11/v12-durable literal + real GRDB matrix 全绿，R12-A script
  除 frozen Stage hash value 外逐字不变；
- R13 preview 的第一次尝试因验证工具按显示名称定位而启动 installed App，并实际
  打开 normal state root 的 lock/DB/SHM/WAL；该 attempt、原日志与 Review01 P1-01
  永久保留为 rejected historical evidence，不得表述为零访问，也不得由后续成功
  retry 覆盖；
- Review15已在R15 exact hashes上判定`APPROVED — 0 P0 / 0 P1`；后续获授权的R15
  invocation在BEGIN attestation中把逐字相等的Review12C expected/actual hash误判为
  mismatch，因而永久标记为`REJECTED_CONTAMINATED`并停止。该boundary没有运行
  targeted/full test、build、matrix、source gate、bundle assembly/sign或preview，
  不能满足A2完成门，也不得被修补、重开或retry；
- Review16已在§28.3的R16 exact hashes上判定`APPROVED — 0 P0 / 0 P1`，牧场主也在
  后续新用户turn以四个terminal hashes授权；但R16 driver在pre-BEGIN
  `pgrep rc=1`缺席探针被全局`ERR` trap抢占后停止，未到达唯一授权消费点。R16四
  anchors与110/110 manifest全绿，12个runtime paths和两类fresh roots均未创建，
  没有运行任何后续门，不能满足A2完成门；
- R17 freeze、driver、Bash 3.2 probe与115-entry manifest完成静态冻结，Review17
  判定`CHANGES REQUIRED — 0 P0 / 1 P1`：canonical Stage要求RanchArt exact-27/
  zero-nonregular结构门在授权消费前完成，但R17 driver把它放在消费后。R17没有获得
  plan approval，caller/BEGIN及全部后续门均未执行，全部R17 runtime paths与两类
  fresh roots保持不存在，不能满足A2完成门；
- Review18已在§28.5的R18 exact hashes上判定`CHANGES REQUIRED — 0 P0 / 1 P1`；
  R18/R18-A从未执行，也永不再具有开门权。Review19随后在§28.6的R19 exact hashes
  上判定`APPROVED — 0 P0 / 0 P1`，牧场主又在后续新用户turn按
  `freeze, Review19, driver, manifest`顺序提供四hash并授权。R19成功到达
  `BEGIN_ATTESTED`，41个A2 named tests为41/41 PASS；但紧接的权威、未过滤
  `swift run RunTests`为651/652，唯一失败是
  `slowActiveStreamDoesNotIdleTimeout`（`AgentLoopTests.swift:611`，
  `idle script exhausted`）。该boundary永久为
  `REJECTED_CONTAMINATED — authoritative full RunTests failure`，不得重跑、补写、
  覆盖或复用；build/release、matrix、source、bundle/sign、preview与END均未运行，
  产品/test bytes零漂移，11个已创建的R19 runtime artifacts与两个保持为空的exact
  fresh roots全部immutable；
- Review20按§28.7批准后，R20获四hash授权并成功完成唯一full 652/652、同log 46/46、
  debug App build与LAUNCH_READY；但其release Core `--product`命令因SwiftPM automatic-
  product fallback编译default graph，并触发release TestSuite caller/DEBUG-only Core
  callee配置错配。R20 boundary因此在`release_core_build`永久
  `REJECTED_CONTAMINATED`；后续symbol/matrix/source/preview/END均未运行；
- A2当前唯一前瞻性完成路径是§28.8的R21 release-configuration closure。Review21必须先
  在R21 exact six surfaces、driver、155-entry manifest与freeze上判定
  `APPROVED — 0 P0 / 0 P1`；随后牧场主须在新的用户turn按
  `freeze, Review21, driver, manifest`顺序提供四个final hashes并授权，才可打开一次
  fresh R21 invocation。该invocation必须保持R20 Core final bytes，只允许在R20新增的
  TestSuite helpers/function/五项tests外围原地增加三对matching DEBUG guards，并以
  target-exact Core/TestSuite release builds及四object release-zero/debug-positive symbol
  gates重新通过全部A2与全阶段门；旧green、R19 41/41、R20 652/652或单独46-name
  subset都不能替代R21权威full-suite全绿；
- 新的职责隔离 implementation Review02 必须同时保留Review01 finding、核对R21
  invocation真实证据并达到零P0/P1；随后acceptance只能断言“R21 clean verification
  invocation零normal-data access”，同时显式披露R13历史incident、
  R15 rejected boundary、R16 pre-BEGIN未消费/零写入false positive与R17/R18未执行
  的plan rejection、R19 authoritative full-test rejection与R20 release-build rejection，
  不得声称整个A2历史零访问。
  acceptance通过前不得进入A3。

### P1-B — 错误可见性与应用层接缝

范围：§7；failure / degradation，关键 `try?` 分类，最小 `AgentLoopApplication`。

完成门：

- P0 标出的 AppStore / McpStore / Orchestrator DB、Keychain、MCP、知识静默路径全部进入 inventory 并有处置；
- 注入数据库、Keychain、MCP、知识失败时 UI workflow state 非空失败且含 trace ID；
- required / optionalApproved 行为有 workflow tests。

### P1-C — Event、Input、Goal 与 Coach

范围：§8–§11。

完成门：

- 空库和 v11 升级可重放；
- Input parsing durable work、Goal 到 ready、Coach、Understanding 全状态机、CAS、
  idempotency 和 crash/replay contract tests 全绿；P1-C 不测试 active；
- 跨 Camp 歧义不会默认落营地；
- Coach 重启可恢复唯一 open question。

### P1-D — Outcome、Verification、Acceptance 与 Grant

范围：§12–§13。

完成门：

- Goal activate/active/paused/achieved 与 OutcomeContract 同 slice 建成；
- 多 requirement 的 all/any reducer、交付、独立验证、验收、退回、撤销、失效和
  §19 反向传播通过 contract + workflow tests；
- content/hash/contract 改变会让旧 Verification 失效；
- UI workflow 只有 durable acceptance 成功后才进入 accepted；
- Grant scope 精确匹配；external operation 在 before-start、after-start、
  after-external-success-before-local-commit 三个 crash window 都有收敛测试。

### P1-E — Cow、Residency、Camp lifecycle schema 与 Memory

范围：§14–§15。

完成门：

- Companion backfill 可重复、无重复 Cow/Residency；
- `campId == nil` 不产生权限；
- 并发驻场、暂停、离营、撤权和跨 Camp bridge tests 全绿；
- lifecycle/deletion、durable-work v16 rebuild、legacy chat/note/all-event scope、
  provider-dispatch ledger、FK 与 deletion-only redaction trigger tests 全绿，
  但 archive/delete workflow 尚不 expose；
- active-only普通 Ingestion `resultOnly|sourceAndResult` 删除合同、sealed command +
  Store-only prepare、instance-owned exact registry/generation UDF、raw
  `sqlite3_create_function_v2+xDestroy` connection ownership、provisional
  install/unlocked C-call/reconcile、封闭 DEBUG lifecycle scenario runner与
  helper-only mismatch测试、完整
  CommandEnvelope专列、initial outbox/privacy、event-bound raw guards、五项
  fixed-zero blocker counts、receipt replay、所有 projection/work/provider blockers、
  incomplete sequence rollback、prepare/execute TOCTOU、typed
  committed/notCommitted/resolutionPending收敛、四 phase pending-command、
  session-local relaunch与 UI race tests全绿；
- provenance 失效和删除传播 tests 全绿。

### P1-F1 — Engine、Artifact、Discussion、Attention 与 Growth

范围：§16–§17，建立所有剩余 scope/owner。

完成门：

- ModelLoop、Codex CLI、Claude CLI adapters 通过统一 conformance suite；
- 能力发现、终结、取消、错误、成本与精确 session continuation / 明确 unsupported 均通过；
- Discussion 有预算/轮数并必须物化；
- Attention 和 Growth 不制造权限；
- terminal whole identity、dispatch CAS、persistent blob/GC roots、invalid proposal
  deterministic terminal、exact session/context tests 全绿。
- artifact origin unresolved backfill、typed managed/external creation、legacy
  no-follow classification与 managed report owner tests 全绿。

### P1-F2 — Camp retirement 与 P1 整合门

范围：§14.2 全部 archive/delete/write fence，并做 P1 全链路 integration。

完成门：

- 所有 Camp-reachable owner 有 stable scope 与 exhaustive registry；
- active-write 与 deletion permit 职责隔离、archive quiescence、并发 write fence、
  dedicated unarchive、exact self-exclusion 全绿；
- user-confirmed irreversible deletion、逐字段 erasure/invalidation、artifact
  ownership、provider drain、failed-work replacement repair、restart/failure
  injection、unknown projection sentinel 全绿；
- Camp 永不物理 DELETE，workspace external file 永不被 App 删除；
- 全部 P1 schema 与 workflow integration tests 通过。

## 21. P1 总完成门

P1 只有在下列条件全部满足后才能 Accepted：

- P1-A…P1-E、P1-F1、P1-F2 每个子阶段都有 spec/plan 对应项、impl report、独立
  Review 和 acceptance；
- R-01…R-09 均有根因修复或被新契约彻底替代，且有回归证据；
- 从空数据库完整重放 v1…P1 最后 migration 成功；
- 从 v11 升级到 P1 最后 migration 成功且重复 migrate 幂等；
- Goal、Input、Coach、Understanding、OutcomeContract、Outcome、Verification、Acceptance、Grant、Event、Memory、Cow/Residency 状态机与版本契约测试全绿；
- Camp archive 与 user-confirmed irreversible deletion 的 fence/quiescence/
  erasure/artifact ownership/sentinel/restart contract tests 全绿；
- 所有 in-flight 状态由 durable work 或 engine execution ledger 承担，并有重启
  收编、projection-atomic cancel、有限重试、失败终态和幂等重放测试；
- Codex / Claude CLI adapter conformance tests 全绿；真实 CLI 能力只报告本轮确实验证的部分；
- 业务错误不再用空值或默认成功吞掉，用户可见失败含稳定 trace ID；
- `swift run RunTests` 全绿；
- `swift build --product AgentLoopApp` 全绿；
- 对本阶段风险匹配的 `AgentLoopApplication` workflow tests 全绿；
- 真实 normal 或隔离 preview App 展示至少 planning、rumination、schedule、
  MCP/knowledge 与 acceptance 失败各一条可见 trace 证据；不得污染normal数据。
  A2只可由§28.8定义且未来另获四-hash授权的R21 clean invocation满足该前瞻性门，并必须同时披露R13
  `REJECTED_CONTAMINATED` incident、mutation unknown与R15
  `REJECTED_CONTAMINATED` BEGIN false negative、R16 pre-BEGIN
  `AUTHORIZATION_NOT_CONSUMED` false positive、R17/R18 plan rejection/not-executed及
  R19 authoritative full-test与R20 release-build两个`REJECTED_CONTAMINATED`，
  不得把历史写成未污染；
- 产品代码和文档事实一致；
- 没有未解决 P0/P1 finding、红测、未知失败或越权改动。

## 22. 禁止跨越的红线

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
21. A2 不得创建第二 production Supervisor、从 current default/Companion fallback
    captured rumination identity、在 App/Adapter 启动 unowned provider Task，或让
    generic DurableWork API mutate/schedule `.rumination`。
22. A2 不得用 mutable lastUsage、任意 provider/usage/optional callback、unowned
    Task或第二 provider path拼接 success usage；§6.4.9 唯一 typed awaited
    phase-command sink除外，且该单一 sink只能承载 identity-bound
    `.set`与`.invalidate(.phase|.projectionCommitted)`。不得用第二 callback、
    observer、per-command Task、cancellation、timeout、`haltStateChanged`或持久
    业务写代替 milestone delivery，不得用phase identity吞掉更高workVersion、
    伪造phase/commit、吞terminal persistence failure，或在A2提前持久化
    provider-returned checkpoint/phase/receipt。normal start specialized Store
    只能由Supervisor调用；不得让Orchestrator/App/Adapter直接commit/refresh，
    不得在start barrier期间由既有pump claim任一kind或跳过FIFO head，不得从
    `.replayed` current attempt/version合成projection milestone，也不得在startup
    persisted snapshot完成前启用start/retry command。不得在同一state root创建
    第二production DB opener/writer、绕过/后移nonblocking exclusive
    `StateDirectoryLock`、缩短AppStore对锁的lifetime持有，或在A2宣称CLI/硬件
    multi-writer已受支持；该扩张必须另开stage设计跨进程coordination/outbox。
23. R15 freeze、Review15、全部`r15-*` repository artifacts与
    `impl-report-r15.md`是immutable rejected evidence；两个volatile roots只在
    containment时被观察为canonical empty，2026-08-02 current复核为`ABSENT`、原因
    `UNKNOWN`，不得虚构连续保全。current exact identities是absorbing tombstones，
    任何node重现都fail closed；不得追加、覆盖、重命名、创建、删除、清理、复用或把
    R15 false negative解释为成功；不得在R15 boundary继续任何门、重新BEGIN、换root
    或创建其未生成的screenshot。
24. R16 freeze、Review16、driver与manifest是immutable approved-plan predecessors；
    R16 caller只到达pre-BEGIN且授权未消费、零runtime artifacts/roots。不得修改、
    补写、重跑或把该结果改写为BEGIN/`REJECTED_CONTAMINATED`。R17 freeze、driver、
    probe、manifest与Review17是immutable rejected-plan predecessors；Review17
    `CHANGES REQUIRED — 0 P0 / 1 P1`没有开门权，R17从未执行，不得补写、重跑或
    洗绿。R18 freeze、driver、manifest与Review18同样是immutable rejected-plan
    predecessors；Review18 verdict为`CHANGES REQUIRED — 0 P0 / 1 P1`，R18从未执行。
    R19已在权威full test失败后永久`REJECTED_CONTAMINATED`；其freeze、Review19、
    driver、manifest、11个runtime artifacts、缺失screenshot与两个exact empty roots均
    immutable。不得在R19 boundary重跑、补跑后续门、补写空日志、清理/删除/复用roots
    或以41/41 targeted、R20 652/652/46/46、旧full-suite green洗绿。R20 freeze、
    Review20、driver、manifest、最终两source bytes、11个runtime artifacts、缺失screenshot、
    exact state root与保留signed App的bundle parent均immutable；不得重跑R20、补跑后续门、
    修改/删除/清理/启动/复用其证据或App。Review21未在
    `evidence/plan-freeze-r21.md`记录的R21 exact hashes上判定
    `APPROVED — 0 P0 / 0 P1`且牧场主未在其后的新用户turn以四个terminal hashes再次
    授权前，不得运行R21 caller/BEGIN、test、build、matrix、source gate、bundle
    assembly/sign或preview，不得实施TestSuite三对guard或修改`AgentLoop.swift`及任何
    其他产品/test/App/RunTests/matrix-script bytes，不得创建Review02/acceptance或进入A3。
    Review21批准也不自动执行。不得执行`scripts/run-app.sh`、
    `scripts/package-app.sh`或任何LaunchServices路径。R21禁止Package.swift、public/package
    API、target/dependency/package edge、schema/migration、逻辑/whitespace移动、timeout/
    事件间隔放大、`.serialized`、skip/filter、修改RunTests并发、失败重跑、模糊object
    search/fallback或吞掉任何错误。

## 23. 回滚与兼容

- P1 migrations 只前进，不提供 destructive down migration。
- 每个 migration 前后都由 test fixture 验证；实施与未来R21 clean verification均不
  操作normal DB。R13已发生的installed-App访问只作为immutable rejected incident
  保留；R15虽在BEGIN失败前未访问normal root，仍是immutable rejected boundary，
  R16虽在pre-BEGIN零写入且未消费授权，也没有运行任何技术门；三者都不能被解释为
  满足本条。R17与R18均在plan review被拒且从未执行；R19虽通过41/41 targeted，仍因
  authoritative full RunTests 651/652永久被拒；R20虽有652/652与LAUNCH_READY，仍因
  release Core build永久被拒；这些历史均不能满足本条。
- 当前 Companion、Mission、Card、Run、event、ingestion 和 schedule 表保留。
- 新路径通过 adapter 读取 legacy 数据；只有真实新命令写新 aggregate。
- P1 子阶段若应用层切换失败，可在代码层回到上一个已 Review commit/worktree 状态；不能删除已执行 migration 或篡改事件。
- 在没有 commit 权限时，实施者只保存 diff、logs 和报告，由 reviewer 判定可否继续。

## 24. Round 3 finding resolution matrix

本矩阵只证明 finding 已落实到 Proposed spec/plan；不代表 Review 通过或本文
Approved。

| Finding | 规范闭环 | DDL / API 锚点 | 必须失败/成功的计划测试 |
|---|---|---|---|
| R3-P0-1 Camp delete/archive incomplete | §14.2 lifecycle、write fence、quiescence、irreversible deletion、逐字段 erasure、artifact ownership、sentinel | §18.6 lifecycle/job/artifact/event scope；Plan §9 F2 owner registry/worker | 每类 quiescence、race/restart、cross-Camp/shared/workspace、field sentinel、unknown projection、rollback |
| R3-P0-2 crashUnknown authority conflict | §13 fail-closed adapter attestation vs user succeeded/abandonedUnknown | §18.5 receipt authority/result/combined terminal unique；Plan §6.7 typed store/coordinator | no-effect authority、CAS winner、no refund after user resolution、receipt raw-SQL guards |
| R3-P0-3 engine dispatch boundary absent | §16.2 `markEngineDispatchStarted` + four crash windows | §18.7 dispatchStartedAt/version/state checks；Plan §8.3 EngineExecutionStore | startNow once、alreadyStarted no call、four crash windows |
| R3-P0-4 invalid proposal/GC gaps | §16.3 invalidation terminal API、persistent blob refs/roots | §18.7 proposal-artifact/blob/reference；Plan §8.3/§8.7 ArtifactBlobStore | deterministic invalid receipt、all rollback edges、source/blob combinations、23h/25h GC |
| R3-P1-1 `complete.outputJson` undefined | §6.2 canonical object/zero-write rule | Plan §3.1 typed error + pre-write validation | nil/canonical success；invalid/nonobject/alternate skip mutation；closure rollback |
| R3-P1-2 nullable receipt hash/weak uniqueness | §13 canonical non-null receipt identity/ordinal | §18.5 NOT NULL key/json/hash、per-use ordinal/partial unique | key/hash replay conflict、ordinal、phase/result/authority、append-only |
| R3-P1-3 waitingForUser taxonomy drift | §16.3 four kinds + blocked needsHumanInput | §18.7 terminalKind/subtype CHECK | SQL/API reject fifth kind；ask_user exact blocked subtype |
| R3-P1-4 proposal identity omitted manifest | §16.3 whole `EngineTerminalProposalContentV1` | §18.7 proposalJson/hash + normalized ordinal rows | manifest-only drift conflict；array reorder same ordinals replay exact generated IDs |
| R3-P1-5 context hash not verified | §16.2 typed envelope/canonical pre-write recompute；immutable sessionScopeHash 与 per-execution contextHash 分离 | §18.7 contextJson/hash/scope hash；Plan §8.3 | typed/raw golden hash；invalid/root/canonical/hash mismatch zero writes；answeredRequests prompt+answer 改 context 但 exact scope 可 resume |
| R3-P1-6 invalidation outside state table/naming drift | §12.2 one authoritative `invalidateVerification` row；§19 reference only | Plan §6.4 `recordInitialOutcome` / `recordNewOutcomeVersion` / `returnOutcome` | exhaustive absent edge rejection；initial/new/return/invalidate propagation |
| R3-P1-7 Input carrier/tombstone ambiguous | §9 exact active XOR and tombstone field matrix | §18.4 exact CHECK；Plan §5.5/§5.8/§9.5 | every retained/null/default field、XOR、deletion propagation |

## 25. Round 4 finding resolution matrix

本矩阵是 Round 5 planner 对 Round 4 finding 的可追踪落实证据，**不是**独立 Review
批准；只有职责隔离 reviewer 在冻结 hash 上给出零 P0/P1 才能开放 A1a。

| Finding | Stage exact clause | Plan owner / files | 必须通过的 tests |
|---|---|---|---|
| R4-P0-1 retirement authority/recovery | §6.2 sealed kind；§14.2 active guard vs opaque permit、state whitelist、self-exclusion、repair；§16.3 engine safe terminal；§18.6 job/work triggers | Plan §3.1 A1a sealing；§6.7 Grant；§7 E schema；§8 F1 engine；§9 F2 CampLifecycleStore/CampDeletionWorker | every wrong/stale permit dimension、unarchive/delete race、exact self-exclusion、Grant/finalize race、engine unknown vs Grant blocker、4th failure/replacement/restart/raw trigger |
| R4-P0-2 privacy erasure impossible/incomplete | §14.2 exhaustive table-column registry；§18.4 inbox shape、§18.5 redacted columns、§18.6/18.7 exact finalizing triggers | Plan §5 C inbox；§6 D verification/acceptance/receipt；§7 E privacy schema；§8 F1 proposal/discussion；§9 F2 sentinel | each named carrier retained/null/default、ordinary/wrong phase/second/extra diff abort、all DELETE abort、global exemption/cross-Camp no-overerase |
| R4-P0-3 legacy scope incomplete | §14.2 Legacy scope resolver；§18.6 three scope tables + post-v16 triggers | Plan §7 E LegacyContentScopeStore/LegacyEventScopeResolver；§9 F2 wiring | every nil-ref persisted kind、global halt/resume、DM/Guide/cowork/manual note、unknown/dangling/ambiguous/cross-Camp rollback、post-v16 missing scope abort |
| R4-P0-4 owners/provider dispatch incomplete | §14.2 provider ledger + compile-time mutation/dispatch registries；§18.6 provider DDL/events | Plan §7 E CampProviderDispatchStore + current services；§8 F1 engine/artifact/report owners；§9 F2 exhaustive registry | message-written/pre-start/started/returned/consumed windows、fence races、raw write/provider/task sentinels、every named owner |
| R4-P1-1 candidate status drift | §14.2 archive split + F2 permit-bound ingestion `queued|ruminating|needsReview→discarded(camp_deleted)`、candidate `proposed|accepted→dismissed(camp_deleted)`，finalizing才擦正文 | Plan §9.3/§9.5 Feed/Rumination/CampLifecycle owners | 每个状态、无work queued、有work/provider、normal materialize/cancel/convert race、restart/replay、terminal history不改状态 |
| R4-P1-2 Outcome command drift | §12.2 + §19 separate `recordInitialOutcome` and `recordNewOutcomeVersion` | Plan §6.4 OutcomeStore | initial v1 plus each returned/revoked/invalidated/verificationFailed/blocked subsequent transition and downstream invalidation |
| R4-P1-3 wrong GC root | §16.3 + §18.7 exact contentHash UNION query | Plan §8.3/§8.7 ArtifactBlobStore | 23h/25h exact content hashes for pending declared/prepared and active refs；proposalHash never root |
| R4-P1-4 legacy artifact classification absent | §14.2 no-follow proof/fail-safe blocker；§18.7 artifact_storage_origin | Plan §8.2/§8.3 ArtifactStorageOriginStore；§9.4 deletion classifier | managed/external/missing/symlink/prefix/permission/hardlink/pending/cross-Camp/concurrent fixtures |

## 26. Round 5 finding resolution matrix

本矩阵仅是本轮 planner 对 review05 的拟议闭环映射，**不代表独立 Review 已通过**；
产品代码实施继续关闭，直到职责隔离 reviewer 对新冻结 hashes 作出结论。

| Finding | Stage 规范闭环 | DDL / API / owner evidence | 必须通过的独立测试 |
|---|---|---|---|
| R5-P0-1 pending/in-flight 删除死锁 | §13/§14.2 F2-only proposal supersession、open-request withdrawal、ingestion/candidate terminalization、reserved Grant-use release；§16.3 recovery | lifecycle/version discriminators、cleanup ledger与四个 specialized permit APIs；generic Engine/Grant/answer/rumination API 不接 permit | proposal全shape；open answer race；Ingestion每状态/无work/有work；reserved无dispatch证据；receipt replay/crash/CAS、所有 blocker归零 |
| R5-P0-2 legacy artifact 无完成裁决 | §14.2 fixed confirmation、typed verifier、resolution state machine、detach-only authority | v16 `camp_deletion_artifact` exact states；v17 verified-outside evidence/origin；ArtifactOwnershipVerifier/CampRetirement controller | 每个 unresolved reason、wrong authority、retry/detach、external/unknown unlink spy=0、managed-only permit、race/restart |
| R5-P0-3 erasure/origin schema 不完备 | §14.2 exact field matrix与 redacted-first decoder contract | origin active/tombstoned；use/Engine字段；user-request withdrawn；ingestion/candidate terminalReason+redactedAt、rumination/link redactedAt、schedule fire redactedAt | 每字段 sentinel/root-kind、terminal history、normal decode forbidden after redaction、global/cross-Camp unchanged、finalize registry completeness |
| R5-P0-4 redaction evidence 可改写 | §14.2 one-shot/no-column-filter/finalizing-only/post-lock/delete guard | v16/v17 exact triggers；provider erasing拒绝；schedule/ingestion/rumination/candidate/link locks | first success、second/no-op/extra diff、逐 retained column UPDATE、marker replay、DELETE、wrong erasing/finalizing/job/Camp |
| R5-P1-1 SQLite 3.52 trigger 顺序 | §18.6/§18.7 complete graph + phase barrier/backfill/assertion before all triggers | 修正未实施 v16/v17，不新增 v18；through-v16/v17 exact 67/84 triggers；双 SQLite同一 runner | statement ordinal、3.51+3.52 fresh/v11/v15 populated/negative、replay、FK/integrity、snapshot rollback |

## 27. Round 6 / R8 finding resolution matrix

本矩阵只声明 R8 修订对 Review06、冻结前 pre-review findings与Review07两个P1的
plan-level closure，**不是 Review08批准**；本轮只采用 E-071 已验证的两个有界
路径。Stage/Plan重新冻结并由职责隔离 reviewer在新 hashes上判定零 P0/P1前，
P0 acceptance、A1a与所有产品代码实施继续关闭。

| Finding | Stage 规范闭环 | DDL / owner evidence | 必须通过的独立测试 |
|---|---|---|---|
| R6-P0-1 append-only carrier guards 不完整 | §18 九表 introduction-time pair、v16 五个 UPDATE replacement、committed-boundary DELETE 语义 | v12 `+2`、v14 `+4`、v15 `+8`、v16 memory `+2`；durable rebuild replace/recreate；three v15 DELETE preserved；exact 67/84 | 每个 introducing slice合法 insert、ordinary/no-op update/delete abort；五表 exact first redaction与wrong/second/extra/delete；domain event scope 1:1；3.51/3.52 literal fence + real GRDB runner、rollback snapshot |
| R6-P1-1 普通 Feed/Rumination 删除被 v16 永久封死 | §14.2 sealed `ActiveIngestionDeletionCommandV1` 与三个 scope唯一语义 | 复用 v14 receipt/event；v16 ingestion/result DELETE guards原位增加 transaction-local UDF；candidate/link永久拒绝；P1-E唯一 Store/UI owner | 三 scope×status/lifecycle、五类 blocker、same-key replay/conflict、新 key not found、materialize/worker/Camp deletion races、raw wrong evidence/UDF、pending UI trace |
| R7-pre-P0-1 persisted evidence 可跨 transaction 伪造删除 | §14.2 sealed SQL permit、connection/generation/step/count绑定、full snapshot重算；§18.6 两枚 UDF-gated guards | AppDatabase instance registry + pointer/nonce cell；IngestionDeletionStore唯一安装/直接 SQL；不增 schema/trigger | 四个反例：虚报 result、跳 CAS、precommitted receipt/scope/event/outbox、arbitrary 64-hex hash拒绝/rollback；三合法路径；wrong connection/transaction/reuse失败 |
| R7-pre-P1-1 blocker claims 未进入完整 identity | command/whole hash、receipt、event、permit均绑定五个 fixed-zero count且 live NOT EXISTS保留 | 两枚 guard分别要求 receipt/event exact 0并把 counts传给 UDF；same-key变化 conflict | 每项 missing/nonzero/claim-live drift、race insert与 same-key count变化均零 mutation |
| R7-pre-P1-2 refresh failure 会生成新删除 key | controller-owned opaque pending、prepare once、execute/replay same command、四 phase | InputWorkflowController/AppStore pending state；adapter/UI prepare+execute/resolve seam | commit→refresh failure→same-key replay→success；prepared cancel可清、executing不清、committed dismiss非撤销 |
| R7-pre2-P1-1 command facts 可由 caller铸造 | §14.2 prepare request仅 envelope+Camp/ingestion/scope；Store一致性 read唯一 factory；execute全量 revalidate | IngestionDeletionStore prepare/execute owner；sealed authority；Controller/Application只持 opaque handle | caller facts不可表示/注入；safe preview无正文；prepare零写；逐字段 TOCTOU；double-click/view rebuild单 prepare |
| R7-pre2-P1-2 permit connection/transaction边界不精确 | AppDatabase instance registry、pointer+nonce weak exact cell、Database-only mutation/resolution lookup、53/63 raw UDF、generation+afterNextTransaction+defer | AppDatabase registry-before-pool + prepareDatabase唯一production install；Permit file raw context/xFunc/xDestroy registry及封闭 DEBUG fixture；Store两条封闭 lookup | readonly/wrong/cross-instance、close/destroy cleanup与pointer reuse、txn/no-txn、empty generation、arity/type、commit/rollback/throw/manual boundary/finish/reuse |
| R7-pre2-P1-3 envelope/outbox/privacy/UI phase缺口 | full CommandEnvelope whole hash与 event专列；safe JSON禁 identity；cursor含 initial outbox；pending四 phase | Store specialized evidence/outbox owner；DomainEventStore global contract；Controller/App state | nullability/time、actor JSON rejection、missing/wrong outbox、same-key no second outbox、prepared/executing/resolution/committed races |
| R7-pre3-P1-1 rollback 后 pending phase 未定义 | execute/SELECT-only resolve按 receipt type/hash/eventCount/result/完整 event graph返回 committed、verified notCommitted或三种 disposition；resolver唯一 writeWithoutTransaction + resolution assertion；shared validator唯一；session-local relaunch只信 persisted truth | IngestionDeletionStore resolution/validator owner；Controller/App四 phase；adapter只转交 opaque handle | before-start/rollback→same handle prepared；writeWithoutTransaction no-txn/autocommit + exact empty-generation assertion；unknown只读 resolve；type/hash/count conflict explicit abandon；每个 receipt/event/scope/outbox损坏 integrity block且 relaunch不可绕；同型 malformed receipt全局 deletion fail closed；process death committed-or-rollback reload |
| R7-pre4-P1-1 prepare integrity scan TOCTOU | same-key absent后、permit/evidence前重扫全部同型 receipts并复用唯一 validator | IngestionDeletionStore new-key writer preflight；source sentinel只允许 shared validator | prepare→逐维注入可归属 fault/无法归属 malformed→execute零 own evidence/permit/mutation；scan通过才可 live revalidate/install |
| R7-pre5-P1-1 shared validator 未重算 command whole hash | expectedCommand/selfContainedScan两模式；event envelope专列+19-field typed payload重建 CanonicalJSON whole hash；execute replay/resolver逐字段绑定 sealed handle | IngestionDeletionStore唯一 validator/hash material；DomainEventStore CanonicalJSONV1 | arbitrary 64-hex三处copy + 重算outer hashes仍拒绝；每个 envelope/payload drift replay失败；prepare/new-key self-contained scan也重算 |
| R7-P1-1 v16 literal fence 与 ordinal gate矛盾 | §18.6 barrier后固定四个 surviving-table UPDATE-guard drops、无 IF EXISTS、其后零DML、任何 trigger统一末相；五个 drops全计入 ordinal | v16 fence原位hoist，不新增 migration/schema/trigger；Plan E migrator/runner/tests | literal+Swift trace barrier<four drops<first create；all structural/drop max<first create；drop/last-drop→first-create/trigger中途 rollback逐字恢复v15 schema/data/16 triggers；3.51/3.52仍67/84 |
| R7-P1-2 GRDB connection-close cleanup不可实现 | §14.2 raw `sqlite3_create_function_v2+xDestroy`唯一ownership、provisional install/reconcile、context/cell/registry exact key与SQLite真实销毁语义 | Permit file唯一raw owner；AppDatabase registry-before-pool + prepare唯一production install；Permit内封闭 DEBUG fixture；AgentLoopCore direct same-package GRDBSQLite，resolved不变 | Swift6/GRDB7 source sentinel、53/63、preflight/provisional publish/unlock-C-call/reconcile、duplicate pointer零C；封闭 DEBUG scenario runner复用唯一 raw call，覆盖 registration failure/later setup throw/direct close/BUSY/close_v2 zombie/helper-only sticky mismatch/256次 bounded pointer reuse且不泄漏能力；后续setup/mutation/resolution fail closed |

### 27.1 R9 SQLite diagnostics `NULL/UNKNOWN` 根因修订

R9 只修订 §18.1 introducing checkpoint 与 §18.6 v16 rebuild 中
`durable_work`、`durable_work_attempt`、`durable_work_attempt_event` 的最终
state/diagnostics matrix，共六处。每处只在既有 matrix 外增加
`CHECK (COALESCE((<existing matrix>), 0))`；六个 inner matrix 的状态、字段、
分支和比较保持不变。没有新增 migration、表、列、索引、trigger、状态、权限、
owner、允许文件或执行顺序。

该 wrapper 把 SQLite 原本会通过 `CHECK` 的 `NULL/UNKNOWN` 明确映射为 `0`，但
不改变任何求值为 `1` 的合法组合。Plan §3.1 与 §10 固定 7 个非法
NULL/UNKNOWN mechanism sentinel、v12 的 19 个合法 branch control、v16 的
21 个合法 branch control、完整 normalized truth table、SQLite 3.51/3.52、
literal + real-GRDB，以及 v16 rebuild 后的同表复测与 poisoned predecessor
rollback 门。

本节是获授权 R9 修订与重新冻结声明，**不是 Review09 结论**。职责隔离 reviewer
在新 hashes 上判定零 P0/P1 前，A1a acceptance、A1b 和其他产品代码实施继续关闭。

## 28. R12–R21 Durable Rumination finding resolution

本节记录获授权 R12/R12-A/R12-B/R12-C/R12-D/R12-E/R12-F 对 A2 入口 blocker、
Review12、Review12A 与 Review12B findings 的 plan-level closure，**不是**
Review12C 结论：

| Finding | 本 Stage 的唯一 closure | Review12C 必核 gate |
|---|---|---|
| B1 recovering UI不在范围 | §6.4.9 增 `.recovering`、exact文案/阶段列，并授权 Contracts/Views | 无 `?? .reading`；matching phase source gate；isolated cold-start preview |
| B2 Supervisor owner缺失 | §6.4.4–§6.4.5 冻结 Orchestrator 唯一 production owner与 unified lifecycle | production instance=1；global FIFO；activation/halt/resume/shutdown/fatal tests |
| B3 captured runtime/legacy resolver缺失 | §6.4.1–§6.4.2、§6.4.6 冻结 preparation、identity、resolver map与完整8-cell legacy mode×snapshot表 | default drift、same-key conflict、full failure matrix、#39穷尽8格与exact-once |
| B4 command/terminal/pending语义不全 | §6.4.3、§6.4.7–§6.4.9 冻结 generic seal、opaque validated turn、唯一provider/parse handshake、单一 phase-command sink、usage/failure、atomic terminal与 in-memory proposal | capability priority、#27/#31/#35 pre-parse ownership/invalidation、retry、rollback、no-recall、restart one terminal |
| B5 completion gate不足 | §20/§21 与总 Plan/A2 leaf 冻结 41 named tests、source/release/matrix/preview gates；§28.1保留R13/R14历史，§28.2冻结R15 bundle provenance与clean boundary | exact discovery、A1b regressions、immutable hashes、R13 incident保留 + R15 source/build/bundle/executable chain + boundary zero normal-root open |
| R12-A control hash矛盾 | matrix script 只同步 line 115 的 final Stage SHA；恢复旧 value须恢复旧 script hash | 除该 64-hex 外 byte-identical；runner/DDL/Package graph零漂移 |
| Review12A P1-1 phase无 invalidation owner/API | §6.4.4/§6.4.7/§6.4.9 把唯一 awaited sink改为 identity-bound set/invalidate command；Supervisor唯一 exactly-once invalidator/async fatal owner先 invalidate 后 cancel/return；Orchestrator exact-match registry/tombstone映射到既有 events；App FIFO clear-before-reload | #27/#35 两轮 control/DB/invariant、cancellation、stale/new-generation、terminal/retry/cancel/halt/restart exact assertions + real enclosing-range/order gate |
| Review12B P1-1 phase-less/post-halt durable commit无最终refresh | §6.4.5/§6.4.8/§6.4.9 把同一callback的 invalidate payload扩为 phase或full `(phaseIdentity,workVersion)` projection milestone；Store返回真实resulting version，Supervisor同actor turn reserve并以per-identity coordinator串行delivery；Orchestrator full receipt/monotonic version+typed optional clear，App always reload；halt在cleanup commit后逐个refresh | #27/#35 live+phase-less terminal/retry/cancel、V+1→V+2、duplicate/regression、rollback、halt前后失败、commit-first/phase-first race、registry四态、App snapshot/FIFO与source owner/order gate |
| R12-E follow-up P1 normal start commit无refresh/claim barrier | §6.4.1/§6.4.4/§6.4.9 冻结Orchestrator façade→唯一Supervisor start owner、Store `DurableWorkEnqueueResult.inserted|replayed`、attempt-zero `version=1` start commit、process-local global-claim barrier、delivery→release→revalidate→conditional kick；replay只按workId等待original in-flight，restart靠single-writer lock与command-enable前persisted snapshot | #1/#6/#11/#22/#33/#34/#35锁existing-pump零claim/零skip、long-unclaimed refresh、replay零synthetic event、start V→control V+1、rollback/conflict零barrier、AppStore lock-before-唯一DB-open与真实owner/order source gate |

Review12 已在原 candidate 上写 immutable
`reviews/12-p1-plan-review.md`，SHA-256
`f27379bfc96a224715e7c6a59ad62fa79d8d97c4d73cf41e890a6ce16957a7c3`，verdict
`CHANGES REQUIRED — 0 P0 / 2 P1`：P1-1 是 organizing-before-parse 无合法
owner/API；P1-2 是 halted+invalid snapshot三格未定义。

R12-B 只在既有 B3/B4 范围机械补齐 §6.4.6–§6.4.9，不扩大13+2 allowlist。
旧 Review12 与旧 `evidence/plan-freeze.md` byte-identical；R12-B candidate另存
`evidence/plan-freeze-r12b.md`。

R12-B phase pre-audit 没有创建报告文件，冻结结论为
`0 P0 / 1 P1 / 0 P2`：Stage 已定义 control/fatal出口，但 #27/#35 与 source gate
未穷尽两轮 expected-loss/DB/invariant 分支。获授权 R12-C 只扩展本节
§6.4.9 completion/source gate、总 Plan 与 leaf 的现有 #27/#35 exact subcases；
不改变架构/API、41 names、13+2 allowlist或 #31。旧 Review12、旧
`evidence/plan-freeze.md` 与 R12-B `evidence/plan-freeze-r12b.md` 均须
byte-identical；R12-C candidate 唯一新 evidence 为
`evidence/plan-freeze-r12c.md`。职责隔离 Review12A 随后在该 exact candidate
写出 immutable `reviews/12a-p1-plan-review.md`，SHA-256
`a102c49138fcfc1f40b0c780990d8c3ad5ec2302b175b043bde9457164331337`，verdict
`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`：第二轮 control/global-fatal在零业务写、
persisted identity不变时没有清除已发 live phase的 producer。

获授权 R12-D 只关闭该同一根因：保留一个 callback与既有两种 KernelEvent，不加
schema/EventKind/allowlist/test name，把 payload升级为 exact
`RuminationPhaseCommand.set|invalidate`；Supervisor唯一 ordered/idempotent
invalidation与 async fatal owner先清 phase再 cancel/return；Orchestrator
exact-identity registry/tombstone先 mutation后 FIFO emit，App changed
clear-before-reload。#27/#35 和 source gate穷尽 second-loss、DB/invariant、
cancellation、stale/new-generation、terminal/retry/cancel/halt与restart。
Review12、Review12A、`evidence/plan-freeze.md`、
`evidence/plan-freeze-r12b.md` 与 `evidence/plan-freeze-r12c.md` 均须
byte-identical；R12-D 唯一新 evidence 为 `evidence/plan-freeze-r12d.md`。
未参与 R12-D 修订的 reviewer 只能在新 exact hashes 上创建
`reviews/12b-p1-plan-review.md`。Review12B 结论为
`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`，immutable SHA-256 为
`66b81e9e5ea0f74e08706c7367f2e80180601a000c9e84c1bbd4357a9c3b4ec5`：
R12-D 已能清 live phase，但 phase-less terminal commit与halt cleanup commit缺少
最终 App persisted-projection refresh owner。

获授权 R12-E 只关闭该同一 finding：保留一个 callback、既有两个 KernelEvent
case、13+2 allowlist、41 names与 #31；不新增schema/migration/DDL/EventKind、
持久phase/receipt或文件。invalidate command payload升级为
`RuminationInvalidationMilestone.phase|projectionCommitted`；full commit identity
由phase identity与Store实际 resulting `workVersion`组成，Supervisor在同actor turn
reserve并用per-identity coordinator保证phase/projection不并发；Orchestrator以full
identity exactly-once、per-work monotonic并发typed optional-clear event，App同一
MainActor FIFO handler always reload。halt在sorted pre-cancel phase clear后取消
tasks、持久化/cleanup，并在actual commit之后逐个refresh，最后才发didCommit/
`haltStateChanged`。#27/#35与source gate只扩展上述subcases。

Review12、Review12A、Review12B、`evidence/plan-freeze.md`、
`evidence/plan-freeze-r12b.md`、`evidence/plan-freeze-r12c.md`与
`evidence/plan-freeze-r12d.md`必须byte-identical；R12-E唯一新evidence为
`evidence/plan-freeze-r12e.md`。未参与R12-E修订的reviewer只能在新exact hashes
上创建`reviews/12c-p1-plan-review.md`。Review12C判定
`APPROVED — 0 P0 / 0 P1`前，A2产品/测试代码、A2 implementation
Review/acceptance与A3继续冻结。

R12-E candidate 后续有界审计（无 Review12C 报告）发现
`0 P0 / 2 P1 / 1 P2`：normal start/user retry transaction虽已commit queued
attempt-zero work，却不在R12-E projection publisher清单内；即使补delivery，
actor reentrancy下既有pump仍可在await sink期间先claim；active replay若从current
version合成milestone又可能重复refresh或碰撞新live generation。

获授权R12-F只关闭这两个同根P1，不采纳需要持久outbox/receipt的P2扩张：保留一个
callback、两个KernelEvent cases、13+2 allowlist、41 names、#31与全部schema/
EventKind。Store start返回既有`DurableWorkEnqueueResult`；`.inserted`由Supervisor
在同步return后验证exact `version=1`，并在第一次await/reentrancy前reserve
attempt-zero full identity并登记
global-claim barrier，所有pump/claim入口零DB claim/零跨kind skip，delivery后
release→重读mode/work→conditional kick。`.replayed`零commit milestone，只按
workId等待同进程original in-flight；delivered/restart无waiter时零补发，restart
由App persisted initial snapshot在command enable前显示recovering。立即
cancel/halt的更高version通过既有coordinator严格排在start后。

R12-F candidate独立预检（无Review12C文件）随后发现
`0 P0 / 1 P1 / 1 P2`：若允许第二production进程在当前进程target-Camp snapshot
ready后写同一DB，restart replay零milestone/零reload会留下stale queued projection；
且new specialized insert合同可比`version>=1`更精确。该P1没有扩大event/replay
refresh API，而是冻结已经存在且可验证的production single-writer invariant：
AppStore lifetime-held `StateDirectoryLock`以`flock(LOCK_EX|LOCK_NB)`先于同root唯一
production `AppDatabase(path:)`取得，第二owner fail-fast；process death释放锁后，
新owner仍须先完成startup target-Camp snapshot ready。因此该跨进程TOCTOU在当前
产品不可达，replay继续零milestone/零reload。P2同时收紧为new inserted work exact
`version=1`与start full identity `workVersion=1`；未来CLI/硬件同root writer须另开
stage设计coordination/outbox，不在A2绕锁。

Review12、Review12A、Review12B与`evidence/plan-freeze.md`、
`evidence/plan-freeze-r12b.md`、`evidence/plan-freeze-r12c.md`、
`evidence/plan-freeze-r12d.md`、`evidence/plan-freeze-r12e.md`全部
byte-identical；R12-F唯一新evidence为`evidence/plan-freeze-r12f.md`。未参与
R12-F修订的reviewer仍只能创建`reviews/12c-p1-plan-review.md`。Review12C在
R12-F exact hashes上判定`APPROVED — 0 P0 / 0 P1`前，A2产品/测试代码、red tests、
build/matrix/preview、implementation Review/acceptance与A3继续冻结。

### 28.1 R14 normal-data incident disposition and clean invocation boundary

本节是牧场主授权R14对immutable A2 implementation Review01 P1-01的有界
plan-level disposition，**不是**对R13历史的改写。R14 freeze
`66436eeeedba03e3e0a4411e208c3dd7993f5c2968952c7bff64446232ca011d`与
Review14 `5bc0adf787dabd1451c53c7fc13df817325b323b030478443f62030bbf28e405`
现均为immutable predecessors；Review14 verdict为
`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`，因此R14从未打开执行。

#### 28.1.1 Immutable incident

- R13整个implementation/completion invocation固定标记为
  `REJECTED_CONTAMINATED`。`p1-a2-durable-rumination/evidence/preview-bootstrap.log`
  记录：R13第一次preview
  的repository App原本使用isolated root且normal open count为0；随后验证工具按
  display name查询时自动启动`/Applications/AgentLoop.app` PID 74836，后者实际
  打开normal root的`.agentloop.lock`、`agentloop.sqlite`、`agentloop.sqlite-shm`
  与`agentloop.sqlite-wal`共四项；
- 该attempt已标记invalid并退出全部进程；后续fresh full-path retry单独看通过，
  但不能反向证明历史零访问。因为没有incident前normal DB content hash，任何文档
  也不得声称zero mutation；
- `impl-report.md`与`reviews/01-p1-a2-review.md`保持byte-identical historical
  evidence。Review01 verdict
  `CHANGES REQUIRED — 0 P0 / 1 P1`永久保留，不追加、不覆盖、不降级；
- 禁止为补证而读取、hash、打开、清理、恢复、重建或重置normal state root。

#### 28.1.2 New clean verification invocation

R14 candidate曾要求Review14在R14 exact Stage/总Plan/leaf/control hashes上判定
`APPROVED — 0 P0 / 0 P1`后，再由后续一次新的用户授权turn建立clean invocation。
Review14没有批准该candidate，故本小节只保留其历史incident-isolation意图，不再
具有current开门权；current且唯一的执行合同见§28.2。

R14 candidate当时要求boundary在任何targeted/full test、build、matrix、source
gate或App launch前写入R14专用evidence，至少记录：

1. 唯一boundary ID、开始时间、branch、HEAD、canonical/control/freeze、
   13+2 source/test、Package/runner/script与全部R13 historical evidence hashes；
2. `pgrep`证明没有`AgentLoop`/`AgentLoopApp`进程；若存在未知实例，只能停止并请求
   用户关闭，不得终止或检查该实例；
3. 将要使用的repository bundle/executable absolute realpath、executable hash与
   fresh `mktemp -d` isolated state root；不得`stat`、list、hash、SQLite-open或
   以其他方式读取normal state root内容；
4. 从此记录到最终退出之间，只能按exact repository path/PID操作App。禁止display
   name、bundle id、installed path或任何可能自动launch另一个App的UI lookup；
   退出后只可做shell process-presence检查，不得再调用UI状态工具。

bootstrap与cold start每次都必须证明exact executable path、两项preview
environment、全局只有一个matching App进程、DB/WAL/SHM/lock只在isolated root，
并在UI操作前后及退出前记录normal-root open-file count为0。synthetic fixture只可
写isolated DB；preview mode零provider dispatch；最终own PID与captured child均退出。
任何第二App、normal-root open、无法归属的PID、错误路径、post-quit UI call或日志
缺口都使整个boundary永久invalid：立即停止，保留证据，不得在该boundary内retry；
新尝试必须再次取得新的plan-level有界授权并创建新的、不可覆盖的boundary
evidence。

#### 28.1.3 Required re-verification and review

R14 candidate曾要求clean invocation在零产品/test drift前提下重新运行并保存
R14专用而非覆盖R13 artifact的完整输出：

- authoritative `swift run RunTests`、App build、release Core build；
- SQLite 3.51/3.52 fresh/v7/v8/v9/v10/v11/v12-durable literal + real-GRDB matrix；
- A1b/A2 source、release/DEBUG seam、41-name、privacy、scope/hash与
  `git diff --check` gates；
- 上述fresh isolated preview与true PNG；
- R14 implementation report addendum，逐项引用R13技术证据、R14新证据与historical
  incident，不重新宣称failure-first。

matrix script在R14 planning/Review14期间保持当前bytes；由于Review14未批准，
该R14单值delta从未执行。

R14 implementation、`r14-*` artifacts、Review02与acceptance均未开始。后续
implementation review与acceptance只能依据§28.2的R15证据。

acceptance必须同时陈述两件不冲突的事实：

1. R13 rejected invocation实际访问过normal state，Review01 P1-01不是“修复为没发生”；
2. 被accept的clean candidate必须是一个后续、独立、完整clean invocation，其明确boundary
   内零normal-data access且产品/test bytes与技术门通过。

不得使用“整个A2历史零normal-data access”“R13 incident已被retry修复”等表述。
R14没有扩大commit、push、merge、release、外部操作、真实用户操作或normal-data权限。

### 28.2 R15 bundle provenance and immutable rejected invocation

本节保存牧场主授权R15关闭Review14 P1-01时冻结的完整plan-level合同及其真实执行
结果。它不改写R13/R14历史，也不再具有current开门权。R15 freeze
`e5ad3967f2e2b26a2bbf8b2ef7be405e8430cc30a82d51a7cb5f51926a99e3d7`与
Review15
`fbaa9612588c39cb5d99e95d9b68e00a234510e325abf5823c15f0b1eb8ecc05`
均为immutable predecessors；Review15 verdict为`APPROVED — 0 P0 / 0 P1`，只批准
R15计划，不构成对失败boundary的追溯性通过。

#### 28.2.1 Historical review and rejected BEGIN

- R15冻结时六个surfaces统一为
  `R15 Bundle-Provenance Candidate Frozen；Review15 Pending；A2 Clean Re-verification Frozen`；
- planner当时只写三份canonical、A2 blocker、两个control indexes与
  `evidence/plan-freeze-r15.md`；未参与修订的reviewer只写
  `reviews/15-p1-plan-review.md`并判定零P0/P1；
- 牧场主随后在新的用户turn授权一次R15 clean invocation；该授权在
  `2026-07-28T18:00:01Z`写入BEGIN后消费，invocation ID为
  `r15-e20bac70-dead-4c21-8d42-541b0b8077b3`；
- BEGIN helper对Review12C记录的expected与actual均为
  `db94c2cd473cd311c79aa61b8a32b634409b9485b5b5fcef775b71ecf1f2a109`，
  但仍进入mismatch分支。只读诊断确认两侧各64字符且逐字相等，故已确认的边界是
  executor attestation false negative，而非仓库或Review12C bytes漂移；更底层触发
  机制缺乏证据，不得宣称已定位或修复；
- R15 boundary因此永久为`REJECTED_CONTAMINATED`。
  `evidence/r15-clean-boundary.log` SHA-256为
  `53eb91b840c5c8997fbc9da02d391f210f27b45d73b5e2431a6280a36110ab3b`，
  `impl-report-r15.md` SHA-256为
  `e6b0226b3440da997f7e08571d8e5e5229d66069ea5ad6485ee146c249dbe72e`；
- 失败发生在任何targeted/full test、build、matrix、source gate、bundle
  assembly/sign或preview之前；planned App从未创建，matrix Stage hash从未替换，
  产品/test/App scripts零delta，AgentLoop进程为零，normal root未被访问；
- fresh state root`/private/tmp/agentloop-r15-state.Zq6Jvm`与bundle parent
  `/private/tmp/agentloop-r15-bundle.2xROcy`仍为空并作为失败证据保留。不得清理、
  复用、改名或在该boundary继续执行。

#### 28.2.2 Four-stage provenance

R15冻结合同要求boundary在任何test/build前写BEGIN并消费一次授权，且BEGIN只记录frozen
source/test/Package/runner/two App scripts/matrix/historical hashes、recipe identity、
planned fresh bundle/state roots与no-process；不得伪造尚未生成的final executable
hash，不得读取、复用、删除或覆盖现存`.build/AgentLoop.app`。

若BEGIN通过，App debug build成功后、任何launch前必须按当时A2 leaf §11的inline exact
`r15-dev-bundle-v1`一次性写入一个独立`mktemp -d` bundle root：

1. `POST_BUILD`记录SwiftPM `AgentLoopApp` executable hash/UUID、generated resource
   bundle manifest，并证明source与generated RanchArt均为27 files、零symlink、
   canonical manifest
   `4f73a80e821faa64d0a29d797cc12e20d5f88248bbb186e74972af49798ddbab`；
2. `PRE_SIGN`证明unsigned copied executable逐byte等于build executable、UUID相同，
   copied resources逐byte等于generated bundle，且inline dev Info.plist通过lint、
   hash精确为
   `5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58`；
3. 只执行一次ad-hoc
   `/usr/bin/codesign --force --sign - <fresh AgentLoop.app>`，禁止Developer ID、
   entitlements、timestamp/notary、icon、zip/DMG或分发流程；
4. `LAUNCH_READY`执行strict codesign verify，记录identifier/signature/CDHash、
   signed bundle manifest与post-sign executable realpath/hash；codesign会改变
   executable bytes，因此post-sign hash不得与build hash比较，但UUID集合必须保持
   相同，resources必须继续匹配。

`scripts/run-app.sh`与`scripts/package-app.sh`只作为immutable hash sentinels；禁止
执行、source、截取、pipe、动态抽取plist。尤其禁止前者的`open`/LaunchServices
尾段与后者的`rm -rf dist`/release/icon/zip/DMG/notary路径。

#### 28.2.3 Launch, matrix exception and fail-closed

R15冻结合同要求bootstrap与cold start顺序、零重叠地direct exec同一
LAUNCH_READY executable，
PID只取shell`$!`，并在每次launch前重核path/hash/UUID/bundle manifest/codesign；
禁止build、re-copy、rewrite plist、re-sign或换bundle。UI工具只可绑定exact
path/PID，不能按display name、bundle id、frontmost/Dock/NSWorkspace/LaunchServices
定位。两次launch只传fresh `AGENTLOOP_STATE_DIR`与`AGENTLOOP_UI_PREVIEW=1`两个
安全键，cold start明确记录`bundle_rebuilt=false`、`bundle_resigned=false`。

matrix script在R15 planning、Review15与失败的R15 invocation全程保持entry SHA-256
`75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c`。
R15合同原允许在Review15通过、新用户授权且BEGIN成功后、matrix前机械替换line 115
唯一`expected_stage_hash`为final R15 Stage hash，并要求matrix完成或失败后立即恢复
predecessor value
`a8ca6e7a56a32e945bae185724a51d4e0015d61676bf02d9637fedc2c27d9b6f`
与entry script hash。R15在该步骤前已经停止，故该临时delta从未发生；R15最终
script delta为0。

R15冻结合同规定任一attestation/test/build/source/matrix失败、wrong/stale bundle、
source/resource/plist/
copy/signature/UUID/manifest drift、LAUNCH_READY后重建/重签、第二App、wrong
path/env/PID、normal-root access、unknown child/provider dispatch、post-quit UI call
或证据缺口都永久标记整个boundary为`REJECTED_CONTAMINATED`并停止。同boundary
不得换root、修补、rebuild/re-sign/relaunch或覆盖负证据；新尝试须再次取得
plan-level授权与新artifact names。

#### 28.2.4 Review02 and scoped acceptance

R15只写distinct `r15-*` logs/evidence与`impl-report-r15.md`；其中未到达的执行日志
保持empty，preview screenshot不存在。因为BEGIN失败，完整
BEGIN→POST_BUILD→PRE_SIGN→LAUNCH_READY→END链没有形成，Review02与acceptance从未
打开或创建。

R15不得被独立accept。任何后续clean acceptance（current gate只能由§28.8的R21
boundary打开）仍必须同时披露R13 installed-App incident、mutation unknown、
Review01未被推翻及R15 BEGIN false negative；不得声称整个A2历史零访问、
historical zero mutation或retry消除了任一事故。

### 28.3 R16 reviewed static attestation and clean invocation boundary

本节是牧场主当时授权R16只关闭R15 executor-attestation false negative的冻结
plan-level合同，现作为immutable historical predecessor保留；其真实pre-BEGIN
结果见§28.4；唯一current gate见§28.8。以下`Review16 Pending`及未来式执行文字只描述R16
freeze时的then-current状态，不再具有开门权。R16不声称已定位R15的微观触发机制，不改变§28.2已冻结的bundle、
launch、matrix、isolation、Review02或acceptance语义，也不修改任何产品/test/App
script。当前授权只允许同步六个canonical/control surfaces，新增reviewed
`r16-begin.sh`、static `r16-entry.sha256`与`plan-freeze-r16.md`，然后执行职责
隔离Review16；它不授权test、build、matrix、source gate、bundle、preview、
Review02、acceptance或A3。

#### 28.3.1 Immutable predecessor and then-current gate

- 当时六个surfaces统一为
  `R15 BEGIN REJECTED_CONTAMINATED；R16 Static-Attestation Candidate Frozen；Review16 Pending；A2 Clean Re-verification Frozen`；
- R15 freeze、Review15、`r15-*` logs/evidence、`impl-report-r15.md`、缺失的R15
  screenshot及两个空fresh roots均保持immutable。R16不得覆盖、追加、清理、改名、
  移动、复用或补齐它们；
- planner只可修订三份canonical、A2 blocker、两个control indexes，并新增
  `p1-a2-durable-rumination/evidence/r16-begin.sh`、
  `p1-a2-durable-rumination/evidence/r16-entry.sha256`与
  `p1-a2-durable-rumination/evidence/plan-freeze-r16.md`；
- 未参与R16修订、driver/manifest生成或freeze的职责隔离plan reviewer只可新增
  `reviews/16-p1-plan-review.md`。Review16必须核对R15历史、无环hash链、external
  caller、static manifest、fresh artifact names、零产品/test/App-script drift、
  matrix restoration、职责分离与Open Questions；
- Review16达到`APPROVED — 0 P0 / 0 P1`只允许牧场主在其后的**新用户turn**给出
  `freeze, Review16, driver, manifest`顺序的四个terminal SHA-256，并另行授权一次
  R16 clean invocation。Review16本身不授权执行；
- Review16前及其通过但未获上述新授权时，禁止运行R16 caller/BEGIN、任何
  targeted/full test、build、matrix、source gate、bundle assembly/sign或preview，
  禁止修改产品/test/App scripts、创建Review02/acceptance或进入A3。

#### 28.3.2 Acyclic trust chain and external caller

R16 attestation的唯一信任链固定为：

```text
frozen inputs + reviewed r16-begin.sh
  → static r16-entry.sha256
  → plan-freeze-r16.md
  → reviews/16-p1-plan-review.md
  → later user authorization carrying four terminal hashes
```

该链必须满足：

1. `r16-entry.sha256`只在driver与六个surfaces全部定稿后一次性生成。它使用
   absolute paths与standard
   `<lowercase 64-hex><two spaces><path>`格式，按path bytewise排序；至少包含
   `r16-begin.sh`、六个surfaces、全部frozen product/test/Package/runner/App-script/
   matrix inputs、R12–R15 freeze/Review chain、R13 incident evidence与全部R15失败
   artifacts；
2. static manifest不得包含自身、`plan-freeze-r16.md`、Review16或任何尚未生成的
   runtime `r16-*` artifact。六个surfaces与driver也不得嵌入manifest、freeze或
   Review16的后生成hash；
3. `plan-freeze-r16.md`记录六个surfaces、driver、static manifest及所有immutable
   inputs的exact hashes，但不记录自身或尚未生成的Review16 hash；Review16再绑定
   freeze hash。driver/manifest/freeze predecessor hashes可由其下游证据正常记录，
   但包含Review16自身hash的完整四元组只能由Review16后的新用户授权提供；任何
   upstream artifact都不得预填或推导Review16/self hash；
4. 禁止执行未先经外部验证的driver。exact caller必须在clean environment中用
   `/bin/bash --noprofile --norc`。它先把用户按`freeze, Review16, driver,
   manifest`顺序授权的四个hash与四个absolute path组成仅存在于memory/stdin的
   四行anchor manifest，
   交给`/usr/bin/shasum -a 256 --strict -c -`，再对static manifest执行同一strict
   check；两次检查均成功后才可启动
   `r16-begin.sh <freeze hash> <Review16 hash> <driver hash> <manifest hash>`。
   caller在driver前不得创建任何artifact/root；driver pre-BEGIN再证明全部R16
   runtime paths不存在。任一pre-BEGIN失败不消费授权；
5. clean environment只保留leaf冻结的非秘密命令查找/locale键；只有四个hash作为
   position arguments传入，invocation ID由reviewed driver在pre-BEGIN全绿后生成。
   不得继承shell function、alias、profile、Bash/Zsh startup file、
   expected-hash map或项目秘密。不得用Zsh执行、source或包装driver；
6. 外部caller check是driver执行前的信任锚；driver不能以“自验成功”替代它。driver在
   BEGIN evidence内重复同样两次`shasum --strict -c`只用于TOCTOU检测与可观测性；
   禁止自写expected/actual equality helper、dynamic expected map、隐式fallback或
   mismatch后继续。任一非零、missing/extra/malformed line、wrong cwd/path或hash
   drift都fail closed。

外部anchor/static-manifest检查发生在driver与BEGIN之前；任一步失败都直接停止，
不创建R16 artifacts/fresh roots、不消费授权，任何test/build/matrix/source/bundle/
preview仍不得开始。只有driver exclusive-create
`evidence/r16-clean-boundary.log`并立即写入`authorization_consumed=true`时才消费
one-shot授权；该点之后任一失败适用§28.3.4的永久拒绝。

#### 28.3.3 R16 BEGIN and fresh artifacts

`r16-begin.sh`是reviewed、静态、零产品/test/App-script写入的Bash driver；除leaf
列出的exclusive runtime artifacts与两个`mktemp -d` roots外不得写入。它必须在
任何执行门之前：

1. 要求四个position arguments均为exact lowercase 64-hex，且与external caller
   使用的四个terminal hashes相同；在任何写入前重复terminal anchors与static
   manifest检查，但不读取normal state root；
2. 证明全部runtime `r16-*` paths在BEGIN前不存在，R15 paths按frozen manifest
   存在或明确保持absent/empty状态；先exclusive-create
   `evidence/r16-clean-boundary.log`并立即写授权消费，再exclusive-create其余R16
   logs，禁止truncate、覆盖、hardlink、symlink或复用R15路径；
3. 重复四行anchor与static manifest的两次strict `shasum`检查并记录完整stdout/
   status；检查失败即写明reason、永久`REJECTED_CONTAMINATED`并停止；
4. 记录unique invocation ID、UTC、branch、HEAD、clean-environment allowlist、
   no-process、normal-root access policy、final canonical/control/freeze/review
   identities与全部frozen input verification；
5. 分别创建全新的absolute `R16_STATE_ROOT`与`R16_BUNDLE_PARENT`，证明两者为空、
   互不嵌套、planned App不存在，且不等于、不位于、不复用任何R13/R15 root；
6. 只记录planned bundle/executable paths与`r16-dev-bundle-v1` recipe identity；
   不伪造尚未build/sign的final executable hash，不读取、删除或复用
   `/Users/muzi/Agent-loop/.build/AgentLoop.app`。

R16使用一整套全新的、leaf逐路径冻结的`r16-*` logs/evidence、
`impl-report-r16.md`与preview screenshot；driver开始前任何runtime R16路径预存在
都阻止授权消费和BEGIN。不得创建或修改`r15-*`、`impl-report-r15.md`、R13 artifacts、
旧Review/acceptance。normal root仍只允许从owned process的`lsof`输出作path
comparison；禁止`ls`、`find`、`stat`、hash、SQLite-open、cleanup、reset、rebuild
或其他内容访问。

#### 28.3.4 Inherited execution gates, failure and completion

BEGIN成功后，R16机械继承§28.2.2–§28.2.3的四阶段provenance与launch合同，并由A2
leaf给出exact Bash commands与artifact paths：

- App build后、任何launch前只可一次性执行inline `r16-dev-bundle-v1`，依次写
  `POST_BUILD→PRE_SIGN→LAUNCH_READY`；Info.plist literal、RanchArt 27-file
  manifest、unsigned executable/resource equality、single ad-hoc codesign、
  post-sign executable/UUID/CDHash/signed-bundle manifest与禁止两条App scripts/
  LaunchServices的语义逐字继承R15冻结合同；
- bootstrap与cold start必须顺序、零重叠复用同一LAUNCH_READY signed bundle，只以
  exact path与shell`$!` PID direct exec；LAUNCH_READY后禁止rebuild、re-copy、
  rewrite plist、re-sign或换bundle；
- matrix script的entry SHA-256仍为
  `75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c`。
  只有Review16通过、新用户授权、external checks与BEGIN均成功后，才可在matrix前
  机械替换line 115唯一`expected_stage_hash`为final R16 Stage hash；matrix成功或
  失败后必须立即恢复predecessor value
  `a8ca6e7a56a32e945bae185724a51d4e0015d61676bf02d9637fedc2c27d9b6f`
  与entry script hash，其他bytes始终零delta；
- 任一external/BEGIN attestation、test/build/source/matrix失败，wrong/stale
  bundle、source/resource/plist/copy/signature/UUID/manifest drift、
  LAUNCH_READY后重建/重签、第二App、wrong path/env/PID、normal-root access、
  unknown child/provider dispatch、post-quit UI call或证据缺口都永久标记整个R16
  boundary为`REJECTED_CONTAMINATED`并立即停止。同boundary不得换root、修补、
  rebuild/re-sign/relaunch、覆盖负证据或retry；若matrix已临时改变，只允许恢复
  entry value/hash作containment，恢复不重新打开任何门；
- 只有全部R16 gates通过、END证明产品/test/two App scripts/final matrix script
  零drift、normal open count为0且owned process/child全退出后，新的职责隔离
  implementation reviewer才可写`reviews/02-p1-a2-review.md`。Review02达到零P0/P1
  后才打开independent acceptance；
- acceptance只能声明R16 boundary内zero normal-data access，必须同时披露R13
  installed-App incident、mutation unknown、Review01及R15 BEGIN false negative；
  不得声称整个A2历史零访问、historical zero mutation或任一retry消除了事故。
  acceptance通过前不得进入A3。

### 28.4 R17 Bash ERR-trap/status-capture root-cause closure

本节保存R16真实pre-BEGIN结果、牧场主授权的R17有界修订及其最终被Review17拒绝的
历史。R17 freeze
`bdbbbd025bbe7cf57032ae2276a6a559043f60e47cebad1ceac43f992e644e1f`、
Review17
`c6838d3c5a9fcfef80dc9db4abf560af712e3175372a163edccb72197daf3dbe`、
driver
`cf1baab60b3e799b1780b20d1dfc7887bdd2c7e85e241fdb8abcd4ad8c04321f`、
Bash 3.2 probe
`5ee154b56d10322fd70ad34698a7f0fd81122862d25b9bbb05b1db18bee67199`
与manifest
`7d10c5c6747cdf0e557befc76a62ea101f2fc4168a49d8076bedd3331d8cbd17`
均为immutable rejected-plan predecessors。Review17 verdict为
`CHANGES REQUIRED — 0 P0 / 1 P1`；它没有开门权。R17 caller/BEGIN、测试、构建、
matrix、source、bundle/sign与preview从未执行，全部R17 runtime paths及两类fresh
root均未创建。以下future-tense文字只记录R17 freeze时的then-current合同，不得被
解释为当前授权；唯一current gate见§28.8。

R17不改变
schema/API/event/package、产品/test bytes、两条App scripts、matrix脚本或§28.2的
source→build→fresh bundle→single ad-hoc sign→same-bundle direct-exec语义；它只
根因级修订reviewed BEGIN driver中受全局`ERR` trap影响的13个status-capture
blocks，增加Bash 3.2 micro-probes，并使用全新R17 planning/runtime names。

#### 28.4.1 Immutable R16 pre-BEGIN outcome

- R16 freeze
  `c10ae51ad78b414aab18c3785b79aac49feb73c47ac5fdcb896ca874ae319867`、
  Review16
  `71f16eceef429f7d02fe8908c4609b9bd0b0b98b44c68b579a75ced2ac9d9824`、
  driver
  `ffa61fa7c8c281cdb8dfb853b38aafce9536ddcc276e18d64c082de8887b55b0`
  与manifest
  `0c2f5dc59e5f0e193214d1c8532a91818a339abdfb3150177c680fe61f8a0b1e`
  均为immutable predecessors；
- Review16 verdict为`APPROVED — 0 P0 / 0 P1`。牧场主随后在新用户turn按
  `freeze, Review16, driver, manifest`顺序逐字提供四个terminal hashes并授权；
- external caller四anchor check与110/110 static manifest check均通过。driver到达
  `pre_begin_processes`，首个`/usr/bin/pgrep -x AgentLoop`以正常“进程不存在”
  返回`rc=1`；
- driver已在全局`set -E`下安装`ERR` trap；局部`set +e`只关闭errexit，不解除
  `ERR` trap。该trap在`r16_process_rc="$?"`和预期`case 1`前退出，故这是
  executor status-capture false positive，不是进程存在、仓库漂移、anchor失败或
  manifest失败；
- `evidence/r16-clean-boundary.log`从未创建，唯一授权消费点未到达，
  `authorization_consumed=false`。全部12个R16 runtime paths以及
  `/private/tmp/agentloop-r16-state.*`、`/private/tmp/agentloop-r16-bundle.*`
  不存在；没有运行targeted/full test、build、matrix、source、bundle/sign或
  preview，也没有产品/test/App-script delta；
- R16不得写成BEGIN或`REJECTED_CONTAMINATED`，不得重跑当前caller、补写runtime
  evidence、创建R16 roots或把absence改成成功证据。

#### 28.4.2 Thirteen capture blocks and Bash 3.2 proof

R17必须一次关闭以下13个继承捕获块，不能只patch绿色路径必现的`pgrep`：

1. pre-BEGIN terminal-anchor pipeline；
2. pre-BEGIN static-manifest `shasum`；
3. process-absence `pgrep`；
4. empty-directory `find` command substitution；
5. preserved R15 root `realpath` command substitution；
6. fresh root `realpath` command substitution；
7. post-activation terminal-anchor pipeline；
8. post-activation static-manifest `shasum`；
9. RanchArt regular-file `find` command substitution；
10. RanchArt path-transform command-substitution pipeline；
11. RanchArt exact-set `diff`；
12. RanchArt nonregular-node `find` command substitution；
13. RanchArt regular-count command-substitution pipeline。

统一合同为：

- 禁止`set +e; <bare command>; rc=$?; set -e`及其pipeline/substitution变体；
- simple command必须在`if`条件内执行，then写`rc=0`，else第一条写真实`rc=$?`；
- pipeline必须在`if`条件内执行，then/else两支第一条都立即复制完整
  `PIPESTATUS`，不得先执行其他命令；
- command substitution在subshell内先`trap - ERR`，外层再以`if assignment`
  捕获真实status；含pipeline时保留`pipefail`；
- 禁止`|| true`、silent fallback、`!`后猜测被反转status、吞掉indeterminate rc、
  generic化specific reason或在active failure path重复写负证据。

planner新增`evidence/r17-bash32-probes.sh`，只允许在planning/Review阶段以clean
macOS `/bin/bash --noprofile --norc`运行；它不得调用driver或任何产品执行门。
probe必须fail-fast覆盖simple/pipeline/substitution三类，至少证明`pgrep rc=1`、
`diff rc=1`、indeterminate `rc=2`、pipeline component nonzero与command-
substitution nonzero均保留真实status，且全局`ERR` trap没有抢占。

#### 28.4.3 R17 artifacts, trust chain and entry gate

六个current surfaces统一为：

`R15 BEGIN REJECTED_CONTAMINATED；R16 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED；R17 Status-Capture Candidate Frozen；Review17 Pending；A2 Clean Re-verification Frozen`

planner只可修订三份canonical、A2 blocker与两个control indexes，并新增：

- `p1-a2-durable-rumination/evidence/r17-begin.sh`；
- `p1-a2-durable-rumination/evidence/r17-bash32-probes.sh`；
- `p1-a2-durable-rumination/evidence/r17-entry.sha256`；
- `p1-a2-durable-rumination/evidence/plan-freeze-r17.md`。

未参与R17修订、driver/probe/manifest/freeze生成的职责隔离reviewer唯一可新增
`reviews/17-p1-plan-review.md`。唯一无环信任链为：

```text
immutable predecessors + final six surfaces
  + reviewed r17-begin.sh + r17-bash32-probes.sh
  → static r17-entry.sha256
  → plan-freeze-r17.md
  → reviews/17-p1-plan-review.md
  → later user authorization carrying four terminal hashes
```

`r17-entry.sha256`固定为115项absolute-path、bytewise sorted unique strict
manifest；它在R16的110项coverage上增加R17 driver、R17 probe、immutable
`r16-entry.sha256`、R16 freeze与Review16。它必须包含final six surfaces、R16
driver及全部既有product/test/sentinel/script/RanchArt/incident/failure chain；
不得包含自身、R17 freeze、Review17或任何runtime R17 artifact。

Review17达到`APPROVED — 0 P0 / 0 P1`也不执行。后续新用户turn仍须按
`freeze, Review17, driver, manifest`顺序逐字提供四个final SHA-256。external
caller先用in-memory/stdin四行manifest和standard
`/usr/bin/shasum -a 256 --strict -c`核四anchors，再strict-check静态manifest，
两次全绿后才可exec reviewed driver；任一步失败零写入、不消费授权。

R17 driver pre-BEGIN还必须证明：

- 全部12个runtime R17 paths不存在；
- 全部12个R16 runtime paths与两类R16 fresh-root glob仍不存在；
- R15两个保全root仍为canonical non-symlink empty directories，R15 planned App与
  screenshot仍不存在；
- exact branch/HEAD、115-entry manifest、RanchArt结构和AgentLoop/AgentLoopApp
  process absence全部成立。

只有exclusive-create`evidence/r17-clean-boundary.log`并在同一初始化写
`authorization_consumed=true`才消费授权；随后才可创建其余fresh `r17-*` logs与
两个`agentloop-r17-*` roots。pre-consumption失败零写入；consumption后任何失败
永久`REJECTED_CONTAMINATED`，同boundary零retry。

#### 28.4.4 Inherited execution, review and acceptance

Review17通过并取得新的四hash执行授权前，禁止R17 caller/BEGIN、targeted/full
test、build、matrix、source gate、bundle assembly/sign、preview、产品/test/
App-script修改、Review02、acceptance或A3。

BEGIN成功后，R17只把§28.3.4与A2 leaf §10–§12中的R16 runtime/recipe names机械
替换为fresh R17 names，其他四阶段provenance、matrix唯一Stage-hash临时delta与
mandatory restoration、same-bundle direct exec、normal-root isolation、fail-once
和END zero-drift合同不变。任一失败立即停止；不得重build、换root、re-sign、
relaunch或覆盖负证据。

只有R17 END与全部技术门形成完整证据后，新的职责隔离implementation reviewer才
可写`reviews/02-p1-a2-review.md`；Review02零P0/P1后才打开independent acceptance。
acceptance只能声明R17 clean boundary内zero normal-data access，并必须同时披露
R13 installed-App incident/mutation unknown/Review01、R15
`REJECTED_CONTAMINATED` BEGIN false negative，以及R16 pre-BEGIN
`authorization_consumed=false`/zero-write false positive。不得声称整个A2历史零
访问、historical zero mutation或任一retry消除了事故。

### 28.5 R18/R18-A RanchArt pre-consumption and R15 tombstone closure

本节记录已经被Review18拒绝、从未执行的R18/R18-A candidate。牧场主先授权R18关闭Review17 P1-01；在freeze前
只读发现两个exact R15 volatile roots已经absent后，又明确授权R18-A按A2
`blocked.md` §24关闭同一current-entry drift。R18-A只把R17继承的preserved-root
`realpath` command-substitution capture一对一替换为联合exact-basename
parent-enumeration capture；inherited合同仍为`2P / 4S / 7C = 13`，另计既有
R16/R17/R18 root-glob absence C后，driver总数仍为`2P / 4S / 8C = 14`。其他12个
inherited capture blocks与immutable `r17-bash32-probes.sh`保持不变；不改变
schema/API/event/package、产品/test bytes、两条App scripts、matrix脚本或§28.2的
source→build→fresh bundle→single ad-hoc sign→same-bundle direct-exec合同。

#### 28.5.1 Immutable R17 rejection and bounded delta

R17 freeze、Review17、driver、probe与manifest的exact hashes依次为：

- `plan-freeze-r17.md`：
  `bdbbbd025bbe7cf57032ae2276a6a559043f60e47cebad1ceac43f992e644e1f`；
- `reviews/17-p1-plan-review.md`：
  `c6838d3c5a9fcfef80dc9db4abf560af712e3175372a163edccb72197daf3dbe`；
- `r17-begin.sh`：
  `cf1baab60b3e799b1780b20d1dfc7887bdd2c7e85e241fdb8abcd4ad8c04321f`；
- `r17-bash32-probes.sh`：
  `5ee154b56d10322fd70ad34698a7f0fd81122862d25b9bbb05b1db18bee67199`；
- `r17-entry.sha256`：
  `7d10c5c6747cdf0e557befc76a62ea101f2fc4168a49d8076bedd3331d8cbd17`。

Review17已静态证明Bash syntax、clean Bash 3.2 probe与115/115 manifest全绿，但以
`CHANGES REQUIRED — 0 P0 / 1 P1`关闭：R17在消费授权后才检查RanchArt新增regular/
nonregular节点，违反canonical pre-consumption zero-write语义。R17没有plan
approval，也没有执行授权；caller/BEGIN、targeted/full test、build、matrix、source、
bundle/sign与preview均未运行，全部12个R17 runtime paths及
`/private/tmp/agentloop-r17-state.*`、`/private/tmp/agentloop-r17-bundle.*`均未创建。
这些事实与全部R15/R16历史保持immutable；Review17不再具有任何开门权。

R15 durable evidence只证明R15 containment时两个exact roots被观察为canonical
non-symlink empty directories。2026-08-02 pre-freeze只读复核确认
`/private/tmp/agentloop-r15-state.Zq6Jvm`与
`/private/tmp/agentloop-r15-bundle.2xROcy`均为`ABSENT`，消失原因只能记录为
`UNKNOWN`；不得归因于reboot、OS cleanup、用户或agent，也不得声称从R15到R18
连续保全。R18-A把这两个exact identities冻结为absorbing tombstones：
`CANONICAL_EMPTY → ABSENT`是允许的历史单向转移，当前`ABSENT`以后不得转回任何
filesystem node；即使重新出现为canonical empty directory也必须fail closed。

R18只允许同步六个canonical/control surfaces，新增
`evidence/r18-begin.sh`、`evidence/r18-entry.sha256`与
`evidence/plan-freeze-r18.md`，并由未参与R18修订、driver/manifest/freeze生成的
职责隔离reviewer唯一新增`reviews/18-p1-plan-review.md`。R18复用且不得修改上述
immutable `r17-bash32-probes.sh`；不新增第二probe或第二RanchArt verifier。

#### 28.5.2 Single phase-aware RanchArt verifier

`r18-begin.sh`必须只有一个phase-aware RanchArt结构verifier；preflight与
post-activation都调用同一个函数、同一份冻结的27-path expected set与同一套
Bash 3.2-safe status-capture逻辑。每次调用都重新读取真实
`Sources/AgentLoopApp/Resources/RanchArt`，同时证明：

1. expected 27个相对路径各自是regular non-symlink file；
2. 实际regular-file相对路径集合bytewise sorted后与expected exact set相等，既无
   missing也无extra；
3. tree中symlink、directory之外的special node及其他nonregular node计数为0；
4. `find`、path transform、exact-set comparison与count任一返回unexpected或
   indeterminate status都fail closed，不得降级成empty/equal/zero。

所有branch/HEAD、119-entry manifest、R18/R17/R16 runtime/path/root absence、R15
exact tombstone/App/screenshot与process absence等zero-write pre-BEGIN门通过后，
driver把
`phase=pre_consumption`的同一verifier作为**唯一授权消费前的最后一个fallible
precondition**。该调用不得创建temp file、artifact、root或持久日志，也不得缓存
或向post-activation传递preflight结果；失败必须在零写入、
`authorization_consumed=false`下退出。
成功后，下一个filesystem mutation才可排他创建
`evidence/r18-clean-boundary.log`并在同一初始化写
`authorization_consumed=true`，同时只记录两个
`r15_state_root_pre_begin_observed_state=ABSENT`、
`r15_bundle_parent_pre_begin_observed_state=ABSENT`、
`r15_state_root_current_absent=true`、`r15_bundle_parent_current_absent=true`、
`r15_absence_proof_identity=private_tmp_parent_enumeration_exact_basename_v1`与
`disappearance_cause=UNKNOWN`。tombstone proof必须成功枚举exact `/private/tmp`
parent且两个exact basenames都不存在；enumeration nonzero、parent missing/non-dir/
symlink、任何basename重现为directory/file/symlink/dangling symlink/special node，
以及final `-e || -L`重检发现重现，都fail closed。不得创建物理tombstone或访问、
删除、清理、重建、复用旧root；不能把probe failure当作absent。

消费后只能先exclusive-create全新的R18 hash log；在创建任何其他runtime
artifact/root之前，driver必须立即以`phase=post_activation`从filesystem重新调用
同一verifier并把phase、`regular_count=27`、exact relative-path-set与
`nonregular_count=0`写入该log，不得复用preflight结果。该verifier不计算或冒充逐
文件content hash。结构证据落盘后，driver必须独立重新执行post-activation
119-entry `shasum --strict -c`，逐文件重校全部bytes（其中包括27个RanchArt files）
并记录producer/shasum statuses。冻结的RanchArt manifest SHA
`4f73a80e821faa64d0a29d797cc12e20d5f88248bbb186e74972af49798ddbab`
只记录expected source identity，不是structure verifier新生成的证明。任一结构
读取、119-entry bytes复核失败或两次结构观测不一致，立即把该R18 boundary永久标为
`REJECTED_CONTAMINATED`并停止，同boundary零retry。

该双读合同不声称filesystem transaction、atomic snapshot或目录锁。preflight只
证明其读取时已经存在的结构污染不会错误消费授权；post-activation重读覆盖两次
观测间可见的TOCTOU变化。若节点在两次读取之间改变后又恢复，或在第二次读取后改变，
本门不声称单独检测；后者仍由后续source/resource/build/bundle/END manifests
fail closed。需要消除整个观测间隙必须另开stage设计真实filesystem lock/snapshot，
不得在R18文档或acceptance中虚构该保证。

#### 28.5.3 R18 manifest, freeze and review chain

R18 candidate六个surfaces当时必须逐字统一为：

`R15 BEGIN REJECTED_CONTAMINATED；R16 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED；R17 PLAN CHANGES REQUIRED — NOT EXECUTED；R18-A Tombstone Candidate Frozen；Review18 Pending；A2 Clean Re-verification Frozen`

`r18-entry.sha256`固定为119项absolute-path、lowercase SHA-256、two-space、
`LC_ALL=C` bytewise sorted unique strict manifest。它继承R17 manifest的115项path
coverage并以R18 final bytes重新计算hash，再仅增加以下四项：

1. reviewed `evidence/r18-begin.sh`；
2. immutable `evidence/r17-entry.sha256`；
3. immutable `evidence/plan-freeze-r17.md`；
4. immutable `reviews/17-p1-plan-review.md`。

immutable `r17-bash32-probes.sh`已经在继承的115项中，不重复计数。manifest必须
包含final six surfaces、产品/test/sentinel/App/matrix/RanchArt与全部历史链；不得
包含自身、R18 freeze、Review18或任何runtime R18 artifact。唯一无环信任链为：

```text
immutable predecessors + final six surfaces
  + immutable r17-bash32-probes.sh + reviewed r18-begin.sh
  + immutable r17-entry.sha256 + R17 freeze + Review17
  → static r18-entry.sha256
  → plan-freeze-r18.md
  → reviews/18-p1-plan-review.md
  → later user authorization carrying four terminal hashes
```

Review18必须重新核对119/119 strict manifest、single-verifier source/control-flow、
pre-consumption零写入顺序、post-activation同源重读/evidence、明确TOCTOU边界、R17
P1-01关闭、R15 historical-empty/current-ABSENT分层、absorbing tombstone与联合parent
enumeration fail-closed语义、一个C职责替换后inherited 13/driver-total 14精确计数、
immutable R15/R16/R17历史、fresh names、零产品/test/App-script delta、职责分离与
Open Questions。Review18达到`APPROVED — 0 P0 / 0 P1`只允许请求牧场主
在其后的新用户turn按`freeze, Review18, driver, manifest`顺序逐字提供四个final
SHA-256；Review18本身不执行任何门。

external caller必须先以in-memory/stdin四行manifest和standard
`/usr/bin/shasum -a 256 --strict -c`核验这四个terminal hashes，再strict-check
119-entry manifest，全部通过后才可在clean
`/usr/bin/env -i`、`/bin/bash --noprofile --norc`中exec reviewed driver。caller
不得创建artifact/root；任一失败零写入且不消费授权。

#### 28.5.4 Fresh runtime boundary and inherited completion

R18使用全新的12个`r18-*`/report paths：`r18-targeted-tests.log`、
`r18-verify.log`、`r18-build.log`、`r18-migration-matrix.log`、
`impl-report-r18.md`、`evidence/r18-clean-boundary.log`、
`evidence/r18-bundle-provenance.log`、`evidence/r18-source-gates.log`、
`evidence/r18-hash-manifest.log`、`evidence/r18-preview-bootstrap.log`、
`evidence/r18-preview-cold-start.log`与`evidence/r18-preview-smoke.png`，以及互不
嵌套的fresh `/private/tmp/agentloop-r18-state.*`和
`/private/tmp/agentloop-r18-bundle.*`。pre-BEGIN必须证明这些R18 paths/roots、
全部R17与R16 runtime paths及两代root globs均不存在，并重新证明R15两个exact
root identities继续为`ABSENT` absorbing tombstones、planned App/screenshot
absent；不得读取、复用、删除、清理、重建旧root或补写任何旧boundary。

Review18通过并取得新的四hash执行授权前，继续禁止external caller/BEGIN、
targeted/full test、build、matrix、source gate、bundle assembly/sign、preview、
产品/test/App-script修改、Review02、acceptance、A3、commit、push、merge、release、
normal-data、外部与真实用户操作。

BEGIN成功后，R18只把§28.2.2–§28.2.4、§28.4.4与A2 leaf §10–§12的runtime/recipe
names机械替换为fresh R18 names；四阶段provenance、matrix唯一Stage-hash临时delta
与mandatory restoration、same-bundle direct exec、normal-root isolation、
fail-once和END zero-drift合同不变。任一失败立即停止；不得重build、换root、
re-sign、relaunch或覆盖负证据。

只有R18 END与全部技术门形成完整证据后，新的职责隔离implementation reviewer才
可写`reviews/02-p1-a2-review.md`；Review02零P0/P1后才打开independent acceptance。
acceptance只能声明R18 clean boundary内zero normal-data access，并必须披露R13
installed-App incident/mutation unknown/Review01、R15 rejected BEGIN、R16
pre-BEGIN authorization-unconsumed/zero-write false positive与R17
plan rejection/not-executed；不得声称整个A2历史零访问或虚构atomic filesystem
snapshot/lock。

### 28.6 R19 lossless pathname transport closure

本节以下内容是R19冻结时的历史执行合同；其实际结果见§28.6.5，唯一current gate已转至
§28.8。职责隔离Review18 SHA-256为
`e0ee95f3703d73810d756410373c1da65fb1e08b08f6d7f74555e8095a12608b`，verdict为
`CHANGES REQUIRED — 0 P0 / 1 P1`。其唯一P1-01证明R18把真实pathname经
`find -print`、command substitution和line-oriented `sed/sort/diff/wc`运输，映射不是
单射；一个包含LF的regular basename可编码成两个expected lines，使stable
contaminated tree在授权消费前假绿。Review18没有运行driver/BEGIN或任何执行门，R18
12个runtime paths与fresh roots均保持absent；R18/R18-A从未获得plan approval或
四-hash执行授权。

R18 immutable terminal identities为：

- freeze：`62bbf93031371659e7ad2d4c60aac002eb13ed0915854f741e40251c9c2c1e76`；
- Review18：`e0ee95f3703d73810d756410373c1da65fb1e08b08f6d7f74555e8095a12608b`；
- driver：`911bbbc70556e41122cfdcc90048e504eee3480246b338131153856d524d7af9`；
- manifest：`71e512a25e6e9bc0d024a53ad2502b55a378a82b39044a341930e1df440cfc2a`。

上述四项仅是失败审计链，永不构成执行授权。牧场主随后以新的明确用户turn授权R19
只关闭同一pathname-serialization根因；该授权允许planning/freeze/Review19，不允许
caller、BEGIN或任何产品执行门。

#### 28.6.1 Bounded write set and current status

R19 planner只可同步六个canonical/control surfaces，并新增
`evidence/r19-begin.sh`、`evidence/r19-entry.sha256`与
`evidence/plan-freeze-r19.md`。未参与R19六面、driver、manifest或freeze修订的职责
隔离reviewer唯一新增`reviews/19-p1-plan-review.md`。R18 driver/manifest/freeze/
Review18、immutable `r17-bash32-probes.sh`、全部R15–R17历史及产品/test/App/matrix
script bytes不得修改、重跑、追加或重分类。

六个current surfaces必须逐字统一为：

`R15 BEGIN REJECTED_CONTAMINATED；R16 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED；R17 PLAN CHANGES REQUIRED — NOT EXECUTED；R18/R18-A PLAN CHANGES REQUIRED — NOT EXECUTED；R19 Pathname-Exact Candidate Frozen；Review19 Pending；A2 Clean Re-verification Frozen`

canonical Stage §29、total Plan §19与A2 leaf §13的Open Questions继续精确为`无。`。

#### 28.6.2 Single lossless phase-aware verifier

`r19-begin.sh`只能有一个phase-aware RanchArt verifier与一份唯一、runtime检查为27项
且bytewise unique的ASCII expected basename array。pre-consumption和
post-activation两次调用必须重新读取真实
`Sources/AgentLoopApp/Resources/RanchArt`，不得缓存、传递或复用第一次结果。

每次读取只允许一个lossless pathname pipeline：

```text
/usr/bin/find -P <RanchArt> -mindepth 1 -maxdepth 1 -print0
  | inline Bash 3.2 validator using IFS= read -r -d ''
```

NUL stream禁止进入command substitution、line split、`for ... in $(...)`、
`sed/sort/diff/wc -l`或raw text evidence。pipeline producer与validator的
`PIPESTATUS`必须在then/else分支第一条命令完整复制，且只有两个status都为0才成功；
stderr不得混入NUL stream。validator必须：

1. 先证明RanchArt root是real non-symlink directory；`find -P`枚举全部direct
   children，不用`-type f`预先缩小universe，因而dotfile、symlink、dangling
   symlink、directory、FIFO/socket/device都进入同一检查；
2. 完整drain stream；EOF时若`read -d ''`留下nonempty partial record则fail closed；
   不得因首个bad node提前关闭pipe并用SIGPIPE掩盖producer traversal status；
3. 在`LC_ALL=C`且`nocasematch`关闭时，从enumeration返回的full path以parameter
   expansion取得actual basename bytes；禁止通过expected-path lookup推断actual
   spelling，避免case-insensitive APFS把case variant当成expected；
4. 使用27-slot indexed `seen[]`、饱和到28的directory-entry count与quoted exact
   equality；每个actual node都必须`-f && ! -L`并恰好匹配一个expected literal，
   结束时27个slot各为1且count精确27；missing、extra、duplicate、LF/CR/control
   pathname、Unicode confusable、case variant、dotfile和任何nonregular node均失败；
5. 在exact/type/count proof完成前不得把raw pathname写入line-oriented evidence。
   失败只允许固定reason code与numeric producer/validator status；成功后因为actual
   已被证明等于safe expected ASCII set，parent才可按expected固定顺序写
   `pathname_transport=find_print0_bash_read_d_nul_v1`、两个status、exact-set block、
   `regular_count=27`、`nonregular_count=0`与`symlink_count=0`。

R18旧RanchArt的regular-find C、transform-pipeline C、exact-set diff S、nonregular-
find C与count-pipeline C共`1S + 4C`五个capture blocks必须整体删除，由上述一个
NUL pipeline P取代。R19 current core inventory因此精确为
`3P / 3S / 3C = 9`；另计覆盖R16/R17/R18/R19 fresh-root glob absence的一个C后，
driver total精确为`3P / 3S / 4C = 10`。R17的`2P / 4S / 7C = 13`和R18的13/14
只作为immutable历史，不得冒充current计数。既有immutable Bash 3.2 probe继续验证
通用P/S/C capture；R19 planning/Review阶段另允许只在内存/stdin运行零文件写入的
`read -d ''` micro-probe，不新增probe artifact，也不调用driver或产品门。

所有terminal anchors、123-entry manifest、branch/HEAD、R16/R17/R18/R19 runtime/
root absence、R15 absorbing tombstones、planned App/screenshot与process absence通过后，
pre-consumption verifier仍必须是boundary exclusive-create前最后一个fallible
precondition；它与boundary之间不得再生成UUID/timestamp、执行substitution或其他门。
失败只写`/dev/stderr`，保持零repository/runtime write与
`authorization_consumed=false`。成功后的下一个mutation才可exclusive-create
`evidence/r19-clean-boundary.log`并写`authorization_consumed=true`。

消费后只可先exclusive-create `evidence/r19-hash-manifest.log`，随后立即以同一lossless
verifier做post-activation filesystem reread并写canonical structure evidence；之后才
独立执行123-entry strict content manifest。任何post structure/content failure永久标记
该boundary为`REJECTED_CONTAMINATED`，同boundary零retry。该双读仍不声称atomic
filesystem snapshot/lock；节点在两次观测间改变后恢复或第二次观测后改变继续由后续
source/resource/build/bundle/END manifests fail closed。本轮不扩大hardlink/inode、
xattr/resource-fork或dirfd lock合同。

#### 28.6.3 123-entry manifest, freeze and Review19

`r19-entry.sha256`必须是123项absolute-path、lowercase SHA-256、two-space、
`LC_ALL=C` bytewise sorted unique strict manifest。它精确继承immutable R18 manifest
的119-path coverage且无删除，以R19 final bytes重算hash，再只增加：

1. reviewed `evidence/r19-begin.sh`；
2. immutable `evidence/r18-entry.sha256`；
3. immutable `evidence/plan-freeze-r18.md`；
4. immutable `reviews/18-p1-plan-review.md`。

六面更新后，immutable R18 manifest对current filesystem必须恰好six surfaces六个
mismatch，其余113/119 unchanged；不得修改旧manifest来恢复119/119。R19 manifest
必须123/123 PASS，包含final six surfaces、R16–R19 drivers、immutable R17 probe、
产品/test/sentinel/App/matrix/RanchArt、R13 evidence、freezes through R18、Reviews
through Review18、R15 failure artifacts与R16/R17/R18 manifests；不得包含自身、
R19 freeze、Review19或任何runtime R19 artifact。

唯一无环信任链为：

```text
immutable predecessors + final six surfaces
  + immutable R17 probe and complete R18 chain + reviewed r19-begin.sh
  → static r19-entry.sha256
  → plan-freeze-r19.md
  → reviews/19-p1-plan-review.md
  → later user authorization carrying four terminal hashes
```

Review19必须独立核对123/123、R18 only-six/113 preservation、single verifier/set、
lossless NUL transport、full drain/partial-record handling、byte-exact actual spelling、
all-node universe、safe evidence、9/10 capture inventory、pre-boundary最后顺序、
post reread/content gate、R15 tombstone、R16–R18 absence、fresh R19 names、无环链、
零产品/test/App-script delta、owner separation与Open Questions。Review19达到
`APPROVED — 0 P0 / 0 P1`只允许请求后续新用户turn按
`freeze, Review19, driver, manifest`顺序逐字给出四个final SHA-256；Review19本身
不得运行任何执行门。

#### 28.6.4 Fresh R19 boundary and inherited completion

R19使用全新的12个paths：`r19-targeted-tests.log`、`r19-verify.log`、
`r19-build.log`、`r19-migration-matrix.log`、`impl-report-r19.md`、
`evidence/r19-clean-boundary.log`、`evidence/r19-bundle-provenance.log`、
`evidence/r19-source-gates.log`、`evidence/r19-hash-manifest.log`、
`evidence/r19-preview-bootstrap.log`、`evidence/r19-preview-cold-start.log`与
`evidence/r19-preview-smoke.png`，以及fresh、互不嵌套的
`/private/tmp/agentloop-r19-state.*`和`/private/tmp/agentloop-r19-bundle.*`。
pre-BEGIN必须证明这些paths/roots和全部R16/R17/R18 runtime paths/root globs不存在，
并重新证明R15两个exact tombstones保持`ABSENT`、planned App/screenshot absent；不得
读取、创建、删除、清理或复用任何旧root或补写旧boundary。

Review19通过并取得新的四-hash执行授权前，继续禁止external caller/BEGIN、
targeted/full test、build、matrix、source gate、bundle assembly/sign、preview、
产品/test/App-script修改、Review02、acceptance、A3、commit、push、merge、release、
normal-data、外部与真实用户操作。

BEGIN若在后续四-hash授权下成功，R19只把§28.2.2–§28.2.4、§28.5.4与A2 leaf
§10–§12的runtime/recipe names机械替换为fresh R19 names；四阶段provenance、matrix
唯一Stage-hash临时delta与mandatory restoration、same-bundle direct exec、normal-root
isolation、fail-once和END zero-drift合同不变。只有R19 END与全部技术门完成后，新的
职责隔离implementation reviewer才可写Review02；其零P0/P1后才打开independent
acceptance。acceptance只能声明R19 boundary内zero normal-data access，并必须披露
R13 incident/mutation unknown、R15 rejected BEGIN、R16 authorization-unconsumed、
R17/R18 plan rejection/not-executed；不得虚构整个A2历史零访问或atomic snapshot。

#### 28.6.5 Immutable R19 execution result

Review19最终SHA-256为
`4588cd645edd47c7648f9c8e372fb4de42f2b8dd3a2bfeb31282aba2d6e7c41c`，verdict为
`APPROVED — 0 P0 / 0 P1`。牧场主随后以R19 freeze
`d7869b0531f5dc868a1e8d92b2aec9f0abf3cd84e0d3857b481f8fcc3807d03f`、Review19、
driver `95a29f4452502a236bd73ac42a9741bf31e66fa6108bcdf4572b5fcc1eef190d`与
manifest `71dede4ad9a86c52e853d36af8629a491e84854badfaf0962054f06e86fcfb43`
四hash授权clean execution。invocation
`r19-daef1dab-0fbe-4a03-bab1-422adc18b3d4`成功到达`BEGIN_ATTESTED`，pre/post
lossless verifier与123/123 manifest均PASS，41-name A2 gate为41/41 PASS。

紧接的唯一一次权威、未过滤`swift run RunTests`发现652 tests / 7 suites并以651 PASS、
1 FAIL退出。唯一失败是`slowActiveStreamDoesNotIdleTimeout`，source为
`Sources/AgentLoopTestSuite/AgentLoopTests.swift:611`，终态错误为
`响应流异常中断：idle script exhausted`。R19 boundary因此在full-tests phase永久
`REJECTED_CONTAMINATED`，`retry_same_boundary=false`。build/release、matrix、source、
bundle/sign、preview与END均未运行；planned App与screenshot不存在，产品/test与matrix
script零漂移，normal-data零访问。

以下11个已存在artifact及其bytes全部immutable：非空的`r19-targeted-tests.log`、
`r19-verify.log`、`impl-report-r19.md`、`evidence/r19-clean-boundary.log`、
`evidence/r19-hash-manifest.log`，以及空的`r19-build.log`、
`r19-migration-matrix.log`、`evidence/r19-bundle-provenance.log`、
`evidence/r19-source-gates.log`、`evidence/r19-preview-bootstrap.log`、
`evidence/r19-preview-cold-start.log`。exact roots
`/private/tmp/agentloop-r19-state.dNgUXh`与
`/private/tmp/agentloop-r19-bundle.49xVDm`保持real non-symlink empty directory并作为
失败证据保留。不得覆盖、追加、补写、删除、清理、移动、重命名、复用或用后续成功
改写上述artifact/root；R19永不再具有执行权。

### 28.7 Historical R20 deterministic-time root-cause closure

本节保存R20当时的plan及其现已失败的execution evidence，不再具有current开门权；
唯一current A2 gate见§28.8。R19日志与R20 entry source共同证明：
`slowActiveStreamDoesNotIdleTimeout`只向`IdlePatternProvider`提供一个`.events` step，
25个event各以真实`Task.sleep(50ms)`延迟，逻辑总时长约1.25秒，而production idle
timeout为1秒。任一full-suite scheduling gap超过1秒都会先触发idle timeout；retry第二次
调用已耗尽single scripted step，最终才显示`idle script exhausted`。这个诊断是
`INFERRED_FROM_FAILURE_LOG_AND_CURRENT_SOURCE`，足以证明现有test依赖wall-clock且不
确定，但不把尚未复现实验区分的host starvation与production watchdog bug虚构为定论。

#### 28.7.1 Planning authority, bounded writes and current status

牧场主已在紧接R20 planning-only请求的新用户turn明确回复“继续，授权R20”。planner
只可同步六个canonical/control surfaces，并新增`evidence/r20-begin.sh`、
`evidence/r20-entry.sha256`与`evidence/plan-freeze-r20.md`。未参与R20 six-surface、
driver、manifest或freeze修订的职责隔离reviewer唯一新增
`reviews/20-p1-plan-review.md`。Review20前不得修改产品/test/App/matrix/RunTests bytes，
不得调用caller/driver/BEGIN或任何test/build/runtime gate。

六个current surfaces必须逐字统一为：

`R15 BEGIN REJECTED_CONTAMINATED；R16 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED；R17 PLAN CHANGES REQUIRED — NOT EXECUTED；R18/R18-A PLAN CHANGES REQUIRED — NOT EXECUTED；R19 BEGIN REJECTED_CONTAMINATED — AUTHORITATIVE FULL TEST 651/652；R20 Deterministic-Time Candidate Frozen；Review20 Pending；A2 Clean Re-verification Frozen`

canonical Stage §29、total Plan §19与A2 leaf §13的Open Questions继续精确为`无。`。

#### 28.7.2 Exact two-file implementation exception

R20是A2 authoritative verification的shared-infrastructure prerequisite，不打开P1-F1，
也不扩大R13 historical 13+2 allowlist。只有Review20达到
`APPROVED — 0 P0 / 0 P1`且牧场主在其后的新用户turn按
`freeze, Review20, driver, manifest`顺序逐字提供四个final SHA-256并明确授权后，
implementer才可且必须只修改：

1. `Sources/AgentLoopCore/Loop/AgentLoop.swift`，entry SHA-256
   `5ec55a86b4548410b3f9ae876f7f8356d4a89e1024ef92f173412164c194a1bc`；
2. `Sources/AgentLoopTestSuite/AgentLoopTests.swift`，entry SHA-256
   `28f5b4287a1004daaca962db375c9ea24ac0f06d0f6abbd0c6ecd277696abfb2`。

不得新增source/test file、target、dependency、package edge、schema、migration、public
API或release-visible testing symbol；其他产品/test/App/script bytes全部immutable。

`AgentLoop.swift`必须使用一个private clock factory与单一generic
`IdleWatchdog<C: Clock>`（`C.Duration == Duration`）复用真实deadline、`beat`与
`waitForTimeout`算法。既有public `AgentLoop.init`签名、参数与默认值逐字不变；普通
production path每attempt仍由factory创建`IdleWatchdog(clock: ContinuousClock())`。
只有`#if DEBUG`下、external label精确为`idleClockForTesting`的package generic
initializer可接受test Clock并创建同一个generic watchdog；禁止fake watchdog、第二套
timeout算法或把manual time带入release。

`AgentLoopTests.swift`内的`ManualAgentLoopClock`必须真实遵循`Clock`，以`NSLock`保护单调instant、
唯一waiter ID与checked throwing continuation；`@unchecked Sendable`只允许用于clock
storage。任何continuation都必须先从lock内移除、释放lock后再resume；advance与cancel
路径必须exactly-once，禁止double resume、遗留waiter、真实sleep或轮询。

#### 28.7.3 Five deterministic named tests and anti-paper-over red lines

同一次未过滤、失败不重跑的权威`swift run RunTests`必须发现并通过以下五个exact
names各一次；它们与既有41个A2 names形成46/46 subset audit，但subset绝不替代整个
full suite全绿：

1. `slowActiveStreamDoesNotIdleTimeout`：逻辑总时长严格大于timeout、每段严格小于
   timeout；终态completed、timeout retry为0、provider `callCount == 1`；
2. `turnTimeoutRetriesOnceThenBlocks`：两个attempt各在watchdog armed后显式advance到
   deadline；恰好一次timeout retry，最终blocked、`callCount == 2`；
3. `timeoutThenSuccessDoesNotAccumulate`：每个provider turn首attempt timeout、次attempt
   success，证明`timeoutCount`按turn重置而不跨turn累计；
4. `cancelWinsOverIdleTimeout`：watchdog armed后先cancel outer task，等待
   `ManualAgentLoopClock` cancellation barrier确认waiter已移除或以`CancellationError`
   恢复，再advance超过
   deadline；结果必须canceled且零waiter。覆盖cancel-before-register与
   register-before-cancel exactly-once，不宣称simultaneous tie的调度优先级；
5. `turnCompletesUnderTimeout`：零advance立即完成，watchdog被取消且零waiter。

controlled provider禁止`Task.sleep`。每个event acknowledgment必须发生在真实
`watchdog.beat`完成之后才允许manual clock advance；测试必须用barrier避开
exact-deadline race，不能靠scheduler luck推断顺序。

R20禁止增加idle timeout、缩短逻辑流或扩大事件间隔余量，禁止`.serialized`、skip、
filter、关闭/修改RunTests并发、失败后重跑直到green、复制scripted provider step、吞掉
`idle script exhausted`、接受旧R13 green或只跑单测。release Core必须通过symbol gate
证明`AgentLoop.swift`中`idleClockForTesting`全部occurrences位于matching `#if DEBUG`，
release `AgentLoop.swift.o`经`nm -j | xcrun swift-demangle`该token count=0、debug count>0；
`ManualAgentLoopClock`只存在test source。debug tests反向证明走的是与production相同的
generic watchdog算法。

#### 28.7.4 140-entry manifest and immutable R19 evidence

`r20-entry.sha256`必须是精确140项absolute-path、lowercase SHA-256、two-space、
`LC_ALL=C` bytewise sorted unique strict manifest。它完整继承R19的123-path coverage且
无删除，以final six-surface bytes重算hash，再增加：

1. reviewed `evidence/r20-begin.sh`；
2. immutable `evidence/r19-entry.sha256`、`evidence/plan-freeze-r19.md`与
   `reviews/19-p1-plan-review.md`；
3. immutable R19 runtime/failure artifacts精确11项：`r19-targeted-tests.log`、
   `r19-verify.log`、`r19-build.log`、`r19-migration-matrix.log`、`impl-report-r19.md`、
   `evidence/r19-clean-boundary.log`、`evidence/r19-bundle-provenance.log`、
   `evidence/r19-source-gates.log`、`evidence/r19-hash-manifest.log`、
   `evidence/r19-preview-bootstrap.log`与`evidence/r19-preview-cold-start.log`；
4. §28.7.2两个source/test entry baselines。

六面更新后immutable R19 manifest对current filesystem必须恰好six surfaces mismatch、
其余117/123 unchanged；不得改旧manifest恢复123/123。R20 BEGIN前及activation后、任何
source/test edit前，R20 manifest必须140/140 PASS。授权实施后，最终entry-manifest
审计必须恰好只有§28.7.2两个authorized source paths mismatch、其余138/140 unchanged，
两path仍为regular non-symlink；另由source/release gates、final hashes与职责隔离diff
review证明其语义。不得错误要求modified source重新匹配entry hash，也不得把第三个
mismatch洗成authorized delta。

R20 manifest不包含自身、R20 freeze、Review20或任何runtime R20 artifact。唯一无环
信任链为：

```text
immutable predecessors + final six surfaces + complete immutable R19 chain
  + two source baselines + reviewed r20-begin.sh
  → static r20-entry.sha256
  → plan-freeze-r20.md
  → reviews/20-p1-plan-review.md
  → later user authorization carrying four terminal hashes
```

#### 28.7.5 Fresh R20 execution and completion gate

R20使用fresh 12个paths：`r20-targeted-tests.log`、`r20-verify.log`、`r20-build.log`、
`r20-migration-matrix.log`、`impl-report-r20.md`、`evidence/r20-clean-boundary.log`、
`evidence/r20-bundle-provenance.log`、`evidence/r20-source-gates.log`、
`evidence/r20-hash-manifest.log`、`evidence/r20-preview-bootstrap.log`、
`evidence/r20-preview-cold-start.log`与`evidence/r20-preview-smoke.png`，以及fresh、
互不嵌套的`/private/tmp/agentloop-r20-state.*`和
`/private/tmp/agentloop-r20-bundle.*`。pre-BEGIN必须证明这些names/roots全部absent，
并只读证明R19两个exact roots仍为real non-symlink empty directory、11 artifacts及
缺失screenshot状态精确；不得读取其内容作为runtime input、写入、删除、清理或复用。

future caller/driver只可在任何edit/test前核对四terminal anchors、140/140 manifest及
继承的R19 lossless pathname/root/process gates并写`BEGIN_ATTESTED`。随后才允许两文件
implementation。只运行一次未过滤`swift run RunTests`并把完整输出写`r20-verify.log`；
失败立即永久拒绝且不得重跑。full suite全绿后，才可从同一日志机械提取既有41+新增5
exact names各一次的discovery/PASS证明写`r20-targeted-tests.log`；不得第二次运行或用
subset替代full。其余build/release/matrix/source/provenance/preview/END顺序继承
§28.2.2–§28.2.4与A2 leaf §10–§12并机械使用fresh R20 names。

Review20达到`APPROVED — 0 P0 / 0 P1`只允许请求后续四-hash执行授权。此前继续禁止
caller/BEGIN、任何test/build/matrix/source/bundle/sign/preview、两个授权source/test
文件及任何其他产品/test/App-script修改、Review02、acceptance、A3、commit、push、
merge、release、normal-data、外部与真实用户操作。只有R20 END和全部技术门完成，新的
职责隔离implementation reviewer才可写Review02；其零P0/P1后才打开independent
acceptance。acceptance必须披露R19 651/652 rejection，不得把R19 roots/artifacts改写为
R20成功证据。

### 28.8 R21 release-configuration root-cause closure

本节是唯一current A2 plan gate。它只关闭R20已经由真实release failure证明的同一根因：
SwiftPM对automatic library product执行`swift build -c release --product AgentLoopCore`
时退化为default graph，release configuration因而同时编译未被DEBUG guard隔离的
TestSuite caller，而Core的`idleClockForTesting` callee已正确从release配置移除。

#### 28.8.1 Immutable R20 result and planning authority

R20 freeze、Review20、driver、manifest依次为：

- `0b698b59f214f23c26db88fd53763c4a600becaf898a716344f9d666ac2e8e07`；
- `e70ea918e00c334a452f87e4fa8f44d5bfc754b042872a9f0a0ec13015e7c68e`；
- `840edee2dad7710f17e1b9bb8dcaa1484224ba0784b636f472bc2934f7e7eaeb`；
- `2f8a6f4f786a2b5f432b2dbf7dcdc7208788d0b9ef5b9cdaa9de422bfaf88e81`。

invocation `r20-98452cde-0ff4-4b66-b3f6-8085eb045a6f`永久为
`REJECTED_CONTAMINATED`，boundary精确为phase=`release_core_build`、
reason=`release_AgentLoopCore_build_failed_rc_1`、exit=1、retry=false。唯一full
RunTests 652/652（SHA-256
`1aea8510917a6a3f72b9b2ab63cc2e90bc209481bf119f6de7c3a0ea74fea4e5`）、同log 46/46
（`5d438374c029ce803903b339876189ccb1d632f4e28f87ae4ee2021a3b56e775`）、debug App
build与POST_BUILD/PRE_SIGN/LAUNCH_READY都是真实、immutable partial evidence；它们不
覆盖release failure，也不满足A2完成门。boundary、hash、build、bundle evidence hashes
依次为`f221507a75730a0a2cf2f0f2fd6213d26e956e0860aef70878f30bc9b4dee6df`、
`5ef1e15c81dacc59872a1b9b1d8a999c19cee5516598564737cbcba764214450`、
`317efebd212133c292e2bc3ddc3e837f2c6acf47e450d48f1c32b9b25b26b5b4`、
`839ce977cbdace6cadd8ce2ee2a0bcc1a5f798389c4d1977a5dcb18ef63d921e`；matrix、source、
bootstrap、cold-start logs保持empty-file hash，screenshot保持absent。

R20 final Core/TestSuite SHA-256分别是
`c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`与
`66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26`。state root
`/private/tmp/agentloop-r20-state.3QwlQa`保持real non-symlink empty；bundle parent
`/private/tmp/agentloop-r20-bundle.30V5RH`保持real non-symlink directory且direct child
精确为signed `AgentLoop.app`。其executable、Info.plist与signed-bundle manifest hashes
分别为`d55fc10e674b77b480a85de46137eff40d40bd94b27c8e33b0d49f55d40a049c`、
`5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58`、
`06e063d4fdd541a808c78eacc5b34ddfd64874a3ab1648bbfe6bf74646db8170`。全部R20 11个
repository artifacts、两个roots、signed App与缺失screenshot状态不得覆盖、append、
补写、删除、清理、移动、重签、启动、重命名或复用。

牧场主已逐字授权R21 planning-only。planner只可同步current六面（其定义已经包含
A2 leaf与blocker），并新增`evidence/r21-begin.sh`、`evidence/r21-entry.sha256`及
`evidence/plan-freeze-r21.md`；未参与R21修订、driver/manifest/freeze生成的职责隔离
reviewer唯一写`reviews/21-p1-plan-review.md`。六面current status必须为：

`R15 BEGIN REJECTED_CONTAMINATED；R16 PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED；R17 PLAN CHANGES REQUIRED — NOT EXECUTED；R18/R18-A PLAN CHANGES REQUIRED — NOT EXECUTED；R19 BEGIN REJECTED_CONTAMINATED — AUTHORITATIVE FULL TEST 651/652；R20 BEGIN REJECTED_CONTAMINATED — RELEASE CORE BUILD FAILURE AFTER AUTHORITATIVE FULL 652/652；R21 Release-Configuration Candidate Frozen；Review21 Pending；A2 Clean Re-verification Frozen`

#### 28.8.2 Exact one-file guard exception

`Sources/AgentLoopCore/Loop/AgentLoop.swift`必须保持R20 final bytes/hash不变。future
implementation唯一source delta是：在R20 final
`Sources/AgentLoopTestSuite/AgentLoopTests.swift`原地增加三对direct matching
`#if DEBUG`/`#endif`，不移动、不重排、不修改既有逻辑或其他bytes：

1. 第一对从`ManualAgentLoopClock`前开始，在`OneShotGate`后、`runLoop`前结束；它
   连续覆盖`ManualAgentLoopClock`、`ControlledIdleProviderError`、
   `ControlledIdleProvider`、`AgentEventProbe`、`OneShotGate`；
2. 第二对只包围完整`startControlledLoop` declaration/body；
3. 第三对只包围五个连续exact tests：`turnTimeoutRetriesOnceThenBlocks`、
   `cancelWinsOverIdleTimeout`、`timeoutThenSuccessDoesNotAccumulate`、
   `slowActiveStreamDoesNotIdleTimeout`、`turnCompletesUnderTimeout`。

禁止`#else`/`#elseif`、nested conditional、第四对guard、新file/target/dependency/package
edge、Package.swift、public/package API、release-visible test seam、schema/migration、其他
产品/test/App/RunTests/matrix-script修改。source gate必须以direct-region line-state parser
证明上述11个tokens全部且只在三段DEBUG regions内；从final TestSuite source删除且只删除
上述六行exact directive后，bytes/hash必须精确恢复R20 final
`66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26`。

#### 28.8.3 Target-exact release and four-object symbol gates

R21当前release命令顺序精确为：

```bash
swift build -c release --target AgentLoopCore
swift build -c release --target AgentLoopTestSuite
```

禁止把第一条改回`--product AgentLoopCore`或接受automatic-product fallback。两条命令都
必须独立返回0；第一条成功后先记录release Core exact object hash，第二条成功后该hash
必须不变。

只以`swift build -c release --show-bin-path`和
`swift build -c debug --show-bin-path`查询canonical configuration roots，精确构造：

- `$releaseBin/AgentLoopCore.build/AgentLoop.swift.o`；
- `$releaseBin/AgentLoopTestSuite.build/AgentLoopTests.swift.o`；
- `$debugBin/AgentLoopCore.build/AgentLoop.swift.o`；
- `$debugBin/AgentLoopTestSuite.build/AgentLoopTests.swift.o`。

bin paths必须分别是`$REPO/.build/<single-component>/release|debug`；每个object必须是
canonical regular non-symlink file，其exact parent必须是canonical real non-symlink
directory并精确为对应bin下的`AgentLoopCore.build`或`AgentLoopTestSuite.build`。layout
变化即fail closed；禁止
`find -quit`、glob、搜索替代object或固定共享`/tmp` nm文件。每项只以
`nm -j <exact-object> | xcrun swift-demangle`读取，保留`pipefail`；任一端非零或空输出
都失败。Core token `idleClockForTesting`必须release count=0/debug count>0；上节11个
TestSuite tokens必须在release Test object逐项count=0、debug Test object逐项count>0。
count以`awk index()` substring机械计算，不以grep status或推测代替。

#### 28.8.4 Manifest, fresh boundary and completion

`r21-entry.sha256`精确155项：完整继承R20 140-path set且零删除，再增加R21 driver、
immutable R20 manifest/freeze/Review20及R20 11个runtime artifacts。六面更新与R20两项
implementation已经发生后，旧R20 manifest对current filesystem必须恰好132 unchanged +
8 mismatch（final six surfaces + Core/TestSuite），不能修改旧manifest洗绿。R21实施前
155/155；实施后必须154 unchanged + `AgentLoopTests.swift`唯一authorized mismatch，
`AgentLoop.swift`仍匹配entry。第二个mismatch即永久失败。

R21 reviewed BEGIN-only driver使用全新12个`r21-*`/report paths及
`/private/tmp/agentloop-r21-state.*`、`/private/tmp/agentloop-r21-bundle.*`，继承R20
lossless NUL/tombstone/R19 containment，并在授权消费前后重证完整R20 evidence、exact
state root及exact-one-child signed App parent。retained App必须由不带`-type`过滤的
`find -P ... -mindepth 1 -print0` all-node universe送入单一NUL validator，精确证明36个
relative nodes（6个real non-symlink directories + 30个regular non-symlink files）的
seen/type/file-hash集合；任何额外、缺失、未知或控制字符pathname都在序列化前失败。
validator只在实际集合完全匹配后输出固定safe expected literals，并复算signed-bundle
manifest为`06e063d4fdd541a808c78eacc5b34ddfd64874a3ab1648bbfe6bf74646db8170`。
四段失败只记录safe numeric find/validator/shasum/hash-validator statuses，不记录actual
pathname。capture inventory按outer driver中面向全局ERR trap的unique parent capture
blocks计数；inline child validator的逐文件hash子状态由该外层P封装、不重复计数。因此
core为`8P/4S/8C=20`，加fresh-root-glob check后driver-total为`8P/4S/9C=21`。BEGIN后只运行
一次未过滤`swift run RunTests`；full全绿后从同一log机械审计46/46。之后唯一顺序为：
debug App build → fresh bundle assembly/sign及POST_BUILD/PRE_SIGN/LAUNCH_READY → R21
pre-release guard-shape/strip source sub-gate → 两条target-exact release → 四object symbol
gates → matrix → remaining source/privacy/final-hash gates → same-bundle preview → END。
每步fail once；任一失败永久`REJECTED_CONTAMINATED`且不得retry、补丁、换object/root或
覆盖负证据。

Review21必须在R21 exact hashes上判定`APPROVED — 0 P0 / 0 P1`；该verdict本身不执行。
只有其后的新用户turn按`freeze, Review21, driver, manifest`顺序逐字给出四个final
SHA-256并明确授权，才可打开caller/BEGIN及上述one-file guard implementation。此前继续
禁止caller/BEGIN、test/build/matrix/source/bundle/sign/preview、产品/test/App-script
修改、Review02/acceptance、A3、commit/push/merge/release/normal-data/外部及真实用户
操作。

### 28.9 R22 volatile-containment and automatic-attestation closure

本节取代§28.8作为唯一current A2 plan gate；§28.8与R21四锚、driver、manifest、freeze、
Review21均转为immutable predecessor。R21在牧场主按顺序提供freeze
`82ec117359bb0172867ed476c0da4a8d7d0fc60c5bd24f25c0f42e360f7996a4`、Review21
`13f75ac2979a25c8cf643e83f264663087c6bc18836696c518b247d7f6d3176b`、driver
`c56db7b465ae3d54923d958892e07e5575d4cf67b8b4946c7d6793e4f1bfb835`与manifest
`d5567a05e61e61a94b732814e24a89ecdb8e2a988d970dac33939f31798a9d86`授权后，external
caller四锚与155/155 manifest通过；driver随后在`pre_begin_r19_containment`因冻结的
exact-two-retained-root假设返回70。失败发生在boundary、hash log、runtime paths、UUID与
fresh roots创建前；R21 12 paths及两类root globs保持ABSENT，Core/TestSuite仍为R20 final
hash。因此R21终态只能是`PRE-BEGIN STOPPED — AUTHORIZATION_NOT_CONSUMED — ZERO WRITE`，
不得创建、补写、重跑或改写任何R21 runtime evidence。

#### 28.9.1 Volatile historical-root state machines

R19 exact state/bundle roots与R20 exact state root在历史boundary中被观察为canonical real
non-symlink empty directories，当前只读复核均为ABSENT，原因只能记录为UNKNOWN。R22按
既有R15 tombstone合同把三者冻结为
`HISTORICAL_CANONICAL_EMPTY → ABSENT_TOMBSTONE`；ABSENT为absorbing，任何file、directory、
symlink、dangling symlink或special node重现都fail closed，即使重现为空目录也不接受。
验证必须在前后`-e || -L` bookends之间，以
`find -P /private/tmp -mindepth 1 -maxdepth 1 -print0`完整枚举top-level universe并由Bash 3.2
`read -r -d ''` validator完整drain；不得用filtered `find`、newline serialization、probe
failure或missing status冒充ABSENT，也不得创建physical tombstone。

R20 bundle parent `/private/tmp/agentloop-r20-bundle.30V5RH`与exact child
`AgentLoop.app`只允许
`VERIFIED_RETAINED → VERIFIED_RETAINED|ABSENT_TOMBSTONE`及
`ABSENT_TOMBSTONE → ABSENT_TOMBSTONE`。retained分支必须重新证明canonical parent、
exact-one-child、36-node all-node NUL set、30项file hashes、signed aggregate及strict
codesign；任一验证失败立即失败，禁止reclassify为disappearance。只有下一次独立full-parent
classification从一开始精确观察为ABSENT，或pre-BEGIN retained而post-activation full-parent
classification精确变成ABSENT，才可记录单向transition；ABSENT后任何重现、alternate
`agentloop-r20-{state,bundle}.*`、wrong type、extra/missing child或hash/codesign drift均失败。
第一次完整观测必须另存immutable `FIRST_OBSERVED_STATE`；重复pre-BEGIN与全部post-activation
观测逐次使用同一单向表，不能由后一次preflight覆盖首见ABSENT再接受retained。同一次
classification的initial/complete-verification/late-bookend只允许retained→retained或
absent→absent；retained→absent只能发生在两个完整、独立观测之间。

#### 28.9.2 Standing Goal and local self-attestation

牧场主在R21精确四hash授权后把长期Goal更新为“不需要哈希值每步确认，继续完整落地，一路
推进”。该standing authority取消人工逐轮回传hash，但不取消职责隔离、plan freeze、Review、
branch/HEAD、manifest、BEGIN consumption或fail-once。Review22达到
`APPROVED — 0 P0 / 0 P1`后，agent不得再次询问用户；automatic caller必须先确认Goal未被
更新用户turn撤销，再读取Review22唯一machine block、校验verdict与其中的freeze/driver/
manifest hashes，机械计算Review22 current SHA，并以clean environment、absolute path只把
该一个SHA参数传给`r22-begin.sh`。driver独立重读machine block、核对四个current anchors、
159/159 manifest、branch/HEAD及全部containment后才可BEGIN。

Review22正文必须有且仅有一个逐字独立行`Verdict: APPROVED — 0 P0 / 0 P1`，并不得有其他
以`Verdict:`开头的行。machine block逐字shape
为：唯一`R22_MACHINE_BLOCK_BEGIN/END`，内部恰有12行：
`authority_mode=standing_goal_automatic_after_review22`、
`standing_goal_authority_verified=true`、`reviewer_independence_attested=true`、
`reviewer_write_scope=review22_only`、`user_hash_echo_required=false`、
`review_verdict=APPROVED_0_P0_0_P1`、三个lowercase 64-hex
`freeze_sha/driver_sha/manifest_sha`、固定branch/HEAD与`manifest_count=159`。该local
consistency只绑定当前filesystem与caller→driver TOCTOU，不冒充human anti-rewrite、独立
身份的密码学证明或外部signature；Review22职责隔离attestation是本地control-plane
trust anchor。

#### 28.9.3 159-entry manifest, fresh boundary and implementation

`r22-entry.sha256`精确159项：完整继承R21 155-path set且零删除，只增加R22 driver、
immutable R21 manifest、R21 freeze与Review21。它排除自身、R22 freeze、Review22、全部
R22 runtime paths及temp roots。六面同步后旧R21 manifest必须精确149 unchanged + final
six surfaces六个mismatch；R22实施前159/159，实施后必须158 unchanged +
`AgentLoopTests.swift`唯一authorized mismatch，Core继续匹配R20 final hash；第二个mismatch
永久失败。

R22使用fresh 12 paths：`r22-targeted-tests.log`、`r22-verify.log`、`r22-build.log`、
`r22-migration-matrix.log`、`impl-report-r22.md`、`evidence/r22-clean-boundary.log`、
`evidence/r22-bundle-provenance.log`、`evidence/r22-source-gates.log`、
`evidence/r22-hash-manifest.log`、`evidence/r22-preview-bootstrap.log`、
`evidence/r22-preview-cold-start.log`、`evidence/r22-preview-smoke.png`，以及fresh
`/private/tmp/agentloop-r22-state.*`与`agentloop-r22-bundle.*`。pre-BEGIN失败零写入且不
消费authority；boundary path须先在短暂signal-masked临界区exclusive-create，EEXIST直接
pre-BEGIN拒绝且零append；只有本进程exclusive-create成功才立即标记authority consumed，
随后初始化内容。初始化partial/failure/signal都必须在该自有file留下永久
`REJECTED_CONTAMINATED`，不得污染既有regular path或误报零写入。boundary后第一批只读动作
立即复证R21 paths/roots与R19/R20 lifecycle；后续在hash evidence及fresh-root前后继续复证。

产品delta与§28.8完全相同：`AgentLoop.swift`保持R20 final bytes；唯一source change是在
`AgentLoopTests.swift`原地增加冻结的三对、六行direct DEBUG directives，strip后精确恢复
R20 final TestSuite hash。BEGIN后的唯一顺序仍是one unfiltered full RunTests → same-log
46/46 → debug App build → fresh bundle/sign及LAUNCH_READY → guard-shape/strip → 两条
target-exact release → 四object symbols → matrix/restoration → remaining source/privacy/hash
→ same-bundle preview → END。

Review22前禁止automatic caller、driver/BEGIN、guard实施及任何test/build/matrix/source/
bundle/sign/preview。只有R22 END和全部技术门完成后，新的职责隔离implementation reviewer
才可写Review02；其零P0/P1后才打开independent acceptance。acceptance必须披露R19/R20
historical-empty/current-ABSENT unknown disappearance、R20 bundle最终observed state、R21
pre-BEGIN零写入/未消费，并只声明R22 boundary内zero normal-data access。A3、commit、push、
merge、release、normal-data、外部与真实用户操作继续关闭。

### 28.10 R23 frozen erosion-snapshot closure

本节取代§28.9成为唯一current A2 plan gate。R22六面、driver、159-entry manifest与freeze
保持immutable；职责隔离Review22
`bf007443ac2b1932fbde93cf908a99b50cb4878de3e485118092bb24552050b5`
判定`CHANGES REQUIRED — 0 P0 / 1 P1`，没有approval machine block，也没有运行caller、
`r22-begin.sh`、BEGIN或任何execution gate。R22 12个runtime paths与两个fresh-root globs
从未创建，authority未消费；禁止补写、重跑、清理、移动或改造R22与R20历史证据。

Review22只读观察到R20 exact bundle parent及exact `AgentLoop.app`仍为canonical real
non-symlink directories，但App内只剩六个历史目录、零regular files：`Contents`、
`Contents/MacOS`、`Contents/Resources`、
`Contents/Resources/AgentLoop_AgentLoopApp.bundle`、
`Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt`与
`Contents/_CodeSignature`。Info.plist、executable、全部27项RanchArt files与
CodeResources均ABSENT，strict codesign非零。R23不得把该partial skeleton写成当前signed
App、不得恢复任何已消失节点，也不得把verification failure伪装成删除。

#### 28.10.1 Fixed 38-bit universe and Review22 baseline

R23对R20 bundle采用唯一固定38-bit mask，顺序不可改变：

1. bit 0：exact R20 bundle parent；
2. bit 1：exact `AgentLoop.app`；
3. bits 2–8：依次为`Contents`、`Contents/Info.plist`、`Contents/MacOS`、
   `Contents/MacOS/AgentLoop`、`Contents/Resources`、inner resource bundle、
   `RanchArt`；
4. bits 9–35：R20冻结36-node数组中27项RanchArt file的原顺序；
5. bits 36–37：`Contents/_CodeSignature`与`CodeResources`。

Review22 observation机械映射后的planning baseline逐字为
`11101011100000000000000000000000000010`，38 bits、8个`1`。该baseline中的每个`0`
从R23首个runtime capture前即已吸收；首个A必须先通过`BASELINE → A`逐bit仅`1→0`，
因此历史file或任何已观察ABSENT节点重现即失败，不能由`FIRST=A`吸收。合法complete
snapshot只有：

- `00`加36个`0`：bundle parent absent；
- `10`加36个`0`：parent-only；
- `11`加一个仅能是baseline node bits子集的36-bit mask：App partial subset。

`01`、extra pathname、alternate R20 root、symlink、dangling symlink、special node、
wrong type或remaining file hash漂移均失败。每个仍为`1`的目录必须保持exact historical
directory type；每个仍为`1`的file必须保持R20冻结SHA。R20 state root继续是原因UNKNOWN
的absorbing tombstone；R20 bundle自身只在R23 invocation内按该mask单向erosion，不创建
physical tombstone。

#### 28.10.2 Double-complete capture and in-process commit

每次pre-BEGIN、immediate post-activation、post-manifest与post-root observation都由两个
完整capture A/B组成。每个capture必须：

- 在`-e || -L`前后bookends之间，以`find -P /private/tmp -mindepth 1 -maxdepth 1 -print0`
  完整drain top-level universe，拒绝所有alternate R20 identities；
- 若parent存在，完整drain direct-child NUL universe，只允许零child或exact App；
- 若App存在，以同一个`find -P App -mindepth 1 -print0` validator完成pathname membership、
  type与每个present file hash验证，并直接输出唯一36-bit node mask与node/dir/file counts；
  禁止再用第二次filesystem读取拼接mask；
- 在subtree full drain后再次验证parent与App的presence、type、non-symlink canonical
  realpath及exact-child shape；任何find/read/hash/type/shape、abnormal EOF或
  `PIPESTATUS`失败都fatal，绝不能编码成`0`。

`R23_R20_CAPTURED_*`与node/dir/file counts是诊断working registers：A、B各次capture会在
full drain期间先reset再逐步更新，失败时可以保留incomplete/A/B staging；它们不是已接受的
erosion lifecycle state，任何安全判断都不得把其比较前值当作commit。第一次pair在提交
FIRST/LATEST与accepted mode-B前验证`BASELINE → A`与`A → B`；后续pair验证
`LATEST → A`与`A → B`，所有比较逐bit只允许`1→0`或不变。只有全部比较通过后才更新：首pair
`FIRST=A, LATEST=B`，后续只推进`LATEST=B`；pre/post accepted mode各记录其B，并把诊断
CAPTURE/counts最终normalize为B。第二capture、comparison或bookend失败时FIRST/LATEST与
accepted mode-B保持pair开始前的已提交值；诊断CAPTURE/counts可反映失败点的staging且必须
如此标注。仅在FIRST/LATEST、final CAPTURE/count normalization与accepted mode-B这组
in-process assignments期间，HUP/INT/TERM handlers临时改为只记录deferred signal；全部
assignment完成后立即恢复fail handlers，并立刻按任一deferred signal永久拒绝。
authorization消费后的fail path必须记录safe global baseline、FIRST、LATEST与当前诊断
capture mask/state/counts；0→1错误还必须记录fixed bit与comparison label。

R23不提供filesystem transaction、filesystem lock或atomic snapshot，也不证明
inode/hardlink、xattr或resource fork不变，不能消除TOCTOU；完全发生并消失在两个capture
可见窗口之外的短暂节点可能不被观察到。本文的“原子”只指所有比较通过后，当前进程一次性
提交FIRST/LATEST变量。若未来要求原子文件系统保证，必须另开stage并重新Review。

只有mask为38个`1`、36 nodes/6 directories/30 files全部重新验证、aggregate精确匹配且
strict codesign为0时才允许写`current_signed_app_verified=true`。由于Review22 baseline已
含30个file zeros，该分支在R23 current route不可达；partial/parent-only/absent只能记录
historical executable、Info.plist与signed aggregate hashes，不得声称当前signed App。

#### 28.10.3 R23 entry, manifest and execution boundary

`r23-entry.sha256`精确163项：完整继承R22 159-path set且零删除，只增加
`r23-begin.sh`、immutable `r22-entry.sha256`、immutable `plan-freeze-r22.md`与immutable
Review22；排除自身、R23 freeze、Review23、所有R23 runtime paths与temp roots。六面同步后
旧R22 manifest必须精确153 unchanged + six current-surface mismatches；R23 implementation
前163/163，实施后162 unchanged + `AgentLoopTests.swift`唯一mismatch，Core继续匹配R20
final bytes。R23 driver的Bash 3.2 ERR-facing unique outer-parent inventory必须冻结为
`8P / 4S / 13C = 25`；inline child validator状态不重复计数。

R22的12 runtime paths与`agentloop-r22-{state,bundle}.*`须在R23 preflight、final
pre-BEGIN、immediate post-activation与post-root四处继续证明ABSENT。R23只能创建fresh
12个`r23-*`/`impl-report-r23.md` paths及fresh distinct
`agentloop-r23-{state,bundle}.*` roots。boundary exclusive-create、signal、partial
initialization、zero-write/authority-consumption与fail-once语义沿用§28.9，但boundary名改为
`R23_EROSION_SNAPSHOT_AND_RELEASE_CONFIGURATION_REPAIR`。

Review23只能由未参与R23六面/driver/manifest/freeze写作的职责隔离reviewer唯一写，正文只能
有一个`Verdict: APPROVED — 0 P0 / 0 P1`行及唯一12-line `R23_MACHINE_BLOCK`：
`authority_mode=standing_goal_automatic_after_review23`、standing Goal、independence、
write-scope、no-hash-echo、machine verdict、freeze/driver/manifest三hash、固定branch/HEAD
与`manifest_count=163`。Review23通过且无更新用户turn撤销standing Goal后，agent自动计算
Review23 SHA并只传该一个参数给frozen driver，不再请求用户echo hashes。

future产品delta和全部execution order保持§28.9不变：仅TestSuite三对/六行direct DEBUG
directives；一次unfiltered full RunTests、same-log 46/46、debug App/fresh bundle/sign、
source strip、target-exact releases、four objects、matrix、remaining gates、same-bundle
preview、END。Review23前继续禁止caller/BEGIN及全部execution gates、产品/test/App-script
修改、Review02/acceptance与A3；commit/push/merge/release、R20 root mutation、normal-data、
外部及真实用户操作始终未授权。

### 28.11 R24 in-driver Bash status-capture closure

本节取代§28.10成为唯一current A2 plan gate。R23 freeze
`9c791a1bab22026ed2930eb120b9c82923390d42fad61a78f53b40080c6cef9a`、Review23
`13bd182b8701df2b83fa63c58e978b440ed55c75c0c4a6c3ac936116d411a8bc`、driver
`0d82a6cf04d4391117d0095bc3b7439f7402d965b45e4396fce50811f4ed4c6c`与163-entry
manifest `1776c5694ce8799258c5f4b37b623d230f3f37218d54817c25489c8dd63a4006`
保持immutable。R23唯一消费authority并完成BEGIN；三对/六行DEBUG directives已按freeze
落地，Core保持`c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`，
TestSuite final为`37fad0b3b123d248f6a52128f5f5d60559587cb8d291b6a6a6da1d615ad87967`。

R23唯一unfiltered `swift run RunTests`的完整log有terminal `652/652`，但外层exec wrapper
实际由zsh承载并读取Bash-only `${PIPESTATUS[@]}`，故Swift/tee status均为
`UNKNOWN_NOT_CAPTURED`、wrapper exit 1。R23因此在
`authoritative_full_test_status_capture`永久`REJECTED_CONTAMINATED`；same-log 46/46及全部
后续build/matrix/source/bundle/preview/END门未运行。十个runtime logs、
`impl-report-r23.md`、缺失screenshot与两个exact empty roots均为immutable failure evidence，
不得补写、覆盖、清理、删除、重命名或复用。失败后的stdout-only strip/hash ad hoc诊断只作
deviation披露，不替代formal source gate。

R24只关闭该同一harness根因，future source delta精确为0。`r24-begin.sh`由caller以
`env -i`、固定`PATH=/usr/bin:/bin:/usr/sbin:/sbin`、`LC_ALL=C`、`LANG=C`、
`TMPDIR=/private/tmp`、Git config隔离及显式
`/bin/bash --noprofile --norc`绝对路径调用；`BASH_ENV`、`ENV`与`CDPATH`必须unset。
driver独立验证canonical `$0`/`BASH_SOURCE[0]`、system Bash `3.2.*`、environment、branch/HEAD、
Review24 machine block、manifest、predecessors与Core/Test final hashes。

BEGIN后driver自己exclusive-create fresh regular non-symlink zero-byte `r24-verify.log`，以
`cd -P`证明exact repo cwd，并在同一顶层Bash 3.2 process无条件执行唯一pipeline：

```bash
if /usr/bin/swift run RunTests 2>&1 | /usr/bin/tee "$R24_VERIFY_LOG"; then
  r24_pipeline_status=("${PIPESTATUS[@]}")
else
  r24_pipeline_status=("${PIPESTATUS[@]}")
fi
```

then/else的第一条命令都必须复制完整`PIPESTATUS`；禁止`!`、`$?`代替、`set +e`、
`|| true`、`-a`或调用方shell读取。两个component先为`UNKNOWN`，array shape必须exact 2、
逐项decimal，随后在defer-signal commit中依次写Swift rc、tee rc并最后写
`status_captured=true`；只有captured `0/0`及唯一652/652 terminal summary才能继续。
成功log的SHA与bytes在handoff前冻结；same-log 46/46及以后任何reader须在读取前后复证该
identity。Bash 3.2 planning micro-probes必须证明success=`2:[0,0]`与failure=`2:[1,0]`。

R24 manifest精确178项：完整R23 163-path set，加R24 driver、immutable R23 manifest/freeze/
Review23、十个R23 runtime logs及`impl-report-r23.md`，即`178 = 163 + 15`；排除自身、R24
freeze/Review24/runtime/temp roots。R24 planning后旧R23 manifest必须精确156 unchanged +
七个expected mismatches（六面与TestSuite）。source delta=0只指产品/test/App与永久script
bytes；entry、每次mutation前、matrix恢复后及END必须178/178。唯一既有matrix窗口只允许
`scripts/verify-p1-migrations-sqlite-matrix.sh` line 115的reviewed Stage-hash单值临时delta，
该窗口精确177 unchanged + script唯一expected mismatch；所有success/error/signal路径mandatory
恢复entry hash，恢复失败永久reject且只能恢复、不能继续。driver handoff前仍须178/178。

R23 fresh roots以fixed two-bit `state,bundle` baseline=`11`进入R24。每次observation完整NUL
drain `/private/tmp` top-level universe，拒绝alternate identities；present bit必须是exact real
non-symlink canonical empty directory并完成empty/full-drain及terminal bookends，absent bit
absorbing。每轮按`BASELINE/LATEST→A→B`只允1→0；FIRST、LATEST与accepted mode-B只在比较
全部通过后defer-signal commit。UNCHANGED记录`disappearance_cause=NOT_OBSERVED`；真实erosion
记录`ERODED`与cause `UNKNOWN`。R20继续继承§28.10 fixed 38-bit erosion合同、R19 tombstone；
R16–R18与R21/R22十二paths及fresh-root globs继续保持zero-write/ABSENT。所有lifecycle共享
LATEST并在preflight、final pre-BEGIN、immediate post-activation、post-root、post-manifest、
post-full-test、每个后续mutation前与final pre-END复证；任何0→1、wrong type、extra或unknown
observation永久reject。R24不修改或清理任何historical root。

Review24只能由未写R24六面/driver/manifest/freeze的职责隔离reviewer唯一写，正文只能有一个
`Verdict: APPROVED — 0 P0 / 0 P1`及唯一12-line `R24_MACHINE_BLOCK`：
`authority_mode=standing_goal_automatic_after_review24`、standing Goal、independence、
`reviewer_write_scope=review24_only`、no-hash-echo、machine verdict、freeze/driver/manifest
三hash、固定branch/HEAD与`manifest_count=178`。批准且无更新user turn撤销Goal后automatic
caller只传Review24 current SHA，不要求用户echo hashes。

R24 driver成功handoff后顺序固定为same-log 46/46 → debug App/fresh bundle/sign/LAUNCH_READY →
formal guard-shape/strip-to-R20 → target-exact Core/TestSuite releases → four exact objects →
matrix/restoration → remaining source/privacy/final hashes → same-bundle preview → final lifecycle
reproof → END。所有Bash-specific status capture都必须在显式clean Bash 3.2 block内部完成；任一
failure永久reject且不重跑、不patch、不换root/object。Review24前全部execution、Review02/
acceptance/A3关闭；commit/push/merge/release、normal-data、外部及真实用户操作继续未授权。

#### 28.11.1 R24 final single-process clean-execution contract

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

### 28.12 R25 numeric-rendering root-cause closure

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

### 28.13 R26 ERR-subshell root-cause closure

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

## 30. Open Questions

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
