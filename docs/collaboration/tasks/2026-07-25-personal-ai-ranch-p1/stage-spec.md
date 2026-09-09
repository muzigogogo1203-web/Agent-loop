# P1 执行控制索引 — Stage

> 状态：**P1-E ACCEPTED；P1-F1 decision-complete planning entry open；P1-F1 implementation closed**
>
> 日期：2026-08-25
>
> 文档性质：执行控制索引，不是新的阶段规范，也不复制或改写冻结规范

## 1. 唯一规范源

P1 的唯一阶段规范仍是：

- `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md`
- R21 predecessor SHA-256：
  `819c37d6181b54be71031f0300d89aa5d30c26af5ec12975c296b8c7316c6704`

P1 的唯一总实施 Plan 仍是：

- `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md`
- R21 predecessor SHA-256：
  `83644e0958e8f0486578d655175982d95ee9b5a5997bc385f49789c21e12da1e`

上位产品权威仍是：

- `docs/superpowers/specs/2026-07-25-personal-ai-ranch-master-spec.md`

上述hash只标记immutable R21 predecessor；R22与R23历史已由各自freeze/Review及R23 immutable
failure evidence固定。R24 freeze
`f22a7ffd954ddf6d9b2d804a5f3be58807373c388634b9200d260f1a8eb66746`、Review24
`a9ef2cab24afa65290f563b85ac03022b958d39253c025017d1c91b689926c0e`、driver
`1b224f442d1fdea856433d12141e5ea9f74190a380e554e4ec94872ba0b8655f`、178-entry manifest
`55a6c2e8a657166de8b983cd0edfb2a7b1ae1943dc291819c0c2ea417338a80c`与十个实际runtime files
均immutable。Review24已`APPROVED — 0 P0 / 0 P1`，但R24执行随后在guard gate永久
`REJECTED_CONTAMINATED`且无END。R25 freeze/Review25/driver/192-entry manifest与十个runtime
files均immutable；其唯一full test 652/652与其后partial greens不改变preview ERR-trap
double-containment rejection及no-END事实。R26又在B01–B06通过后因compound-if丢失helper rc而
永久rejected。R27随后以唯一authoritative full 651/652在Shell timeout测量边界失败，未进入
later gates且无END，现永久`REJECTED_CONTAMINATED`。EOF byte-identical R28 override是唯一
current：六面、fresh `r28-begin.sh`、exact 235-entry manifest与freeze均已冻结，Review28
已完成并由独立 Review02 与 acceptance 接受。上述 R15–R28 记录继续作为 immutable
历史证据；它们不再构成 current P1-B gate，也不要求用户回传 hash。

本索引、顶层 `plan.md` 与各 slice task 文档只负责定位当前执行单元、职责、证据和
阶段门。它们不得成为冻结 Stage/Plan 的替代副本。任何文字、哈希或范围冲突时，
必须立即停止；以上冻结文件及精确哈希优先，不能在本目录自行解释或修订规范。

## 2. P1 入口记录

| 入口条件 | 当前证据 |
|---|---|
| P0 已验收 | `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/acceptance.md`：`ACCEPTED` |
| R8 predecessor Stage/Plan 已通过职责隔离 Review | `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/08-p1-plan-review.md`：`APPROVED — 0 P0 / 0 P1` |
| R9 新冻结 hashes 的职责隔离 Review | `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/09-p1-plan-review.md`：`APPROVED — 0 P0 / 0 P1` |
| R10 有界修订与同根 finding closure | 首轮 Review10 为 `0 P0 / 2 P1`；Candidate 2 hashes 见 §1 与 `evidence/r10a-freeze-validation.md`；Review10A 为 `APPROVED — 0 P0 / 0 P1` |
| R11 implementation-discovered blockers | 牧场主已授权；三份 Candidate hashes见§1/§3，冻结证据 `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/evidence/r11-freeze-validation.md`；Review11 为 `APPROVED — 0 P0 / 0 P1`，曾重新打开 A1b 产品/测试实施 |
| A1a 实现职责隔离 Review | `p1-a1a-durable-work-store/reviews/01-p1-a1a-review.md`：`APPROVED — 0 P0 / 0 P1`；只打开独立 acceptance 判定门 |
| A1a 独立验收 | `p1-a1a-durable-work-store/acceptance.md`：`ACCEPTED`；SHA-256 `070a2b6815ef85323d1041d3023ebc28ec5f98737513746ec9bdf961183a0032` |
| A1b 最终实现职责隔离 Review01 | `p1-a1b-durable-planning/reviews/01-p1-a1b-review.md`：`APPROVED — 0 P0 / 0 P1`；SHA-256 `8c96b742285da1c1999c5360071728cbdf287cfeffeb6b25e281485336e0b1a0`；报告保留首轮 `0 P0 / 2 P1` 历史 |
| A1b 独立验收 | `p1-a1b-durable-planning/acceptance.md`：`ACCEPTED`，22/22 PASS；SHA-256 `efe4d20a7cb4dc3f61d028637a6705d3ed56d4fdd5596ebc3cb993d94481bf1e` |
| A2 独立验收 | `p1-a2-durable-rumination/acceptance.md`：`ACCEPTED`；R-02 `Closed`；只曾打开 A3 |
| A3 最终实现 Review | `p1-a3-candidate-transaction/reviews/04-p1-a3-implementation-rereview.md`：`APPROVED — 0 P0 / 0 P1 / 0 P2` |
| A3 独立验收 | `p1-a3-candidate-transaction/acceptance.md`：`ACCEPTED`；R-03 `Closed`；只打开 A4 bounded planning |
| A4 最终实现 Review | `p1-a4-schedule-fire/reviews/03-p1-a4-implementation-rereview.md`：`APPROVED — 0 P0 / 0 P1 / 0 P2` |
| A4 独立验收 | `p1-a4-schedule-fire/acceptance.md`：`ACCEPTED`；R-04 `Closed`；只打开 P1-B bounded Level-3 planning |
| R12/R12-A A2 plan revision | 牧场主已授权；原 candidate freeze evidence为 `p1-a2-durable-rumination/evidence/plan-freeze.md` |
| Review12 immutable verdict | `reviews/12-p1-plan-review.md`：`CHANGES REQUIRED — 0 P0 / 2 P1`；SHA-256 `f27379bfc96a224715e7c6a59ad62fa79d8d97c4d73cf41e890a6ce16957a7c3` |
| R12-B bounded closure | 牧场主已授权；只关闭 provider/parse/phase handshake 与完整 legacy 8-cell；predecessor exact hashes见 `p1-a2-durable-rumination/evidence/plan-freeze-r12b.md`；Review12A remained pending |
| R12-C phase-gate closure | phase pre-audit（无报告文件）为 `0 P0 / 1 P1 / 0 P2`；牧场主已授权只扩展 #27/#35 与 Stage completion/source gate；新 exact hashes见§1/§3，freeze evidence为 `p1-a2-durable-rumination/evidence/plan-freeze-r12c.md`；Review12A Pending |
| Review12A immutable verdict | `reviews/12a-p1-plan-review.md`：`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`；SHA-256 `a102c49138fcfc1f40b0c780990d8c3ad5ec2302b175b043bde9457164331337` |
| R12-D invalidation closure | 牧场主已授权；只把唯一 phase sink升级为 identity-bound set/invalidate command，并冻结 Supervisor exactly-once invalidator/global-fatal owner、Orchestrator registry/tombstone、App FIFO 与 #27/#35/source gates；candidate hashes/evidence见 `p1-a2-durable-rumination/evidence/plan-freeze-r12d.md`；后续Review12B见下一行 |
| Review12B immutable verdict | `reviews/12b-p1-plan-review.md`：`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`；SHA-256 `66b81e9e5ea0f74e08706c7367f2e80180601a000c9e84c1bbd4357a9c3b4ec5` |
| R12-E durable projection refresh closure | 牧场主已授权；只在同一callback内增加full projection commit milestone，冻结Store resulting version、Supervisor per-identity coordinator、Orchestrator typed optional refresh、App always-reload与halt post-cleanup delivery；当时hashes见 `p1-a2-durable-rumination/evidence/plan-freeze-r12e.md`；Review12C remained pending |
| R12-F start projection closure | R12-E follow-up为`0 P0 / 2 P1 / 1 P2`（无Review报告）；首次R12-F独立预检又为`0 P0 / 1 P1 / 1 P2`；牧场主已授权冻结Supervisor start owner、attempt-zero `version=1` commit+global claim barrier、两种replay origin归一、目标Camp readiness与现有single-writer lock-before-DB-open closure；新hashes见§1/§3，evidence为`p1-a2-durable-rumination/evidence/plan-freeze-r12f.md`；Review12C Pending |
| Review12C immutable verdict | `reviews/12c-p1-plan-review.md`：`APPROVED — 0 P0 / 0 P1`；SHA-256 `db94c2cd473cd311c79aa61b8a32b634409b9485b5b5fcef775b71ecf1f2a109`；当时只打开 A2 failure-first implementation gate，现仅为 historical predecessor |
| Review13 immutable verdict | `reviews/13-p1-plan-review.md`：`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`；SHA-256 `5203057f2a4a7f04827d9f5e0f20b717e08a31125404483b11f5cad722bda66b`；唯一P1-01为current gate分裂 |
| R13A current-gate closure | 只同步canonical headers、current entry/stop、review writer、验证前置与完成门；seam/矩阵/allowlist不变；exact hashes见§1/§3，freeze evidence为`p1-a2-durable-rumination/evidence/plan-freeze-r13a.md`；Review13A Pending |
| Review13A immutable verdict | `reviews/13a-p1-plan-review.md`：`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`；SHA-256 `edfb632ce1af2514dfe3168f87e0506fffe3a116f9cd6d3a427874933d399580`；唯一P1-01为control surfaces仍保留旧开门态 |
| R13B control-only closure | 只把 blocker 与两个 control index 的旧开门文字历史化；三份canonical、seam/矩阵/allowlist不变；freeze evidence为`p1-a2-durable-rumination/evidence/plan-freeze-r13b.md` |
| Review13B immutable verdict | `reviews/13b-p1-plan-review.md`：`APPROVED — 0 P0 / 0 P1`；SHA-256 `b798cffd016865b9441f6c8978da96d7382feb3e5dd51c7555e635bfbca84444`；曾打开R13 implementation |
| A2 R13 implementation result | 41-name、652-test、build/release、matrix/source/hash与fresh retry技术门完成；whole invocation因normal-root incident固定为`REJECTED_CONTAMINATED` |
| A2 Review01 immutable verdict | `p1-a2-durable-rumination/reviews/01-p1-a2-review.md`：`CHANGES REQUIRED — 0 P0 / 1 P1`；SHA-256 `5b6a171515404a644abcd05e3afc3840cb1dd4d84d7993f74af48de0692b4dd5` |
| R14 incident disposition | freeze `p1-a2-durable-rumination/evidence/plan-freeze-r14.md` immutable；Review14为`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`，SHA-256 `5bc0adf787dabd1451c53c7fc13df817325b323b030478443f62030bbf28e405`；唯一P1为bundle provenance缺口，R14从未开门 |
| R15 bundle-provenance closure | freeze `p1-a2-durable-rumination/evidence/plan-freeze-r15.md`与Review15均immutable；Review15批准plan，但随后R15 BEGIN executor false negative使invocation永久`REJECTED_CONTAMINATED`，且所有test/build/matrix/source/bundle/preview均未运行 |
| R16 static-attestation outcome | freeze `plan-freeze-r16.md`与Review16均immutable；四个terminal anchors与110/110 static manifest通过，但首个`pgrep -x AgentLoop`的正常absence `rc=1`被全局`ERR` trap在status assignment前截获。`r16-clean-boundary.log`、12个runtime paths及R16 fresh roots均absent，授权未消费且后续gate均未运行 |
| R17 status-capture closure | 13-block Bash ERR-trap/status-capture根因、fresh `r17-begin.sh`、immutable `r17-bash32-probes.sh`、115-entry manifest与freeze均已冻结；Review17判定`CHANGES REQUIRED — 0 P0 / 1 P1`，R17未执行，12个runtime paths与fresh roots均absent |
| R18/R18-A immutable chain | R18以单一phase-aware verifier关闭Review17 P1-01；R18-A把R15 historical empty/current `ABSENT`分层并冻结两个absorbing tombstones。freeze `62bbf93031371659e7ad2d4c60aac002eb13ed0915854f741e40251c9c2c1e76`、driver `911bbbc70556e41122cfdcc90048e504eee3480246b338131153856d524d7af9`、119-entry manifest `71e512a25e6e9bc0d024a53ad2502b55a378a82b39044a341930e1df440cfc2a` 与 Review18 `e0ee95f3703d73810d756410373c1da65fb1e08b08f6d7f74555e8095a12608b` 均immutable；R18未执行 |
| Review18 immutable verdict | `reviews/18-p1-plan-review.md`：`CHANGES REQUIRED — 0 P0 / 1 P1`；唯一P1-01为newline-delimited pathname serialization不能无歧义表示macOS合法的含换行pathname |
| R19 execution result | Review19 `APPROVED — 0 P0 / 0 P1`且获后续四hash授权；BEGIN与41/41 PASS，但authoritative full RunTests 651/652，唯一`slowActiveStreamDoesNotIdleTimeout`/`idle script exhausted`；boundary永久rejected，后续门未运行，zero product/test drift；11 repository artifacts与historical canonical-empty observations immutable，两个volatile roots current为`ABSENT_TOMBSTONE`/`UNKNOWN` |
| R20 execution result | Review20批准且取得四-hash执行授权；BEGIN、唯一full RunTests 652/652、46/46及LAUNCH_READY通过，随后automatic-product `--product AgentLoopCore`退化default graph并在release TestSuite caller/callee配置错配处失败；永久`REJECTED_CONTAMINATED`，后续门未运行；11 repository artifacts、缺失screenshot与historical signed-App hashes immutable，volatile state root current为`ABSENT`，bundle parent/App只按Review22的8/38 partial snapshot处理 |
| R21 immutable stop | 四锚与155/155均通过；driver在`pre_begin_r19_containment` exit70，发生在boundary与任何runtime write前；authority未消费，R21 paths/roots absent，Core/TestSuite仍为R20 final |
| R22 immutable plan result | Review22 `CHANGES REQUIRED — 0 P0 / 1 P1`；R20 parent/App partial skeleton使R22二态不可进入；R22未执行、未消费、zero runtime write |
| R23 execution result | BEGIN与六行guard已完成；full-test log终端652/652但zsh未捕获Bash PIPESTATUS，永久rejected，后续门未运行 |
| R24 immutable execution result | freeze/Review24/driver/178-entry manifest与十个实际runtime files均immutable；Review24已批准；执行完成full 652/652、same-log 46/46与fresh signed bundle后，在`guard_shape_and_strip`以`core_guard_shape_1:1::0:1:1`永久rejected；无END，report/screenshot absent |
| R25 immutable execution result | full 652/652、same-log 46/46及pre-preview gates通过；preview ERR-trap child containment使三次rejection、无UI challenge、无report/screenshot、无END |
| R27 current planning state | R26永久rejected；six surfaces/fresh driver/exact 220-entry manifest/freeze frozen；Review27 absent/pending；EOF R27 block为唯一current override，全部执行门关闭 |
| Open Questions 为空 | current Stage §30、Plan §20 与 A2 leaf §18 均精确为“无。” |
| 分支满足仓库规则 | `codex/personal-ai-ranch-p0` |
| 进入时代码基线 | `02334ec8d21533be81d93d39191bc7d9b9c24f7f` |
| 未扩大权限 | 仍禁止 commit、push、merge、release、数据重置、外部操作和真实用户操作 |

上述历史入口最初只打开 P1-A1a。Review09、A1a 有界实现、完整验证、Review01
与独立 acceptance 均已完成。A1b 的七项 planning/entry 契约缺口已由获授权的
R10 首轮 candidate 与 Review10 历史保存在
`evidence/r10-freeze-validation.md` 和 `reviews/10-p1-plan-review.md`。Review10
发现的两个 P1 已在 R10-6/R10-1 同一根因内有界修订，Candidate 2 与零代码漂移
证据见 `p1-a1b-durable-planning/blocked.md` 和
`evidence/r10a-freeze-validation.md`。职责隔离 Review10A 已在 Candidate 2 精确
hashes 上给出 `APPROVED — 0 P0 / 0 P1`，报告为
`reviews/10a-p1-plan-review.md`。随后 A1b 实施暴露的四个 R11 根因已由牧场主授权
有界修订；新 Candidate 与零代码漂移证据见
`docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/evidence/r11-freeze-validation.md`。
Review11 已在三份 exact hashes 上判定 `APPROVED — 0 P0 / 0 P1`，报告为
`reviews/11-p1-plan-review.md`，SHA-256
`f03000a92c3b8324a3ca824834cc7724b028c18bbe48061ea4fb72512b81d671`。
该判定曾重新打开 A1b 产品/测试 implementation gate。随后最终职责隔离 Review01
在保留首轮 `0 P0 / 2 P1` 历史的前提下，对有界根因修复判定
`APPROVED — 0 P0 / 0 P1`；独立 acceptance 又以 22/22 PASS 判定 `ACCEPTED`。
因此 A1b 已完成并关闭 R-01。A2 entry 已用于完成 R12/R12-A planning freeze；
Review12 随后以 `0 P0 / 2 P1` 要求修订。获授权的 R12-B 已机械关闭这两项且未
扩大 13+2 allowlist。其 phase pre-audit 又发现唯一 completion/source-gate P1；
R12-C 已只在同根因内穷尽 #27/#35 两轮 control/fatal 出口。Review12A 随后发现
positive-only sink无法在 persisted identity不变时清除第二轮已发phase。获授权
R12-D 已只在该根因内冻结单一 set/invalidate command sink、unique invalidator/
fatal owner、identity registry/tombstone与FIFO consumer。旧 Review12、Review12A
及三份 predecessor freeze evidence保持 byte-identical。Review12B随后以
`0 P0 / 1 P1 / 0 P2`指出phase-less terminal与halt cleanup commit无最终App
refresh。获授权R12-E只在同一callback内冻结full commit milestone、Store真实
version、per-identity串行delivery、typed optional clear/App always-reload与halt
post-cleanup refresh；旧Review与四份predecessor evidence保持byte-identical。
R12-E follow-up又发现start commit refresh与actor-reentrant claim barrier两个P1；
获授权R12-F已冻结Orchestrator façade→Supervisor唯一start owner、existing
`DurableWorkEnqueueResult`、attempt-zero exact `version=1` start milestone、process-local global
claim barrier、两种replay origin按workId归一，以及目标Camp persisted snapshot
ready-before-command。首次candidate预检的跨进程freshness P1由既有AppStore
lifetime-held `StateDirectoryLock`先于唯一production DB open的single-writer合同
收口；两个lock文件byte-identical，未来CLI/硬件同root writer须另开stage。
旧Review与R12-E及更早evidence继续byte-identical。
Review12C 已在 §1/§3 exact hashes 上判定
`APPROVED — 0 P0 / 0 P1`。首批五个 failure-first 红测已完成编译、各被发现一次，
并分别只以冻结的预期 capability failure 失败；`red-tests.log` SHA-256 为
`97b965160adb1b317c76d5227312ceb6c185642cccff0482c40ab281d84e0f15`。
因此当时 A2 产品实现门曾在冻结的 13+2 allowlist 内打开；该历史门已被后续
completion audit 与 Review13/13A 重新关闭，不构成 current implementation 授权。

## 3. 当前 slice 状态与下一入口

**Current P1-F1 route override (2026-08-27):** P1-E is `ACCEPTED` under
effective Revision 09
(`84026df99830853a101ca5aa41daec028da7e99545059a88451efe74d1d1ccb5`),
independent implementation Review02
(`77eae9651e0e907efc7a33810b5a4982d0be99ad13730069b7beee11227a06c0`),
and acceptance
(`114c3b6b157bce4e8de20bde5dbdc660bdeb8978629b5be1dcca0860891e50be`).
Its authoritative exact full run is 992 tests / 24 suites at SHA-256
`0a0be3ef6b29fd949c97628183e07514476fc4545ed396fd4fa7e691c23d51e6`.
Only the decision-complete P1-F1 leaf plan and a responsibility-isolated Codex
plan review are open. P1-F1 product/test/schema/v17 and all F2/P2
implementation remain closed until that review returns zero P0/P1. The user
excludes Claude; review artifacts must accurately disclose Codex authorship
and responsibility isolation. All lower route paragraphs remain immutable
historical evidence and are not the current gate.

**Current P1-C route override (2026-08-25):** P1-B Revision17 is
`ACCEPTED — 0 P0 / 0 P1 / 0 P2`. Authority is Review21
(`eea92e9752a5e4f8b3350673964084c78bc0b4376f6d1c34d60a22b9334d9e15`),
Review22
(`c5788dcbdd17eb3af4b117e8363751aff9260c6a705cd860fe05548f2a839b94`),
Acceptance23
(`da21f00e3eecdf2c69cbbe681f1568f00dec820f4320baaa6d184ac1b5755384`),
and authoritative `verify.log` SHA-256
`6eb521225e14d3de84595c0cd9bb2318ac3acbb072a3806f5543478fbabf2a87`
(714 tests / 7 suites). Only decision-complete
`p1-c-control-contracts/plan.md` creation and responsibility-isolated plan
review are open. P1-C product/test/schema/v14/Goal/Coach/Understanding and
P1-D OutcomeContract implementation remain closed. The 2026-08-11 paragraph
below and all lower R12–R28 text remain immutable historical evidence and are
not the current gate.

**Current override (2026-08-11):** `P1-A2 — Durable Rumination`、
`P1-A3 — Candidate Atomic Conversion` 与
`P1-A4 — Schedule Fire Evaluation/Commit` 均已独立验收为 `ACCEPTED`，
R-02/R-03/R-04 已关闭。当前 slice 是
`P1-B — Error Visibility and Application-Layer Seams`。现只开放 P1-B 只读映射、
Level-3 leaf、`try-question-mark-inventory.md` 与职责隔离 plan review；review 达到
零 P0/P1 前禁止产品/test/Package/App/script 实现。P1-B 独立验收前禁止进入
P1-C。内部证据可继续记录 hash，但不再要求用户 echo。

下方 A1b/A2 与 R12–R28 内容保持为历史证据，不再代表 current execution gate。

当前已完成的 slice：

- `P1-A1b — Durable Planning Supervisor + Integration`
- 入口证据：
  `p1-a1a-durable-work-store/acceptance.md`
- blocker：
  `p1-a1b-durable-planning/blocked.md`
- frozen leaf Plan：
  `p1-a1b-durable-planning/plan.md`
  - SHA-256：
    `4fd98fad71ead93e88d36545127e484be121f8177784a006659483162f922f56`
- 最终 implementation Review：
  `p1-a1b-durable-planning/reviews/01-p1-a1b-review.md`
  - verdict：`APPROVED — 0 P0 / 0 P1`
  - SHA-256：
    `8c96b742285da1c1999c5360071728cbdf287cfeffeb6b25e281485336e0b1a0`
- 独立 acceptance：
  `p1-a1b-durable-planning/acceptance.md`
  - status：`ACCEPTED`，22/22 PASS
  - SHA-256：
    `efe4d20a7cb4dc3f61d028637a6705d3ed56d4fdd5596ebc3cb993d94481bf1e`
- A1b 状态：`Accepted`；R-01：`Closed`。

当前 planning slice 是 `P1-A2 — Durable Rumination`：

- blocker / authorization history：
  `p1-a2-durable-rumination/blocked.md`
- current R25 frozen leaf Plan：
  `p1-a2-durable-rumination/plan.md`
  - current identity由现有freeze单向绑定
- immutable R24 freeze / Review / driver / manifest：
  `p1-a2-durable-rumination/evidence/plan-freeze-r24.md`、
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/24-p1-plan-review.md`、
  `p1-a2-durable-rumination/evidence/r24-begin.sh`与
  `p1-a2-durable-rumination/evidence/r24-entry.sha256`；对应SHA依次为
  `f22a7ffd954ddf6d9b2d804a5f3be58807373c388634b9200d260f1a8eb66746`、
  `a9ef2cab24afa65290f563b85ac03022b958d39253c025017d1c91b689926c0e`、
  `1b224f442d1fdea856433d12141e5ea9f74190a380e554e4ec94872ba0b8655f`与
  `55a6c2e8a657166de8b983cd0edfb2a7b1ae1943dc291819c0c2ea417338a80c`
- immutable R24 execution result：十个实际runtime files保留；Review24已批准但执行在
  `guard_shape_and_strip`永久`REJECTED_CONTAMINATED`，无END，report/screenshot absent
- R25 frozen driver：
  `p1-a2-durable-rumination/evidence/r25-begin.sh`；SHA-256
  `1eee61d199c5bb1c5b0149989f17508e9a75eacfbc2bac3b1a2f0063f0ab68bb`
- R25 frozen gates：exact 192-entry `r25-entry.sha256`与`plan-freeze-r25.md`均已存在且current；
  manifest已验证`192/192`，freeze已单向绑定current六面/driver/manifest；
  `reviews/25-p1-plan-review.md`仍不存在且Pending
- immutable R20 freeze / Review / execution evidence：
  `p1-a2-durable-rumination/evidence/plan-freeze-r20.md`、
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/20-p1-plan-review.md`、
  `p1-a2-durable-rumination/impl-report-r20.md`；R20永久
  `REJECTED_CONTAMINATED — release_core_build`
- immutable R19 freeze evidence：
  `p1-a2-durable-rumination/evidence/plan-freeze-r19.md`；SHA-256
  `d7869b0531f5dc868a1e8d92b2aec9f0abf3cd84e0d3857b481f8fcc3807d03f`
- immutable predecessors：
  `reviews/12-p1-plan-review.md`、`reviews/12a-p1-plan-review.md`、
  `reviews/12b-p1-plan-review.md` 与
  `p1-a2-durable-rumination/evidence/plan-freeze.md`、以及
  `p1-a2-durable-rumination/evidence/plan-freeze-r12b.md`、
  `p1-a2-durable-rumination/evidence/plan-freeze-r12c.md`、
  `p1-a2-durable-rumination/evidence/plan-freeze-r12d.md`、
  `p1-a2-durable-rumination/evidence/plan-freeze-r12e.md`
- Review12C：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/12c-p1-plan-review.md`
  - verdict：`APPROVED — 0 P0 / 0 P1`
  - SHA-256：
    `db94c2cd473cd311c79aa61b8a32b634409b9485b5b5fcef775b71ecf1f2a109`
- red gate：
  `p1-a2-durable-rumination/red-tests.log`
  - result：Build complete；5/5 tests discovered；5/5 expected capability failures
  - SHA-256：
    `97b965160adb1b317c76d5227312ceb6c185642cccff0482c40ab281d84e0f15`
- Review13：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/13-p1-plan-review.md`
  - verdict：`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`
  - SHA-256：
    `5203057f2a4a7f04827d9f5e0f20b717e08a31125404483b11f5cad722bda66b`
- Review13B：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/13b-p1-plan-review.md`
  - verdict：`APPROVED — 0 P0 / 0 P1`
  - SHA-256：
    `b798cffd016865b9441f6c8978da96d7382feb3e5dd51c7555e635bfbca84444`
- A2 implementation Review01：
  `p1-a2-durable-rumination/reviews/01-p1-a2-review.md`
  - verdict：`CHANGES REQUIRED — 0 P0 / 1 P1`
  - SHA-256：
    `5b6a171515404a644abcd05e3afc3840cb1dd4d84d7993f74af48de0692b4dd5`
- Review14 predecessor：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/14-p1-plan-review.md`
  - verdict：`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`
  - SHA-256：
    `5bc0adf787dabd1451c53c7fc13df817325b323b030478443f62030bbf28e405`
- Review15 predecessor：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/15-p1-plan-review.md`
  - verdict：`APPROVED — 0 P0 / 0 P1`
  - SHA-256：
    `fbaa9612588c39cb5d99e95d9b68e00a234510e325abf5823c15f0b1eb8ecc05`
- R15 rejected invocation：
  `p1-a2-durable-rumination/impl-report-r15.md`
  - verdict：`REJECTED_CONTAMINATED — BEGIN attestation false negative`
  - SHA-256：
    `e6b0226b3440da997f7e08571d8e5e5229d66069ea5ad6485ee146c249dbe72e`
- Review16 predecessor：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/16-p1-plan-review.md`
  - verdict：`APPROVED — 0 P0 / 0 P1`
  - SHA-256：
    `71f16eceef429f7d02fe8908c4609b9bd0b0b98b44c68b579a75ced2ac9d9824`
- R16 pre-BEGIN outcome：
  四个terminal anchors与110/110 static manifest通过；首个
  `pgrep -x AgentLoop`返回正常absence `rc=1`后被继承的全局`ERR` trap截获。
  `evidence/r16-clean-boundary.log`与全部12个runtime paths均absent，
  `/private/tmp/agentloop-r16-state.*`和
  `/private/tmp/agentloop-r16-bundle.*`均absent；授权未消费，未运行任何后续gate。
- Review17 predecessor：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/17-p1-plan-review.md`
  - verdict：`CHANGES REQUIRED — 0 P0 / 1 P1`
  - SHA-256：
    `c6838d3c5a9fcfef80dc9db4abf560af712e3175372a163edccb72197daf3dbe`
- R17 not-executed outcome：
  R17没有取得Review approval或后续四-hash授权；全部12个runtime paths与
  `/private/tmp/agentloop-r17-state.*`、
  `/private/tmp/agentloop-r17-bundle.*`均absent，没有运行任何执行门。
- Review18 predecessor：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/18-p1-plan-review.md`
  - verdict：`CHANGES REQUIRED — 0 P0 / 1 P1`
  - SHA-256：
    `e0ee95f3703d73810d756410373c1da65fb1e08b08f6d7f74555e8095a12608b`
- R18 not-executed immutable chain：
  freeze `62bbf93031371659e7ad2d4c60aac002eb13ed0915854f741e40251c9c2c1e76`；
  driver `911bbbc70556e41122cfdcc90048e504eee3480246b338131153856d524d7af9`；
  119-entry manifest
  `71e512a25e6e9bc0d024a53ad2502b55a378a82b39044a341930e1df440cfc2a`。
  Review18未批准，R18没有运行；全部R18 runtime paths与fresh roots均absent。
- Review19 immutable verdict：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/19-p1-plan-review.md`
  - verdict：`APPROVED — 0 P0 / 0 P1`
  - SHA-256：
    `4588cd645edd47c7648f9c8e372fb4de42f2b8dd3a2bfeb31282aba2d6e7c41c`
- R19 rejected invocation：
  invocation `r19-daef1dab-0fbe-4a03-bab1-422adc18b3d4`；BEGIN、pre/post
  manifest与41/41 A2 targeted均通过；唯一未过滤authoritative
  `swift run RunTests`为651/652，唯一失败
  `slowActiveStreamDoesNotIdleTimeout`（`AgentLoopTests.swift:611`，
  `idle script exhausted`）。R19 boundary永久`REJECTED_CONTAMINATED`，未运行
  build/release/matrix/source/bundle/preview/END，zero product/test drift；11项实际
  artifacts与两个exact real non-symlink empty roots保持immutable，screenshot absent。
- R20 rejected invocation：
  invocation `r20-98452cde-0ff4-4b66-b3f6-8085eb045a6f`；唯一未过滤full
  RunTests 652/652、同log 46/46、debug build与LAUNCH_READY通过；随后
  `swift build -c release --product AgentLoopCore`因automatic-product fallback进入
  default target graph并在release TestSuite的unguarded test caller处失败。boundary永久
  `REJECTED_CONTAMINATED`；matrix/source/preview/END未运行。11项repository artifacts、
  缺失screenshot与historical signed-App hashes immutable；volatile state root现为ABSENT，
  bundle parent/App按Review22的8/38 partial snapshot处理，不再声称当前signed App。
- current gate：
  `R24 REVIEW APPROVED / EXECUTION REJECTED_CONTAMINATED — GUARD SHAPE 1:1::0:1:1；R25 BEGIN REJECTED_CONTAMINATED — FULL 652/652 / SAME-LOG 46/46 / PREVIEW ERR-TRAP DOUBLE CONTAINMENT / NO END；R26 BEGIN REJECTED_CONTAMINATED — FULL 652/652 / SAME-LOG 46/46 / B01–B06 PASS / QUIT-WAIT COMPOUND-IF STATUS LOST / NO COLD / NO SCREENSHOT/REPORT/END；R27 Compound-If Status-Capture Candidate Frozen；Driver/220-entry Manifest/Freeze Present；Review27 Pending；A2 Clean Re-verification Blocked`

exact 192-entry R25 static manifest已验证`192/192`，`plan-freeze-r25.md`已单向绑定current
六面/driver/manifest。下一门仅允许未参与R25六面、driver、manifest或
freeze写入的职责隔离reviewer核对current bytes并只写`reviews/25-p1-plan-review.md`。
Review25唯一零P0/P1前不得caller/BEGIN或运行任何执行门；通过且standing Goal未被更新user turn
撤销后，root agent自动计算Review25 SHA并调用冻结caller，无用户hash echo。

R24 filesystem observations仍不提供transaction、lock或atomic snapshot，不证明inode/
hardlink、xattr/resource fork不变，且不能消除capture窗口外TOCTOU；“commit”只指比较通过后
同一进程变量提交。要求更强filesystem保证必须另开stage与Review。

已完成的 A1a：

- `P1-A1a — Durable Work DDL + Store`
- 固定目录：
  `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a1a-durable-work-store/`
- 执行 Plan：
  `p1-a1a-durable-work-store/plan.md`

A1a 的规范锚点是冻结 Stage §5.1、§6.1、§6.2、§6.2.1、§6.2.2、§18.1、
§20 的 P1-A 完成门、§22 红线和 §23 回滚兼容规则；精确实施范围来自冻结 Plan
§1、§3.1、§10–§13。这里只列定位，不重述、不改写这些规范。

## 4. 阶段门

1. A1a 已由独立 acceptance owner 判定 `ACCEPTED`。
2. 首轮 Review10 在原 candidate 上判定 `0 P0 / 2 P1`；不可变报告位于
   `reviews/10-p1-plan-review.md`。
3. 两项 finding 已在 R10-6/R10-1 同一根因内关闭并冻结为 Candidate 2；三份
   hashes、预冻结双路 `0 P0 / 0 P1` 与零代码漂移指纹见
   `evidence/r10a-freeze-validation.md`。
4. Review10A 报告
   `reviews/10a-p1-plan-review.md` 为 `APPROVED — 0 P0 / 0 P1`，SHA-256
   `a268725470996d04db109b4caeb378fdfa64b66abd85b6f7ac55ecb420956bfe`；
   这是历史进入证据，不覆盖后续 R11 gate。
5. R11 Candidate hashes 与 freeze evidence 已冻结；职责隔离 Review11 已判定
   `APPROVED — 0 P0 / 0 P1`。
6. A1b implementation、完整验证证据与有界 Review01 finding closure 已完成。
7. 最终职责隔离 Review01 位于
   `p1-a1b-durable-planning/reviews/01-p1-a1b-review.md`，判定
   `APPROVED — 0 P0 / 0 P1`，SHA-256 为
   `8c96b742285da1c1999c5360071728cbdf287cfeffeb6b25e281485336e0b1a0`；
   报告继续保存首轮 `0 P0 / 2 P1` 历史。
8. 独立 acceptance 位于 `p1-a1b-durable-planning/acceptance.md`，以 22/22 PASS
   判定 `ACCEPTED`，SHA-256 为
   `efe4d20a7cb4dc3f61d028637a6705d3ed56d4fdd5596ebc3cb993d94481bf1e`。
9. A1b `Accepted` 已关闭 R-01；不关闭或改变任何 R-02 及后续风险项。
10. R12/R12-A 的原 candidate 已由 immutable Review12 判定
    `CHANGES REQUIRED — 0 P0 / 2 P1`；旧报告与旧 freeze evidence 不得改写。
11. R12-B 只机械关闭两项 Review12 finding；其 phase pre-audit历史与
    `evidence/plan-freeze-r12b.md` 保持 immutable。
12. R12-C 只机械扩展 #27/#35 与 Stage completion/source gate，并重新冻结
    Stage/Plan/leaf与单行 control hash；不代表 Review12A、implementation 或
    acceptance。
13. Review12A 已在 R12-C exact hashes上判定
    `CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`；immutable报告不得改写。
14. R12-D 只关闭该 phase invalidation owner/API同根因并重新冻结，不改变#31、
    41 names、13+2 allowlist、schema/EventKind或产品/test范围。
15. Review12B 已在R12-D exact hashes上判定
    `CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`，immutable报告不得改写。
16. R12-E只关闭durable projection commit最终refresh根因；一个callback、两个
    KernelEvent cases、#31、41 names、13+2 allowlist与schema/EventKind保持不变。
17. R12-F关闭start commit refresh/claim-barrier、replay归一与独立预检freshness
    finding；new insert exact `version=1`，现有single-writer lock-before-DB-open
    成为entry/red line；一个callback、两个KernelEvent cases、#31、41 names、
    13+2 allowlist与schema/EventKind保持不变。
18. Review12C 已在 §1/§3 exact hashes 上判定 `APPROVED — 0 P0 / 0 P1`；首批五个
    红测随后通过编译、发现与预期 capability failure 质量门，现仅在 13+2
    allowlist 内留下pre-R13实现；完整验证、Review/acceptance 与 A3 仍关闭。
19. Review13在R13 exact hashes上判定`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`；
    报告immutable，唯一P1-01为当前执行权威分裂。
20. R13A只同步canonical current gate；Review13A判定
    `CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`，唯一P1仍是control surfaces旧开门态。
21. R13B只把blocker与两个control index旧开门文字历史化；Review13B已判定
    `APPROVED — 0 P0 / 0 P1`。
22. R13 implementation技术门完成，但display-name lookup误启动installed App并
    打开normal lock/DB/SHM/WAL；Review01判定`CHANGES REQUIRED — 0 P0 / 1 P1`，
    R13 whole invocation固定为`REJECTED_CONTAMINATED`。
23. R14只定义前瞻性clean boundary；Review14以bundle provenance缺口判定
    `CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`，R14没有打开执行。
24. R15 plan获Review15批准，但BEGIN false negative后永久
    `REJECTED_CONTAMINATED`；所有repository证据保持immutable。两个volatile roots只在
    containment时被观察为空，2026-08-02 current复核为`ABSENT`、原因`UNKNOWN`，
    不得声称连续保全。
25. Review16已批准R16 frozen plan；后续R16 caller的四anchors与110/110 manifest
    通过，但首个`pgrep`正常`rc=1`被全局`ERR` trap截获。消费点未到达，12个runtime
    paths与fresh roots均absent，所有后续gate未运行。
26. R17关闭13个status-capture blocks的同一根因并冻结fresh driver、Bash 3.2
    probes、115-entry manifest与freeze；Review17仍以RanchArt结构门位于授权消费后
    判定`CHANGES REQUIRED — 0 P0 / 1 P1`。R17未执行，全部runtime paths/roots absent。
27. R18关闭Review17 P1-01：一个phase-aware verifier与一个expected 27 set；
    pre-consumption调用是exclusive-create/授权消费前最后门，零repository write且
    失败只console；消费后、创建其他runtime artifacts/roots前立即执行
    post-activation重读并把结构证据写入hash log，不能复用boolean/snapshot；随后才
    独立重跑119-entry bytes门。pre-consumption失败保持零写入/授权未消费；只有
    boundary消费后的重读或bytes门失败才永久`REJECTED_CONTAMINATED`。该双读取不宣称
    原子FS lock或消除所有TOCTOU。
28. R18-A把两个current `ABSENT` exact R15 paths冻结为absorbing tombstones；联合
    `/private/tmp` exact-basename parent enumeration、任何node重现或indeterminate均
    fail closed，evidence记录两个exact
    `r15_*_pre_begin_observed_state=ABSENT`、两个`r15_*_current_absent=true`、proof
    identity与`disappearance_cause=UNKNOWN`。
    preserved-root `realpath` C被一对一替换，inherited仍为`2P/4S/7C=13`，另计既有
    root-glob C后driver total为`2P/4S/8C=14`；immutable
    `r17-bash32-probes.sh`继续复用。119-entry manifest精确为R17 115项加R18 driver、R17
    manifest、R17 freeze与Review17，并排除自身/R18 freeze/Review18/runtime。
29. Review18在上述immutable R18 chain上判定
    `CHANGES REQUIRED — 0 P0 / 1 P1`；SHA-256为
    `e0ee95f3703d73810d756410373c1da65fb1e08b08f6d7f74555e8095a12608b`。唯一P1-01是
    newline-delimited RanchArt pathname serialization可被含换行的合法macOS pathname
    伪造；R18从未取得批准或执行授权，未运行任何执行门。
30. R19只关闭Review18 P1-01：single `find -P -print0`直接进入Bash 3.2
    `read -r -d ''` NUL pipeline，不经line serialization或command substitution；完整
    消费NUL stream并逐项以pathname bytes证明exact 27 allowed paths均regular
    non-symlink且无额外node，任何find/read/incomplete-record/type/set异常均fail closed。
    capture inventory更新为core `3P/3S/3C=9`、计入既有root-glob C后的driver total
    `3P/3S/4C=10`；123-entry manifest精确继承R18 119项并增加R19 driver、R18 manifest、
    R18 freeze与Review18。R19使用fresh driver、12个runtime artifact names及
    `/private/tmp/agentloop-r19-state.*`、`/private/tmp/agentloop-r19-bundle.*` roots，
    不复用或创建任何R18 runtime path。
31. Review19以`APPROVED — 0 P0 / 0 P1`批准R19 plan且牧场主随后给出四-hash授权。
    R19 BEGIN、pre/post manifest与41/41 targeted通过，但唯一authoritative unfiltered
    full suite为651/652；唯一`slowActiveStreamDoesNotIdleTimeout`失败于
    `idle script exhausted`。invocation永久`REJECTED_CONTAMINATED`，后续门未运行，
    zero product/test drift；11 artifacts、缺失screenshot与两个exact empty roots
    immutable。
32. R20只在Review20与后续四-hash授权后打开两文件deterministic-time exception：
    `AgentLoop.swift`与`AgentLoopTests.swift`。private factory与单一generic
    `IdleWatchdog<C: Clock>`必须复用production算法；debug-only package initializer标签
    精确为`idleClockForTesting`，`ManualAgentLoopClock`只在test source。五项exact tests
    与既有41项只能从同一次、未过滤且失败不重跑的authoritative `swift run RunTests`
    机械审计；full suite必须全绿。140-entry manifest在edit前140/140，edit后只能两个
    authorized source mismatches且其余138/140 unchanged；第三个mismatch fatal。Review20
    后实际执行为652/652，但在release Core命令退化default graph后永久rejected；该
    partial green不能成为acceptance。
33. R21只在Review21与后续四-hash授权后打开`AgentLoopTests.swift`单文件exception；
    `AgentLoop.swift`必须保持R20 final SHA
    `c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275`。
    TestSuite只增加三对matching direct DEBUG guards，移除六行directive后必须恢复R20
    final hash；release Core与TestSuite分别用`--target`构建，四个exact Core/TestSuite
    release/debug objects执行双向symbol门。155-entry manifest edit前155/155、edit后
    154 unchanged + test唯一mismatch；第二个mismatch fatal。Review21 Pending期间全部
    执行与test修改关闭。
34. R22为immutable changes-required predecessor：Review22发现present partial skeleton，
    R22没有approval/caller/BEGIN且zero-write/未消费；不得再按verified-retained/absent二态
    执行或重跑。
35. R23曾取代#34：Review22 baseline 8/38冻结；首次baseline→A、之后
    LATEST→A→B只允1→0，FIRST=A/LATEST=B且signal-deferred in-process commit。163-entry
    manifest与Review23均通过；执行随后因zsh未捕获PIPESTATUS永久rejected。
36. R24是immutable executed predecessor：freeze/Review24/driver/178-entry manifest与十个
    runtime files固定；Review24已批准，执行的full 652/652、same-log 46/46与fresh signed bundle
    通过，但guard shape false negative使invocation永久rejected且无END。
37. R25取代#36为current frozen gate：只修numeric rendering，产品/test/App与永久script
    delta 0；driver、exact 192-entry manifest与freeze均已存在，Review25在该历史snapshot中尚未创建；其后已批准且R25执行永久rejected。下一门
    严格为职责隔离Review25 only→automatic caller/no hash echo；此前全部执行关闭。
38. commit、push、merge、release、数据重置、付款、公开沟通、外部操作和真实用户
    操作权限均未扩大。

### 4.1 R24 final single-process clean-execution contract

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

### 4.2 R25 numeric-rendering root-cause closure

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


### 4.3 R26 ERR-subshell root-cause closure

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

## 5. 本索引的变更边界

本文件只在 slice 状态、证据位置或已通过的阶段门发生事实变化后更新。若需要改变
数据模型、API、文件范围、测试门、红线或执行顺序，不能在这里修改；必须回到冻结
规范的正式修订与职责隔离 Review 流程。

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
