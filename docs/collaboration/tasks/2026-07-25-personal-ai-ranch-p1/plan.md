# P1 执行控制索引 — Plan

> 状态：**P1-E ACCEPTED；P1-F1 decision-complete planning entry open；P1-F1 implementation closed**
>
> 日期：2026-08-26
>
> 文档性质：执行控制索引；唯一总 Plan 仍是 P0 目录中的权威文件；R15–R28 与 A2/A3
> 历史证据保持 immutable；current route 由下方 P1-D override 指定

## 1. 权威输入与冻结历史

| 文档 | 唯一路径 | SHA-256 |
|---|---|---|
| P1 Stage | `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md` | R21 predecessor `819c37d6181b54be71031f0300d89aa5d30c26af5ec12975c296b8c7316c6704`；R27 executed snapshot由immutable R27 freeze绑定；R28 current bytes由fresh freeze单向绑定 |
| P1 Plan | `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md` | R21 predecessor `83644e0958e8f0486578d655175982d95ee9b5a5997bc385f49789c21e12da1e`；R27 executed snapshot由immutable R27 freeze绑定；R28 current bytes由fresh freeze单向绑定 |
| A2 leaf Plan | `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination/plan.md` | R21 predecessor `1d4ea207855241e21a4df01b001dfef8da37684e19f9d4cee1c844fb26a19777`；R27 executed snapshot由immutable R27 freeze绑定；R28 current bytes由fresh freeze单向绑定 |

上述三个hash只固定immutable R21 predecessor。R22/R23 freeze、Reviews与R23 failure
evidence保留。R24 freeze
`f22a7ffd954ddf6d9b2d804a5f3be58807373c388634b9200d260f1a8eb66746`、Review24
`a9ef2cab24afa65290f563b85ac03022b958d39253c025017d1c91b689926c0e`、driver
`1b224f442d1fdea856433d12141e5ea9f74190a380e554e4ec94872ba0b8655f`、178-entry manifest
`55a6c2e8a657166de8b983cd0edfb2a7b1ae1943dc291819c0c2ea417338a80c`与十个actual runtime
files均immutable；Review24已批准，但R24执行永久rejected且无END。R25 freeze/Review25/driver/
192-entry manifest与十个runtime files均immutable；full 652/652及其后partial greens不改变
preview ERR-trap double-containment rejection与no-END。R26随后验证child ERR fix，却在B01–B06
后因compound-if status capture丢失helper rc而永久rejected。R27修复该根因后以唯一full
651/652在Shell timeout测量边界失败，未进入later gates且无END。EOF R28 override关闭了该
测量边界根因；R28 clean execution、Review02 与 independent acceptance 已完成，A2 已
`ACCEPTED`。这些 hashes/manifest 继续作为 immutable 历史证据，不再构成 current P1-B
执行门，也不要求用户 echo。

本文件不复制总 Plan，也不产生第二套产品语义。Current slice 必须遵循下方 override、
对应 reviewed leaf 与精确 allowlist；未知冲突或范围漂移必须停止执行。

## 2. 严格执行序列

冻结 Plan §1 的顺序保持不变：

```text
P1-A1a → A1b → A2 → A3 → A4 → B → C → D → E → F1 → F2
```

**Current P1-F1 route override (2026-08-27):** P1-E is `ACCEPTED` under
effective Revision 09
(`84026df99830853a101ca5aa41daec028da7e99545059a88451efe74d1d1ccb5`),
independent implementation Review02
(`77eae9651e0e907efc7a33810b5a4982d0be99ad13730069b7beee11227a06c0`),
and acceptance
(`114c3b6b157bce4e8de20bde5dbdc660bdeb8978629b5be1dcca0860891e50be`).
Its authoritative full run is 992 tests / 24 suites at `verify.log` SHA-256
`0a0be3ef6b29fd949c97628183e07514476fc4545ed396fd4fa7e691c23d51e6`.
Only decision-complete P1-F1 planning and its responsibility-isolated Codex
plan review are open. P1-F1 product, test, schema/v17, Engine, Artifact,
Discussion, Attention, Growth, and every later implementation remain closed.
The user excludes Claude but permits responsibility-isolated Codex reviewers;
no review may misstate its authorship or independence. All lower P1-E/P1-D/
P1-C/P1-B and R12–R28 route paragraphs remain immutable historical evidence
and do not represent the current gate.

**Current P1-E route override (2026-08-26):** P1-D is
`ACCEPTED` under plan
(`3b34e4f699a568d2be5cf345dfa260615d29c5708fd21b29772c723858598acf`),
bounded revisions
(`e644c521d4c8898d49b0fa163c68afff9dfb3e3026e7a816ea7c847b4bf2c945`
and
`aea7dff6a34d7d8b8aba0ab74bc1c0dbdbfad50b41cb4f12f3747c102afa8095`),
Review02
(`082267683324c6b341bbb3125860301c208ba1dff53066b455481aea1cf13145`),
and acceptance
(`bef50bba0f5baf6d0fbe4a194b97b1fe05c247ba211dc6f111cf145b5c7566bd`).
Its authoritative full run is 900 tests / 15 suites at `verify.log` SHA-256
`b37571c23456add5b0ca197551fa4149defe318ca1b571c17684907908e5a970`.
Only decision-complete P1-E planning and its disclosed no-Claude self-review
are open. P1-E product, test, schema/v16, Cow/Residency/Camp lifecycle,
Memory, ingestion deletion, and every later implementation remain closed. The
user explicitly directed Codex to proceed without Claude or delegated agents,
so no review artifact may claim independence. All lower P1-D/P1-C/P1-B and
R12–R28 route paragraphs remain immutable historical evidence and do not
represent the current gate.

**Current P1-D route override (2026-08-25):** P1-C is
`ACCEPTED — 0 P0 / 0 P1` under Revision 8 plan
(`142ce6fdce15dec73d45a72ebb8840fb7e5e131cc45e17e728131fcffa3ee52c`),
Review02
(`9aa429822dadf2986f96173114965071f61bb02ce3a1c95b05e2d18c4faecd5f`),
and acceptance
(`417be624b8c9a1b64730d5f3ebbca07d64aaa741159296d74f1520f44423ab82`).
Its authoritative full run is 816 tests / 11 suites at `verify.log` SHA-256
`9262b2b9c9725a41215cecaf9d0c75151e5f2de6a4b91edd13e433b3e51d1cbe`.
Only decision-complete P1-D planning and its disclosed no-Claude self-review
are open. P1-D product, test, schema/v15, Goal active/paused/achieved,
OutcomeContract, Outcome, Verification, Acceptance, ApprovalGrant, and every
later implementation remain closed. The user explicitly directed Codex to
proceed without Claude or delegated agents, so no review artifact may claim
independence. All lower P1-C/P1-B and R12–R28 route paragraphs remain immutable
historical evidence and do not represent the current gate.

**Current P1-C route override (2026-08-25):** P1-B Revision17 is
`ACCEPTED — 0 P0 / 0 P1 / 0 P2`. Its authority is Review21
(`eea92e9752a5e4f8b3350673964084c78bc0b4376f6d1c34d60a22b9334d9e15`),
Review22
(`c5788dcbdd17eb3af4b117e8363751aff9260c6a705cd860fe05548f2a839b94`),
Acceptance23
(`da21f00e3eecdf2c69cbbe681f1568f00dec820f4320baaa6d184ac1b5755384`),
and the authoritative 714-test / 7-suite evidence at `verify.log` SHA-256
`6eb521225e14d3de84595c0cd9bb2318ac3acbb072a3806f5543478fbabf2a87`.
Only creation and responsibility-isolated review of the decision-complete
`p1-c-control-contracts/plan.md` are open. P1-C product, test, schema, v14,
Goal/Coach/Understanding, P1-D OutcomeContract, and every later implementation
remain closed. All lower R12–R28 and 2026-08-11 route paragraphs remain
immutable historical evidence and do not represent the current gate.

**Current P1-B route override (2026-08-11):** P1-A2, P1-A3, and P1-A4
independent acceptance are all `ACCEPTED`; R-02, R-03, and R-04 are closed.
A4 Review03 is `APPROVED — 0 P0 / 0 P1 / 0 P2`, its authoritative full run is
667/667, and `p1-a4-schedule-fire/acceptance.md` opens only bounded Level-3
planning for P1-B. The current work unit is canonical Stage §7/§18.3/§10 and
Plan §4/§10 plus a new decision-complete
`p1-b-error-visibility/plan.md` and
`p1-b-error-visibility/try-question-mark-inventory.md`. Product/test/Package/
App/script implementation remains closed until a responsibility-isolated plan
review returns `APPROVED` with no P0/P1. P1-B acceptance is required before
P1-C. Hashes and manifests may be generated internally as evidence, but no user
hash echo is required. Older R12–R28/A2/A3/A4 gate text remains immutable
process history and does not override this current route.

首轮 Review10 对 R10 candidate 判定 `0 P0 / 2 P1`；两项 finding 已在既有
R10-6/R10-1 根因内有界修订并冻结为 Candidate 2。Review10A 已判定
`APPROVED — 0 P0 / 0 P1`，曾打开 A1b implementation gate。后续实施发现的四个
R11 根因已获授权、修订并重新冻结；Review11 已判定
`APPROVED — 0 P0 / 0 P1`，因此曾重新打开 A1b 产品/测试 implementation gate。
最终 Review01 在保留首轮 `0 P0 / 2 P1` 历史的前提下判定
`APPROVED — 0 P0 / 0 P1`；独立 acceptance 以 22/22 PASS 判定 `ACCEPTED`。
因此 A1b 已关闭 R-01。牧场主随后授权 R12/R12-A，完成 A2 原 candidate；
immutable Review12 以 `CHANGES REQUIRED — 0 P0 / 2 P1` 要求修订。牧场主又授权
R12-B 只机械关闭 provider/parse/phase handshake 与完整 legacy 8-cell；其 phase
pre-audit又以 `0 P0 / 1 P1 / 0 P2`（无报告文件）发现 completion/source gate
未穷尽两轮 control/fatal出口。R12-C 已只扩展 #27/#35 与对应 Stage gate，并重新
冻结 Stage/总 Plan/leaf与 matrix script 单行 Stage hash。Review12A随后在该
candidate判定 `CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`：persisted identity不变时
没有live phase invalidation producer。获授权R12-D只把唯一sink升级为typed
set/invalidate，补齐Supervisor unique invalidator/fatal owner、Orchestrator exact
registry/tombstone、App FIFO与#27/#35/source gates，并重新冻结。Review12B随后
判定`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`：phase-less terminal与halt cleanup
commit没有最终App refresh owner。获授权R12-E只冻结同callback full commit
milestone、Store resulting version、Supervisor per-identity coordinator、
Orchestrator typed optional event、App always reload与halt post-cleanup delivery。
R12-E follow-up又以`0 P0 / 2 P1 / 1 P2`（无Review报告）发现start commit
refresh与actor-reentrant claim barrier两个P1；获授权R12-F只冻结Supervisor唯一
start owner、attempt-zero exact `version=1` commit+global claim barrier、两种replay
origin归一与目标Camp snapshot readiness，不采纳P2持久outbox/receipt扩张。首次
R12-F独立预检又以`0 P0 / 1 P1 / 1 P2`指出跨进程freshness窗口与version可收紧；
已按牧场主授权冻结现有AppStore lifetime-held single-writer
lock-before-唯一production DB open合同，不扩大event/replay refresh API。
Review12C 已在 frozen exact hashes 上判定`APPROVED — 0 P0 / 0 P1`。当时只打开
A2 首批五个 failure-first 红测；该门随后以 Build complete、5/5 exact discovery
和5/5 expected capability failures通过，`red-tests.log` SHA-256为
`97b965160adb1b317c76d5227312ceb6c185642cccff0482c40ab281d84e0f15`。A2产品实现
随后形成pre-R13绿色证据，但completion audit发现动态覆盖缺口。R13已冻结；
Review13在其exact hashes上判定`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`，
immutable SHA-256为
`5203057f2a4a7f04827d9f5e0f20b717e08a31125404483b11f5cad722bda66b`。
R13A只同步canonical current gate；Review13A仍以
`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`发现control surfaces旧开门态。
R13B只关闭该control文字根因；Review13B随后判定
`APPROVED — 0 P0 / 0 P1`并打开R13 implementation。技术实现与完整门完成，但
preview display-name lookup误启动installed App并打开normal lock/DB/SHM/WAL，
Review01判定`CHANGES REQUIRED — 0 P0 / 1 P1`，whole R13 invocation为
`REJECTED_CONTAMINATED`。牧场主随后授权R14只定义后续one-shot clean
re-verification；Review14以bundle provenance缺口判定
`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`，R14从未开门。牧场主授权R15关闭该P1，
Review15批准了plan；随后R15 BEGIN executor在expected/actual逐字相同的Review12C
hash上false-negative，整个R15 invocation永久`REJECTED_CONTAMINATED`，没有运行
任何test/build/matrix/source/bundle/preview。R16随后以reviewed Bash driver与static
manifest替换该attestation风险类，Review16批准plan；获四-hash授权后的external
caller与driver pre-BEGIN四anchors/110-entry manifest均通过，但第一个
`pgrep -x AgentLoop`正常absence `rc=1`被继承的全局`ERR` trap在status assignment前
截获。唯一消费点未到达，12个R16 runtime paths与fresh roots均absent，所有后续gate
未运行。R17随后关闭全部13个同根status-capture blocks并增加Bash 3.2 micro-probes，
但Review17以RanchArt结构门位于授权消费后判定
`CHANGES REQUIRED — 0 P0 / 1 P1`；R17没有执行，12个runtime paths与fresh roots均
absent。牧场主已授权R18把同一phase-aware verifier的零写入preflight移到消费
前最后门；消费后、创建其他runtime artifacts/roots前立即重新读取并把结构证据写入
hash log，随后才由独立119-entry static manifest逐文件重校RanchArt bytes。随后
R18-A又把R15 historical empty/current `ABSENT`分层，冻结两个absorbing tombstones，
以联合parent enumeration fail closed并一对一替换一个C职责，保持inherited
13/driver-total 14计数。Review18随后在immutable R18 chain上判定
`CHANGES REQUIRED — 0 P0 / 1 P1`；唯一P1-01是newline-delimited RanchArt pathname
serialization不能无歧义表示macOS合法的含换行pathname。R18从未执行。牧场主随后
授权R19只关闭该同一根因：single `find -P -print0`直接进入Bash 3.2
`read -r -d ''` NUL pipeline，无line serialization或command substitution；逐项证明
exact 27 allowed paths均regular non-symlink且无额外node，capture inventory冻结为
core `3P/3S/3C=9`、driver total `3P/3S/4C=10`，并使用fresh R19 paths与123-entry
manifest。Review19随后以`APPROVED — 0 P0 / 0 P1`批准，牧场主按顺序给出四-hash
授权。R19 invocation `r19-daef1dab-0fbe-4a03-bab1-422adc18b3d4`的BEGIN、pre/post
manifest与41/41 targeted通过，但唯一未过滤authoritative `swift run RunTests`为
651/652；唯一`slowActiveStreamDoesNotIdleTimeout`在`AgentLoopTests.swift:611`以
`idle script exhausted`失败。R19永久`REJECTED_CONTAMINATED`，未运行
build/release/matrix/source/bundle/preview/END且zero product/test drift；11项实际
artifacts、缺失screenshot与两个exact real non-symlink empty roots immutable。

R20随后取得Review20与四-hash授权，唯一full RunTests 652/652、46/46与LAUNCH_READY
通过，但`--product AgentLoopCore`在automatic product上退化default target graph，
release TestSuite caller/callee配置错配使invocation永久`REJECTED_CONTAMINATED`。
R21随后取得exact四hash授权；caller四锚与155/155均通过，但driver在
`pre_begin_r19_containment` exit70，boundary未写、authority未消费、runtime与fresh roots
零创建。R22虽已冻结，但Review22以`CHANGES REQUIRED — 0 P0 / 1 P1`证明R20 exact bundle
已侵蚀成parent/App+六目录/零file的partial skeleton；R22未执行、未消费且zero runtime write。
R23随后完成BEGIN与guard，但full-test status capture因zsh/Bash carrier错配永久rejected。
R24只关闭该同一根因；Review24已批准，执行也完成full 652/652、same-log 46/46与fresh signed
bundle，但随后因guard numeric rendering false negative永久rejected，十个runtime files
immutable且无END。R25已冻结关闭该render-only根因并保留standing Goal的no-hash-echo；其
driver、exact 192-entry manifest与freeze均已存在，Review25在该历史snapshot中尚未创建；其后已批准且R25执行永久rejected。Review25通过前全部执行、任何产品/test/App-script
修改、Review02/acceptance与A3均关闭；一次Codex invocation不得跨slice，不得commit。

## 3. 当前状态与下一入口

**Current override (2026-08-26, P1-E entry):** P1-D is accepted under the exact
plan, two bounded revisions, Review02, acceptance, and 900-test evidence
identified in §2. The only current next unit is decision-complete P1-E formal
planning plus its disclosed no-Claude self-review. P1-E implementation remains
closed. The prior P1-D/P1-C/P1-B paragraphs immediately below and all lower
R12–R28 text are immutable process history, not the current execution gate.

**Current override (2026-08-25, P1-D entry):** P1-C is accepted under the exact
Revision 8 plan, Review02, acceptance, and 816-test evidence identified in §2.
The only current next unit is decision-complete P1-D formal planning plus its
disclosed no-Claude self-review. P1-D implementation remains closed. The prior
P1-C/P1-B paragraphs immediately below and all lower R12–R28 text are immutable
process history, not the current execution gate.

**Current override (2026-08-25):** P1-B Revision17 is accepted under Review21,
Review22, Acceptance23, and authoritative `verify.log` SHA-256
`6eb521225e14d3de84595c0cd9bb2318ac3acbb072a3806f5543478fbabf2a87`.
The only current next unit is decision-complete P1-C planning plus its
responsibility-isolated plan review. P1-C implementation remains closed. The
2026-08-11 paragraph immediately below and all lower R12–R28 text are
immutable process history, not the current execution gate.

**Current override (2026-08-11):** A2, A3, and A4 are accepted. The current
planning slice is `P1-B — Error Visibility and Application-Layer Seams`; only
bounded Level-3 plan/inventory/control-document work and read-only inspection
are open until its independent plan review passes.
The detailed A1b/A2 material below is retained as historical evidence and is not
the current execution gate.

| 项 | 值 |
|---|---|
| 已完成 slice | `P1-A1b — Durable Planning Supervisor + Integration` |
| A1b 状态 | `Accepted`；R-01 `Closed` |
| 入口证据 | `p1-a1a-durable-work-store/acceptance.md`：`ACCEPTED` |
| A1b 规范源 | 冻结 Stage §6.2.2/§6.3、总 Plan §3.2/§10/§11 与 A1b leaf |
| 产品实施与验证 | 已完成；最终 evidence 已经职责隔离 Review 与独立 acceptance |
| 冻结证据 | `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/evidence/r11-freeze-validation.md`；SHA-256 `8f58e33035f70538dd5f692e979eabb68e4b8b22df07656e95154d428b759852` |
| Plan Review | `docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/11-p1-plan-review.md`：`APPROVED — 0 P0 / 0 P1`；SHA-256 `f03000a92c3b8324a3ca824834cc7724b028c18bbe48061ea4fb72512b81d671` |
| 最终 implementation Review | `p1-a1b-durable-planning/reviews/01-p1-a1b-review.md`：`APPROVED — 0 P0 / 0 P1`；SHA-256 `8c96b742285da1c1999c5360071728cbdf287cfeffeb6b25e281485336e0b1a0`；保留首轮 `0 P0 / 2 P1` 历史 |
| 独立 acceptance | `p1-a1b-durable-planning/acceptance.md`：`ACCEPTED`，22/22 PASS；SHA-256 `efe4d20a7cb4dc3f61d028637a6705d3ed56d4fdd5596ebc3cb993d94481bf1e` |
| A2 blocker/授权 | `p1-a2-durable-rumination/blocked.md`：R13 incident/Review01、R14–R20 rejections、R21/R22 zero-write、R23 rejection、R24 approved-then-rejected execution及R25 bounded planning authorization |
| A2 leaf | `p1-a2-durable-rumination/plan.md`；R25 immutable executed-plan bytes，current identity由现有freeze单向绑定 |
| A2 freeze evidence | R24 `p1-a2-durable-rumination/evidence/plan-freeze-r24.md` immutable；R25 immutable freeze已存在并单向绑定六面/driver/manifest；R12–R23 freezes/Reviews/results immutable |
| Review12 predecessor | `reviews/12-p1-plan-review.md`：`CHANGES REQUIRED — 0 P0 / 2 P1`；SHA-256 `f27379bfc96a224715e7c6a59ad62fa79d8d97c4d73cf41e890a6ce16957a7c3` |
| Review12A predecessor | `reviews/12a-p1-plan-review.md`：`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`；SHA-256 `a102c49138fcfc1f40b0c780990d8c3ad5ec2302b175b043bde9457164331337` |
| Review12B predecessor | `reviews/12b-p1-plan-review.md`：`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`；SHA-256 `66b81e9e5ea0f74e08706c7367f2e80180601a000c9e84c1bbd4357a9c3b4ec5` |
| 红测证据 | `p1-a2-durable-rumination/red-tests.log`；Build complete；5/5 exact discovery；5/5 expected capability failures；SHA-256 `97b965160adb1b317c76d5227312ceb6c185642cccff0482c40ab281d84e0f15` |
| Review13 predecessor | `reviews/13-p1-plan-review.md`：`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`；SHA-256 `5203057f2a4a7f04827d9f5e0f20b717e08a31125404483b11f5cad722bda66b` |
| Review13A predecessor | `reviews/13a-p1-plan-review.md`：`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`；SHA-256 `edfb632ce1af2514dfe3168f87e0506fffe3a116f9cd6d3a427874933d399580` |
| Review13B predecessor | `reviews/13b-p1-plan-review.md`：`APPROVED — 0 P0 / 0 P1`；SHA-256 `b798cffd016865b9441f6c8978da96d7382feb3e5dd51c7555e635bfbca84444` |
| A2 Review01 predecessor | `p1-a2-durable-rumination/reviews/01-p1-a2-review.md`：`CHANGES REQUIRED — 0 P0 / 1 P1`；SHA-256 `5b6a171515404a644abcd05e3afc3840cb1dd4d84d7993f74af48de0692b4dd5` |
| Review14 predecessor | `reviews/14-p1-plan-review.md`：`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`；SHA-256 `5bc0adf787dabd1451c53c7fc13df817325b323b030478443f62030bbf28e405` |
| Review15 predecessor | `reviews/15-p1-plan-review.md`：`APPROVED — 0 P0 / 0 P1`；SHA-256 `fbaa9612588c39cb5d99e95d9b68e00a234510e325abf5823c15f0b1eb8ecc05` |
| R15 rejected evidence | `p1-a2-durable-rumination/impl-report-r15.md`：`REJECTED_CONTAMINATED — BEGIN attestation false negative`；SHA-256 `e6b0226b3440da997f7e08571d8e5e5229d66069ea5ad6485ee146c249dbe72e` |
| Review16 predecessor | `reviews/16-p1-plan-review.md`：`APPROVED — 0 P0 / 0 P1`；SHA-256 `71f16eceef429f7d02fe8908c4609b9bd0b0b98b44c68b579a75ced2ac9d9824` |
| R16 pre-BEGIN result | 四anchors与110/110 manifest通过；首个`pgrep`正常`rc=1`被全局`ERR` trap截获；`r16-clean-boundary.log`、12个runtime paths与fresh roots均absent，authorization not consumed，后续gates未运行 |
| Review17 predecessor | `reviews/17-p1-plan-review.md`：`CHANGES REQUIRED — 0 P0 / 1 P1`；SHA-256 `c6838d3c5a9fcfef80dc9db4abf560af712e3175372a163edccb72197daf3dbe` |
| R17 not-executed result | 没有Review approval或四-hash执行授权；12个runtime paths与R17 state/bundle roots均absent，未运行任何执行门 |
| R18 immutable chain | freeze `62bbf93031371659e7ad2d4c60aac002eb13ed0915854f741e40251c9c2c1e76`；driver `911bbbc70556e41122cfdcc90048e504eee3480246b338131153856d524d7af9`；119-entry manifest `71e512a25e6e9bc0d024a53ad2502b55a378a82b39044a341930e1df440cfc2a`；均immutable且R18未执行 |
| Review18 predecessor | `reviews/18-p1-plan-review.md`：`CHANGES REQUIRED — 0 P0 / 1 P1`；SHA-256 `e0ee95f3703d73810d756410373c1da65fb1e08b08f6d7f74555e8095a12608b` |
| Review19 predecessor | `reviews/19-p1-plan-review.md`：`APPROVED — 0 P0 / 0 P1`；SHA-256 `4588cd645edd47c7648f9c8e372fb4de42f2b8dd3a2bfeb31282aba2d6e7c41c` |
| R19 execution result | BEGIN与41/41 targeted通过；authoritative full suite 651/652，唯一`slowActiveStreamDoesNotIdleTimeout`/`idle script exhausted`；永久`REJECTED_CONTAMINATED`，后续门未运行，zero product/test drift；11 repository artifacts、缺失screenshot与historical canonical-empty observations immutable，两个volatile roots current为`ABSENT_TOMBSTONE`/`UNKNOWN` |
| Review20 predecessor | `reviews/20-p1-plan-review.md`：`APPROVED — 0 P0 / 0 P1`；SHA-256 `e70ea918e00c334a452f87e4fa8f44d5bfc754b042872a9f0a0ec13015e7c68e` |
| R20 execution result | invocation `r20-98452cde-0ff4-4b66-b3f6-8085eb045a6f`；full 652/652、46/46、debug/LAUNCH_READY通过；release Core automatic-product fallback后失败，永久`REJECTED_CONTAMINATED`；后续门未运行；11 repository artifacts、缺失screenshot与historical signed-App hashes immutable，volatile state root current为`ABSENT`，bundle parent/App只按Review22的8/38 partial snapshot处理 |
| R21 immutable result | freeze/Review/driver/manifest四锚与155/155通过；pre-BEGIN exit70于R19 containment，authority未消费、zero write，R21 paths/roots absent |
| R22 immutable plan result | Review22 `CHANGES REQUIRED — 0 P0 / 1 P1`；exact R20 bundle为parent/App+六目录/零file partial skeleton；R22无caller/BEGIN，未消费且zero runtime write |
| R23 execution result | BEGIN+guards完成；terminal 652/652但PIPESTATUS unknown，permanent rejected；十logs/report与two empty roots immutable |
| R24 immutable closure | freeze/Review24/driver/178-entry manifest与十个runtime files immutable；Review24 `APPROVED — 0 P0 / 0 P1`；执行在full 652/652、46/46与fresh signed bundle后因guard shape `1:1::0:1:1`永久rejected，无END |
| R25 historical plan snapshot | 只做numeric render-only closure，product/test/App/permanent-script delta 0；`r25-begin.sh`、exact 192-entry manifest与freeze均已存在且candidate Frozen；Review25在该历史snapshot中尚未创建；其后已批准且R25执行永久rejected |
| 下一门 | 仅职责隔离Review25写`reviews/25-p1-plan-review.md`；批准且Goal未撤销后automatic caller仅传Review25 SHA，无hash echo |
| 本次 A2 边界 | R25只关闭R24 harness numeric-rendering false negative；Review25前全部执行与产品/test/App scripts关闭；Review02依赖R25 exact END |

R25 historical contract以canonical Stage §28.12、total Plan R25 final section、leaf §16、blocked §34
及两个索引的相同R25正文为准。它继承的R24 filesystem observation不提供transaction、lock或
atomic snapshot，也不证明inode/hardlink/xattr/resource fork不变，不能消除capture窗口外
TOCTOU；变量commit不等于filesystem atomicity。

## 4. 任务产物与职责

| 产物 | 唯一 owner | 当前状态 |
|---|---|---|
| P1 总 `plan.md` | planner | R25 historical candidate snapshot；exact 192-entry manifest/freeze与Review25现均immutable，execution rejected |
| A2 leaf `plan.md` | planner | R25 historical candidate snapshot；exact 192-entry manifest/freeze与Review25现均immutable，execution rejected |
| A2 `evidence/plan-freeze-r12f.md` | planner | R12-F candidate manifest；不替代 Review12C |
| A2 `evidence/plan-freeze-r13.md` | planner | R13 candidate manifest；不替代职责隔离 Review13 |
| A2 `evidence/plan-freeze-r13a.md` | planner | R13A current-gate manifest；不替代职责隔离 Review13A |
| A2 `evidence/plan-freeze-r13b.md` | planner | R13B control-only manifest；不替代职责隔离 Review13B |
| A2 `evidence/plan-freeze-r14.md` | planner | immutable R14 predecessor；SHA-256 `66436eeeedba03e3e0a4411e208c3dd7993f5c2968952c7bff64446232ca011d` |
| `reviews/14-p1-plan-review.md` | 职责隔离 independent plan reviewer | immutable `CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2` predecessor |
| A2 `evidence/plan-freeze-r15.md` | planner | immutable R15 predecessor；SHA-256 `e5ad3967f2e2b26a2bbf8b2ef7be405e8430cc30a82d51a7cb5f51926a99e3d7` |
| `reviews/15-p1-plan-review.md` | 职责隔离 independent plan reviewer | immutable `APPROVED — 0 P0 / 0 P1` plan predecessor |
| A2 `evidence/r16-begin.sh` | planner | immutable flawed predecessor；SHA-256 `ffa61fa7c8c281cdb8dfb853b38aafce9536ddcc276e18d64c082de8887b55b0`；不得修改或重跑 |
| A2 `evidence/r16-entry.sha256` | planner | immutable 110-entry predecessor；SHA-256 `0c2f5dc59e5f0e193214d1c8532a91818a339abdfb3150177c680fe61f8a0b1e` |
| A2 `evidence/plan-freeze-r16.md` | planner | immutable R16 freeze；SHA-256 `c10ae51ad78b414aab18c3785b79aac49feb73c47ac5fdcb896ca874ae319867` |
| `reviews/16-p1-plan-review.md` | 职责隔离 independent plan reviewer | immutable `APPROVED — 0 P0 / 0 P1` predecessor；SHA-256 `71f16eceef429f7d02fe8908c4609b9bd0b0b98b44c68b579a75ced2ac9d9824` |
| A2 `evidence/r17-begin.sh` | planner | immutable R17 driver；SHA-256 `cf1baab60b3e799b1780b20d1dfc7887bdd2c7e85e241fdb8abcd4ad8c04321f`；不得运行或修改 |
| A2 `evidence/r17-bash32-probes.sh` | planner | immutable zero-repository-write Bash 3.2 probes；由R18–R21 static manifests传递绑定 |
| A2 `evidence/r17-entry.sha256` | planner | immutable 115-entry manifest；SHA-256 `7d10c5c6747cdf0e557befc76a62ea101f2fc4168a49d8076bedd3331d8cbd17` |
| A2 `evidence/plan-freeze-r17.md` | planner | immutable R17 freeze；SHA-256 `bdbbbd025bbe7cf57032ae2276a6a559043f60e47cebad1ceac43f992e644e1f` |
| `reviews/17-p1-plan-review.md` | 职责隔离 independent plan reviewer | immutable `CHANGES REQUIRED — 0 P0 / 1 P1` predecessor；SHA-256 `c6838d3c5a9fcfef80dc9db4abf560af712e3175372a163edccb72197daf3dbe` |
| A2 `evidence/r18-begin.sh` | planner | immutable not-executed R18 driver；SHA-256 `911bbbc70556e41122cfdcc90048e504eee3480246b338131153856d524d7af9`；不得运行或修改 |
| A2 `evidence/r18-entry.sha256` | planner | immutable 119-entry manifest；SHA-256 `71e512a25e6e9bc0d024a53ad2502b55a378a82b39044a341930e1df440cfc2a` |
| A2 `evidence/plan-freeze-r18.md` | planner | immutable R18/R18-A freeze；SHA-256 `62bbf93031371659e7ad2d4c60aac002eb13ed0915854f741e40251c9c2c1e76` |
| `reviews/18-p1-plan-review.md` | 职责隔离 independent plan reviewer | immutable `CHANGES REQUIRED — 0 P0 / 1 P1` predecessor；SHA-256 `e0ee95f3703d73810d756410373c1da65fb1e08b08f6d7f74555e8095a12608b` |
| A2 `evidence/r19-begin.sh` | planner | immutable executed R19 driver；SHA-256 `95a29f4452502a236bd73ac42a9741bf31e66fa6108bcdf4572b5fcc1eef190d`；不得修改或重跑 |
| A2 `evidence/r19-entry.sha256` | planner | immutable 123-entry manifest；SHA-256 `71dede4ad9a86c52e853d36af8629a491e84854badfaf0962054f06e86fcfb43` |
| A2 `evidence/plan-freeze-r19.md` | planner | immutable R19 freeze；SHA-256 `d7869b0531f5dc868a1e8d92b2aec9f0abf3cd84e0d3857b481f8fcc3807d03f` |
| `reviews/19-p1-plan-review.md` | 职责隔离 independent plan reviewer | immutable `APPROVED — 0 P0 / 0 P1` predecessor；SHA-256 `4588cd645edd47c7648f9c8e372fb4de42f2b8dd3a2bfeb31282aba2d6e7c41c` |
| A2 `evidence/r20-begin.sh` | planner | immutable executed R20 driver；SHA-256 `840edee2dad7710f17e1b9bb8dcaa1484224ba0784b636f472bc2934f7e7eaeb`；不得修改或重跑 |
| A2 `evidence/r20-entry.sha256` | planner | immutable 140-entry static manifest；SHA-256 `2f8a6f4f786a2b5f432b2dbf7dcdc7208788d0b9ef5b9cdaa9de422bfaf88e81` |
| A2 `evidence/plan-freeze-r20.md` | planner | immutable R20 freeze；SHA-256 `0b698b59f214f23c26db88fd53763c4a600becaf898a716344f9d666ac2e8e07` |
| `reviews/20-p1-plan-review.md` | 职责隔离 independent plan reviewer | immutable `APPROVED — 0 P0 / 0 P1` predecessor；SHA-256 `e70ea918e00c334a452f87e4fa8f44d5bfc754b042872a9f0a0ec13015e7c68e` |
| A2 `evidence/r21-begin.sh` | planner | immutable pre-BEGIN-stopped driver；SHA-256 `c56db7b465ae3d54923d958892e07e5575d4cf67b8b4946c7d6793e4f1bfb835`；不得修改或重跑 |
| A2 `evidence/r21-entry.sha256` | planner | immutable 155-entry manifest；SHA-256 `d5567a05e61e61a94b732814e24a89ecdb8e2a988d970dac33939f31798a9d86` |
| A2 `evidence/plan-freeze-r21.md` | planner | immutable R21 freeze；SHA-256 `82ec117359bb0172867ed476c0da4a8d7d0fc60c5bd24f25c0f42e360f7996a4` |
| `reviews/21-p1-plan-review.md` | 职责隔离 independent plan reviewer | immutable approved predecessor；SHA-256 `13f75ac2979a25c8cf643e83f264663087c6bc18836696c518b247d7f6d3176b` |
| A2 `evidence/r22-begin.sh` | planner | immutable unexecuted predecessor；不得运行或修改 |
| A2 `evidence/r22-entry.sha256` | planner | immutable 159-entry predecessor |
| A2 `evidence/plan-freeze-r22.md` | planner | immutable R22 freeze |
| `reviews/22-p1-plan-review.md` | 职责隔离 independent plan reviewer | immutable `CHANGES REQUIRED — 0 P0 / 1 P1`；SHA-256 `bf007443ac2b1932fbde93cf908a99b50cb4878de3e485118092bb24552050b5` |
| A2 `evidence/r23-begin.sh` | planner | immutable executed R23 driver；不得修改或重跑 |
| A2 `evidence/r23-entry.sha256` | planner | immutable 163-entry manifest |
| A2 `evidence/plan-freeze-r23.md` | planner | immutable R23 freeze |
| `reviews/23-p1-plan-review.md` | 职责隔离 independent plan reviewer | immutable approved predecessor |
| A2 `evidence/r24-begin.sh` | planner | immutable executed R24 driver；SHA-256 `1b224f442d1fdea856433d12141e5ea9f74190a380e554e4ec94872ba0b8655f`；不得修改或重跑 |
| A2 `evidence/r24-entry.sha256` | planner | immutable exact 178-entry manifest；SHA-256 `55a6c2e8a657166de8b983cd0edfb2a7b1ae1943dc291819c0c2ea417338a80c` |
| A2 `evidence/plan-freeze-r24.md` | planner | immutable R24 freeze；SHA-256 `f22a7ffd954ddf6d9b2d804a5f3be58807373c388634b9200d260f1a8eb66746` |
| `reviews/24-p1-plan-review.md` | 职责隔离 independent plan reviewer | immutable `APPROVED — 0 P0 / 0 P1` predecessor；SHA-256 `a9ef2cab24afa65290f563b85ac03022b958d39253c025017d1c91b689926c0e` |
| A2 `evidence/r25-begin.sh` | planner | Frozen driver；SHA-256 `1eee61d199c5bb1c5b0149989f17508e9a75eacfbc2bac3b1a2f0063f0ab68bb`；Review25前禁止运行 |
| A2 `evidence/r25-entry.sha256` | planner | exact 192-entry current static manifest已存在并验证`192/192` |
| A2 `evidence/plan-freeze-r25.md` | planner | R25 immutable freeze已存在并单向绑定current六面/driver/manifest |
| `reviews/25-p1-plan-review.md` | 职责隔离 independent plan reviewer | 尚不存在且Pending；下一门唯一reviewer write，reviewer不得写六面/driver/manifest/freeze |
| `p1-a2-durable-rumination/reviews/01-p1-a2-review.md` | 职责隔离 implementation reviewer | immutable `CHANGES REQUIRED — 0 P0 / 1 P1` predecessor |
| A2 `*-r15` logs/evidence + `impl-report-r15.md` | implementer | immutable rejected evidence；不得覆盖、追加、补齐、重命名或复用 |
| A2 `*-r16` logs/evidence + `impl-report-r16.md` | implementer | 全部absent；R16授权未消费的immutable negative fact，不得补写、改名或复用 |
| A2 `*-r17` logs/evidence + `impl-report-r17.md` | implementer | 全部absent；R17未执行的immutable negative fact，不得补写、改名或复用 |
| A2 `*-r18` logs/evidence + `impl-report-r18.md` | implementer | 全部absent；R18未执行的immutable negative fact，不得补写、改名或复用 |
| A2 `*-r19` logs/evidence + `impl-report-r19.md` | implementer | 11项实际artifact immutable；`evidence/r19-preview-smoke.png` absent；不得覆盖、追加、补齐、重命名、读取为runtime input或复用 |
| A2 `*-r20` logs/evidence + `impl-report-r20.md` | implementer | 11项实际artifact immutable、screenshot absent；永久release failure evidence，不得覆盖、追加、清理、重命名或复用 |
| A2 `*-r21` logs/evidence + `impl-report-r21.md` | implementer | 全部absent；R21 pre-BEGIN zero-write/未消费的immutable negative fact，不得补写或复用 |
| A2 `*-r22` logs/evidence + `impl-report-r22.md` | implementer | 全部absent；R22 changes-required/未执行的immutable negative fact，不得补写或复用 |
| A2 `*-r23` logs/evidence + `impl-report-r23.md` | implementer | 十logs+report immutable rejected evidence，screenshot absent；不得补写/清理/复用 |
| A2 `*-r24` logs/evidence + `impl-report-r24.md` | implementer | 十个实际runtime files immutable；`impl-report-r24.md`与`evidence/r24-preview-smoke.png` absent；永久rejected evidence不得补写、清理或复用 |
| A2 fresh `*-r25` runtime/evidence + `impl-report-r25.md` | implementer | 12个fresh runtime paths、两个fresh roots与全部invocation-owned hidden stages均不存在；Review25批准并由automatic caller进入BEGIN前禁止创建 |
| `p1-a2-durable-rumination/reviews/02-p1-a2-review.md` | 新职责隔离 implementation reviewer | R25 exact END及全部clean evidence完成前禁止创建 |
| `p1-a2-durable-rumination/acceptance.md` | 独立 acceptance owner | Review02零P0/P1前禁止创建 |
| `reviews/13-p1-plan-review.md` | 职责隔离 independent reviewer | immutable `CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2` predecessor |
| `reviews/13a-p1-plan-review.md` | 职责隔离 independent reviewer | immutable `CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2` predecessor |
| `reviews/12-p1-plan-review.md` | 职责隔离 independent reviewer | immutable `CHANGES REQUIRED — 0 P0 / 2 P1` predecessor |
| `reviews/12a-p1-plan-review.md` | 职责隔离 independent reviewer | immutable `CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2` predecessor |
| `reviews/12b-p1-plan-review.md` | 职责隔离 independent reviewer | immutable `CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2` predecessor |
| `reviews/12c-p1-plan-review.md` | 职责隔离 independent reviewer | `APPROVED — 0 P0 / 0 P1`；SHA-256 `db94c2cd473cd311c79aa61b8a32b634409b9485b5b5fcef775b71ecf1f2a109` |
| `verify.log` | implementer | A1b 最终验证证据已完成并被独立核对 |
| `build.log` | implementer | A1b 最终 build/release gate 证据已完成并被独立核对 |
| `impl-report.md` | implementer | A1b 最终实现报告已完成并被独立核对 |
| `reviews/01-p1-a1a-review.md` | 职责隔离独立 reviewer | `APPROVED — 0 P0 / 0 P1` |
| `p1-a1a-durable-work-store/acceptance.md` | A1a acceptance owner | `ACCEPTED`；SHA-256 `070a2b6815ef85323d1041d3023ebc28ec5f98737513746ec9bdf961183a0032` |
| `p1-a1b-durable-planning/reviews/01-p1-a1b-review.md` | A1b 职责隔离独立 reviewer | `APPROVED — 0 P0 / 0 P1`；SHA-256 `8c96b742285da1c1999c5360071728cbdf287cfeffeb6b25e281485336e0b1a0` |
| `p1-a1b-durable-planning/acceptance.md` | A1b acceptance owner | `ACCEPTED`，22/22 PASS；SHA-256 `efe4d20a7cb4dc3f61d028637a6705d3ed56d4fdd5596ebc3cb993d94481bf1e` |
| `preview-smoke.png` | implementer evidence | A1b 隔离 preview 已完成并被 Review/acceptance 核对 |

planner 不写实现日志、Review 或 acceptance；implementer 不代写 Review 或
acceptance；reviewer 不回写实现和验证日志。

## 5. 执行控制

R10 Candidate 2、R11 与 A1b closeout 的当前控制事实为：

1. 首轮七项冻结契约与不可变 Review10 历史已保存；
2. Review10 的两个同根 P1 已在授权范围内修订；
3. Stage/Plan/leaf Candidate 2 hashes、产品/test 指纹与双路预冻结
   `0 P0 / 0 P1` 已保存；
4. Review10A 已由未参与修订的 reviewer 判定 `APPROVED — 0 P0 / 0 P1`；
5. 四个 implementation-discovered R11 根因已获授权并冻结为§1 hashes；
6. 两路预冻结 cross-audit为0 P0/P1，但不替代职责隔离 Review11；
7. Review11 已在 §1 exact hashes 上判定 `APPROVED — 0 P0 / 0 P1`，报告 SHA-256
   为 `f03000a92c3b8324a3ca824834cc7724b028c18bbe48061ea4fb72512b81d671`；
8. 初始 Review01 的 `CHANGES REQUIRED — 0 P0 / 2 P1` 作为历史保留；有界根因修复
   后，同一报告最终判定 `APPROVED — 0 P0 / 0 P1`，最终 SHA-256 为
   `8c96b742285da1c1999c5360071728cbdf287cfeffeb6b25e281485336e0b1a0`；
9. 独立 acceptance 以 22/22 PASS 判定 `ACCEPTED`，SHA-256 为
   `efe4d20a7cb4dc3f61d028637a6705d3ed56d4fdd5596ebc3cb993d94481bf1e`；
10. A1b `Accepted` 关闭 R-01。
11. R12/R12-A 原 candidate 与 immutable Review12 `0 P0 / 2 P1` 历史已保存。
12. R12-B freeze 与随后无报告的 phase pre-audit历史已保存。
13. R12-C 已把 Stage、总 Plan与 A2 leaf重新冻结为§1 hashes；matrix script仍只
    同步 frozen Stage hash，恢复最初 value 可恢复最初 script hash。
14. Review12A 已在 R12-C candidate判定
    `CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`，immutable历史已保存。
15. R12-D 已只关闭identity-bound phase invalidation根因并把Stage、总Plan、leaf
    重新冻结为§1 hashes；#31、41 names、13+2 allowlist不变。
16. Review12B 已判定`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`；immutable历史已保存。
17. R12-E已只关闭durable projection final refresh根因并重新冻结；一个callback、
    两个KernelEvent cases、#31、41 names、13+2 allowlist与schema/EventKind不变。
18. R12-F已关闭start commit refresh/claim-barrier、两种replay origin归一与首次
    独立预检freshness finding并重新冻结；new insert exact `version=1`，两个lock
    文件byte-identical且single-writer lock-before-open为entry/red line；上述
    callback/case/name/allowlist/schema边界不变。
19. Review12C 已在 §1 exact hashes 上判定`APPROVED — 0 P0 / 0 P1`；首批五个
    failure-first 测试随后以 Build complete、5/5 exact discovery、5/5 expected
    capability failures通过红测门；后续绿色日志仅为pre-R13 evidence。
20. Review13在R13 exact hashes上判定`CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2`；
    唯一P1-01是current entry/reviewer writer/implementation opening分裂。
21. R13A只同步canonical current gates；Review13A仍发现control surfaces旧开门态。
22. R13B只历史化blocker与两个control index的旧开门文字；Review13B最终
    `APPROVED — 0 P0 / 0 P1`并打开R13 implementation。
23. R13技术门完成，但normal-root incident使Review01给出
    `CHANGES REQUIRED — 0 P0 / 1 P1`；历史artifact与mutation unknown保持immutable。
24. R14只在plan层定义一次新的clean re-verification；Review14以source/build→
    bundle→executable provenance不闭合判定一个P1，R14没有打开执行。
25. R15冻结BEGIN→POST_BUILD→PRE_SIGN→LAUNCH_READY、fresh bundle、
    same-bundle direct exec与matrix restoration；Review15批准plan，但BEGIN false
    negative后永久拒绝，所有R15 repository失败证据保持immutable。两个volatile
    roots只在containment时被观察为空，2026-08-02 current复核为`ABSENT`、原因
    `UNKNOWN`，不得声称连续保全。
26. Review16已批准R16 plan；R16 external caller与driver pre-BEGIN四anchors及
    110/110 manifest通过，但首个`pgrep`正常`rc=1`被全局`ERR` trap截获。唯一授权
    消费点未到达，12个runtime paths与fresh roots均absent，所有后续gate未运行。
27. R17关闭13个status-capture blocks的统一根因并增加
    `r17-bash32-probes.sh`；Review17仍以RanchArt结构门位于消费后判定
    `CHANGES REQUIRED — 0 P0 / 1 P1`。R17未执行，12个runtime paths与roots absent。
28. R18关闭Review17 P1-01：单一phase-aware verifier与单一expected 27 set；
    pre-consumption调用是exclusive-create/授权消费前最后门，零repository write、失败
    只console；消费后、创建其他runtime artifacts/roots前立即post-activation重读并把
    结构证据写入hash log，不复用boolean/snapshot；随后才独立重跑119-entry bytes门。
    pre-consumption失败保持零写入/授权未消费；只有boundary消费后的重读或bytes门失败
    才永久`REJECTED_CONTAMINATED`。双读取只收窄TOCTOU，不宣称原子FS lock。
29. R18-A把两个current `ABSENT` exact R15 paths冻结为absorbing tombstones；联合
    `/private/tmp` exact-basename parent enumeration、任何node重现或indeterminate均
    fail closed。preserved-root `realpath` C被一对一替换，inherited仍为
    `2P/4S/7C=13`，另计root-glob C后driver total为`2P/4S/8C=14`；immutable
    `r17-bash32-probes.sh`继续复用。119-entry manifest精确为R17 115项加R18 driver、R17
    manifest、R17 freeze与Review17，排除自身/R18 freeze/Review18/runtime。
30. Review18在immutable R18 chain上判定
    `CHANGES REQUIRED — 0 P0 / 1 P1`；SHA-256为
    `e0ee95f3703d73810d756410373c1da65fb1e08b08f6d7f74555e8095a12608b`。唯一P1-01是
    newline-delimited RanchArt pathname serialization不能无歧义表示含换行的合法
    macOS pathname。R18未取得批准或执行授权，12个runtime paths与fresh roots均absent。
31. R19只关闭Review18 P1-01：single `find -P -print0`直接进入Bash 3.2
    `read -r -d ''` NUL pipeline，不经line serialization或command substitution；完整
    消费NUL stream并逐项以pathname bytes证明exact 27 allowed paths均regular
    non-symlink且无额外node，任何find/read/incomplete-record/type/set异常均fail closed。
    capture inventory为core `3P/3S/3C=9`、计入既有root-glob C后的driver total
    `3P/3S/4C=10`。123-entry manifest精确继承R18 119项并增加R19 driver、R18 manifest、
    R18 freeze与Review18；R19使用fresh driver、12个runtime artifact names及
    `/private/tmp/agentloop-r19-state.*`、`/private/tmp/agentloop-r19-bundle.*` roots。
32. Review19以`APPROVED — 0 P0 / 0 P1`批准R19 plan，后续四-hash授权也已取得。
    R19 BEGIN、pre/post manifest与41/41 targeted通过，但唯一authoritative unfiltered
    full suite为651/652；唯一`slowActiveStreamDoesNotIdleTimeout`失败于
    `idle script exhausted`。R19永久`REJECTED_CONTAMINATED`，后续门未运行且zero
    product/test drift；11项实际artifacts、缺失screenshot与两个exact real non-symlink
    empty roots immutable。
33. R20只在Review20与后续四-hash授权后打开`AgentLoop.swift`与
    `AgentLoopTests.swift`两文件exception。private factory与单一generic
    `IdleWatchdog<C: Clock>`复用production算法；debug-only package initializer external
    label精确为`idleClockForTesting`，`ManualAgentLoopClock`只在test source。五项exact
    tests与既有41项从同一次未过滤、失败不重跑的authoritative full-suite日志机械审计；
    46/46不能替代full green。R20实际full green，但automatic-product release gate
    失败后永久rejected；该结果不能accept。
34. R21仅允许未来在`AgentLoopTests.swift`添加三对matching direct DEBUG guards；
    `AgentLoop.swift`保持R20 final bytes。release Core/TestSuite必须分别执行target-exact
    build；以canonical `--show-bin-path`构造四个exact object paths并证明Core/TestSuite
    release tokens全0、debug对应tokens全>0。Test source移除六行directive后必须恢复
    R20 final hash；155-entry manifest edit前155/155，edit后154+1且唯一test mismatch。
35. R22为immutable changes-required predecessor：Review22发现R20 bundle为present partial
    skeleton；R22没有approval/caller/BEGIN且zero-write/未消费，不得执行或重跑。
36. R23已执行并永久rejected：guard落地、terminal 652/652，但zsh wrapper未捕获Bash
    PIPESTATUS；十logs/report与two empty roots immutable，后续门未运行。
37. R24是immutable executed predecessor：freeze/Review24/driver/178-entry manifest与十个
    runtime files固定；Review24已批准，full 652/652、same-log 46/46与fresh signed bundle通过，
    但guard numeric rendering false negative使invocation永久rejected且无END。
38. R25 historical numeric-rendering gate已冻结、通过Review25并执行；full 652/652及pre-preview
    partial greens完成，但child ERR trap double containment导致preview永久rejected且无END。
39. R26 current gate只关闭该ERR-subshell根因；six surfaces/fresh driver/exact 206-entry
    manifest/freeze frozen，Review26 absent/pending。§5.3是唯一current override，
    Review26零P0/P1前全部执行门关闭。
任何新增架构、范围、
测试门或语义缺口都必须走
正式修订与职责隔离流程，不得靠本索引扩大冻结权限。

### 5.1 R24 final single-process clean-execution contract

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

### 5.2 R25 numeric-rendering root-cause closure

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


### 5.3 R26 ERR-subshell root-cause closure

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

## 6. 跨门红线

- A1a 与 A1b 均已 Accepted；A1b 只关闭 R-01 durable planning 根因，不关闭任何
  R-02 及后续风险项。
- A2 R15 boundary永久`REJECTED_CONTAMINATED`且全部repository证据immutable；R15
  roots historical empty/current ABSENT分层并作为absorbing tombstones；R16只在
  pre-BEGIN停止且授权未消费；R17因Review17 changes-required从未执行；R18因
  Review18 changes-required从未执行；R16–R18 freeze/Review/driver/manifest与absence
  事实均immutable。R19已因authoritative full test 651/652永久rejected，其
  freeze/Review/driver/manifest、11项artifacts、缺失screenshot与两个exact empty roots
  immutable。R20已在release Core build永久rejected；其full 652/652、46/46、
  LAUNCH_READY、11 repository artifacts、缺失screenshot与historical signed-App hashes均为
  immutable partial/failure evidence；volatile bundle root当前只按Review22 8/38 partial
  snapshot处理。R21在pre-BEGIN停止且zero-write；R22 plan changes-required且未执行；R23
  因PIPESTATUS unknown永久rejected；R24 freeze/Review24/driver/178-entry manifest与十个runtime
  files immutable，Review24虽批准但执行因guard shape永久rejected且无END。R25 freeze/Review25/
  driver/exact 192-entry manifest与十个runtime files immutable，执行因preview ERR-subshell
  double containment永久rejected且无END。不得把任何partial green解释为A2已验收，也不得把历史
  evidence改写为后续成功证据。
- commit、push、merge、release、数据重置、付款、公开沟通、外部操作和真实用户
  操作的权限没有扩大。
- 若需要改变冻结 Stage/Plan 的架构、数据、依赖、允许文件、测试或顺序，必须停止并
  重新进入正式修订与职责隔离 Review；不得在本索引或 slice task 中自行决策。

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
