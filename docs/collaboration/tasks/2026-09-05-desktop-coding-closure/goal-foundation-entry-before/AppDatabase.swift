import Foundation
import GRDB
import os

public struct CampLifecycleCommandUnavailableError:
    Error, Sendable, Equatable
{
    public init() {}
}

// P1-E-BEGIN V16IdentityMemorySQL
package let p1EIdentityMemoryMigrationSQL = """
CREATE TABLE camp_lifecycle (
  campId TEXT PRIMARY KEY NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  state TEXT NOT NULL CHECK (state IN
    ('active','archived','deletionRequested','deleting','deletedTombstone')),
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  deletionRequestedAt DATETIME,
  deletedAt DATETIME,
  CHECK (
    (state IN ('active','archived')
      AND deletionRequestedAt IS NULL AND deletedAt IS NULL)
    OR
    (state IN ('deletionRequested','deleting')
      AND deletionRequestedAt IS NOT NULL AND deletedAt IS NULL)
    OR
    (state = 'deletedTombstone'
      AND deletionRequestedAt IS NOT NULL AND deletedAt IS NOT NULL)
  )
);
CREATE INDEX camp_lifecycle_state
  ON camp_lifecycle(state, updatedAt);

INSERT INTO camp_lifecycle(
  campId, state, version, createdAt, updatedAt,
  deletionRequestedAt, deletedAt
)
SELECT id,
       CASE WHEN archived = 1 THEN 'archived' ELSE 'active' END,
       1, createdAt, createdAt, NULL, NULL
FROM camp;

-- user_request answerJson NULL no longer means "open": deletion withdrawal and
-- redaction both clear it, so v16 installs an explicit lifecycle discriminator.
ALTER TABLE user_request ADD COLUMN lifecycleState TEXT NOT NULL DEFAULT 'open'
  CHECK (lifecycleState IN ('open','answered','withdrawn','redacted'));
ALTER TABLE user_request ADD COLUMN terminalReason TEXT;
ALTER TABLE user_request ADD COLUMN redactedAt DATETIME;
UPDATE user_request
SET lifecycleState = CASE
  WHEN answerJson IS NULL THEN 'open' ELSE 'answered'
END;
ALTER TABLE approval_grant_use ADD COLUMN redactedAt DATETIME;

ALTER TABLE ingestion_item ADD COLUMN version INTEGER NOT NULL DEFAULT 1
  CHECK (version >= 1);
ALTER TABLE ingestion_item ADD COLUMN terminalReason TEXT
  CHECK (
    terminalReason IS NULL
    OR (status = 'discarded' AND terminalReason = 'camp_deleted')
  );
ALTER TABLE ingestion_item ADD COLUMN redactedAt DATETIME
  CHECK (
    redactedAt IS NULL
    OR
    (rawText = '[deleted]' AND title IS NULL AND sourceURL IS NULL
      AND author IS NULL AND userIntent IS NULL AND errorText IS NULL)
  );

ALTER TABLE rumination_result ADD COLUMN version INTEGER NOT NULL DEFAULT 1
  CHECK (version >= 1);
ALTER TABLE rumination_result ADD COLUMN redactedAt DATETIME
  CHECK (
    redactedAt IS NULL
    OR (resultJson = '{}' AND userEditedJson IS NULL)
  );

ALTER TABLE action_candidate ADD COLUMN version INTEGER NOT NULL DEFAULT 1
  CHECK (version >= 1);
ALTER TABLE action_candidate ADD COLUMN terminalReason TEXT
  CHECK (
    terminalReason IS NULL
    OR (status = 'dismissed' AND terminalReason = 'camp_deleted')
  );
ALTER TABLE action_candidate ADD COLUMN redactedAt DATETIME
  CHECK (
    redactedAt IS NULL
    OR (title = '[deleted]' AND detailJson = '{}')
  );

-- Locator bytes are private Camp data too.  A dedicated discriminator makes
-- their one-shot finalizing redaction and subsequent immutability expressible.
ALTER TABLE knowledge_source_link ADD COLUMN version INTEGER NOT NULL DEFAULT 1
  CHECK (version >= 1);
ALTER TABLE knowledge_source_link ADD COLUMN redactedAt DATETIME
  CHECK (redactedAt IS NULL OR locatorJson IS NULL);

-- campDeletion has been sealed since v12; F2 has not run yet.
CREATE TEMP TABLE v16_assert_no_early_camp_deletion (
  count INTEGER NOT NULL CHECK (count = 0)
);
INSERT INTO v16_assert_no_early_camp_deletion(count)
SELECT COUNT(*) FROM durable_work WHERE kind = 'campDeletion';
DROP TABLE v16_assert_no_early_camp_deletion;

-- Deterministically close every archived Camp's pre-v16 active work before
-- binding all rows to lifecycle version 1.
INSERT INTO durable_work_attempt_event(
  id, workId, attempt, sequence, eventKind, workerId, workVersion,
  resultingWorkState, errorCode, errorMessage, occurredAt
)
SELECT 'v16-archive-cancel:' || a.workId || ':' || a.attempt,
       a.workId, a.attempt,
       COALESCE((
         SELECT MAX(e.sequence) + 1
         FROM durable_work_attempt_event e
         WHERE e.workId = a.workId AND e.attempt = a.attempt
       ), 1),
       'canceled', a.workerId, w.version + 1, 'canceled',
       'work_canceled', 'camp_archived_backfill', CURRENT_TIMESTAMP
FROM durable_work_attempt a
JOIN durable_work w ON w.id = a.workId
JOIN camp c ON c.id = w.campId
WHERE c.archived = 1 AND w.state = 'running' AND a.endedAt IS NULL;

UPDATE durable_work_attempt
SET endedAt = CURRENT_TIMESTAMP,
    outcome = 'canceled',
    errorCode = 'work_canceled',
    errorMessage = 'camp_archived_backfill',
    terminalWorkVersion = (
      SELECT w.version + 1 FROM durable_work w
      WHERE w.id = durable_work_attempt.workId
    )
WHERE endedAt IS NULL
  AND workId IN (
    SELECT w.id FROM durable_work w
    JOIN camp c ON c.id = w.campId
    WHERE c.archived = 1 AND w.state = 'running'
  );

UPDATE durable_work
SET state = 'canceled',
    notBefore = NULL,
    leaseOwner = NULL,
    leaseExpiresAt = NULL,
    outputJson = NULL,
    errorCode = 'work_canceled',
    errorMessage = 'camp_archived_backfill',
    version = version + 1,
    updatedAt = CURRENT_TIMESTAMP,
    finishedAt = CURRENT_TIMESTAMP
WHERE campId IN (SELECT id FROM camp WHERE archived = 1)
  AND state IN ('queued','running','retryScheduled');

CREATE TABLE durable_work_v16 (
  id TEXT PRIMARY KEY NOT NULL,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  campLifecycleVersion INTEGER NOT NULL CHECK (campLifecycleVersion >= 1),
  kind TEXT NOT NULL CHECK (kind IN
    ('planning','rumination','coach','guideChat','memoryPromotion','inputParsing',
     'campDeletion')),
  aggregateType TEXT NOT NULL,
  aggregateId TEXT NOT NULL,
  idempotencyKey TEXT NOT NULL,
  state TEXT NOT NULL CHECK (state IN
    ('queued','running','retryScheduled','succeeded','failed','canceled')),
  attempt INTEGER NOT NULL DEFAULT 0 CHECK (attempt >= 0),
  maxAttempts INTEGER NOT NULL DEFAULT 4 CHECK (maxAttempts >= 1),
  notBefore DATETIME,
  leaseOwner TEXT,
  leaseExpiresAt DATETIME,
  inputJson TEXT NOT NULL,
  inputHash TEXT NOT NULL CHECK (
    length(inputHash) = 64 AND inputHash NOT GLOB '*[^0-9a-f]*'
  ),
  outputJson TEXT,
  errorCode TEXT,
  errorMessage TEXT CHECK (
    errorMessage IS NULL OR length(errorMessage) BETWEEN 1 AND 1000
  ),
  traceId TEXT NOT NULL,
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  finishedAt DATETIME,
  UNIQUE(kind, idempotencyKey),
  CHECK (
    (state = 'running' AND leaseOwner IS NOT NULL AND leaseExpiresAt IS NOT NULL)
    OR
    (state <> 'running' AND leaseOwner IS NULL AND leaseExpiresAt IS NULL)
  ),
  CHECK (
    (state = 'retryScheduled' AND notBefore IS NOT NULL)
    OR
    (state <> 'retryScheduled' AND notBefore IS NULL)
  ),
  CHECK (
    (state IN ('succeeded','failed','canceled') AND finishedAt IS NOT NULL)
    OR
    (state IN ('queued','running','retryScheduled') AND finishedAt IS NULL)
  ),
  CHECK (outputJson IS NULL OR state = 'succeeded'),
  CHECK (
    errorCode IS NULL OR (
      length(errorCode) BETWEEN 1 AND 64
      AND substr(errorCode, 1, 1) GLOB '[a-z]'
      AND errorCode NOT GLOB '*[^a-z0-9_]*'
    )
  ),
  CHECK (COALESCE((
    (state = 'queued' AND outputJson IS NULL
      AND ((errorCode IS NULL AND errorMessage IS NULL)
        OR (errorCode = 'worker_interrupted' AND errorMessage IS NULL)))
    OR
    (state IN ('running','succeeded')
      AND errorCode IS NULL AND errorMessage IS NULL)
    OR
    (state IN ('retryScheduled','failed') AND errorCode IS NOT NULL
      AND outputJson IS NULL)
    OR
    (state = 'canceled' AND errorCode = 'work_canceled'
      AND errorMessage IS NOT NULL AND outputJson IS NULL)
  ), 0))
);
INSERT INTO durable_work_v16(
  id, campId, campLifecycleVersion, kind, aggregateType, aggregateId,
  idempotencyKey, state, attempt, maxAttempts, notBefore, leaseOwner,
  leaseExpiresAt, inputJson, inputHash, outputJson, errorCode, errorMessage,
  traceId, version, createdAt, updatedAt, finishedAt
)
SELECT id, campId, 1, kind, aggregateType, aggregateId, idempotencyKey, state,
       attempt, maxAttempts, notBefore, leaseOwner, leaseExpiresAt, inputJson,
       inputHash, outputJson, errorCode, errorMessage, traceId, version,
       createdAt, updatedAt, finishedAt
FROM durable_work;

-- Child rows are staged without foreign keys.  The final-named child tables are
-- created only after the parent has its final name; this is deliberate and is
-- required to make the migration independent of legacy_alter_table behavior.
CREATE TEMP TABLE p1_durable_work_attempt_stage AS
SELECT workId, attempt, id, workerId, startedAt, endedAt, outcome, errorCode,
       errorMessage, traceId, terminalWorkVersion
FROM durable_work_attempt;

CREATE TEMP TABLE p1_durable_work_attempt_event_stage AS
SELECT id, workId, attempt, sequence, eventKind,
       NULL AS providerDispatchId, workerId, workVersion, resultingWorkState,
       errorCode, errorMessage, occurredAt, NULL AS redactedAt
FROM durable_work_attempt_event;

-- v12 guarantees this guard exists.  Drop it explicitly and fail fast before
-- rebuilding the owning table; the v12 DELETE guard is not explicitly dropped.
-- SQLite removes that DELETE trigger with the old table, and the final trigger
-- phase below recreates it under the same name before this transaction commits.
DROP TRIGGER durable_work_attempt_event_reject_update;
DROP TABLE durable_work_attempt_event;
DROP TABLE durable_work_attempt;
DROP TABLE durable_work;
ALTER TABLE durable_work_v16 RENAME TO durable_work;

CREATE TABLE durable_work_attempt (
  workId TEXT NOT NULL REFERENCES durable_work(id) ON DELETE RESTRICT,
  attempt INTEGER NOT NULL CHECK (attempt >= 1),
  id TEXT NOT NULL UNIQUE,
  workerId TEXT NOT NULL,
  startedAt DATETIME NOT NULL,
  endedAt DATETIME,
  outcome TEXT CHECK (outcome IS NULL OR outcome IN
    ('succeeded','failed','canceled','interrupted')),
  errorCode TEXT,
  errorMessage TEXT CHECK (
    errorMessage IS NULL OR length(errorMessage) BETWEEN 1 AND 1000
  ),
  traceId TEXT NOT NULL,
  terminalWorkVersion INTEGER CHECK
    (terminalWorkVersion IS NULL OR terminalWorkVersion >= 1),
  PRIMARY KEY(workId, attempt),
  CHECK (
    (endedAt IS NULL AND outcome IS NULL AND terminalWorkVersion IS NULL)
    OR
    (endedAt IS NOT NULL AND outcome IS NOT NULL AND terminalWorkVersion IS NOT NULL)
  ),
  CHECK (
    errorCode IS NULL OR (
      length(errorCode) BETWEEN 1 AND 64
      AND substr(errorCode, 1, 1) GLOB '[a-z]'
      AND errorCode NOT GLOB '*[^a-z0-9_]*'
    )
  ),
  CHECK (COALESCE((
    (endedAt IS NULL AND errorCode IS NULL AND errorMessage IS NULL)
    OR (outcome = 'succeeded' AND errorCode IS NULL AND errorMessage IS NULL)
    OR (outcome = 'failed' AND errorCode IS NOT NULL)
    OR (outcome = 'canceled' AND errorCode = 'work_canceled'
      AND errorMessage IS NOT NULL)
    OR (outcome = 'interrupted' AND errorCode = 'worker_interrupted'
      AND errorMessage IS NULL)
  ), 0))
);
INSERT INTO durable_work_attempt
SELECT * FROM p1_durable_work_attempt_stage;

CREATE TABLE camp_provider_dispatch (
  id TEXT PRIMARY KEY NOT NULL,
  workId TEXT NOT NULL,
  workAttempt INTEGER NOT NULL,
  turnOrdinal INTEGER NOT NULL CHECK (turnOrdinal >= 0),
  dispatchAttempt INTEGER NOT NULL CHECK (dispatchAttempt >= 1),
  replayOfDispatchId TEXT REFERENCES camp_provider_dispatch(id) ON DELETE RESTRICT,
  idempotencyKey TEXT NOT NULL UNIQUE,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  campLifecycleVersion INTEGER NOT NULL CHECK (campLifecycleVersion >= 1),
  operationKind TEXT NOT NULL CHECK
    (operationKind IN ('guideChat','memoryPromotion')),
  replayClass TEXT NOT NULL CHECK
    (replayClass IN ('replaySafeInference','idempotencyKeyed','nonReplayable')),
  state TEXT NOT NULL CHECK
    (state IN ('prepared','started','returned','consumed','abandoned')),
  requestJson TEXT NOT NULL,
  requestHash TEXT NOT NULL CHECK (
    length(requestHash) = 64 AND requestHash NOT GLOB '*[^0-9a-f]*'
  ),
  responseJson TEXT,
  responseHash TEXT CHECK (
    responseHash IS NULL OR
    (length(responseHash) = 64 AND responseHash NOT GLOB '*[^0-9a-f]*')
  ),
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  preparedAt DATETIME NOT NULL,
  startedAt DATETIME,
  returnedAt DATETIME,
  consumedAt DATETIME,
  abandonedAt DATETIME,
  redactedAt DATETIME,
  FOREIGN KEY(workId, workAttempt)
    REFERENCES durable_work_attempt(workId, attempt) ON DELETE RESTRICT,
  UNIQUE(workId, turnOrdinal, dispatchAttempt),
  CHECK (
    (dispatchAttempt = 1 AND replayOfDispatchId IS NULL)
    OR
    (dispatchAttempt > 1 AND replayOfDispatchId IS NOT NULL)
  ),
  CHECK (
    (state = 'prepared'
      AND startedAt IS NULL AND returnedAt IS NULL
      AND consumedAt IS NULL AND abandonedAt IS NULL
      AND responseJson IS NULL AND responseHash IS NULL)
    OR
    (state = 'started'
      AND startedAt IS NOT NULL AND returnedAt IS NULL
      AND consumedAt IS NULL AND abandonedAt IS NULL
      AND responseJson IS NULL AND responseHash IS NULL)
    OR
    (state = 'returned'
      AND startedAt IS NOT NULL AND returnedAt IS NOT NULL
      AND consumedAt IS NULL AND abandonedAt IS NULL
      AND responseJson IS NOT NULL AND responseHash IS NOT NULL)
    OR
    (state = 'consumed'
      AND startedAt IS NOT NULL AND returnedAt IS NOT NULL
      AND consumedAt IS NOT NULL AND abandonedAt IS NULL
      AND (
        (redactedAt IS NULL AND responseJson IS NOT NULL AND responseHash IS NOT NULL)
        OR
        (redactedAt IS NOT NULL AND responseJson IS NULL AND responseHash IS NULL)
      ))
    OR
    (state = 'abandoned'
      AND consumedAt IS NULL AND abandonedAt IS NOT NULL
      AND (returnedAt IS NULL OR startedAt IS NOT NULL)
      AND (
        (redactedAt IS NULL
          AND ((returnedAt IS NULL AND responseJson IS NULL AND responseHash IS NULL)
            OR (returnedAt IS NOT NULL
              AND responseJson IS NOT NULL AND responseHash IS NOT NULL)))
        OR
        (redactedAt IS NOT NULL AND responseJson IS NULL AND responseHash IS NULL)
      ))
  ),
  CHECK (
    redactedAt IS NULL
    OR
    (state IN ('consumed','abandoned')
      AND requestJson = '{}' AND responseJson IS NULL AND responseHash IS NULL)
  )
);
CREATE UNIQUE INDEX camp_provider_dispatch_one_returned
  ON camp_provider_dispatch(workId, turnOrdinal)
  WHERE state IN ('returned','consumed');
CREATE INDEX camp_provider_dispatch_quiescence
  ON camp_provider_dispatch(campId, state, preparedAt);
CREATE TABLE durable_work_attempt_event (
  id TEXT PRIMARY KEY NOT NULL,
  workId TEXT NOT NULL,
  attempt INTEGER NOT NULL,
  sequence INTEGER NOT NULL CHECK (sequence >= 0),
  eventKind TEXT NOT NULL CHECK (eventKind IN
    ('claimed','leaseRenewed','providerDispatchStarted',
     'providerResponseReturned','succeeded','failed','canceled','interrupted')),
  providerDispatchId TEXT
    REFERENCES camp_provider_dispatch(id) ON DELETE RESTRICT,
  workerId TEXT NOT NULL,
  workVersion INTEGER NOT NULL CHECK (workVersion >= 1),
  resultingWorkState TEXT NOT NULL CHECK (resultingWorkState IN
    ('running','retryScheduled','succeeded','failed','canceled','queued')),
  errorCode TEXT,
  errorMessage TEXT CHECK (
    errorMessage IS NULL OR length(errorMessage) BETWEEN 1 AND 1000
  ),
  occurredAt DATETIME NOT NULL,
  redactedAt DATETIME,
  FOREIGN KEY(workId, attempt)
    REFERENCES durable_work_attempt(workId, attempt) ON DELETE RESTRICT,
  UNIQUE(workId, attempt, sequence),
  UNIQUE(providerDispatchId, eventKind),
  CHECK ((sequence = 0) = (eventKind = 'claimed')),
  CHECK (
    (eventKind IN ('providerDispatchStarted','providerResponseReturned')
      AND providerDispatchId IS NOT NULL)
    OR
    (eventKind NOT IN ('providerDispatchStarted','providerResponseReturned')
      AND providerDispatchId IS NULL)
  ),
  CHECK (
    errorCode IS NULL OR (
      length(errorCode) BETWEEN 1 AND 64
      AND substr(errorCode, 1, 1) GLOB '[a-z]'
      AND errorCode NOT GLOB '*[^a-z0-9_]*'
    )
  ),
  CHECK (COALESCE((
    (eventKind IN ('claimed','leaseRenewed','providerDispatchStarted',
      'providerResponseReturned')
      AND resultingWorkState = 'running'
      AND errorCode IS NULL AND errorMessage IS NULL)
    OR
    (eventKind = 'succeeded' AND resultingWorkState = 'succeeded'
      AND errorCode IS NULL AND errorMessage IS NULL)
    OR
    (eventKind = 'failed'
      AND resultingWorkState IN ('retryScheduled','failed')
      AND errorCode IS NOT NULL)
    OR
    (eventKind = 'canceled' AND resultingWorkState = 'canceled'
      AND errorCode = 'work_canceled' AND errorMessage IS NOT NULL)
    OR
    (eventKind = 'interrupted' AND resultingWorkState = 'queued'
      AND errorCode = 'worker_interrupted' AND errorMessage IS NULL)
  ), 0)),
  CHECK (redactedAt IS NULL OR errorMessage IS NULL)
);
INSERT INTO durable_work_attempt_event(
  id, workId, attempt, sequence, eventKind, providerDispatchId, workerId,
  workVersion, resultingWorkState, errorCode, errorMessage, occurredAt, redactedAt
)
SELECT id, workId, attempt, sequence, eventKind, providerDispatchId, workerId,
       workVersion, resultingWorkState, errorCode, errorMessage, occurredAt,
       redactedAt
FROM p1_durable_work_attempt_event_stage;

DROP TABLE p1_durable_work_attempt_event_stage;
DROP TABLE p1_durable_work_attempt_stage;

CREATE UNIQUE INDEX durable_work_one_active_aggregate
  ON durable_work(kind, aggregateType, aggregateId)
  WHERE state IN ('queued','running','retryScheduled');
CREATE INDEX durable_work_claimable
  ON durable_work(campId, kind, state, notBefore, createdAt);
CREATE INDEX durable_work_aggregate_history
  ON durable_work(aggregateType, aggregateId, createdAt);
CREATE UNIQUE INDEX durable_work_attempt_one_terminal
  ON durable_work_attempt_event(workId, attempt)
  WHERE eventKind IN ('succeeded','failed','canceled','interrupted');
CREATE INDEX durable_work_attempt_event_work
  ON durable_work_attempt_event(workId, attempt, sequence);

CREATE TABLE camp_deletion_job (
  id TEXT PRIMARY KEY NOT NULL,
  campId TEXT NOT NULL UNIQUE REFERENCES camp(id) ON DELETE RESTRICT,
  workId TEXT NOT NULL UNIQUE REFERENCES durable_work(id) ON DELETE RESTRICT,
  requestIdempotencyKey TEXT NOT NULL UNIQUE,
  confirmationId TEXT NOT NULL UNIQUE,
  confirmationHash TEXT NOT NULL CHECK (
    length(confirmationHash) = 64
    AND confirmationHash NOT GLOB '*[^0-9a-f]*'
  ),
  unknownArtifactDisposition TEXT NOT NULL CHECK
    (unknownArtifactDisposition = 'detachOnlyNeverUnlink'),
  requestedByActorId TEXT NOT NULL,
  state TEXT NOT NULL CHECK
    (state IN ('requested','quiescing','erasing','finalizing','completed')),
  phaseCursorJson TEXT NOT NULL,
  lastErrorCode TEXT,
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  completedAt DATETIME,
  CHECK (
    (state = 'completed' AND completedAt IS NOT NULL)
    OR
    (state <> 'completed' AND completedAt IS NULL)
  )
);
CREATE INDEX camp_deletion_job_recovery
  ON camp_deletion_job(state, updatedAt);
CREATE TABLE camp_deletion_artifact (
  id TEXT PRIMARY KEY NOT NULL,
  jobId TEXT NOT NULL REFERENCES camp_deletion_job(id) ON DELETE RESTRICT,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  artifactId TEXT NOT NULL REFERENCES artifact(id) ON DELETE RESTRICT,
  originVersion INTEGER NOT NULL CHECK (originVersion >= 1),
  resolutionClass TEXT NOT NULL CHECK (resolutionClass IN
    ('unresolved','managedExclusive','managedShared','workspaceExternal')),
  evidenceKind TEXT CHECK (evidenceKind IS NULL OR evidenceKind IN
    ('typedPreparedArtifact','verifiedManagedRootCapability',
     'explicitWorkspaceExternal','verifiedOutsideAllManagedRoots',
     'legacyUnknown','userConfirmedUnknownDetach')),
  managedRootId TEXT,
  objectId TEXT,
  contentHash TEXT CHECK (
    contentHash IS NULL OR
    (length(contentHash) = 64 AND contentHash NOT GLOB '*[^0-9a-f]*')
  ),
  fileIdentityHash TEXT CHECK (
    fileIdentityHash IS NULL OR
    (length(fileIdentityHash) = 64
      AND fileIdentityHash NOT GLOB '*[^0-9a-f]*')
  ),
  originalRefHash TEXT NOT NULL CHECK (
    length(originalRefHash) = 64
    AND originalRefHash NOT GLOB '*[^0-9a-f]*'
  ),
  evidenceHash TEXT CHECK (
    evidenceHash IS NULL OR
    (length(evidenceHash) = 64 AND evidenceHash NOT GLOB '*[^0-9a-f]*')
  ),
  referenceSetHash TEXT CHECK (
    referenceSetHash IS NULL OR
    (length(referenceSetHash) = 64
      AND referenceSetHash NOT GLOB '*[^0-9a-f]*')
  ),
  authorityHash TEXT CHECK (
    authorityHash IS NULL OR
    (length(authorityHash) = 64 AND authorityHash NOT GLOB '*[^0-9a-f]*')
  ),
  state TEXT NOT NULL CHECK
    (state IN ('pendingInspection','awaitingResolution','detachAuthorized',
      'unlinkPrepared','retryableFailure','detached','retainedShared',
      'deleted','alreadyAbsent')),
  attempt INTEGER NOT NULL DEFAULT 0 CHECK (attempt >= 0),
  lastErrorCode TEXT,
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  finishedAt DATETIME,
  UNIQUE(jobId, artifactId),
  CHECK (
    (resolutionClass IN ('workspaceExternal','unresolved')
      AND managedRootId IS NULL AND objectId IS NULL
      AND contentHash IS NULL AND fileIdentityHash IS NULL)
    OR
    (resolutionClass IN ('managedExclusive','managedShared')
      AND contentHash IS NOT NULL AND fileIdentityHash IS NOT NULL)
  ),
  CHECK (
    (state IN ('unlinkPrepared','retryableFailure')
      AND resolutionClass = 'managedExclusive'
      AND managedRootId IS NOT NULL AND objectId IS NOT NULL
      AND authorityHash IS NOT NULL AND finishedAt IS NULL)
    OR
    (state = 'detachAuthorized'
      AND resolutionClass IN ('workspaceExternal','unresolved')
      AND authorityHash IS NOT NULL AND finishedAt IS NULL)
    OR
    (state = 'awaitingResolution'
      AND resolutionClass = 'unresolved'
      AND lastErrorCode IS NOT NULL AND finishedAt IS NULL)
    OR
    (state = 'pendingInspection' AND finishedAt IS NULL)
    OR
    (state IN ('detached','retainedShared','deleted','alreadyAbsent')
      AND finishedAt IS NOT NULL)
  ),
  CHECK (
    (state = 'detached'
      AND resolutionClass IN ('workspaceExternal','unresolved'))
    OR state <> 'detached'
  ),
  CHECK (
    (state = 'retainedShared' AND resolutionClass = 'managedShared')
    OR state <> 'retainedShared'
  ),
  CHECK (
    (state IN ('deleted','alreadyAbsent')
      AND resolutionClass = 'managedExclusive')
    OR state NOT IN ('deleted','alreadyAbsent')
  ),
  CHECK (
    state NOT IN ('detached','retainedShared','deleted','alreadyAbsent')
    OR (managedRootId IS NULL AND objectId IS NULL)
  )
);
CREATE INDEX camp_deletion_artifact_recovery
  ON camp_deletion_artifact(jobId, state, updatedAt);

CREATE TABLE legacy_chat_scope (
  threadId TEXT PRIMARY KEY NOT NULL
    REFERENCES chat_thread(id) ON DELETE RESTRICT,
  scopeKind TEXT NOT NULL CHECK (scopeKind IN ('globalCow','camp')),
  campId TEXT REFERENCES camp(id) ON DELETE RESTRICT,
  cowId TEXT NOT NULL REFERENCES companion(id) ON DELETE RESTRICT,
  evidenceKind TEXT NOT NULL CHECK
    (evidenceKind IN ('dmThread','guideThread')),
  createdAt DATETIME NOT NULL,
  CHECK (
    (scopeKind = 'globalCow' AND campId IS NULL)
    OR
    (scopeKind = 'camp' AND campId IS NOT NULL)
  )
);
CREATE INDEX legacy_chat_scope_camp
  ON legacy_chat_scope(scopeKind, campId, cowId);

CREATE TABLE legacy_companion_note_scope (
  noteId TEXT PRIMARY KEY NOT NULL
    REFERENCES companion_note(id) ON DELETE RESTRICT,
  scopeKind TEXT NOT NULL CHECK (scopeKind IN ('globalCow','camp')),
  campId TEXT REFERENCES camp(id) ON DELETE RESTRICT,
  cowId TEXT NOT NULL REFERENCES companion(id) ON DELETE RESTRICT,
  sourceThreadId TEXT REFERENCES chat_thread(id) ON DELETE RESTRICT,
  evidenceKind TEXT NOT NULL CHECK
    (evidenceKind IN ('dmThread','guideThread','coworkEvent','manualCow')),
  createdAt DATETIME NOT NULL,
  CHECK (
    (scopeKind = 'globalCow' AND campId IS NULL)
    OR
    (scopeKind = 'camp' AND campId IS NOT NULL)
  )
);
CREATE INDEX legacy_companion_note_scope_camp
  ON legacy_companion_note_scope(scopeKind, campId, cowId);

CREATE TABLE camp_event_scope (
  sourceTable TEXT NOT NULL CHECK (sourceTable IN ('event','domain_event')),
  eventId TEXT NOT NULL,
  scopeKind TEXT NOT NULL CHECK (scopeKind IN ('camp','global')),
  campId TEXT REFERENCES camp(id) ON DELETE RESTRICT,
  payloadRedactedAt DATETIME,
  PRIMARY KEY(sourceTable, eventId),
  CHECK (
    (scopeKind = 'camp' AND campId IS NOT NULL)
    OR
    (scopeKind = 'global' AND campId IS NULL)
  ),
  CHECK (sourceTable <> 'domain_event' OR scopeKind = 'camp')
);
CREATE INDEX camp_event_scope_camp
  ON camp_event_scope(scopeKind, campId, sourceTable, eventId);

INSERT INTO camp_event_scope(
  sourceTable, eventId, scopeKind, campId, payloadRedactedAt
)
SELECT 'domain_event', id, 'camp', campId, NULL FROM domain_event;

CREATE TABLE cow_identity (
  id TEXT PRIMARY KEY NOT NULL REFERENCES companion(id) ON DELETE RESTRICT,
  displayName TEXT NOT NULL,
  appearanceRef TEXT,
  personality TEXT NOT NULL,
  baseRole TEXT NOT NULL,
  defaultEnginePolicyJson TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('active','retired')),
  aggregateVersion INTEGER NOT NULL DEFAULT 1 CHECK (aggregateVersion >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL
);

CREATE TABLE camp_residency (
  id TEXT PRIMARY KEY NOT NULL,
  cowId TEXT NOT NULL REFERENCES cow_identity(id) ON DELETE RESTRICT,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  role TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN
    ('requested','authorized','active','paused','left','revoked')),
  idempotencyKey TEXT NOT NULL UNIQUE,
  joinedAt DATETIME,
  pausedAt DATETIME,
  leftAt DATETIME,
  revokedAt DATETIME,
  aggregateVersion INTEGER NOT NULL DEFAULT 1 CHECK (aggregateVersion >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  CHECK ((status = 'paused') = (pausedAt IS NOT NULL)),
  CHECK ((status = 'left') = (leftAt IS NOT NULL)),
  CHECK ((status = 'revoked') = (revokedAt IS NOT NULL))
);
CREATE UNIQUE INDEX camp_residency_one_live
  ON camp_residency(cowId, campId)
  WHERE status IN ('requested','authorized','active','paused');
CREATE INDEX camp_residency_camp_status
  ON camp_residency(campId, status, cowId);

CREATE TABLE camp_bridge (
  id TEXT PRIMARY KEY NOT NULL,
  sourceCampId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  targetCampId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  mode TEXT NOT NULL CHECK (mode IN ('reference','copy','searchGrant')),
  contentScopeJson TEXT NOT NULL,
  grantedByActorId TEXT NOT NULL,
  validUntil DATETIME,
  status TEXT NOT NULL CHECK (status IN ('active','revoked')),
  revokedAt DATETIME,
  aggregateVersion INTEGER NOT NULL DEFAULT 1 CHECK (aggregateVersion >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  CHECK (sourceCampId <> targetCampId),
  CHECK (
    (status = 'revoked' AND revokedAt IS NOT NULL)
    OR
    (status = 'active' AND revokedAt IS NULL)
  )
);
CREATE INDEX camp_bridge_lookup
  ON camp_bridge(sourceCampId, targetCampId, status, validUntil);

CREATE TABLE memory_record_version (
  id TEXT NOT NULL,
  version INTEGER NOT NULL CHECK (version >= 1),
  layer TEXT NOT NULL CHECK (layer IN
    ('rawSource','working','campKnowledge','globalPreference','globalSkill')),
  ownerType TEXT NOT NULL CHECK (ownerType IN ('user','goal','camp','cow')),
  ownerId TEXT NOT NULL,
  campId TEXT REFERENCES camp(id) ON DELETE RESTRICT,
  title TEXT NOT NULL,
  bodyText TEXT,
  contentRef TEXT,
  contentHash TEXT NOT NULL CHECK (length(contentHash) = 64),
  status TEXT NOT NULL CHECK (status IN
    ('proposed','active','needsReview','invalidated','deletedTombstone')),
  sourceType TEXT NOT NULL CHECK
    (sourceType IN ('userConfirmed','independentSource','outcomeExperience','inference')),
  applicabilityJson TEXT NOT NULL,
  createdByActorId TEXT NOT NULL,
  confirmedByActorId TEXT,
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  PRIMARY KEY(id, version),
  UNIQUE(id, version, contentHash),
  CHECK (
    (status = 'deletedTombstone' AND bodyText IS NULL AND contentRef IS NULL)
    OR
    (status <> 'deletedTombstone'
      AND ((bodyText IS NOT NULL) <> (contentRef IS NOT NULL)))
  ),
  CHECK (
    (layer IN ('rawSource','working'))
    OR
    (sourceType = 'inference')
    OR
    (confirmedByActorId IS NOT NULL)
  )
);
CREATE INDEX memory_record_owner
  ON memory_record_version(ownerType, ownerId, status, version);
CREATE INDEX memory_record_camp
  ON memory_record_version(campId, layer, status);

CREATE TABLE memory_dependency (
  id TEXT PRIMARY KEY NOT NULL,
  memoryId TEXT NOT NULL,
  memoryVersion INTEGER NOT NULL,
  dependencyType TEXT NOT NULL CHECK (dependencyType IN
    ('input','outcome','verification','acceptance','memory')),
  dependencyId TEXT NOT NULL,
  dependencyVersion INTEGER,
  dependencyHash TEXT NOT NULL CHECK (length(dependencyHash) = 64),
  createdAt DATETIME NOT NULL,
  FOREIGN KEY(memoryId, memoryVersion)
    REFERENCES memory_record_version(id, version) ON DELETE RESTRICT,
  UNIQUE(
    memoryId, memoryVersion, dependencyType,
    dependencyId, dependencyVersion, dependencyHash)
);
CREATE INDEX memory_dependency_source
  ON memory_dependency(
    dependencyType, dependencyId, dependencyVersion, dependencyHash);

-- MIGRATION PHASE BARRIER: the real Swift migrator runs all v16 copy/backfill
-- resolvers and count/FK assertions here.  Only after that callback succeeds may
-- it execute the four ordered surviving-table UPDATE-guard drops below.
-- These v15/legacy guards deliberately remain installed through all data work.
-- No IF EXISTS is allowed: a missing predecessor guard is schema corruption.
DROP TRIGGER event_no_update;
DROP TRIGGER verification_record_reject_update;
DROP TRIGGER acceptance_record_reject_update;
DROP TRIGGER external_operation_receipt_reject_update;

-- No DML, resolver, copy/backfill, or assertion may follow the four drops.
-- Every v16 CREATE TRIGGER, including same-table guards, starts only here, after
-- the complete graph, durable-work rename, successful barrier, and all five
-- v16 DROP TRIGGER statements (the owning-table drop occurred before rebuild).
CREATE TRIGGER memory_dependency_reject_update
BEFORE UPDATE ON memory_dependency
BEGIN
  SELECT RAISE(ABORT, 'memory_dependency is append-only');
END;
CREATE TRIGGER memory_dependency_reject_delete
BEFORE DELETE ON memory_dependency
BEGIN
  SELECT RAISE(ABORT, 'memory_dependency is append-only');
END;

CREATE TRIGGER camp_provider_dispatch_validate_replay
BEFORE INSERT ON camp_provider_dispatch
WHEN NEW.dispatchAttempt > 1 AND NOT EXISTS (
  SELECT 1 FROM camp_provider_dispatch p
  WHERE p.id = NEW.replayOfDispatchId
    AND p.workId = NEW.workId
    AND p.turnOrdinal = NEW.turnOrdinal
    AND p.dispatchAttempt = NEW.dispatchAttempt - 1
    AND p.state = 'abandoned'
)
BEGIN
  SELECT RAISE(ABORT, 'provider replay must follow exact abandoned attempt');
END;
CREATE TRIGGER camp_deletion_job_validate_work_insert
BEFORE INSERT ON camp_deletion_job
WHEN NOT EXISTS (
  SELECT 1 FROM durable_work w
  WHERE w.id = NEW.workId AND w.campId = NEW.campId
    AND w.kind = 'campDeletion'
    AND w.aggregateType = 'camp' AND w.aggregateId = NEW.campId
)
BEGIN
  SELECT RAISE(ABORT, 'deletion job work binding mismatch');
END;
CREATE TRIGGER camp_deletion_job_validate_work_update
BEFORE UPDATE OF workId, campId ON camp_deletion_job
WHEN NOT EXISTS (
  SELECT 1 FROM durable_work w
  WHERE w.id = NEW.workId AND w.campId = NEW.campId
    AND w.kind = 'campDeletion'
    AND w.aggregateType = 'camp' AND w.aggregateId = NEW.campId
)
BEGIN
  SELECT RAISE(ABORT, 'deletion job replacement work binding mismatch');
END;

CREATE TRIGGER camp_provider_dispatch_first_redaction_exact
BEFORE UPDATE ON camp_provider_dispatch
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.id = OLD.id
  AND NEW.workId = OLD.workId
  AND NEW.workAttempt = OLD.workAttempt
  AND NEW.turnOrdinal = OLD.turnOrdinal
  AND NEW.dispatchAttempt = OLD.dispatchAttempt
  AND NEW.replayOfDispatchId IS OLD.replayOfDispatchId
  AND NEW.idempotencyKey = OLD.idempotencyKey
  AND NEW.campId = OLD.campId
  AND NEW.campLifecycleVersion = OLD.campLifecycleVersion
  AND NEW.operationKind = OLD.operationKind
  AND NEW.replayClass = OLD.replayClass
  AND NEW.state = OLD.state
  AND NEW.requestJson = '{}'
  AND NEW.requestHash = OLD.requestHash
  AND NEW.responseJson IS NULL AND NEW.responseHash IS NULL
  AND NEW.version = OLD.version + 1
  AND NEW.preparedAt = OLD.preparedAt
  AND NEW.startedAt IS OLD.startedAt
  AND NEW.returnedAt IS OLD.returnedAt
  AND NEW.consumedAt IS OLD.consumedAt
  AND NEW.abandonedAt IS OLD.abandonedAt
  AND EXISTS (
    SELECT 1 FROM camp_lifecycle l
    JOIN camp_deletion_job j ON j.campId = l.campId
    WHERE l.campId = OLD.campId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN
  SELECT RAISE(ABORT, 'provider redaction diff is invalid');
END;
CREATE TRIGGER camp_provider_dispatch_reject_private_update
BEFORE UPDATE ON camp_provider_dispatch
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NULL
  AND NEW.requestJson IS NOT OLD.requestJson
BEGIN
  SELECT RAISE(ABORT, 'provider request is immutable');
END;
CREATE TRIGGER camp_provider_dispatch_post_redaction_lock
BEFORE UPDATE ON camp_provider_dispatch
WHEN OLD.redactedAt IS NOT NULL
BEGIN
  SELECT RAISE(ABORT, 'provider row is immutable after redaction');
END;
CREATE TRIGGER camp_provider_dispatch_reject_delete
BEFORE DELETE ON camp_provider_dispatch
BEGIN
  SELECT RAISE(ABORT, 'provider row may not be deleted');
END;

CREATE TRIGGER user_request_validate_state_insert
BEFORE INSERT ON user_request
WHEN NOT (
  (NEW.lifecycleState = 'open'
    AND NEW.answerJson IS NULL AND NEW.answeredAt IS NULL
    AND NEW.terminalReason IS NULL AND NEW.redactedAt IS NULL)
  OR
  (NEW.lifecycleState = 'answered'
    AND NEW.answerJson IS NOT NULL AND NEW.answeredAt IS NOT NULL
    AND NEW.terminalReason IS NULL AND NEW.redactedAt IS NULL)
)
BEGIN
  SELECT RAISE(ABORT, 'invalid user request lifecycle');
END;
CREATE TRIGGER user_request_validate_update_and_redaction
BEFORE UPDATE ON user_request
WHEN NOT (
  (OLD.lifecycleState = 'open' AND NEW.lifecycleState = 'answered'
    AND NEW.id = OLD.id AND NEW.cardId = OLD.cardId AND NEW.kind = OLD.kind
    AND NEW.prompt = OLD.prompt AND NEW.optionsJson IS OLD.optionsJson
    AND NEW.answerJson IS NOT NULL AND NEW.answeredAt IS NOT NULL
    AND NEW.createdAt = OLD.createdAt
    AND NEW.terminalReason IS NULL AND NEW.redactedAt IS NULL
    AND EXISTS (
      SELECT 1 FROM card c
      JOIN mission m ON m.id = c.missionId
      JOIN squad s ON s.id = m.squadId
      JOIN camp_lifecycle l ON l.campId = s.campId
      JOIN camp p ON p.id = s.campId
      WHERE c.id = OLD.cardId
        AND l.state = 'active' AND p.archived = 0
    ))
  OR
  (OLD.lifecycleState = 'open' AND NEW.lifecycleState = 'withdrawn'
    AND NEW.id = OLD.id AND NEW.cardId = OLD.cardId AND NEW.kind = OLD.kind
    AND NEW.prompt = OLD.prompt AND NEW.optionsJson IS OLD.optionsJson
    AND NEW.answerJson IS NULL AND NEW.answeredAt IS NULL
    AND NEW.createdAt = OLD.createdAt
    AND NEW.terminalReason = 'camp_deleted' AND NEW.redactedAt IS NULL
    AND EXISTS (
      SELECT 1 FROM card c
      JOIN mission m ON m.id = c.missionId
      JOIN squad s ON s.id = m.squadId
      JOIN camp_lifecycle l ON l.campId = s.campId
      JOIN camp_deletion_job j ON j.campId = s.campId
      WHERE c.id = OLD.cardId
        AND l.state = 'deletionRequested' AND j.state = 'quiescing'
    ))
  OR
  (OLD.redactedAt IS NULL
    AND OLD.lifecycleState IN ('answered','withdrawn')
    AND NEW.lifecycleState = 'redacted'
    AND NEW.id = OLD.id AND NEW.cardId = OLD.cardId AND NEW.kind = OLD.kind
    AND NEW.prompt = '[deleted]' AND NEW.optionsJson IS NULL
    AND NEW.answerJson IS NULL AND NEW.answeredAt IS NULL
    AND NEW.createdAt = OLD.createdAt
    AND NEW.terminalReason = 'camp_deleted' AND NEW.redactedAt IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM card c
      JOIN mission m ON m.id = c.missionId
      JOIN squad s ON s.id = m.squadId
      JOIN camp_lifecycle l ON l.campId = s.campId
      JOIN camp_deletion_job j ON j.campId = s.campId
      WHERE c.id = OLD.cardId
        AND l.state = 'deleting' AND j.state = 'finalizing'
    ))
)
BEGIN
  SELECT RAISE(ABORT, 'invalid user request update');
END;
CREATE TRIGGER user_request_post_redaction_lock
BEFORE UPDATE ON user_request
WHEN OLD.redactedAt IS NOT NULL
BEGIN
  SELECT RAISE(ABORT, 'user request is immutable after redaction');
END;
CREATE TRIGGER user_request_reject_delete
BEFORE DELETE ON user_request
BEGIN
  SELECT RAISE(ABORT, 'user request may not be deleted');
END;

CREATE TRIGGER ingestion_item_validate_deletion_terminal
BEFORE UPDATE ON ingestion_item
WHEN NEW.terminalReason IS NOT OLD.terminalReason
AND NOT (
  OLD.terminalReason IS NULL
  AND OLD.redactedAt IS NULL AND NEW.redactedAt IS NULL
  AND OLD.status IN ('queued','ruminating','needsReview')
  AND NEW.id = OLD.id AND NEW.campId = OLD.campId
  AND NEW.sourceType = OLD.sourceType
  AND NEW.title IS OLD.title AND NEW.rawText = OLD.rawText
  AND NEW.sourceURL IS OLD.sourceURL AND NEW.author IS OLD.author
  AND NEW.userIntent IS OLD.userIntent
  AND NEW.contentHash = OLD.contentHash
  AND NEW.status = 'discarded'
  AND NEW.attempt = OLD.attempt AND NEW.errorText IS OLD.errorText
  AND NEW.createdAt = OLD.createdAt AND NEW.updatedAt = OLD.updatedAt
  AND NEW.version = OLD.version + 1
  AND NEW.terminalReason = 'camp_deleted'
  AND EXISTS (
    SELECT 1 FROM camp_lifecycle l
    JOIN camp_deletion_job j ON j.campId = l.campId
    WHERE l.campId = OLD.campId
      AND l.state = 'deletionRequested' AND j.state = 'quiescing'
  )
)
BEGIN SELECT RAISE(ABORT, 'ingestion deletion terminal diff is invalid'); END;
CREATE TRIGGER ingestion_item_deletion_terminal_lock
BEFORE UPDATE ON ingestion_item
WHEN OLD.terminalReason = 'camp_deleted'
  AND OLD.redactedAt IS NULL AND NEW.redactedAt IS NULL
BEGIN SELECT RAISE(ABORT, 'deletion-terminal ingestion is immutable'); END;
CREATE TRIGGER ingestion_item_first_redaction_exact
BEFORE UPDATE ON ingestion_item
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  OLD.status IN ('materialized','failed','discarded')
  AND NEW.id = OLD.id AND NEW.campId = OLD.campId
  AND NEW.sourceType = OLD.sourceType
  AND NEW.title IS NULL AND NEW.rawText = '[deleted]'
  AND NEW.sourceURL IS NULL AND NEW.author IS NULL
  AND NEW.userIntent IS NULL
  AND NEW.contentHash = OLD.contentHash
  AND NEW.status = OLD.status
  AND NEW.attempt = OLD.attempt AND NEW.errorText IS NULL
  AND NEW.createdAt = OLD.createdAt AND NEW.updatedAt = OLD.updatedAt
  AND NEW.version = OLD.version + 1
  AND NEW.terminalReason IS OLD.terminalReason
  AND EXISTS (
    SELECT 1 FROM camp_lifecycle l
    JOIN camp_deletion_job j ON j.campId = l.campId
    WHERE l.campId = OLD.campId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN SELECT RAISE(ABORT, 'ingestion redaction diff is invalid'); END;
CREATE TRIGGER ingestion_item_post_redaction_lock
BEFORE UPDATE ON ingestion_item WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'ingestion is immutable after redaction'); END;
CREATE TRIGGER ingestion_item_reject_delete
BEFORE DELETE ON ingestion_item
WHEN NOT EXISTS (
  SELECT 1
  FROM camp_lifecycle l
  JOIN camp c ON c.id = l.campId
  JOIN domain_event e
    ON e.campId = l.campId
   AND e.aggregateType = 'ingestion'
   AND e.aggregateId = OLD.id
   AND e.aggregateVersion = OLD.version + 1
   AND e.eventType = 'active_ingestion_deleted_v1'
   AND e.payloadVersion = 1
   AND e.eventOrdinal = 0
   AND e.eventIdempotencyKey =
     e.commandIdempotencyKey || '#0000:ingestion:' || OLD.id
  JOIN domain_command_receipt r
    ON r.idempotencyKey = e.commandIdempotencyKey
  JOIN event_outbox o
    ON o.eventId = e.id
  JOIN camp_event_scope s
    ON s.sourceTable = 'domain_event' AND s.eventId = e.id
   AND s.scopeKind = 'camp' AND s.campId = OLD.campId
  WHERE l.campId = OLD.campId
    AND l.state = 'active' AND c.archived = 0
    AND OLD.status IN ('queued','failed','needsReview','discarded')
    AND OLD.terminalReason IS NULL AND OLD.redactedAt IS NULL
    AND r.commandType = 'activeIngestionDeletion.v1'
    AND r.eventCount = 1
    AND (
      SELECT COUNT(*) FROM domain_event one_event
      WHERE one_event.commandIdempotencyKey = r.idempotencyKey
    ) = 1
    AND length(r.commandPayloadHash) = 64
    AND r.commandPayloadHash NOT GLOB '*[^0-9a-f]*'
    AND length(r.resultHash) = 64
    AND r.resultHash NOT GLOB '*[^0-9a-f]*'
    AND length(e.payloadHash) = 64
    AND e.payloadHash NOT GLOB '*[^0-9a-f]*'
    AND json_valid(r.resultJson) AND json_valid(e.payloadJson)
    AND (SELECT COUNT(*) FROM json_each(r.resultJson)) = 23
    AND (SELECT COUNT(*) FROM json_each(e.payloadJson)) = 21
    AND json_type(r.resultJson, '$.actorRef') IS NULL
    AND json_type(r.resultJson, '$.actorId') IS NULL
    AND json_type(r.resultJson, '$.actorType') IS NULL
    AND json_type(r.resultJson, '$.deviceId') IS NULL
    AND json_type(r.resultJson, '$.accountId') IS NULL
    AND json_type(r.resultJson, '$.accountIdentifier') IS NULL
    AND json_type(e.payloadJson, '$.actorRef') IS NULL
    AND json_type(e.payloadJson, '$.actorId') IS NULL
    AND json_type(e.payloadJson, '$.actorType') IS NULL
    AND json_type(e.payloadJson, '$.deviceId') IS NULL
    AND json_type(e.payloadJson, '$.accountId') IS NULL
    AND json_type(e.payloadJson, '$.accountIdentifier') IS NULL
    AND e.actorType = 'user'
    AND length(e.actorId) > 0
    AND e.deviceId IS NOT NULL AND length(e.deviceId) > 0
    AND length(e.correlationId) > 0
    AND (e.causationId IS NULL OR length(e.causationId) > 0)
    AND length(e.occurredAt) > 0 AND length(e.recordedAt) > 0
    AND e.recordedAt >= e.occurredAt
    AND o.state = 'pending' AND o.attempt = 0
    AND o.notBefore IS NULL AND o.leaseOwner IS NULL
    AND o.leaseExpiresAt IS NULL AND o.lastError IS NULL
    AND o.version = 1 AND o.createdAt = e.recordedAt
    AND o.updatedAt = e.recordedAt AND o.sentAt IS NULL
    AND (
      SELECT COUNT(*) FROM event_outbox one_outbox
      WHERE one_outbox.eventId = e.id
    ) = 1
    AND json_extract(r.resultJson, '$.commandIdempotencyKey')
      = e.commandIdempotencyKey
    AND json_extract(r.resultJson, '$.eventId') = e.id
    AND json_extract(r.resultJson, '$.eventPayloadHash') = e.payloadHash
    AND json_extract(r.resultJson, '$.campId') = OLD.campId
    AND json_extract(r.resultJson, '$.expectedLifecycleVersion') = l.version
    AND json_extract(r.resultJson, '$.ingestionId') = OLD.id
    AND json_extract(r.resultJson, '$.oldIngestionVersion') = OLD.version
    AND json_extract(r.resultJson, '$.oldIngestionStatus') = OLD.status
    AND json_extract(r.resultJson, '$.ingestionContentHash') = OLD.contentHash
    AND length(json_extract(r.resultJson, '$.ingestionSnapshotHash')) = 64
    AND json_extract(r.resultJson, '$.ingestionSnapshotHash')
      NOT GLOB '*[^0-9a-f]*'
    AND json_extract(r.resultJson, '$.scope') = 'sourceAndResult'
    AND json_extract(r.resultJson, '$.deletedIngestionCount') = 1
    AND json_extract(r.resultJson, '$.updatedIngestionCount') = 0
    AND json_extract(r.resultJson, '$.knowledgeSourceLinkCount') = 0
    AND json_extract(r.resultJson, '$.actionCandidateCount') = 0
    AND json_extract(r.resultJson, '$.nonterminalRuminationWorkCount') = 0
    AND json_extract(r.resultJson, '$.openRuminationAttemptCount') = 0
    AND json_extract(r.resultJson, '$.nonterminalProviderDispatchCount') = 0
    AND json_extract(e.payloadJson, '$.campId') = OLD.campId
    AND json_extract(e.payloadJson, '$.commandIdempotencyKey')
      = e.commandIdempotencyKey
    AND json_extract(e.payloadJson, '$.expectedLifecycleVersion') = l.version
    AND json_extract(e.payloadJson, '$.commandPayloadHash')
      = r.commandPayloadHash
    AND json_extract(e.payloadJson, '$.ingestionId') = OLD.id
    AND json_extract(e.payloadJson, '$.oldIngestionVersion') = OLD.version
    AND json_extract(e.payloadJson, '$.oldIngestionStatus') = OLD.status
    AND json_extract(e.payloadJson, '$.ingestionContentHash') = OLD.contentHash
    AND length(json_extract(e.payloadJson, '$.ingestionSnapshotHash')) = 64
    AND json_extract(e.payloadJson, '$.ingestionSnapshotHash')
      NOT GLOB '*[^0-9a-f]*'
    AND json_extract(r.resultJson, '$.ingestionSnapshotHash')
      = json_extract(e.payloadJson, '$.ingestionSnapshotHash')
    AND json_extract(e.payloadJson, '$.scope') = 'sourceAndResult'
    AND json_extract(e.payloadJson, '$.deletedIngestionCount') = 1
    AND json_extract(e.payloadJson, '$.updatedIngestionCount') = 0
    AND json_extract(e.payloadJson, '$.deletedResultCount') IN (0, 1)
    AND json_extract(e.payloadJson, '$.knowledgeSourceLinkCount') = 0
    AND json_extract(e.payloadJson, '$.actionCandidateCount') = 0
    AND json_extract(e.payloadJson, '$.nonterminalRuminationWorkCount') = 0
    AND json_extract(e.payloadJson, '$.openRuminationAttemptCount') = 0
    AND json_extract(e.payloadJson, '$.nonterminalProviderDispatchCount') = 0
    AND json_extract(r.resultJson, '$.commandPayloadHash')
      = json_extract(e.payloadJson, '$.commandPayloadHash')
    AND json_extract(r.resultJson, '$.scope')
      = json_extract(e.payloadJson, '$.scope')
    AND json_extract(r.resultJson, '$.deletedResultCount')
      = json_extract(e.payloadJson, '$.deletedResultCount')
    AND (
      (json_extract(e.payloadJson, '$.deletedResultCount') = 0
        AND json_type(e.payloadJson, '$.resultId') = 'null'
        AND json_type(e.payloadJson, '$.resultVersion') = 'null'
        AND json_type(e.payloadJson, '$.resultHash') = 'null'
        AND json_type(r.resultJson, '$.resultId') = 'null'
        AND json_type(r.resultJson, '$.resultVersion') = 'null'
        AND json_type(r.resultJson, '$.resultHash') = 'null')
      OR
      (json_extract(e.payloadJson, '$.deletedResultCount') = 1
        AND json_type(e.payloadJson, '$.resultId') = 'text'
        AND json_type(e.payloadJson, '$.resultVersion') = 'integer'
        AND json_extract(e.payloadJson, '$.resultVersion') >= 1
        AND length(json_extract(e.payloadJson, '$.resultHash')) = 64
        AND json_extract(e.payloadJson, '$.resultHash')
          NOT GLOB '*[^0-9a-f]*'
        AND json_extract(r.resultJson, '$.resultId')
          = json_extract(e.payloadJson, '$.resultId')
        AND json_extract(r.resultJson, '$.resultVersion')
          = json_extract(e.payloadJson, '$.resultVersion')
        AND json_extract(r.resultJson, '$.resultHash')
          = json_extract(e.payloadJson, '$.resultHash'))
    )
    AND NOT EXISTS (
      SELECT 1 FROM rumination_result rr WHERE rr.ingestionId = OLD.id
    )
    AND NOT EXISTS (
      SELECT 1 FROM knowledge_source_link k WHERE k.ingestionId = OLD.id
    )
    AND NOT EXISTS (
      SELECT 1 FROM action_candidate a WHERE a.ingestionId = OLD.id
    )
    AND NOT EXISTS (
      SELECT 1 FROM durable_work w
      WHERE w.campId = OLD.campId AND w.kind = 'rumination'
        AND w.aggregateType = 'ingestion' AND w.aggregateId = OLD.id
        AND w.state IN ('queued','running','retryScheduled')
    )
    AND NOT EXISTS (
      SELECT 1 FROM durable_work_attempt a
      JOIN durable_work w ON w.id = a.workId
      WHERE w.campId = OLD.campId AND w.kind = 'rumination'
        AND w.aggregateType = 'ingestion' AND w.aggregateId = OLD.id
        AND a.endedAt IS NULL
    )
    AND NOT EXISTS (
      SELECT 1 FROM camp_provider_dispatch p
      JOIN durable_work w ON w.id = p.workId
      WHERE w.campId = OLD.campId AND w.kind = 'rumination'
        AND w.aggregateType = 'ingestion' AND w.aggregateId = OLD.id
        AND p.state IN ('prepared','started','returned')
    )
    AND agentloop_active_ingestion_deletion_permit_v1(
      'deleteIngestion',
      e.commandIdempotencyKey, r.commandPayloadHash, e.id, e.payloadHash,
      e.actorType, e.actorId, e.deviceId, e.correlationId, e.causationId,
      e.occurredAt, e.recordedAt, OLD.campId, l.version,
      json_extract(e.payloadJson, '$.scope'),
      json_extract(e.payloadJson, '$.ingestionSnapshotHash'),
      json_extract(e.payloadJson, '$.resultHash'),
      json_extract(e.payloadJson, '$.deletedResultCount'),
      json_extract(e.payloadJson, '$.deletedIngestionCount'),
      json_extract(e.payloadJson, '$.updatedIngestionCount'),
      json_extract(e.payloadJson, '$.knowledgeSourceLinkCount'),
      json_extract(e.payloadJson, '$.actionCandidateCount'),
      json_extract(e.payloadJson, '$.nonterminalRuminationWorkCount'),
      json_extract(e.payloadJson, '$.openRuminationAttemptCount'),
      json_extract(e.payloadJson, '$.nonterminalProviderDispatchCount'),
      o.eventId, o.state, o.attempt, o.notBefore, o.leaseOwner,
      o.leaseExpiresAt, o.lastError, o.version, o.createdAt, o.updatedAt,
      o.sentAt,
      OLD.id, OLD.campId, OLD.sourceType, OLD.title, OLD.rawText,
      OLD.sourceURL, OLD.author, OLD.userIntent, OLD.contentHash, OLD.status,
      OLD.attempt, OLD.errorText, OLD.createdAt, OLD.updatedAt, OLD.version,
      OLD.terminalReason, OLD.redactedAt
    ) = 1
)
BEGIN
  SELECT RAISE(ABORT, 'ingestion delete requires exact transaction permit');
END;

CREATE TRIGGER rumination_result_first_redaction_exact
BEFORE UPDATE ON rumination_result
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.id = OLD.id AND NEW.ingestionId = OLD.ingestionId
  AND NEW.pipelineVersion = OLD.pipelineVersion
  AND NEW.resultJson = '{}' AND NEW.userEditedJson IS NULL
  AND NEW.materializedAt IS OLD.materializedAt
  AND NEW.createdAt = OLD.createdAt AND NEW.updatedAt = OLD.updatedAt
  AND NEW.version = OLD.version + 1
  AND EXISTS (
    SELECT 1 FROM ingestion_item i
    JOIN camp_lifecycle l ON l.campId = i.campId
    JOIN camp_deletion_job j ON j.campId = i.campId
    WHERE i.id = OLD.ingestionId
      AND i.status IN ('materialized','failed','discarded')
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN SELECT RAISE(ABORT, 'rumination result redaction diff is invalid'); END;
CREATE TRIGGER rumination_result_post_redaction_lock
BEFORE UPDATE ON rumination_result WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'rumination result is immutable after redaction'); END;
CREATE TRIGGER rumination_result_reject_delete
BEFORE DELETE ON rumination_result
WHEN NOT EXISTS (
  SELECT 1
  FROM ingestion_item i
  JOIN camp_lifecycle l ON l.campId = i.campId
  JOIN camp c ON c.id = i.campId
  JOIN domain_event e
    ON e.campId = i.campId
   AND e.aggregateType = 'ingestion'
   AND e.aggregateId = i.id
   AND e.aggregateVersion = i.version + 1
   AND e.eventType = 'active_ingestion_deleted_v1'
   AND e.payloadVersion = 1
   AND e.eventOrdinal = 0
   AND e.eventIdempotencyKey =
     e.commandIdempotencyKey || '#0000:ingestion:' || i.id
  JOIN domain_command_receipt r
    ON r.idempotencyKey = e.commandIdempotencyKey
  JOIN event_outbox o
    ON o.eventId = e.id
  JOIN camp_event_scope s
    ON s.sourceTable = 'domain_event' AND s.eventId = e.id
   AND s.scopeKind = 'camp' AND s.campId = i.campId
  WHERE i.id = OLD.ingestionId
    AND l.state = 'active' AND c.archived = 0
    AND i.terminalReason IS NULL AND i.redactedAt IS NULL
    AND OLD.redactedAt IS NULL AND OLD.materializedAt IS NULL
    AND r.commandType = 'activeIngestionDeletion.v1'
    AND r.eventCount = 1
    AND (
      SELECT COUNT(*) FROM domain_event one_event
      WHERE one_event.commandIdempotencyKey = r.idempotencyKey
    ) = 1
    AND length(r.commandPayloadHash) = 64
    AND r.commandPayloadHash NOT GLOB '*[^0-9a-f]*'
    AND length(r.resultHash) = 64
    AND r.resultHash NOT GLOB '*[^0-9a-f]*'
    AND length(e.payloadHash) = 64
    AND e.payloadHash NOT GLOB '*[^0-9a-f]*'
    AND json_valid(r.resultJson) AND json_valid(e.payloadJson)
    AND (SELECT COUNT(*) FROM json_each(r.resultJson)) = 23
    AND (SELECT COUNT(*) FROM json_each(e.payloadJson)) = 21
    AND json_type(r.resultJson, '$.actorRef') IS NULL
    AND json_type(r.resultJson, '$.actorId') IS NULL
    AND json_type(r.resultJson, '$.actorType') IS NULL
    AND json_type(r.resultJson, '$.deviceId') IS NULL
    AND json_type(r.resultJson, '$.accountId') IS NULL
    AND json_type(r.resultJson, '$.accountIdentifier') IS NULL
    AND json_type(e.payloadJson, '$.actorRef') IS NULL
    AND json_type(e.payloadJson, '$.actorId') IS NULL
    AND json_type(e.payloadJson, '$.actorType') IS NULL
    AND json_type(e.payloadJson, '$.deviceId') IS NULL
    AND json_type(e.payloadJson, '$.accountId') IS NULL
    AND json_type(e.payloadJson, '$.accountIdentifier') IS NULL
    AND e.actorType = 'user'
    AND length(e.actorId) > 0
    AND e.deviceId IS NOT NULL AND length(e.deviceId) > 0
    AND length(e.correlationId) > 0
    AND (e.causationId IS NULL OR length(e.causationId) > 0)
    AND length(e.occurredAt) > 0 AND length(e.recordedAt) > 0
    AND e.recordedAt >= e.occurredAt
    AND o.state = 'pending' AND o.attempt = 0
    AND o.notBefore IS NULL AND o.leaseOwner IS NULL
    AND o.leaseExpiresAt IS NULL AND o.lastError IS NULL
    AND o.version = 1 AND o.createdAt = e.recordedAt
    AND o.updatedAt = e.recordedAt AND o.sentAt IS NULL
    AND (
      SELECT COUNT(*) FROM event_outbox one_outbox
      WHERE one_outbox.eventId = e.id
    ) = 1
    AND json_extract(r.resultJson, '$.commandIdempotencyKey')
      = e.commandIdempotencyKey
    AND json_extract(r.resultJson, '$.eventId') = e.id
    AND json_extract(r.resultJson, '$.eventPayloadHash') = e.payloadHash
    AND json_extract(r.resultJson, '$.campId') = i.campId
    AND json_extract(r.resultJson, '$.expectedLifecycleVersion') = l.version
    AND json_extract(r.resultJson, '$.ingestionId') = i.id
    AND json_extract(r.resultJson, '$.oldIngestionVersion') = i.version
    AND json_extract(r.resultJson, '$.oldIngestionStatus') = i.status
    AND json_extract(r.resultJson, '$.ingestionContentHash') = i.contentHash
    AND length(json_extract(r.resultJson, '$.ingestionSnapshotHash')) = 64
    AND json_extract(r.resultJson, '$.ingestionSnapshotHash')
      NOT GLOB '*[^0-9a-f]*'
    AND json_extract(r.resultJson, '$.resultId') = OLD.id
    AND json_extract(r.resultJson, '$.resultVersion') = OLD.version
    AND json_extract(r.resultJson, '$.knowledgeSourceLinkCount') = 0
    AND json_extract(r.resultJson, '$.actionCandidateCount') = 0
    AND json_extract(r.resultJson, '$.nonterminalRuminationWorkCount') = 0
    AND json_extract(r.resultJson, '$.openRuminationAttemptCount') = 0
    AND json_extract(r.resultJson, '$.nonterminalProviderDispatchCount') = 0
    AND json_extract(e.payloadJson, '$.campId') = i.campId
    AND json_extract(e.payloadJson, '$.commandIdempotencyKey')
      = e.commandIdempotencyKey
    AND json_extract(e.payloadJson, '$.expectedLifecycleVersion') = l.version
    AND json_extract(e.payloadJson, '$.commandPayloadHash')
      = r.commandPayloadHash
    AND json_extract(e.payloadJson, '$.ingestionId') = i.id
    AND json_extract(e.payloadJson, '$.oldIngestionVersion') = i.version
    AND json_extract(e.payloadJson, '$.oldIngestionStatus') = i.status
    AND json_extract(e.payloadJson, '$.ingestionContentHash') = i.contentHash
    AND length(json_extract(e.payloadJson, '$.ingestionSnapshotHash')) = 64
    AND json_extract(e.payloadJson, '$.ingestionSnapshotHash')
      NOT GLOB '*[^0-9a-f]*'
    AND json_extract(r.resultJson, '$.ingestionSnapshotHash')
      = json_extract(e.payloadJson, '$.ingestionSnapshotHash')
    AND json_extract(e.payloadJson, '$.resultId') = OLD.id
    AND json_extract(e.payloadJson, '$.resultVersion') = OLD.version
    AND length(json_extract(e.payloadJson, '$.resultHash')) = 64
    AND json_extract(e.payloadJson, '$.resultHash')
      NOT GLOB '*[^0-9a-f]*'
    AND json_extract(r.resultJson, '$.commandPayloadHash')
      = json_extract(e.payloadJson, '$.commandPayloadHash')
    AND json_extract(r.resultJson, '$.scope')
      = json_extract(e.payloadJson, '$.scope')
    AND json_extract(r.resultJson, '$.resultHash')
      = json_extract(e.payloadJson, '$.resultHash')
    AND json_extract(r.resultJson, '$.deletedResultCount') = 1
    AND json_extract(e.payloadJson, '$.deletedResultCount') = 1
    AND json_extract(e.payloadJson, '$.knowledgeSourceLinkCount') = 0
    AND json_extract(e.payloadJson, '$.actionCandidateCount') = 0
    AND json_extract(e.payloadJson, '$.nonterminalRuminationWorkCount') = 0
    AND json_extract(e.payloadJson, '$.openRuminationAttemptCount') = 0
    AND json_extract(e.payloadJson, '$.nonterminalProviderDispatchCount') = 0
    AND (
      (json_extract(e.payloadJson, '$.scope') = 'resultOnly'
        AND i.status IN ('needsReview','failed')
        AND json_extract(r.resultJson, '$.deletedIngestionCount') = 0
        AND json_extract(e.payloadJson, '$.deletedIngestionCount') = 0
        AND json_extract(r.resultJson, '$.updatedIngestionCount') = 1
        AND json_extract(e.payloadJson, '$.updatedIngestionCount') = 1)
      OR
      (json_extract(e.payloadJson, '$.scope') = 'sourceAndResult'
        AND i.status IN ('queued','failed','needsReview','discarded')
        AND json_extract(r.resultJson, '$.deletedIngestionCount') = 1
        AND json_extract(e.payloadJson, '$.deletedIngestionCount') = 1
        AND json_extract(r.resultJson, '$.updatedIngestionCount') = 0
        AND json_extract(e.payloadJson, '$.updatedIngestionCount') = 0)
    )
    AND NOT EXISTS (
      SELECT 1 FROM knowledge_source_link k WHERE k.ingestionId = i.id
    )
    AND NOT EXISTS (
      SELECT 1 FROM action_candidate a WHERE a.ingestionId = i.id
    )
    AND NOT EXISTS (
      SELECT 1 FROM durable_work w
      WHERE w.campId = i.campId AND w.kind = 'rumination'
        AND w.aggregateType = 'ingestion' AND w.aggregateId = i.id
        AND w.state IN ('queued','running','retryScheduled')
    )
    AND NOT EXISTS (
      SELECT 1 FROM durable_work_attempt a
      JOIN durable_work w ON w.id = a.workId
      WHERE w.campId = i.campId AND w.kind = 'rumination'
        AND w.aggregateType = 'ingestion' AND w.aggregateId = i.id
        AND a.endedAt IS NULL
    )
    AND NOT EXISTS (
      SELECT 1 FROM camp_provider_dispatch p
      JOIN durable_work w ON w.id = p.workId
      WHERE w.campId = i.campId AND w.kind = 'rumination'
        AND w.aggregateType = 'ingestion' AND w.aggregateId = i.id
        AND p.state IN ('prepared','started','returned')
    )
    AND agentloop_active_ingestion_deletion_permit_v1(
      'deleteResult',
      e.commandIdempotencyKey, r.commandPayloadHash, e.id, e.payloadHash,
      e.actorType, e.actorId, e.deviceId, e.correlationId, e.causationId,
      e.occurredAt, e.recordedAt, i.campId, l.version,
      json_extract(e.payloadJson, '$.scope'),
      json_extract(e.payloadJson, '$.ingestionSnapshotHash'),
      json_extract(e.payloadJson, '$.resultHash'),
      json_extract(e.payloadJson, '$.deletedResultCount'),
      json_extract(e.payloadJson, '$.deletedIngestionCount'),
      json_extract(e.payloadJson, '$.updatedIngestionCount'),
      json_extract(e.payloadJson, '$.knowledgeSourceLinkCount'),
      json_extract(e.payloadJson, '$.actionCandidateCount'),
      json_extract(e.payloadJson, '$.nonterminalRuminationWorkCount'),
      json_extract(e.payloadJson, '$.openRuminationAttemptCount'),
      json_extract(e.payloadJson, '$.nonterminalProviderDispatchCount'),
      o.eventId, o.state, o.attempt, o.notBefore, o.leaseOwner,
      o.leaseExpiresAt, o.lastError, o.version, o.createdAt, o.updatedAt,
      o.sentAt,
      i.id, i.campId, i.sourceType, i.title, i.rawText, i.sourceURL, i.author,
      i.userIntent, i.contentHash, i.status, i.attempt, i.errorText,
      i.createdAt, i.updatedAt, i.version, i.terminalReason, i.redactedAt,
      OLD.id, OLD.ingestionId, OLD.pipelineVersion, OLD.resultJson,
      OLD.userEditedJson, OLD.materializedAt, OLD.createdAt, OLD.updatedAt,
      OLD.version, OLD.redactedAt
    ) = 1
)
BEGIN
  SELECT RAISE(ABORT, 'rumination result delete requires exact transaction permit');
END;

CREATE TRIGGER action_candidate_validate_deletion_terminal
BEFORE UPDATE ON action_candidate
WHEN NEW.terminalReason IS NOT OLD.terminalReason
AND NOT (
  OLD.terminalReason IS NULL
  AND OLD.redactedAt IS NULL AND NEW.redactedAt IS NULL
  AND OLD.status IN ('proposed','accepted')
  AND NEW.id = OLD.id AND NEW.ingestionId = OLD.ingestionId
  AND NEW.campId = OLD.campId AND NEW.type = OLD.type
  AND NEW.title = OLD.title AND NEW.detailJson = OLD.detailJson
  AND NEW.status = 'dismissed' AND NEW.missionId IS OLD.missionId
  AND NEW.idemKey = OLD.idemKey
  AND NEW.createdAt = OLD.createdAt AND NEW.updatedAt = OLD.updatedAt
  AND NEW.version = OLD.version + 1
  AND NEW.terminalReason = 'camp_deleted'
  AND EXISTS (
    SELECT 1 FROM ingestion_item i
    JOIN camp_lifecycle l ON l.campId = i.campId
    JOIN camp_deletion_job j ON j.campId = i.campId
    WHERE i.id = OLD.ingestionId AND i.campId = OLD.campId
      AND l.state = 'deletionRequested' AND j.state = 'quiescing'
  )
)
BEGIN SELECT RAISE(ABORT, 'candidate deletion terminal diff is invalid'); END;
CREATE TRIGGER action_candidate_deletion_terminal_lock
BEFORE UPDATE ON action_candidate
WHEN OLD.terminalReason = 'camp_deleted'
  AND OLD.redactedAt IS NULL AND NEW.redactedAt IS NULL
BEGIN SELECT RAISE(ABORT, 'deletion-terminal candidate is immutable'); END;
CREATE TRIGGER action_candidate_first_redaction_exact
BEFORE UPDATE ON action_candidate
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  OLD.status IN ('dismissed','converted')
  AND NEW.id = OLD.id AND NEW.ingestionId = OLD.ingestionId
  AND NEW.campId = OLD.campId AND NEW.type = OLD.type
  AND NEW.title = '[deleted]' AND NEW.detailJson = '{}'
  AND NEW.status = OLD.status AND NEW.missionId IS OLD.missionId
  AND NEW.idemKey = OLD.idemKey
  AND NEW.createdAt = OLD.createdAt AND NEW.updatedAt = OLD.updatedAt
  AND NEW.version = OLD.version + 1
  AND NEW.terminalReason IS OLD.terminalReason
  AND EXISTS (
    SELECT 1 FROM ingestion_item i
    JOIN camp_lifecycle l ON l.campId = i.campId
    JOIN camp_deletion_job j ON j.campId = i.campId
    WHERE i.id = OLD.ingestionId AND i.campId = OLD.campId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN SELECT RAISE(ABORT, 'candidate redaction diff is invalid'); END;
CREATE TRIGGER action_candidate_post_redaction_lock
BEFORE UPDATE ON action_candidate WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'candidate is immutable after redaction'); END;
CREATE TRIGGER action_candidate_reject_delete
BEFORE DELETE ON action_candidate
BEGIN SELECT RAISE(ABORT, 'candidate may not be deleted'); END;

CREATE TRIGGER knowledge_source_link_first_redaction_exact
BEFORE UPDATE ON knowledge_source_link
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.id = OLD.id
  AND NEW.campNoteId = OLD.campNoteId
  AND NEW.ingestionId = OLD.ingestionId
  AND NEW.locatorJson IS NULL
  AND NEW.createdAt = OLD.createdAt
  AND NEW.version = OLD.version + 1
  AND EXISTS (
    SELECT 1 FROM camp_note n
    JOIN ingestion_item i ON i.id = OLD.ingestionId
    JOIN camp_lifecycle l ON l.campId = i.campId
    JOIN camp_deletion_job j ON j.campId = i.campId
    WHERE n.id = OLD.campNoteId AND n.campId = i.campId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN SELECT RAISE(ABORT, 'knowledge source redaction diff is invalid'); END;
CREATE TRIGGER knowledge_source_link_post_redaction_lock
BEFORE UPDATE ON knowledge_source_link WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'knowledge source is immutable after redaction'); END;
CREATE TRIGGER knowledge_source_link_reject_delete
BEFORE DELETE ON knowledge_source_link
BEGIN SELECT RAISE(ABORT, 'knowledge source may not be deleted'); END;

CREATE TRIGGER schedule_fire_first_redaction_exact
BEFORE UPDATE ON schedule_fire
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.id = OLD.id
  AND NEW.scheduleId = OLD.scheduleId
  AND NEW.templateId = OLD.templateId
  AND NEW.slotKey = OLD.slotKey
  AND NEW.scheduledAt = OLD.scheduledAt
  AND NEW.replayOfFireId IS OLD.replayOfFireId
  AND NEW.replayIdempotencyKey IS OLD.replayIdempotencyKey
  AND NEW.replayPayloadHash IS OLD.replayPayloadHash
  AND NEW.state = OLD.state
  AND NEW.missionId IS OLD.missionId
  AND NEW.traceId = OLD.traceId
  AND NEW.errorCode IS OLD.errorCode
  AND NEW.errorMessage IS NULL
  AND NEW.createdAt = OLD.createdAt
  AND EXISTS (
    SELECT 1 FROM schedule s
    JOIN mission_template t ON t.id = s.templateId
    JOIN camp_lifecycle l ON l.campId = t.campId
    JOIN camp_deletion_job j ON j.campId = t.campId
    WHERE s.id = OLD.scheduleId
      AND s.templateId = OLD.templateId
      AND l.state = 'deleting' AND j.state = 'finalizing'
      AND (
        OLD.missionId IS NULL
        OR EXISTS (
          SELECT 1 FROM mission m
          JOIN squad q ON q.id = m.squadId
          WHERE m.id = OLD.missionId AND q.campId = t.campId
        )
      )
      AND (
        OLD.replayOfFireId IS NULL
        OR EXISTS (
          SELECT 1 FROM schedule_fire parent
          WHERE parent.id = OLD.replayOfFireId
            AND parent.scheduleId = OLD.scheduleId
            AND parent.templateId = OLD.templateId
        )
      )
  )
)
BEGIN SELECT RAISE(ABORT, 'schedule fire redaction diff is invalid'); END;
CREATE TRIGGER schedule_fire_post_redaction_lock
BEFORE UPDATE ON schedule_fire WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'schedule fire is immutable after redaction'); END;
CREATE TRIGGER schedule_fire_reject_delete
BEFORE DELETE ON schedule_fire
BEGIN SELECT RAISE(ABORT, 'schedule fire may not be deleted'); END;

CREATE TRIGGER failure_record_first_redaction_exact
BEFORE UPDATE ON failure_record
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.id = OLD.id
  AND NEW.operation = OLD.operation
  AND NEW.scopeKind = OLD.scopeKind
  AND NEW.campId IS OLD.campId
  AND NEW.scopeType = OLD.scopeType
  AND NEW.scopeId = OLD.scopeId
  AND NEW.severity = OLD.severity
  AND NEW.errorCode = OLD.errorCode
  AND NEW.userMessage = '[deleted]'
  AND NEW.diagnosticJson = '{}'
  AND NEW.state = OLD.state
  AND NEW.firstSeenAt = OLD.firstSeenAt
  AND NEW.lastSeenAt = OLD.lastSeenAt
  AND NEW.occurrenceCount = OLD.occurrenceCount
  AND NEW.resolvedAt IS OLD.resolvedAt
  AND OLD.scopeKind = 'camp' AND OLD.campId IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM camp_lifecycle l
    JOIN camp_deletion_job j ON j.campId = l.campId
    WHERE l.campId = OLD.campId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN SELECT RAISE(ABORT, 'failure record redaction diff is invalid'); END;
CREATE TRIGGER failure_record_post_redaction_lock
BEFORE UPDATE ON failure_record WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'failure record is immutable after redaction'); END;
CREATE TRIGGER failure_record_reject_delete
BEFORE DELETE ON failure_record
BEGIN SELECT RAISE(ABORT, 'failure record may not be deleted'); END;

CREATE TRIGGER context_degradation_first_redaction_exact
BEFORE UPDATE ON context_degradation
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.id = OLD.id
  AND NEW.missionId IS OLD.missionId
  AND NEW.cardId IS OLD.cardId
  AND NEW.dependencyType = OLD.dependencyType
  AND NEW.dependencyId = OLD.dependencyId
  AND NEW.policy = OLD.policy
  AND NEW.traceId = OLD.traceId
  AND NEW.detail = '[deleted]'
  AND NEW.createdAt = OLD.createdAt
  AND EXISTS (
    SELECT 1 FROM camp_lifecycle l
    JOIN camp_deletion_job j ON j.campId = l.campId
    WHERE l.state = 'deleting' AND j.state = 'finalizing'
      AND (
        EXISTS (
          SELECT 1 FROM mission m JOIN squad s ON s.id = m.squadId
          WHERE m.id = OLD.missionId AND s.campId = l.campId
        )
        OR EXISTS (
          SELECT 1 FROM card c
          JOIN mission m ON m.id = c.missionId
          JOIN squad s ON s.id = m.squadId
          WHERE c.id = OLD.cardId AND s.campId = l.campId
        )
      )
      AND NOT EXISTS (
        SELECT 1 FROM mission m JOIN squad s ON s.id = m.squadId
        WHERE m.id = OLD.missionId AND s.campId <> l.campId
      )
      AND NOT EXISTS (
        SELECT 1 FROM card c
        JOIN mission m ON m.id = c.missionId
        JOIN squad s ON s.id = m.squadId
        WHERE c.id = OLD.cardId AND s.campId <> l.campId
      )
  )
)
BEGIN SELECT RAISE(ABORT, 'degradation redaction diff is invalid'); END;
CREATE TRIGGER context_degradation_post_redaction_lock
BEFORE UPDATE ON context_degradation WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'degradation is immutable after redaction'); END;
CREATE TRIGGER context_degradation_reject_delete
BEFORE DELETE ON context_degradation
BEGIN SELECT RAISE(ABORT, 'degradation may not be deleted'); END;

CREATE TRIGGER inbox_message_first_redaction_exact
BEFORE UPDATE ON inbox_message
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.id = OLD.id
  AND NEW.campId = OLD.campId AND OLD.campId IS NOT NULL
  AND NEW.sourceDeviceId = '[deleted]'
  AND NEW.idempotencyKey = OLD.idempotencyKey
  AND NEW.payloadJson = '{}'
  AND NEW.payloadHash = OLD.payloadHash
  AND NEW.state = 'rejected'
  AND NEW.receivedAt = OLD.receivedAt
  AND NEW.appliedAt IS OLD.appliedAt
  AND NEW.errorCode = 'camp_deleted'
  AND NEW.version = OLD.version + 1
  AND EXISTS (
    SELECT 1 FROM camp_lifecycle l
    JOIN camp_deletion_job j ON j.campId = l.campId
    WHERE l.campId = OLD.campId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN SELECT RAISE(ABORT, 'inbox redaction diff is invalid'); END;
CREATE TRIGGER inbox_message_post_redaction_lock
BEFORE UPDATE ON inbox_message WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'inbox row is immutable after redaction'); END;
CREATE TRIGGER inbox_message_reject_delete
BEFORE DELETE ON inbox_message
BEGIN SELECT RAISE(ABORT, 'inbox row may not be deleted'); END;

CREATE TRIGGER approval_grant_first_redaction_exact
BEFORE UPDATE ON approval_grant
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.id = OLD.id
  AND NEW.version = OLD.version + 1
  AND NEW.scopeVersion = OLD.scopeVersion
  AND NEW.grantorActorType = OLD.grantorActorType
  AND NEW.grantorActorId = '[deleted]'
  AND NEW.grantorPolicyId IS NULL
  AND NEW.grantorPolicyVersion IS NULL
  AND NEW.grantorPolicyHash IS NULL
  AND NEW.granteeType = OLD.granteeType
  AND NEW.granteeId = OLD.granteeId
  AND NEW.capability = OLD.capability
  AND NEW.campId = OLD.campId
  AND NEW.cardId = OLD.cardId
  AND NEW.toolId = OLD.toolId
  AND NEW.approvedInputHash = OLD.approvedInputHash
  AND NEW.purpose = '[deleted]'
  AND NEW.dataLevel = OLD.dataLevel
  AND NEW.adapterReplayClass = OLD.adapterReplayClass
  AND NEW.validFrom = OLD.validFrom
  AND NEW.validUntil = OLD.validUntil
  AND NEW.maxUses = OLD.maxUses
  AND NEW.usedCount = OLD.usedCount
  AND (
    (OLD.status = 'active'
      AND NEW.status = 'revoked' AND NEW.revokedAt = NEW.redactedAt)
    OR
    (OLD.status IN ('exhausted','revoked','expired')
      AND NEW.status = OLD.status AND NEW.revokedAt IS OLD.revokedAt)
  )
  AND NEW.createdAt = OLD.createdAt
  AND NEW.updatedAt = NEW.redactedAt
  AND EXISTS (
    SELECT 1 FROM camp_lifecycle l
    JOIN camp_deletion_job j ON j.campId = l.campId
    WHERE l.campId = OLD.campId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN SELECT RAISE(ABORT, 'grant redaction diff is invalid'); END;
CREATE TRIGGER approval_grant_post_redaction_lock
BEFORE UPDATE ON approval_grant WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'grant is immutable after redaction'); END;
CREATE TRIGGER approval_grant_reject_delete
BEFORE DELETE ON approval_grant
BEGIN SELECT RAISE(ABORT, 'grant may not be deleted'); END;
CREATE TRIGGER approval_grant_use_first_redaction_exact
BEFORE UPDATE ON approval_grant_use
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.id = OLD.id AND NEW.grantId = OLD.grantId
  AND NEW.idempotencyKey = OLD.idempotencyKey
  AND NEW.toolId = OLD.toolId AND NEW.inputHash = OLD.inputHash
  AND NEW.adapterId = OLD.adapterId
  AND NEW.adapterReplayClass = OLD.adapterReplayClass
  AND NEW.state = OLD.state AND NEW.adapterOperationId IS NULL
  AND NEW.version = OLD.version + 1
  AND NEW.reservedAt = OLD.reservedAt
  AND NEW.dispatchIntentAt IS OLD.dispatchIntentAt
  AND NEW.adapterAcceptedAt IS OLD.adapterAcceptedAt
  AND NEW.finishedAt IS OLD.finishedAt
  AND OLD.state IN ('succeeded','failedFinal','released','abandonedUnknown')
  AND EXISTS (
    SELECT 1 FROM approval_grant g
    JOIN camp_lifecycle l ON l.campId = g.campId
    JOIN camp_deletion_job j ON j.campId = g.campId
    WHERE g.id = OLD.grantId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN
  SELECT RAISE(ABORT, 'grant use redaction diff is invalid');
END;
CREATE TRIGGER approval_grant_use_post_redaction_lock
BEFORE UPDATE ON approval_grant_use WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'grant use is immutable after redaction'); END;
CREATE TRIGGER approval_grant_use_reject_delete
BEFORE DELETE ON approval_grant_use
BEGIN SELECT RAISE(ABORT, 'grant use may not be deleted'); END;

CREATE TRIGGER event_require_typed_scope
AFTER INSERT ON event
WHEN NOT EXISTS (
  SELECT 1 FROM camp_event_scope s
  WHERE s.sourceTable = 'event' AND s.eventId = NEW.id
)
BEGIN
  SELECT RAISE(ABORT, 'legacy event requires typed scope');
END;
CREATE TRIGGER domain_event_require_matching_scope
AFTER INSERT ON domain_event
WHEN NOT EXISTS (
  SELECT 1 FROM camp_event_scope s
  WHERE s.sourceTable = 'domain_event' AND s.eventId = NEW.id
    AND s.scopeKind = 'camp' AND s.campId = NEW.campId
)
BEGIN
  SELECT RAISE(ABORT, 'domain event requires matching Camp scope');
END;

CREATE TRIGGER camp_event_scope_reject_update_except_redaction
BEFORE UPDATE ON camp_event_scope
WHEN NOT (
  NEW.sourceTable = OLD.sourceTable
  AND NEW.eventId = OLD.eventId
  AND NEW.scopeKind = OLD.scopeKind
  AND NEW.campId IS OLD.campId
  AND OLD.payloadRedactedAt IS NULL
  AND NEW.payloadRedactedAt IS NOT NULL
  AND OLD.sourceTable = 'event'
  AND OLD.scopeKind = 'camp'
  AND EXISTS (
    SELECT 1 FROM camp_lifecycle l
    JOIN camp_deletion_job j ON j.campId = l.campId
    WHERE l.campId = OLD.campId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN
  SELECT RAISE(ABORT, 'event scope is immutable except final redaction');
END;
CREATE TRIGGER camp_event_scope_reject_delete
BEFORE DELETE ON camp_event_scope
BEGIN
  SELECT RAISE(ABORT, 'event scope is immutable');
END;

CREATE TRIGGER event_reject_update_except_camp_redaction
BEFORE UPDATE ON event
WHEN NOT (
  NEW.id = OLD.id
  AND NEW.missionId IS OLD.missionId
  AND NEW.cardId IS OLD.cardId
  AND NEW.runId IS OLD.runId
  AND NEW.kind = OLD.kind
  AND NEW.createdAt = OLD.createdAt
  AND OLD.payloadJson <> '{"redacted":"camp_deleted"}'
  AND NEW.payloadJson = '{"redacted":"camp_deleted"}'
  AND EXISTS (
    SELECT 1 FROM camp_event_scope s
    JOIN camp_lifecycle l ON l.campId = s.campId
    JOIN camp_deletion_job j ON j.campId = s.campId
    WHERE s.sourceTable = 'event' AND s.eventId = OLD.id
      AND s.scopeKind = 'camp' AND s.payloadRedactedAt IS NOT NULL
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN
  SELECT RAISE(ABORT, 'event is append-only');
END;

CREATE TRIGGER durable_work_attempt_event_reject_update_except_camp_redaction
BEFORE UPDATE ON durable_work_attempt_event
WHEN NOT (
  NEW.id = OLD.id
  AND NEW.workId = OLD.workId
  AND NEW.attempt = OLD.attempt
  AND NEW.sequence = OLD.sequence
  AND NEW.eventKind = OLD.eventKind
  AND NEW.providerDispatchId IS OLD.providerDispatchId
  AND NEW.workerId = OLD.workerId
  AND NEW.workVersion = OLD.workVersion
  AND NEW.resultingWorkState = OLD.resultingWorkState
  AND NEW.errorCode IS OLD.errorCode
  AND NEW.errorMessage IS NULL
  AND NEW.occurredAt = OLD.occurredAt
  AND OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM durable_work w
    JOIN camp_lifecycle l ON l.campId = w.campId
    JOIN camp_deletion_job j ON j.campId = w.campId
    WHERE w.id = OLD.workId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN
  SELECT RAISE(ABORT, 'durable_work_attempt_event is append-only');
END;
CREATE TRIGGER durable_work_attempt_event_reject_delete
BEFORE DELETE ON durable_work_attempt_event
BEGIN
  SELECT RAISE(ABORT, 'durable_work_attempt_event is append-only');
END;

-- The three v15 DELETE guards remain installed.  Their UPDATE guards were
-- dropped in the ordered post-barrier block and are replaced here by the exact
-- finalizing exceptions.
CREATE TRIGGER verification_record_reject_update_except_camp_redaction
BEFORE UPDATE ON verification_record
WHEN NOT (
  NEW.id = OLD.id
  AND NEW.commandIdempotencyKey = OLD.commandIdempotencyKey
  AND NEW.contractId = OLD.contractId
  AND NEW.contractVersion = OLD.contractVersion
  AND NEW.contractHash = OLD.contractHash
  AND NEW.requirementId = OLD.requirementId
  AND NEW.requirementVersion = OLD.requirementVersion
  AND NEW.requirementHash = OLD.requirementHash
  AND NEW.outcomeId = OLD.outcomeId
  AND NEW.outcomeVersion = OLD.outcomeVersion
  AND NEW.outcomeHash = OLD.outcomeHash
  AND NEW.verifierType = OLD.verifierType
  AND NEW.verifierId = OLD.verifierId
  AND NEW.method = OLD.method
  AND NEW.ruleId = OLD.ruleId
  AND NEW.ruleVersion = OLD.ruleVersion
  AND NEW.environmentJson = '{}'
  AND NEW.commandOrRuleJson = '{}'
  AND NEW.rawResultRef IS NULL
  AND NEW.evidenceHash = OLD.evidenceHash
  AND NEW.result = OLD.result
  AND NEW.supersedesVerificationId IS OLD.supersedesVerificationId
  AND NEW.createdAt = OLD.createdAt
  AND OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM outcome o
    JOIN goal_controller g ON g.id = o.goalId
    JOIN camp_lifecycle l ON l.campId = g.campId
    JOIN camp_deletion_job j ON j.campId = g.campId
    WHERE o.id = OLD.outcomeId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN
  SELECT RAISE(ABORT, 'verification_record is append-only');
END;

CREATE TRIGGER acceptance_record_reject_update_except_camp_redaction
BEFORE UPDATE ON acceptance_record
WHEN NOT (
  NEW.id = OLD.id
  AND NEW.commandIdempotencyKey = OLD.commandIdempotencyKey
  AND NEW.contractId = OLD.contractId
  AND NEW.contractVersion = OLD.contractVersion
  AND NEW.contractHash = OLD.contractHash
  AND NEW.outcomeId = OLD.outcomeId
  AND NEW.outcomeVersion = OLD.outcomeVersion
  AND NEW.outcomeHash = OLD.outcomeHash
  AND NEW.subjectType = OLD.subjectType
  AND NEW.subjectId = OLD.subjectId
  AND NEW.policyId IS OLD.policyId
  AND NEW.policyVersion IS OLD.policyVersion
  AND NEW.decision = OLD.decision
  AND NEW.reason = '[deleted]'
  AND NEW.supersedesAcceptanceId IS OLD.supersedesAcceptanceId
  AND NEW.createdAt = OLD.createdAt
  AND OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM outcome o
    JOIN goal_controller g ON g.id = o.goalId
    JOIN camp_lifecycle l ON l.campId = g.campId
    JOIN camp_deletion_job j ON j.campId = g.campId
    WHERE o.id = OLD.outcomeId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN
  SELECT RAISE(ABORT, 'acceptance_record is append-only');
END;

CREATE TRIGGER external_operation_receipt_reject_update_except_camp_redaction
BEFORE UPDATE ON external_operation_receipt
WHEN NOT (
  NEW.id = OLD.id
  AND NEW.grantUseId = OLD.grantUseId
  AND NEW.receiptIdempotencyKey = OLD.receiptIdempotencyKey
  AND NEW.ordinal = OLD.ordinal
  AND NEW.phase = OLD.phase
  AND NEW.result = OLD.result
  AND NEW.adapterOperationId IS NULL
  AND NEW.receiptRef IS NULL
  AND NEW.receiptJson = '{"redacted":"camp_deleted"}'
  AND NEW.receiptHash = OLD.receiptHash
  AND NEW.authorityKind = OLD.authorityKind
  AND NEW.authorityId = '[deleted]'
  AND NEW.createdAt = OLD.createdAt
  AND OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM approval_grant_use u
    JOIN approval_grant g ON g.id = u.grantId
    JOIN camp_lifecycle l ON l.campId = g.campId
    JOIN camp_deletion_job j ON j.campId = g.campId
    WHERE u.id = OLD.grantUseId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN
  SELECT RAISE(ABORT, 'external_operation_receipt is append-only');
END;

"""
// P1-E-END V16IdentityMemorySQL
// P1-F1-BEGIN V17EngineCoordinationSQL
package let p1F1EngineCoordinationMigrationSQL = """
CREATE TABLE engine_session (
  id TEXT PRIMARY KEY NOT NULL,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  adapterId TEXT NOT NULL,
  adapterVersion TEXT NOT NULL,
  profileId TEXT NOT NULL REFERENCES runtime_profile(id) ON DELETE RESTRICT,
  externalSessionId TEXT,
  workspaceHash TEXT NOT NULL CHECK (length(workspaceHash) = 64),
  sessionScopeJson TEXT NOT NULL,
  sessionScopeHash TEXT NOT NULL CHECK (length(sessionScopeHash) = 64),
  state TEXT NOT NULL CHECK (state IN ('active','closed','invalid')),
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  redactedAt DATETIME,
  CHECK (
    (state IN ('active','closed') AND externalSessionId IS NOT NULL
      AND redactedAt IS NULL)
    OR
    (state = 'invalid')
  ),
  CHECK (
    redactedAt IS NULL
    OR
    (state = 'invalid' AND externalSessionId IS NULL
      AND sessionScopeJson = '{}')
  )
);
CREATE UNIQUE INDEX engine_session_external_identity
  ON engine_session(adapterId, profileId, externalSessionId)
  WHERE externalSessionId IS NOT NULL;
CREATE INDEX engine_session_resume
  ON engine_session(campId, profileId, adapterId, state, updatedAt);

CREATE TABLE engine_execution (
  id TEXT PRIMARY KEY NOT NULL,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  campLifecycleVersion INTEGER NOT NULL CHECK (campLifecycleVersion >= 1),
  idempotencyKey TEXT NOT NULL UNIQUE,
  runId TEXT NOT NULL UNIQUE REFERENCES run(id) ON DELETE RESTRICT,
  cardId TEXT NOT NULL REFERENCES card(id) ON DELETE RESTRICT,
  adapterId TEXT NOT NULL,
  adapterVersion TEXT NOT NULL,
  profileId TEXT NOT NULL REFERENCES runtime_profile(id) ON DELETE RESTRICT,
  engineKind TEXT NOT NULL,
  model TEXT NOT NULL,
  requestJson TEXT NOT NULL,
  requestHash TEXT NOT NULL CHECK (length(requestHash) = 64),
  contextJson TEXT NOT NULL,
  contextHash TEXT NOT NULL CHECK (length(contextHash) = 64),
  sessionScopeJson TEXT NOT NULL,
  sessionScopeHash TEXT NOT NULL CHECK (length(sessionScopeHash) = 64),
  sessionId TEXT REFERENCES engine_session(id) ON DELETE RESTRICT,
  replayClass TEXT NOT NULL CHECK
    (replayClass IN ('replaySafe','idempotencyKeyed','nonReplayable')),
  dispatchState TEXT NOT NULL CHECK
    (dispatchState IN ('prepared','started','sessionBound','terminalProposed','terminal')),
  state TEXT NOT NULL CHECK (state IN
    ('running','completed','blocked','failed','canceled')),
  terminalSubtype TEXT CHECK (terminalSubtype IS NULL OR terminalSubtype IN
    ('ordinary','needsHumanInput','engineProtocolError','externalEffectUnknown')),
  nextSequence INTEGER NOT NULL DEFAULT 0 CHECK (nextSequence >= 0),
  terminalReceiptIdempotencyKey TEXT
    REFERENCES domain_command_receipt(idempotencyKey) ON DELETE RESTRICT,
  terminalReceiptHash TEXT CHECK
    (terminalReceiptHash IS NULL OR
      (length(terminalReceiptHash) = 64
       AND terminalReceiptHash NOT GLOB '*[^0-9a-f]*')),
  inputTokens INTEGER NOT NULL DEFAULT 0 CHECK (inputTokens >= 0),
  outputTokens INTEGER NOT NULL DEFAULT 0 CHECK (outputTokens >= 0),
  cacheReadTokens INTEGER NOT NULL DEFAULT 0 CHECK (cacheReadTokens >= 0),
  costMicros INTEGER NOT NULL DEFAULT 0 CHECK (costMicros >= 0),
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  dispatchStartedAt DATETIME,
  cancellationRequestedAt DATETIME,
  cancellationReason TEXT,
  finishedAt DATETIME,
  redactedAt DATETIME,
  CHECK (
    (state = 'running'
      AND terminalReceiptIdempotencyKey IS NULL
      AND terminalReceiptHash IS NULL AND finishedAt IS NULL)
    OR
    (state <> 'running'
      AND terminalReceiptIdempotencyKey IS NOT NULL
      AND terminalReceiptHash IS NOT NULL AND finishedAt IS NOT NULL)
  ),
  CHECK (
    (state = 'running' AND dispatchState <> 'terminal')
    OR
    (state <> 'running' AND dispatchState = 'terminal')
  ),
  CHECK (
    (state = 'blocked' AND terminalSubtype IS NOT NULL)
    OR
    (state <> 'blocked' AND terminalSubtype IS NULL)
  ),
  CHECK (
    (dispatchState = 'prepared' AND dispatchStartedAt IS NULL
      AND state = 'running')
    OR
    (dispatchState IN ('started','sessionBound','terminalProposed')
      AND dispatchStartedAt IS NOT NULL AND state = 'running')
    OR
    (dispatchState = 'terminal'
      AND (
        (state = 'completed' AND dispatchStartedAt IS NOT NULL)
        OR
        (state = 'canceled'
          AND (dispatchStartedAt IS NOT NULL OR cancellationRequestedAt IS NOT NULL))
        OR
        state IN ('blocked','failed')
      ))
  ),
  CHECK (
    (sessionId IS NULL AND dispatchState <> 'sessionBound')
    OR
    (sessionId IS NOT NULL AND dispatchState IN ('sessionBound','terminalProposed','terminal'))
  ),
  CHECK (
    (cancellationRequestedAt IS NULL AND cancellationReason IS NULL)
    OR
    (cancellationRequestedAt IS NOT NULL AND cancellationReason IS NOT NULL)
  ),
  CHECK (
    redactedAt IS NULL
    OR
    (state <> 'running' AND requestJson = '{}' AND contextJson = '{}'
      AND sessionScopeJson = '{}'
      AND (
        (cancellationRequestedAt IS NULL AND cancellationReason IS NULL)
        OR
        (cancellationRequestedAt IS NOT NULL
          AND cancellationReason = 'camp_deleted')
      ))
  )
);
CREATE INDEX engine_execution_recovery
  ON engine_execution(campId, state, dispatchState, updatedAt);
CREATE INDEX engine_execution_card
  ON engine_execution(cardId, createdAt);

CREATE TABLE engine_terminal_proposal (
  id TEXT PRIMARY KEY NOT NULL,
  executionId TEXT NOT NULL UNIQUE
    REFERENCES engine_execution(id) ON DELETE RESTRICT,
  terminalIdempotencyKey TEXT NOT NULL UNIQUE,
  sequence INTEGER NOT NULL CHECK (sequence >= 0),
  terminalKind TEXT NOT NULL CHECK
    (terminalKind IN ('completed','blocked','failed','canceled')),
  terminalSubtype TEXT CHECK (terminalSubtype IS NULL OR terminalSubtype IN
    ('ordinary','needsHumanInput','engineProtocolError','externalEffectUnknown')),
  proposalJson TEXT NOT NULL,
  proposalHash TEXT NOT NULL CHECK (
    length(proposalHash) = 64 AND proposalHash NOT GLOB '*[^0-9a-f]*'
  ),
  payloadJson TEXT NOT NULL,
  payloadHash TEXT NOT NULL CHECK (length(payloadHash) = 64),
  artifactManifestJson TEXT NOT NULL,
  artifactManifestHash TEXT NOT NULL CHECK (length(artifactManifestHash) = 64),
  state TEXT NOT NULL CHECK (state IN ('pending','committed','invalid')),
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  createdAt DATETIME NOT NULL,
  committedAt DATETIME,
  invalidReason TEXT,
  invalidatedAt DATETIME,
  redactedAt DATETIME,
  CHECK (
    (terminalKind = 'blocked' AND terminalSubtype IS NOT NULL)
    OR
    (terminalKind <> 'blocked' AND terminalSubtype IS NULL)
  ),
  CHECK (
    (state = 'pending' AND committedAt IS NULL
      AND invalidReason IS NULL AND invalidatedAt IS NULL)
    OR
    (state = 'committed' AND committedAt IS NOT NULL
      AND invalidReason IS NULL AND invalidatedAt IS NULL)
    OR
    (state = 'invalid' AND committedAt IS NULL
      AND invalidReason IS NOT NULL AND invalidatedAt IS NOT NULL)
  ),
  CHECK (
    redactedAt IS NULL
    OR
    (state IN ('committed','invalid')
      AND proposalJson = '{}' AND payloadJson = '{}'
      AND artifactManifestJson = '[]'
      AND (
        (state = 'committed' AND invalidReason IS NULL)
        OR
        (state = 'invalid' AND invalidReason = 'camp_deleted')
      ))
  )
);
CREATE INDEX engine_terminal_proposal_pending
  ON engine_terminal_proposal(state, createdAt);
CREATE TABLE artifact_blob (
  contentHash TEXT PRIMARY KEY NOT NULL CHECK (
    length(contentHash) = 64 AND contentHash NOT GLOB '*[^0-9a-f]*'
  ),
  byteCount INTEGER NOT NULL CHECK (byteCount >= 0),
  relativePath TEXT NOT NULL,
  state TEXT NOT NULL CHECK
    (state IN ('available','quarantined','deletedTombstone')),
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  createdAt DATETIME NOT NULL,
  verifiedAt DATETIME NOT NULL,
  deletedAt DATETIME,
  CHECK (
    (state = 'deletedTombstone' AND relativePath = '' AND deletedAt IS NOT NULL)
    OR
    (state <> 'deletedTombstone' AND relativePath <> '' AND deletedAt IS NULL)
  )
);
CREATE UNIQUE INDEX artifact_blob_path
  ON artifact_blob(relativePath) WHERE relativePath <> '';
CREATE INDEX artifact_blob_gc
  ON artifact_blob(state, createdAt);

CREATE TABLE engine_proposal_artifact (
  id TEXT PRIMARY KEY NOT NULL,
  proposalId TEXT NOT NULL
    REFERENCES engine_terminal_proposal(id) ON DELETE RESTRICT,
  artifactId TEXT NOT NULL,
  ordinal INTEGER NOT NULL CHECK (ordinal >= 0),
  sourceRelativePath TEXT NOT NULL,
  kind TEXT NOT NULL,
  label TEXT NOT NULL,
  byteCount INTEGER NOT NULL CHECK (byteCount >= 0),
  contentHash TEXT NOT NULL CHECK (
    length(contentHash) = 64 AND contentHash NOT GLOB '*[^0-9a-f]*'
  ),
  state TEXT NOT NULL CHECK (state IN ('declared','prepared')),
  preparedAt DATETIME,
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  redactedAt DATETIME,
  UNIQUE(proposalId, artifactId),
  UNIQUE(proposalId, ordinal),
  CHECK (
    (state = 'declared' AND preparedAt IS NULL)
    OR
    (state = 'prepared' AND preparedAt IS NOT NULL)
  ),
  CHECK (
    redactedAt IS NULL
    OR
    (sourceRelativePath = '' AND kind = 'tombstone' AND label = '[deleted]')
  )
);
CREATE INDEX engine_proposal_artifact_gc_root
  ON engine_proposal_artifact(contentHash, proposalId, state);
CREATE TABLE camp_deletion_proposal_blob (
  id TEXT PRIMARY KEY NOT NULL,
  jobId TEXT NOT NULL REFERENCES camp_deletion_job(id) ON DELETE RESTRICT,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  proposalArtifactId TEXT NOT NULL
    REFERENCES engine_proposal_artifact(id) ON DELETE RESTRICT,
  contentHash TEXT NOT NULL CHECK (
    length(contentHash) = 64 AND contentHash NOT GLOB '*[^0-9a-f]*'
  ),
  expectedBlobVersion INTEGER CHECK (
    expectedBlobVersion IS NULL OR expectedBlobVersion >= 1
  ),
  state TEXT NOT NULL CHECK (state IN
    ('pending','reserved','unlinkReady','retryableFailure',
     'retainedShared','deleted','alreadyAbsent')),
  attempt INTEGER NOT NULL DEFAULT 0 CHECK (attempt >= 0),
  lastErrorCode TEXT,
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  createdAt DATETIME NOT NULL,
  reservedAt DATETIME,
  finishedAt DATETIME,
  UNIQUE(jobId, proposalArtifactId),
  CHECK (
    (state IN ('pending','retryableFailure')
      AND reservedAt IS NULL AND finishedAt IS NULL)
    OR
    (state IN ('reserved','unlinkReady')
      AND reservedAt IS NOT NULL AND finishedAt IS NULL)
    OR
    (state IN ('retainedShared','deleted','alreadyAbsent')
      AND finishedAt IS NOT NULL)
  )
);
CREATE INDEX camp_deletion_proposal_blob_recovery
  ON camp_deletion_proposal_blob(jobId, state, contentHash);

CREATE TABLE artifact_blob_reference (
  artifactId TEXT PRIMARY KEY NOT NULL
    REFERENCES artifact(id) ON DELETE RESTRICT,
  proposalArtifactId TEXT NOT NULL UNIQUE
    REFERENCES engine_proposal_artifact(id) ON DELETE RESTRICT,
  executionId TEXT NOT NULL
    REFERENCES engine_execution(id) ON DELETE RESTRICT,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  contentHash TEXT NOT NULL
    REFERENCES artifact_blob(contentHash) ON DELETE RESTRICT,
  state TEXT NOT NULL CHECK (state IN ('active','tombstoned')),
  createdAt DATETIME NOT NULL,
  tombstonedAt DATETIME,
  CHECK (
    (state = 'active' AND tombstonedAt IS NULL)
    OR
    (state = 'tombstoned' AND tombstonedAt IS NOT NULL)
  )
);
CREATE INDEX artifact_blob_reference_live
  ON artifact_blob_reference(contentHash, state);
CREATE INDEX artifact_blob_reference_camp
  ON artifact_blob_reference(campId, state);

CREATE TABLE artifact_storage_origin (
  artifactId TEXT PRIMARY KEY NOT NULL
    REFERENCES artifact(id) ON DELETE RESTRICT,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  state TEXT NOT NULL DEFAULT 'active' CHECK
    (state IN ('active','tombstoned')),
  storageClass TEXT NOT NULL CHECK
    (storageClass IN ('managed','workspaceExternal','unresolved')),
  evidenceKind TEXT NOT NULL CHECK
    (evidenceKind IN
      ('typedPreparedArtifact','verifiedManagedRootCapability',
       'explicitWorkspaceExternal','verifiedOutsideAllManagedRoots',
       'legacyUnknown')),
  managedRootId TEXT,
  objectId TEXT,
  contentHash TEXT CHECK (
    contentHash IS NULL OR
    (length(contentHash) = 64 AND contentHash NOT GLOB '*[^0-9a-f]*')
  ),
  fileIdentityHash TEXT CHECK (
    fileIdentityHash IS NULL OR
    (length(fileIdentityHash) = 64
      AND fileIdentityHash NOT GLOB '*[^0-9a-f]*')
  ),
  originalRefHash TEXT NOT NULL CHECK (
    length(originalRefHash) = 64
    AND originalRefHash NOT GLOB '*[^0-9a-f]*'
  ),
  classificationEvidenceHash TEXT NOT NULL CHECK (
    length(classificationEvidenceHash) = 64
    AND classificationEvidenceHash NOT GLOB '*[^0-9a-f]*'
  ),
  terminalDisposition TEXT CHECK (
    terminalDisposition IS NULL OR terminalDisposition IN
      ('managedDeleted','managedAlreadyAbsent','managedSharedDetached',
       'workspaceExternalDetached','unresolvedDetached')
  ),
  terminalAuthorityHash TEXT CHECK (
    terminalAuthorityHash IS NULL OR
    (length(terminalAuthorityHash) = 64
      AND terminalAuthorityHash NOT GLOB '*[^0-9a-f]*')
  ),
  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
  classifiedAt DATETIME NOT NULL,
  redactedAt DATETIME,
  CHECK (
    (state = 'active' AND storageClass = 'managed'
      AND evidenceKind IN
        ('typedPreparedArtifact','verifiedManagedRootCapability')
      AND managedRootId IS NOT NULL AND objectId IS NOT NULL
      AND contentHash IS NOT NULL AND fileIdentityHash IS NOT NULL
      AND terminalDisposition IS NULL AND terminalAuthorityHash IS NULL
      AND redactedAt IS NULL)
    OR
    (state = 'active' AND storageClass = 'workspaceExternal'
      AND evidenceKind IN
        ('explicitWorkspaceExternal','verifiedOutsideAllManagedRoots')
      AND managedRootId IS NULL AND objectId IS NULL
      AND contentHash IS NULL AND fileIdentityHash IS NULL
      AND terminalDisposition IS NULL AND terminalAuthorityHash IS NULL
      AND redactedAt IS NULL)
    OR
    (state = 'active' AND storageClass = 'unresolved'
      AND evidenceKind = 'legacyUnknown'
      AND managedRootId IS NULL AND objectId IS NULL
      AND contentHash IS NULL AND fileIdentityHash IS NULL
      AND terminalDisposition IS NULL AND terminalAuthorityHash IS NULL
      AND redactedAt IS NULL)
    OR
    (state = 'tombstoned' AND storageClass = 'managed'
      AND evidenceKind IN
        ('typedPreparedArtifact','verifiedManagedRootCapability')
      AND managedRootId IS NULL AND objectId IS NULL
      AND contentHash IS NOT NULL AND fileIdentityHash IS NOT NULL
      AND terminalDisposition IN
        ('managedDeleted','managedAlreadyAbsent','managedSharedDetached')
      AND terminalAuthorityHash IS NOT NULL AND redactedAt IS NOT NULL)
    OR
    (state = 'tombstoned' AND storageClass = 'workspaceExternal'
      AND evidenceKind IN
        ('explicitWorkspaceExternal','verifiedOutsideAllManagedRoots')
      AND managedRootId IS NULL AND objectId IS NULL
      AND contentHash IS NULL AND fileIdentityHash IS NULL
      AND terminalDisposition = 'workspaceExternalDetached'
      AND terminalAuthorityHash IS NOT NULL AND redactedAt IS NOT NULL)
    OR
    (state = 'tombstoned' AND storageClass = 'unresolved'
      AND evidenceKind = 'legacyUnknown'
      AND managedRootId IS NULL AND objectId IS NULL
      AND contentHash IS NULL AND fileIdentityHash IS NULL
      AND terminalDisposition = 'unresolvedDetached'
      AND terminalAuthorityHash IS NOT NULL AND redactedAt IS NOT NULL)
  )
);
CREATE INDEX artifact_storage_origin_camp
  ON artifact_storage_origin(campId, state, storageClass, classifiedAt);
CREATE TABLE discussion (
  id TEXT PRIMARY KEY NOT NULL,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  goalId TEXT REFERENCES goal_controller(id) ON DELETE RESTRICT,
  missionId TEXT REFERENCES mission(id) ON DELETE RESTRICT,
  cardId TEXT REFERENCES card(id) ON DELETE RESTRICT,
  purpose TEXT NOT NULL,
  participantActorIdsJson TEXT NOT NULL,
  maxRounds INTEGER NOT NULL CHECK (maxRounds BETWEEN 1 AND 3),
  tokenBudget INTEGER NOT NULL CHECK (tokenBudget > 0),
  spentTokens INTEGER NOT NULL DEFAULT 0 CHECK
    (spentTokens >= 0 AND spentTokens <= tokenBudget),
  status TEXT NOT NULL CHECK (status IN
    ('proposed','running','completed','blocked','canceled','failed')),
  requiredMaterialization TEXT NOT NULL CHECK (requiredMaterialization IN
    ('decision','handoff','outcome','verification','cardRevision','planRevision')),
  materializationType TEXT,
  materializationId TEXT,
  aggregateVersion INTEGER NOT NULL DEFAULT 1 CHECK (aggregateVersion >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  CHECK (goalId IS NOT NULL OR missionId IS NOT NULL OR cardId IS NOT NULL),
  CHECK (
    (status = 'completed'
      AND materializationType = requiredMaterialization
      AND materializationId IS NOT NULL)
    OR
    (status <> 'completed'
      AND materializationType IS NULL AND materializationId IS NULL)
  )
);

CREATE TABLE discussion_turn (
  id TEXT PRIMARY KEY NOT NULL,
  discussionId TEXT NOT NULL REFERENCES discussion(id) ON DELETE RESTRICT,
  round INTEGER NOT NULL CHECK (round BETWEEN 1 AND 3),
  sequence INTEGER NOT NULL CHECK (sequence >= 0),
  speakerActorId TEXT NOT NULL,
  contentRef TEXT NOT NULL,
  contentHash TEXT NOT NULL CHECK (length(contentHash) = 64),
  inputTokens INTEGER NOT NULL DEFAULT 0 CHECK (inputTokens >= 0),
  outputTokens INTEGER NOT NULL DEFAULT 0 CHECK (outputTokens >= 0),
  createdAt DATETIME NOT NULL,
  redactedAt DATETIME,
  UNIQUE(discussionId, sequence),
  CHECK (redactedAt IS NULL OR contentRef = '')
);
CREATE INDEX discussion_turn_round
  ON discussion_turn(discussionId, round, sequence);
CREATE TABLE attention_item (
  id TEXT PRIMARY KEY NOT NULL,
  sourceEventId TEXT NOT NULL REFERENCES domain_event(id) ON DELETE RESTRICT,
  level TEXT NOT NULL CHECK
    (level IN ('recordOnly','summary','needsAction','urgent')),
  dedupeKey TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL CHECK
    (status IN ('open','acknowledged','dismissed','resolved')),
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  goalId TEXT REFERENCES goal_controller(id) ON DELETE RESTRICT,
  missionId TEXT REFERENCES mission(id) ON DELETE RESTRICT,
  dueAt DATETIME,
  escalationAt DATETIME,
  aggregateVersion INTEGER NOT NULL DEFAULT 1 CHECK (aggregateVersion >= 1),
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL
);
CREATE INDEX attention_item_open
  ON attention_item(status, level, dueAt, escalationAt);

CREATE TABLE growth_evidence (
  id TEXT PRIMARY KEY NOT NULL,
  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
  track TEXT NOT NULL CHECK (track IN ('capability','relationship','world')),
  subjectType TEXT NOT NULL CHECK (subjectType IN ('cow','camp','world')),
  subjectId TEXT NOT NULL,
  outcomeId TEXT REFERENCES outcome(id) ON DELETE RESTRICT,
  outcomeVersion INTEGER,
  verificationId TEXT
    REFERENCES verification_record(id) ON DELETE RESTRICT,
  acceptanceId TEXT REFERENCES acceptance_record(id) ON DELETE RESTRICT,
  sourceEventId TEXT REFERENCES domain_event(id) ON DELETE RESTRICT,
  evidenceHash TEXT NOT NULL CHECK (length(evidenceHash) = 64),
  status TEXT NOT NULL CHECK (status IN ('proposed','active','invalidated')),
  invalidatedByEventId TEXT REFERENCES domain_event(id) ON DELETE RESTRICT,
  createdAt DATETIME NOT NULL,
  invalidatedAt DATETIME,
  CHECK (
    (track = 'capability'
      AND outcomeId IS NOT NULL AND outcomeVersion IS NOT NULL
      AND verificationId IS NOT NULL AND acceptanceId IS NOT NULL)
    OR
    (track IN ('relationship','world') AND sourceEventId IS NOT NULL)
  ),
  CHECK (
    (status = 'invalidated'
      AND invalidatedByEventId IS NOT NULL AND invalidatedAt IS NOT NULL)
    OR
    (status <> 'invalidated'
      AND invalidatedByEventId IS NULL AND invalidatedAt IS NULL)
  )
);
CREATE INDEX growth_evidence_subject
  ON growth_evidence(subjectType, subjectId, track, status);

-- MIGRATION PHASE BARRIER: the real Swift migrator performs legacy artifact
-- origin backfill plus count/FK assertions here.  Trigger installation is the
-- final phase and is skipped entirely if backfill/assertion fails.
-- Every v17 trigger is installed only after the complete
-- Engine/Artifact/Discussion/Attention/Growth table and index graph exists.
CREATE TRIGGER engine_session_first_redaction_exact
BEFORE UPDATE ON engine_session
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.id = OLD.id
  AND NEW.campId = OLD.campId
  AND NEW.adapterId = OLD.adapterId
  AND NEW.adapterVersion = OLD.adapterVersion
  AND NEW.profileId = OLD.profileId
  AND NEW.externalSessionId IS NULL
  AND NEW.workspaceHash = OLD.workspaceHash
  AND NEW.sessionScopeJson = '{}'
  AND NEW.sessionScopeHash = OLD.sessionScopeHash
  AND NEW.state = 'invalid'
  AND NEW.version = OLD.version + 1
  AND NEW.createdAt = OLD.createdAt
  AND NEW.updatedAt = NEW.redactedAt
  AND EXISTS (
    SELECT 1 FROM camp_lifecycle l
    JOIN camp_deletion_job j ON j.campId = l.campId
    WHERE l.campId = OLD.campId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN SELECT RAISE(ABORT, 'engine session redaction diff is invalid'); END;
CREATE TRIGGER engine_session_post_redaction_lock
BEFORE UPDATE ON engine_session WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'engine session is immutable after redaction'); END;
CREATE TRIGGER engine_session_reject_delete
BEFORE DELETE ON engine_session
BEGIN SELECT RAISE(ABORT, 'engine session may not be deleted'); END;

CREATE TRIGGER engine_execution_first_redaction_exact
BEFORE UPDATE ON engine_execution
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.id = OLD.id
  AND NEW.campId = OLD.campId
  AND NEW.campLifecycleVersion = OLD.campLifecycleVersion
  AND NEW.idempotencyKey = OLD.idempotencyKey
  AND NEW.runId = OLD.runId
  AND NEW.cardId = OLD.cardId
  AND NEW.adapterId = OLD.adapterId
  AND NEW.adapterVersion = OLD.adapterVersion
  AND NEW.profileId = OLD.profileId
  AND NEW.engineKind = OLD.engineKind
  AND NEW.model = OLD.model
  AND NEW.requestJson = '{}'
  AND NEW.requestHash = OLD.requestHash
  AND NEW.contextJson = '{}'
  AND NEW.contextHash = OLD.contextHash
  AND NEW.sessionScopeJson = '{}'
  AND NEW.sessionScopeHash = OLD.sessionScopeHash
  AND NEW.sessionId IS OLD.sessionId
  AND NEW.replayClass = OLD.replayClass
  AND NEW.dispatchState = OLD.dispatchState
  AND OLD.dispatchState = 'terminal'
  AND NEW.state = OLD.state AND OLD.state <> 'running'
  AND NEW.terminalSubtype IS OLD.terminalSubtype
  AND NEW.nextSequence = OLD.nextSequence
  AND NEW.terminalReceiptIdempotencyKey IS OLD.terminalReceiptIdempotencyKey
  AND NEW.terminalReceiptHash IS OLD.terminalReceiptHash
  AND NEW.inputTokens = OLD.inputTokens
  AND NEW.outputTokens = OLD.outputTokens
  AND NEW.cacheReadTokens = OLD.cacheReadTokens
  AND NEW.costMicros = OLD.costMicros
  AND NEW.version = OLD.version + 1
  AND NEW.createdAt = OLD.createdAt
  AND NEW.updatedAt = NEW.redactedAt
  AND NEW.dispatchStartedAt IS OLD.dispatchStartedAt
  AND NEW.cancellationRequestedAt IS OLD.cancellationRequestedAt
  AND (
    (OLD.cancellationRequestedAt IS NULL AND NEW.cancellationReason IS NULL)
    OR
    (OLD.cancellationRequestedAt IS NOT NULL
      AND NEW.cancellationReason = 'camp_deleted')
  )
  AND NEW.finishedAt IS OLD.finishedAt
  AND EXISTS (
    SELECT 1 FROM camp_lifecycle l
    JOIN camp_deletion_job j ON j.campId = l.campId
    WHERE l.campId = OLD.campId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN SELECT RAISE(ABORT, 'engine execution redaction diff is invalid'); END;
CREATE TRIGGER engine_execution_post_redaction_lock
BEFORE UPDATE ON engine_execution WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'engine execution is immutable after redaction'); END;
CREATE TRIGGER engine_execution_reject_delete
BEFORE DELETE ON engine_execution
BEGIN SELECT RAISE(ABORT, 'engine execution may not be deleted'); END;

CREATE TRIGGER engine_terminal_proposal_first_redaction_exact
BEFORE UPDATE ON engine_terminal_proposal
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.id = OLD.id
  AND NEW.executionId = OLD.executionId
  AND NEW.terminalIdempotencyKey = OLD.terminalIdempotencyKey
  AND NEW.sequence = OLD.sequence
  AND NEW.terminalKind = OLD.terminalKind
  AND NEW.terminalSubtype IS OLD.terminalSubtype
  AND NEW.proposalJson = '{}'
  AND NEW.proposalHash = OLD.proposalHash
  AND NEW.payloadJson = '{}'
  AND NEW.payloadHash = OLD.payloadHash
  AND NEW.artifactManifestJson = '[]'
  AND NEW.artifactManifestHash = OLD.artifactManifestHash
  AND NEW.state = OLD.state AND OLD.state IN ('committed','invalid')
  AND NEW.version = OLD.version + 1
  AND NEW.createdAt = OLD.createdAt
  AND NEW.committedAt IS OLD.committedAt
  AND (
    (OLD.state = 'committed' AND NEW.invalidReason IS NULL)
    OR
    (OLD.state = 'invalid' AND NEW.invalidReason = 'camp_deleted')
  )
  AND NEW.invalidatedAt IS OLD.invalidatedAt
  AND EXISTS (
    SELECT 1 FROM engine_execution x
    JOIN camp_lifecycle l ON l.campId = x.campId
    JOIN camp_deletion_job j ON j.campId = x.campId
    WHERE x.id = OLD.executionId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN SELECT RAISE(ABORT, 'engine proposal redaction diff is invalid'); END;
CREATE TRIGGER engine_terminal_proposal_post_redaction_lock
BEFORE UPDATE ON engine_terminal_proposal WHEN OLD.redactedAt IS NOT NULL
BEGIN SELECT RAISE(ABORT, 'engine proposal is immutable after redaction'); END;
CREATE TRIGGER engine_terminal_proposal_reject_delete
BEFORE DELETE ON engine_terminal_proposal
BEGIN SELECT RAISE(ABORT, 'engine proposal may not be deleted'); END;

CREATE TRIGGER engine_proposal_artifact_reject_private_field_update
BEFORE UPDATE ON engine_proposal_artifact
WHEN (
  NEW.sourceRelativePath IS NOT OLD.sourceRelativePath
  OR NEW.kind IS NOT OLD.kind
  OR NEW.label IS NOT OLD.label
  OR NEW.redactedAt IS NOT OLD.redactedAt
)
AND NOT (
  NEW.id = OLD.id
  AND NEW.proposalId = OLD.proposalId
  AND NEW.artifactId = OLD.artifactId
  AND NEW.ordinal = OLD.ordinal
  AND NEW.sourceRelativePath = ''
  AND NEW.kind = 'tombstone'
  AND NEW.label = '[deleted]'
  AND NEW.byteCount = OLD.byteCount
  AND NEW.contentHash = OLD.contentHash
  AND NEW.state = OLD.state
  AND NEW.preparedAt IS OLD.preparedAt
  AND NEW.version = OLD.version
  AND OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM engine_terminal_proposal p
    JOIN engine_execution x ON x.id = p.executionId
    JOIN camp_lifecycle l ON l.campId = x.campId
    JOIN camp_deletion_job j ON j.campId = x.campId
    WHERE p.id = OLD.proposalId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN
  SELECT RAISE(ABORT, 'proposal artifact private fields are immutable');
END;
CREATE TRIGGER engine_proposal_artifact_post_redaction_lock
BEFORE UPDATE ON engine_proposal_artifact
WHEN OLD.redactedAt IS NOT NULL
BEGIN
  SELECT RAISE(ABORT, 'proposal artifact is immutable after redaction');
END;
CREATE TRIGGER engine_proposal_artifact_reject_delete
BEFORE DELETE ON engine_proposal_artifact
BEGIN
  SELECT RAISE(ABORT, 'proposal artifact may not be deleted');
END;

CREATE TRIGGER artifact_storage_origin_first_redaction_exact
BEFORE UPDATE ON artifact_storage_origin
WHEN OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
AND NOT (
  NEW.artifactId = OLD.artifactId
  AND NEW.campId = OLD.campId
  AND NEW.state = 'tombstoned'
  AND NEW.storageClass = OLD.storageClass
  AND NEW.evidenceKind = OLD.evidenceKind
  AND NEW.managedRootId IS NULL AND NEW.objectId IS NULL
  AND NEW.contentHash IS OLD.contentHash
  AND NEW.fileIdentityHash IS OLD.fileIdentityHash
  AND NEW.originalRefHash = OLD.originalRefHash
  AND NEW.classificationEvidenceHash = OLD.classificationEvidenceHash
  AND NEW.terminalDisposition IS NOT NULL
  AND NEW.terminalAuthorityHash IS NOT NULL
  AND NEW.version = OLD.version + 1
  AND NEW.classifiedAt = OLD.classifiedAt
  AND EXISTS (
    SELECT 1 FROM camp_lifecycle l
    JOIN camp_deletion_job j ON j.campId = l.campId
    WHERE l.campId = OLD.campId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN
  SELECT RAISE(ABORT, 'artifact origin redaction diff is invalid');
END;
CREATE TRIGGER artifact_storage_origin_post_redaction_lock
BEFORE UPDATE ON artifact_storage_origin
WHEN OLD.redactedAt IS NOT NULL
BEGIN
  SELECT RAISE(ABORT, 'artifact origin is immutable after redaction');
END;
CREATE TRIGGER artifact_storage_origin_reject_delete
BEFORE DELETE ON artifact_storage_origin
BEGIN
  SELECT RAISE(ABORT, 'artifact origin may not be deleted');
END;

CREATE TRIGGER discussion_turn_reject_update_except_camp_redaction
BEFORE UPDATE ON discussion_turn
WHEN NOT (
  NEW.id = OLD.id
  AND NEW.discussionId = OLD.discussionId
  AND NEW.round = OLD.round
  AND NEW.sequence = OLD.sequence
  AND NEW.speakerActorId = OLD.speakerActorId
  AND NEW.contentRef = ''
  AND NEW.contentHash = OLD.contentHash
  AND NEW.inputTokens = OLD.inputTokens
  AND NEW.outputTokens = OLD.outputTokens
  AND NEW.createdAt = OLD.createdAt
  AND OLD.redactedAt IS NULL AND NEW.redactedAt IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM discussion d
    JOIN camp_lifecycle l ON l.campId = d.campId
    JOIN camp_deletion_job j ON j.campId = d.campId
    WHERE d.id = OLD.discussionId
      AND l.state = 'deleting' AND j.state = 'finalizing'
  )
)
BEGIN
  SELECT RAISE(ABORT, 'discussion_turn is append-only');
END;
CREATE TRIGGER discussion_turn_reject_delete
BEFORE DELETE ON discussion_turn
BEGIN
  SELECT RAISE(ABORT, 'discussion_turn is append-only');
END;

"""
// P1-F1-END V17EngineCoordinationSQL

package struct P1F1MigrationIntegrityError:
    Error, Equatable, Sendable, CustomStringConvertible
{
    package let code: String
    package let subject: String

    package init(code: String, subject: String) {
        self.code = code
        self.subject = subject
    }

    package var description: String {
        "P1-F1 migration integrity failure [\(code)]: \(subject)"
    }
}

private struct LegacyArtifactOriginAttestationV1: Encodable {
    let schemaVersion: Int
    let artifactId: String
    let cardId: String
    let campId: String
    let originalRefHash: String
}

private struct LegacyArtifactOriginJoinedRowV1 {
    let artifactId: String
    let cardId: String
    let persistedPath: String
    let campId: String
}

package enum LegacyArtifactOriginMigrationV1 {
    package static func backfill(in database: Database) throws {
        let sourceCount = try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM artifact"
        ) ?? -1
        let rows = try joinedArtifacts(in: database)
        guard sourceCount == rows.count else {
            let missing = try String.fetchAll(
                database,
                sql: """
                    SELECT a.id
                    FROM artifact AS a
                    LEFT JOIN card AS c ON c.id = a.cardId
                    LEFT JOIN mission AS m ON m.id = c.missionId
                    LEFT JOIN squad AS s ON s.id = m.squadId
                    LEFT JOIN camp ON camp.id = s.campId
                    WHERE c.id IS NULL OR m.id IS NULL
                       OR s.id IS NULL OR camp.id IS NULL
                    ORDER BY a.id
                    """
            )
            throw P1F1MigrationIntegrityError(
                code: "v17_legacy_artifact_join_mismatch",
                subject: "source=\(sourceCount),joined=\(rows.count),ids=\(missing.joined(separator: ","))"
            )
        }

        for row in rows {
            let originalRefHash = CanonicalJSONV1.sha256Hex(
                Data(row.persistedPath.utf8)
            )
            let attestation = LegacyArtifactOriginAttestationV1(
                schemaVersion: 1,
                artifactId: row.artifactId,
                cardId: row.cardId,
                campId: row.campId,
                originalRefHash: originalRefHash
            )
            let evidenceBytes: Data
            do {
                evidenceBytes = try CanonicalJSONV1.encode(attestation)
            } catch {
                throw P1F1MigrationIntegrityError(
                    code: "v17_legacy_attestation_encoding",
                    subject: row.artifactId
                )
            }
            let classificationEvidenceHash = CanonicalJSONV1.sha256Hex(
                evidenceBytes
            )
            try database.execute(
                sql: """
                    INSERT INTO artifact_storage_origin(
                      artifactId,campId,state,storageClass,evidenceKind,
                      managedRootId,objectId,contentHash,fileIdentityHash,
                      originalRefHash,classificationEvidenceHash,
                      terminalDisposition,terminalAuthorityHash,
                      version,classifiedAt,redactedAt
                    )
                    SELECT a.id,?,'active','unresolved','legacyUnknown',
                           NULL,NULL,NULL,NULL,?,?,NULL,NULL,1,a.createdAt,NULL
                    FROM artifact AS a
                    WHERE a.id=?
                    """,
                arguments: [
                    row.campId,
                    originalRefHash,
                    classificationEvidenceHash,
                    row.artifactId,
                ]
            )
            guard database.changesCount == 1 else {
                throw P1F1MigrationIntegrityError(
                    code: "v17_legacy_artifact_insert_count",
                    subject: row.artifactId
                )
            }
        }
    }

    package static func assertBarrier(in database: Database) throws {
        let sourceCount = try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM artifact"
        ) ?? -1
        let joinedRows = try joinedArtifacts(in: database)
        let originCount = try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM artifact_storage_origin"
        ) ?? -1
        let duplicateCount = try Int.fetchOne(
            database,
            sql: """
                SELECT COUNT(*) FROM (
                  SELECT artifactId
                  FROM artifact_storage_origin
                  GROUP BY artifactId
                  HAVING COUNT(*) <> 1
                )
                """
        ) ?? -1
        guard sourceCount == joinedRows.count,
              sourceCount == originCount,
              duplicateCount == 0
        else {
            throw P1F1MigrationIntegrityError(
                code: "v17_legacy_artifact_origin_count_mismatch",
                subject: "source=\(sourceCount),joined=\(joinedRows.count),origin=\(originCount),duplicates=\(duplicateCount)"
            )
        }

        let shapeMismatches = try String.fetchAll(
            database,
            sql: """
                SELECT a.id
                FROM artifact AS a
                JOIN card AS c ON c.id=a.cardId
                JOIN mission AS m ON m.id=c.missionId
                JOIN squad AS s ON s.id=m.squadId
                JOIN camp ON camp.id=s.campId
                LEFT JOIN artifact_storage_origin AS o ON o.artifactId=a.id
                WHERE o.artifactId IS NULL
                   OR o.campId<>camp.id
                   OR o.state<>'active'
                   OR o.storageClass<>'unresolved'
                   OR o.evidenceKind<>'legacyUnknown'
                   OR o.managedRootId IS NOT NULL
                   OR o.objectId IS NOT NULL
                   OR o.contentHash IS NOT NULL
                   OR o.fileIdentityHash IS NOT NULL
                   OR o.terminalDisposition IS NOT NULL
                   OR o.terminalAuthorityHash IS NOT NULL
                   OR o.version<>1
                   OR o.classifiedAt IS NOT a.createdAt
                   OR o.redactedAt IS NOT NULL
                ORDER BY a.id
                """
        )
        guard shapeMismatches.isEmpty else {
            throw P1F1MigrationIntegrityError(
                code: "v17_legacy_artifact_origin_shape_mismatch",
                subject: shapeMismatches.joined(separator: ",")
            )
        }

        let originRows = try Row.fetchAll(
            database,
            sql: """
                SELECT a.id AS artifactId,
                       c.id AS cardId,
                       a.path AS persistedPath,
                       camp.id AS campId,
                       o.originalRefHash AS originalRefHash,
                       o.classificationEvidenceHash AS classificationEvidenceHash
                FROM artifact AS a
                JOIN card AS c ON c.id=a.cardId
                JOIN mission AS m ON m.id=c.missionId
                JOIN squad AS s ON s.id=m.squadId
                JOIN camp ON camp.id=s.campId
                JOIN artifact_storage_origin AS o ON o.artifactId=a.id
                ORDER BY a.id
                """
        )
        for row in originRows {
            let artifactId: String = row["artifactId"]
            let cardId: String = row["cardId"]
            let persistedPath: String = row["persistedPath"]
            let campId: String = row["campId"]
            let storedOriginalRefHash: String = row["originalRefHash"]
            let storedClassificationHash: String =
                row["classificationEvidenceHash"]
            let originalRefHash = CanonicalJSONV1.sha256Hex(
                Data(persistedPath.utf8)
            )
            let attestation = LegacyArtifactOriginAttestationV1(
                schemaVersion: 1,
                artifactId: artifactId,
                cardId: cardId,
                campId: campId,
                originalRefHash: originalRefHash
            )
            let evidenceBytes: Data
            do {
                evidenceBytes = try CanonicalJSONV1.encode(attestation)
            } catch {
                throw P1F1MigrationIntegrityError(
                    code: "v17_legacy_attestation_encoding",
                    subject: artifactId
                )
            }
            guard storedOriginalRefHash == originalRefHash,
                  storedClassificationHash
                    == CanonicalJSONV1.sha256Hex(evidenceBytes)
            else {
                throw P1F1MigrationIntegrityError(
                    code: "v17_legacy_artifact_origin_hash_mismatch",
                    subject: artifactId
                )
            }
        }

        let foreignKeyFailures = try Row.fetchAll(
            database,
            sql: "PRAGMA foreign_key_check"
        )
        guard foreignKeyFailures.isEmpty else {
            throw P1F1MigrationIntegrityError(
                code: "v17_foreign_key_check",
                subject: "count=\(foreignKeyFailures.count)"
            )
        }
    }

    private static func joinedArtifacts(
        in database: Database
    ) throws -> [LegacyArtifactOriginJoinedRowV1] {
        try Row.fetchAll(
            database,
            sql: """
                SELECT a.id AS artifactId,
                       c.id AS cardId,
                       a.path AS persistedPath,
                       camp.id AS campId
                FROM artifact AS a
                JOIN card AS c ON c.id = a.cardId
                JOIN mission AS m ON m.id = c.missionId
                JOIN squad AS s ON s.id = m.squadId
                JOIN camp ON camp.id = s.campId
                ORDER BY a.id
                """
        ).map { row in
            LegacyArtifactOriginJoinedRowV1(
                artifactId: row["artifactId"],
                cardId: row["cardId"],
                persistedPath: row["persistedPath"],
                campId: row["campId"]
            )
        }
    }
}


// MARK: - AppDatabase

package struct EngineCardReadyCauseV1: Sendable, Equatable {
    package let eventId: String
    package let idempotencyKey: String
    package let answeredRequestId: String?
    package let causalPredecessorExecutionId: String?

    package init(
        eventId: String,
        idempotencyKey: String,
        answeredRequestId: String?,
        causalPredecessorExecutionId: String?
    ) {
        self.eventId = eventId
        self.idempotencyKey = idempotencyKey
        self.answeredRequestId = answeredRequestId
        self.causalPredecessorExecutionId = causalPredecessorExecutionId
    }
}

package struct EngineCardReadyObservationV1: Sendable, Equatable {
    package let cardId: String
    package let cardStatus: CardStatus
    package let latestTransitionEventId: String?
    package let latestTransitionKind: String?

    package init(
        cardId: String,
        cardStatus: CardStatus,
        latestTransitionEventId: String?,
        latestTransitionKind: String?
    ) {
        self.cardId = cardId
        self.cardStatus = cardStatus
        self.latestTransitionEventId = latestTransitionEventId
        self.latestTransitionKind = latestTransitionKind
    }
}

package enum EngineCardReadyCauseErrorV1: Error, Sendable, Equatable {
    case missingCurrentReadyEvent(EngineCardReadyObservationV1)
    case malformedReadyEvent(
        observation: EngineCardReadyObservationV1,
        eventId: String
    )
    case ambiguousAnsweredRequest(
        observation: EngineCardReadyObservationV1,
        requestId: String
    )
    case brokenPredecessorGraph(
        observation: EngineCardReadyObservationV1,
        requestId: String
    )
}

public final class AppDatabase: Sendable {
    package let activeIngestionDeletionSQLPermitRegistry: ActiveIngestionDeletionSQLPermitRegistryV1
    public let pool: DatabasePool
    private static let logger = Logger(subsystem: "com.muzi.agentloop", category: "database")

    public init(path: String) throws {
        let registry = ActiveIngestionDeletionSQLPermitRegistryV1()
        activeIngestionDeletionSQLPermitRegistry = registry
        var cfg = Configuration()
        cfg.journalMode = .wal
        cfg.busyMode = .timeout(5)
        cfg.prepareDatabase { db in
            try registry.installConnectionUDF(on: db)
        }
        pool = try DatabasePool(path: path, configuration: cfg)
        try Self.migrator.migrate(pool)
        try pool.writeWithoutTransaction { db in
            try LegacyContentScopeStore.installConnectionGuards(on: db)
        }
    }

    // MARK: Migration v1 — all spec §4.2 tables (forward-compatible; M1 uses a subset)

    public static var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()
        m.registerMigration("v1") { db in
            // camp
            try db.create(table: "camp") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            // companion
            try db.create(table: "companion") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("color", .text).notNull()
                t.column("rolePrompt", .text).notNull()
                t.column("model", .text).notNull()
                t.column("toolsJson", .text).notNull()
                t.column("kind", .text).notNull().defaults(to: "regular")
                t.column("campId", .text).references("camp")
                t.column("createdAt", .datetime).notNull()
            }
            // squad
            try db.create(table: "squad") { t in
                t.primaryKey("id", .text)
                t.column("campId", .text).notNull().references("camp")
                t.column("name", .text).notNull()
                t.column("memberIdsJson", .text).notNull()
                t.column("workspacePath", .text)
                t.column("createdAt", .datetime).notNull()
            }
            // mission
            try db.create(table: "mission") { t in
                t.primaryKey("id", .text)
                t.column("squadId", .text).notNull().references("squad")
                t.column("goalRaw", .text).notNull()
                t.column("goalRefined", .text).notNull()
                t.column("status", .text).notNull()
                t.column("budgetTokens", .integer).notNull()
                t.column("spentTokens", .integer).notNull().defaults(to: 0)
                t.column("revision", .integer).notNull().defaults(to: 1)
                t.column("createdAt", .datetime).notNull()
            }
            // card
            try db.create(table: "card") { t in
                t.primaryKey("id", .text)
                t.column("missionId", .text).notNull().references("mission")
                t.column("idemKey", .text).notNull().unique()
                t.column("title", .text).notNull()
                t.column("descriptionText", .text).notNull()
                t.column("expectedOutput", .text).notNull()
                t.column("assigneeId", .text)
                t.column("status", .text).notNull()
                t.column("blockedReasonJson", .text)
                t.column("dependsOnJson", .text).notNull().defaults(to: "[]")
                t.column("maxTurns", .integer).notNull()
                t.column("tokenBudget", .integer).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            // run
            try db.create(table: "run") { t in
                t.primaryKey("id", .text)
                t.column("cardId", .text).notNull().references("card")
                t.column("attempt", .integer).notNull()
                t.column("outcome", .text)
                t.column("turns", .integer).notNull().defaults(to: 0)
                t.column("tokensIn", .integer).notNull().defaults(to: 0)
                t.column("tokensOut", .integer).notNull().defaults(to: 0)
                t.column("startedAt", .datetime).notNull()
                t.column("endedAt", .datetime)
            }
            // event (append-only — never UPDATE/DELETE)
            try db.create(table: "event") { t in
                t.primaryKey("id", .text)
                t.column("missionId", .text)
                t.column("cardId", .text)
                t.column("runId", .text)
                t.column("kind", .text).notNull()
                t.column("payloadJson", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            // artifact
            try db.create(table: "artifact") { t in
                t.primaryKey("id", .text)
                t.column("cardId", .text).notNull().references("card")
                t.column("path", .text).notNull()
                t.column("kind", .text).notNull()
                t.column("label", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            // camp_note (M1 schema-only — not read/written in M1)
            try db.create(table: "camp_note") { t in
                t.primaryKey("id", .text)
                t.column("campId", .text).notNull().references("camp")
                t.column("missionId", .text).references("mission") // FK Fix 5
                t.column("title", .text).notNull()
                t.column("bodyMd", .text).notNull()
                t.column("pinned", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            // user_request (M1 schema-only — not read/written in M1)
            try db.create(table: "user_request") { t in
                t.primaryKey("id", .text)
                t.column("cardId", .text).notNull().references("card")
                t.column("kind", .text).notNull()
                t.column("prompt", .text).notNull()
                t.column("optionsJson", .text)
                t.column("answerJson", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("answeredAt", .datetime)
            }
            // chat_thread (Fix 5: campId FK)
            try db.create(table: "chat_thread") { t in
                t.primaryKey("id", .text)
                t.column("kind", .text).notNull()
                t.column("companionId", .text).notNull().references("companion")
                t.column("campId", .text).references("camp") // FK Fix 5
                t.column("createdAt", .datetime).notNull()
            }
            // chat_message
            try db.create(table: "chat_message") { t in
                t.primaryKey("id", .text)
                t.column("threadId", .text).notNull().references("chat_thread").indexed() // Fix 5: index
                t.column("role", .text).notNull()
                t.column("contentJson", .text).notNull()
                t.column("distilled", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
            }

            // Fix 5: additional indexes for hot query paths
            try db.create(index: "event_cardId", on: "event", columns: ["cardId"])
            try db.create(index: "run_cardId", on: "run", columns: ["cardId"])
            try db.create(index: "artifact_cardId", on: "artifact", columns: ["cardId"])

            // Fix 5: append-only enforcement for event table via SQLite triggers
            try db.execute(sql: """
                CREATE TRIGGER event_no_update BEFORE UPDATE ON event BEGIN
                    SELECT RAISE(ABORT, 'event is append-only');
                END
                """)
            try db.execute(sql: """
                CREATE TRIGGER event_no_delete BEFORE DELETE ON event BEGIN
                    SELECT RAISE(ABORT, 'event is append-only');
                END
                """)
        }
        m.registerMigration("v2") { db in
            try db.alter(table: "card") { t in
                t.add(column: "handoffJson", .text)
                t.add(column: "stage", .integer).notNull().defaults(to: 1)
            }
            try db.execute(sql: """
                UPDATE mission SET status = 'executing'
                WHERE status NOT IN ('planning','executing','delivering','accepted','failed')
                """)
        }
        // M4: 伙伴记忆表（v1 只建了 camp_note；companion_note 是 M4 补齐的缺口）
        m.registerMigration("v3") { db in
            try db.create(table: "companion_note") { t in
                t.primaryKey("id", .text)
                t.column("companionId", .text).notNull().references("companion").indexed()
                t.column("sourceThreadId", .text).references("chat_thread")
                t.column("title", .text).notNull()
                t.column("bodyMd", .text).notNull()
                t.column("pinned", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(index: "camp_note_campId", on: "camp_note", columns: ["campId"])
        }
        // M5-1: 安全作用域书签（沙箱下重启恢复工作目录权限）
        m.registerMigration("v4") { db in
            try db.alter(table: "squad") { t in
                t.add(column: "workspaceBookmark", .blob)
            }
        }
        // M7-D2: 行动自主档位（谨慎/标准/放手），决定工具审批矩阵
        m.registerMigration("v5") { db in
            try db.alter(table: "mission") { t in
                t.add(column: "autonomy", .text).notNull().defaults(to: "standard")
            }
        }
        // M8-D2: MCP 驿站——全局注册表 + 营地级启用关联（频道隔离与 M5-0 一致）。
        // 敏感 env 值不落库（secretEnvKeysJson 只存 key 名，值在 Keychain，M8-D5）。
        m.registerMigration("v6") { db in
            try db.create(table: "mcp_server") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull().unique()
                t.column("command", .text).notNull()
                t.column("argsJson", .text).notNull().defaults(to: "[]")
                t.column("envJson", .text).notNull().defaults(to: "{}")
                t.column("secretEnvKeysJson", .text).notNull().defaults(to: "[]")
                t.column("experimental", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "camp_mcp_enable") { t in
                t.column("campId", .text).notNull().references("camp")
                t.column("serverId", .text).notNull().references("mcp_server")
                t.primaryKey(["campId", "serverId"])
            }
        }
        // P0 durable halt: global kernel dispatch gate. This descriptive id is
        // intentionally inserted before the v7 id reserved by M9.
        m.registerMigration("v6-durable-halt") { db in
            try db.create(table: "kernel_control") { t in
                t.primaryKey("id", .text).check(sql: "id = 'global'")
                t.column("dispatchMode", .text).notNull()
                    .check(sql: "dispatchMode IN ('running', 'halted')")
                t.column("updatedAt", .datetime).notNull()
            }
            try KernelControlRecord(
                id: "global",
                dispatchMode: .running,
                updatedAt: Date()
            ).insert(db)
        }
        // M9-D4/D6: done-card review flags + camp archive bit. Both are projections;
        // event history remains append-only.
        m.registerMigration("v7") { db in
            try db.alter(table: "card") { t in
                t.add(column: "reviewFlag", .text)
            }
            try db.alter(table: "camp") { t in
                t.add(column: "archived", .boolean).notNull().defaults(to: false)
            }
        }
        // Coding 牧场 MVP：主动喂牛、反刍、来源与行动候选。
        m.registerMigration("v8-coding-ranch") { db in
            try db.create(table: "ingestion_item") { t in
                t.primaryKey("id", .text)
                t.column("campId", .text).notNull().references("camp")
                t.column("sourceType", .text).notNull()
                t.column("title", .text)
                t.column("rawText", .text).notNull()
                t.column("sourceURL", .text)
                t.column("author", .text)
                t.column("userIntent", .text)
                t.column("contentHash", .text).notNull()
                t.column("status", .text).notNull()
                t.column("attempt", .integer).notNull().defaults(to: 0)
                t.column("errorText", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(index: "ingestion_item_camp_status", on: "ingestion_item", columns: ["campId", "status"])
            try db.create(index: "ingestion_item_camp_hash", on: "ingestion_item", columns: ["campId", "contentHash"])

            try db.create(table: "rumination_result") { t in
                t.primaryKey("id", .text)
                t.column("ingestionId", .text).notNull().unique().references("ingestion_item")
                t.column("pipelineVersion", .text).notNull()
                t.column("resultJson", .text).notNull()
                t.column("userEditedJson", .text)
                t.column("materializedAt", .datetime)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            try db.create(table: "knowledge_source_link") { t in
                t.primaryKey("id", .text)
                t.column("campNoteId", .text).notNull().references("camp_note")
                t.column("ingestionId", .text).notNull().references("ingestion_item")
                t.column("locatorJson", .text)
                t.column("createdAt", .datetime).notNull()
                t.uniqueKey(["campNoteId", "ingestionId"])
            }
            try db.create(index: "knowledge_source_ingestion", on: "knowledge_source_link", columns: ["ingestionId"])

            try db.create(table: "action_candidate") { t in
                t.primaryKey("id", .text)
                t.column("ingestionId", .text).notNull().references("ingestion_item")
                t.column("campId", .text).notNull().references("camp")
                t.column("type", .text).notNull()
                t.column("title", .text).notNull()
                t.column("detailJson", .text).notNull()
                t.column("status", .text).notNull()
                t.column("missionId", .text).references("mission")
                t.column("idemKey", .text).notNull().unique()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(index: "action_candidate_camp_status", on: "action_candidate", columns: ["campId", "status"])
        }
        // M10: 长明火定时行动。v8 已被 Coding 牧场 MVP 占用，本轮必须注册为 v9-evercamp。
        m.registerMigration("v9-evercamp") { db in
            let templateExists = try db.tableExists("mission_template")
            let scheduleExists = try db.tableExists("schedule")

            if templateExists || scheduleExists {
                guard templateExists && scheduleExists else {
                    throw DatabaseError(message: "legacy Evercamp schema is incomplete: mission_template and schedule must both exist")
                }

                // A pre-release build registered these tables as migration `v8`.
                // Released builds use `v8-coding-ranch` + `v9-evercamp`, so validate
                // that legacy shape before adopting it instead of blindly recreating
                // tables or silently accepting a corrupt partial migration.
                let requiredColumns: [(String, Set<String>)] = [
                    ("mission_template", [
                        "id", "name", "goal", "companionIdsJson", "workspacePath",
                        "budgetTokens", "autonomy", "campId", "createdAt",
                    ]),
                    ("schedule", [
                        "id", "templateId", "frequency", "hour", "minute", "weekday",
                        "enabled", "lastFiredAt", "createdAt",
                    ]),
                ]
                for (table, required) in requiredColumns {
                    let actual = Set(try db.columns(in: table).map(\.name))
                    let missing = required.subtracting(actual).sorted()
                    guard missing.isEmpty else {
                        throw DatabaseError(message: "legacy Evercamp table \(table) is missing columns: \(missing.joined(separator: ", "))")
                    }
                }
                Self.logger.notice("Adopting validated legacy Evercamp v8 tables as v9-evercamp")
            } else {
                try db.create(table: "mission_template") { t in
                    t.primaryKey("id", .text)
                    t.column("name", .text).notNull()
                    t.column("goal", .text).notNull()
                    t.column("companionIdsJson", .text).notNull()
                    t.column("workspacePath", .text)
                    t.column("budgetTokens", .integer).notNull()
                    t.column("autonomy", .text).notNull()
                    t.column("campId", .text).notNull().references("camp")
                    t.column("createdAt", .datetime).notNull()
                }

                try db.create(table: "schedule") { t in
                    t.primaryKey("id", .text)
                    t.column("templateId", .text).notNull().references("mission_template")
                    t.column("frequency", .text).notNull()
                        .check(sql: "frequency IN ('daily', 'weekly')")
                    t.column("hour", .integer).notNull()
                        .check(sql: "hour >= 0 AND hour <= 23")
                    t.column("minute", .integer).notNull()
                        .check(sql: "minute >= 0 AND minute <= 59")
                    t.column("weekday", .integer)
                        .check(sql: "weekday IS NULL OR (weekday >= 1 AND weekday <= 7)")
                    t.column("enabled", .boolean).notNull().defaults(to: false)
                    t.column("lastFiredAt", .datetime)
                    t.column("createdAt", .datetime).notNull()
                }
            }
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS mission_template_camp ON mission_template(campId, createdAt)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS schedule_template ON schedule(templateId)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS schedule_enabled ON schedule(enabled, templateId)")
        }
        m.registerMigration("v10-runtime-profiles") { db in
            try db.create(table: "runtime_profile") { t in
                t.primaryKey("id", .text)
                t.column("kind", .text).notNull()
                    .check(sql: "kind IN ('anthropic_api', 'openai_api', 'chatgpt_oauth')")
                t.column("name", .text).notNull()
                t.column("baseURL", .text)
                t.column("credentialAccount", .text)
                t.column("isDefault", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
            }
            try db.execute(sql: """
                CREATE UNIQUE INDEX runtime_profile_one_default
                ON runtime_profile(isDefault)
                WHERE isDefault = 1
                """)
            try db.alter(table: "companion") { t in
                t.add(column: "runtimeProfileId", .text).references("runtime_profile")
                t.add(column: "modelPolicy", .text).notNull().defaults(to: CompanionModelPolicy.pinned.rawValue)
                    .check(sql: "modelPolicy IN ('inherit', 'pinned')")
            }
            try db.create(index: "companion_runtimeProfileId", on: "companion", columns: ["runtimeProfileId"])
        }
        m.registerMigration("v11-cli-kinds") { db in
            try db.create(table: "runtime_profile_v11") { t in
                t.primaryKey("id", .text)
                t.column("kind", .text).notNull()
                    .check(sql: """
                        kind IN ('anthropic_api', 'openai_api', 'chatgpt_oauth', 'cli_codex', 'cli_claude')
                        """)
                t.column("name", .text).notNull()
                t.column("baseURL", .text)
                t.column("credentialAccount", .text)
                t.column("isDefault", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
            }
            try db.execute(sql: """
                INSERT INTO runtime_profile_v11(
                    id, kind, name, baseURL, credentialAccount, isDefault, createdAt
                )
                SELECT id, kind, name, baseURL, credentialAccount, isDefault, createdAt
                FROM runtime_profile
                """)
            try db.drop(index: "runtime_profile_one_default")
            try db.drop(table: "runtime_profile")
            try db.rename(table: "runtime_profile_v11", to: "runtime_profile")
            try db.execute(sql: """
                CREATE UNIQUE INDEX runtime_profile_one_default
                ON runtime_profile(isDefault)
                WHERE isDefault = 1
                """)
        }
        m.registerMigration("v12-p1-durable-work") { db in
            try db.execute(sql: """
                CREATE TABLE durable_work (
                  id TEXT PRIMARY KEY NOT NULL,
                  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
                  kind TEXT NOT NULL CHECK (kind IN
                    ('planning','rumination','coach','guideChat','memoryPromotion','inputParsing',
                     'campDeletion')),
                  aggregateType TEXT NOT NULL,
                  aggregateId TEXT NOT NULL,
                  idempotencyKey TEXT NOT NULL,
                  state TEXT NOT NULL CHECK (state IN
                    ('queued','running','retryScheduled','succeeded','failed','canceled')),
                  attempt INTEGER NOT NULL DEFAULT 0 CHECK (attempt >= 0),
                  maxAttempts INTEGER NOT NULL DEFAULT 4 CHECK (maxAttempts >= 1),
                  notBefore DATETIME,
                  leaseOwner TEXT,
                  leaseExpiresAt DATETIME,
                  inputJson TEXT NOT NULL,
                  inputHash TEXT NOT NULL CHECK (
                    length(inputHash) = 64 AND inputHash NOT GLOB '*[^0-9a-f]*'
                  ),
                  outputJson TEXT,
                  errorCode TEXT,
                  errorMessage TEXT CHECK (
                    errorMessage IS NULL OR length(errorMessage) BETWEEN 1 AND 1000
                  ),
                  traceId TEXT NOT NULL,
                  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
                  createdAt DATETIME NOT NULL,
                  updatedAt DATETIME NOT NULL,
                  finishedAt DATETIME,
                  UNIQUE(kind, idempotencyKey),
                  CHECK (
                    (state = 'running' AND leaseOwner IS NOT NULL AND leaseExpiresAt IS NOT NULL)
                    OR
                    (state <> 'running' AND leaseOwner IS NULL AND leaseExpiresAt IS NULL)
                  ),
                  CHECK (
                    (state = 'retryScheduled' AND notBefore IS NOT NULL)
                    OR
                    (state <> 'retryScheduled' AND notBefore IS NULL)
                  ),
                  CHECK (
                    (state IN ('succeeded','failed','canceled') AND finishedAt IS NOT NULL)
                    OR
                    (state IN ('queued','running','retryScheduled') AND finishedAt IS NULL)
                  ),
                  CHECK (outputJson IS NULL OR state = 'succeeded'),
                  CHECK (
                    errorCode IS NULL OR (
                      length(errorCode) BETWEEN 1 AND 64
                      AND substr(errorCode, 1, 1) GLOB '[a-z]'
                      AND errorCode NOT GLOB '*[^a-z0-9_]*'
                    )
                  ),
                  CHECK (COALESCE((
                    (state = 'queued'
                      AND outputJson IS NULL
                      AND (
                        (errorCode IS NULL AND errorMessage IS NULL)
                        OR
                        (errorCode = 'worker_interrupted' AND errorMessage IS NULL)
                      ))
                    OR
                    (state IN ('running','succeeded')
                      AND errorCode IS NULL AND errorMessage IS NULL)
                    OR
                    (state IN ('retryScheduled','failed') AND errorCode IS NOT NULL
                      AND outputJson IS NULL)
                    OR
                    (state = 'canceled' AND errorCode = 'work_canceled'
                      AND errorMessage IS NOT NULL AND outputJson IS NULL)
                  ), 0))
                );
                CREATE UNIQUE INDEX durable_work_one_active_aggregate
                  ON durable_work(kind, aggregateType, aggregateId)
                  WHERE state IN ('queued','running','retryScheduled');
                CREATE INDEX durable_work_claimable
                  ON durable_work(campId, kind, state, notBefore, createdAt);
                CREATE INDEX durable_work_aggregate_history
                  ON durable_work(aggregateType, aggregateId, createdAt);

                CREATE TABLE durable_work_attempt (
                  workId TEXT NOT NULL REFERENCES durable_work(id) ON DELETE RESTRICT,
                  attempt INTEGER NOT NULL CHECK (attempt >= 1),
                  id TEXT NOT NULL UNIQUE,
                  workerId TEXT NOT NULL,
                  startedAt DATETIME NOT NULL,
                  endedAt DATETIME,
                  outcome TEXT CHECK (outcome IS NULL OR outcome IN
                    ('succeeded','failed','canceled','interrupted')),
                  errorCode TEXT,
                  errorMessage TEXT CHECK (
                    errorMessage IS NULL OR length(errorMessage) BETWEEN 1 AND 1000
                  ),
                  traceId TEXT NOT NULL,
                  terminalWorkVersion INTEGER CHECK
                    (terminalWorkVersion IS NULL OR terminalWorkVersion >= 1),
                  PRIMARY KEY(workId, attempt),
                  CHECK (
                    (endedAt IS NULL AND outcome IS NULL AND terminalWorkVersion IS NULL)
                    OR
                    (endedAt IS NOT NULL AND outcome IS NOT NULL AND terminalWorkVersion IS NOT NULL)
                  ),
                  CHECK (
                    errorCode IS NULL OR (
                      length(errorCode) BETWEEN 1 AND 64
                      AND substr(errorCode, 1, 1) GLOB '[a-z]'
                      AND errorCode NOT GLOB '*[^a-z0-9_]*'
                    )
                  ),
                  CHECK (COALESCE((
                    (endedAt IS NULL AND errorCode IS NULL AND errorMessage IS NULL)
                    OR
                    (outcome = 'succeeded' AND errorCode IS NULL AND errorMessage IS NULL)
                    OR
                    (outcome = 'failed' AND errorCode IS NOT NULL)
                    OR
                    (outcome = 'canceled' AND errorCode = 'work_canceled'
                      AND errorMessage IS NOT NULL)
                    OR
                    (outcome = 'interrupted' AND errorCode = 'worker_interrupted'
                      AND errorMessage IS NULL)
                  ), 0))
                );

                CREATE TABLE durable_work_attempt_event (
                  id TEXT PRIMARY KEY NOT NULL,
                  workId TEXT NOT NULL,
                  attempt INTEGER NOT NULL,
                  sequence INTEGER NOT NULL CHECK (sequence >= 0),
                  eventKind TEXT NOT NULL CHECK (eventKind IN
                    ('claimed','leaseRenewed','succeeded','failed','canceled','interrupted')),
                  workerId TEXT NOT NULL,
                  workVersion INTEGER NOT NULL CHECK (workVersion >= 1),
                  resultingWorkState TEXT NOT NULL CHECK (resultingWorkState IN
                    ('running','retryScheduled','succeeded','failed','canceled','queued')),
                  errorCode TEXT,
                  errorMessage TEXT CHECK (
                    errorMessage IS NULL OR length(errorMessage) BETWEEN 1 AND 1000
                  ),
                  occurredAt DATETIME NOT NULL,
                  FOREIGN KEY(workId, attempt)
                    REFERENCES durable_work_attempt(workId, attempt) ON DELETE RESTRICT,
                  UNIQUE(workId, attempt, sequence),
                  CHECK ((sequence = 0) = (eventKind = 'claimed')),
                  CHECK (
                    errorCode IS NULL OR (
                      length(errorCode) BETWEEN 1 AND 64
                      AND substr(errorCode, 1, 1) GLOB '[a-z]'
                      AND errorCode NOT GLOB '*[^a-z0-9_]*'
                    )
                  ),
                  CHECK (COALESCE((
                    (eventKind IN ('claimed','leaseRenewed')
                      AND resultingWorkState = 'running'
                      AND errorCode IS NULL AND errorMessage IS NULL)
                    OR
                    (eventKind = 'succeeded' AND resultingWorkState = 'succeeded'
                      AND errorCode IS NULL AND errorMessage IS NULL)
                    OR
                    (eventKind = 'failed'
                      AND resultingWorkState IN ('retryScheduled','failed')
                      AND errorCode IS NOT NULL)
                    OR
                    (eventKind = 'canceled' AND resultingWorkState = 'canceled'
                      AND errorCode = 'work_canceled' AND errorMessage IS NOT NULL)
                    OR
                    (eventKind = 'interrupted' AND resultingWorkState = 'queued'
                      AND errorCode = 'worker_interrupted' AND errorMessage IS NULL)
                  ), 0))
                );
                CREATE UNIQUE INDEX durable_work_attempt_one_terminal
                  ON durable_work_attempt_event(workId, attempt)
                  WHERE eventKind IN ('succeeded','failed','canceled','interrupted');
                CREATE INDEX durable_work_attempt_event_work
                  ON durable_work_attempt_event(workId, attempt, sequence);

                CREATE TRIGGER durable_work_attempt_event_reject_update
                BEFORE UPDATE ON durable_work_attempt_event
                BEGIN
                  SELECT RAISE(ABORT, 'durable_work_attempt_event is append-only');
                END;
                CREATE TRIGGER durable_work_attempt_event_reject_delete
                BEFORE DELETE ON durable_work_attempt_event
                BEGIN
                  SELECT RAISE(ABORT, 'durable_work_attempt_event is append-only');
                END;
                """)
        }
        m.registerMigration("v12-p1-schedule-fire") { db in
            try db.execute(sql: """
                CREATE TABLE schedule_fire (
                  id TEXT PRIMARY KEY NOT NULL,
                  scheduleId TEXT NOT NULL REFERENCES schedule(id) ON DELETE RESTRICT,
                  templateId TEXT NOT NULL REFERENCES mission_template(id) ON DELETE RESTRICT,
                  slotKey TEXT NOT NULL,
                  scheduledAt DATETIME NOT NULL,
                  replayOfFireId TEXT REFERENCES schedule_fire(id) ON DELETE RESTRICT,
                  replayIdempotencyKey TEXT,
                  replayPayloadHash TEXT CHECK
                    (replayPayloadHash IS NULL OR length(replayPayloadHash) = 64),
                  state TEXT NOT NULL CHECK (state IN ('started','failed')),
                  missionId TEXT REFERENCES mission(id) ON DELETE RESTRICT,
                  traceId TEXT NOT NULL,
                  errorCode TEXT,
                  errorMessage TEXT CHECK (errorMessage IS NULL OR length(errorMessage) <= 1000),
                  createdAt DATETIME NOT NULL,
                  redactedAt DATETIME,
                  CHECK (
                    (replayOfFireId IS NULL AND replayIdempotencyKey IS NULL
                      AND replayPayloadHash IS NULL)
                    OR
                    (replayOfFireId IS NOT NULL AND replayIdempotencyKey IS NOT NULL
                      AND replayPayloadHash IS NOT NULL)
                  ),
                  CHECK (
                    (state = 'started' AND missionId IS NOT NULL
                      AND errorCode IS NULL AND errorMessage IS NULL)
                    OR
                    (state = 'failed' AND missionId IS NULL AND errorCode IS NOT NULL)
                  ),
                  CHECK (redactedAt IS NULL OR errorMessage IS NULL)
                );
                CREATE UNIQUE INDEX schedule_fire_original_slot
                  ON schedule_fire(scheduleId, slotKey) WHERE replayOfFireId IS NULL;
                CREATE UNIQUE INDEX schedule_fire_replay_key
                  ON schedule_fire(replayIdempotencyKey)
                  WHERE replayIdempotencyKey IS NOT NULL;
                CREATE INDEX schedule_fire_schedule_time
                  ON schedule_fire(scheduleId, scheduledAt, createdAt);

                CREATE TABLE schedule_evaluation_cursor (
                  scheduleId TEXT PRIMARY KEY NOT NULL REFERENCES schedule(id) ON DELETE CASCADE,
                  lastEvaluatedSlotKey TEXT NOT NULL,
                  lastEvaluatedScheduledAt DATETIME NOT NULL,
                  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
                  updatedAt DATETIME NOT NULL
                );
                """)
        }
        m.registerMigration("v13-p1-observability") { db in
            try db.execute(sql: """
                CREATE TABLE failure_record (
                  id TEXT PRIMARY KEY NOT NULL,
                  operation TEXT NOT NULL,
                  scopeKind TEXT NOT NULL CHECK (scopeKind IN ('camp','global')),
                  campId TEXT REFERENCES camp(id) ON DELETE RESTRICT,
                  scopeType TEXT NOT NULL,
                  scopeId TEXT NOT NULL,
                  severity TEXT NOT NULL CHECK (severity IN ('info','warning','error','critical')),
                  errorCode TEXT NOT NULL,
                  userMessage TEXT NOT NULL CHECK (length(userMessage) <= 1000),
                  diagnosticJson TEXT NOT NULL,
                  state TEXT NOT NULL CHECK (state IN ('open','resolved')),
                  firstSeenAt DATETIME NOT NULL,
                  lastSeenAt DATETIME NOT NULL,
                  occurrenceCount INTEGER NOT NULL DEFAULT 1 CHECK (occurrenceCount >= 1),
                  resolvedAt DATETIME,
                  redactedAt DATETIME,
                  CHECK (
                    (scopeKind = 'camp' AND campId IS NOT NULL)
                    OR
                    (scopeKind = 'global' AND campId IS NULL)
                  ),
                  CHECK (
                    redactedAt IS NULL
                    OR (scopeKind = 'camp' AND userMessage = '[deleted]'
                      AND diagnosticJson = '{}')
                  )
                );
                CREATE INDEX failure_record_open_scope
                  ON failure_record(scopeKind, campId, state, scopeType, scopeId, lastSeenAt);

                CREATE TABLE context_degradation (
                  id TEXT PRIMARY KEY NOT NULL,
                  missionId TEXT REFERENCES mission(id) ON DELETE RESTRICT,
                  cardId TEXT REFERENCES card(id) ON DELETE RESTRICT,
                  dependencyType TEXT NOT NULL,
                  dependencyId TEXT NOT NULL,
                  policy TEXT NOT NULL CHECK (policy IN ('required','optionalApproved')),
                  traceId TEXT NOT NULL,
                  detail TEXT NOT NULL CHECK (length(detail) <= 1000),
                  createdAt DATETIME NOT NULL,
                  redactedAt DATETIME,
                  CHECK (missionId IS NOT NULL OR cardId IS NOT NULL),
                  CHECK (redactedAt IS NULL OR detail = '[deleted]')
                );
                CREATE INDEX context_degradation_mission
                  ON context_degradation(missionId, createdAt);
                CREATE INDEX context_degradation_card
                  ON context_degradation(cardId, createdAt);
                """)
        }
        // P1-C-BEGIN V14ControlContractsMigration
        m.registerMigration("v14-p1-control-contracts") { db in
            try db.execute(sql: """
                CREATE TABLE domain_command_receipt (
                  idempotencyKey TEXT PRIMARY KEY NOT NULL,
                  commandType TEXT NOT NULL,
                  commandPayloadHash TEXT NOT NULL CHECK (length(commandPayloadHash) = 64),
                  eventCount INTEGER NOT NULL CHECK (eventCount >= 0),
                  resultJson TEXT NOT NULL,
                  resultHash TEXT NOT NULL CHECK (length(resultHash) = 64),
                  createdAt DATETIME NOT NULL
                );

                CREATE TABLE domain_event (
                  id TEXT PRIMARY KEY NOT NULL,
                  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
                  aggregateType TEXT NOT NULL,
                  aggregateId TEXT NOT NULL,
                  aggregateVersion INTEGER NOT NULL CHECK (aggregateVersion >= 1),
                  eventType TEXT NOT NULL,
                  payloadVersion INTEGER NOT NULL CHECK (payloadVersion >= 1),
                  payloadJson TEXT NOT NULL,
                  payloadHash TEXT NOT NULL CHECK (length(payloadHash) = 64),
                  actorType TEXT NOT NULL CHECK (actorType IN
                    ('user','system','coach','cow','engine','device')),
                  actorId TEXT NOT NULL,
                  deviceId TEXT,
                  causationId TEXT,
                  correlationId TEXT NOT NULL,
                  commandIdempotencyKey TEXT NOT NULL
                    REFERENCES domain_command_receipt(idempotencyKey) ON DELETE RESTRICT,
                  eventOrdinal INTEGER NOT NULL CHECK (eventOrdinal >= 0),
                  eventIdempotencyKey TEXT NOT NULL UNIQUE,
                  occurredAt DATETIME NOT NULL,
                  recordedAt DATETIME NOT NULL,
                  UNIQUE(aggregateType, aggregateId, aggregateVersion),
                  UNIQUE(commandIdempotencyKey, eventOrdinal)
                );
                CREATE INDEX domain_event_correlation ON domain_event(correlationId, recordedAt);
                CREATE INDEX domain_event_camp ON domain_event(campId, recordedAt);
                CREATE INDEX domain_event_aggregate
                  ON domain_event(aggregateType, aggregateId, aggregateVersion);

                CREATE TABLE event_outbox (
                  eventId TEXT PRIMARY KEY NOT NULL
                    REFERENCES domain_event(id) ON DELETE RESTRICT,
                  state TEXT NOT NULL CHECK
                    (state IN ('pending','dispatching','sent','failed')),
                  attempt INTEGER NOT NULL DEFAULT 0 CHECK (attempt >= 0),
                  notBefore DATETIME,
                  leaseOwner TEXT,
                  leaseExpiresAt DATETIME,
                  lastError TEXT CHECK (lastError IS NULL OR length(lastError) <= 1000),
                  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
                  createdAt DATETIME NOT NULL,
                  updatedAt DATETIME NOT NULL,
                  sentAt DATETIME,
                  CHECK (
                    (state = 'dispatching' AND leaseOwner IS NOT NULL AND leaseExpiresAt IS NOT NULL)
                    OR
                    (state <> 'dispatching' AND leaseOwner IS NULL AND leaseExpiresAt IS NULL)
                  ),
                  CHECK (
                    (state = 'sent' AND sentAt IS NOT NULL)
                    OR
                    (state <> 'sent' AND sentAt IS NULL)
                  )
                );
                CREATE INDEX event_outbox_pending ON event_outbox(state, notBefore, createdAt);

                CREATE TABLE inbox_message (
                  id TEXT PRIMARY KEY NOT NULL,
                  campId TEXT REFERENCES camp(id) ON DELETE RESTRICT,
                  sourceDeviceId TEXT NOT NULL,
                  idempotencyKey TEXT NOT NULL UNIQUE,
                  payloadJson TEXT NOT NULL,
                  payloadHash TEXT NOT NULL CHECK (length(payloadHash) = 64),
                  state TEXT NOT NULL CHECK (state IN ('received','applied','rejected')),
                  receivedAt DATETIME NOT NULL,
                  appliedAt DATETIME,
                  errorCode TEXT,
                  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
                  redactedAt DATETIME,
                  CHECK (
                    redactedAt IS NULL
                    OR
                    (campId IS NOT NULL
                      AND sourceDeviceId = '[deleted]'
                      AND payloadJson = '{}'
                      AND state = 'rejected'
                      AND errorCode = 'camp_deleted')
                  )
                );
                CREATE INDEX inbox_message_camp_state
                  ON inbox_message(campId, state, receivedAt);

                CREATE TABLE input_envelope (
                  id TEXT PRIMARY KEY NOT NULL,
                  schemaVersion INTEGER NOT NULL DEFAULT 1 CHECK (schemaVersion = 1),
                  aggregateVersion INTEGER NOT NULL DEFAULT 1 CHECK (aggregateVersion >= 1),
                  idempotencyKey TEXT NOT NULL UNIQUE,
                  sourceType TEXT NOT NULL CHECK (sourceType IN
                    ('text','url','file','image','audio','device','connector')),
                  sourceDeviceId TEXT,
                  connectorId TEXT,
                  authorId TEXT,
                  capturedAt DATETIME NOT NULL,
                  inlineText TEXT,
                  payloadRef TEXT,
                  contentHash TEXT NOT NULL CHECK (length(contentHash) = 64),
                  candidateCampIdsJson TEXT NOT NULL,
                  campId TEXT REFERENCES camp(id) ON DELETE RESTRICT,
                  explicitIntent TEXT NOT NULL CHECK (explicitIntent IN
                    ('unspecified','archiveOnly','organize','createGoal','startNow')),
                  privacyLevel TEXT NOT NULL CHECK (privacyLevel IN
                    ('localOnly','encryptedSync','cloudExecution')),
                  status TEXT NOT NULL CHECK (status IN
                    ('captured','parseFailed','campAssignmentRequired','campAmbiguous',
                     'coaching','archived','goalCreated','deletedTombstone')),
                  errorCode TEXT,
                  errorMessage TEXT CHECK (errorMessage IS NULL OR length(errorMessage) <= 1000),
                  parentInputId TEXT REFERENCES input_envelope(id) ON DELETE RESTRICT,
                  retentionState TEXT NOT NULL CHECK (retentionState IN
                    ('active','deletionRequested','deletedTombstone')),
                  createdAt DATETIME NOT NULL,
                  updatedAt DATETIME NOT NULL,
                  deletedAt DATETIME,
                  CHECK (
                    (status = 'deletedTombstone' AND retentionState = 'deletedTombstone')
                    OR
                    (status <> 'deletedTombstone' AND retentionState <> 'deletedTombstone')
                  ),
                  CHECK (
                    (retentionState = 'deletedTombstone'
                      AND sourceDeviceId IS NULL
                      AND connectorId IS NULL
                      AND authorId IS NULL
                      AND inlineText IS NULL
                      AND payloadRef IS NULL
                      AND candidateCampIdsJson = '[]'
                      AND explicitIntent = 'unspecified'
                      AND privacyLevel = 'localOnly'
                      AND errorCode IS NULL
                      AND errorMessage IS NULL
                      AND parentInputId IS NULL
                      AND deletedAt IS NOT NULL
                      AND updatedAt = deletedAt)
                    OR
                    (retentionState <> 'deletedTombstone'
                      AND ((inlineText IS NOT NULL) <> (payloadRef IS NOT NULL))
                      AND deletedAt IS NULL)
                  )
                );
                CREATE INDEX input_envelope_status ON input_envelope(status, updatedAt);
                CREATE INDEX input_envelope_camp ON input_envelope(campId, capturedAt);

                CREATE TABLE goal_controller (
                  id TEXT PRIMARY KEY NOT NULL,
                  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
                  sourceInputId TEXT REFERENCES input_envelope(id) ON DELETE RESTRICT,
                  title TEXT NOT NULL,
                  rawIntent TEXT NOT NULL,
                  status TEXT NOT NULL CHECK (status IN
                    ('clarifying','ready','active','paused','achieved','abandoned','failed',
                     'deletedTombstone')),
                  currentUnderstandingId TEXT,
                  currentUnderstandingVersion INTEGER,
                  currentOutcomeContractId TEXT,
                  currentOutcomeContractVersion INTEGER,
                  aggregateVersion INTEGER NOT NULL DEFAULT 1 CHECK (aggregateVersion >= 1),
                  createdByActorId TEXT NOT NULL,
                  createdAt DATETIME NOT NULL,
                  updatedAt DATETIME NOT NULL,
                  CHECK (
                    (currentUnderstandingId IS NULL AND currentUnderstandingVersion IS NULL)
                    OR
                    (currentUnderstandingId IS NOT NULL AND currentUnderstandingVersion >= 1)
                  ),
                  CHECK (
                    (currentOutcomeContractId IS NULL AND currentOutcomeContractVersion IS NULL)
                    OR
                    (currentOutcomeContractId IS NOT NULL AND currentOutcomeContractVersion >= 1)
                  )
                );
                CREATE INDEX goal_controller_camp_status
                  ON goal_controller(campId, status, updatedAt);

                CREATE TABLE goal_mission_link (
                  missionId TEXT PRIMARY KEY NOT NULL REFERENCES mission(id) ON DELETE RESTRICT,
                  goalId TEXT NOT NULL REFERENCES goal_controller(id) ON DELETE RESTRICT,
                  outcomeContractId TEXT,
                  outcomeContractVersion INTEGER,
                  state TEXT NOT NULL CHECK (state IN ('active','detached')),
                  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
                  createdAt DATETIME NOT NULL,
                  updatedAt DATETIME NOT NULL,
                  CHECK (
                    (outcomeContractId IS NULL AND outcomeContractVersion IS NULL)
                    OR
                    (outcomeContractId IS NOT NULL AND outcomeContractVersion >= 1)
                  )
                );
                CREATE INDEX goal_mission_link_goal ON goal_mission_link(goalId, state);

                CREATE TABLE coach_session (
                  id TEXT PRIMARY KEY NOT NULL,
                  goalId TEXT NOT NULL REFERENCES goal_controller(id) ON DELETE RESTRICT,
                  inputId TEXT REFERENCES input_envelope(id) ON DELETE RESTRICT,
                  actorId TEXT NOT NULL CHECK (actorId = 'system:coach:v1'),
                  status TEXT NOT NULL CHECK (status IN
                    ('interviewing','waitingForUser','readyForConfirmation',
                     'confirmed','canceled','failed')),
                  currentUnderstandingVersion INTEGER,
                  pendingQuestionId TEXT,
                  traceId TEXT NOT NULL,
                  aggregateVersion INTEGER NOT NULL DEFAULT 1 CHECK (aggregateVersion >= 1),
                  createdAt DATETIME NOT NULL,
                  updatedAt DATETIME NOT NULL
                );
                CREATE INDEX coach_session_goal ON coach_session(goalId, status, updatedAt);

                CREATE TABLE coach_question (
                  id TEXT PRIMARY KEY NOT NULL,
                  sessionId TEXT NOT NULL REFERENCES coach_session(id) ON DELETE RESTRICT,
                  decisionKey TEXT NOT NULL,
                  prompt TEXT NOT NULL,
                  recommendation TEXT NOT NULL,
                  reason TEXT NOT NULL,
                  answerJson TEXT,
                  state TEXT NOT NULL CHECK (state IN ('open','answered','withdrawn')),
                  createdAt DATETIME NOT NULL,
                  answeredAt DATETIME
                );
                CREATE UNIQUE INDEX coach_question_one_open
                  ON coach_question(sessionId) WHERE state = 'open';
                CREATE UNIQUE INDEX coach_question_decision
                  ON coach_question(sessionId, decisionKey);

                CREATE TABLE understanding_card_version (
                  id TEXT NOT NULL,
                  version INTEGER NOT NULL CHECK (version >= 1),
                  goalId TEXT NOT NULL REFERENCES goal_controller(id) ON DELETE RESTRICT,
                  problem TEXT NOT NULL,
                  scenario TEXT NOT NULL,
                  targetAudience TEXT NOT NULL,
                  goalsJson TEXT NOT NULL,
                  nonGoalsJson TEXT NOT NULL,
                  deliverablesJson TEXT NOT NULL,
                  constraintsJson TEXT NOT NULL,
                  acceptanceCriteriaJson TEXT NOT NULL,
                  verificationPlanJson TEXT NOT NULL,
                  resourceRefsJson TEXT NOT NULL,
                  requiredCapabilitiesJson TEXT NOT NULL,
                  budgetPolicyJson TEXT NOT NULL,
                  assumptionsJson TEXT NOT NULL,
                  acceptedRisksJson TEXT NOT NULL,
                  status TEXT NOT NULL CHECK (status IN
                    ('draft','awaitingConfirmation','confirmed','superseded','withdrawn')),
                  contentHash TEXT NOT NULL CHECK (length(contentHash) = 64),
                  createdByActorId TEXT NOT NULL,
                  confirmedByActorId TEXT,
                  confirmedAt DATETIME,
                  createdAt DATETIME NOT NULL,
                  PRIMARY KEY(id, version),
                  UNIQUE(id, version, contentHash),
                  CHECK (
                    (status IN ('confirmed','superseded')
                      AND confirmedByActorId IS NOT NULL AND confirmedAt IS NOT NULL)
                    OR
                    (status NOT IN ('confirmed','superseded')
                      AND confirmedByActorId IS NULL AND confirmedAt IS NULL)
                  )
                );
                CREATE INDEX understanding_goal ON understanding_card_version(goalId, version);

                CREATE TRIGGER domain_command_receipt_reject_update
                BEFORE UPDATE ON domain_command_receipt
                BEGIN
                  SELECT RAISE(ABORT, 'domain_command_receipt is append-only');
                END;
                CREATE TRIGGER domain_command_receipt_reject_delete
                BEFORE DELETE ON domain_command_receipt
                BEGIN
                  SELECT RAISE(ABORT, 'domain_command_receipt is append-only');
                END;
                CREATE TRIGGER domain_event_reject_update
                BEFORE UPDATE ON domain_event
                BEGIN
                  SELECT RAISE(ABORT, 'domain_event is append-only');
                END;
                CREATE TRIGGER domain_event_reject_delete
                BEFORE DELETE ON domain_event
                BEGIN
                  SELECT RAISE(ABORT, 'domain_event is append-only');
                END;
                """)
        }
        // P1-C-END V14ControlContractsMigration
        // P1-D-BEGIN V15OutcomeContractsMigration
        m.registerMigration("v15-p1-outcome-contracts") { db in
            try db.execute(sql: """
                CREATE TABLE acceptance_policy_version (
                  id TEXT NOT NULL,
                  version INTEGER NOT NULL CHECK (version >= 1),
                  outcomeType TEXT NOT NULL,
                  maxRiskClass TEXT NOT NULL CHECK (maxRiskClass IN ('low','normal')),
                  policyActorId TEXT NOT NULL,
                  validFrom DATETIME NOT NULL,
                  validUntil DATETIME NOT NULL,
                  maxOutcomeAgeSeconds INTEGER NOT NULL CHECK (maxOutcomeAgeSeconds > 0),
                  requireAllVerification INTEGER NOT NULL DEFAULT 1
                    CHECK (requireAllVerification = 1),
                  status TEXT NOT NULL CHECK (status IN ('active','revoked','expired')),
                  revokedAt DATETIME,
                  createdByActorId TEXT NOT NULL,
                  contentHash TEXT NOT NULL CHECK (length(contentHash) = 64),
                  createdAt DATETIME NOT NULL,
                  PRIMARY KEY(id, version),
                  UNIQUE(id, version, contentHash),
                  CHECK (validUntil > validFrom),
                  CHECK (
                    (status = 'revoked' AND revokedAt IS NOT NULL)
                    OR
                    (status <> 'revoked' AND revokedAt IS NULL)
                  )
                );
                CREATE INDEX acceptance_policy_applicability
                  ON acceptance_policy_version(outcomeType, status, validFrom, validUntil);

                CREATE TABLE outcome_contract_version (
                  id TEXT NOT NULL,
                  version INTEGER NOT NULL CHECK (version >= 1),
                  goalId TEXT NOT NULL REFERENCES goal_controller(id) ON DELETE RESTRICT,
                  understandingId TEXT NOT NULL,
                  understandingVersion INTEGER NOT NULL CHECK (understandingVersion >= 1),
                  understandingHash TEXT NOT NULL CHECK (length(understandingHash) = 64),
                  outcomeType TEXT NOT NULL,
                  deliverablesJson TEXT NOT NULL,
                  acceptanceCriteriaJson TEXT NOT NULL,
                  verificationRequirementsJson TEXT NOT NULL,
                  unacceptableDeviationsJson TEXT NOT NULL,
                  requiredDependencyRefsJson TEXT NOT NULL,
                  optionalDependencyRefsJson TEXT NOT NULL,
                  requiresSubjectiveJudgment INTEGER NOT NULL DEFAULT 0
                    CHECK (requiresSubjectiveJudgment IN (0,1)),
                  includesPublicRelease INTEGER NOT NULL DEFAULT 0
                    CHECK (includesPublicRelease IN (0,1)),
                  includesPayment INTEGER NOT NULL DEFAULT 0 CHECK (includesPayment IN (0,1)),
                  includesDeletion INTEGER NOT NULL DEFAULT 0 CHECK (includesDeletion IN (0,1)),
                  includesExternalSend INTEGER NOT NULL DEFAULT 0
                    CHECK (includesExternalSend IN (0,1)),
                  riskClass TEXT NOT NULL CHECK
                    (riskClass IN ('low','normal','high','irreversible')),
                  acceptanceOwner TEXT NOT NULL CHECK (acceptanceOwner IN ('user','policy')),
                  acceptancePolicyId TEXT,
                  acceptancePolicyVersion INTEGER,
                  status TEXT NOT NULL CHECK
                    (status IN ('draft','active','superseded','fulfilled','canceled')),
                  contentHash TEXT NOT NULL CHECK (length(contentHash) = 64),
                  createdByActorId TEXT NOT NULL,
                  activatedByActorId TEXT,
                  createdAt DATETIME NOT NULL,
                  activatedAt DATETIME,
                  PRIMARY KEY(id, version),
                  UNIQUE(id, version, contentHash),
                  FOREIGN KEY(understandingId, understandingVersion, understandingHash)
                    REFERENCES understanding_card_version(id, version, contentHash)
                    ON DELETE RESTRICT,
                  FOREIGN KEY(acceptancePolicyId, acceptancePolicyVersion)
                    REFERENCES acceptance_policy_version(id, version) ON DELETE RESTRICT,
                  CHECK (
                    (acceptanceOwner = 'user'
                      AND acceptancePolicyId IS NULL AND acceptancePolicyVersion IS NULL)
                    OR
                    (acceptanceOwner = 'policy'
                      AND acceptancePolicyId IS NOT NULL AND acceptancePolicyVersion >= 1)
                  ),
                  CHECK (
                    (status IN ('active','superseded','fulfilled')
                      AND activatedByActorId IS NOT NULL AND activatedAt IS NOT NULL)
                    OR
                    (status IN ('draft','canceled')
                      AND activatedByActorId IS NULL AND activatedAt IS NULL)
                  )
                );
                CREATE INDEX outcome_contract_goal
                  ON outcome_contract_version(goalId, status, version);

                CREATE TABLE verification_requirement_group (
                  contractId TEXT NOT NULL,
                  contractVersion INTEGER NOT NULL,
                  groupId TEXT NOT NULL,
                  mode TEXT NOT NULL CHECK (mode IN ('all','any')),
                  ordinal INTEGER NOT NULL CHECK (ordinal >= 0),
                  PRIMARY KEY(contractId, contractVersion, groupId),
                  UNIQUE(contractId, contractVersion, ordinal),
                  FOREIGN KEY(contractId, contractVersion)
                    REFERENCES outcome_contract_version(id, version) ON DELETE RESTRICT
                );

                CREATE TABLE verification_requirement (
                  contractId TEXT NOT NULL,
                  contractVersion INTEGER NOT NULL,
                  groupId TEXT NOT NULL,
                  requirementId TEXT NOT NULL,
                  requirementVersion INTEGER NOT NULL CHECK (requirementVersion >= 1),
                  ordinal INTEGER NOT NULL CHECK (ordinal >= 0),
                  verifierType TEXT NOT NULL CHECK (verifierType IN ('cow','deterministic')),
                  verifierId TEXT NOT NULL,
                  method TEXT NOT NULL CHECK (method IN
                    ('command','tests','build','artifactHash','externalReceipt','modelSupplement')),
                  ruleId TEXT NOT NULL,
                  ruleVersion INTEGER NOT NULL CHECK (ruleVersion >= 1),
                  configJson TEXT NOT NULL,
                  requirementHash TEXT NOT NULL CHECK (length(requirementHash) = 64),
                  PRIMARY KEY(contractId, contractVersion, requirementId),
                  UNIQUE(contractId, contractVersion, requirementId, requirementVersion),
                  UNIQUE(contractId, contractVersion, groupId, ordinal),
                  FOREIGN KEY(contractId, contractVersion, groupId)
                    REFERENCES verification_requirement_group(contractId, contractVersion, groupId)
                    ON DELETE RESTRICT
                );
                CREATE INDEX verification_requirement_group_order
                  ON verification_requirement(contractId, contractVersion, groupId, ordinal);

                CREATE TABLE outcome (
                  id TEXT PRIMARY KEY NOT NULL,
                  goalId TEXT NOT NULL REFERENCES goal_controller(id) ON DELETE RESTRICT,
                  missionId TEXT NOT NULL REFERENCES mission(id) ON DELETE RESTRICT,
                  contractId TEXT NOT NULL,
                  contractVersion INTEGER NOT NULL,
                  contractHash TEXT NOT NULL CHECK (length(contractHash) = 64),
                  currentVersion INTEGER NOT NULL CHECK (currentVersion >= 1),
                  state TEXT NOT NULL CHECK (state IN
                    ('produced','verificationPending','verificationFailed','blocked','verified',
                     'delivered','accepted','returned','revoked','invalidated')),
                  aggregateVersion INTEGER NOT NULL DEFAULT 1 CHECK (aggregateVersion >= 1),
                  createdAt DATETIME NOT NULL,
                  updatedAt DATETIME NOT NULL,
                  FOREIGN KEY(contractId, contractVersion, contractHash)
                    REFERENCES outcome_contract_version(id, version, contentHash)
                    ON DELETE RESTRICT
                );
                CREATE INDEX outcome_goal ON outcome(goalId, state, updatedAt);
                CREATE INDEX outcome_mission ON outcome(missionId, state, updatedAt);

                CREATE TABLE outcome_version (
                  outcomeId TEXT NOT NULL REFERENCES outcome(id) ON DELETE RESTRICT,
                  version INTEGER NOT NULL CHECK (version >= 1),
                  contractId TEXT NOT NULL,
                  contractVersion INTEGER NOT NULL,
                  contractHash TEXT NOT NULL CHECK (length(contractHash) = 64),
                  producerActorId TEXT NOT NULL,
                  runIdsJson TEXT NOT NULL,
                  manifestJson TEXT NOT NULL,
                  contentHash TEXT NOT NULL CHECK (length(contentHash) = 64),
                  createdAt DATETIME NOT NULL,
                  PRIMARY KEY(outcomeId, version),
                  UNIQUE(outcomeId, version, contentHash),
                  FOREIGN KEY(contractId, contractVersion, contractHash)
                    REFERENCES outcome_contract_version(id, version, contentHash)
                    ON DELETE RESTRICT
                );

                CREATE TABLE verification_record (
                  id TEXT PRIMARY KEY NOT NULL,
                  commandIdempotencyKey TEXT NOT NULL UNIQUE,
                  contractId TEXT NOT NULL,
                  contractVersion INTEGER NOT NULL,
                  contractHash TEXT NOT NULL CHECK (length(contractHash) = 64),
                  requirementId TEXT NOT NULL,
                  requirementVersion INTEGER NOT NULL,
                  requirementHash TEXT NOT NULL CHECK (length(requirementHash) = 64),
                  outcomeId TEXT NOT NULL,
                  outcomeVersion INTEGER NOT NULL,
                  outcomeHash TEXT NOT NULL CHECK (length(outcomeHash) = 64),
                  verifierType TEXT NOT NULL CHECK (verifierType IN ('cow','deterministic')),
                  verifierId TEXT NOT NULL,
                  method TEXT NOT NULL CHECK (method IN
                    ('command','tests','build','artifactHash','externalReceipt','modelSupplement')),
                  ruleId TEXT NOT NULL,
                  ruleVersion INTEGER NOT NULL CHECK (ruleVersion >= 1),
                  environmentJson TEXT NOT NULL,
                  commandOrRuleJson TEXT NOT NULL,
                  rawResultRef TEXT,
                  evidenceHash TEXT NOT NULL CHECK (length(evidenceHash) = 64),
                  result TEXT NOT NULL CHECK (result IN ('passed','failed','blocked','invalid')),
                  supersedesVerificationId TEXT REFERENCES verification_record(id) ON DELETE RESTRICT,
                  createdAt DATETIME NOT NULL,
                  redactedAt DATETIME,
                  FOREIGN KEY(contractId, contractVersion, contractHash)
                    REFERENCES outcome_contract_version(id, version, contentHash)
                    ON DELETE RESTRICT,
                  FOREIGN KEY(contractId, contractVersion, requirementId, requirementVersion)
                    REFERENCES verification_requirement(
                      contractId, contractVersion, requirementId, requirementVersion)
                    ON DELETE RESTRICT,
                  FOREIGN KEY(outcomeId, outcomeVersion, outcomeHash)
                    REFERENCES outcome_version(outcomeId, version, contentHash)
                    ON DELETE RESTRICT,
                  CHECK (
                    redactedAt IS NULL
                    OR
                    (environmentJson = '{}' AND commandOrRuleJson = '{}'
                      AND rawResultRef IS NULL)
                  )
                );
                CREATE INDEX verification_record_requirement
                  ON verification_record(
                    outcomeId, outcomeVersion, requirementId, requirementVersion, createdAt);

                CREATE TABLE verification_result_head (
                  outcomeId TEXT NOT NULL,
                  outcomeVersion INTEGER NOT NULL,
                  contractId TEXT NOT NULL,
                  contractVersion INTEGER NOT NULL,
                  requirementId TEXT NOT NULL,
                  requirementVersion INTEGER NOT NULL,
                  currentVerificationId TEXT NOT NULL
                    REFERENCES verification_record(id) ON DELETE RESTRICT,
                  derivedResult TEXT NOT NULL CHECK
                    (derivedResult IN ('passed','failed','blocked','invalid')),
                  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
                  updatedAt DATETIME NOT NULL,
                  PRIMARY KEY(
                    outcomeId, outcomeVersion, contractId, contractVersion,
                    requirementId, requirementVersion),
                  FOREIGN KEY(outcomeId, outcomeVersion)
                    REFERENCES outcome_version(outcomeId, version) ON DELETE RESTRICT,
                  FOREIGN KEY(contractId, contractVersion, requirementId, requirementVersion)
                    REFERENCES verification_requirement(
                      contractId, contractVersion, requirementId, requirementVersion)
                    ON DELETE RESTRICT
                );

                CREATE TABLE verification_invalidation (
                  id TEXT PRIMARY KEY NOT NULL,
                  verificationId TEXT NOT NULL
                    REFERENCES verification_record(id) ON DELETE RESTRICT,
                  reasonCode TEXT NOT NULL,
                  dependencyType TEXT NOT NULL,
                  dependencyId TEXT NOT NULL,
                  dependencyVersion INTEGER,
                  dependencyHash TEXT CHECK
                    (dependencyHash IS NULL OR length(dependencyHash) = 64),
                  eventId TEXT NOT NULL REFERENCES domain_event(id) ON DELETE RESTRICT,
                  createdAt DATETIME NOT NULL,
                  UNIQUE(
                    verificationId, reasonCode, dependencyType,
                    dependencyId, dependencyVersion, dependencyHash)
                );
                CREATE INDEX verification_invalidation_record
                  ON verification_invalidation(verificationId, createdAt);

                CREATE TABLE acceptance_record (
                  id TEXT PRIMARY KEY NOT NULL,
                  commandIdempotencyKey TEXT NOT NULL UNIQUE,
                  contractId TEXT NOT NULL,
                  contractVersion INTEGER NOT NULL,
                  contractHash TEXT NOT NULL CHECK (length(contractHash) = 64),
                  outcomeId TEXT NOT NULL,
                  outcomeVersion INTEGER NOT NULL,
                  outcomeHash TEXT NOT NULL CHECK (length(outcomeHash) = 64),
                  subjectType TEXT NOT NULL CHECK (subjectType IN ('user','policy')),
                  subjectId TEXT NOT NULL,
                  policyId TEXT,
                  policyVersion INTEGER,
                  decision TEXT NOT NULL CHECK (decision IN ('accepted','returned','revoked')),
                  reason TEXT NOT NULL,
                  supersedesAcceptanceId TEXT
                    REFERENCES acceptance_record(id) ON DELETE RESTRICT,
                  createdAt DATETIME NOT NULL,
                  redactedAt DATETIME,
                  FOREIGN KEY(contractId, contractVersion, contractHash)
                    REFERENCES outcome_contract_version(id, version, contentHash)
                    ON DELETE RESTRICT,
                  FOREIGN KEY(outcomeId, outcomeVersion, outcomeHash)
                    REFERENCES outcome_version(outcomeId, version, contentHash)
                    ON DELETE RESTRICT,
                  FOREIGN KEY(policyId, policyVersion)
                    REFERENCES acceptance_policy_version(id, version) ON DELETE RESTRICT,
                  CHECK (
                    (subjectType = 'user' AND policyId IS NULL AND policyVersion IS NULL)
                    OR
                    (subjectType = 'policy' AND policyId IS NOT NULL AND policyVersion >= 1)
                  ),
                  CHECK (redactedAt IS NULL OR reason = '[deleted]')
                );
                CREATE INDEX acceptance_record_outcome
                  ON acceptance_record(outcomeId, createdAt);

                CREATE TABLE outcome_metric_credit (
                  outcomeId TEXT PRIMARY KEY NOT NULL REFERENCES outcome(id) ON DELETE RESTRICT,
                  state TEXT NOT NULL CHECK (state IN ('active','reversed')),
                  creditedOutcomeVersion INTEGER NOT NULL CHECK (creditedOutcomeVersion >= 1),
                  acceptanceId TEXT NOT NULL REFERENCES acceptance_record(id) ON DELETE RESTRICT,
                  reversedByEventId TEXT REFERENCES domain_event(id) ON DELETE RESTRICT,
                  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
                  creditedAt DATETIME NOT NULL,
                  reversedAt DATETIME
                );

                CREATE TABLE approval_grant (
                  id TEXT PRIMARY KEY NOT NULL,
                  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
                  scopeVersion INTEGER NOT NULL DEFAULT 1 CHECK (scopeVersion = 1),
                  grantorActorType TEXT NOT NULL CHECK
                    (grantorActorType IN ('user','policy','system')),
                  grantorActorId TEXT NOT NULL,
                  grantorPolicyId TEXT,
                  grantorPolicyVersion INTEGER CHECK
                    (grantorPolicyVersion IS NULL OR grantorPolicyVersion >= 1),
                  grantorPolicyHash TEXT CHECK
                    (grantorPolicyHash IS NULL OR length(grantorPolicyHash) = 64),
                  granteeType TEXT NOT NULL CHECK (granteeType IN ('cow','engine','system')),
                  granteeId TEXT NOT NULL,
                  capability TEXT NOT NULL,
                  campId TEXT NOT NULL REFERENCES camp(id) ON DELETE RESTRICT,
                  cardId TEXT NOT NULL REFERENCES card(id) ON DELETE RESTRICT,
                  toolId TEXT NOT NULL,
                  approvedInputHash TEXT NOT NULL CHECK (length(approvedInputHash) = 64),
                  purpose TEXT NOT NULL,
                  dataLevel TEXT NOT NULL CHECK
                    (dataLevel IN ('local','workspace','external','sensitive')),
                  adapterReplayClass TEXT NOT NULL CHECK (adapterReplayClass IN
                    ('replaySafe','idempotencyKeyed','nonReplayable')),
                  validFrom DATETIME NOT NULL,
                  validUntil DATETIME NOT NULL,
                  maxUses INTEGER NOT NULL CHECK (maxUses >= 1),
                  usedCount INTEGER NOT NULL DEFAULT 0 CHECK
                    (usedCount >= 0 AND usedCount <= maxUses),
                  status TEXT NOT NULL CHECK
                    (status IN ('active','exhausted','revoked','expired')),
                  revokedAt DATETIME,
                  createdAt DATETIME NOT NULL,
                  updatedAt DATETIME NOT NULL,
                  redactedAt DATETIME,
                  CHECK (validUntil > validFrom),
                  CHECK (
                    redactedAt IS NOT NULL
                    OR
                    (grantorActorType = 'policy'
                      AND grantorPolicyId IS NOT NULL
                      AND grantorPolicyVersion IS NOT NULL
                      AND grantorPolicyHash IS NOT NULL)
                    OR
                    (grantorActorType IN ('user','system')
                      AND grantorPolicyId IS NULL
                      AND grantorPolicyVersion IS NULL
                      AND grantorPolicyHash IS NULL)
                  ),
                  CHECK (
                    redactedAt IS NULL
                    OR
                    (grantorActorId = '[deleted]'
                      AND grantorPolicyId IS NULL
                      AND grantorPolicyVersion IS NULL
                      AND grantorPolicyHash IS NULL
                      AND purpose = '[deleted]')
                  ),
                  CHECK (
                    adapterReplayClass <> 'nonReplayable'
                    OR
                    (grantorActorType = 'user' AND maxUses = 1)
                  )
                );
                CREATE INDEX approval_grant_match
                  ON approval_grant(campId, cardId, toolId, approvedInputHash, status, validUntil);

                CREATE TABLE approval_grant_use (
                  id TEXT PRIMARY KEY NOT NULL,
                  grantId TEXT NOT NULL REFERENCES approval_grant(id) ON DELETE RESTRICT,
                  idempotencyKey TEXT NOT NULL UNIQUE,
                  toolId TEXT NOT NULL,
                  inputHash TEXT NOT NULL CHECK (length(inputHash) = 64),
                  adapterId TEXT NOT NULL,
                  adapterReplayClass TEXT NOT NULL CHECK (adapterReplayClass IN
                    ('replaySafe','idempotencyKeyed','nonReplayable')),
                  state TEXT NOT NULL CHECK (state IN
                    ('reserved','dispatching','accepted','succeeded','failedFinal',
                     'released','crashUnknown','abandonedUnknown')),
                  adapterOperationId TEXT,
                  version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
                  reservedAt DATETIME NOT NULL,
                  dispatchIntentAt DATETIME,
                  adapterAcceptedAt DATETIME,
                  finishedAt DATETIME,
                  CHECK (
                    (state = 'reserved'
                      AND dispatchIntentAt IS NULL AND adapterAcceptedAt IS NULL
                      AND finishedAt IS NULL)
                    OR
                    (state = 'dispatching'
                      AND dispatchIntentAt IS NOT NULL AND adapterAcceptedAt IS NULL
                      AND finishedAt IS NULL)
                    OR
                    (state = 'accepted'
                      AND dispatchIntentAt IS NOT NULL AND adapterAcceptedAt IS NOT NULL
                      AND finishedAt IS NULL)
                    OR
                    (state = 'crashUnknown'
                      AND dispatchIntentAt IS NOT NULL AND finishedAt IS NULL)
                    OR
                    (state IN ('succeeded','failedFinal','abandonedUnknown')
                      AND dispatchIntentAt IS NOT NULL AND finishedAt IS NOT NULL)
                    OR
                    (state = 'released' AND finishedAt IS NOT NULL)
                  )
                );
                CREATE INDEX approval_grant_use_recovery
                  ON approval_grant_use(state, adapterReplayClass, dispatchIntentAt);

                CREATE TABLE external_operation_receipt (
                  id TEXT PRIMARY KEY NOT NULL,
                  grantUseId TEXT NOT NULL REFERENCES approval_grant_use(id) ON DELETE RESTRICT,
                  receiptIdempotencyKey TEXT NOT NULL UNIQUE,
                  ordinal INTEGER NOT NULL CHECK (ordinal >= 0),
                  phase TEXT NOT NULL CHECK (phase IN
                    ('dispatchIntent','adapterAccepted','effectConfirmed','noEffectConfirmed',
                     'reconciliationFailed','userResolved')),
                  result TEXT NOT NULL CHECK (result IN
                    ('pending','succeeded','failedFinal','noEffect','unknown',
                     'abandonedUnknown')),
                  adapterOperationId TEXT,
                  receiptRef TEXT,
                  receiptJson TEXT NOT NULL,
                  receiptHash TEXT NOT NULL CHECK (
                    length(receiptHash) = 64 AND receiptHash NOT GLOB '*[^0-9a-f]*'
                  ),
                  authorityKind TEXT NOT NULL CHECK
                    (authorityKind IN ('system','adapter','user')),
                  authorityId TEXT NOT NULL,
                  createdAt DATETIME NOT NULL,
                  redactedAt DATETIME,
                  UNIQUE(grantUseId, ordinal),
                  CHECK (
                    (phase = 'dispatchIntent'
                      AND result = 'pending' AND authorityKind = 'system')
                    OR
                    (phase = 'adapterAccepted'
                      AND result = 'pending' AND authorityKind = 'adapter')
                    OR
                    (phase = 'effectConfirmed'
                      AND result IN ('succeeded','failedFinal')
                      AND authorityKind = 'adapter')
                    OR
                    (phase = 'noEffectConfirmed'
                      AND result = 'noEffect' AND authorityKind = 'adapter')
                    OR
                    (phase = 'reconciliationFailed'
                      AND result = 'unknown' AND authorityKind = 'adapter')
                    OR
                    (phase = 'userResolved'
                      AND result IN ('succeeded','abandonedUnknown')
                      AND authorityKind = 'user')
                  ),
                  CHECK (
                    redactedAt IS NULL
                    OR
                    (adapterOperationId IS NULL AND receiptRef IS NULL
                      AND receiptJson = '{"redacted":"camp_deleted"}'
                      AND authorityId = '[deleted]')
                  )
                );
                CREATE INDEX external_operation_receipt_use
                  ON external_operation_receipt(grantUseId, ordinal);
                CREATE UNIQUE INDEX external_operation_one_dispatch_intent
                  ON external_operation_receipt(grantUseId)
                  WHERE phase = 'dispatchIntent';
                CREATE UNIQUE INDEX external_operation_one_adapter_acceptance
                  ON external_operation_receipt(grantUseId)
                  WHERE phase = 'adapterAccepted';
                CREATE UNIQUE INDEX external_operation_one_terminal_resolution
                  ON external_operation_receipt(grantUseId)
                  WHERE phase IN ('effectConfirmed','noEffectConfirmed','userResolved');

                CREATE TRIGGER verification_record_reject_update
                BEFORE UPDATE ON verification_record
                BEGIN
                  SELECT RAISE(ABORT, 'verification_record is append-only');
                END;
                CREATE TRIGGER verification_record_reject_delete
                BEFORE DELETE ON verification_record
                BEGIN
                  SELECT RAISE(ABORT, 'verification_record is append-only');
                END;
                CREATE TRIGGER verification_invalidation_reject_update
                BEFORE UPDATE ON verification_invalidation
                BEGIN
                  SELECT RAISE(ABORT, 'verification_invalidation is append-only');
                END;
                CREATE TRIGGER verification_invalidation_reject_delete
                BEFORE DELETE ON verification_invalidation
                BEGIN
                  SELECT RAISE(ABORT, 'verification_invalidation is append-only');
                END;
                CREATE TRIGGER acceptance_record_reject_update
                BEFORE UPDATE ON acceptance_record
                BEGIN
                  SELECT RAISE(ABORT, 'acceptance_record is append-only');
                END;
                CREATE TRIGGER acceptance_record_reject_delete
                BEFORE DELETE ON acceptance_record
                BEGIN
                  SELECT RAISE(ABORT, 'acceptance_record is append-only');
                END;
                CREATE TRIGGER external_operation_receipt_reject_update
                BEFORE UPDATE ON external_operation_receipt
                BEGIN
                  SELECT RAISE(ABORT, 'external_operation_receipt is append-only');
                END;
                CREATE TRIGGER external_operation_receipt_reject_delete
                BEFORE DELETE ON external_operation_receipt
                BEGIN
                  SELECT RAISE(ABORT, 'external_operation_receipt is append-only');
                END;
                """)
        }
        // P1-D-END V15OutcomeContractsMigration
        // P1-E-BEGIN V16IdentityMemoryMigration
        m.registerMigration("v16-p1-identity-memory") { database in
            let boundary = "DROP TRIGGER event_no_update;"
            let parts = p1EIdentityMemoryMigrationSQL.components(
                separatedBy: boundary
            )
            guard parts.count == 2 else {
                throw P1EMigrationIntegrityError(
                    code: "v16_phase_boundary",
                    subject: "occurrences=\(parts.count - 1)"
                )
            }
            try database.execute(sql: parts[0])
            try LegacyContentScopeMigrationV1.backfill(in: database)
            try LegacyEventScopeResolverV1.backfill(in: database)
            try Self.assertP1EV16MigrationBarrier(in: database)
            try database.execute(sql: boundary + parts[1])
        }
        // P1-E-END V16IdentityMemoryMigration
        // P1-F1-BEGIN V17EngineCoordinationMigration
        m.registerMigration("v17-p1-engine-coordination") { database in
            let boundary =
                "CREATE TRIGGER engine_session_first_redaction_exact"
            let parts = p1F1EngineCoordinationMigrationSQL.components(
                separatedBy: boundary
            )
            guard parts.count == 2 else {
                throw P1F1MigrationIntegrityError(
                    code: "v17_phase_boundary",
                    subject: "occurrences=\(parts.count - 1)"
                )
            }
            try database.execute(sql: parts[0])
            try LegacyArtifactOriginMigrationV1.backfill(in: database)
            try LegacyArtifactOriginMigrationV1.assertBarrier(in: database)
            try database.execute(sql: boundary + parts[1])
        }
        // P1-F1-END V17EngineCoordinationMigration
        return m
    }

    private static func assertP1EV16MigrationBarrier(
        in database: Database
    ) throws {
        let exactCounts: [(String, String, String)] = [
            ("camp", "camp_lifecycle", "camp lifecycle"),
            ("companion", "cow_identity", "cow identity"),
            ("chat_thread", "legacy_chat_scope", "legacy chat scope"),
            ("companion_note", "legacy_companion_note_scope", "legacy note scope"),
        ]
        for (source, projection, label) in exactCounts {
            let sourceCount = try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM \(source)"
            ) ?? -1
            let projectionCount = try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM \(projection)"
            ) ?? -1
            guard sourceCount == projectionCount else {
                throw P1EMigrationIntegrityError(
                    code: "v16_count_mismatch",
                    subject: "\(label):\(sourceCount)/\(projectionCount)"
                )
            }
        }
        let eventCount = try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM event"
        ) ?? -1
        let eventScopeCount = try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM camp_event_scope WHERE sourceTable='event'"
        ) ?? -1
        let domainEventCount = try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM domain_event"
        ) ?? -1
        let domainScopeCount = try Int.fetchOne(
            database,
            sql: "SELECT COUNT(*) FROM camp_event_scope WHERE sourceTable='domain_event'"
        ) ?? -1
        guard eventCount == eventScopeCount,
              domainEventCount == domainScopeCount
        else {
            throw P1EMigrationIntegrityError(
                code: "v16_event_scope_count_mismatch",
                subject: "event=\(eventCount)/\(eventScopeCount),domain=\(domainEventCount)/\(domainScopeCount)"
            )
        }
        let archivedActiveWork = try Int.fetchOne(
            database,
            sql: """
                SELECT COUNT(*) FROM durable_work AS work
                JOIN camp_lifecycle AS lifecycle ON lifecycle.campId=work.campId
                WHERE lifecycle.state='archived'
                  AND work.state IN ('queued','running','retryScheduled')
                """
        ) ?? -1
        guard archivedActiveWork == 0 else {
            throw P1EMigrationIntegrityError(
                code: "v16_archived_active_work",
                subject: "count=\(archivedActiveWork)"
            )
        }
        for table in [
            "durable_work_attempt", "camp_provider_dispatch",
            "durable_work_attempt_event",
        ] {
            let targets = try String.fetchAll(
                database,
                sql: "SELECT \"table\" FROM pragma_foreign_key_list(?)",
                arguments: [table]
            )
            guard !targets.contains(where: {
                $0.contains("_v16") || $0.contains("_legacy")
                    || $0.contains("stage")
            }) else {
                throw P1EMigrationIntegrityError(
                    code: "v16_nonfinal_fk_target",
                    subject: "\(table):\(targets.joined(separator: ","))"
                )
            }
        }
        let foreignKeyFailures = try Row.fetchAll(
            database,
            sql: "PRAGMA foreign_key_check"
        )
        guard foreignKeyFailures.isEmpty else {
            throw P1EMigrationIntegrityError(
                code: "v16_foreign_key_check",
                subject: "count=\(foreignKeyFailures.count)"
            )
        }
    }

    // MARK: Bootstrap (idempotent)

    @discardableResult
    public func ensureDefaultCamp() throws -> CampRecord {
        try pool.write { db in
            try Self.ensureDefaultCamp(db)
        }
    }

    static func ensureDefaultCamp(_ db: Database) throws -> CampRecord {
        if let camp = try CampRecord.fetchOne(db) { return camp }
        let now = Date()
        let camp = CampRecord(
            id: UUID().uuidString,
            name: "我的营地",
            createdAt: now
        )
        try camp.insert(db)
        try CampLifecycleStore.insertInitialActive(
            campId: camp.id,
            at: now,
            database: db
        )
        var guide = CompanionRecord.new(
            name: "向导", color: "amber",
            rolePrompt: "你是这个营地的向导，熟悉营地里的一切。",
            model: KernelDefaults.defaultGuideModel, kind: .guide, campId: camp.id)
        guide.toolsJson = "[]"
        try guide.insert(db)
        _ = try CowResidencyStore.synchronizeCompanion(
            guide,
            provisionActiveResidency: true,
            database: db
        )
        return camp
    }

    public func guide(campId: String) throws -> CompanionRecord? {
        try pool.read {
            try Self.guide(campId: campId, in: $0)
        }
    }

    // MARK: 营地 CRUD（M5-0：营地=频道，可多建）

    public func camps() throws -> [CampRecord] {
        try pool.read { db in
            try CampRecord.order(Column("createdAt"), Column.rowID).fetchAll(db)
        }
    }

    public func camp(id: String) throws -> CampRecord? {
        try pool.read { db in try CampRecord.fetchOne(db, key: id) }
    }

    /// 建营地并自动配备向导（spec §10.2：每营地创建时自动配一位向导）。
    @discardableResult
    public func createCamp(name: String, guidePrompt: String? = nil) throws -> CampRecord {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPrompt = guidePrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return try pool.write { db in
            let now = Date()
            let camp = CampRecord(
                id: UUID().uuidString,
                name: trimmedName.isEmpty ? "新营地" : trimmedName,
                createdAt: now)
            try camp.insert(db)
            try CampLifecycleStore.insertInitialActive(
                campId: camp.id,
                at: now,
                database: db
            )
            var guide = CompanionRecord.new(
                name: "营地管家", color: "amber",
                rolePrompt: trimmedPrompt.isEmpty ? "你是这个 Coding 牧场营地的管家，熟悉营地里的一切。" : trimmedPrompt,
                model: KernelDefaults.defaultGuideModel, kind: .guide, campId: camp.id)
            guide.toolsJson = "[]"
            try guide.insert(db)
            _ = try CowResidencyStore.synchronizeCompanion(
                guide,
                provisionActiveResidency: true,
                database: db
            )
            return camp
        }
    }

    public func renameCamp(id: String, name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try pool.write { db in
            guard var camp = try CampRecord.fetchOne(db, key: id) else {
                throw RecordNotFoundError(table: "camp", id: id)
            }
            camp.name = trimmed
            try camp.update(db)
        }
    }

    @discardableResult
    public func setCampArchived(
        id: String,
        archived: Bool
    ) throws -> CampRecord {
        try pool.write { db in
            guard var camp = try CampRecord.fetchOne(db, key: id) else {
                throw RecordNotFoundError(table: "camp", id: id)
            }
            guard camp.archived != archived else { return camp }
            try db.execute(
                sql: """
                    INSERT OR IGNORE INTO camp_lifecycle(
                      campId,state,version,createdAt,updatedAt,
                      deletionRequestedAt,deletedAt
                    ) VALUES (?, ?,1,?,?,NULL,NULL)
                    """,
                arguments: [
                    id, camp.archived ? "archived" : "active",
                    camp.createdAt, camp.createdAt,
                ]
            )
            if archived {
                let activeMissionCount = try Int.fetchOne(
                    db,
                    sql: """
                        SELECT COUNT(*)
                        FROM mission m
                        JOIN squad s ON s.id = m.squadId
                        WHERE s.campId = ?
                          AND m.status IN (
                            'planning','executing','delivering'
                          )
                        """,
                    arguments: [id]
                ) ?? 0
                guard activeMissionCount == 0 else {
                    throw CampArchiveBlockedError.activeMission
                }
                let enabledScheduleCount = try Int.fetchOne(
                    db,
                    sql: """
                        SELECT COUNT(*)
                        FROM schedule s
                        JOIN mission_template t ON t.id = s.templateId
                        WHERE t.campId = ? AND s.enabled = 1
                        """,
                    arguments: [id]
                ) ?? 0
                guard enabledScheduleCount == 0 else {
                    throw CampArchiveBlockedError.enabledSchedule
                }
                let ruminatingItemCount = try Int.fetchOne(
                    db,
                    sql: """
                        SELECT COUNT(*)
                        FROM ingestion_item
                        WHERE campId = ?
                          AND status = 'ruminating'
                        """,
                    arguments: [id]
                ) ?? 0
                let activeRuminationCount = try Int.fetchOne(
                    db,
                    sql: """
                        SELECT COUNT(*)
                        FROM durable_work
                        WHERE campId = ?
                          AND kind = 'rumination'
                          AND state IN (
                            'queued','running','retryScheduled'
                          )
                        """,
                    arguments: [id]
                ) ?? 0
                guard ruminatingItemCount == 0,
                      activeRuminationCount == 0
                else {
                    throw InvalidDurableWorkStateError()
                }
            }
            let now = Date()
            camp.archived = archived
            try camp.update(db)
            try db.execute(
                sql: """
                    UPDATE camp_lifecycle
                    SET state=?,version=version+1,updatedAt=?
                    WHERE campId=? AND state=?
                """,
                arguments: [
                    archived ? "archived" : "active", now, id,
                    archived ? "active" : "archived",
                ]
            )
            guard db.changesCount == 1 else {
                throw CampLifecycleWriteAuthorizationError.missing
            }
            try Self.appendEvent(
                db,
                missionId: nil,
                cardId: nil,
                runId: nil,
                kind: EventKind.campArchived,
                payload: ["campId": .string(id), "archived": .bool(archived)]
            )
            return camp
        }
    }

    // MARK: Companion CRUD

    public func saveCompanion(_ c: CompanionRecord) throws { // Fix 7: drop inout
        try pool.write { db in
            let isNew = try CompanionRecord.fetchOne(db, key: c.id) == nil
            try c.save(db)
            _ = try CowResidencyStore.synchronizeCompanion(
                c,
                provisionActiveResidency: isNew && c.campId != nil,
                database: db
            )
        }
    }

    public func companion(id: String) throws -> CompanionRecord? {
        try pool.read { try Self.companion(id: id, in: $0) }
    }

    public func regularCompanions() throws -> [CompanionRecord] {
        try pool.read { db in
            try CompanionRecord.fetchAll(
                db,
                sql: """
                    SELECT p.*
                    FROM companion p
                    JOIN cow_identity c ON c.id = p.id
                    WHERE p.kind = 'regular' AND c.status = 'active'
                    ORDER BY p.createdAt
                    """
            )
        }
    }

    // MARK: Single-card mission (camp + squad + mission + card + event in one write tx)

    public struct SingleCardIds: Sendable {
        public let missionId: String
        public let cardId: String
        public let squadId: String
    }

    public func createSingleCardMission(
        campName: String,
        squadName: String,
        goal: String,
        cardTitle: String,
        cardDescription: String,
        expectedOutput: String,
        assigneeId: String?,
        maxTurns: Int,
        workspacePath: String? = nil,
        tokenBudget: Int = KernelDefaults.cardTokenBudget,
        campId: String? = nil
    ) throws -> SingleCardIds {
        let camp = try resolveCamp(id: campId)
        return try pool.write { db in
            let squad = SquadRecord(
                id: UUID().uuidString, campId: camp.id, name: squadName,
                memberIdsJson: "[]", workspacePath: workspacePath,
                workspaceBookmark: WorkspaceScopedAccess.captureBookmark(forPath: workspacePath),
                createdAt: Date())
            try squad.insert(db)

            let mission = MissionRecord(
                id: UUID().uuidString, squadId: squad.id, goalRaw: goal,
                goalRefined: goal, status: .executing,
                budgetTokens: tokenBudget, spentTokens: 0, revision: 1, createdAt: Date())
            try mission.insert(db)

            let card = CardRecord(
                id: UUID().uuidString, missionId: mission.id,
                idemKey: "mission:\(mission.id):stage-1",
                title: cardTitle, descriptionText: cardDescription,
                expectedOutput: expectedOutput, assigneeId: assigneeId,
                status: .ready, blockedReasonJson: nil, dependsOnJson: "[]",
                handoffJson: nil, stage: 1,
                maxTurns: maxTurns, tokenBudget: tokenBudget, createdAt: Date())
            try card.insert(db)

            try Self.appendEvent(db, missionId: mission.id, cardId: card.id, runId: nil,
                                 kind: EventKind.missionCreated, payload: ["goal": .string(goal)])
            try Self.appendEvent(
                db,
                missionId: mission.id,
                cardId: card.id,
                runId: nil,
                kind: EventKind.cardReady,
                payload: .object([:])
            )

            return SingleCardIds(missionId: mission.id, cardId: card.id, squadId: squad.id)
        }
    }

    private func resolveCamp(id: String?) throws -> CampRecord {
        guard let id else { return try ensureDefaultCamp() }
        guard let camp = try camp(id: id) else {
            throw RecordNotFoundError(table: "camp", id: id)
        }
        if camp.archived {
            throw CampArchivedError(campId: id)
        }
        return camp
    }

    /// 预算追加（M5-2 三选之「加预算」）；饱和加法防溢出。
    public func addBudget(missionId: String, tokens: Int) throws {
        try pool.write { db in
            guard var mission = try MissionRecord.fetchOne(db, key: missionId) else {
                throw RecordNotFoundError(table: "mission", id: missionId)
            }
            let (sum, overflow) = mission.budgetTokens.addingReportingOverflow(max(0, tokens))
            mission.budgetTokens = overflow ? Int.max : sum
            try mission.update(db)
            try Self.appendEvent(
                db, missionId: missionId, cardId: nil, runId: nil,
                kind: EventKind.budgetAdded,
                payload: ["tokens": .number(Double(max(0, tokens)))]
            )
        }
    }

    // MARK: Card queries

    public func card(id: String) throws -> CardRecord? {
        try pool.read { db in try CardRecord.fetchOne(db, key: id) }
    }

    public func clearCardReviewFlag(cardId: String) throws {
        try pool.write { db in
            guard var card = try CardRecord.fetchOne(db, key: cardId) else {
                throw RecordNotFoundError(table: "card", id: cardId)
            }
            guard card.reviewFlag != nil else { return }
            card.reviewFlag = nil
            try card.update(db)
            try Self.appendEvent(
                db,
                missionId: card.missionId,
                cardId: card.id,
                runId: nil,
                kind: EventKind.cardReviewCleared,
                payload: .object([:])
            )
        }
    }

    public func returnCardForRework(cardId: String, feedback: String) throws {
        let trimmed = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try pool.write { db in
            guard var card = try CardRecord.fetchOne(db, key: cardId) else {
                throw RecordNotFoundError(table: "card", id: cardId)
            }
            guard var mission = try MissionRecord.fetchOne(db, key: card.missionId) else {
                throw RecordNotFoundError(table: "mission", id: card.missionId)
            }
            guard mission.status == .executing || mission.status == .delivering else {
                throw MissionStateError(missionId: mission.id, from: mission.status, expected: .executing)
            }
            guard card.status.canTransition(to: .ready) else {
                throw CardTransitionError(from: card.status, to: .ready)
            }

            let handoff = card.handoffJson.flatMap {
                try? JSONDecoder().decode(HandoffPayload.self, from: Data($0.utf8))
            }
            let payload: JSONValue = [
                "feedback": .string(trimmed),
                "previousOutcome": .string(handoff?.outcome ?? ""),
                "previousSummary": .string(handoff?.summary ?? ""),
            ]

            card.status = .ready
            card.blockedReasonJson = nil
            card.reviewFlag = nil
            try card.update(db)
            try Self.appendEvent(
                db,
                missionId: card.missionId,
                cardId: card.id,
                runId: nil,
                kind: EventKind.cardReturned,
                payload: payload
            )

            let downstream = try CardRecord
                .filter(Column("missionId") == card.missionId && Column("status") == CardStatus.done.rawValue)
                .fetchAll(db)
            for var dependent in downstream where Self.dependsOn(card.id, dependsOnJson: dependent.dependsOnJson) {
                dependent.reviewFlag = "stale_upstream"
                try dependent.update(db)
            }

            let statuses = try CardRecord
                .filter(Column("missionId") == mission.id)
                .fetchAll(db)
                .map(\.status)
            let next = MissionStatus.rollup(current: mission.status, cards: statuses)
            if next != mission.status {
                let previous = mission.status
                mission.status = next
                try mission.update(db)
                try Self.appendEvent(
                    db,
                    missionId: mission.id,
                    cardId: nil,
                    runId: nil,
                    kind: EventKind.missionStatusChanged,
                    payload: ["from": .string(previous.rawValue), "to": .string(next.rawValue)]
                )
            }
            try Self.appendEvent(
                db,
                missionId: card.missionId,
                cardId: card.id,
                runId: nil,
                kind: EventKind.cardReady,
                payload: .object([:])
            )
        }
    }

    public func latestReturnFeedback(cardId: String) throws -> (feedback: String, previousOutcome: String, previousSummary: String)? {
        try pool.read { db in
            guard let event = try EventRecord
                .filter(Column("cardId") == cardId && Column("kind") == EventKind.cardReturned)
                .order(Column("createdAt").desc, Column.rowID.desc)
                .fetchOne(db),
                  let payload = try? JSONValue.decoded(from: event.payloadJson),
                  let feedback = payload["feedback"]?.stringValue,
                  !feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return (
                feedback,
                payload["previousOutcome"]?.stringValue ?? "",
                payload["previousSummary"]?.stringValue ?? ""
            )
        }
    }

    public func squad(forCard cardId: String) throws -> SquadRecord? {
        try pool.read { db in
            guard let card = try CardRecord.fetchOne(db, key: cardId),
                  let mission = try MissionRecord.fetchOne(db, key: card.missionId) else { return nil }
            return try SquadRecord.fetchOne(db, key: mission.squadId)
        }
    }

    private static func dependsOn(_ upstreamId: String, dependsOnJson: String) -> Bool {
        guard let ids = try? JSONDecoder().decode([String].self, from: Data(dependsOnJson.utf8)) else {
            return false
        }
        return ids.contains(upstreamId)
    }

    public func squad(forMission missionId: String) throws -> SquadRecord? {
        try pool.read { db in
            guard let mission = try MissionRecord.fetchOne(db, key: missionId) else { return nil }
            return try SquadRecord.fetchOne(db, key: mission.squadId)
        }
    }

    public func mission(id: String) throws -> MissionRecord? {
        try pool.read { db in try MissionRecord.fetchOne(db, key: id) }
    }

    public func cards(missionId: String) throws -> [CardRecord] {
        try pool.read { db in
            try CardRecord
                .filter(Column("missionId") == missionId)
                .order(Column("stage"))
                .fetchAll(db)
        }
    }

    public func companions(ids: [String]) throws -> [CompanionRecord] {
        var seen = Set<String>()
        let uniqueIds = ids.filter { seen.insert($0).inserted }
        return try pool.read { db in
            var companions: [CompanionRecord] = []
            for id in uniqueIds {
                guard let companion = try CompanionRecord.fetchOne(db, key: id) else {
                    throw RecordNotFoundError(table: "companion", id: id)
                }
                companions.append(companion)
            }
            return companions
        }
    }

    public func missionArtifacts(missionId: String) throws -> [ArtifactRecord] {
        try pool.read { db in
            try ArtifactRecord
                .fetchAll(
                    db,
                    sql: """
                        SELECT artifact.*
                        FROM artifact
                        JOIN card ON card.id = artifact.cardId
                        WHERE card.missionId = ?
                        ORDER BY card.stage, artifact.createdAt
                        """,
                    arguments: [missionId]
                )
        }
    }

    // MARK: Card state machine (exhaustive; event appended in SAME transaction — spec §4.2/§5.1)

    public func transitionCard(id: String, to next: CardStatus, eventKind: String,
                               payload: JSONValue, blockedReasonJson: String? = nil) throws {
        try pool.write { db in
            try transitionCard(db, id: id, to: next, eventKind: eventKind,
                               payload: payload, blockedReasonJson: blockedReasonJson)
        }
    }

    func transitionCard(_ db: Database, id: String, to next: CardStatus, eventKind: String,
                        payload: JSONValue, blockedReasonJson: String? = nil) throws {
        guard var card = try CardRecord.fetchOne(db, key: id) else {
            throw RecordNotFoundError(table: "card", id: id)
        }
        guard card.status.canTransition(to: next) else {
            throw CardTransitionError(from: card.status, to: next)
        }
        card.status = next
        card.blockedReasonJson = (next == .blocked) ? blockedReasonJson : nil
        try card.update(db)
        try Self.appendEvent(db, missionId: card.missionId, cardId: card.id, runId: nil,
                             kind: eventKind, payload: payload)
        try rollupMission(db, missionId: card.missionId)
    }

    func rollupMission(_ db: Database, missionId: String) throws {
        guard var mission = try MissionRecord.fetchOne(db, key: missionId) else {
            throw RecordNotFoundError(table: "mission", id: missionId)
        }
        let statuses = try CardRecord
            .filter(Column("missionId") == missionId)
            .fetchAll(db)
            .map(\.status)
        let next = MissionStatus.rollup(current: mission.status, cards: statuses)
        guard next != mission.status else { return }
        let previous = mission.status
        mission.status = next
        try mission.update(db)
        try Self.appendEvent(
            db,
            missionId: missionId,
            cardId: nil,
            runId: nil,
            kind: EventKind.missionStatusChanged,
            payload: ["from": .string(previous.rawValue), "to": .string(next.rawValue)]
        )
        if next == .failed && previous != .accepted && previous != .failed {
            try Self.appendEvent(
                db,
                missionId: missionId,
                cardId: nil,
                runId: nil,
                kind: EventKind.missionFailed,
                payload: ["reason": "defensive_rollup"]
            )
        }
    }

    // MARK: Current ready-event dispatch cause (P1-F1 §26.1)

    package func engineCardReadyObservation(
        for card: CardRecord,
        in db: Database
    ) throws -> EngineCardReadyObservationV1 {
        let latest = try EventRecord.fetchOne(
            db,
            sql: """
                SELECT *
                FROM event
                WHERE cardId=?
                  AND kind IN (
                    'card_started', 'card_completed', 'card_blocked',
                    'card_ready', 'card_canceled', 'card_interrupted',
                    'card_returned'
                  )
                ORDER BY rowid DESC
                LIMIT 1
                """,
            arguments: [card.id]
        )
        return EngineCardReadyObservationV1(
            cardId: card.id,
            cardStatus: card.status,
            latestTransitionEventId: latest?.id,
            latestTransitionKind: latest?.kind
        )
    }

    package func resolveEngineCardReadyCause(
        for card: CardRecord,
        in db: Database
    ) throws -> EngineCardReadyCauseV1 {
        let observation = try engineCardReadyObservation(for: card, in: db)
        guard card.status == .ready,
              observation.latestTransitionKind == EventKind.cardReady,
              let eventID = observation.latestTransitionEventId,
              let ready = try EventRecord.fetchOne(db, key: eventID)
        else {
            throw EngineCardReadyCauseErrorV1.missingCurrentReadyEvent(observation)
        }

        let payload: JSONValue
        do {
            let bytes = Data(ready.payloadJson.utf8)
            guard try CanonicalJSONV1.canonicalize(rawUTF8: bytes) == bytes else {
                throw CanonicalJSONNotCanonicalError()
            }
            payload = try JSONValue.decoded(from: ready.payloadJson)
        } catch {
            throw EngineCardReadyCauseErrorV1.malformedReadyEvent(
                observation: observation,
                eventId: ready.id
            )
        }

        guard let object = payload.objectValue else {
            throw EngineCardReadyCauseErrorV1.malformedReadyEvent(
                observation: observation,
                eventId: ready.id
            )
        }
        if object.isEmpty {
            return EngineCardReadyCauseV1(
                eventId: ready.id,
                idempotencyKey: "engine.execution.v1:\(ready.id)",
                answeredRequestId: nil,
                causalPredecessorExecutionId: nil
            )
        }
        if Set(object.keys) == ["executionId", "reasonCode", "terminalKind"],
           let executionID = object["executionId"]?.stringValue,
           object["terminalKind"]?.stringValue == "canceled"
        {
            do {
                try CanonicalContractCodingV1.validateCanonicalUUID(executionID)
            } catch {
                throw EngineCardReadyCauseErrorV1.malformedReadyEvent(
                    observation: observation,
                    eventId: ready.id
                )
            }
            switch object["reasonCode"] {
            case .string, .null:
                return EngineCardReadyCauseV1(
                    eventId: ready.id,
                    idempotencyKey: "engine.execution.v1:\(ready.id)",
                    answeredRequestId: nil,
                    causalPredecessorExecutionId: nil
                )
            default:
                throw EngineCardReadyCauseErrorV1.malformedReadyEvent(
                    observation: observation,
                    eventId: ready.id
                )
            }
        }
        guard Set(object.keys) == ["answeredRequest"],
              let requestID = object["answeredRequest"]?.stringValue
        else {
            throw EngineCardReadyCauseErrorV1.malformedReadyEvent(
                observation: observation,
                eventId: ready.id
            )
        }
        do {
            try CanonicalContractCodingV1.validateCanonicalUUID(requestID)
        } catch {
            throw EngineCardReadyCauseErrorV1.malformedReadyEvent(
                observation: observation,
                eventId: ready.id
            )
        }
        guard let request = try UserRequestRecord.fetchOne(db, key: requestID),
              request.cardId == card.id,
              request.kind != .approval,
              request.lifecycleState == .answered,
              request.terminalReason == nil,
              request.redactedAt == nil,
              let answerJSON = request.answerJson,
              try P1DTimestampV1.restorePersisted(request.answeredAt) != nil
        else {
            throw EngineCardReadyCauseErrorV1.brokenPredecessorGraph(
                observation: observation,
                requestId: requestID
            )
        }
        do {
            let answerBytes = Data(answerJSON.utf8)
            guard try CanonicalJSONV1.canonicalize(rawUTF8: answerBytes) == answerBytes else {
                throw CanonicalJSONNotCanonicalError()
            }
        } catch {
            throw EngineCardReadyCauseErrorV1.brokenPredecessorGraph(
                observation: observation,
                requestId: requestID
            )
        }

        let created = try EventRecord.fetchAll(
            db,
            sql: "SELECT * FROM event WHERE kind=? ORDER BY rowid",
            arguments: [EventKind.userRequestCreated]
        )
        var predecessors: [EventRecord] = []
        for event in created {
            let eventPayload: JSONValue
            do {
                eventPayload = try JSONValue.decoded(from: event.payloadJson)
            } catch {
                continue
            }
            guard eventPayload["userRequestId"]?.stringValue == requestID else {
                continue
            }
            do {
                let bytes = Data(event.payloadJson.utf8)
                guard try CanonicalJSONV1.canonicalize(rawUTF8: bytes) == bytes else {
                    throw CanonicalJSONNotCanonicalError()
                }
            } catch {
                throw EngineCardReadyCauseErrorV1.brokenPredecessorGraph(
                    observation: observation,
                    requestId: requestID
                )
            }
            guard let eventObject = eventPayload.objectValue,
                  Set(eventObject.keys) == ["kind", "prompt", "userRequestId"],
                  eventObject["kind"]?.stringValue == request.kind.rawValue,
                  eventObject["prompt"]?.stringValue == request.prompt,
                  event.cardId == card.id,
                  event.runId != nil
            else {
                throw EngineCardReadyCauseErrorV1.brokenPredecessorGraph(
                    observation: observation,
                    requestId: requestID
                )
            }
            predecessors.append(event)
        }
        guard predecessors.count <= 1 else {
            throw EngineCardReadyCauseErrorV1.ambiguousAnsweredRequest(
                observation: observation,
                requestId: requestID
            )
        }
        guard let predecessor = predecessors.first else {
            return EngineCardReadyCauseV1(
                eventId: ready.id,
                idempotencyKey: "engine.execution.v1:\(ready.id)",
                answeredRequestId: requestID,
                causalPredecessorExecutionId: nil
            )
        }
        guard let runID = predecessor.runId,
              let run = try RunRecord.fetchOne(db, key: runID),
              run.cardId == card.id
        else {
            throw EngineCardReadyCauseErrorV1.brokenPredecessorGraph(
                observation: observation,
                requestId: requestID
            )
        }
        let executions = try EngineExecutionRecord
            .filter(Column("runId") == runID)
            .fetchAll(db)
        guard executions.count <= 1 else {
            throw EngineCardReadyCauseErrorV1.brokenPredecessorGraph(
                observation: observation,
                requestId: requestID
            )
        }
        guard let execution = executions.first else {
            return EngineCardReadyCauseV1(
                eventId: ready.id,
                idempotencyKey: "engine.execution.v1:\(ready.id)",
                answeredRequestId: requestID,
                causalPredecessorExecutionId: nil
            )
        }
        guard execution.cardId == card.id,
              execution.redactedAt == nil,
              execution.state == .blocked,
              execution.terminalSubtype == .needsHumanInput
        else {
            throw EngineCardReadyCauseErrorV1.brokenPredecessorGraph(
                observation: observation,
                requestId: requestID
            )
        }
        return EngineCardReadyCauseV1(
            eventId: ready.id,
            idempotencyKey: "engine.execution.v1:\(ready.id)",
            answeredRequestId: requestID,
            causalPredecessorExecutionId: execution.id
        )
    }

    // MARK: Event helpers (event table is APPEND-ONLY — no update/delete paths)

    package static func appendEvent(
        _ db: Database,
        missionId: String?,
        cardId: String?,
        runId: String?,
        kind: String,
        payload: JSONValue
    ) throws {
        _ = try appendLegacyEventAndScope(
            db,
            missionId: missionId,
            cardId: cardId,
            runId: runId,
            kind: kind,
            payload: payload
        )
    }

    public func events(cardId: String) throws -> [EventRecord] {
        try pool.read { db in
            try EventRecord
                .filter(Column("cardId") == cardId)
                .order(Column("createdAt"), Column.rowID)
                .fetchAll(db)
        }
    }

    public func events(missionId: String, limit: Int = 200) throws -> [EventRecord] {
        try pool.read { db in
            let rows = try EventRecord.fetchAll(
                db,
                sql: """
                    SELECT *
                    FROM event
                    WHERE missionId = ?
                    ORDER BY createdAt DESC, rowid DESC
                    LIMIT ?
                    """,
                arguments: [missionId, limit]
            )
            return rows.reversed()
        }
    }

    public func missions(limit: Int = 20) throws -> [MissionRecord] {
        try pool.read { db in
            try MissionRecord
                .order(Column("createdAt").desc, Column.rowID.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// 某营地的行动（M5-0：侧栏按频道分组 + 营地首页往期区）。
    public func missions(campId: String, limit: Int = 50) throws -> [MissionRecord] {
        try pool.read { db in
            try MissionRecord.fetchAll(
                db,
                sql: """
                    SELECT mission.*
                    FROM mission
                    JOIN squad ON squad.id = mission.squadId
                    WHERE squad.campId = ?
                    ORDER BY mission.createdAt DESC, mission.rowid DESC
                    LIMIT ?
                    """,
                arguments: [campId, limit]
            )
        }
    }

    public func suspendCardForUserRequest(
        cardId: String,
        runId: String?,
        kind: UserRequestRecord.Kind,
        prompt: String,
        options: [String]?
    ) throws -> String {
        try pool.write { db in
            guard let card = try CardRecord.fetchOne(db, key: cardId) else {
                throw RecordNotFoundError(table: "card", id: cardId)
            }

            let requestId = UUID().uuidString
            let optionsJson: String?
            if let options {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                optionsJson = String(data: try encoder.encode(options), encoding: .utf8)
            } else {
                optionsJson = nil
            }

            try UserRequestRecord(
                id: requestId,
                cardId: cardId,
                kind: kind,
                prompt: prompt,
                optionsJson: optionsJson,
                answerJson: nil,
                createdAt: Date(),
                answeredAt: nil
            ).insert(db)

            let blockedPayload: JSONValue = [
                "detail": .string(prompt),
                "reason": "needs_human_input",
                "userRequestId": .string(requestId),
            ]
            try blockCard(
                db,
                id: cardId,
                runId: runId,
                reason: "needs_human_input",
                detail: prompt,
                payload: blockedPayload,
                reasonJson: try blockedPayload.encodedString()
            )
            try Self.appendEvent(
                db,
                missionId: card.missionId,
                cardId: cardId,
                runId: runId,
                kind: EventKind.userRequestCreated,
                payload: [
                    "kind": .string(kind.rawValue),
                    "prompt": .string(prompt),
                    "userRequestId": .string(requestId),
                ]
            )
            return requestId
        }
    }

    public func answerUserRequest(requestId: String, answerJson: String) throws {
        try pool.write { db in
            guard var request = try UserRequestRecord.fetchOne(db, key: requestId),
                  request.answerJson == nil,
                  request.answeredAt == nil,
                  request.lifecycleState == .open,
                  request.terminalReason == nil,
                  request.redactedAt == nil,
                  let card = try CardRecord.fetchOne(db, key: request.cardId),
                  card.status == .blocked,
                  let blockedReasonJson = card.blockedReasonJson,
                  let blockedReason = try? JSONValue.decoded(from: blockedReasonJson),
                  blockedReason["userRequestId"]?.stringValue == requestId
            else {
                throw StaleUserRequestError(requestId: requestId)
            }

            request.answerJson = answerJson
            request.answeredAt = Date()
            request.lifecycleState = .answered
            try request.update(db)

            var readyCard = card
            readyCard.status = .ready
            readyCard.blockedReasonJson = nil
            try readyCard.update(db)
            try Self.appendEvent(
                db,
                missionId: card.missionId,
                cardId: card.id,
                runId: nil,
                kind: EventKind.userRequestAnswered,
                payload: ["userRequestId": .string(requestId)]
            )
            // M7-D4：审批答复额外落 decided 事件（含决定，feed 可渲染）
            if request.kind == .approval,
               let answer = try? JSONValue.decoded(from: answerJson),
               let decision = answer["decision"]?.stringValue {
                try Self.appendEvent(
                    db,
                    missionId: card.missionId,
                    cardId: card.id,
                    runId: nil,
                    kind: EventKind.approvalDecided,
                    payload: ["userRequestId": .string(requestId), "decision": .string(decision)]
                )
            }
            try rollupMission(db, missionId: card.missionId)
            try Self.appendEvent(
                db,
                missionId: card.missionId,
                cardId: card.id,
                runId: nil,
                kind: EventKind.cardReady,
                payload: request.kind == .approval
                    ? .object([:])
                    : ["answeredRequest": .string(requestId)]
            )
        }
    }

    /// M7-D3：审批挂起（复用 ask_user 持久门语义）。optionsJson 存 {tool, input, inputHash} 全文，
    /// UI 从中渲染动作实体内容（命令全文/写入路径与内容）。
    public func suspendCardForApproval(
        cardId: String,
        runId: String?,
        prompt: String,
        tool: String,
        input: JSONValue,
        inputHash: String
    ) throws -> String {
        try pool.write { db in
            guard let card = try CardRecord.fetchOne(db, key: cardId) else {
                throw RecordNotFoundError(table: "card", id: cardId)
            }
            let requestId = UUID().uuidString
            let payload: JSONValue = [
                "tool": .string(tool),
                "input": input,
                "inputHash": .string(inputHash),
            ]
            try UserRequestRecord(
                id: requestId,
                cardId: cardId,
                kind: .approval,
                prompt: prompt,
                optionsJson: try payload.encodedString(),
                answerJson: nil,
                createdAt: Date(),
                answeredAt: nil
            ).insert(db)

            let blockedPayload: JSONValue = [
                "detail": .string(prompt),
                "reason": "needs_human_input",
                "userRequestId": .string(requestId),
            ]
            try blockCard(
                db,
                id: cardId,
                runId: runId,
                reason: "needs_human_input",
                detail: prompt,
                payload: blockedPayload,
                reasonJson: try blockedPayload.encodedString()
            )
            try Self.appendEvent(
                db,
                missionId: card.missionId,
                cardId: cardId,
                runId: runId,
                kind: EventKind.approvalRequested,
                payload: [
                    "tool": .string(tool),
                    "prompt": .string(prompt),
                    "userRequestId": .string(requestId),
                ]
            )
            return requestId
        }
    }

    /// 本卡已决的审批记录 → 授权令牌快照（M7-D4，冷启动重跑时装入令牌罐）
    public func approvalDecisions(cardId: String) throws -> [ApprovalDecision] {
        let answered = try answeredRequests(cardId: cardId).filter { $0.kind == .approval }
        return try answered.map { request in
            guard let optionsJson = request.optionsJson,
                  let payload = try JSONValue.decoded(
                      from: optionsJson
                  ).objectValue,
                  Set(payload.keys) == ["input", "inputHash", "tool"],
                  let input = payload["input"],
                  let tool = payload["tool"]?.stringValue,
                  let hash = payload["inputHash"]?.stringValue,
                  let answerJson = request.answerJson,
                  let answer = try JSONValue.decoded(
                      from: answerJson
                  ).objectValue,
                  let decision = answer["decision"]?.stringValue,
                  decision == "approve" || decision == "deny",
                  Set(answer.keys) == ["decision"]
                    || (
                        decision == "deny"
                            && Set(answer.keys) == ["decision", "reason"]
                    )
            else {
                throw ApprovalAnswerContractError()
            }
            try CanonicalContractCodingV1.validateNonempty(tool)
            try CanonicalContractCodingV1.validateLowercaseHash(hash)
            guard try ApprovalToken.hash(input: input) == hash else {
                throw ApprovalAnswerContractError()
            }
            let reason = answer["reason"]?.stringValue
            if answer.keys.contains("reason") {
                guard let reason, !reason.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty else {
                    throw ApprovalAnswerContractError()
                }
            }
            return ApprovalDecision(
                tool: tool,
                inputHash: hash,
                approved: decision == "approve",
                reason: reason
            )
        }
    }

    public func answeredRequests(cardId: String) throws -> [UserRequestRecord] {
        try pool.read { db in
            try UserRequestRecord
                .filter(
                    Column("cardId") == cardId
                        && Column("lifecycleState")
                            == UserRequestRecord.LifecycleState.answered.rawValue
                )
                .order(Column("createdAt"), Column.rowID)
                .fetchAll(db)
        }
    }

    public func pendingUserRequests(missionId: String) throws -> [UserRequestRecord] {
        try pool.read { db in
            try Self.pendingUserRequests(missionId: missionId, in: db)
        }
    }

    // P1-B-SEAM databasePendingUserRequests
    package static func pendingUserRequests(
        missionId: String,
        in database: Database
    ) throws -> [UserRequestRecord] {
        try UserRequestRecord.fetchAll(
            database,
            sql: """
                SELECT user_request.*
                FROM user_request
                JOIN card ON card.id = user_request.cardId
                WHERE card.missionId = ?
                  AND user_request.lifecycleState = 'open'
                ORDER BY user_request.createdAt, user_request.rowid
                """,
            arguments: [missionId]
        )
    }

    public func appendKernelErrorEvent(missionId: String, message: String) {
        do {
            try pool.write { db in
                try Self.appendEvent(
                    db,
                    missionId: missionId,
                    cardId: nil,
                    runId: nil,
                    kind: EventKind.kernelError,
                    payload: ["message": .string(message)]
                )
            }
        } catch {
            Self.logger.error(
                "failed to persist kernel error event for mission \(missionId, privacy: .public): \(String(describing: error), privacy: .public)"
            )
        }
    }

    public func appendDiagnosticEvent(cardId: String, runId: String, kind: String, payload: JSONValue) throws {
        try pool.write { db in
            guard let card = try CardRecord.fetchOne(db, key: cardId) else {
                throw RecordNotFoundError(table: "card", id: cardId)
            }
            try Self.appendEvent(
                db,
                missionId: card.missionId,
                cardId: cardId,
                runId: runId,
                kind: kind,
                payload: payload
            )
        }
    }

    // MARK: Run lifecycle

    public func runs(cardId: String) throws -> [RunRecord] {
        try pool.read { db in
            try RunRecord.filter(Column("cardId") == cardId).order(Column("startedAt")).fetchAll(db)
        }
    }

    /// Atomically inserts a run row AND transitions the card ready→running in one write transaction.
    /// A failed transition (e.g. card not ready) rolls back the run insert, preventing orphaned run rows.
    public func startRun(cardId: String, runId: String) throws {
        try pool.write { db in
            let attempt = try RunRecord.filter(Column("cardId") == cardId).fetchCount(db)
            try RunRecord(
                id: runId, cardId: cardId, attempt: attempt + 1, outcome: nil,
                turns: 0, tokensIn: 0, tokensOut: 0, startedAt: Date(), endedAt: nil
            ).insert(db)

            guard var card = try CardRecord.fetchOne(db, key: cardId) else {
                throw RecordNotFoundError(table: "card", id: cardId)
            }
            guard card.status.canTransition(to: .running) else {
                throw CardTransitionError(from: card.status, to: .running)
            }
            card.status = .running
            card.blockedReasonJson = nil
            try card.update(db)
            try Self.appendEvent(db, missionId: card.missionId, cardId: cardId, runId: runId,
                                 kind: EventKind.cardStarted, payload: ["runId": .string(runId)])
        }
    }

    public func finishRun(id: String, outcome: String, turns: Int, tokensIn: Int, tokensOut: Int) throws {
        try pool.write { db in
            guard var run = try RunRecord.fetchOne(db, key: id) else {
                throw RecordNotFoundError(table: "run", id: id)
            }
            run.outcome = outcome
            run.turns = turns
            run.tokensIn = tokensIn
            run.tokensOut = tokensOut
            run.endedAt = Date()
            try run.update(db)
            if let card = try CardRecord.fetchOne(db, key: run.cardId),
               var mission = try MissionRecord.fetchOne(db, key: card.missionId) {
                Self.addSpentSaturating(&mission, tokensIn: tokensIn, tokensOut: tokensOut)
                try mission.update(db)
            }
        }
    }

    /// 行动花销分账（M7-D7，本地估算口径）：按伙伴聚合 run 表 + 规划轮事件求和
    public func missionSpendBreakdown(missionId: String) throws -> MissionSpendBreakdown {
        try pool.read { db in
            try Self.missionSpendBreakdown(missionId: missionId, in: db)
        }
    }

    // P1-B-SEAM databaseMissionSpend
    package static func missionSpendBreakdown(
        missionId: String,
        in database: Database
    ) throws -> MissionSpendBreakdown {
        let rows = try Row.fetchAll(
            database,
            sql: """
                SELECT card.assigneeId AS assigneeId,
                       companion.name AS name,
                       SUM(COALESCE(run.tokensIn, 0) + COALESCE(run.tokensOut, 0)) AS tokens
                FROM run
                JOIN card ON card.id = run.cardId
                LEFT JOIN companion ON companion.id = card.assigneeId
                WHERE card.missionId = ?
                GROUP BY card.assigneeId
                ORDER BY tokens DESC
                """,
            arguments: [missionId]
        )
        let companions = try rows.map { row in
            let companionId: String? = row["assigneeId"]
            let persistedName: String? = row["name"]
            let tokens: Int? = row["tokens"]
            guard let tokens, tokens >= 0 else {
                throw BudgetArithmeticError.spendProjectionOverflow
            }
            let name: String
            if companionId == nil {
                name = "（未指派）"
            } else {
                guard let persistedName,
                      !persistedName.trimmingCharacters(
                        in: .whitespacesAndNewlines
                      ).isEmpty
                else {
                    throw ProjectionContractError.invalidPayload
                }
                name = persistedName
            }
            return MissionSpendBreakdown.CompanionSpend(
                companionId: companionId,
                name: name,
                tokens: tokens
            )
        }
        let planningEvents = try EventRecord
            .filter(
                Column("missionId") == missionId
                    && Column("kind") == EventKind.planningTokens
            )
            .order(Column("createdAt"), Column.rowID)
            .fetchAll(database)
        var planning = 0
        for event in planningEvents {
            let payload = try JSONValue.decoded(from: event.payloadJson)
            guard let input = payload["inputTokens"]?.intValue,
                  let output = payload["outputTokens"]?.intValue,
                  input >= 0,
                  output >= 0
            else {
                throw BudgetArithmeticError.spendProjectionOverflow
            }
            planning = try checkedSpendSum(planning, input)
            planning = try checkedSpendSum(planning, output)
        }
        return MissionSpendBreakdown(
            planningTokens: planning,
            companions: companions
        )
    }

    private static func checkedSpendSum(_ lhs: Int, _ rhs: Int) throws -> Int {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        guard !overflow else {
            throw BudgetArithmeticError.spendProjectionOverflow
        }
        return sum
    }

    /// 行动自主档位中途可改（M7-D2）：更新与 autonomy_changed 事件同事务
    public func setMissionAutonomy(missionId: String, to autonomy: MissionAutonomy) throws {
        try pool.write { db in
            guard var mission = try MissionRecord.fetchOne(db, key: missionId) else {
                throw RecordNotFoundError(table: "mission", id: missionId)
            }
            guard mission.autonomy != autonomy else { return }
            let previous = mission.autonomy
            mission.autonomy = autonomy
            try mission.update(db)
            try Self.appendEvent(
                db, missionId: missionId, cardId: nil, runId: nil,
                kind: EventKind.autonomyChanged,
                payload: ["from": .string(previous.rawValue), "to": .string(autonomy.rawValue)])
        }
    }

    /// 饱和加法（原内联于 finishRun）：溢出封顶 Int.max，预算执法不许翻车
    private static func addSpentSaturating(_ mission: inout MissionRecord, tokensIn: Int, tokensOut: Int) {
        let (total, totalOverflow) = max(0, tokensIn).addingReportingOverflow(max(0, tokensOut))
        let (newSpent, overflow) = mission.spentTokens.addingReportingOverflow(totalOverflow ? Int.max : total)
        mission.spentTokens = (overflow || totalOverflow) ? Int.max : newSpent
    }

    // MARK: Artifacts

    public func artifacts(cardId: String) throws -> [ArtifactRecord] {
        try pool.read { db in
            try ArtifactRecord.filter(Column("cardId") == cardId).order(Column("createdAt")).fetchAll(db)
        }
    }

    // MARK: Chat

    public func findOrCreateDMThread(companionId: String) throws -> ChatThreadRecord {
        try pool.write {
            try Self.findOrCreateDMThread(
                companionId: companionId,
                in: $0
            )
        }
    }

    public func messages(threadId: String) throws -> [ChatMessageRecord] {
        try pool.read {
            try Self.chatMessages(threadId: threadId, in: $0)
        }
    }

    public func appendChatMessage(threadId: String, role: String, text: String) throws {
        let contentJson = try JSONValue.object([
            "text": .string(text),
        ]).encodedString()
        try pool.write {
            _ = try Self.appendChatMessage(
                threadId: threadId,
                role: role,
                contentJson: contentJson,
                in: $0
            )
        }
    }

    static func truncatedFirstLine(_ text: String, max: Int) -> String {
        let first = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        return String(first.prefix(max))
    }
}

extension AppDatabase {
    package func readScheduleWorkflowBundle(
        campId: String
    ) throws -> ScheduleWorkflowReadBundle {
        try pool.read { database in
            try Self.scheduleWorkflowBundle(
                campId: campId,
                database: database,
                afterAnchorRead: {}
            )
        }
    }

#if DEBUG
    package func readScheduleWorkflowBundleForTesting(
        campId: String,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> ScheduleWorkflowReadBundle {
        try pool.read { database in
            try Self.scheduleWorkflowBundle(
                campId: campId,
                database: database,
                afterAnchorRead: afterAnchorRead
            )
        }
    }
#endif

    private static func scheduleWorkflowBundle(
        campId: String,
        database: Database,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> ScheduleWorkflowReadBundle {
        guard try CampRecord.fetchOne(database, key: campId) != nil else {
            throw RecordNotFoundError(
                table: CampRecord.databaseTableName,
                id: campId
            )
        }
        afterAnchorRead()
        let templates = try missionTemplates(
            campId: campId,
            in: database
        )
        for template in templates {
            _ = try template.validateForScheduledMission()
        }
        let schedules = try schedules(campId: campId, in: database)
        for schedule in schedules {
            try schedule.validate()
        }
        return ScheduleWorkflowReadBundle(
            campId: campId,
            templates: templates,
            schedules: schedules
        )
    }

    package func readScheduleRuntimeBundle(
        templateId: String? = nil
    ) throws -> ScheduleRuntimeReadBundle {
        try pool.read { database in
            try Self.scheduleRuntimeBundle(
                templateId: templateId,
                database: database,
                afterAnchorRead: {}
            )
        }
    }

#if DEBUG
    package func readScheduleRuntimeBundleForTesting(
        templateId: String?,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> ScheduleRuntimeReadBundle {
        try pool.read { database in
            try Self.scheduleRuntimeBundle(
                templateId: templateId,
                database: database,
                afterAnchorRead: afterAnchorRead
            )
        }
    }
#endif

    private static func scheduleRuntimeBundle(
        templateId: String?,
        database: Database,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> ScheduleRuntimeReadBundle {
        let enabled = try enabledSchedules(in: database)
        afterAnchorRead()
        var cursorByScheduleId:
            [String: ScheduleEvaluationCursorRecord] = [:]
        for item in enabled {
            if let cursor = try scheduleEvaluationCursor(
                scheduleId: item.schedule.id,
                in: database
            ) {
                cursorByScheduleId[item.schedule.id] = cursor
            }
        }
        let requestedTemplate: MissionTemplateRecord?
        if let templateId {
            guard let template = try missionTemplate(
                id: templateId,
                in: database
            ) else {
                throw RecordNotFoundError(
                    table: MissionTemplateRecord.databaseTableName,
                    id: templateId
                )
            }
            _ = try template.validateForScheduledMission()
            requestedTemplate = template
        } else {
            requestedTemplate = nil
        }
        return ScheduleRuntimeReadBundle(
            enabled: enabled,
            cursorByScheduleId: cursorByScheduleId,
            requestedTemplate: requestedTemplate
        )
    }

    package func readScheduledMissionNotificationBundle(
        missionId: String
    ) throws -> ScheduledMissionNotificationReadBundle? {
        try pool.read { database in
            try Self.scheduledMissionNotificationBundle(
                missionId: missionId,
                database: database,
                afterAnchorRead: {}
            )
        }
    }

#if DEBUG
    package func readScheduledMissionNotificationBundleForTesting(
        missionId: String,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> ScheduledMissionNotificationReadBundle? {
        try pool.read { database in
            try Self.scheduledMissionNotificationBundle(
                missionId: missionId,
                database: database,
                afterAnchorRead: afterAnchorRead
            )
        }
    }
#endif

    private static func scheduledMissionNotificationBundle(
        missionId: String,
        database: Database,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> ScheduledMissionNotificationReadBundle? {
        let origin = try scheduledOrigin(
            missionId: missionId,
            in: database
        )
        afterAnchorRead()
        guard let origin else { return nil }
        guard let template = try missionTemplate(
            id: origin.templateId,
            in: database
        ) else {
            throw RecordNotFoundError(
                table: MissionTemplateRecord.databaseTableName,
                id: origin.templateId
            )
        }
        _ = try template.validateForScheduledMission()
        guard let mission = try MissionRecord.fetchOne(
            database,
            key: missionId
        ) else {
            throw RecordNotFoundError(
                table: MissionRecord.databaseTableName,
                id: missionId
            )
        }
        guard let squad = try SquadRecord.fetchOne(
            database,
            key: mission.squadId
        ) else {
            throw RecordNotFoundError(
                table: SquadRecord.databaseTableName,
                id: mission.squadId
            )
        }
        let descendingEvents = try EventRecord.fetchAll(
            database,
            sql: """
                SELECT *
                FROM event
                WHERE missionId = ?
                ORDER BY createdAt DESC, id DESC
                LIMIT 200
                """,
            arguments: [missionId]
        )
        return ScheduledMissionNotificationReadBundle(
            scheduleId: origin.scheduleId,
            templateId: origin.templateId,
            mission: mission,
            squad: squad,
            events: Array(descendingEvents.reversed())
        )
    }

    package func readMissionIndexBundle(
        includeArchived: Bool
    ) throws -> MissionIndexReadBundle {
        try pool.read { database in
            try Self.missionIndexBundle(
                includeArchived: includeArchived,
                database: database,
                afterAnchorRead: {}
            )
        }
    }

#if DEBUG
    package func readMissionIndexBundleForTesting(
        includeArchived: Bool,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> MissionIndexReadBundle {
        try pool.read { database in
            try Self.missionIndexBundle(
                includeArchived: includeArchived,
                database: database,
                afterAnchorRead: afterAnchorRead
            )
        }
    }
#endif

    private static func missionIndexBundle(
        includeArchived: Bool,
        database: Database,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> MissionIndexReadBundle {
        let missions = try MissionRecord.fetchAll(
            database,
            sql: """
                SELECT mission.*
                FROM mission
                JOIN squad ON squad.id = mission.squadId
                JOIN camp ON camp.id = squad.campId
                WHERE ? OR camp.archived = 0
                ORDER BY mission.createdAt DESC, mission.rowid DESC
                LIMIT 50
                """,
            arguments: [includeArchived]
        )
        afterAnchorRead()
        let camps: [CampRecord]
        if includeArchived {
            camps = try CampRecord
                .order(Column("createdAt"), Column.rowID)
                .fetchAll(database)
        } else {
            camps = try CampRecord
                .filter(Column("archived") == false)
                .order(Column("createdAt"), Column.rowID)
                .fetchAll(database)
        }
        var missionsByCamp: [String: [MissionRecord]] = [:]
        missionsByCamp.reserveCapacity(camps.count)
        for camp in camps {
            missionsByCamp[camp.id] = try MissionRecord.fetchAll(
                database,
                sql: """
                    SELECT mission.*
                    FROM mission
                    JOIN squad ON squad.id = mission.squadId
                    WHERE squad.campId = ?
                    ORDER BY mission.createdAt DESC, mission.rowid DESC
                    LIMIT 50
                    """,
                arguments: [camp.id]
            )
        }
        return MissionIndexReadBundle(
            missions: missions,
            camps: camps,
            missionsByCamp: missionsByCamp,
            artifactLedger: try missionIndexArtifactLedger(
                includeArchived: includeArchived,
                database: database
            )
        )
    }

    private static func missionIndexArtifactLedger(
        includeArchived: Bool,
        database: Database
    ) throws -> [ArtifactLedgerItem] {
        let artifacts = try ArtifactRecord
            .order(Column("createdAt").desc, Column.rowID.desc)
            .fetchAll(database)
        var items: [ArtifactLedgerItem] = []
        items.reserveCapacity(artifacts.count)
        for artifact in artifacts {
            guard let card = try CardRecord.fetchOne(
                database,
                key: artifact.cardId
            ) else {
                throw RecordNotFoundError(
                    table: CardRecord.databaseTableName,
                    id: artifact.cardId
                )
            }
            guard let mission = try MissionRecord.fetchOne(
                database,
                key: card.missionId
            ) else {
                throw RecordNotFoundError(
                    table: MissionRecord.databaseTableName,
                    id: card.missionId
                )
            }
            guard let squad = try SquadRecord.fetchOne(
                database,
                key: mission.squadId
            ) else {
                throw RecordNotFoundError(
                    table: SquadRecord.databaseTableName,
                    id: mission.squadId
                )
            }
            guard let camp = try CampRecord.fetchOne(
                database,
                key: squad.campId
            ) else {
                throw RecordNotFoundError(
                    table: CampRecord.databaseTableName,
                    id: squad.campId
                )
            }
            if !includeArchived, camp.archived {
                continue
            }
            items.append(
                ArtifactLedgerItem(
                    artifact: artifact,
                    card: card,
                    mission: mission,
                    camp: camp
                )
            )
        }
        return items
    }
}

package struct RuntimeProviderResolutionReadBundle: Sendable {
    package let defaultProfile: RuntimeProfileRecord?
    package let companion: CompanionRecord?
    package let selectedProfile: RuntimeProfileRecord?

    package init(
        defaultProfile: RuntimeProfileRecord?,
        companion: CompanionRecord?,
        selectedProfile: RuntimeProfileRecord?
    ) {
        self.defaultProfile = defaultProfile
        self.companion = companion
        self.selectedProfile = selectedProfile
    }
}

public enum BudgetArithmeticError: Error, Sendable, Equatable {
    case nonpositiveBudgetDelta(Int)
    case budgetOverflow
    case negativeRunUsage
    case spendProjectionOverflow
}

package struct MissionDetailReadBundle: Sendable {
    package let mission: MissionRecord
    package let cards: [CardRecord]
    package let artifacts: [ArtifactRecord]
    package let pendingRequests: [UserRequestRecord]
    package let squad: SquadRecord
    package let squadMemberIds: [String]
    package let companionsById: [String: CompanionRecord]
    package let events: [EventRecord]
    package let spend: MissionSpendBreakdown

    package init(
        mission: MissionRecord,
        cards: [CardRecord],
        artifacts: [ArtifactRecord],
        pendingRequests: [UserRequestRecord],
        squad: SquadRecord,
        squadMemberIds: [String],
        companionsById: [String: CompanionRecord],
        events: [EventRecord],
        spend: MissionSpendBreakdown
    ) {
        self.mission = mission
        self.cards = cards
        self.artifacts = artifacts
        self.pendingRequests = pendingRequests
        self.squad = squad
        self.squadMemberIds = squadMemberIds
        self.companionsById = companionsById
        self.events = events
        self.spend = spend
    }
}

package struct MissionIndexReadBundle: Sendable {
    package let missions: [MissionRecord]
    package let camps: [CampRecord]
    package let missionsByCamp: [String: [MissionRecord]]
    package let artifactLedger: [ArtifactLedgerItem]

    package init(
        missions: [MissionRecord],
        camps: [CampRecord],
        missionsByCamp: [String: [MissionRecord]],
        artifactLedger: [ArtifactLedgerItem]
    ) {
        self.missions = missions
        self.camps = camps
        self.missionsByCamp = missionsByCamp
        self.artifactLedger = artifactLedger
    }
}

package struct RuntimeWorkflowReadBundle: Sendable {
    package let profiles: [RuntimeProfileRecord]
    package let defaultProfile: RuntimeProfileRecord
    package let companions: [CompanionRecord]
    package let camps: [CampRecord]

    package init(
        profiles: [RuntimeProfileRecord],
        defaultProfile: RuntimeProfileRecord,
        companions: [CompanionRecord],
        camps: [CampRecord]
    ) {
        self.profiles = profiles
        self.defaultProfile = defaultProfile
        self.companions = companions
        self.camps = camps
    }
}

package struct ScheduleWorkflowReadBundle: Sendable {
    package let campId: String
    package let templates: [MissionTemplateRecord]
    package let schedules: [ScheduleRecord]

    package init(
        campId: String,
        templates: [MissionTemplateRecord],
        schedules: [ScheduleRecord]
    ) {
        self.campId = campId
        self.templates = templates
        self.schedules = schedules
    }
}

package struct ScheduleRuntimeReadBundle: Sendable {
    package let enabled: [EnabledScheduleRecord]
    package let cursorByScheduleId:
        [String: ScheduleEvaluationCursorRecord]
    package let requestedTemplate: MissionTemplateRecord?

    package init(
        enabled: [EnabledScheduleRecord],
        cursorByScheduleId: [String: ScheduleEvaluationCursorRecord],
        requestedTemplate: MissionTemplateRecord?
    ) {
        self.enabled = enabled
        self.cursorByScheduleId = cursorByScheduleId
        self.requestedTemplate = requestedTemplate
    }
}

package struct ScheduledMissionNotificationReadBundle: Sendable {
    package let scheduleId: String
    package let templateId: String
    package let mission: MissionRecord
    package let squad: SquadRecord
    package let events: [EventRecord]

    package init(
        scheduleId: String,
        templateId: String,
        mission: MissionRecord,
        squad: SquadRecord,
        events: [EventRecord]
    ) {
        self.scheduleId = scheduleId
        self.templateId = templateId
        self.mission = mission
        self.squad = squad
        self.events = events
    }
}

package struct InputCampReadBundle: Sendable {
    package let camp: CampRecord
    package let guide: CompanionRecord
    package let ingestionItems: [IngestionItemRecord]
    package let activeRuminationByIngestion: [String: DurableWorkRecord]
    package let materializedNoteIdByIngestion: [String: String]
    package let missions: [MissionRecord]
    package let artifactCountByMission: [String: Int]
    package let campNotes: [CampNoteRecord]
    package let regularCompanions: [CompanionRecord]
    package let newcomerProgress: NewcomerProgress

    package init(
        camp: CampRecord,
        guide: CompanionRecord,
        ingestionItems: [IngestionItemRecord],
        activeRuminationByIngestion: [String: DurableWorkRecord],
        materializedNoteIdByIngestion: [String: String],
        missions: [MissionRecord],
        artifactCountByMission: [String: Int],
        campNotes: [CampNoteRecord],
        regularCompanions: [CompanionRecord],
        newcomerProgress: NewcomerProgress
    ) {
        self.camp = camp
        self.guide = guide
        self.ingestionItems = ingestionItems
        self.activeRuminationByIngestion = activeRuminationByIngestion
        self.materializedNoteIdByIngestion = materializedNoteIdByIngestion
        self.missions = missions
        self.artifactCountByMission = artifactCountByMission
        self.campNotes = campNotes
        self.regularCompanions = regularCompanions
        self.newcomerProgress = newcomerProgress
    }
}

package struct InputReviewReadBundle: Sendable {
    package let ingestion: IngestionItemRecord
    package let result: RuminationResult
    package let baseCow: CompanionRecord?

    package init(
        ingestion: IngestionItemRecord,
        result: RuminationResult,
        baseCow: CompanionRecord?
    ) {
        self.ingestion = ingestion
        self.result = result
        self.baseCow = baseCow
    }
}

package struct ChatMessageProjection: Sendable, Equatable {
    package let id: String
    package let role: String
    package let text: String
    package let proposal: SquadProposalBlock?
    package let createdAt: Date

    package init(
        id: String,
        role: String,
        text: String,
        proposal: SquadProposalBlock?,
        createdAt: Date
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.proposal = proposal
        self.createdAt = createdAt
    }
}

package struct ChatHistoryReadBundle: Sendable {
    package let thread: ChatThreadRecord
    package let messages: [ChatMessageProjection]

    package init(
        thread: ChatThreadRecord,
        messages: [ChatMessageProjection]
    ) {
        self.thread = thread
        self.messages = messages
    }
}

package struct DMChatTurnPreparation: Sendable {
    package let companion: CompanionRecord
    package let thread: ChatThreadRecord
    package let history: [APIMessage]
    package let pinnedNotes: [CompanionNoteRecord]
    package let recentNotes: [CompanionNoteRecord]

    package init(
        companion: CompanionRecord,
        thread: ChatThreadRecord,
        history: [APIMessage],
        pinnedNotes: [CompanionNoteRecord],
        recentNotes: [CompanionNoteRecord]
    ) {
        self.companion = companion
        self.thread = thread
        self.history = history
        self.pinnedNotes = pinnedNotes
        self.recentNotes = recentNotes
    }
}

package struct GuideChatTurnPreparation: Sendable {
    package let guide: CompanionRecord
    package let thread: ChatThreadRecord
    package let history: [APIMessage]

    package init(
        guide: CompanionRecord,
        thread: ChatThreadRecord,
        history: [APIMessage]
    ) {
        self.guide = guide
        self.thread = thread
        self.history = history
    }
}

package struct DefaultCampResolutionReceipt: Sendable {
    package let camp: CampRecord
    package let created: Bool

    package init(camp: CampRecord, created: Bool) {
        self.camp = camp
        self.created = created
    }
}

extension AppDatabase {
    package func readMissionDetailBundle(
        missionId: String
    ) throws -> MissionDetailReadBundle {
        try pool.read { database in
            try Self.missionDetailBundle(
                missionId: missionId,
                database: database,
                afterAnchorRead: {}
            )
        }
    }

#if DEBUG
    package func readMissionDetailBundleForTesting(
        missionId: String,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> MissionDetailReadBundle {
        try pool.read { database in
            try Self.missionDetailBundle(
                missionId: missionId,
                database: database,
                afterAnchorRead: afterAnchorRead
            )
        }
    }
#endif

    private static func missionDetailBundle(
        missionId: String,
        database: Database,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> MissionDetailReadBundle {
        guard let mission = try MissionRecord.fetchOne(
            database,
            key: missionId
        ) else {
            throw RecordNotFoundError(
                table: MissionRecord.databaseTableName,
                id: missionId
            )
        }
        afterAnchorRead()

        let cards = try CardRecord
            .filter(Column("missionId") == missionId)
            .order(Column("stage"), Column.rowID)
            .fetchAll(database)
        let artifacts = try ArtifactRecord.fetchAll(
            database,
            sql: """
                SELECT artifact.*
                FROM artifact
                JOIN card ON card.id = artifact.cardId
                WHERE card.missionId = ?
                ORDER BY card.stage, artifact.createdAt, artifact.rowid
                """,
            arguments: [missionId]
        )
        let pendingRequests = try pendingUserRequests(
            missionId: missionId,
            in: database
        )
        guard let squad = try SquadRecord.fetchOne(
            database,
            key: mission.squadId
        ) else {
            throw RecordNotFoundError(
                table: SquadRecord.databaseTableName,
                id: mission.squadId
            )
        }
        let squadMemberIds: [String]
        do {
            squadMemberIds = try JSONDecoder().decode(
                [String].self,
                from: Data(squad.memberIdsJson.utf8)
            )
        } catch {
            throw ProjectionContractError.invalidPayload
        }
        guard squadMemberIds.allSatisfy({
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) else {
            throw ProjectionContractError.invalidPayload
        }
        var companionsById: [String: CompanionRecord] = [:]
        for companionId in Set(squadMemberIds).sorted() {
            guard let companion = try CompanionRecord.fetchOne(
                database,
                key: companionId
            ) else {
                throw RecordNotFoundError(
                    table: CompanionRecord.databaseTableName,
                    id: companionId
                )
            }
            companionsById[companionId] = companion
        }
        let descendingEvents = try EventRecord.fetchAll(
            database,
            sql: """
                SELECT *
                FROM event
                WHERE missionId = ?
                ORDER BY createdAt DESC, rowid DESC
                LIMIT 200
                """,
            arguments: [missionId]
        )
        let events = Array(descendingEvents.reversed())
        let spend = try missionSpendBreakdown(
            missionId: missionId,
            in: database
        )
        return MissionDetailReadBundle(
            mission: mission,
            cards: cards,
            artifacts: artifacts,
            pendingRequests: pendingRequests,
            squad: squad,
            squadMemberIds: squadMemberIds,
            companionsById: companionsById,
            events: events,
            spend: spend
        )
    }

    package func saveRuminationReview(
        ingestionId: String,
        result: RuminationResult
    ) throws {
        try pool.write { database in
            guard let ingestion = try IngestionItemRecord.fetchOne(
                database,
                key: ingestionId
            ) else {
                throw FeedServiceError.ingestionNotFound(ingestionId)
            }
            guard ingestion.status == .needsReview else {
                throw FeedServiceError.invalidState(ingestion.status)
            }
            guard let lifecycle = try Row.fetchOne(
                database,
                sql: """
                    SELECT lifecycle.state,lifecycle.version,camp.archived
                    FROM camp_lifecycle AS lifecycle
                    JOIN camp ON camp.id=lifecycle.campId
                    WHERE lifecycle.campId=?
                    """,
                arguments: [ingestion.campId]
            ) else {
                throw CampLifecycleWriteAuthorizationError.missing
            }
            guard let lifecycleState = CampLifecycleStateV1(
                rawValue: lifecycle["state"] as String
            ), lifecycleState == .active else {
                throw CampLifecycleWriteAuthorizationError.inactive(
                    CampLifecycleStateV1(
                        rawValue: lifecycle["state"] as String
                    ) ?? .deletedTombstone
                )
            }
            guard (lifecycle["archived"] as Int) == 0 else {
                throw CampLifecycleWriteAuthorizationError.legacyArchived
            }
            guard let stored = try RuminationResultRecord
                .filter(Column("ingestionId") == ingestionId)
                .fetchOne(database)
            else {
                throw RecordNotFoundError(
                    table: RuminationResultRecord.databaseTableName,
                    id: ingestionId
                )
            }
            guard let fence = try Row.fetchOne(
                database,
                sql: "SELECT version,redactedAt FROM rumination_result WHERE id=? AND ingestionId=?",
                arguments: [stored.id, ingestionId]
            ) else {
                throw RecordNotFoundError(
                    table: RuminationResultRecord.databaseTableName,
                    id: ingestionId
                )
            }
            let version: Int = fence["version"]
            let redactedAt: Date? = fence["redactedAt"]
            guard redactedAt == nil, stored.materializedAt == nil else {
                throw FeedServiceError.invalidState(ingestion.status)
            }
            let (nextVersion, overflow) = version.addingReportingOverflow(1)
            guard !overflow else { throw InvalidDurableWorkStateError() }
            try database.execute(
                sql: """
                    UPDATE rumination_result
                    SET userEditedJson=?,updatedAt=?,version=?
                    WHERE id=? AND ingestionId=? AND version=?
                      AND materializedAt IS NULL AND redactedAt IS NULL
                    """,
                arguments: [
                    try RuminationCoding.encode(result),
                    Date(),
                    nextVersion,
                    stored.id,
                    ingestionId,
                    version,
                ]
            )
            guard database.changesCount == 1 else {
                throw StaleDurableWorkClaimError()
            }
        }
    }

    package func resolveDefaultCamp() throws
        -> DefaultCampResolutionReceipt
    {
        try pool.write { database in
            if let existing = try CampRecord
                .order(Column("createdAt"), Column.rowID)
                .fetchOne(database)
            {
                return DefaultCampResolutionReceipt(
                    camp: existing,
                    created: false
                )
            }
            return DefaultCampResolutionReceipt(
                camp: try Self.ensureDefaultCamp(database),
                created: true
            )
        }
    }

    package func readInputCampBundle(
        campId: String
    ) throws -> InputCampReadBundle {
        try pool.read { database in
            try Self.inputCampBundle(
                campId: campId,
                database: database,
                afterAnchorRead: {}
            )
        }
    }

#if DEBUG
    package func readInputCampBundleForTesting(
        campId: String,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> InputCampReadBundle {
        try pool.read { database in
            try Self.inputCampBundle(
                campId: campId,
                database: database,
                afterAnchorRead: afterAnchorRead
            )
        }
    }
#endif

    private static func inputCampBundle(
        campId: String,
        database: Database,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> InputCampReadBundle {
            guard let camp = try CampRecord.fetchOne(database, key: campId)
            else {
                throw RecordNotFoundError(
                    table: CampRecord.databaseTableName,
                    id: campId
                )
            }
            afterAnchorRead()
            let guides = try CompanionRecord
                .filter(
                    Column("campId") == campId
                        && Column("kind") == CompanionRecord.Kind.guide.rawValue
                )
                .order(Column("createdAt"), Column.rowID)
                .limit(2)
                .fetchAll(database)
            guard guides.count == 1, let guide = guides.first else {
                if guides.isEmpty {
                    throw RecordNotFoundError(
                        table: "companion(guide)",
                        id: campId
                    )
                }
                throw ProjectionContractError.invalidPayload
            }
            let items = try IngestionItemRecord
                .filter(Column("campId") == campId)
                .order(Column("createdAt").desc, Column.rowID.desc)
                .fetchAll(database)
            let active = try DurableWorkRecord.fetchAll(
                database,
                sql: """
                    SELECT *
                    FROM durable_work
                    WHERE campId = ?
                      AND kind = 'rumination'
                      AND aggregateType = 'ingestion'
                      AND state IN ('queued','running','retryScheduled')
                    ORDER BY createdAt, rowid
                    """,
                arguments: [campId]
            )
            let itemIDs = Set(items.map(\.id))
            var activeByIngestion: [String: DurableWorkRecord] = [:]
            for work in active {
                guard itemIDs.contains(work.aggregateId),
                      activeByIngestion[work.aggregateId] == nil
                else {
                    throw ProjectionContractError.invalidPayload
                }
                activeByIngestion[work.aggregateId] = work
            }

            let links: [KnowledgeSourceLinkRecord]
            if itemIDs.isEmpty {
                links = []
            } else {
                links = try KnowledgeSourceLinkRecord
                    .filter(itemIDs.contains(Column("ingestionId")))
                    .order(Column("createdAt"), Column.rowID)
                    .fetchAll(database)
            }
            var materializedByIngestion: [String: String] = [:]
            for link in links {
                guard materializedByIngestion[link.ingestionId] == nil else {
                    throw ProjectionContractError.invalidPayload
                }
                materializedByIngestion[link.ingestionId] = link.campNoteId
            }

            let missions = try MissionRecord.fetchAll(
                database,
                sql: """
                    SELECT mission.*
                    FROM mission
                    JOIN squad ON squad.id = mission.squadId
                    WHERE squad.campId = ?
                    ORDER BY mission.createdAt DESC, mission.rowid DESC
                    LIMIT 50
                    """,
                arguments: [campId]
            )
            var artifactCountByMission = Dictionary(
                uniqueKeysWithValues: missions.map { ($0.id, 0) }
            )
            if !missions.isEmpty {
                let rows = try Row.fetchAll(
                    database,
                    sql: """
                        SELECT card.missionId AS missionId,
                               COUNT(artifact.id) AS artifactCount
                        FROM card
                        LEFT JOIN artifact ON artifact.cardId = card.id
                        WHERE card.missionId IN (\(Array(
                            repeating: "?",
                            count: missions.count
                        ).joined(separator: ",")))
                        GROUP BY card.missionId
                        """,
                    arguments: StatementArguments(missions.map(\.id))
                )
                for row in rows {
                    let missionId: String = row["missionId"]
                    let count: Int = row["artifactCount"]
                    guard artifactCountByMission[missionId] != nil,
                          count >= 0
                    else {
                        throw ProjectionContractError.invalidPayload
                    }
                    artifactCountByMission[missionId] = count
                }
            }
            let notes = try CampNoteRecord
                .filter(Column("campId") == campId)
                .order(
                    Column("pinned").desc,
                    Column("updatedAt").desc,
                    Column.rowID.desc
                )
                .fetchAll(database)
            let companions = try CompanionRecord.fetchAll(
                database,
                sql: """
                    SELECT p.*
                    FROM companion p
                    JOIN cow_identity c ON c.id = p.id
                    WHERE p.kind = 'regular'
                      AND c.status = 'active'
                      AND (
                        p.campId = ? OR p.campId IS NULL OR p.campId = ''
                      )
                    ORDER BY p.createdAt, p.rowid
                    """,
                arguments: [campId]
            )
            return InputCampReadBundle(
                camp: camp,
                guide: guide,
                ingestionItems: items,
                activeRuminationByIngestion: activeByIngestion,
                materializedNoteIdByIngestion: materializedByIngestion,
                missions: missions,
                artifactCountByMission: artifactCountByMission,
                campNotes: notes,
                regularCompanions: companions,
                newcomerProgress: try NewcomerUnlockPolicy.progress(
                    database: database,
                    campId: campId
                )
            )
    }

    package func readInputReviewBundle(
        ingestionId: String
    ) throws -> InputReviewReadBundle {
        try pool.read { database in
            try Self.inputReviewBundle(
                ingestionId: ingestionId,
                database: database,
                afterAnchorRead: {}
            )
        }
    }

#if DEBUG
    package func readInputReviewBundleForTesting(
        ingestionId: String,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> InputReviewReadBundle {
        try pool.read { database in
            try Self.inputReviewBundle(
                ingestionId: ingestionId,
                database: database,
                afterAnchorRead: afterAnchorRead
            )
        }
    }
#endif

    private static func inputReviewBundle(
        ingestionId: String,
        database: Database,
        afterAnchorRead: @Sendable () -> Void
    ) throws -> InputReviewReadBundle {
            guard let ingestion = try IngestionItemRecord.fetchOne(
                database,
                key: ingestionId
            ) else {
                throw RecordNotFoundError(
                    table: IngestionItemRecord.databaseTableName,
                    id: ingestionId
                )
            }
            afterAnchorRead()
            let rows = try RuminationResultRecord
                .filter(Column("ingestionId") == ingestionId)
                .order(Column("createdAt"), Column.rowID)
                .limit(2)
                .fetchAll(database)
            guard rows.count == 1, let stored = rows.first else {
                if rows.isEmpty {
                    throw RecordNotFoundError(
                        table: RuminationResultRecord.databaseTableName,
                        id: ingestionId
                    )
                }
                throw ProjectionContractError.invalidPayload
            }
            let result: RuminationResult
            do {
                result = try RuminationCoding.decode(
                    stored.userEditedJson ?? stored.resultJson
                )
            } catch {
                throw ProjectionContractError.invalidPayload
            }
            return InputReviewReadBundle(
                ingestion: ingestion,
                result: result,
                baseCow: try CompanionRecord.fetchOne(
                    database,
                    key: CowTemplate.baseCowId
                )
            )
    }

    package func readRuntimeProviderResolutionBundle(
        companionId: String?
    ) throws -> RuntimeProviderResolutionReadBundle {
        try pool.read { database in
            let defaults = try RuntimeProfileRecord
                .filter(Column("isDefault") == true)
                .order(Column("createdAt"), Column.rowID)
                .limit(2)
                .fetchAll(database)
            guard defaults.count <= 1 else {
                throw ProjectionContractError.invalidPayload
            }
            let defaultProfile = defaults.first
            let companion: CompanionRecord?
            if let companionId {
                companion = try CompanionRecord.fetchOne(
                    database,
                    key: companionId
                )
            } else {
                companion = nil
            }
            let selectedProfileId = companion?.runtimeProfileId
                ?? defaultProfile?.id
            let selectedProfile: RuntimeProfileRecord?
            if let selectedProfileId {
                selectedProfile = try RuntimeProfileRecord.fetchOne(
                    database,
                    key: selectedProfileId
                )
            } else {
                selectedProfile = nil
            }
            return RuntimeProviderResolutionReadBundle(
                defaultProfile: defaultProfile,
                companion: companion,
                selectedProfile: selectedProfile
            )
        }
    }

    package func readRuntimeWorkflowBundle() throws
        -> RuntimeWorkflowReadBundle
    {
        try pool.read { database in
            let profiles = try RuntimeProfileRecord
                .order(Column("createdAt"), Column.rowID)
                .fetchAll(database)
            let defaults = try RuntimeProfileRecord
                .filter(Column("isDefault") == true)
                .order(Column("createdAt"), Column.rowID)
                .limit(2)
                .fetchAll(database)
            guard defaults.count == 1, let defaultProfile = defaults.first
            else {
                throw ProjectionContractError.invalidPayload
            }
            let companions = try CompanionRecord
                .filter(
                    Column("kind")
                        == CompanionRecord.Kind.regular.rawValue
                )
                .order(Column("createdAt"), Column.rowID)
                .fetchAll(database)
            let camps = try CampRecord
                .order(Column("createdAt"), Column.rowID)
                .fetchAll(database)
            return RuntimeWorkflowReadBundle(
                profiles: profiles,
                defaultProfile: defaultProfile,
                companions: companions,
                camps: camps
            )
        }
    }

}

extension AppDatabase: FailureRecordWriting {
    package func persistFailureRecord(_ record: FailureRecord) throws {
        try pool.write { database in
            try Self.upsertFailureRecord(record, database: database)
        }
    }

    package func failureRecord(id: String) throws -> FailureRecord? {
        guard FailureMetadataGrammar.isSafeID(id) else {
            throw FailureMetadataValidationError.invalidTraceId
        }
        return try pool.read { database in
            try FailureRecord.fetchOne(
                database,
                sql: "SELECT * FROM failure_record WHERE id = ?",
                arguments: [id]
            )
        }
    }

    package func contextDegradations(
        missionId: String?,
        cardId: String?,
        limit: Int = 200
    ) throws -> [ContextDegradationRecord] {
        guard missionId != nil || cardId != nil,
              (1...200).contains(limit),
              missionId.map(FailureMetadataGrammar.isSafeID) ?? true,
              cardId.map(FailureMetadataGrammar.isSafeID) ?? true
        else {
            throw FailureMetadataValidationError.invalidCoordinate
        }
        return try pool.read { database in
            var predicates: [String] = []
            var arguments = StatementArguments()
            if let missionId {
                predicates.append("missionId = ?")
                arguments += [missionId]
            }
            if let cardId {
                predicates.append("cardId = ?")
                arguments += [cardId]
            }
            arguments += [limit]
            return try ContextDegradationRecord.fetchAll(
                database,
                sql: """
                    SELECT * FROM context_degradation
                    WHERE \(predicates.joined(separator: " OR "))
                    ORDER BY createdAt ASC, id ASC
                    LIMIT ?
                    """,
                arguments: arguments
            )
        }
    }

    package func resolveFailureRecord(
        id: String,
        resolvedAt: Date
    ) throws -> FailureRecord {
        guard FailureMetadataGrammar.isSafeID(id) else {
            throw FailureMetadataValidationError.invalidTraceId
        }
        return try pool.write { database in
            guard let existing = try Self.fetchFailureRecord(
                id: id,
                database: database
            ) else {
                throw RecordNotFoundError(table: "failure_record", id: id)
            }
            guard existing.redactedAt == nil else {
                throw FailureRecordRedactedError()
            }
            if existing.state == .resolved {
                return existing
            }
            try database.execute(
                sql: """
                    UPDATE failure_record
                    SET state = 'resolved', resolvedAt = ?
                    WHERE id = ?
                    """,
                arguments: [resolvedAt, id]
            )
            guard let resolved = try Self.fetchFailureRecord(
                id: id,
                database: database
            ) else {
                throw RecordNotFoundError(table: "failure_record", id: id)
            }
            return resolved
        }
    }

    package func persistContextFailure(
        _ prepared: PreparedFailure,
        degradation: ContextDegradationRecord,
        cardId: String,
        disposition: ContextFailureCardDisposition
    ) throws {
        guard degradation.traceId == prepared.record.id,
              degradation.cardId == cardId,
              FailureMetadataGrammar.isSafeID(cardId)
        else {
            throw FailureMetadataValidationError.invalidCoordinate
        }
        try pool.write { database in
            try Self.upsertFailureRecord(
                prepared.record,
                database: database
            )
            try Self.insertContextDegradation(
                degradation,
                database: database
            )
            switch disposition {
            case .leaveReady:
                break
            case .block:
                try blockCard(
                    database,
                    id: cardId,
                    runId: nil,
                    reason: "context_unavailable",
                    detail: prepared.visible.message
                )
            }
        }
    }

    package func persistMcpConnectionDown(
        _ prepared: PreparedFailure,
        missionId: String,
        cardId: String,
        serverId: String
    ) throws {
        guard FailureMetadataGrammar.isSafeID(missionId),
              FailureMetadataGrammar.isSafeID(cardId),
              FailureMetadataGrammar.isSafeID(serverId)
        else {
            throw FailureMetadataValidationError.invalidCoordinate
        }
        try pool.write { database in
            try Self.upsertFailureRecord(
                prepared.record,
                database: database
            )
            try Self.appendEvent(
                database,
                missionId: missionId,
                cardId: cardId,
                runId: nil,
                kind: EventKind.mcpServerDown,
                payload: [
                    "errorCode": .string(prepared.record.errorCode.rawValue),
                    "serverId": .string(serverId),
                    "traceId": .string(prepared.record.id),
                ]
            )
        }
    }

    private static func upsertFailureRecord(
        _ record: FailureRecord,
        database: Database
    ) throws {
        if let existing = try fetchFailureRecord(
            id: record.id,
            database: database
        ) {
            guard existing.redactedAt == nil else {
                throw FailureRecordRedactedError()
            }
            guard existing.operation == record.operation,
                  existing.scope == record.scope,
                  existing.severity == record.severity,
                  existing.errorCode == record.errorCode,
                  existing.userMessage == record.userMessage
            else {
                throw TraceIdentityConflictError()
            }
            let increment = existing.occurrenceCount.addingReportingOverflow(1)
            guard !increment.overflow else {
                throw FailureMetadataValidationError.invalidDiagnostics
            }
            try database.execute(
                sql: """
                    UPDATE failure_record
                    SET diagnosticJson = ?, state = 'open',
                        lastSeenAt = ?, occurrenceCount = ?, resolvedAt = NULL
                    WHERE id = ?
                    """,
                arguments: [
                    record.diagnosticJson,
                    record.lastSeenAt,
                    increment.partialValue,
                    record.id,
                ]
            )
            return
        }

        try database.execute(
            sql: """
                INSERT INTO failure_record (
                  id, operation, scopeKind, campId, scopeType, scopeId,
                  severity, errorCode, userMessage, diagnosticJson, state,
                  firstSeenAt, lastSeenAt, occurrenceCount,
                  resolvedAt, redactedAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                record.id,
                record.operation.rawValue,
                record.scope.campId == nil ? "global" : "camp",
                record.scope.campId,
                record.scope.type.rawValue,
                record.scope.id,
                record.severity.rawValue,
                record.errorCode.rawValue,
                record.userMessage,
                record.diagnosticJson,
                record.state.rawValue,
                record.firstSeenAt,
                record.lastSeenAt,
                record.occurrenceCount,
                record.resolvedAt,
                record.redactedAt,
            ]
        )
    }

    private static func insertContextDegradation(
        _ record: ContextDegradationRecord,
        database: Database
    ) throws {
        try database.execute(
            sql: """
                INSERT INTO context_degradation (
                  id, missionId, cardId, dependencyType, dependencyId,
                  policy, traceId, detail, createdAt, redactedAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                record.id,
                record.missionId,
                record.cardId,
                record.dependencyType.rawValue,
                record.dependencyId,
                record.policy.rawValue,
                record.traceId,
                record.detail,
                record.createdAt,
                record.redactedAt,
            ]
        )
    }

    private static func fetchFailureRecord(
        id: String,
        database: Database
    ) throws -> FailureRecord? {
        try FailureRecord.fetchOne(
            database,
            sql: "SELECT * FROM failure_record WHERE id = ?",
            arguments: [id]
        )
    }
}

extension AppDatabase {
    package func prepareRuminationStart(
        ingestionId: String
    ) throws -> RuminationStartPreparation {
        try pool.read { database in
            guard let item = try IngestionItemRecord.fetchOne(
                database,
                key: ingestionId
            ) else {
                throw FeedServiceError.ingestionNotFound(ingestionId)
            }
            guard let lifecycle = try Row.fetchOne(
                database,
                sql: """
                    SELECT lifecycle.state,lifecycle.version,camp.archived
                    FROM camp_lifecycle AS lifecycle
                    JOIN camp ON camp.id=lifecycle.campId
                    WHERE lifecycle.campId=?
                    """,
                arguments: [item.campId]
            ) else {
                throw CampLifecycleWriteAuthorizationError.missing
            }
            guard let lifecycleState = CampLifecycleStateV1(
                rawValue: lifecycle["state"] as String
            ), lifecycleState == .active else {
                throw CampLifecycleWriteAuthorizationError.inactive(
                    CampLifecycleStateV1(
                        rawValue: lifecycle["state"] as String
                    ) ?? .deletedTombstone
                )
            }
            guard (lifecycle["archived"] as Int) == 0 else {
                throw CampLifecycleWriteAuthorizationError.legacyArchived
            }

            switch item.status {
            case .queued, .failed:
                let unexpectedActive = try Int.fetchOne(
                    database,
                    sql: """
                        SELECT COUNT(*)
                        FROM durable_work
                        WHERE kind = 'rumination'
                          AND aggregateType = 'ingestion'
                          AND aggregateId = ?
                          AND state IN (
                            'queued','running','retryScheduled'
                          )
                        """,
                    arguments: [item.id]
                ) ?? 0
                guard unexpectedActive == 0 else {
                    throw RuminationStartRecoveryRequiredError(
                        ingestionId: item.id
                    )
                }
                let (generation, overflow) =
                    item.attempt.addingReportingOverflow(1)
                guard !overflow else {
                    throw InvalidDurableWorkStateError()
                }
                return .new(
                    ingestionId: item.id,
                    expectedPreviousAttempt: item.attempt,
                    generation: generation,
                    idempotencyKey:
                        "rumination-start:\(item.id):\(generation):v1"
                )
            case .ruminating:
                let active = try DurableWorkRecord.fetchAll(
                    database,
                    sql: """
                        SELECT *
                        FROM durable_work
                        WHERE kind = 'rumination'
                          AND aggregateType = 'ingestion'
                          AND aggregateId = ?
                          AND state IN (
                            'queued','running','retryScheduled'
                          )
                        ORDER BY createdAt, rowid
                        """,
                    arguments: [item.id]
                )
                guard active.count == 1, let work = active.first else {
                    throw RuminationStartRecoveryRequiredError(
                        ingestionId: item.id
                    )
                }
                do {
                    try Self.validateActiveRuminationReplay(
                        database,
                        item: item,
                        work: work
                    )
                } catch {
                    throw RuminationStartRecoveryRequiredError(
                        ingestionId: item.id
                    )
                }
                return .replay(
                    ingestionId: item.id,
                    workId: work.id
                )
            case .needsReview, .materialized, .discarded:
                throw FeedServiceError.invalidState(item.status)
            }
        }
    }

    private static func validateActiveRuminationReplay(
        _ database: Database,
        item: IngestionItemRecord,
        work: DurableWorkRecord
    ) throws {
        let inputBytes = Data(work.inputJson.utf8)
        let input = try JSONDecoder().decode(
            RuminationWorkInput.self,
            from: inputBytes
        )
        guard try CanonicalJSONV1.encode(input) == inputBytes,
              CanonicalJSONV1.sha256Hex(inputBytes) == work.inputHash,
              work.kind == .rumination,
              work.aggregateType == "ingestion",
              work.aggregateId == item.id,
              work.campId == item.campId,
              work.maxAttempts == 4,
              [.queued, .running, .retryScheduled].contains(work.state)
        else {
            throw DurableWorkReplayConflictError()
        }

        let normalKey =
            "rumination-start:\(item.id):\(item.attempt):v1"
        guard work.idempotencyKey == normalKey
                || work.idempotencyKey
                    == "legacy-rumination:\(item.id)"
        else {
            throw DurableWorkReplayConflictError()
        }
        guard let currentLifecycleVersion = try Int.fetchOne(
            database,
            sql: "SELECT version FROM camp_lifecycle WHERE campId=? AND state='active'",
            arguments: [item.campId]
        ), let workLifecycleVersion = try Int.fetchOne(
            database,
            sql: "SELECT campLifecycleVersion FROM durable_work WHERE id=?",
            arguments: [work.id]
        ), workLifecycleVersion == currentLifecycleVersion else {
            throw DurableWorkReplayConflictError()
        }

        let openAttempts = try DurableWorkAttemptRecord
            .filter(
                Column("workId") == work.id
                    && Column("endedAt") == nil
            )
            .fetchAll(database)
        switch work.state {
        case .running:
            guard openAttempts.count == 1,
                  openAttempts[0].attempt == work.attempt,
                  openAttempts[0].workerId == work.leaseOwner,
                  work.attempt >= 1,
                  work.leaseOwner != nil,
                  work.leaseExpiresAt != nil
            else {
                throw DurableWorkReplayConflictError()
            }
        case .queued, .retryScheduled:
            guard openAttempts.isEmpty,
                  work.leaseOwner == nil,
                  work.leaseExpiresAt == nil
            else {
                throw DurableWorkReplayConflictError()
            }
        default:
            throw DurableWorkReplayConflictError()
        }
    }
}
