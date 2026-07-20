# 实施报告：Claude Code 全量收口与 Coding 草原最新版

## 结果

散落在 4 个 Claude Worktree 的有效提交，以及随后交付的 7 色小牛/插画比例任务，已经集中到 `/Users/muzi/Agent-loop` 的同一份主工作区整合集。最终只剩一个 Git worktree；最新版 Coding 牧场 1.1.0（124）已安装到 `/Applications/AgentLoop.app`、运行并停留在 Coding 草原页面。

## 已吸收的 Claude 交付

| 来源 | 内容 | 吸收证据 |
|---|---|---|
| `1d4605c` | 模型目录策略、Runtime Profile 与 OAuth bootstrap 收敛 | 原补丁可从当前索引精确反向应用 |
| `305a2c6` | Board socket fd、listener close 与 SIGPIPE 生命周期修复 | 原补丁可从当前索引精确反向应用 |
| `ff60788` | `git describe` 祖先约束版本探测 | 原补丁可从当前索引精确反向应用 |
| `173d595` | CLI 输出管道 post-exit grace 状态机 | 原补丁可从当前索引精确反向应用 |
| `2026-07-18-pasture-sprites-aspect` | 7 色透明小牛、全部 RanchArt fit、3:2 动态舞台 | 源码、11 个 bundle 资源、亮暗 UI 与安装版验收 |

四个提交均用 `git diff <parent> <commit> --binary | git apply --cached --reverse --check -` 证明补丁已存在于主工作区索引。对应 worktree 在 clean 状态下移除并 prune；Claude 分支仍保留用于追溯。

## 本轮产品结果

### Coding 草原

- 旧 `CampfireTheaterView` 已由真实状态驱动的 `CodingPastureTheaterView` 替代。
- 日/夜黏土牧场保持完整 3:2 构图；透明小牛按真实 companion 颜色、状态和工作卡分布在草地上。
- 小牛点击、状态徽章、知识槽、阶段轨道、dense 模式、Reduce Motion 和失焦暂停契约保持。
- 7 色 PNG 已进入 release bundle；资源缺失时保留旧头像/卡片回退。
- 牛棚和空闲营地图统一使用不裁切的 fit 渲染。

### 启动与认证

- `KeychainStore` 增加显式交互策略；启动同步路径不再在首窗前触发授权 UI。
- 首帧后异步刷新凭据 presence，设置页公开读取中/失败状态而不记录秘密。
- 安装版首窗正常出现；设置页现场显示“网页登录已授权”“API Key 已保存”。

### Provider、CLI 与 Board

- 模型目录、OAuth 默认模型对账、CLI pipe drain、Board socket 生命周期和 package 版本推导全部进入同一整合集。
- OpenAI Responses 的 ChatGPT backend 请求体兼容修复与回归测试保留。

## 最终验证

- `swift build`：通过。
- 权威命令 `swift run RunTests`：423/423 通过。
- `scripts/package-app.sh`：成功；App、ZIP、DMG 均生成。
- release 与安装版签名校验：通过。
- release 与安装版可执行文件 SHA-256：`fa0c185e302504d0915077d2e273f3f3b1e32a601e14ecd5ba9bca4cde13249e`。
- bundle：4 张 RanchBarn/RanchBase 日夜图 + 7 张 RanchCow PNG，共 11 个 RanchArt 资源。
- UI：亮/暗草原、具象小牛、工作卡点击、牛棚完整构图、阶段轨道、设置认证状态均完成真实界面验收。
- 安装版 sample：主线程在正常 AppKit 事件循环，无钥匙串阻塞；最近 15 分钟无新崩溃。

完整证据见本目录 `verify.log`、`package.log`、`live-verify.log`，sprite 专项细节见相邻任务目录 `2026-07-18-pasture-sprites-aspect`。

## 清理与恢复

- `git worktree list` 最终仅 `/Users/muzi/Agent-loop  3f11d08 [main]`。
- 临时 sprite 验收状态已移到废纸篓，可恢复。
- Git 安全 stash 保留：`stash@{0}: codex-safety-before-latest-integration-20260718`。
- 最新替换前安装版备份：`/Users/muzi/Library/Application Support/AgentLoop/Install Backups/20260718-231244-pre-sprites/AgentLoop-pre-sprites.app`。
- 更早两个安装恢复点继续保留。

## 与原计划的偏离

1. 首轮牧场舞台仍是参数化小牛头像；Claude 的晚到交付补充了 7 色透明 sprite，现已一并吸收。
2. SwiftUI 对 `GeometryReader` 的 10pt ideal-size 探测会压扁原计划的 `.aspectRatio` 组合；使用同文件内的 `AspectFitStageLayout` 从可用宽度确定 3:2 尺寸，并由真实亮暗 UI 证明修复。
3. `scripts/run-app.sh --preview` 的 `open --env` 参数顺序会忽略预览变量；验收使用直接 `open -n --env ...`，未把非阻塞脚本修复扩入 sprite 计划。
4. 按仓库 `AGENTS.md` 未创建 commit；最终整合集已 staged，供用户体验和后续审阅。
