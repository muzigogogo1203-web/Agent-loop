# 运行时档案与 CLI 执行后端 实施计划 v1(Level 3,待用户过目后才触发实现)

日期:2026-07-14
分支:待用户确认后从 main(c3af1e3)新开 `feat/v1.1`
来源:blocked.md(2026-07-14 用户侧 Codex 会话的 10 项规划决策请求)
前置:blocked.md 的 worktree 抉择已解决——feat/v1.0 已合入 main 并推送,工作区干净,直接从 main tip 开工。

## 定位

解决两个相关但可分层的问题,拆成两个里程碑:

- **V1.1a 模型档案(供给线)**:凭据来源(Anthropic 兼容网关 / OpenAI API key / ChatGPT OAuth)与模型目录、伙伴模型绑定解耦——今天两头普通牛存着 `glm-5.2` 而生效凭据是 ChatGPT 登录,派单时才炸。
- **V1.1b CLI 牧工(执行后端)**:把本机已登录的 Codex CLI / Claude Code 作为整卡执行后端接入内核,与现有 CardRunner 并列。

V1.1a 是 V1.1b 的地基(CLI 后端本质是一种新的 runtime profile kind)。**分两个任务目录、两轮实现、各自验收**;本计划一次把两块决策写完,避免地基返工。

---

## V1.1a 模型档案(迁移 v10,Level 3)

### D1 数据模型

新表 `runtime_profile`(迁移 `v10-runtime-profiles`):

| 列 | 类型 | 说明 |
|---|---|---|
| id | TEXT PK | UUID |
| kind | TEXT NOT NULL | `anthropic_api` / `openai_api` / `chatgpt_oauth`(V1.1b 追加 `cli_codex` / `cli_claude`);CHECK 约束 |
| name | TEXT NOT NULL | 用户可改显示名(如「官方 API」「ChatGPT 登录」) |
| baseURL | TEXT | 仅 API 类使用;OAuth/CLI 为 NULL |
| credentialAccount | TEXT | Keychain account 名(如 `api-key` / `oauth-access-token`);CLI 类为 NULL |
| isDefault | BOOLEAN NOT NULL DEFAULT 0 | 全局默认档案,恰好一行为 1(部分唯一索引 `WHERE isDefault=1`) |
| createdAt | DATETIME NOT NULL | |

`companion` 加两列(可回放,均带默认值):

- `runtimeProfileId TEXT NULL REFERENCES runtime_profile(id)`——NULL = 跟随默认档案;
- `modelPolicy TEXT NOT NULL DEFAULT 'pinned'`——`inherit`(用档案默认模型)/ `pinned`(用本行 `model` 列)。既有 `model` 列**保留不动**,继续存 pinned 值(零数据搬迁)。

迁移种子(幂等):按当前 Keychain/UserDefaults 状态生成档案——有 API key → 按 apiFormat/apiBaseURL 建一条 API 档案;有 OAuth token → 建一条 `chatgpt_oauth` 档案;`preferredCredentialSource` 决定谁 `isDefault`。两者皆无 → 建一条空 `anthropic_api` 档案为默认(与今天「未配置」等价)。既有伙伴全部保持 `modelPolicy='pinned'`、`runtimeProfileId=NULL`——**行为与迁移前完全一致**(还是那个模型字符串,还是当前生效凭据),不做任何自动改写。

三档全局模型(default/distill/planner)与 `modelChoices` 改为**按档案命名空间**存 UserDefaults(key 形如 `profile.<id>.defaultModel`);迁移时把现有全局值拷入默认档案的命名空间,旧 key 保留不读(便于回滚观察)。

### D2 模型目录发现

`ModelCatalogService`(Core,actor):

- `anthropic_api` / `openai_api`:GET `<baseURL>/models`(两家均支持;网关 best-effort)。成功 → 目录 + fetchedAt 存 UserDefaults(档案命名空间);失败 → 保留上次缓存并标「未验证」;设置页手动「刷新目录」按钮,无自动轮询。
- `chatgpt_oauth`:该后端无公开目录接口——**内置静态目录**(KernelDefaults,gpt-5.5 一档起步)+ 手动追加;标注「内置清单,以实际可用为准」。
- 任何档案都允许**手动输入未验证模型 id**,目录 UI 加「未验证」徽章;派单不阻拦未验证 id(网关场景的现实需要),但记录首个失败并人话化提示。

### D3 切换语义(fail-closed + 显式确认)

- **切默认档案不自动改写任何伙伴**。切换时弹「对账单」sheet:列出 pinned 模型不在新档案目录内的伙伴与三档设置,每行可选「改跟随默认 / 换个模型 / 保持不动」;「保持不动」的伙伴在派单时 fail-closed——卡片 block,理由人话化(「测试牛钉着 glm-5.2,当前供给线(ChatGPT 登录)没有这个模型」),复用现有 block/retry 路径,**不改状态机**。
- 运行中的行动不打断:在飞的 turn 用旧 provider 跑完,下一次装配按新档案解析(与今天改 key 的语义一致)。
- 营地管家/规划/蒸馏:默认 `inherit`;三档设置里可按档案 pin。
- 判定「在目录内」仅对目录可信的档案生效(官方两家 + OAuth 静态表);纯网关目录拉不到时不做此判定(避免误杀)。

### D4 凭据回退:移除静默回退

`storedProviderCredential` 的「首选缺失→用另一个」回退**删除**。档案要什么凭据就用什么;缺失 → `provider()` 返回 nil → 既有「请先配置凭据」提示(带档案名)。可观测性:设置页凭据区常显「当前生效:<档案名>(<kind 人话>)」;`ProviderError.unauthorized` 文案按档案 kind 区分(OAuth →「ChatGPT 登录已过期,请重新登录」;API →「API key 无效或无权限」)。

### V1.1a 触及面与测试

- Core:迁移 v10 + RuntimeProfileRecord/CRUD(新文件 `Database/RuntimeProfileStore.swift`)、ModelCatalogService(新)、KernelDefaults 静态目录;
- App:AppStore 档案解析(provider(model:) 按伙伴→档案→凭据链解析)、设置页档案管理区(增删改/设默认/刷新目录/生效状态行)、切换对账 sheet、CompanionEditor 模型选择改档案感知(inherit/pinned);
- 测试 ~16:迁移种子矩阵(四种凭据组合)、伙伴解析链(pinned/inherit/NULL 档案)、目录缓存与失败保留、切换对账判定、回退移除后的 nil 语义、unauthorized 文案分流。

---

## V1.1b CLI 牧工(执行后端,Level 3)

### D5 后端边界

新 protocol(Core):

```swift
public protocol CardExecutionBackend: Sendable {
    func run(card: CardRecord, packet: ContextPacket, workspace: URL?, budget: BackendBudget,
             events: @Sendable (BackendEvent) -> Void) async throws -> BackendOutcome
}
```

现有 CardRunner 循环收敛为 `ModelLoopBackend`(**纯搬运,行为零变化**,现有全部测试不改断言);新增 `CliProcessBackend`。Orchestrator 派单时按伙伴档案 kind 选后端——`cli_*` 走 CliProcessBackend,其余走 ModelLoopBackend。Mission/Card 状态机、交接包契约、事件模型**全部不动**:两种后端产出同一组终结(complete/block/ask_user)。

### D6 首批适配器:子进程 CLI,不引 SDK

- **Codex:`codex exec --json`**(stdout JSONL;本机已验证可用;必须显式 `-m` + effort 配置,默认模型会被 API 拒——本仓 2026-07-14 实战教训);
- **Claude Code:`claude -p --output-format stream-json`**(本机 2.1.81);
- **Kimi:v1 不做**(未安装),适配器接口预留 kind 扩展。
- 不引 Codex app-server / Claude Agent SDK / ACP:零新依赖,子进程生命周期自持有,与 M8 MiniMCP 的取舍完全同构(6 个传递依赖不值 3 个方法的协议面)。

**实现顺序:Codex 先行打通全链路,Claude Code 第二个接**(同一轮内;若 stream-json 差异超预期,Claude 适配器降级为该轮遗留项单独收口)。

### D7 行动板契约:AgentLoop 自带板务 MCP server

CLI 牧工完成卡片的**唯一终结方式仍是工具**:AgentLoop 以 stdio MCP **server** 身份(新增 `board-server` 运行模式:主可执行文件带 `--board-server --card <id> --token <一次性令牌>` 参数直启,复用 MiniMCP 的换行 JSON-RPC 帧码反向实现)暴露五件工具:`complete_card` / `block_card` / `ask_user` / `progress_note` / `search_camp_notes`。启动 CLI 时把该 server 写入其 MCP 配置(codex `-c mcp_servers...` / claude `--mcp-config`)。

- 一次性令牌绑定 cardId,防止串卡;板务 server 经本机 socketpair/stdio 与主进程通信(server 进程回连主 App 的每卡 Unix domain socket,路径含随机段,权限 0600);
- CLI 退出而未调 `complete_card` → 按「工具缺席」走现有三振 block 路径(退出码与 stderr tail 进 block 理由);
- `ask_user` 语义不变:板务工具挂起卡片、CLI 进程终止,答复后**重新拉起**(v1 无会话续传,靠交接包/QA 注入上下文——`codex exec resume` 留 v2 优化项)。

### D8 自主档位映射(硬约束)

| 牧场档位 | Codex | Claude Code | 板务工具 |
|---|---|---|---|
| 谨慎 careful | `--sandbox read-only` | `--permission-mode plan` 等价只读 | 写档动作照走审批门 |
| 标准 standard | `--sandbox workspace-write`(锁行动工作目录) | 工作目录白名单写 | 同上 |
| 放手 free | 同 standard(**不升级**) | 同 standard | 预算内放行 |

**全档位禁止** `--dangerously-bypass-*` / `--yolo` / permission-bypass 类旗标(常量表硬编码禁用清单 + 测试钉住);CLI 的网络访问跟随其自身默认,不额外放权。无人值守(定时行动)模板若绑 CLI 牧工,沿用 M10-D2 双保险(预算必填 + ≤standard)。

### D9 进程监督

复用既有资产:ShellProcessRegistry(注册/紧急收哨/退出清理)+ LoginShellEnvironment(PATH)。每卡:

- 超时:默认 20 分钟(KernelDefaults 可调),SIGTERM → 5s → SIGKILL;
- 取消/紧急收哨:经 registry 立即终止,卡回 ready(复用现有取消语义);
- stdout JSONL 增量解析 → ActivityFeed 心跳(assistant 文本摘要为 feed beat,token 用量若可得入账 spentTokens;不可得记 0 并在花销面板标「CLI 用量未上报」);
- stderr 环形尾部 20KB,进 block 诊断;
- 退出码非零且无终结工具调用 → block(理由=退出码+stderr tail 人话化)。

### V1.1b 触及面与测试

- Core:CardExecutionBackend 协议 + ModelLoopBackend 收敛(纯重构)+ BoardToolServer(帧码复用 MiniMcp)+ CliProcessBackend + 禁用旗标常量;
- App:档案管理加 CLI kind(探测 which codex/claude + 版本显示)、伙伴编辑器 CLI 档案选择、花销面板「未上报」标注;
- 测试 ~18:后端协议一致性(用假 CLI 脚本 fixture 发 JSONL)、板务 server 五工具契约与一次性令牌、串卡拒绝、CLI 退出无终结→block、超时/取消/收哨、档位→旗标映射矩阵(含禁用清单)、ModelLoopBackend 重构后现有测试全绿。
- 活体验收(用户):真实 Codex 档案跑单卡行动到 complete;谨慎档写文件被审批门拦;Cmd+. 杀 CLI 进程;claude -p 同场景。

---

## 里程碑与节奏

1. **V1.1a**(先行,独立可交付):迁移 v10 + 档案/目录/切换对账 → 全量测试 + 用户 live-test(对账 sheet + glm-5.2 场景修复确认);
2. **V1.1b**(依赖 a):后端协议重构 → 板务 server → Codex 适配 → Claude 适配 → 用户 live-test。

各建任务目录 `2026-07-XX-v1.1a-runtime-profiles/`、`.../v1.1b-cli-backends/`,沿用 Claude 规划/review × Codex 实现(后端重构与板务 server 属并发敏感,review 按 Level 3 清单)。

## 验证命令

```
CLANG_MODULE_CACHE_PATH=/private/tmp/agentloop-clang-cache swift run --disable-sandbox RunTests
swift build --product AgentLoopApp
```

## 拍板记录(用户 2026-07-14「按照你的推荐来」)

1. **V1.1b 首批范围**:Codex 打通全链路 + Claude Code 同轮紧随;stream-json 差异超预期时 Claude 适配器降级为该轮遗留项。
2. **放手档对 CLI 永不 yolo**:确认为硬约束,禁用清单进常量表并测试钉住。
3. **切档案对账**:不自动改写 + 派单 fail-closed + 对账 sheet。
4. **UI 命名**:**供给线**(内核代码保持 RuntimeProfile 中性命名;「草料棚」与喂牛/草料概念冲突,弃)。

Open questions 已清空,计划生效,从 main(3128293)开 feat/v1.1 实施。
