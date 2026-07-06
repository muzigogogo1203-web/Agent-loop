# M5 实现计划 v1 — 多营地(频道化) + 崩溃恢复 + 收官打磨(Level 3,待用户过目)

> 基于 feat/m4(M4 待用户正式测试;M5 在 `feat/m5` 分支进行,M4 修复轮如有则合入)。
> 用户 2026-07-05 增补方向:**营地=频道,可新建多个;行动在营地内发起;每个营地沉淀自己的笔记**——列为 M5-0 优先做。
> 分工沿用 M4:全部代码 Claude 亲自实现;UI 先设计后落地;截图验证走 `scripts/run-app.sh --preview` + AGENTLOOP_STATE_DIR。

验收(spec §16-M5 + 用户增补):**多营地可建可用、行动归属营地、知识按营地隔离;杀进程重启行动续跑;Reduce Motion 全静态替代;产出可分发 .app。**

## M5-0 多营地(用户增补,优先)

### 现状盘点(利好:数据层 M1 起就是多营地形状)

- `camp` 表、`squad.campId`、`camp_note.campId`、`chat_thread.campId`、向导 per-camp 自动配备——全部就位,**零表迁移**。
- 写死单营地的位置:`ensureDefaultCamp()`(createMissionShell/createSingleCardMission 内部调用)、AppStore.campId 单值、侧栏 IA(全局「新行动」+单一「营地」入口)、行动列表全局查询 `missions(limit:)`。
- 伙伴名册:spec §10.2 明确 propose_squad「从**全局名册**选成员」→ **伙伴保持全局**,不按营地划分(guide 除外,per-camp)。

### 决策(C1-C6,待用户过目)

| # | 决策 | 理由 |
|---|---|---|
| C1 | **信息架构**:侧栏顶层=营地列表(每营地一个分区:⛺营地名 → 点击进营地首页;分区下嵌该营地「进行中的行动」;「往期行动」收进营地首页,侧栏只留进行中)+「+ 新营地」;伙伴名册与设置保持全局区。**「新行动」移入营地**:营地首页主按钮 + 营地分区行内「+」,新行动表单顶部显示所属营地(不可在表单里换营地,进哪个营地建哪个) | 频道语义:先选频道再发言;侧栏不随行动数爆炸 |
| C2 | **建营地**:侧栏「+ 新营地」→ 弹窗(名字,可选自定义向导人设)→ `createCamp(name:)` 建 camp + 自动配向导(spec §10.2)+ guide 线程;新营地即刻出现在侧栏并进入其首页 | 最小完整闭环 |
| C3 | **改名/删除**:营地首页 header 支持改名(向导人设经既有「编辑向导」);**删除/归档不做**(级联行动/笔记风险大,进 v2 背包) | MVP 克制 |
| C4 | **归属链路**:`createMissionShell/startMission/createSingleCardMission` 增 `campId` 参数(替换内部 ensureDefaultCamp);AppStore 增 `currentCampId` 上下文;行动列表改按营地查询(join squad);提案确认建队天然归属向导所在营地 | 行动必属某营地 |
| C5 | **知识隔离**:笔记注入/检索/camp_status/向导对话已全部 campId 参数化,接线后补**跨营地隔离测试**(A 营地笔记绝不注入 B 营地行动;向导只见本营地) | 频道的核心承诺 |
| C6 | **兼容**:既有「我的营地」自动成为第一个频道,旧行动/笔记/私聊全部无缝归属它,零数据迁移;启动仍 ensureDefaultCamp 保底(空库首启有家) | 用户无感升级 |

### 触及面

- Core:`createCamp/renameCamp/camps()` API、mission 创建链路加 campId、`missions(campId:)`。
- App:侧栏 IA 重构(营地分区)、`Destination.camp(String)` 带 id、新行动表单挂营地上下文、营地首页 header(名字可编辑)、新营地弹窗。
- 测试:+12± (camp CRUD、归属链路、跨营地隔离 ×3、提案建队归属、兼容路径)。

## M5-1 崩溃恢复

- 启动 reconcile 领养:running 卡 → ready 续跑(现有 card_interrupted 语义收口);**提案 confirmed-无-missionId 自愈**(M4 评审遗留:启动时回滚为 pending 可重确认)。
- 安全作用域书签:工作目录权限持久化与恢复(重启后 file 工具不失效)。
- 验收:杀进程 → 重启 → 行动自动续跑到收营。

## M5-2 预算收尾线

- 预算耗尽三选(spec §13):提示用户 加预算/收现有成果/放弃;设置页暴露默认预算(propose_squad budget 缺省随之)。
- 全局并发节流(同时执行卡上限,防多营地并发失控)。

## M5-3 上下文压缩

- 长行动 usage 近窗口 ~75% 触发客户端摘要压缩旧轮次,复用相同 system/tools 前缀保缓存(spec §6.3)。

## M5-4 动效与可达性打磨

- Reduce Motion 全量审计(含 M4 新界面);TimelineView 低帧率与失焦暂停复查;多营地侧栏动效。

## M5-5 打包分发

- 正式 .app 打包(Info.plist/图标/签名),彻底解决「裸二进制不渲染文字」;`scripts/run-app.sh` 升级为分发构建入口。
- 验收:产出可双击分发的 .app。

## 实现顺序

M5-0(多营地,先做)→ M5-1(恢复)→ M5-2(预算)→ M5-5(打包)→ M5-3(压缩)→ M5-4(打磨贯穿)。
每步测试全绿才进下一步;UI 部分先补设计稿(侧栏 IA + 新营地弹窗)再落地。

## Open questions(待用户拍板)

1. C1 的「往期行动」收进营地首页(侧栏只留进行中)——OK?
2. C3 不做删除/归档——OK?
3. M5-3 上下文压缩工程量不小,若想早点收官可推 v2——保留还是推迟?
