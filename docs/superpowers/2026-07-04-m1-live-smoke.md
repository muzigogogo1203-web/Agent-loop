# M1 活体冒烟记录（spec §15-5 硬门）

- 日期：2026-07-04（待执行）
- 前置：feat/m1 @ 04fb46e，`swift run RunTests` 68/68 绿，`swift build` 干净，应用启动存活验证通过
- 执行人：Muzi（需真实 Anthropic API key，产生真实费用）

## 冒烟脚本

1. `swift run AgentLoopApp`
2. 设置 → 粘贴 Anthropic API key →「已配置」出现
3. 新建伙伴：名「阿规」、颜色任选、职责「你是一位务实的生活规划伙伴，擅长把需求整理成可执行的清单文档」、模型 claude-sonnet-4-6
4. 私聊「阿规」：「你会怎么规划一次两天一夜的露营？」
   - [ ] 流式回复顺畅，头像 thinking 冒泡出现
   - [ ] 切走再回来历史仍在
5. `mkdir -p ~/Desktop/agentloop-smoke`
6. 单卡试运行：标题「露营装备清单」、说明「为两人两天一夜的秋季露营整理装备清单，按类别分组，标注哪些可租」、预期产出「工作目录里一份 装备清单.md」、工作目录 `~/Desktop/agentloop-smoke`、伙伴阿规 → 开工
7. 过程核对：
   - [ ] 流式转录实时出现
   - [ ] 「正在用工具：write_file / complete_card」状态出现
   - [ ] add_progress_note 的进展汇报出现
8. 结束核对：
   - [ ] 状态为完成（交接包 summary 显示）
   - [ ] 交付物条出现「装备清单.md」
   - [ ] 「在 Finder 中显示」定位到耐久存储文件（~/Library/Application Support/AgentLoop/artifacts/<card_id>/）
   - [ ] `~/Desktop/agentloop-smoke/装备清单.md` 原件也在，内容合格

## M1 验收对照（spec §16）

- [ ] 真实 API 完成一个单卡任务
- [ ] 产物可 Finder reveal
- [ ] 与伙伴流畅私聊
- [ ] 等待全程有活动指示

## 结果记录（执行后填写）

- 结果：
- 用时 / token 用量（run 表 tokensIn/tokensOut）：
- 发现的问题：

## M1 已知遗留（M2+ 归属）

- 上下文压缩、mission token 预算硬顶、每轮 120s 超时（暂依赖 URLSession 缺省）、多卡依赖、规划者、伙伴记忆沉淀、向导对话、营地笔记
- 运行中无「停止」按钮（取消机制内核已具备并有测试，UI 待接线，M1.x）
- ProviderError 面向用户的文案化（现为枚举插值，可见但生硬）
- `String: @retroactive Error` 建议 post-M1 换为专用 ValidationError 类型
- WebFetch：按字符截断非字节、重定向可降级 http、无显式超时（M2 网络工具强化一并处理）
- pause_turn 续接在启用服务端工具后需重审（M1 不可达）
- prompt 缓存在 M1 的短 system 下不会命中（低于最小可缓存长度），ContextPacket 变长后自然生效——冒烟时 cache_read=0 属预期

## 参考对照：loop-engineering（用户提供的开源参考）

https://github.com/cobusgreyling/loop-engineering 是「运营层循环工程」模式集（定时自动化循环、预算、失败模式目录），与本产品的每卡 Agent Loop 属不同层，但其失败模式目录与我们的内核设计互相印证：

| loop-engineering 失败模式 | AgentLoop 对应设计 |
|---|---|
| Infinite Fix Loop → 硬顶尝试次数+升级人类 | maxTurns 硬顶 + 三振受阻 + blocked 显式等人（§5.2-5） |
| Verifier Theater → 验证者必须真跑命令、独立于实现者 | 交接包强制 verification 字段（§7）；M2 评审判定独立化 |
| State Rot → 每轮重读状态、单一事实源 | level-triggered reconcile + SQLite 唯一事实源（§5.3） |
| Budget & kill switch → 超预算暂停+记录+开 issue | 三层预算 + 行动暂停三选（§13）；**全局 kill switch 采纳进 v2 清单** |
| L1/L2 自主级别分级 | v2 议题：按行动配置自主级别（报告制/协助制） |
