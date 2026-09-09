# Review01D — AgentLoop P1-C Revision 4 Plan Review

> Date: 2026-08-25  
> Reviewer: fresh responsibility-isolated read-only Codex reviewer  
> Checkout: `/Users/muzi/Agent-loop`  
> Review boundary: frozen P1-C Revision 4 plan only  
> Final status: **CHANGES REQUIRED**

## 1. Review conduct

- 完整读取并核验了 `AGENTS.md`、协作协议、master spec、P1-C canonical authority、P1-C/v14 stage authority、P1-B Acceptance23/Review24/完整 `verify.log`、immutable Review01/01A/01B/01C，以及 Revision 4 全文。
- 独立检查了当前相关 Swift 6、GRDB、DurableWork、Application seam、migration runner/script 和 test carrier 源码。
- 没有依赖实现者对可实施性或正确性的判断；项目事实和结论均从当前 checkout 重新取得。
- 全程只读。没有编辑或创建文件，没有运行 tests、build、migration、matrix、App、Claude 或 Git write。
- 只执行了只读状态/哈希检查、嵌入 serializer、`bash -n`、Ruby 语法编译和静态清单解析。

## 2. Frozen checkout、worktree 与哈希

### 2.1 Checkout 和 worktree

| Check | Review start | Review end |
|---|---|---|
| CWD | `/Users/muzi/Agent-loop` | same |
| Branch | `codex/personal-ai-ranch-p0` | same |
| HEAD | `02334ec8d21533be81d93d39191bc7d9b9c24f7f` | same |
| Revision 4 SHA-256 | `8b66b17649c2cf64f5563699f9a59d0fc7166ee1f2d44ba312b4ab63a2e8e745` | same |
| Expanded porcelain-v1 `-z` SHA-256 | `716feee2af9abb1af0885cbae1653483227fb3df703b770fd8d6d21ca478bbfb` | same |
| Dirty paths | 462 | 462 |
| Tracked worktree modifications | 63 | 63 |
| Untracked paths | 399 | 399 |
| Staged paths | 0 | 0 |

计划起始和结束哈希均等于用户给定值。原始 porcelain 哈希也未变化，因此 review 没有改变既有 dirty worktree。

### 2.2 Authority、evidence 与 immutable review 哈希

以下值在 review 起止均一致：

| Artifact | SHA-256 |
|---|---|
| `AGENTS.md` | `046010f8f693130aa7b0dd7b3727d5ea3370705051fbc0433bd981dab084b242` |
| Collaboration protocol | `9eab1e22f4d285bff77a84107216f6dfa1fb0a8470064822441154f282c78fc1` |
| Master spec | `5f942e58745500925c90405460a9bbd161dd07389d7e4d0ee10e156b374d4b4a` |
| Canonical P1 plan | `d499111f168e52a82485d70fd8aa412f34f8db92597d7c8dca3c22b68b24d18f` |
| Canonical P1 stage spec | `bacc1a99492f4d4acdb48ffb4f94918ffa7ba0358122547db7a828b31c1620b6` |
| P1-B Acceptance23 | `da21f00e3eecdf2c69cbbe681f1568f00dec820f4320baaa6d184ac1b5755384` |
| P1-B Review24 | `3f91981a7a3fe40e92f21b64d7169cd8de340a5662d6853dbb88e47fb9a95bd8` |
| P1-B authoritative `verify.log` | `6eb521225e14d3de84595c0cd9bb2318ac3acbb072a3806f5543478fbabf2a87` |
| Rejected Review01 | `08fce8b86f3a7caef3d56c7457fa27cb2d1d2ac86f0d84c9629b50e7645e726b` |
| Rejected Review01A | `cacf4d3b718f192d1ee1b68e81dba003fde9b405ac4fece180a0cf09124c8d7a` |
| Rejected Review01B | `52391a6cf2612211f1a3612e5fb5379101cb2c90f644430c7fe04e5398a4e4de` |
| Rejected Review01C | `c07a305be3c0fae8e8f26fb02622c4d862997f20b5fc6b5ffe1778a89c7f9053` |
| Revision 4 candidate | `8b66b17649c2cf64f5563699f9a59d0fc7166ee1f2d44ba312b4ab63a2e8e745` |

P1-B accepted evidence仍记录：

```text
714 tests in 7 suites passed after 43.614 seconds
EXIT: 0
RESULT: PASSED
```

本 review 只读取该历史证据，没有重跑。

### 2.3 Frozen source/carrier 哈希

| Surface | SHA-256 |
|---|---|
| `CanonicalJSON.swift` | `7b14b628b14e8f10854116d029bbb7af480a3f9f2c7f5562ad8daae764113b79` |
| `DurableWork.swift` | `5882ffddaedf6c6f00a73121f3948f903119ff0f6f29e29a6945344eb3c46433` |
| `DurableWorkStore.swift` | `3e0ada2a6f7fb79a8aa23ccc467e4577d86863e2c971fbc187c334de2bbf60fa` |
| `DurableWorkSupervisor.swift` | `decfbc90e891580acc55c8f6ab03d4014bf6667a7fa486d6a959150cc4de7095` |
| `DurableWorkTests.swift` | `061b23b239592ae7f6803ef3174c5ade2f29f73193781f621f8b16643669b3ad` |
| `Package.swift` | `b55b600fc7489aca6bc4e305ea968ac5c9d9e438b4b70be48bf47527e445b99c` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |
| `Sources/RunTests/main.swift` | `70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3` |
| `AppDatabase.swift` | `29d4deaac25840ca8f8f826e4829441857893f171784bf692920dbef9bab0b2b` |
| `EventKind.swift` | `1a3184711a261c15fa915571088ecbd9187c53a314139e41c8f336ffd51f7da4` |
| `InputWorkflowController.swift` | `1963a8d101a9d6ed57fb4ce8ef8577f63a1b7502ba0b0eb11b9569ef0e35a1bb` |
| Matrix runner | `951fdbf6a4f9dacefaa4712318984540f9f8109ce34626e6c7afcf8ce95a20f4` |
| Matrix script | `ab8d91fe04ca38007110c7ad8466e4dd0904fa05e859c1474dea0ac51247a84f` |

### 2.4 Outside serializer

Revision 4 内嵌 serializer 通过 stdin 原样执行，起止结果一致：

```text
dirty_total=462
allowlisted_present_count=14
outside_count=448
outside_manifest_v1=bd09656fe85d57b2b53d2a871acbdacb8fbf2429fe1bacaf30ce78460ed4e4a0
```

## 3. Authority 和阶段边界

- P1-B Acceptance23 与 Review24 提供有效的 P1-C planning entry。
- P1-C authority 只允许 Event/Input/Goal/Coach/Understanding 到 `Goal.ready`。
- Stage spec 明确把 Goal activation、`active|paused|achieved`、OutcomeContract、Outcome、Verification、Acceptance 和 Grant 留给 P1-D/v15。
- Revision 4 的声明性范围仍遵守该边界；没有发现 authority 级 P0 冲突。
- 但是其完成 source gate 尚不能机械保证该边界，见 P1-04。

## 4. Review01C 九项 P1 关闭核验

| Review01C finding | Review01D determination |
|---|---|
| P1-01 — prepared/new construction contradiction | **RESOLVED.** §§5.2、6 已把 pre-receipt `PreparedDomainCommandV1` 与 post-mutation `NewDomainCommandV1` 分离。 |
| P1-02 — unsafe/incomplete adoption | **RESOLVED as originally framed.** 新的 expired-only control adoption 同时覆盖 same-owner/foreign-owner expired lease，并保留 live lease。 |
| P1-03 — attempt-start reused as terminal time | **RESOLVED.** Envelope 保留 `attempt.startedAt`，terminal mutation 使用单独且单调的 `terminalNow`。 |
| P1-04 — missing all-command actor matrix | **RESOLVED.** 静态核验得到 23 个唯一 command，actor matrix 覆盖 23/23。 |
| P1-05 — multiple Coach sessions | **RESOLVED.** Store 冻结 one-total-session-per-Goal、serialized open、zero/one/multiple resume 规则。 |
| P1-06 — worker interfaces/provider snapshots | **NOT FULLY RESOLVED.** Request snapshot 与 provider outcome 外壳已冻结，但 Input result DTO、terminal disposition、lease policy 和 invalid-output terminal behavior仍不完整。见 P1-01、P1-02、P1-03。 |
| P1-07 — inbox handler partial writes | **RESOLVED.** `db.inSavepoint` rollback 后再持久化 rejected evidence；当前 GRDB 7 API支持该结构。 |
| P1-08 — missing Understanding hash carrier | **RESOLVED.** Goal 保存 ID/version，Store join exact confirmed Understanding row并校验 sealed ID/version/hash/event head。 |
| P1-09 — per-instance identity lock | **RESOLVED.** type-static `NSLock` 覆盖同一进程内所有独立 adapter。 |

因此，Revision 4 没有完整关闭其声称已经关闭的全部九项：Review01C P1-06 仍未 decision-complete。

## 5. 静态机械核验结果

### 5.1 v14 与 GRDB

从 stage spec §18.4 独立抽取得到：

```text
lines=292
sha256=a62302bf5f45ef07caded2899322ce3e94e51d21ddc28b3cdb9c102d6936d531
tables=10
indexes=13
triggers=4
create_total=27
```

当前 GRDB 7 提供同步、可嵌套的：

```swift
public func inSavepoint(
    _ operations: () throws -> TransactionCompletion
) throws
```

而 `DatabaseWriter.write` 已拥有外层 transaction。因此 inbox savepoint 方案和 v14 GRDB migration 结构本身静态可实施。

### 5.2 Allowlist、strip gates 与 source syntax

- 产品/contract-test allowlist 为 21 个路径，另有 2 个 migration verification carrier。
- Store/Supervisor 当前 pre-image 分别匹配 `3e0ada...` 与 `decfbc...`。
- 两个 Bash code fence 均通过 `/bin/bash -n`。
- source gate 中 4 个 Ruby heredoc 均通过当前 Ruby 2.6 语法编译。
- 独立 outside serializer 可执行并产生冻结结果。
- 但是 strip block 内容约束和 P1-D lexical fence仍可被普通、非混淆代码绕过，见 P1-04。

### 5.3 Closed test manifest

静态抽取结果：

```text
entries=100
unique_specs=100
unique_names=100
ControlContractMigrationTests=9
DomainEventContractTests=25
InputEnvelopeContractTests=32
GoalCoachContractTests=34
```

23 个 command vocabulary 也是唯一且 actor matrix 覆盖 23/23。Declaration/discovery 比较逻辑在语法层面可执行；依用户禁令，没有实际执行 `--list-tests`。

## 6. Findings

### P0

None.

### P1

#### P1-01 — 三个 Input 边界类型仍未定义为可实施的 exact contract

Revision 4 使用了三个关键形状，却没有冻结其声明：

1. `InputParseResultV1` 仅被称为 “exact-key typed value”，并用于 provider outcome 和 parse-result command；计划没有给出字段、case、initializer、validation 或 Codable 形状。
2. `input.parse-failure.v1` payload 包含 `terminalDisposition`，但没有定义其类型名、case/raw value 或构造规则。相比之下，Coach 的四个 failure branch 已逐项定义。
3. `InputCaptureReceiptV1` 出现在 `InputCapturePorts.capture` 和 `captureLocalInput` 返回类型中，但全文没有 declaration、typealias、字段或从 `CampSafeCommandResultV1` 的映射。当前源码也没有该类型。

证据：

- `plan.md:726-754`
- `plan.md:1147-1152`
- `plan.md:1206-1214`
- `plan.md:1663-1677`
- `plan.md:1733-1745`
- `FailureRecord.swift:733-739` 还要求 `OperationCommitOutcome` 的 Value 必须 `Sendable`。

影响：

- 实现者必须自行设计 package API、canonical command bytes、replay payload 和 Application/Core return seam。
- 不同选择会改变 public/package surface、command whole hash、receipt result shape 和 tests；这不是可留给实现阶段的局部编码细节。

所需修正：

- 冻结 `InputParseResultV1` 的 exact fields/cases、访问级别、`Sendable/Equatable/Codable`、validating initializer 和每个 routing branch 的字段成员。
- 冻结 Input failure terminal-disposition 类型、raw values，以及从 attempt/maxAttempts/failure disposition 到该值的唯一 reducer。
- 明确 `InputCaptureReceiptV1` 是 `CampSafeCommandResultV1` 的 exact typealias，还是一个独立 exact struct；若为 struct，必须列出字段和唯一映射。
- 将这些声明及正反例纳入现有 closed manifest 和 source gate。

#### P1-02 — 两个 control worker 没有冻结 lease duration

两个 initializer 只接收 `database/workerId/clock/sleep/provider`：

- `plan.md:1216-1227`
- `plan.md:1520-1531`

计划只规定“每 15 秒 renew”，没有规定 claim/renew 使用的 lease duration，也没有把它作为 initializer dependency 或 package constant。

当前真实 API 则强制调用者提供：

```swift
claimNext(..., leaseDuration: TimeInterval)
renewLease(..., leaseDuration: TimeInterval)
```

证据：

- `DurableWorkStore.swift:134-152`
- `DurableWorkStore.swift:277-289`

现有 `DurableWorkSupervisor` 虽有 `60s lease / 15s renewal`，但两个值是该类型的 `private static`：

- `DurableWorkSupervisor.swift:198-199`

新 `InputParsingWorker` 文件和独立 `CoachTurnProcessor` 不能引用该 private constant。

影响：

- 实现者必须自行选择安全关键时序值。
- 不同值会改变 foreign-live adoption、same-owner expiry、renewal race 和 crash-recovery tests 的含义。
- 计划目前不能决定 claim 和 renew 是否使用同一个 duration，也没有冻结 renewal interval 与 lease duration 的安全关系。

所需修正：

- 为两个 worker 冻结同一个 exact positive finite lease duration，明确由 initializer 注入还是由可共享 package constant 持有。
- 明确 claim 与每次 renew 必须使用同一个值，以及它与 15 秒 cadence 的不变量。
- 在现有 renewal/adoption tests 中断言 exact lease expiration 和 live/expired 边界；不要让实现者从另一个类型的 private constant 猜测。

#### P1-03 — Invalid provider output 绕过 deterministic failure 和有限重试

计划明确规定：

- Input parser invalid output 抛 worker validation error，但不执行 terminal command：`plan.md:1235-1239`。
- Coach invalid output 同样不执行 terminal mutation，只等待 lease expiry/recovery：`plan.md:1566-1574`。

这与 stage authority 冲突：

- 每个 claimed attempt 最终必须有一个 terminal event：`p1-stage-spec.md:197-204`。
- parsing/schema/contract conflict 是 deterministic failure，不自动重试：`p1-stage-spec.md:277-284`。
- Input parsing 必须使用有限重试，deterministic/exhausted failure 同事务进入 `parseFailed`：`p1-stage-spec.md:2103-2111`。

而当前 generic `claimNext` 的 queued/due 查询不检查 `attempt < maxAttempts`；只有 `retryOrFail` 才执行该上限：

- `DurableWorkStore.swift:177-199`
- `DurableWorkStore.swift:483-486`

因此反复 invalid output 会形成：

```text
claim → invalid output → lease expiry → interrupted adoption → queued → claim
```

它可以超过 `maxAttempts=4`，且永远不产生 deterministic parse/Coach failure 事实。

影响：

- malformed provider output 可能导致无限 reclaim/provider churn。
- Input 可永久停在 `captured`，Coach session 可永久留在 interviewing。
- 真实契约错误被伪装成 crash recovery，而不是可观察、有限、确定性的失败。

所需修正：

- 将 post-await provider-output validation failure 映射为一个 exact deterministic `ControlWorkerProviderFailureV1`，通过同一 latest claim 和 terminal Store transaction 记录失败。
- 若有某一类基础设施错误确实必须留给 lease recovery，必须把它与 invalid domain/provider output 分开，并冻结其 bounded recovery policy。
- Input 与 Coach tests 都必须覆盖 invalid output、一次 deterministic terminal、无额外 provider recall、projection/event/work 原子性和 replay。

#### P1-04 — Source/scope gate 不能严格阻止额外代码或 P1-D

Revision 4 构造：

```bash
p1d_product=("${new_product[@]}" "${p1c_blocks[@]}")
```

它没有把三个既有可写产品 carrier 纳入 P1-D lexical scan：

- `AppDatabase.swift`
- `EventKind.swift`
- `InputWorkflowController.swift`

证据：`plan.md:2296-2317`。

即便对已扫描的非-Goal文件，regex 只拒绝：

```text
OutcomeContract
activate|pause|resume|achieve
GoalControllerStatusV1.active|paused|achieved
```

它不会拒绝普通实现：

```swift
package func startGoal(...)
UPDATE goal_controller SET status = 'active'
```

随后跨全部 product 的检查仍只匹配函数名 `activate|pause|resume|achieve`。证据：`plan.md:2330-2354`。

Strip gates 也只证明 prefix pre-image 和少数 required declaration：

- Store gate要求一个 extension 和一个 `adoptExpiredControlWork`，但没有拒绝同一 block 中的其他方法或类型：`plan.md:2200-2233`。
- Supervisor gate要求一个 `CoachTurnProcessor`、一个 task group 和一个 envelope factory use，但没有拒绝额外顶层声明或额外 package API：`plan.md:2235-2270`。

影响：

- 一个实现可以在保持所有 pre-image hash、100 tests 和当前 lexical checks 通过的同时加入未授权代码。
- 明显的 raw-SQL `ready -> active` 或改名后的 activation API能够越过 P1-D fence。
- 因而“P1-D active/paused/achieved/OutcomeContract 严格关闭”不是机械成立的完成条件。

所需修正：

- 对两个 marker block 冻结并机械检查允许的 package/top-level declaration surface，拒绝额外声明。
- 把所有可写产品 carrier 纳入 P1-D 检查；对 `AppDatabase` 和 `GoalController` 中 v14 forward-compatible DDL/record fields 使用窄、位置化例外。
- 增加 raw SQL/status literal、`.active/.paused/.achieved` reducer、Outcome reference 写入及替代命名 API 的拒绝规则。
- 对当前已有 dirty carrier 使用 marker/diff-aware delta gate，不能只依赖 path allowlist 和若干关键词。
- 保留 `goalP1CTransitionsOnlyClarifyingReadyAbandonedAndFailed` 等行为测试，但不能用未调用隐藏 API 的测试替代 source/scope gate。

### P2

None.

## 7. Feasibility determination

以下部分静态上可实施：

- v14 exact migration、双 SQLite carrier 扩展和 GRDB-owned transaction。
- Receipt-first command execution、outbox identity 和 inbox savepoint。
- Expired-only control adoption及 Store/Supervisor prefix restoration。
- 23-command actor matrix、one-total-session rule、joined Understanding hash。
- type-static process-shared local identity lock。
- 100-test exact declaration/discovery清单。

但是四个 P1 分别留下 package/API 设计、lease safety、deterministic failure lifecycle 和 scope enforcement 决策。它们会影响 canonical bytes、durable state、public/package interfaces、recovery semantics 和 P1-D red line，不能在实现阶段自行补齐。

## 8. Gate decision

- P0: 0
- P1: 4
- P2: 0
- Revision 4 approval gate remains closed.
- P1-C product/test/schema/migration implementation remains closed.
- Review02、P1-C acceptance 和 P1-D remain closed.
- Frozen plan、authority、source hashes 和 outside manifest在 review 全程未漂移。

verdict=CHANGES REQUIRED — 0 P0 / 4 P1 / 0 P2
