# Review28 — R28 Shell timeout measurement-boundary plan review

Verdict: APPROVED — 0 P0 / 0 P1

## Review scope and independence

本 reviewer 未参与 R28 六面、driver、manifest、freeze 或 source delta 的设计与写入；本次唯一 repository write 是本 review 文件。审查期间未运行 driver、test、build、matrix 或 UI，也未访问、枚举或读取任何历史 temp root 或 descendant。

## Findings

- 六个 current control surface 顶部状态一致；各自 EOF 的 R28 body 均为 116 个 newline-terminated lines、8,817 bytes、SHA-256 `f7245b4202c9dd3c62e7febde3c99ee6ab2b37b7215fdc3ee0f9fdb7b3252183`，全文 SHA、行数与字节数均与 freeze 表一致。
- Freeze 现场 SHA-256 为 `902f0ceebd2a998cff724cdf0343440dc6f017733659614001ef11d3c28cc14f`。Driver 现场 SHA-256 为 `2f84ff2167faed7a1d677003f36d57548896d4a323ffe9980926fa8f8b0745c7`，5,970 lines、309,526 bytes、mode 0755，并通过 `/bin/bash -n`。Manifest 现场 SHA-256 为 `9d5fbeb6556a293dddb67fed80ea7983a920f4952c3f5f7ed11a5fb56e945dfc`，235 lines、42,488 bytes。
- Manifest 的 235 条记录均为 `/Users/muzi/Agent-loop/` 下 bytewise-sorted、unique 的 regular non-symlink file，pre-patch 为 235/235。它精确等于完整 R27 220-path set 加 15 个互斥 addition；R27 manifest 当前分区精确为 214 unchanged + 6 个六面 mismatch。Review28、R28 manifest/freeze、12 个 future runtime/report/screenshot paths 不在 manifest 中。
- R27 四个 immutable anchor、十个 repository runtime file 的 SHA/bytes/type 均复算一致；唯一 authoritative run 明确记录 652 tests 中 651 通过，唯一 issue 是 `shellTimeoutTerminatesProcess()` 的 5.13908825s `< 5s` elapsed assertion。Boundary 明确为 `REJECTED_CONTAMINATED`，Swift/tee 为 1/0；targeted、build、matrix、bundle、source、preview、screenshot、report 与 END 均未发生。
- `ShellToolTests.swift` entry SHA 为 `c4c75d66540c2cc0760f0edaef0650a93e2e589a45a5d8b932ab3b2bdc091350`。在唯一目标函数中、唯一 `let clock = ContinuousClock()` 正前方加入冻结的一行，预测 final SHA 精确为 `37b9e97c567cc599b98899fe1ca6c1deb9383b2889d52c2c42d3236dd2535a29`；删除且只删除该 newline-terminated line 可逐字恢复 entry SHA。现有 5s threshold、300ms timeout、300ms grace、输出/error/registry assertions 均保持不变。
- 产品 witnesses `ShellTool.swift` 与 `ShellProcessRegistry.swift` 分别保持 `e5980b4fb7d756656a7271ea646a54d49355c7a64f683245c6689254d76f2faf` 与 `260896d845d031e5cf46865303cfd00e944fa1c212278482c0d9a29d1001e6d1`。代码顺序证明登录环境解析发生在 `process.run()` 与 command deadline 之前；因此 frozen one-line change 修复的是测试测量边界，没有掩盖或改写 ShellTool timeout 状态机。Login-shell single-flight 保持 P2 候选，不阻断 R28。
- Driver 不包含 source write 或 patch implementation；它只接受 Review28 后由 root agent 在 pre-BEGIN 使用 `apply_patch` 产生的 exact final bytes，并在创建 boundary 前复证 final SHA、strip-to-entry、两个产品 witness、branch/HEAD、process absence、R27 predecessor 与 234+1 steady manifest。
- 三态闭合：当前 235/235；预测 one-line 后只有 `ShellToolTests.swift` 一项 mismatch，即 234+1；按 driver 第 115 行的唯一 matrix rewrite，预测只有 shell test 与 owned matrix script 两项 mismatch，即 233+2，restore 后回到 234+1。任何其他 path/type/hash drift 都 fail closed。
- Fail-once、ERR/subshell、Bash 3.2 compound-if status capture、matrix mandatory restore、preview direct-child containment、staged screenshot/report publication及 tiny commit-wins END 均有静态 gate。完整链只允许唯一 unfiltered `swift run RunTests`，并要求 652/652、same-log 46/46、shell timeout discovery/pass/failure 1/1/0、build/release/object/matrix/source/privacy/bundle、B01–B06 与 C01–C09 全部通过；不存在 retry、handoff 或 predecessor substitution 路径。
- 只有 exact R28 END 与全部 technical gates 通过后才允许职责隔离 Review02；只有 Review02 0 P0/0 P1 才打开 A2 acceptance，A3 及以后继续关闭。Commit、push、merge、release、数据操作、外部操作和真实用户操作仍未授权。
- 现场分支为 `codex/personal-ai-ranch-p0`，HEAD 为 `02334ec8d21533be81d93d39191bc7d9b9c24f7f`；Review28 与全部 12 个 R28 runtime/report/screenshot path 在写 review 前均 absent，`AgentLoop` 与 `AgentLoopApp` 精确进程均 absent。当前用户“不要哈希了，完整落地”的明确指令与仓库 standing Goal 授权允许 Review28 通过后自动继续，不要求用户回显 hash。

## Gate decision

R28 的 bounded measurement-boundary 修订已达到进入条件。Root agent 可在本 review 的 exact SHA 被 frozen caller 绑定后，先以 `apply_patch` 应用唯一一行 test-only delta，再按 frozen driver 执行；任何 pre-BEGIN proof 失败必须零 R28 runtime write，任何 BEGIN 后失败必须永久记为 `REJECTED_CONTAMINATED`。

R28_MACHINE_BLOCK_BEGIN
authority_mode=standing_goal_automatic_after_review28
standing_goal_authority_verified=true
reviewer_independence_attested=true
reviewer_write_scope=review28_only
user_hash_echo_required=false
review_verdict=APPROVED_0_P0_0_P1
freeze_sha=902f0ceebd2a998cff724cdf0343440dc6f017733659614001ef11d3c28cc14f
driver_sha=2f84ff2167faed7a1d677003f36d57548896d4a323ffe9980926fa8f8b0745c7
manifest_sha=9d5fbeb6556a293dddb67fed80ea7983a920f4952c3f5f7ed11a5fb56e945dfc
branch=codex/personal-ai-ranch-p0
head=02334ec8d21533be81d93d39191bc7d9b9c24f7f
manifest_count=235
R28_MACHINE_BLOCK_END
