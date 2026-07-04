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
    var artifacts: [ArtifactRecord] = []
    private var runTask: Task<Void, Never>?

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
        try? keychain.set(key.trimmingCharacters(in: .whitespacesAndNewlines), account: "anthropic-api-key")
        reload()
    }

    func provider(model: String) -> AnthropicProvider? {
        guard let key = try? keychain.get(account: "anthropic-api-key") else {
            return nil
        }
        return AnthropicProvider(apiKey: key, model: model)
    }

    func startRun(
        companion: CompanionRecord,
        title: String,
        description: String,
        expectedOutput: String,
        workspacePath: String
    ) {
        guard let provider = provider(model: companion.model) else {
            runPhase = .failed("请先在设置里填入 API key")
            return
        }
        transcript = ""
        progressNotes = []
        artifacts = []
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
                for try await event in try runner.run(
                    cardId: ids.cardId,
                    companionName: companion.name,
                    rolePrompt: companion.rolePrompt
                ) {
                    switch event {
                    case .textDelta(let text):
                        await coalescer.push(text)
                    case .toolStarted(let name):
                        await coalescer.flush()
                        runPhase = .toolRunning(name)
                    case .toolFinished:
                        runPhase = .thinking
                    case .turnEnded:
                        break
                    case .finished(let outcome):
                        await coalescer.flush()
                        artifacts = (try? db.artifacts(cardId: ids.cardId)) ?? []
                        progressNotes = (try? db.events(cardId: ids.cardId))?
                            .filter { $0.kind == "progress_note" }
                            .compactMap { try? JSONValue.decoded(from: $0.payloadJson)["text"]?.stringValue } ?? []
                        switch outcome {
                        case .completed(let handoff):
                            runPhase = .finished(handoff.summary)
                        case .blocked(let reason, let detail):
                            runPhase = .failed("受阻(\(reason))：\(detail)")
                        }
                    }
                }
            } catch {
                runPhase = .failed("\(error)")
            }
        }
    }

    func revealArtifact(_ artifact: ArtifactRecord) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: artifact.path)])
    }

    func sendChat(companion: CompanionRecord, text: String) {
        guard let provider = provider(model: companion.model) else {
            return
        }
        chatMessages.append((role: "user", text: text))
        chatMessages.append((role: "companion", text: ""))
        chatStreaming = true
        let chat = ChatService(db: db, provider: provider)
        chatTask = Task {
            do {
                let coalescer = DeltaCoalescer { [weak self] batch in
                    await MainActor.run {
                        guard let self, !self.chatMessages.isEmpty else {
                            return
                        }
                        self.chatMessages[self.chatMessages.count - 1].text += batch
                    }
                }
                for try await event in try chat.send(companionId: companion.id, userText: text) {
                    if case .textDelta(let text) = event {
                        await coalescer.push(text)
                    }
                }
                await coalescer.flush()
            } catch {
                if !chatMessages.isEmpty {
                    chatMessages[chatMessages.count - 1].text = "（出错了：\(error)）"
                }
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
