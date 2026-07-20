# Review 01 — board socket 生命周期收尾

范围：工作树 diff（BoardToolServer.swift / BoardServerBridgeMain.swift / PosixSockets.swift / BoardServerTests.swift）+ impl-report.md + verify.log。

## 总评

三项修复均按 plan 落地，无 plan 外改动，锁纪律与「单一 close owner」不变量保持正确：连接 fd 唯一 close 点仍是 handle()（stop 只 shutdown），listener 唯一 close 点在 acceptLoop 尾部（未 claim 时 stop 锁内收走所有权后 close）。handler 强捕获无 retain cycle（block 仅被队列持有至执行完）。生产路径（CliProcessBackend 单次 start/stop）行为正确。

**注意：verify.log 里测试并未真正运行**——Codex 沙箱无法写 `~/.cache/clang/ModuleCache` 且工具链报 SDK 版本不匹配，构建未开始。验证由 Claude 在沙箱外执行（进行中），全绿前不得验收。

## 发现

### P2-1 start() 防御 guard 放在 bindAndListen 之后，误用时会先破坏活 listener 的 socket 路径

BoardToolServer.swift start()：guard 在 `bindAndListen(fd:path:)` 成功后才检查。而 bindAndListen 一进去就 `removeItem(atPath:)` 再 bind——若 server 已在运行，第二次 start() 会先 unlink 活 listener 的 socket 文件并绑上新 socket，随后 guard 才 throw 并 close 新 fd，留下一个连不通的孤儿 socket 文件，原 listener 从此不可达。防御 guard 的意义因此打了折扣。

修法：进入 start() 后、创建 socket 之前先锁内检查 `listenFD < 0 && !acceptLoopOwnsListener`，违反即 throw；bind 后的现有 guard 保留（覆盖并发 start 的 TOCTOU 窗口）。

### P2-2 stop→start 重启时，迟到的旧 acceptLoop block 可能 claim 新 listener，双循环同抢一个 fd

序列：start#1 → 在 acceptLoop#1 的 dispatch block 尚未执行时 stop()（owns=false，stop 关掉 listener#1、listenFD=-1）→ start#2（guard 通过）设置 listenFD=fd#2 并派发 acceptLoop#2。此时滞留的 block#1 先跑：claim 分支看到 `!stopped && listenFD=fd#2 ≥ 0`，把 fd#2 claim 走；block#2 随后也进 claim——`acceptLoopOwnsListener` 已为 true 却无人检查，两个循环 accept 同一个 fd，退出路径双双 close/置位，正是本次要消灭的竞态形态。

plan 声明不支持重启复用，但 guard 现状恰恰放行了「完整 stop 后重启」，所以这个洞可达。修法（任选其一，倾向 a）：
a) 把 listener fd 作为参数传给 acceptLoop（start 时捕获），claim 时锁内校验 `listenFD == expectedFD && !acceptLoopOwnsListener`，不匹配直接 return（旧 fd 已被 stop 关闭，无需 close）；
b) claim 分支同时检查 `acceptLoopOwnsListener == false`，并让 start() 在 `acceptLoopOwnsListener == true` 时一律 throw（现已如此）——但仅此不够，还需防 block#1 抢 fd#2，故仍需 (a) 的 fd 校验。

### P2-3 回归 1 自旋等待后缺少 `#expect(weakServer == nil)` 终态断言

`boardServerHandlerBlockKeepsServerAliveUntilConnectionCloses` 中 `while weakServer != nil, Date() < deadline` 自旋结束后没有断言 weakServer 已归零（plan 步骤 5 要求）。当前若 handle 未能释放，只能靠轮末 fd 阈值间接兜住，诊断信息差。加一行终态断言。

### P3-1（备忘，不要求改）回归 1 的 probe 依赖 SO_RCVTIMEO=1s

probe.readLine() 的 nil 既可能来自 claim-fail 关闭、也可能来自 1s 接收超时；极端负载下超时先到会让测试在未确认 claim 的状态下继续走。本机 .serialized 套件下 accept 在微秒级完成，风险可忽略；若未来出现偶发红，优先怀疑此处。

## 检查清单结论

1. 符合 plan：✓（触及文件与清单一致，无越权改动）
2. 正确性：P2-1 / P2-2（均为误用/重启路径，生产单次 start/stop 不受影响）
3. 并发：✓（锁内 claim/移交、shutdown-唤醒-唯一 close、强捕获无环、deinit 不可能与 acceptLoop 并发）
4. 数据层：n/a
5. 契约：✓（init 新参数带默认值，向后兼容；无 JSON/schema 变化）
6. 测试真实性：✗ verify.log 无真实测试运行（沙箱环境问题，非实现问题）；P2-3；P3-1
7. 安全：✓
8. 代码质量：✓（死代码已清，注释已更新，风格贴合）

## 结论

P0/P1：无。P2-1、P2-2、P2-3 按「便宜就修」原则本轮修掉。验收前置条件：Claude 本地 `swift run RunTests` 全绿。
