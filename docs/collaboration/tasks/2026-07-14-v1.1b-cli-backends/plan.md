# V1.1b CLI 牧工(执行后端)Core 轮实施计划

日期:2026-07-14
分支:feat/v1.1(基线 ae4ead3,V1.1a 已合入)
母计划:`docs/collaboration/tasks/2026-07-14-oauth-model-cli-integration/plan.md` §V1.1b(D5-D9 + 拍板记录)
本轮范围:Core + App 逻辑层。设置页 CLI 供给线 UI、伙伴编辑器展示、花销面板标注留 Claude UI 轮;Views/*.swift 不得改动。

## 实现契约(母计划之外的落地决策)

1. **后端边界用组合不动刀**:`CardExecutionBackend` protocol(Core)在 Orchestrator 调起卡片执行的接缝处引入;`ModelLoopBackend` **包装现有 CardRunner(组合,不拆其内部)**,现有全部测试不改断言。协议签名以贴合现有 CardRunner 调用点为准(卡片 id/伙伴/工具装配上下文进,终结结果出),不必照抄母计划伪代码。
2. **kind 扩展**:迁移 **v11-cli-kinds**——重建或放宽 runtime_profile.kind 的 CHECK 约束以允许 `cli_codex` / `cli_claude`(SQLite CHECK 不可 ALTER,用新表迁移数据或触发器方案,保证可回放);RuntimeProfileKind 加两 case;这类档案 credentialAccount/baseURL 为 NULL;ModelCatalogService 对 cli_* 返回静态占位目录 `["cli-default"]`(CLI 自带模型,不在牧场选模型;伙伴 modelPolicy 对 cli_* 强制 inherit 语义,解析链跳过模型判定)。
3. **板务 server(BoardToolServer)**:
   - App 侧:每次 CLI 卡执行前,在 `Application Support/AgentLoop/board-sockets/<uuid>.sock`(0700 目录)起 Unix domain socket listener(Network.framework NWListener unix path 或 Darwin socket API,选实现简单者);ToolExecutor 复用现有五工具 handler(complete_card/block_card/ask_user/progress_note/search_camp_notes),按 cardId 绑定;一次性令牌 = 随机 32B hex,连接首帧必须携带,错误即断。
   - 桥进程:主可执行文件识别 `AGENTLOOP_BOARD_SOCKET` + `AGENTLOOP_BOARD_TOKEN` 环境变量 + argv 含 `--board-server` 时进入桥模式:stdin/stdout 讲 MCP(newline JSON-RPC,复用 MiniMcp 帧码常量/解析,反向实现 initialize/tools-list/tools-call),把 tools/call 转发到 socket、回传结果。桥模式不初始化 GRDB/UI。
   - CLI 退出而未调 complete_card/block_card → 视为异常终结:卡走现有「三振 block」语义之一次性 block(理由=退出码+stderr 尾)。
4. **CliProcessBackend**:按档案 kind 组装命令:
   - codex:`codex exec --cd <workspace> --sandbox <read-only|workspace-write> -c mcp_servers.ranchboard.command=<自身路径> -c mcp_servers.ranchboard.args=["--board-server"] -c mcp_servers.ranchboard.env.AGENTLOOP_BOARD_SOCKET=<sock> -c mcp_servers.ranchboard.env.AGENTLOOP_BOARD_TOKEN=<token> --json <prompt>`;
   - claude:`claude -p <prompt> --output-format stream-json --verbose --mcp-config <临时json文件> --permission-mode <plan|acceptEdits> --add-dir <workspace>`(mcp-config json 内容含 command/args/env 同上);
   - prompt = ContextPacket 渲染文本 + 明确指示「唯一终结方式是调用 ranchboard 的 complete_card/block_card 工具」;
   - **禁用旗标常量表** `CliBackendPolicy.bannedFlags`(--dangerously-bypass-approvals-and-sandbox、--yolo、--dangerously-skip-permissions、bypassPermissions 等),组装后断言不含,测试钉住;
   - 档位映射:careful→codex read-only / claude plan;standard 与 free→codex workspace-write / claude acceptEdits(+--add-dir 限工作目录);free 不升级(拍板 2)。
5. **监督**:子进程经 ShellProcessRegistry 注册;LoginShellEnvironment 取 PATH;超时 `KernelDefaults.cliCardTimeout = 1200s`(SIGTERM→5s→SIGKILL);stdout 按行读,JSONL 解析宽容(非 JSON 行忽略);codex `--json` 事件与 claude stream-json 事件各写一个最小解析器(assistant 文本 → 现有 feed 心跳事件;token 用量字段可得则入账,不可得记 0);stderr 环形 20KB;取消/紧急收哨走 registry 现有路径,卡回 ready。
6. **Orchestrator 选路**:装配处按伙伴档案 kind 选 backend;cli_* 伙伴的工具白名单/审批门语义:板务工具经 ToolExecutor 照走现有 ApprovalGate(写档动作按档位审批)。
7. **live spike(env-gated)**:仿 McpSpikeTests 模式,`AGENTLOOP_CLI_SPIKE=1` 时对真实 `codex exec` 跑一个最小单卡(无 key 依赖,用 echo 型任务),CI/常规跑跳过。

## 测试要求(~18,新文件 CliBackendTests.swift + BoardServerTests.swift)

BoardToolServer:五工具转发契约、一次性令牌错误即断、串卡拒绝(令牌绑 cardId)、并发连接拒绝第二条;CliProcessBackend:fake CLI 脚本 fixture(TestSuite 写临时 bash 脚本)——JSONL 输出被解析成 feed 事件、退出无终结→block(理由含退出码)、超时 SIGTERM→SIGKILL、取消即刻回 ready、banned flags 断言、档位→旗标矩阵(codex/claude × 三档);迁移 v11 回放(cli kind 可存、旧 kind 不受影响);ModelCatalogService cli_* 静态目录;ModelLoopBackend 包装后现有测试全绿(0 断言改动)。

## 验证命令

```
CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests
swift build --product AgentLoopApp
```

## 完成定义

全量测试绿(389 基线 + 新增);App 构建过;Views/ 未触碰;不 commit;不重置工作区;impl-report.md + verify.log 落本目录。若 CLI 旗标/输出格式与本契约不符,以本机实测为准并在 impl-report 记偏差(codex 0.132.0 / claude 2.1.81 已安装可实测 --help)。

## Blocker 答复(2026-07-14,Claude)

RuntimeProfileViews.swift 的穷举 switch 已由 Claude 预改为带 default 分支(kindLabel→「CLI 牧工」、kindIcon→terminal),编辑器 kind picker 改为显式三类白名单。**新增 cli_codex/cli_claude case 不会再破坏 Views 编译**,继续按契约实现,Views 仍然不许改。
