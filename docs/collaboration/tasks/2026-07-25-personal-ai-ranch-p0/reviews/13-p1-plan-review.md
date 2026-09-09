# Review13 — P1-A2 R13 Plan Review

> 结论：**CHANGES REQUIRED — 0 P0 / 1 P1 / 0 P2**
>
> 日期：2026-07-27
>
> Reviewer：职责隔离 Review13 reviewer

## Frozen candidate verified

`evidence/plan-freeze-r13.md` 可定位，且当前 bytes 与其中冻结值逐字一致：

| Artifact | Verified SHA-256 |
|---|---|
| P1 Stage | `09e782f7fa3ba792a64f58d1f4db3cbbcfdcafa233d1efbb70b59c454c7e5f78` |
| P1 total Plan | `23593ea5954903d5c08498defbd08d7ca8f5ae7f0daa5c6063532bfefa6f4846` |
| P1-A2 leaf | `c1c245cf3f64a4e9f3c362853e53b077ced6c3b9d838f72474788d95799fb0b0` |

R13 新增的封闭 DEBUG seam、2×23 动态矩阵、#31/#40/#41 补强、
`PlanningTestFixtures.uniqueFunction` gate、release `nm` 零符号及 DEBUG caller
guard，在本次有界检查范围内彼此同义，未发现新的架构、schema、API、target 或
dependency 扩张。

## P1 finding

### P1-01 — 当前执行权威仍同时指向 Review12C 与 Review13，implementation gate 分裂

总 Plan §11 已正确规定：只有 Review13 在 R13 exact hashes 上判定
`APPROVED — 0 P0 / 0 P1` 后，才可实施 seam 或改写 #27/#31/#35/#40/#41
（总 Plan 4205–4209）。但同一冻结 candidate 的当前入口仍规定另一套 gate：

- Stage header 仍为 `R12-F Candidate Frozen；Review12C Pending`（Stage 3）；
- total Plan header 同样仍指向 R12-F / Review12C（total Plan 3）；
- total Plan §3.3 仍说 Review12C 在 R12-F hashes 上通过后即可改产品/测试
  （total Plan 1379–1380）；
- total Plan §3.3 的 Review/acceptance 条款仍限制“下一 reviewer”只能写
  `reviews/12c-p1-plan-review.md`，并仍以 Review12C 打开 implementation
  （total Plan 1880–1892）；
- A2 leaf header、进入门、停止门、验证前置与完成门仍分别以 R12-F /
  Review12C 为当前权威（leaf 3、27–35、50、682、794–798）。

这不是纯历史措辞：上述条款直接决定“谁能写哪个 review 文件”以及“何时可以修改
产品/测试”。Review12C 已经存在且已批准旧 candidate；若按这些仍具规范性的入口执行，
可以在没有 Review13 批准当前 R13 bytes 的情况下打开 implementation，正好绕过
§11 新增的硬门。因此当前 candidate 不能批准。

## Minimal bounded closure

只做 R13 授权范围内的 gate 同步，不改 seam 语义、测试矩阵、allowlist 或产品/test：

1. 将 Stage、total Plan、A2 leaf 的当前状态 header 同步为 R13 Candidate /
   Review13 Pending / seam-test completion frozen；
2. 将 total Plan §3.3 的 current entry、review writer path 与 implementation-opening
   条款统一到 R13 exact hashes、`reviews/13a-p1-plan-review.md` 与 Review13A；
   Review12C 只保留为 immutable historical predecessor；
3. 将 A2 leaf §1、§10、§12 的 current freeze evidence、review path、停止门、
   验证前置和完成门做同义同步；Review12C 同样只保留为 predecessor；
4. 重新计算 Stage / total Plan / leaf hashes，写新的 R13A freeze evidence，并证明
   本 Review13 与产品/test bytes 均未改变。

职责隔离的新 reviewer 必须在新 exact hashes 上写
`reviews/13a-p1-plan-review.md` 并重新判定。Review13A 达到
`APPROVED — 0 P0 / 0 P1` 前，继续禁止 DEBUG seam、测试、其他产品代码实施、
A2 implementation Review/acceptance 与 A3。

