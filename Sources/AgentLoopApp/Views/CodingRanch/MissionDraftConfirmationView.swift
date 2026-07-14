import SwiftUI
import AppKit

struct MissionDraftConfirmationView: View {
    @State private var draft: MissionDraftViewState
    var onStart: (MissionDraftViewState) async throws -> String
    var onStarted: (String) -> Void
    var onCancel: () -> Void

    @State private var showAdvanced = false
    @State private var actionState: CodingRanchActionState = .idle

    init(
        draft: MissionDraftViewState,
        onStart: @escaping (MissionDraftViewState) async throws -> String,
        onStarted: @escaping (String) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        _draft = State(initialValue: draft)
        self.onStart = onStart
        self.onStarted = onStarted
        self.onCancel = onCancel
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                goalCard
                knowledgeCard
                acceptanceCard
                deliveryCard
                DisclosureGroup("高级设置", isExpanded: $showAdvanced) {
                    Text("自主档位、预算、模型和工具继续使用 Coding 牧场的全局设置。首次任务默认只使用基础牛。")
                        .font(.caption)
                        .foregroundStyle(Camp.inkSecondary)
                        .padding(.top, 8)
                }
                .tint(Camp.ember)
                .campCard()
                if let error = errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(Camp.charcoalRed)
                        .campStatusPanel(Camp.charcoalRed)
                }
                footer
            }
            .frame(maxWidth: 720)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Camp.canvas)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            if let cow = draft.cow {
                CompanionAvatarView(name: cow.name, colorName: cow.colorName, size: 58)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(draft.isNewcomer ? "基础牛准备这样做" : "确认放牛任务")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Camp.ink)
                Text("确认目标、验收清单和工作目录后，才会创建真实任务并开始调用模型和工具。")
                    .font(.callout)
                    .foregroundStyle(Camp.inkSecondary)
            }
        }
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            CampSectionTitle("任务目标")
            TextField("这次放牛要完成什么？", text: $draft.goal, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...8)
                .padding(10)
                .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius))
                .overlay(RoundedRectangle(cornerRadius: Camp.smallRadius).stroke(Camp.line))
        }
        .campCard()
    }

    private var knowledgeCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            CampSectionTitle("将使用的营地知识")
            if draft.knowledge.isEmpty {
                Text("这次任务没有关联营地笔记。")
                    .font(.callout)
                    .foregroundStyle(Camp.inkSecondary)
            } else {
                ForEach(draft.knowledge) { item in
                    HStack(spacing: 8) {
                        Image(systemName: "book.closed.fill").foregroundStyle(Camp.amber)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.callout.weight(.medium)).foregroundStyle(Camp.ink)
                            Text(item.sourceLabel).font(.caption).foregroundStyle(Camp.inkSecondary)
                        }
                    }
                }
            }
        }
        .campCard()
    }

    private var acceptanceCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                CampSectionTitle("验收清单")
                Spacer()
                Button("增加一项") { draft.acceptance.append("") }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Camp.ember)
            }
            ForEach(draft.acceptance.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle").foregroundStyle(Camp.moss)
                    TextField("可验证的验收条件", text: $draft.acceptance[index])
                        .textFieldStyle(.plain)
                    Button {
                        draft.acceptance.remove(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Camp.stone)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("删除这条验收条件")
                }
                .padding(9)
                .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius))
            }
        }
        .campCard()
    }

    private var deliveryCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                CampSectionTitle("交付物")
                Spacer()
                CampChip(text: draft.deliverableType, color: Camp.creek, icon: "doc.fill")
            }
            HStack(spacing: 9) {
                Image(systemName: "folder.fill").foregroundStyle(Camp.inkSecondary)
                Text(draft.workspacePath.isEmpty ? "还没有选择工作目录" : draft.workspacePath)
                    .font(.callout)
                    .foregroundStyle(draft.workspacePath.isEmpty ? Camp.inkSecondary : Camp.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("选择…", action: chooseWorkspace)
                    .buttonStyle(CampSecondaryButtonStyle())
            }
        }
        .campCard()
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("返回", action: onCancel)
                .buttonStyle(CampSecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button {
                Task { await start() }
            } label: {
                if actionState == .running {
                    HStack(spacing: 7) {
                        ProgressView().controlSize(.small).tint(.white)
                        Text("正在开工…")
                    }
                } else {
                    Label("开始放牛", systemImage: "flag.fill")
                }
            }
            .buttonStyle(CampPrimaryButtonStyle())
            .keyboardShortcut(.defaultAction)
            .disabled(!canStart || actionState == .running)
            .opacity(canStart && actionState != .running ? 1 : 0.5)
            .help(draft.startBlockReason ?? "创建任务并进入 Coding 草原")
        }
    }

    private var canStart: Bool {
        draft.canStart
            && !draft.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.workspacePath.isEmpty
            && !draft.acceptance.filter({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }).isEmpty
    }

    private var errorMessage: String? {
        if case .failed(let message) = actionState { return message }
        if !draft.canStart { return draft.startBlockReason }
        return nil
    }

    private func chooseWorkspace() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            draft.workspacePath = panel.url?.path ?? ""
        }
    }

    @MainActor private func start() async {
        guard canStart else { return }
        actionState = .running
        do {
            let missionId = try await onStart(draft)
            actionState = .idle
            onStarted(missionId)
        } catch {
            actionState = .failed(error.localizedDescription)
        }
    }
}

struct MissionDraftConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        MissionDraftConfirmationView(
            draft: CodingRanchPreviewFixtures.review.missionDraft!,
            onStart: { _ in "mission-preview" },
            onStarted: { _ in }
        )
        .frame(width: 780, height: 760)
    }
}
