# 牧场 UI 第二轮：草原滚动+路径行进、牛棚布局重排

Level 1-2。用户对上轮的反馈：① 草原页窗口矮时无法滚动；② 小牛动作僵硬、遮挡关系乱；③ 牛棚头图太高；④ 希望「可以学习的牛」在上、牛棚图在下。

## 允许触碰的文件（仅此 3 个）

`TaskRunView.swift`、`Components/CodingPastureTheaterView.swift`、`CodingRanch/CowRosterView.swift`。

## A. 草原可滚动（TaskRunView）

missionView 主体二选一处：`theaterMode` 分支改为 `ScrollView { VStack(spacing: 14) { CodingPastureTheaterView(...); artifactsView } }`（原参数不变），工作卡分支保持现状（cardList 自带滚动 + artifactsView 在外）。确保 ScrollView 内舞台仍水平居中、宽度跟随窗口。

## B. 路径行进系统（CodingPastureTheaterView，替换现有 pastureMotion）

废除 Lissajous 漂移，改「草点环线：走—停—吃草—再走」。全部仍是 `t` 的纯函数（seek-safe），TimelineView/paused 契约不变。

1. **草点环线**（每牛确定性生成，复用现有 fnv1a）：取 4 个位段随机数；第 k 个草点（k=0..3）：
   `angle_k = k*π/2 + (rand_k - 0.5) * 1.0`，`radius_k = (0.035 + 0.03 * rand2_k) * W`；
   `waypoint_k = slot + (radius_k * cos(angle_k), radius_k * 0.55 * sin(angle_k))`（椭圆压扁模拟草地透视），并用现有 inset（水平 56 / 垂直 60）钳制进舞台。
2. **时刻表**：步速 `v = 9pt/s * speedJitter`；每段 `walkDur_k = dist(wp_k, wp_{k+1}) / v`，段后停留 `pauseDur_k = 4 + 6 * rand3_k` 秒（吃草）。周期 `D = Σ(walkDur + pauseDur)`；`t' = (t + phaseOffset) mod D`（phaseOffset 由种子生成，错开各牛节奏）。
3. **位置**：t' 落在走段 → `lerp(wp_k, wp_{k+1}, smoothstep(progress))`（smoothstep = p*p*(3-2p)，起步/到达有缓动）；落在停段 → 停在 `wp_{k+1}`。
4. **朝向**：走段 = 行进方向的 x 分量符号（右行不翻、左行翻转，若 |dx|<1pt 沿用上一段朝向）；停段 = 保持刚走完那段的朝向。翻转仍加 `.animation(.easeInOut(duration: 0.3), value: flipped)`。基础奇偶翻转废除（朝向完全由行进方向决定）。
5. **步态**：走段 `bob = -2.0 * abs(sin(t * 7 * speedJitter))`（小跳步，只向上弹）；停段 bob = 0。
6. **状态权限**（不变式：状态说话）：
   - `idle / thinking / celebrating`：完整环线行进。
   - `asking / scratching`：停在 slot，`dx = 1.5*sin(t*0.8+phase1)` 轻晃，无行进。
   - `working`：停在 slot，`dy = 1.4*sin(t*1.7+phase1)` 点头。
   - `napping`：完全静止。
7. **遮挡排序**：每个 agentSpot 加 `.zIndex(当前实际 y 坐标)`（含行进偏移后的 y）——站得越靠下（近）的牛渲染在前。`memoryTrough` 加 `.zIndex(10_000)` 保持可点；`emptyPastureHint` 不变。
8. 名牌胶囊随牛整体移动（现有结构即如此）；dense 模式不变。

## C. 牛棚布局重排（CowRosterView）

1. **分区顺序改为**：页头 →（若有）「下一只可以学习的牛」解锁区 → 「已经在营地的牛」名册区 → 牛棚横幅图（移到最底部收尾）。
2. **横幅缩小**：`RanchArtView(kind: .barn, layout: .fit(maxWidth: 560))`，居中；上方加一行 `Text("牧场的一天，从牛棚开始。")`（caption、`Camp.inkSecondary`、居中）作为收尾语。
3. 其余（卡片样式、进度路径、错误面板）不动；`actionState` 失败面板仍紧跟解锁区之后。

## 验证

`swift build` 通过；`swift run RunTests` 基线全绿；impl-report 逐项映射。

## Open questions

（无）
