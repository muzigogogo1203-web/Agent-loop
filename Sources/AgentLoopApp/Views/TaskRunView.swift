import SwiftUI
import AgentLoopCore

struct TaskRunView: View {
    @Environment(AppStore.self) private var store
    @State private var title = ""
    @State private var description = ""
    @State private var expected = ""
    @State private var workspace = ""
    @State private var companionId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if case .idle = store.runPhase {
                form
            } else {
                runView
            }
        }
        .padding()
        .navigationTitle("单卡试运行")
    }

    private var form: some View {
        Form {
            Picker("伙伴", selection: $companionId) {
                Text("选择伙伴").tag(String?.none)
                ForEach(store.companions, id: \.id) { companion in
                    Text(companion.name).tag(String?(companion.id))
                }
            }
            TextField("小目标标题", text: $title)
            TextField("说明", text: $description, axis: .vertical)
            TextField("预期产出（必填）", text: $expected)
            HStack {
                TextField("工作目录", text: $workspace)
                Button("选择...") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    if panel.runModal() == .OK {
                        workspace = panel.url?.path ?? ""
                    }
                }
            }
            Button("开工") {
                guard let companionId,
                      let companion = store.companions.first(where: { $0.id == companionId }) else {
                    return
                }
                store.startRun(
                    companion: companion,
                    title: title,
                    description: description,
                    expectedOutput: expected,
                    workspacePath: workspace
                )
            }
            .keyboardShortcut(.defaultAction)
            .disabled(companionId == nil || title.isEmpty || expected.isEmpty || workspace.isEmpty)
        }
        .formStyle(.grouped)
    }

    private var runView: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusHeader
            ScrollView {
                Text(store.transcript)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !store.progressNotes.isEmpty {
                ForEach(store.progressNotes, id: \.self) { note in
                    Label(note, systemImage: "text.bubble")
                }
            }
            if !store.artifacts.isEmpty {
                GroupBox("交付物") {
                    ForEach(store.artifacts, id: \.id) { artifact in
                        HStack {
                            Label(artifact.label, systemImage: "doc")
                            Spacer()
                            Button("在 Finder 中显示") {
                                store.revealArtifact(artifact)
                            }
                        }
                    }
                }
            }
            if case .finished = store.runPhase {
                Button("再来一单") { store.runPhase = .idle }
            }
            if case .failed = store.runPhase {
                Button("返回") { store.runPhase = .idle }
            }
        }
    }

    @ViewBuilder private var statusHeader: some View {
        switch store.runPhase {
        case .thinking:
            HStack { TypingIndicatorView(); Text("在想...") }
        case .streaming:
            HStack { TypingIndicatorView(); Text("在写...") }
        case .toolRunning(let name):
            Label("正在用工具：\(name)", systemImage: "wrench.adjustable")
        case .finished(let summary):
            Label(summary, systemImage: "checkmark.circle")
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "hand.raised")
                .foregroundStyle(.orange)
        case .idle:
            EmptyView()
        }
    }
}
