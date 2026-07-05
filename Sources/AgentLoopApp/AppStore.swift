import SwiftUI
import AgentLoopCore

@MainActor @Observable
final class AppStore {
    struct ActivityItem: Identifiable, Equatable {
        let id = UUID()
        var text: String
        var kind: Kind

        enum Kind {
            case start, tool, toolDone, toolError, note, retry, finish
        }
    }

    let db: AppDatabase
    let keychain = KeychainStore()
    let artifactStoreRoot: URL

    var companions: [CompanionRecord] = []
    var apiKeyPresent = false
    var defaultModel = "claude-sonnet-4-6"
    static let modelChoices = ["claude-sonnet-4-6", "claude-fable-5", "claude-haiku-4-5-20251001"]

    static let defaultBaseURL = "https://api.anthropic.com"
    var apiBaseURL: String = AppStore.defaultBaseURL {
        didSet { UserDefaults.standard.set(apiBaseURL, forKey: "apiBaseURL") }
    }
    var apiBaseURLValid: Bool { AnthropicProvider.normalizedBaseURL(apiBaseURL) != nil }

    enum RunPhase: Equatable {
        case idle
        case thinking
        case streaming
        case toolRunning(String)
        case finished(String)
        case failed(String)
    }

    var runPhase: RunPhase = .idle
    var transcript = ""
    var progressNotes: [String] = []
    var activityLog: [ActivityItem] = []
    var artifacts: [ArtifactRecord] = []
    private var runTask: Task<Void, Never>?
    private var turnStartTranscriptCount = 0

    var chatMessages: [(role: String, text: String)] = []
    var chatStreaming = false
    private var chatTask: Task<Void, Never>?
    private var chatCoalescer: DeltaCoalescer?
    private var chatStreamID = 0

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AgentLoop")
        try! FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        artifactStoreRoot = appSupport.appendingPathComponent("artifacts")
        db = try! AppDatabase(path: appSupport.appendingPathComponent("agentloop.sqlite").path)
        try! db.ensureDefaultCamp()
        apiBaseURL = UserDefaults.standard.string(forKey: "apiBaseURL") ?? Self.defaultBaseURL
        reload()
    }

    func reload() {
        companions = (try? db.regularCompanions()) ?? []
        apiKeyPresent = ((try? keychain.get(account: "anthropic-api-key")) ?? nil) != nil
    }

    func saveAPIKey(_ key: String) {
        try? keychain.set(key.trimmingCharacters(in: .whitespacesAndNewlines), account: "anthropic-api-key")
        reload()
    }

    func provider(model: String) -> AnthropicProvider? {
        guard let key = try? keychain.get(account: "anthropic-api-key") else {
            return nil
        }
        let base = AnthropicProvider.normalizedBaseURL(apiBaseURL)
            ?? URL(string: Self.defaultBaseURL)!
        return AnthropicProvider(apiKey: key, model: model, baseURL: base)
    }

    func startRun(
        companion: CompanionRecord,
        title: String,
        description: String,
        expectedOutput: String,
        workspacePath: String
    ) {
        transcript = ""
        progressNotes = []
        activityLog = []
        artifacts = []
        turnStartTranscriptCount = 0
        guard let provider = provider(model: companion.model) else {
            runPhase = .failed("请先在设置里填入 API key")
            return
        }
        runPhase = .thinking
        runTask = Task {
            do {
                let ids = try db.createSingleCardMission(
                    campName: "我的营地",
                    squadName: "试营小队",
                    goal: title,
                    cardTitle: title,
                    cardDescription: description,
                    expectedOutput: expectedOutput,
                    assigneeId: companion.id,
                    maxTurns: 30,
                    workspacePath: workspacePath
                )
                let coalescer = DeltaCoalescer { [weak self] batch in
                    await MainActor.run {
                        self?.transcript += batch
                        self?.runPhase = .streaming
                    }
                }
                let runner = CardRunner(db: db, provider: provider, artifactStoreRoot: artifactStoreRoot)
                activityLog.append(ActivityItem(text: "\(companion.name)开工了", kind: .start))
                for try await event in try runner.run(
                    cardId: ids.cardId,
                    companionName: companion.name,
                    rolePrompt: companion.rolePrompt
                ) {
                    switch event {
                    case .turnStarted:
                        await coalescer.flush()
                        turnStartTranscriptCount = transcript.count
                    case .textDelta(let text):
                        await coalescer.push(text)
                    case .toolStarted(let name):
                        await coalescer.flush()
                        activityLog.append(ActivityItem(text: "正在\(humanToolName(name))…", kind: .tool))
                        runPhase = .toolRunning(name)
                    case .toolFinished(let name, let isError):
                        markToolActivityFinished(name: name, isError: isError)
                        if name == "add_progress_note", !isError {
                            progressNotes = loadProgressNotes(cardId: ids.cardId)
                        }
                        runPhase = .thinking
                    case .turnRetrying(let attempt, let reason):
                        await coalescer.flush()
                        transcript = String(transcript.prefix(turnStartTranscriptCount))
                        activityLog.append(ActivityItem(
                            text: "网络波动，正在重试（\(attempt)/2）：\(reason)",
                            kind: .retry
                        ))
                    case .turnEnded:
                        break
                    case .finished(let outcome):
                        await coalescer.flush()
                        artifacts = (try? db.artifacts(cardId: ids.cardId)) ?? []
                        progressNotes = loadProgressNotes(cardId: ids.cardId)
                        activityLog.append(ActivityItem(text: "运行结束", kind: .finish))
                        switch outcome {
                        case .completed(let handoff):
                            runPhase = .finished(handoff.summary)
                        case .blocked(let reason, let detail):
                            runPhase = .failed("受阻(\(reason))：\(detail)")
                        }
                    }
                }
            } catch {
                runPhase = .failed(readableError(error))
            }
        }
    }

    private func loadProgressNotes(cardId: String) -> [String] {
        (try? db.events(cardId: cardId))?
            .filter { $0.kind == "progress_note" }
            .compactMap { try? JSONValue.decoded(from: $0.payloadJson)["text"]?.stringValue } ?? []
    }

    private func markToolActivityFinished(name: String, isError: Bool) {
        let label = humanToolName(name)
        let pendingText = "正在\(label)…"
        if let index = activityLog.lastIndex(where: { $0.kind == .tool && $0.text == pendingText }) {
            activityLog[index].text = isError ? "\(label)失败" : "\(label)完成"
            activityLog[index].kind = isError ? .toolError : .toolDone
        }
    }

    private func humanToolName(_ name: String) -> String {
        switch name {
        case "write_file": return "写文件"
        case "read_file": return "读文件"
        case "list_dir": return "查看目录"
        case "web_fetch": return "查网页"
        case "complete_card": return "提交交接包"
        case "block_card": return "报告受阻"
        case "add_progress_note": return "汇报进展"
        default: return name
        }
    }

    private func readableError(_ error: Error) -> String {
        if let urlError = error as? URLError {
            return urlError.localizedDescription
        }
        return String(describing: error)
    }

    func revealArtifact(_ artifact: ArtifactRecord) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: artifact.path)])
    }

    func sendChat(companion: CompanionRecord, text: String) {
        guard !text.isEmpty, !chatStreaming else {
            return
        }
        guard let provider = provider(model: companion.model) else {
            return
        }
        chatStreamID += 1
        let streamID = chatStreamID
        chatMessages.append((role: "user", text: text))
        chatMessages.append((role: "companion", text: ""))
        let companionMessageIndex = chatMessages.count - 1
        chatStreaming = true
        let chat = ChatService(db: db, provider: provider)
        let coalescer = DeltaCoalescer { [weak self] batch in
            await MainActor.run {
                guard let self,
                      self.chatStreamID == streamID,
                      self.chatMessages.indices.contains(companionMessageIndex) else {
                    return
                }
                self.chatMessages[companionMessageIndex].text += batch
            }
        }
        chatCoalescer = coalescer
        chatTask = Task {
            do {
                for try await event in try chat.send(companionId: companion.id, userText: text) {
                    if case .textDelta(let text) = event {
                        await coalescer.push(text)
                    }
                }
                if Task.isCancelled {
                    await coalescer.discard()
                } else {
                    await coalescer.flush()
                }
            } catch is CancellationError {
                await coalescer.discard()
            } catch {
                await coalescer.discard()
                if chatStreamID == streamID, chatMessages.indices.contains(companionMessageIndex) {
                    chatMessages[companionMessageIndex].text = "（出错了：\(error)）"
                }
            }
            if chatStreamID == streamID {
                chatStreaming = false
                chatCoalescer = nil
                chatTask = nil
            }
        }
    }

    func loadChatHistory(companion: CompanionRecord) {
        // 切换伙伴时终止在途流，防止上一位伙伴的增量写进新伙伴的气泡
        chatStreamID += 1
        chatTask?.cancel()
        chatTask = nil
        let coalescer = chatCoalescer
        chatCoalescer = nil
        chatStreaming = false
        Task {
            await coalescer?.discard()
        }
        let thread = try? db.findOrCreateDMThread(companionId: companion.id)
        chatMessages = (thread.flatMap { try? db.messages(threadId: $0.id) } ?? [])
            .map { (role: $0.role, text: $0.text) }
    }
}
