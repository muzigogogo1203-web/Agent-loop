#!/bin/bash

# R22 BEGIN-only candidate driver.
# This file does not run tests, build, migration matrix, source gates, bundle
# assembly, signing, or preview. It establishes one fail-once evidence boundary.

set -Eeuo pipefail
set -f
IFS=$' \t\n'
umask 077

readonly R22_REPOSITORY_ROOT="/Users/muzi/Agent-loop"
readonly R22_TASK_DIRECTORY="${R22_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination"
readonly R22_DRIVER_PATH="${R22_TASK_DIRECTORY}/evidence/r22-begin.sh"
readonly R22_MANIFEST_PATH="${R22_TASK_DIRECTORY}/evidence/r22-entry.sha256"
readonly R22_FREEZE_PATH="${R22_TASK_DIRECTORY}/evidence/plan-freeze-r22.md"
readonly R22_REVIEW22_PATH="${R22_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/22-p1-plan-review.md"
readonly R22_BOUNDARY_LOG="${R22_TASK_DIRECTORY}/evidence/r22-clean-boundary.log"
readonly R22_HASH_LOG="${R22_TASK_DIRECTORY}/evidence/r22-hash-manifest.log"
readonly R22_RANCH_ART_DIRECTORY="${R22_REPOSITORY_ROOT}/Sources/AgentLoopApp/Resources/RanchArt"
readonly R22_EXPECTED_MANIFEST_COUNT="159"
readonly R22_EXPECTED_BRANCH="codex/personal-ai-ranch-p0"
readonly R22_EXPECTED_HEAD="02334ec8d21533be81d93d39191bc7d9b9c24f7f"
readonly R22_EXPECTED_INFO_PLIST_SHA="5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58"
readonly R22_EXPECTED_RANCH_ART_MANIFEST_SHA="4f73a80e821faa64d0a29d797cc12e20d5f88248bbb186e74972af49798ddbab"
readonly R22_R15_STATE_ROOT_BASENAME="agentloop-r15-state.Zq6Jvm"
readonly R22_R15_BUNDLE_PARENT_BASENAME="agentloop-r15-bundle.2xROcy"
readonly R22_R15_STATE_ROOT="/private/tmp/${R22_R15_STATE_ROOT_BASENAME}"
readonly R22_R15_BUNDLE_PARENT="/private/tmp/${R22_R15_BUNDLE_PARENT_BASENAME}"
readonly R22_R15_ABSENCE_PROOF_IDENTITY="private_tmp_parent_enumeration_exact_basename_v1"
readonly R22_R15_PLANNED_APP="${R22_R15_BUNDLE_PARENT}/AgentLoop.app"
readonly R22_R15_SCREENSHOT="${R22_TASK_DIRECTORY}/evidence/r15-preview-smoke.png"
readonly R22_R19_INVOCATION_ID="r19-daef1dab-0fbe-4a03-bab1-422adc18b3d4"
readonly R22_R19_MANIFEST_PATH="${R22_TASK_DIRECTORY}/evidence/r19-entry.sha256"
readonly R22_R19_FREEZE_PATH="${R22_TASK_DIRECTORY}/evidence/plan-freeze-r19.md"
readonly R22_R19_REVIEW_PATH="${R22_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/19-p1-plan-review.md"
readonly R22_R19_STATE_ROOT_BASENAME="agentloop-r19-state.dNgUXh"
readonly R22_R19_BUNDLE_PARENT_BASENAME="agentloop-r19-bundle.49xVDm"
readonly R22_R19_STATE_ROOT="/private/tmp/agentloop-r19-state.dNgUXh"
readonly R22_R19_BUNDLE_PARENT="/private/tmp/agentloop-r19-bundle.49xVDm"
readonly R22_R19_PLANNED_APP="${R22_R19_BUNDLE_PARENT}/AgentLoop.app"
readonly R22_R19_SCREENSHOT="${R22_TASK_DIRECTORY}/evidence/r19-preview-smoke.png"
readonly R22_R19_BOUNDARY_LOG="${R22_TASK_DIRECTORY}/evidence/r19-clean-boundary.log"
readonly R22_R19_HASH_LOG="${R22_TASK_DIRECTORY}/evidence/r19-hash-manifest.log"
readonly R22_R19_TARGETED_LOG="${R22_TASK_DIRECTORY}/r19-targeted-tests.log"
readonly R22_R19_VERIFY_LOG="${R22_TASK_DIRECTORY}/r19-verify.log"
readonly R22_R19_REPORT="${R22_TASK_DIRECTORY}/impl-report-r19.md"
readonly R22_R20_INVOCATION_ID="r20-98452cde-0ff4-4b66-b3f6-8085eb045a6f"
readonly R22_R20_MANIFEST_PATH="${R22_TASK_DIRECTORY}/evidence/r20-entry.sha256"
readonly R22_R20_FREEZE_PATH="${R22_TASK_DIRECTORY}/evidence/plan-freeze-r20.md"
readonly R22_R20_REVIEW_PATH="${R22_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/20-p1-plan-review.md"
readonly R22_R20_STATE_ROOT_BASENAME="agentloop-r20-state.3QwlQa"
readonly R22_R20_BUNDLE_PARENT_BASENAME="agentloop-r20-bundle.30V5RH"
readonly R22_R20_STATE_ROOT="/private/tmp/agentloop-r20-state.3QwlQa"
readonly R22_R20_BUNDLE_PARENT="/private/tmp/agentloop-r20-bundle.30V5RH"
readonly R22_R20_APP="${R22_R20_BUNDLE_PARENT}/AgentLoop.app"
readonly R22_R20_EXECUTABLE="${R22_R20_APP}/Contents/MacOS/AgentLoop"
readonly R22_R20_INFO_PLIST="${R22_R20_APP}/Contents/Info.plist"
readonly R22_R20_SCREENSHOT="${R22_TASK_DIRECTORY}/evidence/r20-preview-smoke.png"
readonly R22_R20_BOUNDARY_LOG="${R22_TASK_DIRECTORY}/evidence/r20-clean-boundary.log"
readonly R22_R20_HASH_LOG="${R22_TASK_DIRECTORY}/evidence/r20-hash-manifest.log"
readonly R22_R20_TARGETED_LOG="${R22_TASK_DIRECTORY}/r20-targeted-tests.log"
readonly R22_R20_VERIFY_LOG="${R22_TASK_DIRECTORY}/r20-verify.log"
readonly R22_R20_BUILD_LOG="${R22_TASK_DIRECTORY}/r20-build.log"
readonly R22_R20_REPORT="${R22_TASK_DIRECTORY}/impl-report-r20.md"
readonly R22_R20_EXECUTABLE_SHA="d55fc10e674b77b480a85de46137eff40d40bd94b27c8e33b0d49f55d40a049c"
readonly R22_R20_INFO_PLIST_SHA="5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58"
readonly R22_R20_SIGNED_BUNDLE_MANIFEST_SHA="06e063d4fdd541a808c78eacc5b34ddfd64874a3ab1648bbfe6bf74646db8170"
readonly R22_R20_CORE_FINAL_SHA="c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275"
readonly R22_R20_TEST_FINAL_SHA="66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26"
readonly R22_R21_DRIVER_PATH="${R22_TASK_DIRECTORY}/evidence/r21-begin.sh"
readonly R22_R21_MANIFEST_PATH="${R22_TASK_DIRECTORY}/evidence/r21-entry.sha256"
readonly R22_R21_FREEZE_PATH="${R22_TASK_DIRECTORY}/evidence/plan-freeze-r21.md"
readonly R22_R21_REVIEW_PATH="${R22_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/21-p1-plan-review.md"
readonly R22_IMPLEMENTATION_CORE_PATH="${R22_REPOSITORY_ROOT}/Sources/AgentLoopCore/Loop/AgentLoop.swift"
readonly R22_IMPLEMENTATION_TEST_PATH="${R22_REPOSITORY_ROOT}/Sources/AgentLoopTestSuite/AgentLoopTests.swift"

R22_BOUNDARY_ACTIVE="false"
R22_BOUNDARY_INITIALIZED="false"
R22_PHASE="pre_begin"
R22_INVOCATION_ID=""
R22_STATE_ROOT=""
R22_BUNDLE_PARENT=""
R22_R20_BUNDLE_FIRST_OBSERVED_STATE=""
R22_R20_BUNDLE_PRE_BEGIN_STATE=""
R22_R20_BUNDLE_POST_ACTIVATION_STATE=""
R22_R20_BUNDLE_CURRENT_STATE=""

r22_utc_now() {
  /bin/date -u '+%Y-%m-%dT%H:%M:%SZ'
}

r22_pre_begin_fail() {
  local r22_exit_code="$1"
  shift
  /usr/bin/printf 'R22 pre-BEGIN rejected: %s\n' "$*" >&2
  exit "$r22_exit_code"
}

r22_append_boundary() {
  /usr/bin/printf '%s\n' "$*" >> "${R22_BOUNDARY_LOG}"
}

r22_authorization_is_consumed() {
  if [[ "${R22_BOUNDARY_ACTIVE}" == "true" ]]; then
    return 0
  fi
  if [[ -n "${R22_INVOCATION_ID}" &&
        -f "${R22_BOUNDARY_LOG}" &&
        ! -L "${R22_BOUNDARY_LOG}" ]] &&
     /usr/bin/grep -Fx "invocation_id=${R22_INVOCATION_ID}" "${R22_BOUNDARY_LOG}" >/dev/null 2>&1 &&
     /usr/bin/grep -Fx 'authorization_consumed=true' "${R22_BOUNDARY_LOG}" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

r22_active_fail() {
  local r22_exit_code="$1"
  local r22_reason="$2"
  local r22_command="${3:-explicit_fail_closed}"
  trap - ERR HUP INT TERM
  set +e
  if [[ "${R22_BOUNDARY_INITIALIZED}" != "true" ]]; then
    /usr/bin/printf '\n' >> "${R22_BOUNDARY_LOG}"
    r22_append_boundary "recovery_invocation_id=${R22_INVOCATION_ID}"
    r22_append_boundary "recovery_authorization_consumed=true"
    r22_append_boundary "recovery_boundary_exclusive_create_succeeded=true"
    r22_append_boundary "boundary_initialization_complete=false"
  fi
  r22_append_boundary "utc=$(r22_utc_now)"
  r22_append_boundary "status=REJECTED_CONTAMINATED"
  r22_append_boundary "phase=${R22_PHASE}"
  r22_append_boundary "reason=${r22_reason}"
  printf 'failed_command=%q\n' "${r22_command}" >> "${R22_BOUNDARY_LOG}"
  r22_append_boundary "exit_code=${r22_exit_code}"
  r22_append_boundary "state_root=${R22_STATE_ROOT:-UNCREATED}"
  r22_append_boundary "bundle_parent=${R22_BUNDLE_PARENT:-UNCREATED}"
  if [[ -n "${R22_PLANNED_APP:-}" ]]; then
    r22_append_boundary "planned_app=${R22_PLANNED_APP}"
  fi
  r22_append_boundary "retry_same_boundary=false"
  /usr/bin/printf 'R22 rejected after authorization consumption: %s\n' "${r22_reason}" >&2
  exit "$r22_exit_code"
}

r22_unexpected_error() {
  local r22_exit_code="$?"
  local r22_command="${BASH_COMMAND:-unknown}"
  trap - ERR
  if r22_authorization_is_consumed; then
    r22_active_fail "${r22_exit_code}" "unexpected_command_failure" "${r22_command}"
  fi
  printf 'R22 pre-BEGIN command failed: phase=%s rc=%s command=%q\n' \
    "${R22_PHASE}" "${r22_exit_code}" "${r22_command}" >&2
  exit "${r22_exit_code}"
}

r22_signal_error() {
  local r22_signal="$1"
  trap - HUP INT TERM
  if r22_authorization_is_consumed; then
    r22_active_fail "74" "signal_${r22_signal}" "signal_${r22_signal}"
  fi
  /usr/bin/printf 'R22 pre-BEGIN interrupted by signal %s\n' "${r22_signal}" >&2
  exit 74
}

trap r22_unexpected_error ERR
trap 'r22_signal_error HUP' HUP
trap 'r22_signal_error INT' INT
trap 'r22_signal_error TERM' TERM

r22_attestation_fail() {
  local r22_exit_code="$1"
  shift
  if r22_authorization_is_consumed; then
    r22_active_fail "${r22_exit_code}" "$*"
  fi
  r22_pre_begin_fail "${r22_exit_code}" "$*"
}

r22_require_lowercase_sha256() {
  local r22_value="$1"
  local r22_label="$2"
  if [[ "${#r22_value}" -ne 64 ]]; then
    r22_pre_begin_fail 64 "${r22_label} must be exactly 64 lowercase hex characters"
  fi
  case "${r22_value}" in
    *[!0-9a-f]*)
      r22_pre_begin_fail 64 "${r22_label} must be exactly 64 lowercase hex characters"
      ;;
  esac
}

r22_load_review22_machine_block() {
  local r22_review_values
  local r22_review_values_rc
  local r22_review_freeze_sha
  local r22_review_driver_sha
  local r22_review_manifest_sha
  local r22_review_extra
  if [[ ! -f "${R22_REVIEW22_PATH}" || -L "${R22_REVIEW22_PATH}" ]]; then
    r22_pre_begin_fail 65 "Review22 is missing, non-regular, or a symlink"
  fi
  if r22_review_values="$(
    trap - ERR
    /usr/bin/awk '
      BEGIN {
        in_block = 0
        begin_count = 0
        end_count = 0
        block_line_count = 0
        authority_count = 0
        standing_goal_count = 0
        independence_count = 0
        write_scope_count = 0
        echo_count = 0
        verdict_count = 0
        human_verdict_count = 0
        other_human_verdict_count = 0
        freeze_count = 0
        driver_count = 0
        manifest_count = 0
        branch_count = 0
        head_count = 0
        count_count = 0
      }
      $0 == "R22_MACHINE_BLOCK_BEGIN" {
        begin_count++
        if (in_block != 0) exit 2
        in_block = 1
        next
      }
      $0 == "R22_MACHINE_BLOCK_END" {
        end_count++
        if (in_block != 1) exit 2
        in_block = 0
        next
      }
      in_block == 1 {
        block_line_count++
        if ($0 == "authority_mode=standing_goal_automatic_after_review22") authority_count++
        else if ($0 == "standing_goal_authority_verified=true") standing_goal_count++
        else if ($0 == "reviewer_independence_attested=true") independence_count++
        else if ($0 == "reviewer_write_scope=review22_only") write_scope_count++
        else if ($0 == "user_hash_echo_required=false") echo_count++
        else if ($0 == "review_verdict=APPROVED_0_P0_0_P1") verdict_count++
        else if (index($0, "freeze_sha=") == 1) {
          freeze_count++
          freeze_sha = substr($0, 12)
        }
        else if (index($0, "driver_sha=") == 1) {
          driver_count++
          driver_sha = substr($0, 12)
        }
        else if (index($0, "manifest_sha=") == 1) {
          manifest_count++
          manifest_sha = substr($0, 14)
        }
        else if ($0 == "branch=codex/personal-ai-ranch-p0") branch_count++
        else if ($0 == "head=02334ec8d21533be81d93d39191bc7d9b9c24f7f") head_count++
        else if ($0 == "manifest_count=159") count_count++
        else exit 2
        next
      }
      $0 == "Verdict: APPROVED — 0 P0 / 0 P1" {
        human_verdict_count++
        next
      }
      index($0, "Verdict:") == 1 {
        other_human_verdict_count++
        next
      }
      END {
        if (in_block != 0 ||
            begin_count != 1 || end_count != 1 || block_line_count != 12 ||
            authority_count != 1 || standing_goal_count != 1 ||
            independence_count != 1 || write_scope_count != 1 ||
            echo_count != 1 || verdict_count != 1 || human_verdict_count != 1 ||
            other_human_verdict_count != 0 ||
            freeze_count != 1 || driver_count != 1 || manifest_count != 1 ||
            branch_count != 1 || head_count != 1 || count_count != 1 ||
            length(freeze_sha) != 64 || freeze_sha ~ /[^0-9a-f]/ ||
            length(driver_sha) != 64 || driver_sha ~ /[^0-9a-f]/ ||
            length(manifest_sha) != 64 || manifest_sha ~ /[^0-9a-f]/) exit 2
        printf "%s %s %s\n", freeze_sha, driver_sha, manifest_sha
      }
    ' "${R22_REVIEW22_PATH}"
  )"; then
    r22_review_values_rc=0
  else
    r22_review_values_rc="$?"
  fi
  if [[ "${r22_review_values_rc}" -ne 0 ]]; then
    r22_pre_begin_fail 65 "Review22 machine block validation failed with rc=${r22_review_values_rc}"
  fi
  r22_review_extra=""
  IFS=' ' read -r \
    r22_review_freeze_sha \
    r22_review_driver_sha \
    r22_review_manifest_sha \
    r22_review_extra <<< "${r22_review_values}"
  if [[ -n "${r22_review_extra}" ||
        -z "${r22_review_freeze_sha}" ||
        -z "${r22_review_driver_sha}" ||
        -z "${r22_review_manifest_sha}" ]]; then
    r22_pre_begin_fail 65 "Review22 machine block output shape is invalid"
  fi
  R22_EXPECTED_FREEZE_SHA="${r22_review_freeze_sha}"
  R22_EXPECTED_DRIVER_SHA="${r22_review_driver_sha}"
  R22_EXPECTED_MANIFEST_SHA="${r22_review_manifest_sha}"
}

r22_emit_anchor_manifest() {
  /usr/bin/printf '%s  %s\n' "${R22_EXPECTED_FREEZE_SHA}" "${R22_FREEZE_PATH}"
  /usr/bin/printf '%s  %s\n' "${R22_EXPECTED_REVIEW22_SHA}" "${R22_REVIEW22_PATH}"
  /usr/bin/printf '%s  %s\n' "${R22_EXPECTED_DRIVER_SHA}" "${R22_DRIVER_PATH}"
  /usr/bin/printf '%s  %s\n' "${R22_EXPECTED_MANIFEST_SHA}" "${R22_MANIFEST_PATH}"
}

r22_check_anchors_to_stdout() {
  local -a r22_anchor_status
  if r22_emit_anchor_manifest |
    /usr/bin/shasum -a 256 --strict -c -; then
    r22_anchor_status=( "${PIPESTATUS[@]}" )
  else
    r22_anchor_status=( "${PIPESTATUS[@]}" )
  fi
  if [[ "${r22_anchor_status[0]}" -ne 0 || "${r22_anchor_status[1]}" -ne 0 ]]; then
    r22_pre_begin_fail 65 "terminal anchor verification failed with producer_rc=${r22_anchor_status[0]} shasum_rc=${r22_anchor_status[1]}"
  fi
}

r22_manifest_contains_path() {
  local r22_manifest_file="$1"
  local r22_expected_path="$2"
  local r22_manifest_line
  local r22_manifest_entry_path
  while IFS= read -r r22_manifest_line || [[ -n "${r22_manifest_line}" ]]; do
    r22_manifest_entry_path="${r22_manifest_line#*  }"
    if [[ "${r22_manifest_entry_path}" == "${r22_expected_path}" ]]; then
      return 0
    fi
  done < "${r22_manifest_file}"
  return 1
}

r22_check_manifest_shape() {
  local r22_manifest_count
  local r22_manifest_count_rc
  local r22_r21_manifest_count
  local r22_r21_manifest_count_rc
  local r22_r21_manifest_line
  local r22_r21_manifest_entry_path
  local r22_required_addition
  local -a r22_required_additions=(
    "${R22_DRIVER_PATH}"
    "${R22_R21_MANIFEST_PATH}"
    "${R22_R21_FREEZE_PATH}"
    "${R22_R21_REVIEW_PATH}"
  )
  if [[ ! -f "${R22_MANIFEST_PATH}" || -L "${R22_MANIFEST_PATH}" ]]; then
    r22_attestation_fail 66 "static manifest is missing, non-regular, or a symlink"
  fi
  if r22_manifest_count="$(
    trap - ERR
    /usr/bin/awk 'END { print NR }' "${R22_MANIFEST_PATH}"
  )"; then
    r22_manifest_count_rc=0
  else
    r22_manifest_count_rc="$?"
  fi
  if [[ "${r22_manifest_count_rc}" -ne 0 ]]; then
    r22_attestation_fail 66 "static manifest record count failed with rc=${r22_manifest_count_rc}"
  fi
  if [[ "${r22_manifest_count}" != "${R22_EXPECTED_MANIFEST_COUNT}" ]]; then
    r22_attestation_fail 66 "static manifest entry count is ${r22_manifest_count}, expected ${R22_EXPECTED_MANIFEST_COUNT}"
  fi
  if /usr/bin/grep -F -- "  ${R22_MANIFEST_PATH}" "${R22_MANIFEST_PATH}" >/dev/null 2>&1; then
    r22_attestation_fail 66 "static manifest must not contain itself"
  fi
  if /usr/bin/grep -F -- "  ${R22_FREEZE_PATH}" "${R22_MANIFEST_PATH}" >/dev/null 2>&1; then
    r22_attestation_fail 66 "static manifest must not contain the R22 freeze"
  fi
  if /usr/bin/grep -F -- "  ${R22_REVIEW22_PATH}" "${R22_MANIFEST_PATH}" >/dev/null 2>&1; then
    r22_attestation_fail 66 "static manifest must not contain Review22"
  fi
  if ! /usr/bin/cut -c 67- "${R22_MANIFEST_PATH}" | LC_ALL=C /usr/bin/sort -cu; then
    r22_attestation_fail 66 "static manifest paths are not bytewise sorted and unique"
  fi
  while IFS= read -r r22_manifest_line || [[ -n "${r22_manifest_line}" ]]; do
    local r22_manifest_entry_path="${r22_manifest_line#*  }"
    case "${r22_manifest_entry_path}" in
      "${R22_REPOSITORY_ROOT}"/*)
        ;;
      *)
        r22_attestation_fail 66 "static manifest entry is outside the repository"
        ;;
    esac
    case "${r22_manifest_entry_path}" in
      *"/../"*|*"/./"*|*/..|*/.)
        r22_attestation_fail 66 "static manifest entry contains a non-canonical path segment"
        ;;
    esac
    if [[ ! -f "${r22_manifest_entry_path}" || -L "${r22_manifest_entry_path}" ]]; then
      r22_attestation_fail 66 "static manifest entry is non-regular or a symlink: ${r22_manifest_entry_path}"
    fi
  done < "${R22_MANIFEST_PATH}"

  if ! /usr/bin/grep -Fx -- \
      "${R22_R20_CORE_FINAL_SHA}  ${R22_IMPLEMENTATION_CORE_PATH}" \
      "${R22_MANIFEST_PATH}" >/dev/null 2>&1; then
    r22_attestation_fail 66 "R22 manifest does not pin the immutable R20-final Core source"
  fi
  if ! /usr/bin/grep -Fx -- \
      "${R22_R20_TEST_FINAL_SHA}  ${R22_IMPLEMENTATION_TEST_PATH}" \
      "${R22_MANIFEST_PATH}" >/dev/null 2>&1; then
    r22_attestation_fail 66 "R22 manifest does not pin the R20-final TestSuite entry source"
  fi

  if [[ ! -f "${R22_R21_MANIFEST_PATH}" || -L "${R22_R21_MANIFEST_PATH}" ]]; then
    r22_attestation_fail 66 "immutable R21 manifest is missing, non-regular, or a symlink"
  fi
  if r22_r21_manifest_count="$(
    trap - ERR
    /usr/bin/awk 'END { print NR }' "${R22_R21_MANIFEST_PATH}"
  )"; then
    r22_r21_manifest_count_rc=0
  else
    r22_r21_manifest_count_rc="$?"
  fi
  if [[ "${r22_r21_manifest_count_rc}" -ne 0 ]]; then
    r22_attestation_fail 66 "immutable R21 manifest record count failed with rc=${r22_r21_manifest_count_rc}"
  fi
  if [[ "${r22_r21_manifest_count}" != "155" ]]; then
    r22_attestation_fail 66 "immutable R21 manifest no longer has exactly 155 entries"
  fi
  if ! /usr/bin/cut -c 67- "${R22_R21_MANIFEST_PATH}" | LC_ALL=C /usr/bin/sort -cu; then
    r22_attestation_fail 66 "immutable R21 manifest paths are not bytewise sorted and unique"
  fi
  if [[ "${#r22_required_additions[@]}" -ne 4 ]]; then
    r22_attestation_fail 66 "R22 required-addition set no longer has exactly 4 paths"
  fi
  while IFS= read -r r22_r21_manifest_line || [[ -n "${r22_r21_manifest_line}" ]]; do
    r22_r21_manifest_entry_path="${r22_r21_manifest_line#*  }"
    if ! r22_manifest_contains_path "${R22_MANIFEST_PATH}" "${r22_r21_manifest_entry_path}"; then
      r22_attestation_fail 66 "R22 manifest does not inherit the complete R21 path set"
    fi
  done < "${R22_R21_MANIFEST_PATH}"
  for r22_required_addition in "${r22_required_additions[@]}"; do
    if r22_manifest_contains_path "${R22_R21_MANIFEST_PATH}" "${r22_required_addition}"; then
      r22_attestation_fail 66 "R22 required addition unexpectedly overlaps the R21 path set"
    fi
    if ! r22_manifest_contains_path "${R22_MANIFEST_PATH}" "${r22_required_addition}"; then
      r22_attestation_fail 66 "R22 manifest is missing a required addition"
    fi
  done
}

r22_check_manifest_to_stdout() {
  local r22_manifest_rc
  if /usr/bin/shasum -a 256 --strict -c "${R22_MANIFEST_PATH}"; then
    r22_manifest_rc=0
  else
    r22_manifest_rc="$?"
  fi
  if [[ "${r22_manifest_rc}" -ne 0 ]]; then
    r22_pre_begin_fail 66 "static manifest verification failed with rc=${r22_manifest_rc}"
  fi
}

r22_require_process_absent() {
  local r22_process_name="$1"
  local r22_process_rc
  if /usr/bin/pgrep -x "${r22_process_name}" >/dev/null 2>&1; then
    r22_process_rc=0
  else
    r22_process_rc="$?"
  fi
  case "${r22_process_rc}" in
    1)
      ;;
    0)
      r22_attestation_fail 69 "${r22_process_name} process is present"
      ;;
    *)
      r22_attestation_fail 69 "pgrep for ${r22_process_name} was indeterminate with rc=${r22_process_rc}"
      ;;
  esac
}

r22_require_absent_path() {
  local r22_path="$1"
  if [[ -e "${r22_path}" || -L "${r22_path}" ]]; then
    r22_attestation_fail 68 "runtime artifact already exists: ${r22_path}"
  fi
}

r22_probe_empty_directory() {
  local r22_path="$1"
  local r22_probe_output
  local r22_probe_rc
  if r22_probe_output="$(
    trap - ERR
    /usr/bin/find "${r22_path}" -mindepth 1 -maxdepth 1 -print -quit 2>&1
  )"; then
    r22_probe_rc=0
  else
    r22_probe_rc="$?"
  fi
  if [[ "${r22_probe_rc}" -ne 0 ]]; then
    return 2
  fi
  if [[ -n "${r22_probe_output}" ]]; then
    return 1
  fi
  return 0
}

r22_require_r15_tombstones_absent() {
  local r22_r15_tombstone_probe_output
  local r22_r15_tombstone_probe_rc
  if [[ -z "${R22_R15_STATE_ROOT_BASENAME}" ||
        "${R22_R15_STATE_ROOT_BASENAME}" == "." ||
        "${R22_R15_STATE_ROOT_BASENAME}" == ".." ||
        -z "${R22_R15_BUNDLE_PARENT_BASENAME}" ||
        "${R22_R15_BUNDLE_PARENT_BASENAME}" == "." ||
        "${R22_R15_BUNDLE_PARENT_BASENAME}" == ".." ||
        "${R22_R15_STATE_ROOT_BASENAME}" == "${R22_R15_BUNDLE_PARENT_BASENAME}" ]]; then
    r22_pre_begin_fail 70 "R15 tombstone basenames are invalid or non-distinct"
  fi
  if [[ "${R22_R15_STATE_ROOT_BASENAME}" != "agentloop-r15-state.Zq6Jvm" ||
        "${R22_R15_BUNDLE_PARENT_BASENAME}" != "agentloop-r15-bundle.2xROcy" ||
        "${R22_R15_STATE_ROOT}" != "/private/tmp/agentloop-r15-state.Zq6Jvm" ||
        "${R22_R15_BUNDLE_PARENT}" != "/private/tmp/agentloop-r15-bundle.2xROcy" ]]; then
    r22_pre_begin_fail 70 "R15 tombstone frozen basename or path identity drifted"
  fi
  if [[ "${R22_R15_STATE_ROOT}" != "/private/tmp/${R22_R15_STATE_ROOT_BASENAME}" ||
        "${R22_R15_BUNDLE_PARENT}" != "/private/tmp/${R22_R15_BUNDLE_PARENT_BASENAME}" ]]; then
    r22_pre_begin_fail 70 "R15 tombstone path reconstruction failed"
  fi
  if [[ ! -d /private/tmp || -L /private/tmp ]]; then
    r22_pre_begin_fail 70 "R15 tombstone parent is missing, non-directory, or symlink: /private/tmp"
  fi
  if r22_r15_tombstone_probe_output="$(
    trap - ERR
    /usr/bin/find /private/tmp \
      -mindepth 1 -maxdepth 1 \
      \( \
        -name "${R22_R15_STATE_ROOT_BASENAME}" -o \
        -name "${R22_R15_BUNDLE_PARENT_BASENAME}" \
      \) \
      -print -quit 2>&1
  )"; then
    r22_r15_tombstone_probe_rc=0
  else
    r22_r15_tombstone_probe_rc="$?"
  fi
  if [[ "${r22_r15_tombstone_probe_rc}" -ne 0 ]]; then
    r22_pre_begin_fail 70 "R15 tombstone absence parent enumeration was indeterminate with rc=${r22_r15_tombstone_probe_rc}"
  fi
  if [[ -n "${r22_r15_tombstone_probe_output}" ]]; then
    r22_pre_begin_fail 70 "R15 tombstoned volatile root reappeared: ${r22_r15_tombstone_probe_output}"
  fi
  if [[ -e "${R22_R15_STATE_ROOT}" || -L "${R22_R15_STATE_ROOT}" ]]; then
    r22_pre_begin_fail 70 "R15 tombstoned state root reappeared after parent enumeration: ${R22_R15_STATE_ROOT}"
  fi
  if [[ -e "${R22_R15_BUNDLE_PARENT}" || -L "${R22_R15_BUNDLE_PARENT}" ]]; then
    r22_pre_begin_fail 70 "R15 tombstoned bundle parent reappeared after parent enumeration: ${R22_R15_BUNDLE_PARENT}"
  fi
}

r22_require_no_unconsumed_fresh_roots() {
  local r22_verification_mode="$1"
  local -a r22_root_pipeline_status
  case "${r22_verification_mode}" in
    pre_begin|post_activation)
      ;;
    *)
      r22_attestation_fail 64 "invalid historical fresh-root verification mode: ${r22_verification_mode}"
      ;;
  esac
  if [[ ! -d /private/tmp || -L /private/tmp ]]; then
    r22_attestation_fail 70 "historical fresh-root parent is missing, non-directory, or symlink"
  fi
  if /usr/bin/find -P /private/tmp -mindepth 1 -maxdepth 1 -print0 2>/dev/null |
    /bin/bash --noprofile --norc -c '
      set -uo pipefail
      set -f
      IFS=$'"'"' \t\n'"'"'
      set +H
      if ! shopt -u nocasematch; then
        exit 2
      fi
      mode="$1"
      actual_path=""
      read_rc=1
      partial_final_record=0
      matched_root_count=0
      while :; do
        actual_path=""
        if IFS= read -r -d "" actual_path; then
          case "${actual_path}" in
            /private/tmp/agentloop-r16-state.*|/private/tmp/agentloop-r16-bundle.*|\
            /private/tmp/agentloop-r17-state.*|/private/tmp/agentloop-r17-bundle.*|\
            /private/tmp/agentloop-r18-state.*|/private/tmp/agentloop-r18-bundle.*|\
            /private/tmp/agentloop-r21-state.*|/private/tmp/agentloop-r21-bundle.*)
              matched_root_count=$(( matched_root_count + 1 ))
              ;;
            /private/tmp/agentloop-r22-state.*|/private/tmp/agentloop-r22-bundle.*)
              if [[ "${mode}" == "pre_begin" ]]; then
                matched_root_count=$(( matched_root_count + 1 ))
              fi
              ;;
          esac
        else
          read_rc="$?"
          if [[ -n "${actual_path}" ]]; then
            partial_final_record=1
          fi
          break
        fi
      done
      if [[ "${read_rc}" -ne 1 ||
            "${partial_final_record}" -ne 0 ||
            "${matched_root_count}" -ne 0 ]]; then
        exit 1
      fi
    ' -- "${r22_verification_mode}"; then
    r22_root_pipeline_status=( "${PIPESTATUS[@]}" )
  else
    r22_root_pipeline_status=( "${PIPESTATUS[@]}" )
  fi
  if [[ "${#r22_root_pipeline_status[@]}" -ne 2 ||
        "${r22_root_pipeline_status[0]}" -ne 0 ||
        "${r22_root_pipeline_status[1]}" -ne 0 ]]; then
    r22_attestation_fail 70 \
      "historical fresh-root full-parent verification failed in ${r22_verification_mode} with find_rc=${r22_root_pipeline_status[0]:-MISSING} validator_rc=${r22_root_pipeline_status[1]:-MISSING}"
  fi
}

r22_exclusive_create_empty() {
  local r22_path="$1"
  ( set -C; : > "${r22_path}" )
}

r22_require_fresh_root() {
  local r22_path="$1"
  local r22_label="$2"
  local r22_probe_rc
  local r22_realpath
  local r22_realpath_rc
  if [[ ! -d "${r22_path}" || -L "${r22_path}" ]]; then
    r22_active_fail 72 "${r22_label}_invalid_type"
  fi
  if r22_realpath="$(
    trap - ERR
    /bin/realpath "${r22_path}" 2>&1
  )"; then
    r22_realpath_rc=0
  else
    r22_realpath_rc="$?"
  fi
  if [[ "${r22_realpath_rc}" -ne 0 ]]; then
    r22_active_fail 72 "${r22_label}_realpath_probe_failed"
  fi
  if [[ "${r22_realpath}" != "${r22_path}" ]]; then
    r22_active_fail 72 "${r22_label}_realpath_mismatch"
  fi
  if r22_probe_empty_directory "${r22_path}"; then
    return 0
  else
    r22_probe_rc="$?"
  fi
  if [[ "${r22_probe_rc}" -eq 1 ]]; then
    r22_active_fail 72 "${r22_label}_not_empty"
  fi
  r22_active_fail 72 "${r22_label}_emptiness_probe_indeterminate"
}

r22_emit_r19_artifact_manifest() {
  /usr/bin/printf '%s  %s\n' \
    "501957999e7a8103e553cb580d9b70f0825ee79a5c9a89e4b47e13c5db350f45" "${R22_R19_TARGETED_LOG}" \
    "8ef56ce31c3e01c551e4ef65c98ce43e3631ad7554b56640e943cdb0ce5d5c15" "${R22_R19_VERIFY_LOG}" \
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "${R22_TASK_DIRECTORY}/r19-build.log" \
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "${R22_TASK_DIRECTORY}/r19-migration-matrix.log" \
    "cddaffeaf553ff72b8f40ea1748baad649d98f747ff2210722f8fd1c388aceec" "${R22_R19_REPORT}" \
    "a5e1b1b8edda476204f4b0fbcc01f90e3e6bced1dee07daf4d58b9f4e143ca30" "${R22_R19_BOUNDARY_LOG}" \
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "${R22_TASK_DIRECTORY}/evidence/r19-bundle-provenance.log" \
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "${R22_TASK_DIRECTORY}/evidence/r19-source-gates.log" \
    "43e9d2eb00c0a63d5071b0c17f2cdc4c5809530788e893b4ffb0381e60e1aff8" "${R22_R19_HASH_LOG}" \
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "${R22_TASK_DIRECTORY}/evidence/r19-preview-bootstrap.log" \
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "${R22_TASK_DIRECTORY}/evidence/r19-preview-cold-start.log"
}

r22_require_r19_tombstones_absent() {
  local -a r22_r19_tombstone_status
  if [[ "${R22_R19_STATE_ROOT}" != "/private/tmp/${R22_R19_STATE_ROOT_BASENAME}" ||
        "${R22_R19_BUNDLE_PARENT}" != "/private/tmp/${R22_R19_BUNDLE_PARENT_BASENAME}" ||
        "${R22_R19_STATE_ROOT_BASENAME}" == "${R22_R19_BUNDLE_PARENT_BASENAME}" ]]; then
    r22_attestation_fail 70 "R19 tombstone frozen identities drifted"
  fi
  if [[ ! -d /private/tmp || -L /private/tmp ]]; then
    r22_attestation_fail 70 "R19 tombstone parent is missing, non-directory, or symlink"
  fi
  if [[ -e "${R22_R19_STATE_ROOT}" || -L "${R22_R19_STATE_ROOT}" ||
        -e "${R22_R19_BUNDLE_PARENT}" || -L "${R22_R19_BUNDLE_PARENT}" ]]; then
    r22_attestation_fail 70 "R19 absorbing tombstone reappeared before parent enumeration"
  fi
  if /usr/bin/find -P /private/tmp -mindepth 1 -maxdepth 1 -print0 2>/dev/null |
    /bin/bash --noprofile --norc -c '
      set -uo pipefail
      set -f
      IFS=$'"'"' \t\n'"'"'
      set +H
      if ! shopt -u nocasematch; then
        exit 2
      fi
      expected_state="$1"
      expected_bundle="$2"
      actual_path=""
      read_rc=1
      partial_final_record=0
      seen_state=0
      seen_bundle=0
      alternate_root=0
      while :; do
        actual_path=""
        if IFS= read -r -d "" actual_path; then
          case "${actual_path}" in
            "${expected_state}")
              seen_state=$(( seen_state + 1 ))
              ;;
            "${expected_bundle}")
              seen_bundle=$(( seen_bundle + 1 ))
              ;;
            /private/tmp/agentloop-r19-state.*|/private/tmp/agentloop-r19-bundle.*)
              alternate_root=$(( alternate_root + 1 ))
              ;;
          esac
        else
          read_rc="$?"
          if [[ -n "${actual_path}" ]]; then
            partial_final_record=1
          fi
          break
        fi
      done
      if [[ "${read_rc}" -ne 1 ||
            "${partial_final_record}" -ne 0 ||
            "${seen_state}" -ne 0 ||
            "${seen_bundle}" -ne 0 ||
            "${alternate_root}" -ne 0 ]]; then
        exit 1
      fi
    ' -- "${R22_R19_STATE_ROOT}" "${R22_R19_BUNDLE_PARENT}"; then
    r22_r19_tombstone_status=( "${PIPESTATUS[@]}" )
  else
    r22_r19_tombstone_status=( "${PIPESTATUS[@]}" )
  fi
  if [[ "${#r22_r19_tombstone_status[@]}" -ne 2 ||
        "${r22_r19_tombstone_status[0]}" -ne 0 ||
        "${r22_r19_tombstone_status[1]}" -ne 0 ]]; then
    r22_attestation_fail 70 \
      "R19 tombstone full-parent verification failed with find_rc=${r22_r19_tombstone_status[0]:-MISSING} validator_rc=${r22_r19_tombstone_status[1]:-MISSING}"
  fi
  if [[ -e "${R22_R19_STATE_ROOT}" || -L "${R22_R19_STATE_ROOT}" ||
        -e "${R22_R19_BUNDLE_PARENT}" || -L "${R22_R19_BUNDLE_PARENT}" ]]; then
    r22_attestation_fail 70 "R19 absorbing tombstone reappeared after parent enumeration"
  fi
}

r22_require_r19_containment() {
  local r22_verification_mode="$1"
  local -a r22_r19_artifact_status
  local -a r22_r19_artifacts=(
    "${R22_R19_TARGETED_LOG}"
    "${R22_R19_VERIFY_LOG}"
    "${R22_TASK_DIRECTORY}/r19-build.log"
    "${R22_TASK_DIRECTORY}/r19-migration-matrix.log"
    "${R22_R19_REPORT}"
    "${R22_R19_BOUNDARY_LOG}"
    "${R22_TASK_DIRECTORY}/evidence/r19-bundle-provenance.log"
    "${R22_TASK_DIRECTORY}/evidence/r19-source-gates.log"
    "${R22_R19_HASH_LOG}"
    "${R22_TASK_DIRECTORY}/evidence/r19-preview-bootstrap.log"
    "${R22_TASK_DIRECTORY}/evidence/r19-preview-cold-start.log"
  )
  local r22_r19_artifact
  local r22_r19_required_line

  case "${r22_verification_mode}" in
    pre_begin)
      if r22_authorization_is_consumed; then
        r22_attestation_fail 70 "pre_begin_r19_containment_after_authorization_consumption"
      fi
      ;;
    post_activation|post_activation_probe)
      if ! r22_authorization_is_consumed; then
        r22_pre_begin_fail 70 "post_activation_r19_containment_before_authorization_consumption"
      fi
      ;;
    *)
      r22_attestation_fail 64 "invalid R19 containment verification mode: ${r22_verification_mode}"
      ;;
  esac

  for r22_r19_artifact in "${r22_r19_artifacts[@]}"; do
    if [[ ! -f "${r22_r19_artifact}" || -L "${r22_r19_artifact}" ]]; then
      r22_attestation_fail 70 "R19 artifact is missing, non-regular, or a symlink"
    fi
  done

  if r22_emit_r19_artifact_manifest |
    /usr/bin/shasum -a 256 --strict -c - >/dev/null; then
    r22_r19_artifact_status=( "${PIPESTATUS[@]}" )
  else
    r22_r19_artifact_status=( "${PIPESTATUS[@]}" )
  fi
  if [[ "${#r22_r19_artifact_status[@]}" -ne 2 ||
        "${r22_r19_artifact_status[0]}" -ne 0 ||
        "${r22_r19_artifact_status[1]}" -ne 0 ]]; then
    r22_attestation_fail 70 "R19 immutable artifact verification failed"
  fi

  r22_require_r19_tombstones_absent

  if [[ -e "${R22_R19_PLANNED_APP}" || -L "${R22_R19_PLANNED_APP}" ]]; then
    r22_attestation_fail 70 "R19 planned App reappeared under an absorbing tombstone"
  fi
  if [[ -e "${R22_R19_SCREENSHOT}" || -L "${R22_R19_SCREENSHOT}" ]]; then
    r22_attestation_fail 70 "R19 screenshot must remain absent"
  fi

  for r22_r19_required_line in \
    "boundary=R19_CLEAN_REVERIFICATION" \
    "invocation_id=${R22_R19_INVOCATION_ID}" \
    "authorization_consumed=true" \
    "status=REJECTED_CONTAMINATED" \
    "phase=full_tests" \
    "reason=swift_run_full_failed" \
    "state_root=${R22_R19_STATE_ROOT}" \
    "bundle_parent=${R22_R19_BUNDLE_PARENT}" \
    "containment_state_root_empty=true" \
    "containment_bundle_parent_empty=true" \
    "containment_app_absent=true" \
    "verdict_remains=REJECTED_CONTAMINATED" \
    "retry_same_boundary=false"; do
    if ! /usr/bin/grep -Fx -- "${r22_r19_required_line}" "${R22_R19_BOUNDARY_LOG}" >/dev/null 2>&1; then
      r22_attestation_fail 70 "R19 immutable boundary fact is missing"
    fi
  done

  if [[ "${r22_verification_mode}" == "post_activation" ]]; then
    /usr/bin/printf '%s\n' \
      "section=r19_containment" \
      "phase=post_activation" \
      "r19_invocation_id=${R22_R19_INVOCATION_ID}" \
      "r19_verdict=REJECTED_CONTAMINATED" \
      "r19_artifact_count=11" \
      "r19_artifacts_immutable=true" \
      "r19_roots_historical_state=CANONICAL_EMPTY" \
      "r19_roots_current_state=ABSENT_TOMBSTONE" \
      "r19_root_glob_exact_count=0" \
      "r19_state_root=${R22_R19_STATE_ROOT}" \
      "r19_bundle_parent=${R22_R19_BUNDLE_PARENT}" \
      "r19_disappearance_cause=UNKNOWN" \
      "r19_tombstone_transition=CANONICAL_EMPTY_TO_ABSENT" \
      "r19_tombstone_absorbing=true" \
      "r19_tombstone_parent_transport=find_print0_bash_read_d_nul_v1" \
      "r19_planned_app_absent=true" \
      "r19_screenshot_absent=true" \
      "r19_retry_same_boundary=false" >> "${R22_HASH_LOG}"
  fi
}

r22_classify_r20_volatile_roots() {
  local -a r22_r20_root_pipeline_status
  if [[ "${R22_R20_STATE_ROOT}" != "/private/tmp/${R22_R20_STATE_ROOT_BASENAME}" ||
        "${R22_R20_BUNDLE_PARENT}" != "/private/tmp/${R22_R20_BUNDLE_PARENT_BASENAME}" ||
        "${R22_R20_STATE_ROOT_BASENAME}" == "${R22_R20_BUNDLE_PARENT_BASENAME}" ]]; then
    r22_attestation_fail 70 "R20 volatile root frozen identities drifted"
  fi
  if [[ ! -d /private/tmp || -L /private/tmp ]]; then
    r22_attestation_fail 70 "R20 volatile root parent is missing, non-directory, or symlink"
  fi
  if [[ -e "${R22_R20_STATE_ROOT}" || -L "${R22_R20_STATE_ROOT}" ]]; then
    r22_attestation_fail 70 "R20 state-root absorbing tombstone reappeared before parent enumeration"
  fi
  if /usr/bin/find -P /private/tmp -mindepth 1 -maxdepth 1 -print0 2>/dev/null |
    /bin/bash --noprofile --norc -c '
      set -uo pipefail
      set -f
      IFS=$'"'"' \t\n'"'"'
      set +H
      if ! shopt -u nocasematch; then
        exit 2
      fi
      expected_state="$1"
      expected_bundle="$2"
      actual_path=""
      read_rc=1
      partial_final_record=0
      seen_state=0
      seen_bundle=0
      alternate_root=0
      while :; do
        actual_path=""
        if IFS= read -r -d "" actual_path; then
          case "${actual_path}" in
            /private/tmp/agentloop-r20-state.*)
              if [[ "${actual_path}" == "${expected_state}" ]]; then
                seen_state=$((seen_state + 1))
              else
                alternate_root=$((alternate_root + 1))
              fi
              ;;
            /private/tmp/agentloop-r20-bundle.*)
              if [[ "${actual_path}" == "${expected_bundle}" ]]; then
                seen_bundle=$((seen_bundle + 1))
              else
                alternate_root=$((alternate_root + 1))
              fi
              ;;
          esac
        else
          read_rc="$?"
          if [[ -n "${actual_path}" ]]; then
            partial_final_record=1
          fi
          break
        fi
      done
      if [[ "${read_rc}" -ne 1 ||
            "${partial_final_record}" -ne 0 ||
            "${seen_state}" -ne 0 ||
            "${seen_bundle}" -gt 1 ||
            "${alternate_root}" -ne 0 ]]; then
        exit 1
      fi
      if [[ "${seen_bundle}" -eq 1 ]]; then
        exit 0
      fi
      exit 3
    ' -- "${R22_R20_STATE_ROOT}" "${R22_R20_BUNDLE_PARENT}"; then
    r22_r20_root_pipeline_status=( "${PIPESTATUS[@]}" )
  else
    r22_r20_root_pipeline_status=( "${PIPESTATUS[@]}" )
  fi
  if [[ "${#r22_r20_root_pipeline_status[@]}" -ne 2 ||
        "${r22_r20_root_pipeline_status[0]}" -ne 0 ]]; then
    r22_attestation_fail 70 \
      "R20 volatile-root full-parent verification failed with find_rc=${r22_r20_root_pipeline_status[0]:-MISSING} validator_rc=${r22_r20_root_pipeline_status[1]:-MISSING}"
  fi
  case "${r22_r20_root_pipeline_status[1]}" in
    0)
      R22_R20_BUNDLE_CURRENT_STATE="RETAINED_CANDIDATE"
      ;;
    3)
      R22_R20_BUNDLE_CURRENT_STATE="ABSENT_TOMBSTONE"
      ;;
    *)
      r22_attestation_fail 70 \
        "R20 volatile-root set is neither exact retained nor monotonic absent with validator_rc=${r22_r20_root_pipeline_status[1]}"
      ;;
  esac
  if [[ -e "${R22_R20_STATE_ROOT}" || -L "${R22_R20_STATE_ROOT}" ]]; then
    r22_attestation_fail 70 "R20 state-root absorbing tombstone reappeared after parent enumeration"
  fi
  case "${R22_R20_BUNDLE_CURRENT_STATE}" in
    RETAINED_CANDIDATE)
      if [[ ! -e "${R22_R20_BUNDLE_PARENT}" && ! -L "${R22_R20_BUNDLE_PARENT}" ]]; then
        r22_attestation_fail 70 "R20 retained bundle disappeared after classification"
      fi
      ;;
    ABSENT_TOMBSTONE)
      if [[ -e "${R22_R20_BUNDLE_PARENT}" || -L "${R22_R20_BUNDLE_PARENT}" ||
            -e "${R22_R20_APP}" || -L "${R22_R20_APP}" ]]; then
        r22_attestation_fail 70 "R20 absent bundle reappeared after classification"
      fi
      ;;
  esac
}

r22_require_exact_single_child() {
  local r22_directory="$1"
  local r22_expected_child="$2"
  local r22_label="$3"
  local -a r22_child_pipeline_status
  if /usr/bin/find -P "${r22_directory}" \
      -mindepth 1 -maxdepth 1 -print0 2>/dev/null |
    /bin/bash --noprofile --norc -c '
      set -uo pipefail
      IFS=$'"'"' \t\n'"'"'
      set +H
      if ! shopt -u nocasematch; then
        exit 2
      fi
      expected="$1"
      actual=""
      actual_count=0
      seen=0
      valid=true
      read_rc=1
      partial_final_record=0
      while :; do
        actual=""
        if IFS= read -r -d "" actual; then
          actual_count=$((actual_count + 1))
          if [[ "${actual}" == "${expected}" ]]; then
            seen=$((seen + 1))
          else
            valid=false
          fi
          if (( actual_count > 1 || seen > 1 )); then
            valid=false
          fi
        else
          read_rc="$?"
          if [[ -n "${actual}" ]]; then
            partial_final_record=1
            valid=false
          fi
          break
        fi
      done
      if [[ "${read_rc}" -ne 1 ||
            "${partial_final_record}" -ne 0 ||
            "${valid}" != "true" ||
            "${actual_count}" -ne 1 ||
            "${seen}" -ne 1 ]]; then
        exit 1
      fi
    ' -- "${r22_expected_child}"; then
    r22_child_pipeline_status=( "${PIPESTATUS[@]}" )
  else
    r22_child_pipeline_status=( "${PIPESTATUS[@]}" )
  fi
  if [[ "${#r22_child_pipeline_status[@]}" -ne 2 ||
        "${r22_child_pipeline_status[0]}" -ne 0 ||
        "${r22_child_pipeline_status[1]}" -ne 0 ]]; then
    r22_attestation_fail 70 \
      "${r22_label} exact-child verification failed with find_rc=${r22_child_pipeline_status[0]:-MISSING} validator_rc=${r22_child_pipeline_status[1]:-MISSING}"
  fi
}

r22_require_r20_containment() {
  local r22_verification_mode="$1"
  local -a r22_r20_artifacts=(
    "${R22_R20_TARGETED_LOG}"
    "${R22_R20_VERIFY_LOG}"
    "${R22_R20_BUILD_LOG}"
    "${R22_TASK_DIRECTORY}/r20-migration-matrix.log"
    "${R22_R20_REPORT}"
    "${R22_R20_BOUNDARY_LOG}"
    "${R22_TASK_DIRECTORY}/evidence/r20-bundle-provenance.log"
    "${R22_TASK_DIRECTORY}/evidence/r20-source-gates.log"
    "${R22_R20_HASH_LOG}"
    "${R22_TASK_DIRECTORY}/evidence/r20-preview-bootstrap.log"
    "${R22_TASK_DIRECTORY}/evidence/r20-preview-cold-start.log"
  )
  local r22_r20_artifact
  local r22_r20_bundle_realpath
  local r22_r20_bundle_realpath_rc
  local r22_r20_codesign_rc
  local r22_r20_required_line
  local r22_r20_verified_state_before_late_bookend
  local -a r22_r20_bundle_manifest_status
  local -a r22_r20_expected_bundle_nodes=(
    "D"
    "Contents"
    "-"
    "F"
    "Contents/Info.plist"
    "${R22_R20_INFO_PLIST_SHA}"
    "D"
    "Contents/MacOS"
    "-"
    "F"
    "Contents/MacOS/AgentLoop"
    "${R22_R20_EXECUTABLE_SHA}"
    "D"
    "Contents/Resources"
    "-"
    "D"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle"
    "-"
    "D"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt"
    "-"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelBarnDay.png"
    "8e3fa4eae64bd933b2119e8609fed3a95621207ff3a40fa4d63de68c40e8d93b"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelBarnNight.png"
    "13c402ff5225e87bc3e9dd686a022034f52a4b7004563507ebd9e86cc9999b9b"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideAmber.png"
    "3166ee2fbf917c2700913fc0b8e989f09efa49c9d26035412be8bdde6e022a98"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideBlue.png"
    "bc59959c81e6957cf6403e79ef48d4f7b543cfb3b6980c1900f6a19de0f1a3a9"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideCoral.png"
    "da471a67b32b32a560ef3234ccaf42a66c3ffb403da7c3a8c8de9f7eab709cb3"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideGreen.png"
    "2b5c2178fa8ca4ba11b5615347f6029450237c1a3cfa97220dee7da34a6cad70"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSidePink.png"
    "7e424ea3ea38a0d927d9548e53ac7575c18224f24a05fc5163b2aaa505dee409"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSidePurple.png"
    "5a1b90a96720cbb03572babd2d234f8a6e5945a5ae2e650556108ff6185dd2c8"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideTeal.png"
    "b5577e1bb6bdb448f25f5078ce534167471dac47b02910e48346fdd08a1fcbc1"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepAmber.png"
    "337a18ea9ff0f48d71eb8f799942290d49c17c6e725f614ca93500738fad99d0"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepBlue.png"
    "9ca08f0809cdebee7ff5d340494fc85b3df9d9c16cb9d739419c1c9debb18c4b"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepCoral.png"
    "73a4cdad14d69ccf25106aba261b36c792ca004634a88e8a2be24ad04ecd306b"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepGreen.png"
    "326be64cd3c4b6ac2ff0b2d991c5eff0a7752616a5cf4d8297a1fed6010d7513"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepPink.png"
    "bbc2145cedc821959420c1a27f50ef1c2454c36c0b11d17f8da43e4259d80444"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepPurple.png"
    "e9def94b358c6950c5f3168124d7a3563c8f0680e386149d12538ae30a6fcbe3"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepTeal.png"
    "7a68441ea798d211b13f9764928332bb4cf1a1607646c55fb0a1f0bfa4773627"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideAmber.png"
    "3f8bbbb82fb11e4934efc97018e084e2eab541c97ed25ecc1382996392ac7c8c"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideBlue.png"
    "cbf47e2668e19e1ce32b98b6ec1fcc3403f63c358a8dababa3c0da09946f8fb1"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideCoral.png"
    "55726ca797194d1c428567426a6b2fae50dc01bb43795dbb7b1aa1c19b532650"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideGreen.png"
    "08efff075a883dbbdda94eb3388910bfb7c2c0e042a818bb5696dba3baa6cc8b"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStridePink.png"
    "cd0cf39c9120fbecff1433387ebe4ddcff57a3c468a62b0fb78af29621a15b8e"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStridePurple.png"
    "d31abde4d4e4b70ddf2bdd547226ff81bc808155308aa40430d78e87f8d81c1a"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideTeal.png"
    "27926a3f3088a4d570c9acfbf1ba599b6387a16f1bdc0df3dd413eb65c2e5540"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelPanoramaDay.png"
    "35f89d34928e3bba5d68fbc52a55dfa55df6cf586ca867b05b5d1198e1b1d308"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelPanoramaNight.png"
    "fba4f7457df442a55280fa1af7ad03e1443d63c92e47c7fb1efd99196c2a8e25"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelPastureDay.png"
    "6d831556ccfcc2d173683375b29579bd75926e6e8668e78bfb311823b3d8966f"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelPastureNight.png"
    "0a106a90f04569292e150071dc1649c5fc995dd6921b43f2f8874039d89f6909"
    "D"
    "Contents/_CodeSignature"
    "-"
    "F"
    "Contents/_CodeSignature/CodeResources"
    "4e903bc32534480c4fa8a17490e49c496e655f1827eafbed280d09fc0eb90ae4"
  )

  case "${r22_verification_mode}" in
    pre_begin)
      if r22_authorization_is_consumed; then
        r22_attestation_fail 70 "pre_begin_r20_containment_after_authorization_consumption"
      fi
      ;;
    post_activation|post_activation_probe)
      if ! r22_authorization_is_consumed; then
        r22_pre_begin_fail 70 "post_activation_r20_containment_before_authorization_consumption"
      fi
      ;;
    *)
      r22_attestation_fail 64 "invalid R20 containment verification mode: ${r22_verification_mode}"
      ;;
  esac

  for r22_r20_artifact in "${r22_r20_artifacts[@]}"; do
    if [[ ! -f "${r22_r20_artifact}" || -L "${r22_r20_artifact}" ]]; then
      r22_attestation_fail 70 "R20 artifact is missing, non-regular, or a symlink"
    fi
  done

  r22_classify_r20_volatile_roots

  if [[ "${r22_verification_mode}" != "pre_begin" &&
        "${R22_R20_BUNDLE_PRE_BEGIN_STATE}" == "ABSENT_TOMBSTONE" &&
        "${R22_R20_BUNDLE_CURRENT_STATE}" == "RETAINED_CANDIDATE" ]]; then
    r22_attestation_fail 70 "R20 bundle absorbing tombstone reappeared"
  fi

  if [[ "${R22_R20_BUNDLE_CURRENT_STATE}" == "RETAINED_CANDIDATE" ]]; then
    if r22_r20_bundle_realpath="$(
      trap - ERR
      /bin/realpath "${R22_R20_BUNDLE_PARENT}" 2>&1
    )"; then
      r22_r20_bundle_realpath_rc=0
    else
      r22_r20_bundle_realpath_rc="$?"
    fi
    if [[ ! -d "${R22_R20_BUNDLE_PARENT}" || -L "${R22_R20_BUNDLE_PARENT}" ||
          "${r22_r20_bundle_realpath_rc}" -ne 0 ||
          "${r22_r20_bundle_realpath}" != "${R22_R20_BUNDLE_PARENT}" ]]; then
      r22_attestation_fail 70 "R20 retained bundle parent type or realpath drifted"
    fi
    r22_require_exact_single_child \
      "${R22_R20_BUNDLE_PARENT}" "${R22_R20_APP}" "R20 bundle parent"
    if [[ ! -d "${R22_R20_APP}" || -L "${R22_R20_APP}" ||
          ! -f "${R22_R20_EXECUTABLE}" || -L "${R22_R20_EXECUTABLE}" ||
          ! -f "${R22_R20_INFO_PLIST}" || -L "${R22_R20_INFO_PLIST}" ]]; then
      r22_attestation_fail 70 "R20 signed App, executable, or Info.plist type drifted"
    fi
    if /usr/bin/find -P "${R22_R20_APP}" -mindepth 1 -print0 2>/dev/null |
    /bin/bash --noprofile --norc -c '
      set -uo pipefail
      set -f
      IFS=$'"'"' \t\n'"'"'
      set +H
      if ! shopt -u nocasematch; then
        exit 2
      fi
      app="$1"
      shift
      if [[ "$#" -ne 108 ]]; then
        exit 1
      fi
      expected_count=0
      expected_file_count=0
      expected_type=()
      expected_path=()
      expected_hash=()
      seen=()
      while [[ "$#" -gt 0 ]]; do
        type="$1"
        relative_path="$2"
        file_hash="$3"
        shift 3
        if [[ -z "${relative_path}" || "${relative_path}" == /* ]]; then
          exit 1
        fi
        case "${relative_path}" in
          *[!A-Za-z0-9._/-]*|*//*|../*|*/../*|*/..|./*|*/./*|*/.)
            exit 1
            ;;
        esac
        case "${type}" in
          D)
            if [[ "${file_hash}" != "-" ]]; then
              exit 1
            fi
            ;;
          F)
            if [[ "${#file_hash}" -ne 64 ]]; then
              exit 1
            fi
            case "${file_hash}" in
              *[!0-9a-f]*)
                exit 1
                ;;
            esac
            expected_file_count=$(( expected_file_count + 1 ))
            ;;
          *)
            exit 1
            ;;
        esac
        other_index=0
        while [[ "${other_index}" -lt "${expected_count}" ]]; do
          if [[ "${expected_path[other_index]}" == "${relative_path}" ]]; then
            exit 1
          fi
          other_index=$(( other_index + 1 ))
        done
        expected_type[expected_count]="${type}"
        expected_path[expected_count]="${relative_path}"
        expected_hash[expected_count]="${file_hash}"
        seen[expected_count]=0
        expected_count=$(( expected_count + 1 ))
      done
      if [[ "${expected_count}" -ne 36 || "${expected_file_count}" -ne 30 ]]; then
        exit 1
      fi

      path=""
      read_rc=1
      actual_count=0
      actual_file_count=0
      valid=true
      while :; do
        path=""
        if IFS= read -r -d "" path; then
          if [[ "${actual_count}" -lt 37 ]]; then
            actual_count=$(( actual_count + 1 ))
          else
            valid=false
          fi
          case "${path}" in
            "${app}"/*)
              relative_path="${path#"${app}"/}"
              ;;
            *)
              relative_path=""
              valid=false
              ;;
          esac
          matched_index=-1
          index=0
          while [[ "${index}" -lt "${expected_count}" ]]; do
            if [[ "${relative_path}" == "${expected_path[index]}" ]]; then
              matched_index="${index}"
              break
            fi
            index=$(( index + 1 ))
          done
          if [[ "${matched_index}" -lt 0 ]]; then
            valid=false
            continue
          fi
          if [[ "${seen[matched_index]}" -ne 0 ]]; then
            valid=false
            continue
          fi
          seen[matched_index]=1
          case "${expected_type[matched_index]}" in
            D)
              if [[ ! -d "${path}" || -L "${path}" ]]; then
                valid=false
              fi
              ;;
            F)
              if [[ ! -f "${path}" || -L "${path}" ]]; then
                valid=false
                continue
              fi
              if file_sha="$(/usr/bin/shasum -a 256 "${path}")"; then
                file_sha="${file_sha%% *}"
              else
                exit "$?"
              fi
              if [[ "${file_sha}" != "${expected_hash[matched_index]}" ]]; then
                valid=false
              fi
              actual_file_count=$(( actual_file_count + 1 ))
              ;;
            *)
              exit 1
              ;;
          esac
        else
          read_rc="$?"
          if [[ "${read_rc}" -ne 1 || -n "${path}" ]]; then
            valid=false
          fi
          break
        fi
      done
      if [[ "${valid}" != "true" ||
            "${actual_count}" -ne 36 ||
            "${actual_file_count}" -ne 30 ]]; then
        exit 1
      fi
      index=0
      while [[ "${index}" -lt "${expected_count}" ]]; do
        if [[ "${seen[index]}" -ne 1 ]]; then
          exit 1
        fi
        if [[ "${expected_type[index]}" == "F" ]]; then
          /usr/bin/printf "%s  %s\n" \
            "${expected_hash[index]}" "${expected_path[index]}"
        fi
        index=$(( index + 1 ))
      done
    ' -- "${R22_R20_APP}" "${r22_r20_expected_bundle_nodes[@]}" |
    /usr/bin/shasum -a 256 |
    /bin/bash --noprofile --norc -c '
      set -uo pipefail
      IFS=$'"'"' \t\n'"'"'
      expected="$1  -"
      actual=""
      extra=""
      if ! IFS= read -r actual; then
        exit 1
      fi
      if [[ "${actual}" != "${expected}" ]]; then
        exit 1
      fi
      if IFS= read -r extra || [[ -n "${extra}" ]]; then
        exit 1
      fi
    ' -- "${R22_R20_SIGNED_BUNDLE_MANIFEST_SHA}"; then
    r22_r20_bundle_manifest_status=( "${PIPESTATUS[@]}" )
  else
    r22_r20_bundle_manifest_status=( "${PIPESTATUS[@]}" )
  fi
    if [[ "${#r22_r20_bundle_manifest_status[@]}" -ne 4 ||
          "${r22_r20_bundle_manifest_status[0]}" -ne 0 ||
          "${r22_r20_bundle_manifest_status[1]}" -ne 0 ||
          "${r22_r20_bundle_manifest_status[2]}" -ne 0 ||
          "${r22_r20_bundle_manifest_status[3]}" -ne 0 ]]; then
      r22_attestation_fail 70 \
        "R20_signed_App_all_node_manifest_failed_find_${r22_r20_bundle_manifest_status[0]:-MISSING}_validator_${r22_r20_bundle_manifest_status[1]:-MISSING}_shasum_${r22_r20_bundle_manifest_status[2]:-MISSING}_hash_validator_${r22_r20_bundle_manifest_status[3]:-MISSING}"
    fi
    if /usr/bin/codesign --verify --deep --strict "${R22_R20_APP}" >/dev/null 2>&1; then
      r22_r20_codesign_rc=0
    else
      r22_r20_codesign_rc="$?"
    fi
    if [[ "${r22_r20_codesign_rc}" -ne 0 ]]; then
      r22_attestation_fail 70 "R20 signed App verification failed with rc=${r22_r20_codesign_rc}"
    fi
    R22_R20_BUNDLE_CURRENT_STATE="VERIFIED_RETAINED"
  fi

  r22_r20_verified_state_before_late_bookend="${R22_R20_BUNDLE_CURRENT_STATE}"
  r22_classify_r20_volatile_roots
  case "${r22_r20_verified_state_before_late_bookend}:${R22_R20_BUNDLE_CURRENT_STATE}" in
    VERIFIED_RETAINED:RETAINED_CANDIDATE)
      R22_R20_BUNDLE_CURRENT_STATE="VERIFIED_RETAINED"
      ;;
    ABSENT_TOMBSTONE:ABSENT_TOMBSTONE)
      ;;
    *)
      r22_attestation_fail 70 \
        "R20 late full-parent bookend transition is invalid: ${r22_r20_verified_state_before_late_bookend}:${R22_R20_BUNDLE_CURRENT_STATE}"
      ;;
  esac

  case "${r22_verification_mode}" in
    pre_begin)
      if [[ -z "${R22_R20_BUNDLE_FIRST_OBSERVED_STATE}" ]]; then
        R22_R20_BUNDLE_FIRST_OBSERVED_STATE="${R22_R20_BUNDLE_CURRENT_STATE}"
        R22_R20_BUNDLE_PRE_BEGIN_STATE="${R22_R20_BUNDLE_CURRENT_STATE}"
      else
        case "${R22_R20_BUNDLE_PRE_BEGIN_STATE}:${R22_R20_BUNDLE_CURRENT_STATE}" in
          VERIFIED_RETAINED:VERIFIED_RETAINED|VERIFIED_RETAINED:ABSENT_TOMBSTONE|ABSENT_TOMBSTONE:ABSENT_TOMBSTONE)
            R22_R20_BUNDLE_PRE_BEGIN_STATE="${R22_R20_BUNDLE_CURRENT_STATE}"
            ;;
          *)
            r22_attestation_fail 70 \
              "R20 repeated pre-BEGIN observation is not monotonic from first-observed ${R22_R20_BUNDLE_FIRST_OBSERVED_STATE}: ${R22_R20_BUNDLE_PRE_BEGIN_STATE}:${R22_R20_BUNDLE_CURRENT_STATE}"
            ;;
        esac
      fi
      ;;
    post_activation|post_activation_probe)
      local r22_r20_previous_observed_state
      if [[ -n "${R22_R20_BUNDLE_POST_ACTIVATION_STATE}" ]]; then
        r22_r20_previous_observed_state="${R22_R20_BUNDLE_POST_ACTIVATION_STATE}"
      else
        r22_r20_previous_observed_state="${R22_R20_BUNDLE_PRE_BEGIN_STATE}"
      fi
      case "${r22_r20_previous_observed_state}:${R22_R20_BUNDLE_CURRENT_STATE}" in
        VERIFIED_RETAINED:VERIFIED_RETAINED|VERIFIED_RETAINED:ABSENT_TOMBSTONE|ABSENT_TOMBSTONE:ABSENT_TOMBSTONE)
          R22_R20_BUNDLE_POST_ACTIVATION_STATE="${R22_R20_BUNDLE_CURRENT_STATE}"
          ;;
        *)
          r22_attestation_fail 70 \
            "R20 bundle transition is not monotonic: ${r22_r20_previous_observed_state}:${R22_R20_BUNDLE_CURRENT_STATE}"
          ;;
      esac
      ;;
  esac
  if [[ -z "${R22_R20_BUNDLE_CURRENT_STATE}" ||
        "${R22_R20_BUNDLE_CURRENT_STATE}" == "RETAINED_CANDIDATE" ]]; then
    r22_attestation_fail 70 "R20 bundle classification did not reach a terminal observed state"
  fi
  if [[ -e "${R22_R20_SCREENSHOT}" || -L "${R22_R20_SCREENSHOT}" ]]; then
    r22_attestation_fail 70 "R20 screenshot must remain absent"
  fi

  for r22_r20_required_line in \
    "boundary=R20_DETERMINISTIC_CLOCK_REPAIR" \
    "invocation_id=${R22_R20_INVOCATION_ID}" \
    "authorization_consumed=true" \
    "authoritative_test_invocation_count=1" \
    "authoritative_test_filter=none" \
    "authoritative_swift_rc=0" \
    "authoritative_tee_rc=0" \
    "targeted_required_name_count=46" \
    "launch_ready=true" \
    "executable_sha=${R22_R20_EXECUTABLE_SHA}" \
    "signed_bundle_manifest_sha=${R22_R20_SIGNED_BUNDLE_MANIFEST_SHA}" \
    "status=REJECTED_CONTAMINATED" \
    "phase=release_core_build" \
    "reason=release_AgentLoopCore_build_failed_rc_1" \
    "exit_code=1" \
    "state_root=${R22_R20_STATE_ROOT}" \
    "bundle_parent=${R22_R20_BUNDLE_PARENT}" \
    "retry_same_boundary=false"; do
    if ! /usr/bin/grep -Fx -- "${r22_r20_required_line}" "${R22_R20_BOUNDARY_LOG}" >/dev/null 2>&1; then
      r22_attestation_fail 70 "R20 immutable boundary fact is missing"
    fi
  done

  if [[ "${r22_verification_mode}" == "post_activation" ]]; then
    /usr/bin/printf '%s\n' \
      "section=r20_containment" \
      "phase=post_activation" \
      "r20_invocation_id=${R22_R20_INVOCATION_ID}" \
      "r20_verdict=REJECTED_CONTAMINATED" \
      "r20_failure_phase=release_core_build" \
      "r20_authoritative_full_tests=652_of_652_pass" \
      "r20_targeted_audit=46_of_46_pass" \
      "r20_launch_ready=true" \
      "r20_artifact_count=11" \
      "r20_artifacts_immutable_by_static_manifest=true" \
      "r20_state_root=${R22_R20_STATE_ROOT}" \
      "r20_state_root_historical_state=CANONICAL_EMPTY" \
      "r20_state_root_current_state=ABSENT_TOMBSTONE" \
      "r20_state_root_disappearance_cause=UNKNOWN" \
      "r20_bundle_parent=${R22_R20_BUNDLE_PARENT}" \
      "r20_bundle_first_observed_state=${R22_R20_BUNDLE_FIRST_OBSERVED_STATE}" \
      "r20_bundle_pre_begin_state=${R22_R20_BUNDLE_PRE_BEGIN_STATE}" \
      "r20_bundle_post_activation_state=${R22_R20_BUNDLE_CURRENT_STATE}" \
      "r20_bundle_transition=${R22_R20_BUNDLE_PRE_BEGIN_STATE}_TO_${R22_R20_BUNDLE_CURRENT_STATE}" \
      "r20_volatile_root_parent_transport=find_print0_bash_read_d_nul_v1" \
      "r20_screenshot_absent=true" \
      "r20_retry_same_boundary=false" >> "${R22_HASH_LOG}"
    case "${R22_R20_BUNDLE_CURRENT_STATE}" in
      VERIFIED_RETAINED)
        /usr/bin/printf '%s\n' \
          "r20_root_glob_exact_count=1" \
          "r20_bundle_parent_exact_child=${R22_R20_APP}" \
          "r20_signed_app_verified=true" \
          "r20_signed_app_path_transport=find_print0_bash_read_d_nul_v1" \
          "r20_signed_app_all_node_count=36" \
          "r20_signed_app_directory_count=6" \
          "r20_signed_app_regular_file_count=30" \
          "r20_signed_bundle_manifest_recomputed=true" \
          "r20_executable_sha=${R22_R20_EXECUTABLE_SHA}" \
          "r20_info_plist_sha=${R22_R20_INFO_PLIST_SHA}" \
          "r20_signed_bundle_manifest_sha=${R22_R20_SIGNED_BUNDLE_MANIFEST_SHA}" >> "${R22_HASH_LOG}"
        ;;
      ABSENT_TOMBSTONE)
        /usr/bin/printf '%s\n' \
          "r20_root_glob_exact_count=0" \
          "r20_bundle_disappearance_cause=UNKNOWN" \
          "r20_bundle_absorbing_tombstone=true" \
          "r20_current_signed_app_verified=false" \
          "r20_historical_executable_sha=${R22_R20_EXECUTABLE_SHA}" \
          "r20_historical_info_plist_sha=${R22_R20_INFO_PLIST_SHA}" \
          "r20_historical_signed_bundle_manifest_sha=${R22_R20_SIGNED_BUNDLE_MANIFEST_SHA}" >> "${R22_HASH_LOG}"
        ;;
    esac
  fi
}

r22_post_activation_anchor_check() {
  local -a r22_anchor_status
  {
    /usr/bin/printf '%s\n' "section=terminal_anchors"
    r22_emit_anchor_manifest
  } >> "${R22_HASH_LOG}"
  if r22_emit_anchor_manifest |
    /usr/bin/shasum -a 256 --strict -c - >> "${R22_HASH_LOG}" 2>&1; then
    r22_anchor_status=( "${PIPESTATUS[@]}" )
  else
    r22_anchor_status=( "${PIPESTATUS[@]}" )
  fi
  /usr/bin/printf 'terminal_anchor_producer_rc=%s\n' "${r22_anchor_status[0]}" >> "${R22_HASH_LOG}"
  /usr/bin/printf 'terminal_anchor_shasum_rc=%s\n' "${r22_anchor_status[1]}" >> "${R22_HASH_LOG}"
  if [[ "${r22_anchor_status[0]}" -ne 0 || "${r22_anchor_status[1]}" -ne 0 ]]; then
    r22_active_fail 65 "post_activation_terminal_anchor_failure_producer_${r22_anchor_status[0]}_shasum_${r22_anchor_status[1]}"
  fi
}

r22_post_activation_manifest_check() {
  local r22_manifest_rc
  local r22_manifest_count
  local r22_manifest_count_rc
  if r22_manifest_count="$(
    trap - ERR
    /usr/bin/awk 'END { print NR }' "${R22_MANIFEST_PATH}"
  )"; then
    r22_manifest_count_rc=0
  else
    r22_manifest_count_rc="$?"
  fi
  if [[ "${r22_manifest_count_rc}" -ne 0 ]]; then
    r22_active_fail 66 "post_activation_static_manifest_count_failed_rc_${r22_manifest_count_rc}"
  fi
  /usr/bin/printf '%s\n' "section=static_manifest" >> "${R22_HASH_LOG}"
  /usr/bin/printf 'static_manifest_expected_count=%s\n' "${R22_EXPECTED_MANIFEST_COUNT}" >> "${R22_HASH_LOG}"
  /usr/bin/printf 'static_manifest_actual_count=%s\n' "${r22_manifest_count}" >> "${R22_HASH_LOG}"
  if /usr/bin/shasum -a 256 --strict -c "${R22_MANIFEST_PATH}" >> "${R22_HASH_LOG}" 2>&1; then
    r22_manifest_rc=0
  else
    r22_manifest_rc="$?"
  fi
  /usr/bin/printf 'static_manifest_rc=%s\n' "${r22_manifest_rc}" >> "${R22_HASH_LOG}"
  if [[ "${r22_manifest_rc}" -ne 0 ]]; then
    r22_active_fail 66 "post_activation_static_manifest_failure_rc_${r22_manifest_rc}"
  fi
  if [[ "${r22_manifest_count}" != "${R22_EXPECTED_MANIFEST_COUNT}" ]]; then
    r22_active_fail 66 "post_activation_static_manifest_count_${r22_manifest_count}"
  fi
}

r22_check_ranch_art_structure() {
  local r22_verification_mode="$1"
  local r22_evidence_sink
  local r22_evidence_phase
  local -a r22_expected_basenames=(
    "PixelBarnDay.png"
    "PixelBarnNight.png"
    "PixelCowSideAmber.png"
    "PixelCowSideBlue.png"
    "PixelCowSideCoral.png"
    "PixelCowSideGreen.png"
    "PixelCowSidePink.png"
    "PixelCowSidePurple.png"
    "PixelCowSideTeal.png"
    "PixelCowSleepAmber.png"
    "PixelCowSleepBlue.png"
    "PixelCowSleepCoral.png"
    "PixelCowSleepGreen.png"
    "PixelCowSleepPink.png"
    "PixelCowSleepPurple.png"
    "PixelCowSleepTeal.png"
    "PixelCowStrideAmber.png"
    "PixelCowStrideBlue.png"
    "PixelCowStrideCoral.png"
    "PixelCowStrideGreen.png"
    "PixelCowStridePink.png"
    "PixelCowStridePurple.png"
    "PixelCowStrideTeal.png"
    "PixelPanoramaDay.png"
    "PixelPanoramaNight.png"
    "PixelPastureDay.png"
    "PixelPastureNight.png"
  )
  local -a r22_ranch_pipeline_status

  case "${r22_verification_mode}" in
    pre_begin)
      if r22_authorization_is_consumed; then
        r22_attestation_fail 70 "pre_begin_ranch_art_check_after_authorization_consumption"
      fi
      r22_evidence_sink="/dev/stderr"
      r22_evidence_phase="pre_consumption"
      ;;
    post_activation)
      if ! r22_authorization_is_consumed; then
        r22_pre_begin_fail 70 "post_activation_ranch_art_check_before_authorization_consumption"
      fi
      if [[ ! -f "${R22_HASH_LOG}" || -L "${R22_HASH_LOG}" ]]; then
        r22_active_fail 70 "post_activation_ranch_art_hash_log_invalid"
      fi
      r22_evidence_sink="${R22_HASH_LOG}"
      r22_evidence_phase="post_activation"
      ;;
    *)
      r22_attestation_fail 64 "invalid RanchArt verification mode: ${r22_verification_mode}"
      ;;
  esac

  # Hide raw pathname diagnostics while retaining both numeric pipeline statuses
  # in the fixed fail-closed reason below.
  if /usr/bin/find -P "${R22_RANCH_ART_DIRECTORY}" \
      -mindepth 1 -maxdepth 1 -print0 2>/dev/null |
    /bin/bash -c '
      set +x
      set +v
      set -u
      set -f
      LC_ALL=C
      export LC_ALL
      shopt -u nocasematch

      r22_directory="$1"
      shift
      r22_expected_count="$#"
      r22_invalid=0
      r22_partial_final_record=0
      r22_read_rc=1
      r22_total_count=0
      r22_regular_count=0
      r22_nonregular_count=0
      r22_symlink_count=0
      r22_index=0
      r22_other_index=0
      r22_path=""
      r22_basename=""
      r22_prefix="${r22_directory}/"
      r22_expected_value=""
      r22_other_expected_value=""
      r22_seen=()

      if [[ "${r22_expected_count}" -ne 27 ]]; then
        r22_invalid=1
      fi
      if [[ ! -d "${r22_directory}" || -L "${r22_directory}" ]]; then
        r22_invalid=1
      fi

      r22_index=0
      for r22_expected_value in "$@"; do
        r22_seen[r22_index]=0
        if [[ -z "${r22_expected_value}" || "${r22_expected_value}" == */* ]]; then
          r22_invalid=1
        fi
        case "${r22_expected_value}" in
          *[!A-Za-z0-9.]* )
            r22_invalid=1
            ;;
        esac
        r22_other_index=0
        for r22_other_expected_value in "$@"; do
          if [[ "${r22_index}" -ne "${r22_other_index}" &&
                "${r22_expected_value}" == "${r22_other_expected_value}" ]]; then
            r22_invalid=1
          fi
          r22_other_index=$(( r22_other_index + 1 ))
        done
        r22_index=$(( r22_index + 1 ))
      done

      while :; do
        r22_path=""
        if IFS= read -r -d "" r22_path; then
          if [[ "${r22_total_count}" -lt 28 ]]; then
            r22_total_count=$(( r22_total_count + 1 ))
          else
            r22_invalid=1
          fi

          r22_record_regular=0
          if [[ -f "${r22_path}" && ! -L "${r22_path}" ]]; then
            r22_record_regular=1
            if [[ "${r22_regular_count}" -lt 28 ]]; then
              r22_regular_count=$(( r22_regular_count + 1 ))
            else
              r22_invalid=1
            fi
          else
            if [[ "${r22_nonregular_count}" -lt 28 ]]; then
              r22_nonregular_count=$(( r22_nonregular_count + 1 ))
            else
              r22_invalid=1
            fi
          fi
          if [[ -L "${r22_path}" ]]; then
            if [[ "${r22_symlink_count}" -lt 28 ]]; then
              r22_symlink_count=$(( r22_symlink_count + 1 ))
            else
              r22_invalid=1
            fi
          fi

          r22_record_matched=0
          if [[ "${r22_path}" == "${r22_prefix}"* ]]; then
            r22_basename="${r22_path#"${r22_prefix}"}"
            if [[ -n "${r22_basename}" && "${r22_basename}" != */* ]]; then
              r22_index=0
              for r22_expected_value in "$@"; do
                if [[ "${r22_basename}" == "${r22_expected_value}" ]]; then
                  r22_record_matched=1
                  if [[ "${r22_seen[r22_index]}" -eq 0 ]]; then
                    r22_seen[r22_index]=1
                  else
                    r22_invalid=1
                  fi
                  break
                fi
                r22_index=$(( r22_index + 1 ))
              done
            fi
          fi
          if [[ "${r22_record_regular}" -ne 1 || "${r22_record_matched}" -ne 1 ]]; then
            r22_invalid=1
          fi
        else
          r22_read_rc="$?"
          if [[ -n "${r22_path}" ]]; then
            r22_partial_final_record=1
            r22_invalid=1
          fi
          break
        fi
      done

      if [[ "${r22_read_rc}" -ne 1 ||
            "${r22_partial_final_record}" -ne 0 ||
            "${r22_total_count}" -ne 27 ||
            "${r22_regular_count}" -ne 27 ||
            "${r22_nonregular_count}" -ne 0 ||
            "${r22_symlink_count}" -ne 0 ||
            ! -d "${r22_directory}" || -L "${r22_directory}" ]]; then
        r22_invalid=1
      fi
      r22_index=0
      for r22_expected_value in "$@"; do
        if [[ "${r22_seen[r22_index]}" -ne 1 ]]; then
          r22_invalid=1
        fi
        r22_index=$(( r22_index + 1 ))
      done

      if [[ "${r22_invalid}" -ne 0 ]]; then
        exit 1
      fi
      exit 0
    ' "r22-ranch-art-nul-validator-v1" \
      "${R22_RANCH_ART_DIRECTORY}" "${r22_expected_basenames[@]}"; then
    r22_ranch_pipeline_status=( "${PIPESTATUS[@]}" )
  else
    r22_ranch_pipeline_status=( "${PIPESTATUS[@]}" )
  fi

  if [[ "${#r22_ranch_pipeline_status[@]}" -ne 2 ]]; then
    r22_attestation_fail 70 "ranch_art_pipeline_status_shape_invalid"
  fi
  if [[ "${r22_ranch_pipeline_status[0]}" -ne 0 ||
        "${r22_ranch_pipeline_status[1]}" -ne 0 ]]; then
    r22_attestation_fail 70 \
      "ranch_art_nul_validation_failed_find_${r22_ranch_pipeline_status[0]}_validator_${r22_ranch_pipeline_status[1]}"
  fi

  /usr/bin/printf '%s\n' "section=ranch_art_structure" >> "${r22_evidence_sink}"
  /usr/bin/printf 'phase=%s\n' "${r22_evidence_phase}" >> "${r22_evidence_sink}"
  /usr/bin/printf 'ranch_art_verification_mode=%s\n' \
    "${r22_verification_mode}" >> "${r22_evidence_sink}"
  /usr/bin/printf '%s\n' \
    "pathname_transport=find_print0_bash_read_d_nul_v1" \
    "ranch_art_find_rc=${r22_ranch_pipeline_status[0]}" \
    "ranch_art_validator_rc=${r22_ranch_pipeline_status[1]}" \
    "ranch_art_expected_count=27" \
    "ranch_art_parent_type=directory_non_symlink" \
    "ranch_art_node_type=regular_non_symlink" \
    "ranch_art_actual_count=27" \
    "ranch_art_exact_relative_path_set_begin" >> "${r22_evidence_sink}"
  /usr/bin/printf '%s\n' "${r22_expected_basenames[@]}" >> "${r22_evidence_sink}"
  /usr/bin/printf '%s\n' \
    "ranch_art_exact_relative_path_set_end" \
    "nonregular_count=0" \
    "symlink_count=0" \
    "regular_count=27" >> "${r22_evidence_sink}"
}

if [[ "$#" -ne 1 ]]; then
  r22_pre_begin_fail 64 "expected one automatically computed Review22 SHA-256 argument"
fi

readonly R22_EXPECTED_REVIEW22_SHA="$1"
r22_require_lowercase_sha256 "${R22_EXPECTED_REVIEW22_SHA}" "Review22 hash"

if [[ "$0" != "${R22_DRIVER_PATH}" ]]; then
  r22_pre_begin_fail 64 "driver must be invoked by its frozen absolute path"
fi
if [[ "${BASH_SOURCE[0]}" != "${R22_DRIVER_PATH}" ||
      ! -f "${R22_DRIVER_PATH}" ||
      -L "${R22_DRIVER_PATH}" ||
      "$(/bin/realpath "${R22_DRIVER_PATH}")" != "${R22_DRIVER_PATH}" ]]; then
  r22_pre_begin_fail 64 "driver source path or file type is not canonical"
fi
if (( BASH_VERSINFO[0] < 3 ||
      (BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] < 2) )); then
  r22_pre_begin_fail 64 "Bash 3.2 or newer is required"
fi
if [[ "${LC_ALL:-}" != "C" || "${LANG:-}" != "C" ]]; then
  r22_pre_begin_fail 64 "LC_ALL and LANG must both equal C"
fi
if [[ "${PATH:-}" != "/usr/bin:/bin:/usr/sbin:/sbin" ]]; then
  r22_pre_begin_fail 64 "PATH is not the frozen clean value"
fi
if [[ "${TMPDIR:-}" != "/private/tmp" ]]; then
  r22_pre_begin_fail 64 "TMPDIR is not the frozen clean value"
fi
if [[ "${GIT_CONFIG_NOSYSTEM:-}" != "1" || "${GIT_CONFIG_GLOBAL:-}" != "/dev/null" ]]; then
  r22_pre_begin_fail 64 "Git clean-environment controls are missing"
fi
if [[ -n "${BASH_ENV+x}" || -n "${ENV+x}" || -n "${CDPATH+x}" ]]; then
  r22_pre_begin_fail 64 "shell startup or directory environment was inherited"
fi

R22_PHASE="pre_begin_review22_authority"
r22_load_review22_machine_block
r22_require_lowercase_sha256 "${R22_EXPECTED_FREEZE_SHA}" "freeze hash"
r22_require_lowercase_sha256 "${R22_EXPECTED_DRIVER_SHA}" "driver hash"
r22_require_lowercase_sha256 "${R22_EXPECTED_MANIFEST_SHA}" "manifest hash"
readonly R22_EXPECTED_FREEZE_SHA
readonly R22_EXPECTED_DRIVER_SHA
readonly R22_EXPECTED_MANIFEST_SHA

R22_PHASE="pre_begin_terminal_anchors"
r22_check_anchors_to_stdout

R22_PHASE="pre_begin_manifest_shape"
r22_check_manifest_shape

R22_PHASE="pre_begin_static_manifest"
r22_check_manifest_to_stdout

R22_PHASE="pre_begin_repository_identity"
R22_ACTUAL_BRANCH="$(/usr/bin/git -C "${R22_REPOSITORY_ROOT}" symbolic-ref --quiet --short HEAD)"
R22_ACTUAL_HEAD="$(/usr/bin/git -C "${R22_REPOSITORY_ROOT}" rev-parse --verify HEAD)"
if [[ "${R22_ACTUAL_BRANCH}" != "${R22_EXPECTED_BRANCH}" ]]; then
  r22_pre_begin_fail 67 "branch is ${R22_ACTUAL_BRANCH}, expected ${R22_EXPECTED_BRANCH}"
fi
if [[ "${R22_ACTUAL_HEAD}" != "${R22_EXPECTED_HEAD}" ]]; then
  r22_pre_begin_fail 67 "HEAD is ${R22_ACTUAL_HEAD}, expected ${R22_EXPECTED_HEAD}"
fi

R22_PHASE="pre_begin_r16_preservation"
R22_R16_RUNTIME_PATHS=(
  "${R22_TASK_DIRECTORY}/r16-targeted-tests.log"
  "${R22_TASK_DIRECTORY}/r16-verify.log"
  "${R22_TASK_DIRECTORY}/r16-build.log"
  "${R22_TASK_DIRECTORY}/r16-migration-matrix.log"
  "${R22_TASK_DIRECTORY}/impl-report-r16.md"
  "${R22_TASK_DIRECTORY}/evidence/r16-clean-boundary.log"
  "${R22_TASK_DIRECTORY}/evidence/r16-bundle-provenance.log"
  "${R22_TASK_DIRECTORY}/evidence/r16-source-gates.log"
  "${R22_TASK_DIRECTORY}/evidence/r16-hash-manifest.log"
  "${R22_TASK_DIRECTORY}/evidence/r16-preview-bootstrap.log"
  "${R22_TASK_DIRECTORY}/evidence/r16-preview-cold-start.log"
  "${R22_TASK_DIRECTORY}/evidence/r16-preview-smoke.png"
)
for R22_R16_RUNTIME_PATH in "${R22_R16_RUNTIME_PATHS[@]}"; do
  r22_require_absent_path "${R22_R16_RUNTIME_PATH}"
done

R22_PHASE="pre_begin_r17_preservation"
R22_R17_RUNTIME_PATHS=(
  "${R22_TASK_DIRECTORY}/r17-targeted-tests.log"
  "${R22_TASK_DIRECTORY}/r17-verify.log"
  "${R22_TASK_DIRECTORY}/r17-build.log"
  "${R22_TASK_DIRECTORY}/r17-migration-matrix.log"
  "${R22_TASK_DIRECTORY}/impl-report-r17.md"
  "${R22_TASK_DIRECTORY}/evidence/r17-clean-boundary.log"
  "${R22_TASK_DIRECTORY}/evidence/r17-bundle-provenance.log"
  "${R22_TASK_DIRECTORY}/evidence/r17-source-gates.log"
  "${R22_TASK_DIRECTORY}/evidence/r17-hash-manifest.log"
  "${R22_TASK_DIRECTORY}/evidence/r17-preview-bootstrap.log"
  "${R22_TASK_DIRECTORY}/evidence/r17-preview-cold-start.log"
  "${R22_TASK_DIRECTORY}/evidence/r17-preview-smoke.png"
)
for R22_R17_RUNTIME_PATH in "${R22_R17_RUNTIME_PATHS[@]}"; do
  r22_require_absent_path "${R22_R17_RUNTIME_PATH}"
done

R22_PHASE="pre_begin_r18_preservation"
R22_R18_RUNTIME_PATHS=(
  "${R22_TASK_DIRECTORY}/r18-targeted-tests.log"
  "${R22_TASK_DIRECTORY}/r18-verify.log"
  "${R22_TASK_DIRECTORY}/r18-build.log"
  "${R22_TASK_DIRECTORY}/r18-migration-matrix.log"
  "${R22_TASK_DIRECTORY}/impl-report-r18.md"
  "${R22_TASK_DIRECTORY}/evidence/r18-clean-boundary.log"
  "${R22_TASK_DIRECTORY}/evidence/r18-bundle-provenance.log"
  "${R22_TASK_DIRECTORY}/evidence/r18-source-gates.log"
  "${R22_TASK_DIRECTORY}/evidence/r18-hash-manifest.log"
  "${R22_TASK_DIRECTORY}/evidence/r18-preview-bootstrap.log"
  "${R22_TASK_DIRECTORY}/evidence/r18-preview-cold-start.log"
  "${R22_TASK_DIRECTORY}/evidence/r18-preview-smoke.png"
)
for R22_R18_RUNTIME_PATH in "${R22_R18_RUNTIME_PATHS[@]}"; do
  r22_require_absent_path "${R22_R18_RUNTIME_PATH}"
done

R22_PHASE="pre_begin_r21_preservation"
R22_R21_RUNTIME_PATHS=(
  "${R22_TASK_DIRECTORY}/r21-targeted-tests.log"
  "${R22_TASK_DIRECTORY}/r21-verify.log"
  "${R22_TASK_DIRECTORY}/r21-build.log"
  "${R22_TASK_DIRECTORY}/r21-migration-matrix.log"
  "${R22_TASK_DIRECTORY}/impl-report-r21.md"
  "${R22_TASK_DIRECTORY}/evidence/r21-clean-boundary.log"
  "${R22_TASK_DIRECTORY}/evidence/r21-bundle-provenance.log"
  "${R22_TASK_DIRECTORY}/evidence/r21-source-gates.log"
  "${R22_TASK_DIRECTORY}/evidence/r21-hash-manifest.log"
  "${R22_TASK_DIRECTORY}/evidence/r21-preview-bootstrap.log"
  "${R22_TASK_DIRECTORY}/evidence/r21-preview-cold-start.log"
  "${R22_TASK_DIRECTORY}/evidence/r21-preview-smoke.png"
)
for R22_R21_RUNTIME_PATH in "${R22_R21_RUNTIME_PATHS[@]}"; do
  r22_require_absent_path "${R22_R21_RUNTIME_PATH}"
done

R22_PHASE="pre_begin_r19_containment"
r22_require_r19_containment "pre_begin"

R22_PHASE="pre_begin_r20_containment"
r22_require_r20_containment "pre_begin"

r22_require_no_unconsumed_fresh_roots "pre_begin"

R22_PHASE="pre_begin_runtime_paths"
R22_RUNTIME_PATHS=(
  "${R22_TASK_DIRECTORY}/r22-targeted-tests.log"
  "${R22_TASK_DIRECTORY}/r22-verify.log"
  "${R22_TASK_DIRECTORY}/r22-build.log"
  "${R22_TASK_DIRECTORY}/r22-migration-matrix.log"
  "${R22_TASK_DIRECTORY}/impl-report-r22.md"
  "${R22_TASK_DIRECTORY}/evidence/r22-clean-boundary.log"
  "${R22_TASK_DIRECTORY}/evidence/r22-bundle-provenance.log"
  "${R22_TASK_DIRECTORY}/evidence/r22-source-gates.log"
  "${R22_TASK_DIRECTORY}/evidence/r22-hash-manifest.log"
  "${R22_TASK_DIRECTORY}/evidence/r22-preview-bootstrap.log"
  "${R22_TASK_DIRECTORY}/evidence/r22-preview-cold-start.log"
  "${R22_TASK_DIRECTORY}/evidence/r22-preview-smoke.png"
)
for R22_RUNTIME_PATH in "${R22_RUNTIME_PATHS[@]}"; do
  r22_require_absent_path "${R22_RUNTIME_PATH}"
done

R22_PHASE="pre_begin_processes"
r22_require_process_absent "AgentLoop"
r22_require_process_absent "AgentLoopApp"

R22_PHASE="pre_begin_r15_tombstone_absence"
r22_require_r15_tombstones_absent
if [[ -e "${R22_R15_PLANNED_APP}" || -L "${R22_R15_PLANNED_APP}" ]]; then
  r22_pre_begin_fail 70 "R15 planned App must remain absent"
fi
if [[ -e "${R22_R15_SCREENSHOT}" || -L "${R22_R15_SCREENSHOT}" ]]; then
  r22_pre_begin_fail 70 "R15 screenshot must remain absent"
fi

R22_PHASE="pre_begin_activation_metadata"
R22_INVOCATION_ID="r22-$(
  /usr/bin/uuidgen |
    /usr/bin/tr '[:upper:]' '[:lower:]'
)"
if [[ ! "${R22_INVOCATION_ID}" =~ ^r22-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
  r22_pre_begin_fail 71 "generated R22 invocation ID has invalid format"
fi
R22_BEGIN_UTC="$(r22_utc_now)"
if [[ ! "${R22_BEGIN_UTC}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
  r22_pre_begin_fail 71 "generated R22 begin UTC has invalid format"
fi

R22_PHASE="pre_begin_ranch_art_structure"
r22_check_ranch_art_structure "pre_begin"

R22_PHASE="pre_begin_final_r21_preservation"
for R22_R21_RUNTIME_PATH in "${R22_R21_RUNTIME_PATHS[@]}"; do
  r22_require_absent_path "${R22_R21_RUNTIME_PATH}"
done
r22_require_no_unconsumed_fresh_roots "pre_begin"

R22_PHASE="pre_begin_final_r19_containment"
r22_require_r19_containment "pre_begin"

R22_PHASE="pre_begin_final_r20_containment"
r22_require_r20_containment "pre_begin"

R22_PHASE="activation_boundary"
trap '' HUP INT TERM
if r22_exclusive_create_empty "${R22_BOUNDARY_LOG}"; then
  R22_BOUNDARY_ACTIVE="true"
  trap 'r22_signal_error HUP' HUP
  trap 'r22_signal_error INT' INT
  trap 'r22_signal_error TERM' TERM
else
  trap 'r22_signal_error HUP' HUP
  trap 'r22_signal_error INT' INT
  trap 'r22_signal_error TERM' TERM
  r22_pre_begin_fail 71 "could not exclusive-create R22 boundary log"
fi
if ! /usr/bin/printf '%s\n' \
    "boundary=R22_VOLATILE_CONTAINMENT_AND_RELEASE_CONFIGURATION_REPAIR" \
    "invocation_id=${R22_INVOCATION_ID}" \
    "utc_begin=${R22_BEGIN_UTC}" \
    "authorization_consumed=true" \
    "boundary_exclusive_create_succeeded=true" \
    "authority_mode=standing_goal_automatic_after_review22" \
    "standing_goal_authority_verified=true" \
    "reviewer_independence_attested=true" \
    "reviewer_write_scope=review22_only" \
    "user_hash_echo_required=false" \
    "local_consistency_is_not_human_anti_rewrite=true" \
    "status=BEGIN_STARTED" \
    "branch=${R22_ACTUAL_BRANCH}" \
    "head=${R22_ACTUAL_HEAD}" \
    "r15_state_root_pre_begin_observed_state=ABSENT" \
    "r15_bundle_parent_pre_begin_observed_state=ABSENT" \
    "r15_state_root_current_absent=true" \
    "r15_bundle_parent_current_absent=true" \
    "r15_absence_proof_identity=${R22_R15_ABSENCE_PROOF_IDENTITY}" \
    "disappearance_cause=UNKNOWN" \
    "pre_begin_ranch_art_structure=true" \
    "recipe=r22-dev-bundle-v1" \
    "normal_root=/Users/muzi/Library/Application Support/AgentLoop" \
    "normal_root_access_policy=lsof_path_comparison_only" \
    "r19_invocation_id=${R22_R19_INVOCATION_ID}" \
    "r19_verdict=REJECTED_CONTAMINATED" \
    "r19_artifact_count=11" \
    "r19_state_root=${R22_R19_STATE_ROOT}" \
    "r19_bundle_parent=${R22_R19_BUNDLE_PARENT}" \
    "r19_roots_historical_state=CANONICAL_EMPTY" \
    "r19_roots_current_state=ABSENT_TOMBSTONE" \
    "r19_roots_disappearance_cause=UNKNOWN" \
    "r19_retry_same_boundary=false" \
    "r20_invocation_id=${R22_R20_INVOCATION_ID}" \
    "r20_verdict=REJECTED_CONTAMINATED" \
    "r20_failure_phase=release_core_build" \
    "r20_authoritative_full_tests=652_of_652_pass" \
    "r20_targeted_audit=46_of_46_pass" \
    "r20_launch_ready=true" \
    "r20_artifact_count=11" \
    "r20_state_root=${R22_R20_STATE_ROOT}" \
    "r20_state_root_historical_state=CANONICAL_EMPTY" \
    "r20_state_root_current_state=ABSENT_TOMBSTONE" \
    "r20_state_root_disappearance_cause=UNKNOWN" \
    "r20_bundle_parent=${R22_R20_BUNDLE_PARENT}" \
    "r20_bundle_first_observed_state=${R22_R20_BUNDLE_FIRST_OBSERVED_STATE}" \
    "r20_bundle_pre_begin_state=${R22_R20_BUNDLE_PRE_BEGIN_STATE}" \
    "r20_retry_same_boundary=false" \
    "r21_review_approved=true" \
    "r21_external_caller_anchors_passed=true" \
    "r21_static_manifest_155_of_155_passed=true" \
    "r21_pre_begin_exit_code=70" \
    "r21_pre_begin_failure_phase=r19_containment" \
    "r21_authorization_consumed=false" \
    "r21_runtime_write_count=0" \
    "implementation_entry_baseline_count=2" \
    "implementation_allowed_final_delta_count=1" \
    "implementation_final_delta_policy=exact_test_path_only_relative_to_entry_manifest" \
    "implementation_core_path=${R22_IMPLEMENTATION_CORE_PATH}" \
    "implementation_test_path=${R22_IMPLEMENTATION_TEST_PATH}" \
    "implementation_core_required_sha=${R22_R20_CORE_FINAL_SHA}" \
    "implementation_test_entry_sha=${R22_R20_TEST_FINAL_SHA}" \
    "implementation_test_delta=three_matching_debug_guard_pairs_only" \
    "authoritative_test_command=swift_run_RunTests_unfiltered_once" \
    "test_filter_forbidden=true" \
    "targeted_evidence_source=mechanical_46_name_extraction_from_authoritative_log" \
    "freeze_sha=${R22_EXPECTED_FREEZE_SHA}" \
    "review22_sha=${R22_EXPECTED_REVIEW22_SHA}" \
    "driver_sha=${R22_EXPECTED_DRIVER_SHA}" \
    "manifest_sha=${R22_EXPECTED_MANIFEST_SHA}" \
    >> "${R22_BOUNDARY_LOG}"; then
  r22_active_fail 71 "could_not_initialize_R22_boundary_log" "boundary_initialization"
fi
R22_BOUNDARY_INITIALIZED="true"

R22_PHASE="post_activation_immediate_r21_preservation"
for R22_R21_RUNTIME_PATH in "${R22_R21_RUNTIME_PATHS[@]}"; do
  r22_require_absent_path "${R22_R21_RUNTIME_PATH}"
done
r22_require_no_unconsumed_fresh_roots "post_activation"

R22_PHASE="post_activation_immediate_r19_containment"
r22_require_r19_containment "post_activation_probe"

R22_PHASE="post_activation_immediate_r20_containment"
r22_require_r20_containment "post_activation_probe"

R22_PHASE="activation_hash_log"
if ! r22_exclusive_create_empty "${R22_HASH_LOG}"; then
  r22_active_fail 71 "exclusive_create_failed_${R22_HASH_LOG}" "exclusive_create"
fi

R22_PHASE="post_activation_ranch_art_structure"
r22_check_ranch_art_structure "post_activation"

R22_PHASE="post_activation_terminal_anchors"
r22_post_activation_anchor_check

R22_PHASE="post_activation_static_manifest"
r22_check_manifest_shape
r22_post_activation_manifest_check

R22_PHASE="post_activation_r19_containment"
r22_require_r19_containment "post_activation"

R22_PHASE="post_activation_r20_containment"
r22_require_r20_containment "post_activation"

/usr/bin/printf 'frozen_info_plist_sha=%s\n' "${R22_EXPECTED_INFO_PLIST_SHA}" >> "${R22_HASH_LOG}"
/usr/bin/printf 'frozen_ranch_art_manifest_sha=%s\n' "${R22_EXPECTED_RANCH_ART_MANIFEST_SHA}" >> "${R22_HASH_LOG}"
/usr/bin/printf '%s\n' "section=worktree_status" >> "${R22_HASH_LOG}"
/usr/bin/git --no-optional-locks -C "${R22_REPOSITORY_ROOT}" status --short --branch >> "${R22_HASH_LOG}"

R22_PHASE="activation_remaining_logs"
R22_REMAINING_TEXT_LOGS=(
  "${R22_TASK_DIRECTORY}/r22-targeted-tests.log"
  "${R22_TASK_DIRECTORY}/r22-verify.log"
  "${R22_TASK_DIRECTORY}/r22-build.log"
  "${R22_TASK_DIRECTORY}/r22-migration-matrix.log"
  "${R22_TASK_DIRECTORY}/evidence/r22-bundle-provenance.log"
  "${R22_TASK_DIRECTORY}/evidence/r22-source-gates.log"
  "${R22_TASK_DIRECTORY}/evidence/r22-preview-bootstrap.log"
  "${R22_TASK_DIRECTORY}/evidence/r22-preview-cold-start.log"
)
for R22_REMAINING_TEXT_LOG in "${R22_REMAINING_TEXT_LOGS[@]}"; do
  if ! r22_exclusive_create_empty "${R22_REMAINING_TEXT_LOG}"; then
    r22_active_fail 71 "exclusive_create_failed_${R22_REMAINING_TEXT_LOG}" "exclusive_create"
  fi
done

R22_PHASE="activation_fresh_roots"
R22_STATE_ROOT="$(/usr/bin/mktemp -d '/private/tmp/agentloop-r22-state.XXXXXX')"
R22_BUNDLE_PARENT="$(/usr/bin/mktemp -d '/private/tmp/agentloop-r22-bundle.XXXXXX')"
R22_PLANNED_APP="${R22_BUNDLE_PARENT}/AgentLoop.app"
R22_PLANNED_EXECUTABLE="${R22_PLANNED_APP}/Contents/MacOS/AgentLoop"

r22_require_fresh_root "${R22_STATE_ROOT}" "fresh_state_root"
r22_require_fresh_root "${R22_BUNDLE_PARENT}" "fresh_bundle_parent"
if [[ "${R22_STATE_ROOT}" == "${R22_BUNDLE_PARENT}" ]]; then
  r22_active_fail 72 "fresh_roots_equal"
fi
case "${R22_STATE_ROOT}/" in
  "${R22_BUNDLE_PARENT}/"* )
    r22_active_fail 72 "state_root_nested_in_bundle_parent"
    ;;
esac
case "${R22_BUNDLE_PARENT}/" in
  "${R22_STATE_ROOT}/"* )
    r22_active_fail 72 "bundle_parent_nested_in_state_root"
    ;;
esac
if [[ "${R22_STATE_ROOT}" == "${R22_R15_STATE_ROOT}" ||
      "${R22_STATE_ROOT}" == "${R22_R15_BUNDLE_PARENT}" ||
      "${R22_BUNDLE_PARENT}" == "${R22_R15_STATE_ROOT}" ||
      "${R22_BUNDLE_PARENT}" == "${R22_R15_BUNDLE_PARENT}" ||
      "${R22_STATE_ROOT}" == "${R22_R19_STATE_ROOT}" ||
      "${R22_STATE_ROOT}" == "${R22_R19_BUNDLE_PARENT}" ||
      "${R22_BUNDLE_PARENT}" == "${R22_R19_STATE_ROOT}" ||
      "${R22_BUNDLE_PARENT}" == "${R22_R19_BUNDLE_PARENT}" ||
      "${R22_STATE_ROOT}" == "${R22_R20_STATE_ROOT}" ||
      "${R22_STATE_ROOT}" == "${R22_R20_BUNDLE_PARENT}" ||
      "${R22_BUNDLE_PARENT}" == "${R22_R20_STATE_ROOT}" ||
      "${R22_BUNDLE_PARENT}" == "${R22_R20_BUNDLE_PARENT}" ]]; then
  r22_active_fail 72 "fresh_root_reuses_historical_root"
fi
if [[ -e "${R22_PLANNED_APP}" || -L "${R22_PLANNED_APP}" ]]; then
  r22_active_fail 72 "planned_app_preexists"
fi

R22_PHASE="post_root_r21_preservation"
for R22_R21_RUNTIME_PATH in "${R22_R21_RUNTIME_PATHS[@]}"; do
  r22_require_absent_path "${R22_R21_RUNTIME_PATH}"
done
r22_require_no_unconsumed_fresh_roots "post_activation"

R22_PHASE="post_root_final_r19_containment"
r22_require_r19_containment "post_activation_probe"

R22_PHASE="post_root_final_r20_containment"
r22_require_r20_containment "post_activation_probe"

/usr/bin/printf '%s\n' \
  "section=final_historical_root_lifecycle" \
  "r19_roots_current_state=ABSENT_TOMBSTONE" \
  "r20_state_root_current_state=ABSENT_TOMBSTONE" \
  "r20_bundle_first_observed_state=${R22_R20_BUNDLE_FIRST_OBSERVED_STATE}" \
  "r20_bundle_pre_begin_state=${R22_R20_BUNDLE_PRE_BEGIN_STATE}" \
  "r20_bundle_final_observed_state=${R22_R20_BUNDLE_CURRENT_STATE}" \
  >> "${R22_HASH_LOG}"

r22_append_boundary "state_root=${R22_STATE_ROOT}"
r22_append_boundary "bundle_parent=${R22_BUNDLE_PARENT}"
r22_append_boundary "planned_app=${R22_PLANNED_APP}"
r22_append_boundary "planned_executable=${R22_PLANNED_EXECUTABLE}"
r22_append_boundary "final_executable_hash=DEFERRED_TO_LAUNCH_READY"
r22_append_boundary "process_count=0"
r22_append_boundary "r15_planned_app_absent=true"
r22_append_boundary "r15_screenshot_absent=true"
r22_append_boundary "r16_runtime_artifacts_absent=true"
r22_append_boundary "r16_fresh_roots_absent=true"
r22_append_boundary "r16_pre_begin_zero_write_preserved=true"
r22_append_boundary "r17_runtime_artifacts_absent=true"
r22_append_boundary "r17_fresh_roots_absent=true"
r22_append_boundary "r17_not_executed_preserved=true"
  r22_append_boundary "r18_runtime_artifacts_absent=true"
  r22_append_boundary "r18_fresh_roots_absent=true"
  r22_append_boundary "r18_not_executed_preserved=true"
  r22_append_boundary "r21_runtime_artifacts_absent=true"
  r22_append_boundary "r21_fresh_roots_absent=true"
  r22_append_boundary "r21_pre_begin_zero_write_preserved=true"
  r22_append_boundary "r21_authorization_consumed=false"
  r22_append_boundary "r19_runtime_artifacts_immutable=true"
r22_append_boundary "r19_runtime_artifact_count=11"
  r22_append_boundary "r19_boundary_rejected_contaminated=true"
  r22_append_boundary "r19_state_root=${R22_R19_STATE_ROOT}"
  r22_append_boundary "r19_bundle_parent=${R22_R19_BUNDLE_PARENT}"
  r22_append_boundary "r19_roots_historical_state=CANONICAL_EMPTY"
  r22_append_boundary "r19_roots_current_state=ABSENT_TOMBSTONE"
  r22_append_boundary "r19_roots_disappearance_cause=UNKNOWN"
  r22_append_boundary "r19_tombstone_absorbing=true"
r22_append_boundary "r19_planned_app_absent=true"
r22_append_boundary "r19_screenshot_absent=true"
r22_append_boundary "r19_retry_same_boundary=false"
r22_append_boundary "r20_runtime_artifacts_immutable=true"
r22_append_boundary "r20_runtime_artifact_count=11"
r22_append_boundary "r20_boundary_rejected_contaminated=true"
r22_append_boundary "r20_failure_phase=release_core_build"
r22_append_boundary "r20_authoritative_full_tests=652_of_652_pass"
r22_append_boundary "r20_targeted_audit=46_of_46_pass"
  r22_append_boundary "r20_launch_ready=true"
  r22_append_boundary "r20_state_root=${R22_R20_STATE_ROOT}"
  r22_append_boundary "r20_bundle_parent=${R22_R20_BUNDLE_PARENT}"
  r22_append_boundary "r20_state_root_historical_state=CANONICAL_EMPTY"
  r22_append_boundary "r20_state_root_current_state=ABSENT_TOMBSTONE"
  r22_append_boundary "r20_state_root_disappearance_cause=UNKNOWN"
  r22_append_boundary "r20_bundle_pre_begin_state=${R22_R20_BUNDLE_PRE_BEGIN_STATE}"
  r22_append_boundary "r20_bundle_first_observed_state=${R22_R20_BUNDLE_FIRST_OBSERVED_STATE}"
  r22_append_boundary "r20_bundle_post_activation_state=${R22_R20_BUNDLE_CURRENT_STATE}"
  r22_append_boundary "r20_bundle_transition=${R22_R20_BUNDLE_PRE_BEGIN_STATE}_TO_${R22_R20_BUNDLE_CURRENT_STATE}"
  if [[ "${R22_R20_BUNDLE_CURRENT_STATE}" == "VERIFIED_RETAINED" ]]; then
    r22_append_boundary "r20_bundle_parent_exact_child=${R22_R20_APP}"
    r22_append_boundary "r20_signed_app_verified=true"
    r22_append_boundary "r20_signed_app_path_transport=find_print0_bash_read_d_nul_v1"
    r22_append_boundary "r20_signed_app_all_node_count=36"
    r22_append_boundary "r20_signed_app_directory_count=6"
    r22_append_boundary "r20_signed_app_regular_file_count=30"
    r22_append_boundary "r20_signed_bundle_manifest_recomputed=true"
    r22_append_boundary "r20_executable_sha=${R22_R20_EXECUTABLE_SHA}"
    r22_append_boundary "r20_info_plist_sha=${R22_R20_INFO_PLIST_SHA}"
    r22_append_boundary "r20_signed_bundle_manifest_sha=${R22_R20_SIGNED_BUNDLE_MANIFEST_SHA}"
  else
    r22_append_boundary "r20_bundle_absorbing_tombstone=true"
    r22_append_boundary "r20_bundle_disappearance_cause=UNKNOWN"
    r22_append_boundary "r20_historical_executable_sha=${R22_R20_EXECUTABLE_SHA}"
    r22_append_boundary "r20_historical_info_plist_sha=${R22_R20_INFO_PLIST_SHA}"
    r22_append_boundary "r20_historical_signed_bundle_manifest_sha=${R22_R20_SIGNED_BUNDLE_MANIFEST_SHA}"
  fi
r22_append_boundary "r20_screenshot_absent=true"
r22_append_boundary "r20_retry_same_boundary=false"
r22_append_boundary "r22_pre_activation_fresh_roots_absent=true"
r22_append_boundary "frozen_info_plist_sha=${R22_EXPECTED_INFO_PLIST_SHA}"
r22_append_boundary "frozen_ranch_art_manifest_sha=${R22_EXPECTED_RANCH_ART_MANIFEST_SHA}"

R22_PHASE="begin_finalization"
r22_require_process_absent "AgentLoop"
r22_require_process_absent "AgentLoopApp"
r22_append_boundary "utc_begin_attested=$(r22_utc_now)"
r22_append_boundary "begin_attestation_complete=true"
r22_append_boundary "status=BEGIN_ATTESTED"
r22_append_boundary "retry_same_boundary=false"

/usr/bin/printf '%s\n' \
  "status=BEGIN_ATTESTED" \
  "invocation_id=${R22_INVOCATION_ID}" \
  "boundary_log=${R22_BOUNDARY_LOG}" \
  "hash_log=${R22_HASH_LOG}" \
  "state_root=${R22_STATE_ROOT}" \
  "bundle_parent=${R22_BUNDLE_PARENT}" \
  "planned_app=${R22_PLANNED_APP}" \
  "planned_executable=${R22_PLANNED_EXECUTABLE}"
