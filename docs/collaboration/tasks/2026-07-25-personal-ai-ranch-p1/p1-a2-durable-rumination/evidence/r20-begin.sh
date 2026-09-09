#!/bin/bash

# R20 BEGIN-only candidate driver.
# This file does not run tests, build, migration matrix, source gates, bundle
# assembly, signing, or preview. It establishes one fail-once evidence boundary.

set -Eeuo pipefail
set -f
IFS=$' \t\n'
umask 077

readonly R20_REPOSITORY_ROOT="/Users/muzi/Agent-loop"
readonly R20_TASK_DIRECTORY="${R20_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination"
readonly R20_DRIVER_PATH="${R20_TASK_DIRECTORY}/evidence/r20-begin.sh"
readonly R20_MANIFEST_PATH="${R20_TASK_DIRECTORY}/evidence/r20-entry.sha256"
readonly R20_FREEZE_PATH="${R20_TASK_DIRECTORY}/evidence/plan-freeze-r20.md"
readonly R20_REVIEW20_PATH="${R20_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/20-p1-plan-review.md"
readonly R20_BOUNDARY_LOG="${R20_TASK_DIRECTORY}/evidence/r20-clean-boundary.log"
readonly R20_HASH_LOG="${R20_TASK_DIRECTORY}/evidence/r20-hash-manifest.log"
readonly R20_RANCH_ART_DIRECTORY="${R20_REPOSITORY_ROOT}/Sources/AgentLoopApp/Resources/RanchArt"
readonly R20_EXPECTED_MANIFEST_COUNT="140"
readonly R20_EXPECTED_BRANCH="codex/personal-ai-ranch-p0"
readonly R20_EXPECTED_HEAD="02334ec8d21533be81d93d39191bc7d9b9c24f7f"
readonly R20_EXPECTED_INFO_PLIST_SHA="5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58"
readonly R20_EXPECTED_RANCH_ART_MANIFEST_SHA="4f73a80e821faa64d0a29d797cc12e20d5f88248bbb186e74972af49798ddbab"
readonly R20_R15_STATE_ROOT_BASENAME="agentloop-r15-state.Zq6Jvm"
readonly R20_R15_BUNDLE_PARENT_BASENAME="agentloop-r15-bundle.2xROcy"
readonly R20_R15_STATE_ROOT="/private/tmp/${R20_R15_STATE_ROOT_BASENAME}"
readonly R20_R15_BUNDLE_PARENT="/private/tmp/${R20_R15_BUNDLE_PARENT_BASENAME}"
readonly R20_R15_ABSENCE_PROOF_IDENTITY="private_tmp_parent_enumeration_exact_basename_v1"
readonly R20_R15_PLANNED_APP="${R20_R15_BUNDLE_PARENT}/AgentLoop.app"
readonly R20_R15_SCREENSHOT="${R20_TASK_DIRECTORY}/evidence/r15-preview-smoke.png"
readonly R20_R19_INVOCATION_ID="r19-daef1dab-0fbe-4a03-bab1-422adc18b3d4"
readonly R20_R19_MANIFEST_PATH="${R20_TASK_DIRECTORY}/evidence/r19-entry.sha256"
readonly R20_R19_FREEZE_PATH="${R20_TASK_DIRECTORY}/evidence/plan-freeze-r19.md"
readonly R20_R19_REVIEW_PATH="${R20_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/19-p1-plan-review.md"
readonly R20_R19_STATE_ROOT="/private/tmp/agentloop-r19-state.dNgUXh"
readonly R20_R19_BUNDLE_PARENT="/private/tmp/agentloop-r19-bundle.49xVDm"
readonly R20_R19_PLANNED_APP="${R20_R19_BUNDLE_PARENT}/AgentLoop.app"
readonly R20_R19_SCREENSHOT="${R20_TASK_DIRECTORY}/evidence/r19-preview-smoke.png"
readonly R20_R19_BOUNDARY_LOG="${R20_TASK_DIRECTORY}/evidence/r19-clean-boundary.log"
readonly R20_R19_HASH_LOG="${R20_TASK_DIRECTORY}/evidence/r19-hash-manifest.log"
readonly R20_R19_TARGETED_LOG="${R20_TASK_DIRECTORY}/r19-targeted-tests.log"
readonly R20_R19_VERIFY_LOG="${R20_TASK_DIRECTORY}/r19-verify.log"
readonly R20_R19_REPORT="${R20_TASK_DIRECTORY}/impl-report-r19.md"
readonly R20_IMPLEMENTATION_CORE_PATH="${R20_REPOSITORY_ROOT}/Sources/AgentLoopCore/Loop/AgentLoop.swift"
readonly R20_IMPLEMENTATION_TEST_PATH="${R20_REPOSITORY_ROOT}/Sources/AgentLoopTestSuite/AgentLoopTests.swift"

R20_BOUNDARY_ACTIVE="false"
R20_PHASE="pre_begin"
R20_INVOCATION_ID=""
R20_STATE_ROOT=""
R20_BUNDLE_PARENT=""

r20_utc_now() {
  /bin/date -u '+%Y-%m-%dT%H:%M:%SZ'
}

r20_pre_begin_fail() {
  local r20_exit_code="$1"
  shift
  /usr/bin/printf 'R20 pre-BEGIN rejected: %s\n' "$*" >&2
  exit "$r20_exit_code"
}

r20_append_boundary() {
  /usr/bin/printf '%s\n' "$*" >> "${R20_BOUNDARY_LOG}"
}

r20_authorization_is_consumed() {
  if [[ "${R20_BOUNDARY_ACTIVE}" == "true" ]]; then
    return 0
  fi
  if [[ -n "${R20_INVOCATION_ID}" &&
        -f "${R20_BOUNDARY_LOG}" &&
        ! -L "${R20_BOUNDARY_LOG}" ]] &&
     /usr/bin/grep -Fx "invocation_id=${R20_INVOCATION_ID}" "${R20_BOUNDARY_LOG}" >/dev/null 2>&1 &&
     /usr/bin/grep -Fx 'authorization_consumed=true' "${R20_BOUNDARY_LOG}" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

r20_active_fail() {
  local r20_exit_code="$1"
  local r20_reason="$2"
  local r20_command="${3:-explicit_fail_closed}"
  trap - ERR HUP INT TERM
  set +e
  r20_append_boundary "utc=$(r20_utc_now)"
  r20_append_boundary "status=REJECTED_CONTAMINATED"
  r20_append_boundary "phase=${R20_PHASE}"
  r20_append_boundary "reason=${r20_reason}"
  printf 'failed_command=%q\n' "${r20_command}" >> "${R20_BOUNDARY_LOG}"
  r20_append_boundary "exit_code=${r20_exit_code}"
  r20_append_boundary "state_root=${R20_STATE_ROOT:-UNCREATED}"
  r20_append_boundary "bundle_parent=${R20_BUNDLE_PARENT:-UNCREATED}"
  if [[ -n "${R20_PLANNED_APP:-}" ]]; then
    r20_append_boundary "planned_app=${R20_PLANNED_APP}"
  fi
  r20_append_boundary "retry_same_boundary=false"
  /usr/bin/printf 'R20 rejected after authorization consumption: %s\n' "${r20_reason}" >&2
  exit "$r20_exit_code"
}

r20_unexpected_error() {
  local r20_exit_code="$?"
  local r20_command="${BASH_COMMAND:-unknown}"
  trap - ERR
  if r20_authorization_is_consumed; then
    r20_active_fail "${r20_exit_code}" "unexpected_command_failure" "${r20_command}"
  fi
  printf 'R20 pre-BEGIN command failed: phase=%s rc=%s command=%q\n' \
    "${R20_PHASE}" "${r20_exit_code}" "${r20_command}" >&2
  exit "${r20_exit_code}"
}

r20_signal_error() {
  local r20_signal="$1"
  trap - HUP INT TERM
  if r20_authorization_is_consumed; then
    r20_active_fail "74" "signal_${r20_signal}" "signal_${r20_signal}"
  fi
  /usr/bin/printf 'R20 pre-BEGIN interrupted by signal %s\n' "${r20_signal}" >&2
  exit 74
}

trap r20_unexpected_error ERR
trap 'r20_signal_error HUP' HUP
trap 'r20_signal_error INT' INT
trap 'r20_signal_error TERM' TERM

r20_attestation_fail() {
  local r20_exit_code="$1"
  shift
  if r20_authorization_is_consumed; then
    r20_active_fail "${r20_exit_code}" "$*"
  fi
  r20_pre_begin_fail "${r20_exit_code}" "$*"
}

r20_require_lowercase_sha256() {
  local r20_value="$1"
  local r20_label="$2"
  if [[ "${#r20_value}" -ne 64 ]]; then
    r20_pre_begin_fail 64 "${r20_label} must be exactly 64 lowercase hex characters"
  fi
  case "${r20_value}" in
    *[!0-9a-f]*)
      r20_pre_begin_fail 64 "${r20_label} must be exactly 64 lowercase hex characters"
      ;;
  esac
}

r20_emit_anchor_manifest() {
  /usr/bin/printf '%s  %s\n' "${R20_EXPECTED_FREEZE_SHA}" "${R20_FREEZE_PATH}"
  /usr/bin/printf '%s  %s\n' "${R20_EXPECTED_REVIEW20_SHA}" "${R20_REVIEW20_PATH}"
  /usr/bin/printf '%s  %s\n' "${R20_EXPECTED_DRIVER_SHA}" "${R20_DRIVER_PATH}"
  /usr/bin/printf '%s  %s\n' "${R20_EXPECTED_MANIFEST_SHA}" "${R20_MANIFEST_PATH}"
}

r20_check_anchors_to_stdout() {
  local -a r20_anchor_status
  if r20_emit_anchor_manifest |
    /usr/bin/shasum -a 256 --strict -c -; then
    r20_anchor_status=( "${PIPESTATUS[@]}" )
  else
    r20_anchor_status=( "${PIPESTATUS[@]}" )
  fi
  if [[ "${r20_anchor_status[0]}" -ne 0 || "${r20_anchor_status[1]}" -ne 0 ]]; then
    r20_pre_begin_fail 65 "terminal anchor verification failed with producer_rc=${r20_anchor_status[0]} shasum_rc=${r20_anchor_status[1]}"
  fi
}

r20_manifest_contains_path() {
  local r20_manifest_file="$1"
  local r20_expected_path="$2"
  local r20_manifest_line
  local r20_manifest_entry_path
  while IFS= read -r r20_manifest_line || [[ -n "${r20_manifest_line}" ]]; do
    r20_manifest_entry_path="${r20_manifest_line#*  }"
    if [[ "${r20_manifest_entry_path}" == "${r20_expected_path}" ]]; then
      return 0
    fi
  done < "${r20_manifest_file}"
  return 1
}

r20_check_manifest_shape() {
  local r20_manifest_count
  local r20_manifest_count_rc
  local r20_r19_manifest_count
  local r20_r19_manifest_count_rc
  local r20_r19_manifest_line
  local r20_r19_manifest_entry_path
  local r20_required_addition
  local -a r20_required_additions=(
    "${R20_DRIVER_PATH}"
    "${R20_R19_MANIFEST_PATH}"
    "${R20_R19_FREEZE_PATH}"
    "${R20_R19_REVIEW_PATH}"
    "${R20_R19_TARGETED_LOG}"
    "${R20_R19_VERIFY_LOG}"
    "${R20_TASK_DIRECTORY}/r19-build.log"
    "${R20_TASK_DIRECTORY}/r19-migration-matrix.log"
    "${R20_R19_REPORT}"
    "${R20_R19_BOUNDARY_LOG}"
    "${R20_TASK_DIRECTORY}/evidence/r19-bundle-provenance.log"
    "${R20_TASK_DIRECTORY}/evidence/r19-source-gates.log"
    "${R20_R19_HASH_LOG}"
    "${R20_TASK_DIRECTORY}/evidence/r19-preview-bootstrap.log"
    "${R20_TASK_DIRECTORY}/evidence/r19-preview-cold-start.log"
    "${R20_IMPLEMENTATION_CORE_PATH}"
    "${R20_IMPLEMENTATION_TEST_PATH}"
  )
  if [[ ! -f "${R20_MANIFEST_PATH}" || -L "${R20_MANIFEST_PATH}" ]]; then
    r20_attestation_fail 66 "static manifest is missing, non-regular, or a symlink"
  fi
  if r20_manifest_count="$(
    trap - ERR
    /usr/bin/awk 'END { print NR }' "${R20_MANIFEST_PATH}"
  )"; then
    r20_manifest_count_rc=0
  else
    r20_manifest_count_rc="$?"
  fi
  if [[ "${r20_manifest_count_rc}" -ne 0 ]]; then
    r20_attestation_fail 66 "static manifest record count failed with rc=${r20_manifest_count_rc}"
  fi
  if [[ "${r20_manifest_count}" != "${R20_EXPECTED_MANIFEST_COUNT}" ]]; then
    r20_attestation_fail 66 "static manifest entry count is ${r20_manifest_count}, expected ${R20_EXPECTED_MANIFEST_COUNT}"
  fi
  if /usr/bin/grep -F -- "  ${R20_MANIFEST_PATH}" "${R20_MANIFEST_PATH}" >/dev/null 2>&1; then
    r20_attestation_fail 66 "static manifest must not contain itself"
  fi
  if /usr/bin/grep -F -- "  ${R20_FREEZE_PATH}" "${R20_MANIFEST_PATH}" >/dev/null 2>&1; then
    r20_attestation_fail 66 "static manifest must not contain the R20 freeze"
  fi
  if /usr/bin/grep -F -- "  ${R20_REVIEW20_PATH}" "${R20_MANIFEST_PATH}" >/dev/null 2>&1; then
    r20_attestation_fail 66 "static manifest must not contain Review20"
  fi
  if ! /usr/bin/cut -c 67- "${R20_MANIFEST_PATH}" | LC_ALL=C /usr/bin/sort -cu; then
    r20_attestation_fail 66 "static manifest paths are not bytewise sorted and unique"
  fi
  while IFS= read -r r20_manifest_line || [[ -n "${r20_manifest_line}" ]]; do
    local r20_manifest_entry_path="${r20_manifest_line#*  }"
    case "${r20_manifest_entry_path}" in
      "${R20_REPOSITORY_ROOT}"/*)
        ;;
      *)
        r20_attestation_fail 66 "static manifest entry is outside the repository"
        ;;
    esac
    case "${r20_manifest_entry_path}" in
      *"/../"*|*"/./"*|*/..|*/.)
        r20_attestation_fail 66 "static manifest entry contains a non-canonical path segment"
        ;;
    esac
    if [[ ! -f "${r20_manifest_entry_path}" || -L "${r20_manifest_entry_path}" ]]; then
      r20_attestation_fail 66 "static manifest entry is non-regular or a symlink: ${r20_manifest_entry_path}"
    fi
  done < "${R20_MANIFEST_PATH}"

  if [[ ! -f "${R20_R19_MANIFEST_PATH}" || -L "${R20_R19_MANIFEST_PATH}" ]]; then
    r20_attestation_fail 66 "immutable R19 manifest is missing, non-regular, or a symlink"
  fi
  if r20_r19_manifest_count="$(
    trap - ERR
    /usr/bin/awk 'END { print NR }' "${R20_R19_MANIFEST_PATH}"
  )"; then
    r20_r19_manifest_count_rc=0
  else
    r20_r19_manifest_count_rc="$?"
  fi
  if [[ "${r20_r19_manifest_count_rc}" -ne 0 ]]; then
    r20_attestation_fail 66 "immutable R19 manifest record count failed with rc=${r20_r19_manifest_count_rc}"
  fi
  if [[ "${r20_r19_manifest_count}" != "123" ]]; then
    r20_attestation_fail 66 "immutable R19 manifest no longer has exactly 123 entries"
  fi
  if ! /usr/bin/cut -c 67- "${R20_R19_MANIFEST_PATH}" | LC_ALL=C /usr/bin/sort -cu; then
    r20_attestation_fail 66 "immutable R19 manifest paths are not bytewise sorted and unique"
  fi
  if [[ "${#r20_required_additions[@]}" -ne 17 ]]; then
    r20_attestation_fail 66 "R20 required-addition set no longer has exactly 17 paths"
  fi
  while IFS= read -r r20_r19_manifest_line || [[ -n "${r20_r19_manifest_line}" ]]; do
    r20_r19_manifest_entry_path="${r20_r19_manifest_line#*  }"
    if ! r20_manifest_contains_path "${R20_MANIFEST_PATH}" "${r20_r19_manifest_entry_path}"; then
      r20_attestation_fail 66 "R20 manifest does not inherit the complete R19 path set"
    fi
  done < "${R20_R19_MANIFEST_PATH}"
  for r20_required_addition in "${r20_required_additions[@]}"; do
    if r20_manifest_contains_path "${R20_R19_MANIFEST_PATH}" "${r20_required_addition}"; then
      r20_attestation_fail 66 "R20 required addition unexpectedly overlaps the R19 path set"
    fi
    if ! r20_manifest_contains_path "${R20_MANIFEST_PATH}" "${r20_required_addition}"; then
      r20_attestation_fail 66 "R20 manifest is missing a required addition"
    fi
  done
}

r20_check_manifest_to_stdout() {
  local r20_manifest_rc
  if /usr/bin/shasum -a 256 --strict -c "${R20_MANIFEST_PATH}"; then
    r20_manifest_rc=0
  else
    r20_manifest_rc="$?"
  fi
  if [[ "${r20_manifest_rc}" -ne 0 ]]; then
    r20_pre_begin_fail 66 "static manifest verification failed with rc=${r20_manifest_rc}"
  fi
}

r20_require_process_absent() {
  local r20_process_name="$1"
  local r20_process_rc
  if /usr/bin/pgrep -x "${r20_process_name}" >/dev/null 2>&1; then
    r20_process_rc=0
  else
    r20_process_rc="$?"
  fi
  case "${r20_process_rc}" in
    1)
      ;;
    0)
      r20_attestation_fail 69 "${r20_process_name} process is present"
      ;;
    *)
      r20_attestation_fail 69 "pgrep for ${r20_process_name} was indeterminate with rc=${r20_process_rc}"
      ;;
  esac
}

r20_require_absent_path() {
  local r20_path="$1"
  if [[ -e "${r20_path}" || -L "${r20_path}" ]]; then
    r20_pre_begin_fail 68 "runtime artifact already exists: ${r20_path}"
  fi
}

r20_probe_empty_directory() {
  local r20_path="$1"
  local r20_probe_output
  local r20_probe_rc
  if r20_probe_output="$(
    trap - ERR
    /usr/bin/find "${r20_path}" -mindepth 1 -maxdepth 1 -print -quit 2>&1
  )"; then
    r20_probe_rc=0
  else
    r20_probe_rc="$?"
  fi
  if [[ "${r20_probe_rc}" -ne 0 ]]; then
    return 2
  fi
  if [[ -n "${r20_probe_output}" ]]; then
    return 1
  fi
  return 0
}

r20_require_r15_tombstones_absent() {
  local r20_r15_tombstone_probe_output
  local r20_r15_tombstone_probe_rc
  if [[ -z "${R20_R15_STATE_ROOT_BASENAME}" ||
        "${R20_R15_STATE_ROOT_BASENAME}" == "." ||
        "${R20_R15_STATE_ROOT_BASENAME}" == ".." ||
        -z "${R20_R15_BUNDLE_PARENT_BASENAME}" ||
        "${R20_R15_BUNDLE_PARENT_BASENAME}" == "." ||
        "${R20_R15_BUNDLE_PARENT_BASENAME}" == ".." ||
        "${R20_R15_STATE_ROOT_BASENAME}" == "${R20_R15_BUNDLE_PARENT_BASENAME}" ]]; then
    r20_pre_begin_fail 70 "R15 tombstone basenames are invalid or non-distinct"
  fi
  if [[ "${R20_R15_STATE_ROOT_BASENAME}" != "agentloop-r15-state.Zq6Jvm" ||
        "${R20_R15_BUNDLE_PARENT_BASENAME}" != "agentloop-r15-bundle.2xROcy" ||
        "${R20_R15_STATE_ROOT}" != "/private/tmp/agentloop-r15-state.Zq6Jvm" ||
        "${R20_R15_BUNDLE_PARENT}" != "/private/tmp/agentloop-r15-bundle.2xROcy" ]]; then
    r20_pre_begin_fail 70 "R15 tombstone frozen basename or path identity drifted"
  fi
  if [[ "${R20_R15_STATE_ROOT}" != "/private/tmp/${R20_R15_STATE_ROOT_BASENAME}" ||
        "${R20_R15_BUNDLE_PARENT}" != "/private/tmp/${R20_R15_BUNDLE_PARENT_BASENAME}" ]]; then
    r20_pre_begin_fail 70 "R15 tombstone path reconstruction failed"
  fi
  if [[ ! -d /private/tmp || -L /private/tmp ]]; then
    r20_pre_begin_fail 70 "R15 tombstone parent is missing, non-directory, or symlink: /private/tmp"
  fi
  if r20_r15_tombstone_probe_output="$(
    trap - ERR
    /usr/bin/find /private/tmp \
      -mindepth 1 -maxdepth 1 \
      \( \
        -name "${R20_R15_STATE_ROOT_BASENAME}" -o \
        -name "${R20_R15_BUNDLE_PARENT_BASENAME}" \
      \) \
      -print -quit 2>&1
  )"; then
    r20_r15_tombstone_probe_rc=0
  else
    r20_r15_tombstone_probe_rc="$?"
  fi
  if [[ "${r20_r15_tombstone_probe_rc}" -ne 0 ]]; then
    r20_pre_begin_fail 70 "R15 tombstone absence parent enumeration was indeterminate with rc=${r20_r15_tombstone_probe_rc}"
  fi
  if [[ -n "${r20_r15_tombstone_probe_output}" ]]; then
    r20_pre_begin_fail 70 "R15 tombstoned volatile root reappeared: ${r20_r15_tombstone_probe_output}"
  fi
  if [[ -e "${R20_R15_STATE_ROOT}" || -L "${R20_R15_STATE_ROOT}" ]]; then
    r20_pre_begin_fail 70 "R15 tombstoned state root reappeared after parent enumeration: ${R20_R15_STATE_ROOT}"
  fi
  if [[ -e "${R20_R15_BUNDLE_PARENT}" || -L "${R20_R15_BUNDLE_PARENT}" ]]; then
    r20_pre_begin_fail 70 "R15 tombstoned bundle parent reappeared after parent enumeration: ${R20_R15_BUNDLE_PARENT}"
  fi
}

r20_require_no_unconsumed_fresh_roots() {
  local r20_root_probe_output
  local r20_root_probe_rc
  if r20_root_probe_output="$(
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
        -name 'agentloop-r20-state.*' -o \
        -name 'agentloop-r20-bundle.*' \
      \) \
      -print -quit 2>&1
  )"; then
    r20_root_probe_rc=0
  else
    r20_root_probe_rc="$?"
  fi
  if [[ "${r20_root_probe_rc}" -ne 0 ]]; then
    r20_pre_begin_fail 70 "R16/R17/R18/R20 fresh-root absence probe was indeterminate with rc=${r20_root_probe_rc}"
  fi
  if [[ -n "${r20_root_probe_output}" ]]; then
    r20_pre_begin_fail 70 "R16/R17/R18/R20 fresh root must remain absent: ${r20_root_probe_output}"
  fi
}

r20_exclusive_create_empty() {
  local r20_path="$1"
  ( set -C; : > "${r20_path}" )
}

r20_require_fresh_root() {
  local r20_path="$1"
  local r20_label="$2"
  local r20_probe_rc
  local r20_realpath
  local r20_realpath_rc
  if [[ ! -d "${r20_path}" || -L "${r20_path}" ]]; then
    r20_active_fail 72 "${r20_label}_invalid_type"
  fi
  if r20_realpath="$(
    trap - ERR
    /bin/realpath "${r20_path}" 2>&1
  )"; then
    r20_realpath_rc=0
  else
    r20_realpath_rc="$?"
  fi
  if [[ "${r20_realpath_rc}" -ne 0 ]]; then
    r20_active_fail 72 "${r20_label}_realpath_probe_failed"
  fi
  if [[ "${r20_realpath}" != "${r20_path}" ]]; then
    r20_active_fail 72 "${r20_label}_realpath_mismatch"
  fi
  if r20_probe_empty_directory "${r20_path}"; then
    return 0
  else
    r20_probe_rc="$?"
  fi
  if [[ "${r20_probe_rc}" -eq 1 ]]; then
    r20_active_fail 72 "${r20_label}_not_empty"
  fi
  r20_active_fail 72 "${r20_label}_emptiness_probe_indeterminate"
}

r20_emit_r19_artifact_manifest() {
  /usr/bin/printf '%s  %s\n' \
    "501957999e7a8103e553cb580d9b70f0825ee79a5c9a89e4b47e13c5db350f45" "${R20_R19_TARGETED_LOG}" \
    "8ef56ce31c3e01c551e4ef65c98ce43e3631ad7554b56640e943cdb0ce5d5c15" "${R20_R19_VERIFY_LOG}" \
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "${R20_TASK_DIRECTORY}/r19-build.log" \
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "${R20_TASK_DIRECTORY}/r19-migration-matrix.log" \
    "cddaffeaf553ff72b8f40ea1748baad649d98f747ff2210722f8fd1c388aceec" "${R20_R19_REPORT}" \
    "a5e1b1b8edda476204f4b0fbcc01f90e3e6bced1dee07daf4d58b9f4e143ca30" "${R20_R19_BOUNDARY_LOG}" \
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "${R20_TASK_DIRECTORY}/evidence/r19-bundle-provenance.log" \
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "${R20_TASK_DIRECTORY}/evidence/r19-source-gates.log" \
    "43e9d2eb00c0a63d5071b0c17f2cdc4c5809530788e893b4ffb0381e60e1aff8" "${R20_R19_HASH_LOG}" \
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "${R20_TASK_DIRECTORY}/evidence/r19-preview-bootstrap.log" \
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "${R20_TASK_DIRECTORY}/evidence/r19-preview-cold-start.log"
}

r20_require_exact_r19_root_set() {
  local -a r20_r19_root_pipeline_status
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
    ' -- "${R20_R19_STATE_ROOT}" "${R20_R19_BUNDLE_PARENT}"; then
    r20_r19_root_pipeline_status=( "${PIPESTATUS[@]}" )
  else
    r20_r19_root_pipeline_status=( "${PIPESTATUS[@]}" )
  fi
  if [[ "${#r20_r19_root_pipeline_status[@]}" -ne 2 ||
        "${r20_r19_root_pipeline_status[0]}" -ne 0 ||
        "${r20_r19_root_pipeline_status[1]}" -ne 0 ]]; then
    r20_attestation_fail 70 \
      "R19 retained root exact-set verification failed with find_rc=${r20_r19_root_pipeline_status[0]:-MISSING} validator_rc=${r20_r19_root_pipeline_status[1]:-MISSING}"
  fi
}

r20_require_r19_containment() {
  local r20_verification_mode="$1"
  local -a r20_r19_artifact_status
  local -a r20_r19_artifacts=(
    "${R20_R19_TARGETED_LOG}"
    "${R20_R19_VERIFY_LOG}"
    "${R20_TASK_DIRECTORY}/r19-build.log"
    "${R20_TASK_DIRECTORY}/r19-migration-matrix.log"
    "${R20_R19_REPORT}"
    "${R20_R19_BOUNDARY_LOG}"
    "${R20_TASK_DIRECTORY}/evidence/r19-bundle-provenance.log"
    "${R20_TASK_DIRECTORY}/evidence/r19-source-gates.log"
    "${R20_R19_HASH_LOG}"
    "${R20_TASK_DIRECTORY}/evidence/r19-preview-bootstrap.log"
    "${R20_TASK_DIRECTORY}/evidence/r19-preview-cold-start.log"
  )
  local r20_r19_artifact
  local r20_r19_root
  local r20_r19_root_realpath
  local r20_r19_root_realpath_rc
  local r20_r19_empty_rc
  local r20_r19_required_line

  case "${r20_verification_mode}" in
    pre_begin)
      if r20_authorization_is_consumed; then
        r20_attestation_fail 70 "pre_begin_r19_containment_after_authorization_consumption"
      fi
      ;;
    post_activation)
      if ! r20_authorization_is_consumed; then
        r20_pre_begin_fail 70 "post_activation_r19_containment_before_authorization_consumption"
      fi
      ;;
    *)
      r20_attestation_fail 64 "invalid R19 containment verification mode: ${r20_verification_mode}"
      ;;
  esac

  for r20_r19_artifact in "${r20_r19_artifacts[@]}"; do
    if [[ ! -f "${r20_r19_artifact}" || -L "${r20_r19_artifact}" ]]; then
      r20_attestation_fail 70 "R19 artifact is missing, non-regular, or a symlink"
    fi
  done

  if r20_emit_r19_artifact_manifest |
    /usr/bin/shasum -a 256 --strict -c - >/dev/null; then
    r20_r19_artifact_status=( "${PIPESTATUS[@]}" )
  else
    r20_r19_artifact_status=( "${PIPESTATUS[@]}" )
  fi
  if [[ "${#r20_r19_artifact_status[@]}" -ne 2 ||
        "${r20_r19_artifact_status[0]}" -ne 0 ||
        "${r20_r19_artifact_status[1]}" -ne 0 ]]; then
    r20_attestation_fail 70 "R19 immutable artifact verification failed"
  fi

  r20_require_exact_r19_root_set

  for r20_r19_root in "${R20_R19_STATE_ROOT}" "${R20_R19_BUNDLE_PARENT}"; do
    if [[ ! -d "${r20_r19_root}" || -L "${r20_r19_root}" ]]; then
      r20_attestation_fail 70 "R19 retained root is missing, non-directory, or a symlink"
    fi
    if r20_r19_root_realpath="$(
      trap - ERR
      /bin/realpath "${r20_r19_root}" 2>&1
    )"; then
      r20_r19_root_realpath_rc=0
    else
      r20_r19_root_realpath_rc="$?"
    fi
    if [[ "${r20_r19_root_realpath_rc}" -ne 0 ||
          "${r20_r19_root_realpath}" != "${r20_r19_root}" ]]; then
      r20_attestation_fail 70 "R19 retained root realpath verification failed"
    fi
    if r20_probe_empty_directory "${r20_r19_root}"; then
      r20_r19_empty_rc=0
    else
      r20_r19_empty_rc="$?"
    fi
    case "${r20_r19_empty_rc}" in
      0)
        ;;
      1)
        r20_attestation_fail 70 "R19 retained root is not empty"
        ;;
      *)
        r20_attestation_fail 70 "R19 retained root emptiness was indeterminate"
        ;;
    esac
  done

  if [[ "${R20_R19_STATE_ROOT}" == "${R20_R19_BUNDLE_PARENT}" ]]; then
    r20_attestation_fail 70 "R19 retained roots are not distinct"
  fi
  if [[ -e "${R20_R19_PLANNED_APP}" || -L "${R20_R19_PLANNED_APP}" ]]; then
    r20_attestation_fail 70 "R19 planned App must remain absent"
  fi
  if [[ -e "${R20_R19_SCREENSHOT}" || -L "${R20_R19_SCREENSHOT}" ]]; then
    r20_attestation_fail 70 "R19 screenshot must remain absent"
  fi

  for r20_r19_required_line in \
    "boundary=R19_CLEAN_REVERIFICATION" \
    "invocation_id=${R20_R19_INVOCATION_ID}" \
    "authorization_consumed=true" \
    "status=REJECTED_CONTAMINATED" \
    "phase=full_tests" \
    "reason=swift_run_full_failed" \
    "state_root=${R20_R19_STATE_ROOT}" \
    "bundle_parent=${R20_R19_BUNDLE_PARENT}" \
    "containment_state_root_empty=true" \
    "containment_bundle_parent_empty=true" \
    "containment_app_absent=true" \
    "verdict_remains=REJECTED_CONTAMINATED" \
    "retry_same_boundary=false"; do
    if ! /usr/bin/grep -Fx -- "${r20_r19_required_line}" "${R20_R19_BOUNDARY_LOG}" >/dev/null 2>&1; then
      r20_attestation_fail 70 "R19 immutable boundary fact is missing"
    fi
  done

  if [[ "${r20_verification_mode}" == "post_activation" ]]; then
    /usr/bin/printf '%s\n' \
      "section=r19_containment" \
      "phase=post_activation" \
      "r19_invocation_id=${R20_R19_INVOCATION_ID}" \
      "r19_verdict=REJECTED_CONTAMINATED" \
      "r19_artifact_count=11" \
      "r19_artifacts_immutable=true" \
      "r19_root_glob_exact_count=2" \
      "r19_state_root=${R20_R19_STATE_ROOT}" \
      "r19_bundle_parent=${R20_R19_BUNDLE_PARENT}" \
      "r19_state_root_real_empty=true" \
      "r19_bundle_parent_real_empty=true" \
      "r19_planned_app_absent=true" \
      "r19_screenshot_absent=true" \
      "r19_retry_same_boundary=false" >> "${R20_HASH_LOG}"
  fi
}

r20_post_activation_anchor_check() {
  local -a r20_anchor_status
  {
    /usr/bin/printf '%s\n' "section=terminal_anchors"
    r20_emit_anchor_manifest
  } >> "${R20_HASH_LOG}"
  if r20_emit_anchor_manifest |
    /usr/bin/shasum -a 256 --strict -c - >> "${R20_HASH_LOG}" 2>&1; then
    r20_anchor_status=( "${PIPESTATUS[@]}" )
  else
    r20_anchor_status=( "${PIPESTATUS[@]}" )
  fi
  /usr/bin/printf 'terminal_anchor_producer_rc=%s\n' "${r20_anchor_status[0]}" >> "${R20_HASH_LOG}"
  /usr/bin/printf 'terminal_anchor_shasum_rc=%s\n' "${r20_anchor_status[1]}" >> "${R20_HASH_LOG}"
  if [[ "${r20_anchor_status[0]}" -ne 0 || "${r20_anchor_status[1]}" -ne 0 ]]; then
    r20_active_fail 65 "post_activation_terminal_anchor_failure_producer_${r20_anchor_status[0]}_shasum_${r20_anchor_status[1]}"
  fi
}

r20_post_activation_manifest_check() {
  local r20_manifest_rc
  local r20_manifest_count
  local r20_manifest_count_rc
  if r20_manifest_count="$(
    trap - ERR
    /usr/bin/awk 'END { print NR }' "${R20_MANIFEST_PATH}"
  )"; then
    r20_manifest_count_rc=0
  else
    r20_manifest_count_rc="$?"
  fi
  if [[ "${r20_manifest_count_rc}" -ne 0 ]]; then
    r20_active_fail 66 "post_activation_static_manifest_count_failed_rc_${r20_manifest_count_rc}"
  fi
  /usr/bin/printf '%s\n' "section=static_manifest" >> "${R20_HASH_LOG}"
  /usr/bin/printf 'static_manifest_expected_count=%s\n' "${R20_EXPECTED_MANIFEST_COUNT}" >> "${R20_HASH_LOG}"
  /usr/bin/printf 'static_manifest_actual_count=%s\n' "${r20_manifest_count}" >> "${R20_HASH_LOG}"
  if /usr/bin/shasum -a 256 --strict -c "${R20_MANIFEST_PATH}" >> "${R20_HASH_LOG}" 2>&1; then
    r20_manifest_rc=0
  else
    r20_manifest_rc="$?"
  fi
  /usr/bin/printf 'static_manifest_rc=%s\n' "${r20_manifest_rc}" >> "${R20_HASH_LOG}"
  if [[ "${r20_manifest_rc}" -ne 0 ]]; then
    r20_active_fail 66 "post_activation_static_manifest_failure_rc_${r20_manifest_rc}"
  fi
  if [[ "${r20_manifest_count}" != "${R20_EXPECTED_MANIFEST_COUNT}" ]]; then
    r20_active_fail 66 "post_activation_static_manifest_count_${r20_manifest_count}"
  fi
}

r20_check_ranch_art_structure() {
  local r20_verification_mode="$1"
  local r20_evidence_sink
  local r20_evidence_phase
  local -a r20_expected_basenames=(
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
  local -a r20_ranch_pipeline_status

  case "${r20_verification_mode}" in
    pre_begin)
      if r20_authorization_is_consumed; then
        r20_attestation_fail 70 "pre_begin_ranch_art_check_after_authorization_consumption"
      fi
      r20_evidence_sink="/dev/stderr"
      r20_evidence_phase="pre_consumption"
      ;;
    post_activation)
      if ! r20_authorization_is_consumed; then
        r20_pre_begin_fail 70 "post_activation_ranch_art_check_before_authorization_consumption"
      fi
      if [[ ! -f "${R20_HASH_LOG}" || -L "${R20_HASH_LOG}" ]]; then
        r20_active_fail 70 "post_activation_ranch_art_hash_log_invalid"
      fi
      r20_evidence_sink="${R20_HASH_LOG}"
      r20_evidence_phase="post_activation"
      ;;
    *)
      r20_attestation_fail 64 "invalid RanchArt verification mode: ${r20_verification_mode}"
      ;;
  esac

  # Hide raw pathname diagnostics while retaining both numeric pipeline statuses
  # in the fixed fail-closed reason below.
  if /usr/bin/find -P "${R20_RANCH_ART_DIRECTORY}" \
      -mindepth 1 -maxdepth 1 -print0 2>/dev/null |
    /bin/bash -c '
      set +x
      set +v
      set -u
      set -f
      LC_ALL=C
      export LC_ALL
      shopt -u nocasematch

      r20_directory="$1"
      shift
      r20_expected_count="$#"
      r20_invalid=0
      r20_partial_final_record=0
      r20_read_rc=1
      r20_total_count=0
      r20_regular_count=0
      r20_nonregular_count=0
      r20_symlink_count=0
      r20_index=0
      r20_other_index=0
      r20_path=""
      r20_basename=""
      r20_prefix="${r20_directory}/"
      r20_expected_value=""
      r20_other_expected_value=""
      r20_seen=()

      if [[ "${r20_expected_count}" -ne 27 ]]; then
        r20_invalid=1
      fi
      if [[ ! -d "${r20_directory}" || -L "${r20_directory}" ]]; then
        r20_invalid=1
      fi

      r20_index=0
      for r20_expected_value in "$@"; do
        r20_seen[r20_index]=0
        if [[ -z "${r20_expected_value}" || "${r20_expected_value}" == */* ]]; then
          r20_invalid=1
        fi
        case "${r20_expected_value}" in
          *[!A-Za-z0-9.]* )
            r20_invalid=1
            ;;
        esac
        r20_other_index=0
        for r20_other_expected_value in "$@"; do
          if [[ "${r20_index}" -ne "${r20_other_index}" &&
                "${r20_expected_value}" == "${r20_other_expected_value}" ]]; then
            r20_invalid=1
          fi
          r20_other_index=$(( r20_other_index + 1 ))
        done
        r20_index=$(( r20_index + 1 ))
      done

      while :; do
        r20_path=""
        if IFS= read -r -d "" r20_path; then
          if [[ "${r20_total_count}" -lt 28 ]]; then
            r20_total_count=$(( r20_total_count + 1 ))
          else
            r20_invalid=1
          fi

          r20_record_regular=0
          if [[ -f "${r20_path}" && ! -L "${r20_path}" ]]; then
            r20_record_regular=1
            if [[ "${r20_regular_count}" -lt 28 ]]; then
              r20_regular_count=$(( r20_regular_count + 1 ))
            else
              r20_invalid=1
            fi
          else
            if [[ "${r20_nonregular_count}" -lt 28 ]]; then
              r20_nonregular_count=$(( r20_nonregular_count + 1 ))
            else
              r20_invalid=1
            fi
          fi
          if [[ -L "${r20_path}" ]]; then
            if [[ "${r20_symlink_count}" -lt 28 ]]; then
              r20_symlink_count=$(( r20_symlink_count + 1 ))
            else
              r20_invalid=1
            fi
          fi

          r20_record_matched=0
          if [[ "${r20_path}" == "${r20_prefix}"* ]]; then
            r20_basename="${r20_path#"${r20_prefix}"}"
            if [[ -n "${r20_basename}" && "${r20_basename}" != */* ]]; then
              r20_index=0
              for r20_expected_value in "$@"; do
                if [[ "${r20_basename}" == "${r20_expected_value}" ]]; then
                  r20_record_matched=1
                  if [[ "${r20_seen[r20_index]}" -eq 0 ]]; then
                    r20_seen[r20_index]=1
                  else
                    r20_invalid=1
                  fi
                  break
                fi
                r20_index=$(( r20_index + 1 ))
              done
            fi
          fi
          if [[ "${r20_record_regular}" -ne 1 || "${r20_record_matched}" -ne 1 ]]; then
            r20_invalid=1
          fi
        else
          r20_read_rc="$?"
          if [[ -n "${r20_path}" ]]; then
            r20_partial_final_record=1
            r20_invalid=1
          fi
          break
        fi
      done

      if [[ "${r20_read_rc}" -ne 1 ||
            "${r20_partial_final_record}" -ne 0 ||
            "${r20_total_count}" -ne 27 ||
            "${r20_regular_count}" -ne 27 ||
            "${r20_nonregular_count}" -ne 0 ||
            "${r20_symlink_count}" -ne 0 ||
            ! -d "${r20_directory}" || -L "${r20_directory}" ]]; then
        r20_invalid=1
      fi
      r20_index=0
      for r20_expected_value in "$@"; do
        if [[ "${r20_seen[r20_index]}" -ne 1 ]]; then
          r20_invalid=1
        fi
        r20_index=$(( r20_index + 1 ))
      done

      if [[ "${r20_invalid}" -ne 0 ]]; then
        exit 1
      fi
      exit 0
    ' "r20-ranch-art-nul-validator-v1" \
      "${R20_RANCH_ART_DIRECTORY}" "${r20_expected_basenames[@]}"; then
    r20_ranch_pipeline_status=( "${PIPESTATUS[@]}" )
  else
    r20_ranch_pipeline_status=( "${PIPESTATUS[@]}" )
  fi

  if [[ "${#r20_ranch_pipeline_status[@]}" -ne 2 ]]; then
    r20_attestation_fail 70 "ranch_art_pipeline_status_shape_invalid"
  fi
  if [[ "${r20_ranch_pipeline_status[0]}" -ne 0 ||
        "${r20_ranch_pipeline_status[1]}" -ne 0 ]]; then
    r20_attestation_fail 70 \
      "ranch_art_nul_validation_failed_find_${r20_ranch_pipeline_status[0]}_validator_${r20_ranch_pipeline_status[1]}"
  fi

  /usr/bin/printf '%s\n' "section=ranch_art_structure" >> "${r20_evidence_sink}"
  /usr/bin/printf 'phase=%s\n' "${r20_evidence_phase}" >> "${r20_evidence_sink}"
  /usr/bin/printf 'ranch_art_verification_mode=%s\n' \
    "${r20_verification_mode}" >> "${r20_evidence_sink}"
  /usr/bin/printf '%s\n' \
    "pathname_transport=find_print0_bash_read_d_nul_v1" \
    "ranch_art_find_rc=${r20_ranch_pipeline_status[0]}" \
    "ranch_art_validator_rc=${r20_ranch_pipeline_status[1]}" \
    "ranch_art_expected_count=27" \
    "ranch_art_parent_type=directory_non_symlink" \
    "ranch_art_node_type=regular_non_symlink" \
    "ranch_art_actual_count=27" \
    "ranch_art_exact_relative_path_set_begin" >> "${r20_evidence_sink}"
  /usr/bin/printf '%s\n' "${r20_expected_basenames[@]}" >> "${r20_evidence_sink}"
  /usr/bin/printf '%s\n' \
    "ranch_art_exact_relative_path_set_end" \
    "nonregular_count=0" \
    "symlink_count=0" \
    "regular_count=27" >> "${r20_evidence_sink}"
}

if [[ "$#" -ne 4 ]]; then
  r20_pre_begin_fail 64 "expected four SHA-256 arguments: freeze Review20 driver manifest"
fi

readonly R20_EXPECTED_FREEZE_SHA="$1"
readonly R20_EXPECTED_REVIEW20_SHA="$2"
readonly R20_EXPECTED_DRIVER_SHA="$3"
readonly R20_EXPECTED_MANIFEST_SHA="$4"

r20_require_lowercase_sha256 "${R20_EXPECTED_FREEZE_SHA}" "freeze hash"
r20_require_lowercase_sha256 "${R20_EXPECTED_REVIEW20_SHA}" "Review20 hash"
r20_require_lowercase_sha256 "${R20_EXPECTED_DRIVER_SHA}" "driver hash"
r20_require_lowercase_sha256 "${R20_EXPECTED_MANIFEST_SHA}" "manifest hash"

if [[ "$0" != "${R20_DRIVER_PATH}" ]]; then
  r20_pre_begin_fail 64 "driver must be invoked by its frozen absolute path"
fi
if [[ "${BASH_SOURCE[0]}" != "${R20_DRIVER_PATH}" ||
      ! -f "${R20_DRIVER_PATH}" ||
      -L "${R20_DRIVER_PATH}" ||
      "$(/bin/realpath "${R20_DRIVER_PATH}")" != "${R20_DRIVER_PATH}" ]]; then
  r20_pre_begin_fail 64 "driver source path or file type is not canonical"
fi
if (( BASH_VERSINFO[0] < 3 ||
      (BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] < 2) )); then
  r20_pre_begin_fail 64 "Bash 3.2 or newer is required"
fi
if [[ "${LC_ALL:-}" != "C" || "${LANG:-}" != "C" ]]; then
  r20_pre_begin_fail 64 "LC_ALL and LANG must both equal C"
fi
if [[ "${PATH:-}" != "/usr/bin:/bin:/usr/sbin:/sbin" ]]; then
  r20_pre_begin_fail 64 "PATH is not the frozen clean value"
fi
if [[ "${TMPDIR:-}" != "/private/tmp" ]]; then
  r20_pre_begin_fail 64 "TMPDIR is not the frozen clean value"
fi
if [[ "${GIT_CONFIG_NOSYSTEM:-}" != "1" || "${GIT_CONFIG_GLOBAL:-}" != "/dev/null" ]]; then
  r20_pre_begin_fail 64 "Git clean-environment controls are missing"
fi
if [[ -n "${BASH_ENV+x}" || -n "${ENV+x}" || -n "${CDPATH+x}" ]]; then
  r20_pre_begin_fail 64 "shell startup or directory environment was inherited"
fi

R20_PHASE="pre_begin_terminal_anchors"
r20_check_anchors_to_stdout

R20_PHASE="pre_begin_manifest_shape"
r20_check_manifest_shape

R20_PHASE="pre_begin_static_manifest"
r20_check_manifest_to_stdout

R20_PHASE="pre_begin_repository_identity"
R20_ACTUAL_BRANCH="$(/usr/bin/git -C "${R20_REPOSITORY_ROOT}" symbolic-ref --quiet --short HEAD)"
R20_ACTUAL_HEAD="$(/usr/bin/git -C "${R20_REPOSITORY_ROOT}" rev-parse --verify HEAD)"
if [[ "${R20_ACTUAL_BRANCH}" != "${R20_EXPECTED_BRANCH}" ]]; then
  r20_pre_begin_fail 67 "branch is ${R20_ACTUAL_BRANCH}, expected ${R20_EXPECTED_BRANCH}"
fi
if [[ "${R20_ACTUAL_HEAD}" != "${R20_EXPECTED_HEAD}" ]]; then
  r20_pre_begin_fail 67 "HEAD is ${R20_ACTUAL_HEAD}, expected ${R20_EXPECTED_HEAD}"
fi

R20_PHASE="pre_begin_r16_preservation"
R20_R16_RUNTIME_PATHS=(
  "${R20_TASK_DIRECTORY}/r16-targeted-tests.log"
  "${R20_TASK_DIRECTORY}/r16-verify.log"
  "${R20_TASK_DIRECTORY}/r16-build.log"
  "${R20_TASK_DIRECTORY}/r16-migration-matrix.log"
  "${R20_TASK_DIRECTORY}/impl-report-r16.md"
  "${R20_TASK_DIRECTORY}/evidence/r16-clean-boundary.log"
  "${R20_TASK_DIRECTORY}/evidence/r16-bundle-provenance.log"
  "${R20_TASK_DIRECTORY}/evidence/r16-source-gates.log"
  "${R20_TASK_DIRECTORY}/evidence/r16-hash-manifest.log"
  "${R20_TASK_DIRECTORY}/evidence/r16-preview-bootstrap.log"
  "${R20_TASK_DIRECTORY}/evidence/r16-preview-cold-start.log"
  "${R20_TASK_DIRECTORY}/evidence/r16-preview-smoke.png"
)
for R20_R16_RUNTIME_PATH in "${R20_R16_RUNTIME_PATHS[@]}"; do
  r20_require_absent_path "${R20_R16_RUNTIME_PATH}"
done

R20_PHASE="pre_begin_r17_preservation"
R20_R17_RUNTIME_PATHS=(
  "${R20_TASK_DIRECTORY}/r17-targeted-tests.log"
  "${R20_TASK_DIRECTORY}/r17-verify.log"
  "${R20_TASK_DIRECTORY}/r17-build.log"
  "${R20_TASK_DIRECTORY}/r17-migration-matrix.log"
  "${R20_TASK_DIRECTORY}/impl-report-r17.md"
  "${R20_TASK_DIRECTORY}/evidence/r17-clean-boundary.log"
  "${R20_TASK_DIRECTORY}/evidence/r17-bundle-provenance.log"
  "${R20_TASK_DIRECTORY}/evidence/r17-source-gates.log"
  "${R20_TASK_DIRECTORY}/evidence/r17-hash-manifest.log"
  "${R20_TASK_DIRECTORY}/evidence/r17-preview-bootstrap.log"
  "${R20_TASK_DIRECTORY}/evidence/r17-preview-cold-start.log"
  "${R20_TASK_DIRECTORY}/evidence/r17-preview-smoke.png"
)
for R20_R17_RUNTIME_PATH in "${R20_R17_RUNTIME_PATHS[@]}"; do
  r20_require_absent_path "${R20_R17_RUNTIME_PATH}"
done

R20_PHASE="pre_begin_r18_preservation"
R20_R18_RUNTIME_PATHS=(
  "${R20_TASK_DIRECTORY}/r18-targeted-tests.log"
  "${R20_TASK_DIRECTORY}/r18-verify.log"
  "${R20_TASK_DIRECTORY}/r18-build.log"
  "${R20_TASK_DIRECTORY}/r18-migration-matrix.log"
  "${R20_TASK_DIRECTORY}/impl-report-r18.md"
  "${R20_TASK_DIRECTORY}/evidence/r18-clean-boundary.log"
  "${R20_TASK_DIRECTORY}/evidence/r18-bundle-provenance.log"
  "${R20_TASK_DIRECTORY}/evidence/r18-source-gates.log"
  "${R20_TASK_DIRECTORY}/evidence/r18-hash-manifest.log"
  "${R20_TASK_DIRECTORY}/evidence/r18-preview-bootstrap.log"
  "${R20_TASK_DIRECTORY}/evidence/r18-preview-cold-start.log"
  "${R20_TASK_DIRECTORY}/evidence/r18-preview-smoke.png"
)
for R20_R18_RUNTIME_PATH in "${R20_R18_RUNTIME_PATHS[@]}"; do
  r20_require_absent_path "${R20_R18_RUNTIME_PATH}"
done

R20_PHASE="pre_begin_r19_containment"
r20_require_r19_containment "pre_begin"

r20_require_no_unconsumed_fresh_roots

R20_PHASE="pre_begin_runtime_paths"
R20_RUNTIME_PATHS=(
  "${R20_TASK_DIRECTORY}/r20-targeted-tests.log"
  "${R20_TASK_DIRECTORY}/r20-verify.log"
  "${R20_TASK_DIRECTORY}/r20-build.log"
  "${R20_TASK_DIRECTORY}/r20-migration-matrix.log"
  "${R20_TASK_DIRECTORY}/impl-report-r20.md"
  "${R20_TASK_DIRECTORY}/evidence/r20-clean-boundary.log"
  "${R20_TASK_DIRECTORY}/evidence/r20-bundle-provenance.log"
  "${R20_TASK_DIRECTORY}/evidence/r20-source-gates.log"
  "${R20_TASK_DIRECTORY}/evidence/r20-hash-manifest.log"
  "${R20_TASK_DIRECTORY}/evidence/r20-preview-bootstrap.log"
  "${R20_TASK_DIRECTORY}/evidence/r20-preview-cold-start.log"
  "${R20_TASK_DIRECTORY}/evidence/r20-preview-smoke.png"
)
for R20_RUNTIME_PATH in "${R20_RUNTIME_PATHS[@]}"; do
  r20_require_absent_path "${R20_RUNTIME_PATH}"
done

R20_PHASE="pre_begin_processes"
r20_require_process_absent "AgentLoop"
r20_require_process_absent "AgentLoopApp"

R20_PHASE="pre_begin_r15_tombstone_absence"
r20_require_r15_tombstones_absent
if [[ -e "${R20_R15_PLANNED_APP}" || -L "${R20_R15_PLANNED_APP}" ]]; then
  r20_pre_begin_fail 70 "R15 planned App must remain absent"
fi
if [[ -e "${R20_R15_SCREENSHOT}" || -L "${R20_R15_SCREENSHOT}" ]]; then
  r20_pre_begin_fail 70 "R15 screenshot must remain absent"
fi

R20_PHASE="pre_begin_activation_metadata"
R20_INVOCATION_ID="r20-$(
  /usr/bin/uuidgen |
    /usr/bin/tr '[:upper:]' '[:lower:]'
)"
if [[ ! "${R20_INVOCATION_ID}" =~ ^r20-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
  r20_pre_begin_fail 71 "generated R20 invocation ID has invalid format"
fi
R20_BEGIN_UTC="$(r20_utc_now)"
if [[ ! "${R20_BEGIN_UTC}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
  r20_pre_begin_fail 71 "generated R20 begin UTC has invalid format"
fi

R20_PHASE="pre_begin_ranch_art_structure"
r20_check_ranch_art_structure "pre_begin"

if ! (
  set -C
  /usr/bin/printf '%s\n' \
    "boundary=R20_DETERMINISTIC_CLOCK_REPAIR" \
    "invocation_id=${R20_INVOCATION_ID}" \
    "utc_begin=${R20_BEGIN_UTC}" \
    "authorization_consumed=true" \
    "status=BEGIN_STARTED" \
    "branch=${R20_ACTUAL_BRANCH}" \
    "head=${R20_ACTUAL_HEAD}" \
    "r15_state_root_pre_begin_observed_state=ABSENT" \
    "r15_bundle_parent_pre_begin_observed_state=ABSENT" \
    "r15_state_root_current_absent=true" \
    "r15_bundle_parent_current_absent=true" \
    "r15_absence_proof_identity=${R20_R15_ABSENCE_PROOF_IDENTITY}" \
    "disappearance_cause=UNKNOWN" \
    "pre_begin_ranch_art_structure=true" \
    "recipe=r20-dev-bundle-v1" \
    "normal_root=/Users/muzi/Library/Application Support/AgentLoop" \
    "normal_root_access_policy=lsof_path_comparison_only" \
    "r19_invocation_id=${R20_R19_INVOCATION_ID}" \
    "r19_verdict=REJECTED_CONTAMINATED" \
    "r19_artifact_count=11" \
    "r19_state_root=${R20_R19_STATE_ROOT}" \
    "r19_bundle_parent=${R20_R19_BUNDLE_PARENT}" \
    "r19_roots_real_empty=true" \
    "r19_retry_same_boundary=false" \
    "implementation_entry_baseline_count=2" \
    "implementation_allowed_final_delta_count=2" \
    "implementation_final_delta_policy=exact_two_paths_relative_to_entry_manifest" \
    "implementation_core_path=${R20_IMPLEMENTATION_CORE_PATH}" \
    "implementation_test_path=${R20_IMPLEMENTATION_TEST_PATH}" \
    "authoritative_test_command=swift_run_RunTests_unfiltered_once" \
    "test_filter_forbidden=true" \
    "targeted_evidence_source=mechanical_46_name_extraction_from_authoritative_log" \
    "freeze_sha=${R20_EXPECTED_FREEZE_SHA}" \
    "review20_sha=${R20_EXPECTED_REVIEW20_SHA}" \
    "driver_sha=${R20_EXPECTED_DRIVER_SHA}" \
    "manifest_sha=${R20_EXPECTED_MANIFEST_SHA}" \
    > "${R20_BOUNDARY_LOG}"
); then
  R20_PHASE="activation_boundary"
  r20_attestation_fail 71 "could not exclusive-create and initialize R20 boundary log"
fi
R20_PHASE="activation_boundary"
R20_BOUNDARY_ACTIVE="true"

R20_PHASE="activation_hash_log"
if ! r20_exclusive_create_empty "${R20_HASH_LOG}"; then
  r20_active_fail 71 "exclusive_create_failed_${R20_HASH_LOG}" "exclusive_create"
fi

R20_PHASE="post_activation_ranch_art_structure"
r20_check_ranch_art_structure "post_activation"

R20_PHASE="post_activation_terminal_anchors"
r20_post_activation_anchor_check

R20_PHASE="post_activation_static_manifest"
r20_check_manifest_shape
r20_post_activation_manifest_check

R20_PHASE="post_activation_r19_containment"
r20_require_r19_containment "post_activation"

/usr/bin/printf 'frozen_info_plist_sha=%s\n' "${R20_EXPECTED_INFO_PLIST_SHA}" >> "${R20_HASH_LOG}"
/usr/bin/printf 'frozen_ranch_art_manifest_sha=%s\n' "${R20_EXPECTED_RANCH_ART_MANIFEST_SHA}" >> "${R20_HASH_LOG}"
/usr/bin/printf '%s\n' "section=worktree_status" >> "${R20_HASH_LOG}"
/usr/bin/git --no-optional-locks -C "${R20_REPOSITORY_ROOT}" status --short --branch >> "${R20_HASH_LOG}"

R20_PHASE="activation_remaining_logs"
R20_REMAINING_TEXT_LOGS=(
  "${R20_TASK_DIRECTORY}/r20-targeted-tests.log"
  "${R20_TASK_DIRECTORY}/r20-verify.log"
  "${R20_TASK_DIRECTORY}/r20-build.log"
  "${R20_TASK_DIRECTORY}/r20-migration-matrix.log"
  "${R20_TASK_DIRECTORY}/evidence/r20-bundle-provenance.log"
  "${R20_TASK_DIRECTORY}/evidence/r20-source-gates.log"
  "${R20_TASK_DIRECTORY}/evidence/r20-preview-bootstrap.log"
  "${R20_TASK_DIRECTORY}/evidence/r20-preview-cold-start.log"
)
for R20_REMAINING_TEXT_LOG in "${R20_REMAINING_TEXT_LOGS[@]}"; do
  if ! r20_exclusive_create_empty "${R20_REMAINING_TEXT_LOG}"; then
    r20_active_fail 71 "exclusive_create_failed_${R20_REMAINING_TEXT_LOG}" "exclusive_create"
  fi
done

R20_PHASE="activation_fresh_roots"
R20_STATE_ROOT="$(/usr/bin/mktemp -d '/private/tmp/agentloop-r20-state.XXXXXX')"
R20_BUNDLE_PARENT="$(/usr/bin/mktemp -d '/private/tmp/agentloop-r20-bundle.XXXXXX')"
R20_PLANNED_APP="${R20_BUNDLE_PARENT}/AgentLoop.app"
R20_PLANNED_EXECUTABLE="${R20_PLANNED_APP}/Contents/MacOS/AgentLoop"

r20_require_fresh_root "${R20_STATE_ROOT}" "fresh_state_root"
r20_require_fresh_root "${R20_BUNDLE_PARENT}" "fresh_bundle_parent"
if [[ "${R20_STATE_ROOT}" == "${R20_BUNDLE_PARENT}" ]]; then
  r20_active_fail 72 "fresh_roots_equal"
fi
case "${R20_STATE_ROOT}/" in
  "${R20_BUNDLE_PARENT}/"* )
    r20_active_fail 72 "state_root_nested_in_bundle_parent"
    ;;
esac
case "${R20_BUNDLE_PARENT}/" in
  "${R20_STATE_ROOT}/"* )
    r20_active_fail 72 "bundle_parent_nested_in_state_root"
    ;;
esac
if [[ "${R20_STATE_ROOT}" == "${R20_R15_STATE_ROOT}" ||
      "${R20_STATE_ROOT}" == "${R20_R15_BUNDLE_PARENT}" ||
      "${R20_BUNDLE_PARENT}" == "${R20_R15_STATE_ROOT}" ||
      "${R20_BUNDLE_PARENT}" == "${R20_R15_BUNDLE_PARENT}" ||
      "${R20_STATE_ROOT}" == "${R20_R19_STATE_ROOT}" ||
      "${R20_STATE_ROOT}" == "${R20_R19_BUNDLE_PARENT}" ||
      "${R20_BUNDLE_PARENT}" == "${R20_R19_STATE_ROOT}" ||
      "${R20_BUNDLE_PARENT}" == "${R20_R19_BUNDLE_PARENT}" ]]; then
  r20_active_fail 72 "fresh_root_reuses_historical_root"
fi
if [[ -e "${R20_PLANNED_APP}" || -L "${R20_PLANNED_APP}" ]]; then
  r20_active_fail 72 "planned_app_preexists"
fi

r20_append_boundary "state_root=${R20_STATE_ROOT}"
r20_append_boundary "bundle_parent=${R20_BUNDLE_PARENT}"
r20_append_boundary "planned_app=${R20_PLANNED_APP}"
r20_append_boundary "planned_executable=${R20_PLANNED_EXECUTABLE}"
r20_append_boundary "final_executable_hash=DEFERRED_TO_LAUNCH_READY"
r20_append_boundary "process_count=0"
r20_append_boundary "r15_planned_app_absent=true"
r20_append_boundary "r15_screenshot_absent=true"
r20_append_boundary "r16_runtime_artifacts_absent=true"
r20_append_boundary "r16_fresh_roots_absent=true"
r20_append_boundary "r16_pre_begin_zero_write_preserved=true"
r20_append_boundary "r17_runtime_artifacts_absent=true"
r20_append_boundary "r17_fresh_roots_absent=true"
r20_append_boundary "r17_not_executed_preserved=true"
r20_append_boundary "r18_runtime_artifacts_absent=true"
r20_append_boundary "r18_fresh_roots_absent=true"
r20_append_boundary "r18_not_executed_preserved=true"
r20_append_boundary "r19_runtime_artifacts_immutable=true"
r20_append_boundary "r19_runtime_artifact_count=11"
r20_append_boundary "r19_boundary_rejected_contaminated=true"
r20_append_boundary "r19_state_root=${R20_R19_STATE_ROOT}"
r20_append_boundary "r19_bundle_parent=${R20_R19_BUNDLE_PARENT}"
r20_append_boundary "r19_state_root_real_empty=true"
r20_append_boundary "r19_bundle_parent_real_empty=true"
r20_append_boundary "r19_planned_app_absent=true"
r20_append_boundary "r19_screenshot_absent=true"
r20_append_boundary "r19_retry_same_boundary=false"
r20_append_boundary "r20_pre_activation_fresh_roots_absent=true"
r20_append_boundary "frozen_info_plist_sha=${R20_EXPECTED_INFO_PLIST_SHA}"
r20_append_boundary "frozen_ranch_art_manifest_sha=${R20_EXPECTED_RANCH_ART_MANIFEST_SHA}"

R20_PHASE="begin_finalization"
r20_require_process_absent "AgentLoop"
r20_require_process_absent "AgentLoopApp"
r20_append_boundary "utc_begin_attested=$(r20_utc_now)"
r20_append_boundary "begin_attestation_complete=true"
r20_append_boundary "status=BEGIN_ATTESTED"
r20_append_boundary "retry_same_boundary=false"

/usr/bin/printf '%s\n' \
  "status=BEGIN_ATTESTED" \
  "invocation_id=${R20_INVOCATION_ID}" \
  "boundary_log=${R20_BOUNDARY_LOG}" \
  "hash_log=${R20_HASH_LOG}" \
  "state_root=${R20_STATE_ROOT}" \
  "bundle_parent=${R20_BUNDLE_PARENT}" \
  "planned_app=${R20_PLANNED_APP}" \
  "planned_executable=${R20_PLANNED_EXECUTABLE}"
