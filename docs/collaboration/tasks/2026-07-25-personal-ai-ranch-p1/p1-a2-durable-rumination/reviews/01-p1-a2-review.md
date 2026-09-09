# P1-A2 Independent Implementation Review 01

> 结论：**CHANGES REQUIRED — 0 P0 / 1 P1**
>
> 日期：2026-07-27
>
> Reviewer：职责隔离 implementation reviewer

## 1. 职责隔离与审查边界

本 reviewer 未参与 R13/R13A/R13B plan/control 同步、P1-A2 产品或测试实施、
验证日志生成、preview 操作或 implementation report 编写。本轮只读取当前仓库
快照、冻结权威、真实源码、测试源码与既有证据，并只写本 Review。

本轮没有启动任何 AgentLoop App，没有访问普通
`Application Support/AgentLoop` 数据目录，没有运行会打开该目录的命令，没有修改
产品、测试、计划、freeze、旧 Review、日志、evidence 或 acceptance，也没有
commit、push、merge、release、数据重置、外部操作或真实用户操作。

## 2. Exact candidate 与权威

独立重算后的 candidate 如下：

| Artifact | Verified SHA-256 / value |
|---|---|
| Branch | `codex/personal-ai-ranch-p0` |
| HEAD | `02334ec8d21533be81d93d39191bc7d9b9c24f7f` |
| P1 Stage canonical | `a8ca6e7a56a32e945bae185724a51d4e0015d61676bf02d9637fedc2c27d9b6f` |
| P1 total Plan canonical | `2382ac752807e2a36dbb6de834636a9858c539d5e19c607608af55094fdb2626` |
| P1-A2 leaf canonical | `4564896993dad717f0150800f918133fd7c17508e3c57cfb941a322e49d46908` |
| R13B control freeze | `b9ff965be2477e68d70b2d938a3e496ff47409a20efae710a971b0a96322b8d1` |
| Review13B | `b798cffd016865b9441f6c8978da96d7382feb3e5dd51c7555e635bfbca84444`; `APPROVED — 0 P0 / 0 P1` |

Review13B 确实在 exact R13B inputs 上打开了有界 implementation；冻结 control
surface 中保留的 `Review13B Pending` 是被 hash 锁定的候选历史文字，不构成新的
实施阻断或本轮 finding。

## 3. 独立 hash、scope 与真实 gate 审计

### 3.1 Scope 与 immutable

独立重算当前三个 R13 产品/测试 delta：

| Allowed file | Entry SHA-256 | Current SHA-256 |
|---|---|---|
| `Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift` | `48fa9a04ec21f07c41b958e54433681c5099e31ed851f3b4ff6deb064aef07cf` | `e7cde04d577cc53b5b4ad0f8ad18bb4ca4ce604de18c660020fbc4096cd48f45` |
| `Sources/AgentLoopTestSuite/CodingRanchTests.swift` | `13733b134cf80a63415ade04fa5ec407de3b7930b0ec7c31bb78c6e04132597a` | `5e311070fc5299fd4f576b4af6fb2286e4a515bf5b23a72d1ccc464c88c2c2bb` |
| `Sources/AgentLoopTestSuite/DurableWorkTests.swift` | `893944ff1266cd94d0cf2ddba15840719415596bc25e8b39415b205f3e54c346` | `818dfc5f897a0258b3113902f175d65bdf917732652ca44c08bd86fd0a2f0dd7` |

15-file allowlist 的其余 12 项与 R13A entry hashes 一致。matrix script 当前
SHA-256 为
`75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c`；
只在输入流中把 line 115 的 Stage hash 从当前
`a8ca6e7a...d9b6f` 恢复为 R12-F 值
`cfe8562d...faaa9`，得到冻结旧 script SHA-256
`187da197ea4b0c80e1e437a6b5c576216f7c3491696c45b0f9104a9197401467`。
因此 control exception 是单一 64-hex value delta。

10 个 leaf §2.4 immutable 文件均独立重算匹配；其中两个 lock 文件分别为：

- `StateDirectoryLock.swift`：
  `863819791bbbead28c7fb0ba80540703fa275977682c846fbb8b415ce512c363`；
- `SupportTests.swift`：
  `eb5f8392870a8cca3a0e9729cc17082d259346b8187ff68cde9ee71ff1497386`。

`AppDatabase.swift` lines 21–612 boundary 为
`5bbb555016a64801c25be3634b0fcfcca0da8fe3b4d3cda493b0df3851a8ccff`，
Stage §18.1 lines 3850–4036 boundary 为
`fb77180d6edd44413e41179e4b220666438e2660de11fbde1dafee78b6fde5c2`。
`git diff --check` 无输出。除下述 operational incident 外，没有发现 schema、
EventKind、dependency、target graph、immutable 或 A2 source scope 的 P0/P1 漂移。

### 3.2 源码与测试 delta

本 reviewer 直接检查了当前 Supervisor seam、真实 handler/catch、两轮 validator
位置、production invalidation/fatal owner，以及两份测试中的动态 matrix 与
source-range gates：

- DEBUG seam 是 `first|second` 两 checkpoint、23 loss cases、single armed
  scenario；types、storage、arm、consume 与两个 caller 均位于 matching
  `#if DEBUG`；
- 两个 caller 分别位于真实 actor gate + durable validator 之后、
  `organizing` 之前，以及 awaited `organizing` + 第二轮真实 gates 之后、
  parse 之前；
- #27 与 #35 各遍历 2 × 23 个 fresh isolated fixture，断言 one provider call、
  durable/business snapshot byte-equivalent、exact invalidation reason、零 result/
  completed/failed event 与零 late command；
- `a2Eventually` 使用 `ContinuousClock` 两秒 deadline 与 1 ms poll，不再把
  scheduler yield 次数冒充 elapsed timeout；
- 独立机械对照得到 41 个冻结 test name、41 个唯一 `@Test` definition、targeted
  log 中每项恰好一次 green；
- 当前 release Supervisor object 的 R13 seam symbol 为 0，DEBUG object 为 144。

未发现该三个 source/test delta 自身留下新的 P0/P1。

### 3.3 验证证据

既有日志与本轮独立机械核对一致：

| Gate | Review result |
|---|---|
| Failure-first | 5 个真实缺能力 red；不是 compile/discovery/fixture/unknown failure |
| Targeted exact names | 41 tests / 2 suites PASS，5.941 s |
| Authoritative `swift run RunTests` | 652 tests / 7 suites PASS，42.681 s |
| Exclusive/release lock test | PASS in authoritative run |
| `swift build --product AgentLoopApp` | PASS |
| `swift build -c release --product AgentLoopCore` | PASS；只有已记录 warning |
| Release/DEBUG seam | 0 / 144 symbols |
| SQLite matrix | 3.51 与 3.52；fresh/v7/v8/v9/v10/v11/v12-durable；literal + real GRDB PASS |
| Source/privacy gates | PASS；独立 artifact secret-pattern scan为 0 |
| Hash/scope manifest | PASS；12 unchanged + 3 authorized deltas + 1 script exception |

`verify.log`、`red-tests.log`、`build.log`、`migration-matrix.log`、
`source-gates.log` 与 `hash-manifest.log` 当前 SHA-256 均与 `impl-report.md`
记录一致。

### 3.4 Preview 的技术结果

独立检查截图与 retry 证据后，fresh full-path retry **单独看**满足 UI/isolation
观察：

- bootstrap/cold-start 均使用
  `/private/tmp/agentloop-a2-preview.Kb1Er6`；
- retry 与导航期间 normal-root open-file count 为 0；
- synthetic fixture 只写 isolated DB，FK 为 0、integrity 为 `ok`；
- 截图是 1190 × 732 RGB PNG，SHA-256
  `8623453541c08c538eab784bac1872fee86e1e497c553ce9576b50ae4f84a9c3`；
- 截图可见 `隔离恢复验证`、`保存原文`、`正在恢复`，未把 extracting、
  organizing 或 confirm 虚构为 current stage；
- cold-start App/child cleanly exited。

该成功 retry 不能消除下面的历史 gate violation。

## 4. Blocking finding

### P1-01 — 已发生的 normal state root access 违反 A2 明文停止门，成功 retry 不能把它改写成 zero access

**冻结合同。**

- leaf `plan.md:56-58` 明定“实施中任一 … normal data access”关闭 A2
  completion gate并禁止 A3；
- leaf `plan.md:775-786` 要求 preview 的 DB/WAL/SHM/lock 只在 isolated root、
  normal open-file count为0，并明确“不得读写/重置 normal DB”；
- leaf `plan.md:804-807` 要求 implementation Review 零 P0/P1后才能交
  acceptance，且 acceptance 必须证明“零 normal-data access”；
- Stage `p1-stage-spec.md:7999-8001` 要求 isolated preview 的 normal
  数据/open files为零；Stage `p1-stage-spec.md:8173-8174` 又明确实施不操作
  normal DB。

**真实事实。**

`evidence/preview-bootstrap.log:35-44` 明确记录第一次 attempt 被判 invalid，
原因是 display-name lookup 自动启动 installed
`/Applications/AgentLoop.app`，PID `74836` 的
`installed_normal_root_open_count=4`，实际打开：

1. `.agentloop.lock`；
2. `agentloop.sqlite`；
3. `agentloop.sqlite-shm`；
4. `agentloop.sqlite-wal`。

`impl-report.md:243-259` 也确认 installed App 打开了这四个 normal-root
路径；因为没有 incident 前的内容 hash，implementer 正确地没有声称 zero
normal-data access或zero mutation。

**判定。**

App 实际打开 normal SQLite state 已经是合同所说的 normal data access；是否由
operator 主动查看表内容、是否主观标记该 attempt 为 rejected，都不改变已经发生的
访问。后续 fresh isolated retry证明了“下一次操作可隔离”，但不能反向证明整个
本次 A2 implementation invocation 为零 normal-data access。当前 frozen
Stage/Plan/leaf 也没有授权把 rejected attempt 从 completion history 中排除。

本 finding 评为 **P1**，因为它直接阻止冻结的 A2 completion/acceptance/A3 gate；
现有证据没有证明 destructive reset、确定的数据损坏、秘密泄露或真实用户影响，
因此不升为 P0。没有 pre-incident hash也意味着不能把“未发现损坏”升级成
“已证明零 mutation”。

**必要处置。**

1. 不得写 A2 `acceptance.md`，不得开始 A3，继续禁止 commit/push/merge/release。
2. 保留 incident 与 valid retry 原始证据；不得通过打开、清理、重建或重置 normal
   DB 来试图“修复证据”。
3. 该历史事实不能由产品代码修改、再跑测试或再做一次 preview 消除。planner 必须
   先记录 blocker，并取得明确、有界授权，决定是修订 Stage/总 Plan/leaf 的 incident
   disposition/新的 invocation boundary，还是让 A2 保持关闭；reviewer 不替 planner
   发明该产品/流程决定。
4. 如果获得 plan-level 修订授权，必须重新冻结 exact hashes、执行职责隔离 plan
   Review；只有新合同通过后，才可按新合同重跑必要 gates与 fresh isolated preview，
   再进行独立 implementation Review。一次成功 retry 本身不构成 closure。

## 5. Verdict

技术 source/test/build/matrix 与 fresh isolated retry 未发现其他 P0/P1；但
P1-01 使冻结的 zero-normal-data completion gate 不成立。

**CHANGES REQUIRED — 0 P0 / 1 P1**

A2 acceptance 与 A3 继续关闭。
