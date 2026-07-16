# P0 / P1 修复与本机安装报告

## 结果

- 分支：`codex/fix-oauth-cli-p0-p1`（未提交）
- 安装位置：`/Applications/AgentLoop.app`
- 已安装版本：`1.1.0 (120)`
- 最终状态：App 稳定运行，签名校验通过，生产数据库完整性检查通过。
- 回滚备份：`~/Library/Application Support/AgentLoop/Install Backups/20260715-092730/`

## 修复内容

### P0：CLI / Board socket 生命周期

- `BoardToolServer.stop()` 改为只负责 `shutdown` 唤醒，连接 handler 作为唯一 close owner，消除并发 double-close / fd 复用窗口。
- server/client socket 都设置 `SO_NOSIGPIPE`，管道断开时转为可处理错误，不再把进程直接打崩。
- CLI stdout/stderr 改为非阻塞 POSIX 读取；进程退出后先排空已缓冲数据，再关闭 handle，修复 token usage 偶发丢失和 `FileHandle` 并发关闭问题。

### P1：OAuth 模型目录与旧伙伴对账

- ChatGPT OAuth 只使用内置受控目录，不再混入手工模型；当前目录为 `gpt-5.5`。
- 首次升级或 OAuth 成为默认供给线时，不兼容的旧默认/蒸馏/规划模型被归一化。
- 旧小牛的原模型字符串保留用于追溯，但策略从 `pinned` 改为 `inherit`，防止 `glm-5.2` / `claude-sonnet-4-6` 继续落到 OAuth 请求上。
- 设置页和小牛档案共用同一目录规则：OAuth/CLI 只读，API 供给线允许手工模型。
- CLI 新建菜单保留 `Codex CLI` 与 `Claude Code` 两个入口。

### 安装时发现并修复的生产 P0

第一个发布包在真实旧库上启动失败：一个预发布版曾用 migration `v8` 创建 `mission_template` / `schedule`，而当前主线将它们登记为 `v9-evercamp`。新版重放时重复建表，导致启动崩溃。

处理方式：

- v9 迁移先检查两张表是否成对存在。
- 对真实 legacy v8 必需列做严格验证；结构不完整则明确失败，不吞错。
- 验证通过后接管原表、补齐索引，并继续 v10/v11；旧模板和日程数据保留。
- 打包脚本只接受 `vX.Y.Z` 语义化标签作为 App 版本来源，避免把里程碑标签 `m3` 写进 Bundle 版本。

## 修改文件

- Core：`AppDatabase.swift`, `BoardServerBridgeMain.swift`, `BoardToolServer.swift`, `CliProcessBackend.swift`, `RuntimeProfileBootstrap.swift`, `ModelCatalogService.swift`
- App：`AppStore.swift`, `SettingsView.swift`, `CompanionEditorView.swift`
- Tests：`BoardServerTests.swift`, `RuntimeProfileTests.swift`, `ScheduleTests.swift`
- 工程：`AGENTS.md`, `scripts/package-app.sh`
- 验证记录：`verify.log`, `live-verify.log`

## 验证证据

- `swift run --disable-sandbox RunTests`：**409 / 409 通过**，完整输出在 `verify.log`。
- legacy v8 迁移定向回归：2 / 2 通过，包括真实旧结构数据保留。
- Board socket 组：6 / 6 通过；额外连续压测 100 轮通过。
- CLI token drain 定向压测：连续 30 轮通过。
- 真实 Codex CLI spike：1 / 1 通过，22.602s，输出在 `live-verify.log`。
- 本机 CLI：Codex `0.132.0`，Claude Code `2.1.81`。
- Release App：ad-hoc 签名验证通过，arm64，Bundle ID `com.muzi.agentloop`。
- 生产库：`PRAGMA integrity_check = ok`，`foreign_key_check` 无输出，迁移已到 `v11-cli-kinds`。
- 真实 UI：OAuth 目录仅 `gpt-5.5`，无手工输入；小牛默认为继承，钉住时仅有 `gpt-5.5`；CLI 菜单两个入口可见。

## 最终产物

- `dist/Coding 牧场.app`
- `dist/CodingRanch-1.1.0.zip`
  - SHA-256: `ce94fe11b85caa178a3b1c4073cf1724bf292a5f8f26b54e3a9729c9b9faaad9`
- `dist/CodingRanch-1.1.0.dmg`
  - SHA-256: `0e15c76fa4fca84b0922a95e7cbd4a5278bf1c49c7f5ec50ba7244ff2f7938b8`

## 边界

- 真实 Codex CLI 已跑通。Claude Code 的参数策略和 fake CLI 回归在全量测试内通过，本轮未向真实 Claude 账户发起任务。
- Kimi CLI 本机未安装，也不在当前 v1.1 的已接入种类中。
- 本地包为 ad-hoc 签名，未配置 Apple Notary Profile，因此没有做对外分发公证；不影响当前本机安装使用。
