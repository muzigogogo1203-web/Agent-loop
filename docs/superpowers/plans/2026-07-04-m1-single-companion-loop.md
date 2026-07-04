# AgentLoop M1 — 单伙伴单卡 Loop 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 交付 M1：单个伙伴跑通完整 Agent Loop（真实 Anthropic API、流式 UI、文件/网络工具、交接包收尾、产物 Finder reveal）+ 伙伴私聊 + 动效骨架。

**Architecture:** 纯 SwiftPM 单包：`AgentLoopCore` 库（Provider/Loop/Tools/DB，全部 CLI 可测）+ `AgentLoopApp` 可执行目标（SwiftUI）。LLM 接入为手写 Anthropic Messages API 客户端（SSE 流式 + tool use），藏在 `LLMProvider` 协议后。GRDB 7 SQLite（WAL）为唯一事实源，事件追加与投影同事务。

**Tech Stack:** Swift 6.2（CLT，无 Xcode——`swift test` / `swift run` 驱动一切）、SwiftUI（macOS 14+）、GRDB 7.11+、URLSession SSE。

**与 spec 的两处偏差（均已核实环境后决定）：**
1. spec §12 写 SwiftAnthropic 2.2.x——本计划改为手写轻量客户端（~300 行）。理由：计划要求完整可离线验证的代码；报文格式已完全掌握；`LLMProvider` 协议接缝不变，之后可无痛换回。
2. 本机无 Xcode（仅 CLT），M1 不做 .app bundle/XcodeGen；`swift run AgentLoopApp` 以裸可执行方式启动 SwiftUI 窗口（需 `NSApp.setActivationPolicy(.regular)`，代码已含）。打包与沙箱按 spec 属 M5。

**Spec:** `docs/superpowers/specs/2026-07-04-agentloop-macos-mvp-design.md`（§5 内核不变量、§6 Loop、§7 交接包、§8 工具、§11 动效、§16-M1 验收）

---

## 环境前提

- macOS 14+，Swift 6.2 CLT（已确认：`swift --version` → 6.2.3）。
- 联网（首次 `swift build` 拉 GRDB；活体冒烟需 Anthropic API key）。
- 不需要 Xcode、xcodegen、brew 包。

## 文件结构总览

```text
/Users/muzi/Agent-loop/
  Package.swift
  Sources/AgentLoopCore/
    JSON/JSONValue.swift              # 通用 JSON 树（Codable、下标、字面量）
    Provider/ContentBlock.swift       # 内容块枚举（unknown 原样透传）+ APIMessage
    Provider/StopReason.swift
    Provider/SSEParser.swift          # 行级 SSE → 类型化流事件
    Provider/TurnAccumulator.swift    # 流事件 → 完整 assistant 轮
    Provider/LLMProvider.swift        # 协议 + ProviderEvent/TurnResult
    Provider/AnthropicProvider.swift  # 手写客户端（编码/重试/流）
    Provider/MockProvider.swift       # 脚本化回放（测试/金路径用）
    Database/AppDatabase.swift        # GRDB 池 + migration v1（spec §4.2 全表）
    Database/Records.swift            # 全部 record struct
    Tools/ToolDef.swift               # 工具 JSON Schema 定义
    Tools/ToolExecutor.swift          # 分发器 + ToolOutcome
    Tools/FileTools.swift             # list_dir/read_file/write_file + 路径包含
    Tools/WebFetchTool.swift
    Tools/HandoffPayload.swift        # v1 结构 + 写入时校验
    Tools/BoardTools.swift            # complete_card/block_card + 产物耐久拷贝
    Loop/ContextPacket.swift
    Loop/AgentLoop.swift              # while 循环（终止/提醒/自愈/预算）
    Chat/ChatService.swift            # 私聊（纯对话 + 持久化）
    Support/KeychainStore.swift
    Support/DeltaCoalescer.swift      # 40ms 合批
  Sources/AgentLoopApp/
    AgentLoopApp.swift                # @main + 激活策略
    AppStore.swift                    # @MainActor @Observable
    Views/RootView.swift              # NavigationSplitView
    Views/SettingsView.swift          # API key（Keychain）+ 默认模型
    Views/CompanionEditorView.swift
    Views/TaskRunView.swift           # 单卡：表单 → 流式转录 → 交付条
    Views/DMChatView.swift
    Views/Components/CompanionAvatarView.swift  # idle/thinking 两态（§11.2）
    Views/Components/TypingIndicatorView.swift
  Tests/AgentLoopCoreTests/           # 每个 Task 对应测试文件
```

设计约束回顾（实现时不可违背，出处 spec）：
- 未知内容块**原样透传**（§6.1）；assistant 轮 content 原样入 history。
- 工具错误返回 `is_error` tool_result 不抛出循环；同工具连续 3 次失败 → blocked（§14）。
- `complete_card` 先把产物拷进耐久存储、再在同事务落 done + 事件（§5.2-2）。
- 工具是 Run 唯一终结方式；end_turn 未收尾 → 提醒一次 → 再犯 blocked(noTerminator)（§5.2-4/§6.1）。
- 事件表 append-only，投影表同事务更新（§4.2）。
- system 前缀冻结 + cache_control（§6.3）。

---

### Task 0: SwiftPM 脚手架 + 空窗口应用可启动

**Files:**
- Create: `Package.swift`
- Create: `Sources/AgentLoopCore/JSON/JSONValue.swift`（空占位，Task 1 填）
- Create: `Sources/AgentLoopApp/AgentLoopApp.swift`
- Create: `Tests/AgentLoopCoreTests/SmokeTests.swift`

- [ ] **Step 1: 写 Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentLoop",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AgentLoopCore", targets: ["AgentLoopCore"]),
        .executable(name: "AgentLoopApp", targets: ["AgentLoopApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.11.0"),
    ],
    targets: [
        .target(
            name: "AgentLoopCore",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")]
        ),
        .executableTarget(
            name: "AgentLoopApp",
            dependencies: ["AgentLoopCore"]
        ),
        .testTarget(name: "AgentLoopCoreTests", dependencies: ["AgentLoopCore"]),
    ]
)
```

- [ ] **Step 2: 写最小可执行入口**（裸可执行启动 SwiftUI 的激活样板是关键，别删）

```swift
// Sources/AgentLoopApp/AgentLoopApp.swift
import SwiftUI

@main
struct AgentLoopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup("AgentLoop") {
            Text("营地搭建中…").padding(40)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

`Sources/AgentLoopCore/JSON/JSONValue.swift` 先放 `import Foundation` 一行占位。`Tests/AgentLoopCoreTests/SmokeTests.swift`：

```swift
import Testing
@testable import AgentLoopCore

@Test func packageBuilds() { #expect(Bool(true)) }
```

- [ ] **Step 3: 构建 + 测试 + 启动验证**

Run: `cd /Users/muzi/Agent-loop && swift test`
Expected: `Test run with 1 test passed`（首次会先解析拉取 GRDB，耗时数分钟）

Run: `swift run AgentLoopApp &` → 出现「营地搭建中…」窗口 → 关闭窗口/`kill %1`
Expected: 窗口正常显示并置前

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "chore(m1): SwiftPM scaffold — core lib + SwiftUI executable boots"
```

---

### Task 1: JSONValue（通用 JSON 树）

**Files:**
- Modify: `Sources/AgentLoopCore/JSON/JSONValue.swift`
- Test: `Tests/AgentLoopCoreTests/JSONValueTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import Testing
import Foundation
@testable import AgentLoopCore

@Test func jsonRoundTrip() throws {
    let raw = #"{"a":[1,"x",true,null],"b":{"c":2.5}}"#.data(using: .utf8)!
    let v = try JSONDecoder().decode(JSONValue.self, from: raw)
    #expect(v["a"]?[1]?.stringValue == "x")
    #expect(v["b"]?["c"]?.doubleValue == 2.5)
    let re = try JSONEncoder().encode(v)
    let v2 = try JSONDecoder().decode(JSONValue.self, from: re)
    #expect(v == v2) // 语义等价往返
}

@Test func jsonLiterals() {
    let v: JSONValue = ["name": "read_file", "n": 3, "ok": true]
    #expect(v["name"]?.stringValue == "read_file")
    #expect(v["n"]?.intValue == 3)
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter JSONValueTests`
Expected: FAIL（`JSONValue` 未定义）

- [ ] **Step 3: 实现**

```swift
import Foundation

public enum JSONValue: Sendable, Equatable, Codable {
    case string(String), number(Double), bool(Bool), null
    case array([JSONValue]), object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n):
            if n == n.rounded(), abs(n) < 1e15 { try c.encode(Int64(n)) } else { try c.encode(n) }
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }

    public subscript(key: String) -> JSONValue? {
        if case .object(let o) = self { return o[key] }; return nil
    }
    public subscript(index: Int) -> JSONValue? {
        if case .array(let a) = self, a.indices.contains(index) { return a[index] }; return nil
    }
    public var stringValue: String? { if case .string(let s) = self { return s }; return nil }
    public var doubleValue: Double? { if case .number(let n) = self { return n }; return nil }
    public var intValue: Int? { doubleValue.flatMap { Int(exactly: $0) } }
    public var boolValue: Bool? { if case .bool(let b) = self { return b }; return nil }
    public var objectValue: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }
    public var arrayValue: [JSONValue]? { if case .array(let a) = self { return a }; return nil }

    public func encodedString() throws -> String {
        String(data: try JSONEncoder().encode(self), encoding: .utf8) ?? "{}"
    }
    public static func decoded(from string: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(string.utf8))
    }
}

extension JSONValue: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral,
    ExpressibleByBooleanLiteral, ExpressibleByFloatLiteral,
    ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral, ExpressibleByNilLiteral {
    public init(stringLiteral v: String) { self = .string(v) }
    public init(integerLiteral v: Int) { self = .number(Double(v)) }
    public init(booleanLiteral v: Bool) { self = .bool(v) }
    public init(floatLiteral v: Double) { self = .number(v) }
    public init(arrayLiteral e: JSONValue...) { self = .array(e) }
    public init(dictionaryLiteral e: (String, JSONValue)...) { self = .object(.init(uniqueKeysWithValues: e)) }
    public init(nilLiteral: ()) { self = .null }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --filter JSONValueTests`
Expected: PASS（2 tests）

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(m1): JSONValue generic JSON tree"`

---

### Task 2: ContentBlock / APIMessage（unknown 原样透传）

**Files:**
- Create: `Sources/AgentLoopCore/Provider/ContentBlock.swift`, `Sources/AgentLoopCore/Provider/StopReason.swift`
- Test: `Tests/AgentLoopCoreTests/ContentBlockTests.swift`

- [ ] **Step 1: 写失败测试**（透传保真是 spec §6.1 的硬约束，测试为先）

```swift
import Testing
import Foundation
@testable import AgentLoopCore

@Test func decodeKnownBlocks() throws {
    let raw = #"[{"type":"text","text":"hi"},{"type":"tool_use","id":"toolu_1","name":"read_file","input":{"path":"a.md"}}]"#
    let blocks = try JSONDecoder().decode([ContentBlock].self, from: Data(raw.utf8))
    #expect(blocks[0] == .text("hi"))
    guard case .toolUse(let id, let name, let input) = blocks[1] else { Issue.record("not toolUse"); return }
    #expect(id == "toolu_1" && name == "read_file" && input["path"]?.stringValue == "a.md")
}

@Test func unknownBlockRoundTripsVerbatim() throws {
    let raw = #"{"type":"thinking","thinking":"...","signature":"sig123"}"#
    let block = try JSONDecoder().decode(ContentBlock.self, from: Data(raw.utf8))
    guard case .unknown = block else { Issue.record("should be unknown"); return }
    let re = try JSONEncoder().encode(block)
    let a = try JSONValue.decoded(from: String(data: re, encoding: .utf8)!)
    let b = try JSONValue.decoded(from: raw)
    #expect(a == b) // 语义级原样透传
}

@Test func toolResultEncoding() throws {
    let block = ContentBlock.toolResult(toolUseId: "toolu_1", content: "ok", isError: false)
    let v = try JSONValue.decoded(from: String(data: JSONEncoder().encode(block), encoding: .utf8)!)
    #expect(v["type"]?.stringValue == "tool_result")
    #expect(v["tool_use_id"]?.stringValue == "toolu_1")
    #expect(v["is_error"]?.boolValue == false)
}
```

- [ ] **Step 2: 确认失败** — Run: `swift test --filter ContentBlockTests` → FAIL

- [ ] **Step 3: 实现**

```swift
// ContentBlock.swift
import Foundation

public enum ContentBlock: Sendable, Equatable, Codable {
    case text(String)
    case toolUse(id: String, name: String, input: JSONValue)
    case toolResult(toolUseId: String, content: String, isError: Bool)
    case unknown(JSONValue)   // thinking/compaction 等：原样透传（spec §6.1）

    public init(from decoder: Decoder) throws {
        let v = try JSONValue(from: decoder)
        switch v["type"]?.stringValue {
        case "text":
            self = .text(v["text"]?.stringValue ?? "")
        case "tool_use":
            self = .toolUse(id: v["id"]?.stringValue ?? "",
                            name: v["name"]?.stringValue ?? "",
                            input: v["input"] ?? .object([:]))
        case "tool_result":
            self = .toolResult(toolUseId: v["tool_use_id"]?.stringValue ?? "",
                               content: v["content"]?.stringValue ?? "",
                               isError: v["is_error"]?.boolValue ?? false)
        default:
            self = .unknown(v)
        }
    }

    public func encode(to encoder: Encoder) throws {
        try jsonValue.encode(to: encoder)
    }

    public var jsonValue: JSONValue {
        switch self {
        case .text(let t): return ["type": "text", "text": .string(t)]
        case .toolUse(let id, let name, let input):
            return ["type": "tool_use", "id": .string(id), "name": .string(name), "input": input]
        case .toolResult(let id, let content, let isError):
            return ["type": "tool_result", "tool_use_id": .string(id),
                    "content": .string(content), "is_error": .bool(isError)]
        case .unknown(let v): return v
        }
    }
}

public struct APIMessage: Sendable, Equatable, Codable {
    public var role: Role
    public var content: [ContentBlock]
    public enum Role: String, Sendable, Codable { case user, assistant }
    public init(role: Role, content: [ContentBlock]) { self.role = role; self.content = content }
    public static func user(_ text: String) -> APIMessage { .init(role: .user, content: [.text(text)]) }
    public static func user(toolResults: [ContentBlock]) -> APIMessage { .init(role: .user, content: toolResults) }
    public static func assistant(_ content: [ContentBlock]) -> APIMessage { .init(role: .assistant, content: content) }
}
```

```swift
// StopReason.swift
public enum StopReason: Sendable, Equatable {
    case endTurn, toolUse, maxTokens, refusal, pauseTurn, stopSequence, contextExceeded
    case other(String)

    public init(apiValue: String?) {
        switch apiValue {
        case "end_turn": self = .endTurn
        case "tool_use": self = .toolUse
        case "max_tokens": self = .maxTokens
        case "refusal": self = .refusal
        case "pause_turn": self = .pauseTurn
        case "stop_sequence": self = .stopSequence
        case "model_context_window_exceeded": self = .contextExceeded
        default: self = .other(apiValue ?? "nil")
        }
    }
}
```

- [ ] **Step 4: 确认通过** — Run: `swift test --filter ContentBlockTests` → PASS（3 tests）
- [ ] **Step 5: Commit** — `git commit -am "feat(m1): content blocks with verbatim unknown passthrough"`

---

### Task 3: SSE 行解析器

**Files:**
- Create: `Sources/AgentLoopCore/Provider/SSEParser.swift`
- Test: `Tests/AgentLoopCoreTests/SSEParserTests.swift`

Anthropic 流每个事件形如 `event: <name>\ndata: <json>\n\n`，data 单行。解析器按行喂入，见到 `data:` 即产出事件（不依赖空行）。

- [ ] **Step 1: 写失败测试**

```swift
import Testing
@testable import AgentLoopCore

@Test func parsesEventDataPairs() {
    var p = SSELineParser()
    #expect(p.consume(line: "event: message_start") == nil)
    let e = p.consume(line: #"data: {"type":"message_start"}"#)
    #expect(e?.event == "message_start")
    #expect(e?.data == #"{"type":"message_start"}"#)
    #expect(p.consume(line: "") == nil)
}

@Test func ignoresCommentsAndPings() {
    var p = SSELineParser()
    #expect(p.consume(line: ": keep-alive") == nil)
    _ = p.consume(line: "event: ping")
    let e = p.consume(line: #"data: {"type":"ping"}"#)
    #expect(e?.event == "ping")
}
```

- [ ] **Step 2: 确认失败** — `swift test --filter SSEParserTests` → FAIL

- [ ] **Step 3: 实现**

```swift
public struct RawSSEEvent: Sendable, Equatable {
    public let event: String
    public let data: String
}

public struct SSELineParser: Sendable {
    private var pendingEvent: String = "message"
    public init() {}

    public mutating func consume(line: String) -> RawSSEEvent? {
        if line.hasPrefix(":") || line.isEmpty { return nil }
        if line.hasPrefix("event:") {
            pendingEvent = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            return nil
        }
        if line.hasPrefix("data:") {
            let data = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            return RawSSEEvent(event: pendingEvent, data: data)
        }
        return nil
    }
}
```

- [ ] **Step 4: 确认通过** → PASS（2 tests）
- [ ] **Step 5: Commit** — `git commit -am "feat(m1): SSE line parser"`

---

### Task 4: TurnAccumulator（流事件 → 完整轮）

**Files:**
- Create: `Sources/AgentLoopCore/Provider/TurnAccumulator.swift`, `Sources/AgentLoopCore/Provider/LLMProvider.swift`
- Test: `Tests/AgentLoopCoreTests/TurnAccumulatorTests.swift`

先定协议与共享类型（累加器的产出类型）：

```swift
// LLMProvider.swift
public struct Usage: Sendable, Equatable {
    public var inputTokens: Int, outputTokens: Int, cacheReadTokens: Int
    public init(inputTokens: Int = 0, outputTokens: Int = 0, cacheReadTokens: Int = 0) {
        self.inputTokens = inputTokens; self.outputTokens = outputTokens; self.cacheReadTokens = cacheReadTokens
    }
}

public struct TurnResult: Sendable, Equatable {
    public var content: [ContentBlock]
    public var stopReason: StopReason
    public var usage: Usage
    public init(content: [ContentBlock], stopReason: StopReason, usage: Usage = .init()) {
        self.content = content; self.stopReason = stopReason; self.usage = usage
    }
    public var toolUses: [(id: String, name: String, input: JSONValue)] {
        content.compactMap { if case .toolUse(let i, let n, let inp) = $0 { return (i, n, inp) }; return nil }
    }
}

public enum ProviderEvent: Sendable {
    case textDelta(String)
    case turn(TurnResult)
}

public enum ProviderError: Error, Sendable, Equatable {
    case http(status: Int, body: String)
    case unauthorized
    case overloadedRetriesExhausted
    case apiError(type: String, message: String)
    case malformedStream(String)
}

public protocol LLMProvider: Sendable {
    func streamTurn(system: String, history: [APIMessage], tools: [ToolDef], maxTokens: Int)
        -> AsyncThrowingStream<ProviderEvent, Error>
}
```

（`ToolDef` 在 Task 8 定义；此处先加最小声明避免编译断裂：）

```swift
// 临时放在 LLMProvider.swift 底部，Task 8 移入 Tools/ToolDef.swift
public struct ToolDef: Sendable, Equatable {
    public let name: String
    public let description: String
    public let inputSchema: JSONValue
    public init(name: String, description: String, inputSchema: JSONValue) {
        self.name = name; self.description = description; self.inputSchema = inputSchema
    }
}
```

- [ ] **Step 1: 写失败测试**（覆盖：文本增量、tool_use 的 input_json_delta 拼接、stop_reason、usage）

```swift
import Testing
@testable import AgentLoopCore

private func feed(_ acc: inout TurnAccumulator, _ event: String, _ json: String) throws -> [String] {
    var deltas: [String] = []
    try acc.consume(RawSSEEvent(event: event, data: json)) { deltas.append($0) }
    return deltas
}

@Test func accumulatesTextAndToolUse() throws {
    var acc = TurnAccumulator()
    _ = try feed(&acc, "message_start", #"{"type":"message_start","message":{"usage":{"input_tokens":10}}}"#)
    _ = try feed(&acc, "content_block_start", #"{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}"#)
    let d1 = try feed(&acc, "content_block_delta", #"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"你好"}}"#)
    #expect(d1 == ["你好"])
    _ = try feed(&acc, "content_block_stop", #"{"type":"content_block_stop","index":0}"#)
    _ = try feed(&acc, "content_block_start", #"{"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"toolu_9","name":"write_file","input":{}}}"#)
    _ = try feed(&acc, "content_block_delta", #"{"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\"path\":"}}"#)
    _ = try feed(&acc, "content_block_delta", #"{"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"\"a.md\"}"}}"#)
    _ = try feed(&acc, "content_block_stop", #"{"type":"content_block_stop","index":1}"#)
    _ = try feed(&acc, "message_delta", #"{"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":42}}"#)
    _ = try feed(&acc, "message_stop", #"{"type":"message_stop"}"#)

    let turn = try #require(acc.finishedTurn)
    #expect(turn.stopReason == .toolUse)
    #expect(turn.content[0] == .text("你好"))
    guard case .toolUse(let id, let name, let input) = turn.content[1] else { Issue.record("no toolUse"); return }
    #expect(id == "toolu_9" && name == "write_file" && input["path"]?.stringValue == "a.md")
    #expect(turn.usage.inputTokens == 10 && turn.usage.outputTokens == 42)
}

@Test func emptyToolInputBecomesEmptyObject() throws {
    var acc = TurnAccumulator()
    _ = try feed(&acc, "content_block_start", #"{"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"t","name":"list_dir","input":{}}}"#)
    _ = try feed(&acc, "content_block_stop", #"{"type":"content_block_stop","index":0}"#)
    _ = try feed(&acc, "message_delta", #"{"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{}}"#)
    _ = try feed(&acc, "message_stop", #"{"type":"message_stop"}"#)
    guard case .toolUse(_, _, let input) = try #require(acc.finishedTurn).content[0] else { return }
    #expect(input == .object([:]))
}

@Test func apiErrorEventThrows() {
    var acc = TurnAccumulator()
    #expect(throws: ProviderError.self) {
        try acc.consume(RawSSEEvent(event: "error", data: #"{"type":"error","error":{"type":"overloaded_error","message":"busy"}}"#)) { _ in }
    }
}
```

- [ ] **Step 2: 确认失败** — `swift test --filter TurnAccumulatorTests` → FAIL

- [ ] **Step 3: 实现**

```swift
import Foundation

public struct TurnAccumulator: Sendable {
    private enum Pending {
        case text(String)
        case toolUse(id: String, name: String, jsonBuffer: String)
        case unknown(JSONValue)
    }
    private var pending: [Int: Pending] = [:]
    private var finished: [(index: Int, block: ContentBlock)] = []
    private var stopReason: StopReason?
    private var usage = Usage()
    public private(set) var finishedTurn: TurnResult?

    public init() {}

    public mutating func consume(_ raw: RawSSEEvent, onTextDelta: (String) -> Void) throws {
        let v = try JSONValue.decoded(from: raw.data)
        switch raw.event {
        case "message_start":
            usage.inputTokens = v["message"]?["usage"]?["input_tokens"]?.intValue ?? 0
            usage.cacheReadTokens = v["message"]?["usage"]?["cache_read_input_tokens"]?.intValue ?? 0
        case "content_block_start":
            let idx = v["index"]?.intValue ?? 0
            let block = v["content_block"] ?? .object([:])
            switch block["type"]?.stringValue {
            case "text": pending[idx] = .text(block["text"]?.stringValue ?? "")
            case "tool_use":
                pending[idx] = .toolUse(id: block["id"]?.stringValue ?? "",
                                        name: block["name"]?.stringValue ?? "", jsonBuffer: "")
            default: pending[idx] = .unknown(block)
            }
        case "content_block_delta":
            let idx = v["index"]?.intValue ?? 0
            let delta = v["delta"] ?? .object([:])
            switch delta["type"]?.stringValue {
            case "text_delta":
                let t = delta["text"]?.stringValue ?? ""
                if case .text(let existing) = pending[idx] { pending[idx] = .text(existing + t) }
                onTextDelta(t)
            case "input_json_delta":
                let part = delta["partial_json"]?.stringValue ?? ""
                if case .toolUse(let id, let name, let buf) = pending[idx] {
                    pending[idx] = .toolUse(id: id, name: name, jsonBuffer: buf + part)
                }
            default: break
            }
        case "content_block_stop":
            let idx = v["index"]?.intValue ?? 0
            guard let p = pending.removeValue(forKey: idx) else { break }
            let block: ContentBlock
            switch p {
            case .text(let t): block = .text(t)
            case .toolUse(let id, let name, let buf):
                if buf.isEmpty {
                    block = .toolUse(id: id, name: name, input: .object([:]))
                } else {
                    guard let input = try? JSONValue.decoded(from: buf) else {
                        let preview = String(buf.prefix(120))
                        throw ProviderError.malformedStream("tool_use \(id) input: \(preview)")
                    }
                    block = .toolUse(id: id, name: name, input: input)
                }
            case .unknown(let v): block = .unknown(v)
            }
            finished.append((idx, block))
        case "message_delta":
            if let sr = v["delta"]?["stop_reason"]?.stringValue { stopReason = StopReason(apiValue: sr) }
            if let out = v["usage"]?["output_tokens"]?.intValue { usage.outputTokens = out }
        case "message_stop":
            finishedTurn = TurnResult(
                content: finished.sorted { $0.index < $1.index }.map(\.block),
                stopReason: stopReason ?? .endTurn, usage: usage)
        case "error":
            throw ProviderError.apiError(type: v["error"]?["type"]?.stringValue ?? "unknown",
                                         message: v["error"]?["message"]?.stringValue ?? "")
        default: break // ping 等
        }
    }
}
```

- [ ] **Step 4: 确认通过** → PASS（3 tests）
- [ ] **Step 5: Commit** — `git commit -am "feat(m1): turn accumulator — SSE events to complete assistant turns"`

---

### Task 5: AnthropicProvider（请求编码 / 重试 / 流集成）

**Files:**
- Create: `Sources/AgentLoopCore/Provider/AnthropicProvider.swift`
- Test: `Tests/AgentLoopCoreTests/AnthropicProviderTests.swift`

**分层策略**：请求体编码是纯函数（直接单测）；HTTP 用 `URLProtocol` 桩测 headers/重试/401；流集成复用 Task 3/4 已测组件。

> ⚠️ `StubProtocol.handler` 是共享静态量，而 Swift Testing 默认并行跑测试——本文件与 Task 10 的 WebFetchTests 都要给套件加 `.serialized` trait（`@Suite(.serialized)`），否则会间歇性串桩。

- [ ] **Step 1: 写失败测试**

```swift
import Testing
import Foundation
@testable import AgentLoopCore

@Test func requestBodyShape() throws {
    let body = AnthropicProvider.requestBody(
        model: "claude-sonnet-4-6", system: "你是伙伴",
        history: [.user("hi")],
        tools: [ToolDef(name: "read_file", description: "读文件",
                        inputSchema: ["type": "object", "properties": ["path": ["type": "string"]], "required": ["path"], "additionalProperties": false])],
        maxTokens: 4096)
    #expect(body["model"]?.stringValue == "claude-sonnet-4-6")
    #expect(body["stream"]?.boolValue == true)
    #expect(body["max_tokens"]?.intValue == 4096)
    // system 是带 cache_control 的块数组（spec §6.3 缓存一等设计）
    #expect(body["system"]?[0]?["cache_control"]?["type"]?.stringValue == "ephemeral")
    #expect(body["tools"]?[0]?["input_schema"]?["type"]?.stringValue == "object")
    #expect(body["messages"]?[0]?["role"]?.stringValue == "user")
}

// URLProtocol 桩
final class StubProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, Data, [String: String]))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, data, headers) = Self.handler!(request)
        let resp = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private func stubbedSession() -> URLSession {
    let cfg = URLSessionConfiguration.ephemeral
    cfg.protocolClasses = [StubProtocol.self]
    return URLSession(configuration: cfg)
}

@Test func streamsTextTurnEndToEnd() async throws {
    let sse = """
    event: message_start
    data: {"type":"message_start","message":{"usage":{"input_tokens":5}}}
    event: content_block_start
    data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}
    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"好的"}}
    event: content_block_stop
    data: {"type":"content_block_stop","index":0}
    event: message_delta
    data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":7}}
    event: message_stop
    data: {"type":"message_stop"}
    """
    StubProtocol.handler = { req in
        #expect(req.value(forHTTPHeaderField: "x-api-key") == "sk-test")
        #expect(req.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        return (200, Data(sse.utf8), ["Content-Type": "text/event-stream"])
    }
    let p = AnthropicProvider(apiKey: "sk-test", model: "claude-sonnet-4-6", session: stubbedSession())
    var deltas = ""; var turn: TurnResult?
    for try await ev in p.streamTurn(system: "s", history: [.user("hi")], tools: [], maxTokens: 100) {
        switch ev {
        case .textDelta(let t): deltas += t
        case .turn(let t): turn = t
        }
    }
    #expect(deltas == "好的")
    #expect(turn?.stopReason == .endTurn)
    #expect(turn?.usage.outputTokens == 7)
}

@Test func unauthorizedFailsFastNoRetry() async {
    nonisolated(unsafe) var calls = 0
    StubProtocol.handler = { _ in calls += 1; return (401, Data(#"{"error":{"message":"bad key"}}"#.utf8), [:]) }
    let p = AnthropicProvider(apiKey: "bad", model: "m", session: stubbedSession())
    await #expect(throws: ProviderError.unauthorized) {
        for try await _ in p.streamTurn(system: "s", history: [.user("x")], tools: [], maxTokens: 10) {}
    }
    #expect(calls == 1)
}

@Test func overloadedRetriesThenSucceeds() async throws {
    nonisolated(unsafe) var calls = 0
    let okSSE = "event: message_stop\ndata: {\"type\":\"message_stop\"}"
    StubProtocol.handler = { _ in
        calls += 1
        return calls < 3 ? (529, Data("overloaded".utf8), [:]) : (200, Data(okSSE.utf8), [:])
    }
    let p = AnthropicProvider(apiKey: "k", model: "m", session: stubbedSession(),
                              retryBaseDelay: .milliseconds(1)) // 测试加速
    for try await _ in p.streamTurn(system: "s", history: [.user("x")], tools: [], maxTokens: 10) {}
    #expect(calls == 3)
}
```

- [ ] **Step 2: 确认失败** — `swift test --filter AnthropicProviderTests` → FAIL

- [ ] **Step 3: 实现**

```swift
import Foundation

public struct AnthropicProvider: LLMProvider {
    let apiKey: String
    let model: String
    let session: URLSession
    let baseURL: URL
    let retryBaseDelay: Duration
    let maxRetries: Int

    public init(apiKey: String, model: String, session: URLSession = .shared,
                baseURL: URL = URL(string: "https://api.anthropic.com")!,
                retryBaseDelay: Duration = .seconds(1), maxRetries: Int = 3) {
        self.apiKey = apiKey; self.model = model; self.session = session
        self.baseURL = baseURL; self.retryBaseDelay = retryBaseDelay; self.maxRetries = maxRetries
    }

    // 纯函数，直接单测。system 块数组 + cache_control（spec §6.3）
    public static func requestBody(model: String, system: String, history: [APIMessage],
                                   tools: [ToolDef], maxTokens: Int) -> JSONValue {
        var body: [String: JSONValue] = [
            "model": .string(model),
            "max_tokens": .number(Double(maxTokens)),
            "stream": .bool(true),
            "system": .array([[
                "type": "text", "text": .string(system),
                "cache_control": ["type": "ephemeral"],
            ]]),
            "messages": .array(history.map { msg in
                ["role": .string(msg.role.rawValue),
                 "content": .array(msg.content.map(\.jsonValue))]
            }),
        ]
        if !tools.isEmpty {
            body["tools"] = .array(tools.map {
                ["name": .string($0.name), "description": .string($0.description),
                 "input_schema": $0.inputSchema]
            })
        }
        return .object(body)
    }

    public func streamTurn(system: String, history: [APIMessage], tools: [ToolDef],
                           maxTokens: Int) -> AsyncThrowingStream<ProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await run(system: system, history: history, tools: tools,
                                  maxTokens: maxTokens, continuation: continuation)
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func run(system: String, history: [APIMessage], tools: [ToolDef], maxTokens: Int,
                     continuation: AsyncThrowingStream<ProviderEvent, Error>.Continuation) async throws {
        var request = URLRequest(url: baseURL.appending(path: "/v1/messages"))
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        request.httpBody = try encoder.encode(
            Self.requestBody(model: model, system: system, history: history, tools: tools, maxTokens: maxTokens))

        var attempt = 0
        while true {
            attempt += 1
            let (bytes, response) = try await session.bytes(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch status {
            case 200:
                try await consumeStream(bytes, continuation: continuation)
                return
            case 401, 403:
                throw ProviderError.unauthorized
            case 429, 500...599:
                guard attempt <= maxRetries else {
                    throw ProviderError.overloadedRetriesExhausted
                }
                let retryAfterSeconds = (response as? HTTPURLResponse)?
                    .value(forHTTPHeaderField: "retry-after").flatMap(Double.init)
                let delay: Duration
                if let s = retryAfterSeconds, s.isFinite, s >= 0 {
                    delay = .seconds(min(s, 60))
                } else {
                    delay = retryBaseDelay * (1 << (attempt - 1))
                }
                try await Task.sleep(for: delay)
            default:
                var body = ""
                for try await line in bytes.lines { body += line; if body.count > 2000 { break } }
                throw ProviderError.http(status: status, body: body)
            }
        }
    }

    private func consumeStream(_ bytes: URLSession.AsyncBytes,
                               continuation: AsyncThrowingStream<ProviderEvent, Error>.Continuation) async throws {
        var parser = SSELineParser()
        var acc = TurnAccumulator()
        for try await line in bytes.lines {
            guard let raw = parser.consume(line: line) else { continue }
            try acc.consume(raw) { continuation.yield(.textDelta($0)) }
            if let turn = acc.finishedTurn {
                continuation.yield(.turn(turn))
                return
            }
        }
        // 流意外结束而无 message_stop
        if acc.finishedTurn == nil { throw ProviderError.malformedStream("stream ended without message_stop") }
    }
}
```

注意：实现时用清晰写法：

```swift
case 429, 500...599:
    guard attempt <= maxRetries else { throw ProviderError.overloadedRetriesExhausted }
    // ...退避后 continue
```

- [ ] **Step 4: 确认通过** — `swift test --filter AnthropicProviderTests` → PASS（4 tests）
- [ ] **Step 5: Commit** — `git commit -am "feat(m1): hand-rolled Anthropic streaming provider with retry/backoff"`

---

### Task 6: MockProvider（脚本化回放）

**Files:**
- Create: `Sources/AgentLoopCore/Provider/MockProvider.swift`
- Test: `Tests/AgentLoopCoreTests/MockProviderTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import Testing
@testable import AgentLoopCore

@Test func mockReplaysScriptInOrder() async throws {
    let mock = MockProvider(script: [
        TurnResult(content: [.text("想一下")], stopReason: .endTurn),
        TurnResult(content: [.toolUse(id: "t1", name: "read_file", input: ["path": "a"])], stopReason: .toolUse),
    ])
    var turns: [TurnResult] = []
    for _ in 0..<2 {
        for try await ev in mock.streamTurn(system: "", history: [], tools: [], maxTokens: 1) {
            if case .turn(let t) = ev { turns.append(t) }
        }
    }
    #expect(turns.count == 2)
    #expect(turns[0].stopReason == .endTurn)
    #expect(turns[1].stopReason == .toolUse)
    #expect(await mock.callCount == 2)
}
```

- [ ] **Step 2: 确认失败** → FAIL

- [ ] **Step 3: 实现**

```swift
public actor MockProvider: LLMProvider {
    private var script: [TurnResult]
    public private(set) var callCount = 0
    public private(set) var recordedHistories: [[APIMessage]] = []

    public init(script: [TurnResult]) { self.script = script }

    public nonisolated func streamTurn(system: String, history: [APIMessage], tools: [ToolDef],
                                       maxTokens: Int) -> AsyncThrowingStream<ProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let turn = await self.next(history: history)
                guard let turn else {
                    continuation.finish(throwing: ProviderError.malformedStream("mock script exhausted"))
                    return
                }
                for block in turn.content {
                    if case .text(let t) = block { continuation.yield(.textDelta(t)) }
                }
                continuation.yield(.turn(turn))
                continuation.finish()
            }
        }
    }

    private func next(history: [APIMessage]) -> TurnResult? {
        callCount += 1
        recordedHistories.append(history)
        return script.isEmpty ? nil : script.removeFirst()
    }
}
```

- [ ] **Step 4: 确认通过** → PASS
- [ ] **Step 5: Commit** — `git commit -am "feat(m1): scripted mock provider"`

---

### Task 7: AppDatabase + migration v1 + 事件同事务投影

**Files:**
- Create: `Sources/AgentLoopCore/Database/AppDatabase.swift`, `Sources/AgentLoopCore/Database/Records.swift`
- Test: `Tests/AgentLoopCoreTests/DatabaseTests.swift`

Migration v1 建 spec §4.2 **全部**表（M1 只用子集，前向兼容）。id 全部为应用生成的 UUID 字符串（spec §5.3：永不信任模型报的 id，一律内核生成）。

- [ ] **Step 1: 写失败测试**

```swift
import Testing
import Foundation
import GRDB
@testable import AgentLoopCore

private func tempDB() throws -> AppDatabase {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try AppDatabase(path: dir.appendingPathComponent("test.sqlite").path)
}

@Test func migratesAndBootstraps() throws {
    let db = try tempDB()
    let camp = try db.ensureDefaultCamp()
    #expect(camp.name == "我的营地")
    let guide = try db.guide(campId: camp.id)
    #expect(guide?.kind == .guide)
    // 幂等：再次调用不重复创建
    _ = try db.ensureDefaultCamp()
    let camps = try db.pool.read { try CampRecord.fetchCount($0) }
    #expect(camps == 1)
}

@Test func companionCRUD() throws {
    let db = try tempDB()
    var c = CompanionRecord.new(name: "阿规", color: "purple", rolePrompt: "你是产品伙伴", model: "claude-sonnet-4-6")
    try db.saveCompanion(&c)
    let all = try db.regularCompanions()
    #expect(all.map(\.name) == ["阿规"])
}

@Test func eventAppendAndProjectionSameTransaction() throws {
    let db = try tempDB()
    let ids = try db.createSingleCardMission(
        campName: "我的营地", squadName: "试营小队",
        goal: "写清单", cardTitle: "写清单", cardDescription: "…",
        expectedOutput: "一份 md", assigneeId: nil, maxTurns: 30)
    try db.transitionCard(id: ids.cardId, to: .running, eventKind: "card_started", payload: ["by": "test"])
    let card = try db.card(id: ids.cardId)
    #expect(card?.status == .running)
    let events = try db.events(cardId: ids.cardId)
    #expect(events.contains { $0.kind == "card_started" })
}

@Test func illegalTransitionThrows() throws {
    let db = try tempDB()
    let ids = try db.createSingleCardMission(campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e", assigneeId: nil, maxTurns: 30)
    // ready → done 非法（createSingleCardMission 建卡即 ready；done 必须先经 running，spec §5.1）
    #expect(throws: CardTransitionError.self) {
        try db.transitionCard(id: ids.cardId, to: .done, eventKind: "x", payload: .object([:]))
    }
}
```

- [ ] **Step 2: 确认失败** → FAIL

- [ ] **Step 3: 实现 Records.swift**（节选完整给出；全部 record 同构，实现者按此模式补全其余表）

```swift
import Foundation
import GRDB

public enum CardStatus: String, Sendable, Codable, CaseIterable {
    case todo, ready, running, done, blocked, canceled
    // spec §5.1 穷举转移
    public func canTransition(to next: CardStatus) -> Bool {
        switch (self, next) {
        case (.todo, .ready), (.ready, .running), (.running, .done),
             (.running, .blocked), (.blocked, .ready), (.blocked, .canceled),
             (.todo, .canceled), (.ready, .canceled):
            return true
        default: return false
        }
    }
}

public struct CardTransitionError: Error, Equatable {
    public let from: CardStatus, to: CardStatus
}

public struct CampRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "camp"
    public var id: String, name: String, createdAt: Date
}

public struct CompanionRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "companion"
    public enum Kind: String, Codable, Sendable { case regular, guide }
    public var id: String, name: String, color: String, rolePrompt: String
    public var model: String, toolsJson: String, kind: Kind, campId: String?, createdAt: Date

    public static func new(name: String, color: String, rolePrompt: String, model: String,
                           kind: Kind = .regular, campId: String? = nil) -> CompanionRecord {
        .init(id: UUID().uuidString, name: name, color: color, rolePrompt: rolePrompt,
              model: model, toolsJson: "[]", kind: kind, campId: campId, createdAt: Date())
    }
}

public struct SquadRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "squad"
    public var id: String, campId: String, name: String, memberIdsJson: String
    public var workspacePath: String?, createdAt: Date
    // M1 非沙箱：workspacePath 存明文路径；M5 换安全作用域书签（spec 偏差说明见计划头）
}

public struct MissionRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "mission"
    public var id: String, squadId: String, goalRaw: String, goalRefined: String
    public var status: String, budgetTokens: Int, spentTokens: Int, revision: Int, createdAt: Date
}

public struct CardRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "card"
    public var id: String, missionId: String, idemKey: String, title: String
    public var descriptionText: String, expectedOutput: String, assigneeId: String?
    public var status: CardStatus, blockedReasonJson: String?, dependsOnJson: String
    public var maxTurns: Int, tokenBudget: Int, createdAt: Date
    public static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
}

public struct RunRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "run"
    public var id: String, cardId: String, attempt: Int, outcome: String?
    public var turns: Int, tokensIn: Int, tokensOut: Int, startedAt: Date, endedAt: Date?
}

public struct EventRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "event"
    public var id: String, missionId: String?, cardId: String?, runId: String?
    public var kind: String, payloadJson: String, createdAt: Date
}

public struct ArtifactRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "artifact"
    public var id: String, cardId: String, path: String, kind: String, label: String, createdAt: Date
}

public struct ChatThreadRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "chat_thread"
    public enum Kind: String, Codable, Sendable { case dm, guide }
    public var id: String, kind: Kind, companionId: String, campId: String?, createdAt: Date
}

public struct ChatMessageRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "chat_message"
    public var id: String, threadId: String, role: String, contentJson: String
    public var distilled: Bool, createdAt: Date
}

// camp_note / user_request 两表 M1 不读写，仅建表（列见 spec §4.2）
```

- [ ] **Step 4: 实现 AppDatabase.swift**

```swift
import Foundation
import GRDB

public final class AppDatabase: Sendable {
    public let pool: DatabasePool

    public init(path: String) throws {
        var cfg = Configuration()
        cfg.journalMode = .wal
        pool = try DatabasePool(path: path, configuration: cfg)
        try migrator.migrate(pool)
    }

    private var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()
        m.registerMigration("v1") { db in
            try db.create(table: "camp") { t in
                t.primaryKey("id", .text); t.column("name", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "companion") { t in
                t.primaryKey("id", .text); t.column("name", .text).notNull()
                t.column("color", .text).notNull(); t.column("rolePrompt", .text).notNull()
                t.column("model", .text).notNull(); t.column("toolsJson", .text).notNull()
                t.column("kind", .text).notNull().defaults(to: "regular")
                t.column("campId", .text).references("camp"); t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "squad") { t in
                t.primaryKey("id", .text); t.column("campId", .text).notNull().references("camp")
                t.column("name", .text).notNull(); t.column("memberIdsJson", .text).notNull()
                t.column("workspacePath", .text); t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "mission") { t in
                t.primaryKey("id", .text); t.column("squadId", .text).notNull().references("squad")
                t.column("goalRaw", .text).notNull(); t.column("goalRefined", .text).notNull()
                t.column("status", .text).notNull(); t.column("budgetTokens", .integer).notNull()
                t.column("spentTokens", .integer).notNull().defaults(to: 0)
                t.column("revision", .integer).notNull().defaults(to: 1)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "card") { t in
                t.primaryKey("id", .text); t.column("missionId", .text).notNull().references("mission")
                t.column("idemKey", .text).notNull().unique()
                t.column("title", .text).notNull(); t.column("descriptionText", .text).notNull()
                t.column("expectedOutput", .text).notNull(); t.column("assigneeId", .text)
                t.column("status", .text).notNull(); t.column("blockedReasonJson", .text)
                t.column("dependsOnJson", .text).notNull().defaults(to: "[]")
                t.column("maxTurns", .integer).notNull(); t.column("tokenBudget", .integer).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "run") { t in
                t.primaryKey("id", .text); t.column("cardId", .text).notNull().references("card")
                t.column("attempt", .integer).notNull(); t.column("outcome", .text)
                t.column("turns", .integer).notNull().defaults(to: 0)
                t.column("tokensIn", .integer).notNull().defaults(to: 0)
                t.column("tokensOut", .integer).notNull().defaults(to: 0)
                t.column("startedAt", .datetime).notNull(); t.column("endedAt", .datetime)
            }
            try db.create(table: "event") { t in
                t.primaryKey("id", .text)
                t.column("missionId", .text); t.column("cardId", .text); t.column("runId", .text)
                t.column("kind", .text).notNull(); t.column("payloadJson", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "artifact") { t in
                t.primaryKey("id", .text); t.column("cardId", .text).notNull().references("card")
                t.column("path", .text).notNull(); t.column("kind", .text).notNull()
                t.column("label", .text).notNull(); t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "camp_note") { t in
                t.primaryKey("id", .text); t.column("campId", .text).notNull().references("camp")
                t.column("missionId", .text); t.column("title", .text).notNull()
                t.column("bodyMd", .text).notNull(); t.column("pinned", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull(); t.column("updatedAt", .datetime).notNull()
            }
            try db.create(table: "user_request") { t in
                t.primaryKey("id", .text); t.column("cardId", .text).notNull().references("card")
                t.column("kind", .text).notNull(); t.column("prompt", .text).notNull()
                t.column("optionsJson", .text); t.column("answerJson", .text)
                t.column("createdAt", .datetime).notNull(); t.column("answeredAt", .datetime)
            }
            try db.create(table: "chat_thread") { t in
                t.primaryKey("id", .text); t.column("kind", .text).notNull()
                t.column("companionId", .text).notNull().references("companion")
                t.column("campId", .text); t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "chat_message") { t in
                t.primaryKey("id", .text); t.column("threadId", .text).notNull().references("chat_thread")
                t.column("role", .text).notNull(); t.column("contentJson", .text).notNull()
                t.column("distilled", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
            }
        }
        return m
    }

    // MARK: 引导（幂等）
    @discardableResult
    public func ensureDefaultCamp() throws -> CampRecord {
        try pool.write { db in
            if let camp = try CampRecord.fetchOne(db) { return camp }
            let camp = CampRecord(id: UUID().uuidString, name: "我的营地", createdAt: Date())
            try camp.insert(db)
            var guide = CompanionRecord.new(
                name: "向导", color: "amber",
                rolePrompt: "你是这个营地的向导，熟悉营地里的一切。",
                model: "claude-sonnet-4-6", kind: .guide, campId: camp.id)
            guide.toolsJson = "[]"
            try guide.insert(db)
            return camp
        }
    }

    public func guide(campId: String) throws -> CompanionRecord? {
        try pool.read { db in
            try CompanionRecord.filter(Column("campId") == campId && Column("kind") == "guide").fetchOne(db)
        }
    }

    // MARK: 伙伴
    public func saveCompanion(_ c: inout CompanionRecord) throws {
        try pool.write { [c] db in try c.save(db) }
    }
    public func regularCompanions() throws -> [CompanionRecord] {
        try pool.read { db in
            try CompanionRecord.filter(Column("kind") == "regular").order(Column("createdAt")).fetchAll(db)
        }
    }

    // MARK: M1 单卡任务（camp/squad/mission/card 一步建齐，幂等键 mission:<id>:stage-1）
    public struct SingleCardIds: Sendable { public let missionId: String, cardId: String, squadId: String }
    public func createSingleCardMission(campName: String, squadName: String, goal: String,
                                        cardTitle: String, cardDescription: String, expectedOutput: String,
                                        assigneeId: String?, maxTurns: Int,
                                        workspacePath: String? = nil, tokenBudget: Int = 200_000) throws -> SingleCardIds {
        let camp = try ensureDefaultCamp()
        return try pool.write { db in
            let squad = SquadRecord(id: UUID().uuidString, campId: camp.id, name: squadName,
                                    memberIdsJson: "[]", workspacePath: workspacePath, createdAt: Date())
            try squad.insert(db)
            let mission = MissionRecord(id: UUID().uuidString, squadId: squad.id, goalRaw: goal,
                                        goalRefined: goal, status: "executing",
                                        budgetTokens: tokenBudget, spentTokens: 0, revision: 1, createdAt: Date())
            try mission.insert(db)
            let card = CardRecord(id: UUID().uuidString, missionId: mission.id,
                                  idemKey: "mission:\(mission.id):stage-1",
                                  title: cardTitle, descriptionText: cardDescription,
                                  expectedOutput: expectedOutput, assigneeId: assigneeId,
                                  status: .ready, blockedReasonJson: nil, dependsOnJson: "[]",
                                  maxTurns: maxTurns, tokenBudget: tokenBudget, createdAt: Date())
            try card.insert(db)
            try Self.appendEvent(db, missionId: mission.id, cardId: card.id, runId: nil,
                                 kind: "mission_created", payload: ["goal": .string(goal)])
            return SingleCardIds(missionId: mission.id, cardId: card.id, squadId: squad.id)
        }
    }

    public func card(id: String) throws -> CardRecord? {
        try pool.read { try CardRecord.fetchOne($0, key: id) }
    }
    public func events(cardId: String) throws -> [EventRecord] {
        try pool.read { db in
            try EventRecord.filter(Column("cardId") == cardId).order(Column("createdAt")).fetchAll(db)
        }
    }

    // MARK: 状态转移（穷举校验 + 事件同事务，spec §4.2/§5.1）
    public func transitionCard(id: String, to next: CardStatus, eventKind: String,
                               payload: JSONValue, blockedReasonJson: String? = nil) throws {
        try pool.write { db in
            guard var card = try CardRecord.fetchOne(db, key: id) else { return }
            guard card.status.canTransition(to: next) else {
                throw CardTransitionError(from: card.status, to: next)
            }
            card.status = next
            card.blockedReasonJson = next == .blocked ? blockedReasonJson : nil
            try card.update(db)
            try Self.appendEvent(db, missionId: card.missionId, cardId: card.id, runId: nil,
                                 kind: eventKind, payload: payload)
        }
    }

    static func appendEvent(_ db: Database, missionId: String?, cardId: String?, runId: String?,
                            kind: String, payload: JSONValue) throws {
        try EventRecord(id: UUID().uuidString, missionId: missionId, cardId: cardId, runId: runId,
                        kind: kind, payloadJson: (try? payload.encodedString()) ?? "{}",
                        createdAt: Date()).insert(db)
    }
}
```

- [ ] **Step 5: 确认通过** — `swift test --filter DatabaseTests` → PASS（4 tests）
- [ ] **Step 6: Commit** — `git commit -am "feat(m1): GRDB schema v1 + exhaustive card transitions + same-tx event projection"`

---

### Task 8: ToolDef 清单 + ToolExecutor 骨架

**Files:**
- Create: `Sources/AgentLoopCore/Tools/ToolDef.swift`（把 Task 4 的临时声明移到这里）、`Sources/AgentLoopCore/Tools/ToolExecutor.swift`
- Modify: `Sources/AgentLoopCore/Provider/LLMProvider.swift`（删临时 ToolDef）
- Test: `Tests/AgentLoopCoreTests/ToolExecutorTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import Testing
@testable import AgentLoopCore

@Test func m1ToolDefsComplete() {
    let names = ToolDef.m1Tools.map(\.name)
    #expect(names == ["complete_card", "block_card", "add_progress_note",
                      "list_dir", "read_file", "write_file", "web_fetch"])
    for def in ToolDef.m1Tools {
        #expect(def.inputSchema["type"]?.stringValue == "object")
        #expect(def.inputSchema["additionalProperties"]?.boolValue == false)
        #expect(!def.description.isEmpty)
    }
}

@Test func unknownToolReturnsError() async {
    let exec = ToolExecutor(handlers: [:])
    let outcome = await exec.execute(name: "no_such_tool", input: .object([:]))
    guard case .error(let msg) = outcome else { Issue.record("expected error"); return }
    #expect(msg.contains("no_such_tool"))
}
```

- [ ] **Step 2: 确认失败** → FAIL

- [ ] **Step 3: 实现**

```swift
// ToolDef.swift —— 从 LLMProvider.swift 移入原 struct，再加清单。
// 描述遵循 spec §6/调研 ACI 原则：说清何时用、参数含义、边界。
extension ToolDef {
    static func obj(_ props: [String: JSONValue], required: [String]) -> JSONValue {
        ["type": "object", "properties": .object(props),
         "required": .array(required.map(JSONValue.string)), "additionalProperties": false]
    }

    public static let completeCard = ToolDef(
        name: "complete_card",
        description: "完成当前小目标的唯一方式。校验通过后小目标进入 done。必须在工作真正完成并自查后调用。artifacts 里的 relativePath 必须是你已写入工作目录的真实文件；若确实无文件产物，给出 noArtifactReason。",
        inputSchema: obj([
            "outcome": ["type": "string", "description": "结果一句话"],
            "summary": ["type": "string", "description": "人话摘要，给用户和下游伙伴看"],
            "artifacts": ["type": "array", "items": obj([
                "relativePath": ["type": "string"], "kind": ["type": "string"], "label": ["type": "string"],
            ], required: ["relativePath", "kind", "label"])],
            "noArtifactReason": ["type": "string"],
            "verification": ["type": "array", "items": obj([
                "method": ["type": "string"], "passed": ["type": "boolean"], "note": ["type": "string"],
            ], required: ["method", "passed", "note"])],
            "next": ["type": "string"], "risks": ["type": "array", "items": ["type": "string"]],
        ], required: ["outcome", "summary", "verification", "risks"]))

    public static let blockCard = ToolDef(
        name: "block_card",
        description: "当你确定无法继续（缺信息/权限/反复失败）时调用，说明原因。这会挂起小目标等待用户处理。",
        inputSchema: obj([
            "reason": ["type": "string", "enum": ["needs_human_input", "tool_failure", "other"]],
            "detail": ["type": "string"],
        ], required: ["reason", "detail"]))

    public static let addProgressNote = ToolDef(
        name: "add_progress_note",
        description: "用一句话向用户汇报当前进展（会实时显示在界面上）。做完一个阶段就汇报一次。",
        inputSchema: obj(["text": ["type": "string"]], required: ["text"]))

    public static let listDir = ToolDef(
        name: "list_dir",
        description: "列出工作目录内某个相对路径下的文件与子目录。path 为空字符串表示根目录。",
        inputSchema: obj(["path": ["type": "string"]], required: ["path"]))

    public static let readFile = ToolDef(
        name: "read_file",
        description: "读取工作目录内的文本文件（相对路径）。",
        inputSchema: obj(["path": ["type": "string"]], required: ["path"]))

    public static let writeFile = ToolDef(
        name: "write_file",
        description: "把文本写入工作目录内的相对路径（自动创建中间目录，覆盖已有文件）。",
        inputSchema: obj(["path": ["type": "string"], "content": ["type": "string"]],
                         required: ["path", "content"]))

    public static let webFetch = ToolDef(
        name: "web_fetch",
        description: "抓取一个 https URL 的正文文本（只读，最多返回 ~50KB）。",
        inputSchema: obj(["url": ["type": "string"]], required: ["url"]))

    public static let m1Tools: [ToolDef] = [
        completeCard, blockCard, addProgressNote, listDir, readFile, writeFile, webFetch,
    ]
}

// ToolExecutor.swift
public enum ToolOutcome: Sendable {
    case result(String)                 // 正常结果 → tool_result
    case error(String)                  // is_error tool_result（模型可自愈）
    case completed(HandoffPayload)      // 终结：done
    case blocked(reason: String, detail: String) // 终结：blocked
}

public protocol ToolHandler: Sendable {
    func execute(input: JSONValue) async -> ToolOutcome
}

public struct ToolExecutor: Sendable {
    let handlers: [String: any ToolHandler]
    public init(handlers: [String: any ToolHandler]) { self.handlers = handlers }

    public func execute(name: String, input: JSONValue) async -> ToolOutcome {
        guard let h = handlers[name] else {
            return .error("未知工具 \(name)。可用工具：\(handlers.keys.sorted().joined(separator: ", "))")
        }
        return await h.execute(input: input)
    }
}
```

（`HandoffPayload` Task 10 才定义——先在 `Tools/HandoffPayload.swift` 放最小 struct 占位让编译通过：`public struct HandoffPayload: Sendable {}`，Task 10 替换。）

- [ ] **Step 4: 确认通过** → PASS（2 tests）
- [ ] **Step 5: Commit** — `git commit -am "feat(m1): tool definitions (ACI-style descriptions) + executor skeleton"`

---

### Task 9: FileTools（路径包含是安全边界，TDD 攻击用例先行）

**Files:**
- Create: `Sources/AgentLoopCore/Tools/FileTools.swift`
- Test: `Tests/AgentLoopCoreTests/FileToolsTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import Testing
import Foundation
@testable import AgentLoopCore

private func makeWorkspace() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("ws-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

@Test func writeReadListRoundTrip() async throws {
    let ws = try makeWorkspace()
    let tools = FileTools(workspaceRoot: ws)
    _ = await tools.write(input: ["path": "notes/清单.md", "content": "# 装备"])
    let read = await tools.read(input: ["path": "notes/清单.md"])
    guard case .result(let content) = read else { Issue.record("read failed"); return }
    #expect(content == "# 装备")
    let list = await tools.list(input: ["path": "notes"])
    guard case .result(let listing) = list else { return }
    #expect(listing.contains("清单.md"))
}

@Test func escapeAttemptsRejected() async throws {
    let ws = try makeWorkspace()
    let tools = FileTools(workspaceRoot: ws)
    for path in ["../outside.txt", "a/../../outside.txt", "/etc/passwd"] {
        let out = await tools.write(input: ["path": .string(path), "content": "x"])
        guard case .error(let msg) = out else { Issue.record("\(path) should be rejected"); return }
        #expect(msg.contains("工作目录"))
    }
}

@Test func symlinkEscapeRejected() async throws {
    let ws = try makeWorkspace()
    let outside = try makeWorkspace()
    let link = ws.appendingPathComponent("link")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
    let tools = FileTools(workspaceRoot: ws)
    let out = await tools.write(input: ["path": "link/escape.txt", "content": "x"])
    guard case .error = out else { Issue.record("symlink escape should be rejected"); return }
}

@Test func missingWorkspaceExplains() async {
    let tools = FileTools(workspaceRoot: nil)
    let out = await tools.read(input: ["path": "a.md"])
    guard case .error(let msg) = out else { return }
    #expect(msg.contains("未绑定工作目录"))
}
```

- [ ] **Step 2: 确认失败** → FAIL

- [ ] **Step 3: 实现**

> ⚠️ 编译要点：`Result<URL, String>` 需要 `String` 满足 `Error`。在 `Sources/AgentLoopCore/Support/` 加一行 `extension String: @retroactive Error {}`（Task 10/11 的 `HandoffPayload.parse` 同样依赖它）。不要为此改造 `resolve`/`parse` 的签名——测试已锁定 `.get()` 与 `case .failure(let msg)` 的用法。

```swift
import Foundation

public struct FileTools: Sendable {
    let workspaceRoot: URL?
    public init(workspaceRoot: URL?) { self.workspaceRoot = workspaceRoot }

    // 包含检查：标准化 + 解符号链接后必须仍在 root 前缀内（spec §8/§13）
    func resolve(_ relative: String, forWrite: Bool) -> Result<URL, String> {
        guard let root = workspaceRoot else {
            return .failure("未绑定工作目录。请在任务设置里选择一个工作目录后重试。")
        }
        if relative.hasPrefix("/") { return .failure("只允许工作目录内的相对路径，不接受绝对路径。") }
        let rootResolved = root.standardizedFileURL.resolvingSymlinksInPath()
        let candidate = rootResolved.appendingPathComponent(relative).standardizedFileURL
        // 写入时对「已存在的最深父目录」解符号链接（新文件本身还不存在）
        var probe = candidate
        while !FileManager.default.fileExists(atPath: probe.path), probe.pathComponents.count > 1 {
            probe = probe.deletingLastPathComponent()
        }
        let resolvedProbe = probe.resolvingSymlinksInPath()
        guard resolvedProbe.path == rootResolved.path
            || resolvedProbe.path.hasPrefix(rootResolved.path + "/") else {
            return .failure("路径越出了工作目录边界，被拒绝。请使用工作目录内的相对路径。")
        }
        _ = forWrite
        return .success(candidate)
    }

    public func list(input: JSONValue) async -> ToolOutcome {
        let rel = input["path"]?.stringValue ?? ""
        switch resolve(rel.isEmpty ? "." : rel, forWrite: false) {
        case .failure(let msg): return .error(msg)
        case .success(let url):
            do {
                let items = try FileManager.default.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: [.isDirectoryKey])
                let lines = items.map { item in
                    let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    return (isDir ? "[dir] " : "[file] ") + item.lastPathComponent
                }
                return .result(lines.isEmpty ? "(空目录)" : lines.sorted().joined(separator: "\n"))
            } catch { return .error("列目录失败：\(error.localizedDescription)") }
        }
    }

    public func read(input: JSONValue) async -> ToolOutcome {
        guard let rel = input["path"]?.stringValue else { return .error("缺少 path 参数") }
        switch resolve(rel, forWrite: false) {
        case .failure(let msg): return .error(msg)
        case .success(let url):
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                return .result(text.count > 100_000 ? String(text.prefix(100_000)) + "\n…(截断)" : text)
            } catch { return .error("读取失败：\(error.localizedDescription)") }
        }
    }

    public func write(input: JSONValue) async -> ToolOutcome {
        guard let rel = input["path"]?.stringValue, let content = input["content"]?.stringValue else {
            return .error("需要 path 与 content 两个参数")
        }
        switch resolve(rel, forWrite: true) {
        case .failure(let msg): return .error(msg)
        case .success(let url):
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try content.write(to: url, atomically: true, encoding: .utf8)
                return .result("已写入 \(rel)（\(content.utf8.count) 字节）")
            } catch { return .error("写入失败：\(error.localizedDescription)") }
        }
    }
}

// ToolHandler 适配
public struct FileToolHandler: ToolHandler {
    public enum Op: Sendable { case list, read, write }
    let tools: FileTools, op: Op
    public init(tools: FileTools, op: Op) { self.tools = tools; self.op = op }
    public func execute(input: JSONValue) async -> ToolOutcome {
        switch op {
        case .list: return await tools.list(input: input)
        case .read: return await tools.read(input: input)
        case .write: return await tools.write(input: input)
        }
    }
}
```

- [ ] **Step 4: 确认通过** — `swift test --filter FileToolsTests` → PASS（4 tests）
- [ ] **Step 5: Commit** — `git commit -am "feat(m1): file tools with symlink-aware path containment"`

---

### Task 10: WebFetchTool + HandoffPayload 校验

**Files:**
- Create: `Sources/AgentLoopCore/Tools/WebFetchTool.swift`
- Replace: `Sources/AgentLoopCore/Tools/HandoffPayload.swift`（替换 Task 8 的占位）
- Test: `Tests/AgentLoopCoreTests/WebFetchTests.swift`, `Tests/AgentLoopCoreTests/HandoffTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
// HandoffTests.swift
import Testing
@testable import AgentLoopCore

@Test func handoffParsesFromToolInput() throws {
    let input: JSONValue = [
        "outcome": "清单已完成", "summary": "整理了 12 件装备",
        "artifacts": [["relativePath": "清单.md", "kind": "markdown", "label": "装备清单"]],
        "verification": [["method": "重读检查完整性", "passed": true, "note": "分类齐全"]],
        "risks": [],
    ]
    let h = try HandoffPayload.parse(from: input).get()
    #expect(h.outcome == "清单已完成")
    #expect(h.artifacts.count == 1)
}

@Test func handoffRequiresArtifactsOrReason() {
    let input: JSONValue = [
        "outcome": "x", "summary": "y", "artifacts": [], "verification": [], "risks": [],
    ]
    guard case .failure(let msg) = HandoffPayload.parse(from: input) else {
        Issue.record("should fail"); return
    }
    #expect(msg.contains("noArtifactReason"))
}

@Test func handoffRequiresNonEmptyCoreFields() {
    let input: JSONValue = ["outcome": "", "summary": "y", "noArtifactReason": "纯讨论",
                            "artifacts": [], "verification": [], "risks": []]
    guard case .failure = HandoffPayload.parse(from: input) else { Issue.record("should fail"); return }
}
```

```swift
// WebFetchTests.swift（复用 Task 5 的 StubProtocol）
import Testing
import Foundation
@testable import AgentLoopCore

@Test func fetchesAndStripsHTML() async throws {
    StubProtocol.handler = { _ in
        (200, Data("<html><head><style>x{}</style></head><body><h1>标题</h1><p>正文 &amp; 内容</p></body></html>".utf8),
         ["Content-Type": "text/html"])
    }
    let cfg = URLSessionConfiguration.ephemeral; cfg.protocolClasses = [StubProtocol.self]
    let tool = WebFetchTool(session: URLSession(configuration: cfg))
    let out = await tool.execute(input: ["url": "https://example.com/a"])
    guard case .result(let text) = out else { Issue.record("fetch failed"); return }
    #expect(text.contains("标题") && text.contains("正文 & 内容"))
    #expect(!text.contains("<h1>") && !text.contains("style"))
}

@Test func rejectsNonHTTPS() async {
    let tool = WebFetchTool(session: .shared)
    let out = await tool.execute(input: ["url": "file:///etc/passwd"])
    guard case .error(let msg) = out else { return }
    #expect(msg.contains("https"))
}
```

- [ ] **Step 2: 确认失败** → FAIL

- [ ] **Step 3: 实现**

```swift
// HandoffPayload.swift（spec §7 v1）
import Foundation

public struct HandoffPayload: Sendable, Equatable, Codable {
    public struct ArtifactDecl: Sendable, Equatable, Codable {
        public var relativePath: String, kind: String, label: String
    }
    public struct Verification: Sendable, Equatable, Codable {
        public var method: String, passed: Bool, note: String
    }
    public var outcome: String, summary: String
    public var artifacts: [ArtifactDecl], noArtifactReason: String?
    public var verification: [Verification], next: String?, risks: [String]

    // 写入时校验（spec §7）：失败信息将作为 is_error tool_result 返给伙伴修正
    public static func parse(from input: JSONValue) -> Result<HandoffPayload, String> {
        do {
            let data = try JSONEncoder().encode(input)
            let h = try JSONDecoder().decode(HandoffPayload.self, from: data)
            if h.outcome.trimmingCharacters(in: .whitespaces).isEmpty { return .failure("outcome 不能为空") }
            if h.summary.trimmingCharacters(in: .whitespaces).isEmpty { return .failure("summary 不能为空") }
            if h.artifacts.isEmpty && (h.noArtifactReason ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
                return .failure("交接包校验失败：artifacts 为空时必须提供 noArtifactReason 说明为何没有文件产物")
            }
            return .success(h)
        } catch {
            return .failure("交接包格式不正确：\(error)。请按 complete_card 的参数 schema 重新提交。")
        }
    }
}
```

```swift
// WebFetchTool.swift
import Foundation

public struct WebFetchTool: ToolHandler {
    let session: URLSession
    let maxBytes = 50_000
    public init(session: URLSession = .shared) { self.session = session }

    public func execute(input: JSONValue) async -> ToolOutcome {
        guard let urlStr = input["url"]?.stringValue,
              let url = URL(string: urlStr), url.scheme == "https" else {
            return .error("需要一个 https:// 开头的合法 URL")
        }
        do {
            let (data, response) = try await session.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else { return .error("HTTP \(status)") }
            let raw = String(data: data, encoding: .utf8) ?? ""
            let text = Self.stripHTML(raw)
            return .result(text.utf8.count > maxBytes
                ? String(text.prefix(maxBytes)) + "\n…(截断)" : text)
        } catch { return .error("抓取失败：\(error.localizedDescription)") }
    }

    static func stripHTML(_ html: String) -> String {
        var s = html
        for tag in ["script", "style"] {
            s = s.replacingOccurrences(of: "<\(tag)[\\s\\S]*?</\(tag)>",
                                       with: "", options: .regularExpression)
        }
        s = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let entities = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&nbsp;": " "]
        for (k, v) in entities { s = s.replacingOccurrences(of: k, with: v) }
        return s.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

- [ ] **Step 4: 确认通过** → PASS（5 tests）
- [ ] **Step 5: Commit** — `git commit -am "feat(m1): web_fetch tool + handoff payload write-time validation"`

---

### Task 11: BoardTools（complete/block/note + 产物先耐久后完成）

**Files:**
- Create: `Sources/AgentLoopCore/Tools/BoardTools.swift`
- Test: `Tests/AgentLoopCoreTests/BoardToolsTests.swift`

不变量（spec §5.2-2）：**先**把声明产物从工作目录拷贝到耐久存储（copy 不 move，含包含检查），**再**在同一事务里落 done + 事件 + artifact 行。任一产物缺失 → 整体失败为 `.error`，卡片保持 running。

- [ ] **Step 1: 写失败测试**

```swift
import Testing
import Foundation
@testable import AgentLoopCore

private struct Fixture {
    let db: AppDatabase, ws: URL, store: URL, cardId: String, tools: BoardTools
}
private func makeFixture() throws -> Fixture {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let ws = base.appendingPathComponent("ws"), store = base.appendingPathComponent("artifacts")
    try FileManager.default.createDirectory(at: ws, withIntermediateDirectories: true)
    let db = try AppDatabase(path: base.appendingPathComponent("t.sqlite").path)
    let ids = try db.createSingleCardMission(campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e", assigneeId: nil,
        maxTurns: 30, workspacePath: ws.path)
    try db.transitionCard(id: ids.cardId, to: .running, eventKind: "card_started", payload: .object([:]))
    let tools = BoardTools(db: db, cardId: ids.cardId, runId: "run-1",
                           workspaceRoot: ws, artifactStoreRoot: store)
    return Fixture(db: db, ws: ws, store: store, cardId: ids.cardId, tools: tools)
}

@Test func completeCopiesArtifactBeforeDone() async throws {
    let f = try makeFixture()
    try "# 清单".write(to: f.ws.appendingPathComponent("清单.md"), atomically: true, encoding: .utf8)
    let out = await f.tools.complete(input: [
        "outcome": "完成", "summary": "已整理",
        "artifacts": [["relativePath": "清单.md", "kind": "markdown", "label": "装备清单"]],
        "verification": [["method": "重读", "passed": true, "note": "ok"]], "risks": [],
    ])
    guard case .completed = out else { Issue.record("should complete"); return }
    let card = try f.db.card(id: f.cardId)
    #expect(card?.status == .done)
    let artifacts = try f.db.artifacts(cardId: f.cardId)
    #expect(artifacts.count == 1)
    // 耐久路径存在且在 store 下；原文件仍在（copy 不 move）
    #expect(FileManager.default.fileExists(atPath: artifacts[0].path))
    #expect(artifacts[0].path.hasPrefix(f.store.path))
    #expect(FileManager.default.fileExists(atPath: f.ws.appendingPathComponent("清单.md").path))
}

@Test func missingArtifactKeepsCardRunning() async throws {
    let f = try makeFixture()
    let out = await f.tools.complete(input: [
        "outcome": "完成", "summary": "x",
        "artifacts": [["relativePath": "不存在.md", "kind": "md", "label": "l"]],
        "verification": [], "risks": [],
    ])
    guard case .error(let msg) = out else { Issue.record("should error"); return }
    #expect(msg.contains("不存在.md"))
    #expect(try f.db.card(id: f.cardId)?.status == .running)  // 未被污染
    #expect(try f.db.artifacts(cardId: f.cardId).isEmpty)
}

@Test func invalidHandoffKeepsCardRunning() async throws {
    let f = try makeFixture()
    let out = await f.tools.complete(input: ["outcome": "", "summary": "", "artifacts": [],
                                             "verification": [], "risks": []])
    guard case .error = out else { Issue.record("should error"); return }
    #expect(try f.db.card(id: f.cardId)?.status == .running)
}

@Test func blockRecordsTypedReason() async throws {
    let f = try makeFixture()
    let out = await f.tools.block(input: ["reason": "needs_human_input", "detail": "缺预算数字"])
    guard case .blocked = out else { return }
    let card = try f.db.card(id: f.cardId)
    #expect(card?.status == .blocked)
    #expect(card?.blockedReasonJson?.contains("needs_human_input") == true)
}

@Test func progressNoteAppendsEvent() async throws {
    let f = try makeFixture()
    _ = await f.tools.progressNote(input: ["text": "整理到第 8 件"])
    let events = try f.db.events(cardId: f.cardId)
    #expect(events.contains { $0.kind == "progress_note" && $0.payloadJson.contains("第 8 件") })
}
```

- [ ] **Step 2: 确认失败** → FAIL

- [ ] **Step 3: 实现**（同时给 `AppDatabase` 补 `artifacts(cardId:)` 查询与 `completeCard`/`blockCard` 事务方法）

```swift
// AppDatabase 补充
extension AppDatabase {
    public func artifacts(cardId: String) throws -> [ArtifactRecord] {
        try pool.read { db in
            try ArtifactRecord.filter(Column("cardId") == cardId).fetchAll(db)
        }
    }

    /// 产物行 + done 转移 + 完成事件，单事务（调用前产物文件必须已拷贝成功）
    public func completeCard(id: String, runId: String?, handoff: HandoffPayload,
                             durableArtifacts: [(decl: HandoffPayload.ArtifactDecl, durablePath: String)]) throws {
        try pool.write { db in
            guard var card = try CardRecord.fetchOne(db, key: id) else { return }
            guard card.status.canTransition(to: .done) else {
                throw CardTransitionError(from: card.status, to: .done)
            }
            for (decl, path) in durableArtifacts {
                try ArtifactRecord(id: UUID().uuidString, cardId: id, path: path,
                                   kind: decl.kind, label: decl.label, createdAt: Date()).insert(db)
            }
            card.status = .done
            try card.update(db)
            let payloadData = try JSONEncoder().encode(handoff)
            try Self.appendEvent(db, missionId: card.missionId, cardId: id, runId: runId,
                                 kind: "card_completed",
                                 payload: try JSONValue.decoded(from: String(data: payloadData, encoding: .utf8) ?? "{}"))
        }
    }

    public func blockCard(id: String, runId: String?, reason: String, detail: String) throws {
        let reasonJson = try? JSONValue.object(["reason": .string(reason), "detail": .string(detail)]).encodedString()
        try pool.write { db in
            guard var card = try CardRecord.fetchOne(db, key: id) else { return }
            guard card.status.canTransition(to: .blocked) else {
                throw CardTransitionError(from: card.status, to: .blocked)
            }
            card.status = .blocked
            card.blockedReasonJson = reasonJson
            try card.update(db)
            try Self.appendEvent(db, missionId: card.missionId, cardId: id, runId: runId,
                                 kind: "card_blocked",
                                 payload: ["reason": .string(reason), "detail": .string(detail)])
        }
    }
}

// BoardTools.swift
import Foundation

public struct BoardTools: Sendable {
    let db: AppDatabase, cardId: String, runId: String
    let workspaceRoot: URL?, artifactStoreRoot: URL
    public init(db: AppDatabase, cardId: String, runId: String,
                workspaceRoot: URL?, artifactStoreRoot: URL) {
        self.db = db; self.cardId = cardId; self.runId = runId
        self.workspaceRoot = workspaceRoot; self.artifactStoreRoot = artifactStoreRoot
    }

    public func complete(input: JSONValue) async -> ToolOutcome {
        let handoff: HandoffPayload
        switch HandoffPayload.parse(from: input) {
        case .failure(let msg): return .error(msg)
        case .success(let h): handoff = h
        }
        // 1) 先拷产物到耐久存储（spec §5.2-2）
        var durable: [(HandoffPayload.ArtifactDecl, String)] = []
        let fileTools = FileTools(workspaceRoot: workspaceRoot)
        for decl in handoff.artifacts {
            switch fileTools.resolve(decl.relativePath, forWrite: false) {
            case .failure(let msg): return .error("产物 \(decl.relativePath)：\(msg)")
            case .success(let src):
                guard FileManager.default.fileExists(atPath: src.path) else {
                    return .error("声明的产物 \(decl.relativePath) 在工作目录中不存在。请先用 write_file 写入，或修正 relativePath。")
                }
                let destDir = artifactStoreRoot.appendingPathComponent(cardId)
                let dest = destDir.appendingPathComponent(src.lastPathComponent)
                do {
                    try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
                    if FileManager.default.fileExists(atPath: dest.path) {
                        try FileManager.default.removeItem(at: dest)
                    }
                    try FileManager.default.copyItem(at: src, to: dest)
                    durable.append((decl, dest.path))
                } catch { return .error("产物拷贝失败：\(error.localizedDescription)") }
            }
        }
        // 2) 再落库（单事务）
        do {
            try db.completeCard(id: cardId, runId: runId, handoff: handoff, durableArtifacts: durable)
            return .completed(handoff)
        } catch { return .error("完成落库失败：\(error)") }
    }

    public func block(input: JSONValue) async -> ToolOutcome {
        let reason = input["reason"]?.stringValue ?? "other"
        let detail = input["detail"]?.stringValue ?? ""
        do {
            try db.blockCard(id: cardId, runId: runId, reason: reason, detail: detail)
            return .blocked(reason: reason, detail: detail)
        } catch { return .error("挂起失败：\(error)") }
    }

    public func progressNote(input: JSONValue) async -> ToolOutcome {
        let text = input["text"]?.stringValue ?? ""
        do {
            try db.pool.write { dbc in
                guard let card = try CardRecord.fetchOne(dbc, key: cardId) else { return }
                try AppDatabase.appendEvent(dbc, missionId: card.missionId, cardId: cardId,
                                            runId: runId, kind: "progress_note", payload: ["text": .string(text)])
            }
            return .result("已汇报")
        } catch { return .error("汇报失败：\(error)") }
    }
}

// ToolHandler 适配
public struct BoardToolHandler: ToolHandler {
    public enum Op: Sendable { case complete, block, note }
    let tools: BoardTools, op: Op
    public init(tools: BoardTools, op: Op) { self.tools = tools; self.op = op }
    public func execute(input: JSONValue) async -> ToolOutcome {
        switch op {
        case .complete: return await tools.complete(input: input)
        case .block: return await tools.block(input: input)
        case .note: return await tools.progressNote(input: input)
        }
    }
}
```

（`FileTools.resolve` 需从 `private` 改为 internal——本包内 BoardTools 复用同一包含检查。）

- [ ] **Step 4: 确认通过** — `swift test --filter BoardToolsTests` → PASS（5 tests）
- [ ] **Step 5: Commit** — `git commit -am "feat(m1): board tools — durable-artifacts-before-done invariant"`

---

### Task 12: ContextPacket（冷启动上下文包）

**Files:**
- Create: `Sources/AgentLoopCore/Loop/ContextPacket.swift`
- Test: `Tests/AgentLoopCoreTests/ContextPacketTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import Testing
@testable import AgentLoopCore

@Test func packetContainsContractAndCard() {
    let p = ContextPacket(
        companionName: "阿规", rolePrompt: "你是产品伙伴",
        cardTitle: "写装备清单", cardDescription: "整理一份露营装备清单",
        expectedOutput: "一份分类清晰的 markdown 清单文件",
        workspacePath: "/tmp/ws", upstreamHandoffs: [])
    // system：职责 + 工具契约 + 交接包格式（冻结前缀，spec §6.3 缓存）
    #expect(p.system.contains("你是产品伙伴"))
    #expect(p.system.contains("complete_card"))
    #expect(p.system.contains("block_card"))
    // user：卡片信息 + 工作目录
    guard case .text(let user) = p.firstUserMessage.content[0] else { return }
    #expect(user.contains("写装备清单"))
    #expect(user.contains("分类清晰"))
    #expect(user.contains("/tmp/ws"))
}

@Test func systemIsStableAcrossCards() {
    // 缓存要求：同伙伴不同卡片，system 完全一致（卡片信息只进 user 消息）
    let a = ContextPacket(companionName: "阿规", rolePrompt: "r", cardTitle: "A",
                          cardDescription: "a", expectedOutput: "x", workspacePath: nil, upstreamHandoffs: [])
    let b = ContextPacket(companionName: "阿规", rolePrompt: "r", cardTitle: "B",
                          cardDescription: "b", expectedOutput: "y", workspacePath: nil, upstreamHandoffs: [])
    #expect(a.system == b.system)
}
```

- [ ] **Step 2: 确认失败** → FAIL

- [ ] **Step 3: 实现**

```swift
public struct ContextPacket: Sendable {
    public let system: String
    public let firstUserMessage: APIMessage

    public init(companionName: String, rolePrompt: String, cardTitle: String,
                cardDescription: String, expectedOutput: String,
                workspacePath: String?, upstreamHandoffs: [String]) {
        // system 前缀冻结：任何随卡片变化的内容禁止进入（spec §6.3）
        self.system = """
        你的名字是\(companionName)。\(rolePrompt)

        # 工作契约
        你在一个协作系统中执行「小目标」。规则：
        1. 用工具完成真实工作；文件操作仅限工作目录内的相对路径。
        2. 每完成一个阶段用 add_progress_note 汇报一句话进展。
        3. 工作完成并自查后，必须调用 complete_card 提交交接包（outcome/summary/artifacts/verification/risks）收尾；artifacts 必须是已写入工作目录的真实文件。
        4. 确定无法继续时调用 block_card 说明原因。
        5. complete_card 或 block_card 是仅有的两种结束方式；不要用普通文本宣布完成。
        """
        var user = """
        # 当前小目标
        标题：\(cardTitle)
        说明：\(cardDescription)
        预期产出：\(expectedOutput)
        """
        if let ws = workspacePath { user += "\n工作目录：\(ws)（工具中一律使用相对路径）" }
        else { user += "\n（本任务未绑定工作目录，文件工具不可用）" }
        if !upstreamHandoffs.isEmpty {
            user += "\n\n# 上游交接\n" + upstreamHandoffs.joined(separator: "\n---\n")
        }
        user += "\n\n现在开始工作。"
        self.firstUserMessage = .user(user)
    }
}
```

- [ ] **Step 4: 确认通过** → PASS（2 tests）
- [ ] **Step 5: Commit** — `git commit -am "feat(m1): cold-start context packet with frozen system prefix"`

---

### Task 13: AgentLoop 核心（M1 最重要的任务）

**Files:**
- Create: `Sources/AgentLoopCore/Loop/AgentLoop.swift`
- Test: `Tests/AgentLoopCoreTests/AgentLoopTests.swift`

循环规则（spec §6.1，全部有对应测试）：
- `tool_use` → 执行全部工具调用，结果合并进**一条** user 消息，继续。
- 终结工具（complete/block）→ 立即结束，不再调 API。
- `end_turn` 未收尾 → 注入提醒一次；再犯 → blocked(no_terminator)。
- 同一工具连续 3 次 `error` → blocked(tool_failure)。工具成功清零计数。
- 轮数达 maxTurns → blocked(budget_exhausted)。
- `refusal` → blocked(refusal)，不重试。
- assistant content **原样**追加（含 unknown 块）。

- [ ] **Step 1: 写失败测试**

```swift
import Testing
import Foundation
@testable import AgentLoopCore

// 内存版工具桩：可编程返回序列
final class StubHandler: ToolHandler, @unchecked Sendable {
    private let lock = NSLock()
    private var outcomes: [ToolOutcome]
    private(set) var calls: [JSONValue] = []
    init(_ outcomes: [ToolOutcome]) { self.outcomes = outcomes }
    func execute(input: JSONValue) async -> ToolOutcome {
        lock.lock(); defer { lock.unlock() }
        calls.append(input)
        return outcomes.isEmpty ? .error("stub exhausted") : outcomes.removeFirst()
    }
}

private func runLoop(script: [TurnResult], handlers: [String: any ToolHandler],
                     maxTurns: Int = 10) async throws -> (outcome: LoopOutcome, events: [AgentEvent], mock: MockProvider) {
    let mock = MockProvider(script: script)
    let loop = AgentLoop(provider: mock, executor: ToolExecutor(handlers: handlers),
                         packet: ContextPacket(companionName: "T", rolePrompt: "r", cardTitle: "t",
                                               cardDescription: "d", expectedOutput: "e",
                                               workspacePath: nil, upstreamHandoffs: []),
                         tools: ToolDef.m1Tools, maxTurns: maxTurns, maxTokensPerTurn: 4096)
    var events: [AgentEvent] = []
    var final: LoopOutcome?
    for try await ev in loop.run() {
        events.append(ev)
        if case .finished(let o) = ev { final = o }
    }
    return (try #require(final), events, mock)
}

private let doneHandoff: JSONValue = [
    "outcome": "done", "summary": "s", "noArtifactReason": "纯文本任务",
    "artifacts": [], "verification": [], "risks": [],
]

@Test func happyPathToolThenComplete() async throws {
    let handoff = try HandoffPayload.parse(from: doneHandoff).get()
    let write = StubHandler([.result("已写入")])
    let complete = StubHandler([.completed(handoff)])
    let r = try await runLoop(
        script: [
            TurnResult(content: [.text("开工"),
                                 .toolUse(id: "t1", name: "write_file", input: ["path": "a.md", "content": "x"])],
                       stopReason: .toolUse),
            TurnResult(content: [.toolUse(id: "t2", name: "complete_card", input: doneHandoff)],
                       stopReason: .toolUse),
        ],
        handlers: ["write_file": write, "complete_card": complete])
    guard case .completed = r.outcome else { Issue.record("expected completed"); return }
    #expect(write.calls.count == 1 && complete.calls.count == 1)
    // 第二次 API 调用的历史应含：assistant(带toolUse) + user(tool_result)
    let secondHistory = await r.mock.recordedHistories[1]
    #expect(secondHistory.count == 3)
    #expect(secondHistory[1].role == .assistant)
    #expect(secondHistory[2].role == .user)
    guard case .toolResult(let id, _, let isErr) = secondHistory[2].content[0] else { return }
    #expect(id == "t1" && isErr == false)
}

@Test func endTurnWithoutTerminatorRemindsOnceThenBlocks() async throws {
    let r = try await runLoop(
        script: [
            TurnResult(content: [.text("我做完了！")], stopReason: .endTurn),
            TurnResult(content: [.text("真的做完了")], stopReason: .endTurn),
        ], handlers: [:])
    guard case .blocked(let reason, _) = r.outcome else { Issue.record("expected blocked"); return }
    #expect(reason == "no_terminator")
    // 提醒消息进了第二次调用的历史
    let second = await r.mock.recordedHistories[1]
    guard case .text(let reminder) = second.last?.content.first else { return }
    #expect(reminder.contains("complete_card"))
}

@Test func toolErrorSelfHealsButThreeStrikesBlocks() async throws {
    let failing = StubHandler([.error("坏了1"), .error("坏了2"), .error("坏了3")])
    let mkTurn = { TurnResult(content: [.toolUse(id: UUID().uuidString, name: "read_file",
                                                 input: ["path": "x"])], stopReason: .toolUse) }
    let r = try await runLoop(script: [mkTurn(), mkTurn(), mkTurn(), mkTurn()],
                              handlers: ["read_file": failing])
    guard case .blocked(let reason, let detail) = r.outcome else { Issue.record("expected blocked"); return }
    #expect(reason == "tool_failure")
    #expect(detail.contains("read_file"))
    #expect(failing.calls.count == 3)
    // 前两次错误以 is_error tool_result 回传（自愈通道），历史可见
    let third = await r.mock.recordedHistories[2]
    guard case .toolResult(_, _, let isErr) = third.last?.content.first else { return }
    #expect(isErr == true)
}

@Test func maxTurnsExhaustionBlocks() async throws {
    let note = StubHandler(Array(repeating: ToolOutcome.result("ok"), count: 5))
    let mkTurn = { TurnResult(content: [.toolUse(id: UUID().uuidString, name: "add_progress_note",
                                                 input: ["text": "..."])], stopReason: .toolUse) }
    let r = try await runLoop(script: (0..<5).map { _ in mkTurn() },
                              handlers: ["add_progress_note": note], maxTurns: 3)
    guard case .blocked(let reason, _) = r.outcome else { return }
    #expect(reason == "budget_exhausted")
}

@Test func refusalBlocksImmediately() async throws {
    let r = try await runLoop(script: [TurnResult(content: [], stopReason: .refusal)], handlers: [:])
    guard case .blocked(let reason, _) = r.outcome else { return }
    #expect(reason == "refusal")
    #expect(await r.mock.callCount == 1) // 不重试
}

@Test func unknownBlocksPreservedInHistory() async throws {
    let thinking = ContentBlock.unknown(["type": "thinking", "thinking": "hmm", "signature": "sig"])
    let r = try await runLoop(
        script: [
            TurnResult(content: [thinking, .toolUse(id: "t", name: "add_progress_note", input: ["text": "x"])],
                       stopReason: .toolUse),
            TurnResult(content: [.text("done")], stopReason: .endTurn),
            TurnResult(content: [.text("done")], stopReason: .endTurn),
        ],
        handlers: ["add_progress_note": StubHandler([.result("ok")])])
    let second = await r.mock.recordedHistories[1]
    #expect(second[1].content.first == thinking) // 原样在历史里
}
```

- [ ] **Step 2: 确认失败** → FAIL

- [ ] **Step 3: 实现**

```swift
import Foundation

public enum LoopOutcome: Sendable {
    case completed(HandoffPayload)
    case blocked(reason: String, detail: String)
}

public enum AgentEvent: Sendable {
    case textDelta(String)
    case toolStarted(name: String)
    case toolFinished(name: String, isError: Bool)
    case turnEnded(usage: Usage)
    case finished(LoopOutcome)
}

public struct AgentLoop: Sendable {
    let provider: any LLMProvider
    let executor: ToolExecutor
    let packet: ContextPacket
    let tools: [ToolDef]
    let maxTurns: Int
    let maxTokensPerTurn: Int

    public init(provider: any LLMProvider, executor: ToolExecutor, packet: ContextPacket,
                tools: [ToolDef], maxTurns: Int, maxTokensPerTurn: Int) {
        self.provider = provider; self.executor = executor; self.packet = packet
        self.tools = tools; self.maxTurns = maxTurns; self.maxTokensPerTurn = maxTokensPerTurn
    }

    public func run() -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let outcome = try await loop(continuation: continuation)
                    continuation.yield(.finished(outcome))
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func loop(continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation) async throws -> LoopOutcome {
        var history: [APIMessage] = [packet.firstUserMessage]
        var reminded = false
        var pauseTurnCount = 0
        var strikes: [String: Int] = [:]
        var turns = 0

        while turns < maxTurns {
            turns += 1
            try Task.checkCancellation()

            var turn: TurnResult?
            for try await ev in provider.streamTurn(system: packet.system, history: history,
                                                    tools: tools, maxTokens: maxTokensPerTurn) {
                switch ev {
                case .textDelta(let t): continuation.yield(.textDelta(t))
                case .turn(let t): turn = t
                }
            }
            guard let result = turn else { throw ProviderError.malformedStream("no turn result") }
            history.append(.assistant(result.content))   // 原样追加（spec §6.1）
            continuation.yield(.turnEnded(usage: result.usage))

            switch result.stopReason {
            case .toolUse:
                var toolResults: [ContentBlock] = []
                for use in result.toolUses {
                    continuation.yield(.toolStarted(name: use.name))
                    let outcome = await executor.execute(name: use.name, input: use.input)
                    switch outcome {
                    case .completed(let handoff):
                        continuation.yield(.toolFinished(name: use.name, isError: false))
                        return .completed(handoff)
                    case .blocked(let reason, let detail):
                        continuation.yield(.toolFinished(name: use.name, isError: false))
                        return .blocked(reason: reason, detail: detail)
                    case .result(let content):
                        strikes[use.name] = 0
                        continuation.yield(.toolFinished(name: use.name, isError: false))
                        toolResults.append(.toolResult(toolUseId: use.id, content: content, isError: false))
                    case .error(let message):
                        let n = (strikes[use.name] ?? 0) + 1
                        strikes[use.name] = n
                        continuation.yield(.toolFinished(name: use.name, isError: true))
                        if n >= 3 {
                            return .blocked(reason: "tool_failure",
                                            detail: "工具 \(use.name) 连续失败 3 次：\(message)")
                        }
                        toolResults.append(.toolResult(toolUseId: use.id, content: message, isError: true))
                    }
                }
                history.append(.user(toolResults: toolResults))

            case .endTurn, .maxTokens, .stopSequence, .other:
                if reminded {
                    return .blocked(reason: "no_terminator",
                                    detail: "伙伴结束了发言但没有调用 complete_card / block_card 收尾")
                }
                reminded = true
                history.append(.user("你还没有收尾。必须调用 complete_card（工作已完成）或 block_card（无法继续）之一来结束这个小目标。"))

            case .pauseTurn:
                pauseTurnCount += 1
                if pauseTurnCount > 5 {
                    return .blocked(reason: "no_terminator", detail: "pause_turn 续接超过 5 次")
                }
                // 原样续接：不追加任何 user 消息

            case .refusal:
                return .blocked(reason: "refusal", detail: "模型拒绝了这个请求，未重试")

            case .contextExceeded:
                return .blocked(reason: "budget_exhausted", detail: "上下文超限（M1 未实现压缩）")
            }
        }
        return .blocked(reason: "budget_exhausted", detail: "达到最大轮数 \(maxTurns)")
    }
}
```

- [ ] **Step 4: 确认通过** — `swift test --filter AgentLoopTests` → PASS（6 tests）
- [ ] **Step 5: 全量回归** — `swift test` → 全部 PASS
- [ ] **Step 6: Commit** — `git commit -am "feat(m1): agent loop — terminator contract, self-heal, strikes, budgets"`

---

### Task 14: CardRunner（loop ↔ 数据库编排：Run 记录 + 状态落库）

**Files:**
- Create: `Sources/AgentLoopCore/Loop/CardRunner.swift`
- Test: `Tests/AgentLoopCoreTests/CardRunnerTests.swift`

AgentLoop 是纯逻辑；CardRunner 负责：起 Run 记录 → ready→running 转移 → 跑 loop 转发事件 → 终态落 Run（completed/blocked 已由 BoardTools 落卡片状态，此处只收 Run 与用量）。

- [ ] **Step 1: 写失败测试**

```swift
import Testing
import Foundation
@testable import AgentLoopCore

@Test func runnerDrivesCardToDoneWithRunRecord() async throws {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let ws = base.appendingPathComponent("ws")
    try FileManager.default.createDirectory(at: ws, withIntermediateDirectories: true)
    try "内容".write(to: ws.appendingPathComponent("out.md"), atomically: true, encoding: .utf8)
    let db = try AppDatabase(path: base.appendingPathComponent("t.sqlite").path)
    let ids = try db.createSingleCardMission(campName: "c", squadName: "s", goal: "g",
        cardTitle: "t", cardDescription: "d", expectedOutput: "e", assigneeId: nil,
        maxTurns: 10, workspacePath: ws.path)

    let handoffInput: JSONValue = [
        "outcome": "ok", "summary": "s",
        "artifacts": [["relativePath": "out.md", "kind": "markdown", "label": "产出"]],
        "verification": [["method": "重读", "passed": true, "note": "ok"]], "risks": [],
    ]
    let mock = MockProvider(script: [
        TurnResult(content: [.toolUse(id: "t1", name: "complete_card", input: handoffInput)],
                   stopReason: .toolUse, usage: Usage(inputTokens: 100, outputTokens: 50)),
    ])
    let runner = CardRunner(db: db, provider: mock,
                            artifactStoreRoot: base.appendingPathComponent("store"))
    var sawFinished = false
    for try await ev in try runner.run(cardId: ids.cardId, companionName: "阿规", rolePrompt: "r") {
        if case .finished(.completed) = ev { sawFinished = true }
    }
    #expect(sawFinished)
    #expect(try db.card(id: ids.cardId)?.status == .done)
    let runs = try db.runs(cardId: ids.cardId)
    #expect(runs.count == 1)
    #expect(runs[0].outcome == "completed")
    #expect(runs[0].tokensOut == 50)
    #expect(runs[0].endedAt != nil)
}
```

- [ ] **Step 2: 确认失败** → FAIL

- [ ] **Step 3: 实现**（`AppDatabase` 补 `runs(cardId:)`、`insertRun`、`finishRun`、`squad(forCard:)`、`companion(id:)`——同前模式，单事务、事件伴随；此处省略样板，实现者按 Task 7/11 的模式写并让测试通过。`companion(id:)` 也是 Task 15 ChatService 的依赖）

```swift
import Foundation

public struct CardRunner: Sendable {
    let db: AppDatabase
    let provider: any LLMProvider
    let artifactStoreRoot: URL

    public init(db: AppDatabase, provider: any LLMProvider, artifactStoreRoot: URL) {
        self.db = db; self.provider = provider; self.artifactStoreRoot = artifactStoreRoot
    }

    public func run(cardId: String, companionName: String, rolePrompt: String)
        throws -> AsyncThrowingStream<AgentEvent, Error> {
        guard let card = try db.card(id: cardId) else {
            throw CardTransitionError(from: .todo, to: .running)
        }
        let squad = try db.squad(forCard: cardId)
        let workspace = squad?.workspacePath.map { URL(fileURLWithPath: $0) }
        let runId = UUID().uuidString
        try db.insertRun(id: runId, cardId: cardId)
        try db.transitionCard(id: cardId, to: .running, eventKind: "card_started",
                              payload: ["runId": .string(runId)])

        let board = BoardTools(db: db, cardId: cardId, runId: runId,
                               workspaceRoot: workspace, artifactStoreRoot: artifactStoreRoot)
        let files = FileTools(workspaceRoot: workspace)
        let executor = ToolExecutor(handlers: [
            "complete_card": BoardToolHandler(tools: board, op: .complete),
            "block_card": BoardToolHandler(tools: board, op: .block),
            "add_progress_note": BoardToolHandler(tools: board, op: .note),
            "list_dir": FileToolHandler(tools: files, op: .list),
            "read_file": FileToolHandler(tools: files, op: .read),
            "write_file": FileToolHandler(tools: files, op: .write),
            "web_fetch": WebFetchTool(),
        ])
        let packet = ContextPacket(companionName: companionName, rolePrompt: rolePrompt,
                                   cardTitle: card.title, cardDescription: card.descriptionText,
                                   expectedOutput: card.expectedOutput,
                                   workspacePath: workspace?.path, upstreamHandoffs: [])
        let loop = AgentLoop(provider: provider, executor: executor, packet: packet,
                             tools: ToolDef.m1Tools, maxTurns: card.maxTurns, maxTokensPerTurn: 8192)

        return AsyncThrowingStream { continuation in
            let task = Task {
                var totalIn = 0, totalOut = 0, turns = 0
                do {
                    for try await ev in loop.run() {
                        if case .turnEnded(let usage) = ev {
                            totalIn += usage.inputTokens; totalOut += usage.outputTokens; turns += 1
                        }
                        continuation.yield(ev)
                        if case .finished(let outcome) = ev {
                            let label = if case .completed = outcome { "completed" } else { "blocked" }
                            try db.finishRun(id: runId, outcome: label,
                                             turns: turns, tokensIn: totalIn, tokensOut: totalOut)
                        }
                    }
                    continuation.finish()
                } catch {
                    try? db.finishRun(id: runId, outcome: "failed",
                                      turns: turns, tokensIn: totalIn, tokensOut: totalOut)
                    // 传输层错误：卡片回 blocked 以便 UI 呈现（若已终态则忽略转移错误）
                    try? db.blockCard(id: cardId, runId: runId, reason: "other",
                                      detail: "运行错误：\(error)")
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
```

- [ ] **Step 4: 确认通过 + 全量回归** — `swift test` → 全部 PASS
- [ ] **Step 5: Commit** — `git commit -am "feat(m1): card runner — run records, status transitions, error containment"`

---

### Task 15: ChatService（伙伴私聊，纯对话 + 持久化）

**Files:**
- Create: `Sources/AgentLoopCore/Chat/ChatService.swift`
- Test: `Tests/AgentLoopCoreTests/ChatServiceTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import Testing
import Foundation
@testable import AgentLoopCore

@Test func dmPersistsBothSidesAndFindsThread() async throws {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    let db = try AppDatabase(path: base.appendingPathComponent("t.sqlite").path)
    var c = CompanionRecord.new(name: "细细", color: "coral", rolePrompt: "你是审校伙伴", model: "m")
    try db.saveCompanion(&c)

    let mock = MockProvider(script: [TurnResult(content: [.text("你好呀")], stopReason: .endTurn)])
    let chat = ChatService(db: db, provider: mock)
    var reply = ""
    for try await ev in try chat.send(companionId: c.id, userText: "在吗") {
        if case .textDelta(let t) = ev { reply += t }
    }
    #expect(reply == "你好呀")

    // 单线程：同伙伴复用同一 thread（spec §10.1）
    let t1 = try db.findOrCreateDMThread(companionId: c.id)
    let msgs = try db.messages(threadId: t1.id)
    #expect(msgs.count == 2)
    #expect(msgs[0].role == "user" && msgs[1].role == "companion")
    // 历史进入第二次调用
    _ = try? await consume(chat.send(companionId: c.id, userText: "再聊"))
    #expect(try db.messages(threadId: t1.id).count >= 3)
}

private func consume(_ s: AsyncThrowingStream<ProviderEvent, Error>) async throws {
    for try await _ in s {}
}
```

- [ ] **Step 2: 确认失败** → FAIL

- [ ] **Step 3: 实现**（`AppDatabase` 补 `findOrCreateDMThread` / `messages(threadId:)` / `appendChatMessage`，同 Task 7 模式）

```swift
import Foundation

public struct ChatService: Sendable {
    let db: AppDatabase
    let provider: any LLMProvider
    public init(db: AppDatabase, provider: any LLMProvider) { self.db = db; self.provider = provider }

    /// 私聊：无工具、system=职责 prompt、全历史重发（M1 不做压缩与沉淀）
    public func send(companionId: String, userText: String) throws -> AsyncThrowingStream<ProviderEvent, Error> {
        guard let companion = try db.companion(id: companionId) else {
            throw ProviderError.malformedStream("no companion")
        }
        let thread = try db.findOrCreateDMThread(companionId: companionId)
        try db.appendChatMessage(threadId: thread.id, role: "user", text: userText)
        let history: [APIMessage] = try db.messages(threadId: thread.id).map { msg in
            APIMessage(role: msg.role == "user" ? .user : .assistant, content: [.text(msg.text)])
        }
        let system = "你的名字是\(companion.name)。\(companion.rolePrompt)\n你正在与你的用户一对一聊天，语气自然、有人情味，回答简洁。"

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var full = ""
                    for try await ev in provider.streamTurn(system: system, history: history,
                                                            tools: [], maxTokens: 4096) {
                        if case .textDelta(let t) = ev { full += t }
                        continuation.yield(ev)
                    }
                    try db.appendChatMessage(threadId: thread.id, role: "companion", text: full)
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
```

（`ChatMessageRecord` 增加便捷 `text` 访问：`contentJson` 存 `{"text":"…"}`；`appendChatMessage` 负责编码。）

- [ ] **Step 4: 确认通过** → PASS
- [ ] **Step 5: Commit** — `git commit -am "feat(m1): companion DM chat — persisted single thread, no tools"`

---

### Task 16: KeychainStore + DeltaCoalescer

**Files:**
- Create: `Sources/AgentLoopCore/Support/KeychainStore.swift`, `Sources/AgentLoopCore/Support/DeltaCoalescer.swift`
- Test: `Tests/AgentLoopCoreTests/SupportTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import Testing
import Foundation
@testable import AgentLoopCore

@Test func keychainRoundTrip() throws {
    let store = KeychainStore(service: "com.muzi.agentloop.tests.\(UUID().uuidString)")
    defer { try? store.delete(account: "k") }
    #expect(try store.get(account: "k") == nil)
    try store.set("sk-abc", account: "k")
    #expect(try store.get(account: "k") == "sk-abc")
    try store.set("sk-def", account: "k")   // 覆盖更新
    #expect(try store.get(account: "k") == "sk-def")
}

@Test func coalescerBatchesDeltas() async throws {
    let collected = Collected()
    let c = DeltaCoalescer(interval: .milliseconds(30)) { batch in await collected.append(batch) }
    for i in 0..<50 { await c.push("x\(i) ") }
    try await Task.sleep(for: .milliseconds(120))
    await c.flush()
    let batches = await collected.values
    #expect(batches.joined() == (0..<50).map { "x\($0) " }.joined())  // 无丢失、保序
    #expect(batches.count < 50)                                        // 确有合批
}
actor Collected { var values: [String] = []; func append(_ s: String) { values.append(s) } }
```

- [ ] **Step 2: 确认失败** → FAIL

- [ ] **Step 3: 实现**

```swift
// KeychainStore.swift
import Foundation
import Security

public struct KeychainStore: Sendable {
    public let service: String
    public init(service: String = "com.muzi.agentloop") { self.service = service }

    public func set(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account]
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = query; add[kSecValueData as String] = data
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
        } else if status != errSecSuccess { throw KeychainError(status: status) }
    }

    public func get(account: String) throws -> String? {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw KeychainError(status: status) }
        return String(data: data, encoding: .utf8)
    }

    public func delete(account: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }
}
public struct KeychainError: Error { public let status: OSStatus }
```

```swift
// DeltaCoalescer.swift —— spec §11：token 增量 30–50ms 合批
public actor DeltaCoalescer {
    private var buffer = ""
    private var flusher: Task<Void, Never>?
    private let interval: Duration
    private let deliver: @Sendable (String) async -> Void

    public init(interval: Duration = .milliseconds(40),
                deliver: @escaping @Sendable (String) async -> Void) {
        self.interval = interval; self.deliver = deliver
    }

    public func push(_ delta: String) {
        buffer += delta
        if flusher == nil {
            flusher = Task {
                try? await Task.sleep(for: interval)
                await self.flush()
            }
        }
    }

    public func flush() async {
        flusher?.cancel(); flusher = nil
        guard !buffer.isEmpty else { return }
        let out = buffer; buffer = ""
        await deliver(out)
    }
}
```

- [ ] **Step 4: 确认通过** → PASS（2 tests）
- [ ] **Step 5: Commit** — `git commit -am "feat(m1): keychain store + 40ms delta coalescer"`

---

### Task 17: App UI 骨架（AppStore / 三栏 / 设置 / 伙伴编辑器 / 单卡运行 / 私聊）

**Files:**
- Create: `Sources/AgentLoopApp/AppStore.swift`、`Views/RootView.swift`、`Views/SettingsView.swift`、`Views/CompanionEditorView.swift`、`Views/TaskRunView.swift`、`Views/DMChatView.swift`
- Modify: `Sources/AgentLoopApp/AgentLoopApp.swift`

UI 层无单测（M1 用构建 + 手动验证清单）；一切业务状态改动经 AppStore（@MainActor @Observable），事件消费用 DeltaCoalescer。

- [ ] **Step 1: 实现 AppStore**

```swift
import SwiftUI
import AgentLoopCore

@MainActor @Observable
final class AppStore {
    let db: AppDatabase
    let keychain = KeychainStore()
    let artifactStoreRoot: URL

    var companions: [CompanionRecord] = []
    var apiKeyPresent = false
    var defaultModel = "claude-sonnet-4-6"
    static let modelChoices = ["claude-sonnet-4-6", "claude-fable-5", "claude-haiku-4-5-20251001"]

    // 单卡运行状态（M1 一次一个）
    enum RunPhase: Equatable { case idle, thinking, streaming, toolRunning(String), finished(String), failed(String) }
    var runPhase: RunPhase = .idle
    var transcript = ""
    var progressNotes: [String] = []
    var artifacts: [ArtifactRecord] = []
    private var runTask: Task<Void, Never>?

    // 私聊状态
    var chatMessages: [(role: String, text: String)] = []
    var chatStreaming = false
    private var chatTask: Task<Void, Never>?

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AgentLoop")
        try! FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        artifactStoreRoot = appSupport.appendingPathComponent("artifacts")
        db = try! AppDatabase(path: appSupport.appendingPathComponent("agentloop.sqlite").path)
        try! db.ensureDefaultCamp()
        reload()
    }

    func reload() {
        companions = (try? db.regularCompanions()) ?? []
        apiKeyPresent = ((try? keychain.get(account: "anthropic-api-key")) ?? nil) != nil
    }

    func saveAPIKey(_ key: String) {
        try? keychain.set(key.trimmingCharacters(in: .whitespaces), account: "anthropic-api-key")
        reload()
    }

    func provider(model: String) -> AnthropicProvider? {
        // try? 对「throws 且返回 Optional」的调用已自动展平（SE-0230），单层解包即可
        guard let key = try? keychain.get(account: "anthropic-api-key") else { return nil }
        return AnthropicProvider(apiKey: key, model: model)
    }

    func startRun(companion: CompanionRecord, title: String, description: String,
                  expectedOutput: String, workspacePath: String) {
        guard let provider = provider(model: companion.model) else {
            runPhase = .failed("请先在设置里填入 API key"); return
        }
        transcript = ""; progressNotes = []; artifacts = []; runPhase = .thinking
        runTask = Task {
            do {
                let ids = try db.createSingleCardMission(
                    campName: "我的营地", squadName: "试营小队", goal: title,
                    cardTitle: title, cardDescription: description, expectedOutput: expectedOutput,
                    assigneeId: companion.id, maxTurns: 30, workspacePath: workspacePath)
                let coalescer = DeltaCoalescer { [weak self] batch in
                    await MainActor.run { self?.transcript += batch; self?.runPhase = .streaming }
                }
                let runner = CardRunner(db: db, provider: provider, artifactStoreRoot: artifactStoreRoot)
                for try await ev in try runner.run(cardId: ids.cardId,
                                                   companionName: companion.name,
                                                   rolePrompt: companion.rolePrompt) {
                    switch ev {
                    case .textDelta(let t): await coalescer.push(t)
                    case .toolStarted(let name):
                        await coalescer.flush()
                        runPhase = .toolRunning(name)
                    case .toolFinished: runPhase = .thinking
                    case .turnEnded: break
                    case .finished(let outcome):
                        await coalescer.flush()
                        artifacts = (try? db.artifacts(cardId: ids.cardId)) ?? []
                        progressNotes = (try? db.events(cardId: ids.cardId))?
                            .filter { $0.kind == "progress_note" }
                            .compactMap { try? JSONValue.decoded(from: $0.payloadJson)["text"]?.stringValue } ?? []
                        switch outcome {
                        case .completed(let h): runPhase = .finished(h.summary)
                        case .blocked(let reason, let detail): runPhase = .failed("受阻(\(reason))：\(detail)")
                        }
                    }
                }
            } catch { runPhase = .failed("\(error)") }
        }
    }

    func revealArtifact(_ a: ArtifactRecord) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: a.path)])
    }

    func sendChat(companion: CompanionRecord, text: String) {
        guard let provider = provider(model: companion.model) else { return }
        chatMessages.append((role: "user", text: text))
        chatMessages.append((role: "companion", text: ""))
        chatStreaming = true
        let chat = ChatService(db: db, provider: provider)
        chatTask = Task {
            do {
                let coalescer = DeltaCoalescer { [weak self] batch in
                    await MainActor.run {
                        guard let self, !self.chatMessages.isEmpty else { return }
                        self.chatMessages[self.chatMessages.count - 1].text += batch
                    }
                }
                for try await ev in try chat.send(companionId: companion.id, userText: text) {
                    if case .textDelta(let t) = ev { await coalescer.push(t) }
                }
                await coalescer.flush()
            } catch {
                chatMessages[chatMessages.count - 1].text = "（出错了：\(error)）"
            }
            chatStreaming = false
        }
    }

    func loadChatHistory(companion: CompanionRecord) {
        let thread = try? db.findOrCreateDMThread(companionId: companion.id)
        chatMessages = (thread.flatMap { try? db.messages(threadId: $0.id) } ?? [])
            .map { (role: $0.role, text: $0.text) }
    }
}
```

- [ ] **Step 2: 实现视图**（关键结构给全，样式从简；动效在 Task 18 补）

```swift
// RootView.swift
import SwiftUI
import AgentLoopCore

enum Destination: Hashable {
    case newTask, settings
    case chat(String)     // companionId
    case editCompanion(String?)
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var selection: Destination? = .newTask

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("行动") {
                    NavigationLink(value: Destination.newTask) { Label("单卡试运行", systemImage: "flag") }
                }
                Section("伙伴") {
                    ForEach(store.companions, id: \.id) { c in
                        NavigationLink(value: Destination.chat(c.id)) {
                            HStack {
                                CompanionAvatarView(name: c.name, colorName: c.color, state: .idle, size: 22)
                                Text(c.name)
                            }
                        }
                    }
                    NavigationLink(value: Destination.editCompanion(nil)) { Label("新伙伴…", systemImage: "plus") }
                }
                Section {
                    NavigationLink(value: Destination.settings) { Label("设置", systemImage: "gearshape") }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            switch selection {
            case .newTask, nil: TaskRunView()
            case .settings: SettingsView()
            case .chat(let id):
                if let c = store.companions.first(where: { $0.id == id }) { DMChatView(companion: c) }
            case .editCompanion(let id):
                CompanionEditorView(companionId: id) { selection = .newTask }
            }
        }
    }
}
```

```swift
// SettingsView.swift
struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var key = ""
    var body: some View {
        Form {
            Section("Anthropic API Key") {
                SecureField("sk-ant-…", text: $key)
                HStack {
                    Button("保存到钥匙串") { store.saveAPIKey(key); key = "" }
                        .disabled(key.isEmpty)
                    if store.apiKeyPresent { Label("已配置", systemImage: "checkmark.seal").foregroundStyle(.green) }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("设置")
    }
}
```

```swift
// CompanionEditorView.swift
struct CompanionEditorView: View {
    @Environment(AppStore.self) private var store
    let companionId: String?
    var onDone: () -> Void
    @State private var name = ""
    @State private var color = "purple"
    @State private var rolePrompt = ""
    @State private var model = "claude-sonnet-4-6"
    static let colors = ["purple", "teal", "coral", "pink", "blue", "green", "amber"]

    var body: some View {
        Form {
            TextField("名字（比如：阿规）", text: $name)
            Picker("颜色", selection: $color) {
                ForEach(Self.colors, id: \.self) { Text($0).tag($0) }
            }
            Picker("模型", selection: $model) {
                ForEach(AppStore.modelChoices, id: \.self) { Text($0).tag($0) }
            }
            Section("职责（system prompt）") {
                TextEditor(text: $rolePrompt).frame(minHeight: 120)
            }
            Button("保存伙伴") {
                var c = CompanionRecord.new(name: name, color: color, rolePrompt: rolePrompt, model: model)
                try? store.db.saveCompanion(&c)
                store.reload(); onDone()
            }
            .disabled(name.isEmpty || rolePrompt.isEmpty)
        }
        .formStyle(.grouped)
        .navigationTitle(companionId == nil ? "新伙伴" : "编辑伙伴")
    }
}
```

```swift
// TaskRunView.swift —— 表单 → 运行转录 → 交付条
struct TaskRunView: View {
    @Environment(AppStore.self) private var store
    @State private var title = ""
    @State private var desc = ""
    @State private var expected = ""
    @State private var workspace = ""
    @State private var companionId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if case .idle = store.runPhase { form } else { runView }
        }
        .padding()
        .navigationTitle("单卡试运行")
    }

    private var form: some View {
        Form {
            Picker("伙伴", selection: $companionId) {
                Text("选择伙伴").tag(String?.none)
                ForEach(store.companions, id: \.id) { Text($0.name).tag(String?($0.id)) }
            }
            TextField("小目标标题", text: $title)
            TextField("说明", text: $desc, axis: .vertical)
            TextField("预期产出（必填）", text: $expected)
            HStack {
                TextField("工作目录", text: $workspace)
                Button("选择…") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true; panel.canChooseFiles = false
                    if panel.runModal() == .OK { workspace = panel.url?.path ?? "" }
                }
            }
            Button("开工") {
                guard let cid = companionId,
                      let c = store.companions.first(where: { $0.id == cid }) else { return }
                store.startRun(companion: c, title: title, description: desc,
                               expectedOutput: expected, workspacePath: workspace)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(companionId == nil || title.isEmpty || expected.isEmpty || workspace.isEmpty)
        }
        .formStyle(.grouped)
    }

    private var runView: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusHeader
            ScrollView { Text(store.transcript).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading) }
            if !store.progressNotes.isEmpty {
                ForEach(store.progressNotes, id: \.self) { Label($0, systemImage: "text.bubble") }
            }
            if !store.artifacts.isEmpty {
                GroupBox("交付物") {
                    ForEach(store.artifacts, id: \.id) { a in
                        HStack {
                            Label(a.label, systemImage: "doc")
                            Spacer()
                            Button("在 Finder 中显示") { store.revealArtifact(a) }
                        }
                    }
                }
            }
            if case .finished = store.runPhase { Button("再来一单") { store.runPhase = .idle } }
            if case .failed = store.runPhase { Button("返回") { store.runPhase = .idle } }
        }
    }

    @ViewBuilder private var statusHeader: some View {
        switch store.runPhase {
        case .thinking: HStack { TypingIndicatorView(); Text("在想…") }
        case .streaming: HStack { TypingIndicatorView(); Text("在写…") }
        case .toolRunning(let name): Label("正在用工具：\(name)", systemImage: "wrench.adjustable")
        case .finished(let s): Label(s, systemImage: "checkmark.circle").foregroundStyle(.green)
        case .failed(let s): Label(s, systemImage: "hand.raised").foregroundStyle(.orange)
        case .idle: EmptyView()
        }
    }
}
```

```swift
// DMChatView.swift
struct DMChatView: View {
    @Environment(AppStore.self) private var store
    let companion: CompanionRecord
    @State private var input = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(store.chatMessages.enumerated()), id: \.offset) { _, msg in
                            ChatBubble(msg: msg, companion: companion,
                                       thinking: store.chatStreaming && msg.text.isEmpty)
                        }
                    }.padding()
                }
                .onChange(of: store.chatMessages.count) { proxy.scrollTo(store.chatMessages.count - 1) }
            }
            Divider()
            HStack {
                TextField("跟\(companion.name)说点什么…", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(send)
                Button("发送", action: send).disabled(input.isEmpty || store.chatStreaming)
            }.padding(10)
        }
        .navigationTitle(companion.name)
        .task(id: companion.id) { store.loadChatHistory(companion: companion) }
    }

    private func send() {
        guard !input.isEmpty else { return }
        store.sendChat(companion: companion, text: input); input = ""
    }
}

struct ChatBubble: View {
    let msg: (role: String, text: String)
    let companion: CompanionRecord
    var thinking = false
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if msg.role == "companion" {
                CompanionAvatarView(name: companion.name, colorName: companion.color,
                                    state: thinking ? .thinking : .idle, size: 26)
            } else { Spacer(minLength: 60) }
            Group {
                if thinking { TypingIndicatorView() } else { Text(msg.text).textSelection(.enabled) }
            }
            .padding(10)
            .background(msg.role == "user" ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 12))
            if msg.role == "user" { } else { Spacer(minLength: 60) }
        }
    }
}
```

```swift
// AgentLoopApp.swift（更新）
@main
struct AgentLoopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var store = AppStore()
    var body: some Scene {
        WindowGroup("AgentLoop") {
            RootView().environment(store).frame(minWidth: 760, minHeight: 520)
        }
    }
}
```

（Task 18 之前，`CompanionAvatarView` / `TypingIndicatorView` 先建占位：静态圆点即可编译。）

- [ ] **Step 3: 构建 + 手动验证清单**

Run: `swift build && swift run AgentLoopApp &`
Expected 手动核对：① 设置里能存 key、显示「已配置」② 能创建伙伴并出现在侧栏 ③ 私聊窗口能加载（无 key 时按钮禁用不崩溃）④ 单卡表单校验生效（缺预期产出时「开工」禁用）

- [ ] **Step 4: Commit** — `git commit -am "feat(m1): app shell — store, split view, settings, editor, run view, DM chat"`

---

### Task 18: 动效骨架（spec §11.2 M1 范围：转场 / 打字指示 / 头像两态 + Reduce Motion）

**Files:**
- Create: `Sources/AgentLoopApp/Views/Components/CompanionAvatarView.swift`、`Views/Components/TypingIndicatorView.swift`
- Modify: `Views/TaskRunView.swift`（视图切换转场）

- [ ] **Step 1: 实现头像两态**（代码绘制、参数化换色；动画由真实状态驱动，spec §11.2）

```swift
import SwiftUI

enum AvatarState { case idle, thinking }

struct CompanionAvatarView: View {
    let name: String, colorName: String
    var state: AvatarState = .idle
    var size: CGFloat = 26
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let palette: [String: Color] = [
        "purple": Color(red: 0.33, green: 0.29, blue: 0.72), "teal": Color(red: 0.11, green: 0.62, blue: 0.46),
        "coral": Color(red: 0.85, green: 0.35, blue: 0.19), "pink": Color(red: 0.83, green: 0.33, blue: 0.49),
        "blue": Color(red: 0.22, green: 0.54, blue: 0.87), "green": Color(red: 0.39, green: 0.6, blue: 0.13),
        "amber": Color(red: 0.94, green: 0.62, blue: 0.15),
    ]
    private var color: Color { Self.palette[colorName] ?? .gray }

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.22))
            Circle().stroke(color.opacity(0.55), lineWidth: 1)
            eyes
            Text(String(name.prefix(1))).font(.system(size: size * 0.38, weight: .medium))
                .foregroundStyle(color).offset(y: size * 0.18)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topTrailing) { if state == .thinking { thinkingBubble } }
    }

    // idle：每 3s 眨一次眼（Reduce Motion → 常开）
    private var eyes: some View {
        TimelineView(.animation(minimumInterval: 0.4, paused: reduceMotion)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let blink = !reduceMotion && t.truncatingRemainder(dividingBy: 3.0) < 0.15
            HStack(spacing: size * 0.16) {
                Capsule().frame(width: size * 0.09, height: blink ? size * 0.02 : size * 0.16)
                Capsule().frame(width: size * 0.09, height: blink ? size * 0.02 : size * 0.16)
            }
            .foregroundStyle(color)
            .offset(y: -size * 0.12)
        }
    }

    // thinking：头顶冒泡
    private var thinkingBubble: some View {
        TimelineView(.animation(minimumInterval: 0.25, paused: reduceMotion)) { ctx in
            let phase = reduceMotion ? 1 : Int(ctx.date.timeIntervalSinceReferenceDate * 3) % 3
            HStack(spacing: 1.5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().frame(width: 3, height: 3).opacity(i <= phase ? 1 : 0.25)
                }
            }
            .foregroundStyle(color)
            .offset(x: size * 0.28, y: -size * 0.12)
        }
    }
}
```

- [ ] **Step 2: 实现打字指示**

```swift
struct TypingIndicatorView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if reduceMotion {
            Text("…").foregroundStyle(.secondary)
        } else {
            TimelineView(.animation(minimumInterval: 0.15)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle().frame(width: 5, height: 5)
                            .offset(y: sin((t * 5) + Double(i) * 0.9) * 2.5)
                    }
                }.foregroundStyle(.secondary)
            }
        }
    }
}
```

- [ ] **Step 3: 转场承接**（TaskRunView 表单⇄运行切换）

在 `TaskRunView.body` 的条件分支处加：

```swift
.animation(.snappy(duration: 0.25), value: isIdle)   // isIdle: 由 store.runPhase 派生的 Bool
// form 与 runView 各加：.transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
//                                              removal: .move(edge: .leading).combined(with: .opacity)))
```

侧栏选中切换依赖 NavigationSplitView 自带过渡；聊天气泡追加加 `.animation(.snappy, value: store.chatMessages.count)`。

- [ ] **Step 4: 构建 + 手动验证清单**

Run: `swift build && swift run AgentLoopApp &`
Expected：① 侧栏伙伴头像会眨眼 ② 私聊等待回复时头像切 thinking 冒泡 + 气泡内打字指示 ③ 表单→运行视图有滑动过渡 ④ 系统开启「减弱动态效果」后全部动效替换为静态（系统设置 → 辅助功能 → 显示 → 减弱动态效果，开关对比）
Expected（性能）：私聊流式时窗口拖动不卡顿（合批 + TimelineView 低频）

- [ ] **Step 5: Commit** — `git commit -am "feat(m1): motion skeleton — blinking avatars, thinking state, typing dots, transitions, reduce-motion"`

---

### Task 19: 活体冒烟仪式 + M1 收尾（spec §15-5 硬门）

**Files:**
- Create: `docs/superpowers/2026-XX-XX-m1-live-smoke.md`（记录当天日期与结果）

- [ ] **Step 1: 全量离线回归**

Run: `swift test`
Expected: 全部 PASS（≥30 tests）

- [ ] **Step 2: 活体冒烟（需要用户在场提供 API key，事先说明将产生真实 API 费用）**

流程（全程零代码改动，若需改代码则修完从 Step 1 重来）：
1. `swift run AgentLoopApp`
2. 设置 → 粘贴真实 Anthropic API key
3. 新建伙伴：名「阿规」、职责「你是一位务实的生活规划伙伴，擅长把需求整理成可执行的清单文档」、模型 claude-sonnet-4-6
4. 私聊「阿规」：问一句「你会怎么规划一次两天一夜的露营？」→ 验证流式回复顺畅、头像 thinking 动画、再次进入时历史还在
5. 单卡试运行：标题「露营装备清单」、说明「为两人两天一夜的秋季露营整理装备清单，按类别分组，标注哪些可租」、预期产出「工作目录里一份 装备清单.md」、工作目录选 `~/Desktop/agentloop-smoke`（先建好）、伙伴选阿规 → 开工
6. 观察核对：流式转录 + 「正在用工具」状态 + 进展汇报出现
7. 结束核对：状态为完成、交付物条出现「装备清单.md」、点「在 Finder 中显示」定位到耐久存储中的文件、文件内容合格、`~/Desktop/agentloop-smoke/装备清单.md` 原件也在

- [ ] **Step 3: 记录冒烟结果**（成功/失败、用时、token 用量、发现的问题清单）写入 `docs/superpowers/2026-XX-XX-m1-live-smoke.md`

- [ ] **Step 4: 对照 M1 验收（spec §16）逐条打勾**
- 真实 API 完成一个单卡任务 ✓/✗
- 产物可 Finder reveal ✓/✗
- 与伙伴流畅私聊 ✓/✗
- 等待全程有活动指示 ✓/✗

- [ ] **Step 5: Commit + 打 tag**

```bash
git add -A && git commit -m "docs(m1): live smoke record — M1 acceptance"
git tag m1
```

---

## 完成定义（M1 DoD）

1. `swift test` 全绿（核心逻辑全部 TDD 覆盖：类型/SSE/累加器/Provider 重试/DB 转移/工具包含检查/交接包校验/产物耐久不变量/Loop 六场景/私聊持久化）。
2. 活体冒烟四条验收全过且有记录文档。
3. spec §5.2 不变量在 M1 范围内成立：产物先耐久后完成（测试 `completeCopiesArtifactBeforeDone`）、工具唯一终结（测试 `endTurnWithoutTerminatorRemindsOnceThenBlocks`）、事件同事务投影（测试 `eventAppendAndProjectionSameTransaction`）。
4. 遗留清单写入冒烟记录（已知 M1 不做：上下文压缩、mission token 预算硬顶、每轮 120s 超时（暂依赖 URLSession 缺省超时，spec §14 项 M2 落）、多卡、沉淀、向导对话——均有 M2+ 归属）。

## 给执行者的注意事项

- **每个任务开始前先 `swift test` 确认基线是绿的**；结束时也必须是绿的。
- Swift 6 严格并发下若遇 Sendable 报错：优先加 `Sendable` 一致性/用 actor 隔离，禁止 `@unchecked Sendable` 兜底（测试桩除外，计划中已标注）。
- GRDB API 若与计划代码有出入（如 `Configuration.journalMode` 写法），以 `.build/checkouts/GRDB.swift/README.md` 为准调整——行为目标不变：WAL 池 + 事务。
- 计划里的代码是「意图完整」的参考实现；编译器报错时修编译错误，但**不得改变测试所锁定的行为**。测试先于实现提交。
- 测试文件一律放在 `Sources/AgentLoopTestSuite/`（计划正文中的 `Tests/AgentLoopCoreTests/` 路径按此映射）；权威测试命令是 `swift run RunTests`。

