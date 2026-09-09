# P0 真实 App UI 观察

> 时间：2026-07-25 11:21 PDT
>
> App：`com.muzi.agentloop.dev`
>
> 进程：`.build/AgentLoop.app/Contents/MacOS/AgentLoop`
>
> 模式：normal；实际打开 `/Users/muzi/Library/Application Support/AgentLoop/agentloop.sqlite`
>
> 方法：macOS Accessibility tree + 同步屏幕截图

## 1. 保存证据

- `current-live-app.jpg`：当前任务工作卡界面
- `current-live-home.jpg`：我的营地主场
- `current-live-pasture.jpg`：真实 Coding 草原

这些截图包含本机测试任务的文字内容，只作为私有 P0 证据保存，不得因后续 commit、PR 或发布动作而自动公开。截图证明当时 normal App 的可见状态，但不单独证明运行二进制严格对应某个 Git HEAD。

## 2. 已证实

### 2.1 窗口与导航

- 真实窗口标题为“Coding 牧场”；
- Sidebar 可见我的营地、进行中任务、发起放牛、回营成果、牛群、新牛和设置；
- 我的营地主场可实际打开；
- 进行中任务可在“工作卡”和“Coding 草原”间切换；
- 本次只切换导航与视图，没有提交、接受、重试、续预算、收哨或修改设置。

### 2.2 我的营地

活体界面可见：

- “管家与工具”“笔记”“牛棚”“驿站设置”；
- 统一文字投喂入口；
- 当前待处理摘要；
- Coding 草原任务入口；
- 以“喂牛并收进营地 → 从资料开始放牛 → 得到真实成果 → 验收并回营”为表述的新手任务；
- 最近营地笔记。

### 2.3 当前任务

真实任务不是 fixture：

- 标题为“创建‘减肥大作战’ HTML 应用”；
- 3 张工作卡中 2 张完成；
- 2 件可见回营成果；
- 当前累计约 473.6k / 400.0k tokens，任务因预算见底暂停派发；
- 第三张工作卡显示受阻，可见网关响应中断和超预算历史；
- UI 提供续预算、重试、就地收成果、放弃和收哨入口。

这证明失败与预算阻塞能被展示，但不证明其根因、恢复和 durable closeout 已完整正确。

### 2.4 Coding 草原

活体像素世界可见：

- 两头牛和一份营地知识；
- 牛的标签与真实工作卡关联；
- 一头牛处于悠闲待命，一头牛处于回头复检；
- 回营成果与远征报告和工作动态同源显示。

这证明当前像素世界已读取真实任务投影；单次截图不能证明动画长期不漂移、重启恢复或所有状态映射都正确。

## 3. 不能由本次观察证明

- Feed 提交、URL/文件真实摄取和反刍成功；
- App 内 ChatGPT OAuth / OpenAI API 请求成功；
- Codex/Claude CLI profile 在牧场中完成工作卡；
- 成果真实查看、独立验证、用户验收和知识晋升闭环；
- 预算续充、重试、收哨、取消和 App 重启后的耐久行为；
- preview、clean-install onboarding、打包 App 或另一台机器的运行行为。
