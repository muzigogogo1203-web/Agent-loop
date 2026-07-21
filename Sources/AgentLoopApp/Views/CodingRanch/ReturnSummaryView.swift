import SwiftUI
import QuickLook

struct ReturnSummaryView: View {
    let state: ReturnSummaryViewState
    var onReveal: (ArtifactSummaryViewState) -> Void
    var onRequestChanges: () -> Void
    var onAccept: () -> Void
    var onAbandon: () -> Void
    var onOpenRoster: () -> Void = {}

    @State private var previewURL: URL?
    @State private var showAbandonConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                artifacts
                validation
                knowledge
                newcomer
                actions
            }
            .frame(maxWidth: 900)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Camp.canvas)
        .quickLookPreview($previewURL)
        .confirmationDialog("放弃这次成果？", isPresented: $showAbandonConfirmation, titleVisibility: .visible) {
            Button("放弃成果", role: .destructive, action: onAbandon)
            Button("继续验收", role: .cancel) {}
        } message: {
            Text("已经生成的文件会保留，但任务不会作为一次成功回营。")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("回营验收", systemImage: "house.and.flag.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Camp.ink)
                Spacer()
                CampChip(text: state.mission.phaseText, color: state.canAccept ? Camp.moss : Camp.amber)
            }
            Text(state.mission.title)
                .font(.title3)
                .foregroundStyle(Camp.inkSecondary)
        }
        .campCard()
    }

    private var artifacts: some View {
        VStack(alignment: .leading, spacing: 10) {
            RanchSectionHeader(icon: "shippingbox.fill", title: "成果预览", tint: Camp.creek)
            if state.artifacts.isEmpty {
                Label("还没有真实交付物", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Camp.charcoalRed)
            } else {
                ForEach(state.artifacts) { artifact in
                    HStack(spacing: 10) {
                        Image(systemName: artifact.exists ? "doc.fill" : "doc.badge.ellipsis")
                            .foregroundStyle(artifact.exists ? Camp.moss : Camp.charcoalRed)
                        Text(artifact.label).font(.callout.weight(.medium)).foregroundStyle(Camp.ink)
                        Spacer()
                        if artifact.previewable && artifact.exists {
                            Button("预览") { previewURL = URL(fileURLWithPath: artifact.path) }
                                .buttonStyle(CampSecondaryButtonStyle())
                        }
                        Button("Finder") { onReveal(artifact) }
                            .buttonStyle(CampSecondaryButtonStyle())
                            .disabled(!artifact.exists)
                    }
                }
            }
        }
        .campCard()
    }

    private var validation: some View {
        VStack(alignment: .leading, spacing: 9) {
            RanchSectionHeader(icon: "checkmark.seal.fill", title: "验证清单", tint: Camp.moss)
            ForEach(state.validationChecklist) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.completed ? Camp.moss : Camp.stone)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.callout).foregroundStyle(Camp.ink)
                        if let evidence = item.evidence, !evidence.isEmpty {
                            Text(evidence).font(.caption).foregroundStyle(Camp.inkSecondary).lineLimit(3)
                        }
                    }
                }
            }
        }
        .campCard()
    }

    private var knowledge: some View {
        VStack(alignment: .leading, spacing: 9) {
            RanchSectionHeader(icon: "book.closed.fill", title: "这次基础牛用了什么", tint: Camp.stone)
            if state.usedKnowledge.isEmpty {
                Text("没有记录到显式引用的营地知识。")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            } else {
                ForEach(state.usedKnowledge) { item in
                    Label(item.title, systemImage: "book.closed.fill")
                        .font(.callout)
                        .foregroundStyle(Camp.ink)
                }
            }
        }
        .campCard()
    }

    private var newcomer: some View {
        NewcomerTaskCard(progress: state.newcomerProgress, onOpenRoster: onOpenRoster)
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let blockReason = state.blockReason {
                Label(blockReason, systemImage: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Camp.amber)
            }
            HStack {
                Button("放弃成果", role: .destructive) { showAbandonConfirmation = true }
                    .buttonStyle(.plain)
                    .foregroundStyle(Camp.charcoalRed)
                Spacer()
                Button("提出修改", action: onRequestChanges)
                    .buttonStyle(CampSecondaryButtonStyle(tint: Camp.amber))
                Button("验收并回营", action: onAccept)
                    .buttonStyle(CampPrimaryButtonStyle())
                    .disabled(!state.canAccept)
            }
        }
    }
}
