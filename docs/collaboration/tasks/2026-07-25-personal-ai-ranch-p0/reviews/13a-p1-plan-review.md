# Review13A — P1-A2 R13A Plan Review

> 结论：**CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2**
>
> 日期：2026-07-27
>
> Reviewer：职责隔离 Review13A reviewer

## Frozen candidate verified

`evidence/plan-freeze-r13a.md` 可定位，且当前 bytes 与其中冻结值逐字一致：

| Artifact | Verified SHA-256 |
|---|---|
| P1 Stage | `a8ca6e7a56a32e945bae185724a51d4e0015d61676bf02d9637fedc2c27d9b6f` |
| P1 total Plan | `2382ac752807e2a36dbb6de834636a9858c539d5e19c607608af55094fdb2626` |
| P1-A2 leaf | `4564896993dad717f0150800f918133fd7c17508e3c57cfb941a322e49d46908` |
| R13A freeze evidence | `a79e577ecb14978fd5097ce05d9c012711427ea50d3b16ce9ea2b67e57691138` |

Immutable predecessor bytes也匹配：

| Artifact | Verified SHA-256 |
|---|---|
| R13 freeze evidence | `9bcfd9a6a430899bb51e164121e48ae7fb23f8e8454694b47ea30fcf7d6132d0` |
| immutable Review13 | `5203057f2a4a7f04827d9f5e0f20b717e08a31125404483b11f5cad722bda66b` |
| R12-F freeze evidence | `d88c14815b08aaa9187ae4053b33c8bfa45b1b03b0f2d2d61adf24e76bebbf41` |
| immutable Review12C | `db94c2cd473cd311c79aa61b8a32b634409b9485b5b5fcef775b71ecf1f2a109` |
| matrix script | `187da197ea4b0c80e1e437a6b5c576216f7c3491696c45b0f9104a9197401467` |

R13A freeze列出的15个product/test sentinel、10个immutable
source/package sentinel也全部逐项匹配；`git diff --check`对本次planning/control
范围无输出。本Review未运行build、test、matrix或preview。

Canonical Stage、总Plan和leaf的current header、entry、redline、验证前置与完成门
已经统一指向Review13A及
`reviews/13a-p1-plan-review.md`。R13的release-absent DEBUG seam、`first|second`
×23=46动态矩阵、#31/#35/#40/#41、
`PlanningTestFixtures.uniqueFunction`、release `nm`零符号与防伪门在三份canonical
中保持同义；41 names、13+2 allowlist、schema/migration/DDL/EventKind、
callback/KernelEvent与target/package graph未扩张。

## P1 finding

### P1-01 — current control surfaces仍把Review12C写成有效开门权威

R13A正确修复了三份canonical的current gate，但它同时冻结并纳入执行入口的
blocker与两个control index仍保留以下当前态表述：

- `p1-a2-durable-rumination/blocked.md:3` 的顶层状态仍是
  `Review12C Approved；A2 Red Gate Passed；Product Implementation Open`；
- 同一blocker的§13仍以`当前仅打开`描述Review12C activation
  （`blocked.md:503–523`），没有把该段明确降级为historical；
- P1 Stage control index的Review12C入口仍写`只打开 A2 failure-first
  implementation gate`（`stage-spec.md:53`），并在当前控制叙述中得出
  `因此 A2 产品实现门已在冻结的 13+2 allowlist 内打开`
  （`stage-spec.md:98–102`）；
- P1 Plan control index仍写`当前只打开 A2 首批五个 failure-first 红测`
  （`plan.md:55–58`），且“任务产物与职责”的`当前状态`把总Plan与A2 leaf写成
  `R12-F frozen；Review12C approved`
  （`plan.md:93–96`），而不是R13A Candidate / Review13A Pending。

这些不是哈希漂移；`plan-freeze-r13a.md`精确冻结的正是这些冲突bytes。后文虽又写
Review13A Pending和实施冻结，但顶层状态、current control结论和当前状态表仍能让
执行者依据Review12C绕过Review13A。故Review13的同一P1-01 split-brain尚未完全
关闭，本candidate不能批准。

## Minimal bounded R13B closure

只同步上述control文字，不改canonical seam/矩阵/allowlist或产品/test：

1. 把A2 `blocked.md`顶层状态改为R13B Candidate/Review13B Pending/A2
   Seam-Test Completion Frozen；把§13显式标成historical并将`当前仅打开`改为
   `当时仅打开`；
2. 把Stage control index中Review12C的开门描述全部改成明确的历史过去式，删除
   `因此 A2 产品实现门已...打开`这一当前结论；唯一current gate只保留新candidate
   的职责隔离review；
3. 把Plan control index的`当前只打开`改成pre-R13历史叙述，并把§4总Plan/leaf
   当前状态同步为新candidate frozen / 新review pending；
4. 重新计算blocker、两个control index与freeze evidence hashes，继续证明三份
   canonical R13A bytes、Review13A、R13 freeze/Review13及全部product/test/script
   sentinel不变；
5. 由未参与R13B同步的职责隔离reviewer写新的distinct review artifact并在新exact
   control hashes上重新判定。

新职责隔离review达到`APPROVED — 0 P0 / 0 P1`前，继续禁止DEBUG seam、
#27/#31/#35/#40/#41、其他产品代码实施、A2 implementation Review/acceptance与A3。
