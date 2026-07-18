---
name: verify
description: AgentLoop 真机验证配方——.app 壳启动、进程级观察、SwiftPM 资源打包陷阱与干净机器模拟
---

# AgentLoop 验证配方

## 启动（唯一正确方式）

- `scripts/run-app.sh --preview`（隔离状态目录、不读钥匙串；`--dark` 追加强制暗色）。
- 本机直跑裸二进制**不渲染文字**，必须走 .app 壳；脚本要求冷启动，先 `pkill -x AgentLoop`。
- 进程观察：`pgrep -x AgentLoop`（注意 /Applications 里的生产版进程名也是 AgentLoop——脚本的 ensure_cold_launch 会拒绝并存，pgrep 命中即脚本所启实例）。
- 结束验证后 `pkill -x AgentLoop` 清场。

## 测试

- 权威跑法 `swift run RunTests`（正常环境基线 409/409，约 3 秒）。
- 受限沙箱（如 Codex exec）里 keychain（-50）、security-scoped bookmark 必失败，串行 `--no-parallel` 下个别卡片状态断言不稳——都是环境产物，先在正常环境复核再下结论。

## SwiftPM 资源陷阱（真实踩过）

- `Bundle.module` accessor 只查 `.app 根/[target].bundle` 和**写死的构建机 .build 绝对路径**，都没有就 fatalError——本机 .app 靠写死路径侥幸运行，分发即崩。
- 资源必须由 run-app.sh / package-app.sh 拷入 `Contents/Resources/`（已修）；代码侧用显式 helper 先查 `Bundle.main.resourceURL` 下的 bundle（见 RanchArtView.swift）。
- **干净机器模拟**：`mv .build/arm64-apple-macosx/debug/AgentLoop_AgentLoopApp.bundle{,.hidden}` 后直接 `open .build/AgentLoop.app --env AGENTLOOP_UI_PREVIEW=1 --env AGENTLOOP_STATE_DIR=$PWD/.build/AgentLoopPreviewState`，8 秒后 pgrep 判存活；验证完记得 mv 回来。

## 其他

- 桌面截图需 computer-use request_access（用户可能拒绝）；进程存活 + bundle 内容 ls 是无屏幕授权时的替代证据链。
- 磁盘可能被并行 worktree 构建打满（曾致 RunTests 假卡死、Codex panic）；验证异常先 `df -h /`。
