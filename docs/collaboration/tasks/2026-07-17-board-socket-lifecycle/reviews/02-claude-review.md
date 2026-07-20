# Review 02 — 本地验证结果与修复项（含 01 遗留 P2）

Claude 在 worktree（/Users/muzi/Agent-loop/.claude/worktrees/magical-ptolemy-19d5ce）本地执行 `swift run RunTests`：**编译全过，但测试阶段进程以 SIGTRAP（exit 133）中止**，全绿未达成。两个新 P1 + 01 号 review 的三个 P2 一并修。

## P1-1 回归 1 的错误路径释放挂起队列，SIGTRAP 打死整个测试进程

`boardServerHandlerBlockKeepsServerAliveUntilConnectionCloses` 每轮 `queue.suspend()` 后，一旦中途 throw（本次真实发生：start() 抛 socketPathTooLong），挂起状态的 DispatchQueue 被释放，libdispatch 以 "release of a suspended object" trap（SIGTRAP，exit 133），RunTests 进程整体死亡，后续所有套件未运行。

修法：每轮循环体内用一次性守卫保证 resume 恰好执行一次，无论正常路径还是 throw 路径：

```swift
var queueResumed = false
defer { if !queueResumed { queue.resume() } }
// ……正常路径把 queue.resume() 替换为：
queueResumed = true
queue.resume()
```

（注意不可双 resume——over-resume 同样 trap。）

## P1-2 测试 socket 路径在 git worktree 下超过 AF_UNIX sun_path 104 字节上限

`makeBoardHarness` 把 socket 目录放在 CWD 的 `.build/t/bXXXXXXXX/s/`，在 worktree 前缀（65 字符）下最终路径约 107 字节 > 104，`bindAndListen` 抛 `socketPathTooLong`，导致 boardServerRejectsWrongTokenAndMismatchedCard、boardServerRejectsSecondConcurrentConnection、boardServerStopWhileConnectionIsActiveClosesExactlyOnce 及两个新回归在 worktree 环境全部失败；而 `agentLoopCanBindListenerSocket()` 的探针路径（约 93 字节）恰好低于上限，门形同虚设。main 检出路径短，故此前未暴露。本项目常规在 worktree 跑测试，必须修。

修法（仅测试文件）：
- `makeBoardHarness` 的 `sockets` 目录改为短路径临时目录：`URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("al-\(UUID().uuidString.prefix(8))")`（/var/folders/... 前缀约 50 字节，总长 < 90）。db 与 workspace 保持在 `.build/t/` 下不动。
- `agentLoopCanBindListenerSocket()` 探针改用同样的短临时目录，保持门与实际绑定位置一致。

## P2（沿 01 号 review，逐项修）

- **P2-1**：start() 的防御 guard 移到 bindAndListen 之前（锁内先查 `listenFD < 0 && !acceptLoopOwnsListener`，违反即 throw，不得先 unlink 活 listener 的 socket 文件）；bind 后现有 guard 保留。
- **P2-2**：listener fd 作为参数传入 acceptLoop（start 派发时捕获），claim 时锁内校验 `listenFD == expectedFD && !acceptLoopOwnsListener`，不匹配直接 return 不 close，杜绝 stop→start 重启时旧 block 抢占新 listener。
- **P2-3**：回归 1 自旋等待后补 `#expect(weakServer == nil)` 终态断言。

## 验收口径不变

修复后由 Claude 在 worktree 重跑 `swift run RunTests`，全绿才验收（Codex 沙箱跑不了测试，verify.log 记录构建即可，测试结果以 Claude 侧为准）。
