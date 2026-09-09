#!/bin/bash

# R24 reviewed clean re-verification driver.
# BEGIN, the unique full test, every later mechanical gate, both interactive
# preview checkpoints, and END execute in this one Bash 3.2 process.  No
# caller-shell status, lifecycle state, or ad-hoc continuation is trusted.

set -Eeuo pipefail
set -f
IFS=$' \t\n'
umask 077

readonly R24_REPOSITORY_ROOT="/Users/muzi/Agent-loop"
readonly R24_TASK_DIRECTORY="${R24_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination"
readonly R24_DRIVER_PATH="${R24_TASK_DIRECTORY}/evidence/r24-begin.sh"
readonly R24_MANIFEST_PATH="${R24_TASK_DIRECTORY}/evidence/r24-entry.sha256"
readonly R24_FREEZE_PATH="${R24_TASK_DIRECTORY}/evidence/plan-freeze-r24.md"
readonly R24_REVIEW24_PATH="${R24_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/24-p1-plan-review.md"
readonly R24_BOUNDARY_LOG="${R24_TASK_DIRECTORY}/evidence/r24-clean-boundary.log"
readonly R24_HASH_LOG="${R24_TASK_DIRECTORY}/evidence/r24-hash-manifest.log"
readonly R24_VERIFY_LOG="${R24_TASK_DIRECTORY}/r24-verify.log"
readonly R24_EXPECTED_MANIFEST_COUNT="178"
readonly R24_EXPECTED_BRANCH="codex/personal-ai-ranch-p0"
readonly R24_EXPECTED_HEAD="02334ec8d21533be81d93d39191bc7d9b9c24f7f"
readonly R24_EXPECTED_CORE_SHA="c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275"
readonly R24_EXPECTED_TEST_SHA="37fad0b3b123d248f6a52128f5f5d60559587cb8d291b6a6a6da1d615ad87967"
readonly R24_EXPECTED_R20_TEST_SHA="66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26"
readonly R24_EXPECTED_RANCH_ART_MANIFEST_SHA="4f73a80e821faa64d0a29d797cc12e20d5f88248bbb186e74972af49798ddbab"
readonly R24_EXPECTED_MATRIX_ENTRY_SHA="75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c"
readonly R24_EXPECTED_R23_FREEZE_SHA="9c791a1bab22026ed2930eb120b9c82923390d42fad61a78f53b40080c6cef9a"
readonly R24_EXPECTED_R23_REVIEW_SHA="13bd182b8701df2b83fa63c58e978b440ed55c75c0c4a6c3ac936116d411a8bc"
readonly R24_EXPECTED_R23_DRIVER_SHA="0d82a6cf04d4391117d0095bc3b7439f7402d965b45e4396fce50811f4ed4c6c"
readonly R24_EXPECTED_R23_MANIFEST_SHA="1776c5694ce8799258c5f4b37b623d230f3f37218d54817c25489c8dd63a4006"
readonly R24_EXPECTED_R23_REPORT_SHA="512e123bcd861043c3f57c08a364489f662582528ecd7f745f282ee9ab999c69"
readonly R24_EXPECTED_R23_BOUNDARY_SHA="4b17b1e7e8536fa88b7b41e68efc089f3b300dd801d42729a375fe2284cd5a78"
readonly R24_EXPECTED_R23_HASH_LOG_SHA="cdb9776b645f0db4b059d2c4e44a974da3788c565653741e1ff2635c22e3afeb"
readonly R24_EXPECTED_R23_VERIFY_SHA="c0f5fe79792c60eacfa266a12d53f79abdf3cea53d6e8c9e1f6bc42337100762"
readonly R24_EXPECTED_EMPTY_SHA="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

readonly R24_R23_FREEZE_PATH="${R24_TASK_DIRECTORY}/evidence/plan-freeze-r23.md"
readonly R24_R23_REVIEW_PATH="${R24_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/23-p1-plan-review.md"
readonly R24_R23_DRIVER_PATH="${R24_TASK_DIRECTORY}/evidence/r23-begin.sh"
readonly R24_R23_MANIFEST_PATH="${R24_TASK_DIRECTORY}/evidence/r23-entry.sha256"
readonly R24_R23_REPORT_PATH="${R24_TASK_DIRECTORY}/impl-report-r23.md"
readonly R24_R23_BOUNDARY_PATH="${R24_TASK_DIRECTORY}/evidence/r23-clean-boundary.log"
readonly R24_R23_HASH_LOG_PATH="${R24_TASK_DIRECTORY}/evidence/r23-hash-manifest.log"
readonly R24_R23_VERIFY_PATH="${R24_TASK_DIRECTORY}/r23-verify.log"
readonly R24_R23_SCREENSHOT_PATH="${R24_TASK_DIRECTORY}/evidence/r23-preview-smoke.png"
readonly R24_R23_STATE_ROOT="/private/tmp/agentloop-r23-state.GsQHd1"
readonly R24_R23_BUNDLE_ROOT="/private/tmp/agentloop-r23-bundle.PuKOJy"
readonly R24_R23_PLANNED_APP="${R24_R23_BUNDLE_ROOT}/AgentLoop.app"
readonly R24_R23_PLANNED_EXECUTABLE="${R24_R23_PLANNED_APP}/Contents/MacOS/AgentLoop"
readonly R24_R23_BASELINE_MASK="11"

readonly R24_R15_STATE_ROOT="/private/tmp/agentloop-r15-state.Zq6Jvm"
readonly R24_R15_BUNDLE_ROOT="/private/tmp/agentloop-r15-bundle.2xROcy"

readonly R24_R19_STATE_ROOT="/private/tmp/agentloop-r19-state.dNgUXh"
readonly R24_R19_BUNDLE_ROOT="/private/tmp/agentloop-r19-bundle.49xVDm"
readonly R24_R20_STATE_ROOT="/private/tmp/agentloop-r20-state.3QwlQa"
readonly R24_R20_BUNDLE_ROOT="/private/tmp/agentloop-r20-bundle.30V5RH"
readonly R24_R20_APP="${R24_R20_BUNDLE_ROOT}/AgentLoop.app"
readonly R24_R20_BASELINE_MASK="11101011100000000000000000000000000010"
readonly R24_R20_CONTENTS="${R24_R20_APP}/Contents"
readonly R24_R20_MACOS="${R24_R20_CONTENTS}/MacOS"
readonly R24_R20_RESOURCES="${R24_R20_CONTENTS}/Resources"
readonly R24_R20_RESOURCE_BUNDLE="${R24_R20_RESOURCES}/AgentLoop_AgentLoopApp.bundle"
readonly R24_R20_RANCH_ART="${R24_R20_RESOURCE_BUNDLE}/RanchArt"
readonly R24_R20_CODE_SIGNATURE="${R24_R20_CONTENTS}/_CodeSignature"

readonly R24_CORE_PATH="${R24_REPOSITORY_ROOT}/Sources/AgentLoopCore/Loop/AgentLoop.swift"
readonly R24_TEST_PATH="${R24_REPOSITORY_ROOT}/Sources/AgentLoopTestSuite/AgentLoopTests.swift"
readonly R24_MATRIX_SCRIPT="${R24_REPOSITORY_ROOT}/scripts/verify-p1-migrations-sqlite-matrix.sh"
readonly R24_STAGE_PATH="${R24_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md"
readonly R24_RANCH_ART_DIRECTORY="${R24_REPOSITORY_ROOT}/Sources/AgentLoopApp/Resources/RanchArt"
readonly R24_BUILD_LOG="${R24_TASK_DIRECTORY}/r24-build.log"
readonly R24_TARGETED_LOG="${R24_TASK_DIRECTORY}/r24-targeted-tests.log"
readonly R24_MATRIX_LOG="${R24_TASK_DIRECTORY}/r24-migration-matrix.log"
readonly R24_BUNDLE_LOG="${R24_TASK_DIRECTORY}/evidence/r24-bundle-provenance.log"
readonly R24_SOURCE_LOG="${R24_TASK_DIRECTORY}/evidence/r24-source-gates.log"
readonly R24_BOOTSTRAP_LOG="${R24_TASK_DIRECTORY}/evidence/r24-preview-bootstrap.log"
readonly R24_COLD_START_LOG="${R24_TASK_DIRECTORY}/evidence/r24-preview-cold-start.log"
readonly R24_SCREENSHOT="${R24_TASK_DIRECTORY}/evidence/r24-preview-smoke.png"
readonly R24_IMPL_REPORT="${R24_TASK_DIRECTORY}/impl-report-r24.md"

R24_BOUNDARY_ACTIVE="false"
R24_PHASE="pre_begin"
R24_INVOCATION_ID=""
R24_STATE_ROOT=""
R24_BUNDLE_ROOT=""
R24_R23_FIRST_MASK=""
R24_R23_LATEST_MASK="${R24_R23_BASELINE_MASK}"
R24_R23_ACCEPTED_MODE_B=""
R24_R20_FIRST_MASK=""
R24_R20_LATEST_MASK="${R24_R20_BASELINE_MASK}"
R24_R20_ACCEPTED_MODE_B=""
R24_AUTHORITATIVE_SWIFT_RC="UNKNOWN"
R24_AUTHORITATIVE_TEE_RC="UNKNOWN"
R24_AUTHORITATIVE_STATUS_CAPTURED="false"
R24_VERIFY_LOG_SHA="UNKNOWN"
R24_VERIFY_LOG_BYTES="UNKNOWN"
R24_DEFERRED_SIGNAL=""
R24_DEFERRED_SIGNAL_STATUS=""
R24_MATRIX_MUTATED="false"
R24_MATRIX_ENTRY_BYTES=""
R24_MATRIX_ENTRY_SHA=""
R24_MATRIX_BACKUP_PATH=""
R24_MATRIX_MUTATED_STAGE=""
R24_MATRIX_RESTORE_STAGE=""
R24_MATRIX_BACKUP_OWNED="false"
R24_MATRIX_MUTATED_STAGE_OWNED="false"
R24_MATRIX_RESTORE_STAGE_OWNED="false"
R24_APP=""
R24_APP_EXECUTABLE=""
R24_BUILD_EXECUTABLE=""
R24_BUILD_RESOURCE_BUNDLE=""
R24_BUILD_EXECUTABLE_SHA=""
R24_BUILD_UUID_SET=""
R24_SIGNED_EXECUTABLE_SHA=""
R24_SIGNED_BUNDLE_MANIFEST_SHA=""
R24_SIGNED_UUID_SET=""
R24_INFO_PLIST_SHA=""
R24_SIGNED_CDHASH=""
R24_APP_PID=""
R24_APP_CHILDREN=""
R24_APP_PPID=""
R24_APP_DIRECT_CHILD_OWNED="false"
R24_APP_IDENTITY_COMMITTED="false"
R24_BOOTSTRAP_PID=""
R24_BOOTSTRAP_BIRTH=""
R24_BOOTSTRAP_NONCE=""
R24_COLD_START_NONCE=""
R24_PREVIEW_CAMP_ID=""
R24_CURRENT_ROOT_PHASE="uncreated"
R24_BUNDLE_IDENTIFIER=""
R24_APP_BIRTH=""
R24_SCREENSHOT_SHA=""
R24_SCREENSHOT_BYTES=""
R24_SCREENSHOT_WIDTH=""
R24_SCREENSHOT_HEIGHT=""
R24_SCREENSHOT_STAGE=""
R24_SCREENSHOT_STAGE_OWNED="false"
R24_PREVIEW_CONTAINMENT_RC="0"
R24_PREVIEW_CONTAINMENT_WAIT_RC="NOT_WAITED"
R24_PREVIEW_CONTAINMENT_COMMAND_MATCH="NOT_OBSERVED"
R24_PREVIEW_CONTAINMENT_PPID_MATCH="NOT_OBSERVED"
R24_PREVIEW_CONTAINMENT_BIRTH_MATCH="NOT_OBSERVED"
R24_PREVIEW_CONTAINMENT_AUTH_RC="NOT_ATTEMPTED"
R24_CU_RAW_PATH=""
R24_CU_RAW_ENCODING=""
R24_CU_RAW_BYTES=""
R24_CU_RAW_SHA=""
R24_IMPL_REPORT_STAGE=""
R24_IMPL_REPORT_STAGE_SHA=""
R24_IMPL_REPORT_STAGE_OWNED="false"
R24_IMPL_REPORT_PUBLISHED="false"
R24_END_COMMITTED="false"

r24_now() {
  /bin/date -u '+%Y-%m-%dT%H:%M:%SZ'
}

r24_capture_now() {
  local r24_captured_now=""
  if r24_captured_now="$(r24_now)"; then
    :
  else
    return "$?"
  fi
  [[ -n "${r24_captured_now}" && "${r24_captured_now}" != *$'\n'* ]] || return 70
  /usr/bin/printf '%s\n' "${r24_captured_now}"
}

r24_sha() {
  local r24_sha_line=""
  if r24_sha_line="$(/usr/bin/shasum -a 256 "$1")"; then
    /usr/bin/printf '%s\n' "${r24_sha_line%% *}"
  else
    return "$?"
  fi
}

r24_canonical_directory() {
  local r24_directory="$1"
  (
    cd -P "${r24_directory}"
    pwd -P
  )
}

r24_canonical_file() {
  local r24_file="$1"
  local r24_parent=""
  local r24_parent_real=""
  local r24_name=""
  r24_parent="${r24_file%/*}"
  r24_name="${r24_file##*/}"
  [[ -n "${r24_parent}" && -n "${r24_name}" ]] || return 70
  if r24_parent_real="$(r24_canonical_directory "${r24_parent}")"; then
    :
  else
    return "$?"
  fi
  /usr/bin/printf '%s/%s\n' "${r24_parent_real}" "${r24_name}"
}

r24_require_sha_literal() {
  local r24_name="$1"
  local r24_value="$2"
  [[ "${#r24_value}" == "64" ]] || r24_fail 70 "sha_literal_length_${r24_name}_${#r24_value}"
  case "${r24_value}" in
    *[!0-9a-f]*) r24_fail 70 "sha_literal_format_${r24_name}" ;;
  esac
}

r24_require_sha_constant_shapes() {
  local r24_pair=""
  local r24_name=""
  local r24_value=""
  for r24_pair in \
    "expected_core=${R24_EXPECTED_CORE_SHA}" \
    "expected_test=${R24_EXPECTED_TEST_SHA}" \
    "expected_r20_test=${R24_EXPECTED_R20_TEST_SHA}" \
    "expected_ranch_art=${R24_EXPECTED_RANCH_ART_MANIFEST_SHA}" \
    "expected_matrix_entry=${R24_EXPECTED_MATRIX_ENTRY_SHA}" \
    "r23_freeze=${R24_EXPECTED_R23_FREEZE_SHA}" \
    "r23_review=${R24_EXPECTED_R23_REVIEW_SHA}" \
    "r23_driver=${R24_EXPECTED_R23_DRIVER_SHA}" \
    "r23_manifest=${R24_EXPECTED_R23_MANIFEST_SHA}" \
    "r23_report=${R24_EXPECTED_R23_REPORT_SHA}" \
    "r23_boundary=${R24_EXPECTED_R23_BOUNDARY_SHA}" \
    "r23_hash_log=${R24_EXPECTED_R23_HASH_LOG_SHA}" \
    "r23_verify=${R24_EXPECTED_R23_VERIFY_SHA}" \
    "empty=${R24_EXPECTED_EMPTY_SHA}"; do
    r24_name="${r24_pair%%=*}"
    r24_value="${r24_pair#*=}"
    r24_require_sha_literal "${r24_name}" "${r24_value}"
  done
}

r24_require_canonical_entry_paths() {
  local r24_initial_cwd=""
  local r24_repo_real=""
  local r24_driver_parent_real=""
  local r24_driver_real=""
  if r24_initial_cwd="$(pwd -P)"; then :; else r24_fail 70 "entry_pwd_failed"; fi
  [[ "${r24_initial_cwd}" == "${R24_REPOSITORY_ROOT}" ]] || r24_fail 70 "entry_cwd_mismatch_${r24_initial_cwd}"
  [[ -d "${R24_REPOSITORY_ROOT}" && ! -L "${R24_REPOSITORY_ROOT}" ]] || r24_fail 70 "repository_root_not_real_directory"
  if r24_repo_real="$(r24_canonical_directory "${R24_REPOSITORY_ROOT}")"; then :; else r24_fail 70 "repository_root_canonicalization_failed"; fi
  [[ "${r24_repo_real}" == "${R24_REPOSITORY_ROOT}" ]] || r24_fail 70 "repository_root_canonical_mismatch_${r24_repo_real}"
  [[ -d "${R24_TASK_DIRECTORY}/evidence" && ! -L "${R24_TASK_DIRECTORY}/evidence" ]] || r24_fail 70 "driver_parent_not_real_directory"
  if r24_driver_parent_real="$(r24_canonical_directory "${R24_TASK_DIRECTORY}/evidence")"; then :; else r24_fail 70 "driver_parent_canonicalization_failed"; fi
  [[ "${r24_driver_parent_real}" == "${R24_TASK_DIRECTORY}/evidence" ]] || r24_fail 70 "driver_parent_canonical_mismatch_${r24_driver_parent_real}"
  r24_require_regular_file "${R24_DRIVER_PATH}"
  if r24_driver_real="$(r24_canonical_file "${R24_DRIVER_PATH}")"; then :; else r24_fail 70 "driver_canonicalization_failed"; fi
  [[ "${r24_driver_real}" == "${R24_DRIVER_PATH}" ]] || r24_fail 70 "driver_canonical_mismatch_${r24_driver_real}"
  [[ "$0" == "${R24_DRIVER_PATH}" ]] || r24_fail 70 "driver_argv0_not_canonical_$0"
  [[ "${BASH_SOURCE[0]}" == "${R24_DRIVER_PATH}" ]] || r24_fail 70 "driver_BASH_SOURCE_not_canonical_${BASH_SOURCE[0]}"
}

r24_require_private_tmp() {
  local r24_private_tmp=""
  [[ -d /private/tmp && ! -L /private/tmp ]] || r24_fail 70 "private_tmp_not_real_directory"
  if r24_private_tmp="$(r24_canonical_directory /private/tmp)"; then :; else r24_fail 70 "private_tmp_canonicalization_failed"; fi
  [[ "${r24_private_tmp}" == "/private/tmp" ]] || r24_fail 70 "private_tmp_canonical_mismatch_${r24_private_tmp}"
}

r24_pre_begin_fail() {
  local r24_status="$1"
  shift
  /usr/bin/printf 'R24 pre-BEGIN failure: %s\n' "$*" >&2
  exit "${r24_status}"
}

r24_append_boundary() {
  /usr/bin/printf '%s\n' "$*" >> "${R24_BOUNDARY_LOG}"
}

r24_restore_matrix_containment() {
  local r24_restored_sha=""
  local r24_restore_mode=""
  [[ "${R24_MATRIX_MUTATED}" == "true" ]] || return 0
  [[ "${R24_MATRIX_BACKUP_OWNED}" == "true" ]] || return 90
  [[ -n "${R24_MATRIX_BACKUP_PATH}" && -f "${R24_MATRIX_BACKUP_PATH}" && ! -L "${R24_MATRIX_BACKUP_PATH}" ]] || return 91
  [[ -n "${R24_MATRIX_RESTORE_STAGE}" ]] || return 92
  if [[ "${R24_MATRIX_RESTORE_STAGE_OWNED}" == "true" ]]; then
    r24_remove_exact_matrix_stage "${R24_MATRIX_RESTORE_STAGE}" || return 93
  fi
  r24_exclusive_create_empty "${R24_MATRIX_RESTORE_STAGE}" || return 93
  R24_MATRIX_RESTORE_STAGE_OWNED="true"
  /bin/cp -p "${R24_MATRIX_BACKUP_PATH}" "${R24_MATRIX_RESTORE_STAGE}" || return 94
  [[ -f "${R24_MATRIX_RESTORE_STAGE}" && ! -L "${R24_MATRIX_RESTORE_STAGE}" ]] || return 95
  r24_restored_sha="$(r24_sha "${R24_MATRIX_RESTORE_STAGE}")" || return 96
  [[ "${r24_restored_sha}" == "${R24_EXPECTED_MATRIX_ENTRY_SHA}" ]] || return 97
  r24_restore_mode="$(/usr/bin/stat -f '%Lp' "${R24_MATRIX_RESTORE_STAGE}")" || return 98
  [[ "${r24_restore_mode}" == "755" ]] || return 99
  /bin/mv -f "${R24_MATRIX_RESTORE_STAGE}" "${R24_MATRIX_SCRIPT}" || return 100
  R24_MATRIX_RESTORE_STAGE_OWNED="false"
  [[ -f "${R24_MATRIX_SCRIPT}" && ! -L "${R24_MATRIX_SCRIPT}" ]] || return 101
  r24_restored_sha="$(r24_sha "${R24_MATRIX_SCRIPT}")" || return 102
  [[ "${r24_restored_sha}" == "${R24_EXPECTED_MATRIX_ENTRY_SHA}" ]] || return 103
  r24_restore_mode="$(/usr/bin/stat -f '%Lp' "${R24_MATRIX_SCRIPT}")" || return 104
  [[ "${r24_restore_mode}" == "755" ]] || return 105
  R24_MATRIX_MUTATED="false"
  [[ "${R24_MATRIX_BACKUP_OWNED}" == "true" ]] || return 106
  /bin/rm -f "${R24_MATRIX_BACKUP_PATH}" || return 106
  [[ ! -e "${R24_MATRIX_BACKUP_PATH}" && ! -L "${R24_MATRIX_BACKUP_PATH}" ]] || return 107
  R24_MATRIX_BACKUP_OWNED="false"
  return 0
}

r24_remove_exact_matrix_stage() {
  local r24_stage="$1"
  local r24_kind=""
  [[ -n "${r24_stage}" ]] || return 0
  case "${r24_stage}" in
    "${R24_REPOSITORY_ROOT}/scripts/.${R24_INVOCATION_ID}.matrix-mutated.stage")
      r24_kind="mutated"
      [[ "${R24_MATRIX_MUTATED_STAGE_OWNED}" == "true" ]] || return 0
      ;;
    "${R24_REPOSITORY_ROOT}/scripts/.${R24_INVOCATION_ID}.matrix-restore.stage")
      r24_kind="restore"
      [[ "${R24_MATRIX_RESTORE_STAGE_OWNED}" == "true" ]] || return 0
      ;;
    *) return 111 ;;
  esac
  if [[ -e "${r24_stage}" || -L "${r24_stage}" ]]; then
    [[ -f "${r24_stage}" && ! -L "${r24_stage}" ]] || return 112
    /bin/rm -f "${r24_stage}" || return 113
  fi
  [[ ! -e "${r24_stage}" && ! -L "${r24_stage}" ]] || return 114
  if [[ "${r24_kind}" == "mutated" ]]; then
    R24_MATRIX_MUTATED_STAGE_OWNED="false"
  else
    R24_MATRIX_RESTORE_STAGE_OWNED="false"
  fi
}

r24_contain_matrix_owned_paths() {
  local r24_live_sha=""
  r24_remove_exact_matrix_stage "${R24_MATRIX_MUTATED_STAGE}" || return "$?"
  r24_remove_exact_matrix_stage "${R24_MATRIX_RESTORE_STAGE}" || return "$?"
  if [[ "${R24_MATRIX_BACKUP_OWNED}" == "true" ]]; then
    [[ "${R24_MATRIX_BACKUP_PATH}" == "${R24_STATE_ROOT}/r24-matrix-entry.backup" ]] || return 115
    if [[ -e "${R24_MATRIX_BACKUP_PATH}" || -L "${R24_MATRIX_BACKUP_PATH}" ]]; then
      [[ -f "${R24_MATRIX_BACKUP_PATH}" && ! -L "${R24_MATRIX_BACKUP_PATH}" ]] || return 116
    fi
    r24_live_sha="$(r24_sha "${R24_MATRIX_SCRIPT}")" || return 117
    if [[ "${r24_live_sha}" == "${R24_EXPECTED_MATRIX_ENTRY_SHA}" ]]; then
      if [[ -e "${R24_MATRIX_BACKUP_PATH}" || -L "${R24_MATRIX_BACKUP_PATH}" ]]; then
        /bin/rm -f "${R24_MATRIX_BACKUP_PATH}" || return 118
      fi
      [[ ! -e "${R24_MATRIX_BACKUP_PATH}" && ! -L "${R24_MATRIX_BACKUP_PATH}" ]] || return 119
      R24_MATRIX_BACKUP_OWNED="false"
    fi
  fi
  return 0
}

r24_contain_screenshot_stage() {
  [[ -n "${R24_SCREENSHOT_STAGE}" ]] || return 0
  [[ "${R24_SCREENSHOT_STAGE_OWNED}" == "true" ]] || return 0
  [[ "${R24_SCREENSHOT_STAGE}" == "${R24_TASK_DIRECTORY}/evidence/.${R24_INVOCATION_ID}.r24-preview-smoke.stage.png" ]] || return 120
  if [[ -e "${R24_SCREENSHOT_STAGE}" || -L "${R24_SCREENSHOT_STAGE}" ]]; then
    [[ -f "${R24_SCREENSHOT_STAGE}" && ! -L "${R24_SCREENSHOT_STAGE}" ]] || return 121
    /bin/rm -f "${R24_SCREENSHOT_STAGE}" || return 122
  fi
  [[ ! -e "${R24_SCREENSHOT_STAGE}" && ! -L "${R24_SCREENSHOT_STAGE}" ]] || return 123
  R24_SCREENSHOT_STAGE_OWNED="false"
  return 0
}

# Reset identity only after the direct child has been reaped.
r24_clear_owned_preview_identity() {
  R24_APP_PID=""
  R24_APP_PPID=""
  R24_APP_BIRTH=""
  R24_APP_DIRECT_CHILD_OWNED="false"
  R24_APP_IDENTITY_COMMITTED="false"
}

# Count the exact PID in one numeric Bash job-list snapshot.
r24_job_list_exact_pid_count() {
  local r24_list="$1"
  local r24_line=""
  local r24_count=0
  while IFS= read -r r24_line; do
    [[ -n "${r24_line}" ]] || continue
    case "${r24_line}" in *[!0-9]*) return 2 ;; esac
    if [[ "${r24_line}" == "${R24_APP_PID}" ]]; then
      r24_count=$((r24_count + 1))
    fi
  done <<< "${r24_list}"
  [[ "${r24_count}" -le 1 ]] || return 2
  /usr/bin/printf '%s\n' "${r24_count}"
}

# Return 0 only after two stable snapshots place the exact PID in precisely
# one Bash running/stopped set, 1 only after two stable snapshots place it in
# neither set, and 2 for transition/indeterminate output.  Done/Exit jobs are
# deliberately excluded by -r/-s before cached wait is consumed.
r24_preview_active_job_exact() {
  local r24_running=""
  local r24_stopped=""
  local r24_running_count=""
  local r24_stopped_count=""
  local r24_state=""
  local r24_previous_state=""
  local r24_index=0
  while (( r24_index < 20 )); do
    if r24_running="$(jobs -pr)" && r24_stopped="$(jobs -ps)"; then :; else return 2; fi
    if r24_running_count="$(r24_job_list_exact_pid_count "${r24_running}")"; then :; else return 2; fi
    if r24_stopped_count="$(r24_job_list_exact_pid_count "${r24_stopped}")"; then :; else return 2; fi
    case "${r24_running_count}:${r24_stopped_count}" in
      1:0) r24_state="RUNNING" ;;
      0:1) r24_state="STOPPED" ;;
      0:0) r24_state="ABSENT" ;;
      *) r24_state="TRANSITION" ;;
    esac
    if [[ "${r24_state}" != "TRANSITION" && "${r24_state}" == "${r24_previous_state}" ]]; then
      [[ "${r24_state}" == "ABSENT" ]] && return 1
      return 0
    fi
    r24_previous_state="${r24_state}"
    /bin/sleep 0.01
    r24_index=$((r24_index + 1))
  done
  return 2
}

# Consume Bash's cached status only after stable running/stopped snapshots
# prove the child is no longer active. No kill -0 probe is used because an OS
# PID may already have been reused after Bash reaps the child.
r24_wait_cached_preview_child() {
  local r24_job_rc=0
  local r24_wait_rc=0
  [[ "${R24_APP_DIRECT_CHILD_OWNED}" == "true" ]] || return 126
  if r24_preview_active_job_exact; then
    return 1
  else
    r24_job_rc="$?"
  fi
  [[ "${r24_job_rc}" == "1" ]] || return 128
  if wait "${R24_APP_PID}" 2>/dev/null; then
    r24_wait_rc=0
  else
    r24_wait_rc="$?"
  fi
  R24_PREVIEW_CONTAINMENT_WAIT_RC="${r24_wait_rc}"
  r24_clear_owned_preview_identity
  [[ "${r24_wait_rc}" != "127" ]] || return 127
  return 0
}

# Refresh the job-table, PPID, and (once committed) birth token immediately
# before each signal.  Command identity remains diagnostic because a direct
# launch may still be in its fork-to-exec window.
r24_authorize_preview_signal() {
  local r24_job_rc=0
  local r24_command=""
  local r24_birth=""
  local r24_ppid=""
  R24_PREVIEW_CONTAINMENT_COMMAND_MATCH="READ_FAILED"
  R24_PREVIEW_CONTAINMENT_PPID_MATCH="READ_FAILED"
  R24_PREVIEW_CONTAINMENT_BIRTH_MATCH="READ_FAILED"
  if r24_preview_active_job_exact; then
    :
  else
    r24_job_rc="$?"
    return $((130 + r24_job_rc))
  fi
  if r24_ppid="$(/bin/ps -p "${R24_APP_PID}" -o ppid= 2>/dev/null)"; then :; else return 133; fi
  r24_ppid="${r24_ppid// /}"
  r24_ppid="${r24_ppid//$'\t'/}"
  if [[ "${r24_ppid}" == "$$" ]]; then
    R24_PREVIEW_CONTAINMENT_PPID_MATCH="true"
  else
    R24_PREVIEW_CONTAINMENT_PPID_MATCH="false_${r24_ppid}"
    return 134
  fi
  if r24_command="$(/bin/ps -ww -p "${R24_APP_PID}" -o command= 2>/dev/null)"; then
    if [[ "${r24_command}" == "${R24_APP_EXECUTABLE}" ]]; then
      R24_PREVIEW_CONTAINMENT_COMMAND_MATCH="true"
    else
      R24_PREVIEW_CONTAINMENT_COMMAND_MATCH="false_preexec_or_drift"
    fi
  fi
  if [[ "${R24_APP_IDENTITY_COMMITTED}" == "true" ]]; then
    [[ -n "${R24_APP_BIRTH}" ]] || return 135
    if r24_birth="$(/bin/ps -p "${R24_APP_PID}" -o lstart= 2>/dev/null)"; then :; else return 136; fi
    if [[ "${r24_birth}" == "${R24_APP_BIRTH}" ]]; then
      R24_PREVIEW_CONTAINMENT_BIRTH_MATCH="true"
    else
      R24_PREVIEW_CONTAINMENT_BIRTH_MATCH="false"
      return 137
    fi
  else
    R24_PREVIEW_CONTAINMENT_BIRTH_MATCH="not_committed"
  fi
  R24_PREVIEW_CONTAINMENT_AUTH_RC="0"
  return 0
}

r24_contain_preview_process() {
  local r24_job_rc=0
  local r24_authorize_rc=0
  local r24_index=0
  [[ -n "${R24_APP_PID}" ]] || {
    [[ "${R24_APP_DIRECT_CHILD_OWNED}" == "false" ]] || return 120
    return 0
  }
  case "${R24_APP_PID}" in ''|*[!0-9]*) return 121 ;; esac
  [[ "${R24_APP_DIRECT_CHILD_OWNED}" == "true" ]] || return 122

  if r24_preview_active_job_exact; then
    :
  else
    r24_job_rc="$?"
    if [[ "${r24_job_rc}" == "1" ]]; then
      r24_wait_cached_preview_child
      return "$?"
    fi
    return 123
  fi
  if r24_authorize_preview_signal; then
    :
  else
    r24_authorize_rc="$?"
    R24_PREVIEW_CONTAINMENT_AUTH_RC="${r24_authorize_rc}"
    if r24_preview_active_job_exact; then
      return 133
    else
      r24_job_rc="$?"
      if [[ "${r24_job_rc}" == "1" ]]; then
        r24_wait_cached_preview_child
        return "$?"
      fi
      return 124
    fi
  fi
  /bin/kill -TERM "${R24_APP_PID}" 2>/dev/null || {
    if r24_preview_active_job_exact; then
      return 125
    fi
    r24_job_rc="$?"
    if [[ "${r24_job_rc}" == "1" ]]; then
      r24_wait_cached_preview_child
      return "$?"
    fi
    return 126
  }

  while (( r24_index < 100 )); do
    if r24_preview_active_job_exact; then
      /bin/sleep 0.1
      r24_index=$((r24_index + 1))
      continue
    fi
    r24_job_rc="$?"
    if [[ "${r24_job_rc}" == "1" ]]; then
      r24_wait_cached_preview_child
      return "$?"
    fi
    return 127
  done

  # Refresh the full proof again immediately before escalation.  If any
  # identity token is absent or mismatched, do not signal the current PID.
  if r24_authorize_preview_signal; then
    :
  else
    r24_authorize_rc="$?"
    R24_PREVIEW_CONTAINMENT_AUTH_RC="${r24_authorize_rc}"
    if r24_preview_active_job_exact; then
      return 134
    else
      r24_job_rc="$?"
      if [[ "${r24_job_rc}" == "1" ]]; then
        r24_wait_cached_preview_child
        return "$?"
      fi
      return 128
    fi
  fi
  /bin/kill -KILL "${R24_APP_PID}" 2>/dev/null || {
    if r24_preview_active_job_exact; then
      return 129
    fi
    r24_job_rc="$?"
    if [[ "${r24_job_rc}" == "1" ]]; then
      r24_wait_cached_preview_child
      return "$?"
    fi
    return 130
  }
  r24_index=0
  while (( r24_index < 100 )); do
    if r24_preview_active_job_exact; then
      /bin/sleep 0.1
      r24_index=$((r24_index + 1))
      continue
    fi
    r24_job_rc="$?"
    if [[ "${r24_job_rc}" == "1" ]]; then
      r24_wait_cached_preview_child
      return "$?"
    fi
    return 131
  done
  return 132
}

r24_contain_uncommitted_impl_report() {
  local r24_live_sha=""
  [[ "${R24_END_COMMITTED}" == "false" ]] || return 0
  if [[ "${R24_IMPL_REPORT_STAGE_OWNED}" == "true" ]]; then
    [[ -n "${R24_INVOCATION_ID}" ]] || return 140
    [[ "${R24_IMPL_REPORT_STAGE}" == "${R24_TASK_DIRECTORY}/.${R24_INVOCATION_ID}.impl-report-r24.stage.md" ]] || return 141
    if [[ -e "${R24_IMPL_REPORT_STAGE}" || -L "${R24_IMPL_REPORT_STAGE}" ]]; then
      [[ -f "${R24_IMPL_REPORT_STAGE}" && ! -L "${R24_IMPL_REPORT_STAGE}" ]] || return 142
      /bin/rm -f "${R24_IMPL_REPORT_STAGE}" || return 143
    fi
    [[ ! -e "${R24_IMPL_REPORT_STAGE}" && ! -L "${R24_IMPL_REPORT_STAGE}" ]] || return 144
    R24_IMPL_REPORT_STAGE_OWNED="false"
  fi
  if [[ "${R24_IMPL_REPORT_PUBLISHED}" == "true" ]]; then
    [[ -n "${R24_IMPL_REPORT_STAGE_SHA}" ]] || return 145
    [[ -f "${R24_IMPL_REPORT}" && ! -L "${R24_IMPL_REPORT}" ]] || return 146
    if r24_live_sha="$(r24_sha "${R24_IMPL_REPORT}")"; then :; else return 147; fi
    [[ "${r24_live_sha}" == "${R24_IMPL_REPORT_STAGE_SHA}" ]] || return 148
    /bin/rm -f "${R24_IMPL_REPORT}" || return 149
    [[ ! -e "${R24_IMPL_REPORT}" && ! -L "${R24_IMPL_REPORT}" ]] || return 150
    R24_IMPL_REPORT_PUBLISHED="false"
  fi
  return 0
}

r24_active_fail() {
  local r24_status="$1"
  local r24_matrix_restore_rc=0
  local r24_matrix_owned_cleanup_rc=0
  local r24_preview_containment_rc=0
  local r24_screenshot_stage_cleanup_rc=0
  local r24_impl_report_cleanup_rc=0
  local r24_matrix_restore_attempts=0
  local r24_rejected_at=""
  shift
  trap - ERR
  trap '' HUP INT TERM
  set +e
  if [[ "${R24_MATRIX_MUTATED}" == "true" ]]; then
    while (( r24_matrix_restore_attempts < 2 )); do
      r24_matrix_restore_attempts=$((r24_matrix_restore_attempts + 1))
      r24_restore_matrix_containment
      r24_matrix_restore_rc="$?"
      [[ "${r24_matrix_restore_rc}" == "0" ]] && break
    done
  fi
  r24_contain_matrix_owned_paths
  r24_matrix_owned_cleanup_rc="$?"
  r24_contain_preview_process
  r24_preview_containment_rc="$?"
  R24_PREVIEW_CONTAINMENT_RC="${r24_preview_containment_rc}"
  r24_contain_screenshot_stage
  r24_screenshot_stage_cleanup_rc="$?"
  r24_contain_uncommitted_impl_report
  r24_impl_report_cleanup_rc="$?"
  if [[ -f "${R24_BOUNDARY_LOG}" && ! -L "${R24_BOUNDARY_LOG}" ]]; then
    {
      /usr/bin/printf '%s\n' 'status=REJECTED_CONTAMINATED'
      /usr/bin/printf 'phase=%s\n' "${R24_PHASE}"
      /usr/bin/printf 'reason=%s\n' "$*"
      /usr/bin/printf 'exit_code=%s\n' "${r24_status}"
      /usr/bin/printf 'r23_first_mask=%s\n' "${R24_R23_FIRST_MASK:-UNCOMMITTED}"
      /usr/bin/printf 'r23_latest_mask=%s\n' "${R24_R23_LATEST_MASK:-UNCOMMITTED}"
      /usr/bin/printf 'r20_first_mask=%s\n' "${R24_R20_FIRST_MASK:-UNCOMMITTED}"
      /usr/bin/printf 'r20_latest_mask=%s\n' "${R24_R20_LATEST_MASK:-UNCOMMITTED}"
      /usr/bin/printf 'authoritative_status_captured=%s\n' "${R24_AUTHORITATIVE_STATUS_CAPTURED}"
      /usr/bin/printf 'authoritative_swift_rc=%s\n' "${R24_AUTHORITATIVE_SWIFT_RC}"
      /usr/bin/printf 'authoritative_tee_rc=%s\n' "${R24_AUTHORITATIVE_TEE_RC}"
      /usr/bin/printf 'authoritative_verify_log_sha=%s\n' "${R24_VERIFY_LOG_SHA}"
      /usr/bin/printf 'authoritative_verify_log_bytes=%s\n' "${R24_VERIFY_LOG_BYTES}"
      /usr/bin/printf 'matrix_restore_attempt_rc=%s\n' "${r24_matrix_restore_rc}"
      /usr/bin/printf 'matrix_restore_attempt_count=%s\n' "${r24_matrix_restore_attempts}"
      /usr/bin/printf 'matrix_mutated_after_containment=%s\n' "${R24_MATRIX_MUTATED}"
      /usr/bin/printf 'matrix_owned_path_cleanup_rc=%s\n' "${r24_matrix_owned_cleanup_rc}"
      /usr/bin/printf 'preview_exact_pid_containment_rc=%s\n' "${r24_preview_containment_rc}"
      /usr/bin/printf 'preview_exact_pid_containment_wait_rc=%s\n' "${R24_PREVIEW_CONTAINMENT_WAIT_RC}"
      /usr/bin/printf 'preview_direct_child_owned_after_containment=%s\n' "${R24_APP_DIRECT_CHILD_OWNED}"
      /usr/bin/printf 'preview_identity_committed_after_containment=%s\n' "${R24_APP_IDENTITY_COMMITTED}"
      /usr/bin/printf 'preview_containment_command_match=%s\n' "${R24_PREVIEW_CONTAINMENT_COMMAND_MATCH}"
      /usr/bin/printf 'preview_containment_ppid_match=%s\n' "${R24_PREVIEW_CONTAINMENT_PPID_MATCH}"
      /usr/bin/printf 'preview_containment_birth_match=%s\n' "${R24_PREVIEW_CONTAINMENT_BIRTH_MATCH}"
      /usr/bin/printf 'preview_containment_authorization_rc=%s\n' "${R24_PREVIEW_CONTAINMENT_AUTH_RC}"
      /usr/bin/printf 'preview_screenshot_stage_cleanup_rc=%s\n' "${r24_screenshot_stage_cleanup_rc}"
      /usr/bin/printf 'impl_report_uncommitted_cleanup_rc=%s\n' "${r24_impl_report_cleanup_rc}"
      /usr/bin/printf 'terminal_end_committed=%s\n' "${R24_END_COMMITTED}"
      /usr/bin/printf 'preview_raw_path=%s\n' "${R24_CU_RAW_PATH:-UNSET}"
      /usr/bin/printf '%s\n' 'preview_raw_if_present_retained_as_isolated_contaminated_evidence=true'
      /usr/bin/printf '%s\n' 'authorization_consumed=true'
      /usr/bin/printf '%s\n' 'retry_same_boundary=false'
      if r24_rejected_at="$(r24_capture_now)"; then :; else r24_rejected_at="TIMESTAMP_CAPTURE_FAILED"; fi
      /usr/bin/printf 'utc_rejected=%s\n' "${r24_rejected_at}"
    } >> "${R24_BOUNDARY_LOG}"
  fi
  /usr/bin/printf 'R24 active failure: %s\n' "$*" >&2
  exit "${r24_status}"
}

r24_err_trap() {
  local r24_status="$?"
  local r24_command="${BASH_COMMAND:-UNKNOWN}"
  if [[ "${R24_BOUNDARY_ACTIVE}" == "true" ]]; then
    r24_active_fail "${r24_status}" "unexpected_command_failure_${r24_command}"
  fi
  r24_pre_begin_fail "${r24_status}" "unexpected_command_failure_${r24_command}"
}

r24_signal_trap() {
  local r24_name="$1"
  local r24_status="$2"
  if [[ "${R24_BOUNDARY_ACTIVE}" == "true" ]]; then
    r24_active_fail "${r24_status}" "signal_${r24_name}"
  fi
  r24_pre_begin_fail "${r24_status}" "signal_${r24_name}"
}

r24_defer_signal() {
  if [[ -z "${R24_DEFERRED_SIGNAL}" ]]; then
    R24_DEFERRED_SIGNAL="$1"
    R24_DEFERRED_SIGNAL_STATUS="$2"
  fi
}

r24_install_signal_traps() {
  trap 'r24_signal_trap HUP 129' HUP
  trap 'r24_signal_trap INT 130' INT
  trap 'r24_signal_trap TERM 143' TERM
}

r24_begin_preview_launch_identity_window() {
  [[ -z "${R24_APP_PID}" ]] || r24_active_fail 70 "launch_window_pid_already_set"
  [[ "${R24_APP_DIRECT_CHILD_OWNED}" == "false" ]] || r24_active_fail 70 "launch_window_child_already_owned"
  [[ "${R24_APP_IDENTITY_COMMITTED}" == "false" ]] || r24_active_fail 70 "launch_window_identity_already_committed"
  R24_DEFERRED_SIGNAL=""
  R24_DEFERRED_SIGNAL_STATUS=""
  R24_PREVIEW_CONTAINMENT_WAIT_RC="NOT_WAITED"
  R24_PREVIEW_CONTAINMENT_COMMAND_MATCH="NOT_OBSERVED"
  R24_PREVIEW_CONTAINMENT_PPID_MATCH="NOT_OBSERVED"
  R24_PREVIEW_CONTAINMENT_BIRTH_MATCH="NOT_OBSERVED"
  R24_PREVIEW_CONTAINMENT_AUTH_RC="NOT_ATTEMPTED"
  trap 'r24_defer_signal HUP 129' HUP
  trap 'r24_defer_signal INT 130' INT
  trap 'r24_defer_signal TERM 143' TERM
}

r24_capture_preview_launch_identity() {
  local r24_job_rc=0
  local r24_index=0
  local r24_birth=""
  local r24_ppid=""
  while (( r24_index < 50 )); do
    if r24_preview_active_job_exact; then
      if r24_ppid="$(/bin/ps -p "${R24_APP_PID}" -o ppid= 2>/dev/null)" && \
         r24_birth="$(/bin/ps -p "${R24_APP_PID}" -o lstart= 2>/dev/null)"; then
        r24_ppid="${r24_ppid// /}"
        r24_ppid="${r24_ppid//$'\t'/}"
        if [[ "${r24_ppid}" == "$$" && -n "${r24_birth}" && "${r24_birth}" != *$'\n'* ]]; then
          R24_APP_PPID="${r24_ppid}"
          R24_APP_BIRTH="${r24_birth}"
          return 0
        fi
      fi
    else
      r24_job_rc="$?"
      if [[ "${r24_job_rc}" == "1" ]]; then
        r24_wait_cached_preview_child || :
        return 71
      fi
      return 72
    fi
    /bin/sleep 0.02
    r24_index=$((r24_index + 1))
  done
  return 73
}

r24_commit_preview_launch_identity_window() {
  local r24_label="$1"
  [[ "${R24_APP_DIRECT_CHILD_OWNED}" == "true" ]] || r24_active_fail 70 "launch_identity_not_owned_${r24_label}"
  case "${R24_APP_PID}" in ''|*[!0-9]*) r24_active_fail 70 "launch_identity_pid_invalid_${r24_label}" ;; esac
  [[ -n "${R24_APP_BIRTH}" && "${R24_APP_BIRTH}" != *$'\n'* ]] || r24_active_fail 70 "launch_identity_birth_invalid_${r24_label}"
  [[ "${R24_APP_PPID}" == "$$" ]] || r24_active_fail 70 "launch_identity_ppid_invalid_${r24_label}_${R24_APP_PPID}"
  R24_APP_IDENTITY_COMMITTED="true"
  r24_install_signal_traps
  if [[ -n "${R24_DEFERRED_SIGNAL}" ]]; then
    r24_active_fail "${R24_DEFERRED_SIGNAL_STATUS}" "deferred_signal_${R24_DEFERRED_SIGNAL}_launch_identity_${r24_label}"
  fi
}

trap 'r24_err_trap' ERR
r24_install_signal_traps

r24_fail() {
  local r24_status="$1"
  shift
  if [[ "${R24_BOUNDARY_ACTIVE}" == "true" ]]; then
    r24_active_fail "${r24_status}" "$*"
  fi
  r24_pre_begin_fail "${r24_status}" "$*"
}

r24_require_regular_file() {
  local r24_path="$1"
  [[ -f "${r24_path}" && ! -L "${r24_path}" ]] || r24_fail 70 "not_regular_non_symlink_${r24_path}"
}

r24_require_absent_path() {
  local r24_path="$1"
  [[ ! -e "${r24_path}" && ! -L "${r24_path}" ]] || r24_fail 70 "expected_absent_${r24_path}"
}

r24_require_sha() {
  local r24_expected="$1"
  local r24_path="$2"
  local r24_actual=""
  r24_require_regular_file "${r24_path}"
  if r24_actual="$(r24_sha "${r24_path}")"; then
    :
  else
    r24_fail 70 "sha_read_failed_${r24_path}"
  fi
  [[ "${r24_actual}" == "${r24_expected}" ]] || r24_fail 70 "sha_mismatch_${r24_path}"
}

r24_exact_line_count() {
  local r24_path="$1"
  local r24_line="$2"
  /usr/bin/awk -v expected="${r24_line}" '$0 == expected { count += 1 } END { print count + 0 }' "${r24_path}"
}

r24_require_exact_line_once() {
  local r24_path="$1"
  local r24_line="$2"
  local r24_count=""
  if r24_count="$(r24_exact_line_count "${r24_path}" "${r24_line}")"; then
    :
  else
    r24_fail 70 "line_count_failed_${r24_path}"
  fi
  [[ "${r24_count}" == "1" ]] || r24_fail 70 "line_not_unique_${r24_path}_${r24_line}"
}

r24_machine_value() {
  local r24_key="$1"
  /usr/bin/awk -v key="${r24_key}" '
    $0 == "R24_MACHINE_BLOCK_BEGIN" { inside = 1; next }
    $0 == "R24_MACHINE_BLOCK_END" { inside = 0; next }
    inside && index($0, key "=") == 1 { print substr($0, length(key) + 2) }
  ' "${R24_REVIEW24_PATH}"
}

r24_require_review24() {
  local r24_argument_sha="$1"
  local r24_actual_review_sha=""
  local r24_field_count=""
  local r24_key=""
  local r24_expected=""
  local r24_actual=""
  local r24_verdict_count=""
  local r24_freeze_sha=""
  local r24_driver_sha=""
  local r24_manifest_sha=""

  r24_require_regular_file "${R24_REVIEW24_PATH}"
  if r24_actual_review_sha="$(r24_sha "${R24_REVIEW24_PATH}")"; then
    :
  else
    r24_fail 70 "review24_sha_read_failed"
  fi
  [[ "${r24_actual_review_sha}" == "${r24_argument_sha}" ]] || r24_fail 70 "review24_argument_sha_mismatch"
  r24_require_exact_line_once "${R24_REVIEW24_PATH}" 'Verdict: APPROVED — 0 P0 / 0 P1'
  if r24_verdict_count="$(/usr/bin/awk '/^Verdict:/ { count += 1 } END { print count + 0 }' "${R24_REVIEW24_PATH}")"; then :; else r24_fail 70 "review24_verdict_count_read_failed"; fi
  [[ "${r24_verdict_count}" == "1" ]] || r24_fail 70 "review24_verdict_count_${r24_verdict_count}"
  r24_require_exact_line_once "${R24_REVIEW24_PATH}" 'R24_MACHINE_BLOCK_BEGIN'
  r24_require_exact_line_once "${R24_REVIEW24_PATH}" 'R24_MACHINE_BLOCK_END'
  if r24_field_count="$(/usr/bin/awk '
      $0 == "R24_MACHINE_BLOCK_BEGIN" { inside = 1; next }
      $0 == "R24_MACHINE_BLOCK_END" { inside = 0; next }
      inside { count += 1 }
      END { print count + 0 }
    ' "${R24_REVIEW24_PATH}")"; then
    :
  else
    r24_fail 70 "review24_field_count_failed"
  fi
  [[ "${r24_field_count}" == "12" ]] || r24_fail 70 "review24_field_count_${r24_field_count}"
  if r24_freeze_sha="$(r24_sha "${R24_FREEZE_PATH}")"; then :; else r24_fail 70 "review24_freeze_sha_read_failed"; fi
  if r24_driver_sha="$(r24_sha "${R24_DRIVER_PATH}")"; then :; else r24_fail 70 "review24_driver_sha_read_failed"; fi
  if r24_manifest_sha="$(r24_sha "${R24_MANIFEST_PATH}")"; then :; else r24_fail 70 "review24_manifest_sha_read_failed"; fi

  for r24_key in \
    authority_mode standing_goal_authority_verified reviewer_independence_attested \
    reviewer_write_scope user_hash_echo_required review_verdict freeze_sha driver_sha \
    manifest_sha branch head manifest_count; do
    if r24_actual="$(r24_machine_value "${r24_key}")"; then
      :
    else
      r24_fail 70 "review24_field_read_failed_${r24_key}"
    fi
    [[ -n "${r24_actual}" && "${r24_actual}" != *$'\n'* ]] || r24_fail 70 "review24_field_not_unique_${r24_key}"
    case "${r24_key}" in
      authority_mode) r24_expected='standing_goal_automatic_after_review24' ;;
      standing_goal_authority_verified) r24_expected='true' ;;
      reviewer_independence_attested) r24_expected='true' ;;
      reviewer_write_scope) r24_expected='review24_only' ;;
      user_hash_echo_required) r24_expected='false' ;;
      review_verdict) r24_expected='APPROVED_0_P0_0_P1' ;;
      freeze_sha) r24_expected="${r24_freeze_sha}" ;;
      driver_sha) r24_expected="${r24_driver_sha}" ;;
      manifest_sha) r24_expected="${r24_manifest_sha}" ;;
      branch) r24_expected="${R24_EXPECTED_BRANCH}" ;;
      head) r24_expected="${R24_EXPECTED_HEAD}" ;;
      manifest_count) r24_expected="${R24_EXPECTED_MANIFEST_COUNT}" ;;
      *) r24_fail 70 "review24_unknown_field_${r24_key}" ;;
    esac
    [[ "${r24_actual}" == "${r24_expected}" ]] || r24_fail 70 "review24_field_mismatch_${r24_key}"
  done
}

r24_require_manifest() {
  local r24_count=""
  local r24_shape=""
  local r24_status=""
  local r24_expected=""
  local r24_path=""
  local r24_membership_count=""
  local r24_old_path=""
  local r24_addition=""
  local r24_excluded=""
  local r24_old_count=0
  local r24_addition_count=0

  R24_MANIFEST_ADDITIONS=(
    "${R24_DRIVER_PATH}"
    "${R24_R23_MANIFEST_PATH}"
    "${R24_R23_FREEZE_PATH}"
    "${R24_R23_REVIEW_PATH}"
    "${R24_R23_BOUNDARY_PATH}"
    "${R24_R23_HASH_LOG_PATH}"
    "${R24_R23_VERIFY_PATH}"
    "${R24_TASK_DIRECTORY}/r23-targeted-tests.log"
    "${R24_TASK_DIRECTORY}/r23-build.log"
    "${R24_TASK_DIRECTORY}/r23-migration-matrix.log"
    "${R24_TASK_DIRECTORY}/evidence/r23-bundle-provenance.log"
    "${R24_TASK_DIRECTORY}/evidence/r23-source-gates.log"
    "${R24_TASK_DIRECTORY}/evidence/r23-preview-bootstrap.log"
    "${R24_TASK_DIRECTORY}/evidence/r23-preview-cold-start.log"
    "${R24_R23_REPORT_PATH}"
  )
  R24_MANIFEST_EXCLUSIONS=(
    "${R24_MANIFEST_PATH}"
    "${R24_FREEZE_PATH}"
    "${R24_REVIEW24_PATH}"
    "${R24_TARGETED_LOG}"
    "${R24_VERIFY_LOG}"
    "${R24_BUILD_LOG}"
    "${R24_MATRIX_LOG}"
    "${R24_TASK_DIRECTORY}/impl-report-r24.md"
    "${R24_BOUNDARY_LOG}"
    "${R24_BUNDLE_LOG}"
    "${R24_SOURCE_LOG}"
    "${R24_HASH_LOG}"
    "${R24_BOOTSTRAP_LOG}"
    "${R24_COLD_START_LOG}"
    "${R24_SCREENSHOT}"
  )

  r24_require_sha "${R24_EXPECTED_R23_MANIFEST_SHA}" "${R24_R23_MANIFEST_PATH}"
  r24_require_regular_file "${R24_MANIFEST_PATH}"
  if r24_count="$(/usr/bin/awk 'END { print NR + 0 }' "${R24_MANIFEST_PATH}")"; then
    :
  else
    r24_fail 70 "manifest_count_read_failed"
  fi
  [[ "${r24_count}" == "${R24_EXPECTED_MANIFEST_COUNT}" ]] || r24_fail 70 "manifest_count_${r24_count}"
  if r24_shape="$(/usr/bin/awk -v root="${R24_REPOSITORY_ROOT}/" '
      BEGIN { ok = 1; previous = "" }
      {
        if ($0 !~ /^[0-9a-f]{64}  \/Users\/muzi\/Agent-loop\//) ok = 0
        path = substr($0, 67)
        if (path <= previous) ok = 0
        previous = path
      }
      END { print ok }
    ' "${R24_MANIFEST_PATH}")"; then
    :
  else
    r24_fail 70 "manifest_shape_read_failed"
  fi
  [[ "${r24_shape}" == "1" ]] || r24_fail 70 "manifest_shape_invalid"

  while IFS= read -r r24_status; do
    r24_expected="${r24_status%%  *}"
    r24_path="${r24_status#*  }"
    [[ "${r24_expected}" != "${r24_status}" ]] || r24_fail 70 "manifest_record_parse_failed"
    r24_require_regular_file "${r24_path}"
  done < "${R24_MANIFEST_PATH}"

  while IFS= read -r r24_status; do
    r24_old_path="${r24_status#*  }"
    [[ "${r24_old_path}" != "${r24_status}" ]] || r24_fail 70 "r23_manifest_path_parse_failed"
    if r24_membership_count="$(/usr/bin/awk -v expected="${r24_old_path}" 'substr($0, 67) == expected { count += 1 } END { print count + 0 }' "${R24_MANIFEST_PATH}")"; then
      :
    else
      r24_fail 70 "r23_path_membership_read_failed_${r24_old_path}"
    fi
    [[ "${r24_membership_count}" == "1" ]] || r24_fail 70 "r23_path_not_in_r24_manifest_${r24_old_path}"
    r24_old_count=$((r24_old_count + 1))
  done < "${R24_R23_MANIFEST_PATH}"
  [[ "${r24_old_count}" == "163" ]] || r24_fail 70 "r23_path_set_count_${r24_old_count}"

  for r24_addition in "${R24_MANIFEST_ADDITIONS[@]}"; do
    if r24_membership_count="$(/usr/bin/awk -v expected="${r24_addition}" 'substr($0, 67) == expected { count += 1 } END { print count + 0 }' "${R24_R23_MANIFEST_PATH}")"; then :; else r24_fail 70 "addition_old_membership_read_failed_${r24_addition}"; fi
    [[ "${r24_membership_count}" == "0" ]] || r24_fail 70 "addition_overlaps_r23_set_${r24_addition}"
    if r24_membership_count="$(/usr/bin/awk -v expected="${r24_addition}" 'substr($0, 67) == expected { count += 1 } END { print count + 0 }' "${R24_MANIFEST_PATH}")"; then :; else r24_fail 70 "addition_membership_read_failed_${r24_addition}"; fi
    [[ "${r24_membership_count}" == "1" ]] || r24_fail 70 "addition_not_exactly_once_${r24_addition}"
    r24_addition_count=$((r24_addition_count + 1))
  done
  [[ "${r24_addition_count}" == "15" ]] || r24_fail 70 "addition_count_${r24_addition_count}"

  for r24_excluded in "${R24_MANIFEST_EXCLUSIONS[@]}"; do
    if r24_membership_count="$(/usr/bin/awk -v expected="${r24_excluded}" 'substr($0, 67) == expected { count += 1 } END { print count + 0 }' "${R24_MANIFEST_PATH}")"; then :; else r24_fail 70 "exclusion_membership_read_failed_${r24_excluded}"; fi
    [[ "${r24_membership_count}" == "0" ]] || r24_fail 70 "excluded_path_present_${r24_excluded}"
  done

  if /usr/bin/shasum -a 256 --strict -c "${R24_MANIFEST_PATH}" >/dev/null 2>&1; then
    :
  else
    r24_fail 70 "manifest_strict_check_failed"
  fi
}

r24_require_r23_predecessor() {
  local r24_path=""
  local r24_empty_path=""
  local r24_old_expected=""
  local r24_old_path=""
  local r24_old_actual=""
  local r24_old_pass=0
  local r24_old_mismatch=0
  local r24_expected_mismatch="false"

  r24_require_sha "${R24_EXPECTED_R23_FREEZE_SHA}" "${R24_R23_FREEZE_PATH}"
  r24_require_sha "${R24_EXPECTED_R23_REVIEW_SHA}" "${R24_R23_REVIEW_PATH}"
  r24_require_sha "${R24_EXPECTED_R23_DRIVER_SHA}" "${R24_R23_DRIVER_PATH}"
  r24_require_sha "${R24_EXPECTED_R23_MANIFEST_SHA}" "${R24_R23_MANIFEST_PATH}"
  r24_require_sha "${R24_EXPECTED_R23_REPORT_SHA}" "${R24_R23_REPORT_PATH}"
  r24_require_sha "${R24_EXPECTED_R23_BOUNDARY_SHA}" "${R24_R23_BOUNDARY_PATH}"
  r24_require_sha "${R24_EXPECTED_R23_HASH_LOG_SHA}" "${R24_R23_HASH_LOG_PATH}"
  r24_require_sha "${R24_EXPECTED_R23_VERIFY_SHA}" "${R24_R23_VERIFY_PATH}"

  R24_R23_EMPTY_RUNTIME_PATHS=(
    "${R24_TASK_DIRECTORY}/r23-targeted-tests.log"
    "${R24_TASK_DIRECTORY}/r23-build.log"
    "${R24_TASK_DIRECTORY}/r23-migration-matrix.log"
    "${R24_TASK_DIRECTORY}/evidence/r23-bundle-provenance.log"
    "${R24_TASK_DIRECTORY}/evidence/r23-source-gates.log"
    "${R24_TASK_DIRECTORY}/evidence/r23-preview-bootstrap.log"
    "${R24_TASK_DIRECTORY}/evidence/r23-preview-cold-start.log"
  )
  for r24_empty_path in "${R24_R23_EMPTY_RUNTIME_PATHS[@]}"; do
    r24_require_sha "${R24_EXPECTED_EMPTY_SHA}" "${r24_empty_path}"
  done
  r24_require_absent_path "${R24_R23_SCREENSHOT_PATH}"

  r24_require_exact_line_once "${R24_R23_REVIEW_PATH}" 'Verdict: APPROVED — 0 P0 / 0 P1'
  r24_require_exact_line_once "${R24_R23_BOUNDARY_PATH}" 'status=REJECTED_CONTAMINATED'
  r24_require_exact_line_once "${R24_R23_BOUNDARY_PATH}" 'phase=authoritative_full_test_status_capture'
  r24_require_exact_line_once "${R24_R23_BOUNDARY_PATH}" 'reason=outer_shell_zsh_PIPESTATUS_unset_after_terminal_652_of_652_log'
  r24_require_exact_line_once "${R24_R23_BOUNDARY_PATH}" 'authoritative_pipeline_status=UNKNOWN_NOT_CAPTURED'
  r24_require_exact_line_once "${R24_R23_BOUNDARY_PATH}" 'authoritative_swift_rc=UNKNOWN_NOT_CAPTURED'
  r24_require_exact_line_once "${R24_R23_BOUNDARY_PATH}" 'authoritative_tee_rc=UNKNOWN_NOT_CAPTURED'
  r24_require_exact_line_once "${R24_R23_BOUNDARY_PATH}" 'full_test_rerun_forbidden=true'
  r24_require_exact_line_once "${R24_R23_BOUNDARY_PATH}" 'subsequent_gates_run=false'
  r24_require_exact_line_once "${R24_R23_VERIFY_PATH}" '✔ Test run with 652 tests in 7 suites passed after 41.900 seconds.'
  r24_require_absent_path "${R24_R23_PLANNED_APP}"
  r24_require_absent_path "${R24_R23_PLANNED_EXECUTABLE}"

  while IFS= read -r r24_path; do
    r24_require_regular_file "${r24_path}"
  done <<EOF
${R24_R23_BOUNDARY_PATH}
${R24_R23_HASH_LOG_PATH}
${R24_R23_VERIFY_PATH}
${R24_R23_REPORT_PATH}
EOF

  while IFS= read -r r24_path; do
    r24_old_expected="${r24_path%%  *}"
    r24_old_path="${r24_path#*  }"
    if r24_old_actual="$(r24_sha "${r24_old_path}")"; then
      :
    else
      r24_fail 70 "r23_manifest_actual_sha_failed_${r24_old_path}"
    fi
    r24_expected_mismatch="false"
    case "${r24_old_path}" in
      "${R24_TEST_PATH}"|\
      "${R24_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md"|\
      "${R24_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md"|\
      "${R24_TASK_DIRECTORY}/plan.md"|\
      "${R24_TASK_DIRECTORY}/blocked.md"|\
      "${R24_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/stage-spec.md"|\
      "${R24_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/plan.md")
        r24_expected_mismatch="true"
        ;;
    esac
    if [[ "${r24_expected_mismatch}" == "true" ]]; then
      [[ "${r24_old_actual}" != "${r24_old_expected}" ]] || r24_fail 70 "r23_manifest_expected_mismatch_missing_${r24_old_path}"
      r24_old_mismatch=$((r24_old_mismatch + 1))
    else
      [[ "${r24_old_actual}" == "${r24_old_expected}" ]] || r24_fail 70 "r23_manifest_unexpected_mismatch_${r24_old_path}"
      r24_old_pass=$((r24_old_pass + 1))
    fi
  done < "${R24_R23_MANIFEST_PATH}"
  [[ "${r24_old_pass}" == "156" && "${r24_old_mismatch}" == "7" ]] || r24_fail 70 "r23_manifest_partition_${r24_old_pass}_${r24_old_mismatch}"
}

r24_require_implementation_baseline() {
  r24_require_sha "${R24_EXPECTED_CORE_SHA}" "${R24_CORE_PATH}"
  r24_require_sha "${R24_EXPECTED_TEST_SHA}" "${R24_TEST_PATH}"
}

r24_require_branch_and_head() {
  local r24_branch=""
  local r24_head=""
  if r24_branch="$(/usr/bin/git -C "${R24_REPOSITORY_ROOT}" branch --show-current)"; then
    :
  else
    r24_fail 70 "branch_read_failed"
  fi
  if r24_head="$(/usr/bin/git -C "${R24_REPOSITORY_ROOT}" rev-parse HEAD)"; then
    :
  else
    r24_fail 70 "head_read_failed"
  fi
  [[ "${r24_branch}" == "${R24_EXPECTED_BRANCH}" ]] || r24_fail 70 "branch_mismatch_${r24_branch}"
  [[ "${r24_head}" == "${R24_EXPECTED_HEAD}" ]] || r24_fail 70 "head_mismatch_${r24_head}"
}

r24_require_invocation_environment() {
  local r24_env_output=""
  local r24_env_status=()
  case "${BASH_VERSION}" in
    3.2.*) ;;
    *) r24_fail 70 "unexpected_bash_version_${BASH_VERSION}" ;;
  esac
  [[ -z "${BASH_ENV+x}" ]] || r24_fail 70 "BASH_ENV_must_be_unset"
  [[ -z "${ENV+x}" ]] || r24_fail 70 "ENV_must_be_unset"
  [[ -z "${CDPATH+x}" ]] || r24_fail 70 "CDPATH_must_be_unset"
  if r24_env_output="$({
      if /usr/bin/env -0 |
        /usr/bin/sort -z |
        /bin/bash --noprofile --norc -c '
          set -u
          expected=(
            "GIT_CONFIG_GLOBAL=/dev/null"
            "GIT_CONFIG_NOSYSTEM=1"
            "LANG=C"
            "LC_ALL=C"
            "PATH=/usr/bin:/bin:/usr/sbin:/sbin"
            "PWD=/Users/muzi/Agent-loop"
            "SHLVL=1"
            "TMPDIR=/private/tmp"
            "_=/usr/bin/env"
          )
          index=0
          while :; do
            record=""
            IFS= read -r -d "" record
            read_rc=$?
            if [[ "${read_rc}" == "0" ]]; then
              [[ "${index}" -lt "${#expected[@]}" ]] || exit 71
              [[ "${record}" == "${expected[${index}]}" ]] || exit 72
              index=$((index + 1))
              continue
            fi
            if [[ "${read_rc}" == "1" ]]; then
              [[ -z "${record}" ]] || exit 73
              break
            fi
            exit 74
          done
          [[ "${index}" == "${#expected[@]}" ]] || exit 75
        '; then
        r24_env_status=("${PIPESTATUS[@]}")
      else
        r24_env_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r24_env_status[@]}" == "3" ]] || exit 76
      [[ "${r24_env_status[0]}" == "0" && "${r24_env_status[1]}" == "0" && "${r24_env_status[2]}" == "0" ]] || exit 77
    })"; then
    :
  else
    r24_fail 70 "clean_environment_exact_universe_failed"
  fi
  [[ -z "${r24_env_output}" ]] || r24_fail 70 "clean_environment_probe_output"
}

r24_require_no_process() {
  local r24_process_rc=""
  if /usr/bin/pgrep -x AgentLoop >/dev/null 2>&1; then
    r24_process_rc="0"
  else
    r24_process_rc="$?"
  fi
  [[ "${r24_process_rc}" == "1" ]] || r24_fail 70 "AgentLoop_process_state_${r24_process_rc}"
  if /usr/bin/pgrep -x AgentLoopApp >/dev/null 2>&1; then
    r24_process_rc="0"
  else
    r24_process_rc="$?"
  fi
  [[ "${r24_process_rc}" == "1" ]] || r24_fail 70 "AgentLoopApp_process_state_${r24_process_rc}"
}

r24_runtime_paths() {
  /usr/bin/printf '%s\n' \
    "${R24_TASK_DIRECTORY}/r24-targeted-tests.log" \
    "${R24_TASK_DIRECTORY}/r24-verify.log" \
    "${R24_TASK_DIRECTORY}/r24-build.log" \
    "${R24_TASK_DIRECTORY}/r24-migration-matrix.log" \
    "${R24_TASK_DIRECTORY}/impl-report-r24.md" \
    "${R24_TASK_DIRECTORY}/evidence/r24-clean-boundary.log" \
    "${R24_TASK_DIRECTORY}/evidence/r24-bundle-provenance.log" \
    "${R24_TASK_DIRECTORY}/evidence/r24-source-gates.log" \
    "${R24_TASK_DIRECTORY}/evidence/r24-hash-manifest.log" \
    "${R24_TASK_DIRECTORY}/evidence/r24-preview-bootstrap.log" \
    "${R24_TASK_DIRECTORY}/evidence/r24-preview-cold-start.log" \
    "${R24_TASK_DIRECTORY}/evidence/r24-preview-smoke.png"
}

r24_require_fresh_runtime_absence() {
  local r24_path=""
  while IFS= read -r r24_path; do
    r24_require_absent_path "${r24_path}"
  done < <(r24_runtime_paths)
}

r24_require_zero_write_predecessors() {
  local r24_round="$1"
  local r24_generation=""
  local r24_path=""
  for r24_generation in r16 r17 r18 r21 r22; do
    for r24_path in \
      "${R24_TASK_DIRECTORY}/${r24_generation}-targeted-tests.log" \
      "${R24_TASK_DIRECTORY}/${r24_generation}-verify.log" \
      "${R24_TASK_DIRECTORY}/${r24_generation}-build.log" \
      "${R24_TASK_DIRECTORY}/${r24_generation}-migration-matrix.log" \
      "${R24_TASK_DIRECTORY}/impl-report-${r24_generation}.md" \
      "${R24_TASK_DIRECTORY}/evidence/${r24_generation}-clean-boundary.log" \
      "${R24_TASK_DIRECTORY}/evidence/${r24_generation}-bundle-provenance.log" \
      "${R24_TASK_DIRECTORY}/evidence/${r24_generation}-source-gates.log" \
      "${R24_TASK_DIRECTORY}/evidence/${r24_generation}-hash-manifest.log" \
      "${R24_TASK_DIRECTORY}/evidence/${r24_generation}-preview-bootstrap.log" \
      "${R24_TASK_DIRECTORY}/evidence/${r24_generation}-preview-cold-start.log" \
      "${R24_TASK_DIRECTORY}/evidence/${r24_generation}-preview-smoke.png"; do
      r24_require_absent_path "${r24_path}"
    done
  done
  if [[ "${R24_BOUNDARY_ACTIVE}" == "true" ]]; then
    r24_append_boundary "r16_r17_r18_r21_r22_zero_write_${r24_round}=true"
  fi
}

r24_validate_empty_exact_root() {
  local r24_path="$1"
  local r24_real=""
  local r24_capture=""
  [[ -d "${r24_path}" && ! -L "${r24_path}" ]] || r24_fail 70 "root_not_real_directory_${r24_path}"
  if r24_real="$(r24_canonical_directory "${r24_path}")"; then
    :
  else
    r24_fail 70 "root_realpath_failed_${r24_path}"
  fi
  [[ "${r24_real}" == "${r24_path}" ]] || r24_fail 70 "root_realpath_mismatch_${r24_path}_${r24_real}"
  if r24_capture="$({
      if /usr/bin/find -P "${r24_path}" -mindepth 1 -print0 |
        /bin/bash --noprofile --norc -c '
          set -u
          unexpected=""
          IFS= read -r -d "" unexpected
          read_rc=$?
          if [[ "${read_rc}" == "0" ]]; then exit 72; fi
          if [[ "${read_rc}" != "1" ]]; then exit 73; fi
          [[ -z "${unexpected}" ]] || exit 74
        '; then
        r24_status=("${PIPESTATUS[@]}")
      else
        r24_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r24_status[@]}" == "2" ]] || exit 75
      [[ "${r24_status[0]}" == "0" && "${r24_status[1]}" == "0" ]] || exit 76
    })"; then
    :
  else
    r24_fail 70 "root_not_proven_empty_${r24_path}"
  fi
  [[ -z "${r24_capture}" ]] || r24_fail 70 "root_empty_probe_output_${r24_path}"
  [[ -d "${r24_path}" && ! -L "${r24_path}" ]] || r24_fail 70 "root_terminal_bookend_failed_${r24_path}"
}

r24_require_r15_tombstone_universe() {
  local r24_capture=""
  r24_require_private_tmp
  if r24_capture="$({
      if /usr/bin/find -P /private/tmp -mindepth 1 -maxdepth 1 -print0 |
        /bin/bash --noprofile --norc -c '
          set -u
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 71; break; fi
            [[ "${read_rc}" == "0" ]] || exit 72
            case "${path}" in
              /private/tmp/agentloop-r15-state.*|/private/tmp/agentloop-r15-bundle.*) exit 73 ;;
            esac
          done
        '; then
        r24_status=("${PIPESTATUS[@]}")
      else
        r24_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r24_status[@]}" == "2" ]] || exit 74
      [[ "${r24_status[0]}" == "0" && "${r24_status[1]}" == "0" ]] || exit 75
    })"; then
    :
  else
    r24_fail 70 "r15_tombstone_universe_failed"
  fi
  [[ -z "${r24_capture}" ]] || r24_fail 70 "r15_tombstone_universe_output"
  r24_require_absent_path "${R24_R15_STATE_ROOT}"
  r24_require_absent_path "${R24_R15_BUNDLE_ROOT}"
}

r24_validate_preview_state_tree() {
  local r24_capture=""
  if r24_capture="$({
      if /usr/bin/find -P "${R24_STATE_ROOT}" -mindepth 1 -maxdepth 1 -print0 |
        /usr/bin/sort -z |
        /bin/bash --noprofile --norc -c '
          set -u
          root="$1"
          expected=(
            ".agentloop.lock"
            "agentloop.sqlite"
            "agentloop.sqlite-shm"
            "agentloop.sqlite-wal"
          )
          index=0
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 71; break; fi
            [[ "${read_rc}" == "0" ]] || exit 72
            [[ "${index}" -lt "${#expected[@]}" ]] || exit 73
            [[ "${path}" == "${root}/${expected[${index}]}" ]] || exit 74
            [[ -f "${path}" && ! -L "${path}" ]] || exit 75
            index=$((index + 1))
          done
          [[ "${index}" == "4" ]] || exit 76
          /usr/bin/printf "%s\n" "${index}"
        ' bash "${R24_STATE_ROOT}"; then
        r24_status=("${PIPESTATUS[@]}")
      else
        r24_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r24_status[@]}" == "3" ]] || exit 77
      [[ "${r24_status[0]}" == "0" && "${r24_status[1]}" == "0" && "${r24_status[2]}" == "0" ]] || exit 78
    })"; then
    :
  else
    r24_fail 70 "preview_state_tree_validation_failed"
  fi
  [[ "${r24_capture}" == "4" ]] || r24_fail 70 "preview_state_tree_count_${r24_capture}"
}

r24_validate_quiescent_preview_state_tree() {
  local r24_capture=""
  if r24_capture="$({
      if /usr/bin/find -P "${R24_STATE_ROOT}" -mindepth 1 -maxdepth 1 -print0 |
        /usr/bin/sort -z |
        /bin/bash --noprofile --norc -c '
          set -u
          root="$1"
          expected=(
            ".agentloop.lock"
            "agentloop.sqlite"
            "agentloop.sqlite-shm"
            "agentloop.sqlite-wal"
          )
          index=0
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 71; break; fi
            [[ "${read_rc}" == "0" ]] || exit 72
            [[ "${index}" -lt "${#expected[@]}" ]] || exit 73
            [[ "${path}" == "${root}/${expected[${index}]}" ]] || exit 74
            [[ -f "${path}" && ! -L "${path}" ]] || exit 75
            index=$((index + 1))
          done
          [[ "${index}" == "2" || "${index}" == "4" ]] || exit 76
          /usr/bin/printf "%s\n" "${index}"
        ' bash "${R24_STATE_ROOT}"; then
        r24_status=("${PIPESTATUS[@]}")
      else
        r24_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r24_status[@]}" == "3" ]] || exit 77
      [[ "${r24_status[0]}" == "0" && "${r24_status[1]}" == "0" && "${r24_status[2]}" == "0" ]] || exit 78
    })"; then
    :
  else
    r24_fail 70 "quiescent_preview_state_tree_validation_failed"
  fi
  [[ "${r24_capture}" == "2" || "${r24_capture}" == "4" ]] || r24_fail 70 "quiescent_preview_state_tree_count_${r24_capture}"
  [[ -d "${R24_STATE_ROOT}" && ! -L "${R24_STATE_ROOT}" ]] || r24_fail 70 "quiescent_preview_state_root_terminal_bookend"
}

r24_validate_bundle_root_ready() {
  local r24_capture=""
  local r24_current_exec_sha=""
  local r24_current_bundle_sha=""
  local r24_current_uuid=""
  if r24_capture="$({
      if /usr/bin/find -P "${R24_BUNDLE_ROOT}" -mindepth 1 -maxdepth 1 -print0 |
        /bin/bash --noprofile --norc -c '
          set -u
          expected="$1"
          count=0
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 71; break; fi
            [[ "${read_rc}" == "0" ]] || exit 72
            [[ "${path}" == "${expected}" && "${count}" == "0" ]] || exit 73
            [[ -d "${path}" && ! -L "${path}" ]] || exit 74
            count=1
          done
          /usr/bin/printf "%s\n" "${count}"
        ' bash "${R24_APP}"; then
        r24_status=("${PIPESTATUS[@]}")
      else
        r24_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r24_status[@]}" == "2" ]] || exit 75
      [[ "${r24_status[0]}" == "0" && "${r24_status[1]}" == "0" ]] || exit 76
    })"; then
    :
  else
    r24_fail 70 "bundle_root_direct_child_validation_failed"
  fi
  [[ "${r24_capture}" == "1" ]] || r24_fail 70 "bundle_root_direct_child_count_${r24_capture}"
  r24_validate_app_tree "signed"
  if r24_current_exec_sha="$(r24_sha "${R24_APP_EXECUTABLE}")"; then :; else r24_fail 70 "bundle_ready_exec_sha_failed"; fi
  if r24_current_bundle_sha="$(r24_tree_manifest_sha "${R24_APP}")"; then :; else r24_fail 70 "bundle_ready_manifest_failed"; fi
  if r24_current_uuid="$(r24_uuid_set "${R24_APP_EXECUTABLE}")"; then :; else r24_fail 70 "bundle_ready_uuid_failed"; fi
  [[ "${r24_current_exec_sha}" == "${R24_SIGNED_EXECUTABLE_SHA}" ]] || r24_fail 70 "bundle_ready_exec_sha_drift"
  [[ "${r24_current_bundle_sha}" == "${R24_SIGNED_BUNDLE_MANIFEST_SHA}" ]] || r24_fail 70 "bundle_ready_manifest_drift"
  [[ "${r24_current_uuid}" == "${R24_SIGNED_UUID_SET}" ]] || r24_fail 70 "bundle_ready_uuid_drift"
  if /usr/bin/codesign --verify --deep --strict --verbose=4 "${R24_APP}" >/dev/null 2>&1; then :; else r24_fail 70 "bundle_ready_codesign_drift"; fi
}

r24_validate_current_roots_phase() {
  case "${R24_CURRENT_ROOT_PHASE}" in
    empty)
      r24_validate_empty_exact_root "${R24_STATE_ROOT}"
      r24_validate_empty_exact_root "${R24_BUNDLE_ROOT}"
      ;;
    bundle_ready)
      r24_validate_empty_exact_root "${R24_STATE_ROOT}"
      r24_validate_bundle_root_ready
      ;;
    preview_live)
      r24_validate_preview_state_tree
      r24_validate_bundle_root_ready
      ;;
    preview_quiescent)
      r24_validate_quiescent_preview_state_tree
      r24_validate_bundle_root_ready
      ;;
    *)
      r24_fail 70 "r24_root_phase_not_observable_${R24_CURRENT_ROOT_PHASE}"
      ;;
  esac
}

r24_capture_r23_roots() {
  local r24_expect_r24="$1"
  local r24_mask=""
  local r24_status_capture=""

  r24_require_private_tmp
  if r24_status_capture="$({
      if /usr/bin/find -P /private/tmp -mindepth 1 -maxdepth 1 -print0 |
        /bin/bash --noprofile --norc -c '
          set -u
          r23_state="$1"
          r23_bundle="$2"
          r24_state="$3"
          r24_bundle="$4"
          expect_r24="$5"
          state_bit=0
          bundle_bit=0
          r24_state_seen=0
          r24_bundle_seen=0
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then
              [[ -z "${path}" ]] || exit 69
              break
            fi
            [[ "${read_rc}" == "0" ]] || exit 70
            case "${path}" in
              /private/tmp/agentloop-r15-state.*|/private/tmp/agentloop-r15-bundle.*)
                exit 68
                ;;
              /private/tmp/agentloop-r19-state.*|/private/tmp/agentloop-r19-bundle.*)
                exit 71
                ;;
              /private/tmp/agentloop-r20-state.*)
                exit 72
                ;;
              /private/tmp/agentloop-r16-state.*|/private/tmp/agentloop-r16-bundle.*|/private/tmp/agentloop-r17-state.*|/private/tmp/agentloop-r17-bundle.*|/private/tmp/agentloop-r18-state.*|/private/tmp/agentloop-r18-bundle.*|/private/tmp/agentloop-r21-state.*|/private/tmp/agentloop-r21-bundle.*|/private/tmp/agentloop-r22-state.*|/private/tmp/agentloop-r22-bundle.*)
                exit 73
                ;;
              /private/tmp/agentloop-r23-state.*)
                [[ "${path}" == "${r23_state}" && "${state_bit}" == "0" ]] || exit 74
                state_bit=1
                ;;
              /private/tmp/agentloop-r23-bundle.*)
                [[ "${path}" == "${r23_bundle}" && "${bundle_bit}" == "0" ]] || exit 75
                bundle_bit=1
                ;;
              /private/tmp/agentloop-r24-state.*)
                [[ "${expect_r24}" == "true" && "${path}" == "${r24_state}" && "${r24_state_seen}" == "0" ]] || exit 76
                r24_state_seen=1
                ;;
              /private/tmp/agentloop-r24-bundle.*)
                [[ "${expect_r24}" == "true" && "${path}" == "${r24_bundle}" && "${r24_bundle_seen}" == "0" ]] || exit 77
                r24_bundle_seen=1
                ;;
            esac
          done
          if [[ "${expect_r24}" == "true" ]]; then
            [[ "${r24_state_seen}" == "1" && "${r24_bundle_seen}" == "1" ]] || exit 78
          else
            [[ "${r24_state_seen}" == "0" && "${r24_bundle_seen}" == "0" ]] || exit 79
          fi
          /usr/bin/printf "%s%s\n" "${state_bit}" "${bundle_bit}"
        ' bash "${R24_R23_STATE_ROOT}" "${R24_R23_BUNDLE_ROOT}" "${R24_STATE_ROOT}" "${R24_BUNDLE_ROOT}" "${r24_expect_r24}"; then
        r24_status=("${PIPESTATUS[@]}")
      else
        r24_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r24_status[@]}" == "2" ]] || exit 80
      [[ "${r24_status[0]}" == "0" && "${r24_status[1]}" == "0" ]] || exit 81
    })"; then
    :
  else
    r24_fail 70 "top_level_root_universe_capture_failed"
  fi
  r24_mask="${r24_status_capture}"
  [[ "${#r24_mask}" == "2" && "${r24_mask}" != *[!01]* ]] || r24_fail 70 "r23_root_mask_invalid_${r24_mask}"
  r24_require_absent_path "${R24_R15_STATE_ROOT}"
  r24_require_absent_path "${R24_R15_BUNDLE_ROOT}"
  if [[ "${r24_mask:0:1}" == "1" ]]; then
    r24_validate_empty_exact_root "${R24_R23_STATE_ROOT}"
  else
    r24_require_absent_path "${R24_R23_STATE_ROOT}"
  fi
  if [[ "${r24_mask:1:1}" == "1" ]]; then
    r24_validate_empty_exact_root "${R24_R23_BUNDLE_ROOT}"
  else
    r24_require_absent_path "${R24_R23_BUNDLE_ROOT}"
  fi
  if [[ "${r24_expect_r24}" == "true" ]]; then
    r24_validate_current_roots_phase
  fi
  /usr/bin/printf '%s\n' "${r24_mask}"
}

r24_capture_r20() {
  local r24_top=""
  local r24_parent_bit=""
  local r24_child=""
  local r24_app_bit="0"
  local r24_nodes="000000000000000000000000000000000000"
  local r24_real=""
  local r24_mask=""
  local r24_terminal_child=""

  r24_require_private_tmp
  if r24_top="$({
      if /usr/bin/find -P /private/tmp -mindepth 1 -maxdepth 1 -print0 |
        /bin/bash --noprofile --norc -c '
          set -u
          exact="$1"
          seen=0
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 69; break; fi
            [[ "${read_rc}" == "0" ]] || exit 70
            case "${path}" in
              /private/tmp/agentloop-r20-bundle.*)
                [[ "${path}" == "${exact}" && "${seen}" == "0" ]] || exit 71
                seen=1
                ;;
            esac
          done
          /usr/bin/printf "%s\n" "${seen}"
        ' bash "${R24_R20_BUNDLE_ROOT}"; then
        r24_status=("${PIPESTATUS[@]}")
      else
        r24_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r24_status[@]}" == "2" ]] || exit 72
      [[ "${r24_status[0]}" == "0" && "${r24_status[1]}" == "0" ]] || exit 73
    })"; then
    :
  else
    r24_fail 70 "r20_top_level_capture_failed"
  fi
  r24_parent_bit="${r24_top}"
  [[ "${r24_parent_bit}" == "0" || "${r24_parent_bit}" == "1" ]] || r24_fail 70 "r20_parent_bit_invalid"
  if [[ "${r24_parent_bit}" == "0" ]]; then
    r24_require_absent_path "${R24_R20_BUNDLE_ROOT}"
    r24_require_absent_path "${R24_R20_APP}"
    /usr/bin/printf '%s\n' '00000000000000000000000000000000000000'
    return
  fi

  [[ -d "${R24_R20_BUNDLE_ROOT}" && ! -L "${R24_R20_BUNDLE_ROOT}" ]] || r24_fail 70 "r20_parent_not_directory"
  if r24_real="$(r24_canonical_directory "${R24_R20_BUNDLE_ROOT}")"; then :; else r24_fail 70 "r20_parent_realpath_failed"; fi
  [[ "${r24_real}" == "${R24_R20_BUNDLE_ROOT}" ]] || r24_fail 70 "r20_parent_realpath_mismatch"

  if r24_child="$({
      if /usr/bin/find -P "${R24_R20_BUNDLE_ROOT}" -mindepth 1 -maxdepth 1 -print0 |
        /bin/bash --noprofile --norc -c '
          set -u
          exact="$1"
          seen=0
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 69; break; fi
            [[ "${read_rc}" == "0" ]] || exit 70
            [[ "${path}" == "${exact}" && "${seen}" == "0" ]] || exit 71
            seen=1
          done
          /usr/bin/printf "%s\n" "${seen}"
        ' bash "${R24_R20_APP}"; then
        r24_status=("${PIPESTATUS[@]}")
      else
        r24_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r24_status[@]}" == "2" ]] || exit 72
      [[ "${r24_status[0]}" == "0" && "${r24_status[1]}" == "0" ]] || exit 73
    })"; then
    :
  else
    r24_fail 70 "r20_direct_child_capture_failed"
  fi
  r24_app_bit="${r24_child}"
  [[ "${r24_app_bit}" == "0" || "${r24_app_bit}" == "1" ]] || r24_fail 70 "r20_app_bit_invalid"
  if [[ "${r24_app_bit}" == "0" ]]; then
    r24_require_absent_path "${R24_R20_APP}"
    [[ -d "${R24_R20_BUNDLE_ROOT}" && ! -L "${R24_R20_BUNDLE_ROOT}" ]] || r24_fail 70 "r20_parent_terminal_bookend"
    /usr/bin/printf '%s\n' '10000000000000000000000000000000000000'
    return
  fi

  [[ -d "${R24_R20_APP}" && ! -L "${R24_R20_APP}" ]] || r24_fail 70 "r20_app_not_directory"
  if r24_real="$(r24_canonical_directory "${R24_R20_APP}")"; then :; else r24_fail 70 "r20_app_realpath_failed"; fi
  [[ "${r24_real}" == "${R24_R20_APP}" ]] || r24_fail 70 "r20_app_realpath_mismatch"

  if r24_nodes="$({
      if /usr/bin/find -P "${R24_R20_APP}" -mindepth 1 -print0 |
        /bin/bash --noprofile --norc -c '
          set -u
          app="$1"
          bits=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 69; break; fi
            [[ "${read_rc}" == "0" ]] || exit 70
            [[ "${path}" == "${app}/"* ]] || exit 71
            rel="${path#${app}/}"
            case "${rel}" in
              Contents) index=0 ;;
              Contents/MacOS) index=2 ;;
              Contents/Resources) index=4 ;;
              Contents/Resources/AgentLoop_AgentLoopApp.bundle) index=5 ;;
              Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt) index=6 ;;
              Contents/_CodeSignature) index=34 ;;
              *) exit 72 ;;
            esac
            [[ "${bits[${index}]}" == "0" ]] || exit 73
            [[ -d "${path}" && ! -L "${path}" ]] || exit 74
            bits[${index}]=1
          done
          for bit in "${bits[@]}"; do /usr/bin/printf "%s" "${bit}"; done
          /usr/bin/printf "\n"
        ' bash "${R24_R20_APP}"; then
        r24_status=("${PIPESTATUS[@]}")
      else
        r24_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r24_status[@]}" == "2" ]] || exit 75
      [[ "${r24_status[0]}" == "0" && "${r24_status[1]}" == "0" ]] || exit 76
    })"; then
    :
  else
    r24_fail 70 "r20_subtree_capture_failed"
  fi
  [[ "${#r24_nodes}" == "36" && "${r24_nodes}" != *[!01]* ]] || r24_fail 70 "r20_node_mask_invalid_${r24_nodes}"

  [[ -d "${R24_R20_BUNDLE_ROOT}" && ! -L "${R24_R20_BUNDLE_ROOT}" ]] || r24_fail 70 "r20_parent_terminal_bookend"
  [[ -d "${R24_R20_APP}" && ! -L "${R24_R20_APP}" ]] || r24_fail 70 "r20_app_terminal_bookend"
  if r24_real="$(r24_canonical_directory "${R24_R20_BUNDLE_ROOT}")"; then :; else r24_fail 70 "r20_parent_terminal_realpath_failed"; fi
  [[ "${r24_real}" == "${R24_R20_BUNDLE_ROOT}" ]] || r24_fail 70 "r20_parent_terminal_realpath_mismatch"
  if r24_real="$(r24_canonical_directory "${R24_R20_APP}")"; then :; else r24_fail 70 "r20_app_terminal_realpath_failed"; fi
  [[ "${r24_real}" == "${R24_R20_APP}" ]] || r24_fail 70 "r20_app_terminal_realpath_mismatch"
  if r24_terminal_child="$({
      if /usr/bin/find -P "${R24_R20_BUNDLE_ROOT}" -mindepth 1 -maxdepth 1 -print0 |
        /bin/bash --noprofile --norc -c '
          set -u
          exact="$1"
          seen=0
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 69; break; fi
            [[ "${read_rc}" == "0" ]] || exit 70
            [[ "${path}" == "${exact}" && "${seen}" == "0" ]] || exit 71
            seen=1
          done
          /usr/bin/printf "%s\n" "${seen}"
        ' bash "${R24_R20_APP}"; then
        r24_status=("${PIPESTATUS[@]}")
      else
        r24_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r24_status[@]}" == "2" ]] || exit 72
      [[ "${r24_status[0]}" == "0" && "${r24_status[1]}" == "0" ]] || exit 73
    })"; then
    :
  else
    r24_fail 70 "r20_terminal_direct_child_capture_failed"
  fi
  [[ "${r24_terminal_child}" == "1" ]] || r24_fail 70 "r20_terminal_direct_child_shape_${r24_terminal_child}"

  r24_mask="11${r24_nodes}"
  /usr/bin/printf '%s\n' "${r24_mask}"
}

r24_compare_erosion() {
  local r24_from="$1"
  local r24_to="$2"
  local r24_label="$3"
  local r24_index=0
  local r24_from_bit=""
  local r24_to_bit=""
  [[ "${#r24_from}" == "${#r24_to}" ]] || r24_fail 70 "erosion_length_${r24_label}"
  while (( r24_index < ${#r24_from} )); do
    r24_from_bit="${r24_from:r24_index:1}"
    r24_to_bit="${r24_to:r24_index:1}"
    [[ "${r24_from_bit}" == "0" || "${r24_from_bit}" == "1" ]] || r24_fail 70 "erosion_from_bit_${r24_label}_${r24_index}"
    [[ "${r24_to_bit}" == "0" || "${r24_to_bit}" == "1" ]] || r24_fail 70 "erosion_to_bit_${r24_label}_${r24_index}"
    [[ "${r24_from_bit}${r24_to_bit}" != "01" ]] || r24_fail 70 "erosion_reappearance_${r24_label}_bit_${r24_index}"
    r24_index=$((r24_index + 1))
  done
}

r24_observe_lifecycles() {
  local r24_label="$1"
  local r24_expect_r24="$2"
  local r24_r23_a=""
  local r24_r23_b=""
  local r24_r20_a=""
  local r24_r20_b=""
  local r24_pair_r23_from="${R24_R23_LATEST_MASK}"
  local r24_pair_r20_from="${R24_R20_LATEST_MASK}"
  local r24_r23_transition="UNCHANGED"
  local r24_r20_transition="UNCHANGED"
  local r24_r23_disappearance_cause="NOT_OBSERVED"
  local r24_r20_disappearance_cause="NOT_OBSERVED"

  r24_require_r15_tombstone_universe
  if r24_r23_a="$(r24_capture_r23_roots "${r24_expect_r24}")"; then :; else r24_fail 70 "r23_capture_a_${r24_label}"; fi
  if r24_r20_a="$(r24_capture_r20)"; then :; else r24_fail 70 "r20_capture_a_${r24_label}"; fi
  if r24_r23_b="$(r24_capture_r23_roots "${r24_expect_r24}")"; then :; else r24_fail 70 "r23_capture_b_${r24_label}"; fi
  if r24_r20_b="$(r24_capture_r20)"; then :; else r24_fail 70 "r20_capture_b_${r24_label}"; fi
  r24_require_r15_tombstone_universe

  r24_compare_erosion "${r24_pair_r23_from}" "${r24_r23_a}" "r23_${r24_label}_LATEST_to_A"
  r24_compare_erosion "${r24_r23_a}" "${r24_r23_b}" "r23_${r24_label}_A_to_B"
  r24_compare_erosion "${r24_pair_r20_from}" "${r24_r20_a}" "r20_${r24_label}_LATEST_to_A"
  r24_compare_erosion "${r24_r20_a}" "${r24_r20_b}" "r20_${r24_label}_A_to_B"
  if [[ "${r24_pair_r23_from}" != "${r24_r23_b}" ]]; then
    r24_r23_transition="ERODED"
    r24_r23_disappearance_cause="UNKNOWN"
  fi
  if [[ "${r24_pair_r20_from}" != "${r24_r20_b}" ]]; then
    r24_r20_transition="ERODED"
    r24_r20_disappearance_cause="UNKNOWN"
  fi

  R24_DEFERRED_SIGNAL=""
  R24_DEFERRED_SIGNAL_STATUS=""
  trap 'r24_defer_signal HUP 129' HUP
  trap 'r24_defer_signal INT 130' INT
  trap 'r24_defer_signal TERM 143' TERM
  if [[ -z "${R24_R23_FIRST_MASK}" ]]; then R24_R23_FIRST_MASK="${r24_r23_a}"; fi
  R24_R23_LATEST_MASK="${r24_r23_b}"
  R24_R23_ACCEPTED_MODE_B="${r24_r23_b}"
  if [[ -z "${R24_R20_FIRST_MASK}" ]]; then R24_R20_FIRST_MASK="${r24_r20_a}"; fi
  R24_R20_LATEST_MASK="${r24_r20_b}"
  R24_R20_ACCEPTED_MODE_B="${r24_r20_b}"
  r24_install_signal_traps
  if [[ -n "${R24_DEFERRED_SIGNAL}" ]]; then
    r24_fail "${R24_DEFERRED_SIGNAL_STATUS}" "deferred_signal_${R24_DEFERRED_SIGNAL}_${r24_label}"
  fi

  if [[ "${R24_BOUNDARY_ACTIVE}" == "true" ]]; then
    {
      /usr/bin/printf 'lifecycle_label=%s\n' "${r24_label}"
      /usr/bin/printf 'r23_capture_a=%s\n' "${r24_r23_a}"
      /usr/bin/printf 'r23_capture_b=%s\n' "${r24_r23_b}"
      /usr/bin/printf 'r23_first_mask=%s\n' "${R24_R23_FIRST_MASK}"
      /usr/bin/printf 'r23_latest_mask=%s\n' "${R24_R23_LATEST_MASK}"
      /usr/bin/printf 'r23_accepted_mode_b=%s\n' "${R24_R23_ACCEPTED_MODE_B}"
      /usr/bin/printf 'r23_transition=%s\n' "${r24_r23_transition}"
      /usr/bin/printf 'r23_disappearance_cause=%s\n' "${r24_r23_disappearance_cause}"
      /usr/bin/printf 'r20_capture_a=%s\n' "${r24_r20_a}"
      /usr/bin/printf 'r20_capture_b=%s\n' "${r24_r20_b}"
      /usr/bin/printf 'r20_first_mask=%s\n' "${R24_R20_FIRST_MASK}"
      /usr/bin/printf 'r20_latest_mask=%s\n' "${R24_R20_LATEST_MASK}"
      /usr/bin/printf 'r20_accepted_mode_b=%s\n' "${R24_R20_ACCEPTED_MODE_B}"
      /usr/bin/printf 'r20_transition=%s\n' "${r24_r20_transition}"
      /usr/bin/printf 'r20_disappearance_cause=%s\n' "${r24_r20_disappearance_cause}"
    } >> "${R24_BOUNDARY_LOG}"
  fi
}

r24_exclusive_create_empty() {
  local r24_path="$1"
  local r24_old_noclobber="false"
  case "$-" in *C*) r24_old_noclobber="true" ;; esac
  set -C
  if : > "${r24_path}"; then
    if [[ "${r24_old_noclobber}" != "true" ]]; then set +C; fi
    return 0
  fi
  if [[ "${r24_old_noclobber}" != "true" ]]; then set +C; fi
  return 1
}

r24_create_runtime_evidence() {
  local r24_path=""
  R24_PHASE="activation_hash_log"
  r24_exclusive_create_empty "${R24_HASH_LOG}" || r24_active_fail 71 "exclusive_create_failed_${R24_HASH_LOG}"
  for r24_path in \
    "${R24_TASK_DIRECTORY}/r24-targeted-tests.log" \
    "${R24_VERIFY_LOG}" \
    "${R24_TASK_DIRECTORY}/r24-build.log" \
    "${R24_TASK_DIRECTORY}/r24-migration-matrix.log" \
    "${R24_TASK_DIRECTORY}/evidence/r24-bundle-provenance.log" \
    "${R24_TASK_DIRECTORY}/evidence/r24-source-gates.log" \
    "${R24_TASK_DIRECTORY}/evidence/r24-preview-bootstrap.log" \
    "${R24_TASK_DIRECTORY}/evidence/r24-preview-cold-start.log"; do
    r24_exclusive_create_empty "${r24_path}" || r24_active_fail 71 "exclusive_create_failed_${r24_path}"
  done
}

r24_require_verify_log_identity() {
  local r24_label="$1"
  local r24_sha_before=""
  local r24_sha_after=""
  local r24_bytes_before=""
  local r24_bytes_after=""
  [[ "${R24_VERIFY_LOG_SHA}" != "UNKNOWN" && "${R24_VERIFY_LOG_BYTES}" != "UNKNOWN" ]] || r24_active_fail 70 "verify_identity_not_committed_${r24_label}"
  r24_require_regular_file "${R24_VERIFY_LOG}"
  if r24_sha_before="$(r24_sha "${R24_VERIFY_LOG}")"; then :; else r24_active_fail 70 "verify_sha_before_failed_${r24_label}"; fi
  if r24_bytes_before="$(/usr/bin/stat -f '%z' "${R24_VERIFY_LOG}")"; then :; else r24_active_fail 70 "verify_bytes_before_failed_${r24_label}"; fi
  r24_require_regular_file "${R24_VERIFY_LOG}"
  if r24_sha_after="$(r24_sha "${R24_VERIFY_LOG}")"; then :; else r24_active_fail 70 "verify_sha_after_failed_${r24_label}"; fi
  if r24_bytes_after="$(/usr/bin/stat -f '%z' "${R24_VERIFY_LOG}")"; then :; else r24_active_fail 70 "verify_bytes_after_failed_${r24_label}"; fi
  [[ "${r24_sha_before}" == "${R24_VERIFY_LOG_SHA}" && "${r24_sha_after}" == "${R24_VERIFY_LOG_SHA}" ]] || r24_active_fail 70 "verify_sha_drift_${r24_label}"
  [[ "${r24_bytes_before}" == "${R24_VERIFY_LOG_BYTES}" && "${r24_bytes_after}" == "${R24_VERIFY_LOG_BYTES}" ]] || r24_active_fail 70 "verify_bytes_drift_${r24_label}"
}

r24_run_authoritative_full_test() {
  local r24_pipeline_status=()
  local r24_terminal_count=""
  local r24_working_directory=""
  local r24_verify_sha=""
  local r24_verify_bytes=""

  R24_PHASE="authoritative_full_test"
  [[ -f "${R24_VERIFY_LOG}" && ! -L "${R24_VERIFY_LOG}" && ! -s "${R24_VERIFY_LOG}" ]] || r24_active_fail 70 "authoritative_verify_log_not_fresh_empty_regular"
  cd -P "${R24_REPOSITORY_ROOT}"
  if r24_working_directory="$(pwd -P)"; then :; else r24_active_fail 70 "authoritative_pwd_failed"; fi
  [[ "${r24_working_directory}" == "${R24_REPOSITORY_ROOT}" ]] || r24_active_fail 70 "authoritative_cwd_mismatch_${r24_working_directory}"
  R24_AUTHORITATIVE_SWIFT_RC="UNKNOWN"
  R24_AUTHORITATIVE_TEE_RC="UNKNOWN"
  R24_AUTHORITATIVE_STATUS_CAPTURED="false"
  if /usr/bin/swift run RunTests 2>&1 | /usr/bin/tee "${R24_VERIFY_LOG}"; then
    r24_pipeline_status=("${PIPESTATUS[@]}")
  else
    r24_pipeline_status=("${PIPESTATUS[@]}")
  fi
  [[ "${#r24_pipeline_status[@]}" == "2" ]] || r24_active_fail 70 "authoritative_PIPESTATUS_cardinality_${#r24_pipeline_status[@]}"
  case "${r24_pipeline_status[0]}" in ''|*[!0-9]*) r24_active_fail 70 "authoritative_swift_status_not_numeric" ;; esac
  case "${r24_pipeline_status[1]}" in ''|*[!0-9]*) r24_active_fail 70 "authoritative_tee_status_not_numeric" ;; esac
  R24_DEFERRED_SIGNAL=""
  R24_DEFERRED_SIGNAL_STATUS=""
  trap 'r24_defer_signal HUP 129' HUP
  trap 'r24_defer_signal INT 130' INT
  trap 'r24_defer_signal TERM 143' TERM
  R24_AUTHORITATIVE_SWIFT_RC="${r24_pipeline_status[0]}"
  R24_AUTHORITATIVE_TEE_RC="${r24_pipeline_status[1]}"
  R24_AUTHORITATIVE_STATUS_CAPTURED="true"
  r24_install_signal_traps
  if [[ -n "${R24_DEFERRED_SIGNAL}" ]]; then
    r24_active_fail "${R24_DEFERRED_SIGNAL_STATUS}" "deferred_signal_${R24_DEFERRED_SIGNAL}_authoritative_status_commit"
  fi
  [[ -f "${R24_VERIFY_LOG}" && ! -L "${R24_VERIFY_LOG}" ]] || r24_active_fail 70 "authoritative_verify_log_terminal_type"
  {
    /usr/bin/printf '%s\n' 'authoritative_test_invocation_count=1'
    /usr/bin/printf '%s\n' 'authoritative_test_filter=none'
    /usr/bin/printf '%s\n' 'authoritative_host_shell_dependency=false'
    /usr/bin/printf '%s\n' 'authoritative_capture_shell=/bin/bash_3.2'
    /usr/bin/printf 'authoritative_status_captured=%s\n' "${R24_AUTHORITATIVE_STATUS_CAPTURED}"
    /usr/bin/printf 'authoritative_swift_rc=%s\n' "${R24_AUTHORITATIVE_SWIFT_RC}"
    /usr/bin/printf 'authoritative_tee_rc=%s\n' "${R24_AUTHORITATIVE_TEE_RC}"
  } >> "${R24_BOUNDARY_LOG}"
  [[ "${R24_AUTHORITATIVE_SWIFT_RC}" == "0" ]] || r24_active_fail "${R24_AUTHORITATIVE_SWIFT_RC}" "authoritative_swift_failed"
  [[ "${R24_AUTHORITATIVE_TEE_RC}" == "0" ]] || r24_active_fail "${R24_AUTHORITATIVE_TEE_RC}" "authoritative_tee_failed"
  if r24_terminal_count="$(/usr/bin/awk '$0 ~ /^.*Test run with 652 tests in 7 suites passed after [0-9.]+ seconds\.$/ { count += 1 } END { print count + 0 }' "${R24_VERIFY_LOG}")"; then
    :
  else
    r24_active_fail 70 "authoritative_terminal_summary_scan_failed"
  fi
  [[ "${r24_terminal_count}" == "1" ]] || r24_active_fail 70 "authoritative_terminal_summary_count_${r24_terminal_count}"
  if r24_verify_sha="$(r24_sha "${R24_VERIFY_LOG}")"; then :; else r24_active_fail 70 "authoritative_verify_sha_failed"; fi
  if r24_verify_bytes="$(/usr/bin/stat -f '%z' "${R24_VERIFY_LOG}")"; then :; else r24_active_fail 70 "authoritative_verify_size_failed"; fi
  case "${r24_verify_bytes}" in ''|*[!0-9]*) r24_active_fail 70 "authoritative_verify_size_not_numeric" ;; esac
  [[ "${r24_verify_bytes}" != "0" ]] || r24_active_fail 70 "authoritative_verify_log_empty"
  R24_VERIFY_LOG_SHA="${r24_verify_sha}"
  R24_VERIFY_LOG_BYTES="${r24_verify_bytes}"
  r24_append_boundary 'authoritative_log_terminal_summary=652_of_652_pass'
  r24_append_boundary 'authoritative_pipeline_status=CAPTURED_BOTH_ZERO'
  r24_append_boundary "authoritative_verify_log_sha=${R24_VERIFY_LOG_SHA}"
  r24_append_boundary "authoritative_verify_log_bytes=${R24_VERIFY_LOG_BYTES}"
  r24_append_boundary 'status=AUTHORITATIVE_FULL_TEST_ATTESTED'
  r24_require_verify_log_identity "authoritative_terminal_adjacent"
}

r24_run_same_log_targeted_audit() {
  local r24_name=""
  local r24_joined_names=""
  local r24_audit_output=""
  local r24_audit_status=""
  local r24_now_value=""
  local r24_name_index=0
  R24_REQUIRED_TEST_NAMES=(
    ruminationStartAndWorkAreAtomic
    ruminationCrashIsAdoptedAndCompletesOnce
    ruminationFailurePersistenceFailureRemainsRecoverable
    ruminationCancelRejectsStaleResponse
    legacyRuminatingRowGetsOneRepairWork
    repeatedRuminationCommandReturnsExistingWork
    ruminationCancelAndQueuedProjectionRollbackTogether
    ruminationAttemptClosesExactlyOnce
    ruminationWorkInputUsesCanonicalCapturedIdentityAndFirstTrace
    ruminationSameKeyDifferentCapturedIdentityConflictsWithoutResolution
    ruminationTerminalRetryCreatesReplacementWhileActiveReplayReusesWork
    ruminationCapturedProfileAndModelIgnoreDefaultDrift
    ruminationClaimResolutionFailureMatrixIsStableSafeAndFailClosed
    ruminationResolverNeverFallsBackToCurrentDefaultOrCompanion
    ruminationTransientFailureRetriesAtFiveThirtyOneTwentyThenTerminates
    ruminationDeterministicFailureDoesNotRetry
    ruminationTerminalFailureAndProjectionCommitOrRollbackTogether
    ruminationSuccessResultProjectionAndWorkCommitOrRollbackTogether
    ruminationLeaseRenewalAllowsOnlyLatestClaimToCommit
    ruminationTerminalCommitFailureRetainsProposalAndDoesNotRecallProvider
    ruminationProcessRestartMayRecallProviderButCommitsOneResultAndTerminal
    ruminationEmergencyHaltCancelsWorkAndQueuesProjectionAtomically
    ruminationEmergencyHaltRejectsClaimResolveAndProviderDispatch
    ruminationLateProviderResponseCannotOverrideEmergencyHalt
    ruminationResumeDoesNotReviveCanceledWork
    ruminationWaitUntilIdleIncludesDueRuminationAndIgnoresFutureRetry
    ruminationLivePhaseEventsAreOwnedOrderedAndProcessLocal
    legacyRuminationWithoutResolvableRuntimeFailsSafelyExactlyOnce
    ruminationSanitizesPersistedAndVisibleDiagnostics
    ruminationInvalidOutputIsDeterministicAndPreservesSource
    ruminationProviderUsesNoToolsAndProducesOneCanonicalResult
    singleOrchestratorSupervisorOwnsPlanningAndRuminationLifecycle
    ruminationAdapterDelegatesStartRetryCancelWithoutUnownedTask
    ruminationUnknownRestartRendersRecoveringWithoutInventingReading
    ruminationPhaseProjectionUsesOnlyMatchingSupervisorEvents
    genericDurableWorkAPIsSealRuminationWithExactPriority
    supervisedWorkPumpIsGlobalFIFOWithoutPlanningRegression
    ruminationStartupRemainsSuppressedUntilOrchestratorActivation
    legacyRuminationRepairCoversValidHaltedAndEveryTerminalReason
    ruminationUsageIsExactOrFailsBeforeAccounting
    activeRuminationFencesDiscardDeleteAndArchiveRaces
    slowActiveStreamDoesNotIdleTimeout
    turnTimeoutRetriesOnceThenBlocks
    timeoutThenSuccessDoesNotAccumulate
    cancelWinsOverIdleTimeout
    turnCompletesUnderTimeout
  )
  [[ "${#R24_REQUIRED_TEST_NAMES[@]}" == "46" ]] || r24_active_fail 70 "targeted_name_array_count"
  for r24_name in "${R24_REQUIRED_TEST_NAMES[@]}"; do
    if [[ "${r24_name_index}" == "0" ]]; then
      r24_joined_names="${r24_name}"
    else
      r24_joined_names="${r24_joined_names}|${r24_name}"
    fi
    r24_name_index=$((r24_name_index + 1))
  done
  r24_require_verify_log_identity "targeted_reader_pre"
  if r24_audit_output="$(/usr/bin/awk -v joined="${r24_joined_names}" '
      BEGIN { n = split(joined, names, "|"); ok = 1 }
      {
        if ($0 != "") last = $0
        if ($0 == "◇ Test run started.") run_started += 1
        if ($0 ~ /^◇ Test .*\(\) started\.$/) test_started += 1
        if ($0 ~ /^✔ Test .*\(\) passed after [0-9.]+ seconds\.$/) test_passed += 1
        if ($0 ~ /^◇ Suite .* started\.$/) suite_started += 1
        if ($0 ~ /^✔ Suite .* passed after [0-9.]+ seconds\.$/) suite_passed += 1
        if ($0 ~ /^✘ /) failure_markers += 1
        if ($0 ~ /^✔ Test run with 652 tests in 7 suites passed after [0-9.]+ seconds\.$/) summary += 1
        for (i = 1; i <= n; i += 1) {
          if ($0 == "◇ Test " names[i] "() started.") discovery[i] += 1
          if ($0 ~ ("^✔ Test " names[i] "\\(\\) passed after [0-9.]+ seconds\\.$")) passed[i] += 1
          if ($0 ~ ("^✘ Test " names[i] "\\(\\)")) failed[i] += 1
        }
      }
      END {
        if (n != 46 || run_started != 1 || test_started != 652 || test_passed != 652 ||
            suite_started != 7 || suite_passed != 7 || failure_markers != 0 || summary != 1 ||
            last !~ /^✔ Test run with 652 tests in 7 suites passed after [0-9.]+ seconds\.$/) ok = 0
        print "captured_run_started_count=" run_started
        print "full_test_discovery_count=" test_started
        print "full_test_pass_count=" test_passed
        print "full_suite_start_count=" suite_started
        print "full_suite_pass_count=" suite_passed
        print "full_failure_marker_count=" failure_markers
        print "full_summary_count=" summary
        print "full_summary_is_last_nonempty_line=" (last ~ /^✔ Test run with 652 tests in 7 suites passed after [0-9.]+ seconds\.$/ ? "true" : "false")
        print "required_name_count=" n
        discovery_total = 0; pass_total = 0
        for (i = 1; i <= n; i += 1) {
          discovery_total += discovery[i]; pass_total += passed[i]
          if (discovery[i] != 1 || passed[i] != 1 || failed[i] != 0) ok = 0
          print "name=" names[i] " discovery=" (discovery[i] + 0) " pass=" (passed[i] + 0) " failure=" (failed[i] + 0)
        }
        print "required_discovery_total=" discovery_total
        print "required_pass_total=" pass_total
        print "status=" (ok ? "PASS" : "FAIL")
      }
    ' "${R24_VERIFY_LOG}")"; then
    :
  else
    r24_active_fail 70 "targeted_audit_awk_failed"
  fi
  r24_require_verify_log_identity "targeted_reader_post"
  if r24_now_value="$(r24_capture_now)"; then :; else r24_active_fail 70 "targeted_timestamp_failed"; fi
  {
    /usr/bin/printf '%s\n' 'format=r24-targeted-tests-v1'
    /usr/bin/printf 'utc=%s\n' "${r24_now_value}"
    /usr/bin/printf 'source_log=%s\n' "${R24_VERIFY_LOG}"
    /usr/bin/printf 'source_sha256=%s\n' "${R24_VERIFY_LOG_SHA}"
    /usr/bin/printf 'source_bytes=%s\n' "${R24_VERIFY_LOG_BYTES}"
    /usr/bin/printf '%s\n' 'authoritative_command=swift run RunTests'
    /usr/bin/printf '%s\n' 'authoritative_unfiltered=true'
    /usr/bin/printf '%s\n' 'authoritative_single_invocation=true'
    /usr/bin/printf '%s\n' "${r24_audit_output}"
  } >> "${R24_TARGETED_LOG}"
  if r24_audit_status="$(r24_exact_line_count "${R24_TARGETED_LOG}" 'status=PASS')"; then :; else r24_active_fail 70 "targeted_status_read_failed"; fi
  [[ "${r24_audit_status}" == "1" ]] || r24_active_fail 70 "targeted_audit_not_pass"
  r24_require_verify_log_identity "targeted_transition_adjacent"
  r24_append_boundary 'same_log_targeted_audit=46_of_46_pass'
}

r24_tree_manifest_sha() {
  local r24_tree="$1"
  local r24_manifest_output=""
  [[ -d "${r24_tree}" && ! -L "${r24_tree}" ]] || return 70
  if r24_manifest_output="$({
      cd -P "${r24_tree}" || exit 71
      if /usr/bin/find -P . -type f -print0 |
        /usr/bin/sort -z |
        /usr/bin/xargs -0 /usr/bin/shasum -a 256 |
        /usr/bin/sed 's#  \./#  #' |
        /usr/bin/shasum -a 256 |
        /usr/bin/awk '{print $1}'; then
        r24_status=("${PIPESTATUS[@]}")
      else
        r24_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r24_status[@]}" == "6" ]] || exit 72
      for r24_rc in "${r24_status[@]}"; do [[ "${r24_rc}" == "0" ]] || exit 73; done
    })"; then
    :
  else
    return "$?"
  fi
  [[ "${#r24_manifest_output}" == "64" && "${r24_manifest_output}" != *[!0-9a-f]* ]] || return 74
  /usr/bin/printf '%s\n' "${r24_manifest_output}"
}

r24_uuid_set() {
  local r24_binary="$1"
  local r24_uuid_output=""
  r24_require_regular_file "${r24_binary}"
  if r24_uuid_output="$({
      if /usr/bin/dwarfdump --uuid "${r24_binary}" |
        /usr/bin/awk '/^UUID: / { gsub(/[()]/, "", $3); print $2 "|" $3 }' |
        /usr/bin/sort; then
        r24_status=("${PIPESTATUS[@]}")
      else
        r24_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r24_status[@]}" == "3" ]] || exit 71
      [[ "${r24_status[0]}" == "0" && "${r24_status[1]}" == "0" && "${r24_status[2]}" == "0" ]] || exit 72
    })"; then
    :
  else
    return "$?"
  fi
  [[ -n "${r24_uuid_output}" ]] || return 73
  /usr/bin/printf '%s\n' "${r24_uuid_output}"
}

r24_validate_ranch_art_tree() {
  local r24_tree="$1"
  local r24_capture=""
  local r24_manifest=""
  [[ -d "${r24_tree}" && ! -L "${r24_tree}" ]] || r24_active_fail 70 "ranch_art_not_real_directory_${r24_tree}"
  if r24_capture="$({
      if /usr/bin/find -P "${r24_tree}" -mindepth 1 -maxdepth 1 -print0 |
        /bin/bash --noprofile --norc -c '
          set -u
          count=0
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 71; break; fi
            [[ "${read_rc}" == "0" ]] || exit 72
            [[ -f "${path}" && ! -L "${path}" ]] || exit 73
            count=$((count + 1))
          done
          /usr/bin/printf "%s\n" "${count}"
        '; then
        r24_status=("${PIPESTATUS[@]}")
      else
        r24_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r24_status[@]}" == "2" ]] || exit 74
      [[ "${r24_status[0]}" == "0" && "${r24_status[1]}" == "0" ]] || exit 75
    })"; then
    :
  else
    r24_active_fail 70 "ranch_art_tree_drain_failed_${r24_tree}"
  fi
  [[ "${r24_capture}" == "27" ]] || r24_active_fail 70 "ranch_art_count_${r24_tree}_${r24_capture}"
  if r24_manifest="$(r24_tree_manifest_sha "${r24_tree}")"; then :; else r24_active_fail 70 "ranch_art_manifest_failed_${r24_tree}"; fi
  [[ "${r24_manifest}" == "${R24_EXPECTED_RANCH_ART_MANIFEST_SHA}" ]] || r24_active_fail 70 "ranch_art_manifest_mismatch_${r24_tree}"
}

r24_validate_app_tree() {
  local r24_mode="$1"
  local r24_capture=""
  local r24_expected_count=""
  case "${r24_mode}" in
    unsigned) r24_expected_count="34" ;;
    signed) r24_expected_count="36" ;;
    *) r24_active_fail 70 "invalid_app_tree_mode_${r24_mode}" ;;
  esac
  if r24_capture="$({
      if /usr/bin/find -P "${R24_APP}" -mindepth 1 -print0 |
        /usr/bin/sort -z |
        /bin/bash --noprofile --norc -c '
          set -u
          app="$1"
          mode="$2"
          expected=(
            "Contents"
            "Contents/Info.plist"
            "Contents/MacOS"
            "Contents/MacOS/AgentLoop"
            "Contents/Resources"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelBarnDay.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelBarnNight.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideAmber.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideBlue.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideCoral.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideGreen.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSidePink.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSidePurple.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideTeal.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepAmber.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepBlue.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepCoral.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepGreen.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepPink.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepPurple.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepTeal.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideAmber.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideBlue.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideCoral.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideGreen.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStridePink.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStridePurple.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideTeal.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelPanoramaDay.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelPanoramaNight.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelPastureDay.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelPastureNight.png"
          )
          if [[ "${mode}" == "signed" ]]; then
            expected+=("Contents/_CodeSignature" "Contents/_CodeSignature/CodeResources")
          fi
          index=0
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 71; break; fi
            [[ "${read_rc}" == "0" ]] || exit 72
            [[ "${index}" -lt "${#expected[@]}" ]] || exit 73
            rel="${path#${app}/}"
            [[ "${rel}" == "${expected[${index}]}" ]] || exit 74
            case "${rel}" in
              Contents|Contents/MacOS|Contents/Resources|Contents/Resources/AgentLoop_AgentLoopApp.bundle|Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt|Contents/_CodeSignature)
                [[ -d "${path}" && ! -L "${path}" ]] || exit 75 ;;
              *) [[ -f "${path}" && ! -L "${path}" ]] || exit 76 ;;
            esac
            index=$((index + 1))
          done
          [[ "${index}" == "${#expected[@]}" ]] || exit 77
          /usr/bin/printf "%s\n" "${index}"
        ' bash "${R24_APP}" "${r24_mode}"; then
        r24_status=("${PIPESTATUS[@]}")
      else
        r24_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r24_status[@]}" == "3" ]] || exit 78
      [[ "${r24_status[0]}" == "0" && "${r24_status[1]}" == "0" && "${r24_status[2]}" == "0" ]] || exit 79
    })"; then
    :
  else
    r24_active_fail 70 "app_tree_validation_failed_${r24_mode}"
  fi
  [[ "${r24_capture}" == "${r24_expected_count}" ]] || r24_active_fail 70 "app_tree_count_${r24_mode}_${r24_capture}"
}

r24_run_debug_build_and_bundle() {
  local r24_build_status=()
  local r24_bin_dir=""
  local r24_bin_real=""
  local r24_bin_component=""
  local r24_resource_manifest=""
  local r24_copied_resource_manifest=""
  local r24_info_sha=""
  local r24_plist_exec=""
  local r24_plist_identifier=""
  local r24_ls_state=""
  local r24_ls_preview=""
  local r24_unsigned_sha=""
  local r24_unsigned_uuid=""
  local r24_signature_detail=""
  local r24_entitlements=""
  local r24_cdhash=""
  local r24_now_value=""
  local r24_app_real=""
  local r24_exec_real=""

  R24_PHASE="debug_app_build"
  r24_require_verify_log_identity "pre_debug_build"
  if /usr/bin/swift build --product AgentLoopApp 2>&1 | /usr/bin/tee -a "${R24_BUILD_LOG}"; then
    r24_build_status=("${PIPESTATUS[@]}")
  else
    r24_build_status=("${PIPESTATUS[@]}")
  fi
  [[ "${#r24_build_status[@]}" == "2" ]] || r24_active_fail 70 "debug_build_status_shape"
  [[ "${r24_build_status[0]}" == "0" && "${r24_build_status[1]}" == "0" ]] || r24_active_fail 70 "debug_build_failed_${r24_build_status[0]}_${r24_build_status[1]}"

  if r24_bin_dir="$(/usr/bin/swift build -c debug --show-bin-path)"; then :; else r24_active_fail 70 "debug_bin_path_query_failed"; fi
  [[ -d "${r24_bin_dir}" && ! -L "${r24_bin_dir}" ]] || r24_active_fail 70 "debug_bin_not_real_directory"
  if r24_bin_real="$(r24_canonical_directory "${r24_bin_dir}")"; then :; else r24_active_fail 70 "debug_bin_canonicalization_failed"; fi
  [[ "${r24_bin_real}" == "${r24_bin_dir}" ]] || r24_active_fail 70 "debug_bin_canonical_mismatch"
  case "${r24_bin_dir}" in
    "${R24_REPOSITORY_ROOT}/.build/"*/debug) ;;
    *) r24_active_fail 70 "debug_bin_layout_${r24_bin_dir}" ;;
  esac
  r24_bin_component="${r24_bin_dir#${R24_REPOSITORY_ROOT}/.build/}"
  r24_bin_component="${r24_bin_component%/debug}"
  [[ -n "${r24_bin_component}" && "${r24_bin_component}" != */* ]] || r24_active_fail 70 "debug_bin_component_${r24_bin_component}"

  R24_BUILD_EXECUTABLE="${r24_bin_dir}/AgentLoopApp"
  R24_BUILD_RESOURCE_BUNDLE="${r24_bin_dir}/AgentLoop_AgentLoopApp.bundle"
  r24_require_regular_file "${R24_BUILD_EXECUTABLE}"
  [[ -x "${R24_BUILD_EXECUTABLE}" ]] || r24_active_fail 70 "debug_build_executable_not_executable"
  [[ -d "${R24_BUILD_RESOURCE_BUNDLE}" && ! -L "${R24_BUILD_RESOURCE_BUNDLE}" ]] || r24_active_fail 70 "debug_resource_not_real_directory"
  if R24_BUILD_EXECUTABLE_SHA="$(r24_sha "${R24_BUILD_EXECUTABLE}")"; then :; else r24_active_fail 70 "debug_build_executable_sha_failed"; fi
  if R24_BUILD_UUID_SET="$(r24_uuid_set "${R24_BUILD_EXECUTABLE}")"; then :; else r24_active_fail 70 "debug_build_uuid_failed"; fi
  r24_validate_ranch_art_tree "${R24_RANCH_ART_DIRECTORY}"
  r24_validate_ranch_art_tree "${R24_BUILD_RESOURCE_BUNDLE}/RanchArt"
  if r24_resource_manifest="$(r24_tree_manifest_sha "${R24_BUILD_RESOURCE_BUNDLE}")"; then :; else r24_active_fail 70 "generated_resource_manifest_failed"; fi
  if r24_now_value="$(r24_capture_now)"; then :; else r24_active_fail 70 "post_build_timestamp_failed"; fi
  {
    /usr/bin/printf '%s\n' 'section=POST_BUILD'
    /usr/bin/printf 'utc=%s\n' "${r24_now_value}"
    /usr/bin/printf '%s\n' 'recipe=r24-dev-bundle-v1'
    /usr/bin/printf '%s\n' 'debug_build_command=swift build --product AgentLoopApp'
    /usr/bin/printf '%s\n' 'debug_build_rc=0'
    /usr/bin/printf 'bin_dir=%s\n' "${r24_bin_dir}"
    /usr/bin/printf 'build_executable=%s\n' "${R24_BUILD_EXECUTABLE}"
    /usr/bin/printf 'build_resource_bundle=%s\n' "${R24_BUILD_RESOURCE_BUNDLE}"
    /usr/bin/printf 'build_executable_sha=%s\n' "${R24_BUILD_EXECUTABLE_SHA}"
    /usr/bin/printf '%s\n' 'build_uuid_set_begin'
    /usr/bin/printf '%s\n' "${R24_BUILD_UUID_SET}"
    /usr/bin/printf '%s\n' 'build_uuid_set_end'
    /usr/bin/printf '%s\n' 'source_ranch_art_regular_count=27'
    /usr/bin/printf 'source_ranch_art_manifest_sha=%s\n' "${R24_EXPECTED_RANCH_ART_MANIFEST_SHA}"
    /usr/bin/printf '%s\n' 'generated_ranch_art_regular_count=27'
    /usr/bin/printf 'generated_ranch_art_manifest_sha=%s\n' "${R24_EXPECTED_RANCH_ART_MANIFEST_SHA}"
    /usr/bin/printf 'generated_resource_manifest_sha=%s\n' "${r24_resource_manifest}"
    /usr/bin/printf '%s\n' 'status=PASS'
  } >> "${R24_BUNDLE_LOG}"

  R24_PHASE="bundle_assembly_pre_sign"
  R24_APP="${R24_BUNDLE_ROOT}/AgentLoop.app"
  R24_APP_EXECUTABLE="${R24_APP}/Contents/MacOS/AgentLoop"
  r24_require_absent_path "${R24_APP}"
  umask 022
  /bin/mkdir -p "${R24_APP}/Contents/MacOS" "${R24_APP}/Contents/Resources"
  /bin/cp "${R24_BUILD_EXECUTABLE}" "${R24_APP_EXECUTABLE}"
  /bin/cp -R "${R24_BUILD_RESOURCE_BUNDLE}" "${R24_APP}/Contents/Resources/"
  /bin/cat > "${R24_APP}/Contents/Info.plist" <<R24_PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>AgentLoop</string>
  <key>CFBundleIdentifier</key><string>${R24_BUNDLE_IDENTIFIER}</string>
  <key>CFBundleName</key><string>AgentLoop</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSEnvironment</key>
  <dict>
    <key>AGENTLOOP_STATE_DIR</key><string>${R24_STATE_ROOT}</string>
    <key>AGENTLOOP_UI_PREVIEW</key><string>1</string>
  </dict>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSMultipleInstancesProhibited</key><true/>
</dict>
</plist>
R24_PLIST
  umask 077
  r24_validate_app_tree "unsigned"
  if /usr/bin/cmp -s "${R24_BUILD_EXECUTABLE}" "${R24_APP_EXECUTABLE}"; then :; else r24_active_fail 70 "unsigned_executable_cmp_failed"; fi
  if /usr/bin/diff -qr "${R24_BUILD_RESOURCE_BUNDLE}" "${R24_APP}/Contents/Resources/AgentLoop_AgentLoopApp.bundle" >/dev/null; then :; else r24_active_fail 70 "unsigned_resource_diff_failed"; fi
  r24_validate_ranch_art_tree "${R24_APP}/Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt"
  if r24_copied_resource_manifest="$(r24_tree_manifest_sha "${R24_APP}/Contents/Resources/AgentLoop_AgentLoopApp.bundle")"; then :; else r24_active_fail 70 "copied_resource_manifest_failed"; fi
  [[ "${r24_copied_resource_manifest}" == "${r24_resource_manifest}" ]] || r24_active_fail 70 "copied_resource_manifest_mismatch"
  if /usr/bin/plutil -lint "${R24_APP}/Contents/Info.plist" >> "${R24_BUILD_LOG}" 2>&1; then :; else r24_active_fail 70 "info_plist_lint_failed"; fi
  if r24_info_sha="$(r24_sha "${R24_APP}/Contents/Info.plist")"; then :; else r24_active_fail 70 "info_plist_sha_failed"; fi
  R24_INFO_PLIST_SHA="${r24_info_sha}"
  if r24_plist_exec="$(/usr/bin/plutil -extract CFBundleExecutable raw -o - "${R24_APP}/Contents/Info.plist")"; then :; else r24_active_fail 70 "plist_executable_read_failed"; fi
  if r24_plist_identifier="$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "${R24_APP}/Contents/Info.plist")"; then :; else r24_active_fail 70 "plist_identifier_read_failed"; fi
  [[ "${r24_plist_exec}" == "AgentLoop" && "${r24_plist_identifier}" == "${R24_BUNDLE_IDENTIFIER}" ]] || r24_active_fail 70 "plist_identity_mismatch"
  if r24_ls_state="$(/usr/bin/plutil -extract LSEnvironment.AGENTLOOP_STATE_DIR raw -o - "${R24_APP}/Contents/Info.plist")"; then :; else r24_active_fail 70 "plist_ls_environment_state_read_failed"; fi
  if r24_ls_preview="$(/usr/bin/plutil -extract LSEnvironment.AGENTLOOP_UI_PREVIEW raw -o - "${R24_APP}/Contents/Info.plist")"; then :; else r24_active_fail 70 "plist_ls_environment_preview_read_failed"; fi
  [[ "${r24_ls_state}" == "${R24_STATE_ROOT}" ]] || r24_active_fail 70 "plist_ls_environment_state_mismatch"
  [[ "${r24_ls_preview}" == "1" ]] || r24_active_fail 70 "plist_ls_environment_preview_mismatch"
  if /usr/bin/python3 - "${R24_APP}/Contents/Info.plist" "${R24_BUNDLE_IDENTIFIER}" "${R24_STATE_ROOT}" <<'R24_PLIST_CHECK'
import plistlib
import sys

path, identifier, state_root = sys.argv[1:]
with open(path, "rb") as handle:
    value = plistlib.load(handle)
expected = {
    "CFBundleExecutable": "AgentLoop",
    "CFBundleIdentifier": identifier,
    "CFBundleName": "AgentLoop",
    "CFBundlePackageType": "APPL",
    "LSEnvironment": {
        "AGENTLOOP_STATE_DIR": state_root,
        "AGENTLOOP_UI_PREVIEW": "1",
    },
    "LSMinimumSystemVersion": "14.0",
    "LSMultipleInstancesProhibited": True,
    "NSHighResolutionCapable": True,
}
if value != expected:
    raise SystemExit(71)
if any(key.startswith("AGENTLOOP_BOARD_") for key in value["LSEnvironment"]):
    raise SystemExit(72)
R24_PLIST_CHECK
  then :; else r24_active_fail 70 "plist_exact_schema_failed"; fi
  if r24_unsigned_sha="$(r24_sha "${R24_APP_EXECUTABLE}")"; then :; else r24_active_fail 70 "unsigned_executable_sha_failed"; fi
  [[ "${r24_unsigned_sha}" == "${R24_BUILD_EXECUTABLE_SHA}" ]] || r24_active_fail 70 "unsigned_executable_sha_mismatch"
  if r24_unsigned_uuid="$(r24_uuid_set "${R24_APP_EXECUTABLE}")"; then :; else r24_active_fail 70 "unsigned_uuid_failed"; fi
  [[ "${r24_unsigned_uuid}" == "${R24_BUILD_UUID_SET}" ]] || r24_active_fail 70 "unsigned_uuid_mismatch"
  if r24_now_value="$(r24_capture_now)"; then :; else r24_active_fail 70 "pre_sign_timestamp_failed"; fi
  {
    /usr/bin/printf '%s\n' 'section=PRE_SIGN'
    /usr/bin/printf 'utc=%s\n' "${r24_now_value}"
    /usr/bin/printf 'bundle_parent=%s\n' "${R24_BUNDLE_ROOT}"
    /usr/bin/printf 'app=%s\n' "${R24_APP}"
    /usr/bin/printf 'app_executable=%s\n' "${R24_APP_EXECUTABLE}"
    /usr/bin/printf '%s\n' 'fresh_bundle_structure_exact=true'
    /usr/bin/printf '%s\n' 'unsigned_executable_cmp_build=true'
    /usr/bin/printf 'unsigned_executable_sha=%s\n' "${r24_unsigned_sha}"
    /usr/bin/printf '%s\n' 'unsigned_uuid_set_begin'
    /usr/bin/printf '%s\n' "${r24_unsigned_uuid}"
    /usr/bin/printf '%s\n' 'unsigned_uuid_set_end'
    /usr/bin/printf '%s\n' 'copied_resource_diff_equal=true'
    /usr/bin/printf 'copied_resource_manifest_sha=%s\n' "${r24_copied_resource_manifest}"
    /usr/bin/printf 'info_plist_sha=%s\n' "${r24_info_sha}"
    /usr/bin/printf 'CFBundleExecutable=%s\n' "${r24_plist_exec}"
    /usr/bin/printf 'CFBundleIdentifier=%s\n' "${r24_plist_identifier}"
    /usr/bin/printf 'LSEnvironment.AGENTLOOP_STATE_DIR=%s\n' "${R24_STATE_ROOT}"
    /usr/bin/printf '%s\n' 'LSEnvironment.AGENTLOOP_UI_PREVIEW=1'
    /usr/bin/printf '%s\n' 'status=PASS'
  } >> "${R24_BUNDLE_LOG}"

  R24_PHASE="bundle_sign_launch_ready"
  if /usr/bin/codesign --force --sign - "${R24_APP}" >> "${R24_BUILD_LOG}" 2>&1; then :; else r24_active_fail 70 "codesign_sign_failed"; fi
  if /usr/bin/codesign --verify --deep --strict --verbose=4 "${R24_APP}" >> "${R24_BUILD_LOG}" 2>&1; then :; else r24_active_fail 70 "codesign_verify_failed"; fi
  if r24_signature_detail="$(/usr/bin/codesign --display --verbose=4 "${R24_APP}" 2>&1)"; then :; else r24_active_fail 70 "codesign_display_failed"; fi
  [[ "${r24_signature_detail}" == *$'Signature=adhoc'* ]] || r24_active_fail 70 "signature_not_adhoc"
  [[ "${r24_signature_detail}" == *"Identifier=${R24_BUNDLE_IDENTIFIER}"* ]] || r24_active_fail 70 "signature_identifier_mismatch"
  [[ "${r24_signature_detail}" == *$'TeamIdentifier=not set'* ]] || r24_active_fail 70 "signature_team_identifier_present_or_unknown"
  [[ "${r24_signature_detail}" != *'Developer ID'* ]] || r24_active_fail 70 "developer_id_present"
  if r24_entitlements="$(/usr/bin/codesign --display --entitlements :- "${R24_APP}" 2>&1)"; then :; else r24_active_fail 70 "codesign_entitlements_read_failed"; fi
  [[ "${r24_entitlements}" != *'com.apple.security.app-sandbox'* ]] || r24_active_fail 70 "app_sandbox_entitlement_present"
  r24_require_absent_path "${R24_APP}/Contents/embedded.provisionprofile"
  r24_validate_app_tree "signed"
  if r24_app_real="$(r24_canonical_directory "${R24_APP}")"; then :; else r24_active_fail 70 "signed_app_canonicalization_failed"; fi
  if r24_exec_real="$(r24_canonical_file "${R24_APP_EXECUTABLE}")"; then :; else r24_active_fail 70 "signed_exec_canonicalization_failed"; fi
  [[ "${r24_app_real}" == "${R24_APP}" && "${r24_exec_real}" == "${R24_APP_EXECUTABLE}" ]] || r24_active_fail 70 "signed_path_canonical_mismatch"
  if R24_SIGNED_EXECUTABLE_SHA="$(r24_sha "${R24_APP_EXECUTABLE}")"; then :; else r24_active_fail 70 "signed_executable_sha_failed"; fi
  if R24_SIGNED_UUID_SET="$(r24_uuid_set "${R24_APP_EXECUTABLE}")"; then :; else r24_active_fail 70 "signed_uuid_failed"; fi
  [[ "${R24_SIGNED_UUID_SET}" == "${R24_BUILD_UUID_SET}" ]] || r24_active_fail 70 "signed_uuid_mismatch"
  if R24_SIGNED_BUNDLE_MANIFEST_SHA="$(r24_tree_manifest_sha "${R24_APP}")"; then :; else r24_active_fail 70 "signed_bundle_manifest_failed"; fi
  if /usr/bin/diff -qr "${R24_BUILD_RESOURCE_BUNDLE}" "${R24_APP}/Contents/Resources/AgentLoop_AgentLoopApp.bundle" >/dev/null; then :; else r24_active_fail 70 "signed_resource_diff_failed"; fi
  if r24_cdhash="$(/usr/bin/awk -F= '$1 == "CDHash" { print $2 }' <<< "${r24_signature_detail}")"; then :; else r24_active_fail 70 "cdhash_parse_failed"; fi
  [[ -n "${r24_cdhash}" && "${r24_cdhash}" != *$'\n'* ]] || r24_active_fail 70 "cdhash_not_unique"
  R24_SIGNED_CDHASH="${r24_cdhash}"
  r24_require_no_process
  if r24_now_value="$(r24_capture_now)"; then :; else r24_active_fail 70 "launch_ready_timestamp_failed"; fi
  {
    /usr/bin/printf '%s\n' 'section=LAUNCH_READY'
    /usr/bin/printf 'utc=%s\n' "${r24_now_value}"
    /usr/bin/printf 'app=%s\n' "${R24_APP}"
    /usr/bin/printf 'executable=%s\n' "${R24_APP_EXECUTABLE}"
    /usr/bin/printf '%s\n' 'signature=adhoc'
    /usr/bin/printf 'identifier=%s\n' "${R24_BUNDLE_IDENTIFIER}"
    /usr/bin/printf '%s\n' 'team_identifier=not_set'
    /usr/bin/printf '%s\n' 'developer_id_present=false'
    /usr/bin/printf '%s\n' 'entitlement_plist_present=false'
    /usr/bin/printf '%s\n' 'app_sandbox_entitlement_present=false'
    /usr/bin/printf 'post_sign_executable_sha=%s\n' "${R24_SIGNED_EXECUTABLE_SHA}"
    /usr/bin/printf '%s\n' 'post_sign_uuid_set_begin'
    /usr/bin/printf '%s\n' "${R24_SIGNED_UUID_SET}"
    /usr/bin/printf '%s\n' 'post_sign_uuid_set_end'
    /usr/bin/printf 'cdhash=%s\n' "${r24_cdhash}"
    /usr/bin/printf 'signed_bundle_manifest_sha=%s\n' "${R24_SIGNED_BUNDLE_MANIFEST_SHA}"
    /usr/bin/printf '%s\n' 'resources_equal_build=true'
    /usr/bin/printf '%s\n' 'process_count=0'
    /usr/bin/printf '%s\n' 'status=PASS'
  } >> "${R24_BUNDLE_LOG}"
  r24_require_verify_log_identity "post_launch_ready"
  R24_CURRENT_ROOT_PHASE="bundle_ready"
  r24_append_boundary 'launch_ready=true'
}

r24_run_guard_shape_and_strip() {
  local r24_core_shape=""
  local r24_test_shape=""
  local r24_strip_sha=""
  local r24_strip_output=""
  local r24_now_value=""
  R24_PHASE="guard_shape_and_strip"
  if r24_core_shape="$(/usr/bin/awk '
      /^#(if|elseif|else|endif)/ {
        if ($0 == "#if DEBUG" && depth == 0) { depth = 1; opens += 1; next }
        if ($0 == "#endif" && depth == 1) { depth = 0; closes += 1; next }
        bad += 1
      }
      index($0, "idleClockForTesting") { token += 1; if (depth == 1) guarded += 1 }
      END { print opens ":" closes ":" bad ":" depth ":" token ":" guarded }
    ' "${R24_CORE_PATH}")"; then :; else r24_active_fail 70 "core_guard_parser_failed"; fi
  [[ "${r24_core_shape}" == "1:1:0:0:1:1" ]] || r24_active_fail 70 "core_guard_shape_${r24_core_shape}"
  if r24_test_shape="$(/usr/bin/awk '
      BEGIN {
        split("ManualAgentLoopClock|ControlledIdleProviderError|ControlledIdleProvider|AgentEventProbe|OneShotGate|startControlledLoop|turnTimeoutRetriesOnceThenBlocks|cancelWinsOverIdleTimeout|timeoutThenSuccessDoesNotAccumulate|slowActiveStreamDoesNotIdleTimeout|turnCompletesUnderTimeout", tokens, "|")
      }
      /^#(if|elseif|else|endif)/ {
        directives += 1
        if ($0 == "#if DEBUG" && depth == 0) { depth = 1; opens += 1; next }
        if ($0 == "#endif" && depth == 1) { depth = 0; closes += 1; next }
        bad += 1
      }
      {
        for (i = 1; i <= 11; i += 1) {
          if (index($0, tokens[i])) { total[i] += 1; if (depth == 1) guarded[i] += 1 }
        }
      }
      END {
        ok = (opens == 3 && closes == 3 && directives == 6 && bad == 0 && depth == 0)
        for (i = 1; i <= 11; i += 1) if (total[i] < 1 || total[i] != guarded[i]) ok = 0
        print opens ":" closes ":" directives ":" bad ":" depth ":" ok
      }
    ' "${R24_TEST_PATH}")"; then :; else r24_active_fail 70 "test_guard_parser_failed"; fi
  [[ "${r24_test_shape}" == "3:3:6:0:0:1" ]] || r24_active_fail 70 "test_guard_shape_${r24_test_shape}"
  if r24_strip_output="$(/usr/bin/awk '
      (NR == 90 || NR == 643 || NR == 1007) { if ($0 != "#if DEBUG") exit 71; next }
      (NR == 603 || NR == 695 || NR == 1253) { if ($0 != "#endif") exit 72; next }
      { print }
    ' "${R24_TEST_PATH}")"; then :; else r24_active_fail 70 "test_guard_strip_failed"; fi
  if r24_strip_sha="$(/usr/bin/python3 -c 'import hashlib, sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())' <<< "${r24_strip_output}")"; then :; else r24_active_fail 70 "test_guard_strip_sha_failed"; fi
  [[ "${r24_strip_sha}" == "${R24_EXPECTED_R20_TEST_SHA}" ]] || r24_active_fail 70 "test_guard_strip_hash_${r24_strip_sha}"
  if r24_now_value="$(r24_capture_now)"; then :; else r24_active_fail 70 "guard_shape_timestamp_failed"; fi
  {
    /usr/bin/printf '%s\n' 'section=R21_GUARD_SHAPE_AND_STRIP'
    /usr/bin/printf 'utc=%s\n' "${r24_now_value}"
    /usr/bin/printf 'core_guard_shape=%s\n' "${r24_core_shape}"
    /usr/bin/printf 'test_guard_shape=%s\n' "${r24_test_shape}"
    /usr/bin/printf 'test_stripped_sha=%s\n' "${r24_strip_sha}"
    /usr/bin/printf '%s\n' 'test_stripped_matches_r20=true'
    /usr/bin/printf '%s\n' 'status=PASS'
  } >> "${R24_SOURCE_LOG}"
}

r24_require_exact_object() {
  local r24_object="$1"
  local r24_expected_parent="$2"
  local r24_parent="${r24_object%/*}"
  local r24_parent_real=""
  local r24_object_real=""
  [[ -d "${r24_parent}" && ! -L "${r24_parent}" ]] || r24_active_fail 70 "object_parent_not_real_${r24_object}"
  if r24_parent_real="$(r24_canonical_directory "${r24_parent}")"; then :; else r24_active_fail 70 "object_parent_canonical_failed_${r24_object}"; fi
  [[ "${r24_parent_real}" == "${r24_expected_parent}" ]] || r24_active_fail 70 "object_parent_mismatch_${r24_object}"
  r24_require_regular_file "${r24_object}"
  if r24_object_real="$(r24_canonical_file "${r24_object}")"; then :; else r24_active_fail 70 "object_canonical_failed_${r24_object}"; fi
  [[ "${r24_object_real}" == "${r24_object}" ]] || r24_active_fail 70 "object_canonical_mismatch_${r24_object}"
}

r24_demangle_object() {
  local r24_object="$1"
  local r24_output=""
  if r24_output="$({
      if /usr/bin/nm -j "${r24_object}" | /usr/bin/xcrun swift-demangle; then
        r24_status=("${PIPESTATUS[@]}")
      else
        r24_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r24_status[@]}" == "2" ]] || exit 71
      [[ "${r24_status[0]}" == "0" && "${r24_status[1]}" == "0" ]] || exit 72
    })"; then
    :
  else
    return "$?"
  fi
  [[ -n "${r24_output}" ]] || return 73
  /usr/bin/printf '%s\n' "${r24_output}"
}

r24_run_release_and_object_gates() {
  local r24_release_status=()
  local r24_release_bin=""
  local r24_release_real=""
  local r24_debug_bin=""
  local r24_debug_real=""
  local r24_release_component=""
  local r24_debug_component=""
  local r24_release_core_object=""
  local r24_release_test_object=""
  local r24_debug_core_object=""
  local r24_debug_test_object=""
  local r24_core_object_sha_before=""
  local r24_core_object_sha_after=""
  local r24_release_core_symbols=""
  local r24_release_test_symbols=""
  local r24_debug_core_symbols=""
  local r24_debug_test_symbols=""
  local r24_count=""
  local r24_token=""
  local r24_now_value=""

  R24_PHASE="release_core_target"
  if /usr/bin/swift build -c release --target AgentLoopCore 2>&1 | /usr/bin/tee -a "${R24_BUILD_LOG}"; then
    r24_release_status=("${PIPESTATUS[@]}")
  else
    r24_release_status=("${PIPESTATUS[@]}")
  fi
  [[ "${#r24_release_status[@]}" == "2" && "${r24_release_status[0]}" == "0" && "${r24_release_status[1]}" == "0" ]] || r24_active_fail 70 "release_core_target_failed"
  if r24_release_bin="$(/usr/bin/swift build -c release --show-bin-path)"; then :; else r24_active_fail 70 "release_bin_path_query_failed"; fi
  if r24_debug_bin="$(/usr/bin/swift build -c debug --show-bin-path)"; then :; else r24_active_fail 70 "debug_bin_path_requery_failed"; fi
  [[ -d "${r24_release_bin}" && ! -L "${r24_release_bin}" && -d "${r24_debug_bin}" && ! -L "${r24_debug_bin}" ]] || r24_active_fail 70 "bin_path_not_real_directory"
  if r24_release_real="$(r24_canonical_directory "${r24_release_bin}")"; then :; else r24_active_fail 70 "release_bin_canonical_failed"; fi
  if r24_debug_real="$(r24_canonical_directory "${r24_debug_bin}")"; then :; else r24_active_fail 70 "debug_bin_canonical_failed"; fi
  [[ "${r24_release_real}" == "${r24_release_bin}" && "${r24_debug_real}" == "${r24_debug_bin}" ]] || r24_active_fail 70 "bin_path_canonical_mismatch"
  case "${r24_release_bin}" in "${R24_REPOSITORY_ROOT}/.build/"*/release) ;; *) r24_active_fail 70 "release_bin_layout" ;; esac
  case "${r24_debug_bin}" in "${R24_REPOSITORY_ROOT}/.build/"*/debug) ;; *) r24_active_fail 70 "debug_bin_layout_requery" ;; esac
  r24_release_component="${r24_release_bin#${R24_REPOSITORY_ROOT}/.build/}"; r24_release_component="${r24_release_component%/release}"
  r24_debug_component="${r24_debug_bin#${R24_REPOSITORY_ROOT}/.build/}"; r24_debug_component="${r24_debug_component%/debug}"
  [[ -n "${r24_release_component}" && "${r24_release_component}" != */* && "${r24_release_component}" == "${r24_debug_component}" ]] || r24_active_fail 70 "bin_component_mismatch"
  r24_release_core_object="${r24_release_bin}/AgentLoopCore.build/AgentLoop.swift.o"
  r24_release_test_object="${r24_release_bin}/AgentLoopTestSuite.build/AgentLoopTests.swift.o"
  r24_debug_core_object="${r24_debug_bin}/AgentLoopCore.build/AgentLoop.swift.o"
  r24_debug_test_object="${r24_debug_bin}/AgentLoopTestSuite.build/AgentLoopTests.swift.o"
  r24_require_exact_object "${r24_release_core_object}" "${r24_release_bin}/AgentLoopCore.build"
  if r24_core_object_sha_before="$(r24_sha "${r24_release_core_object}")"; then :; else r24_active_fail 70 "release_core_object_sha_before_failed"; fi

  R24_PHASE="release_test_target"
  if /usr/bin/swift build -c release --target AgentLoopTestSuite 2>&1 | /usr/bin/tee -a "${R24_BUILD_LOG}"; then
    r24_release_status=("${PIPESTATUS[@]}")
  else
    r24_release_status=("${PIPESTATUS[@]}")
  fi
  [[ "${#r24_release_status[@]}" == "2" && "${r24_release_status[0]}" == "0" && "${r24_release_status[1]}" == "0" ]] || r24_active_fail 70 "release_test_target_failed"
  r24_require_exact_object "${r24_release_core_object}" "${r24_release_bin}/AgentLoopCore.build"
  r24_require_exact_object "${r24_release_test_object}" "${r24_release_bin}/AgentLoopTestSuite.build"
  r24_require_exact_object "${r24_debug_core_object}" "${r24_debug_bin}/AgentLoopCore.build"
  r24_require_exact_object "${r24_debug_test_object}" "${r24_debug_bin}/AgentLoopTestSuite.build"
  if r24_core_object_sha_after="$(r24_sha "${r24_release_core_object}")"; then :; else r24_active_fail 70 "release_core_object_sha_after_failed"; fi
  [[ "${r24_core_object_sha_after}" == "${r24_core_object_sha_before}" ]] || r24_active_fail 70 "release_core_object_replaced_by_test_target"
  if r24_release_core_symbols="$(r24_demangle_object "${r24_release_core_object}")"; then :; else r24_active_fail 70 "release_core_nm_failed"; fi
  if r24_release_test_symbols="$(r24_demangle_object "${r24_release_test_object}")"; then :; else r24_active_fail 70 "release_test_nm_failed"; fi
  if r24_debug_core_symbols="$(r24_demangle_object "${r24_debug_core_object}")"; then :; else r24_active_fail 70 "debug_core_nm_failed"; fi
  if r24_debug_test_symbols="$(r24_demangle_object "${r24_debug_test_object}")"; then :; else r24_active_fail 70 "debug_test_nm_failed"; fi
  if r24_count="$(/usr/bin/awk -v token='idleClockForTesting' 'index($0, token) { count += 1 } END { print count + 0 }' <<< "${r24_release_core_symbols}")"; then :; else r24_active_fail 70 "release_core_token_count_failed"; fi
  [[ "${r24_count}" == "0" ]] || r24_active_fail 70 "release_core_idle_clock_symbol_count_${r24_count}"
  if r24_count="$(/usr/bin/awk -v token='idleClockForTesting' 'index($0, token) { count += 1 } END { print count + 0 }' <<< "${r24_debug_core_symbols}")"; then :; else r24_active_fail 70 "debug_core_token_count_failed"; fi
  [[ "${r24_count}" -gt "0" ]] || r24_active_fail 70 "debug_core_idle_clock_symbol_absent"
  R24_OBJECT_TEST_TOKENS=(ManualAgentLoopClock ControlledIdleProviderError ControlledIdleProvider AgentEventProbe OneShotGate startControlledLoop turnTimeoutRetriesOnceThenBlocks cancelWinsOverIdleTimeout timeoutThenSuccessDoesNotAccumulate slowActiveStreamDoesNotIdleTimeout turnCompletesUnderTimeout)
  for r24_token in "${R24_OBJECT_TEST_TOKENS[@]}"; do
    if r24_count="$(/usr/bin/awk -v token="${r24_token}" 'index($0, token) { count += 1 } END { print count + 0 }' <<< "${r24_release_test_symbols}")"; then :; else r24_active_fail 70 "release_test_token_count_failed_${r24_token}"; fi
    [[ "${r24_count}" == "0" ]] || r24_active_fail 70 "release_test_token_present_${r24_token}_${r24_count}"
    if r24_count="$(/usr/bin/awk -v token="${r24_token}" 'index($0, token) { count += 1 } END { print count + 0 }' <<< "${r24_debug_test_symbols}")"; then :; else r24_active_fail 70 "debug_test_token_count_failed_${r24_token}"; fi
    [[ "${r24_count}" -gt "0" ]] || r24_active_fail 70 "debug_test_token_absent_${r24_token}"
  done
  if r24_now_value="$(r24_capture_now)"; then :; else r24_active_fail 70 "object_gate_timestamp_failed"; fi
  {
    /usr/bin/printf '%s\n' 'section=RELEASE_DEBUG_OBJECT_GATES'
    /usr/bin/printf 'utc=%s\n' "${r24_now_value}"
    /usr/bin/printf 'release_bin=%s\n' "${r24_release_bin}"
    /usr/bin/printf 'debug_bin=%s\n' "${r24_debug_bin}"
    /usr/bin/printf 'release_core_object=%s\n' "${r24_release_core_object}"
    /usr/bin/printf 'release_test_object=%s\n' "${r24_release_test_object}"
    /usr/bin/printf 'debug_core_object=%s\n' "${r24_debug_core_object}"
    /usr/bin/printf 'debug_test_object=%s\n' "${r24_debug_test_object}"
    /usr/bin/printf 'release_core_object_sha=%s\n' "${r24_core_object_sha_after}"
    /usr/bin/printf '%s\n' 'release_core_idleClockForTesting_count=0'
    /usr/bin/printf '%s\n' 'debug_core_idleClockForTesting_count_gt_zero=true'
    /usr/bin/printf '%s\n' 'release_test_11_token_counts_zero=true'
    /usr/bin/printf '%s\n' 'debug_test_11_token_counts_gt_zero=true'
    /usr/bin/printf '%s\n' 'status=PASS'
  } >> "${R24_SOURCE_LOG}"
}

r24_require_matrix_window_manifest() {
  local r24_record=""
  local r24_expected=""
  local r24_path=""
  local r24_actual=""
  local r24_pass=0
  local r24_mismatch=0
  while IFS= read -r r24_record; do
    r24_expected="${r24_record%%  *}"
    r24_path="${r24_record#*  }"
    [[ "${r24_expected}" != "${r24_record}" ]] || r24_active_fail 70 "matrix_window_manifest_parse_failed"
    if r24_actual="$(r24_sha "${r24_path}")"; then :; else r24_active_fail 70 "matrix_window_sha_failed_${r24_path}"; fi
    if [[ "${r24_actual}" == "${r24_expected}" ]]; then
      r24_pass=$((r24_pass + 1))
    else
      [[ "${r24_path}" == "${R24_MATRIX_SCRIPT}" ]] || r24_active_fail 70 "matrix_window_unexpected_mismatch_${r24_path}"
      r24_mismatch=$((r24_mismatch + 1))
    fi
  done < "${R24_MANIFEST_PATH}"
  [[ "${r24_pass}" == "177" && "${r24_mismatch}" == "1" ]] || r24_active_fail 70 "matrix_window_partition_${r24_pass}_${r24_mismatch}"
}

r24_run_matrix_with_mandatory_restore() {
  local r24_stage_sha=""
  local r24_stage_line_count=""
  local r24_matrix_mode=""
  local r24_mutated_sha=""
  local r24_matrix_status=()
  local r24_restore_rc=0
  local r24_now_value=""
  local r24_mutated_mode=""
  R24_PHASE="matrix_pre_mutation"
  r24_require_manifest
  r24_require_sha "${R24_EXPECTED_MATRIX_ENTRY_SHA}" "${R24_MATRIX_SCRIPT}"
  if r24_matrix_mode="$(/usr/bin/stat -f '%Lp' "${R24_MATRIX_SCRIPT}")"; then :; else r24_active_fail 70 "matrix_mode_read_failed"; fi
  [[ "${r24_matrix_mode}" == "755" ]] || r24_active_fail 70 "matrix_entry_mode_${r24_matrix_mode}"
  if r24_stage_sha="$(/usr/bin/awk -v expected="${R24_STAGE_PATH}" 'substr($0, 67) == expected { print substr($0, 1, 64) }' "${R24_MANIFEST_PATH}")"; then :; else r24_active_fail 70 "matrix_stage_manifest_sha_read_failed"; fi
  r24_require_sha_literal "matrix_stage_manifest" "${r24_stage_sha}"
  r24_require_sha "${r24_stage_sha}" "${R24_STAGE_PATH}"
  if r24_stage_line_count="$(/usr/bin/awk '$0 == "expected_stage_hash=\"a8ca6e7a56a32e945bae185724a51d4e0015d61676bf02d9637fedc2c27d9b6f\"" { count += 1; line = NR } END { print count ":" line }' "${R24_MATRIX_SCRIPT}")"; then :; else r24_active_fail 70 "matrix_stage_line_scan_failed"; fi
  [[ "${r24_stage_line_count}" == "1:115" ]] || r24_active_fail 70 "matrix_stage_line_shape_${r24_stage_line_count}"
  R24_MATRIX_BACKUP_PATH="${R24_STATE_ROOT}/r24-matrix-entry.backup"
  R24_MATRIX_MUTATED_STAGE="${R24_REPOSITORY_ROOT}/scripts/.${R24_INVOCATION_ID}.matrix-mutated.stage"
  R24_MATRIX_RESTORE_STAGE="${R24_REPOSITORY_ROOT}/scripts/.${R24_INVOCATION_ID}.matrix-restore.stage"
  r24_require_absent_path "${R24_MATRIX_BACKUP_PATH}"
  r24_require_absent_path "${R24_MATRIX_MUTATED_STAGE}"
  r24_require_absent_path "${R24_MATRIX_RESTORE_STAGE}"
  R24_DEFERRED_SIGNAL=""
  R24_DEFERRED_SIGNAL_STATUS=""
  trap 'r24_defer_signal HUP 129' HUP
  trap 'r24_defer_signal INT 130' INT
  trap 'r24_defer_signal TERM 143' TERM
  if r24_exclusive_create_empty "${R24_MATRIX_BACKUP_PATH}"; then
    R24_MATRIX_BACKUP_OWNED="true"
  else
    r24_install_signal_traps
    r24_active_fail 70 "matrix_backup_exclusive_create_failed"
  fi
  r24_install_signal_traps
  if [[ -n "${R24_DEFERRED_SIGNAL}" ]]; then r24_active_fail "${R24_DEFERRED_SIGNAL_STATUS}" "deferred_signal_${R24_DEFERRED_SIGNAL}_matrix_backup_create"; fi
  /bin/cp -p "${R24_MATRIX_SCRIPT}" "${R24_MATRIX_BACKUP_PATH}"
  r24_require_sha "${R24_EXPECTED_MATRIX_ENTRY_SHA}" "${R24_MATRIX_BACKUP_PATH}"
  R24_DEFERRED_SIGNAL=""
  R24_DEFERRED_SIGNAL_STATUS=""
  trap 'r24_defer_signal HUP 129' HUP
  trap 'r24_defer_signal INT 130' INT
  trap 'r24_defer_signal TERM 143' TERM
  if r24_exclusive_create_empty "${R24_MATRIX_MUTATED_STAGE}"; then
    R24_MATRIX_MUTATED_STAGE_OWNED="true"
  else
    r24_install_signal_traps
    r24_active_fail 70 "matrix_mutated_stage_exclusive_create_failed"
  fi
  r24_install_signal_traps
  if [[ -n "${R24_DEFERRED_SIGNAL}" ]]; then r24_active_fail "${R24_DEFERRED_SIGNAL_STATUS}" "deferred_signal_${R24_DEFERRED_SIGNAL}_matrix_mutated_stage_create"; fi
  if /usr/bin/awk -v new_sha="${r24_stage_sha}" '
      NR == 115 {
        if ($0 != "expected_stage_hash=\"a8ca6e7a56a32e945bae185724a51d4e0015d61676bf02d9637fedc2c27d9b6f\"") exit 71
        print "expected_stage_hash=\"" new_sha "\""
        changed += 1
        next
      }
      { print }
      END { if (changed != 1) exit 72 }
    ' "${R24_MATRIX_SCRIPT}" > "${R24_MATRIX_MUTATED_STAGE}"; then :; else r24_active_fail 70 "matrix_single_line_rewrite_failed"; fi
  /bin/chmod 755 "${R24_MATRIX_MUTATED_STAGE}"
  r24_require_regular_file "${R24_MATRIX_MUTATED_STAGE}"
  if r24_mutated_sha="$(r24_sha "${R24_MATRIX_MUTATED_STAGE}")"; then :; else r24_active_fail 70 "matrix_mutated_stage_sha_failed"; fi
  [[ "${r24_mutated_sha}" != "${R24_EXPECTED_MATRIX_ENTRY_SHA}" ]] || r24_active_fail 70 "matrix_mutated_stage_unchanged"
  if r24_mutated_mode="$(/usr/bin/stat -f '%Lp' "${R24_MATRIX_MUTATED_STAGE}")"; then :; else r24_active_fail 70 "matrix_mutated_stage_mode_failed"; fi
  [[ "${r24_mutated_mode}" == "755" ]] || r24_active_fail 70 "matrix_mutated_stage_mode_${r24_mutated_mode}"
  R24_DEFERRED_SIGNAL=""
  R24_DEFERRED_SIGNAL_STATUS=""
  trap 'r24_defer_signal HUP 129' HUP
  trap 'r24_defer_signal INT 130' INT
  trap 'r24_defer_signal TERM 143' TERM
  R24_MATRIX_MUTATED="true"
  if /bin/mv -f "${R24_MATRIX_MUTATED_STAGE}" "${R24_MATRIX_SCRIPT}"; then :; else r24_install_signal_traps; r24_active_fail 70 "matrix_mutated_publish_failed"; fi
  R24_MATRIX_MUTATED_STAGE_OWNED="false"
  r24_install_signal_traps
  if [[ -n "${R24_DEFERRED_SIGNAL}" ]]; then r24_active_fail "${R24_DEFERRED_SIGNAL_STATUS}" "deferred_signal_${R24_DEFERRED_SIGNAL}_matrix_publish"; fi
  if [[ -e "${R24_MATRIX_MUTATED_STAGE}" || -L "${R24_MATRIX_MUTATED_STAGE}" ]]; then r24_active_fail 70 "matrix_mutated_stage_survived_publish"; fi
  if r24_mutated_sha="$(r24_sha "${R24_MATRIX_SCRIPT}")"; then :; else r24_active_fail 70 "matrix_mutated_sha_failed"; fi
  if r24_stage_line_count="$(/usr/bin/awk -v expected="expected_stage_hash=\"${r24_stage_sha}\"" '$0 == expected { count += 1; line = NR } END { print count ":" line }' "${R24_MATRIX_SCRIPT}")"; then :; else r24_active_fail 70 "matrix_mutated_line_scan_failed"; fi
  [[ "${r24_stage_line_count}" == "1:115" ]] || r24_active_fail 70 "matrix_mutated_line_shape_${r24_stage_line_count}"
  r24_require_matrix_window_manifest
  R24_PHASE="migration_matrix"
  if "${R24_MATRIX_SCRIPT}" --sqlite 3.51 --sqlite 3.52 2>&1 | /usr/bin/tee -a "${R24_MATRIX_LOG}"; then
    r24_matrix_status=("${PIPESTATUS[@]}")
  else
    r24_matrix_status=("${PIPESTATUS[@]}")
  fi
  R24_PHASE="matrix_mandatory_restore"
  R24_DEFERRED_SIGNAL=""
  R24_DEFERRED_SIGNAL_STATUS=""
  trap 'r24_defer_signal HUP 129' HUP
  trap 'r24_defer_signal INT 130' INT
  trap 'r24_defer_signal TERM 143' TERM
  if r24_restore_matrix_containment; then
    r24_restore_rc=0
  else
    r24_restore_rc="$?"
  fi
  r24_install_signal_traps
  [[ "${r24_restore_rc}" == "0" ]] || r24_active_fail 70 "matrix_restore_failed_${r24_restore_rc}"
  if [[ -n "${R24_DEFERRED_SIGNAL}" ]]; then r24_active_fail "${R24_DEFERRED_SIGNAL_STATUS}" "deferred_signal_${R24_DEFERRED_SIGNAL}_matrix_restore"; fi
  [[ "${#r24_matrix_status[@]}" == "2" ]] || r24_active_fail 70 "matrix_status_shape"
  [[ "${r24_matrix_status[0]}" == "0" && "${r24_matrix_status[1]}" == "0" ]] || r24_active_fail 70 "matrix_failed_${r24_matrix_status[0]}_${r24_matrix_status[1]}"
  r24_require_sha "${R24_EXPECTED_MATRIX_ENTRY_SHA}" "${R24_MATRIX_SCRIPT}"
  [[ "${R24_MATRIX_MUTATED}" == "false" ]] || r24_active_fail 70 "matrix_mutated_flag_after_restore"
  [[ "${R24_MATRIX_BACKUP_OWNED}" == "false" && "${R24_MATRIX_MUTATED_STAGE_OWNED}" == "false" && "${R24_MATRIX_RESTORE_STAGE_OWNED}" == "false" ]] || r24_active_fail 70 "matrix_owned_flags_after_restore"
  r24_require_absent_path "${R24_MATRIX_BACKUP_PATH}"
  r24_require_absent_path "${R24_MATRIX_MUTATED_STAGE}"
  r24_require_absent_path "${R24_MATRIX_RESTORE_STAGE}"
  r24_require_manifest
  r24_require_exact_line_once "${R24_MATRIX_LOG}" 'p1_migration_matrix.result=pass'
  if r24_now_value="$(r24_capture_now)"; then :; else r24_active_fail 70 "matrix_timestamp_failed"; fi
  {
    /usr/bin/printf '%s\n' 'section=R24_MATRIX_WINDOW'
    /usr/bin/printf 'utc=%s\n' "${r24_now_value}"
    /usr/bin/printf 'stage_sha=%s\n' "${r24_stage_sha}"
    /usr/bin/printf 'temporary_matrix_sha=%s\n' "${r24_mutated_sha}"
    /usr/bin/printf '%s\n' 'window_manifest_partition=177_PASS_1_MATRIX_SCRIPT_MISMATCH'
    /usr/bin/printf 'restored_matrix_sha=%s\n' "${R24_EXPECTED_MATRIX_ENTRY_SHA}"
    /usr/bin/printf '%s\n' 'matrix_mutated_after_restore=false'
    /usr/bin/printf '%s\n' 'status=PASS'
  } >> "${R24_SOURCE_LOG}"
  r24_append_boundary 'migration_matrix=PASS'
  r24_append_boundary 'matrix_restored=true'
}

r24_require_launch_ready_identity() {
  local r24_label="$1"
  local r24_info_sha=""
  local r24_signature_detail=""
  local r24_cdhash=""
  local r24_post_build_count=""
  local r24_pre_sign_count=""
  local r24_launch_ready_count=""
  [[ "${R24_CURRENT_ROOT_PHASE}" == "bundle_ready" || "${R24_CURRENT_ROOT_PHASE}" == "preview_live" || "${R24_CURRENT_ROOT_PHASE}" == "preview_quiescent" ]] || r24_active_fail 70 "launch_ready_wrong_root_phase_${r24_label}_${R24_CURRENT_ROOT_PHASE}"
  [[ "${R24_APP}" == "${R24_BUNDLE_ROOT}/AgentLoop.app" ]] || r24_active_fail 70 "launch_ready_app_identity_${r24_label}"
  [[ "${R24_APP_EXECUTABLE}" == "${R24_APP}/Contents/MacOS/AgentLoop" ]] || r24_active_fail 70 "launch_ready_exec_identity_${r24_label}"
  r24_validate_bundle_root_ready
  if r24_info_sha="$(r24_sha "${R24_APP}/Contents/Info.plist")"; then :; else r24_active_fail 70 "launch_ready_info_sha_failed_${r24_label}"; fi
  [[ "${r24_info_sha}" == "${R24_INFO_PLIST_SHA}" ]] || r24_active_fail 70 "launch_ready_info_sha_drift_${r24_label}"
  if /usr/bin/python3 - "${R24_APP}/Contents/Info.plist" "${R24_BUNDLE_IDENTIFIER}" "${R24_STATE_ROOT}" <<'R24_LAUNCH_PLIST_CHECK'
import plistlib
import sys

path, identifier, state_root = sys.argv[1:]
with open(path, "rb") as handle:
    value = plistlib.load(handle)
expected = {
    "CFBundleExecutable": "AgentLoop",
    "CFBundleIdentifier": identifier,
    "CFBundleName": "AgentLoop",
    "CFBundlePackageType": "APPL",
    "LSEnvironment": {"AGENTLOOP_STATE_DIR": state_root, "AGENTLOOP_UI_PREVIEW": "1"},
    "LSMinimumSystemVersion": "14.0",
    "LSMultipleInstancesProhibited": True,
    "NSHighResolutionCapable": True,
}
raise SystemExit(0 if value == expected else 71)
R24_LAUNCH_PLIST_CHECK
  then :; else r24_active_fail 70 "launch_ready_plist_schema_drift_${r24_label}"; fi
  if r24_signature_detail="$(/usr/bin/codesign --display --verbose=4 "${R24_APP}" 2>&1)"; then :; else r24_active_fail 70 "launch_ready_codesign_display_failed_${r24_label}"; fi
  [[ "${r24_signature_detail}" == *$'Signature=adhoc'* && "${r24_signature_detail}" == *"Identifier=${R24_BUNDLE_IDENTIFIER}"* && "${r24_signature_detail}" == *$'TeamIdentifier=not set'* ]] || r24_active_fail 70 "launch_ready_signature_drift_${r24_label}"
  if r24_cdhash="$(/usr/bin/awk -F= '$1 == "CDHash" { print $2 }' <<< "${r24_signature_detail}")"; then :; else r24_active_fail 70 "launch_ready_cdhash_parse_failed_${r24_label}"; fi
  [[ "${r24_cdhash}" == "${R24_SIGNED_CDHASH}" ]] || r24_active_fail 70 "launch_ready_cdhash_drift_${r24_label}"
  if r24_post_build_count="$(r24_exact_line_count "${R24_BUNDLE_LOG}" 'section=POST_BUILD')"; then :; else r24_active_fail 70 "post_build_section_read_failed_${r24_label}"; fi
  if r24_pre_sign_count="$(r24_exact_line_count "${R24_BUNDLE_LOG}" 'section=PRE_SIGN')"; then :; else r24_active_fail 70 "pre_sign_section_read_failed_${r24_label}"; fi
  if r24_launch_ready_count="$(r24_exact_line_count "${R24_BUNDLE_LOG}" 'section=LAUNCH_READY')"; then :; else r24_active_fail 70 "launch_ready_section_read_failed_${r24_label}"; fi
  [[ "${r24_post_build_count}:${r24_pre_sign_count}:${r24_launch_ready_count}" == "1:1:1" ]] || r24_active_fail 70 "bundle_provenance_section_counts_${r24_label}"
  r24_require_no_process
}

r24_require_literal_hashes() {
  local r24_record=""
  local r24_expected=""
  local r24_path=""
  while IFS= read -r r24_record; do
    r24_expected="${r24_record%%  *}"
    r24_path="${r24_record#*  }"
    [[ "${r24_expected}" != "${r24_record}" ]] || r24_active_fail 70 "literal_hash_record_parse_failed"
    r24_require_sha_literal "literal_${r24_path}" "${r24_expected}"
    r24_require_sha "${r24_expected}" "${r24_path}"
  done <<'R24_LITERAL_HASHES'
80fdb08592d0e48b09b64f4bd17db5f54019e35ef9b738907915d6c429aa61d6  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Work/DurableWork.swift
e7cde04d577cc53b5b4ad0f8ad18bb4ca4ce604de18c660020fbc4096cd48f45  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift
f8842cbdde0bdb93c4139e59372cd897e8c091f79925a1cb9e18e8570ee954b5  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Database/DurableWorkStore.swift
147fac786fb877aae96423caa406af4f2d79c33f8298a164e9969cc518d558de  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Database/AppDatabase.swift
af5854b2545cf59f32ea8e216b7dc9d1e91b0387d2a8dda5e10030f3056f0d33  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Ingestion/IngestionRecords.swift
2d5907a5cbeb23934025e3fad248de7c719e61935f34ca7a776c8a525fb0fdae  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Ingestion/FeedService.swift
e1adf999b7b4d4b69ca5530601d3363fc691074d3dc5b4342b9ba36a95faeb6e  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Rumination/RuminationService.swift
80420d32709974fafcada2e6cb8cc71444792a2440c70c7901c514465ab1e8e3  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Rumination/RuminationParser.swift
b2f49eb3350aed0c1f03b574df5eadc09d5401b7c0a467ddc81e9af4819e87c2  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Kernel/Orchestrator.swift
1bf853e7bcd2addf679cf55588c0ae45f2b0d6955dda1e966e8629f11818dcd2  /Users/muzi/Agent-loop/Sources/AgentLoopApp/CodingRanchStoreAdapter.swift
0b3a918ac539c5975e9aa9a6583e2c6f723039b0f243bba497368f4d9d1f6e33  /Users/muzi/Agent-loop/Sources/AgentLoopApp/AppStore.swift
d0d769d025d5927485e833d327abb2c6b36fb5444a56a3c250dc11cea1448a6d  /Users/muzi/Agent-loop/Sources/AgentLoopApp/CodingRanchContracts.swift
54950383569ee7b0965364eda8a6402277e2c7f251aeab7de4f68340a4f97e34  /Users/muzi/Agent-loop/Sources/AgentLoopApp/Views/CodingRanch/RuminationViews.swift
5e311070fc5299fd4f576b4af6fb2286e4a515bf5b23a72d1ccc464c88c2c2bb  /Users/muzi/Agent-loop/Sources/AgentLoopTestSuite/CodingRanchTests.swift
818dfc5f897a0258b3113902f175d65bdf917732652ca44c08bd86fd0a2f0dd7  /Users/muzi/Agent-loop/Sources/AgentLoopTestSuite/DurableWorkTests.swift
863819791bbbead28c7fb0ba80540703fa275977682c846fbb8b415ce512c363  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Support/StateDirectoryLock.swift
eb5f8392870a8cca3a0e9729cc17082d259346b8187ff68cde9ee71ff1497386  /Users/muzi/Agent-loop/Sources/AgentLoopTestSuite/SupportTests.swift
094319b38c287a9265311fa60eb3c0e289555c6676dd0e3cfc0345cf289907c5  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Work/PlanningProviderResolver.swift
7ec1e5a45bc99d6af0270e84c535e59aa04cd57ae02e9f60537ec94c699b8be7  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Rumination/RuminationResult.swift
f0cd523ddf43789a9b0485bbcd0ee7b860b43a129795e06b1483c077d522623f  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Rumination/RuminationMaterializer.swift
1a3184711a261c15fa915571088ecbd9187c53a314139e41c8f336ffd51f7da4  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Database/EventKind.swift
db9d0ef56158321bcfe5048778cc1b63bd592a7cbddb355fac42ec9169f0c267  /Users/muzi/Agent-loop/Sources/P1MigrationMatrixRunner/main.swift
577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d  /Users/muzi/Agent-loop/Package.swift
d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a  /Users/muzi/Agent-loop/Package.resolved
70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3  /Users/muzi/Agent-loop/Sources/RunTests/main.swift
5b34e5e98a0e91b4087e20525c3aba81e7955475865d2af70e6ae65736e7997b  /Users/muzi/Agent-loop/scripts/run-app.sh
7891aef62cfe26caef766572b5258f0fe206b7ccd8b6f039700834276e6a1705  /Users/muzi/Agent-loop/scripts/package-app.sh
3ebed0ed43157459a0d137bc296f875fdebc4f2eba6397007ccc86ac35e70754  /Users/muzi/Agent-loop/Sources/AgentLoopApp/Views/CodingRanch/RanchArtView.swift
R24_LITERAL_HASHES
}

r24_require_slice_sha() {
  local r24_path="$1"
  local r24_start="$2"
  local r24_end="$3"
  local r24_expected_lines="$4"
  local r24_expected_sha="$5"
  local r24_actual_sha=""
  local r24_actual_lines=""
  if r24_actual_sha="$({
      if /usr/bin/sed -n "${r24_start},${r24_end}p" "${r24_path}" |
        /usr/bin/shasum -a 256 |
        /usr/bin/awk '{print $1}'; then
        r24_status=("${PIPESTATUS[@]}")
      else
        r24_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r24_status[@]}" == "3" ]] || exit 71
      [[ "${r24_status[0]}" == "0" && "${r24_status[1]}" == "0" && "${r24_status[2]}" == "0" ]] || exit 72
    })"; then :; else r24_active_fail 70 "slice_sha_pipeline_failed_${r24_path}_${r24_start}_${r24_end}"; fi
  if r24_actual_lines="$(/usr/bin/awk -v first="${r24_start}" -v last="${r24_end}" 'NR >= first && NR <= last { count += 1 } END { print count + 0 }' "${r24_path}")"; then :; else r24_active_fail 70 "slice_line_count_failed_${r24_path}"; fi
  [[ "${r24_actual_lines}" == "${r24_expected_lines}" ]] || r24_active_fail 70 "slice_line_count_${r24_path}_${r24_actual_lines}"
  [[ "${r24_actual_sha}" == "${r24_expected_sha}" ]] || r24_active_fail 70 "slice_sha_mismatch_${r24_path}_${r24_actual_sha}"
}

r24_run_remaining_source_privacy_final_hashes() {
  local r24_source_test_output=""
  local r24_source_log_sha=""
  local r24_source_log_bytes=""
  local r24_diff_output=""
  local r24_git_status=""
  local r24_now_value=""
  local r24_stage_header=""
  R24_PHASE="remaining_source_privacy_final_hashes"
  [[ "${R24_MATRIX_MUTATED}" == "false" ]] || r24_active_fail 70 "source_gate_matrix_still_mutated"
  r24_require_sha "${R24_EXPECTED_MATRIX_ENTRY_SHA}" "${R24_MATRIX_SCRIPT}"
  r24_require_launch_ready_identity "source_pre"
  r24_require_verify_log_identity "source_contract_reader_pre"
  r24_require_literal_hashes
  r24_require_slice_sha "${R24_REPOSITORY_ROOT}/scripts/run-app.sh" 45 86 42 "6d6daeccd905540f9b59ecdb426da33c11b22029a5d37c91dd8a987421821c83"
  r24_require_slice_sha "${R24_REPOSITORY_ROOT}/scripts/run-app.sh" 88 103 16 "8d3f091cdc2916ec42fcaacf980b285c6fa3acc586c82fe9d24598b70b4fc9fa"
  r24_require_slice_sha "${R24_REPOSITORY_ROOT}/Sources/AgentLoopCore/Database/AppDatabase.swift" 21 612 592 "5bbb555016a64801c25be3634b0fcfcca0da8fe3b4d3cda493b0df3851a8ccff"
  r24_require_slice_sha "${R24_STAGE_PATH}" 3850 4036 187 "fb77180d6edd44413e41179e4b220666438e2660de11fbde1dafee78b6fde5c2"
  if r24_stage_header="$(/usr/bin/sed -n '3847p' "${R24_STAGE_PATH}")"; then :; else r24_active_fail 70 "stage_18_1_header_read_failed"; fi
  [[ "${r24_stage_header}" == '### 18.1 `v12-p1-durable-work`（P1-A1a）' ]] || r24_active_fail 70 "stage_18_1_header_line_drift"
  r24_require_sha "f52b1a98a81e39fed0d3c619ecca81dfa34f22eaf1fd507d79dbf2ed56c5e7d2" "${R24_TASK_DIRECTORY}/evidence/source-gates.log"
  r24_require_sha "12617d5dd3bb43eb9d10074a0aa5fe50328b88c22dac40232fc90f7e10a2765f" "${R24_TASK_DIRECTORY}/evidence/hash-manifest.log"
  r24_require_sha "5b6a171515404a644abcd05e3afc3840cb1dd4d84d7993f74af48de0692b4dd5" "${R24_TASK_DIRECTORY}/reviews/01-p1-a2-review.md"

  if /usr/bin/python3 - "${R24_REPOSITORY_ROOT}" <<'R24_SOURCE_ASSERTIONS'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
def text(relative):
    return (root / relative).read_text(encoding="utf-8")
def count(pattern, relative, flags=0):
    return len(re.findall(pattern, text(relative), flags))
def require(condition, code):
    if not condition:
        raise SystemExit(code)

core_tree = "\n".join(p.read_text(encoding="utf-8") for p in (root / "Sources/AgentLoopCore").rglob("*.swift"))
require(core_tree.count("suppressForOrchestratorRecoveryFailure") == 0, 71)
require(count(r"\bplanningTasks\b", "Sources/AgentLoopCore/Kernel/Orchestrator.swift") == 0, 72)
combined = "\n".join(text(p) for p in [
    "Sources/AgentLoopCore/Kernel/Orchestrator.swift",
    "Sources/AgentLoopApp/AppStore.swift",
    "Sources/AgentLoopApp/CodingRanchStoreAdapter.swift",
])
require(len(re.findall(r"\b(createMissionShell|recordPlanningTokens|recordPlanFallback|planMission)\s*\(", combined)) == 0, 73)
app_calls = "\n".join(text(p) for p in [
    "Sources/AgentLoopApp/AppStore.swift",
    "Sources/AgentLoopApp/CodingRanchStoreAdapter.swift",
    "Sources/AgentLoopApp/MissionScheduler.swift",
])
require(len(re.findall(r"\borchestrator\.(startMission|confirmSquadProposal)\s*\(", app_calls)) == 0, 74)
require(count(r"\bdb\.claimScheduleFire\s*\(", "Sources/AgentLoopApp/MissionScheduler.swift") == 0, 75)
require(count(r"\b(?:factory\.)?linkConverted\s*\(", "Sources/AgentLoopApp/CodingRanchStoreAdapter.swift") == 0, 76)
legacy_public = r"public func (claimNextPlanning|renewPlanningLease|nextClaimablePlanningDate|adoptInterruptedPlanning|commitPlanningSuccess|recordPlanningAttemptFailure|recordPlanningUsageOverflow|cancelPlanning|cancelAllPlanningForEmergencyHalt|repairLegacyPlanningMissions)\b"
require(count(legacy_public, "Sources/AgentLoopCore/Database/AppDatabase.swift") == 0, 77)
require(count(legacy_public, "Sources/AgentLoopCore/Database/DurableWorkStore.swift") == 0, 78)
require(count(r"kind: DurableWorkKind = \.planning|kinds: \[DurableWorkKind\] = \[\.planning\]", "Sources/AgentLoopTestSuite/DurableWorkTests.swift") == 0, 79)
require(count(r"^fileprivate enum PlanningDurableWorkLedgerOwner\b", "Sources/AgentLoopCore/Database/DurableWorkStore.swift", re.M) == 1, 80)

seam = re.compile(r"A2RuminationAuthorization(?:Checkpoint|Loss|Scenario)ForTesting|a2RuminationAuthorizationScenarioForTesting|armA2RuminationAuthorizationScenarioForTesting|consumeA2RuminationAuthorizationScenarioForTesting")
for relative, expected in [
    ("Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift", 17),
    ("Sources/AgentLoopTestSuite/CodingRanchTests.swift", 13),
    ("Sources/AgentLoopTestSuite/DurableWorkTests.swift", 7),
]:
    source = text(relative)
    depth = 0
    guarded = []
    for line in source.splitlines(True):
        if line.strip() == "#if DEBUG":
            require(depth == 0, 81)
            depth = 1
        if depth:
            guarded.append(line)
        if line.strip() == "#endif":
            require(depth == 1, 82)
            depth = 0
    require(depth == 0, 83)
    require(len(seam.findall(source)) == expected, 84)
    require(len(seam.findall("".join(guarded))) == expected, 85)
supervisor = text("Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift")
depth = 0
guarded = []
for line in supervisor.splitlines(True):
    if line.strip() == "#if DEBUG": depth = 1
    if depth: guarded.append(line)
    if line.strip() == "#endif": depth = 0
guarded = "".join(guarded)
for forbidden in ["Mirror(", "unsafeBitCast(", "withUnsafe", "DurableWorkStore(", "database.execute(", ".pool.write", "handleValidatedRuminationTurn(", "validateRuminationPhaseOwnership(", "invalidateRuminationPhaseIfNeeded(", "latchFatalAndInvalidateRumination(", "deliverRuminationCommand(", "onRuminationPhase(", "RuminationParser.parse(", "parseValidatedTurn(", "produceValidatedTurn(", "Fake"]:
    require(forbidden not in guarded, 86)

coding = text("Sources/AgentLoopTestSuite/CodingRanchTests.swift")
durable = text("Sources/AgentLoopTestSuite/DurableWorkTests.swift")
require(coding.count("PlanningTestFixtures.uniqueFunction") == 19, 87)
require(durable.count("PlanningTestFixtures.uniqueFunction") == 1, 88)
definitions = {
    "ruminationSanitizesPersistedAndVisibleDiagnostics": "Sources/AgentLoopTestSuite/CodingRanchTests.swift",
    "ruminationProviderUsesNoToolsAndProducesOneCanonicalResult": "Sources/AgentLoopTestSuite/CodingRanchTests.swift",
    "singleOrchestratorSupervisorOwnsPlanningAndRuminationLifecycle": "Sources/AgentLoopTestSuite/CodingRanchTests.swift",
    "ruminationAdapterDelegatesStartRetryCancelWithoutUnownedTask": "Sources/AgentLoopTestSuite/CodingRanchTests.swift",
    "ruminationUnknownRestartRendersRecoveringWithoutInventingReading": "Sources/AgentLoopTestSuite/CodingRanchTests.swift",
    "ruminationPhaseProjectionUsesOnlyMatchingSupervisorEvents": "Sources/AgentLoopTestSuite/CodingRanchTests.swift",
    "ruminationLivePhaseEventsAreOwnedOrderedAndProcessLocal": "Sources/AgentLoopTestSuite/DurableWorkTests.swift",
    "ruminationUsageIsExactOrFailsBeforeAccounting": "Sources/AgentLoopTestSuite/DurableWorkTests.swift",
    "activeRuminationFencesDiscardDeleteAndArchiveRaces": "Sources/AgentLoopTestSuite/DurableWorkTests.swift",
    "stateDirectoryLockRejectsSecondFileDescriptionAndReleases": "Sources/AgentLoopTestSuite/SupportTests.swift",
}
for name, relative in definitions.items():
    require(count(r"@Test func " + re.escape(name) + r"\(", relative) == 1, 89)
R24_SOURCE_ASSERTIONS
  then :; else r24_active_fail 70 "source_contract_static_assertions_failed"; fi

  if r24_source_test_output="$(/usr/bin/awk -v joined='ruminationSanitizesPersistedAndVisibleDiagnostics|ruminationProviderUsesNoToolsAndProducesOneCanonicalResult|singleOrchestratorSupervisorOwnsPlanningAndRuminationLifecycle|ruminationAdapterDelegatesStartRetryCancelWithoutUnownedTask|ruminationUnknownRestartRendersRecoveringWithoutInventingReading|ruminationPhaseProjectionUsesOnlyMatchingSupervisorEvents|ruminationLivePhaseEventsAreOwnedOrderedAndProcessLocal|ruminationUsageIsExactOrFailsBeforeAccounting|activeRuminationFencesDiscardDeleteAndArchiveRaces|stateDirectoryLockRejectsSecondFileDescriptionAndReleases' '
      BEGIN { n = split(joined, names, "|") }
      {
        for (i = 1; i <= n; i += 1) {
          if ($0 == "◇ Test " names[i] "() started.") started[i] += 1
          if ($0 ~ ("^✔ Test " names[i] "\\(\\) passed after [0-9.]+ seconds\\.$")) passed[i] += 1
          if ($0 ~ ("^✘ Test " names[i] "\\(\\)")) failed[i] += 1
        }
      }
      END {
        ok = (n == 10)
        for (i = 1; i <= n; i += 1) {
          if (started[i] != 1 || passed[i] != 1 || failed[i] != 0) ok = 0
          print "source_contract_test=" names[i] " discovery=" (started[i] + 0) " pass=" (passed[i] + 0) " failure=" (failed[i] + 0)
        }
        print "source_contract_test_count=" n
        print "source_contract_tests_status=" (ok ? "PASS" : "FAIL")
      }
    ' "${R24_VERIFY_LOG}")"; then :; else r24_active_fail 70 "source_contract_same_log_scan_failed"; fi
  r24_require_verify_log_identity "source_contract_reader_post"
  [[ "${r24_source_test_output}" == *$'source_contract_tests_status=PASS' ]] || r24_active_fail 70 "source_contract_same_log_not_pass"

  if /usr/bin/python3 - "${R24_VERIFY_LOG}" "${R24_TARGETED_LOG}" "${R24_BUILD_LOG}" "${R24_MATRIX_LOG}" "${R24_BUNDLE_LOG}" "${R24_BOUNDARY_LOG}" "${R24_HASH_LOG}" <<'R24_PRIVACY_SCAN'
import re
import sys
from pathlib import Path

pattern = re.compile(rb"sk-[A-Za-z0-9_-]{20,}|Bearer\s+[A-Za-z0-9._-]{20,}|(?:access|refresh|id)_token[\"=:\s]+[A-Za-z0-9._-]{20,}", re.I)
for item in sys.argv[1:]:
    if pattern.search(Path(item).read_bytes()):
        raise SystemExit(71)
R24_PRIVACY_SCAN
  then :; else r24_active_fail 70 "pre_preview_runtime_privacy_scan_failed"; fi

  r24_validate_ranch_art_tree "${R24_RANCH_ART_DIRECTORY}"
  r24_require_branch_and_head
  r24_require_manifest
  r24_require_r23_predecessor
  r24_require_implementation_baseline
  if r24_diff_output="$(/usr/bin/git --no-optional-locks -C "${R24_REPOSITORY_ROOT}" diff --check)"; then :; else r24_active_fail 70 "git_diff_check_failed"; fi
  [[ -z "${r24_diff_output}" ]] || r24_active_fail 70 "git_diff_check_output"
  if r24_git_status="$(/usr/bin/git --no-optional-locks -C "${R24_REPOSITORY_ROOT}" status --short --branch)"; then :; else r24_active_fail 70 "git_status_failed"; fi
  r24_require_launch_ready_identity "source_post"
  r24_require_verify_log_identity "source_transition_adjacent"
  if r24_now_value="$(r24_capture_now)"; then :; else r24_active_fail 70 "source_gate_timestamp_failed"; fi
  {
    /usr/bin/printf '%s\n' 'section=REMAINING_SOURCE_PRIVACY_FINAL_HASHES'
    /usr/bin/printf 'utc=%s\n' "${r24_now_value}"
    /usr/bin/printf '%s\n' "${r24_source_test_output}"
    /usr/bin/printf '%s\n' 'a1b_sentinels=PASS'
    /usr/bin/printf '%s\n' 'a2_seam_source_guards=PASS'
    /usr/bin/printf '%s\n' 'planning_unique_function_a2_callers=20'
    /usr/bin/printf '%s\n' 'same_log_source_contract_tests=10_of_10_PASS'
    /usr/bin/printf '%s\n' 'literal_hashes=PASS'
    /usr/bin/printf '%s\n' 'pre_preview_privacy_scan=PASS'
    /usr/bin/printf '%s\n' 'git_diff_check=PASS'
    /usr/bin/printf '%s\n' 'status=PASS'
  } >> "${R24_SOURCE_LOG}"
  if r24_source_log_sha="$(r24_sha "${R24_SOURCE_LOG}")"; then :; else r24_active_fail 70 "source_log_sha_failed"; fi
  if r24_source_log_bytes="$(/usr/bin/stat -f '%z' "${R24_SOURCE_LOG}")"; then :; else r24_active_fail 70 "source_log_bytes_failed"; fi
  {
    /usr/bin/printf '%s\n' 'section=pre_preview_final_hashes'
    /usr/bin/printf 'source_log_sha=%s\n' "${r24_source_log_sha}"
    /usr/bin/printf 'source_log_bytes=%s\n' "${r24_source_log_bytes}"
    /usr/bin/printf 'matrix_script_sha=%s\n' "${R24_EXPECTED_MATRIX_ENTRY_SHA}"
    /usr/bin/printf 'core_sha=%s\n' "${R24_EXPECTED_CORE_SHA}"
    /usr/bin/printf 'test_sha=%s\n' "${R24_EXPECTED_TEST_SHA}"
    /usr/bin/printf 'verify_sha=%s\n' "${R24_VERIFY_LOG_SHA}"
    /usr/bin/printf 'bundle_manifest_sha=%s\n' "${R24_SIGNED_BUNDLE_MANIFEST_SHA}"
    /usr/bin/printf 'git_status_begin\n%s\ngit_status_end\n' "${r24_git_status}"
  } >> "${R24_HASH_LOG}"
  r24_append_boundary 'remaining_source_privacy_final_hashes=PASS'
  r24_append_boundary 'manifest_final_pre_preview=178_of_178'
  r24_append_boundary 'next_in_process_gate=same_bundle_preview'
}

r24_pgrep_exact_name() {
  local r24_name="$1"
  local r24_output=""
  local r24_rc=0
  if r24_output="$(/usr/bin/pgrep -x "${r24_name}")"; then
    r24_rc=0
  else
    r24_rc="$?"
  fi
  case "${r24_rc}" in
    0) [[ -n "${r24_output}" ]] || return 71 ;;
    1) [[ -z "${r24_output}" ]] || return 72 ;;
    *) return 73 ;;
  esac
  /usr/bin/printf '%s\n' "${r24_output}"
  return "${r24_rc}"
}

r24_preview_state_ready_probe() {
  local r24_output=""
  if r24_output="$({
      if /usr/bin/find -P "${R24_STATE_ROOT}" -mindepth 1 -maxdepth 1 -print0 |
        /usr/bin/sort -z |
        /bin/bash --noprofile --norc -c '
          set -u
          root="$1"
          lock_seen=0
          db_seen=0
          shm_seen=0
          wal_seen=0
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 72; break; fi
            [[ "${read_rc}" == "0" ]] || exit 73
            [[ -f "${path}" && ! -L "${path}" ]] || exit 76
            case "${path}" in
              "${root}/.agentloop.lock") [[ "${lock_seen}" == "0" ]] || exit 74; lock_seen=1 ;;
              "${root}/agentloop.sqlite") [[ "${db_seen}" == "0" ]] || exit 74; db_seen=1 ;;
              "${root}/agentloop.sqlite-shm") [[ "${shm_seen}" == "0" ]] || exit 74; shm_seen=1 ;;
              "${root}/agentloop.sqlite-wal") [[ "${wal_seen}" == "0" ]] || exit 74; wal_seen=1 ;;
              *) exit 75 ;;
            esac
          done
          /usr/bin/printf "%s\n" "$((lock_seen + db_seen + shm_seen + wal_seen))"
        ' bash "${R24_STATE_ROOT}"; then
        r24_status=("${PIPESTATUS[@]}")
      else
        r24_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r24_status[@]}" == "3" ]] || exit 77
      [[ "${r24_status[0]}" == "0" && "${r24_status[1]}" == "0" && "${r24_status[2]}" == "0" ]] || exit 78
    })"; then
    :
  else
    return 2
  fi
  [[ "${r24_output}" == "4" ]] || return 1
  return 0
}

# 0 means the exact isolated open-file set is ready, 1 is a safe startup
# subset, and 2 is an identity/isolation violation or indeterminate failure.
r24_preview_process_ready_probe() {
  local r24_command=""
  local r24_birth=""
  local r24_ppid=""
  local r24_env_line=""
  local r24_env_shape=""
  local r24_lsof_output=""
  local r24_lsof_shape=""
  case "${R24_APP_PID}" in ''|*[!0-9]*) return 2 ;; esac
  /bin/kill -0 "${R24_APP_PID}" 2>/dev/null || return 2
  if r24_birth="$(/bin/ps -p "${R24_APP_PID}" -o lstart= 2>/dev/null)"; then :; else return 2; fi
  [[ -n "${R24_APP_BIRTH}" && "${r24_birth}" == "${R24_APP_BIRTH}" ]] || return 2
  if r24_ppid="$(/bin/ps -p "${R24_APP_PID}" -o ppid= 2>/dev/null)"; then :; else return 2; fi
  r24_ppid="${r24_ppid// /}"
  r24_ppid="${r24_ppid//$'\t'/}"
  [[ "${r24_ppid}" == "$$" ]] || return 2
  if r24_command="$(/bin/ps -ww -p "${R24_APP_PID}" -o command= 2>/dev/null)"; then
    :
  else
    /bin/kill -0 "${R24_APP_PID}" 2>/dev/null || return 2
    return 1
  fi
  [[ "${r24_command}" == "${R24_APP_EXECUTABLE}" ]] || return 1
  if r24_env_line="$(/bin/ps eww -p "${R24_APP_PID}" -o command= 2>/dev/null)"; then :; else return 2; fi
  if r24_env_shape="$(/usr/bin/awk -v state="AGENTLOOP_STATE_DIR=${R24_STATE_ROOT}" '
      { for (i = 1; i <= NF; i += 1) { if ($i == state) state_count += 1; if ($i == "AGENTLOOP_UI_PREVIEW=1") preview_count += 1; if ($i ~ /^AGENTLOOP_BOARD_/) board_count += 1 } }
      END { print state_count + 0 ":" preview_count + 0 ":" board_count + 0 }
    ' <<< "${r24_env_line}")"; then :; else return 2; fi
  [[ "${r24_env_shape}" == "1:1:0" ]] || return 2
  if r24_lsof_output="$(/usr/sbin/lsof -p "${R24_APP_PID}" -Fn 2>/dev/null)"; then :; else
    /bin/kill -0 "${R24_APP_PID}" 2>/dev/null || return 2
    return 1
  fi
  if r24_lsof_shape="$(/usr/bin/python3 -c '
import sys
root = sys.argv[1]
exact_exec = sys.argv[2]
normal = "/Users/muzi/Library/Application Support/AgentLoop"
expected = {root + "/.agentloop.lock", root + "/agentloop.sqlite", root + "/agentloop.sqlite-shm", root + "/agentloop.sqlite-wal"}
paths = [line[1:] for line in sys.stdin.read().splitlines() if line.startswith("n")]
normal_count = sum(path == normal or path.startswith(normal + "/") for path in paths)
isolated = {path for path in paths if path.startswith(root + "/")}
unexpected = len(isolated - expected)
exact_exec_count = sum(path == exact_exec for path in paths)
print(f"{normal_count}:{unexpected}:{exact_exec_count}:{1 if isolated == expected else 0}")
' "${R24_STATE_ROOT}" "${R24_APP_EXECUTABLE}" <<< "${r24_lsof_output}")"; then :; else return 2; fi
  case "${r24_lsof_shape}" in
    0:0:1:1) return 0 ;;
    0:0:1:0) return 1 ;;
    *) return 2 ;;
  esac
}

r24_require_live_preview_process() {
  local r24_label="$1"
  local r24_pids=""
  local r24_app_pids=""
  local r24_command=""
  local r24_birth=""
  local r24_ppid=""
  local r24_txt=""
  local r24_env_line=""
  local r24_env_shape=""
  local r24_lsof_output=""
  local r24_lsof_shape=""
  local r24_children=""
  local r24_child_rc=0
  local r24_current_exec_sha=""
  local r24_current_bundle_sha=""
  case "${R24_APP_PID}" in ''|*[!0-9]*) r24_active_fail 70 "preview_pid_not_numeric_${r24_label}" ;; esac
  if /bin/kill -0 "${R24_APP_PID}" 2>/dev/null; then :; else r24_active_fail 70 "preview_pid_not_live_${r24_label}"; fi
  if r24_pids="$(r24_pgrep_exact_name AgentLoop)"; then :; else r24_active_fail 70 "preview_global_AgentLoop_probe_${r24_label}"; fi
  [[ "${r24_pids}" == "${R24_APP_PID}" ]] || r24_active_fail 70 "preview_global_pid_mismatch_${r24_label}_${r24_pids}"
  if r24_app_pids="$(r24_pgrep_exact_name AgentLoopApp)"; then
    r24_active_fail 70 "preview_AgentLoopApp_present_${r24_label}_${r24_app_pids}"
  else
    [[ "$?" == "1" ]] || r24_active_fail 70 "preview_AgentLoopApp_probe_indeterminate_${r24_label}"
  fi
  if r24_command="$(/bin/ps -ww -p "${R24_APP_PID}" -o command=)"; then :; else r24_active_fail 70 "preview_command_read_failed_${r24_label}"; fi
  [[ "${r24_command}" == "${R24_APP_EXECUTABLE}" ]] || r24_active_fail 70 "preview_command_mismatch_${r24_label}_${r24_command}"
  if r24_ppid="$(/bin/ps -p "${R24_APP_PID}" -o ppid=)"; then :; else r24_active_fail 70 "preview_ppid_read_failed_${r24_label}"; fi
  r24_ppid="${r24_ppid// /}"
  r24_ppid="${r24_ppid//$'\t'/}"
  [[ "${r24_ppid}" == "$$" ]] || r24_active_fail 70 "preview_ppid_mismatch_${r24_label}_${r24_ppid}_expected_$$"
  R24_APP_PPID="${r24_ppid}"
  if r24_birth="$(/bin/ps -p "${R24_APP_PID}" -o lstart=)"; then :; else r24_active_fail 70 "preview_birth_read_failed_${r24_label}"; fi
  [[ -n "${r24_birth}" && "${r24_birth}" != *$'\n'* ]] || r24_active_fail 70 "preview_birth_invalid_${r24_label}"
  if [[ -z "${R24_APP_BIRTH}" ]]; then R24_APP_BIRTH="${r24_birth}"; else [[ "${r24_birth}" == "${R24_APP_BIRTH}" ]] || r24_active_fail 70 "preview_pid_birth_replacement_${r24_label}"; fi
  if r24_txt="$(/usr/sbin/lsof -a -p "${R24_APP_PID}" -d txt -Fn)"; then :; else r24_active_fail 70 "preview_txt_lsof_failed_${r24_label}"; fi
  if r24_txt="$(/usr/bin/awk -v expected="n${R24_APP_EXECUTABLE}" '
      /^n/ { total += 1; if ($0 == expected) exact += 1 }
      END { print total + 0 ":" exact + 0 }
    ' <<< "${r24_txt}")"; then :; else r24_active_fail 70 "preview_txt_parse_failed_${r24_label}"; fi
  [[ "${r24_txt##*:}" == "1" && "${r24_txt%%:*}" -ge 1 ]] || r24_active_fail 70 "preview_txt_identity_mismatch_${r24_label}_${r24_txt}"
  if r24_env_line="$(/bin/ps eww -p "${R24_APP_PID}" -o command=)"; then :; else r24_active_fail 70 "preview_env_read_failed_${r24_label}"; fi
  if r24_env_shape="$(/usr/bin/awk -v state="AGENTLOOP_STATE_DIR=${R24_STATE_ROOT}" '
      { for (i = 1; i <= NF; i += 1) { if ($i == state) state_count += 1; if ($i == "AGENTLOOP_UI_PREVIEW=1") preview_count += 1; if ($i ~ /^AGENTLOOP_BOARD_/) board_count += 1 } }
      END { print state_count + 0 ":" preview_count + 0 ":" board_count + 0 }
    ' <<< "${r24_env_line}")"; then :; else r24_active_fail 70 "preview_env_parse_failed_${r24_label}"; fi
  [[ "${r24_env_shape}" == "1:1:0" ]] || r24_active_fail 70 "preview_safe_env_shape_${r24_label}_${r24_env_shape}"
  if r24_lsof_output="$(/usr/sbin/lsof -p "${R24_APP_PID}" -Fn)"; then :; else r24_active_fail 70 "preview_lsof_failed_${r24_label}"; fi
  if r24_lsof_shape="$(/usr/bin/python3 -c '
import sys
root = sys.argv[1]
normal = "/Users/muzi/Library/Application Support/AgentLoop"
expected = {root + "/.agentloop.lock", root + "/agentloop.sqlite", root + "/agentloop.sqlite-shm", root + "/agentloop.sqlite-wal"}
paths = [line[1:] for line in sys.stdin.read().splitlines() if line.startswith("n")]
normal_count = sum(path == normal or path.startswith(normal + "/") for path in paths)
isolated = {path for path in paths if path.startswith(root + "/")}
print(f"{normal_count}:{1 if isolated == expected else 0}")
' "${R24_STATE_ROOT}" <<< "${r24_lsof_output}")"; then :; else r24_active_fail 70 "preview_lsof_parse_failed_${r24_label}"; fi
  [[ "${r24_lsof_shape}" == "0:1" ]] || r24_active_fail 70 "preview_lsof_shape_${r24_label}_${r24_lsof_shape}"
  if r24_children="$(/usr/bin/pgrep -P "${R24_APP_PID}")"; then
    r24_child_rc=0
  else
    r24_child_rc="$?"
  fi
  [[ "${r24_child_rc}" == "1" && -z "${r24_children}" ]] || r24_active_fail 70 "preview_children_present_or_unknown_${r24_label}_${r24_child_rc}_${r24_children}"
  if r24_current_exec_sha="$(r24_sha "${R24_APP_EXECUTABLE}")"; then :; else r24_active_fail 70 "preview_exec_sha_failed_${r24_label}"; fi
  if r24_current_bundle_sha="$(r24_tree_manifest_sha "${R24_APP}")"; then :; else r24_active_fail 70 "preview_bundle_sha_failed_${r24_label}"; fi
  [[ "${r24_current_exec_sha}" == "${R24_SIGNED_EXECUTABLE_SHA}" && "${r24_current_bundle_sha}" == "${R24_SIGNED_BUNDLE_MANIFEST_SHA}" ]] || r24_active_fail 70 "preview_bundle_identity_drift_${r24_label}"
}

r24_new_nonce() {
  local r24_nonce=""
  if r24_nonce="$({
      if /usr/bin/uuidgen | /usr/bin/tr -d '-' | /usr/bin/tr '[:upper:]' '[:lower:]'; then
        r24_status=("${PIPESTATUS[@]}")
      else
        r24_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r24_status[@]}" == "3" ]] || exit 71
      [[ "${r24_status[0]}" == "0" && "${r24_status[1]}" == "0" && "${r24_status[2]}" == "0" ]] || exit 72
    })"; then :; else return "$?"; fi
  [[ "${#r24_nonce}" == "32" && "${r24_nonce}" != *[!0-9a-f]* ]] || return 73
  /usr/bin/printf '%s\n' "${r24_nonce}"
}

r24_start_direct_bootstrap() {
  local r24_index=0
  local r24_probe_rc=0
  local r24_process_probe_rc=0
  local r24_now_value=""
  R24_PHASE="preview_bootstrap_direct_start"
  r24_require_launch_ready_identity "bootstrap_pre_launch"
  r24_validate_empty_exact_root "${R24_STATE_ROOT}"
  R24_APP_BIRTH=""
  R24_APP_PPID=""
  r24_begin_preview_launch_identity_window
  AGENTLOOP_STATE_DIR="${R24_STATE_ROOT}" AGENTLOOP_UI_PREVIEW=1 \
    "${R24_APP_EXECUTABLE}" >> "${R24_BOOTSTRAP_LOG}" 2>&1 < /dev/null &
  R24_APP_PID="$!" R24_APP_DIRECT_CHILD_OWNED="true"
  case "${R24_APP_PID}" in ''|*[!0-9]*) r24_active_fail 70 "bootstrap_pid_not_numeric" ;; esac
  r24_capture_preview_launch_identity || r24_active_fail 70 "bootstrap_identity_capture_failed"
  r24_commit_preview_launch_identity_window "bootstrap"
  R24_BOOTSTRAP_PID="${R24_APP_PID}"
  R24_BOOTSTRAP_BIRTH="${R24_APP_BIRTH}"
  while (( r24_index < 150 )); do
    if r24_preview_state_ready_probe; then
      r24_probe_rc=0
    else
      r24_probe_rc="$?"
    fi
    [[ "${r24_probe_rc}" == "0" || "${r24_probe_rc}" == "1" ]] || r24_active_fail 70 "bootstrap_state_ready_probe_error_${r24_probe_rc}"
    if r24_preview_process_ready_probe; then
      r24_process_probe_rc=0
    else
      r24_process_probe_rc="$?"
    fi
    [[ "${r24_process_probe_rc}" == "0" || "${r24_process_probe_rc}" == "1" ]] || r24_active_fail 70 "bootstrap_process_ready_probe_error_${r24_process_probe_rc}"
    if [[ "${r24_probe_rc}" == "0" && "${r24_process_probe_rc}" == "0" ]]; then break; fi
    if /bin/kill -0 "${R24_APP_PID}" 2>/dev/null; then :; else r24_active_fail 70 "bootstrap_process_exited_before_ready"; fi
    /bin/sleep 0.1
    r24_index=$((r24_index + 1))
  done
  [[ "${r24_probe_rc}" == "0" && "${r24_process_probe_rc}" == "0" ]] || r24_active_fail 70 "bootstrap_ready_timeout"
  R24_CURRENT_ROOT_PHASE="preview_live"
  r24_require_live_preview_process "bootstrap_ready"
  if r24_now_value="$(r24_capture_now)"; then :; else r24_active_fail 70 "bootstrap_start_timestamp_failed"; fi
  {
    /usr/bin/printf 'preview.bootstrap.started_at=%s\n' "${r24_now_value}"
    /usr/bin/printf '%s\n' 'preview.bootstrap.launch_transport=direct_exact_executable_with_explicit_env'
    /usr/bin/printf 'preview.bootstrap.app=%s\n' "${R24_APP}"
    /usr/bin/printf 'preview.bootstrap.executable=%s\n' "${R24_APP_EXECUTABLE}"
    /usr/bin/printf 'preview.bootstrap.pid=%s\n' "${R24_APP_PID}"
    /usr/bin/printf 'preview.bootstrap.ppid=%s\n' "${R24_APP_PPID}"
    /usr/bin/printf '%s\n' 'preview.bootstrap.direct_child=true'
    /usr/bin/printf 'preview.bootstrap.bundle_identifier=%s\n' "${R24_BUNDLE_IDENTIFIER}"
    /usr/bin/printf 'preview.environment.AGENTLOOP_STATE_DIR=%s\n' "${R24_STATE_ROOT}"
    /usr/bin/printf '%s\n' 'preview.environment.AGENTLOOP_UI_PREVIEW=1'
    /usr/bin/printf '%s\n' 'preview.bootstrap.pid_source=direct_child_dollar_bang'
    /usr/bin/printf '%s\n' 'preview.bootstrap.launchservices_fallback_configured_and_signed=true'
    /usr/bin/printf '%s\n' 'preview.bootstrap.normal_root_open_observed_count=0'
  } >> "${R24_BOOTSTRAP_LOG}"
}

r24_start_direct_cold_preview() {
  local r24_index=0
  local r24_probe_rc=0
  local r24_process_probe_rc=0
  local r24_now_value=""
  R24_PHASE="preview_cold_direct_start"
  r24_require_launch_ready_identity "cold_pre_launch"
  R24_APP_BIRTH=""
  R24_APP_PPID=""
  r24_begin_preview_launch_identity_window
  AGENTLOOP_STATE_DIR="${R24_STATE_ROOT}" AGENTLOOP_UI_PREVIEW=1 \
    "${R24_APP_EXECUTABLE}" >> "${R24_COLD_START_LOG}" 2>&1 < /dev/null &
  R24_APP_PID="$!" R24_APP_DIRECT_CHILD_OWNED="true"
  case "${R24_APP_PID}" in ''|*[!0-9]*) r24_active_fail 70 "cold_pid_not_numeric" ;; esac
  r24_capture_preview_launch_identity || r24_active_fail 70 "cold_identity_capture_failed"
  r24_commit_preview_launch_identity_window "cold"
  [[ -n "${R24_BOOTSTRAP_PID}" && -n "${R24_BOOTSTRAP_BIRTH}" ]] || r24_active_fail 70 "cold_bootstrap_identity_missing"
  [[ "${R24_APP_PID}" != "${R24_BOOTSTRAP_PID}" ]] || r24_active_fail 70 "cold_reused_bootstrap_pid"
  [[ "${R24_APP_BIRTH}" != "${R24_BOOTSTRAP_BIRTH}" ]] || r24_active_fail 70 "cold_reused_bootstrap_birth"
  while (( r24_index < 150 )); do
    if r24_preview_state_ready_probe; then
      r24_probe_rc=0
    else
      r24_probe_rc="$?"
    fi
    [[ "${r24_probe_rc}" == "0" || "${r24_probe_rc}" == "1" ]] || r24_active_fail 70 "cold_state_ready_probe_error_${r24_probe_rc}"
    if r24_preview_process_ready_probe; then
      r24_process_probe_rc=0
    else
      r24_process_probe_rc="$?"
    fi
    [[ "${r24_process_probe_rc}" == "0" || "${r24_process_probe_rc}" == "1" ]] || r24_active_fail 70 "cold_process_ready_probe_error_${r24_process_probe_rc}"
    if [[ "${r24_probe_rc}" == "0" && "${r24_process_probe_rc}" == "0" ]]; then break; fi
    if /bin/kill -0 "${R24_APP_PID}" 2>/dev/null; then :; else r24_active_fail 70 "cold_process_exited_before_ready"; fi
    /bin/sleep 0.1
    r24_index=$((r24_index + 1))
  done
  [[ "${r24_probe_rc}" == "0" && "${r24_process_probe_rc}" == "0" ]] || r24_active_fail 70 "cold_ready_timeout"
  R24_CURRENT_ROOT_PHASE="preview_live"
  r24_require_live_preview_process "cold_ready"
  if r24_now_value="$(r24_capture_now)"; then :; else r24_active_fail 70 "cold_start_timestamp_failed"; fi
  {
    /usr/bin/printf 'preview.cold_start.started_at=%s\n' "${r24_now_value}"
    /usr/bin/printf '%s\n' 'preview.cold_start.launch_transport=direct_exact_executable_with_explicit_env'
    /usr/bin/printf 'preview.cold_start.pid=%s\n' "${R24_APP_PID}"
    /usr/bin/printf 'preview.cold_start.ppid=%s\n' "${R24_APP_PPID}"
    /usr/bin/printf '%s\n' 'preview.cold_start.direct_child=true'
    /usr/bin/printf '%s\n' 'preview.cold_start.lifecycle_distinct_from_bootstrap=true'
    /usr/bin/printf 'preview.cold_start.bundle_identifier=%s\n' "${R24_BUNDLE_IDENTIFIER}"
    /usr/bin/printf '%s\n' 'preview.cold_start.normal_root_open_observed_count=0'
  } >> "${R24_COLD_START_LOG}"
}

r24_cu_log_path() {
  case "$1" in
    bootstrap) /usr/bin/printf '%s\n' "${R24_BOOTSTRAP_LOG}" ;;
    cold) /usr/bin/printf '%s\n' "${R24_COLD_START_LOG}" ;;
    *) return 71 ;;
  esac
}

r24_cu_exchange_exact() {
  local r24_phase="$1"
  local r24_step="$2"
  local r24_allowed_scope="$3"
  local r24_expected_metrics="$4"
  local r24_quit_step="$5"
  local r24_nonce=""
  local r24_log=""
  local r24_challenge=""
  local r24_expected=""
  local r24_reply=""
  [[ "${r24_quit_step}" == "true" || "${r24_quit_step}" == "false" ]] || r24_active_fail 70 "cu_quit_flag_invalid_${r24_phase}_${r24_step}"
  [[ -n "${r24_allowed_scope}" && "${r24_allowed_scope}" != *'|'* && "${r24_allowed_scope}" != *$'\n'* ]] || r24_active_fail 70 "cu_allowed_scope_invalid_${r24_phase}_${r24_step}"
  if r24_nonce="$(r24_new_nonce)"; then :; else r24_active_fail 70 "cu_nonce_failed_${r24_phase}_${r24_step}"; fi
  if r24_log="$(r24_cu_log_path "${r24_phase}")"; then :; else r24_active_fail 70 "cu_log_path_failed_${r24_phase}"; fi
  r24_require_live_preview_process "cu_${r24_phase}_${r24_step}_pre"
  r24_challenge="R24_CU_CHALLENGE_V1|invocation_id=${R24_INVOCATION_ID}|phase=${r24_phase}|step=${r24_step}|nonce=${r24_nonce}|pid=${R24_APP_PID}|app=${R24_APP}|exec=${R24_APP_EXECUTABLE}|exec_sha=${R24_SIGNED_EXECUTABLE_SHA}|bundle_sha=${R24_SIGNED_BUNDLE_MANIFEST_SHA}|bundle_id=${R24_BUNDLE_IDENTIFIER}|state_root=${R24_STATE_ROOT}|raw_path=NONE|allowed_scope=${r24_allowed_scope}|full_state_disableDiff=true|coordinates_forbidden=true|fallback_lookup_forbidden=true|timeout_s=180"
  /usr/bin/printf 'control.challenge=%s\n' "${r24_challenge}" >> "${r24_log}"
  /usr/bin/printf '%s\n' "${r24_challenge}"
  if IFS= read -r -t 180 r24_reply; then :; else r24_active_fail 70 "cu_reply_timeout_or_eof_${r24_phase}_${r24_step}"; fi
  [[ "${#r24_reply}" -le 4096 && "${r24_reply}" != *$'\r'* && "${r24_reply}" != *$'\n'* ]] || r24_active_fail 70 "cu_reply_shape_${r24_phase}_${r24_step}"
  r24_expected="R24_CU_RESULT_V1|invocation_id=${R24_INVOCATION_ID}|phase=${r24_phase}|step=${r24_step}|nonce=${r24_nonce}|status=PASS|${r24_expected_metrics}"
  [[ "${r24_reply}" == "${r24_expected}" ]] || r24_active_fail 70 "cu_reply_mismatch_${r24_phase}_${r24_step}"
  /usr/bin/printf 'control.result=%s\n' "${r24_reply}" >> "${r24_log}"
  if [[ "${r24_quit_step}" == "false" ]]; then
    r24_require_live_preview_process "cu_${r24_phase}_${r24_step}_post"
  fi
}

r24_wait_owned_preview_exit() {
  local r24_phase="$1"
  local r24_pid="${R24_APP_PID}"
  local r24_birth="${R24_APP_BIRTH}"
  local r24_job_rc=0
  local r24_current_birth=""
  local r24_ppid=""
  local r24_wait_rc=0
  local r24_index=0
  local r24_log=""
  local r24_now_value=""
  case "${r24_pid}" in ''|*[!0-9]*) r24_active_fail 70 "quit_wait_pid_not_numeric_${r24_phase}" ;; esac
  [[ -n "${r24_birth}" ]] || r24_active_fail 70 "quit_wait_birth_missing_${r24_phase}"
  [[ "${R24_APP_DIRECT_CHILD_OWNED}" == "true" && "${R24_APP_IDENTITY_COMMITTED}" == "true" ]] || r24_active_fail 70 "quit_wait_child_ownership_missing_${r24_phase}"
  while (( r24_index < 150 )); do
    if r24_preview_active_job_exact; then
      if r24_current_birth="$(/bin/ps -p "${r24_pid}" -o lstart= 2>/dev/null)"; then
        [[ "${r24_current_birth}" == "${r24_birth}" ]] || r24_active_fail 70 "quit_wait_pid_birth_replaced_${r24_phase}"
      else
        if r24_preview_active_job_exact; then :; else
          r24_job_rc="$?"
          if [[ "${r24_job_rc}" == "1" ]]; then break; fi
        fi
        r24_active_fail 70 "quit_wait_birth_read_failed_while_live_${r24_phase}"
      fi
      if r24_ppid="$(/bin/ps -p "${r24_pid}" -o ppid= 2>/dev/null)"; then
        :
      else
        if r24_preview_active_job_exact; then :; else
          r24_job_rc="$?"
          if [[ "${r24_job_rc}" == "1" ]]; then break; fi
        fi
        r24_active_fail 70 "quit_wait_ppid_read_failed_while_live_${r24_phase}"
      fi
      r24_ppid="${r24_ppid// /}"
      r24_ppid="${r24_ppid//$'\t'/}"
      [[ "${r24_ppid}" == "$$" ]] || r24_active_fail 70 "quit_wait_ppid_mismatch_${r24_phase}_${r24_ppid}_expected_$$"
      /bin/sleep 0.1
      r24_index=$((r24_index + 1))
      continue
    fi
    r24_job_rc="$?"
    [[ "${r24_job_rc}" == "1" ]] || r24_active_fail 70 "quit_wait_job_table_indeterminate_${r24_phase}_${r24_job_rc}"
    break
  done
  (( r24_index < 150 )) || r24_active_fail 70 "quit_wait_timeout_${r24_phase}"
  if wait "${r24_pid}"; then
    r24_wait_rc="$?"
  else
    r24_wait_rc="$?"
  fi
  [[ "${r24_wait_rc}" == "0" ]] || r24_active_fail 70 "quit_wait_child_status_${r24_phase}_${r24_wait_rc}"
  r24_clear_owned_preview_identity
  r24_require_no_process
  R24_CURRENT_ROOT_PHASE="preview_quiescent"
  r24_validate_current_roots_phase
  if r24_log="$(r24_cu_log_path "${r24_phase}")"; then :; else r24_active_fail 70 "quit_wait_log_path_failed_${r24_phase}"; fi
  if r24_now_value="$(r24_capture_now)"; then :; else r24_active_fail 70 "quit_wait_timestamp_failed_${r24_phase}"; fi
  {
    /usr/bin/printf 'preview.%s.quit_child_status=%s\n' "${r24_phase}" "${r24_wait_rc}"
    /usr/bin/printf 'preview.%s.quit_pid_identity_preserved=true\n' "${r24_phase}"
    /usr/bin/printf 'preview.%s.global_process_count_after_quit=0\n' "${r24_phase}"
    /usr/bin/printf 'preview.%s.quiescent_state_shape=PASS\n' "${r24_phase}"
    /usr/bin/printf 'preview.%s.quit_completed_at=%s\n' "${r24_phase}" "${r24_now_value}"
  } >> "${r24_log}"
}

r24_install_preview_fixture() {
  local r24_database="${R24_STATE_ROOT}/agentloop.sqlite"
  local r24_output=""
  local r24_fixture_sha=""
  local r24_now_value=""
  R24_PHASE="preview_fixture_install"
  r24_require_no_process
  [[ "${R24_CURRENT_ROOT_PHASE}" == "preview_quiescent" ]] || r24_active_fail 70 "fixture_wrong_root_phase_${R24_CURRENT_ROOT_PHASE}"
  r24_validate_current_roots_phase
  if r24_output="$(/usr/bin/python3 - "${r24_database}" <<'R24_FIXTURE_PY'
import sqlite3
import sys

path = sys.argv[1]
ingestion_id = "a2-preview-ingestion-recovering"
work_id = "a2-preview-work-recovering"
trace_id = "a2-preview-synthetic-trace"
idempotency_key = "rumination-start:a2-preview-ingestion-recovering:1:v1"
raw_text = "A2 isolated synthetic rumination fixture"
raw_hash = "5bfb45aa64ed74731df07ba237682cd525de94b341b8355945f75bb19fd8c5b3"
input_json = '{"model":"preview-model","pipelineVersion":"coding-ranch-v1","runtimeProfileId":"preview-profile"}'
input_hash = "b3c41c894ab7add26938126da5be12bd71cecb51960dcd3e512d657052e8c721"
when = "2026-08-10 00:00:00.000"

connection = sqlite3.connect(path, timeout=5.0)
try:
    connection.execute("PRAGMA foreign_keys = ON")
    if connection.execute("PRAGMA foreign_keys").fetchone() != (1,):
        raise SystemExit(71)
    camps = connection.execute("SELECT id FROM camp ORDER BY createdAt, rowid").fetchall()
    if len(camps) != 1 or not isinstance(camps[0][0], str):
        raise SystemExit(72)
    camp_id = camps[0][0]
    if connection.execute("SELECT COUNT(*) FROM ingestion_item").fetchone() != (0,):
        raise SystemExit(73)
    if connection.execute("SELECT COUNT(*) FROM durable_work").fetchone() != (0,):
        raise SystemExit(74)
    connection.execute("BEGIN IMMEDIATE")
    connection.execute(
        """
        INSERT INTO ingestion_item (
          id, campId, sourceType, title, rawText, sourceURL, author, userIntent,
          contentHash, status, attempt, errorText, createdAt, updatedAt
        ) VALUES (?, ?, ?, ?, ?, NULL, NULL, NULL, ?, ?, ?, NULL, ?, ?)
        """,
        (
            ingestion_id, camp_id, "manual", "隔离恢复验证", raw_text,
            raw_hash, "ruminating", 1, when, when,
        ),
    )
    connection.execute(
        """
        INSERT INTO durable_work (
          id, campId, kind, aggregateType, aggregateId, idempotencyKey, state,
          attempt, maxAttempts, notBefore, leaseOwner, leaseExpiresAt,
          inputJson, inputHash, outputJson, errorCode, errorMessage, traceId,
          version, createdAt, updatedAt, finishedAt
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL, ?, ?, NULL,
                  NULL, NULL, ?, ?, ?, ?, NULL)
        """,
        (
            work_id, camp_id, "rumination", "ingestion", ingestion_id,
            idempotency_key, "queued", 0, 4, input_json, input_hash,
            trace_id, 1, when, when,
        ),
    )
    if connection.execute("PRAGMA foreign_key_check").fetchall() != []:
        raise SystemExit(75)
    if connection.execute("PRAGMA integrity_check").fetchall() != [("ok",)]:
        raise SystemExit(76)
    ingestion = connection.execute(
        """
        SELECT id, campId, sourceType, title, rawText, sourceURL, author,
               userIntent, contentHash, status, attempt, errorText
        FROM ingestion_item
        """
    ).fetchall()
    expected_ingestion = [(
        ingestion_id, camp_id, "manual", "隔离恢复验证", raw_text, None,
        None, None, raw_hash, "ruminating", 1, None,
    )]
    if ingestion != expected_ingestion:
        raise SystemExit(77)
    work = connection.execute(
        """
        SELECT id, campId, kind, aggregateType, aggregateId, idempotencyKey,
               state, attempt, maxAttempts, notBefore, leaseOwner,
               leaseExpiresAt, inputJson, inputHash, outputJson, errorCode,
               errorMessage, traceId, version, finishedAt
        FROM durable_work
        """
    ).fetchall()
    expected_work = [(
        work_id, camp_id, "rumination", "ingestion", ingestion_id,
        idempotency_key, "queued", 0, 4, None, None, None, input_json,
        input_hash, None, None, None, trace_id, 1, None,
    )]
    if work != expected_work:
        raise SystemExit(78)
    connection.commit()
    if connection.execute("PRAGMA foreign_key_check").fetchall() != []:
        raise SystemExit(79)
    if connection.execute("PRAGMA integrity_check").fetchall() != [("ok",)]:
        raise SystemExit(80)
    print("camp_id=" + camp_id)
    print("fixture_counts=1:1")
finally:
    connection.close()
R24_FIXTURE_PY
  )"; then :; else r24_active_fail 70 "preview_fixture_transaction_failed"; fi
  [[ "${r24_output}" == camp_id=*$'\n'fixture_counts=1:1 ]] || r24_active_fail 70 "preview_fixture_output_shape"
  R24_PREVIEW_CAMP_ID="${r24_output%%$'\n'*}"
  R24_PREVIEW_CAMP_ID="${R24_PREVIEW_CAMP_ID#camp_id=}"
  [[ "${#R24_PREVIEW_CAMP_ID}" == "36" ]] || r24_active_fail 70 "preview_fixture_camp_id_length"
  case "${R24_PREVIEW_CAMP_ID}" in *[!0-9A-Fa-f-]*) r24_active_fail 70 "preview_fixture_camp_id_format" ;; esac
  [[ "${R24_PREVIEW_CAMP_ID:8:1}${R24_PREVIEW_CAMP_ID:13:1}${R24_PREVIEW_CAMP_ID:18:1}${R24_PREVIEW_CAMP_ID:23:1}" == "----" ]] || r24_active_fail 70 "preview_fixture_camp_id_hyphens"
  R24_CURRENT_ROOT_PHASE="preview_quiescent"
  r24_validate_current_roots_phase
  if r24_fixture_sha="$(r24_sha "${r24_database}")"; then :; else r24_active_fail 70 "preview_fixture_database_sha_failed"; fi
  if r24_now_value="$(r24_capture_now)"; then :; else r24_active_fail 70 "preview_fixture_timestamp_failed"; fi
  {
    /usr/bin/printf 'preview.fixture.installed_at=%s\n' "${r24_now_value}"
    /usr/bin/printf 'preview.fixture.camp_id=%s\n' "${R24_PREVIEW_CAMP_ID}"
    /usr/bin/printf '%s\n' 'preview.fixture.ingestion_id=a2-preview-ingestion-recovering'
    /usr/bin/printf '%s\n' 'preview.fixture.work_id=a2-preview-work-recovering'
    /usr/bin/printf '%s\n' 'preview.fixture.ingestion_status=ruminating'
    /usr/bin/printf '%s\n' 'preview.fixture.work_state=queued'
    /usr/bin/printf '%s\n' 'preview.fixture.foreign_key_check=PASS'
    /usr/bin/printf '%s\n' 'preview.fixture.integrity_check=PASS'
    /usr/bin/printf 'preview.fixture.database_sha_before_cold_start=%s\n' "${r24_fixture_sha}"
  } >> "${R24_COLD_START_LOG}"
}

r24_cu_capture_screenshot() {
  local r24_nonce=""
  local r24_challenge=""
  local r24_reply=""
  local r24_prefix=""
  local r24_rest=""
  local r24_encoding_field=""
  local r24_bytes_field=""
  local r24_sha_field=""
  local r24_extra_field=""
  local r24_actual_bytes=""
  local r24_actual_sha=""
  local r24_actual_encoding=""
  local r24_dimensions=""
  local r24_sips_dimensions=""
  local r24_mime=""
  local r24_stage_sha=""
  local r24_published_sha=""
  local r24_publish_rc=0
  local r24_sips_output=""
  local r24_now_value=""
  R24_PHASE="preview_cold_C06_screenshot_export"
  R24_CU_RAW_PATH="${R24_STATE_ROOT}/.${R24_INVOCATION_ID}.cu-raw"
  R24_SCREENSHOT_STAGE="${R24_TASK_DIRECTORY}/evidence/.${R24_INVOCATION_ID}.r24-preview-smoke.stage.png"
  r24_require_absent_path "${R24_CU_RAW_PATH}"
  r24_require_absent_path "${R24_SCREENSHOT_STAGE}"
  r24_require_absent_path "${R24_SCREENSHOT}"
  if r24_nonce="$(r24_new_nonce)"; then :; else r24_active_fail 70 "cu_nonce_failed_cold_C06"; fi
  r24_require_live_preview_process "cu_cold_C06_pre"
  r24_challenge="R24_CU_SCREENSHOT_CHALLENGE_V1|invocation_id=${R24_INVOCATION_ID}|phase=cold|step=C06|nonce=${r24_nonce}|pid=${R24_APP_PID}|app=${R24_APP}|exec=${R24_APP_EXECUTABLE}|exec_sha=${R24_SIGNED_EXECUTABLE_SHA}|bundle_sha=${R24_SIGNED_BUNDLE_MANIFEST_SHA}|bundle_id=${R24_BUNDLE_IDENTIFIER}|state_root=${R24_STATE_ROOT}|raw_path=${R24_CU_RAW_PATH}|allowed_scope=node_copy_current_C05_screenshot_once_with_fs_open_wx_to_exact_raw_path|other_fs_writes_forbidden=true|ui_action_forbidden=true|timeout_s=180"
  /usr/bin/printf 'control.challenge=%s\n' "${r24_challenge}" >> "${R24_COLD_START_LOG}"
  /usr/bin/printf '%s\n' "${r24_challenge}"
  if IFS= read -r -t 180 r24_reply; then :; else r24_active_fail 70 "cu_reply_timeout_or_eof_cold_C06"; fi
  [[ "${#r24_reply}" -le 4096 && "${r24_reply}" != *$'\r'* && "${r24_reply}" != *$'\n'* ]] || r24_active_fail 70 "cu_reply_shape_cold_C06"
  r24_prefix="R24_CU_SCREENSHOT_RESULT_V1|invocation_id=${R24_INVOCATION_ID}|phase=cold|step=C06|nonce=${r24_nonce}|status=PASS|raw_path=${R24_CU_RAW_PATH}|"
  [[ "${r24_reply}" == "${r24_prefix}"* ]] || r24_active_fail 70 "cu_reply_prefix_cold_C06"
  r24_rest="${r24_reply#"${r24_prefix}"}"
  IFS='|' read -r r24_encoding_field r24_bytes_field r24_sha_field r24_extra_field <<< "${r24_rest}"
  [[ -z "${r24_extra_field}" ]] || r24_active_fail 70 "cu_reply_extra_field_cold_C06"
  [[ "${r24_encoding_field}" == encoding=* && "${r24_bytes_field}" == bytes=* && "${r24_sha_field}" == sha=* ]] || r24_active_fail 70 "cu_reply_fields_cold_C06"
  R24_CU_RAW_ENCODING="${r24_encoding_field#encoding=}"
  R24_CU_RAW_BYTES="${r24_bytes_field#bytes=}"
  R24_CU_RAW_SHA="${r24_sha_field#sha=}"
  [[ "${R24_CU_RAW_ENCODING}" == "PNG" || "${R24_CU_RAW_ENCODING}" == "JPEG" ]] || r24_active_fail 70 "cu_raw_encoding_cold_C06"
  case "${R24_CU_RAW_BYTES}" in ''|*[!0-9]*) r24_active_fail 70 "cu_raw_bytes_cold_C06" ;; esac
  [[ "${R24_CU_RAW_BYTES}" -gt 0 ]] || r24_active_fail 70 "cu_raw_empty_cold_C06"
  r24_require_sha_literal "cu_raw_C06" "${R24_CU_RAW_SHA}"
  [[ -f "${R24_CU_RAW_PATH}" && ! -L "${R24_CU_RAW_PATH}" ]] || r24_active_fail 70 "cu_raw_path_type_cold_C06"
  if r24_actual_bytes="$(/usr/bin/stat -f '%z' "${R24_CU_RAW_PATH}")"; then :; else r24_active_fail 70 "cu_raw_stat_cold_C06"; fi
  if r24_actual_sha="$(r24_sha "${R24_CU_RAW_PATH}")"; then :; else r24_active_fail 70 "cu_raw_sha_cold_C06"; fi
  [[ "${r24_actual_bytes}" == "${R24_CU_RAW_BYTES}" && "${r24_actual_sha}" == "${R24_CU_RAW_SHA}" ]] || r24_active_fail 70 "cu_raw_metadata_mismatch_cold_C06"
  if r24_actual_encoding="$(/usr/bin/python3 - "${R24_CU_RAW_PATH}" <<'R24_IMAGE_KIND'
import sys
data = open(sys.argv[1], "rb").read(12)
if data.startswith(b"\x89PNG\r\n\x1a\n"):
    print("PNG")
elif data.startswith(b"\xff\xd8\xff"):
    print("JPEG")
else:
    raise SystemExit(71)
R24_IMAGE_KIND
  )"; then :; else r24_active_fail 70 "cu_raw_magic_cold_C06"; fi
  [[ "${r24_actual_encoding}" == "${R24_CU_RAW_ENCODING}" ]] || r24_active_fail 70 "cu_raw_encoding_mismatch_cold_C06"
  R24_DEFERRED_SIGNAL=""
  R24_DEFERRED_SIGNAL_STATUS=""
  trap 'r24_defer_signal HUP 129' HUP
  trap 'r24_defer_signal INT 130' INT
  trap 'r24_defer_signal TERM 143' TERM
  if r24_exclusive_create_empty "${R24_SCREENSHOT_STAGE}"; then
    R24_SCREENSHOT_STAGE_OWNED="true"
  else
    r24_install_signal_traps
    r24_active_fail 70 "cu_stage_exclusive_create_failed_C06"
  fi
  r24_install_signal_traps
  if [[ -n "${R24_DEFERRED_SIGNAL}" ]]; then
    r24_active_fail "${R24_DEFERRED_SIGNAL_STATUS}" "deferred_signal_${R24_DEFERRED_SIGNAL}_screenshot_stage_create"
  fi
  if r24_sips_output="$(/usr/bin/sips -s format png "${R24_CU_RAW_PATH}" --out "${R24_SCREENSHOT_STAGE}" 2>&1)"; then :; else r24_active_fail 70 "cu_full_decode_normalization_failed_C06"; fi
  [[ -n "${r24_sips_output}" ]] || r24_active_fail 70 "cu_full_decode_normalization_output_empty_C06"
  [[ -f "${R24_SCREENSHOT_STAGE}" && ! -L "${R24_SCREENSHOT_STAGE}" ]] || r24_active_fail 70 "cu_stage_type_C06"
  if r24_dimensions="$(/usr/bin/python3 - "${R24_SCREENSHOT_STAGE}" <<'R24_PNG_DIMENSIONS'
import struct
import sys
with open(sys.argv[1], "rb") as handle:
    header = handle.read(24)
if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
    raise SystemExit(71)
width, height = struct.unpack(">II", header[16:24])
if width < 1 or height < 1:
    raise SystemExit(72)
print(f"{width}:{height}")
R24_PNG_DIMENSIONS
  )"; then :; else r24_active_fail 70 "cu_png_dimensions_failed_C06"; fi
  R24_SCREENSHOT_WIDTH="${r24_dimensions%%:*}"
  R24_SCREENSHOT_HEIGHT="${r24_dimensions##*:}"
  if r24_sips_dimensions="$(/usr/bin/sips -g pixelWidth -g pixelHeight "${R24_SCREENSHOT_STAGE}" 2>/dev/null)"; then :; else r24_active_fail 70 "cu_sips_decode_metadata_failed_C06"; fi
  if r24_sips_dimensions="$(/usr/bin/awk '
      $1 == "pixelWidth:" { width = $2; width_count += 1 }
      $1 == "pixelHeight:" { height = $2; height_count += 1 }
      END {
        if (width_count != 1 || height_count != 1 || width !~ /^[0-9]+$/ || height !~ /^[0-9]+$/) exit 71
        print width ":" height
      }
    ' <<< "${r24_sips_dimensions}")"; then :; else r24_active_fail 70 "cu_sips_decode_metadata_parse_failed_C06"; fi
  [[ "${r24_sips_dimensions}" == "${r24_dimensions}" ]] || r24_active_fail 70 "cu_sips_vs_png_dimension_mismatch_C06"
  if r24_stage_sha="$(r24_sha "${R24_SCREENSHOT_STAGE}")"; then :; else r24_active_fail 70 "cu_stage_sha_failed_C06"; fi
  r24_require_absent_path "${R24_SCREENSHOT}"
  if /bin/mv -n "${R24_SCREENSHOT_STAGE}" "${R24_SCREENSHOT}"; then
    r24_publish_rc=0
  else
    r24_publish_rc="$?"
    r24_active_fail 70 "cu_screenshot_same_directory_publish_failed_C06_${r24_publish_rc}"
  fi
  if [[ ! -e "${R24_SCREENSHOT_STAGE}" && ! -L "${R24_SCREENSHOT_STAGE}" && -f "${R24_SCREENSHOT}" && ! -L "${R24_SCREENSHOT}" ]]; then
    R24_SCREENSHOT_STAGE_OWNED="false"
  else
    r24_active_fail 70 "cu_screenshot_publish_postcondition_failed_C06"
  fi
  if r24_published_sha="$(r24_sha "${R24_SCREENSHOT}")"; then :; else r24_active_fail 70 "cu_screenshot_published_sha_failed_C06"; fi
  [[ "${r24_published_sha}" == "${r24_stage_sha}" ]] || r24_active_fail 70 "cu_screenshot_published_sha_mismatch_C06"
  /bin/rm -f "${R24_CU_RAW_PATH}" || r24_active_fail 70 "cu_raw_cleanup_failed_C06"
  r24_require_absent_path "${R24_CU_RAW_PATH}"
  r24_require_absent_path "${R24_SCREENSHOT_STAGE}"
  [[ -f "${R24_SCREENSHOT}" && ! -L "${R24_SCREENSHOT}" ]] || r24_active_fail 70 "cu_screenshot_type_C06"
  if r24_mime="$(/usr/bin/file -b --mime-type "${R24_SCREENSHOT}")"; then :; else r24_active_fail 70 "cu_screenshot_mime_failed_C06"; fi
  [[ "${r24_mime}" == "image/png" ]] || r24_active_fail 70 "cu_screenshot_mime_C06_${r24_mime}"
  R24_SCREENSHOT_SHA="${r24_published_sha}"
  if R24_SCREENSHOT_BYTES="$(/usr/bin/stat -f '%z' "${R24_SCREENSHOT}")"; then :; else r24_active_fail 70 "cu_screenshot_bytes_failed_C06"; fi
  [[ "${R24_SCREENSHOT_BYTES}" -gt 0 ]] || r24_active_fail 70 "cu_screenshot_empty_C06"
  r24_preview_state_ready_probe || r24_active_fail 70 "cu_state_not_exact_four_after_capture_C06"
  r24_require_live_preview_process "cu_cold_C06_post"
  if r24_now_value="$(r24_capture_now)"; then :; else r24_active_fail 70 "cu_screenshot_timestamp_failed_C06"; fi
  /usr/bin/printf 'control.result=%s\n' "${r24_reply}" >> "${R24_COLD_START_LOG}"
  {
    /usr/bin/printf 'preview.screenshot.published_at=%s\n' "${r24_now_value}"
    /usr/bin/printf 'preview.screenshot.path=%s\n' "${R24_SCREENSHOT}"
    /usr/bin/printf 'preview.screenshot.sha=%s\n' "${R24_SCREENSHOT_SHA}"
    /usr/bin/printf 'preview.screenshot.bytes=%s\n' "${R24_SCREENSHOT_BYTES}"
    /usr/bin/printf 'preview.screenshot.width=%s\n' "${R24_SCREENSHOT_WIDTH}"
    /usr/bin/printf 'preview.screenshot.height=%s\n' "${R24_SCREENSHOT_HEIGHT}"
    /usr/bin/printf '%s\n' 'preview.screenshot.encoding=PNG'
    /usr/bin/printf '%s\n' 'preview.screenshot.full_sips_decode_and_dimension_recheck=PASS'
    /usr/bin/printf '%s\n' 'preview.screenshot.same_directory_publish=PASS'
    /usr/bin/printf '%s\n' 'preview.screenshot.raw_and_stage_cleanup=PASS'
  } >> "${R24_COLD_START_LOG}"
}

r24_run_same_bundle_preview() {
  R24_PHASE="same_bundle_preview_bootstrap"
  r24_require_manifest
  r24_require_r23_predecessor
  r24_require_implementation_baseline
  r24_require_zero_write_predecessors "pre_preview"
  r24_observe_lifecycles "pre_preview" "true"
  r24_start_direct_bootstrap
  r24_cu_exchange_exact bootstrap B01 observe_full_onboarding_state "window_count=1|enter_my_camp_count=1|onboarding_visible=true" false
  r24_cu_exchange_exact bootstrap B02 click_exact_enter_my_camp_from_current_state "clicked_enter_my_camp_count=1" false
  r24_cu_exchange_exact bootstrap B03 observe_full_dashboard_state "window_count=1|feed_hero_exact_count=1|enter_my_camp_count=0|view_all_count=0|dashboard_visible=true" false
  r24_cu_exchange_exact bootstrap B04 click_exact_AgentLoop_application_menu_from_current_state "agentloop_menu_clicked_count=1" false
  r24_cu_exchange_exact bootstrap B05 observe_full_application_menu_state "quit_agentloop_count=1|menu_visible=true" false
  r24_cu_exchange_exact bootstrap B06 click_exact_Quit_AgentLoop_from_current_state "quit_agentloop_clicked_count=1" true
  r24_wait_owned_preview_exit bootstrap

  r24_install_preview_fixture

  R24_PHASE="same_bundle_preview_cold"
  r24_start_direct_cold_preview
  r24_cu_exchange_exact cold C01 observe_full_dashboard_state "window_count=1|feed_hero_exact_count=1|enter_my_camp_count=0|view_all_1_exact_count=1|dashboard_visible=true" false
  r24_cu_exchange_exact cold C02 click_exact_view_all_1_from_current_state "clicked_view_all_1_count=1" false
  r24_cu_exchange_exact cold C03 observe_full_rumination_inbox_state "fixture_title_count=1|view_progress_count=1|inbox_visible=true" false
  r24_cu_exchange_exact cold C04 click_exact_fixture_view_progress_from_current_state "clicked_fixture_view_progress_count=1" false
  r24_cu_exchange_exact cold C05 observe_full_recovering_detail_and_capture_current_screenshot "window_count=1|fixture_title_count=1|source_saved_complete_count=2|recovering_in_progress_count=3|extracting_count=0|organizing_count=0|confirm_count=0|screenshot_nonnull_file_url=true" false
  r24_cu_capture_screenshot
  r24_cu_exchange_exact cold C07 click_exact_AgentLoop_application_menu_from_current_C05_state "agentloop_menu_clicked_count=1" false
  r24_cu_exchange_exact cold C08 observe_full_application_menu_state "quit_agentloop_count=1|menu_visible=true" false
  r24_cu_exchange_exact cold C09 click_exact_Quit_AgentLoop_from_current_state "quit_agentloop_clicked_count=1" true
  r24_wait_owned_preview_exit cold
  r24_append_boundary 'same_bundle_preview=PASS'
  r24_append_boundary 'preview_normal_root_open_observed_count=0'
  r24_append_boundary 'preview_all_observed_processes_exact_isolated_child=true'
  r24_append_boundary 'preview_process_replacement_observed=false'
  r24_append_boundary 'preview_screenshot_true_png=PASS'
}

r24_prepare_impl_report_stage() {
  local r24_now_value=""
  [[ -n "${R24_IMPL_REPORT_STAGE}" ]] || r24_active_fail 70 "impl_report_stage_path_missing"
  [[ "${R24_IMPL_REPORT_STAGE}" == "${R24_TASK_DIRECTORY}/.${R24_INVOCATION_ID}.impl-report-r24.stage.md" ]] || r24_active_fail 70 "impl_report_stage_path_mismatch"
  [[ "${R24_IMPL_REPORT_STAGE_OWNED}" == "false" && "${R24_IMPL_REPORT_PUBLISHED}" == "false" ]] || r24_active_fail 70 "impl_report_stage_state_not_fresh"
  R24_DEFERRED_SIGNAL=""
  R24_DEFERRED_SIGNAL_STATUS=""
  trap 'r24_defer_signal HUP 129' HUP
  trap 'r24_defer_signal INT 130' INT
  trap 'r24_defer_signal TERM 143' TERM
  if r24_exclusive_create_empty "${R24_IMPL_REPORT_STAGE}"; then
    R24_IMPL_REPORT_STAGE_OWNED="true"
  else
    r24_install_signal_traps
    r24_active_fail 71 "exclusive_create_failed_${R24_IMPL_REPORT_STAGE}"
  fi
  r24_install_signal_traps
  if [[ -n "${R24_DEFERRED_SIGNAL}" ]]; then
    r24_active_fail "${R24_DEFERRED_SIGNAL_STATUS}" "deferred_signal_${R24_DEFERRED_SIGNAL}_impl_report_stage_create"
  fi
  if r24_now_value="$(r24_capture_now)"; then :; else r24_active_fail 70 "impl_report_timestamp_failed"; fi
  {
    /usr/bin/printf '%s\n' '# R24 implementation report'
    /usr/bin/printf '\n- Status: `PASS`\n'
    /usr/bin/printf -- '- Completed at: `%s`\n' "${r24_now_value}"
    /usr/bin/printf -- '- Product/test/App/permanent-script delta in R24: `0`\n'
    /usr/bin/printf -- '- Authoritative full run: `652/652`, Swift rc `%s`, tee rc `%s`, same-log audit `46/46`\n' "${R24_AUTHORITATIVE_SWIFT_RC}" "${R24_AUTHORITATIVE_TEE_RC}"
    /usr/bin/printf -- '- Core/Test hashes: `%s` / `%s`\n' "${R24_EXPECTED_CORE_SHA}" "${R24_EXPECTED_TEST_SHA}"
    /usr/bin/printf -- '- Matrix entry restored: `%s`; manifest: `178/178`\n' "${R24_EXPECTED_MATRIX_ENTRY_SHA}"
    /usr/bin/printf -- '- Preview app: `%s`\n' "${R24_APP}"
    /usr/bin/printf -- '- Preview state root: `%s`\n' "${R24_STATE_ROOT}"
    /usr/bin/printf -- '- Screenshot: `%s` (`%s`, %sx%s, %s bytes)\n' "${R24_SCREENSHOT}" "${R24_SCREENSHOT_SHA}" "${R24_SCREENSHOT_WIDTH}" "${R24_SCREENSHOT_HEIGHT}" "${R24_SCREENSHOT_BYTES}"
    /usr/bin/printf -- '- Preview isolation claim: every observed owned process used the exact signed executable and isolated state root; observed normal-root open count was zero. This does not claim an atomic proof about unobserved intervals.\n'
    /usr/bin/printf -- '- The invocation-unique bundle domain may contain the isolated onboarding UserDefaults write; R24 does not claim zero preference writes.\n'
    /usr/bin/printf -- '- R23 remains immutable `REJECTED_CONTAMINATED`; its 652/652 output did not substitute for the R24 run.\n'
    /usr/bin/printf -- '- No commit, push, merge, release, normal-data mutation, external communication, or real-user action was performed.\n'
  } >> "${R24_IMPL_REPORT_STAGE}"
  [[ -s "${R24_IMPL_REPORT_STAGE}" && ! -L "${R24_IMPL_REPORT_STAGE}" ]] || r24_active_fail 70 "impl_report_stage_shape_failed"
  if R24_IMPL_REPORT_STAGE_SHA="$(r24_sha "${R24_IMPL_REPORT_STAGE}")"; then :; else r24_active_fail 70 "impl_report_stage_sha_failed"; fi
  if /usr/bin/python3 - "${R24_IMPL_REPORT_STAGE}" <<'R24_REPORT_PRIVACY'
import re
import sys
from pathlib import Path
pattern = re.compile(rb"sk-[A-Za-z0-9_-]{20,}|Bearer\s+[A-Za-z0-9._-]{20,}|(?:access|refresh|id)_token[\"=:\s]+[A-Za-z0-9._-]{20,}", re.I)
raise SystemExit(71 if pattern.search(Path(sys.argv[1]).read_bytes()) else 0)
R24_REPORT_PRIVACY
  then :; else r24_active_fail 70 "impl_report_stage_privacy_scan_failed"; fi
  r24_require_sha "${R24_IMPL_REPORT_STAGE_SHA}" "${R24_IMPL_REPORT_STAGE}"
}

r24_commit_terminal_success() {
  local r24_end_timestamp="$1"
  local r24_end_block=""
  local r24_published_sha=""
  local r24_publish_rc=0
  local r24_append_rc=0
  [[ "${R24_END_COMMITTED}" == "false" ]] || r24_active_fail 70 "terminal_commit_already_complete"
  [[ "${R24_IMPL_REPORT_STAGE_OWNED}" == "true" && "${R24_IMPL_REPORT_PUBLISHED}" == "false" ]] || r24_active_fail 70 "terminal_commit_report_state_invalid"
  r24_require_sha "${R24_IMPL_REPORT_STAGE_SHA}" "${R24_IMPL_REPORT_STAGE}"
  if printf -v r24_end_block \
    'authorization_consumed=true\nretry_same_boundary=false\nmanifest_final=178_of_178\nproduct_test_app_permanent_script_delta=0\nimpl_report_sha=%s\nscreenshot_sha=%s\nr23_first_mask=%s\nr23_latest_mask=%s\nr20_first_mask=%s\nr20_latest_mask=%s\nutc_end=%s\nstatus=END\nresult=PASS\n' \
    "${R24_IMPL_REPORT_STAGE_SHA}" "${R24_SCREENSHOT_SHA}" \
    "${R24_R23_FIRST_MASK}" "${R24_R23_LATEST_MASK}" \
    "${R24_R20_FIRST_MASK}" "${R24_R20_LATEST_MASK}" "${r24_end_timestamp}"; then
    :
  else
    r24_active_fail 70 "terminal_end_block_render_failed"
  fi
  [[ "${r24_end_block}" == *$'\nstatus=END\nresult=PASS\n' ]] || r24_active_fail 70 "terminal_end_block_shape_invalid"
  R24_PHASE="end_commit"
  r24_require_absent_path "${R24_IMPL_REPORT}"
  r24_require_sha "${R24_IMPL_REPORT_STAGE_SHA}" "${R24_IMPL_REPORT_STAGE}"
  R24_DEFERRED_SIGNAL=""
  R24_DEFERRED_SIGNAL_STATUS=""
  trap 'r24_defer_signal HUP 129' HUP
  trap 'r24_defer_signal INT 130' INT
  trap 'r24_defer_signal TERM 143' TERM
  if /bin/mv -n "${R24_IMPL_REPORT_STAGE}" "${R24_IMPL_REPORT}"; then
    r24_publish_rc=0
  else
    r24_publish_rc="$?"
    r24_install_signal_traps
    r24_active_fail 70 "terminal_report_publish_failed_${r24_publish_rc}"
  fi
  if [[ ! -e "${R24_IMPL_REPORT_STAGE}" && ! -L "${R24_IMPL_REPORT_STAGE}" && -f "${R24_IMPL_REPORT}" && ! -L "${R24_IMPL_REPORT}" ]]; then
    R24_IMPL_REPORT_STAGE_OWNED="false"
    R24_IMPL_REPORT_PUBLISHED="true"
  else
    r24_install_signal_traps
    r24_active_fail 70 "terminal_report_publish_postcondition_failed"
  fi
  if r24_published_sha="$(r24_sha "${R24_IMPL_REPORT}")"; then :; else
    r24_install_signal_traps
    r24_active_fail 70 "terminal_report_published_sha_read_failed"
  fi
  if [[ "${r24_published_sha}" != "${R24_IMPL_REPORT_STAGE_SHA}" ]]; then
    r24_install_signal_traps
    r24_active_fail 70 "terminal_report_published_sha_mismatch"
  fi
  r24_install_signal_traps
  if [[ -n "${R24_DEFERRED_SIGNAL}" ]]; then
    r24_active_fail "${R24_DEFERRED_SIGNAL_STATUS}" "deferred_signal_${R24_DEFERRED_SIGNAL}_report_publish"
  fi
  r24_require_sha "${R24_IMPL_REPORT_STAGE_SHA}" "${R24_IMPL_REPORT}"

  # This is the sole commit-wins signal window: the report is already
  # published and verified, and the next external mutation is one END append.
  R24_DEFERRED_SIGNAL=""
  R24_DEFERRED_SIGNAL_STATUS=""
  trap 'r24_defer_signal HUP 129' HUP
  trap 'r24_defer_signal INT 130' INT
  trap 'r24_defer_signal TERM 143' TERM
  if /usr/bin/printf '%s' "${r24_end_block}" >> "${R24_BOUNDARY_LOG}"; then
    r24_append_rc=0
  else
    r24_append_rc="$?"
    r24_install_signal_traps
    r24_active_fail 70 "terminal_boundary_append_failed_${r24_append_rc}"
  fi
  R24_END_COMMITTED="true" R24_BOUNDARY_ACTIVE="false"
  trap '' HUP INT TERM
  trap - ERR
  return 0
}

r24_run_post_preview_final_gates() {
  local r24_diff_output=""
  local r24_git_status=""
  local r24_runtime_hashes=""
  local r24_path=""
  local r24_now_value=""
  R24_PHASE="post_preview_final_gates"
  r24_require_no_process
  [[ "${R24_CURRENT_ROOT_PHASE}" == "preview_quiescent" ]] || r24_active_fail 70 "final_wrong_root_phase_${R24_CURRENT_ROOT_PHASE}"
  r24_validate_current_roots_phase
  [[ -f "${R24_SCREENSHOT}" && ! -L "${R24_SCREENSHOT}" ]] || r24_active_fail 70 "final_screenshot_type"
  r24_require_sha "${R24_SCREENSHOT_SHA}" "${R24_SCREENSHOT}"
  r24_require_absent_path "${R24_CU_RAW_PATH}"
  r24_require_absent_path "${R24_SCREENSHOT_STAGE}"
  if /usr/bin/python3 - "${R24_VERIFY_LOG}" "${R24_TARGETED_LOG}" "${R24_BUILD_LOG}" "${R24_MATRIX_LOG}" "${R24_BUNDLE_LOG}" "${R24_SOURCE_LOG}" "${R24_BOOTSTRAP_LOG}" "${R24_COLD_START_LOG}" "${R24_BOUNDARY_LOG}" "${R24_HASH_LOG}" <<'R24_FINAL_PRIVACY'
import re
import sys
from pathlib import Path
pattern = re.compile(rb"sk-[A-Za-z0-9_-]{20,}|Bearer\s+[A-Za-z0-9._-]{20,}|(?:access|refresh|id)_token[\"=:\s]+[A-Za-z0-9._-]{20,}", re.I)
for item in sys.argv[1:]:
    if pattern.search(Path(item).read_bytes()):
        raise SystemExit(71)
R24_FINAL_PRIVACY
  then :; else r24_active_fail 70 "final_runtime_privacy_scan_failed"; fi
  r24_require_verify_log_identity "final"
  r24_require_manifest
  r24_require_r23_predecessor
  r24_require_implementation_baseline
  r24_require_branch_and_head
  r24_require_sha "${R24_EXPECTED_MATRIX_ENTRY_SHA}" "${R24_MATRIX_SCRIPT}"
  [[ "${R24_MATRIX_MUTATED}" == "false" ]] || r24_active_fail 70 "final_matrix_mutated"
  r24_require_absent_path "${R24_MATRIX_BACKUP_PATH}"
  r24_require_absent_path "${R24_MATRIX_MUTATED_STAGE}"
  r24_require_absent_path "${R24_MATRIX_RESTORE_STAGE}"
  r24_require_launch_ready_identity "final"
  r24_require_zero_write_predecessors "final_pre_end"
  r24_observe_lifecycles "final_pre_end" "true"
  if r24_diff_output="$(/usr/bin/git --no-optional-locks -C "${R24_REPOSITORY_ROOT}" diff --check)"; then :; else r24_active_fail 70 "final_git_diff_check_failed"; fi
  [[ -z "${r24_diff_output}" ]] || r24_active_fail 70 "final_git_diff_check_output"
  if r24_git_status="$(/usr/bin/git --no-optional-locks -C "${R24_REPOSITORY_ROOT}" status --short --branch)"; then :; else r24_active_fail 70 "final_git_status_failed"; fi
  if r24_runtime_hashes="$({
      for r24_path in \
        "${R24_VERIFY_LOG}" "${R24_TARGETED_LOG}" "${R24_BUILD_LOG}" \
        "${R24_MATRIX_LOG}" "${R24_BUNDLE_LOG}" "${R24_SOURCE_LOG}" \
        "${R24_BOOTSTRAP_LOG}" "${R24_COLD_START_LOG}" "${R24_SCREENSHOT}"; do
        /usr/bin/shasum -a 256 "${r24_path}" || exit "$?"
      done
    })"; then :; else r24_active_fail 70 "final_runtime_hash_capture_failed"; fi
  {
    /usr/bin/printf '%s\n' 'section=post_preview_final'
    /usr/bin/printf '%s\n' 'manifest=178_of_178_PASS'
    /usr/bin/printf '%s\n' 'matrix_restored=true'
    /usr/bin/printf '%s\n' 'privacy_scan=PASS'
    /usr/bin/printf '%s\n' 'normal_root_open_observed_count=0'
    /usr/bin/printf '%s\n' 'all_observed_preview_processes_exact_isolated_child=true'
    /usr/bin/printf '%s\n' 'process_replacement_observed=false'
    /usr/bin/printf '%s\n' 'runtime_hashes_begin'
    /usr/bin/printf '%s\n' "${r24_runtime_hashes}"
    /usr/bin/printf '%s\n' 'runtime_hashes_end'
    /usr/bin/printf 'git_status_begin\n%s\ngit_status_end\n' "${r24_git_status}"
  } >> "${R24_HASH_LOG}"
  r24_prepare_impl_report_stage
  if r24_now_value="$(r24_capture_now)"; then :; else r24_active_fail 70 "end_timestamp_failed"; fi
  r24_commit_terminal_success "${r24_now_value}"
}

if [[ "$#" != "1" ]]; then
  r24_pre_begin_fail 64 "expected_one_review24_sha_argument"
fi
R24_REVIEW24_SHA_ARGUMENT="$1"
[[ "${#R24_REVIEW24_SHA_ARGUMENT}" == "64" ]] || r24_pre_begin_fail 64 "review24_sha_length"
case "${R24_REVIEW24_SHA_ARGUMENT}" in
  *[!0-9a-f]*) r24_pre_begin_fail 64 "review24_sha_format" ;;
esac

R24_PHASE="preflight_static"
r24_require_canonical_entry_paths
r24_require_sha_constant_shapes
r24_require_invocation_environment
r24_require_branch_and_head
r24_require_regular_file "${R24_DRIVER_PATH}"
r24_require_regular_file "${R24_FREEZE_PATH}"
r24_require_review24 "${R24_REVIEW24_SHA_ARGUMENT}"
r24_require_manifest
r24_require_r23_predecessor
r24_require_implementation_baseline
r24_require_no_process
r24_require_fresh_runtime_absence
r24_require_zero_write_predecessors "preflight"

R24_PHASE="preflight_lifecycles"
r24_observe_lifecycles "preflight" "false"

R24_PHASE="final_pre_begin"
r24_require_canonical_entry_paths
r24_require_sha_constant_shapes
r24_require_invocation_environment
r24_require_branch_and_head
r24_require_review24 "${R24_REVIEW24_SHA_ARGUMENT}"
r24_require_manifest
r24_require_r23_predecessor
r24_require_implementation_baseline
r24_require_no_process
r24_require_fresh_runtime_absence
r24_require_zero_write_predecessors "final_pre_begin"
r24_observe_lifecycles "final_pre_begin" "false"

R24_PHASE="exclusive_boundary_create"
R24_DEFERRED_SIGNAL=""
R24_DEFERRED_SIGNAL_STATUS=""
trap 'r24_defer_signal HUP 129' HUP
trap 'r24_defer_signal INT 130' INT
trap 'r24_defer_signal TERM 143' TERM
if r24_exclusive_create_empty "${R24_BOUNDARY_LOG}"; then
  R24_BOUNDARY_ACTIVE="true"
else
  r24_install_signal_traps
  r24_pre_begin_fail 73 "boundary_EEXIST_no_append"
fi
r24_install_signal_traps
if [[ -n "${R24_DEFERRED_SIGNAL}" ]]; then
  r24_active_fail "${R24_DEFERRED_SIGNAL_STATUS}" "deferred_signal_${R24_DEFERRED_SIGNAL}_boundary_activation"
fi

r24_invocation_nonce=""
r24_begin_at=""
r24_begin_attested_at=""
r24_freeze_sha=""
r24_driver_sha=""
r24_manifest_sha=""
r24_git_status=""
r24_verify_size=""
if r24_invocation_nonce="$(r24_new_nonce)"; then :; else r24_active_fail 70 "invocation_nonce_failed"; fi
R24_INVOCATION_ID="r24-${r24_invocation_nonce}"
R24_BUNDLE_IDENTIFIER="com.muzi.agentloop.r24.preview.${r24_invocation_nonce}"
R24_IMPL_REPORT_STAGE="${R24_TASK_DIRECTORY}/.${R24_INVOCATION_ID}.impl-report-r24.stage.md"
[[ "${R24_INVOCATION_ID}" != *[!a-z0-9-]* ]] || r24_active_fail 70 "invocation_id_shape"
[[ "${R24_BUNDLE_IDENTIFIER}" != *[!a-z0-9.]* ]] || r24_active_fail 70 "bundle_identifier_shape"
r24_require_absent_path "${R24_IMPL_REPORT_STAGE}"
r24_require_absent_path "${R24_IMPL_REPORT}"
if r24_begin_at="$(r24_capture_now)"; then :; else r24_active_fail 70 "begin_timestamp_failed"; fi
if r24_freeze_sha="$(r24_sha "${R24_FREEZE_PATH}")"; then :; else r24_active_fail 70 "begin_freeze_sha_failed"; fi
if r24_driver_sha="$(r24_sha "${R24_DRIVER_PATH}")"; then :; else r24_active_fail 70 "begin_driver_sha_failed"; fi
if r24_manifest_sha="$(r24_sha "${R24_MANIFEST_PATH}")"; then :; else r24_active_fail 70 "begin_manifest_sha_failed"; fi
{
  /usr/bin/printf '%s\n' 'boundary_identity=R24_SINGLE_BASH_FULL_CHAIN_AND_ISOLATED_PREVIEW'
  /usr/bin/printf 'invocation_id=%s\n' "${R24_INVOCATION_ID}"
  /usr/bin/printf 'bundle_identifier=%s\n' "${R24_BUNDLE_IDENTIFIER}"
  /usr/bin/printf '%s\n' 'authorization_consumed=true'
  /usr/bin/printf '%s\n' 'status=BEGIN_STARTED'
  /usr/bin/printf 'utc_begin_started=%s\n' "${r24_begin_at}"
  /usr/bin/printf 'freeze_sha=%s\n' "${r24_freeze_sha}"
  /usr/bin/printf 'review24_sha=%s\n' "${R24_REVIEW24_SHA_ARGUMENT}"
  /usr/bin/printf 'driver_sha=%s\n' "${r24_driver_sha}"
  /usr/bin/printf 'manifest_sha=%s\n' "${r24_manifest_sha}"
  /usr/bin/printf 'implementation_core_sha=%s\n' "${R24_EXPECTED_CORE_SHA}"
  /usr/bin/printf 'implementation_test_sha=%s\n' "${R24_EXPECTED_TEST_SHA}"
  /usr/bin/printf '%s\n' 'implementation_entry_source_delta=0'
  /usr/bin/printf '%s\n' 'product_test_app_permanent_script_delta=0'
} >> "${R24_BOUNDARY_LOG}"

R24_PHASE="immediate_post_activation"
r24_require_zero_write_predecessors "immediate_post_activation"
r24_observe_lifecycles "immediate_post_activation" "false"
r24_require_r23_predecessor
r24_require_implementation_baseline
r24_create_runtime_evidence

R24_PHASE="fresh_roots"
if R24_STATE_ROOT="$(/usr/bin/mktemp -d '/private/tmp/agentloop-r24-state.XXXXXX')"; then :; else r24_active_fail 71 "state_mktemp_failed"; fi
if R24_BUNDLE_ROOT="$(/usr/bin/mktemp -d '/private/tmp/agentloop-r24-bundle.XXXXXX')"; then :; else r24_active_fail 71 "bundle_mktemp_failed"; fi
[[ "${R24_STATE_ROOT}" != "${R24_BUNDLE_ROOT}" ]] || r24_active_fail 71 "fresh_roots_equal"
R24_CURRENT_ROOT_PHASE="empty"
r24_validate_current_roots_phase
r24_require_zero_write_predecessors "post_root"
r24_observe_lifecycles "post_root" "true"
if r24_begin_attested_at="$(r24_capture_now)"; then :; else r24_active_fail 70 "begin_attested_timestamp_failed"; fi
{
  /usr/bin/printf 'state_root=%s\n' "${R24_STATE_ROOT}"
  /usr/bin/printf 'bundle_root=%s\n' "${R24_BUNDLE_ROOT}"
  /usr/bin/printf 'r23_lifecycle_baseline=%s\n' "${R24_R23_BASELINE_MASK}"
  /usr/bin/printf 'r23_lifecycle_first=%s\n' "${R24_R23_FIRST_MASK}"
  /usr/bin/printf 'r23_lifecycle_latest=%s\n' "${R24_R23_LATEST_MASK}"
  /usr/bin/printf 'r20_lifecycle_baseline=%s\n' "${R24_R20_BASELINE_MASK}"
  /usr/bin/printf 'r20_lifecycle_first=%s\n' "${R24_R20_FIRST_MASK}"
  /usr/bin/printf 'r20_lifecycle_latest=%s\n' "${R24_R20_LATEST_MASK}"
  /usr/bin/printf 'utc_begin_attested=%s\n' "${r24_begin_attested_at}"
  /usr/bin/printf '%s\n' 'begin_attestation_complete=true'
  /usr/bin/printf '%s\n' 'status=BEGIN_ATTESTED'
  /usr/bin/printf '%s\n' 'retry_same_boundary=false'
} >> "${R24_BOUNDARY_LOG}"
if r24_git_status="$(/usr/bin/git --no-optional-locks -C "${R24_REPOSITORY_ROOT}" status --short --branch)"; then :; else r24_active_fail 70 "entry_git_status_failed"; fi
{
  /usr/bin/printf '%s\n' 'section=static_manifest'
  /usr/bin/printf 'manifest_count=%s\n' "${R24_EXPECTED_MANIFEST_COUNT}"
  /usr/bin/printf 'manifest_sha=%s\n' "${r24_manifest_sha}"
  /usr/bin/printf '%s\n' 'r23_manifest_partition=156_PASS_7_EXPECTED_MISMATCHES'
  /usr/bin/printf '%s\n' 'r23_runtime_artifact_count=10'
  /usr/bin/printf 'r23_impl_report_sha=%s\n' "${R24_EXPECTED_R23_REPORT_SHA}"
  /usr/bin/printf '%s\n' 'r23_screenshot_absent=true'
  /usr/bin/printf 'git_status_begin\n%s\ngit_status_end\n' "${r24_git_status}"
} >> "${R24_HASH_LOG}"

R24_PHASE="post_manifest_pre_full_test_reproof"
r24_require_branch_and_head
r24_require_manifest
r24_require_r23_predecessor
r24_require_implementation_baseline
r24_require_no_process
r24_require_zero_write_predecessors "post_manifest_pre_full_test"
r24_observe_lifecycles "post_manifest_pre_full_test" "true"

r24_run_authoritative_full_test

R24_PHASE="post_full_test_adjacent_reproof"
r24_require_verify_log_identity "post_full_test_adjacent"
if r24_verify_size="$(/usr/bin/stat -f '%z' "${R24_VERIFY_LOG}")"; then :; else r24_active_fail 70 "authoritative_verify_log_size_read_failed"; fi
[[ "${r24_verify_size}" == "${R24_VERIFY_LOG_BYTES}" ]] || r24_active_fail 70 "authoritative_verify_log_size_drift"
r24_require_manifest
r24_require_r23_predecessor
r24_require_implementation_baseline
r24_require_no_process
r24_require_zero_write_predecessors "post_full_test"
r24_observe_lifecycles "post_full_test" "true"

r24_run_same_log_targeted_audit

R24_PHASE="pre_debug_build_bundle_reproof"
r24_require_manifest
r24_require_implementation_baseline
r24_require_verify_log_identity "pre_debug_build"
r24_observe_lifecycles "pre_debug_build" "true"
r24_run_debug_build_and_bundle

R24_PHASE="post_bundle_pre_release_reproof"
r24_require_manifest
r24_require_implementation_baseline
r24_require_verify_log_identity "post_bundle"
r24_require_launch_ready_identity "post_bundle"
r24_observe_lifecycles "post_bundle" "true"
r24_run_guard_shape_and_strip
r24_run_release_and_object_gates

R24_PHASE="pre_matrix_reproof"
r24_require_manifest
r24_require_implementation_baseline
r24_require_verify_log_identity "pre_matrix"
r24_require_launch_ready_identity "pre_matrix"
r24_observe_lifecycles "pre_matrix" "true"
r24_run_matrix_with_mandatory_restore

R24_PHASE="post_matrix_reproof"
r24_require_manifest
r24_require_sha "${R24_EXPECTED_MATRIX_ENTRY_SHA}" "${R24_MATRIX_SCRIPT}"
[[ "${R24_MATRIX_MUTATED}" == "false" ]] || r24_active_fail 70 "post_matrix_mutation_flag"
r24_require_verify_log_identity "post_matrix"
r24_observe_lifecycles "post_matrix" "true"
r24_run_remaining_source_privacy_final_hashes

r24_run_same_bundle_preview
r24_run_post_preview_final_gates

[[ "${R24_END_COMMITTED}" == "true" && "${R24_BOUNDARY_ACTIVE}" == "false" ]] || exit 70
exit 0
