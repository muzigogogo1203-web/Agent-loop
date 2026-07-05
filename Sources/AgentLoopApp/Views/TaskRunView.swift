import SwiftUI
import AgentLoopCore

struct TaskRunView: View {
    enum Mode: Equatable {
        case newMission
        case mission(String)
    }

    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var goal = ""
    @State private var workspace = ""
    @State private var selectedCompanionIds: [String] = []
    @State private var theaterPulse = false
    @State private var theaterPulseToken = 0
    @State private var interactionGeneration = 0
    let mode: Mode

    var body: some View {
        Group {
            switch mode {
            case .newMission:
                form
                    .padding()
                    .navigationTitle("新行动")
            case .mission(let id):
                missionView
                    .padding()
                    .navigationTitle("行动")
                    .task(id: id) {
                        store.selectMission(id)
                    }
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: store.missionCards.map(\.status))
        .inspector(isPresented: inspectorBinding) {
            if let card = selectedCard {
                CardDetailInspector(card: card)
                    .frame(minWidth: 320)
            } else {
                ContentUnavailableView("未选择小目标", systemImage: "rectangle.and.text.magnifyingglass")
            }
        }
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
                Button {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    if panel.runModal() == .OK {
                        workspace = panel.url?.path ?? ""
                    }
                } label: {
                    Label("选择", systemImage: "folder")
                }
            }
            Button {
                store.startMission(
                    goal: goal,
                    companionIds: selectedCompanionIds,
                    workspacePath: workspace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : workspace
                )
            } label: {
                Label("开始行动", systemImage: "play.fill")
            }
            .keyboardShortcut(.defaultAction)
            .disabled(goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCompanionIds.isEmpty)
        }
        .formStyle(.grouped)
    }

    private var missionView: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                statusHeader
                HStack {
                    Picker("视图", selection: theaterBinding) {
                        Label("清单", systemImage: "checklist").tag(false)
                        Label("小剧场", systemImage: "campfire").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Image(systemName: "sparkles")
                        .foregroundStyle(.orange)
                        .opacity(theaterPulse ? 1 : 0)
                        .symbolEffect(.pulse, options: .repeat(2), value: theaterPulseToken)
                }
                .task(id: pulseTaskKey) {
                    theaterPulse = false
                    guard !reduceMotion else { return }
                    guard case .executing = store.missionPhase else { return }
                    try? await Task.sleep(for: .seconds(30))
                    guard !Task.isCancelled else { return }
                    if case .executing = store.missionPhase {
                        theaterPulse = true
                        theaterPulseToken += 1
                        try? await Task.sleep(for: .seconds(2))
                        if !Task.isCancelled {
                            theaterPulse = false
                        }
                    }
                }

                if store.theaterMode {
                    CampfireTheaterView(
                        phase: store.missionPhase,
                        cards: store.missionCards,
                        companions: store.cardCompanions,
                        states: store.companionAnimStates,
                        onSelectCard: {
                            recordInteraction()
                            store.selectedCardId = $0
                        }
                    )
                } else {
                    cardList
                }

                artifactsView
                controls
            }
            .frame(minWidth: 460)

            FeedView(
                entries: store.feedEntries,
                pendingRequests: visiblePendingRequests,
                cardTitles: cardTitles,
                phase: store.missionPhase,
                notice: store.feedNotice,
                onAnswer: { requestId, answer in
                    recordInteraction()
                    store.answerRequest(requestId: requestId, answer: answer)
                },
                onCloseout: { store.closeoutCurrentMission() },
                onInteract: { recordInteraction() }
            )
            .frame(minWidth: 300, idealWidth: 360)
        }
    }

    private var cardList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(sortedCards, id: \.id) { card in
                    CardRowView(
                        card: card,
                        companion: card.assigneeId.flatMap { store.cardCompanions[$0] },
                        latest: store.cardLatest[card.id],
                        animState: card.assigneeId.flatMap { store.companionAnimStates[$0] } ?? .idle,
                        pendingRequest: pendingRequest(for: card.id),
                        onRetry: { store.retryCard(card.id) },
                        onAnswer: { requestId, answer in
                            recordInteraction()
                            store.answerRequest(requestId: requestId, answer: answer)
                        },
                        onSelect: {
                            recordInteraction()
                            store.selectedCardId = card.id
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder private var artifactsView: some View {
        GroupBox("交付物") {
            if store.missionArtifacts.isEmpty {
                Text("暂无交付物")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groupedArtifacts, id: \.card.id) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.card.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(group.artifacts, id: \.id) { artifact in
                            HStack {
                                Label(artifact.label, systemImage: "doc")
                                Spacer()
                                Button {
                                    store.revealArtifact(artifact)
                                } label: {
                                    Image(systemName: "folder")
                                }
                                .help("在 Finder 中显示")
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var controls: some View {
        HStack {
            switch store.missionPhase {
            case .delivering:
                Button {
                    store.closeoutCurrentMission()
                } label: {
                    Label("收营", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                Button(role: .destructive) {
                    store.cancelCurrentMission()
                } label: {
                    Label("放弃", systemImage: "xmark.circle")
                }
            case .planning, .executing:
                Button(role: .destructive) {
                    store.cancelCurrentMission()
                } label: {
                    Label("放弃", systemImage: "xmark.circle")
                }
            case .accepted, .failed, .error:
                EmptyView()
            case .idle:
                EmptyView()
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

    private var sortedCards: [CardRecord] {
        store.missionCards.sorted { lhs, rhs in
            let leftNeeds = pendingRequest(for: lhs.id) != nil
            let rightNeeds = pendingRequest(for: rhs.id) != nil
            if leftNeeds != rightNeeds { return leftNeeds }
            return lhs.stage < rhs.stage
        }
    }

    private var visiblePendingRequests: [UserRequestRecord] {
        ActivityFeed.visiblePendingRequests(store.pendingRequests, cards: store.missionCards)
    }

    private func pendingRequest(for cardId: String) -> UserRequestRecord? {
        visiblePendingRequests.first { $0.cardId == cardId }
    }

    private var groupedArtifacts: [(card: CardRecord, artifacts: [ArtifactRecord])] {
        store.missionCards.compactMap { card in
            let artifacts = store.missionArtifacts.filter { $0.cardId == card.id }
            return artifacts.isEmpty ? nil : (card, artifacts)
        }
    }

    private var cardTitles: [String: String] {
        Dictionary(store.missionCards.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })
    }

    private var selectedCard: CardRecord? {
        guard let id = store.selectedCardId else { return nil }
        return store.missionCards.first { $0.id == id }
    }

    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: { store.selectedCardId != nil },
            set: { if !$0 { store.selectedCardId = nil } }
        )
    }

    private var theaterBinding: Binding<Bool> {
        Binding(
            get: { store.theaterMode },
            set: {
                theaterPulse = false
                store.theaterMode = $0
            }
        )
    }

    private var pulseTaskKey: String {
        "\(store.currentMissionId ?? "none")-\(String(describing: store.missionPhase))-\(store.theaterMode)-\(interactionGeneration)"
    }

    private func recordInteraction() {
        theaterPulse = false
        interactionGeneration += 1
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
