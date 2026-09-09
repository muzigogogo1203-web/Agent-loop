# 桌面 Coding 优化执行记录

**09-10 02:45 当前：Task3 与路径 A 全部实施并验证完毕；integration4 36/36 通过，严格 App 构建与 diff 检查通过；权威全量仍带 5 项历史负载敏感失败，均与本次改动无关。** 用户指示继续后采用路径 A：terminateProcessGroup 的两个宽限等待循环只容忍精确类型化 EPERM（僵尸窗口，视为仍在场继续等待），最终守卫保持严格、持久权限失败仍在完整宽限后报错。integration4（36 测试，32.448 秒，exit 0，源码前后不变）全部通过，两个 065 冷测试 cleanup-certified=true、无保留现场。权威全量 full1（1160 测试/33 套件/56.772 秒/exit 1）有 5 项失败：4 项 cliProcessBackend 就绪超时与 Board FD 计数差 32 均为 09-06 以来有完整记录的历史负载竞态（同签名出现在 combined/recheck/base 全量中），1 项 ruminationTerminalCommitFailure 单独运行通过（0.160 秒）且在全部四次历史全量中通过，属同类负载敏感波动；按治理规则不做无改动重跑求绿。EEC 套件在全量中整体通过（含 abort465、23 项分类器、两个冷测试）。严格 App 构建 exit 0（35.27 秒），git diff --check 干净。最终证据 runtime-spawn-cleanup-task3-evidence（25 文件+清单）。本单元（注册启动失败清理调和 + 真实中止证书 + 取消竞态修复）已可提交用户验收；历史全量就绪竞态与 A1/A2/产品/打包验收仍是独立未决事项。本会话未能提供职责分离的独立审查，已在验收材料中明示。以下为历史。

**09-10 02:35 当前：Task3 证书强化完成 RED→GREEN，真实 abort465 隔离通过；integration3 暴露一处新交互，已按停止规则暂停并定位根因，等待用户对修复路径做决定。** 分类器抽取与 23 项无子进程固定值用例先得到 12 处预期 RED（例外接受项 + 11 项原始成功但证明缺失/不匹配），修正后全部通过；Task1/2 冻结的 17 项助手回归字节不变、仍全绿。真实 abort465 隔离运行（exit 0，0.683 秒）恰好命中目标瞬时竞态——初 CONT 0、KILL 0、末 CONT -1/EPERM——生产助手完成三个实际 join 与最终消失确认后调和，证书 signalContract 与新增 spawnCleanupProofMatched 均真，登记撤销、根目录验证后删除、无遏制。integration3（36 测试）33 通过；075 失败系本会话 PATH 缺少 codex 所致（补 /Users/muzi/.npm-global/bin 后同测通过，非回归）；两个 065 冷取消测试失败为真实新交互——经审查的检查器 EPERM 类型化对齐使 terminateProcessGroup 在 KILL 后僵尸窗口抛出 typed EPERM，取消报错但随后直接探测证明 PID/组 ESRCH、waitid ECHILD、登记为空（生产存在同一潜在竞态）。证据已归档 runtime-spawn-cleanup-task3-evidence（14 文件+清单）；两个失败测试按自身设计保留取证根目录，进程已验证消失。修复路径（A：生产取消等待循环容忍瞬时 typed EPERM；B：回退检查器 processGroupExists 对齐）需用户决定，且本会话无法提供职责分离的独立审查。全量/严格 App/产品验收未进入。以下为历史。

**09-10 01:15 当前：已注册启动失败清理的 17 个固定回归全部通过并经独立验收。** 修复保留真实权限和失败结果，只有实际回收、双输出关闭及最终组消失全部确认后才能撤销登记。原测试字节不变，完整 30 文件证据归档。继续准备真实启动中止证书的生产报告检查，先做无子进程反例，再做隔离真实验证；尚未进入全量、App 或产品验收。没有需要用户决定的事项。以下为历史。

**09-10 00:42 当前：已用生产真实清理函数得到确定性 RED，进入修复审查。** 精确两文件提取及新测试经独立审查后编译通过；17个无子进程场景中15个在预定错误行为上失败、2个权限保护场景通过，所有测试自有任务均已等待回收，零脚本调用违规。原有测试及其他307项输入不变。完整证据已归档到 runtime-spawn-cleanup-task1-evidence；修复将只改变已注册启动失败的收尾判断，保留真实权限/结果错误。详见 runtime-spawn-cleanup-result.md。当前没有用户操作阻塞，尚未到全量/App/产品验收。以下为历史。

**09-09 11:00 当前：真实启动中止单项通过，组合检查收敛为一处生产清理竞态。** 新身份/所有权保护已独立验收，孤立 abort465 的完整直接证书全真、无紧急动作。20 项组合检查中其余 19 项通过，abort465 在 KILL 成功后收到 CONT/即时探测 EPERM，生产分支跳过内部 reaper/drain joins 并残留登记。后续 PID/组已消失不等于内部 join 已完成；完整现场保留。继续围绕该真实分支制定确定性回归与收尾修复，不扩大权限或忽略 EPERM，不重试求绿。详见 runtime-integration2-result.md。A2 的 M4/M7 接口补充计划已审查归档，实施仍等运行底座门；无须用户决定的事项。以下为历史。

**09-09 10:33 当前：错误计时阶段与异常收尾单元已完成独立 RED→GREEN，继续真实进程验证准备。** CLI152 计时只在已观测父进程标记后开始；原时间预算不变。启动中止 owner 的四类异常均由调用方完整收尾，四项原断言通过，原有受控等待/溯源两项回归通过，完整证据已归档。当前仅准备真实 abort465 的单一测试入口、准确身份留存及一次性安全收尾；没有运行新的真实 CLI 负载，也没有需要用户批准的普通事项。全量/当前 App/产品仍待验收；A2/A3 只读清单确认主要缺口是桌面组合而非重建已有管理功能。以下为历史。

**09-09 10:03 当前：实际启动信号、进度回调、结果读取三处同步阻塞已完成独立审查和 RED→GREEN。** 旧实现均稳定触发严格线程池救援；最小修复后同样的取消、结果、字节、EOF及资源回收断言通过。两组完整证据已归档。当前继续修正清理测试的错误计时阶段，并补启动中止测试的完整生命周期保护；没有等待用户许可的事项。真实进程集成、全量和当前App验收还未通过，不以局部通过替代。以下为历史。

**09-09 09:31 当前：清理错误溯源修复已通过独立代码和 RED→GREEN 审查，继续处理并发阻塞。** 新回归走真实启动校验/清理路径，但不创建子进程；旧代码仅因丢失原始错误失败，新代码保留主错误及准确清理原因后同一测试通过。完整24个证据文件已归档到runtime-cleanup-provenance-evidence。当前进入实际SIGCONT及065受控等待的同步边界修复；真实进程验证仍需完成新的完整生命周期保护。没有需要用户决定的事项，不重复运行未变化的失败负载，也不把局部通过当作应用可验收。以下为历史。

**09-09 01:41 最新：两处新的阻塞边界已用同样断言完成 RED→GREEN，整体验收仍未通过。** CLI能力检查完整同步操作移到专用线程并严格等待结果；OAuth测试等待不再阻塞需要启动的注册任务。旧实现两项分别因需要救援/等待超时失败，修复后两项通过，取消、原始错误和清理断言保持。原有13项集成检查仍有3项/6处问题：152超时、346未就绪、065的中止465清理原因被泛化且登记未清空。该中止进程的精确身份未持久保留，不能用后续冷测试的PID或证书替代；已停止后续进程负载和全量/App验证，下一步先补清理原因与身份留存。详见runtime-help-oauth-forward-progress-result.md；以下为历史。

**09-09 最新：原生 CLI 夹具定向验证通过，完整门禁仍未通过。** 依赖最小的 C 夹具、私有环境与进程登记、真实清理断言均已独立审查；定向11项通过。默认全量1133项/33组/46.077秒/exit1有三处CLI就绪失败。另一次获准的精确范围日志观测为五处问题（含347未KILL及一项HALT观察失败），不能替代全量。独立复核2562条事件确认三项CLI的后端任务在3秒等待预算耗尽后才进入（4.6766/9.2117/6.1980秒）；具体阻塞源仍需源码与针对性回归证明。没有延长超时、全局串行化、重复采样或产品交付；继续有边界的阻塞点排查。详见runtime-native-cli-fixture-result.md，以下为历史。

**09-08 最新：已修复并独立验证一处真实协作线程阻塞，产品仍未交付。** 阻塞进程等待移至独立线程；同一真实管道回归旧实现救援失败→新实现无需救援通过，取消后实际工作仍完整回收。新增两文件的精确后继登记遗漏已修复并通过独立复核，206/102历史清单不变。一次默认全量1131/33/45.325秒/exit1仍有CLI152/372/346/347和065就绪/清理失败；三项历史HALT本次通过。源码登记之后没有无改动重跑全量。详见runtime-forward-progress-result.md。接下来按runtime-native-cli-fixture-plan.md修复CLI夹具的登录环境、临时脚本和300ms持管道依赖，保留真实权限和回收断言；无新增管理员或用户数据操作。以下均为历史。

**09-08 最新收口：停止 gate 诊断补齐已完成独立复核，产品仍未交付。** 本轮只改两处诊断源码，305输入中其余303项不变；普通构建成功，唯一一次定向测试1项/0.240秒/exit0。保留日志的14个内部观测点通过检查，此前2.202秒停顿未复现，不能据此声称修复。采集器的100次身份轮询错过RunTests启动，原harness exit1/缺失live identity完整保留；独立审查凭既存PID、出生代次、受控wait、日志镜像UUID和时间窗口认可82条日志用于有限分析，后续仅对保留文件运行检查器，没有重跑测试或查询。最终独立审查fe50a9fc…通过本诊断单元，四个全量测试的五处失败及A1/A2/App验收仍未解决。详见`runtime-halt-gate-result.md`；本单元按单次观测边界停止，无新增管理员操作、营地数据改动或App交付。以下为历史检查点。

**09-08 本轮收口：三份独立分析已完整回读，尚未交付。** 已确认停止测试不是及时取消却被轮询漏掉：观察返回失败时，真正的消费任务取消尚未发生；内部gate开门返回后仍过2.202秒才继续。CLI152另有52.704秒登录环境调用区间，原因未明，不能套用CLI347的系统栈。审查保留P1额外缓冲文件范围未知/P2报告包含主机附录；精确删除已独立验证，不追认采集范围。下一单元限定为停止gate内部只记身份和时间的观测，并在独立方案/差异门后最多做一次普通定向测试；本轮未实施，不重跑全量或扩大管理员采样。证据与边界详见`goal-foundation-runtime-admin-observed2-result.md`。四项测试五个问题、A1/A2及App验收仍未通过；后文为历史。

**当前状态（09-08）：第二次诊断已完成，产品仍未到验收。** 诊断启动器完成真实 RED→GREEN 及独立入口复核；09-07 一次获准观测得到全量1130项/33组/92.866秒/四个测试五个问题/exit1，305输入未变。被采样的CLI347实际为`FixtureFailureStillJoinsRealCleanup`，本轮67.105秒通过；栈仅证明采样窗口在AppleSystemPolicy脚本评估等待，不能代替全部故障的根因。正在完成范围/时间线/停止链路的独立分析，详情`goal-foundation-runtime-admin-observed2-result.md`。系统工具额外生成的未知范围文件已获得单独删除授权，22:05:49精确删除并确认不存在，全程未读取内容；这不追认原采集越界。不会再自动提权、采样或无改动全量重跑；A1/A2、打包与真实App验收仍未通过。下文均为保留的历史检查点。

**新授权（09-07）：用户明确允许修正后再做一次同范围诊断。** Attempt2 限定方案已独立通过；无管理员权限的实际回归已复现旧 shell 桥接误判，正在做两文件最小更正。认证入口仍需 GREEN 和独立代码复核。旧 observed1 记录原样保留；新 observed2 尚未启动。下面旧授权耗尽的记录是历史，A1/A2 运行门仍未通过。

**09-07 当前：一次获准诊断已执行，但在启动测试前失败，授权次数已消耗。** 初始认证成功；诊断启动器只允许 `/bin/sh` 桥接进程，而系统实际返回本次 osascript 的 `/bin/bash` 子进程，因此安全校验拒绝继续。没有运行全量、采样或接触营地资料。collector exit93，osascript exit1，无信号；事后四个本次进程均已不存在。305 输入和可执行文件哈希未变。详见 `goal-foundation-runtime-admin-observed1-result.md`；已完整回读独立证据审查28c03a8d…，接受失败事实与证据完整性，不代表诊断或修复成功。不得自动重试；修正并再次诊断需要重新明确授权。A1/A2 和产品验收仍未关闭；下文为历史。

**当前停止点（09-06）：已获得真实子进程等待证据，下一步需要额外系统诊断权限。** 一次新增外部只读观测完成：全量1130项/33组/56.098秒/五个父级问题/exit1；305输入未变。三个CLI子进程各27个有效样本，约2.778秒内管道均为空、执行计数未推进，独立时序报告0c979b4d…与证据审查93f598a4…均已复核；这些测试失败不支持“已有输出在等读取”的解释，也还不能命名内核等待原因。本阶段未观测实际界面。仅针对本任务临时Ruby进程的spindump能力检查明确exit77要求管理员权限，没有提权或系统范围采样。详见 `goal-foundation-runtime-child-checkpoint.md`。暂停受影响路径并请求用户协助一次精确测试子进程的管理员级诊断；不再盲目重跑、不进入A2、不宣称产品交付。下文为历史。

**最新定位（09-06）：一次获批观测已完成，运行门仍未通过。** `goal-foundation-runtime-observed1.log` 为1130项/33组/48.217秒/exit1；五个父级问题分别是CLI347两项、CLI346一项、065两项。独立证据审查5512cfae…确认1997条事件全部属于实际PID83578和精确运行区间，305输入无漂移。独立时序分析8ba948ae…将边界缩至成功SIGCONT及读取任务入场之后、首个正字节之前；346/347直到EOF都没有正字节，372在约2.957秒读到。尚不能区分子进程执行与读取服务延迟，不据此修改信号目标、超时或并发。正在准备最小只读子进程状态观测；没有用户/资源阻塞，A2与产品验收仍封闭。后文当前状态均按时间作为历史保留。

**最新集成门（09-06）：A1 各功能微步骤已独立批准，但全量仍有真实运行失败，尚未验收。** 读取/删除34项、旧输入33项、成果18项、营地迁移13项均通过，独立实现审查及V17限定修正审查均无未决项。随后默认全量1130项/33组/53.406秒/exit1：只有CLI347主动失败清理用例产生两个主失败，原因链为就绪超时、TERM结束且未到KILL；实际清理观测无残留。305源码无漂移。严格App编译31.78秒通过，但不能抵消全量红灯。未修改CLI源码或超时，正在按 `goal-foundation-runtime-observation-plan.md` 审核一次现有日志观测；不进入A2，不重跑直到碰巧通过。

**最新（09-06）：读取/删除清理进入生产实现；迁移四项与补强测试准备已独立批准。** 迁移审查 `goal-foundation-migration-remaining-review.md` 无未决项。新增三项删除反例已应用并真实运行 RED；惰性第二操作改用 failed，防止仅清理 prepared 的实现漏网。34 项基础测试冻结于120fa1c0…，测试审查 b92a7557…关闭三个 P2，仅批准测试准备。当前唯一源码写入者实现实际读取、全操作清理及两条原有删除事务的非修复式重放校验。另有 V16 兼容运行13项中一项历史 V17 全局末尾假设失败；`goal-foundation-v17-checkpoint-amendment-plan.md` 已独立批准（6d31d784…），待生产写入者释放后由 root 仅修正该测试前置范围，原三项断言保留。V14九项、P1F1十六项通过；该批 P1D 未运行。没有用户或资源阻塞，整体交付仍未完成。

**A1 当前进展（09-06）：原子提交及精确源码清单已独立验收；读取与删除清理正在测试先行。** 原子提交修复后26项基础测试、33项旧输入回归通过；精确四文件登记GREEN并独立批准，历史206/102清单与哈希未放宽。新增读取/删除五项用例已运行真实RED：31项中旧26项通过、新五项51issues，缺失路径明确，生产读取/清理尚未实现。独立测试审查补出多操作行、仅操作泄露、跨输入安全回执三类反例，补强补丁已准备待应用。迁移四项检查现全部通过（含新增三项，PID77308，0.510秒，305输入稳定），正在独立复核。测试均使用隔离库，未改用户数据；完整A1/桌面/用户验收仍未完成。以下先前“当前”条目均为历史检查点。

**A1 当前进展：迁移、领域编码、正文修正均已独立验收到各自限定范围，正在实现原子提交与回执 CAS。** 正文修正14项、旧 P1-C 等103项及 P1-D18项均通过，独立 `desktop-text-validation-implementation-review.md` 无未决问题。随后原子提交新增九项测试，完整23项运行中旧14项通过、新九项在明确未实现入口出现预期 RED；独立审查补强了首次挂接另一输入回执的反例，单项 RED2 已实测。当前唯一源码写入者按原 A1 方案实现 journal/store 并提取 InputGoalStore 事务入口，测试冻结，尚无该实现 GREEN。读取、删除脱敏、剩余迁移/源码边界、管理界面及最终 App 仍待完成。运行基线1092项是 A1 之前的验收记录，不冒充当前新增源码全量结果。

**当前状态（09-06）：运行基线及严格 App 编译已独立验收，进入 A1 数据基础，尚未交付产品。** `runtime-provenance-full-review.md` 完整复核了默认全量 1092 项 / 31 组 / 57.278 秒 / exit 0，全部 301 个输入和 12 个重点源码前后匹配；两条负例错误均正确封闭在预期失败子进程中，主测试无失败。严格 App 构建 PID 61834，34.83 秒 / exit 0，同 301 个输入无变更。保留历史失败、停止时延的归因限制，不声称严格一秒内取消。运行入口门禁已解除。按既有获批 A1 方案刷新实际前镜像 `goal-foundation-entry-before/`，先进入迁移行为 RED；仅允许既定八个源码文件，编译测试由 root 串行持有。打包、真实隔离 App、主流程及管理优化仍待完成。

**最新状态（09-06约05:19）：默认全量1092项/31组已通过，正做独立证据复核与当前严格App构建；尚未交付。** 真实CLI清理错误覆盖已通过新增有意义断言、精确失败定位、独立源码审查及修复后069/065回归。最新无过滤 `swift run RunTests`：PID61158，57.278秒，exit0；全部301个Sources/scripts/package输入与12个重点源码前后相符，完整 `runtime-provenance-full.log` 与 `verify.log` 相同。两条内嵌红色输出是有意验证失败传播/泄漏检测的子进程负例，外层全部通过，正由独立审查确认。后面的资源与运行红灯记录是历史，不是当前结果。A1及产品主流程仍待本次门禁复核后进入。

**最新状态（09-06约04:56）：带标记的069和停止链路定向测试均通过，但尚不能解释历史失败。** 固定25行日志经独立审查后，普通编译58.59秒、069全场景10.408秒通过；生产取消代码未改，因此这只是未复现，不是修复。已准备的紧急停止补充观测也通过0.253秒，68条精确父进程事件待独立解读。下一步为CLI清理错误传递补充确定性回归，不能用跳过取消或重复跑绿掩盖问题。详情 `runtime-coro-diagnostic-checkpoint.md`。主流程/管理/App验收阶段仍未进入。

**最新状态（09-06约04:40）：普通编译与065两项测试已通过，069取消错误仍待定位，未交付。** 经独立实际差异审查，069被分为21个顺序场景；普通编译24.78秒完成，两项冷启动/强制失败清理测试17.702秒通过。随后069在0.480秒抛出CancellationError，不能清运行门。现有日志只定位到前段，正在按 `runtime-coro-failure-diagnostic-plan.md` 增加固定场景/消费任务join标记，不改取消或错误处理来假装修复。最新资源已改善至31GiB可用/pressure1；下方资源与编译阻塞表述均为保留历史。

**最新状态（09-06约03:36）：正在处理已定位的编译负载，尚未交付。** 用户改善资源后已恢复一次编译，但精确frontend出现24.1GB内存峰值。安全停止后，低风险pre-LLVM诊断完成，确认已有069大型测试生成216,814行IR/747挂起点；独立源码核对证明该函数未被本轮065修改扩大。另一次定点输出明确到达该069的CoroSplit入口。下一步只对其独立场景做保语义分解并审查，随后实测普通编译和运行；不是继续要求更多磁盘或绕过测试。完整证据见 `runtime-cold-compiler-checkpoint.md`。下方“再次资源阻塞”等描述是上一检查点历史，不是本次归因结论。

当前状态：再次停在真实资源阻塞，未交付。065 清理与停止前段诊断已实施并完成独立源码复核；首次编译出现三处新增断言宏错误，Fix2 已复核，但修正后编译时磁盘降至216 MiB、pressure4、24 GiB交换空间耗尽。仅终止并确认退出本任务编译进程，exit143，测试尚未执行。详见 `runtime-resume-resource-checkpoint.md`；源码和原红灯均保留，不重开已完成实施或绕过运行门。

- [ ] 执行稳定性根因与回归修复。
- [ ] 严格构建诊断清理并复核。
- [ ] 默认目标/共同理解/成果契约主流程贯通。
- [ ] 反刍、营地与牛的管理反馈收口。
- [ ] 全量/构建/兼容/隔离 UI/打包验证与独立复核。
- [ ] 交付用户验收候选。

已确认：沿用 `/Users/muzi/Agent-loop` 的完整 dirty 状态，以新 `codex/desktop-coding-closure-20260905` 分支工作，所有原有实现保留。现有基线测试六项失败，严格构建十三处诊断；不得将单独运行通过等同全量通过。

并行安排：`desktop_flow_design` 只读设计主流程；`strict_build_cleanup_design` 只读设计编译修订；`baseline_process_audit` 只读分析运行时根因。控制器唯一拥有构建/测试/OS采样。任何写代码任务获得独占文件范围后执行。

第一项诊断：当前源码与上一轮清单一致，使用 `swift run --skip-build RunTests` 做一次默认并发诊断，最多两次短 `sample`，不调整超时或并行规则。该诊断命令不是最终权威全量门；保留完整日志、二进制哈希与实际 PID。

## 已完成的实施检查点

- 严格编译：四文件十三处机械修正完成，`strict-build-verify.log` 记录 `swift build --product AgentLoopApp -Xswiftc -warnings-as-errors` exit 0。`strict-build-review.md` 独立审查通过，无 P0/P1/P2。相关运行回归仍随当前运行底座检查完成，未将其等同整包交付。
- 第一次采样诊断：`runtime-before.log` 是 1086 测试、7 issue、exit 1；采样扰动导致集合与原六项失败不完全相同。早期是数据库迁移工作，后期存在 cooperative 线程在 Board.stop 的 group.wait 等待；没有采到实际运行的 utility accept/drain worker。待验证假设调整为“任务已入队但尚未获得执行”，不直接断言线程池被阻塞读占满。
- `runtime-diagnostics-plan.md` 经独立复核，正在实施默认关闭的固定字段 OSLog 观测；不改队列、超时、FD 所有权或断言。控制器将先检查可采集性，再执行一次默认并发观测。
- `goal-flow-plan.md` 已形成并交独立审查；包含真实 coach、原子目标开工和 Outcome/验证桥接。此时没有改变默认入口或宣布主流程完成。
- `management-scope.md` 已核对既有管理合同，正在收敛成可实施子计划。永久营地删除能力仍封闭，不把归档冒充删除。

## 运行诊断已获得证据

- 观测代码一次编译修订后，`runtime-focused.log` 记录精确 075 用例通过（35.680 秒）；`runtime-focused-events.ndjson` 验证 OSLog 可读。独立 `runtime-diagnostics-review.md` 已复审通过源码修正。
- 随后一次 `AGENTLOOP_RUNTIME_DIAGNOSTICS=1 swift run RunTests` 默认并发观测：1086 测试 / 31 suites，57.259 秒，8 issues，exit 1。完整日志 `runtime-observed.log`；父 RunTests PID 85204，开始 23:16:14、结束 23:17:12。事件文件为 326 条父进程事件加日志工具统计行，不含子 RunTests 事件。
- 两条新 issue 来自同一个历史 A3 源文件边界测试：批准新增的 RuntimeLifecycleDiagnostics.swift 令目录枚举 103 而非 102。原历史 manifest 未改；将添加精确的本轮 successor 边界，不能删除哈希检查或排除整个目录。其余六项是原运行故障，CLI 两项在本次表现为 readiness 超时。
- 确定观测：075 的 stdout/stderr worker 入队后约 15.524 秒才真正开始，远晚于两次各一秒 join；Board accept 约 12.559 秒后才开始。独立根因分析正在形成最小修复。
- 主流程计划 `goal-flow-plan.md` SHA a17005f29899478ae2bbca5ce8ecf8334238d19a63423b16e0f1ab2750ce9428 已经五项具体修订后独立批准。运行底座门仍未通过，尚未开始主流程代码。
- 管理计划三项中 1/3 已批准，2 的失败/加载状态与恢复元数据契约修订正在复核。

- 管理计划 Task 2 修订已复核通过，三项计划均可在底座门通过后实施。
- `runtime-repair-plan.md` 与独立 `runtime-repair-plan-review.md` 批准四文件根因修复：native blocking workers、异步 Board stop、CLI 两处 await 清理、真实默认 fixture 与 stop 合同回归。全部期限与原 FD/错误合同保留。
- 测试入口附带事故：尝试 `.build/debug/RunTests --help` 并未显示帮助，反而运行整套测试；控制台捕获不完整且严重拖慢。该额外运行已在确认 PID 87877 身份、冻结后无子进程的情况下 TERM/CONT 停止。它不是门或正式诊断证据，不引用管道的 exit 0 为通过；今后不再探测未知参数、不使用 head 截断测试输出。
- Ruling: 当前批准的诊断新增文件采用单一路径的 dated successor 豁免 — 历史 A3 manifest 与 102 个未变文件哈希必须原样保留 — 若判断错误，新文件需要重新评审，不能扩成目录排除。实施详见 `source-boundary-plan.md`。
- 精确 successor 已由独立实施者完成，另一审查者正在对比单文件 preimage；四文件运行修复获得独占写入范围后开始实施。主流程 A1 正在从批准计划提取可单独验证的基础事务片段，没有跨越运行底座门。
- `goal-flow-plan.md` 的验证命令在批准后按真实 SPI runner 行为作单项勘误：移除 `--help`，使用已观测有效的 `--filter` 形式并保留完整输出。其余产品/数据/阶段合同未变。
- 运行修复四文件已完成；`runtime-repair.diff` 是 postdiagnostic preimage 范围差异，独立审查进行中。定向验证全部 exit 0：Board 12 测试/1 suite/7.811 秒（含新取消/错误/恢复参数用例），source sentinel 1/0.060 秒，CLI cancellation 2/1.983 秒，Shell timeout 1/0.776 秒，075 1/36.175 秒。完整输出为 `runtime-repair-*.log`。
- 新全量观测正在运行：RunTests PID 95860、23:44:33 开始，命令 `AGENTLOOP_RUNTIME_DIAGNOSTICS=1 swift run RunTests`，保留完整输出和父进程事件；未将定向通过视为底座门完成。
- `goal-foundation-plan.md` 已经独立批准，只提取 A1 持久化/事务/删除脱敏与历史门适配；主流程尚未实现。`package-plan.md` 两脚本 helper/不覆盖产物方案已独立批准，尚未实施。
- 全量 PID 95860 在 23:44:59 exit 137，未完成，底座门继续为红。已保留 full log、62 条父进程事件和 macOS crash。crash 明确为 EXC_GUARD / FD CLOSE：旧 075 fixture 在 `dup2`（CliBackendTests.swift:3190）覆盖了已被他方重新使用的 guarded fd 304，内核 SIGKILL；不是内存不足推断。先修测试资源隔离和无覆盖式 sentinel 占用，不重跑危险全量。
- 同一次未完成运行的有限事件显示六个 drain worker 实际入场 67.750–263.750 微秒，Board accept 28.166 微秒；仅证明这些已采到的入场改善，不代表全量通过。五文件源码哈希在运行后逐一匹配。
- 残余 FD 用例只读诊断期间，独占写入者先实施已批准的两脚本打包修复（不运行脚本、不构建、不启动 App）；主流程/管理代码仍等底座门。旧 App 可执行文件哈希已保存。
- 两脚本修复已完成，父控 `package-argument-check.log` 记录 17 项 syntax/参数/Swift-stub 检查 exit 0，旧 App hashes 仍一致；没有实际 Swift 构建、签名或启动。独立源码复核进行中，真实打包门仍待后续。
- `runtime-fd-fixture-plan.md` 经父控独立审查及两项 FD 继承/完整子日志修订批准，目前唯一源码写入者实施 CliBackendTests.swift 一文件修复。preimage/hash、计划/复核/brief 已保存。修复前不再运行不安全的 075 全量 fixture。
- `runtime-residual-io-map.md` 是剩余 Shell/CLI 候选边界的只读地图，没有选定生产修复；只有后续完整运行仍失败时才按归因证据启用。
- `ui-direction.md` 依据已批准方案与现有 Theme 保留像素牧场，收敛行动/状态/管理层级；尚未改 UI 或执行视觉验收。
- 新 FD 隔离两项定向测试 `runtime-fd-fixture-focused.log`：2 tests / 0.217 秒 / exit 0。嵌入日志中的 deliberateChildFailure 是负路径子测试的预期失败，不是外层运行失败。独立审查发现 closed-stdio 子运行在关闭 stdio 之前重复执行 composition，导致第二份 FD 子证据被 `/dev/null` 吞掉；批准仅普通父运行执行 composition 的一处 guard 修正，原 0–9 覆盖及实际 closed-stdio 探测断言全部保留，实施者正在修正。
- 打包路径字面量回归已由有效 RED 转 GREEN；`package-fix1-verify.log` 同时保留两条反斜杠路径测试和 17 项原参数/stub 检查，exit 0。两份旧 App hashes 再次匹配。源码独立补审进行中，尚未实际构建/签名/打包。
- FD Fix 1 与打包 Fix 1 均已独立批准。`runtime-fd-fix1-focused.log` 记录 3 tests / 51.105 秒 / exit 0，正常 FD 子进程 PID 7934 raw status 0，完整日志和三个阶段标记均被保留。
- 下一次默认并发全量 `runtime-base-full.log`：父 PID 8499，00:19:55–00:25:57，1089 tests / 31 suites / 353.036 秒 / 22 issues / exit 1。正常 FD 子 PID 9248 通过（3.077 秒）；预期失败子 PID 8795 正确回传。三者 2069 条生命周期事件加工具统计行已保存；六个源码 hashes 全部匹配，未再发生 guarded-FD crash，但底座门仍未通过。
- 该轮全量期间主机为 16 GB RAM、约 16.7 GB 已用 swap、VM pressure level 2；结束后仍为 level 2、约 16.6 GB swap。记录在 `runtime-base-resources.log`。这解释了需要单独考察的环境条件，不证明全部失败都由环境造成。已非阻塞请用户关闭暂不用的应用；不擅自结束其他进程，不在环境未变时重复整套测试。
- 确定性新失败是 A4 历史脚本校验仍要求已批准修改前的 run-app.sh hash。独立源审确认后批准 `package-historical-gate-plan.md`：保留原 105 项历史分组，划分 104 项原 hash + 1 项固定当前已审 script hash；不改原 manifest 或 A3。
- A2/A3 只读接口复核另发现待明确的真实边界：OAuth Provider 忽略 maxTokens，Provider 内部重试与八次调度计数不同，三处 Provider raw-error 日志需要源头脱敏，重启一次恢复不能遗留尚未过期 lease。A1 未受这些接口问题影响；主流程仍未实施，不能从适配器吞掉这些不一致。
- `runtime-base-analysis.md` 独立解析全量事件：六个隔离 drain 全部结束；140/140 Board accept 进入，median 2.839 ms、max 71.724 ms。两名 accept owner、两名 CLI finalizer 的结束证据不完整；不能将已改善的启动等同全部清理通过。现有日志还不能把 CLI readiness 失败映射到具体启动/读取/消费阶段。
- 实测并确认三次本任务全量留下的 CLI 测试 shell：PID 78055（22:44:03，c-346-D502）、85371（23:16:44，c-346-EBF7）、10332（00:24:40，c-346-B200）。均为 PPID 1、同值 PGID、精确临时 workspace、源码中的 TERM-ignoring ready 循环。首次清理前身份检查因 ps 日期尾随空格而失败，未发信号；修正空白规范化后逐一复验，`runtime-owned-test-cleanup-verified.log` 记录只对这三个 PID 发 SIGKILL，exit 0。随后三个进程组与对应循环均不再存在。没有删除文件、结束其他 App 或操作营地数据；这不代表主机内存压力已解决。
- CLI 测试失败分支缺少 checked cancel/join 已由独立源码检查与上述真实残留共同证实。限定 test-only 清理计划正在形成，不声称它就是最初 readiness 超时的原因。A4 singleton 修正已实施，正在独立复核和 focused 验证；不重跑环境未变的全量。
- A4 修正已独立批准且真实定向验证通过：`package-historical-gate-focused.log`，1 test / 2.914 秒 / exit 0（编译 197.14 秒）。当前 DurablePlanningTests.swift SHA 56b504731d1bff1432e36c82289c1013df033d1dd383c7fc7b5318ca3e6ff06b。此前保存的 A1 preimages 早于此项合法变更；真正进入 A1 前须以当时当前源码重新建立独立 preimage，不把本轮已审 A4 差异混入 A1 审查。
- CLI test-only 清理计划经父控独立复核后已实施，当前 CliBackendTests.swift SHA 74c53a9b1769db189663d65d595b0c8d9279f9e58a71af687df053953498e933。693 行 scoped diff 由父控完整检查，独立源码审查 0 P0/P1/P2；原 075 后缀 124,016 bytes 未变，readiness 方法逐字未变。
- `runtime-cli-fixture-forced.log`：编译 85.33 秒，新增真实 afterReady 主动错误回归 1 test / 1.861 秒 / exit 0。实际 PID 18710（c-347-CDCA）的 TERM/KILL/reap/EOF/exited 及非消费式进程/组/回收/socket 观测通过，无清理错误。
- 重要新证据：原两项取消测试现在在**定向并发运行**即可重现 readiness 失败，无需另一轮全量：`runtime-cli-fixture-cancellation.log`，2 tests / 3.575 秒 / 2 issues / exit 1。PID 18904（346）和 18905（372）均已真实完成清理，resource observations failures=0，保留的唯一失败是原始 process did not become ready；功能断言未到达，不能宣称完整修复。grandchild 定向验证另行进行。
- 因出现可单独复现的窄边界，下一步只制定 opt-in CLI 启动/等待回收/读取/recorder 时间戳计划，随后做一次带身份映射的定向观测；不是在原内存压力下重复整套测试，也不是直接把 waitpid 改线程或猜测硬件原因。主流程/管理/候选交付门继续未通过。
- `runtime-cli-fixture-grandchild.log`：1 test / 0.642 秒 / exit 0，实际 PID 19263、资源观测 failures=0，随后只读检查 PID/组均不存在。它与主动错误回归通过不抵消原取消 pair 的 readiness 失败。主机压力仍为 level 2（新快照约 15.2 GB swap），没有重复全量。
- 三文件默认关闭的 CLI readiness 观测经父控完整差异检查及独立复核批准（0 P0/P1/P2）。唯一配对观测 `runtime-cli-readiness-focused.log`：编译 69.84 秒，2 tests / 1.260 秒 / exit 0；父 PID 21212，01:16:28–01:17:44（含构建），104 条生命周期事件加统计行，三文件 hashes 全匹配。
- 实际身份链完整：recorder 5E901… → execution 346 → continued PID 21998 → Core EB62…；recorder 6DC53… → execution 372 → continued PID 21999 → Core 7486…。两组启动/读取 worker 都在微秒量级入场，首字节约 583/998 ms，就绪约 607/1014 ms；资源检查均 0 failure，之后 PID/组不存在。本次诊断代码未改行为，不能据此解释或抹去前次 readiness 失败；独立时间线报告正在生成。
- 此时主机 VM pressure 已从连续 level 2 变为 level 1。将保留新的运行前资源快照后执行一次带新身份观测的默认全量；这是环境已变化且具备新增诊断的验证，不是在相同压力下循环重跑求绿。仍保留所有旧红灯证据，不跳过或延长测试。
- 新全量 `runtime-recheck-full.log`：父 PID 22458，01:20:41–01:21:44，1090 tests / 31 suites / 61.428 秒 / 3 issues / exit 1。七文件哈希逐一匹配；正常 FD 子 PID 22528 通过 3.066 秒，预期负子 PID 22524 正确失败；完整 2433 条父/子事件加统计行保留。运行前/期间压力 level 1；旧 22 项问题不能因此被称为逐项代码修复。
- 三项剩余问题：停止顺序测试的一秒取消观测、Board 20-loop 的进程全局 FD delta 35、CLI 346 readiness。CLI 152/372/347 通过，四个执行的资源观测均 0 failure，实际 PID 22634/22641/22643/22645 及进程组随后均不存在。
- 346 实际 run 入场约 110 ms，stdout reader 在就绪计时约 460 ms 已进入，但三秒超时前后都未记录正字节；同命令 347 reader 约 464 ms 入场、2.781 秒收到 ready 并通过，不能把两者差异简单归因于 reader 入队延迟。下一观测只补退出/信号来源，尚不改生产调度或猜测 shared registry 干扰。
- `runtime-halt-focused.log` 记录同一停止顺序用例定向通过（0.374 秒，exit 0），未将其视为全量修复。将补最小真实取消阶段标识，保留原一秒观测期限。
- Board 两项 FD 计数用例虽所在 suite 已 serialized，计数仍覆盖其他并发 suite。独立的 `runtime-board-fd-isolation-plan.md` 经父控完整审查批准：复用已审 075 子进程所有权机制、每个原始 20/100-loop 用例单独进程、全部期限与 <10 断言保留，再用真实持有 32 FD 的负子证明断言仍有效。两文件唯一实施者已进入；这是测试归因边界修正，不宣称发现或修复生产泄漏。
- Board 隔离两文件实现已完成；父控完整 scoped diff 与独立复核确认原 20/100 循环及 075 关键前后缀逐字保留。`runtime-board-fd-focused.log` 六个命令全部 exit 0：075 FD 2 tests / 0.133 秒；完整 075 1 / 33.536 秒（内层 drain 3.043 秒）；真实 32 FD 负子对应外层 1 / 2.505 秒；20-loop 1 / 2.534 秒（子 2.392 秒）；100-loop 1 / 0.488 秒（子 0.336 秒）；A3 1 / 0.049 秒。初次编译 19.57 秒。
- 原 20/100-loop 子进程各自 baseline=4、final=4、delta=0；负子 PID 26564 的 baseline=4、final=36、delta=32，原 <10 断言失败且 20 次完成证据存在。独立源码审查指出负向 oracle 仍可能接受证据写入后异常终止；按审查接收流程核对后批准单文件 Fix 1，追加正常 exit(1) 原始状态及完整单测试/单 suite/单问题结束摘要检查，不变更生产或正向测试。当前仍待该项补验与源码再审。
- CLI 信号诊断与停止阶段诊断两个有限计划已分别完整审查批准，处于排队状态；必须在当前源码/构建所有权释放后依次取新 preimage 实施。前者只记精确 signed signal target/result 和已 join 的退出证据；后者分离停止请求、持久化、runtime 取消、Provider 回调与 actor 观察。不改变任何原期限、顺序或异常传播。不会在这两个观测完成前重复全量。
- Board Fix 1 独立再审关闭 P2，当前 BoardServerTests.swift SHA 87b370af82e4ae273e6793ac9d655efcd72c8be5a1f41913430943a85ed86240；`runtime-board-fd-fix1-focused.log` 三项命令均 exit 0：负向外层 2.461 秒（子 PID 28742、raw256、delta32、完整单问题摘要），20-loop 2.491 秒（子 28755、delta0），100-loop 0.482 秒（子 28767、delta0），编译 19.52 秒。限定 Board 归因修正完成，完整并发门仍需后续验证。
- CLI 信号观测已在上述源码与构建释放后进入实施，新 preimages/hashes 保留 post-Board 的 CliBackendTests.swift（8dd4c162…）；停止观测继续排队。没有还原旧规划快照、重复旧任务或把测试测量修正当作产品交付。
- CLI 信号观测三文件实现已由父控完整 scoped diff 检查、独立 `runtime-cli-signal-review.md` 批准；尚未编译或取得实际信号证据。停止阶段诊断已在新的 post-signal preimages 上进入三文件独占实施，不能与构建并发。
- 主流程输出限制作限定产品决策：保留现有 OAuth 路径，API 使用协议请求值 4096，OAuth 如实标为 provider-managed；八次保守应用发起次数、隐私/未知用量继续确认、120 秒客户端期限与真实 join 均保留。三份计划/brief 的完整差异已由父控独立批准，详见 `goal-output-policy-plan-review.md`。未改 SQL/源码范围，A1 仍未开始，旧统一上限的草案不再是有效实施要求。
- 停止诊断三文件独立审查通过。`runtime-halt-diagnostics-focused.log`：1 test / 0.270 秒 / exit 0，编译 128.68 秒；父 PID 33126，完整 46 条事件与真实五角色身份关联，九文件哈希匹配。独立报告确认计数在观察开始后 7.808 ms 写入，早于实际 planner 放行；不是旧失败根因或修复声明。
- 唯一新组合全量 `runtime-combined-full.log`：父 PID 33956，02:09:14–02:10:18，1091 tests / 31 suites / 63.440 秒 / 4 issues / exit 1。九文件前后 hashes 匹配，3293 条父/五个 owned FD 子生命周期事件加统计行保留。Board 正向两子通过、负向子准确测得 32 FD 且外层通过；075 子通过。真实外层失败为 halt 观察、CLI 346/372 readiness、065 cold-gate readiness；四条 mechanics cleanup 均零失败。
- 全量 halt 独立归因：实际 consumption.cancel 比观察返回 false 晚 49.182 ms；主要未分解边界是 coordinator 调用到取消持久化入口的 863.437 ms，不能归为仅 actor 计数迟到，也不能直接猜数据库/线程池。CLI 精确 signal UUID 归因显示失败两组只有成功 SIGCONT 和超时后 fixture TERM；捕获中无 shared path-2 调用，不据此改私有 registry 充当就绪修复。详见两个 `runtime-combined-*-analysis.md`。
- `runtime-cold-gate-analysis.md` 确认另一 test-only 生命周期缺口：065 的 readiness throw 跳过 explicit cancel/join，defer 过早关闭/removes harness；这是独立清理风险，不是已证明的启动根因。候选 owner/PID 34193 已回收，但无直接 fixture 身份关联、无 Board stop 完成证据；不能用历史 PID 或猜测路径授权清理。未实施新修复。
- 只做一次窄 CLI pair + 两次精确新子 PID 的一秒只读 sample：`runtime-cli-child-probe.log` 2 tests / 2.217 秒 / exit 0。PID 35315/35316 的样本均为 `_dyld_start + 0`，随后正常 ready/取消/零清理失败；样本只说明该次经过了可观测启动等待，不证明前次失败根因。没有重复全量或改期限。
- 02:17 左右资源进一步降为仅 1.2 GiB 可用磁盘、pressure 2、swap 已用 18302.88 MiB。停止新的构建/测试/源码实施，保存 `blocked.md` 外部资源检查点。不是产品交付；A1/管理仍未开始，所有已做修订和红灯证据保留，不擅自关闭用户 App、删除缓存或操作真实营地数据。
- A2 `goal-driver-plan.md` / preparation report 已交付，SHA 7eed55faf2fde3a87460c5914977faa948607a581b58d6edf7ae02f31f81966d；尚未独立审批，不是执行授权。计划作者已释放文档所有权。父控保存最新全量完整输出为 `verify.log`（与 `runtime-combined-full.log` hash 相同），恢复时从 `blocked.md` 接续，不重做已完成边界。
- 续接：父控完整读取 A2 的 385 行计划，独立 reviewer 正对实际接口复核；另两名纯文档作者分别准备最小 065 test-only 生命周期修正和两文件 halt 前段观测。尚无源码写入者或 Swift 运行，计划未批准前不实施。保留所有旧红灯和源文件变更归属，不重新启动已完成任务。
- A2 独立计划审查通过，0 P0/P1/P2，`goal-driver-plan-review.md` SHA cf10969b76625430d973987a39bc97a7c4a5b3caa51cf0dd41bc53b316500c6f；19 个检查输入哈希未变。仅 Core 计划审批，不是 A1/A2 实施或 App 生命周期门通过。
- 065 清理计划 SHA 31d584d898287d64201e84c414c71dc57510e498043874586ef32d0f8f04fb0c 与 halt 前段观测计划 SHA d2bbfb807d6e5a03c4aea29247e5291d11feab3f75dc7ff397b43e1d5789f621 均经父控完整独立审查。前者限定一个测试文件、保留冷 stream 与原期限、用真实强制错误验证完整清理；后者限定两个 Core 文件同步诊断插入，不调整停止顺序。已建立各自 SDD ledger 和 fresh brief。065 单一实施者获得源码所有权，控制器不同时运行 Swift。
- 续接实施收口：065 单文件改动、Fix1 就绪/信号记录发布顺序与 Fix2 三个显式 Bool 宏输入，均已独立源码复核；halt 两文件补充观测也独立批准，默认关闭、原异步顺序保持。初次编译 exit1（未跑测试）；修正后编译因磁盘216 MiB、pressure4、24 GiB swap耗尽，核实身份后只 TERM 本任务编译树，exit143（未跑测试）。全部原始日志、前后十文件哈希和停止审计保留。03:11:39 磁盘335 MiB，全部编译 PID 不在、哈希一致、git diff --check0。没有新全量、halt事件、App包或真实营地操作；用户需腾出磁盘和减少内存占用后，从当前验证检查点恢复。
