# Coding 牧场 macOS 验收候选

状态：**READY FOR USER ACCEPTANCE — NOT FORMALLY ACCEPTED**  
候选日期：2026-08-30  
工作目录：`/Users/muzi/Agent-loop`  
分支 / HEAD：`codex/personal-ai-ranch-p0` /
`02334ec8d21533be81d93d39191bc7d9b9c24f7f`

## 可交付软件

- 可直接运行：`/Users/muzi/Agent-loop/dist/Coding 牧场.app`
- ZIP：`/Users/muzi/Agent-loop/dist/CodingRanch-1.1.0.zip`
- DMG：`/Users/muzi/Agent-loop/dist/CodingRanch-1.1.0.dmg`
- 版本：`1.1.0`，build `128`

产物 SHA-256：

- 主程序：
  `74dfd43ca6bbb18b8a13caad474ad2852c78097e1cb1e49fbf6d0192ba4c2704`
- Board Bridge helper：
  `40f7924ef4181b65d736c54c05e24768d12e70dee3847258fc775b6a09eceb62`
- ZIP：
  `121a636a2024086d79b0f80bf44ab978ebabbce5c3fd325a194d15546a3bcead`
- DMG：
  `dc9b5a9cbe375c7fbe6e6dd92ea14e4832936ebc32961ec3828719547501558c`

## 已完成的工程验证

| 验证项 | 结果 | 证据 |
|---|---|---|
| 全量测试 | 串行运行 1,082 tests / 31 suites 全绿，226.512 秒 | `verify.log`, SHA-256 `436781a58b8916af33673ef8b807f941084f1ae65b01c362c9d13343fe76eebb` |
| 静态边界回归 | 2/2 全绿 | `/private/tmp/r9f-root.2U4S9d/static-boundary-final-v157.log`, SHA-256 `3ea633d713f5e3a6c7091f7162a0746013058da766aa76c9d68a460a865af3c4` |
| Release 构建与打包 | App 与 helper 构建成功；ZIP/DMG 生成 | `build.log`, SHA-256 `a07c190d6add8423ce7e392bc33383930304616eaf5c8e084542a9b25179801c` |
| 签名完整性 | App 与嵌套 helper 的 deep/strict codesign 校验通过 | `build.log` |
| 真实启动 | 精确 dist 可执行文件存活 8 秒，创建隔离数据库/锁/runtime，按 PID 干净退出 | `/private/tmp/r9f-root.2U4S9d/dist-launch-final-v160.log`, SHA-256 `999056795e92c0e774381b714025b80319d41d14173fabade770cea270ab1cd2` |
| 干净机器资源模拟 | 隐藏本地 build resource bundle 后，dist App 仍可启动并找到 RanchArt | `preview.log`, SHA-256 `774f8b5fb05c1418293a396a0667c98cfddb046400ed35d4e5fb0cff87f001aa` |
| 迁移/恢复矩阵 | SQLite 3.51/3.52、真实/字面量、replay/rollback/FK/integrity 全部通过；v17 为 79/208/84 | `migration-matrix.log`, SHA-256 `0d2d70c0e3744d4f615acc71d170eefd775529012098c4f4c473908e0323dd24` |
| 工作树格式检查 | `git diff --check` 通过 | 2026-08-30 最终收口检查 |

所有 App 启动验证都使用唯一隔离的 `AGENTLOOP_STATE_DIR`。没有读取或改写
正常用户数据库，没有使用真实密钥，没有调用真实外部 Provider/CLI，也没有发出
真实通知。

## 建议的用户验收路径

1. 双击 `Coding 牧场.app`，确认首页、Coding 草原和任务工作台都能打开。
2. 在测试营地输入一个小型 Coding 目标，确认目标、验收清单和工作目录后再开始任务。
3. 观察任务从教练澄清进入真实执行；若出现“需要你决定”，回答后确认同一任务继续推进，而不是生成重复任务。
4. 在执行中检查进度、Attention 项和失败信息是否可见；退出并重新打开 App，确认任务能恢复而不丢失状态。
5. 成果形成后打开成果/报告，检查产物可读，再使用“验收并回营”。
6. 返回营地首页，确认待验收数量、任务状态、成果记录和 Growth/记忆投影一致。
7. 任选一个失败场景（例如取消一次测试任务或暂时不给模型凭据），确认错误明确可见、任务不会假装成功，并可按界面提示恢复或重试。

## 已知限制与未关闭的正式门

1. 冻结 P1-F1 计划要求最终执行不带 `--no-parallel` 的无过滤
   `swift run RunTests`。本轮串行全量 1,082/1,082 已通过，但默认并行的精确命令
   在重新编译巨大测试源时连续被系统以 signal 9 杀死；一次失败的 SwiftPM 进程
   仍处于 macOS 不可中断状态并持有默认 `.build` 锁。Codex/App 会话重启没有清除
   这些 PID，因此这项正式证据必须在真正的 macOS 重启和更充足磁盘空间后补跑。
2. 当前 `Review02` 的最终正式结论只覆盖到 F1C；全量当前实现的最终独立 Review、
   计划要求的完整 `source-gates.log` 与 `compatibility-verify.log` 尚未关闭。本文不能
   把工程候选误标为“P1-F1 正式 ACCEPTED”。
3. 当前包为 ad-hoc 签名，没有 Developer ID 公证，不是公开发布包；首次打开可能
   需要 macOS 本地确认。没有执行 release、上传或公开分发。
4. 真实用户凭据、真实云端 Provider、真实用户数据及长时多人使用仍由用户验收；
   P3–P6 的云端扩张、硬件、法律、商业化和公开发布不属于本次完成门。
5. Camp retirement/deletion 没有启用；P1 尚未获得形式化整体完成结论。

## 当前裁决

该构建已达到“可供用户开始功能验收”的工程状态。用户验收可以立即开始，但正式
内部 P1-F1 acceptance 必须等默认并行全量门、完整源门和最终独立 Review 补齐后
才能标记为通过。

本轮未执行 commit、push、merge、PR、release、支付、公开消息、正常用户数据操作
或任何真实用户动作。
