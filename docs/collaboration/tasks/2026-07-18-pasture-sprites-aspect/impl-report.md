# 实现报告：草原具象小牛 + 插画比例修复

## 结果

7 色透明小牛已经进入 Coding 草原正式舞台；四处 RanchArt 调用统一为保持原始比例的 fit 渲染。亮/暗主题、工作卡点击、牛棚完整构图、release 打包和真实安装版均已验收。

## 改动文件

- `Sources/AgentLoopApp/Views/CodingRanch/RanchArtView.swift`
  - 统一为 `RanchArtLayout.fit(maxWidth:)` 和 `scaledToFit()`。
  - 新增七色 sprite 映射、JPG/PNG 共用缓存和带接地阴影的 `RanchCowSpriteView`。
- `Sources/AgentLoopApp/Views/Components/CodingPastureTheaterView.swift`
  - 舞台和 dense 头图锁定 3:2 fit 比例，采用计划内站位和 56/60pt 边距。
  - 舞台 agent spot 改为透明小牛、状态徽章和紧凑胶囊；缺少对应资源时完整回退旧卡片。
  - dense 横滚卡优先使用 56pt sprite，保留头像回退。
- `Sources/AgentLoopApp/Views/CodingRanch/CowRosterView.swift`
  - 牛棚头图改为 `.fit(maxWidth: 760)` 并居中。
- `Sources/AgentLoopApp/Views/CodingRanch/CodingRanchHomeView.swift`
  - 空闲草原图改为 `.fit(maxWidth: 640)` 并居中。
- `Sources/AgentLoopApp/Resources/RanchArt/RanchCow*.png`
  - 新增 Purple、Teal、Coral、Pink、Blue、Green、Amber 七张透明小牛。

未改 `TaskRunView` 调用契约、Core、数据层、状态映射或点击行为。

## 根因修正与计划偏离

计划原写法为 `.aspectRatio(1.5, contentMode: .fit)`。真实 UI 首轮验收发现 `GeometryReader` 在 `VStack` 的 ideal-size 探测中被压成 10pt 高度。最终在同一许可文件内增加 `AspectFitStageLayout`，由可用宽度确定 3:2 尺寸并限制最大高度 440/200；亮暗两套实际窗口均确认舞台为完整 3:2，而非用固定高度掩盖问题。

`scripts/run-app.sh --preview` 的 `open --env` 参数顺序会让 macOS 忽略预览环境变量；本任务未越过计划范围修改脚本，UI 验收改用等价的直接 `open -n --env ...` 命令。正式安装版不经过该预览脚本。

## 验证

- `git diff --check`（本任务四个 Swift 文件）：通过。
- `swift build`：通过，9.48 秒；完整输出见 `build.log`。
- 权威测试 `swift run RunTests`：423 tests / 5 suites 全部通过，13.589 秒；完整输出见 `verify.log`。
- 早先受限沙箱运行产生的 bookmark、Keychain 和 durable-halt 三个失败已被本机权威命令复验排除，最终日志已由正常环境结果覆盖。
- release：`scripts/package-app.sh` 成功，生成 App、ZIP、DMG；完整输出见 `package.log`。

## 真实 UI 与安装验收

- 亮色和暗色 Coding 草原均显示完整 660×440 牧场基座、两只透明紫色小牛、状态胶囊、知识槽和阶段轨道；无旧白卡片拼贴。
- 点击小牛可打开正确工作卡详情；Accessibility help 保留真实工作卡标题。
- 暗色牛棚页完整显示 16:9 构图，屋顶、四只牛和牛棚均未裁切。
- “我的营地”当前有进行中任务，未触发空闲插画分支；该分支已确认调用与牛棚相同的 `RanchArtView.fit` 路径。
- 安装版 `/Applications/AgentLoop.app` 为 1.1.0（124），签名校验通过，可执行文件 SHA-256：`fa0c185e302504d0915077d2e273f3f3b1e32a601e14ecd5ba9bca4cde13249e`。
- 安装版真实窗口显示新 sprite 舞台；设置页显示“网页登录已授权”“API Key 已保存”。
- 2 秒进程 sample 的主线程位于 AppKit 事件循环，无 `SecItemCopyMatching` / SecurityAgent 阻塞；最近 15 分钟无新 AgentLoop crash report。

## 资源证明

release 与安装版资源 bundle 均包含 11 个文件：4 张 RanchBarn/RanchBase 日夜 JPEG，加 7 张 RanchCow PNG。

## 清理与恢复

- 临时验收状态已移动到废纸篓：`/Users/muzi/.Trash/AgentLoop-CodingPastureSpritesAcceptance-20260718-231608`，可恢复。
- 替换前安装版备份：`/Users/muzi/Library/Application Support/AgentLoop/Install Backups/20260718-231244-pre-sprites/AgentLoop-pre-sprites.app`。
- 未创建 commit；按仓库 `AGENTS.md` 保持为主工作区 staged 整合集。
