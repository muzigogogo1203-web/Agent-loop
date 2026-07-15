# Claude Review 01 — V1.1b CLI 牧工 Core 轮

日期:2026-07-14
结论:通过(3 处发现,全部由 Claude 当场修复,含于提交 49b90cb)

1. **符合 plan**:契约 7 项全部落地;Views 未触碰;ModelLoopBackend 组合包装 CardRunner,既有测试零断言改动;banned flags 常量表 + 测试;偏差(codex effort 走 -c、claude 模型仅 env 显式、socket 文件名 16-hex 防 sun_path 越界)全部合理并已在 impl-report 记录。
2. **P1(已修)取消竞态**:取消先于进程注册到达时 CliProcessHandle.terminate() 空操作,取消会挂到超时——handle 记住 terminate 意图,set() 时补杀;并在 withTaskCancellationHandler 后补 Task.checkCancellation(),SIGTERM 正常返回也能走 canceled 收尾(cliProcessBackendCancellationReturnsCardToReady 真机首跑抓出;Codex 沙箱禁 socket/kill,该测试在其环境从未真正执行)。
3. **P0(已修)板务 server 崩溃**:FileHandle.availableData 在 fd 被并发关闭时抛 NSFileHandleOperationException(ObjC 异常,Swift 不可捕获)直接炸进程——换 POSIX read 循环(boardServerRejectsWrongTokenAndMismatchedCard 真机触发)。
4. **P1(已修)codex 兜底模型**:gpt-5.6-sol 在本机 codex-cli 0.132.0 被 API 拒(需更新 CLI),兜底改 gpt-5.5(env AGENTLOOP_CODEX_MODEL 可覆盖)。
5. **验证**:真机全量 405/405(4 suites)、App 构建通过。安全:一次性令牌绑 cardId、串卡拒绝、并发第二连接拒绝、全档位禁 bypass/yolo 均有测试钉住。

P3 备忘:CLI 子进程仅直接子进程可控(与 M7 ShellTool 同源限制,孤儿孙进程不追杀);真实 codex/claude 活体单卡验收在 v1.1 live-test 由用户执行(AGENTLOOP_CLI_SPIKE=1 的 env-gated spike 可先行)。
