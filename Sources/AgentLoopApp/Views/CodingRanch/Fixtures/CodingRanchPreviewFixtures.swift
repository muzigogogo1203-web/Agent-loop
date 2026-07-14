import Foundation

enum CodingRanchPreviewFixtures {
    static let baseCow = CowSummaryViewState(
        id: "cow-basic",
        name: "基础牛",
        role: "教学型 Coding 通才",
        colorName: "amber",
        specialties: ["需求整理", "简单网页", "小工具"],
        status: .idle,
        lastActivity: "刚刚回到营地",
        recentMission: nil,
        isSystemGuide: false
    )

    static let workingCow = CowSummaryViewState(
        id: "cow-basic",
        name: "基础牛",
        role: "教学型 Coding 通才",
        colorName: "amber",
        specialties: ["需求整理", "简单网页", "小工具"],
        status: .working,
        lastActivity: "正在制作喝水打卡页",
        recentMission: "七天喝水打卡页",
        isSystemGuide: false
    )

    static let testCow = CowSummaryViewState(
        id: "cow-test",
        name: "测试牛",
        role: "质量与验收专家",
        colorName: "teal",
        specialties: ["验收清单", "边界检查", "回归测试"],
        status: .idle,
        lastActivity: "已领回营地",
        recentMission: nil,
        isSystemGuide: false
    )

    static let lockedTestCow = LockedCowViewState(
        id: "template-test-cow",
        name: "测试牛",
        role: "质量与验收专家",
        capabilities: ["把需求变成测试点", "检查交付物", "发现边界问题"],
        learningGoal: "完成一次真实的喂牛、放牛和回营闭环",
        conditions: ["资料已收进营地", "任务引用了这条资料", "任务产生真实成果", "你完成验收", "任务已回营"]
    )

    static let newcomerProgress = NewcomerProgressViewState(
        steps: [
            UnlockStepViewState(id: "feed", title: "第一次喂牛", status: .completed, evidenceText: "习惯养成文章已收进营地"),
            UnlockStepViewState(id: "mission", title: "第一次放牛", status: .completed, evidenceText: "喝水打卡页正在制作"),
            UnlockStepViewState(id: "return", title: "第一次回营", status: .pending, evidenceText: nil),
        ],
        nextCow: lockedTestCow,
        canUnlock: false,
        isUnlocked: false
    )

    static let unlockEligibleProgress = NewcomerProgressViewState(
        steps: newcomerProgress.steps.map {
            UnlockStepViewState(id: $0.id, title: $0.title, status: .completed, evidenceText: $0.evidenceText ?? "已完成")
        },
        nextCow: lockedTestCow,
        canUnlock: true,
        isUnlocked: false
    )

    static let note = CampNoteSummaryViewState(
        id: "note-1",
        title: "低摩擦打卡的三个原则",
        excerpt: "打卡动作应在十秒内完成，并提供连续反馈。",
        sourceType: "主动喂牛",
        sourceLabel: "《如何养成一个习惯》",
        updatedAt: Date(timeIntervalSince1970: 1_720_000_000),
        pinned: true
    )

    static let mission = MissionSummaryViewState(
        id: "mission-1",
        title: "七天喝水打卡页",
        phaseText: "基础牛正在制作首版",
        cowName: "基础牛",
        lastActivity: "刚刚完成页面骨架",
        pendingUserAction: nil,
        artifactCount: 1
    )

    static let waitingMission = MissionSummaryViewState(
        id: "mission-2",
        title: "整理产品说明",
        phaseText: "基础牛需要你决定一件事",
        cowName: "基础牛",
        lastActivity: "等待选择交付格式",
        pendingUserAction: "选择 Markdown 或 HTML",
        artifactCount: 0
    )

    static let queuedItem = RuminationInboxItemViewState(
        id: "ingestion-queued",
        title: "关于习惯养成的文章",
        sourceKind: .pastedText,
        createdAt: Date(timeIntervalSince1970: 1_720_000_000),
        campName: "我的营地",
        status: .queued,
        resultCountText: "尚未反刍",
        isPossibleDuplicate: false,
        error: nil
    )

    static let ruminatingItem = RuminationInboxItemViewState(
        id: "ingestion-ruminating",
        title: "三人喝水打卡的想法",
        sourceKind: .directThought,
        createdAt: Date(timeIntervalSince1970: 1_720_003_600),
        campName: "我的营地",
        status: .ruminating(stage: .extracting),
        resultCountText: "正在整理",
        isPossibleDuplicate: false,
        error: nil
    )

    static let reviewItem = RuminationInboxItemViewState(
        id: "ingestion-review",
        title: "团队喝水打卡需求",
        sourceKind: .pastedText,
        createdAt: Date(timeIntervalSince1970: 1_720_007_200),
        campName: "我的营地",
        status: .needsReview,
        resultCountText: "3 条知识 · 2 个需求 · 1 个待办",
        isPossibleDuplicate: false,
        error: nil
    )

    static let failedItem = RuminationInboxItemViewState(
        id: "ingestion-failed",
        title: "一段没有整理完的会议记录",
        sourceKind: .pastedText,
        createdAt: Date(timeIntervalSince1970: 1_719_900_000),
        campName: "我的营地",
        status: .failed(message: "模型暂时没有返回有效结果", retryable: true),
        resultCountText: "原文已保留",
        isPossibleDuplicate: true,
        error: "可以稍后重试"
    )

    static let inbox = RuminationInboxViewState(
        loadState: .loaded,
        items: [reviewItem, ruminatingItem, queuedItem, failedItem]
    )

    static let review = RuminationReviewViewState(
        ingestionId: "ingestion-review",
        title: "低摩擦的七天喝水打卡",
        summary: "文章建议把记录动作压缩到十秒内，并通过连续反馈帮助三人坚持七天。",
        candidates: [
            EditableCandidateViewState(
                id: "kp-1", kind: .keyPoint, title: "降低记录摩擦",
                detail: "单次打卡应在十秒内完成。", disposition: .accepted, confidence: 0.94,
                evidence: [SourceEvidenceViewState(id: "e-1", quote: "记录动作越短，越容易坚持。", locator: "第 3 段", originLabel: "来自原文")],
                origin: "来自原文"
            ),
            EditableCandidateViewState(
                id: "req-1", kind: .requirement, title: "三人共同使用",
                detail: "页面需要区分三位参与者。", disposition: .accepted, confidence: 0.86,
                evidence: [SourceEvidenceViewState(id: "e-2", quote: "我想给三个人做一个七天喝水打卡页。", locator: "用户补充", originLabel: "用户明确表达")],
                origin: "用户明确表达"
            ),
            EditableCandidateViewState(
                id: "todo-1", kind: .todo, title: "明天发给同事试用",
                detail: "交付一个双击可打开的页面。", disposition: .accepted, confidence: 0.9,
                evidence: [], origin: "用户明确表达"
            ),
        ],
        missionDraft: MissionDraftViewState(
            draftId: "draft-1", ingestionId: "ingestion-review", campId: "camp-1", cow: baseCow,
            goal: "制作一个三人使用的七天喝水打卡单页",
            acceptance: ["可以记录三个人每天的喝水次数", "展示连续打卡天数", "双击 HTML 文件即可使用"],
            knowledge: [MissionKnowledgeItemViewState(id: "note-1", title: "低摩擦打卡的三个原则", sourceLabel: "主动喂牛")],
            deliverableType: "单页 HTML", workspacePath: "~/Desktop/drink-water",
            isNewcomer: true, canStart: true, startBlockReason: nil
        ),
        source: SourceViewState(
            title: "关于习惯养成的文章",
            sourceURL: "https://example.com/habit",
            author: "示例作者",
            userIntent: "我想给三个人做一个七天喝水打卡页，明天发给同事试用。",
            sourceKind: .pastedText,
            createdAt: Date(timeIntervalSince1970: 1_720_000_000),
            rawText: "记录动作越短，越容易坚持。明确触发、低摩擦记录和连续反馈，是形成习惯的关键。"
        ),
        uncertainties: ["原文没有说明是否需要联网保存数据"],
        isSaving: false,
        error: nil,
        hasChanges: false,
        canMaterialize: true
    )

    static let emptyCamp = CampDashboardViewState(
        loadState: .loaded,
        campId: "camp-1",
        campName: "我的营地",
        activeCow: baseCow,
        pendingRuminationCount: 0,
        pendingConfirmationCount: 0,
        pendingReturnCount: 0,
        pendingItems: [],
        activeMissions: [],
        recentMissions: [],
        recentNotes: [],
        newcomerProgress: NewcomerProgressViewState(
            steps: newcomerProgress.steps.map { UnlockStepViewState(id: $0.id, title: $0.title, status: .pending, evidenceText: nil) },
            nextCow: lockedTestCow,
            canUnlock: false,
            isUnlocked: false
        )
    )

    static let activeCamp = CampDashboardViewState(
        loadState: .loaded,
        campId: "camp-1",
        campName: "我的营地",
        activeCow: workingCow,
        pendingRuminationCount: 2,
        pendingConfirmationCount: 1,
        pendingReturnCount: 1,
        pendingItems: [reviewItem, ruminatingItem],
        activeMissions: [mission, waitingMission],
        recentMissions: [],
        recentNotes: [note],
        newcomerProgress: newcomerProgress
    )

    static let roster = CowRosterViewState(
        loadState: .loaded,
        owned: [baseCow],
        locked: [lockedTestCow],
        newcomerProgress: newcomerProgress,
        canCreateCustomCow: false
    )

    static let eligibleRoster = CowRosterViewState(
        loadState: .loaded,
        owned: [baseCow],
        locked: [lockedTestCow],
        newcomerProgress: unlockEligibleProgress,
        canCreateCustomCow: true
    )

    static let unlockedRoster = CowRosterViewState(
        loadState: .loaded,
        owned: [baseCow, testCow],
        locked: [],
        newcomerProgress: NewcomerProgressViewState(
            steps: unlockEligibleProgress.steps,
            nextCow: lockedTestCow,
            canUnlock: false,
            isUnlocked: true
        ),
        canCreateCustomCow: true
    )
}
