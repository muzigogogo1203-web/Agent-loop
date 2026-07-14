import SwiftUI
import AgentLoopCore

struct CowRosterView: View {
    let state: CowRosterViewState
    var onOpenCow: (String) -> Void = { _ in }
    var onUnlock: () async throws -> CowSummaryViewState
    var onCreateCustomCow: () -> Void = {}

    @State private var actionState: CodingRanchActionState = .idle

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Camp.line)
            content
        }
        .background(Camp.canvas)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "building.2.crop.circle.fill")
                .font(.title2)
                .foregroundStyle(Camp.ember)
            VStack(alignment: .leading, spacing: 3) {
                Text("牛棚")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Camp.ink)
                Text("每只牛都对应真实的角色、能力和任务记录。")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            }
            Spacer()
            if state.canCreateCustomCow {
                Button("创建自定义牛…", action: onCreateCustomCow)
                    .buttonStyle(CampSecondaryButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Camp.surface)
    }

    @ViewBuilder private var content: some View {
        switch state.loadState {
        case .idle, .loading:
            ProgressView("正在打开牛棚…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            CodingRanchEmptyState(title: "牛棚暂时打不开", message: message, systemImage: "exclamationmark.triangle.fill")
                .padding(20)
        case .loaded:
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        CampSectionTitle("已经在营地的牛")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 12)], spacing: 12) {
                            ForEach(state.owned) { cow in
                                CowRosterCard(cow: cow) { onOpenCow(cow.id) }
                            }
                        }
                    }
                    if !state.locked.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            CampSectionTitle("下一只可以学习的牛")
                            ForEach(state.locked) { cow in
                                CowUnlockCard(
                                    cow: cow,
                                    progress: state.newcomerProgress,
                                    actionState: actionState,
                                    onUnlock: { Task { await unlock() } }
                                )
                            }
                        }
                    }
                    if case .failed(let message) = actionState {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(Camp.charcoalRed)
                            .campStatusPanel(Camp.charcoalRed)
                    }
                }
                .padding(20)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            }
        }
    }

    @MainActor private func unlock() async {
        actionState = .running
        do {
            let cow = try await onUnlock()
            actionState = .idle
            AccessibilityNotification.Announcement("\(cow.name)已经领回营地").post()
        } catch {
            actionState = .failed(error.localizedDescription)
        }
    }
}

struct CowRosterCard: View {
    let cow: CowSummaryViewState
    var onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 11) {
                CompanionAvatarView(name: cow.name, colorName: cow.colorName, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(cow.name).font(.headline).foregroundStyle(Camp.ink)
                    Text(cow.role).font(.caption).foregroundStyle(Camp.inkSecondary)
                }
                Spacer()
                CowStatusLabel(status: cow.status)
            }
            Text(cow.specialties.joined(separator: " · "))
                .font(.callout)
                .foregroundStyle(Camp.ink)
                .lineLimit(2)
            if let recentMission = cow.recentMission {
                Label(recentMission, systemImage: "flag.fill")
                    .font(.caption)
                    .foregroundStyle(Camp.inkSecondary)
            }
            Button("查看牛的档案", action: onOpen)
                .buttonStyle(CampSecondaryButtonStyle(tint: Camp.ember))
        }
        .campCard()
    }
}

struct CowUnlockCard: View {
    let cow: LockedCowViewState
    let progress: NewcomerProgressViewState
    let actionState: CodingRanchActionState
    var onUnlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 13) {
                ZStack {
                    Circle().fill(Camp.stone.opacity(0.13)).frame(width: 60, height: 60)
                    Image(systemName: progress.canUnlock ? "pawprint.fill" : "lock.fill")
                        .font(.title2)
                        .foregroundStyle(progress.canUnlock ? Camp.moss : Camp.stone)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(cow.name).font(.headline).foregroundStyle(Camp.ink)
                        CampChip(text: progress.canUnlock ? "可以领回" : "学习中", color: progress.canUnlock ? Camp.moss : Camp.stone)
                    }
                    Text(cow.role).font(.callout).foregroundStyle(Camp.inkSecondary)
                    Text(cow.learningGoal).font(.caption).foregroundStyle(Camp.inkSecondary)
                }
            }
            HStack(alignment: .top, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    CampSectionTitle("它能帮你")
                    ForEach(cow.capabilities, id: \.self) { capability in
                        Label(capability, systemImage: "checkmark.seal")
                            .font(.caption)
                            .foregroundStyle(Camp.ink)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    CampSectionTitle("解锁条件")
                    ForEach(progress.steps) { step in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: step.status == .completed ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(step.status == .completed ? Camp.moss : Camp.stone)
                            Text(step.title)
                                .font(.caption)
                                .foregroundStyle(Camp.ink)
                        }
                    }
                }
            }
            if progress.canUnlock {
                HStack {
                    Text("条件都满足了。确认后，测试牛会作为真实角色加入牛棚。")
                        .font(.caption)
                        .foregroundStyle(Camp.moss)
                    Spacer()
                    Button(action: onUnlock) {
                        if actionState == .running {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Label("领回营地", systemImage: "house.fill")
                        }
                    }
                    .buttonStyle(CampPrimaryButtonStyle(size: .small))
                    .disabled(actionState == .running)
                }
            }
        }
        .campCard(highlighted: progress.canUnlock)
    }
}

struct CowRosterView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CowRosterView(state: CodingRanchPreviewFixtures.roster, onUnlock: { CodingRanchPreviewFixtures.testCow })
                .frame(width: 900, height: 700)
                .previewDisplayName("牛棚 · 学习中")
            CowRosterView(state: CodingRanchPreviewFixtures.eligibleRoster, onUnlock: { CodingRanchPreviewFixtures.testCow })
                .frame(width: 900, height: 700)
                .previewDisplayName("牛棚 · 可领回")
        }
    }
}
