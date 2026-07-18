# 实现报告：牧场氛围资产进 App

## 改动文件

- `Package.swift`
  - 为 `AgentLoopApp` target 增加 `.copy("Resources/RanchArt")`，保留 `RanchArt/` 子目录并生成 `Bundle.module`。
- `Sources/AgentLoopApp/Views/CodingRanch/RanchArtView.swift`
  - 新增 `RanchArtKind` 与主题感知的 `RanchArtView`。
  - 按 `colorScheme` 选择 Barn/Base 的 Day/Night JPEG。
  - 优先从标准 `.app/Contents/Resources/AgentLoop_AgentLoopApp.bundle` 加载，bare-binary / `swift run` 开发路径回退 `Bundle.module`；bundle 与图片均使用 `@MainActor` 静态缓存。
  - 通过 `NSImage(contentsOf:)` 解码；资源缺失或解码失败时不渲染。
  - 图片按调用方高度裁切为圆角横幅，并标记为装饰性内容。
- `Sources/AgentLoopApp/Views/CodingRanch/CowRosterView.swift`
  - 在已加载牛棚的滚动内容首位插入 150pt Barn 横幅。
- `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchHomeView.swift`
  - 仅在 Coding 草原没有进行中任务时，在空闲文案上方插入 170pt Base 横幅。
- `scripts/run-app.sh`
  - 在 codesign 前把 debug `AgentLoop_AgentLoopApp.bundle` 复制到 `.build/AgentLoop.app/Contents/Resources/`。
- `scripts/package-app.sh`
  - 在 codesign 前把 release `AgentLoop_AgentLoopApp.bundle` 复制到分发 `.app/Contents/Resources/`。
- `docs/collaboration/tasks/2026-07-16-ranch-ambient-assets/verify.log`
  - 保存本轮完整、正常收尾的 `RunTests` 输出。
- `docs/collaboration/tasks/2026-07-16-ranch-ambient-assets/impl-report.md`
  - 本报告。

计划提供的四张 JPEG 保持原样，未重新生成或修改：

- `Sources/AgentLoopApp/Resources/RanchArt/RanchBarnDay.jpg`
- `Sources/AgentLoopApp/Resources/RanchArt/RanchBarnNight.jpg`
- `Sources/AgentLoopApp/Resources/RanchArt/RanchBaseDay.jpg`
- `Sources/AgentLoopApp/Resources/RanchArt/RanchBaseNight.jpg`

## 构建与验证

- clean 后全 target 构建：通过。
  - 命令：`CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift build --disable-sandbox`
  - 结果：`Build complete! (86.79s)`。
  - 已核对构建产物；四张 JPEG 均位于 `AgentLoop_AgentLoopApp.bundle/RanchArt/`。
- Swift 语法解析：通过。
- `git diff --check`：通过。
- 完整测试：已运行并写入 `verify.log`。
  - 命令：`CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests --no-parallel`
  - 结果：409 项完成，405 项通过，4 项失败，进程退出码 1。
  - 失败项：
    1. `workspaceBookmarkCaptureAndResolveRoundtrip`：当前受限执行环境未生成 security-scoped bookmark（`workspaceBookmark == nil`）。
    2. `haltDuringRunningCardLeavesReadyCardAndNoOpenRun`：期望卡片回到 `.ready`；隔离复跑 3/3 仍失败。
    3. `emergencyStopCancelsRunningBeforeWaitingForPlanner`：全量串行运行失败；随后隔离复跑通过。
    4. `keychainRoundTrip`：当前受限执行环境返回 `KeychainError(status: -50)`。

上述失败均位于未触及的 Core/测试路径；本任务没有修改相关实现或测试来掩盖失败。当前测试结果未达到计划要求的全绿完成定义。

## 与计划的偏离

- 实现内容没有偏离计划。
- 当前执行环境不能写默认 SwiftPM/Clang 用户缓存，因此构建与测试使用仓库既有的 `/private/tmp` cache + `--disable-sandbox` 跑法；裸命令会在编译 manifest 前失败。
- 释放磁盘空间并执行 `swift package clean`、全量重建后，默认并行 `RunTests` 仍会在发现全部测试后停止推进，无法形成完整摘要。为留下完整、可审查的 409 项输出，最终日志使用 runner 支持的 `--no-parallel` 模式；串行模式暴露了上列 4 个问题。
- 未新增单元测试，符合计划对纯 App 视图/资源改动的测试约定。

## 工作区说明

- 未提交任何 commit。
- 开始任务前已存在的 `docs/collaboration/claude-codex-protocol.md` 未提交改动未被本实现触碰。

## Review 01 P0 修复与证据

### 修复

- `RanchArtView.resourceBundle` 是缓存的 `@MainActor` 静态 bundle：
  1. 先尝试 `Bundle.main.resourceURL/AgentLoop_AgentLoopApp.bundle`；
  2. 标准 `.app` 资源 bundle 不存在时才访问 `Bundle.module`，保留 bare-binary / `swift run` 开发路径。
- `scripts/run-app.sh` 与 `scripts/package-app.sh` 都在 codesign 前把对应构型的资源 bundle 复制到标准 `Contents/Resources/`，没有把 bundle 放到 `.app` 根目录。
- 按 review 要求，P3 的 `GRDB_GRDB.bundle` 与失败 name 的 nil 缓存均未处理。

### `.build/AgentLoop.app` 打包证据

执行：

```text
CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache scripts/run-app.sh --preview
```

脚本已完成 debug build、资源复制与 ad-hoc codesign；当前受限 LaunchServices 在最后 `open` 步骤返回 `kLSNoExecutableErr`。随后独立核对 executable 与严格签名均有效：

```text
app_executable=present
codesign=valid
```

标准资源目录中的四张 JPEG：

```text
.build/AgentLoop.app/Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/RanchBarnDay.jpg
.build/AgentLoop.app/Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/RanchBarnNight.jpg
.build/AgentLoop.app/Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/RanchBaseDay.jpg
.build/AgentLoop.app/Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/RanchBaseNight.jpg
```

### “干净机器”候选 1 验证

验证时临时把 `.build/arm64-apple-macosx/debug/AgentLoop_AgentLoopApp.bundle` 改名，使构建目录候选不可用；最小 Foundation 脚本从 `.build/AgentLoop.app` 的 `resourceURL` 执行与 helper 候选 1 相同的 `Bundle(url:)` 查找，并逐一查找四张 JPEG：

```text
candidate_1=/Users/muzi/Agent-loop/.build/AgentLoop.app/Contents/Resources/AgentLoop_AgentLoopApp.bundle
candidate_1_images=4
```

验证退出码为 0；trap 已恢复构建目录 bundle，并确认临时 `.review-hidden` 路径不存在。

### Review 01 测试追加

完整输出已追加到 `verify.log`，由以下标记开始：

```text
===== Review 01 rerun (2026-07-18; --no-parallel for restricted runner) =====
```

命令：

```text
CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests --no-parallel
```

结果：409 项完成，405 项通过，4 项失败，退出码 1；总耗时 12.777 秒。失败仍为：

1. `workspaceBookmarkCaptureAndResolveRoundtrip`：受限环境中 bookmark 为 nil。
2. `keychainRoundTrip`：受限环境中 `KeychainError(status: -50)`。
3. `haltDuringRunningCardLeavesReadyCardAndNoOpenRun`：卡片状态断言失败。
4. `emergencyStopCancelsRunningBeforeWaitingForPlanner`：卡片状态断言失败。

Review 已记录正常环境基线为 409/409；本轮没有为消除受限环境或串行 runner 下的问题而修改任何 Core/测试代码。
