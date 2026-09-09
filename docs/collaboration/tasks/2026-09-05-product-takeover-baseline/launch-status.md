# 启动验证状态

2026-09-05：**SKIPPED — strict build failed**。

按本轮计划，`swift build --product AgentLoopApp -Xswiftc -warnings-as-errors` 返回 1 后，不执行 `scripts/run-app.sh --preview`，不以旧包启动替代当前源码构建证据。没有创建新的预览状态目录、没有启动/终止 App、没有用户数据或凭据操作。

只读核对磁盘上现有旧产物（不构成本轮构建或启动通过）：

| 产物 | 观察 |
| --- | --- |
| `.build/AgentLoop.app/Contents/MacOS/AgentLoop` | 文件修改时间 Sep 1 09:40；bundle ID `com.muzi.agentloop.dev`；SHA-256 `0269c9f651e8916b61f64ddecdd1ce0c8c139a074b0d9fd0204c266db2e234f2` |
| `dist/Coding 牧场.app/Contents/MacOS/AgentLoop` | 文件修改时间 Aug 30 18:05；version `1.1.0` build `128`；SHA-256 `74dfd43ca6bbb18b8a13caad474ad2852c78097e1cb1e49fbf6d0192ba4c2704` |

dist 主程序哈希与 Aug 30 acceptance.md 的历史记录一致。它不包含 Sept 1 开发包构建身份，不能在没有新验证的情况下称为最新修复版本。不同编译模式本身也会改变二进制哈希，以上差异不能单独证明源码内容差异。
