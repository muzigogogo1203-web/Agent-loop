#!/bin/bash

# R21 BEGIN-only candidate driver.
# This file does not run tests, build, migration matrix, source gates, bundle
# assembly, signing, or preview. It establishes one fail-once evidence boundary.

set -Eeuo pipefail
set -f
IFS=$' \t\n'
umask 077

readonly R21_REPOSITORY_ROOT="/Users/muzi/Agent-loop"
readonly R21_TASK_DIRECTORY="${R21_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination"
readonly R21_DRIVER_PATH="${R21_TASK_DIRECTORY}/evidence/r21-begin.sh"
readonly R21_MANIFEST_PATH="${R21_TASK_DIRECTORY}/evidence/r21-entry.sha256"
readonly R21_FREEZE_PATH="${R21_TASK_DIRECTORY}/evidence/plan-freeze-r21.md"
readonly R21_REVIEW21_PATH="${R21_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/21-p1-plan-review.md"
readonly R21_BOUNDARY_LOG="${R21_TASK_DIRECTORY}/evidence/r21-clean-boundary.log"
readonly R21_HASH_LOG="${R21_TASK_DIRECTORY}/evidence/r21-hash-manifest.log"
readonly R21_RANCH_ART_DIRECTORY="${R21_REPOSITORY_ROOT}/Sources/AgentLoopApp/Resources/RanchArt"
readonly R21_EXPECTED_MANIFEST_COUNT="155"
readonly R21_EXPECTED_BRANCH="codex/personal-ai-ranch-p0"
readonly R21_EXPECTED_HEAD="02334ec8d21533be81d93d39191bc7d9b9c24f7f"
readonly R21_EXPECTED_INFO_PLIST_SHA="5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58"
readonly R21_EXPECTED_RANCH_ART_MANIFEST_SHA="4f73a80e821faa64d0a29d797cc12e20d5f88248bbb186e74972af49798ddbab"
readonly R21_R15_STATE_ROOT_BASENAME="agentloop-r15-state.Zq6Jvm"
readonly R21_R15_BUNDLE_PARENT_BASENAME="agentloop-r15-bundle.2xROcy"
readonly R21_R15_STATE_ROOT="/private/tmp/${R21_R15_STATE_ROOT_BASENAME}"
readonly R21_R15_BUNDLE_PARENT="/private/tmp/${R21_R15_BUNDLE_PARENT_BASENAME}"
readonly R21_R15_ABSENCE_PROOF_IDENTITY="private_tmp_parent_enumeration_exact_basename_v1"
readonly R21_R15_PLANNED_APP="${R21_R15_BUNDLE_PARENT}/AgentLoop.app"
readonly R21_R15_SCREENSHOT="${R21_TASK_DIRECTORY}/evidence/r15-preview-smoke.png"
readonly R21_R19_INVOCATION_ID="r19-daef1dab-0fbe-4a03-bab1-422adc18b3d4"
readonly R21_R19_MANIFEST_PATH="${R21_TASK_DIRECTORY}/evidence/r19-entry.sha256"
readonly R21_R19_FREEZE_PATH="${R21_TASK_DIRECTORY}/evidence/plan-freeze-r19.md"
readonly R21_R19_REVIEW_PATH="${R21_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/19-p1-plan-review.md"
readonly R21_R19_STATE_ROOT="/private/tmp/agentloop-r19-state.dNgUXh"
readonly R21_R19_BUNDLE_PARENT="/private/tmp/agentloop-r19-bundle.49xVDm"
readonly R21_R19_PLANNED_APP="${R21_R19_BUNDLE_PARENT}/AgentLoop.app"
readonly R21_R19_SCREENSHOT="${R21_TASK_DIRECTORY}/evidence/r19-preview-smoke.png"
readonly R21_R19_BOUNDARY_LOG="${R21_TASK_DIRECTORY}/evidence/r19-clean-boundary.log"
readonly R21_R19_HASH_LOG="${R21_TASK_DIRECTORY}/evidence/r19-hash-manifest.log"
readonly R21_R19_TARGETED_LOG="${R21_TASK_DIRECTORY}/r19-targeted-tests.log"
readonly R21_R19_VERIFY_LOG="${R21_TASK_DIRECTORY}/r19-verify.log"
readonly R21_R19_REPORT="${R21_TASK_DIRECTORY}/impl-report-r19.md"
readonly R21_R20_INVOCATION_ID="r20-98452cde-0ff4-4b66-b3f6-8085eb045a6f"
readonly R21_R20_MANIFEST_PATH="${R21_TASK_DIRECTORY}/evidence/r20-entry.sha256"
readonly R21_R20_FREEZE_PATH="${R21_TASK_DIRECTORY}/evidence/plan-freeze-r20.md"
readonly R21_R20_REVIEW_PATH="${R21_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/20-p1-plan-review.md"
readonly R21_R20_STATE_ROOT="/private/tmp/agentloop-r20-state.3QwlQa"
readonly R21_R20_BUNDLE_PARENT="/private/tmp/agentloop-r20-bundle.30V5RH"
readonly R21_R20_APP="${R21_R20_BUNDLE_PARENT}/AgentLoop.app"
readonly R21_R20_EXECUTABLE="${R21_R20_APP}/Contents/MacOS/AgentLoop"
readonly R21_R20_INFO_PLIST="${R21_R20_APP}/Contents/Info.plist"
readonly R21_R20_SCREENSHOT="${R21_TASK_DIRECTORY}/evidence/r20-preview-smoke.png"
readonly R21_R20_BOUNDARY_LOG="${R21_TASK_DIRECTORY}/evidence/r20-clean-boundary.log"
readonly R21_R20_HASH_LOG="${R21_TASK_DIRECTORY}/evidence/r20-hash-manifest.log"
readonly R21_R20_TARGETED_LOG="${R21_TASK_DIRECTORY}/r20-targeted-tests.log"
readonly R21_R20_VERIFY_LOG="${R21_TASK_DIRECTORY}/r20-verify.log"
readonly R21_R20_BUILD_LOG="${R21_TASK_DIRECTORY}/r20-build.log"
readonly R21_R20_REPORT="${R21_TASK_DIRECTORY}/impl-report-r20.md"
readonly R21_R20_EXECUTABLE_SHA="d55fc10e674b77b480a85de46137eff40d40bd94b27c8e33b0d49f55d40a049c"
readonly R21_R20_INFO_PLIST_SHA="5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58"
readonly R21_R20_SIGNED_BUNDLE_MANIFEST_SHA="06e063d4fdd541a808c78eacc5b34ddfd64874a3ab1648bbfe6bf74646db8170"
readonly R21_R20_CORE_FINAL_SHA="c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275"
readonly R21_R20_TEST_FINAL_SHA="66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26"
readonly R21_IMPLEMENTATION_CORE_PATH="${R21_REPOSITORY_ROOT}/Sources/AgentLoopCore/Loop/AgentLoop.swift"
readonly R21_IMPLEMENTATION_TEST_PATH="${R21_REPOSITORY_ROOT}/Sources/AgentLoopTestSuite/AgentLoopTests.swift"

R21_BOUNDARY_ACTIVE="false"
R21_PHASE="pre_begin"
R21_INVOCATION_ID=""
R21_STATE_ROOT=""
R21_BUNDLE_PARENT=""

r21_utc_now() {
  /bin/date -u '+%Y-%m-%dT%H:%M:%SZ'
}

r21_pre_begin_fail() {
  local r21_exit_code="$1"
  shift
  /usr/bin/printf 'R21 pre-BEGIN rejected: %s\n' "$*" >&2
  exit "$r21_exit_code"
}

r21_append_boundary() {
  /usr/bin/printf '%s\n' "$*" >> "${R21_BOUNDARY_LOG}"
}

r21_authorization_is_consumed() {
  if [[ "${R21_BOUNDARY_ACTIVE}" == "true" ]]; then
    return 0
  fi
  if [[ -n "${R21_INVOCATION_ID}" &&
        -f "${R21_BOUNDARY_LOG}" &&
        ! -L "${R21_BOUNDARY_LOG}" ]] &&
     /usr/bin/grep -Fx "invocation_id=${R21_INVOCATION_ID}" "${R21_BOUNDARY_LOG}" >/dev/null 2>&1 &&
     /usr/bin/grep -Fx 'authorization_consumed=true' "${R21_BOUNDARY_LOG}" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

r21_active_fail() {
  local r21_exit_code="$1"
  local r21_reason="$2"
  local r21_command="${3:-explicit_fail_closed}"
  trap - ERR HUP INT TERM
  set +e
  r21_append_boundary "utc=$(r21_utc_now)"
  r21_append_boundary "status=REJECTED_CONTAMINATED"
  r21_append_boundary "phase=${R21_PHASE}"
  r21_append_boundary "reason=${r21_reason}"
  printf 'failed_command=%q\n' "${r21_command}" >> "${R21_BOUNDARY_LOG}"
  r21_append_boundary "exit_code=${r21_exit_code}"
  r21_append_boundary "state_root=${R21_STATE_ROOT:-UNCREATED}"
  r21_append_boundary "bundle_parent=${R21_BUNDLE_PARENT:-UNCREATED}"
  if [[ -n "${R21_PLANNED_APP:-}" ]]; then
    r21_append_boundary "planned_app=${R21_PLANNED_APP}"
  fi
  r21_append_boundary "retry_same_boundary=false"
  /usr/bin/printf 'R21 rejected after authorization consumption: %s\n' "${r21_reason}" >&2
  exit "$r21_exit_code"
}

r21_unexpected_error() {
  local r21_exit_code="$?"
  local r21_command="${BASH_COMMAND:-unknown}"
  trap - ERR
  if r21_authorization_is_consumed; then
    r21_active_fail "${r21_exit_code}" "unexpected_command_failure" "${r21_command}"
  fi
  printf 'R21 pre-BEGIN command failed: phase=%s rc=%s command=%q\n' \
    "${R21_PHASE}" "${r21_exit_code}" "${r21_command}" >&2
  exit "${r21_exit_code}"
}

r21_signal_error() {
  local r21_signal="$1"
  trap - HUP INT TERM
  if r21_authorization_is_consumed; then
    r21_active_fail "74" "signal_${r21_signal}" "signal_${r21_signal}"
  fi
  /usr/bin/printf 'R21 pre-BEGIN interrupted by signal %s\n' "${r21_signal}" >&2
  exit 74
}

trap r21_unexpected_error ERR
trap 'r21_signal_error HUP' HUP
trap 'r21_signal_error INT' INT
trap 'r21_signal_error TERM' TERM

r21_attestation_fail() {
  local r21_exit_code="$1"
  shift
  if r21_authorization_is_consumed; then
    r21_active_fail "${r21_exit_code}" "$*"
  fi
  r21_pre_begin_fail "${r21_exit_code}" "$*"
}

r21_require_lowercase_sha256() {
  local r21_value="$1"
  local r21_label="$2"
  if [[ "${#r21_value}" -ne 64 ]]; then
    r21_pre_begin_fail 64 "${r21_label} must be exactly 64 lowercase hex characters"
  fi
  case "${r21_value}" in
    *[!0-9a-f]*)
      r21_pre_begin_fail 64 "${r21_label} must be exactly 64 lowercase hex characters"
      ;;
  esac
}

r21_emit_anchor_manifest() {
  /usr/bin/printf '%s  %s\n' "${R21_EXPECTED_FREEZE_SHA}" "${R21_FREEZE_PATH}"
  /usr/bin/printf '%s  %s\n' "${R21_EXPECTED_REVIEW21_SHA}" "${R21_REVIEW21_PATH}"
  /usr/bin/printf '%s  %s\n' "${R21_EXPECTED_DRIVER_SHA}" "${R21_DRIVER_PATH}"
  /usr/bin/printf '%s  %s\n' "${R21_EXPECTED_MANIFEST_SHA}" "${R21_MANIFEST_PATH}"
}

r21_check_anchors_to_stdout() {
  local -a r21_anchor_status
  if r21_emit_anchor_manifest |
    /usr/bin/shasum -a 256 --strict -c -; then
    r21_anchor_status=( "${PIPESTATUS[@]}" )
  else
    r21_anchor_status=( "${PIPESTATUS[@]}" )
  fi
  if [[ "${r21_anchor_status[0]}" -ne 0 || "${r21_anchor_status[1]}" -ne 0 ]]; then
    r21_pre_begin_fail 65 "terminal anchor verification failed with producer_rc=${r21_anchor_status[0]} shasum_rc=${r21_anchor_status[1]}"
  fi
}

r21_manifest_contains_path() {
  local r21_manifest_file="$1"
  local r21_expected_path="$2"
  local r21_manifest_line
  local r21_manifest_entry_path
  while IFS= read -r r21_manifest_line || [[ -n "${r21_manifest_line}" ]]; do
    r21_manifest_entry_path="${r21_manifest_line#*  }"
    if [[ "${r21_manifest_entry_path}" == "${r21_expected_path}" ]]; then
      return 0
    fi
  done < "${r21_manifest_file}"
  return 1
}

r21_check_manifest_shape() {
  local r21_manifest_count
  local r21_manifest_count_rc
  local r21_r20_manifest_count
  local r21_r20_manifest_count_rc
  local r21_r20_manifest_line
  local r21_r20_manifest_entry_path
  local r21_required_addition
  local -a r21_required_additions=(
    "${R21_DRIVER_PATH}"
    "${R21_R20_MANIFEST_PATH}"
    "${R21_R20_FREEZE_PATH}"
    "${R21_R20_REVIEW_PATH}"
    "${R21_R20_TARGETED_LOG}"
    "${R21_R20_VERIFY_LOG}"
    "${R21_R20_BUILD_LOG}"
    "${R21_TASK_DIRECTORY}/r20-migration-matrix.log"
    "${R21_R20_REPORT}"
    "${R21_R20_BOUNDARY_LOG}"
    "${R21_TASK_DIRECTORY}/evidence/r20-bundle-provenance.log"
    "${R21_TASK_DIRECTORY}/evidence/r20-source-gates.log"
    "${R21_R20_HASH_LOG}"
    "${R21_TASK_DIRECTORY}/evidence/r20-preview-bootstrap.log"
    "${R21_TASK_DIRECTORY}/evidence/r20-preview-cold-start.log"
  )
  if [[ ! -f "${R21_MANIFEST_PATH}" || -L "${R21_MANIFEST_PATH}" ]]; then
    r21_attestation_fail 66 "static manifest is missing, non-regular, or a symlink"
  fi
  if r21_manifest_count="$(
    trap - ERR
    /usr/bin/awk 'END { print NR }' "${R21_MANIFEST_PATH}"
  )"; then
    r21_manifest_count_rc=0
  else
    r21_manifest_count_rc="$?"
  fi
  if [[ "${r21_manifest_count_rc}" -ne 0 ]]; then
    r21_attestation_fail 66 "static manifest record count failed with rc=${r21_manifest_count_rc}"
  fi
  if [[ "${r21_manifest_count}" != "${R21_EXPECTED_MANIFEST_COUNT}" ]]; then
    r21_attestation_fail 66 "static manifest entry count is ${r21_manifest_count}, expected ${R21_EXPECTED_MANIFEST_COUNT}"
  fi
  if /usr/bin/grep -F -- "  ${R21_MANIFEST_PATH}" "${R21_MANIFEST_PATH}" >/dev/null 2>&1; then
    r21_attestation_fail 66 "static manifest must not contain itself"
  fi
  if /usr/bin/grep -F -- "  ${R21_FREEZE_PATH}" "${R21_MANIFEST_PATH}" >/dev/null 2>&1; then
    r21_attestation_fail 66 "static manifest must not contain the R21 freeze"
  fi
  if /usr/bin/grep -F -- "  ${R21_REVIEW21_PATH}" "${R21_MANIFEST_PATH}" >/dev/null 2>&1; then
    r21_attestation_fail 66 "static manifest must not contain Review21"
  fi
  if ! /usr/bin/cut -c 67- "${R21_MANIFEST_PATH}" | LC_ALL=C /usr/bin/sort -cu; then
    r21_attestation_fail 66 "static manifest paths are not bytewise sorted and unique"
  fi
  while IFS= read -r r21_manifest_line || [[ -n "${r21_manifest_line}" ]]; do
    local r21_manifest_entry_path="${r21_manifest_line#*  }"
    case "${r21_manifest_entry_path}" in
      "${R21_REPOSITORY_ROOT}"/*)
        ;;
      *)
        r21_attestation_fail 66 "static manifest entry is outside the repository"
        ;;
    esac
    case "${r21_manifest_entry_path}" in
      *"/../"*|*"/./"*|*/..|*/.)
        r21_attestation_fail 66 "static manifest entry contains a non-canonical path segment"
        ;;
    esac
    if [[ ! -f "${r21_manifest_entry_path}" || -L "${r21_manifest_entry_path}" ]]; then
      r21_attestation_fail 66 "static manifest entry is non-regular or a symlink: ${r21_manifest_entry_path}"
    fi
  done < "${R21_MANIFEST_PATH}"

  if ! /usr/bin/grep -Fx -- \
      "${R21_R20_CORE_FINAL_SHA}  ${R21_IMPLEMENTATION_CORE_PATH}" \
      "${R21_MANIFEST_PATH}" >/dev/null 2>&1; then
    r21_attestation_fail 66 "R21 manifest does not pin the immutable R20-final Core source"
  fi
  if ! /usr/bin/grep -Fx -- \
      "${R21_R20_TEST_FINAL_SHA}  ${R21_IMPLEMENTATION_TEST_PATH}" \
      "${R21_MANIFEST_PATH}" >/dev/null 2>&1; then
    r21_attestation_fail 66 "R21 manifest does not pin the R20-final TestSuite entry source"
  fi

  if [[ ! -f "${R21_R20_MANIFEST_PATH}" || -L "${R21_R20_MANIFEST_PATH}" ]]; then
    r21_attestation_fail 66 "immutable R20 manifest is missing, non-regular, or a symlink"
  fi
  if r21_r20_manifest_count="$(
    trap - ERR
    /usr/bin/awk 'END { print NR }' "${R21_R20_MANIFEST_PATH}"
  )"; then
    r21_r20_manifest_count_rc=0
  else
    r21_r20_manifest_count_rc="$?"
  fi
  if [[ "${r21_r20_manifest_count_rc}" -ne 0 ]]; then
    r21_attestation_fail 66 "immutable R20 manifest record count failed with rc=${r21_r20_manifest_count_rc}"
  fi
  if [[ "${r21_r20_manifest_count}" != "140" ]]; then
    r21_attestation_fail 66 "immutable R20 manifest no longer has exactly 140 entries"
  fi
  if ! /usr/bin/cut -c 67- "${R21_R20_MANIFEST_PATH}" | LC_ALL=C /usr/bin/sort -cu; then
    r21_attestation_fail 66 "immutable R20 manifest paths are not bytewise sorted and unique"
  fi
  if [[ "${#r21_required_additions[@]}" -ne 15 ]]; then
    r21_attestation_fail 66 "R21 required-addition set no longer has exactly 15 paths"
  fi
  while IFS= read -r r21_r20_manifest_line || [[ -n "${r21_r20_manifest_line}" ]]; do
    r21_r20_manifest_entry_path="${r21_r20_manifest_line#*  }"
    if ! r21_manifest_contains_path "${R21_MANIFEST_PATH}" "${r21_r20_manifest_entry_path}"; then
      r21_attestation_fail 66 "R21 manifest does not inherit the complete R20 path set"
    fi
  done < "${R21_R20_MANIFEST_PATH}"
  for r21_required_addition in "${r21_required_additions[@]}"; do
    if r21_manifest_contains_path "${R21_R20_MANIFEST_PATH}" "${r21_required_addition}"; then
      r21_attestation_fail 66 "R21 required addition unexpectedly overlaps the R20 path set"
    fi
    if ! r21_manifest_contains_path "${R21_MANIFEST_PATH}" "${r21_required_addition}"; then
      r21_attestation_fail 66 "R21 manifest is missing a required addition"
    fi
  done
}

r21_check_manifest_to_stdout() {
  local r21_manifest_rc
  if /usr/bin/shasum -a 256 --strict -c "${R21_MANIFEST_PATH}"; then
    r21_manifest_rc=0
  else
    r21_manifest_rc="$?"
  fi
  if [[ "${r21_manifest_rc}" -ne 0 ]]; then
    r21_pre_begin_fail 66 "static manifest verification failed with rc=${r21_manifest_rc}"
  fi
}

r21_require_process_absent() {
  local r21_process_name="$1"
  local r21_process_rc
  if /usr/bin/pgrep -x "${r21_process_name}" >/dev/null 2>&1; then
    r21_process_rc=0
  else
    r21_process_rc="$?"
  fi
  case "${r21_process_rc}" in
    1)
      ;;
    0)
      r21_attestation_fail 69 "${r21_process_name} process is present"
      ;;
    *)
      r21_attestation_fail 69 "pgrep for ${r21_process_name} was indeterminate with rc=${r21_process_rc}"
      ;;
  esac
}

r21_require_absent_path() {
  local r21_path="$1"
  if [[ -e "${r21_path}" || -L "${r21_path}" ]]; then
    r21_pre_begin_fail 68 "runtime artifact already exists: ${r21_path}"
  fi
}

r21_probe_empty_directory() {
  local r21_path="$1"
  local r21_probe_output
  local r21_probe_rc
  if r21_probe_output="$(
    trap - ERR
    /usr/bin/find "${r21_path}" -mindepth 1 -maxdepth 1 -print -quit 2>&1
  )"; then
    r21_probe_rc=0
  else
    r21_probe_rc="$?"
  fi
  if [[ "${r21_probe_rc}" -ne 0 ]]; then
    return 2
  fi
  if [[ -n "${r21_probe_output}" ]]; then
    return 1
  fi
  return 0
}

r21_require_r15_tombstones_absent() {
  local r21_r15_tombstone_probe_output
  local r21_r15_tombstone_probe_rc
  if [[ -z "${R21_R15_STATE_ROOT_BASENAME}" ||
        "${R21_R15_STATE_ROOT_BASENAME}" == "." ||
        "${R21_R15_STATE_ROOT_BASENAME}" == ".." ||
        -z "${R21_R15_BUNDLE_PARENT_BASENAME}" ||
        "${R21_R15_BUNDLE_PARENT_BASENAME}" == "." ||
        "${R21_R15_BUNDLE_PARENT_BASENAME}" == ".." ||
        "${R21_R15_STATE_ROOT_BASENAME}" == "${R21_R15_BUNDLE_PARENT_BASENAME}" ]]; then
    r21_pre_begin_fail 70 "R15 tombstone basenames are invalid or non-distinct"
  fi
  if [[ "${R21_R15_STATE_ROOT_BASENAME}" != "agentloop-r15-state.Zq6Jvm" ||
        "${R21_R15_BUNDLE_PARENT_BASENAME}" != "agentloop-r15-bundle.2xROcy" ||
        "${R21_R15_STATE_ROOT}" != "/private/tmp/agentloop-r15-state.Zq6Jvm" ||
        "${R21_R15_BUNDLE_PARENT}" != "/private/tmp/agentloop-r15-bundle.2xROcy" ]]; then
    r21_pre_begin_fail 70 "R15 tombstone frozen basename or path identity drifted"
  fi
  if [[ "${R21_R15_STATE_ROOT}" != "/private/tmp/${R21_R15_STATE_ROOT_BASENAME}" ||
        "${R21_R15_BUNDLE_PARENT}" != "/private/tmp/${R21_R15_BUNDLE_PARENT_BASENAME}" ]]; then
    r21_pre_begin_fail 70 "R15 tombstone path reconstruction failed"
  fi
  if [[ ! -d /private/tmp || -L /private/tmp ]]; then
    r21_pre_begin_fail 70 "R15 tombstone parent is missing, non-directory, or symlink: /private/tmp"
  fi
  if r21_r15_tombstone_probe_output="$(
    trap - ERR
    /usr/bin/find /private/tmp \
      -mindepth 1 -maxdepth 1 \
      \( \
        -name "${R21_R15_STATE_ROOT_BASENAME}" -o \
        -name "${R21_R15_BUNDLE_PARENT_BASENAME}" \
      \) \
      -print -quit 2>&1
  )"; then
    r21_r15_tombstone_probe_rc=0
  else
    r21_r15_tombstone_probe_rc="$?"
  fi
  if [[ "${r21_r15_tombstone_probe_rc}" -ne 0 ]]; then
    r21_pre_begin_fail 70 "R15 tombstone absence parent enumeration was indeterminate with rc=${r21_r15_tombstone_probe_rc}"
  fi
  if [[ -n "${r21_r15_tombstone_probe_output}" ]]; then
    r21_pre_begin_fail 70 "R15 tombstoned volatile root reappeared: ${r21_r15_tombstone_probe_output}"
  fi
  if [[ -e "${R21_R15_STATE_ROOT}" || -L "${R21_R15_STATE_ROOT}" ]]; then
    r21_pre_begin_fail 70 "R15 tombstoned state root reappeared after parent enumeration: ${R21_R15_STATE_ROOT}"
  fi
  if [[ -e "${R21_R15_BUNDLE_PARENT}" || -L "${R21_R15_BUNDLE_PARENT}" ]]; then
    r21_pre_begin_fail 70 "R15 tombstoned bundle parent reappeared after parent enumeration: ${R21_R15_BUNDLE_PARENT}"
  fi
}

r21_require_no_unconsumed_fresh_roots() {
  local r21_root_probe_output
  local r21_root_probe_rc
  if r21_root_probe_output="$(
    trap - ERR
    /usr/bin/find /private/tmp \
      -mindepth 1 -maxdepth 1 \
      \( \
        -name 'agentloop-r16-state.*' -o \
        -name 'agentloop-r16-bundle.*' -o \
        -name 'agentloop-r17-state.*' -o \
        -name 'agentloop-r17-bundle.*' -o \
        -name 'agentloop-r18-state.*' -o \
        -name 'agentloop-r18-bundle.*' -o \
        -name 'agentloop-r21-state.*' -o \
        -name 'agentloop-r21-bundle.*' \
      \) \
      -print -quit 2>&1
  )"; then
    r21_root_probe_rc=0
  else
    r21_root_probe_rc="$?"
  fi
  if [[ "${r21_root_probe_rc}" -ne 0 ]]; then
    r21_pre_begin_fail 70 "R16/R17/R18/R21 fresh-root absence probe was indeterminate with rc=${r21_root_probe_rc}"
  fi
  if [[ -n "${r21_root_probe_output}" ]]; then
    r21_pre_begin_fail 70 "R16/R17/R18/R21 fresh root must remain absent: ${r21_root_probe_output}"
  fi
}

r21_exclusive_create_empty() {
  local r21_path="$1"
  ( set -C; : > "${r21_path}" )
}

r21_require_fresh_root() {
  local r21_path="$1"
  local r21_label="$2"
  local r21_probe_rc
  local r21_realpath
  local r21_realpath_rc
  if [[ ! -d "${r21_path}" || -L "${r21_path}" ]]; then
    r21_active_fail 72 "${r21_label}_invalid_type"
  fi
  if r21_realpath="$(
    trap - ERR
    /bin/realpath "${r21_path}" 2>&1
  )"; then
    r21_realpath_rc=0
  else
    r21_realpath_rc="$?"
  fi
  if [[ "${r21_realpath_rc}" -ne 0 ]]; then
    r21_active_fail 72 "${r21_label}_realpath_probe_failed"
  fi
  if [[ "${r21_realpath}" != "${r21_path}" ]]; then
    r21_active_fail 72 "${r21_label}_realpath_mismatch"
  fi
  if r21_probe_empty_directory "${r21_path}"; then
    return 0
  else
    r21_probe_rc="$?"
  fi
  if [[ "${r21_probe_rc}" -eq 1 ]]; then
    r21_active_fail 72 "${r21_label}_not_empty"
  fi
  r21_active_fail 72 "${r21_label}_emptiness_probe_indeterminate"
}

r21_emit_r19_artifact_manifest() {
  /usr/bin/printf '%s  %s\n' \
    "501957999e7a8103e553cb580d9b70f0825ee79a5c9a89e4b47e13c5db350f45" "${R21_R19_TARGETED_LOG}" \
    "8ef56ce31c3e01c551e4ef65c98ce43e3631ad7554b56640e943cdb0ce5d5c15" "${R21_R19_VERIFY_LOG}" \
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "${R21_TASK_DIRECTORY}/r19-build.log" \
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "${R21_TASK_DIRECTORY}/r19-migration-matrix.log" \
    "cddaffeaf553ff72b8f40ea1748baad649d98f747ff2210722f8fd1c388aceec" "${R21_R19_REPORT}" \
    "a5e1b1b8edda476204f4b0fbcc01f90e3e6bced1dee07daf4d58b9f4e143ca30" "${R21_R19_BOUNDARY_LOG}" \
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "${R21_TASK_DIRECTORY}/evidence/r19-bundle-provenance.log" \
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "${R21_TASK_DIRECTORY}/evidence/r19-source-gates.log" \
    "43e9d2eb00c0a63d5071b0c17f2cdc4c5809530788e893b4ffb0381e60e1aff8" "${R21_R19_HASH_LOG}" \
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "${R21_TASK_DIRECTORY}/evidence/r19-preview-bootstrap.log" \
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "${R21_TASK_DIRECTORY}/evidence/r19-preview-cold-start.log"
}

r21_require_exact_r19_root_set() {
  local -a r21_r19_root_pipeline_status
  if /usr/bin/find -P /private/tmp \
      -mindepth 1 -maxdepth 1 \
      \( \
        -name 'agentloop-r19-state.*' -o \
        -name 'agentloop-r19-bundle.*' \
      \) \
      -print0 2>/dev/null |
    /bin/bash --noprofile --norc -c '
      set -uo pipefail
      IFS=$'"'"' \t\n'"'"'
      set +H
      if ! shopt -u nocasematch; then
        exit 2
      fi
      expected_state="$1"
      expected_bundle="$2"
      seen_state=0
      seen_bundle=0
      actual_count=0
      valid=true
      actual_path=""
      read_rc=1
      partial_final_record=0
      while :; do
        actual_path=""
        if IFS= read -r -d "" actual_path; then
          if (( actual_count < 3 )); then
            actual_count=$((actual_count + 1))
          fi
          if [[ "${actual_path}" == "${expected_state}" ]]; then
            seen_state=$((seen_state + 1))
            if (( seen_state > 1 )); then
              valid=false
            fi
          elif [[ "${actual_path}" == "${expected_bundle}" ]]; then
            seen_bundle=$((seen_bundle + 1))
            if (( seen_bundle > 1 )); then
              valid=false
            fi
          else
            valid=false
          fi
        else
          read_rc="$?"
          if [[ -n "${actual_path}" ]]; then
            partial_final_record=1
            valid=false
          fi
          break
        fi
      done
      if [[ "${read_rc}" -ne 1 ||
            "${partial_final_record}" -ne 0 ||
            "${valid}" != "true" ||
            "${actual_count}" -ne 2 ||
            "${seen_state}" -ne 1 ||
            "${seen_bundle}" -ne 1 ]]; then
        exit 1
      fi
    ' -- "${R21_R19_STATE_ROOT}" "${R21_R19_BUNDLE_PARENT}"; then
    r21_r19_root_pipeline_status=( "${PIPESTATUS[@]}" )
  else
    r21_r19_root_pipeline_status=( "${PIPESTATUS[@]}" )
  fi
  if [[ "${#r21_r19_root_pipeline_status[@]}" -ne 2 ||
        "${r21_r19_root_pipeline_status[0]}" -ne 0 ||
        "${r21_r19_root_pipeline_status[1]}" -ne 0 ]]; then
    r21_attestation_fail 70 \
      "R19 retained root exact-set verification failed with find_rc=${r21_r19_root_pipeline_status[0]:-MISSING} validator_rc=${r21_r19_root_pipeline_status[1]:-MISSING}"
  fi
}

r21_require_r19_containment() {
  local r21_verification_mode="$1"
  local -a r21_r19_artifact_status
  local -a r21_r19_artifacts=(
    "${R21_R19_TARGETED_LOG}"
    "${R21_R19_VERIFY_LOG}"
    "${R21_TASK_DIRECTORY}/r19-build.log"
    "${R21_TASK_DIRECTORY}/r19-migration-matrix.log"
    "${R21_R19_REPORT}"
    "${R21_R19_BOUNDARY_LOG}"
    "${R21_TASK_DIRECTORY}/evidence/r19-bundle-provenance.log"
    "${R21_TASK_DIRECTORY}/evidence/r19-source-gates.log"
    "${R21_R19_HASH_LOG}"
    "${R21_TASK_DIRECTORY}/evidence/r19-preview-bootstrap.log"
    "${R21_TASK_DIRECTORY}/evidence/r19-preview-cold-start.log"
  )
  local r21_r19_artifact
  local r21_r19_root
  local r21_r19_root_realpath
  local r21_r19_root_realpath_rc
  local r21_r19_empty_rc
  local r21_r19_required_line

  case "${r21_verification_mode}" in
    pre_begin)
      if r21_authorization_is_consumed; then
        r21_attestation_fail 70 "pre_begin_r19_containment_after_authorization_consumption"
      fi
      ;;
    post_activation)
      if ! r21_authorization_is_consumed; then
        r21_pre_begin_fail 70 "post_activation_r19_containment_before_authorization_consumption"
      fi
      ;;
    *)
      r21_attestation_fail 64 "invalid R19 containment verification mode: ${r21_verification_mode}"
      ;;
  esac

  for r21_r19_artifact in "${r21_r19_artifacts[@]}"; do
    if [[ ! -f "${r21_r19_artifact}" || -L "${r21_r19_artifact}" ]]; then
      r21_attestation_fail 70 "R19 artifact is missing, non-regular, or a symlink"
    fi
  done

  if r21_emit_r19_artifact_manifest |
    /usr/bin/shasum -a 256 --strict -c - >/dev/null; then
    r21_r19_artifact_status=( "${PIPESTATUS[@]}" )
  else
    r21_r19_artifact_status=( "${PIPESTATUS[@]}" )
  fi
  if [[ "${#r21_r19_artifact_status[@]}" -ne 2 ||
        "${r21_r19_artifact_status[0]}" -ne 0 ||
        "${r21_r19_artifact_status[1]}" -ne 0 ]]; then
    r21_attestation_fail 70 "R19 immutable artifact verification failed"
  fi

  r21_require_exact_r19_root_set

  for r21_r19_root in "${R21_R19_STATE_ROOT}" "${R21_R19_BUNDLE_PARENT}"; do
    if [[ ! -d "${r21_r19_root}" || -L "${r21_r19_root}" ]]; then
      r21_attestation_fail 70 "R19 retained root is missing, non-directory, or a symlink"
    fi
    if r21_r19_root_realpath="$(
      trap - ERR
      /bin/realpath "${r21_r19_root}" 2>&1
    )"; then
      r21_r19_root_realpath_rc=0
    else
      r21_r19_root_realpath_rc="$?"
    fi
    if [[ "${r21_r19_root_realpath_rc}" -ne 0 ||
          "${r21_r19_root_realpath}" != "${r21_r19_root}" ]]; then
      r21_attestation_fail 70 "R19 retained root realpath verification failed"
    fi
    if r21_probe_empty_directory "${r21_r19_root}"; then
      r21_r19_empty_rc=0
    else
      r21_r19_empty_rc="$?"
    fi
    case "${r21_r19_empty_rc}" in
      0)
        ;;
      1)
        r21_attestation_fail 70 "R19 retained root is not empty"
        ;;
      *)
        r21_attestation_fail 70 "R19 retained root emptiness was indeterminate"
        ;;
    esac
  done

  if [[ "${R21_R19_STATE_ROOT}" == "${R21_R19_BUNDLE_PARENT}" ]]; then
    r21_attestation_fail 70 "R19 retained roots are not distinct"
  fi
  if [[ -e "${R21_R19_PLANNED_APP}" || -L "${R21_R19_PLANNED_APP}" ]]; then
    r21_attestation_fail 70 "R19 planned App must remain absent"
  fi
  if [[ -e "${R21_R19_SCREENSHOT}" || -L "${R21_R19_SCREENSHOT}" ]]; then
    r21_attestation_fail 70 "R19 screenshot must remain absent"
  fi

  for r21_r19_required_line in \
    "boundary=R19_CLEAN_REVERIFICATION" \
    "invocation_id=${R21_R19_INVOCATION_ID}" \
    "authorization_consumed=true" \
    "status=REJECTED_CONTAMINATED" \
    "phase=full_tests" \
    "reason=swift_run_full_failed" \
    "state_root=${R21_R19_STATE_ROOT}" \
    "bundle_parent=${R21_R19_BUNDLE_PARENT}" \
    "containment_state_root_empty=true" \
    "containment_bundle_parent_empty=true" \
    "containment_app_absent=true" \
    "verdict_remains=REJECTED_CONTAMINATED" \
    "retry_same_boundary=false"; do
    if ! /usr/bin/grep -Fx -- "${r21_r19_required_line}" "${R21_R19_BOUNDARY_LOG}" >/dev/null 2>&1; then
      r21_attestation_fail 70 "R19 immutable boundary fact is missing"
    fi
  done

  if [[ "${r21_verification_mode}" == "post_activation" ]]; then
    /usr/bin/printf '%s\n' \
      "section=r19_containment" \
      "phase=post_activation" \
      "r19_invocation_id=${R21_R19_INVOCATION_ID}" \
      "r19_verdict=REJECTED_CONTAMINATED" \
      "r19_artifact_count=11" \
      "r19_artifacts_immutable=true" \
      "r19_root_glob_exact_count=2" \
      "r19_state_root=${R21_R19_STATE_ROOT}" \
      "r19_bundle_parent=${R21_R19_BUNDLE_PARENT}" \
      "r19_state_root_real_empty=true" \
      "r19_bundle_parent_real_empty=true" \
      "r19_planned_app_absent=true" \
      "r19_screenshot_absent=true" \
      "r19_retry_same_boundary=false" >> "${R21_HASH_LOG}"
  fi
}

r21_require_exact_r20_root_set() {
  local -a r21_r20_root_pipeline_status
  if /usr/bin/find -P /private/tmp \
      -mindepth 1 -maxdepth 1 \
      \( \
        -name 'agentloop-r20-state.*' -o \
        -name 'agentloop-r20-bundle.*' \
      \) \
      -print0 2>/dev/null |
    /bin/bash --noprofile --norc -c '
      set -uo pipefail
      IFS=$'"'"' \t\n'"'"'
      set +H
      if ! shopt -u nocasematch; then
        exit 2
      fi
      expected_state="$1"
      expected_bundle="$2"
      seen_state=0
      seen_bundle=0
      actual_count=0
      valid=true
      actual_path=""
      read_rc=1
      partial_final_record=0
      while :; do
        actual_path=""
        if IFS= read -r -d "" actual_path; then
          if (( actual_count < 3 )); then
            actual_count=$((actual_count + 1))
          else
            valid=false
          fi
          if [[ "${actual_path}" == "${expected_state}" ]]; then
            seen_state=$((seen_state + 1))
          elif [[ "${actual_path}" == "${expected_bundle}" ]]; then
            seen_bundle=$((seen_bundle + 1))
          else
            valid=false
          fi
          if (( seen_state > 1 || seen_bundle > 1 )); then
            valid=false
          fi
        else
          read_rc="$?"
          if [[ -n "${actual_path}" ]]; then
            partial_final_record=1
            valid=false
          fi
          break
        fi
      done
      if [[ "${read_rc}" -ne 1 ||
            "${partial_final_record}" -ne 0 ||
            "${valid}" != "true" ||
            "${actual_count}" -ne 2 ||
            "${seen_state}" -ne 1 ||
            "${seen_bundle}" -ne 1 ]]; then
        exit 1
      fi
    ' -- "${R21_R20_STATE_ROOT}" "${R21_R20_BUNDLE_PARENT}"; then
    r21_r20_root_pipeline_status=( "${PIPESTATUS[@]}" )
  else
    r21_r20_root_pipeline_status=( "${PIPESTATUS[@]}" )
  fi
  if [[ "${#r21_r20_root_pipeline_status[@]}" -ne 2 ||
        "${r21_r20_root_pipeline_status[0]}" -ne 0 ||
        "${r21_r20_root_pipeline_status[1]}" -ne 0 ]]; then
    r21_attestation_fail 70 \
      "R20 retained root exact-set verification failed with find_rc=${r21_r20_root_pipeline_status[0]:-MISSING} validator_rc=${r21_r20_root_pipeline_status[1]:-MISSING}"
  fi
}

r21_require_exact_single_child() {
  local r21_directory="$1"
  local r21_expected_child="$2"
  local r21_label="$3"
  local -a r21_child_pipeline_status
  if /usr/bin/find -P "${r21_directory}" \
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
    ' -- "${r21_expected_child}"; then
    r21_child_pipeline_status=( "${PIPESTATUS[@]}" )
  else
    r21_child_pipeline_status=( "${PIPESTATUS[@]}" )
  fi
  if [[ "${#r21_child_pipeline_status[@]}" -ne 2 ||
        "${r21_child_pipeline_status[0]}" -ne 0 ||
        "${r21_child_pipeline_status[1]}" -ne 0 ]]; then
    r21_attestation_fail 70 \
      "${r21_label} exact-child verification failed with find_rc=${r21_child_pipeline_status[0]:-MISSING} validator_rc=${r21_child_pipeline_status[1]:-MISSING}"
  fi
}

r21_require_r20_containment() {
  local r21_verification_mode="$1"
  local -a r21_r20_artifacts=(
    "${R21_R20_TARGETED_LOG}"
    "${R21_R20_VERIFY_LOG}"
    "${R21_R20_BUILD_LOG}"
    "${R21_TASK_DIRECTORY}/r20-migration-matrix.log"
    "${R21_R20_REPORT}"
    "${R21_R20_BOUNDARY_LOG}"
    "${R21_TASK_DIRECTORY}/evidence/r20-bundle-provenance.log"
    "${R21_TASK_DIRECTORY}/evidence/r20-source-gates.log"
    "${R21_R20_HASH_LOG}"
    "${R21_TASK_DIRECTORY}/evidence/r20-preview-bootstrap.log"
    "${R21_TASK_DIRECTORY}/evidence/r20-preview-cold-start.log"
  )
  local r21_r20_artifact
  local r21_r20_root
  local r21_r20_root_realpath
  local r21_r20_root_realpath_rc
  local r21_r20_empty_rc
  local r21_r20_codesign_rc
  local r21_r20_required_line
  local -a r21_r20_bundle_manifest_status
  local -a r21_r20_expected_bundle_nodes=(
    "D"
    "Contents"
    "-"
    "F"
    "Contents/Info.plist"
    "${R21_R20_INFO_PLIST_SHA}"
    "D"
    "Contents/MacOS"
    "-"
    "F"
    "Contents/MacOS/AgentLoop"
    "${R21_R20_EXECUTABLE_SHA}"
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

  case "${r21_verification_mode}" in
    pre_begin)
      if r21_authorization_is_consumed; then
        r21_attestation_fail 70 "pre_begin_r20_containment_after_authorization_consumption"
      fi
      ;;
    post_activation)
      if ! r21_authorization_is_consumed; then
        r21_pre_begin_fail 70 "post_activation_r20_containment_before_authorization_consumption"
      fi
      ;;
    *)
      r21_attestation_fail 64 "invalid R20 containment verification mode: ${r21_verification_mode}"
      ;;
  esac

  for r21_r20_artifact in "${r21_r20_artifacts[@]}"; do
    if [[ ! -f "${r21_r20_artifact}" || -L "${r21_r20_artifact}" ]]; then
      r21_attestation_fail 70 "R20 artifact is missing, non-regular, or a symlink"
    fi
  done

  r21_require_exact_r20_root_set
  for r21_r20_root in "${R21_R20_STATE_ROOT}" "${R21_R20_BUNDLE_PARENT}"; do
    if [[ ! -d "${r21_r20_root}" || -L "${r21_r20_root}" ]]; then
      r21_attestation_fail 70 "R20 retained root is missing, non-directory, or a symlink"
    fi
    if r21_r20_root_realpath="$(
      trap - ERR
      /bin/realpath "${r21_r20_root}" 2>&1
    )"; then
      r21_r20_root_realpath_rc=0
    else
      r21_r20_root_realpath_rc="$?"
    fi
    if [[ "${r21_r20_root_realpath_rc}" -ne 0 ||
          "${r21_r20_root_realpath}" != "${r21_r20_root}" ]]; then
      r21_attestation_fail 70 "R20 retained root realpath verification failed"
    fi
  done
  if r21_probe_empty_directory "${R21_R20_STATE_ROOT}"; then
    r21_r20_empty_rc=0
  else
    r21_r20_empty_rc="$?"
  fi
  case "${r21_r20_empty_rc}" in
    0)
      ;;
    1)
      r21_attestation_fail 70 "R20 retained state root is not empty"
      ;;
    *)
      r21_attestation_fail 70 "R20 retained state root emptiness was indeterminate"
      ;;
  esac

  r21_require_exact_single_child \
    "${R21_R20_BUNDLE_PARENT}" "${R21_R20_APP}" "R20 bundle parent"
  if [[ ! -d "${R21_R20_APP}" || -L "${R21_R20_APP}" ||
        ! -f "${R21_R20_EXECUTABLE}" || -L "${R21_R20_EXECUTABLE}" ||
        ! -f "${R21_R20_INFO_PLIST}" || -L "${R21_R20_INFO_PLIST}" ]]; then
    r21_attestation_fail 70 "R20 signed App, executable, or Info.plist type drifted"
  fi
  if /usr/bin/find -P "${R21_R20_APP}" -mindepth 1 -print0 2>/dev/null |
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
    ' -- "${R21_R20_APP}" "${r21_r20_expected_bundle_nodes[@]}" |
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
    ' -- "${R21_R20_SIGNED_BUNDLE_MANIFEST_SHA}"; then
    r21_r20_bundle_manifest_status=( "${PIPESTATUS[@]}" )
  else
    r21_r20_bundle_manifest_status=( "${PIPESTATUS[@]}" )
  fi
  if [[ "${#r21_r20_bundle_manifest_status[@]}" -ne 4 ||
        "${r21_r20_bundle_manifest_status[0]}" -ne 0 ||
        "${r21_r20_bundle_manifest_status[1]}" -ne 0 ||
        "${r21_r20_bundle_manifest_status[2]}" -ne 0 ||
        "${r21_r20_bundle_manifest_status[3]}" -ne 0 ]]; then
    r21_attestation_fail 70 \
      "R20_signed_App_all_node_manifest_failed_find_${r21_r20_bundle_manifest_status[0]:-MISSING}_validator_${r21_r20_bundle_manifest_status[1]:-MISSING}_shasum_${r21_r20_bundle_manifest_status[2]:-MISSING}_hash_validator_${r21_r20_bundle_manifest_status[3]:-MISSING}"
  fi
  if /usr/bin/codesign --verify --deep --strict "${R21_R20_APP}" >/dev/null 2>&1; then
    r21_r20_codesign_rc=0
  else
    r21_r20_codesign_rc="$?"
  fi
  if [[ "${r21_r20_codesign_rc}" -ne 0 ]]; then
    r21_attestation_fail 70 "R20 signed App verification failed with rc=${r21_r20_codesign_rc}"
  fi
  if [[ -e "${R21_R20_SCREENSHOT}" || -L "${R21_R20_SCREENSHOT}" ]]; then
    r21_attestation_fail 70 "R20 screenshot must remain absent"
  fi

  for r21_r20_required_line in \
    "boundary=R20_DETERMINISTIC_CLOCK_REPAIR" \
    "invocation_id=${R21_R20_INVOCATION_ID}" \
    "authorization_consumed=true" \
    "authoritative_test_invocation_count=1" \
    "authoritative_test_filter=none" \
    "authoritative_swift_rc=0" \
    "authoritative_tee_rc=0" \
    "targeted_required_name_count=46" \
    "launch_ready=true" \
    "executable_sha=${R21_R20_EXECUTABLE_SHA}" \
    "signed_bundle_manifest_sha=${R21_R20_SIGNED_BUNDLE_MANIFEST_SHA}" \
    "status=REJECTED_CONTAMINATED" \
    "phase=release_core_build" \
    "reason=release_AgentLoopCore_build_failed_rc_1" \
    "exit_code=1" \
    "state_root=${R21_R20_STATE_ROOT}" \
    "bundle_parent=${R21_R20_BUNDLE_PARENT}" \
    "retry_same_boundary=false"; do
    if ! /usr/bin/grep -Fx -- "${r21_r20_required_line}" "${R21_R20_BOUNDARY_LOG}" >/dev/null 2>&1; then
      r21_attestation_fail 70 "R20 immutable boundary fact is missing"
    fi
  done

  if [[ "${r21_verification_mode}" == "post_activation" ]]; then
    /usr/bin/printf '%s\n' \
      "section=r20_containment" \
      "phase=post_activation" \
      "r20_invocation_id=${R21_R20_INVOCATION_ID}" \
      "r20_verdict=REJECTED_CONTAMINATED" \
      "r20_failure_phase=release_core_build" \
      "r20_authoritative_full_tests=652_of_652_pass" \
      "r20_targeted_audit=46_of_46_pass" \
      "r20_launch_ready=true" \
      "r20_artifact_count=11" \
      "r20_artifacts_immutable_by_static_manifest=true" \
      "r20_root_glob_exact_count=2" \
      "r20_state_root=${R21_R20_STATE_ROOT}" \
      "r20_bundle_parent=${R21_R20_BUNDLE_PARENT}" \
      "r20_state_root_real_empty=true" \
      "r20_bundle_parent_exact_child=${R21_R20_APP}" \
      "r20_signed_app_verified=true" \
      "r20_signed_app_path_transport=find_print0_bash_read_d_nul_v1" \
      "r20_signed_app_all_node_count=36" \
      "r20_signed_app_directory_count=6" \
      "r20_signed_app_regular_file_count=30" \
      "r20_signed_bundle_manifest_recomputed=true" \
      "r20_executable_sha=${R21_R20_EXECUTABLE_SHA}" \
      "r20_info_plist_sha=${R21_R20_INFO_PLIST_SHA}" \
      "r20_signed_bundle_manifest_sha=${R21_R20_SIGNED_BUNDLE_MANIFEST_SHA}" \
      "r20_screenshot_absent=true" \
      "r20_retry_same_boundary=false" >> "${R21_HASH_LOG}"
  fi
}

r21_post_activation_anchor_check() {
  local -a r21_anchor_status
  {
    /usr/bin/printf '%s\n' "section=terminal_anchors"
    r21_emit_anchor_manifest
  } >> "${R21_HASH_LOG}"
  if r21_emit_anchor_manifest |
    /usr/bin/shasum -a 256 --strict -c - >> "${R21_HASH_LOG}" 2>&1; then
    r21_anchor_status=( "${PIPESTATUS[@]}" )
  else
    r21_anchor_status=( "${PIPESTATUS[@]}" )
  fi
  /usr/bin/printf 'terminal_anchor_producer_rc=%s\n' "${r21_anchor_status[0]}" >> "${R21_HASH_LOG}"
  /usr/bin/printf 'terminal_anchor_shasum_rc=%s\n' "${r21_anchor_status[1]}" >> "${R21_HASH_LOG}"
  if [[ "${r21_anchor_status[0]}" -ne 0 || "${r21_anchor_status[1]}" -ne 0 ]]; then
    r21_active_fail 65 "post_activation_terminal_anchor_failure_producer_${r21_anchor_status[0]}_shasum_${r21_anchor_status[1]}"
  fi
}

r21_post_activation_manifest_check() {
  local r21_manifest_rc
  local r21_manifest_count
  local r21_manifest_count_rc
  if r21_manifest_count="$(
    trap - ERR
    /usr/bin/awk 'END { print NR }' "${R21_MANIFEST_PATH}"
  )"; then
    r21_manifest_count_rc=0
  else
    r21_manifest_count_rc="$?"
  fi
  if [[ "${r21_manifest_count_rc}" -ne 0 ]]; then
    r21_active_fail 66 "post_activation_static_manifest_count_failed_rc_${r21_manifest_count_rc}"
  fi
  /usr/bin/printf '%s\n' "section=static_manifest" >> "${R21_HASH_LOG}"
  /usr/bin/printf 'static_manifest_expected_count=%s\n' "${R21_EXPECTED_MANIFEST_COUNT}" >> "${R21_HASH_LOG}"
  /usr/bin/printf 'static_manifest_actual_count=%s\n' "${r21_manifest_count}" >> "${R21_HASH_LOG}"
  if /usr/bin/shasum -a 256 --strict -c "${R21_MANIFEST_PATH}" >> "${R21_HASH_LOG}" 2>&1; then
    r21_manifest_rc=0
  else
    r21_manifest_rc="$?"
  fi
  /usr/bin/printf 'static_manifest_rc=%s\n' "${r21_manifest_rc}" >> "${R21_HASH_LOG}"
  if [[ "${r21_manifest_rc}" -ne 0 ]]; then
    r21_active_fail 66 "post_activation_static_manifest_failure_rc_${r21_manifest_rc}"
  fi
  if [[ "${r21_manifest_count}" != "${R21_EXPECTED_MANIFEST_COUNT}" ]]; then
    r21_active_fail 66 "post_activation_static_manifest_count_${r21_manifest_count}"
  fi
}

r21_check_ranch_art_structure() {
  local r21_verification_mode="$1"
  local r21_evidence_sink
  local r21_evidence_phase
  local -a r21_expected_basenames=(
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
  local -a r21_ranch_pipeline_status

  case "${r21_verification_mode}" in
    pre_begin)
      if r21_authorization_is_consumed; then
        r21_attestation_fail 70 "pre_begin_ranch_art_check_after_authorization_consumption"
      fi
      r21_evidence_sink="/dev/stderr"
      r21_evidence_phase="pre_consumption"
      ;;
    post_activation)
      if ! r21_authorization_is_consumed; then
        r21_pre_begin_fail 70 "post_activation_ranch_art_check_before_authorization_consumption"
      fi
      if [[ ! -f "${R21_HASH_LOG}" || -L "${R21_HASH_LOG}" ]]; then
        r21_active_fail 70 "post_activation_ranch_art_hash_log_invalid"
      fi
      r21_evidence_sink="${R21_HASH_LOG}"
      r21_evidence_phase="post_activation"
      ;;
    *)
      r21_attestation_fail 64 "invalid RanchArt verification mode: ${r21_verification_mode}"
      ;;
  esac

  # Hide raw pathname diagnostics while retaining both numeric pipeline statuses
  # in the fixed fail-closed reason below.
  if /usr/bin/find -P "${R21_RANCH_ART_DIRECTORY}" \
      -mindepth 1 -maxdepth 1 -print0 2>/dev/null |
    /bin/bash -c '
      set +x
      set +v
      set -u
      set -f
      LC_ALL=C
      export LC_ALL
      shopt -u nocasematch

      r21_directory="$1"
      shift
      r21_expected_count="$#"
      r21_invalid=0
      r21_partial_final_record=0
      r21_read_rc=1
      r21_total_count=0
      r21_regular_count=0
      r21_nonregular_count=0
      r21_symlink_count=0
      r21_index=0
      r21_other_index=0
      r21_path=""
      r21_basename=""
      r21_prefix="${r21_directory}/"
      r21_expected_value=""
      r21_other_expected_value=""
      r21_seen=()

      if [[ "${r21_expected_count}" -ne 27 ]]; then
        r21_invalid=1
      fi
      if [[ ! -d "${r21_directory}" || -L "${r21_directory}" ]]; then
        r21_invalid=1
      fi

      r21_index=0
      for r21_expected_value in "$@"; do
        r21_seen[r21_index]=0
        if [[ -z "${r21_expected_value}" || "${r21_expected_value}" == */* ]]; then
          r21_invalid=1
        fi
        case "${r21_expected_value}" in
          *[!A-Za-z0-9.]* )
            r21_invalid=1
            ;;
        esac
        r21_other_index=0
        for r21_other_expected_value in "$@"; do
          if [[ "${r21_index}" -ne "${r21_other_index}" &&
                "${r21_expected_value}" == "${r21_other_expected_value}" ]]; then
            r21_invalid=1
          fi
          r21_other_index=$(( r21_other_index + 1 ))
        done
        r21_index=$(( r21_index + 1 ))
      done

      while :; do
        r21_path=""
        if IFS= read -r -d "" r21_path; then
          if [[ "${r21_total_count}" -lt 28 ]]; then
            r21_total_count=$(( r21_total_count + 1 ))
          else
            r21_invalid=1
          fi

          r21_record_regular=0
          if [[ -f "${r21_path}" && ! -L "${r21_path}" ]]; then
            r21_record_regular=1
            if [[ "${r21_regular_count}" -lt 28 ]]; then
              r21_regular_count=$(( r21_regular_count + 1 ))
            else
              r21_invalid=1
            fi
          else
            if [[ "${r21_nonregular_count}" -lt 28 ]]; then
              r21_nonregular_count=$(( r21_nonregular_count + 1 ))
            else
              r21_invalid=1
            fi
          fi
          if [[ -L "${r21_path}" ]]; then
            if [[ "${r21_symlink_count}" -lt 28 ]]; then
              r21_symlink_count=$(( r21_symlink_count + 1 ))
            else
              r21_invalid=1
            fi
          fi

          r21_record_matched=0
          if [[ "${r21_path}" == "${r21_prefix}"* ]]; then
            r21_basename="${r21_path#"${r21_prefix}"}"
            if [[ -n "${r21_basename}" && "${r21_basename}" != */* ]]; then
              r21_index=0
              for r21_expected_value in "$@"; do
                if [[ "${r21_basename}" == "${r21_expected_value}" ]]; then
                  r21_record_matched=1
                  if [[ "${r21_seen[r21_index]}" -eq 0 ]]; then
                    r21_seen[r21_index]=1
                  else
                    r21_invalid=1
                  fi
                  break
                fi
                r21_index=$(( r21_index + 1 ))
              done
            fi
          fi
          if [[ "${r21_record_regular}" -ne 1 || "${r21_record_matched}" -ne 1 ]]; then
            r21_invalid=1
          fi
        else
          r21_read_rc="$?"
          if [[ -n "${r21_path}" ]]; then
            r21_partial_final_record=1
            r21_invalid=1
          fi
          break
        fi
      done

      if [[ "${r21_read_rc}" -ne 1 ||
            "${r21_partial_final_record}" -ne 0 ||
            "${r21_total_count}" -ne 27 ||
            "${r21_regular_count}" -ne 27 ||
            "${r21_nonregular_count}" -ne 0 ||
            "${r21_symlink_count}" -ne 0 ||
            ! -d "${r21_directory}" || -L "${r21_directory}" ]]; then
        r21_invalid=1
      fi
      r21_index=0
      for r21_expected_value in "$@"; do
        if [[ "${r21_seen[r21_index]}" -ne 1 ]]; then
          r21_invalid=1
        fi
        r21_index=$(( r21_index + 1 ))
      done

      if [[ "${r21_invalid}" -ne 0 ]]; then
        exit 1
      fi
      exit 0
    ' "r21-ranch-art-nul-validator-v1" \
      "${R21_RANCH_ART_DIRECTORY}" "${r21_expected_basenames[@]}"; then
    r21_ranch_pipeline_status=( "${PIPESTATUS[@]}" )
  else
    r21_ranch_pipeline_status=( "${PIPESTATUS[@]}" )
  fi

  if [[ "${#r21_ranch_pipeline_status[@]}" -ne 2 ]]; then
    r21_attestation_fail 70 "ranch_art_pipeline_status_shape_invalid"
  fi
  if [[ "${r21_ranch_pipeline_status[0]}" -ne 0 ||
        "${r21_ranch_pipeline_status[1]}" -ne 0 ]]; then
    r21_attestation_fail 70 \
      "ranch_art_nul_validation_failed_find_${r21_ranch_pipeline_status[0]}_validator_${r21_ranch_pipeline_status[1]}"
  fi

  /usr/bin/printf '%s\n' "section=ranch_art_structure" >> "${r21_evidence_sink}"
  /usr/bin/printf 'phase=%s\n' "${r21_evidence_phase}" >> "${r21_evidence_sink}"
  /usr/bin/printf 'ranch_art_verification_mode=%s\n' \
    "${r21_verification_mode}" >> "${r21_evidence_sink}"
  /usr/bin/printf '%s\n' \
    "pathname_transport=find_print0_bash_read_d_nul_v1" \
    "ranch_art_find_rc=${r21_ranch_pipeline_status[0]}" \
    "ranch_art_validator_rc=${r21_ranch_pipeline_status[1]}" \
    "ranch_art_expected_count=27" \
    "ranch_art_parent_type=directory_non_symlink" \
    "ranch_art_node_type=regular_non_symlink" \
    "ranch_art_actual_count=27" \
    "ranch_art_exact_relative_path_set_begin" >> "${r21_evidence_sink}"
  /usr/bin/printf '%s\n' "${r21_expected_basenames[@]}" >> "${r21_evidence_sink}"
  /usr/bin/printf '%s\n' \
    "ranch_art_exact_relative_path_set_end" \
    "nonregular_count=0" \
    "symlink_count=0" \
    "regular_count=27" >> "${r21_evidence_sink}"
}

if [[ "$#" -ne 4 ]]; then
  r21_pre_begin_fail 64 "expected four SHA-256 arguments: freeze Review21 driver manifest"
fi

readonly R21_EXPECTED_FREEZE_SHA="$1"
readonly R21_EXPECTED_REVIEW21_SHA="$2"
readonly R21_EXPECTED_DRIVER_SHA="$3"
readonly R21_EXPECTED_MANIFEST_SHA="$4"

r21_require_lowercase_sha256 "${R21_EXPECTED_FREEZE_SHA}" "freeze hash"
r21_require_lowercase_sha256 "${R21_EXPECTED_REVIEW21_SHA}" "Review21 hash"
r21_require_lowercase_sha256 "${R21_EXPECTED_DRIVER_SHA}" "driver hash"
r21_require_lowercase_sha256 "${R21_EXPECTED_MANIFEST_SHA}" "manifest hash"

if [[ "$0" != "${R21_DRIVER_PATH}" ]]; then
  r21_pre_begin_fail 64 "driver must be invoked by its frozen absolute path"
fi
if [[ "${BASH_SOURCE[0]}" != "${R21_DRIVER_PATH}" ||
      ! -f "${R21_DRIVER_PATH}" ||
      -L "${R21_DRIVER_PATH}" ||
      "$(/bin/realpath "${R21_DRIVER_PATH}")" != "${R21_DRIVER_PATH}" ]]; then
  r21_pre_begin_fail 64 "driver source path or file type is not canonical"
fi
if (( BASH_VERSINFO[0] < 3 ||
      (BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] < 2) )); then
  r21_pre_begin_fail 64 "Bash 3.2 or newer is required"
fi
if [[ "${LC_ALL:-}" != "C" || "${LANG:-}" != "C" ]]; then
  r21_pre_begin_fail 64 "LC_ALL and LANG must both equal C"
fi
if [[ "${PATH:-}" != "/usr/bin:/bin:/usr/sbin:/sbin" ]]; then
  r21_pre_begin_fail 64 "PATH is not the frozen clean value"
fi
if [[ "${TMPDIR:-}" != "/private/tmp" ]]; then
  r21_pre_begin_fail 64 "TMPDIR is not the frozen clean value"
fi
if [[ "${GIT_CONFIG_NOSYSTEM:-}" != "1" || "${GIT_CONFIG_GLOBAL:-}" != "/dev/null" ]]; then
  r21_pre_begin_fail 64 "Git clean-environment controls are missing"
fi
if [[ -n "${BASH_ENV+x}" || -n "${ENV+x}" || -n "${CDPATH+x}" ]]; then
  r21_pre_begin_fail 64 "shell startup or directory environment was inherited"
fi

R21_PHASE="pre_begin_terminal_anchors"
r21_check_anchors_to_stdout

R21_PHASE="pre_begin_manifest_shape"
r21_check_manifest_shape

R21_PHASE="pre_begin_static_manifest"
r21_check_manifest_to_stdout

R21_PHASE="pre_begin_repository_identity"
R21_ACTUAL_BRANCH="$(/usr/bin/git -C "${R21_REPOSITORY_ROOT}" symbolic-ref --quiet --short HEAD)"
R21_ACTUAL_HEAD="$(/usr/bin/git -C "${R21_REPOSITORY_ROOT}" rev-parse --verify HEAD)"
if [[ "${R21_ACTUAL_BRANCH}" != "${R21_EXPECTED_BRANCH}" ]]; then
  r21_pre_begin_fail 67 "branch is ${R21_ACTUAL_BRANCH}, expected ${R21_EXPECTED_BRANCH}"
fi
if [[ "${R21_ACTUAL_HEAD}" != "${R21_EXPECTED_HEAD}" ]]; then
  r21_pre_begin_fail 67 "HEAD is ${R21_ACTUAL_HEAD}, expected ${R21_EXPECTED_HEAD}"
fi

R21_PHASE="pre_begin_r16_preservation"
R21_R16_RUNTIME_PATHS=(
  "${R21_TASK_DIRECTORY}/r16-targeted-tests.log"
  "${R21_TASK_DIRECTORY}/r16-verify.log"
  "${R21_TASK_DIRECTORY}/r16-build.log"
  "${R21_TASK_DIRECTORY}/r16-migration-matrix.log"
  "${R21_TASK_DIRECTORY}/impl-report-r16.md"
  "${R21_TASK_DIRECTORY}/evidence/r16-clean-boundary.log"
  "${R21_TASK_DIRECTORY}/evidence/r16-bundle-provenance.log"
  "${R21_TASK_DIRECTORY}/evidence/r16-source-gates.log"
  "${R21_TASK_DIRECTORY}/evidence/r16-hash-manifest.log"
  "${R21_TASK_DIRECTORY}/evidence/r16-preview-bootstrap.log"
  "${R21_TASK_DIRECTORY}/evidence/r16-preview-cold-start.log"
  "${R21_TASK_DIRECTORY}/evidence/r16-preview-smoke.png"
)
for R21_R16_RUNTIME_PATH in "${R21_R16_RUNTIME_PATHS[@]}"; do
  r21_require_absent_path "${R21_R16_RUNTIME_PATH}"
done

R21_PHASE="pre_begin_r17_preservation"
R21_R17_RUNTIME_PATHS=(
  "${R21_TASK_DIRECTORY}/r17-targeted-tests.log"
  "${R21_TASK_DIRECTORY}/r17-verify.log"
  "${R21_TASK_DIRECTORY}/r17-build.log"
  "${R21_TASK_DIRECTORY}/r17-migration-matrix.log"
  "${R21_TASK_DIRECTORY}/impl-report-r17.md"
  "${R21_TASK_DIRECTORY}/evidence/r17-clean-boundary.log"
  "${R21_TASK_DIRECTORY}/evidence/r17-bundle-provenance.log"
  "${R21_TASK_DIRECTORY}/evidence/r17-source-gates.log"
  "${R21_TASK_DIRECTORY}/evidence/r17-hash-manifest.log"
  "${R21_TASK_DIRECTORY}/evidence/r17-preview-bootstrap.log"
  "${R21_TASK_DIRECTORY}/evidence/r17-preview-cold-start.log"
  "${R21_TASK_DIRECTORY}/evidence/r17-preview-smoke.png"
)
for R21_R17_RUNTIME_PATH in "${R21_R17_RUNTIME_PATHS[@]}"; do
  r21_require_absent_path "${R21_R17_RUNTIME_PATH}"
done

R21_PHASE="pre_begin_r18_preservation"
R21_R18_RUNTIME_PATHS=(
  "${R21_TASK_DIRECTORY}/r18-targeted-tests.log"
  "${R21_TASK_DIRECTORY}/r18-verify.log"
  "${R21_TASK_DIRECTORY}/r18-build.log"
  "${R21_TASK_DIRECTORY}/r18-migration-matrix.log"
  "${R21_TASK_DIRECTORY}/impl-report-r18.md"
  "${R21_TASK_DIRECTORY}/evidence/r18-clean-boundary.log"
  "${R21_TASK_DIRECTORY}/evidence/r18-bundle-provenance.log"
  "${R21_TASK_DIRECTORY}/evidence/r18-source-gates.log"
  "${R21_TASK_DIRECTORY}/evidence/r18-hash-manifest.log"
  "${R21_TASK_DIRECTORY}/evidence/r18-preview-bootstrap.log"
  "${R21_TASK_DIRECTORY}/evidence/r18-preview-cold-start.log"
  "${R21_TASK_DIRECTORY}/evidence/r18-preview-smoke.png"
)
for R21_R18_RUNTIME_PATH in "${R21_R18_RUNTIME_PATHS[@]}"; do
  r21_require_absent_path "${R21_R18_RUNTIME_PATH}"
done

R21_PHASE="pre_begin_r19_containment"
r21_require_r19_containment "pre_begin"

R21_PHASE="pre_begin_r20_containment"
r21_require_r20_containment "pre_begin"

r21_require_no_unconsumed_fresh_roots

R21_PHASE="pre_begin_runtime_paths"
R21_RUNTIME_PATHS=(
  "${R21_TASK_DIRECTORY}/r21-targeted-tests.log"
  "${R21_TASK_DIRECTORY}/r21-verify.log"
  "${R21_TASK_DIRECTORY}/r21-build.log"
  "${R21_TASK_DIRECTORY}/r21-migration-matrix.log"
  "${R21_TASK_DIRECTORY}/impl-report-r21.md"
  "${R21_TASK_DIRECTORY}/evidence/r21-clean-boundary.log"
  "${R21_TASK_DIRECTORY}/evidence/r21-bundle-provenance.log"
  "${R21_TASK_DIRECTORY}/evidence/r21-source-gates.log"
  "${R21_TASK_DIRECTORY}/evidence/r21-hash-manifest.log"
  "${R21_TASK_DIRECTORY}/evidence/r21-preview-bootstrap.log"
  "${R21_TASK_DIRECTORY}/evidence/r21-preview-cold-start.log"
  "${R21_TASK_DIRECTORY}/evidence/r21-preview-smoke.png"
)
for R21_RUNTIME_PATH in "${R21_RUNTIME_PATHS[@]}"; do
  r21_require_absent_path "${R21_RUNTIME_PATH}"
done

R21_PHASE="pre_begin_processes"
r21_require_process_absent "AgentLoop"
r21_require_process_absent "AgentLoopApp"

R21_PHASE="pre_begin_r15_tombstone_absence"
r21_require_r15_tombstones_absent
if [[ -e "${R21_R15_PLANNED_APP}" || -L "${R21_R15_PLANNED_APP}" ]]; then
  r21_pre_begin_fail 70 "R15 planned App must remain absent"
fi
if [[ -e "${R21_R15_SCREENSHOT}" || -L "${R21_R15_SCREENSHOT}" ]]; then
  r21_pre_begin_fail 70 "R15 screenshot must remain absent"
fi

R21_PHASE="pre_begin_activation_metadata"
R21_INVOCATION_ID="r21-$(
  /usr/bin/uuidgen |
    /usr/bin/tr '[:upper:]' '[:lower:]'
)"
if [[ ! "${R21_INVOCATION_ID}" =~ ^r21-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
  r21_pre_begin_fail 71 "generated R21 invocation ID has invalid format"
fi
R21_BEGIN_UTC="$(r21_utc_now)"
if [[ ! "${R21_BEGIN_UTC}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
  r21_pre_begin_fail 71 "generated R21 begin UTC has invalid format"
fi

R21_PHASE="pre_begin_ranch_art_structure"
r21_check_ranch_art_structure "pre_begin"

if ! (
  set -C
  /usr/bin/printf '%s\n' \
    "boundary=R21_RELEASE_CONFIGURATION_REPAIR" \
    "invocation_id=${R21_INVOCATION_ID}" \
    "utc_begin=${R21_BEGIN_UTC}" \
    "authorization_consumed=true" \
    "status=BEGIN_STARTED" \
    "branch=${R21_ACTUAL_BRANCH}" \
    "head=${R21_ACTUAL_HEAD}" \
    "r15_state_root_pre_begin_observed_state=ABSENT" \
    "r15_bundle_parent_pre_begin_observed_state=ABSENT" \
    "r15_state_root_current_absent=true" \
    "r15_bundle_parent_current_absent=true" \
    "r15_absence_proof_identity=${R21_R15_ABSENCE_PROOF_IDENTITY}" \
    "disappearance_cause=UNKNOWN" \
    "pre_begin_ranch_art_structure=true" \
    "recipe=r21-dev-bundle-v1" \
    "normal_root=/Users/muzi/Library/Application Support/AgentLoop" \
    "normal_root_access_policy=lsof_path_comparison_only" \
    "r19_invocation_id=${R21_R19_INVOCATION_ID}" \
    "r19_verdict=REJECTED_CONTAMINATED" \
    "r19_artifact_count=11" \
    "r19_state_root=${R21_R19_STATE_ROOT}" \
    "r19_bundle_parent=${R21_R19_BUNDLE_PARENT}" \
    "r19_roots_real_empty=true" \
    "r19_retry_same_boundary=false" \
    "r20_invocation_id=${R21_R20_INVOCATION_ID}" \
    "r20_verdict=REJECTED_CONTAMINATED" \
    "r20_failure_phase=release_core_build" \
    "r20_authoritative_full_tests=652_of_652_pass" \
    "r20_targeted_audit=46_of_46_pass" \
    "r20_launch_ready=true" \
    "r20_artifact_count=11" \
    "r20_state_root=${R21_R20_STATE_ROOT}" \
    "r20_bundle_parent=${R21_R20_BUNDLE_PARENT}" \
    "r20_state_root_real_empty=true" \
    "r20_bundle_parent_exact_child=${R21_R20_APP}" \
    "r20_retry_same_boundary=false" \
    "implementation_entry_baseline_count=2" \
    "implementation_allowed_final_delta_count=1" \
    "implementation_final_delta_policy=exact_test_path_only_relative_to_entry_manifest" \
    "implementation_core_path=${R21_IMPLEMENTATION_CORE_PATH}" \
    "implementation_test_path=${R21_IMPLEMENTATION_TEST_PATH}" \
    "implementation_core_required_sha=${R21_R20_CORE_FINAL_SHA}" \
    "implementation_test_entry_sha=${R21_R20_TEST_FINAL_SHA}" \
    "implementation_test_delta=three_matching_debug_guard_pairs_only" \
    "authoritative_test_command=swift_run_RunTests_unfiltered_once" \
    "test_filter_forbidden=true" \
    "targeted_evidence_source=mechanical_46_name_extraction_from_authoritative_log" \
    "freeze_sha=${R21_EXPECTED_FREEZE_SHA}" \
    "review21_sha=${R21_EXPECTED_REVIEW21_SHA}" \
    "driver_sha=${R21_EXPECTED_DRIVER_SHA}" \
    "manifest_sha=${R21_EXPECTED_MANIFEST_SHA}" \
    > "${R21_BOUNDARY_LOG}"
); then
  R21_PHASE="activation_boundary"
  r21_attestation_fail 71 "could not exclusive-create and initialize R21 boundary log"
fi
R21_PHASE="activation_boundary"
R21_BOUNDARY_ACTIVE="true"

R21_PHASE="activation_hash_log"
if ! r21_exclusive_create_empty "${R21_HASH_LOG}"; then
  r21_active_fail 71 "exclusive_create_failed_${R21_HASH_LOG}" "exclusive_create"
fi

R21_PHASE="post_activation_ranch_art_structure"
r21_check_ranch_art_structure "post_activation"

R21_PHASE="post_activation_terminal_anchors"
r21_post_activation_anchor_check

R21_PHASE="post_activation_static_manifest"
r21_check_manifest_shape
r21_post_activation_manifest_check

R21_PHASE="post_activation_r19_containment"
r21_require_r19_containment "post_activation"

R21_PHASE="post_activation_r20_containment"
r21_require_r20_containment "post_activation"

/usr/bin/printf 'frozen_info_plist_sha=%s\n' "${R21_EXPECTED_INFO_PLIST_SHA}" >> "${R21_HASH_LOG}"
/usr/bin/printf 'frozen_ranch_art_manifest_sha=%s\n' "${R21_EXPECTED_RANCH_ART_MANIFEST_SHA}" >> "${R21_HASH_LOG}"
/usr/bin/printf '%s\n' "section=worktree_status" >> "${R21_HASH_LOG}"
/usr/bin/git --no-optional-locks -C "${R21_REPOSITORY_ROOT}" status --short --branch >> "${R21_HASH_LOG}"

R21_PHASE="activation_remaining_logs"
R21_REMAINING_TEXT_LOGS=(
  "${R21_TASK_DIRECTORY}/r21-targeted-tests.log"
  "${R21_TASK_DIRECTORY}/r21-verify.log"
  "${R21_TASK_DIRECTORY}/r21-build.log"
  "${R21_TASK_DIRECTORY}/r21-migration-matrix.log"
  "${R21_TASK_DIRECTORY}/evidence/r21-bundle-provenance.log"
  "${R21_TASK_DIRECTORY}/evidence/r21-source-gates.log"
  "${R21_TASK_DIRECTORY}/evidence/r21-preview-bootstrap.log"
  "${R21_TASK_DIRECTORY}/evidence/r21-preview-cold-start.log"
)
for R21_REMAINING_TEXT_LOG in "${R21_REMAINING_TEXT_LOGS[@]}"; do
  if ! r21_exclusive_create_empty "${R21_REMAINING_TEXT_LOG}"; then
    r21_active_fail 71 "exclusive_create_failed_${R21_REMAINING_TEXT_LOG}" "exclusive_create"
  fi
done

R21_PHASE="activation_fresh_roots"
R21_STATE_ROOT="$(/usr/bin/mktemp -d '/private/tmp/agentloop-r21-state.XXXXXX')"
R21_BUNDLE_PARENT="$(/usr/bin/mktemp -d '/private/tmp/agentloop-r21-bundle.XXXXXX')"
R21_PLANNED_APP="${R21_BUNDLE_PARENT}/AgentLoop.app"
R21_PLANNED_EXECUTABLE="${R21_PLANNED_APP}/Contents/MacOS/AgentLoop"

r21_require_fresh_root "${R21_STATE_ROOT}" "fresh_state_root"
r21_require_fresh_root "${R21_BUNDLE_PARENT}" "fresh_bundle_parent"
if [[ "${R21_STATE_ROOT}" == "${R21_BUNDLE_PARENT}" ]]; then
  r21_active_fail 72 "fresh_roots_equal"
fi
case "${R21_STATE_ROOT}/" in
  "${R21_BUNDLE_PARENT}/"* )
    r21_active_fail 72 "state_root_nested_in_bundle_parent"
    ;;
esac
case "${R21_BUNDLE_PARENT}/" in
  "${R21_STATE_ROOT}/"* )
    r21_active_fail 72 "bundle_parent_nested_in_state_root"
    ;;
esac
if [[ "${R21_STATE_ROOT}" == "${R21_R15_STATE_ROOT}" ||
      "${R21_STATE_ROOT}" == "${R21_R15_BUNDLE_PARENT}" ||
      "${R21_BUNDLE_PARENT}" == "${R21_R15_STATE_ROOT}" ||
      "${R21_BUNDLE_PARENT}" == "${R21_R15_BUNDLE_PARENT}" ||
      "${R21_STATE_ROOT}" == "${R21_R19_STATE_ROOT}" ||
      "${R21_STATE_ROOT}" == "${R21_R19_BUNDLE_PARENT}" ||
      "${R21_BUNDLE_PARENT}" == "${R21_R19_STATE_ROOT}" ||
      "${R21_BUNDLE_PARENT}" == "${R21_R19_BUNDLE_PARENT}" ||
      "${R21_STATE_ROOT}" == "${R21_R20_STATE_ROOT}" ||
      "${R21_STATE_ROOT}" == "${R21_R20_BUNDLE_PARENT}" ||
      "${R21_BUNDLE_PARENT}" == "${R21_R20_STATE_ROOT}" ||
      "${R21_BUNDLE_PARENT}" == "${R21_R20_BUNDLE_PARENT}" ]]; then
  r21_active_fail 72 "fresh_root_reuses_historical_root"
fi
if [[ -e "${R21_PLANNED_APP}" || -L "${R21_PLANNED_APP}" ]]; then
  r21_active_fail 72 "planned_app_preexists"
fi

r21_append_boundary "state_root=${R21_STATE_ROOT}"
r21_append_boundary "bundle_parent=${R21_BUNDLE_PARENT}"
r21_append_boundary "planned_app=${R21_PLANNED_APP}"
r21_append_boundary "planned_executable=${R21_PLANNED_EXECUTABLE}"
r21_append_boundary "final_executable_hash=DEFERRED_TO_LAUNCH_READY"
r21_append_boundary "process_count=0"
r21_append_boundary "r15_planned_app_absent=true"
r21_append_boundary "r15_screenshot_absent=true"
r21_append_boundary "r16_runtime_artifacts_absent=true"
r21_append_boundary "r16_fresh_roots_absent=true"
r21_append_boundary "r16_pre_begin_zero_write_preserved=true"
r21_append_boundary "r17_runtime_artifacts_absent=true"
r21_append_boundary "r17_fresh_roots_absent=true"
r21_append_boundary "r17_not_executed_preserved=true"
r21_append_boundary "r18_runtime_artifacts_absent=true"
r21_append_boundary "r18_fresh_roots_absent=true"
r21_append_boundary "r18_not_executed_preserved=true"
r21_append_boundary "r19_runtime_artifacts_immutable=true"
r21_append_boundary "r19_runtime_artifact_count=11"
r21_append_boundary "r19_boundary_rejected_contaminated=true"
r21_append_boundary "r19_state_root=${R21_R19_STATE_ROOT}"
r21_append_boundary "r19_bundle_parent=${R21_R19_BUNDLE_PARENT}"
r21_append_boundary "r19_state_root_real_empty=true"
r21_append_boundary "r19_bundle_parent_real_empty=true"
r21_append_boundary "r19_planned_app_absent=true"
r21_append_boundary "r19_screenshot_absent=true"
r21_append_boundary "r19_retry_same_boundary=false"
r21_append_boundary "r20_runtime_artifacts_immutable=true"
r21_append_boundary "r20_runtime_artifact_count=11"
r21_append_boundary "r20_boundary_rejected_contaminated=true"
r21_append_boundary "r20_failure_phase=release_core_build"
r21_append_boundary "r20_authoritative_full_tests=652_of_652_pass"
r21_append_boundary "r20_targeted_audit=46_of_46_pass"
r21_append_boundary "r20_launch_ready=true"
r21_append_boundary "r20_state_root=${R21_R20_STATE_ROOT}"
r21_append_boundary "r20_bundle_parent=${R21_R20_BUNDLE_PARENT}"
r21_append_boundary "r20_state_root_real_empty=true"
r21_append_boundary "r20_bundle_parent_exact_child=${R21_R20_APP}"
r21_append_boundary "r20_signed_app_verified=true"
r21_append_boundary "r20_signed_app_path_transport=find_print0_bash_read_d_nul_v1"
r21_append_boundary "r20_signed_app_all_node_count=36"
r21_append_boundary "r20_signed_app_directory_count=6"
r21_append_boundary "r20_signed_app_regular_file_count=30"
r21_append_boundary "r20_signed_bundle_manifest_recomputed=true"
r21_append_boundary "r20_executable_sha=${R21_R20_EXECUTABLE_SHA}"
r21_append_boundary "r20_info_plist_sha=${R21_R20_INFO_PLIST_SHA}"
r21_append_boundary "r20_signed_bundle_manifest_sha=${R21_R20_SIGNED_BUNDLE_MANIFEST_SHA}"
r21_append_boundary "r20_screenshot_absent=true"
r21_append_boundary "r20_retry_same_boundary=false"
r21_append_boundary "r21_pre_activation_fresh_roots_absent=true"
r21_append_boundary "frozen_info_plist_sha=${R21_EXPECTED_INFO_PLIST_SHA}"
r21_append_boundary "frozen_ranch_art_manifest_sha=${R21_EXPECTED_RANCH_ART_MANIFEST_SHA}"

R21_PHASE="begin_finalization"
r21_require_process_absent "AgentLoop"
r21_require_process_absent "AgentLoopApp"
r21_append_boundary "utc_begin_attested=$(r21_utc_now)"
r21_append_boundary "begin_attestation_complete=true"
r21_append_boundary "status=BEGIN_ATTESTED"
r21_append_boundary "retry_same_boundary=false"

/usr/bin/printf '%s\n' \
  "status=BEGIN_ATTESTED" \
  "invocation_id=${R21_INVOCATION_ID}" \
  "boundary_log=${R21_BOUNDARY_LOG}" \
  "hash_log=${R21_HASH_LOG}" \
  "state_root=${R21_STATE_ROOT}" \
  "bundle_parent=${R21_BUNDLE_PARENT}" \
  "planned_app=${R21_PLANNED_APP}" \
  "planned_executable=${R21_PLANNED_EXECUTABLE}"
