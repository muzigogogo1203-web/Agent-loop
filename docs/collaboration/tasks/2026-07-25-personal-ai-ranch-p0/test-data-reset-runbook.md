# AgentLoop 测试数据安全重置与回退 Runbook

> 状态：Ready for Review；P0 不执行
>
> 风险级别：破坏性操作
>
> 任何实际重置仍需再次确认精确目标根、运行模式和授权

## 1. 目的与边界

本 runbook 只定义如何安全处理当前测试数据，不把“测试数据无需延续”误解为可以直接删除数据库。

它区分两种完全不同的操作：

1. **领域测试数据 reset**
   - 重置 SQLite、artifacts 和 reports；
   - 保留 UserDefaults、Keychain、签名材料、安装备份和外部工作区；
   - 这是默认允许被进一步规划的最小范围。
2. **真正 clean-install reset**
   - 还会处理 dev/prod 两个 bundle domain 的 UserDefaults 与共享 Keychain service；
   - 会改变登录、Provider、默认模型和其他设备/账号状态；
   - 需要独立 spec、备份和新的明确授权，不能附带执行。

## 2. 权威路径

路径计算证据：

- `Sources/AgentLoopApp/AppStore.swift:339-352`
- `scripts/run-app.sh:88-99`
- `Sources/AgentLoopCore/Support/StateDirectoryLock.swift:30-48`

### 2.1 Normal

默认状态根：

`/Users/muzi/Library/Application Support/AgentLoop`

领域数据：

- `/Users/muzi/Library/Application Support/AgentLoop/agentloop.sqlite`
- `/Users/muzi/Library/Application Support/AgentLoop/agentloop.sqlite-wal`
- `/Users/muzi/Library/Application Support/AgentLoop/agentloop.sqlite-shm`
- `/Users/muzi/Library/Application Support/AgentLoop/artifacts`
- `/Users/muzi/Library/Application Support/AgentLoop/reports`

协调文件（领域 reset 必须保留，不能移动或删除）：

- `/Users/muzi/Library/Application Support/AgentLoop/.agentloop.lock`

`.agentloop.lock` 的安全门是“退出后没有 owner”，不是删除锁文件。它由 `StateDirectoryLock` 以 `O_CREAT` 打开并通过 `flock` 协调进程；空文件本身不是待重置的领域数据。

不得随领域 reset 处理：

- `/Users/muzi/Library/Application Support/AgentLoop/Signing`
- `/Users/muzi/Library/Application Support/AgentLoop/Install Backups`
- `~/Library/Preferences/com.muzi.agentloop.dev.plist`
- `~/Library/Preferences/com.muzi.agentloop.plist`
- Keychain service `com.muzi.agentloop`
- 任何外部 workspace

### 2.2 Preview

通过仓库脚本且没有调用方覆盖 `AGENTLOOP_STATE_DIR` 时：

`/Users/muzi/Agent-loop/.build/AgentLoopPreviewState`

`--preview` 本身不提供数据隔离；真正隔离来自脚本设置的 `AGENTLOOP_STATE_DIR`。若调用环境已经设置该变量，自定义值优先。

### 2.3 自定义状态根

不得凭 bundle id、窗口标题或进程名推断。必须通过目标进程环境和 `lsof` 确认它实际打开的 `.agentloop.lock`、SQLite、WAL 与 SHM 路径。

## 3. 当前只读审计快照

2026-07-25 调查时：

- PID `10416` 是 `.build/AgentLoop.app/Contents/MacOS/AgentLoop`；
- 没有 `AGENTLOOP_*` 环境覆盖；
- 它打开的是 normal 真实状态根；
- `agentloop.sqlite-wal` 非空；
- `PRAGMA integrity_check` 为 `ok`；
- `kernel_control.global.dispatchMode` 为 `running`。

这个状态不满足安全快照或重置前置条件。本记录只是时点证据；任何后续操作必须重新检查，不能复用 PID 或文件大小。

## 4. 安全快照前置门

以下条件必须全部满足：

1. 牧场主明确授权本次精确状态根和 reset 级别。
2. 在真实 UI 执行“紧急收哨”，等待持久状态完成。
3. 只读查询确认 `kernel_control.global.dispatchMode == halted`。
4. 真正退出 App；关闭窗口不算退出，因为菜单栏常驻可能保持进程。
5. `pgrep -x AgentLoop` 与 `pgrep -x AgentLoopApp` 均无结果。
6. `lsof` 确认目标 `.agentloop.lock` 和 `agentloop.sqlite*` 没有 owner。
7. 对精确数据库离线执行 WAL checkpoint，结果必须 `busy=0`，WAL 被安全归并。
8. 离线 `PRAGMA integrity_check` 必须为 `ok`。

任一条件失败立即停止。

## 5. 快照

快照必须位于目标状态根之外，使用时间戳目录，并作为同一不可拆分集合保存：

- checkpoint 后的 `agentloop.sqlite`
- `artifacts/`
- `reports/`
- SHA-256 manifest
- branch、HEAD、目标根、dispatch mode、checkpoint 与 integrity 结果

规则：

- 不把不同时间点的数据库、artifacts 和 reports 混合；
- 不把 `.sqlite` 与非空 WAL 拆开复制；
- `-shm` 是协调文件，不作为正常 checkpoint 快照的耐久真相恢复；
- 如果事故快照无法 checkpoint，main DB 与 WAL 必须作为不可分割对保存，但这种快照不满足正常 P0 reset 门；
- DB 中 artifact path 是绝对路径，恢复到不同根会破坏引用；
- 外部 workspace 不属于 App 状态快照，回滚 App 不会回滚用户项目文件。

## 6. 领域测试数据 Reset

满足 §4–§5 后：

1. 在目标状态根外创建明确的 `pre-reset` 目录。
2. 将以下精确对象移动到该目录，而不是删除：
   - `agentloop.sqlite`
   - 存在时的 `agentloop.sqlite-wal`
   - 存在时的 `agentloop.sqlite-shm`
   - `artifacts/`
   - `reports/`
3. 保留 `.agentloop.lock`，不移动、不删除；除上一步明确列出的五类对象外，不处理任何未知文件，也不使用递归宽泛 glob。
4. 不处理 UserDefaults、Keychain、Signing、Install Backups 或外部 workspace。
5. 以明确 normal / preview / custom 模式启动。
6. 用 `lsof` 再次确认新进程打开预期状态根。
7. 验证新 DB 的 integrity、schema、bootstrap 和空数据状态。

新 DB 默认 `dispatchMode=running` 不表示旧任务被恢复；必须同时确认没有旧 Mission/Card/Run。

## 7. 回退

1. 对新状态重复“收哨 → 真正退出 → 无 owner → checkpoint → integrity”门。
2. 先把 reset 后的新状态完整移动到另一个可恢复快照，不覆盖。
3. 整体移走当前 DB triplet、artifacts 和 reports。
4. 把原 checkpoint 快照的 `agentloop.sqlite`、匹配的 `artifacts/` 和 `reports/` 恢复到原路径。
5. 不恢复旧 `-shm`。
6. 离线确认恢复库 integrity。
7. 恢复库的 `kernel_control.dispatchMode` 必须为 `halted`；如果仍是 `running`，禁止 normal 启动，因为启动恢复可能收编旧 run 并重新调度。
8. 启动后确认 lsof、Mission/Card/Run 数量、产物路径和 UI 状态与快照记录一致。

## 8. Clean-install 额外风险

DB-only reset 不会得到真正首次安装状态：

- Keychain 中仍有凭据，`RuntimeProfileBootstrap` 会重新创建 runtime profiles；
- 新 profile ID 可能使旧 `profile.<id>.*` UserDefaults 成为孤儿；
- dev/prod 两个 UserDefaults domain 仍保留 base URL、API format、自治级别和草稿等设置；
- dev/prod 共用 Keychain service。

因此 onboarding 可以优先用全新、明确隔离的 custom state directory 验证，但 preview 仍可能共享 dev UserDefaults，不能把它描述为完整 clean-install。

## 9. 永久红线

- 进程或文件锁仍在时复制、移动或重置；
- 只复制 `.sqlite`，遗留非空 WAL；
- 单独删除 WAL/SHM；
- 混合不同快照的 DB、artifacts 和 reports；
- 从 `running` 快照恢复后直接 normal 启动；
- 顺手清理 Keychain、prefs、Signing、安装备份或外部工作区；
- 把快照放在即将重置的状态根；
- 用 preview、bundle id 或窗口外观猜测真实数据路径。
