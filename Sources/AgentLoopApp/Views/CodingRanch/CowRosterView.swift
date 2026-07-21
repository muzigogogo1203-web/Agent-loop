import SwiftUI
import AgentLoopCore

struct CowRosterView: View {
    let state: CowRosterViewState
    var onOpenCow: (String) -> Void = { _ in }
    var onUnlock: () async throws -> CowSummaryViewState
    var onCreateCustomCow: () -> Void = {}

    @State private var actionState: CodingRanchActionState = .idle
    @State private var isUnlockExpanded = false
    @State private var toastMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(Camp.canvas)
        .campToast(toastMessage)
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                RanchCowSpriteView(colorName: "teal", height: 40, flipped: false)
                VStack(alignment: .leading, spacing: 3) {
                    Text("牛棚")
                        .font(.title2.weight(.bold))
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

            LinearGradient(
                colors: [Camp.pasture.opacity(0.45), Camp.pasture],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 4)
        }
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
                    RanchBarnView(
                        cows: state.owned.map {
                            (id: $0.id, name: $0.name, colorName: $0.colorName)
                        },
                        lockedCow: state.locked.first.map { ($0.name, state.newcomerProgress.canUnlock) },
                        maxWidth: 800,
                        onSelectCow: onOpenCow
                    )
                    .frame(maxWidth: .infinity)

                    if let cow = state.locked.first {
                        unlockProgressRow(cow)

                        if case .failed(let message) = actionState {
                            Label(message, systemImage: "exclamationmark.triangle.fill")
                                .font(.callout)
                                .foregroundStyle(Camp.charcoalRed)
                                .campStatusPanel(Camp.charcoalRed)
                        }
                    }

                    miniRoster
                }
                .padding(20)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func unlockProgressRow(_ cow: LockedCowViewState) -> some View {
        let progress = state.newcomerProgress
        let done = progress.steps.filter { $0.status == .completed }.count
        let expanded = progress.canUnlock || isUnlockExpanded

        return VStack(alignment: .leading, spacing: 12) {
            if progress.canUnlock {
                unlockProgressHeader(cow, progress: progress, done: done, expanded: expanded, showsUnlockAction: true)
            } else {
                Button {
                    withAnimation {
                        isUnlockExpanded.toggle()
                    }
                } label: {
                    unlockProgressHeader(cow, progress: progress, done: done, expanded: expanded, showsUnlockAction: false)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isUnlockExpanded ? "收起解锁条件" : "展开解锁条件")
            }

            if expanded {
                CowUnlockProgressDetails(cow: cow, progress: progress)
            }
        }
        .campCard()
    }

    private func unlockProgressHeader(
        _ cow: LockedCowViewState,
        progress: NewcomerProgressViewState,
        done: Int,
        expanded: Bool,
        showsUnlockAction: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: progress.canUnlock ? "sparkles" : "lock.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(progress.canUnlock ? Camp.moss : Camp.stone)

            Text(progress.canUnlock
                ? "\(cow.name) · 可以领回"
                : "\(cow.name) · 学习中 \(done)/\(progress.steps.count)")
                .font(.callout.weight(.semibold))
                .foregroundStyle(Camp.ink)

            Spacer()

            if showsUnlockAction {
                Button {
                    Task { await unlock() }
                } label: {
                    if actionState == .running {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Label("领回营地", systemImage: "house.fill")
                    }
                }
                .buttonStyle(CampPrimaryButtonStyle(size: .small))
                .disabled(actionState == .running)
            } else {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Camp.inkSecondary)
                    .rotationEffect(.degrees(expanded ? 180 : 0))
            }
        }
    }

    private var miniRoster: some View {
        FlowLayoutLite(spacing: 8) {
            ForEach(state.owned) { cow in
                Button {
                    onOpenCow(cow.id)
                } label: {
                    HStack(spacing: 6) {
                        RanchCowSpriteView(colorName: cow.colorName, height: 22, flipped: true)
                        Text(cow.name)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(Camp.ink)
                        CampChip(text: cow.role, color: Camp.stone)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Camp.surface, in: Capsule())
                    .overlay(Capsule().stroke(Camp.line, lineWidth: 1))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .campHoverLift()
            }
        }
    }

    @MainActor private func unlock() async {
        actionState = .running
        do {
            let cow = try await onUnlock()
            withAnimation(.spring(duration: 0.5)) {
                actionState = .idle
                toastMessage = "🐮 \(cow.name) 领回营地了"
            }
            AccessibilityNotification.Announcement("\(cow.name)已经领回营地").post()
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                if toastMessage == "🐮 \(cow.name) 领回营地了" {
                    toastMessage = nil
                }
            }
        } catch {
            actionState = .failed(error.localizedDescription)
        }
    }
}

private struct CowUnlockProgressDetails: View {
    let cow: LockedCowViewState
    let progress: NewcomerProgressViewState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            unlockConditionsColumn

            VStack(alignment: .leading, spacing: 6) {
                RanchSectionHeader(icon: "hand.thumbsup.fill", title: "它能帮你", tint: Camp.creek)
                FlowLayoutLite(spacing: 6) {
                    ForEach(cow.capabilities, id: \.self) { capability in
                        CampTag(text: capability)
                    }
                }
            }

            Text(cow.learningGoal)
                .font(.caption)
                .foregroundStyle(Camp.inkSecondary)
        }
    }

    private var unlockConditionsColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("解锁条件")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Camp.ink)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(progress.steps.enumerated()), id: \.element.id) { index, step in
                        VStack(spacing: 5) {
                            ZStack {
                                Circle()
                                    .fill(step.status == .completed ? Camp.moss : Camp.stone.opacity(0.25))
                                if step.status == .completed {
                                    Image(systemName: "pawprint.fill")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                } else {
                                    Text("\(index + 1)")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(Camp.stone)
                                }
                            }
                            .frame(width: 22, height: 22)

                            Text(step.title)
                                .font(.caption2)
                                .foregroundStyle(Camp.ink)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: true, vertical: true)
                        }
                        .frame(minWidth: 72)

                        if index < progress.steps.count - 1 {
                            Rectangle()
                                .fill(step.status == .completed ? Camp.moss : Camp.line)
                                .frame(width: 30, height: 2)
                                .padding(.top, 10)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
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
