import SwiftUI
import AppKit

struct MissionDraftConfirmationView: View {
    @State private var draft: MissionDraftViewState
    @State private var items: [AcceptanceItem]
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
        _items = State(initialValue: draft.acceptance.map { AcceptanceItem(text: $0) })
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
            .padding(20)
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
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Camp.ink)
                Text("确认目标、验收清单和工作目录后，才会创建真实任务并开始调用模型和工具。")
                    .font(.callout)
                    .foregroundStyle(Camp.inkSecondary)
            }
        }
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            RanchSectionHeader(icon: "flag", title: "这次的目标", tint: Camp.ember)
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
            RanchSectionHeader(icon: "book", title: "带上的营地知识", tint: Camp.amber)
            if draft.knowledge.isEmpty {
                Text("这次任务没有关联营地笔记。")
                    .font(.callout)
                    .foregroundStyle(Camp.inkSecondary)
            } else {
                ForEach(draft.knowledge) { item in
                    HStack(spacing: 8) {
                        Image(systemName: "book.closed.fill").foregroundStyle(Camp.stone)
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
                RanchSectionHeader(icon: "checkmark.seal", title: "验收清单", tint: Camp.moss)
                Spacer()
                Button("增加一项") { items.append(AcceptanceItem(text: "")) }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Camp.ember)
            }
            ForEach($items) { $item in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle").foregroundStyle(Camp.moss)
                    TextField("可验证的验收条件", text: $item.text)
                        .textFieldStyle(.plain)
                    Button {
                        items.removeAll { $0.id == item.id }
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
                RanchSectionHeader(icon: "shippingbox", title: "交付方式", tint: Camp.creek)
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
        HStack(alignment: .bottom, spacing: 10) {
            Button("返回", action: onCancel)
                .buttonStyle(CampSecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                if let startDisabledMessage {
                    Text(startDisabledMessage)
                        .font(.caption)
                        .foregroundStyle(Camp.charcoalRed)
                }
                HStack(spacing: 8) {
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
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!canStart || actionState == .running)
                    .help(startDisabledMessage ?? "创建任务并进入 Coding 草原")
                    Text("⌘↩ 开始")
                        .font(.caption2)
                        .foregroundStyle(Camp.inkSecondary)
                    }
            }
        }
    }

    private var canStart: Bool {
        draft.canStart
            && !draft.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.workspacePath.isEmpty
            && items.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var startDisabledMessage: String? {
        guard !canStart else { return nil }
        if let reason = draft.startBlockReason, !reason.isEmpty { return reason }
        var missing: [String] = []
        if draft.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append("目标") }
        if draft.workspacePath.isEmpty { missing.append("工作目录") }
        if !items.contains(where: { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            missing.append("至少一条验收条件")
        }
        return missing.isEmpty ? nil : "还差：\(missing.joined(separator: " / "))"
    }

    private var errorMessage: String? {
        if case .failed(let message) = actionState { return message }
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
            var submittedDraft = draft
            submittedDraft.acceptance = items.map(\.text)
            let missionId = try await onStart(submittedDraft)
            actionState = .idle
            onStarted(missionId)
        } catch {
            actionState = .failed(error.localizedDescription)
        }
    }
}

private struct AcceptanceItem: Identifiable {
    let id = UUID()
    var text: String
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
