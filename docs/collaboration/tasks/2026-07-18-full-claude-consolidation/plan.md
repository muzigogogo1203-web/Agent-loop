# Claude Code 全量收口与 Coding 草原视觉补齐

状态：已完成并吸收晚到 sprite 交付（2026-07-18 23:16 PDT）。

Level 2。依据：`docs/superpowers/specs/2026-07-15-coding-ranch-visual-design.md`，以及用户 2026-07-18 要求把散落的 Claude Code 成果整合进单一最新版并清理 worktree。

## 审计结论

1. 4 个仍注册的 Claude worktree 分别包含模型目录收敛、Board socket 生命周期、版本探测、CLI pipe drain；其提交已保全并进入当前主工作区的 staged 整合集。
2. Git refs、reflog、不可达 commit/blob 与 Claude 本地会话中不存在另一份已完成的 `CampfireTheaterView` 牧场化实现。
3. Claude 已完成并定稿牧场视觉 spec、225MB 概念资产与 5 秒动效试验；App 代码只落了首批 4 张静态资产（牛棚横幅、草原空态），原任务明确把 `CampfireTheaterView` 列为非目标。
4. 因而用户看到的缺口是真实的未完成实现，不是单纯漏 cherry-pick。

## 目标

1. 保留现有真实状态驱动、卡片选择、阶段轨道、Reduce Motion 与窗口失焦暂停契约。
2. 把行动中的旧篝火环坐视觉替换为已定稿的方圆角黏土牧场基座与分散放牧布局。
3. 把参数化头像升级为七色小牛头像，让 Agent=牛的视觉隐喻在整个 App 一致。
4. 权威测试、打包、安装并做真实 UI 验收后，移除 4 个已吸收的散落 worktree；分支引用保留用于追溯。
5. 安装验收发现临时签名变化会触发钥匙串 ACL 授权，而启动路径在首窗前同步读取钥匙串，导致主线程卡在 SecurityAgent。改为首屏非交互探测、窗口出现后异步授权读取，并把读取中/失败状态公开到设置页。

## 触及文件与改动意图

1. `Sources/AgentLoopApp/Views/Components/CampfireTheaterView.swift`
   - 重命名为 `CodingPastureTheaterView.swift`，类型改为 `CodingPastureTheaterView`。
   - 删除篝火、轨道旋转与环坐定位。
   - 使用已打包的 `RanchBaseDay/Night` 作为主题感知的牧场基座；在基座上按稳定槽位分散牛群。
   - 牛的状态、工作卡标题与点击行为保持真实数据驱动。
   - 保留底部工作循环阶段轨道和营地知识计数。
   - 8 只以上使用横向可滚动牛群带，避免窄窗口重叠。
2. `Sources/AgentLoopApp/Views/Components/CompanionAvatarView.swift`
   - 保留七色调色板、表情状态、徽章与低帧率 TimelineView。
   - 把圆形人脸轮廓改为带耳朵、角、额前毛、口鼻与斑块的小牛头。
3. `Sources/AgentLoopApp/Views/CodingRanch/RanchArtView.swift`
   - 复用同一资源缓存，增加可供牧场舞台使用的主题感知背景渲染；资源缺失仍显式返回空视图，不伪造替代图片。
4. `Sources/AgentLoopApp/Views/TaskRunView.swift`
   - 更新组件调用名。
5. 本任务目录
   - `verify.log` 保存 `swift run RunTests` 完整输出。
   - `package.log`、`live-verify.log` 保存打包与真机证据。
   - `impl-report.md` 记录最终变更、worktree 吸收矩阵与偏离项。
6. `Sources/AgentLoopCore/Support/KeychainStore.swift`、`Sources/AgentLoopApp/AppStore.swift`、`Sources/AgentLoopApp/Views/RootView.swift`、`Sources/AgentLoopApp/Views/SettingsView.swift`
   - 增加显式的钥匙串交互策略；同步启动路径禁止弹授权 UI，真实授权读取移到首帧后的后台任务。
   - 设置页公开凭据读取中的状态和不含秘密的 OSStatus 错误，不吞掉认证失败。

## 非目标

- 不引入 Rive/Lottie/逐帧视频，不把 225MB 概念原图打进 App。
- 不修改任务状态机、数据库、Provider、卡片选择优先级或阶段判断。
- 不删除本地 Claude 会话、概念原图、安装版恢复点或安全 stash。
- 不提交；遵守仓库 `AGENTS.md`。

## 验证

1. `swift run RunTests` 全量通过，完整输出写入 `verify.log`。
2. `scripts/package-app.sh` 成功，资源 bundle 内有 4 张 RanchBarn/RanchBase 日夜图和 7 张透明 RanchCow sprite，共 11 个 RanchArt 资源。
3. 真实启动安装版，分别验收亮色与暗色 Coding 草原：无篝火、可见牧场基座、小牛头像、状态/卡片信息与阶段轨道；进程存活，无新鲜 crash report。
4. 逐个确认 4 个 Claude 分支提交的改动已存在于最终工作树后，使用 `git worktree remove` 移除对应目录，并由 `git worktree list` 确认只剩主工作区。
5. 在旧钥匙串 ACL 尚未批准的状态启动新安装版：首窗必须可见且可交互，主线程不得阻塞在 `SecItemCopyMatching`；若系统要求授权，只允许后台读取等待，并在设置页展示状态。

## 完成定义

完整 Claude 成果集、牧场小剧场和晚到的 7 色 sprite/比例修复都集中在 `/Users/muzi/Agent-loop`；权威测试与安装版 UI 验收通过；Git 只保留一个 worktree，分支与恢复点仍可追溯。
