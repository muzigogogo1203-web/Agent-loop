import Foundation

// MARK: - Shared UI boundary

enum CodingRanchLoadState: Sendable, Equatable { case idle, loading, loaded, failed(String) }
enum CodingRanchActionState: Sendable, Equatable { case idle, running, failed(String) }
enum ModelConnectionViewState: Sendable, Equatable { case configured, missing, checking, failed(String) }
enum CowStatusViewState: Sendable, Equatable {
    case idle, planning, working, waitingForUser, validating, returning, blocked(String), unavailable
}

struct CowSummaryViewState: Sendable, Equatable, Identifiable {
    let id: String
    let name: String
    let role: String
    let colorName: String
    let specialties: [String]
    let status: CowStatusViewState
    let lastActivity: String?
    let recentMission: String?
    let isSystemGuide: Bool
}

struct MissionSummaryViewState: Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let phaseText: String
    let cowName: String?
    let lastActivity: String?
    let pendingUserAction: String?
    let artifactCount: Int
}

struct CampNoteSummaryViewState: Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let excerpt: String
    let sourceType: String
    let sourceLabel: String
    let updatedAt: Date
    let pinned: Bool
}

enum UnlockStepStatusViewState: Sendable, Equatable { case pending, completed, blocked }

struct UnlockStepViewState: Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let status: UnlockStepStatusViewState
    let evidenceText: String?
}

struct LockedCowViewState: Sendable, Equatable, Identifiable {
    let id: String
    let name: String
    let role: String
    let capabilities: [String]
    let learningGoal: String
    let conditions: [String]
}

struct NewcomerProgressViewState: Sendable, Equatable {
    let steps: [UnlockStepViewState]
    let nextCow: LockedCowViewState
    let canUnlock: Bool
    let isUnlocked: Bool
}

struct CampDashboardViewState: Sendable, Equatable {
    let loadState: CodingRanchLoadState
    let campId: String
    let campName: String
    let activeCow: CowSummaryViewState?
    let pendingRuminationCount: Int
    let pendingConfirmationCount: Int
    let pendingReturnCount: Int
    let pendingItems: [RuminationInboxItemViewState]
    let activeMissions: [MissionSummaryViewState]
    let recentMissions: [MissionSummaryViewState]
    let recentNotes: [CampNoteSummaryViewState]
    let newcomerProgress: NewcomerProgressViewState
}

struct FeedDraft: Sendable, Equatable {
    var title = ""
    var body = ""
    var sourceURL = ""
    var author = ""
    var userIntent = ""
    var campId: String
}

enum FeedSubmissionResult: Sendable, Equatable {
    case saved(ingestionId: String, startsRumination: Bool)
    case duplicate(existingId: String, title: String)
}

enum RuminationSourceKind: String, Sendable, Equatable { case pastedText, directThought, url, file }
enum RuminationStage: Sendable, Equatable { case saved, reading, extracting, organizing }
enum RuminationStatusViewState: Sendable, Equatable {
    case queued
    case ruminating(stage: RuminationStage)
    case needsReview
    case materialized(noteId: String)
    case failed(message: String, retryable: Bool)
    case discarded
}

struct RuminationInboxItemViewState: Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let sourceKind: RuminationSourceKind
    let createdAt: Date
    let campName: String
    let status: RuminationStatusViewState
    let resultCountText: String
    let isPossibleDuplicate: Bool
    let error: String?
}

struct RuminationInboxViewState: Sendable, Equatable {
    let loadState: CodingRanchLoadState
    let items: [RuminationInboxItemViewState]
}

struct SourceViewState: Sendable, Equatable {
    let title: String
    let sourceURL: String?
    let author: String?
    let userIntent: String?
    let sourceKind: RuminationSourceKind
    let createdAt: Date
    let rawText: String
}

struct SourceEvidenceViewState: Sendable, Equatable, Identifiable {
    let id: String
    let quote: String
    let locator: String?
    let originLabel: String
}

enum CandidateKindViewState: String, Sendable, Equatable { case keyPoint, requirement, todo, mission }
enum CandidateDispositionViewState: Sendable, Equatable { case accepted, ignored }

struct EditableCandidateViewState: Sendable, Equatable, Identifiable {
    let id: String
    let kind: CandidateKindViewState
    var title: String
    var detail: String
    var disposition: CandidateDispositionViewState
    var confidence: Double?
    var evidence: [SourceEvidenceViewState]
    let origin: String?
}

struct MissionKnowledgeItemViewState: Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let sourceLabel: String
}

struct MissionDraftViewState: Sendable, Equatable {
    /// 草稿交付物类型的统一默认值(产品语义:以验收清单界定的成果)
    static let defaultDeliverableType = "可验证成果"

    let draftId: String
    let ingestionId: String?
    var campId: String
    var cow: CowSummaryViewState?
    var goal: String
    var acceptance: [String]
    var knowledge: [MissionKnowledgeItemViewState]
    var deliverableType: String
    var workspacePath: String
    var isNewcomer: Bool
    var canStart: Bool
    var startBlockReason: String?
}

struct RuminationReviewViewState: Sendable, Equatable {
    let ingestionId: String
    var title: String
    var summary: String
    var candidates: [EditableCandidateViewState]
    var missionDraft: MissionDraftViewState?
    let source: SourceViewState
    var uncertainties: [String]
    var isSaving: Bool
    var error: String?
    var hasChanges: Bool
    var canMaterialize: Bool
}

enum MaterializationMode: Sendable, Equatable { case notesOnly, notesAndMission }
struct MaterializationResult: Sendable, Equatable {
    let noteId: String
    let missionDraft: MissionDraftViewState?
}
enum IngestionDeletionScope: Sendable, Equatable { case resultOnly, sourceAndResult, everythingIncludingProjection }

struct ArtifactSummaryViewState: Sendable, Equatable, Identifiable {
    let id: String
    let label: String
    let path: String
    let exists: Bool
    let previewable: Bool
}

struct ValidationItemViewState: Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let completed: Bool
    let evidence: String?
}

struct ReturnSummaryViewState: Sendable, Equatable {
    let mission: MissionSummaryViewState
    let artifacts: [ArtifactSummaryViewState]
    let validationChecklist: [ValidationItemViewState]
    let hasViewedArtifact: Bool
    let usedKnowledge: [MissionKnowledgeItemViewState]
    let writtenBackNotes: [CampNoteSummaryViewState]
    let newcomerProgress: NewcomerProgressViewState
    let canAccept: Bool
    let blockReason: String?
}

struct CowRosterViewState: Sendable, Equatable {
    let loadState: CodingRanchLoadState
    let owned: [CowSummaryViewState]
    let locked: [LockedCowViewState]
    let newcomerProgress: NewcomerProgressViewState
    let canCreateCustomCow: Bool
}

@MainActor
protocol CodingRanchStoreProtocol: AnyObject {
    var dashboard: CampDashboardViewState? { get }
    var ruminationInbox: RuminationInboxViewState { get }

    func loadDashboard(campId: String) async
    func loadRuminationInbox(campId: String) async
    func submitFeed(_ draft: FeedDraft, startRumination: Bool) async throws -> FeedSubmissionResult
    func submitDuplicateAnyway(_ draft: FeedDraft, startRumination: Bool) async throws -> FeedSubmissionResult
    func saveFeedDraft(_ draft: FeedDraft)
    func startRumination(ingestionId: String) async
    func retryRumination(ingestionId: String) async
    func cancelRumination(ingestionId: String) async throws
    func loadRuminationReview(ingestionId: String) async throws -> RuminationReviewViewState
    func saveRuminationReview(_ review: RuminationReviewViewState) async throws
    func materializeRumination(_ review: RuminationReviewViewState, mode: MaterializationMode) async throws -> MaterializationResult
    func deleteIngestion(ingestionId: String, scope: IngestionDeletionScope) async throws
    func createMissionDraft(from ingestionId: String) async throws -> MissionDraftViewState
    func startMission(from draft: MissionDraftViewState) async throws -> String
    func loadReturnSummary(missionId: String) async throws -> ReturnSummaryViewState
    func unlockTestCow() async throws -> CowSummaryViewState
}
