# P1-A1a Durable Work DDL + Store — Independent Implementation Review 01

> 日期：2026-07-26
>
> Reviewer：职责隔离的独立 implementation reviewer
>
> Verdict：**APPROVED — 0 P0 / 0 P1 / 0 P2**

## 1. 身份、职责隔离与权限边界

本 reviewer 未参与 P1-A1a 的 Stage、总 Plan、leaf Plan、R9 修订、实现、测试、
runner、验证日志或 implementation report 的编写，也不是 acceptance owner。

本次唯一 repository-authored 写入是本报告。审查没有修改实现、冻结输入、
`verify.log`、`build.log`、`impl-report.md`、截图或 acceptance；独立验证只产生
SwiftPM 忽略的构建产物。本文不判定 A1a acceptance，不授权 A1b、P1-E/v16 或任何
其他产品代码，不授权 commit、push、merge、release、数据重置、付款、公开沟通、
外部操作或真实用户操作。

2026-07-26 的 follow-up 仍只更新本报告：reviewer 对 implementer/planner 完成的
截图 evidence hygiene 与可变 control index 状态收口做只读复核，没有代写或修改
这些输入。

审查对象：

- branch：`codex/personal-ai-ranch-p0`
- HEAD：`02334ec8d21533be81d93d39191bc7d9b9c24f7f`
- 当前 worktree 含 Review09 已记录的既存 P0/spec 文档差异；本 review 只把十个
  leaf-authorized implementation/test 路径及本 task evidence 判为 A1a 范围。

## 2. 权威输入与 SHA-256

| 输入 | 当前 SHA-256 |
|---|---|
| `AGENTS.md` | `046010f8f693130aa7b0dd7b3727d5ea3370705051fbc0433bd981dab084b242` |
| master spec | `79c266fccccbc6383cfc4cd528b22a39a55a6dc829c0250e3702ace2b8f55ad1` |
| frozen P1 Stage | `330dfd6de888e3cca14927cb9d82d5d4b1e1b7057b2814736fa923e2a2df0190` |
| frozen P1 Plan | `19e57761a9da3b11905ce72cb40e0e5c1a7bbcec1cb5f9462ef1cb1260da6ee3` |
| frozen A1a leaf Plan | `4fc04f2c6c7a3dd67db71874f7d86807fa7882d566a64fe76c60cb3722593deb` |
| mutable P1 Stage control index | `94f68b0a25d9a131edf76f99e4e7f8a1df619af1c2d2c2cd0442c9f5d423b0f9` |
| mutable P1 Plan control index | `102785cfd54a569a3c39afe36902267084ff6626fdc18709ab00b714bbf2c208` |
| `blocked.md` | `1270398a0eef34ed0835bf43a4de14ea653455ce76caca7acf1b6d7e38d2c7f7` |
| `impl-report.md` | `af785077a86a1f29f35d8bfc5c2214495cbb8c09101f99bacab6df6871ceb7b6` |
| `verify.log` | `cad9c8e643b96a09ab5718eb1b15837858f6f97b09107938b6f609fba1cec6f8` |
| `build.log` | `ebd5798549217ddbaee5408d801d8ae2f9216d906bd77961fd81f1ce72edc549` |
| `preview-smoke-source.jpg` | `da658118bf3d3e5e18a288a71c7ac56297dca46b4738003e1ba6ad1a4899419c` |
| `preview-smoke.png` | `90ae69421b6a0be472e5ba22afacb6279b16e2838df75ee13d285e384e3648c8` |
| Review09 | `392489e4f64c7a9ed9813e814654dcb746cce5a288ddae15a009d20f6884145e` |
| `Package.resolved` | `d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a` |

三份冻结执行输入精确匹配任务给定 hashes；Stage/Plan Open Questions 均为“无。”。
Review09 明确以 0 P0 / 0 P1 批准 R9 规范闭包恢复 A1a v12 实施，同时保持
acceptance、A1b 与 v16 关闭。

两个顶层 P1 文件明确自称可变执行控制索引，不是冻结 Stage/Plan。当前索引、
`blocked.md` 与 `impl-report.md` 一致记录：Review09、Review01 已通过；A1a 尚未
Accepted；当前唯一下一门是独立 acceptance owner；A1b 继续关闭。它们没有改写
冻结 schema、契约、范围或执行顺序。

## 3. 审查范围与 scope 结论

当前 A1a implementation/test 范围精确为 leaf Plan 授权的十个路径：

| 路径 | 当前 SHA-256 |
|---|---|
| `Package.swift` | `577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d` |
| `Sources/AgentLoopCore/Database/AppDatabase.swift` | `faf98fa6b1f252d0e58bd463b46cbdc98753324a880357901aeaca07361756ac` |
| `Sources/AgentLoopCore/JSON/CanonicalJSON.swift` | `7b14b628b14e8f10854116d029bbb7af480a3f9f2c7f5562ad8daae764113b79` |
| `Sources/AgentLoopCore/Work/DurableWork.swift` | `694e922ef582ea1551dfcb78ec7544a191967dda980a4f2b82852fa62b20bbb2` |
| `Sources/AgentLoopCore/Database/DurableWorkStore.swift` | `68098d8e4f977a3591826772a737f2e67a2070f1eebf5fa8d18b8172b192f07b` |
| `Sources/P1MigrationMatrixRunner/main.swift` | `dddd1ef320ca591493387f7f90f9be4d1b663f141821fd9bc6e80f49551bf8c5` |
| `scripts/verify-p1-migrations-sqlite-matrix.sh` | `41777ea24e60914734fa4e9c2fbe9bd334cf2bcd1dbbd9abd10494984d470c56` |
| `Sources/AgentLoopTestSuite/DatabaseTests.swift` | `bb35ad60d06e418afe62f261493535a57545a7fb37dda2db049a763150ea6c56` |
| `Sources/AgentLoopTestSuite/CanonicalJSONTests.swift` | `433184d3ed3f270a424d748240252fc4c2c7928480e96a31370589465ee1dfe7` |
| `Sources/AgentLoopTestSuite/DurableWorkTests.swift` | `cc7a14046193664e7d9886ead85e8a185a4ae2bad409c359fcb5bcf7d874bbaf` |

与 Review09 保存的实施暂停点 fingerprints 比较，六个路径未漂移；变化只发生于
获授权的 `AppDatabase.swift`、`DurableWorkTests.swift`、runner 与 matrix script。
将 `AppDatabase.swift` 三组 R9 `COALESCE` opener/closer 逆转后，SHA-256 精确恢复
Review09 baseline
`aa063159902ec27832a91dad5c70b4d6881517847c2a8d46a9134733f356aca0`，
证明该文件没有夹带其他 post-Review09 改动。

`Package.swift` 只增加 test-only `P1MigrationMatrixRunner` target；没有 product target
依赖它。`Package.resolved` 与 Review09、matrix 前后及本 review 当前复算完全一致。
十个路径中没有 v16 migration、provider-dispatch、A1b supervisor/resolver、Schedule
schema 或 App/Planner/Orchestrator/Rumination 产品接线。

post-review evidence/control 收口后再次逐项复算，十个路径仍与上表及初版 Review01
完全相同；本 follow-up 没有实现、测试、runner 或 matrix script 漂移。

## 4. 实现与 frozen 契约审查

### 4.1 v12 DDL 与 R9

- Stage §18.1 的 187 行 SQL literal 与
  `AppDatabase.swift:423-609` 去除 Swift 固定缩进后逐行、逐字相同；literal
  SHA-256 为
  `fb77180d6edd44413e41179e4b220666438e2660de11fbde1dafee78b6fde5c2`。
- 当前真实 migrator 只追加 `v12-p1-durable-work`；三处 v12 diagnostics matrix
  分别在 `AppDatabase.swift:477-494`、`:533-545`、`:575-592` 使用
  `CHECK (COALESCE((...), 0))`。没有实现 Stage §18.6 的三处 v16 wrapper。
- 三表、五个显式索引、attempt-event introduction-time UPDATE/DELETE guard pair 与
  `schedule_fire` 排除均符合 frozen DDL。

### 4.2 CanonicalJSON 与 DurableWork Store

- typed/raw 两条路径汇入同一个 private byte-backed parser/AST/serializer；key/string
  使用 decoded UTF-8 bytes，number 保留 raw token，object 保留 pair array。
- 实现未引用 `JSONValue`、`JSONSerialization` 或 raw `JSONDecoder`，未新增第三方
  dependency；UTF-8、surrogate、decoded duplicate key、byte-order key、RFC number、
  token/coefficient/exponent/output bounds 与 SHA-256 lowercase hex 均符合 §5.1。
- `DurableWorkFailure` 固定四 key、explicit null、missing/extra rejection、initializer
  与 decoder 同 validation、canonical exact usage keys/non-negative Int64、decode
  failure → `DecodingError.dataCorrupted` 均成立；retry 只读取 disposition。
- Store 是只持有 `AppDatabase` 的 immutable `Sendable struct`。public write 均只有
  一个 `pool.write`，并具有同名 internal transaction helper；read 只有一个
  `pool.read`。canonical input/hash、Camp active/replay、campDeletion sealing、
  claim/renew/terminal CAS、attempt/event、projection closure rollback、
  cancelActive serialized writer、adoption、finite time/lease/backoff、三层
  diagnostics 与 claimability predicate 均符合 frozen leaf contract。

### 4.3 69 tests 与 R9 catalog

冻结 69 个 A1a test names 与当前源码集合 exact match、无缺失、无额外、无重名：

- Database：3；
- CanonicalJSON：10；
- DurableWork：56。

R9 单测与 runner 都实际构造完整
`56 work + 40 attempt + 288 event = 384` candidate catalog；不是只检查计数标签。
固定 7 个 `NULL/UNKNOWN` sentinels 与 19 个 legal controls 均属于 catalog，
每个 candidate 在独立 savepoint 执行真实 INSERT并验证成功行存在。非法 candidate
只有 `extendedResultCode == SQLITE_CONSTRAINT_CHECK` 才记作期望拒绝；其他 constraint
class 或错误会重新抛出/使 runner 失败。

实际 verdict 固定为：

- work `56 = 18 accepted / 38 CHECK rejected`；
- attempt `40 = 10 / 30`；
- event `288 = 17 / 271`；
- sentinels `7 = 0 / 7`；
- controls `19 = 19 / 0`。

runner 在 catalog 外层 rollback 前后捕获同一个 equatable health state：三表 row
counts、`PRAGMA foreign_keys`、稳定排序的全部 `foreign_key_check` 行与完整
`integrity_check == ["ok"]`；前后必须完全相同。每个 real fixture 在 append-only
检查后再次通过 health gate，literal fixture 在最终状态再次通过。没有静默清理
illegal row，也没有 A1a 越界执行 v16 poison/rebuild gate。

## 5. 验证证据真实性

保存证据不是摘要替代：

- `verify.log` 保留了两次既有 `IdlePatternProvider` exhaustion 红测、各自 isolation
  通过、随后完整 `492/492` 通过以及 final current `492/492` 通过；失败没有被删除或
  伪装成绿色。
- final hashes 与当前 AppDatabase、DurableWorkTests、runner、script、
  `Package.resolved` 及三份 frozen inputs 逐项一致，证明保存输出绑定当前审查对象。
- matrix 保存输出含两条真实 linked lane：
  SQLite `3.51.0` / source ID
  `f0ca7bba...4dcaapl`，以及 SQLite `3.52.0` / source ID
  `557aeb43...7dceab6`；本 reviewer 当前直接查询两条 CLI 得到相同 version/source ID。
- 每条 lane 都有 fresh、v7、v8、v9、v10、v11 六个真实 GRDB fixture和一个 Stage
  literal scope。五类 diagnostics 结果在日志中各精确出现 14 次
  （7 scopes × 2 lanes），两条 literal CLI gate 与总 matrix result 均为 pass。
- runner/script 的源码审查确认：Stage/literal/Package hashes fail fast、真实 migrator
  必须止于 v12、两条 binary linkage 与 runtime version/source ID 必须匹配各自 CLI，
  两条 lane 都必须执行，缺任一 prerequisite 不会降级成 pass。
- `build.log` 是完整 App product build 输出并成功；截图与 `verify.log` 中的隔离
  state root、真实进程、环境、open files、可见 no-model degraded injection 和 clean
  exit 相互对应。截图可见 Coding 牧场 no-model 状态，没有用 UI 证据冒充 A1a
  product wiring。
- `verify.log` 的 append-only follow-up 保留原 JPEG 证据 hash、记录新 PNG
  magic/尺寸/hash，并再次记录三份 frozen inputs 与 `Package.resolved` 的固定
  hashes；当前文件与该记录逐项一致。
- 原 JPEG bytes 以 `preview-smoke-source.jpg` 原样保留，其 hash 精确等于初版
  Review01 审查的旧截图 hash。`preview-smoke.png` 现在由 `file` 与 `sips` 双重确认
  为 1190×732 的真实 PNG；两文件的可见画面一致。
- 当前可变 control indexes、`blocked.md` 与 `impl-report.md` 都只把下一门指向
  acceptance；task 中没有 `acceptance.md`，也没有 A1b task/产品接线。

本 reviewer 另在当前 worktree 独立执行：

- `swift run RunTests`：**492/492 passed**，5 suites，12.714 秒；
- `swift build --product AgentLoopApp`：passed；
- `bash -n scripts/verify-p1-migrations-sqlite-matrix.sh`：passed；
- `git diff --check`：passed；
- `Package.resolved` SHA-256：仍为 frozen 值。

双 SQLite 完整重编 matrix 的执行事实取自上述与当前 hashes 严格绑定的保存日志；
本 reviewer 独立复核了其 runner/script、完整输出、当前 CLI version/source ID 与
fail-fast gates，没有用本轮单一 system-SQLite test run替代双 lane 证据。

## 6. Findings

### P0

0。

### P1

0。

### P2

0。

### 已关闭的历史 P2-1 — 截图扩展名与实际编码不一致

初版 Review01 发现的 JPEG/`.png` 不一致已关闭：原始 JFIF JPEG bytes 使用
`.jpg` 扩展名保留，新 `preview-smoke.png` 是 1190×732 RGB PNG，严格
MIME/tooling 与扩展名一致；可见截图内容、隔离 state root、进程与退出证据未改变。

## 7. Verdict 与继续门

**APPROVED — 0 P0 / 0 P1 / 0 P2.**

本 verdict 只批准当前 P1-A1a 实现进入独立 acceptance owner 的判定门。它本身不是
acceptance；在 acceptance owner 写出通过结论前，A1a 仍未 Accepted，A1b 继续关闭。
即使 A1a 后续 Accepted，也只能声明 CanonicalJSON v1、durable-work v12
migration、ledger/store 与本 slice 测试门成立；不得宣称 production planning 已接线
或 R-01 已关闭。
