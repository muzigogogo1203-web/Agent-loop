#!/bin/bash
set -euo pipefail

fail() {
    printf 'P1 migration matrix: %s\n' "$*" >&2
    exit 1
}

require_file() {
    test -f "$1" || fail "required file is missing: $1"
}

assert_query() {
    local sqlite_cli="$1"
    local database_file="$2"
    local sql="$3"
    local expected="$4"
    local label="$5"
    local actual

    require_file "$database_file"
    actual="$("$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$database_file" "$sql")"
    test "$actual" = "$expected" \
        || fail "$label: expected [$expected], got [$actual]"
}

expect_sqlite_failure() {
    local sqlite_cli="$1"
    local database_file="$2"
    local sql="$3"
    local label="$4"

    require_file "$database_file"
    if "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$database_file" "$sql"
    then
        fail "$label unexpectedly succeeded"
    fi
}

expect_sqlite_failure_containing() {
    local sqlite_cli="$1"
    local database_file="$2"
    local sql="$3"
    local expected="$4"
    local label="$5"
    local output

    require_file "$database_file"
    if output="$("$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$database_file" "$sql" 2>&1)"
    then
        fail "$label unexpectedly succeeded"
    fi
    printf '%s\n' "$output" | grep -Fq -- "$expected" \
        || fail "$label failed without [$expected]: $output"
}

assert_file_line() {
    local file="$1"
    local expected="$2"
    local label="$3"

    require_file "$file"
    grep -Fqx -- "$expected" "$file" \
        || fail "$label is missing: $expected"
}

assert_ordered_unique_lines() {
    local file="$1"
    shift
    local previous=0
    local expected
    local matches
    local count
    local line

    require_file "$file"
    for expected in "$@"; do
        matches="$(grep -Fnx -- "$expected" "$file" || true)"
        count="$(printf '%s\n' "$matches" \
            | awk 'NF { count += 1 } END { print count + 0 }')"
        test "$count" = "1" \
            || fail "ordered sentinel [$expected] occurs $count times"
        line="${matches%%:*}"
        test "$line" -gt "$previous" \
            || fail "ordered sentinel [$expected] is out of order"
        previous="$line"
    done
}

lane_351=0
lane_352=0
while test "$#" -gt 0; do
    case "$1" in
        --sqlite)
            test "$#" -ge 2 || fail "--sqlite requires a value"
            case "$2" in
                3.51)
                    test "$lane_351" -eq 0 \
                        || fail "duplicate --sqlite 3.51"
                    lane_351=1
                    ;;
                3.52)
                    test "$lane_352" -eq 0 \
                        || fail "duplicate --sqlite 3.52"
                    lane_352=1
                    ;;
                *)
                    fail "unsupported SQLite lane: $2"
                    ;;
            esac
            shift 2
            ;;
        *)
            fail "unknown argument: $1"
            ;;
    esac
done

test "$lane_351" -eq 1 && test "$lane_352" -eq 1 \
    || fail "both --sqlite 3.51 and --sqlite 3.52 are required"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/.." && pwd -P)"
stage_spec="$repo_root/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md"
runner_source="$repo_root/Sources/P1MigrationMatrixRunner/main.swift"
app_database_source="$repo_root/Sources/AgentLoopCore/Database/AppDatabase.swift"
resolved_file="$repo_root/Package.resolved"
swift_bin="$(xcrun --find swift)"
system_sqlite="/usr/bin/sqlite3"
homebrew_sqlite="/opt/homebrew/opt/sqlite/bin/sqlite3"
homebrew_sqlite_lib="/opt/homebrew/opt/sqlite/lib"
grdb_checkout="$repo_root/.build/checkouts/GRDB.swift"
sqlite_submodule_mirror="$grdb_checkout/SQLiteCustom/src"

require_file "$stage_spec"
require_file "$runner_source"
require_file "$app_database_source"
require_file "$resolved_file"
require_file "$system_sqlite"
require_file "$homebrew_sqlite"
require_file "$homebrew_sqlite_lib/libsqlite3.dylib"
test -e "$sqlite_submodule_mirror/.git" \
    || fail "local SQLiteLib submodule mirror is missing"

grdb_submodule_revision="$(git -C "$grdb_checkout" \
    ls-tree HEAD SQLiteCustom/src | awk '{print $3}')"
test -n "$grdb_submodule_revision" \
    || fail "could not resolve the GRDB SQLiteLib submodule revision"
git -C "$sqlite_submodule_mirror" \
    cat-file -e "$grdb_submodule_revision^{commit}" \
    || fail "local SQLiteLib mirror lacks $grdb_submodule_revision"

expected_stage_hash="bacc1a99492f4d4acdb48ffb4f94918ffa7ba0358122547db7a828b31c1620b6"
actual_stage_hash="$(shasum -a 256 "$stage_spec" | awk '{print $1}')"
test "$actual_stage_hash" = "$expected_stage_hash" \
    || fail "frozen Stage hash drifted: $actual_stage_hash"

expected_resolved_hash="d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a"
resolved_hash_before="$(shasum -a 256 "$resolved_file" | awk '{print $1}')"
test "$resolved_hash_before" = "$expected_resolved_hash" \
    || fail "frozen Package.resolved hash drifted: $resolved_hash_before"

matrix_tmp_parent="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
matrix_tmp="$(mktemp -d \
    "${matrix_tmp_parent%/}/agentloop-p1-matrix.XXXXXX")"

cleanup() {
    case "$matrix_tmp" in
        "${matrix_tmp_parent%/}/agentloop-p1-matrix."*)
            rm -rf -- "$matrix_tmp"
            ;;
        *)
            printf 'P1 migration matrix: refusing unsafe cleanup: %s\n' \
                "$matrix_tmp" >&2
            ;;
    esac
}
trap cleanup EXIT

literal_durable_sql="$matrix_tmp/v12-p1-durable-work.sql"
awk '
    /^### 18\.1 / { section = 1; next }
    section && /^```sql$/ { fence = 1; next }
    fence && /^```$/ { exit }
    fence { print }
' "$stage_spec" > "$literal_durable_sql"

literal_durable_line_count="$(wc -l < "$literal_durable_sql" | tr -d ' ')"
literal_durable_hash="$(shasum -a 256 "$literal_durable_sql" | awk '{print $1}')"
test "$literal_durable_line_count" = "187" \
    || fail "§18.1 literal line count is $literal_durable_line_count, expected 187"
test "$literal_durable_hash" = \
    "fb77180d6edd44413e41179e4b220666438e2660de11fbde1dafee78b6fde5c2" \
    || fail "§18.1 literal hash drifted: $literal_durable_hash"

literal_schedule_sql="$matrix_tmp/v12-p1-schedule-fire.sql"
awk '
    /^### 18\.2 / { section = 1; next }
    section && /^```sql$/ { fence = 1; next }
    fence && /^```$/ { exit }
    fence { print }
' "$stage_spec" > "$literal_schedule_sql"

literal_schedule_line_count="$(wc -l < "$literal_schedule_sql" | tr -d ' ')"
literal_schedule_hash="$(shasum -a 256 "$literal_schedule_sql" | awk '{print $1}')"
test "$literal_schedule_line_count" = "47" \
    || fail "§18.2 literal line count is $literal_schedule_line_count, expected 47"
test "$literal_schedule_hash" = \
    "c693edcdfe15d586b018bc51dceeebf8091544edede5dc9eb775a105153717ea" \
    || fail "§18.2 literal hash drifted: $literal_schedule_hash"

literal_observability_sql="$matrix_tmp/v13-p1-observability.sql"
awk '
    /^### 18\.3 / { section = 1; next }
    section && /^```sql$/ { fence = 1; next }
    fence && /^```$/ { exit }
    fence { print }
' "$stage_spec" > "$literal_observability_sql"

literal_observability_line_count="$(wc -l < "$literal_observability_sql" | tr -d ' ')"
literal_observability_hash="$(shasum -a 256 "$literal_observability_sql" | awk '{print $1}')"
test "$literal_observability_line_count" = "49" \
    || fail "§18.3 literal line count is $literal_observability_line_count, expected 49"
test "$literal_observability_hash" = \
    "a0fe7c90723220a8e5a1402cc9f9b1997e04cf2d8a45de6474e8e5f9b599f087" \
    || fail "§18.3 literal hash drifted: $literal_observability_hash"

literal_control_sql="$matrix_tmp/v14-p1-control-contracts.sql"
awk '
    /^### 18\.4 / { section = 1; next }
    section && /^```sql$/ { fence = 1; next }
    fence && /^```$/ { exit }
    fence { print }
' "$stage_spec" > "$literal_control_sql"

literal_control_line_count="$(wc -l < "$literal_control_sql" | tr -d ' ')"
literal_control_hash="$(shasum -a 256 "$literal_control_sql" | awk '{print $1}')"
test "$literal_control_line_count" = "292" \
    || fail "§18.4 literal line count is $literal_control_line_count, expected 292"
test "$literal_control_hash" = \
    "a62302bf5f45ef07caded2899322ce3e94e51d21ddc28b3cdb9c102d6936d531" \
    || fail "§18.4 literal hash drifted: $literal_control_hash"

literal_outcome_sql="$matrix_tmp/v15-p1-outcome-contracts.sql"
awk '
    /^### 18\.5 / { section = 1; next }
    section && /^```sql$/ { fence = 1; next }
    fence && /^```$/ { exit }
    fence { print }
' "$stage_spec" > "$literal_outcome_sql"

literal_outcome_line_count="$(wc -l < "$literal_outcome_sql" | tr -d ' ')"
literal_outcome_hash="$(shasum -a 256 "$literal_outcome_sql" | awk '{print $1}')"
test "$literal_outcome_line_count" = "515" \
    || fail "§18.5 literal line count is $literal_outcome_line_count, expected 515"
test "$literal_outcome_hash" = \
    "0fa300dd5c90e12a90b7cf3f9f0eb84af07f4d9bbc36f869123bdda236214cbb" \
    || fail "§18.5 literal hash drifted: $literal_outcome_hash"

literal_identity_memory_sql="$matrix_tmp/v16-p1-identity-memory.sql"
awk '
    /^### 18\.6 / { section = 1; next }
    section && /^```sql$/ { fence = 1; next }
    fence && /^```$/ { exit }
    fence { print }
' "$stage_spec" | sed '$d' > "$literal_identity_memory_sql"

literal_identity_memory_line_count="$(wc -l < "$literal_identity_memory_sql" | tr -d ' ')"
literal_identity_memory_hash="$(shasum -a 256 "$literal_identity_memory_sql" | awk '{print $1}')"
test "$literal_identity_memory_line_count" = "1998" \
    || fail "§18.6 literal line count is $literal_identity_memory_line_count, expected 1998"
test "$literal_identity_memory_hash" = \
    "3a86de973a0feff2a5a26bbd6d721464382f6cd13c667b062501808a5325fd71" \
    || fail "§18.6 literal hash drifted: $literal_identity_memory_hash"

literal_engine_coordination_sql="$matrix_tmp/v17-p1-engine-coordination.sql"
awk '
    /^### 18\.7 / { section = 1; next }
    section && /^```sql$/ { fence = 1; next }
    fence && /^```$/ { exit }
    fence { print }
' "$stage_spec" | sed '$d' > "$literal_engine_coordination_sql"

literal_engine_coordination_byte_count="$(wc -c < "$literal_engine_coordination_sql" | tr -d ' ')"
literal_engine_coordination_line_count="$(wc -l < "$literal_engine_coordination_sql" | tr -d ' ')"
literal_engine_coordination_nonblank_count="$(awk 'NF { count += 1 } END { print count + 0 }' "$literal_engine_coordination_sql")"
literal_engine_coordination_hash="$(shasum -a 256 "$literal_engine_coordination_sql" | awk '{print $1}')"
test "$literal_engine_coordination_byte_count" = "29934" \
    || fail "§18.7 literal byte count is $literal_engine_coordination_byte_count, expected 29934"
test "$literal_engine_coordination_line_count" = "770" \
    || fail "§18.7 literal line count is $literal_engine_coordination_line_count, expected 770"
test "$literal_engine_coordination_nonblank_count" = "757" \
    || fail "§18.7 literal nonblank count is $literal_engine_coordination_nonblank_count, expected 757"
test "$literal_engine_coordination_hash" = \
    "a6ef8747ee3e8ffeb0856827f6cf8f858c681a70748cd373783ae1d23d2b4e99" \
    || fail "§18.7 literal hash drifted: $literal_engine_coordination_hash"

printf 'stage.sha256=%s\n' "$actual_stage_hash"
printf 'literal.sha256=%s\n' "$literal_durable_hash"
printf 'literal_durable.sha256=%s\n' "$literal_durable_hash"
printf 'literal_schedule.sha256=%s\n' "$literal_schedule_hash"
printf 'literal_observability.sha256=%s\n' "$literal_observability_hash"
printf 'literal_control.sha256=%s\n' "$literal_control_hash"
printf 'literal_outcome.sha256=%s\n' "$literal_outcome_hash"
printf 'literal_identity_memory.sha256=%s\n' "$literal_identity_memory_hash"
printf 'literal_identity_memory.checkpoint=67/171/67\n'
printf 'literal_engine_coordination.sha256=%s\n' \
    "$literal_engine_coordination_hash"
printf 'literal_engine_coordination.bytes=%s\n' \
    "$literal_engine_coordination_byte_count"
printf 'literal_engine_coordination.lines=%s\n' \
    "$literal_engine_coordination_line_count"
printf 'literal_engine_coordination.nonblank=%s\n' \
    "$literal_engine_coordination_nonblank_count"
printf 'literal_engine_coordination.checkpoint=79/208/84\n'
printf 'runner.sha256=%s\n' \
    "$(shasum -a 256 "$runner_source" | awk '{print $1}')"
printf 'app_database.sha256=%s\n' \
    "$(shasum -a 256 "$app_database_source" | awk '{print $1}')"

swift_build() {
    GIT_CONFIG_COUNT=2 \
    GIT_CONFIG_KEY_0="url.file://$sqlite_submodule_mirror.insteadOf" \
    GIT_CONFIG_VALUE_0="https://github.com/swiftlyfalling/SQLiteLib.git" \
    GIT_CONFIG_KEY_1="protocol.file.allow" \
    GIT_CONFIG_VALUE_1="always" \
        "$swift_bin" build "$@"
}

build_runner() {
    local lane="$1"
    local scratch_root="$matrix_tmp/build-$lane"
    local bin_dir
    local runner_bin
    local linkage

    if test "$lane" = "3.51"; then
        swift_build \
            --package-path "$repo_root" \
            --cache-path "$repo_root/.build" \
            --scratch-path "$scratch_root" \
            --disable-automatic-resolution \
            --product P1MigrationMatrixRunner \
            -Xswiftc -DSQLITE_DISABLE_SNAPSHOT >&2
        bin_dir="$(swift_build \
            --package-path "$repo_root" \
            --cache-path "$repo_root/.build" \
            --scratch-path "$scratch_root" \
            --disable-automatic-resolution \
            --show-bin-path \
            -Xswiftc -DSQLITE_DISABLE_SNAPSHOT)"
    else
        swift_build \
            --package-path "$repo_root" \
            --cache-path "$repo_root/.build" \
            --scratch-path "$scratch_root" \
            --disable-automatic-resolution \
            --product P1MigrationMatrixRunner \
            -Xswiftc -DSQLITE_DISABLE_SNAPSHOT \
            -Xswiftc -L"$homebrew_sqlite_lib" \
            -Xlinker -rpath \
            -Xlinker "$homebrew_sqlite_lib" >&2
        bin_dir="$(swift_build \
            --package-path "$repo_root" \
            --cache-path "$repo_root/.build" \
            --scratch-path "$scratch_root" \
            --disable-automatic-resolution \
            --show-bin-path \
            -Xswiftc -DSQLITE_DISABLE_SNAPSHOT \
            -Xswiftc -L"$homebrew_sqlite_lib" \
            -Xlinker -rpath \
            -Xlinker "$homebrew_sqlite_lib")"
    fi

    runner_bin="$bin_dir/P1MigrationMatrixRunner"
    test -x "$runner_bin" || fail "runner is not executable: $runner_bin"
    linkage="$(otool -L "$runner_bin")"
    printf '%s\n' "$linkage" >&2

    if test "$lane" = "3.51"; then
        printf '%s\n' "$linkage" \
            | grep -Fq "/usr/lib/libsqlite3.dylib" \
            || fail "3.51 runner is not linked to system SQLite"
        if printf '%s\n' "$linkage" \
            | grep -Fq "$homebrew_sqlite_lib/libsqlite3.dylib"
        then
            fail "3.51 runner unexpectedly links Homebrew SQLite"
        fi
    else
        printf '%s\n' "$linkage" \
            | grep -Fq "$homebrew_sqlite_lib/libsqlite3.dylib" \
            || fail "3.52 runner is not linked to Homebrew SQLite"
        if printf '%s\n' "$linkage" \
            | grep -Fq "/usr/lib/libsqlite3.dylib"
        then
            fail "3.52 runner unexpectedly links system SQLite"
        fi
    fi

    printf '%s\n' "$runner_bin"
}

cli_version() {
    local sqlite_cli="$1"
    "$sqlite_cli" -init /dev/null -batch :memory: \
        "SELECT sqlite_version();"
}

verify_literal_lane() {
    local lane="$1"
    local sqlite_cli="$2"
    local lane_root="$3"
    local baseline="$lane_root/literal-v12-durable.sqlite"
    local success_database="$lane_root/literal-success.sqlite"
    local rollback_database="$lane_root/literal-rollback.sqlite"
    local success_input="$lane_root/literal-success.sql"
    local rollback_input="$lane_root/literal-rollback.sql"
    local before_dump="$lane_root/literal-before.dump"
    local after_dump="$lane_root/literal-after.dump"
    local before_hash
    local after_hash
    local prefix

    require_file "$baseline"
    cp "$baseline" "$success_database"
    cp "$baseline" "$rollback_database"

    {
        printf 'PRAGMA foreign_keys = ON;\n'
        printf 'BEGIN IMMEDIATE;\n'
        awk '{ print }' "$literal_schedule_sql"
        printf 'COMMIT;\n'
    } > "$success_input"
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" < "$success_input"

    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" \
        "29" "$lane literal table checkpoint"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='index';" \
        "60" "$lane literal index checkpoint"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='trigger';" \
        "4" "$lane literal trigger checkpoint"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT group_concat(name,',') FROM (SELECT name FROM sqlite_master WHERE type='trigger' ORDER BY name);" \
        "durable_work_attempt_event_reject_delete,durable_work_attempt_event_reject_update,event_no_delete,event_no_update" \
        "$lane literal exact trigger set"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM grdb_migrations WHERE identifier='v12-p1-durable-work';" \
        "1" "$lane literal durable migration baseline"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM grdb_migrations WHERE identifier='v12-p1-schedule-fire';" \
        "0" "$lane literal schedule migration is SQL-only"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN ('durable_work','durable_work_attempt','durable_work_attempt_event');" \
        "3" "$lane literal durable tables"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN ('schedule_fire','schedule_evaluation_cursor');" \
        "2" "$lane literal schedule tables"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name IN ('durable_work_one_active_aggregate','durable_work_claimable','durable_work_aggregate_history','durable_work_attempt_one_terminal','durable_work_attempt_event_work');" \
        "5" "$lane literal durable indexes"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='trigger' AND name IN ('durable_work_attempt_event_reject_update','durable_work_attempt_event_reject_delete');" \
        "2" "$lane literal durable triggers"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT group_concat(name,',') FROM (SELECT name FROM pragma_table_info('schedule_fire') ORDER BY cid);" \
        "id,scheduleId,templateId,slotKey,scheduledAt,replayOfFireId,replayIdempotencyKey,replayPayloadHash,state,missionId,traceId,errorCode,errorMessage,createdAt,redactedAt" \
        "$lane literal schedule_fire columns"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT group_concat(name,',') FROM (SELECT name FROM pragma_table_info('schedule_evaluation_cursor') ORDER BY cid);" \
        "scheduleId,lastEvaluatedSlotKey,lastEvaluatedScheduledAt,version,updatedAt" \
        "$lane literal cursor columns"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT group_concat(name,',') FROM (SELECT name FROM sqlite_master WHERE type='index' AND (name LIKE '%schedule_fire%' OR name LIKE '%schedule_evaluation_cursor%') ORDER BY name);" \
        "schedule_fire_original_slot,schedule_fire_replay_key,schedule_fire_schedule_time,sqlite_autoindex_schedule_evaluation_cursor_1,sqlite_autoindex_schedule_fire_1" \
        "$lane literal exact schedule indexes"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT instr(sql,'WHERE replayOfFireId IS NULL')>0 FROM sqlite_master WHERE type='index' AND name='schedule_fire_original_slot';" \
        "1" "$lane literal original index predicate"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT instr(sql,'WHERE replayIdempotencyKey IS NOT NULL')>0 FROM sqlite_master WHERE type='index' AND name='schedule_fire_replay_key';" \
        "1" "$lane literal replay index predicate"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT group_concat(shape,',') FROM (SELECT \"from\"||'|'||\"table\"||'|'||\"to\"||'|'||on_delete AS shape FROM pragma_foreign_key_list('schedule_fire') ORDER BY \"from\");" \
        "missionId|mission|id|RESTRICT,replayOfFireId|schedule_fire|id|RESTRICT,scheduleId|schedule|id|RESTRICT,templateId|mission_template|id|RESTRICT" \
        "$lane literal schedule_fire foreign keys"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT group_concat(shape,',') FROM (SELECT \"from\"||'|'||\"table\"||'|'||\"to\"||'|'||on_delete AS shape FROM pragma_foreign_key_list('schedule_evaluation_cursor') ORDER BY \"from\");" \
        "scheduleId|schedule|id|CASCADE" \
        "$lane literal cursor foreign key"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='trigger' AND tbl_name IN ('schedule_fire','schedule_evaluation_cursor');" \
        "0" "$lane literal no A4 trigger"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT (instr(sql,'state IN (''started'',''failed'')')>0) || '|' || (instr(sql,'intended')=0) || '|' || (instr(sql,'length(replayPayloadHash) = 64')>0) || '|' || (instr(sql,'length(errorMessage) <= 1000')>0) || '|' || (instr(sql,'redactedAt IS NULL OR errorMessage IS NULL')>0) FROM sqlite_master WHERE type='table' AND name='schedule_fire';" \
        "1|1|1|1|1" "$lane literal schedule_fire CHECK DDL"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM schedule_fire;" \
        "0" "$lane literal schedule_fire initially empty"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM schedule_evaluation_cursor;" \
        "0" "$lane literal cursor initially empty"
    assert_query "$sqlite_cli" "$success_database" \
        "PRAGMA foreign_key_check;" "" "$lane literal foreign keys"
    assert_query "$sqlite_cli" "$success_database" \
        "PRAGMA integrity_check;" "ok" "$lane literal integrity"

    prefix="literal_${lane//./_}"
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" "
        PRAGMA foreign_keys = ON;
        INSERT INTO camp(id,name,archived,createdAt)
          VALUES('$prefix-camp','Literal $lane',0,1700000000.25);
        INSERT INTO mission_template(
          id,name,goal,companionIdsJson,workspacePath,budgetTokens,autonomy,
          campId,createdAt
        ) VALUES(
          '$prefix-template','Template','Goal','[]',NULL,1000,'standard',
          '$prefix-camp',1700000000.25
        );
        INSERT INTO schedule(
          id,templateId,frequency,hour,minute,weekday,enabled,lastFiredAt,
          createdAt
        ) VALUES(
          '$prefix-schedule','$prefix-template','daily',9,30,NULL,1,NULL,
          1700000000.25
        );
        INSERT INTO schedule(
          id,templateId,frequency,hour,minute,weekday,enabled,lastFiredAt,
          createdAt
        ) VALUES(
          '$prefix-cursor-only-schedule','$prefix-template','daily',10,45,
          NULL,1,NULL,1700000000.25
        );
        INSERT INTO squad(
          id,campId,name,memberIdsJson,workspacePath,workspaceBookmark,createdAt
        ) VALUES(
          '$prefix-squad','$prefix-camp','Squad','[]',NULL,NULL,
          1700000000.25
        );
        INSERT INTO mission(
          id,squadId,goalRaw,goalRefined,status,budgetTokens,spentTokens,
          revision,autonomy,createdAt
        ) VALUES(
          '$prefix-mission','$prefix-squad','Goal','Goal','planning',1000,0,
          1,'standard',1700000000.25
        );
        INSERT INTO schedule_fire(
          id,scheduleId,templateId,slotKey,scheduledAt,replayOfFireId,
          replayIdempotencyKey,replayPayloadHash,state,missionId,traceId,
          errorCode,errorMessage,createdAt,redactedAt
        ) VALUES(
          '$prefix-started','$prefix-schedule','$prefix-template',
          'slot-started',1700000000.25,NULL,NULL,NULL,'started',
          '$prefix-mission','$prefix-trace-started',NULL,NULL,
          1700000000.5,NULL
        );
        INSERT INTO schedule_fire(
          id,scheduleId,templateId,slotKey,scheduledAt,replayOfFireId,
          replayIdempotencyKey,replayPayloadHash,state,missionId,traceId,
          errorCode,errorMessage,createdAt,redactedAt
        ) VALUES(
          '$prefix-failed','$prefix-schedule','$prefix-template',
          'slot-failed',1700000000.5,NULL,NULL,NULL,'failed',NULL,
          '$prefix-trace-failed','schedule_configuration_invalid',
          printf('%01000d',0),1700000000.75,NULL
        );
        INSERT INTO schedule_fire(
          id,scheduleId,templateId,slotKey,scheduledAt,replayOfFireId,
          replayIdempotencyKey,replayPayloadHash,state,missionId,traceId,
          errorCode,errorMessage,createdAt,redactedAt
        ) VALUES(
          '$prefix-replay','$prefix-schedule','$prefix-template',
          'slot-replay',1700000000.25,'$prefix-failed','$prefix-replay-key',
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'started','$prefix-mission','$prefix-trace-replay',NULL,NULL,
          1700000000.75,NULL
        );
        INSERT INTO schedule_fire(
          id,scheduleId,templateId,slotKey,scheduledAt,replayOfFireId,
          replayIdempotencyKey,replayPayloadHash,state,missionId,traceId,
          errorCode,errorMessage,createdAt,redactedAt
        ) VALUES(
          '$prefix-redacted','$prefix-schedule','$prefix-template',
          'slot-redacted',1700000000.25,NULL,NULL,NULL,'failed',NULL,
          '$prefix-trace-redacted','schedule_configuration_invalid',NULL,
          1700000000.75,1700000001.25
        );
        INSERT INTO schedule_evaluation_cursor(
          scheduleId,lastEvaluatedSlotKey,lastEvaluatedScheduledAt,version,
          updatedAt
        ) VALUES(
          '$prefix-schedule','slot-replay',1700000000.5,1,1700000000.75
        );
        INSERT INTO schedule_evaluation_cursor(
          scheduleId,lastEvaluatedSlotKey,lastEvaluatedScheduledAt,version,
          updatedAt
        ) VALUES(
          '$prefix-cursor-only-schedule','slot-cursor-only',1700000000.5,1,
          1700000000.75
        );
        INSERT INTO durable_work(
          id,campId,kind,aggregateType,aggregateId,idempotencyKey,state,
          attempt,maxAttempts,notBefore,leaseOwner,leaseExpiresAt,inputJson,
          inputHash,outputJson,errorCode,errorMessage,traceId,version,
          createdAt,updatedAt,finishedAt
        ) VALUES(
          '$prefix-work','$prefix-camp','planning','mission',
          '$prefix-aggregate','$prefix-idem','running',1,4,NULL,'worker',
          1000060,'{\"value\":1}',
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          NULL,NULL,NULL,'$prefix-trace',2,1000000,1000000,NULL
        );
        INSERT INTO durable_work_attempt(
          workId,attempt,id,workerId,startedAt,endedAt,outcome,errorCode,
          errorMessage,traceId,terminalWorkVersion
        ) VALUES(
          '$prefix-work',1,'$prefix-attempt','worker',1000000,NULL,NULL,
          NULL,NULL,'$prefix-trace',NULL
        );
        INSERT INTO durable_work_attempt_event(
          id,workId,attempt,sequence,eventKind,workerId,workVersion,
          resultingWorkState,errorCode,errorMessage,occurredAt
        ) VALUES(
          '$prefix-event','$prefix-work',1,0,'claimed','worker',2,
          'running',NULL,NULL,1000000
        );
        "

    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM schedule_fire;" \
        "4" "$lane literal legal schedule fire rows"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM schedule_evaluation_cursor;" \
        "2" "$lane literal legal cursor rows"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT length(errorMessage) FROM schedule_fire WHERE id='$prefix-failed';" \
        "1000" "$lane literal legal error message boundary"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT typeof(scheduledAt)||'|'||typeof(createdAt)||'|'||typeof(redactedAt) FROM schedule_fire WHERE id='$prefix-redacted';" \
        "real|real|real" "$lane literal fire numeric dates"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT typeof(lastEvaluatedScheduledAt)||'|'||typeof(updatedAt) FROM schedule_evaluation_cursor WHERE scheduleId='$prefix-schedule';" \
        "real|real" "$lane literal cursor numeric dates"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT (scheduledAt=1700000000.25)||'|'||(createdAt=1700000000.5) FROM schedule_fire WHERE id='$prefix-started';" \
        "1|1" "$lane literal fire date round trip"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT (lastEvaluatedScheduledAt=1700000000.5)||'|'||(updatedAt=1700000000.75) FROM schedule_evaluation_cursor WHERE scheduleId='$prefix-schedule';" \
        "1|1" "$lane literal cursor date round trip"

    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO schedule_fire(id,scheduleId,templateId,slotKey,scheduledAt,state,missionId,traceId,createdAt) VALUES('$prefix-illegal-intended','$prefix-schedule','$prefix-template','slot-illegal-intended',1700000000.25,'intended','$prefix-mission','$prefix-trace-illegal-intended',1700000000.75);" \
        "$lane literal intended CHECK"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO schedule_fire(id,scheduleId,templateId,slotKey,scheduledAt,replayOfFireId,state,traceId,errorCode,createdAt) VALUES('$prefix-illegal-partial','$prefix-schedule','$prefix-template','slot-illegal-partial',1700000000.25,'$prefix-failed','failed','$prefix-trace-illegal-partial','schedule_configuration_invalid',1700000000.75);" \
        "$lane literal partial replay CHECK"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO schedule_fire(id,scheduleId,templateId,slotKey,scheduledAt,replayOfFireId,replayIdempotencyKey,replayPayloadHash,state,traceId,errorCode,createdAt) VALUES('$prefix-illegal-short-hash','$prefix-schedule','$prefix-template','slot-illegal-short-hash',1700000000.25,'$prefix-failed','$prefix-short-hash-key','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','failed','$prefix-trace-illegal-short-hash','schedule_configuration_invalid',1700000000.75);" \
        "$lane literal replay hash CHECK"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO schedule_fire(id,scheduleId,templateId,slotKey,scheduledAt,state,traceId,createdAt) VALUES('$prefix-illegal-started-no-mission','$prefix-schedule','$prefix-template','slot-illegal-started-no-mission',1700000000.25,'started','$prefix-trace-illegal-started-no-mission',1700000000.75);" \
        "$lane literal started mission CHECK"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO schedule_fire(id,scheduleId,templateId,slotKey,scheduledAt,state,missionId,traceId,errorCode,createdAt) VALUES('$prefix-illegal-started-error','$prefix-schedule','$prefix-template','slot-illegal-started-error',1700000000.25,'started','$prefix-mission','$prefix-trace-illegal-started-error','schedule_configuration_invalid',1700000000.75);" \
        "$lane literal started error CHECK"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO schedule_fire(id,scheduleId,templateId,slotKey,scheduledAt,state,missionId,traceId,errorCode,createdAt) VALUES('$prefix-illegal-failed-mission','$prefix-schedule','$prefix-template','slot-illegal-failed-mission',1700000000.25,'failed','$prefix-mission','$prefix-trace-illegal-failed-mission','schedule_configuration_invalid',1700000000.75);" \
        "$lane literal failed mission CHECK"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO schedule_fire(id,scheduleId,templateId,slotKey,scheduledAt,state,traceId,createdAt) VALUES('$prefix-illegal-failed-no-code','$prefix-schedule','$prefix-template','slot-illegal-failed-no-code',1700000000.25,'failed','$prefix-trace-illegal-failed-no-code',1700000000.75);" \
        "$lane literal failed code CHECK"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO schedule_fire(id,scheduleId,templateId,slotKey,scheduledAt,state,traceId,errorCode,errorMessage,createdAt) VALUES('$prefix-illegal-long-message','$prefix-schedule','$prefix-template','slot-illegal-long-message',1700000000.25,'failed','$prefix-trace-illegal-long-message','schedule_configuration_invalid',printf('%01001d',0),1700000000.75);" \
        "$lane literal error message length CHECK"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO schedule_fire(id,scheduleId,templateId,slotKey,scheduledAt,state,traceId,errorCode,errorMessage,createdAt,redactedAt) VALUES('$prefix-illegal-redacted-message','$prefix-schedule','$prefix-template','slot-illegal-redacted-message',1700000000.25,'failed','$prefix-trace-illegal-redacted-message','schedule_configuration_invalid','must be absent',1700000000.75,1700000001.25);" \
        "$lane literal redacted error CHECK"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "UPDATE schedule_evaluation_cursor SET version=0 WHERE scheduleId='$prefix-cursor-only-schedule';" \
        "$lane literal cursor version CHECK"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO schedule_fire(id,scheduleId,templateId,slotKey,scheduledAt,state,traceId,errorCode,createdAt) VALUES('$prefix-illegal-duplicate-original','$prefix-schedule','$prefix-template','slot-started',1700000000.25,'failed','$prefix-trace-illegal-duplicate-original','schedule_configuration_invalid',1700000000.75);" \
        "$lane literal original slot uniqueness"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO schedule_fire(id,scheduleId,templateId,slotKey,scheduledAt,replayOfFireId,replayIdempotencyKey,replayPayloadHash,state,traceId,errorCode,createdAt) VALUES('$prefix-illegal-duplicate-replay','$prefix-schedule','$prefix-template','slot-illegal-duplicate-replay',1700000000.25,'$prefix-failed','$prefix-replay-key','bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','failed','$prefix-trace-illegal-duplicate-replay','schedule_configuration_invalid',1700000000.75);" \
        "$lane literal replay key uniqueness"

    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "PRAGMA foreign_keys=ON; DELETE FROM mission WHERE id='$prefix-mission';" \
        "$lane literal mission delete RESTRICT"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "PRAGMA foreign_keys=ON; DELETE FROM schedule WHERE id='$prefix-schedule';" \
        "$lane literal schedule delete RESTRICT"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "PRAGMA foreign_keys=ON; DELETE FROM mission_template WHERE id='$prefix-template';" \
        "$lane literal template delete RESTRICT"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM schedule_fire WHERE id IN ('$prefix-started','$prefix-failed','$prefix-replay','$prefix-redacted');" \
        "4" "$lane literal RESTRICT rollback retention"
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" \
        "PRAGMA foreign_keys=ON; DELETE FROM schedule WHERE id='$prefix-cursor-only-schedule';"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM schedule_evaluation_cursor WHERE scheduleId='$prefix-cursor-only-schedule';" \
        "0" "$lane literal cursor CASCADE"

    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "UPDATE durable_work_attempt_event SET workerId='other' WHERE id='$prefix-event';" \
        "$lane literal ordinary event UPDATE"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "UPDATE durable_work_attempt_event SET workerId=workerId WHERE id='$prefix-event';" \
        "$lane literal no-op event UPDATE"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "DELETE FROM durable_work_attempt_event WHERE id='$prefix-event';" \
        "$lane literal event DELETE"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "UPDATE durable_work SET outputJson='{}' WHERE id='$prefix-work';" \
        "$lane literal output CHECK"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "UPDATE durable_work_attempt SET errorCode='illegal' WHERE workId='$prefix-work' AND attempt=1;" \
        "$lane literal attempt CHECK"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO durable_work_attempt_event(id,workId,attempt,sequence,eventKind,workerId,workVersion,resultingWorkState,errorCode,errorMessage,occurredAt) VALUES('$prefix-invalid','$prefix-work',1,1,'claimed','worker',3,'running',NULL,NULL,1000001);" \
        "$lane literal sequence CHECK"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM durable_work_attempt_event WHERE id='$prefix-event' AND workerId='worker';" \
        "1" "$lane literal event retained"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM schedule_evaluation_cursor WHERE scheduleId='$prefix-schedule';" \
        "1" "$lane literal restricted cursor retained"
    assert_query "$sqlite_cli" "$success_database" \
        "PRAGMA foreign_key_check;" "" "$lane literal final foreign keys"
    assert_query "$sqlite_cli" "$success_database" \
        "PRAGMA integrity_check;" "ok" "$lane literal final integrity"

    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$rollback_database" ".dump" > "$before_dump"
    before_hash="$(shasum -a 256 "$before_dump" | awk '{print $1}')"
    {
        printf 'PRAGMA foreign_keys = ON;\n'
        printf 'BEGIN IMMEDIATE;\n'
        awk '{ print }' "$literal_schedule_sql"
        printf 'SELECT * FROM __agentloop_forced_missing_table__;\n'
        printf 'COMMIT;\n'
    } > "$rollback_input"
    if "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$rollback_database" < "$rollback_input"
    then
        fail "$lane literal forced rollback unexpectedly succeeded"
    fi
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$rollback_database" ".dump" > "$after_dump"
    after_hash="$(shasum -a 256 "$after_dump" | awk '{print $1}')"
    test "$after_hash" = "$before_hash" \
        || fail "$lane literal rollback dump changed"
    assert_query "$sqlite_cli" "$rollback_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE name IN ('schedule_fire','schedule_evaluation_cursor','schedule_fire_original_slot','schedule_fire_replay_key','schedule_fire_schedule_time');" \
        "0" "$lane literal rollback schedule objects"
    assert_query "$sqlite_cli" "$rollback_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE name IN ('durable_work','durable_work_attempt','durable_work_attempt_event','durable_work_attempt_event_reject_update','durable_work_attempt_event_reject_delete');" \
        "5" "$lane literal rollback durable objects"
    assert_query "$sqlite_cli" "$rollback_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name IN ('durable_work_one_active_aggregate','durable_work_claimable','durable_work_aggregate_history','durable_work_attempt_one_terminal','durable_work_attempt_event_work');" \
        "5" "$lane literal rollback durable indexes"
    assert_query "$sqlite_cli" "$rollback_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" \
        "27" "$lane literal rollback table checkpoint"
    assert_query "$sqlite_cli" "$rollback_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='index';" \
        "55" "$lane literal rollback index checkpoint"
    assert_query "$sqlite_cli" "$rollback_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='trigger';" \
        "4" "$lane literal rollback trigger checkpoint"
    assert_query "$sqlite_cli" "$rollback_database" \
        "PRAGMA foreign_key_check;" "" "$lane rollback foreign keys"
    assert_query "$sqlite_cli" "$rollback_database" \
        "PRAGMA integrity_check;" "ok" "$lane rollback integrity"
    printf 'literal.%s=pass\n' "$lane"
}

verify_literal_observability_lane() {
    local lane="$1"
    local sqlite_cli="$2"
    local lane_root="$3"
    local baseline="$lane_root/literal-v11-cli-kinds.sqlite"
    local success_database="$lane_root/literal-v13-success.sqlite"
    local rollback_database="$lane_root/literal-v13-rollback.sqlite"
    local through_v12_input="$lane_root/literal-through-v12.sql"
    local success_input="$lane_root/literal-v13-success.sql"
    local rollback_input="$lane_root/literal-v13-rollback.sql"
    local before_dump="$lane_root/literal-v13-before.dump"
    local after_dump="$lane_root/literal-v13-after.dump"
    local replay_before="$lane_root/literal-v13-replay-before.dump"
    local replay_after="$lane_root/literal-v13-replay-after.dump"
    local before_hash
    local after_hash
    local replay_before_hash
    local replay_after_hash
    local prefix="literal_v13_${lane//./_}"

    require_file "$baseline"
    cp "$baseline" "$success_database"
    cp "$baseline" "$rollback_database"

    {
        printf 'PRAGMA foreign_keys = ON;\n'
        printf 'BEGIN IMMEDIATE;\n'
        awk '{ print }' "$literal_durable_sql"
        awk '{ print }' "$literal_schedule_sql"
        printf 'COMMIT;\n'
    } > "$through_v12_input"
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" < "$through_v12_input"
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$rollback_database" < "$through_v12_input"

    assert_query "$sqlite_cli" "$rollback_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" \
        "29" "$lane literal v12 predecessor tables"
    assert_query "$sqlite_cli" "$rollback_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='index';" \
        "60" "$lane literal v12 predecessor indexes"
    assert_query "$sqlite_cli" "$rollback_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='trigger';" \
        "4" "$lane literal v12 predecessor triggers"

    {
        printf 'PRAGMA foreign_keys = ON;\n'
        printf 'BEGIN IMMEDIATE;\n'
        awk '{ print }' "$literal_observability_sql"
        printf 'COMMIT;\n'
    } > "$success_input"
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" < "$success_input"

    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" \
        "31" "$lane literal v13 table checkpoint"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='index';" \
        "65" "$lane literal v13 index checkpoint"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='trigger';" \
        "4" "$lane literal v13 trigger checkpoint"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT group_concat(name,',') FROM (SELECT name FROM pragma_table_info('failure_record') ORDER BY cid);" \
        "id,operation,scopeKind,campId,scopeType,scopeId,severity,errorCode,userMessage,diagnosticJson,state,firstSeenAt,lastSeenAt,occurrenceCount,resolvedAt,redactedAt" \
        "$lane literal failure_record columns"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT group_concat(name,',') FROM (SELECT name FROM pragma_table_info('context_degradation') ORDER BY cid);" \
        "id,missionId,cardId,dependencyType,dependencyId,policy,traceId,detail,createdAt,redactedAt" \
        "$lane literal context_degradation columns"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT group_concat(name,',') FROM (SELECT name FROM sqlite_master WHERE type='index' AND tbl_name IN ('failure_record','context_degradation') ORDER BY name);" \
        "context_degradation_card,context_degradation_mission,failure_record_open_scope,sqlite_autoindex_context_degradation_1,sqlite_autoindex_failure_record_1" \
        "$lane literal exact observability indexes"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT group_concat(name,',') FROM (SELECT name FROM pragma_index_info('failure_record_open_scope') ORDER BY seqno);" \
        "scopeKind,campId,state,scopeType,scopeId,lastSeenAt" \
        "$lane literal failure_record index columns"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT group_concat(name,',') FROM (SELECT name FROM pragma_index_info('context_degradation_mission') ORDER BY seqno);" \
        "missionId,createdAt" "$lane literal mission index columns"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT group_concat(name,',') FROM (SELECT name FROM pragma_index_info('context_degradation_card') ORDER BY seqno);" \
        "cardId,createdAt" "$lane literal card index columns"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT group_concat(shape,',') FROM (SELECT \"from\"||'|'||\"table\"||'|'||\"to\"||'|'||on_delete AS shape FROM pragma_foreign_key_list('failure_record') ORDER BY \"from\");" \
        "campId|camp|id|RESTRICT" "$lane literal failure foreign key"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT group_concat(shape,',') FROM (SELECT \"from\"||'|'||\"table\"||'|'||\"to\"||'|'||on_delete AS shape FROM pragma_foreign_key_list('context_degradation') ORDER BY \"from\");" \
        "cardId|card|id|RESTRICT,missionId|mission|id|RESTRICT" \
        "$lane literal degradation foreign keys"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM failure_record;" "0" \
        "$lane literal failure_record initially empty"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM context_degradation;" "0" \
        "$lane literal context_degradation initially empty"

    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" "
        PRAGMA foreign_keys=ON;
        INSERT INTO camp(id,name,archived,createdAt)
          VALUES('$prefix-camp','P1-B',0,1700000000.25);
        INSERT INTO squad(id,campId,name,memberIdsJson,workspacePath,
          workspaceBookmark,createdAt)
          VALUES('$prefix-squad','$prefix-camp','Squad','[]',NULL,NULL,
          1700000000.25);
        INSERT INTO mission(id,squadId,goalRaw,goalRefined,status,budgetTokens,
          spentTokens,revision,autonomy,createdAt)
          VALUES('$prefix-mission','$prefix-squad','Goal','Goal','planning',
          1000,0,1,'standard',1700000000.25);
        INSERT INTO card(id,missionId,idemKey,title,descriptionText,
          expectedOutput,assigneeId,status,blockedReasonJson,dependsOnJson,
          handoffJson,stage,reviewFlag,maxTurns,tokenBudget,createdAt)
          VALUES('$prefix-card','$prefix-mission','$prefix-idem','Card',
          'Description','Output',NULL,'pending',NULL,'[]',NULL,1,NULL,10,1000,
          1700000000.25);
        INSERT INTO failure_record(id,operation,scopeKind,campId,scopeType,
          scopeId,severity,errorCode,userMessage,diagnosticJson,state,
          firstSeenAt,lastSeenAt,occurrenceCount,resolvedAt,redactedAt)
          VALUES('$prefix-failure','matrix','camp','$prefix-camp','scope','id',
          'error','matrix_error',printf('%01000d',0),'{}','open',
          1700000000.25,1700000000.5,1,NULL,NULL);
        INSERT INTO context_degradation(id,missionId,cardId,dependencyType,
          dependencyId,policy,traceId,detail,createdAt,redactedAt)
          VALUES('$prefix-degradation','$prefix-mission','$prefix-card',
          'knowledge','dependency','optionalApproved','$prefix-trace',
          printf('%01000d',0),1700000000.25,NULL);
        "
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT length(userMessage) FROM failure_record WHERE id='$prefix-failure';" \
        "1000" "$lane literal failure message boundary"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT length(detail) FROM context_degradation WHERE id='$prefix-degradation';" \
        "1000" "$lane literal degradation detail boundary"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO failure_record(id,operation,scopeKind,campId,scopeType,scopeId,severity,errorCode,userMessage,diagnosticJson,state,firstSeenAt,lastSeenAt) VALUES('$prefix-invalid-scope','matrix','owner',NULL,'scope','id','error','code','bad','{}','open',1,1);" \
        "$lane literal invalid failure scope"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO failure_record(id,operation,scopeKind,campId,scopeType,scopeId,severity,errorCode,userMessage,diagnosticJson,state,firstSeenAt,lastSeenAt,redactedAt) VALUES('$prefix-global-redacted','matrix','global',NULL,'scope','id','error','code','[deleted]','{}','open',1,1,2);" \
        "$lane literal global redaction"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO failure_record(id,operation,scopeKind,campId,scopeType,scopeId,severity,errorCode,userMessage,diagnosticJson,state,firstSeenAt,lastSeenAt) VALUES('$prefix-long-failure','matrix','camp','$prefix-camp','scope','id','error','code',printf('%01001d',0),'{}','open',1,1);" \
        "$lane literal failure 1001 boundary"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO context_degradation(id,missionId,cardId,dependencyType,dependencyId,policy,traceId,detail,createdAt) VALUES('$prefix-no-owner',NULL,NULL,'knowledge','dependency','required','trace','bad',1);" \
        "$lane literal degradation owner constraint"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO context_degradation(id,missionId,cardId,dependencyType,dependencyId,policy,traceId,detail,createdAt) VALUES('$prefix-invalid-policy','$prefix-mission',NULL,'knowledge','dependency','optional','trace','bad',1);" \
        "$lane literal degradation policy constraint"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO context_degradation(id,missionId,cardId,dependencyType,dependencyId,policy,traceId,detail,createdAt) VALUES('$prefix-long-degradation','$prefix-mission',NULL,'knowledge','dependency','required','trace',printf('%01001d',0),1);" \
        "$lane literal degradation 1001 boundary"
    assert_query "$sqlite_cli" "$success_database" \
        "PRAGMA foreign_key_check;" "" "$lane literal v13 foreign keys"
    assert_query "$sqlite_cli" "$success_database" \
        "PRAGMA integrity_check;" "ok" "$lane literal v13 integrity"

    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" ".dump" > "$replay_before"
    replay_before_hash="$(shasum -a 256 "$replay_before" | awk '{print $1}')"
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" "PRAGMA foreign_key_check; PRAGMA integrity_check;" \
        >/dev/null
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" ".dump" > "$replay_after"
    replay_after_hash="$(shasum -a 256 "$replay_after" | awk '{print $1}')"
    test "$replay_after_hash" = "$replay_before_hash" \
        || fail "$lane literal v13 reopen changed logical snapshot"

    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$rollback_database" ".dump" > "$before_dump"
    before_hash="$(shasum -a 256 "$before_dump" | awk '{print $1}')"
    {
        printf 'PRAGMA foreign_keys = ON;\n'
        printf 'BEGIN IMMEDIATE;\n'
        awk '{ print }' "$literal_observability_sql"
        printf 'SELECT * FROM __agentloop_forced_missing_table__;\n'
        printf 'COMMIT;\n'
    } > "$rollback_input"
    if "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$rollback_database" < "$rollback_input"
    then
        fail "$lane literal v13 forced rollback unexpectedly succeeded"
    fi
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$rollback_database" ".dump" > "$after_dump"
    after_hash="$(shasum -a 256 "$after_dump" | awk '{print $1}')"
    test "$after_hash" = "$before_hash" \
        || fail "$lane literal v13 rollback dump changed"
    assert_query "$sqlite_cli" "$rollback_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE name IN ('failure_record','failure_record_open_scope','context_degradation','context_degradation_mission','context_degradation_card');" \
        "0" "$lane literal v13 rollback objects"
    assert_query "$sqlite_cli" "$rollback_database" \
        "PRAGMA foreign_key_check;" "" "$lane literal v13 rollback FKs"
    assert_query "$sqlite_cli" "$rollback_database" \
        "PRAGMA integrity_check;" "ok" "$lane literal v13 rollback integrity"

    printf 'literal.v13.observability.rollback=pass\n'
    printf 'literal.v13.observability.replay=pass\n'
    printf 'literal.v13.observability.final_checkpoint=31/65/4\n'
}

verify_literal_control_lane() {
    local lane="$1"
    local sqlite_cli="$2"
    local lane_root="$3"
    local baseline="$lane_root/literal-v11-cli-kinds.sqlite"
    local success_database="$lane_root/literal-v14-success.sqlite"
    local rollback_database="$lane_root/literal-v14-rollback.sqlite"
    local predecessor_input="$lane_root/literal-through-v13.sql"
    local success_input="$lane_root/literal-v14-success.sql"
    local rollback_input="$lane_root/literal-v14-rollback.sql"
    local before_dump="$lane_root/literal-v14-before.dump"
    local after_dump="$lane_root/literal-v14-after.dump"
    local replay_before="$lane_root/literal-v14-replay-before.dump"
    local replay_after="$lane_root/literal-v14-replay-after.dump"
    local before_hash
    local after_hash
    local replay_before_hash
    local replay_after_hash
    local prefix="literal_v14_${lane//./_}"

    require_file "$baseline"
    cp "$baseline" "$success_database"
    cp "$baseline" "$rollback_database"
    {
        printf 'PRAGMA foreign_keys = ON;\n'
        printf 'BEGIN IMMEDIATE;\n'
        awk '{ print }' "$literal_durable_sql"
        awk '{ print }' "$literal_schedule_sql"
        awk '{ print }' "$literal_observability_sql"
        printf 'COMMIT;\n'
    } > "$predecessor_input"
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" < "$predecessor_input"
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$rollback_database" < "$predecessor_input"

    assert_query "$sqlite_cli" "$rollback_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" \
        "31" "$lane literal v14 predecessor tables"
    assert_query "$sqlite_cli" "$rollback_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='index';" \
        "65" "$lane literal v14 predecessor indexes"
    assert_query "$sqlite_cli" "$rollback_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='trigger';" \
        "4" "$lane literal v14 predecessor triggers"

    {
        printf 'PRAGMA foreign_keys = ON;\n'
        printf 'BEGIN IMMEDIATE;\n'
        awk '{ print }' "$literal_control_sql"
        printf 'COMMIT;\n'
    } > "$success_input"
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" < "$success_input"

    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" \
        "41" "$lane literal v14 table checkpoint"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='index';" \
        "94" "$lane literal v14 index checkpoint"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='trigger';" \
        "8" "$lane literal v14 trigger checkpoint"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT group_concat(name,',') FROM (SELECT name FROM sqlite_master WHERE type='table' AND name IN ('domain_command_receipt','domain_event','event_outbox','inbox_message','input_envelope','goal_controller','goal_mission_link','coach_session','coach_question','understanding_card_version') ORDER BY name);" \
        "coach_question,coach_session,domain_command_receipt,domain_event,event_outbox,goal_controller,goal_mission_link,inbox_message,input_envelope,understanding_card_version" \
        "$lane literal exact v14 tables"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT group_concat(name,',') FROM (SELECT name FROM sqlite_master WHERE type='index' AND tbl_name IN ('domain_command_receipt','domain_event','event_outbox','inbox_message','input_envelope','goal_controller','goal_mission_link','coach_session','coach_question','understanding_card_version') ORDER BY name);" \
        "coach_question_decision,coach_question_one_open,coach_session_goal,domain_event_aggregate,domain_event_camp,domain_event_correlation,event_outbox_pending,goal_controller_camp_status,goal_mission_link_goal,inbox_message_camp_state,input_envelope_camp,input_envelope_status,sqlite_autoindex_coach_question_1,sqlite_autoindex_coach_session_1,sqlite_autoindex_domain_command_receipt_1,sqlite_autoindex_domain_event_1,sqlite_autoindex_domain_event_2,sqlite_autoindex_domain_event_3,sqlite_autoindex_domain_event_4,sqlite_autoindex_event_outbox_1,sqlite_autoindex_goal_controller_1,sqlite_autoindex_goal_mission_link_1,sqlite_autoindex_inbox_message_1,sqlite_autoindex_inbox_message_2,sqlite_autoindex_input_envelope_1,sqlite_autoindex_input_envelope_2,sqlite_autoindex_understanding_card_version_1,sqlite_autoindex_understanding_card_version_2,understanding_goal" \
        "$lane literal exact v14 indexes"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT group_concat(name,',') FROM (SELECT name FROM sqlite_master WHERE type='trigger' AND tbl_name IN ('domain_command_receipt','domain_event') ORDER BY name);" \
        "domain_command_receipt_reject_delete,domain_command_receipt_reject_update,domain_event_reject_delete,domain_event_reject_update" \
        "$lane literal exact v14 triggers"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT group_concat(name,',') FROM (SELECT name FROM pragma_table_info('input_envelope') ORDER BY cid);" \
        "id,schemaVersion,aggregateVersion,idempotencyKey,sourceType,sourceDeviceId,connectorId,authorId,capturedAt,inlineText,payloadRef,contentHash,candidateCampIdsJson,campId,explicitIntent,privacyLevel,status,errorCode,errorMessage,parentInputId,retentionState,createdAt,updatedAt,deletedAt" \
        "$lane literal exact input columns"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM pragma_table_info('input_envelope') WHERE name='parseAttempt';" \
        "0" "$lane literal input parseAttempt absence"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT (instr(sql,'WHERE state = ''open''')>0) FROM sqlite_master WHERE type='index' AND name='coach_question_one_open';" \
        "1" "$lane literal coach open partial index"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT (instr(sql,'RAISE(ABORT, ''domain_event is append-only'')')>0) FROM sqlite_master WHERE type='trigger' AND name='domain_event_reject_update';" \
        "1" "$lane literal event append-only trigger"

    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" "
        PRAGMA foreign_keys=ON;
        INSERT INTO camp(id,name,archived,createdAt)
          VALUES('$prefix-camp','P1-C',0,1700000000.25);
        INSERT INTO squad(id,campId,name,memberIdsJson,workspacePath,
          workspaceBookmark,createdAt)
          VALUES('$prefix-squad','$prefix-camp','Squad','[]',NULL,NULL,
          1700000000.25);
        INSERT INTO mission(id,squadId,goalRaw,goalRefined,status,budgetTokens,
          spentTokens,revision,autonomy,createdAt)
          VALUES('$prefix-mission','$prefix-squad','Goal','Goal','planning',
          1000,0,1,'standard',1700000000.25);
        INSERT INTO domain_command_receipt(idempotencyKey,commandType,
          commandPayloadHash,eventCount,resultJson,resultHash,createdAt)
          VALUES('$prefix-command','matrix.control',
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',1,
          '{}','bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',1);
        INSERT INTO domain_event(id,campId,aggregateType,aggregateId,
          aggregateVersion,eventType,payloadVersion,payloadJson,payloadHash,
          actorType,actorId,deviceId,causationId,correlationId,
          commandIdempotencyKey,eventOrdinal,eventIdempotencyKey,occurredAt,
          recordedAt)
          VALUES('$prefix-event','$prefix-camp','goal','$prefix-aggregate',1,
          'matrix.event',1,'{}',
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
          'system','system:matrix',NULL,NULL,'$prefix-correlation',
          '$prefix-command',0,'$prefix-event-key',1,1);
        INSERT INTO event_outbox(eventId,state,attempt,notBefore,leaseOwner,
          leaseExpiresAt,lastError,version,createdAt,updatedAt,sentAt)
          VALUES('$prefix-event','pending',0,NULL,NULL,NULL,NULL,1,1,1,NULL);
        INSERT INTO inbox_message(id,campId,sourceDeviceId,idempotencyKey,
          payloadJson,payloadHash,state,receivedAt,appliedAt,errorCode,version,
          redactedAt)
          VALUES('$prefix-inbox','$prefix-camp','device:matrix',
          '$prefix-inbox-key','{}',
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          'received',1,NULL,NULL,1,NULL);
        INSERT INTO input_envelope(id,schemaVersion,aggregateVersion,
          idempotencyKey,sourceType,sourceDeviceId,connectorId,authorId,
          capturedAt,inlineText,payloadRef,contentHash,candidateCampIdsJson,
          campId,explicitIntent,privacyLevel,status,errorCode,errorMessage,
          parentInputId,retentionState,createdAt,updatedAt,deletedAt)
          VALUES('$prefix-input',1,1,'$prefix-input-key','text',NULL,NULL,NULL,
          1,'visible',NULL,
          'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          '[]','$prefix-camp','unspecified','localOnly','captured',NULL,NULL,
          NULL,'active',1,1,NULL);
        INSERT INTO goal_controller(id,campId,sourceInputId,title,rawIntent,
          status,currentUnderstandingId,currentUnderstandingVersion,
          currentOutcomeContractId,currentOutcomeContractVersion,
          aggregateVersion,createdByActorId,createdAt,updatedAt)
          VALUES('$prefix-goal','$prefix-camp','$prefix-input','Goal','Intent',
          'clarifying',NULL,NULL,NULL,NULL,1,'user:matrix',1,1);
        INSERT INTO goal_mission_link(missionId,goalId,outcomeContractId,
          outcomeContractVersion,state,version,createdAt,updatedAt)
          VALUES('$prefix-mission','$prefix-goal',NULL,NULL,'active',1,1,1);
        INSERT INTO coach_session(id,goalId,inputId,actorId,status,
          currentUnderstandingVersion,pendingQuestionId,traceId,
          aggregateVersion,createdAt,updatedAt)
          VALUES('$prefix-session','$prefix-goal','$prefix-input',
          'system:coach:v1','interviewing',NULL,NULL,'$prefix-trace',1,1,1);
        INSERT INTO coach_question(id,sessionId,decisionKey,prompt,
          recommendation,reason,answerJson,state,createdAt,answeredAt)
          VALUES('$prefix-question','$prefix-session','decision','Prompt',
          'Recommendation','Reason',NULL,'open',1,NULL);
        INSERT INTO understanding_card_version(id,version,goalId,problem,
          scenario,targetAudience,goalsJson,nonGoalsJson,deliverablesJson,
          constraintsJson,acceptanceCriteriaJson,verificationPlanJson,
          resourceRefsJson,requiredCapabilitiesJson,budgetPolicyJson,
          assumptionsJson,acceptedRisksJson,status,contentHash,createdByActorId,
          confirmedByActorId,confirmedAt,createdAt)
          VALUES('$prefix-understanding',1,'$prefix-goal','Problem','Scenario',
          'Audience','[]','[]','[]','[]','[]','[]','[]','[]','{}','[]','[]',
          'draft','ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          'user:matrix',NULL,NULL,1);
        "

    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "UPDATE domain_command_receipt SET commandType=commandType WHERE idempotencyKey='$prefix-command';" \
        "$lane literal receipt no-op update"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "DELETE FROM domain_command_receipt WHERE idempotencyKey='$prefix-command';" \
        "$lane literal receipt delete"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "UPDATE domain_event SET eventType=eventType WHERE id='$prefix-event';" \
        "$lane literal event no-op update"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "DELETE FROM domain_event WHERE id='$prefix-event';" \
        "$lane literal event delete"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO domain_event(id,campId,aggregateType,aggregateId,aggregateVersion,eventType,payloadVersion,payloadJson,payloadHash,actorType,actorId,correlationId,commandIdempotencyKey,eventOrdinal,eventIdempotencyKey,occurredAt,recordedAt) VALUES('$prefix-duplicate-aggregate','$prefix-camp','goal','$prefix-aggregate',1,'matrix.event',1,'{}','cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc','system','system:matrix','$prefix-correlation','$prefix-command',1,'$prefix-duplicate-aggregate-key',1,1);" \
        "$lane literal duplicate aggregate version"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO domain_event(id,campId,aggregateType,aggregateId,aggregateVersion,eventType,payloadVersion,payloadJson,payloadHash,actorType,actorId,correlationId,commandIdempotencyKey,eventOrdinal,eventIdempotencyKey,occurredAt,recordedAt) VALUES('$prefix-duplicate-ordinal','$prefix-camp','goal','$prefix-other-aggregate',1,'matrix.event',1,'{}','cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc','system','system:matrix','$prefix-correlation','$prefix-command',0,'$prefix-duplicate-ordinal-key',1,1);" \
        "$lane literal duplicate command ordinal"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO inbox_message(id,campId,sourceDeviceId,idempotencyKey,payloadJson,payloadHash,state,receivedAt,errorCode,version,redactedAt) VALUES('$prefix-bad-inbox','$prefix-camp','visible-device','$prefix-bad-inbox-key','{}','dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd','rejected',1,'camp_deleted',1,2);" \
        "$lane literal malformed inbox redaction"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO input_envelope(id,schemaVersion,aggregateVersion,idempotencyKey,sourceType,capturedAt,inlineText,payloadRef,contentHash,candidateCampIdsJson,campId,explicitIntent,privacyLevel,status,retentionState,createdAt,updatedAt,deletedAt) VALUES('$prefix-bad-two-bodies',1,1,'$prefix-bad-two-key','text',1,'visible','payload://visible','eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee','[]','$prefix-camp','unspecified','localOnly','captured','active',1,1,NULL);" \
        "$lane literal input exactly-one body"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO input_envelope(id,schemaVersion,aggregateVersion,idempotencyKey,sourceType,capturedAt,inlineText,payloadRef,contentHash,candidateCampIdsJson,campId,explicitIntent,privacyLevel,status,retentionState,createdAt,updatedAt,deletedAt) VALUES('$prefix-bad-status',1,1,'$prefix-bad-status-key','text',1,'visible',NULL,'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee','[]','$prefix-camp','unspecified','localOnly','deletedTombstone','active',1,1,NULL);" \
        "$lane literal input status retention pair"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO goal_controller(id,campId,title,rawIntent,status,currentUnderstandingId,currentUnderstandingVersion,aggregateVersion,createdByActorId,createdAt,updatedAt) VALUES('$prefix-bad-goal','$prefix-camp','Bad','Bad','clarifying','understanding',0,1,'user:matrix',1,1);" \
        "$lane literal goal understanding pair"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO coach_session(id,goalId,actorId,status,traceId,aggregateVersion,createdAt,updatedAt) VALUES('$prefix-bad-session','$prefix-goal','system:coach:v2','interviewing','$prefix-bad-trace',1,1,1);" \
        "$lane literal coach actor"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO coach_question(id,sessionId,decisionKey,prompt,recommendation,reason,state,createdAt) VALUES('$prefix-second-question','$prefix-session','second','Prompt','Recommendation','Reason','open',1);" \
        "$lane literal one open coach question"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "INSERT INTO understanding_card_version(id,version,goalId,problem,scenario,targetAudience,goalsJson,nonGoalsJson,deliverablesJson,constraintsJson,acceptanceCriteriaJson,verificationPlanJson,resourceRefsJson,requiredCapabilitiesJson,budgetPolicyJson,assumptionsJson,acceptedRisksJson,status,contentHash,createdByActorId,confirmedByActorId,confirmedAt,createdAt) VALUES('$prefix-bad-understanding',1,'$prefix-goal','Problem','Scenario','Audience','[]','[]','[]','[]','[]','[]','[]','[]','{}','[]','[]','confirmed','ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff','user:matrix',NULL,NULL,1);" \
        "$lane literal understanding confirmation pair"

    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM domain_command_receipt WHERE idempotencyKey='$prefix-command';" \
        "1" "$lane literal retained receipt"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM domain_event WHERE id='$prefix-event';" \
        "1" "$lane literal retained event"
    assert_query "$sqlite_cli" "$success_database" \
        "PRAGMA foreign_key_check;" "" "$lane literal v14 foreign keys"
    assert_query "$sqlite_cli" "$success_database" \
        "PRAGMA integrity_check;" "ok" "$lane literal v14 integrity"

    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" ".dump" > "$replay_before"
    replay_before_hash="$(shasum -a 256 "$replay_before" | awk '{print $1}')"
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" "PRAGMA foreign_key_check; PRAGMA integrity_check;" \
        >/dev/null
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" ".dump" > "$replay_after"
    replay_after_hash="$(shasum -a 256 "$replay_after" | awk '{print $1}')"
    test "$replay_after_hash" = "$replay_before_hash" \
        || fail "$lane literal v14 reopen changed logical snapshot"

    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$rollback_database" \
        "CREATE INDEX domain_event_correlation ON camp(id);"
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$rollback_database" ".dump" > "$before_dump"
    before_hash="$(shasum -a 256 "$before_dump" | awk '{print $1}')"
    {
        printf 'PRAGMA foreign_keys = ON;\n'
        printf 'BEGIN IMMEDIATE;\n'
        awk '{ print }' "$literal_control_sql"
        printf 'COMMIT;\n'
    } > "$rollback_input"
    if "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$rollback_database" < "$rollback_input"
    then
        fail "$lane literal v14 conflicting-index rollback unexpectedly succeeded"
    fi
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$rollback_database" ".dump" > "$after_dump"
    after_hash="$(shasum -a 256 "$after_dump" | awk '{print $1}')"
    test "$after_hash" = "$before_hash" \
        || fail "$lane literal v14 rollback dump changed"
    assert_query "$sqlite_cli" "$rollback_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN ('domain_command_receipt','domain_event','event_outbox','inbox_message','input_envelope','goal_controller','goal_mission_link','coach_session','coach_question','understanding_card_version');" \
        "0" "$lane literal v14 rollback tables"
    assert_query "$sqlite_cli" "$rollback_database" \
        "SELECT group_concat(name,',') FROM (SELECT name FROM pragma_index_info('domain_event_correlation') ORDER BY seqno);" \
        "id" "$lane literal v14 rollback sentinel"
    assert_query "$sqlite_cli" "$rollback_database" \
        "PRAGMA foreign_key_check;" "" "$lane literal v14 rollback FKs"
    assert_query "$sqlite_cli" "$rollback_database" \
        "PRAGMA integrity_check;" "ok" "$lane literal v14 rollback integrity"

    printf 'literal.v14.control.rollback=pass\n'
    printf 'literal.v14.control.replay=pass\n'
    printf 'literal.v14.control.fk=pass\n'
    printf 'literal.v14.control.integrity=pass\n'
    printf 'literal.v14.control.ddl=pass\n'
    printf 'literal.v14.control.append_only=pass\n'
    printf 'literal.v14.control.final_checkpoint=41/94/8\n'
}

verify_literal_identity_memory_lane() {
    local lane="$1"
    local sqlite_cli="$2"
    local lane_root="$3"
    local baseline="$lane_root/literal-v15-outcome.sqlite"
    local success_database="$lane_root/literal-v16-success.sqlite"
    local rollback_database="$lane_root/literal-v16-rollback.sqlite"
    local success_input="$lane_root/literal-v16-success.sql"
    local rollback_input="$lane_root/literal-v16-rollback.sql"
    local before_dump="$lane_root/literal-v16-before.dump"
    local after_dump="$lane_root/literal-v16-after.dump"
    local replay_before="$lane_root/literal-v16-replay-before.dump"
    local replay_after="$lane_root/literal-v16-replay-after.dump"
    local before_hash
    local after_hash
    local replay_before_hash
    local replay_after_hash
    local prefix="literal_v16_${lane//./_}"
    local camp_id="$prefix-camp"
    local ingestion_id="$prefix-ingestion"
    local command_id="$prefix-command"
    local event_id="$prefix-event"
    local command_hash="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    local result_hash="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    local payload_hash="cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
    local content_hash="dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
    local snapshot_hash="eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"

    require_file "$baseline"
    cp "$baseline" "$success_database"
    cp "$baseline" "$rollback_database"

    {
        printf 'PRAGMA foreign_keys = ON;\n'
        printf 'BEGIN IMMEDIATE;\n'
        awk '{ print }' "$literal_identity_memory_sql"
        printf 'COMMIT;\n'
    } > "$success_input"
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" < "$success_input"

    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';" \
        "67" "$lane literal v16 table checkpoint"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='index';" \
        "171" "$lane literal v16 index checkpoint"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='trigger';" \
        "67" "$lane literal v16 trigger checkpoint"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN ('camp_lifecycle','camp_provider_dispatch','camp_deletion_job','camp_deletion_artifact','legacy_chat_scope','legacy_companion_note_scope','camp_event_scope','cow_identity','camp_residency','camp_bridge','memory_record_version','memory_dependency');" \
        "12" "$lane literal v16 required tables"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM grdb_migrations WHERE identifier='v15-p1-outcome-contracts';" \
        "1" "$lane literal v16 predecessor migration"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM grdb_migrations WHERE identifier='v16-p1-identity-memory';" \
        "0" "$lane literal v16 remains SQL-only"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='trigger' AND name IN ('ingestion_item_reject_delete','rumination_result_reject_delete') AND instr(sql,'agentloop_active_ingestion_deletion_permit_v1')>0;" \
        "2" "$lane literal v16 raw permit guards"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT group_concat(name,',') FROM (SELECT DISTINCT \"table\" AS name FROM pragma_foreign_key_list('durable_work_attempt') ORDER BY name);" \
        "durable_work" "$lane literal v16 attempt final foreign key"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT group_concat(name,',') FROM (SELECT DISTINCT \"table\" AS name FROM pragma_foreign_key_list('durable_work_attempt_event') ORDER BY name);" \
        "camp_provider_dispatch,durable_work_attempt" \
        "$lane literal v16 event final foreign keys"
    assert_query "$sqlite_cli" "$success_database" \
        "PRAGMA foreign_key_check;" "" "$lane literal v16 foreign keys"
    assert_query "$sqlite_cli" "$success_database" \
        "PRAGMA integrity_check;" "ok" "$lane literal v16 integrity"

    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" "
        PRAGMA foreign_keys=ON;
        BEGIN IMMEDIATE;
        INSERT INTO camp(id,name,archived,createdAt)
          VALUES('$camp_id','Literal v16 $lane',0,1);
        INSERT INTO camp_lifecycle(
          campId,state,version,createdAt,updatedAt,deletionRequestedAt,deletedAt
        ) VALUES('$camp_id','active',1,1,1,NULL,NULL);
        INSERT INTO ingestion_item(
          id,campId,sourceType,title,rawText,sourceURL,author,userIntent,
          contentHash,status,attempt,errorText,createdAt,updatedAt,version,
          terminalReason,redactedAt
        ) VALUES(
          '$ingestion_id','$camp_id','text','Title','raw',NULL,NULL,NULL,
          '$content_hash','queued',0,NULL,1,1,1,NULL,NULL
        );
        INSERT INTO domain_command_receipt(
          idempotencyKey,commandType,commandPayloadHash,eventCount,resultJson,
          resultHash,createdAt
        ) VALUES(
          '$command_id','activeIngestionDeletion.v1','$command_hash',1,
          json_object(
            'commandIdempotencyKey','$command_id',
            'eventId','$event_id','eventPayloadHash','$payload_hash',
            'campId','$camp_id','expectedLifecycleVersion',1,
            'ingestionId','$ingestion_id','oldIngestionVersion',1,
            'oldIngestionStatus','queued',
            'ingestionContentHash','$content_hash',
            'ingestionSnapshotHash','$snapshot_hash',
            'scope','sourceAndResult','deletedIngestionCount',1,
            'updatedIngestionCount',0,'deletedResultCount',0,
            'knowledgeSourceLinkCount',0,'actionCandidateCount',0,
            'nonterminalRuminationWorkCount',0,'openRuminationAttemptCount',0,
            'nonterminalProviderDispatchCount',0,
            'commandPayloadHash','$command_hash',
            'resultId',NULL,'resultVersion',NULL,'resultHash',NULL
          ),'$result_hash',1
        );
        INSERT INTO camp_event_scope(
          sourceTable,eventId,scopeKind,campId,payloadRedactedAt
        ) VALUES('domain_event','$event_id','camp','$camp_id',NULL);
        INSERT INTO domain_event(
          id,campId,aggregateType,aggregateId,aggregateVersion,eventType,
          payloadVersion,payloadJson,payloadHash,actorType,actorId,deviceId,
          causationId,correlationId,commandIdempotencyKey,eventOrdinal,
          eventIdempotencyKey,occurredAt,recordedAt
        ) VALUES(
          '$event_id','$camp_id','ingestion','$ingestion_id',2,
          'active_ingestion_deleted_v1',1,
          json_object(
            'campId','$camp_id','commandIdempotencyKey','$command_id',
            'expectedLifecycleVersion',1,'commandPayloadHash','$command_hash',
            'ingestionId','$ingestion_id','oldIngestionVersion',1,
            'oldIngestionStatus','queued',
            'ingestionContentHash','$content_hash',
            'ingestionSnapshotHash','$snapshot_hash',
            'scope','sourceAndResult','deletedIngestionCount',1,
            'updatedIngestionCount',0,'deletedResultCount',0,
            'knowledgeSourceLinkCount',0,'actionCandidateCount',0,
            'nonterminalRuminationWorkCount',0,'openRuminationAttemptCount',0,
            'nonterminalProviderDispatchCount',0,
            'resultId',NULL,'resultVersion',NULL,'resultHash',NULL
          ),'$payload_hash','user','user:matrix','device:matrix',NULL,
          '$prefix-correlation','$command_id',0,
          '$command_id#0000:ingestion:$ingestion_id',1,1
        );
        INSERT INTO event_outbox(
          eventId,state,attempt,notBefore,leaseOwner,leaseExpiresAt,lastError,
          version,createdAt,updatedAt,sentAt
        ) VALUES('$event_id','pending',0,NULL,NULL,NULL,NULL,1,1,1,NULL);
        COMMIT;
        "
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT (SELECT COUNT(*) FROM json_each(resultJson)) || '/' || (SELECT COUNT(*) FROM json_each(payloadJson)) FROM domain_command_receipt JOIN domain_event ON commandIdempotencyKey=idempotencyKey WHERE domain_event.id='$event_id';" \
        "23/21" "$lane literal v16 matching evidence shape"
    expect_sqlite_failure_containing "$sqlite_cli" "$success_database" \
        "PRAGMA foreign_keys=ON; DELETE FROM ingestion_item WHERE id='$ingestion_id';" \
        "no such function: agentloop_active_ingestion_deletion_permit_v1" \
        "$lane literal v16 matching-evidence delete without UDF"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM ingestion_item WHERE id='$ingestion_id';" \
        "1" "$lane literal v16 failed delete retained ingestion"
    assert_query "$sqlite_cli" "$success_database" \
        "PRAGMA foreign_key_check;" "" \
        "$lane literal v16 post-delete foreign keys"
    assert_query "$sqlite_cli" "$success_database" \
        "PRAGMA integrity_check;" "ok" \
        "$lane literal v16 post-delete integrity"

    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" ".dump" > "$replay_before"
    replay_before_hash="$(shasum -a 256 "$replay_before" | awk '{print $1}')"
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" "PRAGMA foreign_key_check; PRAGMA integrity_check;" \
        >/dev/null
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" ".dump" > "$replay_after"
    replay_after_hash="$(shasum -a 256 "$replay_after" | awk '{print $1}')"
    test "$replay_after_hash" = "$replay_before_hash" \
        || fail "$lane literal v16 reopen changed logical snapshot"

    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$rollback_database" \
        "CREATE TABLE memory_dependency(id TEXT PRIMARY KEY NOT NULL); INSERT INTO memory_dependency(id) VALUES('sentinel');"
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$rollback_database" ".dump" > "$before_dump"
    before_hash="$(shasum -a 256 "$before_dump" | awk '{print $1}')"
    {
        printf 'PRAGMA foreign_keys = ON;\n'
        printf 'BEGIN IMMEDIATE;\n'
        awk '{ print }' "$literal_identity_memory_sql"
        printf 'COMMIT;\n'
    } > "$rollback_input"
    if "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$rollback_database" < "$rollback_input"
    then
        fail "$lane literal v16 conflicting-table rollback unexpectedly succeeded"
    fi
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$rollback_database" ".dump" > "$after_dump"
    after_hash="$(shasum -a 256 "$after_dump" | awk '{print $1}')"
    test "$after_hash" = "$before_hash" \
        || fail "$lane literal v16 rollback dump changed"
    assert_query "$sqlite_cli" "$rollback_database" \
        "SELECT group_concat(id,',') FROM memory_dependency ORDER BY id;" \
        "sentinel" "$lane literal v16 rollback sentinel"
    assert_query "$sqlite_cli" "$rollback_database" \
        "SELECT COUNT(*) FROM grdb_migrations WHERE identifier='v16-p1-identity-memory';" \
        "0" "$lane literal v16 rollback migration record"
    assert_query "$sqlite_cli" "$rollback_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN ('camp_lifecycle','camp_provider_dispatch','camp_deletion_job','camp_deletion_artifact','legacy_chat_scope','legacy_companion_note_scope','camp_event_scope','cow_identity','camp_residency','camp_bridge','memory_record_version');" \
        "0" "$lane literal v16 rollback introduced tables"
    assert_query "$sqlite_cli" "$rollback_database" \
        "PRAGMA foreign_key_check;" "" "$lane literal v16 rollback FKs"
    assert_query "$sqlite_cli" "$rollback_database" \
        "PRAGMA integrity_check;" "ok" "$lane literal v16 rollback integrity"

    printf 'literal.v16.identity_memory.checkpoint=67/171/67\n'
    printf 'literal.v16.identity_memory.udf_absent_matching_evidence=pass\n'
    printf 'literal.v16.identity_memory.replay=pass\n'
    printf 'literal.v16.identity_memory.rollback=pass\n'
    printf 'literal.v16.identity_memory.fk=pass\n'
    printf 'literal.v16.identity_memory.integrity=pass\n'
}

verify_literal_engine_coordination_lane() {
    local lane="$1"
    local sqlite_cli="$2"
    local lane_root="$3"
    local baseline="$lane_root/literal-v16-identity-memory.sqlite"
    local success_database="$lane_root/literal-v17-success.sqlite"
    local rollback_database="$lane_root/literal-v17-rollback.sqlite"
    local success_input="$lane_root/literal-v17-success.sql"
    local rollback_input="$lane_root/literal-v17-rollback.sql"
    local replay_before="$lane_root/literal-v17-replay-before.dump"
    local replay_after="$lane_root/literal-v17-replay-after.dump"
    local rollback_before="$lane_root/literal-v17-rollback-before.dump"
    local rollback_after="$lane_root/literal-v17-rollback-after.dump"
    local replay_before_hash
    local replay_after_hash
    local rollback_before_hash
    local rollback_after_hash
    local prefix="literal_v17_${lane//./_}"
    local camp_id="$prefix-camp"
    local squad_id="$prefix-squad"
    local mission_id="$prefix-mission"
    local work_id="$prefix-work"
    local job_id="$prefix-job"
    local discussion_id="$prefix-discussion"
    local first_turn_id="$prefix-turn-1"
    local second_turn_id="$prefix-turn-2"
    local hash_a="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    local hash_b="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

    require_file "$baseline"
    cp "$baseline" "$success_database"
    cp "$baseline" "$rollback_database"

    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM artifact;" "0" \
        "$lane literal v17 baseline artifact table is empty"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';" \
        "67" "$lane literal v17 clean v16 predecessor tables"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='index';" \
        "171" "$lane literal v17 clean v16 predecessor indexes"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='trigger';" \
        "67" "$lane literal v17 clean v16 predecessor triggers"

    {
        printf 'PRAGMA foreign_keys = ON;\n'
        printf 'BEGIN IMMEDIATE;\n'
        awk '{ print }' "$literal_engine_coordination_sql"
        printf 'COMMIT;\n'
    } > "$success_input"
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" < "$success_input"

    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';" \
        "79" "$lane literal v17 table checkpoint"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='index';" \
        "208" "$lane literal v17 index checkpoint"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='trigger';" \
        "84" "$lane literal v17 trigger checkpoint"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT group_concat(name,',') FROM (SELECT name FROM sqlite_master WHERE type='table' AND name IN ('engine_session','engine_execution','engine_terminal_proposal','artifact_blob','engine_proposal_artifact','camp_deletion_proposal_blob','artifact_blob_reference','artifact_storage_origin','discussion','discussion_turn','attention_item','growth_evidence') ORDER BY name);" \
        "artifact_blob,artifact_blob_reference,artifact_storage_origin,attention_item,camp_deletion_proposal_blob,discussion,discussion_turn,engine_execution,engine_proposal_artifact,engine_session,engine_terminal_proposal,growth_evidence" \
        "$lane literal v17 exact table set"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT group_concat(name,',') FROM (SELECT name FROM sqlite_master WHERE type='index' AND name IN ('engine_session_external_identity','engine_session_resume','engine_execution_recovery','engine_execution_card','engine_terminal_proposal_pending','artifact_blob_path','artifact_blob_gc','engine_proposal_artifact_gc_root','camp_deletion_proposal_blob_recovery','artifact_blob_reference_live','artifact_blob_reference_camp','artifact_storage_origin_camp','discussion_turn_round','attention_item_open','growth_evidence_subject') ORDER BY name);" \
        "artifact_blob_gc,artifact_blob_path,artifact_blob_reference_camp,artifact_blob_reference_live,artifact_storage_origin_camp,attention_item_open,camp_deletion_proposal_blob_recovery,discussion_turn_round,engine_execution_card,engine_execution_recovery,engine_proposal_artifact_gc_root,engine_session_external_identity,engine_session_resume,engine_terminal_proposal_pending,growth_evidence_subject" \
        "$lane literal v17 exact named index set"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT group_concat(name,',') FROM (SELECT name FROM sqlite_master WHERE type='trigger' AND name IN ('engine_session_first_redaction_exact','engine_session_post_redaction_lock','engine_session_reject_delete','engine_execution_first_redaction_exact','engine_execution_post_redaction_lock','engine_execution_reject_delete','engine_terminal_proposal_first_redaction_exact','engine_terminal_proposal_post_redaction_lock','engine_terminal_proposal_reject_delete','engine_proposal_artifact_reject_private_field_update','engine_proposal_artifact_post_redaction_lock','engine_proposal_artifact_reject_delete','artifact_storage_origin_first_redaction_exact','artifact_storage_origin_post_redaction_lock','artifact_storage_origin_reject_delete','discussion_turn_reject_update_except_camp_redaction','discussion_turn_reject_delete') ORDER BY name);" \
        "artifact_storage_origin_first_redaction_exact,artifact_storage_origin_post_redaction_lock,artifact_storage_origin_reject_delete,discussion_turn_reject_delete,discussion_turn_reject_update_except_camp_redaction,engine_execution_first_redaction_exact,engine_execution_post_redaction_lock,engine_execution_reject_delete,engine_proposal_artifact_post_redaction_lock,engine_proposal_artifact_reject_delete,engine_proposal_artifact_reject_private_field_update,engine_session_first_redaction_exact,engine_session_post_redaction_lock,engine_session_reject_delete,engine_terminal_proposal_first_redaction_exact,engine_terminal_proposal_post_redaction_lock,engine_terminal_proposal_reject_delete" \
        "$lane literal v17 exact trigger set"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM grdb_migrations WHERE identifier='v16-p1-identity-memory';" \
        "1" "$lane literal v17 predecessor migration"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM grdb_migrations WHERE identifier='v17-p1-engine-coordination';" \
        "0" "$lane literal v17 remains SQL-only"

    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" "
        PRAGMA foreign_keys=ON;
        BEGIN IMMEDIATE;
        INSERT INTO camp(id,name,archived,createdAt)
          VALUES('$camp_id','Literal v17 $lane',0,1);
        INSERT INTO camp_lifecycle(
          campId,state,version,createdAt,updatedAt,deletionRequestedAt,deletedAt
        ) VALUES('$camp_id','deleting',1,1,1,1,NULL);
        INSERT INTO squad(
          id,campId,name,memberIdsJson,workspacePath,workspaceBookmark,createdAt
        ) VALUES('$squad_id','$camp_id','Squad','[]',NULL,NULL,1);
        INSERT INTO mission(
          id,squadId,goalRaw,goalRefined,status,budgetTokens,spentTokens,
          revision,autonomy,createdAt
        ) VALUES('$mission_id','$squad_id','Goal','Goal','planning',1000,0,1,
          'standard',1);
        INSERT INTO durable_work(
          id,campId,campLifecycleVersion,kind,aggregateType,aggregateId,
          idempotencyKey,state,attempt,maxAttempts,notBefore,leaseOwner,
          leaseExpiresAt,inputJson,inputHash,outputJson,errorCode,errorMessage,
          traceId,version,createdAt,updatedAt,finishedAt
        ) VALUES('$work_id','$camp_id',1,'campDeletion','camp','$camp_id',
          '$prefix-delete','queued',0,4,NULL,NULL,NULL,'{}','$hash_a',NULL,NULL,
          NULL,'$prefix-trace',1,1,1,NULL);
        INSERT INTO camp_deletion_job(
          id,campId,workId,requestIdempotencyKey,confirmationId,
          confirmationHash,unknownArtifactDisposition,requestedByActorId,state,
          phaseCursorJson,lastErrorCode,version,createdAt,updatedAt,completedAt
        ) VALUES('$job_id','$camp_id','$work_id','$prefix-request',
          '$prefix-confirmation','$hash_b','detachOnlyNeverUnlink','actor:matrix',
          'erasing','{}',NULL,1,1,1,NULL);
        INSERT INTO discussion(
          id,campId,goalId,missionId,cardId,purpose,
          participantActorIdsJson,maxRounds,tokenBudget,spentTokens,status,
          requiredMaterialization,materializationType,materializationId,
          aggregateVersion,createdAt,updatedAt
        ) VALUES('$discussion_id','$camp_id',NULL,'$mission_id',NULL,
          'Validate append-only turns','[\"actor:a\",\"actor:b\"]',2,1000,20,
          'running','decision',NULL,NULL,1,1,1);
        INSERT INTO discussion_turn(
          id,discussionId,round,sequence,speakerActorId,contentRef,contentHash,
          inputTokens,outputTokens,createdAt,redactedAt
        ) VALUES('$first_turn_id','$discussion_id',1,0,'actor:a','ref:first',
          '$hash_a',5,5,1,NULL);
        INSERT INTO discussion_turn(
          id,discussionId,round,sequence,speakerActorId,contentRef,contentHash,
          inputTokens,outputTokens,createdAt,redactedAt
        ) VALUES('$second_turn_id','$discussion_id',1,1,'actor:b','ref:second',
          '$hash_b',5,5,1,NULL);
        COMMIT;
        "
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "UPDATE discussion_turn SET contentRef='',redactedAt=2 WHERE id='$first_turn_id';" \
        "$lane literal v17 discussion wrong-phase redaction"
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" \
        "UPDATE camp_deletion_job SET state='finalizing',version=version+1,updatedAt=2 WHERE id='$job_id'; UPDATE discussion_turn SET contentRef='',redactedAt=2 WHERE id='$first_turn_id';"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "UPDATE discussion_turn SET redactedAt=3 WHERE id='$first_turn_id';" \
        "$lane literal v17 discussion second redaction"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "UPDATE discussion_turn SET contentRef=contentRef WHERE id='$second_turn_id';" \
        "$lane literal v17 discussion no-op update"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "UPDATE discussion_turn SET contentRef='',outputTokens=outputTokens+1,redactedAt=2 WHERE id='$second_turn_id';" \
        "$lane literal v17 discussion extra-field redaction"
    expect_sqlite_failure "$sqlite_cli" "$success_database" \
        "DELETE FROM discussion_turn WHERE id='$second_turn_id';" \
        "$lane literal v17 discussion delete"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT contentRef||'|'||redactedAt FROM discussion_turn WHERE id='$first_turn_id';" \
        "|2" "$lane literal v17 first exact redaction"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT contentRef||'|'||outputTokens||'|'||COALESCE(redactedAt,'NULL') FROM discussion_turn WHERE id='$second_turn_id';" \
        "ref:second|5|NULL" "$lane literal v17 rejected turn changes"
    assert_query "$sqlite_cli" "$success_database" \
        "SELECT COUNT(*) FROM discussion_turn WHERE discussionId='$discussion_id';" \
        "2" "$lane literal v17 rejected turn deletion"
    printf 'discussion.redaction.first_wrong_second_noop_extra_delete=pass\n'

    assert_query "$sqlite_cli" "$success_database" \
        "PRAGMA foreign_key_check;" "" "$lane literal v17 foreign keys"
    assert_query "$sqlite_cli" "$success_database" \
        "PRAGMA integrity_check;" "ok" "$lane literal v17 integrity"
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" ".dump" > "$replay_before"
    replay_before_hash="$(shasum -a 256 "$replay_before" | awk '{print $1}')"
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" "PRAGMA foreign_key_check; PRAGMA integrity_check;" \
        >/dev/null
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$success_database" ".dump" > "$replay_after"
    replay_after_hash="$(shasum -a 256 "$replay_after" | awk '{print $1}')"
    test "$replay_after_hash" = "$replay_before_hash" \
        || fail "$lane literal v17 reopen changed logical snapshot"

    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$rollback_database" \
        "CREATE TRIGGER discussion_turn_reject_delete BEFORE DELETE ON camp BEGIN SELECT 1; END;"
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$rollback_database" ".dump" > "$rollback_before"
    rollback_before_hash="$(shasum -a 256 "$rollback_before" | awk '{print $1}')"
    {
        printf 'PRAGMA foreign_keys = ON;\n'
        printf 'BEGIN IMMEDIATE;\n'
        awk '{ print }' "$literal_engine_coordination_sql"
        printf 'COMMIT;\n'
    } > "$rollback_input"
    if "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$rollback_database" < "$rollback_input"
    then
        fail "$lane literal v17 last-trigger conflict unexpectedly succeeded"
    fi
    "$sqlite_cli" -init /dev/null -batch -bail -nofollow \
        "$rollback_database" ".dump" > "$rollback_after"
    rollback_after_hash="$(shasum -a 256 "$rollback_after" | awk '{print $1}')"
    test "$rollback_after_hash" = "$rollback_before_hash" \
        || fail "$lane literal v17 last-trigger rollback dump changed"
    assert_query "$sqlite_cli" "$rollback_database" \
        "SELECT type||'|'||tbl_name FROM sqlite_master WHERE name='discussion_turn_reject_delete';" \
        "trigger|camp" "$lane literal v17 rollback sentinel"
    assert_query "$sqlite_cli" "$rollback_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN ('engine_session','engine_execution','engine_terminal_proposal','artifact_blob','engine_proposal_artifact','camp_deletion_proposal_blob','artifact_blob_reference','artifact_storage_origin','discussion','discussion_turn','attention_item','growth_evidence');" \
        "0" "$lane literal v17 rollback tables"
    assert_query "$sqlite_cli" "$rollback_database" \
        "SELECT COUNT(*) FROM sqlite_master WHERE type='trigger' AND name IN ('engine_session_first_redaction_exact','engine_session_post_redaction_lock','engine_session_reject_delete','engine_execution_first_redaction_exact','engine_execution_post_redaction_lock','engine_execution_reject_delete','engine_terminal_proposal_first_redaction_exact','engine_terminal_proposal_post_redaction_lock','engine_terminal_proposal_reject_delete','engine_proposal_artifact_reject_private_field_update','engine_proposal_artifact_post_redaction_lock','engine_proposal_artifact_reject_delete','artifact_storage_origin_first_redaction_exact','artifact_storage_origin_post_redaction_lock','artifact_storage_origin_reject_delete','discussion_turn_reject_update_except_camp_redaction');" \
        "0" "$lane literal v17 rollback canonical trigger prefix"
    assert_query "$sqlite_cli" "$rollback_database" \
        "SELECT COUNT(*) FROM grdb_migrations WHERE identifier='v17-p1-engine-coordination';" \
        "0" "$lane literal v17 rollback migration record"
    assert_query "$sqlite_cli" "$rollback_database" \
        "PRAGMA foreign_key_check;" "" "$lane literal v17 rollback FKs"
    assert_query "$sqlite_cli" "$rollback_database" \
        "PRAGMA integrity_check;" "ok" "$lane literal v17 rollback integrity"

    printf 'literal.v17.engine_coordination.checkpoint=79/208/84\n'
    printf 'literal.v17.engine_coordination.append_only=pass\n'
    printf 'literal.v17.engine_coordination.replay=pass\n'
    printf 'literal.v17.engine_coordination.rollback=pass\n'
    printf 'literal.v17.engine_coordination.fk=pass\n'
    printf 'literal.v17.engine_coordination.integrity=pass\n'
}

run_lane() {
    local lane="$1"
    local sqlite_cli="$2"
    local expected_prefix="$3"
    local exact_cli_version
    local runner_bin
    local runner_log
    local literal_observability_log
    local observability_sentinel_log
    local literal_control_log
    local control_sentinel_log
    local literal_identity_memory_log
    local identity_memory_sentinel_log
    local literal_engine_coordination_log
    local engine_coordination_sentinel_log
    local lane_root="$matrix_tmp/lane-$lane"
    local cli_source_id
    local scope

    exact_cli_version="$(cli_version "$sqlite_cli")"
    case "$exact_cli_version" in
        "$expected_prefix".*) ;;
        *)
            fail "$lane CLI version is $exact_cli_version"
            ;;
    esac
    cli_source_id="$("$sqlite_cli" -init /dev/null -batch :memory: \
        "SELECT sqlite_source_id();")"
    printf 'cli.%s.sqlite_version=%s\n' "$lane" "$exact_cli_version"
    printf 'cli.%s.sqlite_source_id=%s\n' "$lane" "$cli_source_id"

    runner_bin="$(build_runner "$lane")"
    mkdir -p "$lane_root"
    runner_log="$matrix_tmp/runner-$lane.log"
    /usr/bin/env \
        -u DYLD_LIBRARY_PATH \
        -u DYLD_FALLBACK_LIBRARY_PATH \
        -u DYLD_INSERT_LIBRARIES \
        "$runner_bin" \
        --expected-sqlite-version "$exact_cli_version" \
        --fixtures \
        "fresh,v7,v8-coding-ranch,v9-evercamp,v10-runtime-profiles,v11-cli-kinds,v12-durable,v12-schedule,v13-observability,v14-control-contracts,v15-empty,v15-populated,v16-identity-memory,v17-engine-coordination" \
        --literal-schema "$literal_schedule_sql" \
        --literal-observability-schema "$literal_observability_sql" \
        --literal-control-schema "$literal_control_sql" \
        --literal-outcome-schema "$literal_outcome_sql" \
        --literal-identity-memory-schema "$literal_identity_memory_sql" \
        --literal-engine-coordination-schema "$literal_engine_coordination_sql" \
        --output-root "$lane_root" \
        | tee "$runner_log"

    assert_file_line "$runner_log" \
        "lane.sqlite_version=$exact_cli_version" \
        "$lane runner sqlite_version"
    assert_file_line "$runner_log" \
        "lane.sqlite_source_id=$cli_source_id" \
        "$lane runner sqlite_source_id"
    assert_file_line "$runner_log" \
        "literal_schedule_schema_shape=bound" \
        "$lane canonical Stage §18.2 schema shape"
    assert_file_line "$runner_log" \
        "literal_outcome_schema_shape=bound" \
        "$lane canonical Stage §18.5 schema shape"
    assert_file_line "$runner_log" \
        "fixture.v12-durable.predecessor_snapshot=pass" \
        "$lane v12-durable predecessor data snapshot"
    assert_file_line "$runner_log" \
        "fixture.v12-durable.final_idempotent_snapshot=pass" \
        "$lane v12-durable final idempotent snapshot"
    assert_file_line "$runner_log" \
        "rollback.real_v12_durable=pass" \
        "$lane durable migration rollback"
    assert_file_line "$runner_log" \
        "rollback.real_v12_schedule_fire=pass" \
        "$lane schedule-fire migration rollback"
    assert_file_line "$runner_log" \
        "rollback.introduction_guard=pass" \
        "$lane append-only introduction guard rollback"
    for scope in \
        real.fresh \
        real.v7 \
        real.v8-coding-ranch \
        real.v9-evercamp \
        real.v10-runtime-profiles \
        real.v11-cli-kinds \
        real.v12-durable \
        real.v12-schedule \
        real.v13-observability \
        real.v14-control-contracts \
        real.v15-empty \
        real.v15-populated \
        real.v16-identity-memory \
        real.v17-engine-coordination \
        literal
    do
        assert_file_line "$runner_log" \
            "schedule_contract.$scope=pass" \
            "$lane $scope schedule contract"
        assert_file_line "$runner_log" \
            "diagnostics.$scope.work.total=56 accepted=18 check_rejected=38" \
            "$lane $scope work diagnostics"
        assert_file_line "$runner_log" \
            "diagnostics.$scope.attempt.total=40 accepted=10 check_rejected=30" \
            "$lane $scope attempt diagnostics"
        assert_file_line "$runner_log" \
            "diagnostics.$scope.event.total=288 accepted=17 check_rejected=271" \
            "$lane $scope event diagnostics"
        assert_file_line "$runner_log" \
            "diagnostics.$scope.sentinels.total=7 accepted=0 check_rejected=7" \
            "$lane $scope NULL/UNKNOWN sentinels"
        assert_file_line "$runner_log" \
            "diagnostics.$scope.controls.total=19 accepted=19 check_rejected=0" \
            "$lane $scope legal controls"
        assert_file_line "$runner_log" \
            "diagnostics.$scope.result=pass" \
            "$lane $scope diagnostics result"
    done

    for scope in \
        real.fresh \
        real.v7 \
        real.v8-coding-ranch \
        real.v9-evercamp \
        real.v10-runtime-profiles \
        real.v11-cli-kinds \
        real.v12-durable \
        real.v12-schedule \
        real.v13-observability \
        real.v14-control-contracts \
        real.v15-empty \
        real.v15-populated \
        real.v16-identity-memory \
        real.v17-engine-coordination
    do
        assert_file_line "$runner_log" \
            "udf.$scope.registration_and_fail_closed=pass" \
            "$lane $scope connection-local UDF"
        assert_file_line "$runner_log" \
            "identity_memory_contract.$scope=pass" \
            "$lane $scope identity-memory contract"
    done
    assert_file_line "$runner_log" \
        "fixture.v15Empty.replay=pass" \
        "$lane empty v15 replay"
    assert_file_line "$runner_log" \
        "fixture.v15Populated.backfill=pass" \
        "$lane populated v15 backfill"

    assert_file_line "$runner_log" \
        "matrix.result=pass" \
        "$lane runner matrix result"

    verify_literal_lane "$lane" "$sqlite_cli" "$lane_root"
    literal_observability_log="$matrix_tmp/literal-observability-$lane.log"
    verify_literal_observability_lane "$lane" "$sqlite_cli" "$lane_root" \
        | tee "$literal_observability_log"
    observability_sentinel_log="$matrix_tmp/observability-sentinels-$lane.log"
    cat "$runner_log" "$literal_observability_log" \
        > "$observability_sentinel_log"
    assert_ordered_unique_lines "$observability_sentinel_log" \
        "observability_contract.real.fresh=pass" \
        "observability_contract.real.v7=pass" \
        "observability_contract.real.v8-coding-ranch=pass" \
        "observability_contract.real.v9-evercamp=pass" \
        "observability_contract.real.v10-runtime-profiles=pass" \
        "observability_contract.real.v11-cli-kinds=pass" \
        "observability_contract.real.v12-durable=pass" \
        "observability_contract.real.v12-schedule=pass" \
        "fixture.v12-schedule.observability.predecessor_snapshot=pass" \
        "fixture.v12-schedule.observability.failure_record=pass" \
        "fixture.v12-schedule.observability.context_degradation=pass" \
        "fixture.v12-schedule.observability.rollback=pass" \
        "fixture.v12-schedule.observability.replay=pass" \
        "fixture.v12-schedule.observability.fk=pass" \
        "fixture.v12-schedule.observability.integrity=pass" \
        "fixture.v12-schedule.observability.ddl=pass" \
        "fixture.v12-schedule.observability.append_only=pass" \
        "fixture.v12-schedule.observability.final_checkpoint=31/65/4" \
        "observability_contract.real.v13-observability=pass" \
        "observability_contract.real.v14-control-contracts=pass" \
        "observability_contract.real.v15-empty=pass" \
        "observability_contract.real.v15-populated=pass" \
        "observability_contract.real.v16-identity-memory=pass" \
        "observability_contract.real.v17-engine-coordination=pass" \
        "literal_observability_schema_shape=bound" \
        "observability_contract.literal=pass" \
        "rollback.real_v13_observability=pass" \
        "rollback.literal_v13_observability=pass" \
        "literal.v13.observability.rollback=pass" \
        "literal.v13.observability.replay=pass" \
        "literal.v13.observability.final_checkpoint=31/65/4"

    literal_control_log="$matrix_tmp/literal-control-$lane.log"
    verify_literal_control_lane "$lane" "$sqlite_cli" "$lane_root" \
        | tee "$literal_control_log"
    control_sentinel_log="$matrix_tmp/control-sentinels-$lane.log"
    cat "$runner_log" "$literal_control_log" > "$control_sentinel_log"
    assert_ordered_unique_lines "$control_sentinel_log" \
        "literal_control_schema_shape=bound" \
        "control_contract.real.fresh=pass" \
        "control_contract.real.v7=pass" \
        "control_contract.real.v8-coding-ranch=pass" \
        "control_contract.real.v9-evercamp=pass" \
        "control_contract.real.v10-runtime-profiles=pass" \
        "control_contract.real.v11-cli-kinds=pass" \
        "control_contract.real.v12-durable=pass" \
        "control_contract.real.v12-schedule=pass" \
        "control_contract.real.v13-observability=pass" \
        "fixture.v13-observability.control.predecessor_snapshot=pass" \
        "fixture.v13-observability.control.replay=pass" \
        "fixture.v13-observability.control.fk=pass" \
        "fixture.v13-observability.control.integrity=pass" \
        "fixture.v13-observability.control.ddl=pass" \
        "fixture.v13-observability.control.append_only=pass" \
        "fixture.v13-observability.control.final_checkpoint=41/94/8" \
        "control_contract.real.v14-control-contracts=pass" \
        "control_contract.real.v15-empty=pass" \
        "control_contract.real.v15-populated=pass" \
        "control_contract.real.v16-identity-memory=pass" \
        "control_contract.real.v17-engine-coordination=pass" \
        "control_contract.literal=pass" \
        "rollback.real_v14_control_contracts=pass" \
        "rollback.literal_v14_control_contracts=pass" \
        "literal.v14.control.rollback=pass" \
        "literal.v14.control.replay=pass" \
        "literal.v14.control.fk=pass" \
        "literal.v14.control.integrity=pass" \
        "literal.v14.control.ddl=pass" \
        "literal.v14.control.append_only=pass" \
        "literal.v14.control.final_checkpoint=41/94/8"

    assert_ordered_unique_lines "$runner_log" \
        "literal_outcome_schema_shape=bound" \
        "outcome_contract.real.fresh=pass" \
        "outcome_contract.real.v7=pass" \
        "outcome_contract.real.v8-coding-ranch=pass" \
        "outcome_contract.real.v9-evercamp=pass" \
        "outcome_contract.real.v10-runtime-profiles=pass" \
        "outcome_contract.real.v11-cli-kinds=pass" \
        "outcome_contract.real.v12-durable=pass" \
        "outcome_contract.real.v12-schedule=pass" \
        "outcome_contract.real.v13-observability=pass" \
        "outcome_contract.real.v14-control-contracts=pass" \
        "fixture.v14-control-contracts.outcome.predecessor_snapshot=pass" \
        "fixture.v14-control-contracts.outcome.replay=pass" \
        "fixture.v14-control-contracts.outcome.fk=pass" \
        "fixture.v14-control-contracts.outcome.integrity=pass" \
        "fixture.v14-control-contracts.outcome.ddl=pass" \
        "fixture.v14-control-contracts.outcome.append_only=pass" \
        "fixture.v14-control-contracts.outcome.final_checkpoint=55/134/16" \
        "outcome_contract.real.v15-empty=pass" \
        "fixture.v15Empty.replay=pass" \
        "outcome_contract.real.v15-populated=pass" \
        "fixture.v15Populated.backfill=pass" \
        "outcome_contract.real.v16-identity-memory=pass" \
        "outcome_contract.real.v17-engine-coordination=pass" \
        "outcome_contract.literal=pass" \
        "rollback.real_v15_outcome_contracts=pass" \
        "rollback.literal_v15_outcome_contracts=pass" \
        "matrix.result=pass"

    literal_identity_memory_log="$matrix_tmp/literal-identity-memory-$lane.log"
    verify_literal_identity_memory_lane "$lane" "$sqlite_cli" "$lane_root" \
        | tee "$literal_identity_memory_log"
    identity_memory_sentinel_log="$matrix_tmp/identity-memory-sentinels-$lane.log"
    cat "$runner_log" "$literal_identity_memory_log" \
        > "$identity_memory_sentinel_log"
    assert_ordered_unique_lines "$identity_memory_sentinel_log" \
        "identity_memory_contract.real.fresh=pass" \
        "identity_memory_contract.real.v7=pass" \
        "identity_memory_contract.real.v8-coding-ranch=pass" \
        "identity_memory_contract.real.v9-evercamp=pass" \
        "identity_memory_contract.real.v10-runtime-profiles=pass" \
        "identity_memory_contract.real.v11-cli-kinds=pass" \
        "identity_memory_contract.real.v12-durable=pass" \
        "identity_memory_contract.real.v12-schedule=pass" \
        "identity_memory_contract.real.v13-observability=pass" \
        "identity_memory_contract.real.v14-control-contracts=pass" \
        "identity_memory_contract.real.v15-empty=pass" \
        "fixture.v15Empty.replay=pass" \
        "identity_memory_contract.real.v15-populated=pass" \
        "fixture.v15Populated.backfill=pass" \
        "fixture.v16-identity-memory.replay=pass" \
        "identity_memory_contract.real.v16-identity-memory=pass" \
        "fixture.v17-engine-coordination.replay=pass" \
        "identity_memory_contract.real.v17-engine-coordination=pass" \
        "diagnostics.v16.sentinels.total=7 accepted=0 check_rejected=7" \
        "identity_memory_contract.literal=pass" \
        "literal.v16.identity_memory.checkpoint=67/171/67" \
        "literal.v16.identity_memory.udf_absent_matching_evidence=pass" \
        "literal.v16.identity_memory.replay=pass" \
        "literal.v16.identity_memory.rollback=pass" \
        "literal.v16.identity_memory.fk=pass" \
        "literal.v16.identity_memory.integrity=pass"

    literal_engine_coordination_log="$matrix_tmp/literal-engine-coordination-$lane.log"
    verify_literal_engine_coordination_lane "$lane" "$sqlite_cli" "$lane_root" \
        | tee "$literal_engine_coordination_log"
    engine_coordination_sentinel_log="$matrix_tmp/engine-coordination-sentinels-$lane.log"
    cat "$runner_log" "$literal_engine_coordination_log" \
        > "$engine_coordination_sentinel_log"
    assert_ordered_unique_lines "$engine_coordination_sentinel_log" \
        "literal_engine_coordination_schema_shape=bound" \
        "engine_coordination_contract.real.fresh=pass" \
        "engine_coordination_contract.real.v7=pass" \
        "engine_coordination_contract.real.v8-coding-ranch=pass" \
        "engine_coordination_contract.real.v9-evercamp=pass" \
        "engine_coordination_contract.real.v10-runtime-profiles=pass" \
        "engine_coordination_contract.real.v11-cli-kinds=pass" \
        "engine_coordination_contract.real.v12-durable=pass" \
        "engine_coordination_contract.real.v12-schedule=pass" \
        "engine_coordination_contract.real.v13-observability=pass" \
        "engine_coordination_contract.real.v14-control-contracts=pass" \
        "engine_coordination_contract.real.v15-empty=pass" \
        "engine_coordination_contract.real.v15-populated=pass" \
        "fixture.v16-identity-memory.engine_coordination.predecessor_snapshot=pass" \
        "fixture.v16-identity-memory.engine_coordination.legacy_artifact_backfill=pass" \
        "artifact_origin.count_camp_path_hash=pass" \
        "engine_coordination_contract.real.v16-identity-memory=pass" \
        "engine_coordination_contract.real.v17-engine-coordination=pass" \
        "rollback.real_v17_engine_coordination=pass" \
        "discussion.redaction.first_wrong_second_noop_extra_delete=pass" \
        "literal.v17.engine_coordination.checkpoint=79/208/84" \
        "literal.v17.engine_coordination.append_only=pass" \
        "literal.v17.engine_coordination.replay=pass" \
        "literal.v17.engine_coordination.rollback=pass" \
        "literal.v17.engine_coordination.fk=pass" \
        "literal.v17.engine_coordination.integrity=pass"
}

run_lane "3.51" "$system_sqlite" "3.51"
run_lane "3.52" "$homebrew_sqlite" "3.52"

resolved_hash_after="$(shasum -a 256 "$resolved_file" | awk '{print $1}')"
test "$resolved_hash_after" = "$resolved_hash_before" \
    || fail "Package.resolved changed during matrix"
test "$resolved_hash_after" = "$expected_resolved_hash" \
    || fail "frozen Package.resolved hash drifted: $resolved_hash_after"

printf 'package_resolved.sha256=%s\n' "$resolved_hash_after"
printf 'p1_migration_matrix.result=pass\n'
