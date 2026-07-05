import SwiftUI
import AgentLoopCore

struct TaskRunView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var goal = ""
    @State private var workspace = ""
    @State private var selectedCompanionIds: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if store.currentMissionId == nil && store.missionPhase == .idle {
                form
                    .transition(.opacity)
            } else {
                missionView
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: store.currentMissionId)
        .padding()
        .navigationTitle("行动")
    }

    private var form: some View {
        Form {
            TextField("行动目标", text: $goal, axis: .vertical)
                .lineLimit(3...6)
            Section("伙伴") {
                ForEach(store.companions, id: \.id) { companion in
                    Toggle(isOn: companionBinding(companion.id)) {
                        HStack {
                            CompanionAvatarView(name: companion.name, colorName: companion.color, size: 22)
                            Text(companion.name)
                        }
                    }
                }
            }
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
            Button("开始行动") {
                store.startMission(
                    goal: goal,
                    companionIds: selectedCompanionIds,
                    workspacePath: workspace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : workspace
                )
            }
            .keyboardShortcut(.defaultAction)
            .disabled(goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCompanionIds.isEmpty)
        }
        .formStyle(.grouped)
    }

    private var missionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusHeader
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(store.missionCards, id: \.id) { card in
                        CardRowView(
                            card: card,
                            companion: card.assigneeId.flatMap { store.cardCompanions[$0] },
                            latest: store.cardLatest[card.id],
                            onRetry: { store.retryCard(card.id) }
                        )
                    }
                }
            }
            if !store.missionArtifacts.isEmpty {
                GroupBox("交付物") {
                    ForEach(store.missionArtifacts, id: \.id) { artifact in
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
            HStack {
                switch store.missionPhase {
                case .delivering:
                    Button("收营") { store.closeoutCurrentMission() }
                        .buttonStyle(.borderedProminent)
                    Button("放弃") { store.cancelCurrentMission() }
                case .planning, .executing:
                    Button("放弃") { store.cancelCurrentMission() }
                case .accepted, .failed, .error:
                    Button("新行动") {
                        goal = ""
                        workspace = ""
                        selectedCompanionIds = []
                        store.resetMission()
                    }
                case .idle:
                    EmptyView()
                }
            }
        }
    }

    @ViewBuilder private var statusHeader: some View {
        switch store.missionPhase {
        case .planning:
            HStack(spacing: 8) {
                CompanionAvatarView(name: "向导", colorName: "amber", state: .thinking, size: 28)
                TypingIndicatorView()
                Text("规划中")
                    .foregroundStyle(.secondary)
            }
        case .executing:
            Label("进行中", systemImage: "bolt.circle")
                .foregroundStyle(.blue)
        case .delivering:
            Label("可收营", systemImage: "flag.checkered")
                .foregroundStyle(.green)
        case .accepted:
            Label("已收营", systemImage: "checkmark.circle")
                .foregroundStyle(.green)
        case .failed:
            Label("已放弃", systemImage: "xmark.circle")
                .foregroundStyle(.secondary)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        case .idle:
            EmptyView()
        }
    }

    private func companionBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { selectedCompanionIds.contains(id) },
            set: { isOn in
                if isOn {
                    if !selectedCompanionIds.contains(id) {
                        selectedCompanionIds.append(id)
                    }
                } else {
                    selectedCompanionIds.removeAll { $0 == id }
                }
            }
        )
    }
}
