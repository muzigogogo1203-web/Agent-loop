import SwiftUI

struct FeedComposerView: View {
    let campName: String
    let modelConnection: ModelConnectionViewState
    var onSaveDraft: (FeedDraft) -> Void
    var onSubmit: (FeedDraft, Bool) async throws -> FeedSubmissionResult
    var onSubmitDuplicate: (FeedDraft, Bool) async throws -> FeedSubmissionResult
    var onCancel: () -> Void

    @State private var draft: FeedDraft
    @State private var actionState: CodingRanchActionState = .idle
    @State private var duplicate: (id: String, title: String)?
    @State private var pendingStartRumination = true
    @State private var showDiscardConfirmation = false

    init(
        draft: FeedDraft,
        campName: String,
        modelConnection: ModelConnectionViewState = .configured,
        onSaveDraft: @escaping (FeedDraft) -> Void = { _ in },
        onSubmit: @escaping (FeedDraft, Bool) async throws -> FeedSubmissionResult,
        onSubmitDuplicate: @escaping (FeedDraft, Bool) async throws -> FeedSubmissionResult,
        onCancel: @escaping () -> Void = {}
    ) {
        _draft = State(initialValue: draft)
        self.campName = campName
        self.modelConnection = modelConnection
        self.onSaveDraft = onSaveDraft
        self.onSubmit = onSubmit
        self.onSubmitDuplicate = onSubmitDuplicate
        self.onCancel = onCancel
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                contentSection
                sourceSection
                intentSection
                privacyNotice
                if case .failed(let message) = actionState {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(Camp.charcoalRed)
                        .campStatusPanel(Camp.charcoalRed)
                }
                footer
            }
            .frame(maxWidth: 720)
            .padding(22)
            .frame(maxWidth: .infinity)
        }
        .background(Camp.canvas)
        .confirmationDialog(
            "这条内容可能已经喂过",
            isPresented: Binding(get: { duplicate != nil }, set: { if !$0 { duplicate = nil } }),
            titleVisibility: .visible
        ) {
            Button("仍然保存") {
                Task { await submitDuplicate() }
            }
            Button("取消", role: .cancel) { duplicate = nil }
        } message: {
            Text("已有内容：\(duplicate?.title ?? "未命名内容")。再次保存会保留两份独立材料。")
        }
        .confirmationDialog("关闭编辑器？", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
            Button("保存草稿并关闭") {
                onSaveDraft(draft)
                onCancel()
            }
            Button("继续编辑", role: .cancel) {}
        } message: {
            Text("当前内容会作为草稿保留，不会开始反刍。")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("喂给基础牛")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Camp.ink)
                Text("把文章、资料或想法放进\(campName)。原文会先保存，再由营地管家反刍。")
                    .font(.callout)
                    .foregroundStyle(Camp.inkSecondary)
            }
            Spacer()
            Button("关闭") {
                if hasContent {
                    showDiscardConfirmation = true
                } else {
                    onCancel()
                }
            }
            .buttonStyle(CampSecondaryButtonStyle())
            .keyboardShortcut(.cancelAction)
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                CampSectionTitle("正文")
                Spacer()
                Text("\(nonWhitespaceCount) 字")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Camp.inkSecondary)
            }
            TextEditor(text: $draft.body)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 220)
                .padding(10)
                .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                        .stroke(bodyBorderColor, lineWidth: 1)
                )
                .accessibilityLabel("要喂给基础牛的正文")
            if !draft.body.isEmpty && nonWhitespaceCount < 20 {
                Text("内容有点短。可以继续补充，也可以先保存，稍后再反刍。")
                    .font(.caption)
                    .foregroundStyle(Camp.amber)
            }
        }
        .campCard()
    }

    private var sourceSection: some View {
        FeedSourceFieldsView(draft: $draft)
            .campCard()
    }

    private var intentSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            CampSectionTitle("希望基础牛重点关注什么？")
            TextField("例如：帮我找出可以做成小工具的需求", text: $draft.userIntent, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(2...5)
                .padding(11)
                .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous)
                        .stroke(Camp.line, lineWidth: 1)
                )
        }
        .campCard()
    }

    private var privacyNotice: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(Camp.moss)
            VStack(alignment: .leading, spacing: 3) {
                Text("内容保存在当前 Mac")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Camp.ink)
                Text(modelNotice)
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            }
        }
        .campStatusPanel(Camp.moss)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("仅保存，稍后反刍") {
                Task { await submit(startRumination: false) }
            }
            .buttonStyle(CampSecondaryButtonStyle())
            .disabled(!canSave || isRunning)

            Spacer()

            Button {
                Task { await submit(startRumination: true) }
            } label: {
                if isRunning {
                    HStack(spacing: 7) {
                        ProgressView().controlSize(.small).tint(.white)
                        Text("正在保存…")
                    }
                } else {
                    Label("喂给基础牛", systemImage: "leaf.fill")
                }
            }
            .buttonStyle(CampPrimaryButtonStyle())
            .keyboardShortcut(.defaultAction)
            .disabled(!canRuminate || isRunning)
            .opacity(canRuminate && !isRunning ? 1 : 0.5)
            .help(canRuminate ? "保存原文并开始反刍" : primaryDisabledReason)
        }
    }

    private var nonWhitespaceCount: Int {
        draft.body.filter { !$0.isWhitespace }.count
    }

    private var hasContent: Bool {
        !draft.body.isEmpty || !draft.title.isEmpty || !draft.sourceURL.isEmpty || !draft.userIntent.isEmpty
    }

    private var canSave: Bool { nonWhitespaceCount > 0 }
    private var canRuminate: Bool {
        nonWhitespaceCount >= 20 && modelConnection == .configured
    }
    private var isRunning: Bool {
        if case .running = actionState { return true }
        return false
    }
    private var bodyBorderColor: Color {
        !draft.body.isEmpty && nonWhitespaceCount < 20 ? Camp.amber.opacity(0.65) : Camp.line
    }

    private var modelNotice: String {
        switch modelConnection {
        case .configured:
            "开始反刍时，正文会发送给已配置的模型；外部内容始终按不可信资料处理。"
        case .missing:
            "还没有连接模型。你可以先保存原文，配置模型后再反刍。"
        case .checking:
            "正在检查模型连接。原文仍可先保存在本机。"
        case .failed(let message):
            "模型连接暂不可用：\(message)。原文仍可先保存在本机。"
        }
    }

    private var primaryDisabledReason: String {
        if nonWhitespaceCount < 20 { return "至少输入 20 个非空字符后开始反刍" }
        if modelConnection != .configured { return "先连接模型，或选择仅保存" }
        return ""
    }

    @MainActor
    private func submit(startRumination: Bool) async {
        guard canSave else { return }
        actionState = .running
        pendingStartRumination = startRumination
        do {
            let result = try await onSubmit(draft, startRumination)
            switch result {
            case .saved:
                actionState = .idle
                onCancel()
            case .duplicate(let existingId, let title):
                actionState = .idle
                duplicate = (existingId, title)
            }
        } catch {
            actionState = .failed(error.localizedDescription)
        }
    }

    @MainActor
    private func submitDuplicate() async {
        duplicate = nil
        actionState = .running
        do {
            _ = try await onSubmitDuplicate(draft, pendingStartRumination)
            actionState = .idle
            onCancel()
        } catch {
            actionState = .failed(error.localizedDescription)
        }
    }
}

struct FeedSourceFieldsView: View {
    @Binding var draft: FeedDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            CampSectionTitle("标题和来源（可选）")
            TextField("标题；留空时由反刍建议", text: $draft.title)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Camp.smallRadius).stroke(Camp.line))
            HStack(spacing: 10) {
                TextField("来源 URL", text: $draft.sourceURL)
                    .textFieldStyle(.plain)
                Divider().frame(height: 20)
                TextField("作者或出处", text: $draft.author)
                    .textFieldStyle(.plain)
                    .frame(minWidth: 150)
            }
            .padding(10)
            .background(Camp.surfaceRaised, in: RoundedRectangle(cornerRadius: Camp.smallRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Camp.smallRadius).stroke(Camp.line))
        }
    }
}

struct FeedComposerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            FeedComposerView(
                draft: FeedDraft(campId: "camp-1"),
                campName: "我的营地",
                onSubmit: { _, _ in .saved(ingestionId: "preview", startsRumination: true) },
                onSubmitDuplicate: { _, _ in .saved(ingestionId: "preview", startsRumination: true) }
            )
            .frame(width: 760, height: 760)
            .previewDisplayName("喂牛编辑器")

            FeedComposerView(
                draft: FeedDraft(body: "先把这段想法保存在本机，等模型配置好以后再开始反刍。", campId: "camp-1"),
                campName: "我的营地",
                modelConnection: .missing,
                onSubmit: { _, _ in .saved(ingestionId: "preview", startsRumination: false) },
                onSubmitDuplicate: { _, _ in .saved(ingestionId: "preview", startsRumination: false) }
            )
            .frame(width: 680, height: 700)
            .previewDisplayName("模型未连接")
        }
    }
}
