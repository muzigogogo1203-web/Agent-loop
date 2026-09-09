#!/bin/bash

# R18 BEGIN-only candidate driver.
# This file does not run tests, build, migration matrix, source gates, bundle
# assembly, signing, or preview. It establishes one fail-once evidence boundary.

set -Eeuo pipefail
set -f
IFS=$' \t\n'
umask 077

readonly R18_REPOSITORY_ROOT="/Users/muzi/Agent-loop"
readonly R18_TASK_DIRECTORY="${R18_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination"
readonly R18_DRIVER_PATH="${R18_TASK_DIRECTORY}/evidence/r18-begin.sh"
readonly R18_MANIFEST_PATH="${R18_TASK_DIRECTORY}/evidence/r18-entry.sha256"
readonly R18_FREEZE_PATH="${R18_TASK_DIRECTORY}/evidence/plan-freeze-r18.md"
readonly R18_REVIEW18_PATH="${R18_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/18-p1-plan-review.md"
readonly R18_BOUNDARY_LOG="${R18_TASK_DIRECTORY}/evidence/r18-clean-boundary.log"
readonly R18_HASH_LOG="${R18_TASK_DIRECTORY}/evidence/r18-hash-manifest.log"
readonly R18_RANCH_ART_DIRECTORY="${R18_REPOSITORY_ROOT}/Sources/AgentLoopApp/Resources/RanchArt"
readonly R18_EXPECTED_MANIFEST_COUNT="119"
readonly R18_EXPECTED_BRANCH="codex/personal-ai-ranch-p0"
readonly R18_EXPECTED_HEAD="02334ec8d21533be81d93d39191bc7d9b9c24f7f"
readonly R18_EXPECTED_INFO_PLIST_SHA="5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58"
readonly R18_EXPECTED_RANCH_ART_MANIFEST_SHA="4f73a80e821faa64d0a29d797cc12e20d5f88248bbb186e74972af49798ddbab"
readonly R18_R15_STATE_ROOT_BASENAME="agentloop-r15-state.Zq6Jvm"
readonly R18_R15_BUNDLE_PARENT_BASENAME="agentloop-r15-bundle.2xROcy"
readonly R18_R15_STATE_ROOT="/private/tmp/${R18_R15_STATE_ROOT_BASENAME}"
readonly R18_R15_BUNDLE_PARENT="/private/tmp/${R18_R15_BUNDLE_PARENT_BASENAME}"
readonly R18_R15_ABSENCE_PROOF_IDENTITY="private_tmp_parent_enumeration_exact_basename_v1"
readonly R18_R15_PLANNED_APP="${R18_R15_BUNDLE_PARENT}/AgentLoop.app"
readonly R18_R15_SCREENSHOT="${R18_TASK_DIRECTORY}/evidence/r15-preview-smoke.png"

R18_BOUNDARY_ACTIVE="false"
R18_PHASE="pre_begin"
R18_INVOCATION_ID=""
R18_STATE_ROOT=""
R18_BUNDLE_PARENT=""

r18_utc_now() {
  /bin/date -u '+%Y-%m-%dT%H:%M:%SZ'
}

r18_pre_begin_fail() {
  local r18_exit_code="$1"
  shift
  /usr/bin/printf 'R18 pre-BEGIN rejected: %s\n' "$*" >&2
  exit "$r18_exit_code"
}

r18_append_boundary() {
  /usr/bin/printf '%s\n' "$*" >> "${R18_BOUNDARY_LOG}"
}

r18_authorization_is_consumed() {
  if [[ "${R18_BOUNDARY_ACTIVE}" == "true" ]]; then
    return 0
  fi
  if [[ -n "${R18_INVOCATION_ID}" &&
        -f "${R18_BOUNDARY_LOG}" &&
        ! -L "${R18_BOUNDARY_LOG}" ]] &&
     /usr/bin/grep -Fx "invocation_id=${R18_INVOCATION_ID}" "${R18_BOUNDARY_LOG}" >/dev/null 2>&1 &&
     /usr/bin/grep -Fx 'authorization_consumed=true' "${R18_BOUNDARY_LOG}" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

r18_active_fail() {
  local r18_exit_code="$1"
  local r18_reason="$2"
  local r18_command="${3:-explicit_fail_closed}"
  trap - ERR HUP INT TERM
  set +e
  r18_append_boundary "utc=$(r18_utc_now)"
  r18_append_boundary "status=REJECTED_CONTAMINATED"
  r18_append_boundary "phase=${R18_PHASE}"
  r18_append_boundary "reason=${r18_reason}"
  printf 'failed_command=%q\n' "${r18_command}" >> "${R18_BOUNDARY_LOG}"
  r18_append_boundary "exit_code=${r18_exit_code}"
  r18_append_boundary "state_root=${R18_STATE_ROOT:-UNCREATED}"
  r18_append_boundary "bundle_parent=${R18_BUNDLE_PARENT:-UNCREATED}"
  if [[ -n "${R18_PLANNED_APP:-}" ]]; then
    r18_append_boundary "planned_app=${R18_PLANNED_APP}"
  fi
  r18_append_boundary "retry_same_boundary=false"
  /usr/bin/printf 'R18 rejected after authorization consumption: %s\n' "${r18_reason}" >&2
  exit "$r18_exit_code"
}

r18_unexpected_error() {
  local r18_exit_code="$?"
  local r18_command="${BASH_COMMAND:-unknown}"
  trap - ERR
  if r18_authorization_is_consumed; then
    r18_active_fail "${r18_exit_code}" "unexpected_command_failure" "${r18_command}"
  fi
  printf 'R18 pre-BEGIN command failed: phase=%s rc=%s command=%q\n' \
    "${R18_PHASE}" "${r18_exit_code}" "${r18_command}" >&2
  exit "${r18_exit_code}"
}

r18_signal_error() {
  local r18_signal="$1"
  trap - HUP INT TERM
  if r18_authorization_is_consumed; then
    r18_active_fail "74" "signal_${r18_signal}" "signal_${r18_signal}"
  fi
  /usr/bin/printf 'R18 pre-BEGIN interrupted by signal %s\n' "${r18_signal}" >&2
  exit 74
}

trap r18_unexpected_error ERR
trap 'r18_signal_error HUP' HUP
trap 'r18_signal_error INT' INT
trap 'r18_signal_error TERM' TERM

r18_attestation_fail() {
  local r18_exit_code="$1"
  shift
  if r18_authorization_is_consumed; then
    r18_active_fail "${r18_exit_code}" "$*"
  fi
  r18_pre_begin_fail "${r18_exit_code}" "$*"
}

r18_require_lowercase_sha256() {
  local r18_value="$1"
  local r18_label="$2"
  if [[ "${#r18_value}" -ne 64 ]]; then
    r18_pre_begin_fail 64 "${r18_label} must be exactly 64 lowercase hex characters"
  fi
  case "${r18_value}" in
    *[!0-9a-f]*)
      r18_pre_begin_fail 64 "${r18_label} must be exactly 64 lowercase hex characters"
      ;;
  esac
}

r18_emit_anchor_manifest() {
  /usr/bin/printf '%s  %s\n' "${R18_EXPECTED_FREEZE_SHA}" "${R18_FREEZE_PATH}"
  /usr/bin/printf '%s  %s\n' "${R18_EXPECTED_REVIEW18_SHA}" "${R18_REVIEW18_PATH}"
  /usr/bin/printf '%s  %s\n' "${R18_EXPECTED_DRIVER_SHA}" "${R18_DRIVER_PATH}"
  /usr/bin/printf '%s  %s\n' "${R18_EXPECTED_MANIFEST_SHA}" "${R18_MANIFEST_PATH}"
}

r18_check_anchors_to_stdout() {
  local -a r18_anchor_status
  if r18_emit_anchor_manifest |
    /usr/bin/shasum -a 256 --strict -c -; then
    r18_anchor_status=( "${PIPESTATUS[@]}" )
  else
    r18_anchor_status=( "${PIPESTATUS[@]}" )
  fi
  if [[ "${r18_anchor_status[0]}" -ne 0 || "${r18_anchor_status[1]}" -ne 0 ]]; then
    r18_pre_begin_fail 65 "terminal anchor verification failed with producer_rc=${r18_anchor_status[0]} shasum_rc=${r18_anchor_status[1]}"
  fi
}

r18_check_manifest_shape() {
  local r18_manifest_count
  if [[ ! -f "${R18_MANIFEST_PATH}" || -L "${R18_MANIFEST_PATH}" ]]; then
    r18_attestation_fail 66 "static manifest is missing, non-regular, or a symlink"
  fi
  r18_manifest_count="$(/usr/bin/wc -l < "${R18_MANIFEST_PATH}" | /usr/bin/tr -d '[:space:]')"
  if [[ "${r18_manifest_count}" != "${R18_EXPECTED_MANIFEST_COUNT}" ]]; then
    r18_attestation_fail 66 "static manifest entry count is ${r18_manifest_count}, expected ${R18_EXPECTED_MANIFEST_COUNT}"
  fi
  if /usr/bin/grep -F -- "  ${R18_MANIFEST_PATH}" "${R18_MANIFEST_PATH}" >/dev/null 2>&1; then
    r18_attestation_fail 66 "static manifest must not contain itself"
  fi
  if /usr/bin/grep -F -- "  ${R18_FREEZE_PATH}" "${R18_MANIFEST_PATH}" >/dev/null 2>&1; then
    r18_attestation_fail 66 "static manifest must not contain the R18 freeze"
  fi
  if /usr/bin/grep -F -- "  ${R18_REVIEW18_PATH}" "${R18_MANIFEST_PATH}" >/dev/null 2>&1; then
    r18_attestation_fail 66 "static manifest must not contain Review18"
  fi
  if ! /usr/bin/cut -c 67- "${R18_MANIFEST_PATH}" | LC_ALL=C /usr/bin/sort -cu; then
    r18_attestation_fail 66 "static manifest paths are not bytewise sorted and unique"
  fi
  while IFS= read -r r18_manifest_line; do
    local r18_manifest_entry_path="${r18_manifest_line#*  }"
    case "${r18_manifest_entry_path}" in
      "${R18_REPOSITORY_ROOT}"/*)
        ;;
      *)
        r18_attestation_fail 66 "static manifest entry is outside the repository"
        ;;
    esac
    case "${r18_manifest_entry_path}" in
      *"/../"*|*"/./"*|*/..|*/.)
        r18_attestation_fail 66 "static manifest entry contains a non-canonical path segment"
        ;;
    esac
    if [[ ! -f "${r18_manifest_entry_path}" || -L "${r18_manifest_entry_path}" ]]; then
      r18_attestation_fail 66 "static manifest entry is non-regular or a symlink: ${r18_manifest_entry_path}"
    fi
  done < "${R18_MANIFEST_PATH}"
}

r18_check_manifest_to_stdout() {
  local r18_manifest_rc
  if /usr/bin/shasum -a 256 --strict -c "${R18_MANIFEST_PATH}"; then
    r18_manifest_rc=0
  else
    r18_manifest_rc="$?"
  fi
  if [[ "${r18_manifest_rc}" -ne 0 ]]; then
    r18_pre_begin_fail 66 "static manifest verification failed with rc=${r18_manifest_rc}"
  fi
}

r18_require_process_absent() {
  local r18_process_name="$1"
  local r18_process_rc
  if /usr/bin/pgrep -x "${r18_process_name}" >/dev/null 2>&1; then
    r18_process_rc=0
  else
    r18_process_rc="$?"
  fi
  case "${r18_process_rc}" in
    1)
      ;;
    0)
      r18_attestation_fail 69 "${r18_process_name} process is present"
      ;;
    *)
      r18_attestation_fail 69 "pgrep for ${r18_process_name} was indeterminate with rc=${r18_process_rc}"
      ;;
  esac
}

r18_require_absent_path() {
  local r18_path="$1"
  if [[ -e "${r18_path}" || -L "${r18_path}" ]]; then
    r18_pre_begin_fail 68 "runtime artifact already exists: ${r18_path}"
  fi
}

r18_probe_empty_directory() {
  local r18_path="$1"
  local r18_probe_output
  local r18_probe_rc
  if r18_probe_output="$(
    trap - ERR
    /usr/bin/find "${r18_path}" -mindepth 1 -maxdepth 1 -print -quit 2>&1
  )"; then
    r18_probe_rc=0
  else
    r18_probe_rc="$?"
  fi
  if [[ "${r18_probe_rc}" -ne 0 ]]; then
    return 2
  fi
  if [[ -n "${r18_probe_output}" ]]; then
    return 1
  fi
  return 0
}

r18_require_r15_tombstones_absent() {
  local r18_r15_tombstone_probe_output
  local r18_r15_tombstone_probe_rc
  if [[ -z "${R18_R15_STATE_ROOT_BASENAME}" ||
        "${R18_R15_STATE_ROOT_BASENAME}" == "." ||
        "${R18_R15_STATE_ROOT_BASENAME}" == ".." ||
        -z "${R18_R15_BUNDLE_PARENT_BASENAME}" ||
        "${R18_R15_BUNDLE_PARENT_BASENAME}" == "." ||
        "${R18_R15_BUNDLE_PARENT_BASENAME}" == ".." ||
        "${R18_R15_STATE_ROOT_BASENAME}" == "${R18_R15_BUNDLE_PARENT_BASENAME}" ]]; then
    r18_pre_begin_fail 70 "R15 tombstone basenames are invalid or non-distinct"
  fi
  if [[ "${R18_R15_STATE_ROOT_BASENAME}" != "agentloop-r15-state.Zq6Jvm" ||
        "${R18_R15_BUNDLE_PARENT_BASENAME}" != "agentloop-r15-bundle.2xROcy" ||
        "${R18_R15_STATE_ROOT}" != "/private/tmp/agentloop-r15-state.Zq6Jvm" ||
        "${R18_R15_BUNDLE_PARENT}" != "/private/tmp/agentloop-r15-bundle.2xROcy" ]]; then
    r18_pre_begin_fail 70 "R15 tombstone frozen basename or path identity drifted"
  fi
  if [[ "${R18_R15_STATE_ROOT}" != "/private/tmp/${R18_R15_STATE_ROOT_BASENAME}" ||
        "${R18_R15_BUNDLE_PARENT}" != "/private/tmp/${R18_R15_BUNDLE_PARENT_BASENAME}" ]]; then
    r18_pre_begin_fail 70 "R15 tombstone path reconstruction failed"
  fi
  if [[ ! -d /private/tmp || -L /private/tmp ]]; then
    r18_pre_begin_fail 70 "R15 tombstone parent is missing, non-directory, or symlink: /private/tmp"
  fi
  if r18_r15_tombstone_probe_output="$(
    trap - ERR
    /usr/bin/find /private/tmp \
      -mindepth 1 -maxdepth 1 \
      \( \
        -name "${R18_R15_STATE_ROOT_BASENAME}" -o \
        -name "${R18_R15_BUNDLE_PARENT_BASENAME}" \
      \) \
      -print -quit 2>&1
  )"; then
    r18_r15_tombstone_probe_rc=0
  else
    r18_r15_tombstone_probe_rc="$?"
  fi
  if [[ "${r18_r15_tombstone_probe_rc}" -ne 0 ]]; then
    r18_pre_begin_fail 70 "R15 tombstone absence parent enumeration was indeterminate with rc=${r18_r15_tombstone_probe_rc}"
  fi
  if [[ -n "${r18_r15_tombstone_probe_output}" ]]; then
    r18_pre_begin_fail 70 "R15 tombstoned volatile root reappeared: ${r18_r15_tombstone_probe_output}"
  fi
  if [[ -e "${R18_R15_STATE_ROOT}" || -L "${R18_R15_STATE_ROOT}" ]]; then
    r18_pre_begin_fail 70 "R15 tombstoned state root reappeared after parent enumeration: ${R18_R15_STATE_ROOT}"
  fi
  if [[ -e "${R18_R15_BUNDLE_PARENT}" || -L "${R18_R15_BUNDLE_PARENT}" ]]; then
    r18_pre_begin_fail 70 "R15 tombstoned bundle parent reappeared after parent enumeration: ${R18_R15_BUNDLE_PARENT}"
  fi
}

r18_require_no_unconsumed_fresh_roots() {
  local r18_root_probe_output
  local r18_root_probe_rc
  if r18_root_probe_output="$(
    trap - ERR
    /usr/bin/find /private/tmp \
      -mindepth 1 -maxdepth 1 \
      \( \
        -name 'agentloop-r16-state.*' -o \
        -name 'agentloop-r16-bundle.*' -o \
        -name 'agentloop-r17-state.*' -o \
        -name 'agentloop-r17-bundle.*' -o \
        -name 'agentloop-r18-state.*' -o \
        -name 'agentloop-r18-bundle.*' \
      \) \
      -print -quit 2>&1
  )"; then
    r18_root_probe_rc=0
  else
    r18_root_probe_rc="$?"
  fi
  if [[ "${r18_root_probe_rc}" -ne 0 ]]; then
    r18_pre_begin_fail 70 "R16/R17/R18 fresh-root absence probe was indeterminate with rc=${r18_root_probe_rc}"
  fi
  if [[ -n "${r18_root_probe_output}" ]]; then
    r18_pre_begin_fail 70 "R16/R17/R18 fresh root must remain absent: ${r18_root_probe_output}"
  fi
}

r18_exclusive_create_empty() {
  local r18_path="$1"
  ( set -C; : > "${r18_path}" )
}

r18_require_fresh_root() {
  local r18_path="$1"
  local r18_label="$2"
  local r18_probe_rc
  local r18_realpath
  local r18_realpath_rc
  if [[ ! -d "${r18_path}" || -L "${r18_path}" ]]; then
    r18_active_fail 72 "${r18_label}_invalid_type"
  fi
  if r18_realpath="$(
    trap - ERR
    /bin/realpath "${r18_path}" 2>&1
  )"; then
    r18_realpath_rc=0
  else
    r18_realpath_rc="$?"
  fi
  if [[ "${r18_realpath_rc}" -ne 0 ]]; then
    r18_active_fail 72 "${r18_label}_realpath_probe_failed"
  fi
  if [[ "${r18_realpath}" != "${r18_path}" ]]; then
    r18_active_fail 72 "${r18_label}_realpath_mismatch"
  fi
  if r18_probe_empty_directory "${r18_path}"; then
    return 0
  else
    r18_probe_rc="$?"
  fi
  if [[ "${r18_probe_rc}" -eq 1 ]]; then
    r18_active_fail 72 "${r18_label}_not_empty"
  fi
  r18_active_fail 72 "${r18_label}_emptiness_probe_indeterminate"
}

r18_post_activation_anchor_check() {
  local -a r18_anchor_status
  {
    /usr/bin/printf '%s\n' "section=terminal_anchors"
    r18_emit_anchor_manifest
  } >> "${R18_HASH_LOG}"
  if r18_emit_anchor_manifest |
    /usr/bin/shasum -a 256 --strict -c - >> "${R18_HASH_LOG}" 2>&1; then
    r18_anchor_status=( "${PIPESTATUS[@]}" )
  else
    r18_anchor_status=( "${PIPESTATUS[@]}" )
  fi
  /usr/bin/printf 'terminal_anchor_producer_rc=%s\n' "${r18_anchor_status[0]}" >> "${R18_HASH_LOG}"
  /usr/bin/printf 'terminal_anchor_shasum_rc=%s\n' "${r18_anchor_status[1]}" >> "${R18_HASH_LOG}"
  if [[ "${r18_anchor_status[0]}" -ne 0 || "${r18_anchor_status[1]}" -ne 0 ]]; then
    r18_active_fail 65 "post_activation_terminal_anchor_failure_producer_${r18_anchor_status[0]}_shasum_${r18_anchor_status[1]}"
  fi
}

r18_post_activation_manifest_check() {
  local r18_manifest_rc
  local r18_manifest_count
  r18_manifest_count="$(/usr/bin/wc -l < "${R18_MANIFEST_PATH}" | /usr/bin/tr -d '[:space:]')"
  /usr/bin/printf '%s\n' "section=static_manifest" >> "${R18_HASH_LOG}"
  /usr/bin/printf 'static_manifest_expected_count=%s\n' "${R18_EXPECTED_MANIFEST_COUNT}" >> "${R18_HASH_LOG}"
  /usr/bin/printf 'static_manifest_actual_count=%s\n' "${r18_manifest_count}" >> "${R18_HASH_LOG}"
  if /usr/bin/shasum -a 256 --strict -c "${R18_MANIFEST_PATH}" >> "${R18_HASH_LOG}" 2>&1; then
    r18_manifest_rc=0
  else
    r18_manifest_rc="$?"
  fi
  /usr/bin/printf 'static_manifest_rc=%s\n' "${r18_manifest_rc}" >> "${R18_HASH_LOG}"
  if [[ "${r18_manifest_rc}" -ne 0 ]]; then
    r18_active_fail 66 "post_activation_static_manifest_failure_rc_${r18_manifest_rc}"
  fi
  if [[ "${r18_manifest_count}" != "${R18_EXPECTED_MANIFEST_COUNT}" ]]; then
    r18_active_fail 66 "post_activation_static_manifest_count_${r18_manifest_count}"
  fi
}

r18_check_ranch_art_structure() {
  local r18_verification_mode="$1"
  local r18_evidence_sink
  local r18_evidence_phase
  local r18_expected_paths
  local r18_raw_paths
  local r18_actual_paths
  local r18_find_rc
  local r18_transform_rc
  local r18_diff_rc
  local r18_unexpected_node
  local r18_unexpected_rc
  local r18_regular_count
  local r18_count_rc

  case "${r18_verification_mode}" in
    pre_begin)
      if r18_authorization_is_consumed; then
        r18_attestation_fail 70 "pre_begin_ranch_art_check_after_authorization_consumption"
      fi
      r18_evidence_sink="/dev/stderr"
      r18_evidence_phase="pre_consumption"
      ;;
    post_activation)
      if ! r18_authorization_is_consumed; then
        r18_pre_begin_fail 70 "post_activation_ranch_art_check_before_authorization_consumption"
      fi
      if [[ ! -f "${R18_HASH_LOG}" || -L "${R18_HASH_LOG}" ]]; then
        r18_active_fail 70 "post_activation_ranch_art_hash_log_invalid"
      fi
      r18_evidence_sink="${R18_HASH_LOG}"
      r18_evidence_phase="post_activation"
      ;;
    *)
      r18_attestation_fail 64 "invalid RanchArt verification mode: ${r18_verification_mode}"
      ;;
  esac

  /usr/bin/printf '%s\n' "section=ranch_art_structure" >> "${r18_evidence_sink}"
  /usr/bin/printf 'phase=%s\n' "${r18_evidence_phase}" >> "${r18_evidence_sink}"
  /usr/bin/printf 'ranch_art_verification_mode=%s\n' \
    "${r18_verification_mode}" >> "${r18_evidence_sink}"

  r18_expected_paths="$(
    /usr/bin/printf '%s\n' \
      "PixelBarnDay.png" \
      "PixelBarnNight.png" \
      "PixelCowSideAmber.png" \
      "PixelCowSideBlue.png" \
      "PixelCowSideCoral.png" \
      "PixelCowSideGreen.png" \
      "PixelCowSidePink.png" \
      "PixelCowSidePurple.png" \
      "PixelCowSideTeal.png" \
      "PixelCowSleepAmber.png" \
      "PixelCowSleepBlue.png" \
      "PixelCowSleepCoral.png" \
      "PixelCowSleepGreen.png" \
      "PixelCowSleepPink.png" \
      "PixelCowSleepPurple.png" \
      "PixelCowSleepTeal.png" \
      "PixelCowStrideAmber.png" \
      "PixelCowStrideBlue.png" \
      "PixelCowStrideCoral.png" \
      "PixelCowStrideGreen.png" \
      "PixelCowStridePink.png" \
      "PixelCowStridePurple.png" \
      "PixelCowStrideTeal.png" \
      "PixelPanoramaDay.png" \
      "PixelPanoramaNight.png" \
      "PixelPastureDay.png" \
      "PixelPastureNight.png"
  )"

  if r18_raw_paths="$(
    trap - ERR
    /usr/bin/find "${R18_RANCH_ART_DIRECTORY}" \
      -mindepth 1 -maxdepth 1 -type f -print 2>&1
  )"; then
    r18_find_rc=0
  else
    r18_find_rc="$?"
  fi
  /usr/bin/printf 'ranch_art_file_find_rc=%s\n' "${r18_find_rc}" >> "${r18_evidence_sink}"
  if [[ "${r18_find_rc}" -ne 0 ]]; then
    /usr/bin/printf 'ranch_art_file_find_output=%s\n' "${r18_raw_paths}" >> "${r18_evidence_sink}"
    r18_attestation_fail 70 "ranch_art_file_find_indeterminate_rc_${r18_find_rc}"
  fi

  if r18_actual_paths="$(
    trap - ERR
    /usr/bin/printf '%s\n' "${r18_raw_paths}" |
      /usr/bin/sed "s#^${R18_RANCH_ART_DIRECTORY}/##" |
      LC_ALL=C /usr/bin/sort
  )"; then
    r18_transform_rc=0
  else
    r18_transform_rc="$?"
  fi
  /usr/bin/printf 'ranch_art_path_transform_rc=%s\n' "${r18_transform_rc}" >> "${r18_evidence_sink}"
  if [[ "${r18_transform_rc}" -ne 0 ]]; then
    r18_attestation_fail 70 "ranch_art_path_transform_indeterminate_rc_${r18_transform_rc}"
  fi

  if /usr/bin/diff -u \
    <(/usr/bin/printf '%s\n' "${r18_expected_paths}") \
    <(/usr/bin/printf '%s\n' "${r18_actual_paths}") \
    >> "${r18_evidence_sink}" 2>&1; then
    r18_diff_rc=0
  else
    r18_diff_rc="$?"
  fi
  /usr/bin/printf 'ranch_art_path_set_diff_rc=%s\n' "${r18_diff_rc}" >> "${r18_evidence_sink}"
  if [[ "${r18_diff_rc}" -ne 0 ]]; then
    r18_attestation_fail 70 "ranch_art_exact_path_set_mismatch_rc_${r18_diff_rc}"
  fi
  /usr/bin/printf '%s\n%s\n%s\n' \
    "ranch_art_exact_relative_path_set_begin" \
    "${r18_actual_paths}" \
    "ranch_art_exact_relative_path_set_end" >> "${r18_evidence_sink}"

  if r18_unexpected_node="$(
    trap - ERR
    /usr/bin/find "${R18_RANCH_ART_DIRECTORY}" \
      -mindepth 1 -maxdepth 1 ! -type f -print -quit 2>&1
  )"; then
    r18_unexpected_rc=0
  else
    r18_unexpected_rc="$?"
  fi
  /usr/bin/printf 'ranch_art_nonregular_find_rc=%s\n' "${r18_unexpected_rc}" >> "${r18_evidence_sink}"
  if [[ "${r18_unexpected_rc}" -ne 0 ]]; then
    /usr/bin/printf 'ranch_art_nonregular_find_output=%s\n' "${r18_unexpected_node}" >> "${r18_evidence_sink}"
    r18_attestation_fail 70 "ranch_art_nonregular_find_indeterminate_rc_${r18_unexpected_rc}"
  fi
  if [[ -n "${r18_unexpected_node}" ]]; then
    /usr/bin/printf 'ranch_art_first_nonregular_node=%s\n' "${r18_unexpected_node}" >> "${r18_evidence_sink}"
    r18_attestation_fail 70 "ranch_art_nonregular_node_present"
  fi
  /usr/bin/printf '%s\n' "nonregular_count=0" >> "${r18_evidence_sink}"

  if r18_regular_count="$(
    trap - ERR
    /usr/bin/printf '%s\n' "${r18_actual_paths}" |
      /usr/bin/wc -l |
      /usr/bin/tr -d '[:space:]'
  )"; then
    r18_count_rc=0
  else
    r18_count_rc="$?"
  fi
  if [[ "${r18_count_rc}" -ne 0 ]]; then
    r18_attestation_fail 70 "ranch_art_count_indeterminate_rc_${r18_count_rc}"
  fi
  /usr/bin/printf 'ranch_art_regular_file_count=%s\n' "${r18_regular_count}" >> "${r18_evidence_sink}"
  /usr/bin/printf '%s\n' "ranch_art_symlink_count=0" >> "${r18_evidence_sink}"
  if [[ "${r18_regular_count}" != "27" ]]; then
    r18_attestation_fail 70 "ranch_art_regular_file_count_${r18_regular_count}"
  fi
  /usr/bin/printf '%s\n' "regular_count=27" >> "${r18_evidence_sink}"
}

if [[ "$#" -ne 4 ]]; then
  r18_pre_begin_fail 64 "expected four SHA-256 arguments: freeze Review18 driver manifest"
fi

readonly R18_EXPECTED_FREEZE_SHA="$1"
readonly R18_EXPECTED_REVIEW18_SHA="$2"
readonly R18_EXPECTED_DRIVER_SHA="$3"
readonly R18_EXPECTED_MANIFEST_SHA="$4"

r18_require_lowercase_sha256 "${R18_EXPECTED_FREEZE_SHA}" "freeze hash"
r18_require_lowercase_sha256 "${R18_EXPECTED_REVIEW18_SHA}" "Review18 hash"
r18_require_lowercase_sha256 "${R18_EXPECTED_DRIVER_SHA}" "driver hash"
r18_require_lowercase_sha256 "${R18_EXPECTED_MANIFEST_SHA}" "manifest hash"

if [[ "$0" != "${R18_DRIVER_PATH}" ]]; then
  r18_pre_begin_fail 64 "driver must be invoked by its frozen absolute path"
fi
if [[ "${BASH_SOURCE[0]}" != "${R18_DRIVER_PATH}" ||
      ! -f "${R18_DRIVER_PATH}" ||
      -L "${R18_DRIVER_PATH}" ||
      "$(/bin/realpath "${R18_DRIVER_PATH}")" != "${R18_DRIVER_PATH}" ]]; then
  r18_pre_begin_fail 64 "driver source path or file type is not canonical"
fi
if (( BASH_VERSINFO[0] < 3 ||
      (BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] < 2) )); then
  r18_pre_begin_fail 64 "Bash 3.2 or newer is required"
fi
if [[ "${LC_ALL:-}" != "C" || "${LANG:-}" != "C" ]]; then
  r18_pre_begin_fail 64 "LC_ALL and LANG must both equal C"
fi
if [[ "${PATH:-}" != "/usr/bin:/bin:/usr/sbin:/sbin" ]]; then
  r18_pre_begin_fail 64 "PATH is not the frozen clean value"
fi
if [[ "${TMPDIR:-}" != "/private/tmp" ]]; then
  r18_pre_begin_fail 64 "TMPDIR is not the frozen clean value"
fi
if [[ "${GIT_CONFIG_NOSYSTEM:-}" != "1" || "${GIT_CONFIG_GLOBAL:-}" != "/dev/null" ]]; then
  r18_pre_begin_fail 64 "Git clean-environment controls are missing"
fi
if [[ -n "${BASH_ENV+x}" || -n "${ENV+x}" || -n "${CDPATH+x}" ]]; then
  r18_pre_begin_fail 64 "shell startup or directory environment was inherited"
fi

R18_PHASE="pre_begin_terminal_anchors"
r18_check_anchors_to_stdout

R18_PHASE="pre_begin_manifest_shape"
r18_check_manifest_shape

R18_PHASE="pre_begin_static_manifest"
r18_check_manifest_to_stdout

R18_PHASE="pre_begin_repository_identity"
R18_ACTUAL_BRANCH="$(/usr/bin/git -C "${R18_REPOSITORY_ROOT}" symbolic-ref --quiet --short HEAD)"
R18_ACTUAL_HEAD="$(/usr/bin/git -C "${R18_REPOSITORY_ROOT}" rev-parse --verify HEAD)"
if [[ "${R18_ACTUAL_BRANCH}" != "${R18_EXPECTED_BRANCH}" ]]; then
  r18_pre_begin_fail 67 "branch is ${R18_ACTUAL_BRANCH}, expected ${R18_EXPECTED_BRANCH}"
fi
if [[ "${R18_ACTUAL_HEAD}" != "${R18_EXPECTED_HEAD}" ]]; then
  r18_pre_begin_fail 67 "HEAD is ${R18_ACTUAL_HEAD}, expected ${R18_EXPECTED_HEAD}"
fi

R18_PHASE="pre_begin_r16_preservation"
R18_R16_RUNTIME_PATHS=(
  "${R18_TASK_DIRECTORY}/r16-targeted-tests.log"
  "${R18_TASK_DIRECTORY}/r16-verify.log"
  "${R18_TASK_DIRECTORY}/r16-build.log"
  "${R18_TASK_DIRECTORY}/r16-migration-matrix.log"
  "${R18_TASK_DIRECTORY}/impl-report-r16.md"
  "${R18_TASK_DIRECTORY}/evidence/r16-clean-boundary.log"
  "${R18_TASK_DIRECTORY}/evidence/r16-bundle-provenance.log"
  "${R18_TASK_DIRECTORY}/evidence/r16-source-gates.log"
  "${R18_TASK_DIRECTORY}/evidence/r16-hash-manifest.log"
  "${R18_TASK_DIRECTORY}/evidence/r16-preview-bootstrap.log"
  "${R18_TASK_DIRECTORY}/evidence/r16-preview-cold-start.log"
  "${R18_TASK_DIRECTORY}/evidence/r16-preview-smoke.png"
)
for R18_R16_RUNTIME_PATH in "${R18_R16_RUNTIME_PATHS[@]}"; do
  r18_require_absent_path "${R18_R16_RUNTIME_PATH}"
done

R18_PHASE="pre_begin_r17_preservation"
R18_R17_RUNTIME_PATHS=(
  "${R18_TASK_DIRECTORY}/r17-targeted-tests.log"
  "${R18_TASK_DIRECTORY}/r17-verify.log"
  "${R18_TASK_DIRECTORY}/r17-build.log"
  "${R18_TASK_DIRECTORY}/r17-migration-matrix.log"
  "${R18_TASK_DIRECTORY}/impl-report-r17.md"
  "${R18_TASK_DIRECTORY}/evidence/r17-clean-boundary.log"
  "${R18_TASK_DIRECTORY}/evidence/r17-bundle-provenance.log"
  "${R18_TASK_DIRECTORY}/evidence/r17-source-gates.log"
  "${R18_TASK_DIRECTORY}/evidence/r17-hash-manifest.log"
  "${R18_TASK_DIRECTORY}/evidence/r17-preview-bootstrap.log"
  "${R18_TASK_DIRECTORY}/evidence/r17-preview-cold-start.log"
  "${R18_TASK_DIRECTORY}/evidence/r17-preview-smoke.png"
)
for R18_R17_RUNTIME_PATH in "${R18_R17_RUNTIME_PATHS[@]}"; do
  r18_require_absent_path "${R18_R17_RUNTIME_PATH}"
done
r18_require_no_unconsumed_fresh_roots

R18_PHASE="pre_begin_runtime_paths"
R18_RUNTIME_PATHS=(
  "${R18_TASK_DIRECTORY}/r18-targeted-tests.log"
  "${R18_TASK_DIRECTORY}/r18-verify.log"
  "${R18_TASK_DIRECTORY}/r18-build.log"
  "${R18_TASK_DIRECTORY}/r18-migration-matrix.log"
  "${R18_TASK_DIRECTORY}/impl-report-r18.md"
  "${R18_TASK_DIRECTORY}/evidence/r18-clean-boundary.log"
  "${R18_TASK_DIRECTORY}/evidence/r18-bundle-provenance.log"
  "${R18_TASK_DIRECTORY}/evidence/r18-source-gates.log"
  "${R18_TASK_DIRECTORY}/evidence/r18-hash-manifest.log"
  "${R18_TASK_DIRECTORY}/evidence/r18-preview-bootstrap.log"
  "${R18_TASK_DIRECTORY}/evidence/r18-preview-cold-start.log"
  "${R18_TASK_DIRECTORY}/evidence/r18-preview-smoke.png"
)
for R18_RUNTIME_PATH in "${R18_RUNTIME_PATHS[@]}"; do
  r18_require_absent_path "${R18_RUNTIME_PATH}"
done

R18_PHASE="pre_begin_processes"
r18_require_process_absent "AgentLoop"
r18_require_process_absent "AgentLoopApp"

R18_PHASE="pre_begin_r15_tombstone_absence"
r18_require_r15_tombstones_absent
if [[ -e "${R18_R15_PLANNED_APP}" || -L "${R18_R15_PLANNED_APP}" ]]; then
  r18_pre_begin_fail 70 "R15 planned App must remain absent"
fi
if [[ -e "${R18_R15_SCREENSHOT}" || -L "${R18_R15_SCREENSHOT}" ]]; then
  r18_pre_begin_fail 70 "R15 screenshot must remain absent"
fi

R18_PHASE="pre_begin_activation_metadata"
R18_INVOCATION_ID="r18-$(
  /usr/bin/uuidgen |
    /usr/bin/tr '[:upper:]' '[:lower:]'
)"
if [[ ! "${R18_INVOCATION_ID}" =~ ^r18-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
  r18_pre_begin_fail 71 "generated R18 invocation ID has invalid format"
fi
R18_BEGIN_UTC="$(r18_utc_now)"
if [[ ! "${R18_BEGIN_UTC}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
  r18_pre_begin_fail 71 "generated R18 begin UTC has invalid format"
fi

R18_PHASE="pre_begin_ranch_art_structure"
r18_check_ranch_art_structure "pre_begin"

if ! (
  set -C
  /usr/bin/printf '%s\n' \
    "boundary=R18_CLEAN_REVERIFICATION" \
    "invocation_id=${R18_INVOCATION_ID}" \
    "utc_begin=${R18_BEGIN_UTC}" \
    "authorization_consumed=true" \
    "status=BEGIN_STARTED" \
    "branch=${R18_ACTUAL_BRANCH}" \
    "head=${R18_ACTUAL_HEAD}" \
    "r15_state_root_pre_begin_observed_state=ABSENT" \
    "r15_bundle_parent_pre_begin_observed_state=ABSENT" \
    "r15_state_root_current_absent=true" \
    "r15_bundle_parent_current_absent=true" \
    "r15_absence_proof_identity=${R18_R15_ABSENCE_PROOF_IDENTITY}" \
    "disappearance_cause=UNKNOWN" \
    "pre_begin_ranch_art_structure=true" \
    "recipe=r18-dev-bundle-v1" \
    "normal_root=/Users/muzi/Library/Application Support/AgentLoop" \
    "normal_root_access_policy=lsof_path_comparison_only" \
    "freeze_sha=${R18_EXPECTED_FREEZE_SHA}" \
    "review18_sha=${R18_EXPECTED_REVIEW18_SHA}" \
    "driver_sha=${R18_EXPECTED_DRIVER_SHA}" \
    "manifest_sha=${R18_EXPECTED_MANIFEST_SHA}" \
    > "${R18_BOUNDARY_LOG}"
); then
  R18_PHASE="activation_boundary"
  r18_attestation_fail 71 "could not exclusive-create and initialize R18 boundary log"
fi
R18_PHASE="activation_boundary"
R18_BOUNDARY_ACTIVE="true"

R18_PHASE="activation_hash_log"
if ! r18_exclusive_create_empty "${R18_HASH_LOG}"; then
  r18_active_fail 71 "exclusive_create_failed_${R18_HASH_LOG}" "exclusive_create"
fi

R18_PHASE="post_activation_ranch_art_structure"
r18_check_ranch_art_structure "post_activation"

R18_PHASE="post_activation_terminal_anchors"
r18_post_activation_anchor_check

R18_PHASE="post_activation_static_manifest"
r18_check_manifest_shape
r18_post_activation_manifest_check
/usr/bin/printf 'frozen_info_plist_sha=%s\n' "${R18_EXPECTED_INFO_PLIST_SHA}" >> "${R18_HASH_LOG}"
/usr/bin/printf 'frozen_ranch_art_manifest_sha=%s\n' "${R18_EXPECTED_RANCH_ART_MANIFEST_SHA}" >> "${R18_HASH_LOG}"
/usr/bin/printf '%s\n' "section=worktree_status" >> "${R18_HASH_LOG}"
/usr/bin/git --no-optional-locks -C "${R18_REPOSITORY_ROOT}" status --short --branch >> "${R18_HASH_LOG}"

R18_PHASE="activation_remaining_logs"
R18_REMAINING_TEXT_LOGS=(
  "${R18_TASK_DIRECTORY}/r18-targeted-tests.log"
  "${R18_TASK_DIRECTORY}/r18-verify.log"
  "${R18_TASK_DIRECTORY}/r18-build.log"
  "${R18_TASK_DIRECTORY}/r18-migration-matrix.log"
  "${R18_TASK_DIRECTORY}/evidence/r18-bundle-provenance.log"
  "${R18_TASK_DIRECTORY}/evidence/r18-source-gates.log"
  "${R18_TASK_DIRECTORY}/evidence/r18-preview-bootstrap.log"
  "${R18_TASK_DIRECTORY}/evidence/r18-preview-cold-start.log"
)
for R18_REMAINING_TEXT_LOG in "${R18_REMAINING_TEXT_LOGS[@]}"; do
  if ! r18_exclusive_create_empty "${R18_REMAINING_TEXT_LOG}"; then
    r18_active_fail 71 "exclusive_create_failed_${R18_REMAINING_TEXT_LOG}" "exclusive_create"
  fi
done

R18_PHASE="activation_fresh_roots"
R18_STATE_ROOT="$(/usr/bin/mktemp -d '/private/tmp/agentloop-r18-state.XXXXXX')"
R18_BUNDLE_PARENT="$(/usr/bin/mktemp -d '/private/tmp/agentloop-r18-bundle.XXXXXX')"
R18_PLANNED_APP="${R18_BUNDLE_PARENT}/AgentLoop.app"
R18_PLANNED_EXECUTABLE="${R18_PLANNED_APP}/Contents/MacOS/AgentLoop"

r18_require_fresh_root "${R18_STATE_ROOT}" "fresh_state_root"
r18_require_fresh_root "${R18_BUNDLE_PARENT}" "fresh_bundle_parent"
if [[ "${R18_STATE_ROOT}" == "${R18_BUNDLE_PARENT}" ]]; then
  r18_active_fail 72 "fresh_roots_equal"
fi
case "${R18_STATE_ROOT}/" in
  "${R18_BUNDLE_PARENT}/"* )
    r18_active_fail 72 "state_root_nested_in_bundle_parent"
    ;;
esac
case "${R18_BUNDLE_PARENT}/" in
  "${R18_STATE_ROOT}/"* )
    r18_active_fail 72 "bundle_parent_nested_in_state_root"
    ;;
esac
if [[ "${R18_STATE_ROOT}" == "${R18_R15_STATE_ROOT}" ||
      "${R18_STATE_ROOT}" == "${R18_R15_BUNDLE_PARENT}" ||
      "${R18_BUNDLE_PARENT}" == "${R18_R15_STATE_ROOT}" ||
      "${R18_BUNDLE_PARENT}" == "${R18_R15_BUNDLE_PARENT}" ]]; then
  r18_active_fail 72 "fresh_root_reuses_r15_root"
fi
if [[ -e "${R18_PLANNED_APP}" || -L "${R18_PLANNED_APP}" ]]; then
  r18_active_fail 72 "planned_app_preexists"
fi

r18_append_boundary "state_root=${R18_STATE_ROOT}"
r18_append_boundary "bundle_parent=${R18_BUNDLE_PARENT}"
r18_append_boundary "planned_app=${R18_PLANNED_APP}"
r18_append_boundary "planned_executable=${R18_PLANNED_EXECUTABLE}"
r18_append_boundary "final_executable_hash=DEFERRED_TO_LAUNCH_READY"
r18_append_boundary "process_count=0"
r18_append_boundary "r15_planned_app_absent=true"
r18_append_boundary "r15_screenshot_absent=true"
r18_append_boundary "r16_runtime_artifacts_absent=true"
r18_append_boundary "r16_fresh_roots_absent=true"
r18_append_boundary "r16_pre_begin_zero_write_preserved=true"
r18_append_boundary "r17_runtime_artifacts_absent=true"
r18_append_boundary "r17_fresh_roots_absent=true"
r18_append_boundary "r17_not_executed_preserved=true"
r18_append_boundary "r18_pre_activation_fresh_roots_absent=true"
r18_append_boundary "frozen_info_plist_sha=${R18_EXPECTED_INFO_PLIST_SHA}"
r18_append_boundary "frozen_ranch_art_manifest_sha=${R18_EXPECTED_RANCH_ART_MANIFEST_SHA}"

R18_PHASE="begin_finalization"
r18_require_process_absent "AgentLoop"
r18_require_process_absent "AgentLoopApp"
r18_append_boundary "utc_begin_attested=$(r18_utc_now)"
r18_append_boundary "begin_attestation_complete=true"
r18_append_boundary "status=BEGIN_ATTESTED"
r18_append_boundary "retry_same_boundary=false"

/usr/bin/printf '%s\n' \
  "status=BEGIN_ATTESTED" \
  "invocation_id=${R18_INVOCATION_ID}" \
  "boundary_log=${R18_BOUNDARY_LOG}" \
  "hash_log=${R18_HASH_LOG}" \
  "state_root=${R18_STATE_ROOT}" \
  "bundle_parent=${R18_BUNDLE_PARENT}" \
  "planned_app=${R18_PLANNED_APP}" \
  "planned_executable=${R18_PLANNED_EXECUTABLE}"
