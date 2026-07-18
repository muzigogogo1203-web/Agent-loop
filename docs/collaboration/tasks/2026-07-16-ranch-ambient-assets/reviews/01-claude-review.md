# Claude Review 01 — 牧场氛围资产进 App

代码实现与 plan 一致，测试在正常环境 409/409 全绿（Codex 沙箱里的 4 个失败确认为环境产物：keychain -50 / security-scoped bookmark 在受限沙箱不可用）。但真机验证发现打包链路的资源缺失问题：

## P0 — 分发/打包路径缺资源 bundle，最终用户机器上必崩

SwiftPM 生成的 `Bundle.module` accessor（见 `.build/arm64-apple-macosx/debug/AgentLoopApp.build/DerivedSources/resource_bundle_accessor.swift`）只查两个位置：

1. `Bundle.main.bundleURL/AgentLoop_AgentLoopApp.bundle`（即 `AgentLoop.app/AgentLoop_AgentLoopApp.bundle`，.app 根目录，**不是** Contents/Resources）
2. 写死的构建机绝对路径 `/Users/muzi/Agent-loop/.build/<triple>/debug|release/AgentLoop_AgentLoopApp.bundle`

两处都找不到就 `fatalError`。当前：

- `scripts/run-app.sh` 只拷裸二进制进 .app 壳 → 本机 .app 目前**靠候选 2 的写死路径侥幸运行**；`swift package clean` 后或 .app 挪到别的机器即崩。
- `scripts/package-app.sh` 只拷二进制 + AppIcon.icns → 分发的 dmg/zip 在最终用户机器上两个候选都不存在，**打开牛棚页/主页空闲态即 fatalError 崩溃**。

### 修复要求（决策已定，照做即可）

1. `RanchArtView.swift`：不要直接用 `Bundle.module`，新增私有静态 helper `resourceBundle`：
   - 先查 `Bundle.main.resourceURL?.appendingPathComponent("AgentLoop_AgentLoopApp.bundle")`，存在则 `Bundle(url:)` 使用（标准 .app 布局，Contents/Resources 下）；
   - 找不到再退回 `Bundle.module`（保住 bare-binary / swift run 开发路径，此路径下候选 2 可命中）；
   - helper 结果同样缓存，避免每次查文件系统。
2. `scripts/run-app.sh`：拷贝二进制后增加：`mkdir -p "$APP/Contents/Resources" && cp -R .build/debug/AgentLoop_AgentLoopApp.bundle "$APP/Contents/Resources/"`（在 codesign 之前）。
3. `scripts/package-app.sh`：同样在 release 产物拷贝处增加 `cp -R .build/release/AgentLoop_AgentLoopApp.bundle "$APP/Contents/Resources/"`（该脚本已有 `mkdir -p "$APP/Contents/Resources"`；同样必须在 codesign 之前）。
4. 不要把 bundle 放 .app 根目录（会破坏 bundle 规范与严格签名校验）。

## P3（备忘，不要求本轮处理）

- `GRDB_GRDB.bundle` 同样未打包，但已分发的 1.1.0 正常运行说明 GRDB 运行时未触达其 Bundle.module，维持现状即可，此处仅记录。
- `RanchArtView.image(named:)` 对加载失败的 name 不缓存 nil，资源缺失时每次 body 求值重复查 Bundle；数量级可忽略。

## 验证要求

1. `swift run RunTests` 保持全绿（你的沙箱里 keychain/bookmark 两项失败可忽略，但需在 impl-report 里注明）。
2. `scripts/run-app.sh` 构建出的 `.build/AgentLoop.app` 内 `Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/` 四张 JPEG 齐全（ls 证据写入 impl-report）。
3. 模拟"干净机器"场景：临时把 `.build/arm64-apple-macosx/debug/AgentLoop_AgentLoopApp.bundle` 改名，用 `Bundle(url:)` 路径单独写一个最小 Swift 脚本或通过代码审读证明 helper 的候选 1 在 .app 布局下命中（验证方式自选，证据写入 impl-report），验证后恢复改名。
